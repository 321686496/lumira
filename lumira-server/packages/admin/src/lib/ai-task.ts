// 生图异步任务轮询工具（step-cover 手动生成 + wizard 全自动 复用）。
// 批量姿势图已改为「一次性提交 → 拿到单个 batchId → 只轮询一个批次进度接口」的架构，
// 后端在批次内维护 total/completed/current/status/results，前端据此实时展示「第 X/Y 张」。
import {
  aiAnalyzeStatusAction,
  aiGenerateImageBatchStartAction,
  aiGenerateImageBatchStatusAction,
  aiGenerateImageStatusAction,
  aiGenerateSilhouetteStatusAction,
} from '@/actions/ai';
import { aiGenerateSilhouetteStartAction } from '@/actions/ai';
import type {
  AiAnalyzeStatusResult,
  AiImageStatusResult,
  AiSilhouetteStatusResult,
  AiBatchStatusResult,
  AiBatchImageTraceEvent,
  AiResearchRef,
  AiResearchBrief,
  AiResearchVision,
  AiTraceEvent,
} from '@/types/admin';
import { compressImage } from '@/lib/image-compress';

/** 用户可读的错误（含超时 / 上游失败 / 任务不存在） */
export class AiTaskPollError extends Error {}

const DEFAULT_INTERVAL_MS = 2000;
const DEFAULT_TIMEOUT_MS = 600_000;
/** 单张姿势图「真正生成」超时上限：从该张「开始生成」事件起算，排队等待不计入。
 *  原实现从点击提交起算整个批次总时长（10 分钟），第 4 张排队 150s + 生成 60s 也会被
 *  误报「已运行 624.8s 超时」；改为逐张判定后，排队长/批次张数多不再误杀正常生成。 */
const BATCH_IMAGE_GEN_TIMEOUT_MS = 900_000;
/** 批次总预算兜底：从点击起算，仅防信号量死锁/全批卡死；对齐后端批次保留期（60 分钟） */
const BATCH_GLOBAL_BUDGET_MS = 3_600_000;
/** 识别任务总预算：链路含「评分→细化」最多 3 轮迭代且单次 LLM 调用可达 10 分钟，
 *  实测单轮 16~26 分钟、整体可达 40+ 分钟。前端预算必须覆盖后端任务保留期
 *  （后端 RESULT_TTL_MS = 60 分钟，超期任务会被清理），否则会出现「前端已放弃、
 *  后端仍在跑、结果取不回来」的错位 → 直接对齐 60 分钟。 */
const ANALYZE_TIMEOUT_MS = 3600_000;

function sleep(intervalMs: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, intervalMs));
}

/** 中止信号已触发时抛出统一的「已中止」错误（与超时 / 上游失败共用 AiTaskPollError） */
function throwIfAborted(signal?: AbortSignal): void {
  if (signal?.aborted) throw new AiTaskPollError('已中止');
}

/** 毫秒 → 人类可读时长（<1s 显示 ms） */
export function formatSec(ms: number): string {
  if (!Number.isFinite(ms) || ms < 0) return '?';
  if (ms < 1000) return `${Math.round(ms)}ms`;
  return `${(ms / 1000).toFixed(1)}s`;
}

/**
 * 轮询超时时，把仍处于「执行中/等待响应」的阶段与 LLM/检索调用合成 fail 事件，追加进事件流并回调，
 * 让过程面板即时把对应步骤/调用标记为失败（含耗时与原因），而不是永远停在「等待响应…」。
 * 合成顺序：先调用后阶段（父阶段尚未闭合 → 调用 fail 归位到对应阶段下被折叠配对，随后阶段 fail 闭合节点）。
 */
