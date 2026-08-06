// src/actions/templates.ts
'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';

/**
 * 创建模板。formData 字段：
 *   - meta: JSON string (CreateTemplateRequest)
 *   - cover: File (必填)
 *   - silhouette: File (可选)
 * 注意：.pptpl 原始文件不随此提交上传（内容已在客户端解析填充进 meta），
 * 避免触发 Vercel Serverless 4.5MB 请求体限制。
 */
export async function createTemplate(formData: FormData) {
  // 基础校验：cover 必填
  const cover = formData.get('cover');
  if (!cover || !(cover instanceof File) || cover.size === 0) {
    return { error: '请上传封面图片' };
  }
  const meta = formData.get('meta');
  if (!meta || typeof meta !== 'string') {
    return { error: '缺少模板元数据 (meta)' };
  }
  try {
    JSON.parse(meta); // 仅校验是否合法 JSON
  } catch {
    return { error: '模板元数据 (meta) 不是合法 JSON' };
  }

  try {
    await api.createTemplate(formData);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }

  revalidatePath('/dashboard/templates');
  redirect('/dashboard/templates');
}

/**
 * 更新模板。formData 字段同 createTemplate，但 cover / silhouette 均可选。
 */
export async function updateTemplate(id: string, formData: FormData) {
  const meta = formData.get('meta');
  if (!meta || typeof meta !== 'string') {
    return { error: '缺少模板元数据 (meta)' };
  }
  try {
    JSON.parse(meta);
  } catch {
    return { error: '模板元数据 (meta) 不是合法 JSON' };
  }

  try {
    await api.updateTemplate(id, formData);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }

  revalidatePath('/dashboard/templates');
  revalidatePath(`/dashboard/templates/${id}`);
  redirect('/dashboard/templates');
}

export async function deleteTemplate(id: string) {
  try {
    await api.deleteTemplate(id);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
  revalidatePath('/dashboard/templates');
  return { success: true };
}

export async function toggleTemplateActive(id: string) {
  try {
    const result = await api.toggleTemplateActive(id);
    revalidatePath('/dashboard/templates');
    revalidatePath(`/dashboard/templates/${id}`);
    return { success: true, isActive: result.isActive };
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
}
