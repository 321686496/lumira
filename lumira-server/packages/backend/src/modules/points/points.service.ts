// lumira-server/packages/backend/src/modules/points/points.service.ts

import { Injectable, BadRequestException } from '@nestjs/common';
import { eq, sql } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { userPoints, pointTransactions } from '../../database/schema';

// 积分流水类型（与 shared 类型保持一致，此处本地定义避免事务内依赖 shared 构建产物）
type PointTransactionType =
  | 'invite' | 'sign_in' | 'share' | 'redeem_code'
  | 'exchange_template' | 'ad' | 'admin_grant';

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

    db.transaction((tx) => {
      // 同步查询当前余额（better-sqlite3 事务内用 .all()）
      const rows = tx.select().from(userPoints).where(eq(userPoints.deviceId, deviceId)).all() as BalanceRow[];
      const existing = rows[0];

      // 写流水
      tx.insert(pointTransactions).values({
        deviceId,
        delta,
        type,
        refId,
        createdAt: now,
      }).run();

      if (existing) {
        tx.update(userPoints)
          .set({
            balance: existing.balance + delta,
            totalEarned: existing.totalEarned + delta,
            updatedAt: now,
          })
          .where(eq(userPoints.deviceId, deviceId))
          .run();
      } else {
        tx.insert(userPoints).values({
          deviceId,
          balance: delta,
          totalEarned: delta,
          totalSpent: 0,
          updatedAt: now,
        }).run();
      }
    });

    const updated = await this.getBalance(deviceId);
    return updated.balance;
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
    if (delta <= 0) {
      throw new BadRequestException('spendPoints delta must be positive');
    }
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    db.transaction((tx) => {
      const rows = tx.select().from(userPoints).where(eq(userPoints.deviceId, deviceId)).all() as BalanceRow[];
      const existing = rows[0];
      if (!existing || existing.balance < delta) {
        throw new BadRequestException('Insufficient points balance');
      }
      // 写流水（负数）
      tx.insert(pointTransactions).values({
        deviceId,
        delta: -delta,
        type,
        refId,
        createdAt: now,
      }).run();
      // 扣减余额
      tx.update(userPoints)
        .set({
          balance: existing.balance - delta,
          totalSpent: existing.totalSpent + delta,
          updatedAt: now,
        })
        .where(eq(userPoints.deviceId, deviceId))
        .run();
    });

    const updated = await this.getBalance(deviceId);
    return updated.balance;
  }

  /** 查余额（不存在则返回 0） */
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

  /** 查流水（倒序，默认 50 条） */
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
