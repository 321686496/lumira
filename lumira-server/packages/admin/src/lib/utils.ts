import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

// 截断 UUID 显示（前 8 位 + …）
export function truncateDeviceId(id: string): string {
  return id.length > 12 ? `${id.slice(0, 8)}…` : id;
}

// Unix 秒 → YYYY-MM-DD HH:mm（固定 Asia/Shanghai 时区）
// 注意：不要用 getFullYear()/getHours() 等本地时区方法 —— Vercel 服务器运行在 UTC，
// 浏览器在 UTC+8，会渲染出不同的字符串导致 React hydration 失败（#418/#423）。
// 上海无夏令时，恒为 UTC+8，因此加 8 小时偏移后用 UTC getter 即可得到上海时间，
// 且不依赖 Intl 的时区数据实现差异，server/client 输出绝对一致。
const SHANGHAI_OFFSET_MS = 8 * 3600 * 1000;

export function formatUnixTime(unix: number): string {
  const d = new Date(unix * 1000 + SHANGHAI_OFFSET_MS);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())} ${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())}`;
}

// datetime-local 字符串 → Unix 秒
export function toUnixSeconds(localDatetime: string): number {
  return Math.floor(new Date(localDatetime).getTime() / 1000);
}
