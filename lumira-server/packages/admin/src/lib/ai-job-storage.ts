// src/lib/ai-job-storage.ts
// 在浏览器 localStorage 记一个「进行中的 AI 流水线 job」引用，供页面刷新后恢复/续跑。
// 单键设计：同一时间只允许一个进行中的 job（换图/重开流程会覆盖）。
'use client';

import type { AiPipelineJobMode } from '@/types/admin';

const STORAGE_KEY = 'lumira.aiCreateJob';

export interface AiJobRef {
  jobId: string;
  mode: AiPipelineJobMode;
  savedAt: number;
}

export function saveJobRef(ref: { jobId: string; mode: AiPipelineJobMode }): void {
  if (typeof window === 'undefined') return;
  try {
    const payload: AiJobRef = { ...ref, savedAt: Date.now() };
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(payload));
  } catch {
    // 隐私模式/配额满：忽略（刷新恢复是增强，不影响主流程）
  }
}

export function readJobRef(): AiJobRef | null {
  if (typeof window === 'undefined') return null;
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as Partial<AiJobRef>;
    if (typeof parsed?.jobId !== 'string' || !parsed.jobId) return null;
    return {
      jobId: parsed.jobId,
      mode: parsed.mode === 'analyze-only' ? 'analyze-only' : 'auto',
      savedAt: typeof parsed.savedAt === 'number' ? parsed.savedAt : Date.now(),
    };
  } catch {
    return null;
  }
}

export function clearJobRef(): void {
  if (typeof window === 'undefined') return;
  try {
    window.localStorage.removeItem(STORAGE_KEY);
  } catch {
    // 忽略
  }
}