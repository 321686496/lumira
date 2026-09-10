// lumira-server/packages/backend/src/modules/ai/llm-client.ts
// OpenAI 兼容 chat 客户端（qwen / doubao / zhipu / openai 通用）
// visionChat：带图（content 数组）；textChat：纯文本（content 字符串）
// 两者共享 chatRequest（fetch + 错误映射 + jsonMode 降级）
// 设计文档：docs/specs/2026-09-09-ai-template-one-click-creation-design.md 第五节
//
// 纯函数层：Task 4（ai-config 模块）提供 LlmConfig，Task 5（ai-analyze 端点）调用 visionChat / textChat。
// 使用 Node 20 原生 fetch + AbortSignal.timeout，不引入 axios。

export interface LlmConfig {
  provider: string;   // qwen | doubao | zhipu | openai
  baseUrl: string;    // 形如 https://dashscope.aliyuncs.com/compatible-mode/v1（无尾斜杠）
  apiKey: string;
  visionModel: string;
  /** 纯文本任务模型；缺省回退 visionModel */
  textModel?: string;
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

const DEFAULT_TEMPERATURE = 0.3;
const DEFAULT_TIMEOUT_MS = 90_000;
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

/** 公共请求层：messages + model → fetch → 错误映射 → jsonMode 降级 → 取 content；失败抛 Error，message 面向运营可读 */
async function chatRequest(
  cfg: LlmConfig,
  input: { model: string; messages: unknown[]; temperature: number; jsonMode: boolean; timeoutMs: number },
): Promise<string> {
  const url = `${cfg.baseUrl.replace(/\/+$/, '')}/chat/completions`;

  const doFetch = async (jsonMode: boolean): Promise<Response> => {
    const body: Record<string, unknown> = {
      model: input.model,
      temperature: input.temperature,
      max_tokens: MAX_TOKENS,
      messages: input.messages,
    };
    if (jsonMode) body.response_format = { type: 'json_object' };
    return fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${cfg.apiKey}` },
      body: JSON.stringify(body),
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

  const data = (await res.json()) as { choices?: Array<{ message?: { content?: unknown } }> } | null;
  const content = data?.choices?.[0]?.message?.content;
  if (typeof content !== 'string' || !content) throw new Error('AI 服务返回内容为空');
  return content;
}

/** 带图 chat（对外签名与行为不变） */
export async function visionChat(cfg: LlmConfig, input: VisionChatInput): Promise<string> {
  const messages = [
    { role: 'system', content: input.systemPrompt },
    { role: 'user', content: [
      { type: 'text', text: input.userText },
      { type: 'image_url', image_url: { url: `data:${input.imageMime};base64,${input.imageBase64}` } },
    ] },
  ];
  return chatRequest(cfg, {
    model: cfg.visionModel,
    messages,
    temperature: input.temperature ?? DEFAULT_TEMPERATURE,
    jsonMode: input.jsonMode ?? false,
    timeoutMs: input.timeoutMs ?? DEFAULT_TIMEOUT_MS,
  });
}

/** 纯文本 chat：model 取 textModel ?? visionModel */
export async function textChat(cfg: LlmConfig, input: TextChatInput): Promise<string> {
  const messages = [
    { role: 'system', content: input.systemPrompt },
    { role: 'user', content: input.userText },
  ];
  return chatRequest(cfg, {
    model: cfg.textModel ?? cfg.visionModel,
    messages,
    temperature: input.temperature ?? DEFAULT_TEMPERATURE,
    jsonMode: input.jsonMode ?? false,
    timeoutMs: input.timeoutMs ?? DEFAULT_TIMEOUT_MS,
  });
}
