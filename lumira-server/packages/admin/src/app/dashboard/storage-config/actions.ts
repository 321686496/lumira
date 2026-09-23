'use server';

import { revalidatePath } from 'next/cache';
import { api } from '@/lib/api';
import type { StorageConfigView, StorageConfigPayload } from '@/types/admin';

type ActionResult<T> = { ok: true; data: T } | { ok: false; error: string };

async function wrap<T>(fn: () => Promise<T>): Promise<ActionResult<T>> {
  try {
    const data = await fn();
    return { ok: true, data };
  } catch (e) {
    return { ok: false, error: (e as Error).message || '请求失败' };
  }
}

export async function listStorageConfigAction(): Promise<ActionResult<StorageConfigView[]>> {
  return wrap(() => api.listStorageConfig());
}

export async function saveStorageConfigAction(
  id: string,
  payload: StorageConfigPayload & { active?: boolean },
): Promise<ActionResult<{ ok: boolean }>> {
  const res = await wrap(() => api.saveStorageConfig(id, payload));
  revalidatePath('/dashboard/storage-config');
  return res;
}