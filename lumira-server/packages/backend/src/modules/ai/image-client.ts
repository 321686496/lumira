// lumira-server/packages/backend/src/modules/ai/image-client.ts
// per-provider 生图客户端（Task 7）：doubao/zhipu/openai 同步 /images/generations
// （openai 有参考图走 /images/edits FormData），qwen wanx 异步任务轮询。
// 设计文档：docs/specs/2026-09-09-ai-template-one-click-creation-design.md 第五节
//
// 纯函数层（无 DB 依赖）：Task 6 buildImagePrompt 产出 prompt，本模块负责厂商分发与结果统一为 base64。
// 使用 Node 20 原生 fetch + AbortSignal.timeout + FormData/Blob，不引入 axios。
// 错误处理同 llm-client 风格（文案一致），wanx 轮询超时 →「生图任务超时」。

import type { ActiveAiConfig } from './ai-config.service';

export interface GenerateImageInput {
  prompt: string;
  size: string;                 // 形如 '1024x1024'（厂商格式，mapSize 产出）
  referenceBase64?: string;     // 有参考图时优先图生图（仅 doubao/openai 真正支持）
  referenceMime?: string;
}

export interface GenerateImageResult {
  base64: string;               // 不含 data: 前缀
  mimeType: string;             // 'image/png' 等
}

/** 生图行为参数（测试注入小 pollIntervalMs / 短 pollTimeoutMs，避免真实 2s/60s 计时） */
export interface GenerateImageOptions {
  requestTimeoutMs?: number;    // 单次 HTTP 请求超时，默认 120_000
  pollIntervalMs?: number;      // qwen 任务轮询间隔，默认 2_000
  pollTimeoutMs?: number;       // qwen 任务总时长上限，默认 60_000
}

const DEFAULT_REQUEST_TIMEOUT_MS = 120_000;
const DEFAULT_POLL_INTERVAL_MS = 2_000;
const DEFAULT_POLL_TIMEOUT_MS = 60_000;

// ===== 通用错误处理（同 llm-client，文案一致；该文件未导出，故本地实现） =====

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

/** 401/403 → 认证错误；其余非 2xx → 上游错误 */
async function assertOk(res: Response): Promise<void> {
  if (res.status === 401 || res.status === 403) {
    throw new Error('AI 服务认证失败（apiKey 无效或无权限/欠费），请到后台「AI 设置」检查');
  }
  if (!res.ok) throw new Error(await upstreamError(res));
}

// ===== 基础工具 =====

/** baseUrl 去尾斜杠（同 llm-client 拼接口径） */
function normBaseUrl(baseUrl: string): string {
  return baseUrl.replace(/\/+$/, '');
}

