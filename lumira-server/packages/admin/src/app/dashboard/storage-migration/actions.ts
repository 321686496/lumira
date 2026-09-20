// src/app/dashboard/storage-migration/actions.ts
// Server Actions：封装后端迁移 API（adminFetch 依赖 next/headers cookies，仅能在服务端调用）。

'use server';

import { revalidatePath } from 'next/cache';
import type { MigrationRecordView, MigrationRunningView } from '@/types/admin';
import { api } from '@/lib/api';

export interface ActionResult<T> {
  ok: boolean;
  data?: T;
  error?: string;
}

async function wrap<T>(fn: () => Promise<T>): Promise<ActionResult<T>> {
  try {
    return { ok: true, data: await fn() };
  } catch (e) {
    return { ok: false, error: (e as Error).message };
  }
}

export async function startMigrationAction(triggerBy: string, target?: string): Promise<ActionResult<{ id: string; sourceId: string; targetId: string }>> {
  const started = await wrap(() => api.startMigration(triggerBy, target));
  revalidatePath('/dashboard/storage-migration');
  return started;
}

export async function stopMigrationAction(): Promise<ActionResult<{ stopped: boolean }>> {
  const res = await wrap(() => api.stopMigration());
  revalidatePath('/dashboard/storage-migration');
  return res;
}

export async function getMigrationStatusAction(): Promise<ActionResult<MigrationRunningView>> {
  return wrap(() => api.getMigrationStatus());
}

export async function listMigrationsAction(): Promise<ActionResult<MigrationRecordView[]>> {
  return wrap(() => api.listMigrations());
}

export async function getMigrationDetailAction(id: string): Promise<ActionResult<MigrationRecordView>> {
  return wrap(() => api.getMigrationDetail(id));
}

export async function retryMigrationAction(id: string): Promise<ActionResult<{ id: string; sourceId: string; targetId: string }>> {
  const res = await wrap(() => api.retryMigration(id));
  revalidatePath('/dashboard/storage-migration');
  return res;
}