// lumira-server/packages/backend/src/modules/invite/invite.service.ts

import { Injectable, BadRequestException, ConflictException } from '@nestjs/common';
import { eq, and, count, desc } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { devices, inviteRecords, rewardTiers, rewardUnlocks } from '../../database/schema';
import { generateInviteCode } from '../../shared/invite-code.generator';

@Injectable()
export class InviteService {
  constructor(private readonly dbService: DatabaseService) {}

  // 生成或获取已有邀请码（存入 devices.invite_code 列）
  async generateInviteCode(deviceId: string): Promise<string> {
    const db = this.dbService.getDb();

    const device = await db.query.devices.findFirst({
      where: eq(devices.deviceId, deviceId),
    });

    // 兼容读取：优先新列；为空但旧 ip_region 前缀存在则一次性迁移
    let existingCode = device?.inviteCode ?? null;
    if (!existingCode && device?.ipRegion?.startsWith('invite:')) {
      existingCode = device.ipRegion.substring(7);
      await db.update(devices)
        .set({ inviteCode: existingCode })
        .where(eq(devices.deviceId, deviceId));
    }
    if (existingCode) {
      return existingCode;
    }

    // 生成唯一邀请码
    let code: string;
    let attempts = 0;
    do {
      code = generateInviteCode();
      attempts++;
      if (attempts > 10) {
        throw new BadRequestException('Failed to generate unique invite code');
      }
    } while (await this.inviteCodeExists(code));

    await db.update(devices)
      .set({ inviteCode: code })
      .where(eq(devices.deviceId, deviceId));

    return code;
  }

  private async inviteCodeExists(code: string): Promise<boolean> {
    const db = this.dbService.getDb();
    const result = await db.query.devices.findFirst({
      where: eq(devices.inviteCode, code),
    });
    return !!result;
  }

  // 通过邀请码找到邀请人设备
  async findInviterByCode(code: string): Promise<string | null> {
    const db = this.dbService.getDb();
    const result = await db.query.devices.findFirst({
      where: eq(devices.inviteCode, code),
    });
    return result?.deviceId || null;
  }

  // 激活邀请
  async activateInvite(
    inviteeDeviceId: string,
    inviteCode: string,
    channel: string,
    inviteeIp: string,
  ) {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    // 1. 查找邀请人
    const inviterDeviceId = await this.findInviterByCode(inviteCode);
    if (!inviterDeviceId) {
      throw new BadRequestException('Invalid invite code');
    }

    // 2. 自邀拦截
    if (inviterDeviceId === inviteeDeviceId) {
      throw new BadRequestException('Cannot use your own invite code');
    }

    // 3. 检查被邀请人是否已激活过
    const existingActivation = await db.query.inviteRecords.findFirst({
      where: eq(inviteRecords.inviteeDeviceId, inviteeDeviceId),
    });
    if (existingActivation) {
      throw new ConflictException('This device has already activated an invite');
    }

    // Anti-fraud check 4: 2-cycle detection (A→B then B→A).
    // Note: Longer cycles (A→B→C→A) are NOT prevented by this check.
    // This is an accepted MVP limitation — three colluding devices could mutually inflate counts.
    // Extend to transitive closure if fraud becomes a problem at scale.
    // 4. 防回流：检查被邀请人是否曾邀请过当前邀请人
    const reverseRecord = await db.query.inviteRecords.findFirst({
      where: and(
        eq(inviteRecords.inviterDeviceId, inviteeDeviceId),
        eq(inviteRecords.inviteeDeviceId, inviterDeviceId),
      ),
    });
    if (reverseRecord) {
      throw new BadRequestException('Invite cycle detected');
    }

    // 5. 写入邀请记录
    await db.insert(inviteRecords).values({
      inviterDeviceId,
      inviteeDeviceId,
      inviteCode,
      channel,
      activatedAt: now,
      inviterIp: null,
      inviteeIp,
    });

    // 6. 重新计算邀请人累计邀请数
    const countResult = await db.select({ value: count() })
      .from(inviteRecords)
      .where(eq(inviteRecords.inviterDeviceId, inviterDeviceId));
    const totalInvites = countResult[0]?.value || 0;

    // 7. 检查是否达到新的奖励阶梯
    const tiers = await db.query.rewardTiers.findMany({
      where: eq(rewardTiers.isActive, 1),
    });

    let tierReached: number | null = null;
    let rewards: any = null;

    for (const tier of tiers.sort((a, b) => a.tier - b.tier)) {
      if (totalInvites >= tier.requiredInvites) {
        // 检查是否已解锁过此阶梯
        const existingUnlock = await db.query.rewardUnlocks.findFirst({
          where: and(
            eq(rewardUnlocks.deviceId, inviterDeviceId),
            eq(rewardUnlocks.tier, tier.tier),
            eq(rewardUnlocks.source, 'invite'),
          ),
        });

        if (!existingUnlock) {
          await db.insert(rewardUnlocks).values({
            deviceId: inviterDeviceId,
            tier: tier.tier,
            source: 'invite',
            sourceDetail: `${totalInvites}`,
            status: 'unlocked',
            unlockedAt: now,
          });
          tierReached = tier.tier;
          rewards = {
            tier: tier.tier,
            items: JSON.parse(tier.rewardsJson),
          };
        }
      }
    }

    return {
      inviterDeviceId,
      tierReached,
      rewards,
    };
  }

