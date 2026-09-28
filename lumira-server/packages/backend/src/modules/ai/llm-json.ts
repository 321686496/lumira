// lumira-server/packages/backend/src/modules/ai/llm-json.ts
// 识别链路 JSON 结构化输出的容错封装：调用 → extractJson → 按失败原因有界重试。
// 设计文档：docs/superpowers/specs/2026-09-28-ai-llm-json-resilience-design.md
//
// 重试只针对「可恢复」失败：JSON 解析失败（含截断）/ 超时 / HTTP 5xx / 空输出；
// 鉴权与请求错误（401/403/400/404）原样抛出，不做无意义重试。
// 每次尝试都会经 visionChat / textChat 落一条 llm 事件，实时过程面板因此天然可见。

import { textChat, visionChat, type LlmEndpoint } from './llm-client';
import { chatWithTools } from './tools/text-tool-loop';
import type { TextToolContext } from './tools/text-tool-loop';
import { extractJson } from './normalize';
import { traceNote } from './llm-trace';

/** 识别链路稳定性运行时参数（来自 AiConfigService.getActiveConfig().runtime） */
export interface LlmJsonRuntime {
  /** 失败后额外重试次数（0 = 不重试） */
  retryCount: number;
  /** 单次调用超时（毫秒） */
  timeoutMs: number;
  /** 单次输出 token 上限 */
  maxTokens: number;
}

/** JSON 识别调用输入（不含图；visionChatJson 额外要求图字段） */
export interface JsonChatInput {
  systemPrompt: string;
  userText: string;
  temperature?: number;
  /** 覆盖 runtime.timeoutMs */
  timeoutMs?: number;
  /** 覆盖 runtime.maxTokens */
  maxTokens?: number;
  /** 文本模型工具上下文（可选；缺省 = 无工具，行为与旧版一致） */
  ctx?: TextToolContext;
}

/** JSON 识别最终失败（重试已用尽） */
export class LlmJsonError extends Error {}

/** 重试时追加的纠正指令：明确要求完整、可解析、不截断 */
const REPAIR_INSTRUCTION =
  '【重要】上一次输出不是合法 JSON（可能被截断或夹带了额外文字）。请重新输出：只输出一个完整的、可被 JSON.parse 解析的 JSON 对象；不要 markdown 代码块、不要解释、不要省略、不要截断。';

/** 重试退避（毫秒） */
const RETRY_BACKOFF_MS = 800;

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** 可重试失败判定：超时 / 连接失败 / 5xx / 空输出（鉴权与 4xx 不重试） */
function isRetryableMessage(message: string): boolean {
  return /超时/.test(message)
    || /无法连接/.test(message)
    || /返回内容为空/.test(message)
    || /HTTP 5\d\d/.test(message);
}

/**
 * 统一的 JSON 重试循环：callChat 接收本轮 userText（首轮为原文，重试追加纠正指令）。
 * 解析失败与可重试错误计入重试；其余错误立即抛出。
 */
export async function runJsonChat(
  runtime: LlmJsonRuntime,
  callChat: (userText: string) => Promise<string>,
  baseUserText: string,
): Promise<Record<string, unknown>> {
  const total = Math.max(0, Math.floor(runtime.retryCount)) + 1;
  let lastReason = '未知原因';

  for (let attempt = 0; attempt < total; attempt += 1) {
    const userText = attempt === 0 ? baseUserText : `${baseUserText}\n\n${REPAIR_INSTRUCTION}`;
    try {
      const content = await callChat(userText);
      const json = extractJson(content);
      if (json) return json;
      lastReason = '输出不是合法 JSON';
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      if (!isRetryableMessage(message)) throw err;
      lastReason = message;
    }

    const next = attempt + 1;
    if (next < total) {
      traceNote('jsonRetry', `JSON 输出不可用，重试 ${next}/${total - 1}`, lastReason);
      await sleep(RETRY_BACKOFF_MS);
    }
  }

  throw new LlmJsonError(`AI 输出无法解析为 JSON（已重试 ${total - 1} 次）：${lastReason}`);
}

/** 带图 JSON 识别：visionChat(jsonMode) → extractJson → 失败按 runtime 有界重试 */
export async function visionChatJson(
  endpoint: LlmEndpoint,
  input: JsonChatInput & { imageBase64: string; imageMime: string },
  runtime: LlmJsonRuntime,
): Promise<Record<string, unknown>> {
  return runJsonChat(
    runtime,
    (userText) =>
      visionChat(endpoint, {
        systemPrompt: input.systemPrompt,
        userText,
        imageBase64: input.imageBase64,
        imageMime: input.imageMime,
        temperature: input.temperature,
        jsonMode: true,
        timeoutMs: input.timeoutMs ?? runtime.timeoutMs,
        maxTokens: input.maxTokens ?? runtime.maxTokens,
      }),
    input.userText,
  );
}

/** 纯文本 JSON 识别：chatWithTools(jsonMode) → extractJson → 失败按 runtime 有界重试 */
export async function textChatJson(
  endpoint: LlmEndpoint,
  input: JsonChatInput,
  runtime: LlmJsonRuntime,
): Promise<Record<string, unknown>> {
  return runJsonChat(
    runtime,
    (userText) =>
      chatWithTools(
        endpoint,
        {
          systemPrompt: input.systemPrompt,
          userText,
          temperature: input.temperature,
          jsonMode: true,
          timeoutMs: input.timeoutMs ?? runtime.timeoutMs,
          maxTokens: input.maxTokens ?? runtime.maxTokens,
        },
        input.ctx,
      ),
    input.userText,
  );
}