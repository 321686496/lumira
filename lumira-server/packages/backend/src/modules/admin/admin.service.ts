import * as crypto from 'crypto';
import * as fs from 'fs';
import * as path from 'path';
import { BadRequestException, Injectable, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { and, eq, count, desc, asc, sql } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { PointsService } from '../points/points.service';
import {
  devices,
  userProfiles,
  userPoints,
  pointTransactions,
  inviteRecords,
  rewardUnlocks,
  redemptionCodeBatches,
  redemptionCodes,
  redemptionRecords,
  ownedTemplates,
  questionnaireRecords,
  templates,
  feedbacks,
  accountOtp,
  usageEvents,
  dailySignInRecords,
  pointEarnEvents,
} from '../../database/schema';

function parseArr(raw: string | null): string[] {
  if (!raw) return [];
  try {
    const v = JSON.parse(raw);
    return Array.isArray(v) ? v.filter((x) => typeof x === 'string') : [];
  } catch {
    return [];
  }
}

function safeUploadPath(uploadRoot: string, segments: string[]): string | null {
  const target = path.resolve(uploadRoot, ...segments);
  const normalizedRoot = `${path.resolve(uploadRoot)}${path.sep}`;
  return target.startsWith(normalizedRoot) ? target : null;
}

function removeUploadDirs(uploadRoot: string, directories: string[][]): void {
  for (const segments of directories) {
    const target = safeUploadPath(uploadRoot, segments);
    if (!target) continue;
    fs.rmSync(target, { recursive: true, force: true });
  }
}

function verifyLoginKey(input: string): void {
  const expected = process.env.ADMIN_TOKEN || 'dev-admin-token';
  const expectedBuffer = Buffer.from(expected, 'utf8');
  const inputBuffer = Buffer.from(input, 'utf8');
  const matches = inputBuffer.length === expectedBuffer.length
    && crypto.timingSafeEqual(inputBuffer, expectedBuffer);
  if (!matches) {
    throw new UnauthorizedException('登录 key 无效');
  }
}

@Injectable()
export class AdminService {
  constructor(
    private readonly dbService: DatabaseService,
    private readonly pointsService: PointsService,
  ) {}

  async getStats() {
    const db = this.dbService.getDb();

    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    const todayTs = Math.floor(todayStart.getTime() / 1000);

    // 时间口径：本月 1 日 0 点、近 30 天起点（均按服务器本地时区）
    const monthStart = new Date(todayStart);
    monthStart.setDate(1);
    const monthStartTs = Math.floor(monthStart.getTime() / 1000);
    const thirtyDaysAgoTs = todayTs - 30 * 86400;

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

    // ===== 活跃度（DAU / MAU / 本月注册）=====
    const [dauRow] = await db.select({ value: count() }).from(devices)
      .where(sql`${devices.lastSeenAt} >= ${todayTs}`);
    const [mauRow] = await db.select({ value: count() }).from(devices)
      .where(sql`${devices.lastSeenAt} >= ${thirtyDaysAgoTs}`);
    const [newMonthRow] = await db.select({ value: count() }).from(devices)
      .where(sql`${devices.firstSeenAt} >= ${monthStartTs}`);

    // ===== 平台分布 =====
    const platformRows = await db.select({
      platform: devices.platform,
      count: sql<number>`COUNT(*)`,
    }).from(devices)
      .groupBy(devices.platform)
      .orderBy(sql`COUNT(*) DESC`);
    const platformBreakdown = platformRows.map((r) => ({
      platform: r.platform || '未知',
      count: r.count || 0,
    }));

    // ===== 用户画像分布（从 user_profiles 聚合）=====
    const profileRows = await db.select({
      gender: userProfiles.gender,
      skillLevel: userProfiles.skillLevel,
      shootFrequency: userProfiles.shootFrequency,
    }).from(userProfiles);
    const profileBreakdown: Record<string, Record<string, number>> = {
      gender: {},
      skillLevel: {},
      shootFrequency: {},
    };
    for (const row of profileRows) {
      if (row.gender) profileBreakdown.gender[row.gender] = (profileBreakdown.gender[row.gender] || 0) + 1;
      if (row.skillLevel) profileBreakdown.skillLevel[row.skillLevel] = (profileBreakdown.skillLevel[row.skillLevel] || 0) + 1;
      if (row.shootFrequency) profileBreakdown.shootFrequency[row.shootFrequency] = (profileBreakdown.shootFrequency[row.shootFrequency] || 0) + 1;
    }

    // ===== 积分健康 =====
    const [pointsRow] = await db.select({
      earned: sql<number>`COALESCE(SUM(${userPoints.totalEarned}), 0)`,
      spent: sql<number>`COALESCE(SUM(${userPoints.totalSpent}), 0)`,
      balance: sql<number>`COALESCE(SUM(${userPoints.balance}), 0)`,
    }).from(userPoints);
    const [signInRow] = await db.select({ value: count() }).from(dailySignInRecords)
      .where(sql`${dailySignInRecords.createdAt} >= ${todayTs}`);
    const [pointEventRow] = await db.select({ value: count() }).from(pointEarnEvents)
      .where(sql`${pointEarnEvents.createdAt} >= ${todayTs}`);

    // ===== 内容健康度 =====
    const [templateRow] = await db.select({ value: count() }).from(templates);
    const [activeTemplateRow] = await db.select({ value: count() }).from(templates)
      .where(eq(templates.isActive, 1));
    const [paidTemplateRow] = await db.select({ value: count() }).from(templates)
      .where(sql`${templates.price} > 0`);
    const [pendingFeedbackRow] = await db.select({ value: count() }).from(feedbacks)
      .where(eq(feedbacks.status, 'pending'));
    const [successInviteRow] = await db.select({ value: count() }).from(inviteRecords)
      .where(eq(inviteRecords.status, 'success'));
    const [pendingInviteRow] = await db.select({ value: count() }).from(inviteRecords)
      .where(eq(inviteRecords.status, 'pending'));
    const [batchRow] = await db.select({ value: count() }).from(redemptionCodeBatches);

    const inviteTotal = (successInviteRow?.value || 0) + (pendingInviteRow?.value || 0);
    const inviteSuccessRate = inviteTotal > 0
      ? Math.round(((successInviteRow?.value || 0) / inviteTotal) * 100)
      : 0;

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
      // 活跃度
      dau: dauRow?.value || 0,
      mau: mauRow?.value || 0,
      newDevicesThisMonth: newMonthRow?.value || 0,
      // 平台分布
      platformBreakdown,
      // 用户画像
      profileBreakdown,
      // 积分健康
      totalPointsEarned: pointsRow?.earned || 0,
      totalPointsSpent: pointsRow?.spent || 0,
      totalPointsBalance: pointsRow?.balance || 0,
      todaySignIns: signInRow?.value || 0,
      todayPointEvents: pointEventRow?.value || 0,
      // 内容健康度
      totalTemplates: templateRow?.value || 0,
      activeTemplates: activeTemplateRow?.value || 0,
      paidTemplates: paidTemplateRow?.value || 0,
      pendingFeedbacks: pendingFeedbackRow?.value || 0,
      inviteSuccessRate,
      totalBatches: batchRow?.value || 0,
    };
  }

  // 近 N 日逐日趋势（7/30）：newDevices / dau / invites / redemptions / rewardUnlocks
  async getTrend(days: number = 7) {
    const db = this.dbService.getDb();
    const n = days === 30 ? 30 : 7;

    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    const todayTs = Math.floor(todayStart.getTime() / 1000);
    const startTs = todayTs - (n - 1) * 86400;

    const dayStarts: number[] = [];
    for (let i = 0; i < n; i++) dayStarts.push(startTs + i * 86400);

    const countBuckets = (stamps: number[]): number[] => {
      const out = new Array<number>(n).fill(0);
      for (const s of stamps) {
        const idx = Math.floor((s - startTs) / 86400);
        if (idx >= 0 && idx < n) out[idx]++;
      }
      return out;
    };

    const [newDeviceRows, dauRows, inviteRows, redemptionRows, rewardRows] = await Promise.all([
      db.select({ t: devices.firstSeenAt }).from(devices).where(sql`${devices.firstSeenAt} >= ${startTs}`),
      db.select({ t: devices.lastSeenAt }).from(devices).where(sql`${devices.lastSeenAt} >= ${startTs}`),
      db.select({ t: inviteRecords.activatedAt }).from(inviteRecords).where(sql`${inviteRecords.activatedAt} >= ${startTs}`),
      db.select({ t: redemptionRecords.redeemedAt }).from(redemptionRecords).where(sql`${redemptionRecords.redeemedAt} >= ${startTs}`),
      db.select({ t: rewardUnlocks.unlockedAt }).from(rewardUnlocks).where(sql`${rewardUnlocks.unlockedAt} >= ${startTs}`),
    ]);

    const newDevices = countBuckets(newDeviceRows.map((r) => r.t));
    const dau = countBuckets(dauRows.map((r) => r.t));
    const invites = countBuckets(inviteRows.map((r) => r.t));
    const redemptions = countBuckets(redemptionRows.map((r) => r.t));
    const rewardUnlockBuckets = countBuckets(rewardRows.map((r) => r.t));

    const daySeries = dayStarts.map((ds, i) => {
      const d = new Date(ds * 1000);
      const mm = String(d.getMonth() + 1).padStart(2, '0');
      const dd = String(d.getDate()).padStart(2, '0');
      return {
        date: `${mm}-${dd}`,
        newDevices: newDevices[i],
        dau: dau[i],
        invites: invites[i],
        redemptions: redemptions[i],
        rewardUnlocks: rewardUnlockBuckets[i],
      };
    });

    return { days: daySeries };
  }

  async getDeviceList(page: number = 1, pageSize: number = 20, search?: string) {
    const db = this.dbService.getDb();

    // 每个设备作为邀请人发起邀请的用户数（pending + success 都计入「邀请过的新用户」）
    const invitedSubquery = db
      .select({
        inviterDeviceId: inviteRecords.inviterDeviceId,
        invitedCount: sql<number>`COUNT(${inviteRecords.id})`.as('invitedCount'),
      })
      .from(inviteRecords)
      .groupBy(inviteRecords.inviterDeviceId)
      .as('invited_sub');

    let query = db
      .select({
        deviceId: devices.deviceId,
        alias: devices.alias,
        platform: devices.platform,
        osVersion: devices.osVersion,
        deviceModel: devices.deviceModel,
        appVersion: devices.appVersion,
        firstSeenAt: devices.firstSeenAt,
        lastSeenAt: devices.lastSeenAt,
        ipRegion: devices.ipRegion,
        username: userProfiles.username,
        avatarSeed: userProfiles.avatarSeed,
        // 个人资料（个人中心 + 问卷同步）
        gender: userProfiles.gender,
        favoriteCategoriesJson: userProfiles.favoriteCategoriesJson,
        painPointsJson: userProfiles.painPointsJson,
        skillLevel: userProfiles.skillLevel,
        expectationsJson: userProfiles.expectationsJson,
        commonScenesJson: userProfiles.commonScenesJson,
        shootFrequency: userProfiles.shootFrequency,
        avatarUrl: userProfiles.avatarUrl,
        profileUpdatedAt: userProfiles.updatedAt,
        pointsBalance: userPoints.balance,
        invitedCount: invitedSubquery.invitedCount,
      })
      .from(devices)
      .leftJoin(userProfiles, eq(devices.deviceId, userProfiles.deviceId))
      .leftJoin(userPoints, eq(devices.deviceId, userPoints.deviceId))
      .leftJoin(invitedSubquery, eq(devices.deviceId, invitedSubquery.inviterDeviceId))
      .$dynamic();

    if (search) {
      const pattern = `%${search}%`;
      query = query.where(
        sql`(${devices.deviceId} LIKE ${pattern} OR ${devices.alias} LIKE ${pattern} OR ${devices.platform} LIKE ${pattern} OR ${devices.deviceModel} LIKE ${pattern} OR ${userProfiles.username} LIKE ${pattern})`
      );
    }

    const offset = (page - 1) * pageSize;
    const records = await query.orderBy(desc(devices.firstSeenAt)).limit(pageSize).offset(offset);

    const totalCount = search
      ? await db.select({ value: count() }).from(devices)
          .leftJoin(userProfiles, eq(devices.deviceId, userProfiles.deviceId))
          .where(
            sql`(${devices.deviceId} LIKE ${`%${search}%`} OR ${devices.alias} LIKE ${`%${search}%`} OR ${devices.platform} LIKE ${`%${search}%`} OR ${devices.deviceModel} LIKE ${`%${search}%`} OR ${userProfiles.username} LIKE ${`%${search}%`})`
          )
      : await db.select({ value: count() }).from(devices);

    return {
      data: records.map((r) => ({
        ...r,
        invitedCount: (r.invitedCount as number | null) ?? 0,
        favoriteCategories: parseArr(r.favoriteCategoriesJson),
        painPoints: parseArr(r.painPointsJson),
        expectations: parseArr(r.expectationsJson),
        commonScenes: parseArr(r.commonScenesJson),
      })),
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

    return db.transaction(async (tx) => {
      const result = await tx.insert(redemptionCodeBatches).values({
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
      }).$returningId();

      const batchId = result[0].batchId;

      const codeValues = dto.codes.map(code => ({
        code,
        batchId,
        usedCount: 0,
        maxUses: dto.maxUsesPerCode,
      }));

      await tx.insert(redemptionCodes).values(codeValues);

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
    const existing = await db.query.redemptionCodeBatches.findFirst({
      where: eq(redemptionCodeBatches.batchId, batchId),
    });
    if (!existing) {
      throw new NotFoundException('Batch not found');
    }
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

  // ===== 积分管理 =====

  async getUserPoints(deviceId: string) {
    const db = this.dbService.getDb();
    const balance = await this.pointsService.getBalance(deviceId);
    const transactions = await this.pointsService.listTransactions(deviceId, 100, 0);

    return {
      ...balance,
      transactions: transactions.transactions,
    };
  }

  async grantPoints(
    deviceId: string,
    delta: number,
    reason?: string,
  ) {
    if (delta <= 0) {
      throw new BadRequestException('充值积分必须为正数');
    }
    // 充值原因写入流水备注，App 端积分流水优先展示该原因（未填写则回退通用来源文案）
    const trimmedReason = reason?.trim() ? reason.trim() : null;
    const newBalance = await this.pointsService.earnPoints(
      deviceId,
      delta,
      'admin_grant',
      null,
      trimmedReason,
    );
    return { success: true, balance: newBalance };
  }

  async deleteDevice(deviceId: string, loginKey: string) {
    verifyLoginKey(loginKey);
    const db = this.dbService.getDb();
    const existing = await db
      .select({ deviceId: devices.deviceId })
      .from(devices)
      .where(eq(devices.deviceId, deviceId))
      .limit(1);

    if (existing.length === 0) {
      throw new NotFoundException('设备不存在');
    }

    const uploadRoot = path.resolve(process.env.UPLOAD_DIR || './data/uploads');
    const uploadDirs: string[][] = [['users', deviceId]];
    const feedbackRows = await db
      .select({ id: feedbacks.id })
      .from(feedbacks)
      .where(eq(feedbacks.deviceId, deviceId));
    uploadDirs.push(...feedbackRows.map((row) => ['feedback', row.id]));

    await db.transaction(async (tx) => {
      const redemptionUsage = await tx
        .select({
          batchId: redemptionCodeBatches.batchId,
          code: redemptionCodes.code,
          usedCount: count(),
        })
        .from(redemptionRecords)
        .innerJoin(redemptionCodes, eq(redemptionRecords.code, redemptionCodes.code))
        .innerJoin(redemptionCodeBatches, eq(redemptionCodes.batchId, redemptionCodeBatches.batchId))
        .where(eq(redemptionRecords.deviceId, deviceId))
        .groupBy(redemptionCodeBatches.batchId, redemptionCodes.code);

      for (const usage of redemptionUsage) {
        await tx
          .update(redemptionCodes)
          .set({ usedCount: sql`GREATEST(${redemptionCodes.usedCount} - ${Number(usage.usedCount)}, 0)` })
          .where(eq(redemptionCodes.code, usage.code));
        await tx
          .update(redemptionCodeBatches)
          .set({ totalUsed: sql`GREATEST(${redemptionCodeBatches.totalUsed} - ${Number(usage.usedCount)}, 0)` })
          .where(eq(redemptionCodeBatches.batchId, usage.batchId));
      }

      await tx.delete(userProfiles).where(eq(userProfiles.deviceId, deviceId));
      await tx.delete(inviteRecords).where(eq(inviteRecords.inviterDeviceId, deviceId));
      await tx.delete(inviteRecords).where(eq(inviteRecords.inviteeDeviceId, deviceId));
      await tx.delete(rewardUnlocks).where(eq(rewardUnlocks.deviceId, deviceId));
      await tx.delete(redemptionRecords).where(eq(redemptionRecords.deviceId, deviceId));
      await tx.delete(questionnaireRecords).where(eq(questionnaireRecords.deviceId, deviceId));
      await tx.delete(userPoints).where(eq(userPoints.deviceId, deviceId));
      await tx.delete(pointTransactions).where(eq(pointTransactions.deviceId, deviceId));
      await tx.delete(ownedTemplates).where(eq(ownedTemplates.deviceId, deviceId));
      await tx.delete(dailySignInRecords).where(eq(dailySignInRecords.deviceId, deviceId));
      await tx.delete(pointEarnEvents).where(eq(pointEarnEvents.deviceId, deviceId));
      await tx.delete(feedbacks).where(eq(feedbacks.deviceId, deviceId));
      await tx.delete(accountOtp).where(eq(accountOtp.deviceId, deviceId));
      await tx.delete(usageEvents).where(eq(usageEvents.deviceId, deviceId));
      await tx.delete(devices).where(eq(devices.deviceId, deviceId));
    });

    removeUploadDirs(uploadRoot, uploadDirs);
    return { success: true as const };
  }
}
