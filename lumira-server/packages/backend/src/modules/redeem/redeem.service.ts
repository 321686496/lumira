// lumira-server/packages/backend/src/modules/redeem/redeem.service.ts

import { Injectable, NotFoundException, ConflictException, BadRequestException } from '@nestjs/common';
import { eq, and } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import {
  redemptionCodes,
  redemptionCodeBatches,
  redemptionRecords,
  rewardUnlocks,
  rewardTiers,
} from '../../database/schema';

@Injectable()
export class RedeemService {
  constructor(private readonly dbService: DatabaseService) {}

  async redeem(deviceId: string, code: string, ip: string) {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    // 1. 查找码
    const codeRecord = await db.query.redemptionCodes.findFirst({
      where: eq(redemptionCodes.code, code),
    });
    if (!codeRecord) {
      throw new NotFoundException('Code not found');
    }

    // 2. 查找批次
    const batch = await db.query.redemptionCodeBatches.findFirst({
      where: eq(redemptionCodeBatches.batchId, codeRecord.batchId),
    });
    if (!batch) {
      throw new NotFoundException('Batch not found');
    }

    // 3. 检查批次是否激活
    if (!batch.isActive) {
      throw new BadRequestException('This code batch is disabled');
    }

    // 4. 检查有效期
    if (batch.validFrom && now < batch.validFrom) {
      throw new BadRequestException('Code is not yet valid');
    }
    if (batch.validUntil && now > batch.validUntil) {
      throw new BadRequestException('Code has expired');
    }

    // 5. 检查使用次数
    if (codeRecord.usedCount >= codeRecord.maxUses) {
      throw new ConflictException('Code usage limit reached');
    }

    // 6. 检查该设备是否已用过此码
    const existingRedemption = await db.query.redemptionRecords.findFirst({
      where: and(
        eq(redemptionRecords.code, code),
        eq(redemptionRecords.deviceId, deviceId),
      ),
    });
    if (existingRedemption) {
      throw new ConflictException('This device has already redeemed this code');
    }

    // 7. 检查单设备当日兑换次数（防刷：每日 3 次）
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    const todayStartTs = Math.floor(todayStart.getTime() / 1000);

    const todayRedemptions = await db.query.redemptionRecords.findMany({
      where: and(
        eq(redemptionRecords.deviceId, deviceId),
      ),
    });
    const todayCount = todayRedemptions.filter(r => r.redeemedAt >= todayStartTs).length;
    if (todayCount >= 3) {
      throw new ConflictException('Daily redemption limit reached');
    }

    // 8. 原子操作：增加使用次数
    await db.update(redemptionCodes)
      .set({ usedCount: codeRecord.usedCount + 1 })
      .where(eq(redemptionCodes.code, code));

    // 9. 更新批次总使用量
    await db.update(redemptionCodeBatches)
      .set({ totalUsed: batch.totalUsed + 1 })
      .where(eq(redemptionCodeBatches.batchId, batch.batchId));

    // 10. 写入兑换记录
    await db.insert(redemptionRecords).values({
      code,
      deviceId,
      redeemedAt: now,
      ipAddress: ip,
    });

    // 11. 解锁奖励
    const tier = await db.query.rewardTiers.findFirst({
      where: eq(rewardTiers.tier, batch.rewardTier),
    });

    await db.insert(rewardUnlocks).values({
      deviceId,
      tier: batch.rewardTier,
      source: 'redemption',
      sourceDetail: code,
      status: 'unlocked',
      unlockedAt: now,
    });

    return {
      batchId: batch.batchId,
      campaignName: batch.campaignName,
      rewardTier: batch.rewardTier,
      rewardItems: tier ? JSON.parse(tier.rewardsJson) : [],
    };
  }
}
