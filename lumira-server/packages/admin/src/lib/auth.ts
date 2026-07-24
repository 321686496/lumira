// src/lib/auth.ts
import { cookies } from 'next/headers';

export const AUTH_COOKIE_NAME = 'admin_token';
const COOKIE_MAX_AGE = 60 * 60 * 24 * 30; // 30 天

export function getAuthToken(): string | undefined {
  return cookies().get(AUTH_COOKIE_NAME)?.value;
}

export function setAuthToken(token: string): void {
  cookies().set(AUTH_COOKIE_NAME, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    maxAge: COOKIE_MAX_AGE,
    path: '/',
  });
}

export function clearAuthToken(): void {
  cookies().delete(AUTH_COOKIE_NAME);
}

// 校验 token 有效性（调后端 /stats）
// 返回结构化结果，区分「网络错误」「Token 无效」「后端异常状态」，避免把所有失败都误报成 Token 无效。
export type VerifyTokenResult =
  | { ok: true }
  | { ok: false; reason: 'network' | 'unauthorized' | 'unknown'; message: string };

export async function verifyToken(token: string): Promise<VerifyTokenResult> {
  const backendUrl = process.env.BACKEND_URL || 'http://localhost:3000';
  try {
    const res = await fetch(`${backendUrl}/api/v1/admin/stats`, {
      headers: { Authorization: `Bearer ${token}` },
      cache: 'no-store',
    });
    if (res.ok) return { ok: true };
    if (res.status === 401) {
      return { ok: false, reason: 'unauthorized', message: 'Token 无效，请检查后重试' };
    }
    return {
      ok: false,
      reason: 'unknown',
      message: `后端返回异常状态：${res.status} ${res.statusText || ''}`.trim(),
    };
  } catch {
    return {
      ok: false,
      reason: 'network',
      message: `无法连接到后端服务（${backendUrl}），请确认后端已启动`,
    };
  }
}

/**
 * Thrown by adminFetch when the admin token is missing or rejected (HTTP 401).
 * Callers must catch this and call redirect('/login') — do NOT let it surface as
 * an error message, because redirect() inside adminFetch would be swallowed by
 * the caller's try/catch (Next.js redirect() throws NEXT_REDIRECT internally).
 */
export class UnauthenticatedError extends Error {
  constructor(message = 'Unauthorized') {
    super(message);
    this.name = 'UnauthenticatedError';
  }
}
