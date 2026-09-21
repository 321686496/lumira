// lumira-server/packages/backend/src/modules/ai/llm-client.ts
// OpenAI 兼容 chat 客户端（qwen / doubao / zhipu / openai 通用）
// visionChat：带图（content 数组）；textChat：纯文本（content 字符串）
// 两者共享 chatRequest（fetch + 错误映射 + jsonMode 降级）
// 设计文档：docs/specs/2026-09-09-ai-template-one-click-creation-design.md 第五节
//
// 纯函数层：ai-config 模块提供 LlmEndpoint（单模态端点），ai-analyze 等端点调用 visionChat / textChat。
// 使用 Node 20 原生 fetch + AbortSignal.timeout，不引入 axios。

export interface LlmEndpoint {
  provider: string;   // 预留（chat 请求只用 baseUrl + apiKey）
  baseUrl: string;    // 形如 https://dashscope.aliyuncs.com/compatible-mode/v1（无尾斜杠）
  apiKey: string;
  model: string;
}

export interface VisionChatInput {
  systemPrompt: string;
  userText: string;
  imageBase64: string;      // 不含 data: 前缀
  imageMime: string;        // image/jpeg | image/png | image/webp
  temperature?: number;     // 默认 0.3
  jsonMode?: boolean;       // 默认 false；true 时带 response_format json_object，400/404 时自动降级重试一次
  timeoutMs?: number;       // 默认 90_000
}

export interface TextChatInput {
  systemPrompt: string;
  userText: string;
  temperature?: number;     // 默认 0.3
  jsonMode?: boolean;       // 同 visionChat
  timeoutMs?: number;       // 默认 90_000
}

// ===== 函数调用往返（Task 1：工具调用基建）=====

/** tool definition（OpenAI 兼容 tools 数组元素） */
export interface ToolDef {
  name: string;
  description: string;
  parameters: Record<string, unknown>;
}

/** 一条含 tool_calls 的 assistant 消息 */
export interface ToolCallMsg {
  role: 'assistant';
  content: string | null;
  tool_calls: Array<{
    id: string;
    type: 'function';
    function: { name: string; arguments: string };
  }>;
}

/** 工具执行结果回填消息（role:'tool'） */
export interface ToolResultMsg {
  role: 'tool';
  tool_call_id: string;
  content: string;
}

/** toolChat 输入（本版本做一次往返；maxIterations 预留供调用方控制迭代） */
export interface ToolChatInput {
  systemPrompt: string;
  userText: string;
  tools: ToolDef[];
  temperature?: number;
  timeoutMs?: number;
  maxIterations?: number;
}

const DEFAULT_TEMPERATURE = 0.3;
const DEFAULT_TIMEOUT_MS = 300_000;
const MAX_TOKENS = 4096;

/** 网络层错误 → 运营可读 message：AbortError/TimeoutError 视为超时，其余视为连接失败 */
function mapNetworkError(err: unknown): never {
  const name = (err as { name?: string } | null | undefined)?.name;
  if (name === 'AbortError' || name === 'TimeoutError') {
    throw new Error('AI 请求超时，请稍后重试');
  }
  throw new Error('AI 服务无法连接，请检查 baseUrl');
}

/** 解析上游错误响应体（body.error.message / body.message），拼接 HTTP status；body 非 JSON 时仅带 status */
async function upstreamError(res: Response): Promise<string> {
  let detail = '';
  try {
    const body = (await res.json()) as { error?: { message?: unknown }; message?: unknown };
    const msg = body?.error?.message ?? body?.message;
    if (typeof msg === 'string' && msg.trim() !== '') detail = msg.trim();
  } catch {
    // body 非 JSON（或已消费）：仅带 status
  }
  return detail ? `AI 上游错误（HTTP ${res.status}）：${detail}` : `AI 上游错误（HTTP ${res.status}）`;
}

/** 请求体构造参数（含可选 tools / tool_choice） */
interface ChatRequestBase {
  model: string;
  messages: unknown[];
  temperature: number;
  jsonMode: boolean;
  timeoutMs: number;
}

/**
 * 构造 chat/completions 请求体（chatRequest / toolChat 共用）：
 * jsonMode → response_format；tools 非空 → 带 tools + tool_choice:'auto'。
 */
export function buildChatBody(input: ChatRequestBase, opts: { tools?: ToolDef[]; toolChoice?: 'auto' | 'none' | 'required'; jsonMode?: boolean } = {}): Record<string, unknown> {
  const body: Record<string, unknown> = {
    model: input.model,
    temperature: input.temperature,
    max_tokens: MAX_TOKENS,
    messages: input.messages,
  };
  if (opts.jsonMode ?? input.jsonMode) body.response_format = { type: 'json_object' };
  if (opts.tools && opts.tools.length) {
    body.tools = opts.tools;
    body.tool_choice = opts.toolChoice ?? 'auto';
  }
  return body;
}

