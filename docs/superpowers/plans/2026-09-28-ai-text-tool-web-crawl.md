# AI 文本模型通用工具循环 + 网页爬取工具 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 AI 一键生成链路引入「文本模型通用工具循环」，并落地第一个工具 `crawl_website`（按需抓取网页正文），由后台独立开关控制。

**Architecture:** 新增 `modules/ai/tools/`（抓取实现 + 循环原语 + 工具注册），扩展 `llm-client.ts` 支持多轮消息历史，`llm-json.ts` 与各文本调用点透传 `ctx` 即可获得工具能力；`ctx` 缺省时行为与改动前完全一致。开关落到 `ai_provider_config` 新列与后台「AI 设置」。

**Tech Stack:** NestJS + Fastify + Drizzle ORM + MySQL 8；Node 20 原生 `fetch` + `AbortSignal.timeout`；Jest；Next.js 后台（Tailwind + shadcn/ui）。

**设计文档:** `docs/superpowers/specs/2026-09-28-ai-text-tool-web-crawl-design.md`

## Global Constraints

- 不引入任何新 npm 依赖（HTML→文本用正则 + 原生字符串处理）。
- 抓取强制常量：`CRAWL_TIMEOUT_MS = 8000`、`MAX_BYTES = 1048576`（1MB）、`MAX_CHARS = 6000`、`TOOL_LOOP_MAX_ROUNDS = 3`。
- 仅允许 `http` / `https`；拒绝 `localhost` / `*.local` / `*.internal` / 私有网段 / 裸 IP 直连。
- 开关默认值：`crawl_enabled DEFAULT 0`（默认关闭）、`crawl_max_per_session DEFAULT 3`（合法区间 1~6）。
- `ctx` 为 `undefined` 或 `tools` 为空时，文本调用行为必须与改动前逐字节一致（既有测试全绿）。
- **禁止改动**：`lumira-server/packages/admin/src/components/ai-create/**`（并行 WIP：风格识别参考图被误用于姿势生图）、`ai-generate-image.service.ts`、`image-client.ts`、`image-prompt.builder.ts`、`ai-generate-silhouette.service.ts`、`silhouette.pipeline.ts`、Flutter 端、`lumira-app/`。
- 测试命令统一在 `e:\Project\photo_post\lumira-server\packages\backend` 目录执行：`pnpm --filter @lumira/backend test -- <spec 路径> -v`。
- 提交只 `git add` 本任务明确列出的文件，禁止 `git add -A`。

---

### Task 1: 网页正文抓取 `crawl-url.ts`

**Files:**
- Create: `lumira-server/packages/backend/src/modules/ai/tools/crawl-url.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/tools/crawl-url.spec.ts`

**Interfaces:**
- Consumes: `LruCache` from `../trend-research/lru-cache`（`new LruCache<T>(max)`、`get(key)`、`set(key, value)`、`clear()`）
- Produces:
  - `export interface CrawlResult { url: string; text: string; chars: number; truncated: boolean }`
  - `export function assertCrawlableUrl(raw: string): URL`（非法时抛 `Error`）
  - `export function htmlToText(html: string): string`
  - `export async function crawlUrl(raw: string): Promise<CrawlResult>`
  - `export function clearCrawlCache(): void`

- [ ] **Step 1: Write the failing test**

Create `lumira-server/packages/backend/src/modules/ai/tools/crawl-url.spec.ts`:

```ts
import { crawlUrl, htmlToText, assertCrawlableUrl, clearCrawlCache } from './crawl-url';

function htmlResponse(body: string, contentType = 'text/html; charset=utf-8', headers: Record<string, string> = {}) {
  return new Response(body, { status: 200, headers: { 'Content-Type': contentType, ...headers } });
}

describe('htmlToText', () => {
  it('去噪：移除 script/style/注释，保留正文', () => {
    const html = `<html><head><style>a{color:red}</style></head><body>
      <!-- 注释 --><script>var a=1;</script><h1>标题</h1><p>第一段&amp;内容</p></body></html>`;
    const text = htmlToText(html);
    expect(text).toContain('标题');
    expect(text).toContain('第一段&内容');
    expect(text).not.toContain('color:red');
    expect(text).not.toContain('var a=1');
    expect(text).not.toContain('注释');
  });

  it('优先提取 article 区块', () => {
    const html = `<body><nav>导航项</nav><article><h2>正文标题</h2><p>正文内容</p></article><footer>页脚</footer></body>`;
    const text = htmlToText(html);
    expect(text).toContain('正文标题');
    expect(text).not.toContain('导航项');
  });
});

describe('assertCrawlableUrl', () => {
  it.each([
    ['file:///etc/passwd', '协议'],
    ['http://localhost/x', 'localhost'],
    ['http://127.0.0.1/x', '回环'],
    ['http://192.168.1.10/x', '私有网段'],
    ['http://10.0.0.5/x', '私有网段'],
    ['http://172.20.3.4/x', '私有网段'],
    ['http://foo.internal/x', '内网域名'],
  ])('拒绝 %s', (url) => {
    expect(() => assertCrawlableUrl(url)).toThrow();
  });

  it('接受公网 https 地址', () => {
    expect(assertCrawlableUrl('https://example.com/a?b=1').hostname).toBe('example.com');
  });
});

describe('crawlUrl', () => {
  const fetchMock = jest.spyOn(global, 'fetch');

  beforeEach(() => {
    fetchMock.mockReset();
    clearCrawlCache();
  });

  it('抓取 HTML 并返回纯文本', async () => {
    fetchMock.mockResolvedValueOnce(htmlResponse('<html><body><h1>标题</h1><p>正文</p></body></html>'));
    const r = await crawlUrl('https://example.com/post');
    expect(r.text).toContain('标题');
    expect(r.truncated).toBe(false);
    expect(r.chars).toBe(r.text.length);
  });

  it('超过 6000 字被截断并置 truncated', async () => {
    fetchMock.mockResolvedValueOnce(htmlResponse(`<body><p>${'字'.repeat(8000)}</p></body>`));
    const r = await crawlUrl('https://example.com/long');
    expect(r.chars).toBe(6000);
    expect(r.truncated).toBe(true);
  });

  it('非网页类型被拒绝', async () => {
    fetchMock.mockResolvedValueOnce(htmlResponse('%PDF-1.4', 'application/pdf'));
    await expect(crawlUrl('https://example.com/a.pdf')).rejects.toThrow('不是网页正文');
  });

  it('超大响应体被拒绝', async () => {
    fetchMock.mockResolvedValueOnce(htmlResponse('<body>x</body>', 'text/html', { 'Content-Length': String(2 * 1024 * 1024) }));
    await expect(crawlUrl('https://example.com/big')).rejects.toThrow('过大');
  });

  it('超时抛可读错误', async () => {
    fetchMock.mockRejectedValueOnce(Object.assign(new Error('aborted'), { name: 'TimeoutError' }));
    await expect(crawlUrl('https://example.com/slow')).rejects.toThrow('抓取超时');
  });

  it('相同 URL 第二次命中缓存（不再发起 fetch）', async () => {
    fetchMock.mockResolvedValueOnce(htmlResponse('<body><p>缓存内容</p></body>'));
    await crawlUrl('https://example.com/cached');
    await crawlUrl('https://example.com/cached');
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it('重定向落到私有网段时拒绝', async () => {
    fetchMock.mockResolvedValueOnce(
      new Response('<body>x</body>', {
        status: 200,
        headers: { 'Content-Type': 'text/html' },
      }),
    );
    // Response.url 只读，改用 defineProperty 模拟重定向后的最终地址
    const res = await fetchMock.mock.results[0].value;
    Object.defineProperty(res, 'url', { value: 'http://192.168.1.9/secret' });
    await expect(crawlUrl('https://example.com/redirect')).rejects.toThrow();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pnpm --filter @lumira/backend test -- src/modules/ai/tools/crawl-url.spec.ts -v`
Expected: FAIL，报错 `Cannot find module './crawl-url'`

- [ ] **Step 3: Write minimal implementation**

Create `lumira-server/packages/backend/src/modules/ai/tools/crawl-url.ts`:

