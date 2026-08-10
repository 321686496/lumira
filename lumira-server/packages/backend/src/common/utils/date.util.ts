// lumira-server/packages/backend/src/common/utils/date.util.ts
//
// 产品目标市场为 UTC+8（Asia/Shanghai）。签到、每日奖励等"自然日"边界统一按
// UTC+8 计算，避免服务器时区（如 UTC）与用户本地日期不一致导致连签、每日奖励
// 判定错乱（例如北京时间 00:00~07:59 被服务器当作"前一天"）。

const UTC8_OFFSET_MS = 8 * 60 * 60 * 1000;

/** UTC+8 当天 0 点的时间戳（秒）。 */
export function getUtc8DayStart(): number {
  const nowMs = Date.now();
  const shifted = nowMs + UTC8_OFFSET_MS;
  const shiftedDayStart = Math.floor(shifted / 86400000) * 86400000;
  return Math.floor((shiftedDayStart - UTC8_OFFSET_MS) / 1000);
}

/** UTC+8 当天日期字符串 YYYY-MM-DD。 */
export function getUtc8DateStr(d: Date = new Date()): string {
  const shifted = new Date(d.getTime() + UTC8_OFFSET_MS);
  const y = shifted.getUTCFullYear();
  const m = String(shifted.getUTCMonth() + 1).padStart(2, '0');
  const day = String(shifted.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}