/** 底层单次请求：fetch + 错误映射 + jsonMode 降级，返回 choices[0].message（含 tool_calls 时 content 可 null） */
async function rawChatMessage(cfg: LlmEndpoint, input: ChatRequestBase, opts: { tools?: ToolDef[]; toolChoice?: 'auto' | 'none' | 'required' } = {}): Promise<Record<string, unknown>> {
  const url = `${cfg.baseUrl.replace(/\/+$/, '')}/chat/completions`;

  const doFetch = async (jsonMode: boolean): Promise<Response> => {
    return fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${cfg.apiKey}` },
      body: JSON.stringify(buildChatBody(input, { ...opts, jsonMode })),
      signal: AbortSignal.timeout(input.timeoutMs),
    });
  };

  let res = await doFetch(input.jsonMode).catch(mapNetworkError);
  // jsonMode 降级：部分厂商不认识 response_format，400/404 时去掉重试一次
  if (!res.ok && input.jsonMode && (res.status === 400 || res.status === 404)) {
    res = await doFetch(false).catch(mapNetworkError);
  }
  if (res.status === 401 || res.status === 403) {
    throw new Error('AI 服务认证失败（apiKey 无效或无权限/欠费），请到后台「AI 设置」检查');
  }
  if (!res.ok) throw new Error(await upstreamError(res));

  const data = (await res.json()) as { choices?: Array<{ message?: Record<string, unknown> }> } | null;
  const message = data?.choices?.[0]?.message;
  return message && typeof message === 'object' ? message : {};
}

/** 公共请求层：messages + model → fetch → 错误映射 → jsonMode 降级 → 取 content；失败抛 Error，message 面向运营可读 */
async function chatRequest(cfg: LlmEndpoint, input: ChatRequestBase): Promise<string> {
  const message = await rawChatMessage(cfg, input);
  const content = message.content;
  if (typeof content !== 'string' || !content) throw new Error('AI 服务返回内容为空');
  return content;
}

/** 带图 chat（对外签名与行为不变） */
export async function visionChat(cfg: LlmEndpoint, input: VisionChatInput): Promise<string> {
  const messages = [
    { role: 'system', content: input.systemPrompt },
    { role: 'user', content: [
      { type: 'text', text: input.userText },
      { type: 'image_url', image_url: { url: `data:${input.imageMime};base64,${input.imageBase64}` } },
    ] },
  ];
  return chatRequest(cfg, {
    model: cfg.model,
    messages,
    temperature: input.temperature ?? DEFAULT_TEMPERATURE,
    jsonMode: input.jsonMode ?? false,
    timeoutMs: input.timeoutMs ?? DEFAULT_TIMEOUT_MS,
  });
}

/** 纯文本 chat：model 取 cfg.model（textModel → visionModel 回退由 getActiveConfig 负责） */
export async function textChat(cfg: LlmEndpoint, input: TextChatInput): Promise<string> {
  const messages = [
    { role: 'system', content: input.systemPrompt },
    { role: 'user', content: input.userText },
  ];
  return chatRequest(cfg, {
    model: cfg.model,
    messages,
    temperature: input.temperature ?? DEFAULT_TEMPERATURE,
    jsonMode: input.jsonMode ?? false,
    timeoutMs: input.timeoutMs ?? DEFAULT_TIMEOUT_MS,
  });
}

/**
 * 从消息序列中解析出 assistant 的 tool_calls（自末向前扫第一条含 tool_calls 的 assistant 消息）。
 * 无 tool_calls → 空数组。每条返回值是完整 ToolCallMsg（含 tool_calls 的 assistant 消息）。
 */
export function extractToolCalls(content: string | null, messages: unknown[]): ToolCallMsg[] {
  const msgs = Array.isArray(messages) ? messages : [];
  for (let i = msgs.length - 1; i >= 0; i--) {
    const m = msgs[i] as { role?: unknown; tool_calls?: unknown; content?: unknown } | null | undefined;
    if (m && m.role === 'assistant' && Array.isArray(m.tool_calls) && m.tool_calls.length) {
      const calls = (m.tool_calls as Array<Record<string, unknown>>)
        .filter((tc) => tc && typeof tc === 'object')
        .map((tc) => {
          const fn = (tc.function ?? {}) as { name?: unknown; arguments?: unknown };
          return {
            id: typeof tc.id === 'string' ? tc.id : '',
            type: 'function' as const,
            function: {
              name: typeof fn.name === 'string' ? fn.name : '',
              arguments: typeof fn.arguments === 'string' ? fn.arguments : '{}',
            },
          };
        });
      return [{ role: 'assistant', content, tool_calls: calls }];
    }
  }
  return [];
}

/**
 * 函数调用一次往返：system + user + tools → fetch → 返回本轮 assistant 消息。
 * 复用 chatRequest 同款网络 / 错误映射 / jsonMode 降级；content 可为 null（轮到 model 只发 tool_calls）。
 * 返回 messages 为完整上下文（system + user + assistant），供调用方回填工具结果后继续迭代。
 */
export async function toolChat(cfg: LlmEndpoint, input: ToolChatInput): Promise<{ content: string | null; toolCalls: ToolCallMsg[]; messages: unknown[] }> {
  const messages: unknown[] = [
    { role: 'system', content: input.systemPrompt },
    { role: 'user', content: input.userText },
  ];
  const message = await rawChatMessage(
    cfg,
    {
      model: cfg.model,
      messages,
      temperature: input.temperature ?? DEFAULT_TEMPERATURE,
      jsonMode: false,
      timeoutMs: input.timeoutMs ?? DEFAULT_TIMEOUT_MS,
    },
    { tools: input.tools, toolChoice: 'auto' },
  );
  const assistantMsg: Record<string, unknown> = { role: 'assistant', content: message.content ?? null };
  if (Array.isArray(message.tool_calls)) assistantMsg.tool_calls = message.tool_calls;
  messages.push(assistantMsg);

  const content = typeof message.content === 'string' ? message.content : null;
  return { content, toolCalls: extractToolCalls(content, messages), messages };
}
