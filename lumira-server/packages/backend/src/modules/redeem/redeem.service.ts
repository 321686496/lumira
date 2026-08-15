// lumira-server/packages/backend/src/modules/redeem/redeem.service.ts

import { Injectable, NotFoundException, ConflictException, BadRequestException } from '@nestjs/common';
import { eq, and } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import {
  redemptionCodes,
  redemptionCodeBatches,
  redemptionRecords,
  ownedTemplates,
  templates,
  userPoints,
  pointTransactions,
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

    // 6. 检查设备是否已用过此码
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

    // 8. 解析批次奖励配置
    const rewardTemplatesList: string[] = JSON.parse(batch.rewardTemplates || '[]');
    const rewardPoints = batch.rewardPoints;

    // 9. 查询奖励模板名称（在事务前执行 read）
    let templateNames: Map<string, string> = new Map();
    if (rewardTemplatesList.length > 0) {
      const templateRows = await db.select({
        id: templates.id,
        name: templates.name,
      })
        .from(templates)
        .where(and(...rewardTemplatesList.map((tid) => eq(templates.id, tid))));
      templateNames = new Map(templateRows.map((t) => [t.id, t.name]));
    }

    // 10-13. 事务写入：所有写操作必须原子化
    await db.transaction(async (tx) => {
      // 10. 增加码使用次数
      await tx.update(redemptionCodes)
        .set({ usedCount: codeRecord.usedCount + 1 })
        .where(eq(redemptionCodes.code, code));

      // 11. 更新批次总使用量
      await tx.update(redemptionCodeBatches)
        .set({ totalUsed: batch.totalUsed + 1 })
        .where(eq(redemptionCodeBatches.batchId, batch.batchId));

      // 12. 写入兑换记录
      await tx.insert(redemptionRecords).values({
        code,
        deviceId,
        redeemedAt: now,
        ipAddress: ip,
      });

      // 13. 发放积分（直接操作 userPoints 和 pointTransactions）
      if (rewardPoints > 0) {
        const existingPoints = await tx.select().from(userPoints).where(eq(userPoints.deviceId, deviceId)) as Array<{
          deviceId: string;
          balance: number;
          totalEarned: number;
          totalSpent: number;
          updatedAt: number;
        }>;
        await tx.insert(pointTransactions).values({
          deviceId,
          delta: rewardPoints,
          type: 'redeem_code',
          refId: code,
          createdAt: now,
        });
        if (existingPoints.length > 0) {
          await tx.update(userPoints)
            .set({
              balance: existingPoints[0].balance + rewardPoints,
              totalEarned: existingPoints[0].totalEarned + rewardPoints,
              updatedAt: now,
            })
            .where(eq(userPoints.deviceId, deviceId));
        } else {
          await tx.insert(userPoints).values({
            deviceId,
            balance: rewardPoints,
            totalEarned: rewardPoints,
            totalSpent: 0,
            updatedAt: now,
          });
        }
      }

      // 14. 发放模板所有权
      for (const templateId of rewardTemplatesList) {
        const existing = await tx.select({ id: ownedTemplates.id })
          .from(ownedTemplates)
          .where(and(
            eq(ownedTemplates.deviceId, deviceId),
            eq(ownedTemplates.templateId, templateId),
          ));
        if (existing.length === 0) {
          await tx.insert(ownedTemplates).values({
            deviceId,
            templateId,
            source: 'redemption',
            sourceDetail: code,
            unlockedAt: now,
          });
        }
      }
    });

    // 15. 查询当前积分余额
    const balanceRows = await db.select({ balance: userPoints.balance })
      .from(userPoints)
      .where(eq(userPoints.deviceId, deviceId));
    const balance = balanceRows[0]?.balance ?? 0;
    const rewardTemplateInfo = rewardTemplatesList.map((tid) => ({
      templateId: tid,
      templateName: templateNames.get(tid) ?? '未知模板',
    }));

    return {
      batchId: batch.batchId,
      campaignName: batch.campaignName,
      rewardPoints,
      balance,
      rewardTemplates: rewardTemplateInfo,
    };
  }
}
