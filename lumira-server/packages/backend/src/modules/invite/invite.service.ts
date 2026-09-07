// lumira-server/packages/backend/src/modules/invite/invite.service.ts

import { Injectable, BadRequestException, ConflictException } from '@nestjs/common';
import { eq, and, count, desc, gte } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { devices, inviteRecords, rewardTiers, rewardUnlocks, userPoints } from '../../database/schema';
import { generateInviteCode } from '../../shared/invite-code.generator';
import { PointsService } from '../points/points.service';
import { getUtc8DayStart } from '../../common/utils/date.util';

// 邀请即时奖励：达成后（新用户首次成片）双方各 +30 积分；邀请人每日上限 3 次（90 分/天）
const INVITE_INSTANT_POINTS = 30;
const INVITE_DAILY_LIMIT = 3;

// 邀请绑定窗口：仅设备「首次注册后的短时间内」允许绑定邀请码（即新用户定义）。
// 超过该窗口视为老用户，禁止再绑定，防止老用户互刷/复用（违背裂变初衷）。
const INVITE_BIND_WINDOW_SECONDS = 24 * 60 * 60; // 24h

// 邀请达成条件文案：新用户绑定后需首次完成拍照/成片，邀请才成立、奖励才发放
const INVITE_CONDITION_TEXT =
  '绑定成功后，完成首次拍照/成片，你和好友即可各得 30 积分奖励';

// 里程碑奖励 item 结构
interface MilestoneRewardItem {
  type: string; // 'points' | 'unlock_count' | 'achievement'
  value?: number;
  id?: string;
  label?: string;
}

@Injectable()
export class InviteService {
  constructor(
    private readonly dbService: DatabaseService,
    private readonly pointsService: PointsService,
  ) {}

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

  // 激活邀请：仅建立「待达成（pending）」的绑定关系，不发奖励。
  // 奖励与计数延后到新用户首次成片（completeInvite）成立后发放。
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

    // 3. 新用户门槛：仅设备首次注册后的绑定窗口内允许绑定邀请码。
    const inviteeDevice = await db.query.devices.findFirst({
      where: eq(devices.deviceId, inviteeDeviceId),
    });
    if (inviteeDevice && now - inviteeDevice.firstSeenAt > INVITE_BIND_WINDOW_SECONDS) {
      throw new BadRequestException('仅限新用户首次使用时可绑定邀请码');
    }

    // 4. 检查被邀请人是否已绑定过（含 pending 与 success）
    const existingActivation = await db.query.inviteRecords.findFirst({
      where: eq(inviteRecords.inviteeDeviceId, inviteeDeviceId),
    });
    if (existingActivation) {
      throw new ConflictException('This device has already activated an invite');
    }

    // Anti-fraud check 5: 2-cycle detection (A→B then B→A).
    const reverseRecord = await db.query.inviteRecords.findFirst({
      where: and(
        eq(inviteRecords.inviterDeviceId, inviteeDeviceId),
        eq(inviteRecords.inviteeDeviceId, inviterDeviceId),
      ),
    });
    if (reverseRecord) {
      throw new BadRequestException('Invite cycle detected');
    }

    // 6. 写入「待达成」绑定记录（不发放任何奖励）
    await db.insert(inviteRecords).values({
      inviterDeviceId,
      inviteeDeviceId,
      inviteCode,
      channel,
      activatedAt: now,
      status: 'pending',
      achievedAt: null,
      inviterIp: null,
      inviteeIp,
    });

