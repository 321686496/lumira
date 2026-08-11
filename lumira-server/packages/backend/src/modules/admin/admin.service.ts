import { Injectable, NotFoundException } from '@nestjs/common';
import { eq, count, desc, asc, sql } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import {
  devices,
  inviteRecords,
  rewardUnlocks,
  redemptionCodeBatches,
  redemptionCodes,
  redemptionRecords,
  questionnaireRecords,
  templates,
} from '../../database/schema';

@Injectable()
export class AdminService {
  constructor(private readonly dbService: DatabaseService) {}

  async getStats() {
    const db = this.dbService.getDb();

    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    const todayTs = Math.floor(todayStart.getTime() / 1000);

    const [deviceCount] = await db.select({ value: count() }).from(devices);
    const [inviteCount] = await db.select({ value: count() }).from(inviteRecords);
    const [rewardCount] = await db.select({ value: count() }).from(rewardUnlocks);
    const [redemptionCount] = await db.select({ value: count() }).from(redemptionRecords);

    const [todayNewDevicesRow] = await db.select({ value: count() }).from(devices)
      .where(sql`${devices.firstSeenAt} >= ${todayTs}`);
    const [todayNewInvitesRow] = await db.select({ value: count() }).from(inviteRecords)
      .where(sql`${inviteRecords.activatedAt} >= ${todayTs}`);
    const [todayRedeemedRow] = await db.select({ value: count() }).from(redemptionRecords)
      .where(sql`${redemptionRecords.redeemedAt} >= ${todayTs}`);

    const [codesRow] = await db.select({
      generated: sql<number>`COALESCE(SUM(${redemptionCodeBatches.totalGenerated}), 0)`,
      used: sql<number>`COALESCE(SUM(${redemptionCodeBatches.totalUsed}), 0)`,
    }).from(redemptionCodeBatches);

    const totalGenerated = codesRow?.generated || 0;
    const totalUsed = codesRow?.used || 0;

    return {
      totalDevices: deviceCount?.value || 0,
      todayNewDevices: todayNewDevicesRow?.value || 0,
      totalInvites: inviteCount?.value || 0,
      todayNewInvites: todayNewInvitesRow?.value || 0,
      totalRedemptions: redemptionCount?.value || 0,
      todayRedeemed: todayRedeemedRow?.value || 0,
      totalRewardUnlocks: rewardCount?.value || 0,
      totalCodesGenerated: totalGenerated,
      totalCodesUsed: totalUsed,
      totalCodesRemaining: totalGenerated - totalUsed,
    };
  }

  async getDeviceList(page: number = 1, pageSize: number = 20, search?: string) {
    const db = this.dbService.getDb();

    let query = db.select().from(devices).$dynamic();

    if (search) {
      const pattern = `%${search}%`;
      query = query.where(
        sql`(${devices.deviceId} LIKE ${pattern} OR ${devices.alias} LIKE ${pattern} OR ${devices.platform} LIKE ${pattern} OR ${devices.deviceModel} LIKE ${pattern})`
      );
    }

    const offset = (page - 1) * pageSize;
    const records = await query.orderBy(desc(devices.firstSeenAt)).limit(pageSize).offset(offset);

    const totalCount = search
      ? await db.select({ value: count() }).from(devices).where(
          sql`(${devices.deviceId} LIKE ${`%${search}%`} OR ${devices.alias} LIKE ${`%${search}%`} OR ${devices.platform} LIKE ${`%${search}%`} OR ${devices.deviceModel} LIKE ${`%${search}%`})`
        )
      : await db.select({ value: count() }).from(devices);

    return {
      data: records,
      total: totalCount[0]?.value || 0,
      page,
      pageSize,
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
    const totalCount = deviceId
      ? await db.select({ value: count() }).from(inviteRecords).where(eq(inviteRecords.inviterDeviceId, deviceId))
      : await db.select({ value: count() }).from(inviteRecords);

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
    rewardPoints: number;
    rewardTemplates?: string[];
    maxUsesPerCode: number;
    validFrom?: number;
    validUntil?: number;
  }) {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    return db.transaction((tx) => {
      const result = tx.insert(redemptionCodeBatches).values({
        campaignName: dto.campaignName,
        rewardPoints: dto.rewardPoints,
        rewardTemplates: JSON.stringify(dto.rewardTemplates ?? []),
        maxUsesPerCode: dto.maxUsesPerCode,
        totalGenerated: dto.codes.length,
        totalUsed: 0,
        validFrom: dto.validFrom || null,
        validUntil: dto.validUntil || null,
        isActive: 1,
        createdAt: now,
      }).returning().all();

      const batchId = result[0].batchId;

      const codeValues = dto.codes.map(code => ({
        code,
        batchId,
        usedCount: 0,
        maxUses: dto.maxUsesPerCode,
      }));

      tx.insert(redemptionCodes).values(codeValues).run();

      return {
        batchId,
        campaignName: dto.campaignName,
        totalGenerated: dto.codes.length,
        rewardPoints: dto.rewardPoints,
        rewardTemplates: dto.rewardTemplates ?? [],
      };
    });
  }

