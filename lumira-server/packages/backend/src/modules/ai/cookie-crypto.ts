// lumira-server/packages/backend/src/modules/ai/cookie-crypto.ts
// 网页爬取 cookie 的加密存储与按域选择。
// 设计文档：docs/superpowers/specs/2026-09-28-ai-crawl-render-fallback-design.md 第五节
//
// 安全约束：cookie 按域名后缀匹配注入，无匹配就一份都不发（禁止模糊匹配，
// 否则会把某站会话泄露给任意被抓站点）；密文格式 v1:<ivHex>:<tagHex>:<cipherHex>。

import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';

const STORAGE_VERSION = 'v1';
const IV_BYTES = 12;
const ALGO = 'aes-256-gcm';

/** 归一化 hostname / 域名：小写、去尾点 */
function normalizeHost(s: string): string {
  return (s || '').trim().toLowerCase().replace(/\.+$/, '');
}

/**
 * 按目标 host 选择要发送的 cookie：`host === domain || host.endsWith('.' + domain)`。
 * 无匹配返回空对象（此时不得发送任何 cookie）。
 */
export function selectCookiesForHost(host: string, cookies: Record<string, string>): Record<string, string> {
  const h = normalizeHost(host);
  const out: Record<string, string> = {};
  if (!h) return out;
  for (const [domain, value] of Object.entries(cookies ?? {})) {
    const d = normalizeHost(domain);
    if (!d || !value) continue;
    if (h === d || h.endsWith(`.${d}`)) out[domain] = value;
  }
  return out;
}

/** 读取并校验 32 字节密钥（64 位 hex）；缺失/非法抛可读错误 */
function readKey(): Buffer {
  const raw = (process.env.CRAWL_COOKIE_SECRET || '').trim();
  if (!/^[0-9a-fA-F]{64}$/.test(raw)) {
    throw new Error('未配置 CRAWL_COOKIE_SECRET，无法保存 cookie');
  }
  return Buffer.from(raw, 'hex');
}

/** 加密 cookie 映射；无可存内容返回 null；密钥缺失/非法抛错（绝不落明文） */
export function encryptCookies(cookies: Record<string, string>): string | null {
  const entries = Object.entries(cookies ?? {}).filter(([d, v]) => normalizeHost(d) && v);
  if (!entries.length) return null;
  const key = readKey();
  const iv = randomBytes(IV_BYTES);
  const cipher = createCipheriv(ALGO, key, iv);
  const plain = JSON.stringify(Object.fromEntries(entries));
  const enc = Buffer.concat([cipher.update(plain, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `${STORAGE_VERSION}:${iv.toString('hex')}:${tag.toString('hex')}:${enc.toString('hex')}`;
}

/** 解密 cookie 映射；任何异常（格式非法 / 密钥缺失 / 被篡改）返回空对象并 warn，不中断链路 */
export function decryptCookies(stored: string | null | undefined): Record<string, string> {
  if (!stored) return {};
  try {
    const [version, ivHex, tagHex, dataHex] = stored.split(':');
    if (version !== STORAGE_VERSION || !ivHex || !tagHex || !dataHex) return {};
    const raw = (process.env.CRAWL_COOKIE_SECRET || '').trim();
    if (!/^[0-9a-fA-F]{64}$/.test(raw)) return {};
    const decipher = createDecipheriv(ALGO, Buffer.from(raw, 'hex'), Buffer.from(ivHex, 'hex'));
    decipher.setAuthTag(Buffer.from(tagHex, 'hex'));
    const plain = Buffer.concat([decipher.update(Buffer.from(dataHex, 'hex')), decipher.final()]).toString('utf8');
    const parsed = JSON.parse(plain);
    return parsed && typeof parsed === 'object' ? (parsed as Record<string, string>) : {};
  } catch {
    // 只报事实，绝不输出 cookie 值
    console.warn('WARN: 网页爬取 cookie 解密失败，本次按「无 cookie」处理');
    return {};
  }
}