    return {
      inviterDeviceId,
      status: 'pending',
      tierReached: null,
      rewards: null,
      condition: INVITE_CONDITION_TEXT,
      // 达成后可获得的奖励（被邀请人视角，供绑定成功弹窗展示）
      achievableRewards: [
        { type: 'points', value: INVITE_INSTANT_POINTS, label: '邀请奖励' },
      ],
    };
  }

  // 新用户首次完成拍照/成片后，由前端调用：将 pending 关系置为 success，
  // 此时邀请成立，发放双方即时积分 + 邀请人里程碑奖励。
  // 幂等：未绑定返回 status:'none'；已达成返回 status:'success' 且 alreadyAchieved=true。
  async completeInvite(inviteeDeviceId: string) {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    const rec = await db.query.inviteRecords.findFirst({
      where: eq(inviteRecords.inviteeDeviceId, inviteeDeviceId),
    });
    if (!rec) {
      return { status: 'none', achievedAt: null };
    }
    // 幂等：已达成直接返回，不重复发奖
    if (rec.status === 'success') {
      return {
        status: 'success',
        alreadyAchieved: true,
        achievedAt: rec.achievedAt,
        inviterDeviceId: rec.inviterDeviceId,
      };
    }

    // 置为 success
    await db.update(inviteRecords)
      .set({ status: 'success', achievedAt: now })
      .where(eq(inviteRecords.inviteeDeviceId, inviteeDeviceId));

    const inviterDeviceId = rec.inviterDeviceId;

    // 发放即时积分：邀请人受每日上限（按当天成功数）；被邀请人达成即给。
    let inviterInstantGranted = false;
    try {
      const todayCount = await db.select({ value: count() })
        .from(inviteRecords)
        .where(and(
          eq(inviteRecords.inviterDeviceId, inviterDeviceId),
          eq(inviteRecords.status, 'success'),
          gte(inviteRecords.achievedAt, getUtc8DayStart()),
        ));
      const todayInvites = todayCount[0]?.value || 0;
      if (todayInvites <= INVITE_DAILY_LIMIT) {
        await this.pointsService.earnPoints(
          inviterDeviceId, INVITE_INSTANT_POINTS, 'invite', inviteeDeviceId,
        );
        inviterInstantGranted = true;
      }
      await this.pointsService.earnPoints(
        inviteeDeviceId, INVITE_INSTANT_POINTS, 'invite', inviterDeviceId,
      );
    } catch (e) {
      console.error('[invite] complete instant points failed', e);
    }

    // 邀请人累计成功邀请数 → 里程碑奖励（一次性：积分 + 免费解锁 + 成就）
    const successCount = await db.select({ value: count() })
      .from(inviteRecords)
      .where(and(
        eq(inviteRecords.inviterDeviceId, inviterDeviceId),
        eq(inviteRecords.status, 'success'),
      ));
    const totalInvites = successCount[0]?.value || 0;

    let tierReached: number | null = null;
    let rewards: any = null;

    const tiers = await db.query.rewardTiers.findMany({
      where: eq(rewardTiers.isActive, 1),
    });

    for (const tier of tiers.sort((a, b) => a.tier - b.tier)) {
      if (totalInvites >= tier.requiredInvites) {
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

          const items = JSON.parse(tier.rewardsJson) as MilestoneRewardItem[];
          try {
            for (const item of items) {
              if (item.type === 'points' && item.value) {
                await this.pointsService.earnPoints(
                  inviterDeviceId, item.value, 'invite', `tier:${tier.tier}`,
                );
              } else if (item.type === 'unlock_count' && item.value) {
                await this.pointsService.earnFreeUnlocks(
                  inviterDeviceId, item.value, `tier:${tier.tier}`,
                );
              }
            }
          } catch (e) {
            console.error('[invite] milestone rewards failed', e);
          }

          tierReached = tier.tier;
          rewards = {
            tier: tier.tier,
            items,
          };
        }
      }
    }

    return {
      status: 'success',
      alreadyAchieved: false,
      achievedAt: now,
      inviterDeviceId,
      inviterInstantGranted,
      // 被邀请人本次实际获得的奖励
      myRewards: [
        { type: 'points', value: INVITE_INSTANT_POINTS, label: '邀请奖励' },
      ],
      tierReached,
      rewards,
    };
  }

  // 邀请统计：仅「已达成（success）」计入邀请数与阶梯；同时返回待达成数与我的绑定信息。
  async getInviteStats(deviceId: string) {
    const db = this.dbService.getDb();

    // 累计成功邀请数 + 待达成数
    const successCount = await db.select({ value: count() })
      .from(inviteRecords)
      .where(and(
        eq(inviteRecords.inviterDeviceId, deviceId),
        eq(inviteRecords.status, 'success'),
      ));
    const pendingCount = await db.select({ value: count() })
      .from(inviteRecords)
      .where(and(
        eq(inviteRecords.inviterDeviceId, deviceId),
        eq(inviteRecords.status, 'pending'),
      ));
    const totalInvites = successCount[0]?.value || 0;

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

    // 被邀请人真实记录（作为邀请人的邀请），含达成状态
    const inviteesRows = await db.query.inviteRecords.findMany({
      where: eq(inviteRecords.inviterDeviceId, deviceId),
      orderBy: desc(inviteRecords.activatedAt),
    });
    const invitees = inviteesRows.map((r) => ({
      inviteeDeviceId: r.inviteeDeviceId,
      channel: r.channel,
      activatedAt: r.activatedAt,
      status: r.status,
      achievedAt: r.achievedAt,
    }));

    // 我的绑定信息（我被谁邀请）
    const myInviterRow = await db.query.inviteRecords.findFirst({
      where: eq(inviteRecords.inviteeDeviceId, deviceId),
    });
    const myInviter = myInviterRow
      ? {
          inviterDeviceId: myInviterRow.inviterDeviceId,
          inviteCode: myInviterRow.inviteCode,
          channel: myInviterRow.channel,
          activatedAt: myInviterRow.activatedAt,
          status: myInviterRow.status,
          achievedAt: myInviterRow.achievedAt,
        }
      : null;

    // 免费解锁次数 + 今日成功邀请与剩余可领积分邀请数（按当天成功数）
    const pointsRows = await db.select({ freeUnlockCount: userPoints.freeUnlockCount })
      .from(userPoints)
      .where(eq(userPoints.deviceId, deviceId));
    const freeUnlockCount = pointsRows[0]?.freeUnlockCount ?? 0;

    const todayInvites = await db.select({ value: count() })
      .from(inviteRecords)
      .where(and(
        eq(inviteRecords.inviterDeviceId, deviceId),
        eq(inviteRecords.status, 'success'),
        gte(inviteRecords.achievedAt, getUtc8DayStart()),
      ));
    const todayInviteCount = todayInvites[0]?.value || 0;
    const dailyInvitePointsLeft = Math.max(0, INVITE_DAILY_LIMIT - todayInviteCount);

    return {
      totalInvites,
      pendingInvites: pendingCount,
      currentTier,
      nextTier,
      myInviteCode,
      tiers: tierProgress,
      invitees,
      unlockedRewards: rewardsWithItems,
      freeUnlockCount,
      todayInviteCount,
      dailyInvitePointsLeft,
      myInviter,
      condition: INVITE_CONDITION_TEXT,
    };
  }
}