function synthesizeAnalyzeTimeout(events: AiTraceEvent[], errorText: string, nowTs: number): AiTraceEvent[] {
  const failEvents: AiTraceEvent[] = [];
  let seq = 1;
  if (events.length) seq = Math.max(...events.map((e) => e.seq)) + 1;
  const nextSeq = () => seq++;

  // 仍在飞行中的调用：running/pending 的 llm/search，且没有后续 done/fail 配对
  const inflight = new Map<string, AiTraceEvent>();
  const callKey = (ev: AiTraceEvent) => (ev.callId ? `id|${ev.callId}` : `${ev.type}|${ev.title}|${ev.model ?? ''}`);
  for (const ev of events) {
    if (ev.type !== 'llm' && ev.type !== 'search') continue;
    if (ev.status === 'running') inflight.set(callKey(ev), ev);
    else if (ev.status === 'done' || ev.status === 'fail') inflight.delete(callKey(ev));
  }

  // 仍开放中的阶段：running 无对应 done/fail（同阶段多轮迭代各计一次）
  const openStepCount = new Map<string, number>();
  for (const ev of events) {
    if (ev.type !== 'step') continue;
    if (ev.status === 'running') openStepCount.set(ev.step, (openStepCount.get(ev.step) ?? 0) + 1);
    else if (ev.status === 'done' || ev.status === 'fail') {
      const n = (openStepCount.get(ev.step) ?? 0) - 1;
      if (n > 0) openStepCount.set(ev.step, n);
      else openStepCount.delete(ev.step);
    }
  }
  const stepRuns = events.filter((e) => e.type === 'step' && e.status === 'running');

  for (const ev of inflight.values()) {
    failEvents.push({
      seq: nextSeq(),
      ts: nowTs,
      type: ev.type === 'search' ? 'search' : 'llm',
      step: ev.step,
      parentStep: ev.parentStep,
      callId: ev.callId,
      title: ev.title,
      model: ev.model,
      status: 'fail',
      error: errorText,
      durationMs: nowTs - ev.ts,
    });
  }
  // 阶段 fail 从最近一次运行开始闭合（与 buildTimeline「从尾找最近开放同名节点」的顺序一致）
  const remaining = new Map(openStepCount);
  for (let i = stepRuns.length - 1; i >= 0; i--) {
    const run = stepRuns[i];
    const open = remaining.get(run.step);
    if (!open) continue;
    remaining.set(run.step, open - 1);
    failEvents.push({
      seq: nextSeq(),
      ts: nowTs,
      type: 'step',
      step: run.step,
      parentStep: run.parentStep,
      title: run.title,
      status: 'fail',
      error: errorText,
      durationMs: nowTs - run.ts,
    });
  }
  return failEvents;
}

export interface AiTaskFileResult {
  index: number;
  file?: File;
  error?: string;
}

/** 实时进度（第 current/total 张、是否处理完毕 status） */
export interface AiPoseProgress {
  current: number;
  total: number;
  status: 'pending' | 'running' | 'done' | 'error';
}

export function base64ToFile(b64: string, mime: string, name: string): File {
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return new File([bytes], name, { type: mime });
}

