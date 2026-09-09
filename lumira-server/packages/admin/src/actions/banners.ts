// src/actions/banners.ts
'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { api } from '../lib/api';
import { UnauthenticatedError } from '../lib/auth';
import type { BannerPayload } from '../types/admin';

/** 新建 / 编辑运营 Banner（id 为 null 时新建） */
export async function saveBanner(id: string | null, payload: BannerPayload) {
  try {
    if (id) await api.updateBanner(id, payload);
    else await api.createBanner(payload);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
  revalidatePath('/dashboard/banners');
  return { success: true };
}

export async function removeBanner(id: string) {
  try {
    await api.deleteBanner(id);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
  revalidatePath('/dashboard/banners');
  return { success: true };
}

export async function setBannerActive(id: string) {
  try {
    const result = await api.toggleBanner(id);
    revalidatePath('/dashboard/banners');
    return { success: true, isActive: result.isActive };
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
}

/** 上传 Banner 配图（选中即传，与保存解耦；返回后端可访问的完整 URL） */
export async function uploadBannerImage(formData: FormData) {
  try {
    return await api.uploadBannerImage(formData);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
}
