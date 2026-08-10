// lumira-server/packages/backend/src/modules/sign-in/sign-in.service.ts

import { Injectable, ConflictException } from '@nestjs/common';
import { eq, and, desc } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { dailySignInRecords } from '../../database/schema';
import { PointsService } from '../points/points.service';
import { getUtc8DayStart } from '../../common/utils/date.util';

// 签到奖励配置：每天 2 积分，第 7 天额外奖励 14 积分（共 16 积分）
const DAILY_BASE_POINTS = 2;
const DAY_7_BONUS = 14;
const MAX_DAY_INDEX = 7;

@Injectable()
export class SignInService {
  constructor(
    private readonly dbService: DatabaseService,
    private readonly pointsService: PointsService,
  ) {}

  /** 获取当天 0 点时间戳（秒），按 UTC+8（Asia/Shanghai）自然日计算 */
  private getTodayStart(): number {
    return getUtc8DayStart();
  }

  /** 计算连签天数：从今天往前数连续签到天数 */
  private computeConsecutiveDays(records: { signInDate: number }[], today: number): number {
    if (records.length === 0) return 0;
    // records 按 signInDate 倒序
    const dateSet = new Set(records.map((r) => r.signInDate));
    let days = 0;
    const oneDay = 86400;
    for (let i = 0; i < MAX_DAY_INDEX; i++) {
      const checkDate = today - i * oneDay;
      if (dateSet.has(checkDate)) {
        days++;
      } else {
        break;
      }
    }
    return days;
  }

  /** 签到状态 */
  async getStatus(deviceId: string) {
    const db = this.dbService.getDb();
    const today = this.getTodayStart();

    const records = await db.query.dailySignInRecords.findMany({
      where: eq(dailySignInRecords.deviceId, deviceId),
      orderBy: desc(dailySignInRecords.signInDate),
      limit: MAX_DAY_INDEX,
    });

    const signedToday = records.some((r) => r.signInDate === today);
    const consecutiveDays = this.computeConsecutiveDays(
      records.map((r) => ({ signInDate: r.signInDate })),
      today,
    );

    return {
      signedToday,
      consecutiveDays,
      lastSignInDate: records[0]?.signInDate ?? null,
    };
  }

  /** 执行签到 */
  async signIn(deviceId: string) {
    const db = this.dbService.getDb();
    const today = this.getTodayStart();
    const now = Math.floor(Date.now() / 1000);

    // 幂等检查
    const existing = await db.query.dailySignInRecords.findFirst({
      where: and(
        eq(dailySignInRecords.deviceId, deviceId),
        eq(dailySignInRecords.signInDate, today),
      ),
    });
    if (existing) {
      throw new ConflictException('Already signed in today');
    }

    // 计算连签 day_index
    const records = await db.query.dailySignInRecords.findMany({
      where: eq(dailySignInRecords.deviceId, deviceId),
      orderBy: desc(dailySignInRecords.signInDate),
      limit: 1,
    });
    const yesterday = today - 86400;
    const lastWasYesterday = records[0]?.signInDate === yesterday;
    // 连续：昨天签了则在上次基础上 +1，否则重置为 1
    const prevDayIndex = records[0]?.dayIndex ?? 0;
    const dayIndex = lastWasYesterday
      ? (prevDayIndex >= MAX_DAY_INDEX ? 1 : prevDayIndex + 1)
      : 1;

    // 计算积分：第 7 天 = 基础 + 奖励
    const pointsEarned = dayIndex === MAX_DAY_INDEX
      ? DAILY_BASE_POINTS + DAY_7_BONUS
      : DAILY_BASE_POINTS;

    // 写签到记录
    await db.insert(dailySignInRecords).values({
      deviceId,
      signInDate: today,
      dayIndex,
      pointsEarned,
      createdAt: now,
    }).run();

    // 发积分
    const newBalance = await this.pointsService.earnPoints(
      deviceId,
      pointsEarned,
      'sign_in',
      String(today),
    );

    return {
      success: true,
      dayIndex,
      pointsEarned,
      balance: newBalance,
    };
  }
}