/** 生成姿势图：一次性提交 → 后端返回单个 batchId → 只轮询 GET batch/:batchId，实时回调进度。 */
export function generateAiPoseImages(options: {
  draft: Record<string, unknown>;
  /** 姿势参考图（可多张）：第一张作为图生图直接锚点，全部参考图另交由图片识别大模型识别后注入提示词 */
  referenceFiles?: File[];
  extraPrompt?: string | null;
  /** 识别阶段的网络趋势研究结果（透传给后端生图提示词组织器，与草稿同源保持一致） */
  research?: AiResearchRef[] | null;
  /** 趋势研究结构化结论（与 items 同源，透传给后端生图提示词组织器） */
  researchBrief?: AiResearchBrief | null;
  /** 参考图多模态解读结论（透传给后端生图提示词组织器，渲染为文本参考） */
  researchVision?: AiResearchVision | null;
  /** 中止信号：命中后抛 AiTaskPollError('已中止')，仅供前端停止等待（不取消服务端任务） */
  signal?: AbortSignal;
  onResult?: (result: AiTaskFileResult) => void;
  onProgress?: (progress: AiPoseProgress) => void;
  /** 逐张实时过程事件（按 seq 增量累积；用于可溯源的姿势图过程展示） */
  onEvents?: (events: AiBatchImageTraceEvent[]) => void;
}): Promise<AiTaskFileResult[]> {
  const { draft, referenceFiles, extraPrompt, research, researchBrief, researchVision, signal, onResult, onProgress, onEvents } = options;
  return (async () => {
    throwIfAborted(signal);
    const fd = new FormData();
    fd.set('meta', JSON.stringify({
      ...draft,
      consistency: { mode: 'strict' },
    }));
    for (const referenceFile of referenceFiles ?? []) fd.append('reference', referenceFile);
    const extra = typeof extraPrompt === 'string' ? extraPrompt.trim() : '';
    if (extra) fd.set('extraPrompt', extra);
    if ((research && research.length > 0) || researchBrief || researchVision) {
      fd.set('research', JSON.stringify({
        items: research ?? [],
        brief: researchBrief ?? null,
        vision: researchVision ?? null,
      }));
    }

    const started = await aiGenerateImageBatchStartAction(fd);
    if ('error' in started) throw new AiTaskPollError(started.error || '生成任务提交失败');
    const batchId = started.batchId;

    const onResultFile = new Set<number>();
    let since = 0;
    const trace: AiBatchImageTraceEvent[] = [];
    const startedAt = Date.now();
    const budgetDeadline = startedAt + BATCH_GLOBAL_BUDGET_MS;
    const emitProgress = (res: AiBatchStatusResult) =>
      onProgress?.({ current: res.current, total: res.total, status: res.status });
    /** 按 index 聚合姿势图生命周期事件 */
    const groupByIndex = (): Map<number, AiBatchImageTraceEvent[]> => {
      const m = new Map<number, AiBatchImageTraceEvent[]>();
      for (const ev of trace) {
        if (ev.kind && ev.kind !== 'pose') continue;
        const list = m.get(ev.index) ?? [];
        list.push(ev);
        m.set(ev.index, list);
      }
      return m;
    };
    /** 已按「单张真实生成超时」判定并合成 error 的 index（避免重复合成） */
    const genTimedOut = new Set<number>();

    while (Date.now() < budgetDeadline) {
      throwIfAborted(signal);
      const res = await aiGenerateImageBatchStatusAction(batchId, since);
      if ('error' in res) throw new AiTaskPollError(res.error || '查询生成任务失败');
      // 增量吸收实时过程事件（按 seq 去重）
      if ((res as AiBatchStatusResult).events?.length) {
        since = (res as AiBatchStatusResult).lastSeq ?? since;
        trace.push(...(res as AiBatchStatusResult).events!);
        onEvents?.(trace.slice());
      }
      emitProgress(res);

      // 逐张真实生成超时判定：仅对「已真正开始生成」且未结束的张计时；排队阶段不计入，避免误杀
      let synthesized = false;
      const now = Date.now();
      for (const [index, evs] of groupByIndex()) {
        if (genTimedOut.has(index)) continue;
        const last = evs[evs.length - 1]!;
        if (last.status !== 'pending' && last.status !== 'running') continue;
        const genStart = evs.find((e) => e.status === 'running');
        if (!genStart) continue; // 仍在排队等待额度：不消耗生成超时预算，继续等待
        const genMs = Math.max(0, now - genStart.ts);
        if (genMs <= BATCH_IMAGE_GEN_TIMEOUT_MS) continue;
        const queueStart = evs.find((e) => e.status === 'pending');
        const queueMs = queueStart ? Math.max(0, genStart.ts - queueStart.ts) : 0;
        genTimedOut.add(index);
        synthesized = true;
        trace.push({
          seq: (trace.length ? Math.max(...trace.map((e) => e.seq)) : 0) + 1,
          ts: now,
          index,
          title: `姿势图 #${index + 1}`,
          status: 'error',
          error: `生成超时：本张已生成 ${formatSec(genMs)}（排队 ${formatSec(queueMs)}），超过单张生成上限 ${Math.round(BATCH_IMAGE_GEN_TIMEOUT_MS / 60000)} 分钟，生图模型未返回`,
          durationMs: genMs,
        });
      }
      if (synthesized) onEvents?.(trace.slice());

      // 逐张实时回报已完成的姿势图
      for (const item of res.results ?? []) {
        if (!onResultFile.has(item.index) && item.status === 'done' && item.image && item.mimeType) {
          onResultFile.add(item.index);
          onResult?.({ index: item.index, file: base64ToFile(item.image, item.mimeType, `ai-pose-${Date.now()}-${item.index}.png`) });
        }
      }

      if (res.status === 'done') {
        return (res.results ?? []).map((item) => {
          if (item.status === 'done' && item.image && item.mimeType) {
            return { index: item.index, file: base64ToFile(item.image, item.mimeType, `ai-pose-${Date.now()}-${item.index}.png`) };
          }
          return { index: item.index, error: item.error || '姿势图生成失败' };
        });
      }
      await sleep(DEFAULT_INTERVAL_MS);
    }
    // —— 全局兜底：批次从点击起算超总预算（60 分钟，仅防全批卡死/信号量死锁），
    //     把剩余未完成（含仍在排队）合成 error 并抛出 ——
    const now = Date.now();
    const elapsedMs = now - startedAt;
    const budgetMin = Math.round(BATCH_GLOBAL_BUDGET_MS / 60000);
    const unfinished: number[] = [];
    let queuedStill = 0;
    for (const [index, evs] of groupByIndex()) {
      if (genTimedOut.has(index)) continue;
      const last = evs[evs.length - 1]!;
      if (last.status !== 'pending' && last.status !== 'running') continue;
      unfinished.push(index);
      const genStart = evs.find((e) => e.status === 'running');
      const queueStart = evs.find((e) => e.status === 'pending');
      if (!genStart) queuedStill += 1;
      const queueMs = genStart && queueStart ? Math.max(0, genStart.ts - queueStart.ts) : queueStart ? Math.max(0, now - queueStart.ts) : undefined;
      const genMs = genStart ? Math.max(0, now - genStart.ts) : undefined;
      trace.push({
        seq: (trace.length ? Math.max(...trace.map((e) => e.seq)) : 0) + 1,
        ts: now,
        index,
        title: `姿势图 #${index + 1}`,
        status: 'error',
        error: genStart
          ? `批次总时长超 ${budgetMin} 分钟：本张已生成 ${formatSec(genMs!)}（排队 ${queueMs ? formatSec(queueMs) : '0s'}），生图模型未返回`
          : `批次总时长超 ${budgetMin} 分钟：本张仍在排队等待生图额度（已等 ${queueMs ? formatSec(queueMs) : '…'}），生图模型未返回`,
        durationMs: genMs ?? elapsedMs,
      });
    }
    onEvents?.(trace.slice());
    const breakdown = `有 ${unfinished.length} 张姿势图未完成（其中排队中 ${queuedStill} 张、生成中 ${unfinished.length - queuedStill} 张；批次已耗时 ${formatSec(elapsedMs)}）`;
    throw new AiTaskPollError(
      `生成超时：批次已运行 ${formatSec(elapsedMs)}，超过总时长上限 ${budgetMin} 分钟（单张生成超时上限 ${Math.round(BATCH_IMAGE_GEN_TIMEOUT_MS / 60000)} 分钟，排队不计入）。${breakdown}。` +
        `常见原因：生图模型响应过慢或批量排队积压；可稍后重试，或检查「AI 设置」中的生图模型。`,
    );
  })();
}

