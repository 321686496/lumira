import { createHash, randomBytes } from 'crypto';

export function sha256Hex(input: string): string {
  return createHash('sha256').update(input).digest('hex');
}

/** 生成 URL 安全的随机恢复密钥（32 字节 → 43 字符 base64url） */
export function generateSecret(): string {
  return randomBytes(32).toString('base64url');
}

/** 生成 6 位数字验证码 */
export function generateOtp(): string {
  return String(Math.floor(100000 + Math.random() * 900000));
}