// lumira-server/packages/backend/src/modules/points/points.service.ts

import { Injectable, BadRequestException } from '@nestjs/common';
import { eq, sql } from 'drizzle-orm';
import type { ExtractTablesWithRelations } from 'drizzle-orm';
import type { MySql2Transaction } from 'drizzle-orm/mysql2';
import { DatabaseService } from '../../database/database.service';
import { userPoints, pointTransactions, pointEarnEvents } from '../../database/schema';
import * as schema from '../../database/schema';
import { getUtc8DateStr } from '../../common/utils/date.util';

// 积分流水类型（与 shared 类型保持一致，此处本地定义避免事务内依赖 shared 构建产物）
type PointTransactionType =
  | 'invite' | 'sign_in' | 'share' | 'redeem_code'
  | 'exchange_template' | 'ad' | 'admin_grant'
  | 'shoot_daily' | 'challenge';

// 事件型积分规则：type → 单次积分值
const DAILY_SHOOT_POINTS = 2; // 每日首次拍摄
const CHALLENGE_POINTS = 5;   // 每次完成挑战
const SHARE_POINTS = 2;       // 每日首次分享

interface BalanceRow {
  deviceId: string;
  balance: number;
  totalEarned: number;
  totalSpent: number;
  updatedAt: number;
}

@Injectable()
export class PointsService {
  constructor(private readonly dbService: DatabaseService) {}

  /**
   * 增加积分（事务：upsert 余额 + 写流水）
   * 幂等性由调用方保证（如兑换码的 device+code 去重、签到的 device+date 去重）
   */
  async earnPoints(
    deviceId: string,
    delta: number,
    type: PointTransactionType,
    refId: string | null = null,
  ): Promise<number> {
    if (delta <= 0) {
      throw new BadRequestException('earnPoints delta must be positive');
    }
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    await db.transaction(async (tx) => {
      // 查询当前余额
      const rows = await tx.select().from(userPoints).where(eq(userPoints.deviceId, deviceId)) as BalanceRow[];
      const existing = rows[0];

      // 写流水
      await tx.insert(pointTransactions).values({
        deviceId,
        delta,
        type,
        refId,
        createdAt: now,
      });

      if (existing) {
        await tx.update(userPoints)
          .set({
            balance: existing.balance + delta,
            totalEarned: existing.totalEarned + delta,
            updatedAt: now,
          })
          .where(eq(userPoints.deviceId, deviceId));
      } else {
        await tx.insert(userPoints).values({
          deviceId,
          balance: delta,
          totalEarned: delta,
          totalSpent: 0,
          updatedAt: now,
        });
      }
    });

    const updated = await this.getBalance(deviceId);
    return updated.balance;
  }

  /**
   * 事件型积分发放（每日首拍 / 完成挑战等）。
   *
   * 幂等性由 point_earn_events 的 UNIQUE(device_id, type, ref_id) 保证：
   * 同一设备同一事件只发放一次，重复请求返回 { granted: false }（200，不抛错），
   * 避免客户端因状态不同步把"已领取"当错误处理（参考签到 409 → Unknown Error 问题）。
   *
   * @param type  'shoot_daily'（refId 由服务端按 UTC+8 日期计算）| 'challenge'（refId=challengeId）
   */
  async earnEvent(
    deviceId: string,
    type: PointTransactionType,
    refId: string | null = null,
  ): Promise<{ granted: boolean; delta: number; balance: number }> {
    let points: number;
    let eventRefId: string;

    if (type === 'shoot_daily') {
      points = DAILY_SHOOT_POINTS;
      // refId 统一按服务端 UTC+8 自然日计算，防止客户端时区不一致导致重复领取或漏领
      eventRefId = getUtc8DateStr();
    } else if (type === 'challenge') {
      points = CHALLENGE_POINTS;
      if (!refId) {
        throw new BadRequestException('refId is required for challenge');
      }
      eventRefId = refId;
    } else if (type === 'share') {
      points = SHARE_POINTS;
      // 每日首次分享：refId 按 UTC+8 自然日计算（与 shoot_daily 同模式，幂等）
      eventRefId = getUtc8DateStr();
    } else {
      throw new BadRequestException(`Unsupported earn type: ${type}`);
    }

    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    try {
      await db.transaction(async (tx) => {
        // 幂等检查：插入事件记录（device+type+refId 唯一，冲突时抛出 UNIQUE 错误）
        await tx.insert(pointEarnEvents).values({
          deviceId,
          type,
          refId: eventRefId,
          points,
          createdAt: now,
        });

        // 写流水 + upsert 余额
        const rows = await tx.select().from(userPoints).where(eq(userPoints.deviceId, deviceId)) as BalanceRow[];
        const existing = rows[0];

        await tx.insert(pointTransactions).values({
          deviceId,
          delta: points,
          type,
          refId: eventRefId,
          createdAt: now,
        });

        if (existing) {
          await tx.update(userPoints)
            .set({
              balance: existing.balance + points,
              totalEarned: existing.totalEarned + points,
              updatedAt: now,
            })
            .where(eq(userPoints.deviceId, deviceId));
        } else {
          await tx.insert(userPoints).values({
            deviceId,
            balance: points,
            totalEarned: points,
            totalSpent: 0,
            updatedAt: now,
          });
        }
      });
      const updated = await this.getBalance(deviceId);
      return { granted: true, delta: points, balance: updated.balance };
    } catch (e) {
      // 唯一约束冲突 = 该事件已发放过 → 返回未发放（不抛错）
      if (e instanceof Error && (e.message.includes('Duplicate entry') || e.message.includes('ER_DUP_ENTRY'))) {
        const updated = await this.getBalance(deviceId);
        return { granted: false, delta: 0, balance: updated.balance };
      }
      throw e;
    }
  }

