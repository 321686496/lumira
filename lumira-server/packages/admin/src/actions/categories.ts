// src/actions/categories.ts
'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';

/**
 * 创建分类。formData 字段：
 *   - meta: JSON string (CreateCategoryRequest，含 parentKey/level)
 *   - icon: File (可选，仅一级分类)
 */
export async function createCategory(formData: FormData) {
  const meta = formData.get('meta');
  if (!meta || typeof meta !== 'string') {
    return { error: '缺少分类元数据 (meta)' };
  }
  let parsed: {
    key?: string;
    name?: string;
    level?: number;
    parentKey?: string | null;
  };
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
  const level = Number(parsed.level);
  if (![1, 2, 3, 4].includes(level)) {
    return { error: '请选择有效的层级（1/2/3/4）' };
  }
  // 二/三/四级分类必须指定父分类
  if (level !== 1 && !parsed.parentKey) {
    return { error: '二/三/四级分类必须选择父分类' };
  }
  // 一级分类的 parentKey 必须为 null
  if (level === 1 && parsed.parentKey) {
    return { error: '一级分类不能有父分类' };
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
 * @param parentKey 二三级分类需传入父分类 key 用于消歧（同名 key 可跨层级/父级重复）
 */
export async function updateCategory(key: string, formData: FormData, parentKey?: string | null) {
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
    await api.updateCategory(key, formData, parentKey ?? null);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }

  revalidatePath('/dashboard/categories');
  revalidatePath('/dashboard/templates');
  return { success: true };
}

export async function deleteCategory(key: string, parentKey?: string | null) {
  try {
    await api.deleteCategory(key, parentKey ?? null);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
  revalidatePath('/dashboard/categories');
  revalidatePath('/dashboard/templates');
  return { success: true };
}

export async function toggleCategoryActive(key: string, parentKey?: string | null) {
  try {
    const result = await api.toggleCategoryActive(key, parentKey ?? null);
    revalidatePath('/dashboard/categories');
    revalidatePath('/dashboard/templates');
    return { success: true, isActive: result.isActive };
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
}
