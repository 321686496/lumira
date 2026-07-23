// lumira-server/packages/backend/src/modules/admin/admin.service.ts

import { Injectable } from '@nestjs/common';
import { eq, count, desc } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import {
  devices,
  inviteRecords,
  rewardUnlocks,
  redemptionCodeBatches,
  redemptionCodes,
  redemptionRecords,
} from '../../database/schema';

@Injectable()
export class AdminService {
  constructor(private readonly dbService: DatabaseService) {}

  // 概览统计
  async getStats() {
    const db = this.dbService.getDb();

    const deviceCount = await db.select({ value: count() }).from(devices);
    const inviteCount = await db.select({ value: count() }).from(inviteRecords);
    const rewardCount = await db.select({ value: count() }).from(rewardUnlocks);
    const redemptionCount = await db.select({ value: count() }).from(redemptionRecords);

    // 今日数据
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    const todayTs = Math.floor(todayStart.getTime() / 1000);

    const todayDevices = await db.query.devices.findMany();
    const todayNewDevices = todayDevices.filter(d => d.firstSeenAt >= todayTs).length;

    const todayInvites = await db.query.inviteRecords.findMany();
    const todayNewInvites = todayInvites.filter(i => i.activatedAt >= todayTs).length;

    const todayRedemptions = await db.query.redemptionRecords.findMany();
    const todayRedeemed = todayRedemptions.filter(r => r.redeemedAt >= todayTs).length;

    // 兑换码统计
    const batches = await db.query.redemptionCodeBatches.findMany();
    const totalGenerated = batches.reduce((sum, b) => sum + b.totalGenerated, 0);
    const totalUsed = batches.reduce((sum, b) => sum + b.totalUsed, 0);

    return {
      totalDevices: deviceCount[0]?.value || 0,
      todayNewDevices,
      totalInvites: inviteCount[0]?.value || 0,
      todayNewInvites,
      totalRedemptions: redemptionCount[0]?.value || 0,
      todayRedeemed,
      totalRewardUnlocks: rewardCount[0]?.value || 0,
      totalCodesGenerated: totalGenerated,
      totalCodesUsed: totalUsed,
      totalCodesRemaining: totalGenerated - totalUsed,
    };
  }

  // 邀请记录查询
  async getInviteRecords(page: number = 1, pageSize: number = 20, deviceId?: string) {
    const db = this.dbService.getDb();

    let query = db.select().from(inviteRecords).$dynamic();

    if (deviceId) {
      query = query.where(eq(inviteRecords.inviterDeviceId, deviceId));
    }

    const offset = (page - 1) * pageSize;
    const records = await query.orderBy(desc(inviteRecords.activatedAt)).limit(pageSize).offset(offset);
    const totalCount = await db.select({ value: count() }).from(inviteRecords);

    return {
      data: records,
      total: totalCount[0]?.value || 0,
      page,
      pageSize,
    };
  }

  // 创建兑换码批次
  async createBatch(dto: {
    campaignName: string;
    codes: string[];
    rewardTier: number;
    maxUsesPerCode: number;
    validFrom?: number;
    validUntil?: number;
  }) {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    // 创建批次
    const result = await db.insert(redemptionCodeBatches).values({
      campaignName: dto.campaignName,
      rewardTier: dto.rewardTier,
      maxUsesPerCode: dto.maxUsesPerCode,
      totalGenerated: dto.codes.length,
      totalUsed: 0,
      validFrom: dto.validFrom || null,
      validUntil: dto.validUntil || null,
      isActive: 1,
      createdAt: now,
    }).returning();

    const batchId = result[0].batchId;

    // 批量插入码
    const codeValues = dto.codes.map(code => ({
      code,
      batchId,
      usedCount: 0,
      maxUses: dto.maxUsesPerCode,
    }));

    await db.insert(redemptionCodes).values(codeValues);

    return {
      batchId,
      campaignName: dto.campaignName,
      totalGenerated: dto.codes.length,
    };
  }

  // 兑换码批次列表
  async getBatches() {
    const db = this.dbService.getDb();
    return db.select().from(redemptionCodeBatches).orderBy(desc(redemptionCodeBatches.createdAt));
  }

  // 批次详情
  async getBatchDetail(batchId: number) {
    const db = this.dbService.getDb();

    const batch = await db.query.redemptionCodeBatches.findFirst({
      where: eq(redemptionCodeBatches.batchId, batchId),
    });

    if (!batch) {
      return null;
    }

    const codes = await db.query.redemptionCodes.findMany({
      where: eq(redemptionCodes.batchId, batchId),
    });

    return { ...batch, codes };
  }

  // 启用/禁用批次
  async toggleBatch(batchId: number, isActive: boolean) {
    const db = this.dbService.getDb();
    await db.update(redemptionCodeBatches)
      .set({ isActive: isActive ? 1 : 0 })
      .where(eq(redemptionCodeBatches.batchId, batchId));
    return { success: true };
  }

  // 奖励解锁记录
  async getRewardUnlocks(page: number = 1, pageSize: number = 20, deviceId?: string) {
    const db = this.dbService.getDb();

    let query = db.select().from(rewardUnlocks).$dynamic();

    if (deviceId) {
      query = query.where(eq(rewardUnlocks.deviceId, deviceId));
    }

    const offset = (page - 1) * pageSize;
    const records = await query.orderBy(desc(rewardUnlocks.unlockedAt)).limit(pageSize).offset(offset);
    const totalCount = await db.select({ value: count() }).from(rewardUnlocks);

    return {
      data: records,
      total: totalCount[0]?.value || 0,
      page,
      pageSize,
    };
  }
}
