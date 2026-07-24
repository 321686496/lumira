// src/actions/login.ts
'use server';

import { redirect } from 'next/navigation';
import { setAuthToken, verifyToken } from '@/lib/auth';

export async function loginAction(token: string, redirectTo?: string) {
  // trim 防止复制粘贴带入首尾空白符导致比对失败
  const trimmed = token?.trim();
  if (!trimmed) {
    return { error: '请输入 Token' };
  }

  const result = await verifyToken(trimmed);
  if (!result.ok) {
    return { error: result.message };
  }

  setAuthToken(trimmed);
  const safeRedirect =
    redirectTo && redirectTo.startsWith('/') && !redirectTo.startsWith('//')
      ? redirectTo
      : '/dashboard';
  redirect(safeRedirect);
}
