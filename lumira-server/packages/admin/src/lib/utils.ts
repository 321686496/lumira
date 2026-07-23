import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

// 截断 UUID 显示（前 8 位 + …）
export function truncateDeviceId(id: string): string {
  return id.length > 12 ? `${id.slice(0, 8)}…` : id;
}

// Unix 秒 → YYYY-MM-DD HH:mm
export function formatUnixTime(unix: number): string {
  const d = new Date(unix * 1000);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

// datetime-local 字符串 → Unix 秒
export function toUnixSeconds(localDatetime: string): number {
  return Math.floor(new Date(localDatetime).getTime() / 1000);
}