/** 并行提交剪影任务，并分别轮询到完成；结果保持源图顺序。 */
export function generateAiSilhouettes(options: {
  images: File[];
  mode: 'sketch' | 'solid';
  crop: boolean;
  engine: 'ai' | 'local';
  /** 中止信号：命中后每张任务抛出「已中止」，聚合结果按 error 返回 */
  signal?: AbortSignal;
  onCompleted?: (completed: number) => void;
}): Promise<AiTaskFileResult[]> {
  const { images, mode, crop, engine, signal, onCompleted } = options;
  const generated = new Array<File | undefined>(images.length).fill(undefined);
  const publish = () => onCompleted?.(generated.filter(Boolean).length);

  return (async () => Promise.all(images.map(async (image, index) => {
    try {
      throwIfAborted(signal);
      const source = await compressImage(image, { maxDim: 640, quality: 0.6 });
      const fd = new FormData();
      fd.set('image', source);
      fd.set('meta', JSON.stringify({ mode, crop, engine }));
      const start = await aiGenerateSilhouetteStartAction(fd);
      if (!start || 'error' in start) throw new Error(start?.error || '剪影任务提交失败');
      const result = await pollAiSilhouetteTask(start.taskId);
      const file = base64ToFile(result.image!, result.mimeType!, `ai-silhouette-${Date.now()}-${index}.png`);
      generated[index] = file;
      publish();
      return { index, file };
    } catch (err) {
      return { index, error: (err as Error).message || '剪影生成失败' };
    }
  })))();
}

export interface AiTaskPollOptions {
  intervalMs?: number;
  timeoutMs?: number;
}

/**
 * 轮询直到任务完成：
 * - done → resolve(结果，含 image/mimeType)
 * - error / 状态查询失败 / 超时 → reject(AiTaskPollError)
 * - pending/running → 继续；onTick 可选回调暴露最新状态
 */
export function pollAiImageTask(
  taskId: string,
  options: AiTaskPollOptions = {},
  onTick?: (status: AiImageStatusResult['status']) => void,
): Promise<AiImageStatusResult> {
  const { intervalMs = DEFAULT_INTERVAL_MS, timeoutMs = DEFAULT_TIMEOUT_MS } = options;
  const deadline = Date.now() + timeoutMs;

  return (async () => {
    while (Date.now() < deadline) {
      const res = await aiGenerateImageStatusAction(taskId);
      if ('error' in res) throw new AiTaskPollError(res.error || '查询生图任务失败');
      if (res.status === 'done') return res;
      if (res.status === 'error') throw new AiTaskPollError(res.error || '生图失败，请重试');
      onTick?.(res.status);
      await sleep(intervalMs);
    }
    throw new AiTaskPollError('生成超时，请稍后重试');
  })();
}

