// src/actions/feedback.ts
'use server';

import { redirect } from 'next/navigation';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import type { FeedbackListResponse } from '@/types/admin';

/** 分页/筛选列表。未认证时重定向登录；失败返回 null */
export async function listFeedbacks(
  params: { page?: number; pageSize?: number; type?: string; status?: string } = {},
): Promise<FeedbackListResponse | null> {
  try {
    return await api.listFeedbacks(params);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return null;
  }
}

/** 标记已处理 / 恢复未处理 */
export async function updateFeedbackStatus(id: string, status: string) {
  try {
    await api.updateFeedbackStatus(id, status);
    return { success: true };
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
}