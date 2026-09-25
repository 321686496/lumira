// lumira-server/packages/backend/src/modules/ai/llm-trace.ts
// AI 识别流程的实时轨迹采集：把「走到哪一步 / 该步提示词 / 模型响应」按发生顺序记成事件流，
// 由 ai-analyze-task 的任务对象持有，后台轮询增量拉取并像聊天一样实时渲染。
//
// 实现方式：AsyncLocalStorage 存「当前任务的 sink + 当前阶段」，各层（llm-client / 检索 /
// 编排 / 识别服务）只调用 traceStep / traceLlmCall / traceSearchCall，无需改服务签名。
// 未开启采集上下文（定时任务、单测、其它调用方）时全部 no-op，零副作用。

import { AsyncLocalStorage } from 'node:async_hooks';

export type AiTraceEventType = 'step' | 'llm' | 'search' | 'note';
export type AiTraceEventStatus = 'running' | 'done' | 'fail';

/** 一条流程事件（展示单位：阶段或一次 LLM/检索调用） */
export interface AiTraceEvent {
  /** 递增序号（前端按 since 增量拉取与去重） */
  seq: number;
  /** 记录时间（ms epoch） */
  ts: number;
  type: AiTraceEventType;
  /** 阶段标识：reorganize / researchDigest / research / analyze / describe / poseRefSheet / paramValidate / imageScore / draftRefine / finalize */
  step: string;
  /** 阶段中文名（后台直接展示） */
  title: string;
  /** 所属父阶段标识（无嵌套时缺省）；后台据此渲染嵌套时间线，避免父子被拍平成同级导致因果倒置 */
  parentStep?: string;
  /** 一次调用的关联标识（仅 llm/search）：并发同名调用的 running/done 靠它精确配对，不靠标题 */
  callId?: string;
  status: AiTraceEventStatus;
  /** LLM 模型名 / 检索来源名 */
  model?: string;
  /** 请求：system 提示词 */
  systemPrompt?: string;
  /** 请求：user 提示词（含图时图中内容不展开） */
  userPrompt?: string;
  /** 附带图片时的字节数（提示词不展示 base64） */
  imageBytes?: number;
  /** 响应正文（LLM 原始输出 / 检索综述 / 命中摘要） */
  response?: string;
  /** 上游**原始响应体全文**（LLM 为原始 JSON 文本；检索为原始返回），与 response 并列展示 */
  rawResponse?: string;
  /** 实际发出的请求次数（含 jsonMode 降级 / 5xx 重试；1 表示一次成功） */
  attempts?: number;
  /** 阶段结论简述（条数、是否跳过、校验结果等） */
  resultBrief?: string;
  /** 失败原因 */
  error?: string;
  /** 耗时（ms；running 事件无此字段） */
  durationMs?: number;
}

/** 事件收集回调（由识别任务注入：分配 seq/ts 并追加到任务） */
export type TraceSink = (ev: Omit<AiTraceEvent, 'seq' | 'ts'>) => void;

interface TraceStore {
  sink: TraceSink;
  /** 打开中的阶段栈（LIFO）：栈顶即当前阶段，也是嵌套事件的 parentStep 来源 */
  stack: { step: string; title: string }[];
}

const storage = new AsyncLocalStorage<TraceStore>();

/** 栈顶阶段（未打开任何阶段返回 undefined） */
function topStep(): { step: string; title: string } | undefined {
  const stack = storage.getStore()?.stack;
  return stack && stack.length ? stack[stack.length - 1] : undefined;
}

/** 单个字段（提示词 / 响应 / 原始响应体）保留上限：够看全内容，又不让任务对象被超长文本撑爆 */
export const TRACE_TEXT_CAP = 50_000;

/** 截断超长文本并标注（不静默丢内容） */
function capText(text: string | undefined, cap = TRACE_TEXT_CAP): string | undefined {
  if (typeof text !== 'string') return undefined;
  if (text.length <= cap) return text;
  return `${text.slice(0, cap)}\n…（已截断，原长 ${text.length} 字）`;
}

/** 在该 sink 的采集上下文内执行；嵌套调用沿用最外层上下文 */
export function runWithTrace<T>(sink: TraceSink, fn: () => Promise<T>): Promise<T> {
  return storage.run({ sink, stack: [] }, fn);
}

/** 是否有采集上下文（少数需要预先判断的场景） */
export function hasTrace(): boolean {
  return Boolean(storage.getStore());
}

/** 当前阶段（无上下文返回 undefined） */
export function currentTraceStep(): { step: string; title: string } | undefined {
  return topStep();
}

/** 记录一条独立事件（如「任务已提交」「定稿完成」）；有打开中的阶段时归属其下 */
export function traceNote(step: string, title: string, resultBrief?: string): void {
  const store = storage.getStore();
  if (!store) return;
  store.sink({ type: 'note', step, title, parentStep: topStep()?.step, status: 'done', resultBrief });
}

