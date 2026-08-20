// src/actions/notifications.ts
'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { api } from '../lib/api';
import { UnauthenticatedError } from '../lib/auth';
import type { NotificationPayload } from '../types/admin';

/** 业务字段体：targetDeviceIds / targetCriteria 以结构化形式传入，发送后端前序列化为 JSON 字符串 */
export interface NotificationMutationBody {
  id?: string;
  title?: string;
  body?: string;
  iconKey?: string;
  category?: string;
  targetScope?: 'all' | 'devices' | 'criteria';
  targetDeviceIds?: string[];
  targetCriteria?: Record<string, string[]>;
  startAt?: number | null;
  endAt?: number | null;
  isActive?: boolean;
  sortOrder?: number;
}

/**
 * 新建 / 编辑通知公告。payload 使用业务字段（camelCase）；后端 DTO 的
 * targetDeviceIdsJson / targetCriteriaJson 接受 JSON 字符串，故在此序列化。
 */
export async function saveNotification(id: string | null, body: NotificationMutationBody) {
  const payload: NotificationPayload = { ...body };
  if (body.targetDeviceIds !== undefined) {
    payload.targetDeviceIdsJson = JSON.stringify(body.targetDeviceIds);
    delete (payload as Record<string, unknown>).targetDeviceIds;
  }
  if (body.targetCriteria !== undefined) {
    payload.targetCriteriaJson = JSON.stringify(body.targetCriteria);
    delete (payload as Record<string, unknown>).targetCriteria;
  }
  try {
    if (id) await api.updateNotification(id, payload);
    else await api.createNotification(payload);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
  revalidatePath('/dashboard/notifications');
  return { success: true };
}

export async function removeNotification(id: string) {
  try {
    await api.deleteNotification(id);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
  revalidatePath('/dashboard/notifications');
  return { success: true };
}

export async function setNotificationActive(id: string) {
  try {
    const result = await api.toggleNotification(id);
    revalidatePath('/dashboard/notifications');
    return { success: true, isActive: result.isActive };
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
}