/** 轮询剪影异步任务直到完成，避免同步请求被网关 504 掐断。 */
export function pollAiSilhouetteTask(
  taskId: string,
  options: AiTaskPollOptions = {},
  onTick?: (status: AiSilhouetteStatusResult['status']) => void,
): Promise<AiSilhouetteStatusResult> {
  const { intervalMs = DEFAULT_INTERVAL_MS, timeoutMs = DEFAULT_TIMEOUT_MS } = options;
  const deadline = Date.now() + timeoutMs;

  return (async () => {
    while (Date.now() < deadline) {
      const res = await aiGenerateSilhouetteStatusAction(taskId);
      if (!res || 'error' in res) {
        throw new AiTaskPollError((res as { error?: string } | undefined)?.error || '查询剪影任务失败');
      }
      if (res.status === 'done') return res;
      if (res.status === 'error') throw new AiTaskPollError(res.error || '剪影生成失败，请重试');
      onTick?.(res.status);
      await sleep(intervalMs);
    }
    throw new AiTaskPollError('剪影生成超时，请稍后重试');
  })();
}

/**
 * 轮询 AI 识别异步任务直到完成，避免同步请求被网关 504 掐断。done → {draft/warnings}；error/超时 reject AiTaskPollError。
 * 传入 options.onEvents 时，按 since 增量拉取流程事件并累积后回调（后台据此实时渲染"走到哪一步 / 提示词 / 响应"）；
 * done 时返回体带上完整 events，供结束后回看整个过程。
 */
export function pollAiAnalyzeTask(
  taskId: string,
  options: AiTaskPollOptions & {
    onEvents?: (events: AiTraceEvent[]) => void;
    /** 中止信号：命中后 reject AiTaskPollError('已中止') */
    signal?: AbortSignal;
  } = {},
  onTick?: (status: AiAnalyzeStatusResult['status']) => void,
): Promise<AiAnalyzeStatusResult> {
  const { intervalMs = DEFAULT_INTERVAL_MS, timeoutMs = ANALYZE_TIMEOUT_MS, onEvents, signal } = options;
  const startedAt = Date.now();
  const deadline = startedAt + timeoutMs;
  let since = 0;
  const events: AiTraceEvent[] = [];

  /** 拉取到的增量事件追加进累积列表并回调（去重靠后端 seq 递进） */
  const absorb = (res: AiAnalyzeStatusResult) => {
    if (!res.events?.length) return;
    since = res.lastSeq ?? since;
    events.push(...res.events);
    onEvents?.(events.slice());
  };

  return (async () => {
    while (Date.now() < deadline) {
      throwIfAborted(signal);
      const res = await aiAnalyzeStatusAction(taskId, since);
      if (!res || 'error' in res) {
        throw new AiTaskPollError((res as { error?: string } | undefined)?.error || '查询识别任务失败');
      }
      absorb(res);
      if (res.status === 'done') return { ...res, events };
      if (res.status === 'error') {
        throw new AiTaskPollError(res.error || '识别失败，请重试');
      }
      onTick?.(res.status);
      await sleep(intervalMs);
    }
    // —— 超时：把过程面板上仍「执行中/等待响应」的阶段与调用标记为失败，并抛出带明细的报错 ——
    const now = Date.now();
    const elapsedMs = now - startedAt;
    const budgetMin = Math.round(timeoutMs / 60000);
    const lastRunning = [...events].reverse().find((e) => e.type === 'step' && e.status === 'running');
    const where = lastRunning ? `「${lastRunning.title}」阶段` : '识别流程中间';
    const scopeError = `超时：已运行 ${formatSec(elapsedMs)}，超过识别超时上限 ${budgetMin} 分钟，上游未在预算内返回`;
    const synthesized = synthesizeAnalyzeTimeout(events, scopeError, now);
    if (synthesized.length) {
      events.push(...synthesized);
      onEvents?.(events.slice());
    }
    const stepDetail = lastRunning ? `，其中「${lastRunning.title}」已运行 ${formatSec(now - lastRunning.ts)}` : '';
    throw new AiTaskPollError(
      `识别超时：停在${where}，整体已耗时 ${formatSec(elapsedMs)}${stepDetail}（识别超时上限 ${budgetMin} 分钟）。` +
        `常见原因：该阶段上游 LLM 响应过慢、多轮「评分→细化」迭代耗时叠加或网络波动；` +
        `可调大「AI 设置 → 识别稳定性」中的单次 LLM 超时后重试。`,
    );
  })();
}