```ts
// lumira-server/packages/backend/src/modules/ai/tools/crawl-url.ts
// 网页正文抓取：仅抓公开静态 HTML，清洗为纯文本供文本模型阅读。
// 设计文档：docs/superpowers/specs/2026-09-28-ai-text-tool-web-crawl-design.md 第二节
//
// 安全：仅 http/https、拦内网/本机、限体积（1MB）与超时（8s）、限长度（6000 字）。
// 不做 JS 渲染，不引入第三方解析库（正则 + 原生字符串处理）。

import { LruCache } from '../trend-research/lru-cache';

export interface CrawlResult {
  url: string;
  text: string;
  chars: number;
  truncated: boolean;
}

const CRAWL_TIMEOUT_MS = 8_000;
const MAX_BYTES = 1_048_576; // 1MB
const MAX_CHARS = 6_000;
const USER_AGENT = 'LumiraBot/1.0 (+https://lumira.iwtle.top)';
const ALLOWED_MIME = ['text/html', 'application/xhtml+xml', 'text/plain'];

/** 成功结果进程内缓存（key = 归一化 URL） */
const cache = new LruCache<CrawlResult>(100);

/** 内网 / 本机 / 保留地址（防 SSRF） */
const BLOCKED_HOST_PATTERNS = [
  /^localhost$/i,
  /\.local$/i,
  /\.internal$/i,
  /^127\./,
  /^10\./,
  /^169\.254\./,
  /^192\.168\./,
  /^172\.(1[6-9]|2\d|3[01])\./,
  /^::1$/,
  /^\[::1\]$/,
];

/** 校验可抓取 URL；非法抛可读 Error */
export function assertCrawlableUrl(raw: string): URL {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw new Error(`无效网址：${raw}`);
  }
  if (url.protocol !== 'http:' && url.protocol !== 'https:') {
    throw new Error(`仅支持 http/https 网址：${raw}`);
  }
  if (BLOCKED_HOST_PATTERNS.some((p) => p.test(url.hostname))) {
    throw new Error(`不允许抓取内网/本机地址：${raw}`);
  }
  return url;
}

/** 块级标签 → 换行，保证段落不粘连 */
const BLOCK_TAGS =
  /<\/?(p|div|section|article|main|header|footer|li|ul|ol|h[1-6]|tr|td|th|table|thead|tbody|blockquote|br|hr|pre|figure|figcaption|aside|nav|address|dl|dt|dd)[^>]*>/gi;

/** HTML → 纯文本：去噪 → 提正文区块 → 去标签 → 解实体 → 压缩空白 */
export function htmlToText(html: string): string {
  let s = html
    .replace(/<!--[\s\S]*?-->/g, '')
    .replace(/<(script|style|noscript|svg|iframe|template|head)\b[\s\S]*?<\/\1>/gi, '');

  const body = s.match(/<article\b[\s\S]*?<\/article>/i)?.[0] ?? s.match(/<main\b[\s\S]*?<\/main>/i)?.[0];
  if (body) s = body;

  return s
    .replace(BLOCK_TAGS, '\n')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/g, "'")
    .replace(/[ \t\f\v]+/g, ' ')
    .replace(/ *\n */g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

/** 抓取网页正文；失败抛面向模型可读的 Error（由工具执行器转成 error 文本回填） */
export async function crawlUrl(raw: string): Promise<CrawlResult> {
  const url = assertCrawlableUrl(raw);
  const key = url.toString();

  const cached = cache.get(key);
  if (cached) return cached;

  let res: Response;
  try {
    res = await fetch(key, {
      headers: { 'User-Agent': USER_AGENT, Accept: 'text/html,application/xhtml+xml,text/plain;q=0.9' },
      redirect: 'follow',
      signal: AbortSignal.timeout(CRAWL_TIMEOUT_MS),
    });
  } catch (err) {
    const name = (err as { name?: string } | null | undefined)?.name;
    if (name === 'AbortError' || name === 'TimeoutError') {
      throw new Error('抓取超时（8 秒），请换其他链接');
    }
    throw new Error('网页抓取失败，请换其他链接');
  }

  // 重定向可能落到内网：以最终地址再次校验
  if (res.url) assertCrawlableUrl(res.url);
  if (!res.ok) throw new Error(`网页返回错误（HTTP ${res.status}），请换其他链接`);

  const mime = (res.headers.get('content-type') ?? '').toLowerCase();
  if (!ALLOWED_MIME.some((m) => mime.includes(m))) {
    throw new Error('该链接不是网页正文（类型不支持），请换其他链接');
  }

  const declared = Number(res.headers.get('content-length') ?? '0');
  if (Number.isFinite(declared) && declared > MAX_BYTES) {
    throw new Error('网页内容过大（超过 1MB），已跳过');
  }

  const rawBody = await res.text();
  if (Buffer.byteLength(rawBody, 'utf8') > MAX_BYTES) {
    throw new Error('网页内容过大（超过 1MB），已跳过');
  }

  const text = mime.includes('text/plain') ? rawBody.replace(/\s+/g, ' ').trim() : htmlToText(rawBody);
  if (!text) throw new Error('网页未提取到正文内容，请换其他链接');

  const truncated = text.length > MAX_CHARS;
  const clipped = truncated ? text.slice(0, MAX_CHARS) : text;
  const result: CrawlResult = { url: key, text: clipped, chars: clipped.length, truncated };
  cache.set(key, result);
  return result;
}

/** 清空抓取缓存（测试用） */
export function clearCrawlCache(): void {
  cache.clear();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pnpm --filter @lumira/backend test -- src/modules/ai/tools/crawl-url.spec.ts -v`
Expected: PASS（全部用例）

- [ ] **Step 5: Commit**

```bash
git add lumira-server/packages/backend/src/modules/ai/tools/crawl-url.ts lumira-server/packages/backend/src/modules/ai/tools/crawl-url.spec.ts
git commit -m "feat(ai): 新增网页正文抓取 crawlUrl（含 SSRF/体积/超时护栏）"
```

---

### Task 2: `toolChatOnce` — 支持消息历史的多轮往返

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/llm-client.ts`（在 `toolChat` 之后追加）
- Test: `lumira-server/packages/backend/src/modules/ai/llm-client.tool-once.spec.ts`

**Interfaces:**
- Consumes: 现有 `rawChatMessage` / `extractToolCalls` / `traceLlmCall` / `ToolDef` / `ToolCallMsg`（同文件内私有/已导出）
- Produces:
  - `export interface ToolChatOnceInput { messages: unknown[]; tools: ToolDef[]; toolChoice?: 'auto' | 'none'; jsonMode?: boolean; temperature?: number; timeoutMs?: number; maxTokens?: number; title?: string; systemPrompt?: string; userPrompt?: string }`
  - `export async function toolChatOnce(cfg: LlmEndpoint, input: ToolChatOnceInput): Promise<{ content: string | null; toolCalls: ToolCallMsg[]; messages: unknown[] }>`

**行为要求：** 不修改传入的 `messages` 数组；返回的 `messages` = 原数组 + 本轮 assistant 消息。

- [ ] **Step 1: Write the failing test**

Create `lumira-server/packages/backend/src/modules/ai/llm-client.tool-once.spec.ts`:

```ts
import { toolChatOnce, type LlmEndpoint } from './llm-client';

const CFG: LlmEndpoint = { provider: 'qwen', baseUrl: 'https://api.example.com/v1', apiKey: 'k', model: 'qwen-plus' };

function parseBody(init?: RequestInit): Record<string, any> {
  return JSON.parse(String(init?.body));
}

const TOOLS = [{ name: 'crawl_website', description: '抓取网页正文', parameters: { type: 'object', properties: {} } }];

