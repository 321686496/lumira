// src/actions/scenes.ts
'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { api } from '../lib/api';
import { UnauthenticatedError } from '../lib/auth';

/**
 * 新建 / 编辑场景。payload 使用 camelCase 键（同 @lumira/shared 的
 * CreateSceneRequest / UpdateSceneRequest），id 仅在新建时必填。
 */
export async function saveScene(id: string | null, payload: Record<string, unknown>) {
  try {
    if (id) await api.updateScene(id, payload);
    else await api.createScene(payload);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
  revalidatePath('/dashboard/scenes');
  return { success: true };
}

export async function removeScene(id: string) {
  try {
    await api.deleteScene(id);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
  revalidatePath('/dashboard/scenes');
  return { success: true };
}

export async function setSceneActive(id: string) {
  try {
    const result = await api.toggleScene(id);
    revalidatePath('/dashboard/scenes');
    return { success: true, isActive: result.isActive };
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
}