/**
 * 记录一个阶段的开始/结束（异常也记录 fail 后原样抛出）。
 * 有打开中的阶段时，本阶段记为它的子阶段（parentStep）——后台据此渲染嵌套时间线。
 * 无采集上下文时等价于直接执行 fn（零额外开销）。
 */
export async function traceStep<T>(
  step: string,
  title: string,
  fn: () => Promise<T>,
  brief?: (value: T) => string,
): Promise<T> {
  const store = storage.getStore();
  if (!store) return fn();

  const parentStep = topStep()?.step;
  store.stack.push({ step, title });
  const startedAt = Date.now();
  store.sink({ type: 'step', step, title, parentStep, status: 'running' });
  try {
    const value = await fn();
    store.sink({
      type: 'step',
      step,
      title,
      parentStep,
      status: 'done',
      resultBrief: brief?.(value),
      durationMs: Date.now() - startedAt,
    });
    return value;
  } catch (err) {
    store.sink({
      type: 'step',
      step,
      title,
      parentStep,
      status: 'fail',
      error: err instanceof Error ? err.message : String(err),
      durationMs: Date.now() - startedAt,
    });
    throw err;
  } finally {
    // 弹出本阶段：正常路径下栈顶即自身（嵌套时内层已先弹出）；异常路径按最后一次同名项移除，
    // 避免残留导致后续 parentStep 错乱。
    const top = store.stack[store.stack.length - 1];
    if (top && top.step === step) {
      store.stack.pop();
    } else {
      const last = store.stack.map((s) => s.step).lastIndexOf(step);
      if (last >= 0) store.stack.splice(last, 1);
    }
  }
}

/** 一次调用（LLM / 检索）的完成句柄；无采集上下文时为 null */
export interface TraceCallHandle {
  done(response?: string, extra?: { resultBrief?: string; rawResponse?: string; attempts?: number }): void;
  fail(err: unknown): void;
}

interface TraceCallInput {
  type: 'llm' | 'search';
  title: string;
  model?: string;
  systemPrompt?: string;
  userPrompt?: string;
  imageBytes?: number;
}

/** 单次调用关联 id 计数（模块级递增 → 同一进程内唯一，批次流并行多张图也不会撞号） */
let callSeq = 0;

/** 开始记录一次外部调用（提示词在开始时就记下，响应在完成时补记） */
function startCall(input: TraceCallInput): TraceCallHandle | null {
  const store = storage.getStore();
  if (!store) return null;
  const current = topStep();
  const step = current?.step ?? 'call';
  const title = input.title || current?.title || input.title;
  // 并发同名调用（如同一来源的多组短查询并行检索）标题完全相同，靠 callId 才能把
  // 各自的 running 与 done 精确配上，避免响应被错配或占位被丢弃。
  const callId = `c${(callSeq += 1)}`;
  const startedAt = Date.now();
  store.sink({
    type: input.type,
    step,
    title,
    parentStep: current?.step,
    callId,
    status: 'running',
    model: input.model,
    systemPrompt: capText(input.systemPrompt),
    userPrompt: capText(input.userPrompt),
    imageBytes: input.imageBytes,
  });
  return {
    done(response, extra) {
      store.sink({
        type: input.type,
        step,
        title,
        parentStep: current?.step,
        callId,
        status: 'done',
        model: input.model,
        response: capText(response),
        rawResponse: capText(extra?.rawResponse),
        attempts: extra?.attempts,
        resultBrief: extra?.resultBrief,
        durationMs: Date.now() - startedAt,
      });
    },
    fail(err) {
      store.sink({
        type: input.type,
        step,
        title,
        parentStep: current?.step,
        callId,
        status: 'fail',
        model: input.model,
        error: err instanceof Error ? err.message : String(err),
        durationMs: Date.now() - startedAt,
      });
    },
  };
}

/** 记录一次 LLM 调用（llm-client 内调用） */
export function traceLlmCall(input: {
  model: string;
  systemPrompt?: string;
  userPrompt?: string;
  imageBytes?: number;
  title?: string;
}): TraceCallHandle | null {
  const stepTitle = currentTraceStep()?.title;
  return startCall({
    type: 'llm',
    title: input.title || (stepTitle ? `${stepTitle} · LLM` : `LLM · ${input.model}`),
    model: input.model,
    systemPrompt: input.systemPrompt,
    userPrompt: input.userPrompt,
    imageBytes: input.imageBytes,
  });
}

/** 记录一次联网检索调用（检索适配器内调用） */
export function traceSearchCall(input: {
  title: string;
  model?: string;
  query: string;
}): TraceCallHandle | null {
  return startCall({ type: 'search', title: input.title, model: input.model, userPrompt: input.query });
}