// src/actions/login.ts
'use server';

import { redirect } from 'next/navigation';
import { setAuthToken, verifyToken } from '@/lib/auth';

export async function loginAction(token: string, redirectTo?: string) {
  if (!token || token.trim().length === 0) {
    return { error: '请输入 Token' };
  }

  const valid = await verifyToken(token);
  if (!valid) {
    return { error: 'Token 无效，请检查后重试' };
  }

  setAuthToken(token);
  const safeRedirect =
    redirectTo && redirectTo.startsWith('/') && !redirectTo.startsWith('//')
      ? redirectTo
      : '/dashboard';
  redirect(safeRedirect);
}
