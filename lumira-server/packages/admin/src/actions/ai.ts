// src/actions/ai.ts
// AI 一键模板录入 server actions（薄封装：调 api → 错误转 { error }，成功原样返回）
// 不 revalidatePath：AI 生成过程不涉及列表页缓存（模板创建仍走 actions/templates.ts）

'use server';

import { redirect } from 'next/navigation';
import { api } from '@/lib/api';
import { UnauthenticatedError } from '@/lib/auth';
import type {
  AiProviderConfigView,
  UpdateAiConfigPayload,
  AiConfigTestResult,
  AiAnalyzeResult,
  AiImageResult,
} from '@/types/admin';

export async function getAiConfigAction(): Promise<
  AiProviderConfigView | { configured: false }
> {
  try {
    return await api.getAiConfig();
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    // 未配置时后端返回 { configured: false }，不是错误；此处兜底其他异常
    return { configured: false };
  }
}

export async function saveAiConfigAction(
  payload: UpdateAiConfigPayload,
): Promise<{ ok: true; config: AiProviderConfigView } | { error: string }> {
  try {
    const config = await api.saveAiConfig(payload);
    return { ok: true, config };
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
}

export async function testAiConfigAction(): Promise<
  AiConfigTestResult | { error: string }
> {
  try {
    return await api.testAiConfig();
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
}

/** formData：image 文件（示例图） */
export async function aiAnalyzeAction(
  formData: FormData,
): Promise<AiAnalyzeResult | { error: string }> {
  try {
    return await api.aiAnalyze(formData);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
}

/** formData：meta 草稿 JSON 文本 + reference 参考图（可选） */
export async function aiGenerateImageAction(
  formData: FormData,
): Promise<AiImageResult | { error: string }> {
  try {
    return await api.aiGenerateImage(formData);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
}

/** formData：image 文件 + meta JSON（{ mode, crop }，可选） */
export async function aiGenerateSilhouetteAction(
  formData: FormData,
): Promise<AiImageResult | { error: string }> {
  try {
    return await api.aiGenerateSilhouette(formData);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
}