/** qwen 专用：baseUrl（形如 https://dashscope.aliyuncs.com/compatible-mode/v1）→ origin（协议+域名） */
function extractOrigin(baseUrl: string): string {
  try {
    return new URL(baseUrl).origin;
  } catch {
    throw new Error('AI 服务无法连接，请检查 baseUrl');
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** 下载生图结果 url → base64（mimeType 取 content-type，非 image/* 兜底 png） */
async function downloadImage(url: string, opts: GenerateImageOptions): Promise<GenerateImageResult> {
  const res = await fetch(url, {
    signal: AbortSignal.timeout(opts.requestTimeoutMs ?? DEFAULT_REQUEST_TIMEOUT_MS),
  }).catch(mapNetworkError);
  if (!res.ok) throw new Error(`生图结果下载失败（HTTP ${res.status}）`);
  const buf = Buffer.from(await res.arrayBuffer());
  const mime = (res.headers.get('content-type') ?? '').split(';')[0].trim();
  return { base64: buf.toString('base64'), mimeType: mime.startsWith('image/') ? mime : 'image/png' };
}

/** 同步生图响应解析：data[0].b64_json 优先，url 兜底下载 */
async function parseSyncImageResponse(res: Response, opts: GenerateImageOptions): Promise<GenerateImageResult> {
  const data = (await res.json()) as { data?: Array<{ b64_json?: unknown; url?: unknown }> } | null;
  const item = data?.data?.[0];
  if (item && typeof item.b64_json === 'string' && item.b64_json !== '') {
    return { base64: item.b64_json, mimeType: 'image/png' };
  }
  if (item && typeof item.url === 'string' && item.url !== '') {
    return downloadImage(item.url, opts);
  }
  throw new Error('生图服务返回内容为空');
}

/** 同步厂商（doubao/zhipu/openai 文生图）共用：POST {baseUrl}/images/generations */
async function syncGenerate(
  cfg: ActiveAiConfig,
  body: Record<string, unknown>,
  opts: GenerateImageOptions,
): Promise<GenerateImageResult> {
  const res = await fetch(`${normBaseUrl(cfg.baseUrl)}/images/generations`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${cfg.apiKey}` },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(opts.requestTimeoutMs ?? DEFAULT_REQUEST_TIMEOUT_MS),
  }).catch(mapNetworkError);
  await assertOk(res);
  return parseSyncImageResponse(res, opts);
}

// ===== 厂商分支 =====

/** doubao（Seedream，OpenAI 兼容）：文生图 body 加 image 字段（data URL）即图生图 */
async function doubaoGenerate(cfg: ActiveAiConfig, input: GenerateImageInput, opts: GenerateImageOptions) {
  const body: Record<string, unknown> = {
    model: cfg.imageModel,
    prompt: input.prompt,
    size: input.size,
  };
  if (input.referenceBase64) {
    body.image = `data:${input.referenceMime ?? 'image/png'};base64,${input.referenceBase64}`;
  }
  return syncGenerate(cfg, body, opts);
}

/** zhipu（CogView）：纯文生图，忽略参考图 */
async function zhipuGenerate(cfg: ActiveAiConfig, input: GenerateImageInput, opts: GenerateImageOptions) {
  return syncGenerate(
    cfg,
    { model: cfg.imageModel, prompt: input.prompt, size: input.size },
    opts,
  );
}

/** openai：无参考图 /images/generations（b64_json）；有参考图 /images/edits（FormData） */
async function openaiGenerate(cfg: ActiveAiConfig, input: GenerateImageInput, opts: GenerateImageOptions) {
  if (!input.referenceBase64) {
    return syncGenerate(
      cfg,
      { model: cfg.imageModel, prompt: input.prompt, size: input.size, response_format: 'b64_json' },
      opts,
    );
  }

  // 图生图：multipart（FormData 自动带 boundary Content-Type，只手动传鉴权头）
  const refBuf = Buffer.from(input.referenceBase64, 'base64');
  const fd = new FormData();
  fd.append('image', new Blob([refBuf], { type: input.referenceMime ?? 'image/png' }), 'reference.png');
  fd.append('prompt', input.prompt);
  fd.append('model', cfg.imageModel);
  fd.append('size', input.size);

  const res = await fetch(`${normBaseUrl(cfg.baseUrl)}/images/edits`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${cfg.apiKey}` },
    body: fd,
    signal: AbortSignal.timeout(opts.requestTimeoutMs ?? DEFAULT_REQUEST_TIMEOUT_MS),
  }).catch(mapNetworkError);
  await assertOk(res);

  const data = (await res.json()) as { data?: Array<{ b64_json?: unknown }> } | null;
  const b64 = data?.data?.[0]?.b64_json;
  if (typeof b64 !== 'string' || b64 === '') throw new Error('生图服务返回内容为空');
  return { base64: b64, mimeType: 'image/png' };
}

