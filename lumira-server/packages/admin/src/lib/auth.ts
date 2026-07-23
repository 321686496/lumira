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
export async function verifyToken(token: string): Promise<boolean> {
  const backendUrl = process.env.BACKEND_URL || 'http://localhost:3000';
  try {
    const res = await fetch(`${backendUrl}/api/v1/admin/stats`, {
      headers: { Authorization: `Bearer ${token}` },
      cache: 'no-store',
    });
    return res.ok;
  } catch {
    return false;
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