  /**
   * 消耗积分（事务：校验余额 + 扣减 + 写流水）
   * 余额不足抛 BadRequestException
   */
  async spendPoints(
    deviceId: string,
    delta: number,
    type: PointTransactionType,
    refId: string | null = null,
  ): Promise<number> {
    const db = this.dbService.getDb();
    return db.transaction(async (tx) =>
      this.spendPointsSync(tx, deviceId, delta, type, refId),
    );
  }

  /**
   * 消耗积分（供外层事务复用，如模板兑换的整体事务）。
   * 在传入的 tx 内执行：校验余额 + 写流水（负数）+ 扣减余额；
   * 余额不足抛 BadRequestException；返回扣减后的新余额。
   */
  async spendPointsSync(
    tx: MySql2Transaction<typeof schema, ExtractTablesWithRelations<typeof schema>>,
    deviceId: string,
    delta: number,
    type: PointTransactionType,
    refId: string | null = null,
  ): Promise<number> {
    if (delta <= 0) {
      throw new BadRequestException('spendPoints delta must be positive');
    }
    const now = Math.floor(Date.now() / 1000);
    const rows = await tx.select().from(userPoints).where(eq(userPoints.deviceId, deviceId)) as BalanceRow[];
    const existing = rows[0];
    if (!existing || existing.balance < delta) {
      throw new BadRequestException('Insufficient points balance');
    }
    // 写流水（负数）
    await tx.insert(pointTransactions).values({
      deviceId,
      delta: -delta,
      type,
      refId,
      createdAt: now,
    });
    // 扣减余额
    await tx.update(userPoints)
      .set({
        balance: existing.balance - delta,
        totalSpent: existing.totalSpent + delta,
        updatedAt: now,
      })
      .where(eq(userPoints.deviceId, deviceId));
    return existing.balance - delta;
  }

  /** 查余额（不存在则返回 0）*/
  async getBalance(deviceId: string) {
    const db = this.dbService.getDb();
    const rows = await db.select().from(userPoints).where(eq(userPoints.deviceId, deviceId));
    const record = rows[0];
    return {
      deviceId,
      balance: record?.balance ?? 0,
      totalEarned: record?.totalEarned ?? 0,
      totalSpent: record?.totalSpent ?? 0,
    };
  }

  /** 查流水（倒序，默认 50 条）*/
  async listTransactions(deviceId: string, limit = 50, offset = 0) {
    const db = this.dbService.getDb();
    const rows = await db.query.pointTransactions.findMany({
      where: eq(pointTransactions.deviceId, deviceId),
      limit,
      offset,
      orderBy: (t, { desc }) => [desc(t.id)],
    });
    const totalResult = await db.select({ value: sql<number>`count(*)` })
      .from(pointTransactions)
      .where(eq(pointTransactions.deviceId, deviceId));
    const total = totalResult[0]?.value ?? 0;
    return {
      transactions: rows.map((r) => ({
        id: r.id,
        deviceId: r.deviceId,
        delta: r.delta,
        type: r.type as PointTransactionType,
        refId: r.refId,
        createdAt: r.createdAt,
      })),
      total,
    };
  }
}