/** qwen（wanx）：DashScope 异步任务——提交 → 轮询 task_status → SUCCEEDED 后下载 results[0].url */
async function qwenGenerate(cfg: ActiveAiConfig, input: GenerateImageInput, opts: GenerateImageOptions) {
  const origin = extractOrigin(cfg.baseUrl);
  const res = await fetch(`${origin}/api/v1/services/aigc/text2image/image-synthesis`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${cfg.apiKey}`,
      'X-DashScope-Async': 'enable',
    },
    body: JSON.stringify({
      model: cfg.imageModel,
      input: { prompt: input.prompt },
      parameters: { size: input.size, n: 1 },
    }),
    signal: AbortSignal.timeout(opts.requestTimeoutMs ?? DEFAULT_REQUEST_TIMEOUT_MS),
  }).catch(mapNetworkError);
  await assertOk(res);

  const submitted = (await res.json()) as { output?: { task_id?: unknown } } | null;
  const taskId = submitted?.output?.task_id;
  if (typeof taskId !== 'string' || taskId === '') throw new Error('生图服务未返回任务 ID');

  // 轮询任务状态（间隔/上限可注入；失败终态直接抛，超时 →「生图任务超时」）
  const interval = opts.pollIntervalMs ?? DEFAULT_POLL_INTERVAL_MS;
  const deadline = Date.now() + (opts.pollTimeoutMs ?? DEFAULT_POLL_TIMEOUT_MS);
  for (;;) {
    const taskRes = await fetch(`${origin}/api/v1/tasks/${taskId}`, {
      headers: { Authorization: `Bearer ${cfg.apiKey}` },
      signal: AbortSignal.timeout(opts.requestTimeoutMs ?? DEFAULT_REQUEST_TIMEOUT_MS),
    }).catch(mapNetworkError);
    await assertOk(taskRes);

    const task = (await taskRes.json()) as
      | { output?: { task_status?: unknown; results?: Array<{ url?: unknown }> } }
      | null;
    const status = task?.output?.task_status;
    if (status === 'SUCCEEDED') {
      const url = task?.output?.results?.[0]?.url;
      if (typeof url !== 'string' || url === '') throw new Error('生图服务返回内容为空');
      return downloadImage(url, opts);
    }
    if (status === 'FAILED' || status === 'CANCELED' || status === 'UNKNOWN') {
      throw new Error(`生图任务失败（${status}）`);
    }
    if (Date.now() >= deadline) throw new Error('生图任务超时');
    await sleep(interval);
  }
}

/**
 * 按厂商分发生图：doubao/zhipu/openai 同步（openai 有参考图走 edits），
 * qwen wanx 异步任务轮询（间隔 2s、上限 60s，均可经 opts 注入）。
 * 成功返回 base64 + mimeType；失败抛 Error，message 面向运营可读。
 */
export async function generateImage(
  cfg: ActiveAiConfig,
  input: GenerateImageInput,
  opts: GenerateImageOptions = {},
): Promise<GenerateImageResult> {
  switch (cfg.provider) {
    case 'doubao':
      return doubaoGenerate(cfg, input, opts);
    case 'zhipu':
      return zhipuGenerate(cfg, input, opts);
    case 'openai':
      return openaiGenerate(cfg, input, opts);
    case 'qwen':
      return qwenGenerate(cfg, input, opts);
    default:
      throw new Error(`不支持的 AI 厂商：${cfg.provider}`);
  }
}

/**
 * 画幅映射：'3:4' 等草稿 ratio → 各厂商最接近的支持尺寸。
 * 尺寸映射表以「各厂商文档为准微调」——如与文档冲突，以厂商文档修正并在测试同步改：
 * - doubao（Seedream，OpenAI 兼容）：1:1→1024x1024、3:4→864x1152、4:3→1152x864、9:16→720x1440、16:9→1440x720
 * - zhipu（CogView）：1:1→1024x1024、3:4→864x1152、4:3→1152x864、9:16→768x1344、16:9→1344x768
 * - openai（gpt-image 系列）：1:1→1024x1024、纵向(3:4/9:16)→1024x1536、横向(4:3/16:9)→1536x1024
 * - qwen（wanx，size 用 '*' 分隔）：1:1→1024*1024、竖图(3:4/9:16)→720*1280、横图(4:3/16:9)→1280*720
 * 未知 ratio 兜底 1:1；未知 provider 兜底 '1024x1024'。
 */
const SIZE_MAPS: Record<string, Record<string, string>> = {
  doubao: {
    '1:1': '1024x1024',
    '3:4': '864x1152',
    '4:3': '1152x864',
    '9:16': '720x1440',
    '16:9': '1440x720',
  },
  zhipu: {
    '1:1': '1024x1024',
    '3:4': '864x1152',
    '4:3': '1152x864',
    '9:16': '768x1344',
    '16:9': '1344x768',
  },
  openai: {
    '1:1': '1024x1024',
    '3:4': '1024x1536',
    '4:3': '1536x1024',
    '9:16': '1024x1536',
    '16:9': '1536x1024',
  },
  qwen: {
    '1:1': '1024*1024',
    '3:4': '720*1280',
    '4:3': '1280*720',
    '9:16': '720*1280',
    '16:9': '1280*720',
  },
};

export function mapSize(provider: string, aspectRatio: string | undefined): string {
  const map = SIZE_MAPS[provider];
  if (!map) return '1024x1024';
  const known = aspectRatio !== undefined && map[aspectRatio] !== undefined ? aspectRatio : '1:1';
  return map[known];
}