  // 兑换码批次列表
  async getBatches() {
    const db = this.dbService.getDb();
    const rows = await db.select().from(redemptionCodeBatches).orderBy(desc(redemptionCodeBatches.createdAt));
    return rows.map((b) => ({
      ...b,
      rewardTemplates: b.rewardTemplates,
    }));
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
    const updated = await db.update(redemptionCodeBatches)
      .set({ isActive: isActive ? 1 : 0 })
      .where(eq(redemptionCodeBatches.batchId, batchId))
      .returning();
    if (updated.length === 0) {
      throw new NotFoundException('Batch not found');
    }
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
    const totalCount = deviceId
      ? await db.select({ value: count() }).from(rewardUnlocks).where(eq(rewardUnlocks.deviceId, deviceId))
      : await db.select({ value: count() }).from(rewardUnlocks);

    return {
      data: records,
      total: totalCount[0]?.value || 0,
      page,
      pageSize,
    };
  }

  // 查询所有活跃模板（用于 Admin 批次表单选择）
  async getAllActiveTemplates() {
    const db = this.dbService.getDb();
    return db.select({
      id: templates.id,
      name: templates.name,
      price: templates.price,
      coverUrl: templates.coverUrl,
    })
      .from(templates)
      .where(eq(templates.isActive, 1))
      .orderBy(asc(templates.sortOrder));
  }

  // 问卷列表（每设备最新一条）
  async getQuestionnaireList(page: number = 1, pageSize: number = 20, deviceId?: string) {
    const db = this.dbService.getDb();

    // 子查询：每设备最新一条记录的 id
    const latestSubquery = db
      .select({
        id: sql<number>`MAX(${questionnaireRecords.id})`.as('max_id'),
      })
      .from(questionnaireRecords)
      .groupBy(questionnaireRecords.deviceId)
      .as('latest');

    const offset = (page - 1) * pageSize;

    // 主查询：JOIN devices 取 alias，JOIN 子查询取每设备最新
    const rows = await db
      .select({
        id: questionnaireRecords.id,
        deviceId: questionnaireRecords.deviceId,
        answersJson: questionnaireRecords.answersJson,
        submittedAt: questionnaireRecords.submittedAt,
        clientIp: questionnaireRecords.clientIp,
        deviceAlias: devices.alias,
      })
      .from(questionnaireRecords)
      .innerJoin(latestSubquery, eq(questionnaireRecords.id, latestSubquery.id))
      .leftJoin(devices, eq(questionnaireRecords.deviceId, devices.deviceId))
      .where(deviceId ? eq(questionnaireRecords.deviceId, deviceId) : undefined)
      .orderBy(desc(questionnaireRecords.submittedAt))
      .limit(pageSize)
      .offset(offset);

    const totalCount = deviceId
      ? await db.select({ value: count() }).from(questionnaireRecords).where(eq(questionnaireRecords.deviceId, deviceId))
      : await db.select({ value: sql<number>`COUNT(DISTINCT ${questionnaireRecords.deviceId})` }).from(questionnaireRecords);

    return {
      data: rows,
      total: totalCount[0]?.value || 0,
      page,
      pageSize,
    };
  }

  // 单设备问卷历史
  async getQuestionnaireHistory(deviceId: string) {
    const db = this.dbService.getDb();
    const rows = await db
      .select()
      .from(questionnaireRecords)
      .where(eq(questionnaireRecords.deviceId, deviceId))
      .orderBy(desc(questionnaireRecords.submittedAt));

    return {
      data: rows,
      total: rows.length,
    };
  }

  // 问卷聚合统计（基于每设备最新一条）
  async getQuestionnaireStats() {
    const db = this.dbService.getDb();

    const latestSubquery = db
      .select({
        id: sql<number>`MAX(${questionnaireRecords.id})`.as('max_id'),
      })
      .from(questionnaireRecords)
      .groupBy(questionnaireRecords.deviceId)
      .as('latest');

    const rows = await db
      .select({
        answersJson: questionnaireRecords.answersJson,
      })
      .from(questionnaireRecords)
      .innerJoin(latestSubquery, eq(questionnaireRecords.id, latestSubquery.id));

    const stats = {
      totalRespondents: rows.length,
      source: {} as Record<string, number>,
      favorite_categories: {} as Record<string, number>,
      pain_points: {} as Record<string, number>,
      skill_level: {} as Record<string, number>,
      expectations: {} as Record<string, number>,
      common_scenes: {} as Record<string, number>,
      shoot_frequency: {} as Record<string, number>,
    };

    for (const row of rows) {
      try {
        const answers = JSON.parse(row.answersJson) as Record<string, unknown>;
        for (const [key, value] of Object.entries(answers)) {
          if (!stats.hasOwnProperty(key)) continue;
          if (value === null) continue;
          if (Array.isArray(value)) {
            for (const v of value as string[]) {
              stats[key as keyof typeof stats][v] = (stats[key as keyof typeof stats][v] || 0) + 1;
            }
          } else {
            const v = value as string;
            stats[key as keyof typeof stats][v] = (stats[key as keyof typeof stats][v] || 0) + 1;
          }
        }
      } catch {
        // 跳过无法解析的记录
      }
    }

    return stats;
  }
}