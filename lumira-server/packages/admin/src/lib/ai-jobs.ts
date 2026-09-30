// lumira-server/packages/admin/src/lib/ai-jobs.ts
// AI 生成任务队列：类型、状态展示映射、轮询客户端与产物取回。
import {
  aiJobListAction,
  aiJobDetailAction,
  aiJobStopAction,
  aiJobResumeAction,
  aiJobDeleteAction,
  aiJobsCleanupAction,
} from '@/actions/ai';

export type AiJobStatus = 'queued' | 'running' | 'done' | 'error' | 'stopped' | 'interrupted';
export type AiJobStage = 'analyze' | 'image' | 'silhouette';

export interface AiJobListItem {
  id: string;
  title: string;
  status: AiJobStatus;
  mode: 'auto' | 'analyze-only';
  currentStage: AiJobStage | null;
  progress: { poseTotal: number; poseDone: number; silTotal: number; silDone: number };
  queuePos: number;
  errorCode: string | null;
  errorMessage: string | null;
  createdAt: number;
  startedAt: number | null;
  finishedAt: number | null;
}

export interface AiJobDetail extends AiJobListItem {
  jobId: string;
  stages: Record<AiJobStage, { status: string; startedAt?: number; finishedAt?: number; error?: unknown }>;
  error: { code: string; message: string; stage?: AiJobStage; at?: number; hint?: string } | null;
  events: unknown[];
  lastSeq: number;
  draft: unknown | null;
  poseImages: Array<{ index: number; mimeType: string; storageKey: string; url: string }>;
  poseErrors: Array<{ index: number; error: string }>;
  silhouetteImages: Array<{ index: number; mimeType: string; storageKey: string; url: string }>;
  silhouetteErrors: Array<{ index: number; error: string }>;
  [key: string]: unknown;
}

export const JOB_STATUS_META: Record<AiJobStatus, { label: string; tone: 'run' | 'wait' | 'ok' | 'bad' }> = {
  queued: { label: '排队中', tone: 'wait' },
  running: { label: '进行中', tone: 'run' },
  done: { label: '已完成', tone: 'ok' },
  error: { label: '失败', tone: 'bad' },
  stopped: { label: '已停止', tone: 'bad' },
  interrupted: { label: '已中断', tone: 'bad' },
};

export const JOB_STAGE_LABEL: Record<AiJobStage, string> = {
  analyze: '识别',
  image: '姿势图',
  silhouette: '剪影',
};

export function isSettled(status: AiJobStatus): boolean {
  return status === 'done' || status === 'error' || status === 'stopped' || status === 'interrupted';
}

/** 列表右侧一行进度文案 */
export function jobStageProgressText(item: AiJobListItem): string {
  if (item.status === 'queued') return item.queuePos > 0 ? `排队中 · 第 ${item.queuePos} 位` : '排队中';
  if (item.status === 'done') {
    const parts: string[] = [];
    if (item.progress.poseDone) parts.push(`${item.progress.poseDone} 张姿势图`);
    if (item.progress.silDone) parts.push(`${item.progress.silDone} 张剪影`);
    return parts.length ? `已完成 · ${parts.join(' / ')}` : '已完成';
  }
  if (item.status === 'error' || item.status === 'stopped' || item.status === 'interrupted') {
    return item.currentStage ? `${JOB_STAGE_LABEL[item.currentStage]}阶段${JOB_STATUS_META[item.status].label}` : JOB_STATUS_META[item.status].label;
  }
  if (item.currentStage === 'image') {
    const total = Math.max(item.progress.poseTotal, 1);
    return `姿势图 ${Math.min(item.progress.poseDone + 1, total)}/${total}`;
  }
  if (item.currentStage === 'silhouette') {
    const total = Math.max(item.progress.silTotal, 1);
    return `剪影 ${Math.min(item.progress.silDone + 1, total)}/${total}`;
  }
  return '识别中';
}

/** 耗时文案：未开始 → 「—」；已结束 → 定格；进行中 → 实时（调用方按秒重渲染） */
export function formatJobElapsed(startedAt: number | null, finishedAt: number | null): string {
  if (!startedAt) return '—';
  const end = finishedAt ?? Math.floor(Date.now() / 1000);
  const sec = Math.max(0, end - startedAt);
  if (sec < 60) return `${sec}秒`;
  const min = Math.floor(sec / 60);
  if (min < 60) return `${min}分${sec % 60}秒`;
  return `${Math.floor(min / 60)}小时${min % 60}分`;
}

/** 按 URL 取回产物并包装为 File（供向导注入 TemplateForm；相对路径走 admin 代理） */
export async function fetchJobFile(url: string, name: string): Promise<File> {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`取回产物失败（HTTP ${res.status}）：${name}`);
  const blob = await res.blob();
  return new File([blob], name, { type: blob.type || 'image/png' });
}

export async function listAiJobs(params: { status?: AiJobStatus; limit?: number; offset?: number } = {}) {
  return aiJobListAction(params);
}

export async function getAiJobDetail(jobId: string, since = 0) {
  return aiJobDetailAction(jobId, since);
}

export async function stopAiJob(jobId: string) {
  return aiJobStopAction(jobId);
}

export async function resumeAiJob(jobId: string) {
  return aiJobResumeAction(jobId);
}

export async function deleteAiJob(jobId: string) {
  return aiJobDeleteAction(jobId);
}

export async function cleanupAiJobs() {
  return aiJobsCleanupAction();
}