describe('toolChatOnce', () => {
  const fetchMock = jest.spyOn(global, 'fetch');

  beforeEach(() => fetchMock.mockReset());

  it('回填 assistant 消息且不修改入参数组', async () => {
    fetchMock.mockResolvedValueOnce(
      new Response(
        JSON.stringify({
          choices: [{ message: { role: 'assistant', content: null, tool_calls: [{ id: 'call_1', type: 'function', function: { name: 'crawl_website', arguments: '{"url":"https://a.com"}' } }] } }],
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      ),
    );
    const seed = [
      { role: 'system', content: 'sys' },
      { role: 'user', content: 'hi' },
    ];

    const res = await toolChatOnce(CFG, { messages: seed, tools: TOOLS, systemPrompt: 'sys', userPrompt: 'hi' });

    expect(seed).toHaveLength(2); // 入参未被修改
    expect(res.messages).toHaveLength(3);
    expect(res.content).toBeNull();
    expect(res.toolCalls[0].tool_calls[0].function.name).toBe('crawl_website');
  });

  it('toolChoice=none 时请求体带 tools + tool_choice:none', async () => {
    fetchMock.mockResolvedValueOnce(
      new Response(JSON.stringify({ choices: [{ message: { role: 'assistant', content: '{"ok":1}' } }] }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }),
    );

    await toolChatOnce(CFG, { messages: [{ role: 'user', content: 'hi' }], tools: TOOLS, toolChoice: 'none', jsonMode: true });

    const body = parseBody(fetchMock.mock.calls[0][1]);
    expect(body.tool_choice).toBe('none');
    expect(body.tools).toHaveLength(1);
    expect(body.response_format).toEqual({ type: 'json_object' });
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pnpm --filter @lumira/backend test -- src/modules/ai/llm-client.tool-once.spec.ts -v`
Expected: FAIL，`toolChatOnce is not a function`

- [ ] **Step 3: Write minimal implementation**

在 `lumira-server/packages/backend/src/modules/ai/llm-client.ts` 的 `toolChat` 函数之后追加：

```ts
/** toolChatOnce 输入：自带完整消息历史（供多轮工具循环渐进追加） */
export interface ToolChatOnceInput {
  messages: unknown[];
  tools: ToolDef[];
  toolChoice?: 'auto' | 'none';
  jsonMode?: boolean;
  temperature?: number;
  timeoutMs?: number;
  maxTokens?: number;
  /** 采集标题（默认「工具调用 · LLM」） */
  title?: string;
  /** 采集展示用（可选） */
  systemPrompt?: string;
  userPrompt?: string;
}

/**
 * 一次带工具的往返（不修改入参消息数组）：messages + tools → fetch → 本轮 assistant 消息。
 * 返回 messages = 入参 + assistant 消息，供调用方回填 role:'tool' 结果后继续迭代。
 */
export async function toolChatOnce(
  cfg: LlmEndpoint,
  input: ToolChatOnceInput,
): Promise<{ content: string | null; toolCalls: ToolCallMsg[]; messages: unknown[] }> {
  const handle = traceLlmCall({
    model: cfg.model,
    systemPrompt: input.systemPrompt,
    userPrompt: input.userPrompt,
    title: input.title ?? '工具调用 · LLM',
  });
  try {
    const { message, rawText, attempts } = await rawChatMessage(
      cfg,
      {
        model: cfg.model,
        messages: input.messages,
        temperature: input.temperature ?? DEFAULT_TEMPERATURE,
        jsonMode: input.jsonMode ?? false,
        timeoutMs: input.timeoutMs ?? DEFAULT_TIMEOUT_MS,
        maxTokens: input.maxTokens,
      },
      { tools: input.tools, toolChoice: input.toolChoice ?? 'auto' },
    );

    const assistantMsg: Record<string, unknown> = { role: 'assistant', content: message.content ?? null };
    if (Array.isArray(message.tool_calls)) assistantMsg.tool_calls = message.tool_calls;
    const messages = [...input.messages, assistantMsg];

    const content = typeof message.content === 'string' ? message.content : null;
    const toolCalls = extractToolCalls(content, messages);
    const names = toolCalls.flatMap((c) => c.tool_calls.map((t) => t.function.name));
    handle?.done(content ?? undefined, {
      rawResponse: rawText,
      attempts,
      resultBrief: names.length ? `调用工具：${names.join('、')}` : '无工具调用',
    });
    return { content, toolCalls, messages };
  } catch (err) {
    handle?.fail(err);
    throw err;
  }
}
```

随后把现有 `toolChat` 改为复用（保持对外签名与行为不变）：

```ts
/** 函数调用一次往返：system + user + tools → fetch → 返回本轮 assistant 消息（保留旧签名） */
export async function toolChat(cfg: LlmEndpoint, input: ToolChatInput): Promise<{ content: string | null; toolCalls: ToolCallMsg[]; messages: unknown[] }> {
  return toolChatOnce(cfg, {
    messages: [
      { role: 'system', content: input.systemPrompt },
      { role: 'user', content: input.userText },
    ],
    tools: input.tools,
    toolChoice: 'auto',
    temperature: input.temperature,
    timeoutMs: input.timeoutMs,
    systemPrompt: input.systemPrompt,
    userPrompt: input.userText,
  });
}
```

- [ ] **Step 4: Run tests to verify pass + 无回归**

Run: `pnpm --filter @lumira/backend test -- src/modules/ai/llm-client.tool-once.spec.ts src/modules/ai/llm-client.spec.ts -v`
Expected: 两个文件全部 PASS（`toolChat` 既有用例不变）

- [ ] **Step 5: Commit**

```bash
git add lumira-server/packages/backend/src/modules/ai/llm-client.ts lumira-server/packages/backend/src/modules/ai/llm-client.tool-once.spec.ts
git commit -m "feat(ai): llm-client 新增 toolChatOnce（支持消息历史的多轮工具往返）"
```

---

### Task 3: 通用工具循环 `chatWithTools`

**Files:**
- Create: `lumira-server/packages/backend/src/modules/ai/tools/text-tool-loop.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/tools/text-tool-loop.spec.ts`

**Interfaces:**
- Consumes: `toolChatOnce`、`textChat`、`type LlmEndpoint`（`../llm-client`）
- Produces:
  - `export interface TextToolContext { tools: ToolDef[]; execute(name: string, argsJson: string): Promise<string>; maxToolCalls: number }`
  - `export interface ChatWithToolsInput { systemPrompt: string; userText: string; jsonMode?: boolean; temperature?: number; timeoutMs?: number; maxTokens?: number }`
  - `export const TOOL_LOOP_MAX_ROUNDS = 3`
  - `export async function chatWithTools(cfg: LlmEndpoint, input: ChatWithToolsInput, ctx?: TextToolContext): Promise<string>`

- [ ] **Step 1: Write the failing test**

Create `lumira-server/packages/backend/src/modules/ai/tools/text-tool-loop.spec.ts`:

```ts
import { chatWithTools, TOOL_LOOP_MAX_ROUNDS, type TextToolContext } from './text-tool-loop';
import { toolChatOnce, textChat } from '../llm-client';

jest.mock('../llm-client', () => ({
  textChat: jest.fn(),
  toolChatOnce: jest.fn(),
}));

const toolChatOnceMock = toolChatOnce as jest.Mock;
const textChatMock = textChat as jest.Mock;

const CFG = { provider: 'qwen', baseUrl: 'https://api.example.com/v1', apiKey: 'k', model: 'qwen-plus' };
const INPUT = { systemPrompt: 'sys', userText: 'hi' };

function ctxOf(execute: jest.Mock, maxToolCalls = 3): TextToolContext {
  return { tools: [{ name: 'crawl_website', description: 'd', parameters: {} }], execute, maxToolCalls };
}

function toolCallsResult(name = 'crawl_website', args = '{"url":"https://a.com"}') {
  return {
    content: null,
    toolCalls: [{ role: 'assistant' as const, content: null, tool_calls: [{ id: 'call_1', type: 'function' as const, function: { name, arguments: args } }] }],
    messages: [{ role: 'user', content: 'hi' }, { role: 'assistant', content: null }],
  };
}

function contentResult(content: string) {
  return { content, toolCalls: [], messages: [{ role: 'user', content: 'hi' }, { role: 'assistant', content }] };
}

describe('chatWithTools', () => {
  beforeEach(() => {
    toolChatOnceMock.mockReset();
    textChatMock.mockReset();
  });

  it('ctx 缺省 → 直接走 textChat（不调用工具）', async () => {
    textChatMock.mockResolvedValueOnce('plain');
    const out = await chatWithTools(CFG, INPUT);
    expect(out).toBe('plain');
    expect(toolChatOnceMock).not.toHaveBeenCalled();
  });

  it('首轮 tool_calls → 执行工具 → 次轮返回正文', async () => {
    const execute = jest.fn().mockResolvedValue('{"text":"抓到的正文"}');
    toolChatOnceMock
      .mockResolvedValueOnce(toolCallsResult())
      .mockResolvedValueOnce(contentResult('最终 JSON'));

    const out = await chatWithTools(CFG, { ...INPUT, jsonMode: true }, ctxOf(execute));

    expect(out).toBe('最终 JSON');
    expect(execute).toHaveBeenCalledWith('crawl_website', '{"url":"https://a.com"}');
    // 第二轮消息历史里带上了 role:'tool' 回填
    const secondCallMessages = toolChatOnceMock.mock.calls[1][1].messages as Array<{ role: string }>;
    expect(secondCallMessages.some((m) => m.role === 'tool')).toBe(true);
  });

  it('工具执行抛错 → 回填 error 文本并继续', async () => {
    const execute = jest.fn().mockRejectedValue(new Error('抓取超时（8 秒）'));
    toolChatOnceMock
      .mockResolvedValueOnce(toolCallsResult())
      .mockResolvedValueOnce(contentResult('降级结果'));

    const out = await chatWithTools(CFG, INPUT, ctxOf(execute));

    expect(out).toBe('降级结果');
    const secondCallMessages = toolChatOnceMock.mock.calls[1][1].messages as Array<{ role: string; content?: string }>;
    const toolMsg = secondCallMessages.find((m) => m.role === 'tool');
    expect(toolMsg?.content).toContain('抓取超时');
  });

  it('工具次数用尽 → 进入 tool_choice:none 收尾轮', async () => {
    const execute = jest.fn().mockResolvedValue('{"text":"a"}');
    toolChatOnceMock
      .mockResolvedValueOnce(toolCallsResult())
      .mockResolvedValueOnce(toolCallsResult())
      .mockResolvedValueOnce(contentResult('收尾结果'));

    const out = await chatWithTools(CFG, INPUT, ctxOf(execute, 1));

    expect(out).toBe('收尾结果');
    expect(execute).toHaveBeenCalledTimes(1);
    const lastCall = toolChatOnceMock.mock.calls[toolChatOnceMock.mock.calls.length - 1][1];
    expect(lastCall.toolChoice).toBe('none');
  });

  it('全部轮次都只发 tool_calls → 收尾轮强制定稿', async () => {
    const execute = jest.fn().mockResolvedValue('{"text":"a"}');
    for (let i = 0; i < TOOL_LOOP_MAX_ROUNDS; i += 1) toolChatOnceMock.mockResolvedValueOnce(toolCallsResult());
    toolChatOnceMock.mockResolvedValueOnce(contentResult('定稿'));

    const out = await chatWithTools(CFG, INPUT, ctxOf(execute, 99));

    expect(out).toBe('定稿');
    expect(toolChatOnceMock).toHaveBeenCalledTimes(TOOL_LOOP_MAX_ROUNDS + 1);
    expect(toolChatOnceMock.mock.calls[TOOL_LOOP_MAX_ROUNDS][1].toolChoice).toBe('none');
  });

  it('工具轮整体异常 → 回退一次无工具调用', async () => {
    toolChatOnceMock.mockRejectedValue(new Error('AI 服务认证失败'));
    textChatMock.mockResolvedValueOnce('保底结果');

    const out = await chatWithTools(CFG, INPUT, ctxOf(jest.fn()));

    expect(out).toBe('保底结果');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pnpm --filter @lumira/backend test -- src/modules/ai/tools/text-tool-loop.spec.ts -v`
Expected: FAIL，`Cannot find module './text-tool-loop'`

- [ ] **Step 3: Write minimal implementation**

Create `lumira-server/packages/backend/src/modules/ai/tools/text-tool-loop.ts`:

```ts
// lumira-server/packages/backend/src/modules/ai/tools/text-tool-loop.ts
// 通用「文本模型工具循环」原语：ctx 缺省 = 旧行为（单次 textChat）。
// 设计文档：docs/superpowers/specs/2026-09-28-ai-text-tool-web-crawl-design.md 第一节
//
// 循环：带 tools 多轮 → 执行工具 → 回填 role:'tool' → 再决定；
// 轮次/次数用尽后以 tool_choice:'none' 收尾，逼模型输出最终内容。

import { textChat, toolChatOnce, type LlmEndpoint, type ToolDef } from '../llm-client';

export interface TextToolContext {
  tools: ToolDef[];
  /** 执行工具，返回回填给模型的字符串（内部自行把异常转成 error 文本） */
  execute(name: string, argsJson: string): Promise<string>;
  /** 单次会话允许的工具调用总次数上限 */
  maxToolCalls: number;
}

export interface ChatWithToolsInput {
  systemPrompt: string;
  userText: string;
  jsonMode?: boolean;
  temperature?: number;
  timeoutMs?: number;
  maxTokens?: number;
}

/** 带工具的最大轮次（不含收尾轮） */
export const TOOL_LOOP_MAX_ROUNDS = 3;

const DEFAULT_TEMPERATURE = 0.3;
const DEFAULT_TIMEOUT_MS = 300_000;

/**
 * 文本模型对话（可带工具）。ctx 缺省或 tools 为空 → 等价 textChat（行为零变化）。
 */
export async function chatWithTools(cfg: LlmEndpoint, input: ChatWithToolsInput, ctx?: TextToolContext): Promise<string> {
  if (!ctx || ctx.tools.length === 0) {
    return textChat(cfg, input);
  }

  const temperature = input.temperature ?? DEFAULT_TEMPERATURE;
  const timeoutMs = input.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  const trace = { title: '工具调用 · LLM', systemPrompt: input.systemPrompt, userPrompt: input.userText };

  let messages: unknown[] = [
    { role: 'system', content: input.systemPrompt },
    { role: 'user', content: input.userText },
  ];
  let used = 0;

  try {
    for (let round = 0; round < TOOL_LOOP_MAX_ROUNDS; round += 1) {
      const reachedLimit = used >= ctx.maxToolCalls;
      const res = await toolChatOnce(cfg, {
        messages,
        tools: ctx.tools,
        toolChoice: reachedLimit ? 'none' : 'auto',
        temperature,
        timeoutMs,
        maxTokens: input.maxTokens,
        ...trace,
      });
      messages = res.messages;

      if (reachedLimit) {
        if (res.content && res.content.trim()) return res.content;
        break;
      }
      if (res.toolCalls.length === 0) {
        if (res.content && res.content.trim()) return res.content;
        break;
      }

      for (const call of res.toolCalls) {
        for (const tc of call.tool_calls) {
          let resultText: string;
          if (used >= ctx.maxToolCalls) {
            resultText = '{"error":"已达本次会话的网页抓取上限，请基于已有信息直接输出最终结果"}';
          } else {
            used += 1;
            try {
              resultText = await ctx.execute(tc.function.name, tc.function.arguments);
            } catch (err) {
              const message = err instanceof Error ? err.message : String(err);
              resultText = JSON.stringify({ error: message.slice(0, 200) });
            }
          }
          messages = [...messages, { role: 'tool', tool_call_id: tc.id, content: resultText }];
        }
      }
    }

    // 收尾轮：强制无工具调用，逼模型输出最终 JSON / 正文
    const finalRes = await toolChatOnce(cfg, {
      messages,
      tools: ctx.tools,
      toolChoice: 'none',
      jsonMode: input.jsonMode ?? false,
      temperature,
      timeoutMs,
      maxTokens: input.maxTokens,
      ...trace,
    });
    if (finalRes.content && finalRes.content.trim()) return finalRes.content;
    throw new Error('AI 服务返回内容为空');
  } catch {
    // 工具轮整体异常 → 回退一次无工具调用（保底，保证链路仍能产出结果）
    return textChat(cfg, { ...input });
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pnpm --filter @lumira/backend test -- src/modules/ai/tools/text-tool-loop.spec.ts -v`
Expected: PASS（6 个用例）

- [ ] **Step 5: Commit**

```bash
git add lumira-server/packages/backend/src/modules/ai/tools/text-tool-loop.ts lumira-server/packages/backend/src/modules/ai/tools/text-tool-loop.spec.ts
git commit -m "feat(ai): 新增通用文本工具循环 chatWithTools（多轮 + 预算护栏 + 收尾强制定稿）"
```

---

### Task 4: 工具注册表 `crawl_website` + 爬取采集事件

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/llm-trace.ts`（追加 `traceCrawlCall`）
- Create: `lumira-server/packages/backend/src/modules/ai/tools/text-tools.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/tools/text-tools.spec.ts`

**Interfaces:**
- Consumes: `crawlUrl`（Task 1）、`TextToolContext`（Task 3）、`traceCrawlCall`、`type ToolDef`
- Produces:
  - `llm-trace.ts`: `export function traceCrawlCall(input: { url: string }): TraceCallHandle | null`
  - `text-tools.ts`:
    - `export interface CrawlToolConfig { enabled: boolean; maxPerSession: number }`
    - `export const CRAWL_TOOL_NAME = 'crawl_website'`
    - `export function buildCrawlToolDef(): ToolDef`
    - `export function createToolExecutor(): TextToolContext['execute']`
    - `export function resolveTextTools(cfg: { crawl?: CrawlToolConfig } | undefined | null): TextToolContext | undefined`

- [ ] **Step 1: Add trace helper**

在 `lumira-server/packages/backend/src/modules/ai/llm-trace.ts` 的 `traceSearchCall` 之后追加：

```ts
/** 记录一次网页爬取（工具执行器内调用）；host 作为事件标题便于后台时间线识别 */
export function traceCrawlCall(input: { url: string }): TraceCallHandle | null {
  let host = input.url;
  try {
    host = new URL(input.url).host;
  } catch {
    // 非法 URL 保留原值（失败会由 crawlUrl 抛错并记 fail）
  }
  return startCall({ type: 'search', title: `网页爬取 · ${host}`, userPrompt: input.url });
}
```

- [ ] **Step 2: Write the failing test**

Create `lumira-server/packages/backend/src/modules/ai/tools/text-tools.spec.ts`:

```ts
import { CRAWL_TOOL_NAME, buildCrawlToolDef, createToolExecutor, resolveTextTools } from './text-tools';
import { crawlUrl } from './crawl-url';

jest.mock('./crawl-url', () => ({ crawlUrl: jest.fn() }));
jest.mock('../llm-trace', () => ({ traceCrawlCall: () => null }));

const crawlUrlMock = crawlUrl as jest.Mock;

describe('buildCrawlToolDef', () => {
  it('工具定义 name/parameters 正确', () => {
    const def = buildCrawlToolDef();
    expect(def.name).toBe(CRAWL_TOOL_NAME);
    expect(def.parameters).toMatchObject({ type: 'object', required: ['url'] });
  });
});

describe('createToolExecutor', () => {
  beforeEach(() => crawlUrlMock.mockReset());

  it('成功：返回含正文的 JSON 字符串', async () => {
    crawlUrlMock.mockResolvedValueOnce({ url: 'https://a.com', text: '正文', chars: 2, truncated: false });
    const out = await createToolExecutor()(CRAWL_TOOL_NAME, '{"url":"https://a.com"}');
    expect(JSON.parse(out)).toMatchObject({ text: '正文', truncated: false });
  });

  it('缺 url 参数抛错', async () => {
    await expect(createToolExecutor()(CRAWL_TOOL_NAME, '{}')).rejects.toThrow('缺少 url');
  });

  it('未知工具名抛错', async () => {
    await expect(createToolExecutor()('other_tool', '{}')).rejects.toThrow('未知工具');
  });

  it('非法 arguments JSON 抛错', async () => {
    await expect(createToolExecutor()(CRAWL_TOOL_NAME, 'not-json')).rejects.toThrow('参数解析失败');
  });
});

describe('resolveTextTools', () => {
  it('未开启返回 undefined', () => {
    expect(resolveTextTools(undefined)).toBeUndefined();
    expect(resolveTextTools({ crawl: { enabled: false, maxPerSession: 3 } })).toBeUndefined();
  });

  it('开启时下发工具并夹紧次数上限到 1~6', () => {
    const ctx = resolveTextTools({ crawl: { enabled: true, maxPerSession: 99 } });
    expect(ctx?.tools).toHaveLength(1);
    expect(ctx?.maxToolCalls).toBe(6);

    const ctx2 = resolveTextTools({ crawl: { enabled: true, maxPerSession: 0 } });
    expect(ctx2?.maxToolCalls).toBe(1);
  });
});
```

- [ ] **Step 3: Run test to verify it fails**

Run: `pnpm --filter @lumira/backend test -- src/modules/ai/tools/text-tools.spec.ts -v`
Expected: FAIL，`Cannot find module './text-tools'`

- [ ] **Step 4: Write minimal implementation**

Create `lumira-server/packages/backend/src/modules/ai/tools/text-tools.ts`:

```ts
// lumira-server/packages/backend/src/modules/ai/tools/text-tools.ts
// 文本模型可用工具的注册表：首个工具 crawl_website。
// 设计文档：docs/superpowers/specs/2026-09-28-ai-text-tool-web-crawl-design.md 第二节
//
// resolveTextTools(cfg) 是唯一的开关入口：未开启返回 undefined → 调用方行为与旧版一致。

import type { ToolDef } from '../llm-client';
import { traceCrawlCall } from '../llm-trace';
import { crawlUrl } from './crawl-url';
import type { TextToolContext } from './text-tool-loop';

export interface CrawlToolConfig {
  enabled: boolean;
  maxPerSession: number;
}

export const CRAWL_TOOL_NAME = 'crawl_website';

const MAX_TOOL_CALLS_LOWER = 1;
const MAX_TOOL_CALLS_UPPER = 6;

/** crawl_website 工具定义 */
export function buildCrawlToolDef(): ToolDef {
  return {
    name: CRAWL_TOOL_NAME,
    description:
      '抓取指定网页的正文纯文本（用于读取搜索结果或用户提供链接的完整内容）。仅当标题/摘要不足以支撑判断时调用；同一链接不要重复抓取。',
    parameters: {
      type: 'object',
      properties: {
        url: { type: 'string', description: '要抓取的网页绝对地址（http/https）' },
      },
      required: ['url'],
    },
  };
}

/** 解析工具入参 JSON；非法时抛可读错误 */
function parseArgs(argsJson: string): Record<string, unknown> {
  try {
    const parsed = JSON.parse(argsJson || '{}');
    return parsed && typeof parsed === 'object' ? (parsed as Record<string, unknown>) : {};
  } catch {
    throw new Error('工具参数解析失败（非合法 JSON）');
  }
}

/** 工具执行器：把 crawlUrl 的异常留给循环层回填为 error 文本 */
export function createToolExecutor(): TextToolContext['execute'] {
  return async (name: string, argsJson: string): Promise<string> => {
    if (name !== CRAWL_TOOL_NAME) throw new Error(`未知工具：${name}`);
    const args = parseArgs(argsJson);
    const url = typeof args.url === 'string' ? args.url.trim() : '';
    if (!url) throw new Error('缺少 url 参数');

    const handle = traceCrawlCall({ url });
    try {
      const r = await crawlUrl(url);
      handle?.done(r.text.slice(0, 200), {
        resultBrief: `抓取 ${r.chars} 字${r.truncated ? '（已截断）' : ''}`,
      });
      return JSON.stringify({ url: r.url, text: r.text, truncated: r.truncated });
    } catch (err) {
      handle?.fail(err);
      throw err;
    }
  };
}

/**
 * 开关入口：cfg.crawl.enabled !== true → undefined（文本调用退回旧行为）。
 * maxPerSession 夹紧到 1~6，防止后台异常值。
 */
export function resolveTextTools(cfg: { crawl?: CrawlToolConfig } | undefined | null): TextToolContext | undefined {
  const crawl = cfg?.crawl;
  if (!crawl?.enabled) return undefined;
  const raw = Math.floor(Number(crawl.maxPerSession));
  const maxToolCalls = Math.min(Math.max(Number.isFinite(raw) ? raw : MAX_TOOL_CALLS_LOWER, MAX_TOOL_CALLS_LOWER), MAX_TOOL_CALLS_UPPER);
  return { tools: [buildCrawlToolDef()], execute: createToolExecutor(), maxToolCalls };
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `pnpm --filter @lumira/backend test -- src/modules/ai/tools/text-tools.spec.ts -v`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lumira-server/packages/backend/src/modules/ai/llm-trace.ts lumira-server/packages/backend/src/modules/ai/tools/text-tools.ts lumira-server/packages/backend/src/modules/ai/tools/text-tools.spec.ts
git commit -m "feat(ai): 注册 crawl_website 工具与开关入口，新增爬取采集事件"
```

---

### Task 5: 开关配置——DB 迁移 / schema / AiConfigService / DTO

**Files:**
- Create: `lumira-server/packages/backend/src/database/migrations/048_ai_config_web_crawl.sql`
- Modify: `lumira-server/packages/backend/src/database/schema.ts`（`aiProviderConfig` 表定义）
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-config.service.ts`
- Modify: `lumira-server/packages/backend/src/modules/ai/dto/update-ai-config.dto.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/ai-config.crawl.spec.ts`

**Interfaces:**
- Produces（供 Task 7/8 使用）：
  - `ActiveAiConfig` 新增 `crawl: { enabled: boolean; maxPerSession: number }`
  - `AiConfigView` 新增 `crawlEnabled: boolean`、`crawlMaxPerSession: number`
  - `UpdateAiConfigDto` 新增 `crawlEnabled?: boolean`、`crawlMaxPerSession?: number`

- [ ] **Step 1: Write the migration**

Create `lumira-server/packages/backend/src/database/migrations/048_ai_config_web_crawl.sql`:

```sql
-- 048_ai_config_web_crawl.sql
-- AI 设置：网页爬取工具开关（文本模型可按需调用 crawl_website 抓取网页正文）
-- 幂等：重复执行仅提示列已存在

ALTER TABLE `ai_provider_config`
  ADD COLUMN `crawl_enabled` INT NOT NULL DEFAULT 0 COMMENT '网页爬取工具开关：1=启用（文本模型可调用 crawl_website）；0=关闭',
  ADD COLUMN `crawl_max_per_session` INT NOT NULL DEFAULT 3 COMMENT '单次文本会话最多爬取次数（1~6）';
```

- [ ] **Step 2: 更新 schema.ts**

在 `aiProviderConfig` 表定义中，`llmMaxTokens` 字段之后追加（保持现有列命名风格）：

```ts
  /** 网页爬取工具开关：1=启用（文本模型可调用 crawl_website）；0=关闭 */
  crawlEnabled: int('crawl_enabled').notNull().default(0),
  /** 单次文本会话最多爬取次数（1~6） */
  crawlMaxPerSession: int('crawl_max_per_session').notNull().default(3),
```

- [ ] **Step 3: 更新 DTO**

在 `lumira-server/packages/backend/src/modules/ai/dto/update-ai-config.dto.ts` 末尾（`llmMaxTokens` 字段之后）追加：

```ts
  @IsOptional()
  @IsBoolean()
  crawlEnabled?: boolean;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(6)
  crawlMaxPerSession?: number;
```

（若该文件尚未导入 `Min`/`Max`，在既有 `class-validator` 导入语句中补上。）

- [ ] **Step 4: 更新 AiConfigService**

4.1 在 `lumira-server/packages/backend/src/modules/ai/ai-config.service.ts` 的默认值常量区（`DEFAULT_LLM_MAX_TOKENS` 一行之后）追加：

```ts
/** 网页爬取默认次数上限（与迁移 048 的 DEFAULT 一致） */
const DEFAULT_CRAWL_MAX_PER_SESSION = 3;
```

4.2 `AiConfigView` 接口末尾（`llmMaxTokens` 之后）追加：

```ts
  /** 网页爬取工具开关 */
  crawlEnabled: boolean;
  /** 单次文本会话最多爬取次数（1~6） */
  crawlMaxPerSession: number;
```

4.3 `ActiveAiConfig` 接口末尾（`runtime` 之前）追加：

```ts
  /** 网页爬取工具（文本模型工具循环的开关与预算） */
  crawl: {
    enabled: boolean;
    maxPerSession: number;
  };
```

4.4 `get()` 返回值末尾（`llmMaxTokens` 之后）追加：

```ts
      crawlEnabled: row.crawlEnabled === 1,
      crawlMaxPerSession: row.crawlMaxPerSession ?? DEFAULT_CRAWL_MAX_PER_SESSION,
```

4.5 `getActiveConfig()` 返回对象末尾（`runtime` 块之后）追加：

```ts
      crawl: {
        enabled: row.crawlEnabled === 1,
        maxPerSession: row.crawlMaxPerSession ?? DEFAULT_CRAWL_MAX_PER_SESSION,
      },
```

4.6 `save()`：在 `const now = Math.floor(Date.now() / 1000);` 附近（`existing` 已查询之后）加入校验与归一：

```ts
    if (dto.crawlMaxPerSession !== undefined && (dto.crawlMaxPerSession < 1 || dto.crawlMaxPerSession > 6)) {
      throw new BadRequestException('网页爬取次数上限需在 1~6 之间');
    }
    const crawlEnabled = dto.crawlEnabled === undefined ? (existing?.crawlEnabled === 1 ? 1 : 0) : dto.crawlEnabled ? 1 : 0;
    const crawlMaxPerSession = dto.crawlMaxPerSession ?? existing?.crawlMaxPerSession ?? DEFAULT_CRAWL_MAX_PER_SESSION;
```

4.7 在 `save()` 的 **insert** `.values({ ... })` 对象中（`llmMaxTokens,` 之后）追加：

```ts
        crawlEnabled,
        crawlMaxPerSession,
```

4.8 在 `save()` 的 **update** `.set({ ... })` 对象中（`llmMaxTokens,` 之后）追加：

```ts
          crawlEnabled,
          crawlMaxPerSession,
```

- [ ] **Step 5: Write the failing test**

Create `lumira-server/packages/backend/src/modules/ai/ai-config.crawl.spec.ts`:

```ts
import { AiConfigService } from './ai-config.service';
import type { DatabaseService } from '../../database/database.service';

function makeService(row: Record<string, unknown> | null) {
  const db = {
    query: { aiProviderConfig: { findFirst: jest.fn().mockResolvedValue(row) } },
    insert: jest.fn(() => ({ values: jest.fn().mockResolvedValue(undefined) })),
    update: jest.fn(() => ({ set: jest.fn(() => ({ where: jest.fn().mockResolvedValue(undefined) })) })),
  };
  const dbService = { getDb: () => db } as unknown as DatabaseService;
  return { service: new AiConfigService(dbService), db };
}

const BASE_ROW = {
  provider: 'qwen',
  baseUrl: 'https://api.example.com/v1',
  apiKey: 'k',
  visionModel: 'qwen-vl-max',
  imageModel: 'wanx',
  textModel: '',
  enabled: 1,
  searchEnabled: 0,
  maxIterations: 3,
  llmRetryCount: 2,
  llmTimeoutMs: 300000,
  llmMaxTokens: 8192,
  crawlEnabled: 1,
  crawlMaxPerSession: 5,
};

describe('AiConfigService 网页爬取开关', () => {
  it('get() 映射 crawlEnabled / crawlMaxPerSession', async () => {
    const { service } = makeService(BASE_ROW);
    const view = await service.get();
    expect(view).toMatchObject({ configured: true, crawlEnabled: true, crawlMaxPerSession: 5 });
  });

  it('get() 缺列时回退默认 3 且默认关闭', async () => {
    const { service } = makeService({ ...BASE_ROW, crawlEnabled: undefined, crawlMaxPerSession: undefined });
    const view = await service.get();
    expect(view).toMatchObject({ crawlEnabled: false, crawlMaxPerSession: 3 });
  });

  it('getActiveConfig() 暴露 crawl 配置', async () => {
    const { service } = makeService(BASE_ROW);
    const cfg = await service.getActiveConfig();
    expect(cfg.crawl).toEqual({ enabled: true, maxPerSession: 5 });
  });

  it('save() 越界次数上限抛 400', async () => {
    const { service } = makeService(BASE_ROW);
    await expect(
      service.save({
        provider: 'qwen',
        baseUrl: 'https://api.example.com/v1',
        visionModel: 'qwen-vl-max',
        imageModel: 'wanx',
        crawlMaxPerSession: 9,
      } as never),
    ).rejects.toThrow('1~6');
  });
});
```

- [ ] **Step 6: Run test to verify it fails, then passes**

Run: `pnpm --filter @lumira/backend test -- src/modules/ai/ai-config.crawl.spec.ts -v`
Expected: 先 FAIL（`crawlEnabled` 为 undefined），完成 Step 2~4 后 PASS

- [ ] **Step 7: 回归 ai-config 既有测试**

Run: `pnpm --filter @lumira/backend test -- src/modules/ai/ai-config.service.spec.ts -v`
Expected: PASS（若既有断言为「返回对象全等」，需按新字段同步补上 `crawlEnabled` / `crawlMaxPerSession`）

- [ ] **Step 8: Commit**

```bash
git add lumira-server/packages/backend/src/database/migrations/048_ai_config_web_crawl.sql lumira-server/packages/backend/src/database/schema.ts lumira-server/packages/backend/src/modules/ai/ai-config.service.ts lumira-server/packages/backend/src/modules/ai/dto/update-ai-config.dto.ts lumira-server/packages/backend/src/modules/ai/ai-config.crawl.spec.ts
git commit -m "feat(ai): AI 设置新增网页爬取独立开关（迁移 048 + schema + 服务 + DTO）"
```

---

### Task 6: 后台 AI 设置页新增「网页爬取」分区

**Files:**
- Modify: `lumira-server/packages/admin/src/types/admin.ts`（`searchEnabled` 所在的 AI 配置类型）
- Modify: `lumira-server/packages/admin/src/components/ai-config-form.tsx`

**Interfaces:**
- Consumes: Task 5 的 `crawlEnabled` / `crawlMaxPerSession`（GET/PUT）

- [ ] **Step 1: 类型补齐**

在 `lumira-server/packages/admin/src/types/admin.ts` 中 `searchEnabled: boolean;`（约 453 行）所在接口追加 `crawlEnabled: boolean; crawlMaxPerSession: number;`；在 `searchEnabled?: boolean;`（约 511 行）所在请求类型追加 `crawlEnabled?: boolean; crawlMaxPerSession?: number;`。

- [ ] **Step 2: 表单状态与提交**

在 `lumira-server/packages/admin/src/components/ai-config-form.tsx`：

1. 表单 state 初始值处（`searchMode: initial.searchEnabled ...` 约 198 行附近）追加：
   `webCrawl: initial.crawlEnabled === true, crawlMaxPerSession: initial.crawlMaxPerSession ?? 3,`
2. 提交 payload 构造处（`payload.searchEnabled = form.searchMode !== 'off';` 约 497 行之后）追加：

```ts
      payload.crawlEnabled = form.webCrawl;
      payload.crawlMaxPerSession = Number(form.crawlMaxPerSession) || 3;
```

- [ ] **Step 3: 新增 UI 分区**

在「研究管线」分区之后新增一个同级卡片（沿用该文件既有 `Card` / `Switch` / `Input` 组件与 label 样式，不改动任何既有分区）：

- 标题：`网页爬取`
- 说明文案：`开启后，文本模型可在生成过程中按需抓取搜索结果/用户提供链接的网页正文（仅静态页面，单会话有次数上限）。`
- 控件 1：开关，绑定 `form.webCrawl`
- 控件 2：数字输入（min=1 max=6），绑定 `form.crawlMaxPerSession`，仅 `form.webCrawl` 为真时可用

- [ ] **Step 4: 校验**

Run: `pnpm --filter @lumira/admin build`
Expected: 构建通过（TypeScript 无错）

- [ ] **Step 5: Commit**

```bash
git add lumira-server/packages/admin/src/types/admin.ts lumira-server/packages/admin/src/components/ai-config-form.tsx
git commit -m "feat(admin): AI 设置新增网页爬取开关与次数上限"
```

---

### Task 7: `llm-json.ts` 与 JSON 文本调用点接线

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/llm-json.ts`
- Modify: `lumira-server/packages/backend/src/modules/ai/style-profile.service.ts:94-98`
- Modify: `lumira-server/packages/backend/src/modules/ai/pose-ref-sheet.service.ts:166-170`
- Modify: `lumira-server/packages/backend/src/modules/ai/draft-refine.service.ts:88-96`
- Modify: `lumira-server/packages/backend/src/modules/ai/image-score.service.ts:196-204`
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-analyze.service.ts`（文字路径 `textChatJson` 调用处）
- Test: `lumira-server/packages/backend/src/modules/ai/llm-json.ctx.spec.ts`

**Interfaces:**
- Consumes: `chatWithTools`、`TextToolContext`（Task 3）、`resolveTextTools`（Task 4）、`ActiveAiConfig.crawl`（Task 5）
- Produces: `JsonChatInput` 新增 `ctx?: TextToolContext`

- [ ] **Step 1: Write the failing test**

Create `lumira-server/packages/backend/src/modules/ai/llm-json.ctx.spec.ts`:

```ts
import { textChatJson, type LlmJsonRuntime } from './llm-json';
import { textChat } from './llm-client';
import { chatWithTools } from './tools/text-tool-loop';

jest.mock('./llm-client', () => ({
  textChat: jest.fn(),
  visionChat: jest.fn(),
}));

jest.mock('./tools/text-tool-loop', () => ({ chatWithTools: jest.fn() }));

jest.mock('./llm-trace', () => ({ traceNote: jest.fn(), traceLlmCall: () => null }));

const chatWithToolsMock = chatWithTools as jest.Mock;
const textChatMock = textChat as jest.Mock;

const RUNTIME: LlmJsonRuntime = { retryCount: 0, timeoutMs: 300000, maxTokens: 8192 };
const CFG = { provider: 'qwen', baseUrl: 'https://api.example.com/v1', apiKey: 'k', model: 'qwen-plus' };
const CTX = { tools: [{ name: 'crawl_website', description: 'd', parameters: {} }], execute: jest.fn(), maxToolCalls: 3 };

describe('textChatJson 透传工具上下文', () => {
  beforeEach(() => {
    chatWithToolsMock.mockReset();
    textChatMock.mockReset();
  });

  it('带 ctx → 走 chatWithTools', async () => {
    chatWithToolsMock.mockResolvedValueOnce('{"a":1}');
    const out = await textChatJson(CFG, { systemPrompt: 'sys', userText: 'hi', ctx: CTX }, RUNTIME);
    expect(out).toEqual({ a: 1 });
    expect(chatWithToolsMock.mock.calls[0][2]).toBe(CTX);
  });

  it('不带 ctx → 请求等价于旧版 textChat', async () => {
    textChatMock.mockResolvedValueOnce('{"b":2}');
    const out = await textChatJson(CFG, { systemPrompt: 'sys', userText: 'hi' }, RUNTIME);
    expect(out).toEqual({ b: 2 });
    expect(chatWithToolsMock.mock.calls[0][2]).toBeUndefined();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pnpm --filter @lumira/backend test -- src/modules/ai/llm-json.ctx.spec.ts -v`
Expected: FAIL（`ctx` 未被透传 / `chatWithTools` 未被调用）

- [ ] **Step 3: 修改 llm-json.ts**

3.1 顶部导入改为：

```ts
import { textChat, visionChat, type LlmEndpoint } from './llm-client';
import { chatWithTools } from './tools/text-tool-loop';
import type { TextToolContext } from './tools/text-tool-loop';
```

3.2 `JsonChatInput` 追加：

```ts
  /** 文本模型工具上下文（可选；缺省 = 无工具，行为与旧版一致） */
  ctx?: TextToolContext;
```

3.3 `textChatJson` 的 `callChat` 改为：

```ts
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
```

（`visionChatJson` 保持不动。）

- [ ] **Step 4: 各调用点透传 ctx**

在下列每一处 `textChatJson(...)` 的**输入对象内**新增一个字段 `ctx: resolveTextTools(cfg),`，并在文件顶部补 `import { resolveTextTools } from './tools/text-tools';`：

- `style-profile.service.ts`：

```ts
      const json = await textChatJson(
        cfg.text,
        { systemPrompt: STYLE_RESOLVE_SYSTEM_PROMPT, userText, temperature: 0.3, ctx: resolveTextTools(cfg) },
        cfg.runtime,
      );
```

- `pose-ref-sheet.service.ts`：

```ts
    const json = await textChatJson(
      cfg.text,
      { systemPrompt, userText, temperature: 0.4, ctx: resolveTextTools(cfg) },
      cfg.runtime,
    );
```

- `draft-refine.service.ts`：

```ts
          systemPrompt: buildRefineSystemPrompt(input.styleProfile),
          userText: buildRefineUserText(input),
          temperature: 0.5,
          ctx: resolveTextTools(cfg),
```

- `image-score.service.ts`：

```ts
          systemPrompt: buildScoreSystemPrompt(profile),
          userText: buildScoreUserText(input),
          temperature: 0.3,
          ctx: resolveTextTools(cfg),
```

- `ai-analyze.service.ts`：文字草稿路径的 `textChatJson` 调用同样补 `ctx: resolveTextTools(cfg)`（带图路径 `visionChatJson` **不动**）。

定位命令（在仓库根执行）：

```bash
rg -n "textChatJson" lumira-server/packages/backend/src/modules/ai/ai-analyze.service.ts
```

- [ ] **Step 5: Run tests**

Run: `pnpm --filter @lumira/backend test -- src/modules/ai/llm-json.ctx.spec.ts src/modules/ai/style-profile.service.spec.ts src/modules/ai/pose-ref-sheet.service.spec.ts src/modules/ai/draft-refine.service.spec.ts src/modules/ai/image-score.service.spec.ts -v`
Expected: 全部 PASS（这些 spec 的 `cfg` 无 `crawl` → `resolveTextTools` 返回 `undefined` → 行为不变）

- [ ] **Step 6: Commit**

```bash
git add lumira-server/packages/backend/src/modules/ai/llm-json.ts lumira-server/packages/backend/src/modules/ai/llm-json.ctx.spec.ts lumira-server/packages/backend/src/modules/ai/style-profile.service.ts lumira-server/packages/backend/src/modules/ai/pose-ref-sheet.service.ts lumira-server/packages/backend/src/modules/ai/draft-refine.service.ts lumira-server/packages/backend/src/modules/ai/image-score.service.ts lumira-server/packages/backend/src/modules/ai/ai-analyze.service.ts
git commit -m "feat(ai): JSON 文本识别链路透传工具上下文（可调用 crawl_website）"
```

---

### Task 8: 非 JSON 文本调用点接线 + 全量回归 + 优化登记

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/trend-research/research-digest.service.ts:97-103`
- Modify: `lumira-server/packages/backend/src/modules/ai/trend-research/trend-research.service.ts`（查询词重组 `textChat` 调用处）
- Modify: `lumira-server/packages/backend/src/modules/ai/trend-research/web-search-vendor.ts:61`
- Modify: `lumira-server/packages/backend/src/modules/ai/image-prompt.composer.ts:410-415`
- Modify: `lumira-server/packages/backend/src/modules/ai/prompt-polisher.ts:20-25`
- Modify: `docs/future-optimizations.md`

**Interfaces:**
- Consumes: `chatWithTools`（Task 3）、`resolveTextTools`（Task 4）、`ActiveAiConfig.crawl`（Task 5）

- [ ] **Step 1: 资料整理（重点场景）**

`research-digest.service.ts`：

1. 顶部补：`import { chatWithTools } from '../tools/text-tool-loop';`、`import { resolveTextTools } from '../tools/text-tools';`
2. 把 `const content = await textChat(cfg.text, { ... })` 改为：

```ts
          const content = await chatWithTools(
            cfg.text,
            {
              systemPrompt: SYSTEM_PROMPT,
              userText: `${describeTodayUtc8()}\n创作意图：${(topic || '').trim() || '（未提供）'}\n\n检索条目（共 ${items.length} 条）：\n${renderSourceItems(items)}`,
              temperature: 0.3,
              jsonMode: true,
              timeoutMs: 30_000,
            },
            resolveTextTools(cfg),
          );
```

- [ ] **Step 2: 查询词重组 / 厂商检索 / 生图润色 / 提示词润色**

对下列 4 处，把 `textChat(` 替换为 `chatWithTools(`，并在实参末尾补 `resolveTextTools(cfg)`（或该作用域内等价的配置变量），顶部补对应 import。每处替换后保持其余参数不变：

- `trend-research.service.ts`（查询词重组）——用 `rg -n "textChat\(" lumira-server/packages/backend/src/modules/ai/trend-research/trend-research.service.ts` 定位后再改。
- `web-search-vendor.ts:61`：`const content = await textChat(searchEndpoint, { ... })` → `chatWithTools(searchEndpoint, { ... }, resolveTextTools(cfg))`（若该函数无 `cfg`，用其现有的配置入参提供 `crawl` 字段；若确实取不到，则此处**跳过不改**并在提交信息中说明）。
- `image-prompt.composer.ts:410`：`textChat(textEndpoint, { ... })` → `chatWithTools(textEndpoint, { ... }, resolveTextTools(cfg))`。
- `prompt-polisher.ts:20`：`textChat(textEndpoint, { ... })` → `chatWithTools(textEndpoint, { ... }, resolveTextTools(cfg))`。

> 说明：非 JSON 调用点全部以 `resolveTextTools(...)` 返回 `undefined` 作为「未开启」路径，返回 `undefined` 时 `chatWithTools` 内部即调用 `textChat`，行为不变。

- [ ] **Step 3: 全量回归**

Run: `pnpm --filter @lumira/backend test -v`
Expected: 全部 PASS。若个别 spec 因新增 `crawl` 字段导致对象全等断言失败，按 Task 5 的新字段补断言（不改业务逻辑）。

- [ ] **Step 4: 类型检查**

Run: `pnpm --filter @lumira/backend build`
Expected: 构建通过

- [ ] **Step 5: 登记后续优化**

在 `docs/future-optimizations.md` 末尾追加（沿用文档既有格式：优先级 / 模块 / 优化点 / 背景动机 / 目标状态 / 状态标记）：

1. 网页爬取正文抽取为启发式（`<article>/<main>` + 去标签），未做可读性算法 → 后续评估引入 Readability 类方案；
2. 仅支持静态 HTML，不渲染 JS 站点（小红书/抖音正文需另建适配器）；
3. 抓取缓存为进程内 LRU，无跨进程共享。

- [ ] **Step 6: Commit（含推送）**

```bash
git add lumira-server/packages/backend/src/modules/ai/trend-research/research-digest.service.ts lumira-server/packages/backend/src/modules/ai/trend-research/trend-research.service.ts lumira-server/packages/backend/src/modules/ai/trend-research/web-search-vendor.ts lumira-server/packages/backend/src/modules/ai/image-prompt.composer.ts lumira-server/packages/backend/src/modules/ai/prompt-polisher.ts docs/future-optimizations.md
git commit -m "feat(ai): 非 JSON 文本链路接入工具循环，登记爬取后续优化"
git push origin master
git push github master
```

---

## 验收清单（全部任务完成后执行）

- [ ] `pnpm --filter @lumira/backend test -v` 全绿
- [ ] `pnpm --filter @lumira/backend build` 通过
- [ ] `pnpm --filter @lumira/admin build` 通过
- [ ] 后台「AI 设置」可见「网页爬取」开关与次数上限，保存后 GET 回显一致
- [ ] 开关关闭时，AI 一键生成链路无任何 `tools` 字段进入请求体（可用既有 trace 的请求体确认）
- [ ] 开关开启后，资料整理步骤可在实时流程面板看到「网页爬取 · <host>」事件
- [ ] `git status` 确认未触碰 `admin/src/components/ai-create/**` 与生图参考图链路文件