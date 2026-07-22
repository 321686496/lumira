// lumira-server/packages/backend/src/modules/invite/invite.service.ts

import { Injectable, BadRequestException, ConflictException } from '@nestjs/common';
import { eq, and, count } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { devices, inviteRecords, rewardTiers, rewardUnlocks } from '../../database/schema';
import { generateInviteCode } from '../../shared/invite-code.generator';

@Injectable()
export class InviteService {
  constructor(private readonly dbService: DatabaseService) {}

  // 生成或获取已有邀请码
  async generateInviteCode(deviceId: string): Promise<string> {
    const db = this.dbService.getDb();

    const device = await db.query.devices.findFirst({
      where: eq(devices.deviceId, deviceId),
    });

    // 从 ip_region 字段读取已有邀请码（约定格式：invite:XXXXXX）
    // 这是 MVP 简化方案 — 复用 devices.ip_region 字段存储邀请码
    const existingCode = device?.ipRegion?.startsWith('invite:')
      ? device.ipRegion.substring(7)
      : null;

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

    // 存储邀请码到 devices.ip_region 字段（加前缀区分）
    await db.update(devices)
      .set({ ipRegion: `invite:${code}` })
      .where(eq(devices.deviceId, deviceId));

    return code;
  }

  private async inviteCodeExists(code: string): Promise<boolean> {
    const db = this.dbService.getDb();
    const result = await db.query.devices.findFirst({
      where: eq(devices.ipRegion, `invite:${code}`),
    });
    return !!result;
  }

  // 通过邀请码找到邀请人设备
  async findInviterByCode(code: string): Promise<string | null> {
    const db = this.dbService.getDb();
    const result = await db.query.devices.findFirst({
      where: eq(devices.ipRegion, `invite:${code}`),
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

    return {
      totalInvites,
      currentTier,
      nextTier,
      unlockedRewards: rewardsWithItems,
    };
  }
}
