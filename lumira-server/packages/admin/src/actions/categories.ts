// src/actions/categories.ts
'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';

/**
 * 创建分类。formData 字段：
 *   - meta: JSON string (CreateCategoryRequest)
 *   - icon: File (可选)
 */
export async function createCategory(formData: FormData) {
  const meta = formData.get('meta');
  if (!meta || typeof meta !== 'string') {
    return { error: '缺少分类元数据 (meta)' };
  }
  let parsed: { key?: string; name?: string };
  try {
    parsed = JSON.parse(meta);
  } catch {
    return { error: '分类元数据 (meta) 不是合法 JSON' };
  }
  if (!parsed.key || typeof parsed.key !== 'string' || !parsed.key.trim()) {
    return { error: '请填写分类 key' };
  }
  if (!parsed.name || typeof parsed.name !== 'string' || !parsed.name.trim()) {
    return { error: '请填写分类名称' };
  }

  try {
    await api.createCategory(formData);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }

  revalidatePath('/dashboard/categories');
  revalidatePath('/dashboard/templates');
  return { success: true };
}

/**
 * 更新分类。系统分类的 key 不可改（由后端拒绝），formData 同 createCategory。
 */
export async function updateCategory(key: string, formData: FormData) {
  const meta = formData.get('meta');
  if (!meta || typeof meta !== 'string') {
    return { error: '缺少分类元数据 (meta)' };
  }
  try {
    JSON.parse(meta);
  } catch {
    return { error: '分类元数据 (meta) 不是合法 JSON' };
  }

  try {
    await api.updateCategory(key, formData);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }

  revalidatePath('/dashboard/categories');
  revalidatePath('/dashboard/templates');
  return { success: true };
}

export async function deleteCategory(key: string) {
  try {
    await api.deleteCategory(key);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
  revalidatePath('/dashboard/categories');
  revalidatePath('/dashboard/templates');
  return { success: true };
}

export async function toggleCategoryActive(key: string) {
  try {
    const result = await api.toggleCategoryActive(key);
    revalidatePath('/dashboard/categories');
    revalidatePath('/dashboard/templates');
    return { success: true, isActive: result.isActive };
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
}