  // 邀请统计
  async getInviteStats(deviceId: string) {
    const db = this.dbService.getDb();

    // 累计邀请数
    const countResult = await db.select({ value: count() })
      .from(inviteRecords)
      .where(eq(inviteRecords.inviterDeviceId, deviceId));
    const totalInvites = countResult[0]?.value || 0;

    // 当前阶梯
    const tiers = await db.query.rewardTiers.findMany({
      where: eq(rewardTiers.isActive, 1),
    });
    const sortedTiers = tiers.sort((a, b) => a.tier - b.tier);

    let currentTier = 0;
    let nextTier: any = null;

    for (const tier of sortedTiers) {
      if (totalInvites >= tier.requiredInvites) {
        currentTier = tier.tier;
      } else if (!nextTier) {
        nextTier = {
          tier: tier.tier,
          requiredInvites: tier.requiredInvites,
          rewards: JSON.parse(tier.rewardsJson),
        };
      }
    }

    // 已解锁的奖励
    const unlockedRewards = await db.query.rewardUnlocks.findMany({
      where: and(
        eq(rewardUnlocks.deviceId, deviceId),
        eq(rewardUnlocks.source, 'invite'),
      ),
    });

    const rewardsWithItems = unlockedRewards.map((r) => {
      const tier = sortedTiers.find((t) => t.tier === r.tier);
      return {
        id: r.id,
        tier: r.tier,
        source: r.source,
        status: r.status,
        rewardItems: tier ? JSON.parse(tier.rewardsJson) : [],
        unlockedAt: r.unlockedAt,
        claimedAt: r.claimedAt,
      };
    });

    // 我的邀请码
    const me = await db.query.devices.findFirst({
      where: eq(devices.deviceId, deviceId),
    });
    const myInviteCode = me?.inviteCode ?? null;

    // 全量活动阶梯 + done/locked 状态（供前端动态渲染）
    const tierProgress = sortedTiers.map((t) => {
      const done = totalInvites >= t.requiredInvites;
      const isNext = nextTier && nextTier.tier === t.tier;
      return {
        tier: t.tier,
        requiredInvites: t.requiredInvites,
        rewards: JSON.parse(t.rewardsJson),
        done,
        locked: !done && !isNext,
      };
    });

    // 被邀请人真实记录（作为邀请人的邀请）
    const inviteesRows = await db.query.inviteRecords.findMany({
      where: eq(inviteRecords.inviterDeviceId, deviceId),
      orderBy: desc(inviteRecords.activatedAt),
    });
    const invitees = inviteesRows.map((r) => ({
      inviteeDeviceId: r.inviteeDeviceId,
      channel: r.channel,
      activatedAt: r.activatedAt,
    }));

    return {
      totalInvites,
      currentTier,
      nextTier,
      myInviteCode,
      tiers: tierProgress,
      invitees,
      unlockedRewards: rewardsWithItems,
    };
  }
}
