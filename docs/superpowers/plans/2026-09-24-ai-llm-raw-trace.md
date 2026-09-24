# AI 全链路 LLM 调用原始数据实时可见 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 后台「AI 一键生成」的实时过程里，每一次 LLM 调用都能看到该次请求的完整提示词与上游返回的**原始响应体**。

**Architecture:** 后端沿用既有 `AsyncLocalStorage` 采集（`llm-trace.ts`）：事件结构新增 `rawResponse` / `attempts`，`llm-client` 改为先读上游响应原文再解析并把原文写进事件；补齐 `toolChat`、`web-search-qwen` 两处遗漏埋点；批量姿势图任务的 `run()` 用 `runWithTrace` 包裹，把生图链路里的 LLM 调用（`composeImagePrompt` → `textChat`）以 `kind:'llm'` + `index` 归属并入批次事件流。前端抽出共享 `TraceCallCard`，分区默认展开并支持一键复制。

**Tech Stack:** NestJS + Fastify（后端，jest 单测）；Next.js App Router + Tailwind + shadcn（后台，vitest 单测/`next build`）。

**Spec:** `docs/superpowers/specs/2026-09-24-ai-llm-raw-trace-design.md`

## Global Constraints

- 语言：所有新增代码注释、提交信息用中文（与仓库既有风格一致）。
- 平台：Windows + PowerShell。**禁止** `&&` / `||` 连接命令，用 `;`。
- 后端单测命令：`pnpm --filter @lumira/backend exec jest <spec文件>`（该包**没有** vitest）。
- 后端类型检查/构建：`pnpm --filter @lumira/backend build`。
- 后台构建：`pnpm --filter @lumira/admin build`；后台单测用 `pnpm exec vitest run <file>`。
- 后台图标必须从 `@phosphor-icons/react/dist/csr/<IconName>` 子路径导入。
- 禁止使用 `toLocaleTimeString` / `toLocaleString` 等本地时区方法（Next.js hydration 报错）；时间格式化手写或用 `lib/utils.ts`。
- 不改动识别 / 生图业务逻辑；`traceLlmCall` 等采集函数在无采集上下文时必须保持 no-op。
- `TRACE_TEXT_CAP` 上调为 `50_000`，超长文本一律截断并标注「…（已截断，原长 N 字）」，**不静默丢内容**。
- 每个任务完成后 push 双远程：`git push origin master` 与 `git push github master`（仅提交本任务涉及的文件，工作树里有其它会话/无关的未提交改动，**不要** `git add -A`）。
- 工作分支：直接改 `master`。

---

### Task 1: 后端 —— `llm-trace` 事件结构扩展（rawResponse / attempts）

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/llm-trace.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/llm-trace.spec.ts`

**Interfaces:**
- Consumes: 无（本任务为起点）
- Produces:
  - `AiTraceEvent.rawResponse?: string` —— 上游原始响应体全文
  - `AiTraceEvent.attempts?: number` —— 实际发出的请求次数
  - `TraceCallHandle.done(response?: string, extra?: { resultBrief?: string; rawResponse?: string; attempts?: number }): void`
  - `TRACE_TEXT_CAP = 50_000`

- [ ] **Step 1: 写失败测试**

在 `llm-trace.spec.ts` 的 `describe('llm-trace', ...)` 内、末尾 `});` 之前追加两个用例：

```ts
  it('done 携带 rawResponse / attempts：原始响应体与请求次数透传', async () => {
    const { events, sink } = collect();
    const raw = '{"choices":[{"message":{"content":"提取正文"}}]}';
    await runWithTrace(sink, async () => {
      const h = traceLlmCall({ model: 'qwen-plus' })!;
      h.done('提取正文', { rawResponse: raw, attempts: 2 });
    });

    expect(events[1]).toMatchObject({
      status: 'done',
      response: '提取正文',
      rawResponse: raw,
      attempts: 2,
    });
  });

  it('rawResponse 超长同样截断并标注原文长度', async () => {
    const { events, sink } = collect();
    const longRaw = 'y'.repeat(TRACE_TEXT_CAP + 5);
    await runWithTrace(sink, async () => {
      const h = traceLlmCall({ model: 'm' })!;
      h.done('ok', { rawResponse: longRaw });
    });

    expect(events[1]!.rawResponse).toContain(`原长 ${longRaw.length} 字`);
    expect(events[1]!.rawResponse!.startsWith('y'.repeat(100))).toBe(true);
  });
```

- [ ] **Step 2: 跑测试确认失败**

Run: `pnpm --filter @lumira/backend exec jest llm-trace`
Expected: FAIL —— `rawResponse` 为 `undefined`（`expect(...).toMatchObject` 收到不含字段的对象），第二条因 `rawResponse` 是 `undefined` 而 `toContain` 报错。

- [ ] **Step 3: 实现**

`llm-trace.ts` 三处改动：

1) `AiTraceEvent` 接口内、`response` 字段之后插入：

```ts
  /** 上游**原始响应体全文**（LLM 为原始 JSON 文本；检索为原始返回），与 response 并列展示 */
  rawResponse?: string;
  /** 实际发出的请求次数（含 jsonMode 降级 / 5xx 重试；1 表示一次成功） */
  attempts?: number;
```

2) 常量上限调整：

```ts
/** 单个字段（提示词 / 响应 / 原始响应体）保留上限：够看全内容，又不让任务对象被超长文本撑爆 */
export const TRACE_TEXT_CAP = 50_000;
```

3) `TraceCallHandle` 与 `startCall().done` 扩展：

```ts
/** 一次调用（LLM / 检索）的完成句柄；无采集上下文时为 null */
export interface TraceCallHandle {
  done(response?: string, extra?: { resultBrief?: string; rawResponse?: string; attempts?: number }): void;
  fail(err: unknown): void;
}
```

```ts
    done(response, extra) {
      store.sink({
        type: input.type,
        step,
        title: input.title || title,
        status: 'done',
        model: input.model,
        response: capText(response),
        rawResponse: capText(extra?.rawResponse),
        attempts: extra?.attempts,
        resultBrief: extra?.resultBrief,
        durationMs: Date.now() - startedAt,
      });
    },
```

- [ ] **Step 4: 跑测试确认通过**

Run: `pnpm --filter @lumira/backend exec jest llm-trace`
Expected: PASS，该文件全部用例通过（含既有的「超长提示词/响应截断」用例）。

- [ ] **Step 5: 提交并推送**

```powershell
git add lumira-server/packages/backend/src/modules/ai/llm-trace.ts lumira-server/packages/backend/src/modules/ai/llm-trace.spec.ts
git commit -m "feat(ai-trace): 事件结构新增 rawResponse/attempts，字段上限提至 5 万字"
git push origin master
git push github master
```

---

### Task 2: 后端 —— `llm-client` 记录上游原始响应体 + `toolChat` 补埋点

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/llm-client.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/llm-client.spec.ts`

**Interfaces:**
- Consumes: Task 1 的 `TraceCallHandle.done(response?, { rawResponse?, attempts?, resultBrief? })`
- Produces:
  - `visionChat` / `textChat`：行为不变（仍返回 `string`），但事件 `done` 带 `rawResponse`（上游原文）与 `attempts`
  - `toolChat`：签名与返回不变（`{ content, toolCalls, messages }`），新增 LLM 事件（title `工具调用 · LLM`）

- [ ] **Step 1: 写失败测试**

在 `llm-client.spec.ts` 顶部 import 行补充 trace 相关导入：

```ts
import { LlmEndpoint, VisionChatInput, textChat, visionChat, toolChat, extractToolCalls, ToolDef } from './llm-client';
import { runWithTrace } from './llm-trace';
import type { AiTraceEvent } from './llm-trace';
```

在文件末尾追加（注意：`TOOL` / `TOOL_CFG` 是 `describe('toolChat')` 内的局部常量，此处需自行定义同名局部常量，不要跨 describe 引用）：

```ts
describe('实时采集：LLM 事件带原始响应体', () => {
  function collect(): { events: Omit<AiTraceEvent, 'seq' | 'ts'>[]; sink: (e: Omit<AiTraceEvent, 'seq' | 'ts'>) => void } {
    const events: Omit<AiTraceEvent, 'seq' | 'ts'>[] = [];
    return { events, sink: (e) => events.push(e) };
  }

  it('textChat：done 事件带 rawResponse（上游原文）与 attempts=1', async () => {
    const rawResponse = JSON.stringify({ choices: [{ message: { content: '模型输出' } }] });
    jest.spyOn(global, 'fetch').mockResolvedValue(new Response(rawResponse, { status: 200 }));
    const { events, sink } = collect();

    const out = await runWithTrace(sink, () => textChat(CFG, { systemPrompt: 'sys', userText: 'hi' }));

    expect(out).toBe('模型输出');
    const done = events.find((e) => e.type === 'llm' && e.status === 'done')!;
    expect(done.response).toBe('模型输出');
    expect(done.rawResponse).toBe(rawResponse);
    expect(done.attempts).toBe(1);
  });

  it('visionChat：jsonMode 400 降级重试后 attempts=2，rawResponse 为最终成功那次的原文', async () => {
    const okRaw = JSON.stringify({ choices: [{ message: { content: '降级后输出' } }] });
    jest.spyOn(global, 'fetch')
      .mockResolvedValueOnce(errorResponse(400, { error: { message: 'bad' } }))
      .mockResolvedValueOnce(new Response(okRaw, { status: 200 }));
    const { events, sink } = collect();

    const out = await runWithTrace(sink, () => visionChat(CFG, { ...baseInput(), jsonMode: true }));

    expect(out).toBe('降级后输出');
    const done = events.find((e) => e.type === 'llm' && e.status === 'done')!;
    expect(done.attempts).toBe(2);
    expect(done.rawResponse).toBe(okRaw);
  });

  it('toolChat：记录提示词、原始响应体与工具调用名', async () => {
    const tool: ToolDef = {
      name: 'web_search',
      description: '联网搜索',
      parameters: { type: 'object', properties: { query: { type: 'string' } } },
    };
    const rawResponse = JSON.stringify({
      choices: [{ message: { content: null, tool_calls: [
        { id: 'call_1', type: 'function', function: { name: 'web_search', arguments: '{"query":"秋日人像"}' } },
      ] } }],
    });
    jest.spyOn(global, 'fetch').mockResolvedValue(new Response(rawResponse, { status: 200 }));
    const { events, sink } = collect();

    await runWithTrace(sink, () => toolChat(CFG, { systemPrompt: 'sys', userText: 'hi', tools: [tool] }));

    const llm = events.filter((e) => e.type === 'llm');
    expect(llm).toHaveLength(2);
    expect(llm[0]).toMatchObject({ status: 'running', systemPrompt: 'sys', userPrompt: 'hi' });
    expect(llm[1]!.resultBrief).toBe('调用工具：web_search');
    expect(llm[1]!.rawResponse).toContain('web_search');
    expect(llm[1]!.attempts).toBe(1);
  });

  it('无采集上下文：toolChat 照常执行（trace 为 no-op）', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(
      new Response(JSON.stringify({ choices: [{ message: { content: '没有工具调用' } }] }), { status: 200 }),
    );

    const out = await toolChat(CFG, {
      systemPrompt: 'sys',
      userText: 'hi',
      tools: [{ name: 'web_search', description: 'x', parameters: { type: 'object', properties: {} } }],
    });

    expect(out.content).toBe('没有工具调用');
  });
});
```

- [ ] **Step 2: 跑测试确认失败**

Run: `pnpm --filter @lumira/backend exec jest llm-client`
Expected: FAIL —— `done.rawResponse` 为 `undefined`；`toolChat` 用例 `events.filter(...).length` 为 0。

- [ ] **Step 3: 实现**

`llm-client.ts` 改动：

3.1 `rawChatMessage` 的返回类型与实现（原返回 `Promise<Record<string, unknown>>`）：

```ts
/** 底层单次请求结果：解析后的 message + 上游原始响应体原文 + 实际请求次数 */
interface RawChatResult {
  message: Record<string, unknown>;
  /** 上游原始响应体原文（保留原始格式，供实时过程「原始数据」展示） */
  rawText: string;
  /** 实际发出的请求次数（含 jsonMode 降级 / 5xx 重试） */
  attempts: number;
}
```

函数签名改为 `async function rawChatMessage(cfg: LlmEndpoint, input: ChatRequestBase, opts: { tools?: ToolDef[]; toolChoice?: 'auto' | 'none' | 'required' } = {}): Promise<RawChatResult>`，
内部 `doFetch` 增加计数：

```ts
  let attempts = 0;

  const doFetch = async (jsonMode: boolean): Promise<Response> => {
    attempts += 1;
    return fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${cfg.apiKey}` },
      body: JSON.stringify(buildChatBody(input, { ...opts, jsonMode })),
      signal: AbortSignal.timeout(input.timeoutMs),
    });
  };
```

尾部改为先取原文再解析（保持既有「message 非对象 → 返回 {}」行为）：

```ts
  const rawText = await res.text();
  let data: { choices?: Array<{ message?: Record<string, unknown> }> } | null = null;
  try {
    data = JSON.parse(rawText) as { choices?: Array<{ message?: Record<string, unknown> }> };
  } catch {
    // 上游返回非 JSON：rawText 仍原样保留供展示，message 视为空
    data = null;
  }
  const message = data?.choices?.[0]?.message;
  return { message: message && typeof message === 'object' ? message : {}, rawText, attempts };
```

3.2 `chatRequest` 返回原文与次数：

```ts
/** 公共请求层结果：提取正文 + 上游原文 + 请求次数 */
interface ChatRequestResult {
  content: string;
  rawText: string;
  attempts: number;
}

async function chatRequest(cfg: LlmEndpoint, input: ChatRequestBase): Promise<ChatRequestResult> {
  const { message, rawText, attempts } = await rawChatMessage(cfg, input);
  const content = message.content;
  if (typeof content !== 'string' || !content) throw new Error('AI 服务返回内容为空');
  return { content, rawText, attempts };
}
```

3.3 `visionChat` / `textChat` 的 `done` 带上原始数据（两个函数同样改法）：

```ts
    const { content, rawText, attempts } = await chatRequest(cfg, {
      model: cfg.model,
      messages,
      temperature: input.temperature ?? DEFAULT_TEMPERATURE,
      jsonMode: input.jsonMode ?? false,
      timeoutMs: input.timeoutMs ?? DEFAULT_TIMEOUT_MS,
    });
    handle?.done(content, { rawResponse: rawText, attempts });
    return content;
```

3.4 `toolChat` 补埋点（整函数替换）：

```ts
export async function toolChat(cfg: LlmEndpoint, input: ToolChatInput): Promise<{ content: string | null; toolCalls: ToolCallMsg[]; messages: unknown[] }> {
  const messages: unknown[] = [
    { role: 'system', content: input.systemPrompt },
    { role: 'user', content: input.userText },
  ];
  const handle = traceLlmCall({
    model: cfg.model,
    systemPrompt: input.systemPrompt,
    userPrompt: input.userText,
    title: '工具调用 · LLM',
  });
  try {
    const { message, rawText, attempts } = await rawChatMessage(
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

- [ ] **Step 4: 跑测试确认通过**

Run: `pnpm --filter @lumira/backend exec jest llm-client`
Expected: PASS（含既有 20 余条 visionChat/textChat/toolChat 用例，行为未变）。

- [ ] **Step 5: 跑后端构建**

Run: `pnpm --filter @lumira/backend build`
Expected: 编译通过，无 TS 报错。

- [ ] **Step 6: 提交并推送**

```powershell
git add lumira-server/packages/backend/src/modules/ai/llm-client.ts lumira-server/packages/backend/src/modules/ai/llm-client.spec.ts
git commit -m "feat(ai-trace): llm-client 记录上游原始响应体，toolChat 补埋点"
git push origin master
git push github master
```

---

### Task 3: 后端 —— `web-search-qwen` 补埋点

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/trend-research/web-search-qwen.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/trend-research/web-search-qwen.spec.ts`

**Interfaces:**
- Consumes: Task 1 的 `traceLlmCall` / `TraceCallHandle.done(response?, extra?)`
- Produces: 千问联网搜索的 LLM 事件（title `千问联网搜索 · 大模型调用`），`done` 带 `rawResponse`（上游原文）与 `resultBrief`（`N 条`）

- [ ] **Step 1: 写失败测试**

在 `web-search-qwen.spec.ts` 顶部补 import：

```ts
import { runWithTrace } from '../llm-trace';
import type { AiTraceEvent } from '../llm-trace';
```

在 `describe('web-search-qwen', ...)` 末尾追加：

```ts
  it('采集上下文内：记录提示词与上游原始响应体；无上下文时照常返回', async () => {
    const raw = JSON.stringify(OK_TOOL_CALL);
    jest.spyOn(global, 'fetch').mockResolvedValue(new Response(raw, { status: 200 }));
    const events: Omit<AiTraceEvent, 'seq' | 'ts'>[] = [];

    const items = await runWithTrace((e) => events.push(e), () => provider.search({ query: '人像', limit: 10 }));

    expect(items).toHaveLength(2);
    const llm = events.filter((e) => e.type === 'llm');
    expect(llm).toHaveLength(2);
    expect(llm[0]).toMatchObject({ status: 'running', model: 'qwen-plus', userPrompt: '人像' });
    expect(llm[0]!.systemPrompt).toContain('摄影');
    expect(llm[1]!.rawResponse).toBe(raw);
    expect(llm[1]!.resultBrief).toBe('2 条');
  });

  it('采集上下文内：上游报错时记录 fail 事件', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue(new Response('boom', { status: 500 }));
    const events: Omit<AiTraceEvent, 'seq' | 'ts'>[] = [];

    await expect(
      runWithTrace((e) => events.push(e), () => provider.search({ query: '人像', limit: 10 })),
    ).rejects.toThrow('HTTP 500');

    const fail = events.find((e) => e.type === 'llm' && e.status === 'fail')!;
    expect(fail.error).toContain('HTTP 500');
  });
```

- [ ] **Step 2: 跑测试确认失败**

Run: `pnpm --filter @lumira/backend exec jest web-search-qwen`
Expected: FAIL —— `events.filter((e) => e.type === 'llm')` 长度为 0。

- [ ] **Step 3: 实现**

`web-search-qwen.ts`：

3.1 顶部补 import：

```ts
import { traceLlmCall } from '../llm-trace';
```

3.2 `search()` 内，`fetch` 之前开启 handle：

```ts
    async search(q: WebSearchQuery): Promise<ResearchItem[]> {
      if (!base) throw new Error('Qwen 搜索未配置 baseUrl，请到后台「研究管线」填写 Qwen 搜索端点');
      if (!apiKey) throw new Error('Qwen 搜索未配置 API Key，请到后台「研究管线」填写');

      // 实时过程采集：本次既是检索也是大模型调用（enable_search），提示词与原始响应都要留痕
      const handle = traceLlmCall({
        model,
        systemPrompt: buildSystemPrompt(),
        userPrompt: q.query,
        title: '千问联网搜索 · 大模型调用',
      });
```

3.3 拿到响应后取原文，并把所有失败路径纳入 `handle.fail`。`fetch(...).catch(...)` 的既有错误映射保持，改为：

```ts
      let res: Response;
      try {
        res = await fetch(`${base}/chat/completions`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${apiKey}` },
          body: JSON.stringify({
            model,
            messages: [
              { role: 'system', content: buildSystemPrompt() },
              { role: 'user', content: q.query },
            ],
            enable_search: true,
            temperature: 0.3,
            max_tokens: 4096,
            response_format: { type: 'json_object' },
          }),
          signal: AbortSignal.timeout(180_000),
        });
      } catch (err) {
        const name = (err as { name?: string } | null | undefined)?.name;
        const message = name === 'AbortError' || name === 'TimeoutError'
          ? `Qwen 网上搜索超时（${q.query}）`
          : `Qwen 网上搜索无效连接（${q.query}）`;
        handle?.fail(new Error(message));
        throw new Error(message);
      }

      if (!res.ok) {
        const message = `Qwen 网上搜索上游错误（HTTP ${res.status}，${q.query}）`;
        handle?.fail(new Error(message));
        throw new Error(message);
      }
      const rawText = await res.text();
      let data: unknown = null;
      try {
        data = JSON.parse(rawText);
      } catch {
        data = null;
      }
      const items = extractResearchItems(data);
      if (!items) {
        const message = `Qwen 网上搜索本次未取到引用（${q.query}）`;
        handle?.fail(new Error(message));
        throw new Error(message);
      }
      handle?.done(items[0]?.title === '联网综述' ? items[0].snippet : items.map((i) => i.title).filter(Boolean).join('、'), {
        rawResponse: rawText,
        resultBrief: `${items.length} 条`,
      });
      return items;
```

- [ ] **Step 4: 跑测试确认通过**

Run: `pnpm --filter @lumira/backend exec jest web-search-qwen`
Expected: PASS（既有解析用例全部通过；新用例 2 条通过）。

- [ ] **Step 5: 提交并推送**

```powershell
git add lumira-server/packages/backend/src/modules/ai/trend-research/web-search-qwen.ts lumira-server/packages/backend/src/modules/ai/trend-research/web-search-qwen.spec.ts
git commit -m "feat(ai-trace): 千问联网搜索补埋点，记录提示词与原始响应"
git push origin master
git push github master
```

---

### Task 4: 后端 —— 批量姿势图链路接入采集上下文

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-image-task.service.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/ai-image-task.service.spec.ts`

**Interfaces:**
- Consumes: Task 1 的 `AiTraceEvent` / `runWithTrace`；Task 2 的 `llm-client` 埋点（生图链路经 `composeImagePrompt` → `textChat` 自动产生事件）
- Produces:
  - `AiBatchImageTraceEvent.kind?: 'pose' | 'llm' | 'search'`（缺省 `'pose'`）
  - `AiBatchImageTraceEvent` 新增 `systemPrompt?` / `userPrompt?` / `response?` / `rawResponse?` / `attempts?`
  - 行为：批量任务 `run()` 内的 LLM 调用以 `kind:'llm'` + 对应 `index` 进入批次事件流

- [ ] **Step 1: 写失败测试**

在 `ai-image-task.service.spec.ts` 顶部补 import：

```ts
import { traceLlmCall } from './llm-trace';
```

在 `describe('AiImageTaskService', ...)` 末尾追加：

```ts
  it('批量姿势任务：生图链路的 LLM 调用以 kind="llm" 归属对应 index，并带提示词与原始响应', async () => {
    getActiveConfigMock.mockResolvedValue({} as never);
    generateMock.mockImplementation(async () => {
      // 模拟 AiGenerateImageService.generate 内部的 composeImagePrompt → textChat：
      // 只有 run() 建立了采集上下文时 handle 才非 null
      const handle = traceLlmCall({ model: 'qwen-plus', systemPrompt: '整理生图提示词', userPrompt: '素材…' })!;
      handle.done('柔和暖光写真', { rawResponse: '{"choices":[{"message":{"content":"柔和暖光写真"}}]}', attempts: 1 });
      return { base64: 'cG9zZQ==', mimeType: 'image/png', prompt: '柔和暖光写真', model: 'doubao-seedream' };
    });
    const draft = { pose: [{ index: 0 }, { index: 1 }] };

    const { batchId } = await service.submitBatch(undefined, JSON.stringify(draft));
    await waitBatchStatus(batchId, 'done');

    const llm = service.getBatch(batchId)!.events.filter((e) => e.kind === 'llm');
    expect(llm).toHaveLength(2); // 两张姿势图各一次
    expect(llm.map((e) => e.index).sort((a, b) => a - b)).toEqual([0, 1]);
    expect(llm[0]).toMatchObject({
      status: 'done',
      model: 'qwen-plus',
      systemPrompt: '整理生图提示词',
      response: '柔和暖光写真',
      rawResponse: '{"choices":[{"message":{"content":"柔和暖光写真"}}]}',
      attempts: 1,
    });
    // pose 自身事件不受影响：仍有两张图的 done 事件
    const poseDone = service.getBatch(batchId)!.events.filter((e) => e.status === 'done' && e.kind !== 'llm');
    expect(poseDone.map((e) => e.index).sort((a, b) => a - b)).toEqual([0, 1]);
  });
```

- [ ] **Step 2: 跑测试确认失败**

Run: `pnpm --filter @lumira/backend exec jest ai-image-task`
Expected: FAIL —— `traceLlmCall(...)!` 为 `null`（无采集上下文），`handle.done` 抛 TypeError / 断言 `llm` 长度为 0。

- [ ] **Step 3: 实现**

`ai-image-task.service.ts`：

3.1 import 采集能力：

```ts
import { runWithTrace } from './llm-trace';
import type { AiTraceEvent } from './llm-trace';
```

3.2 `AiBatchImageTraceEvent` 接口扩展：

```ts
/** 批量姿势图的单条实时 trace 事件（仿 analyze 的 seq 增量机制） */
export interface AiBatchImageTraceEvent {
  seq: number;
  ts: number;
  /** 对应姿势图 index（0-based） */
  index: number;
  title: string;
  status: ImageTaskStatus;
  /**
   * 事件种类：缺省 'pose'（该张姿势图的生命周期事件）；
   * 'llm' / 'search' 为该张图生成过程中的模型调用（如提示词整理），用于展示提示词与原始响应。
   */
  kind?: 'pose' | 'llm' | 'search';
  /** 生图最终提示词（仅 pose done 事件） */
  prompt?: string;
  model?: string;
  /** LLM 调用的原始数据（kind='llm'/'search' 时） */
  systemPrompt?: string;
  userPrompt?: string;
  response?: string;
  rawResponse?: string;
  attempts?: number;
  error?: string;
  durationMs?: number;
}
```

3.3 `run()` 内包裹采集上下文（原 `const r = await this.generateWithRetry(...)` 一行替换为）：

```ts
      // 该张图生成过程中的 LLM 调用（提示词整理等）以 kind='llm' 归属本张 index，
      // 前端在「姿势图生成」过程里可看到每次请求的提示词与上游原始响应。
      const sink = (ev: Omit<AiTraceEvent, 'seq' | 'ts'>): void => {
        if (ev.type !== 'llm' && ev.type !== 'search') return; // 阶段/备注事件不进入批次流
        this.emitBatchEvent(task.batchId, {
          index,
          kind: ev.type,
          title: ev.title,
          status: ev.status === 'running' ? 'running' : ev.status === 'done' ? 'done' : 'error',
          model: ev.model,
          systemPrompt: ev.systemPrompt,
          userPrompt: ev.userPrompt,
          response: ev.response,
          rawResponse: ev.rawResponse,
          attempts: ev.attempts,
          error: ev.error,
          durationMs: ev.durationMs,
        });
      };
      const r = await runWithTrace(sink, () => this.generateWithRetry(reference, metaJson, extraPrompt, research));
```

- [ ] **Step 4: 跑测试确认通过**

Run: `pnpm --filter @lumira/backend exec jest ai-image-task`
Expected: PASS —— 新用例通过，既有 13 条（since 增量 / pending 事件 / done 透传 / 重试等）全部通过。

- [ ] **Step 5: 跑后端构建**

Run: `pnpm --filter @lumira/backend build`
Expected: 编译通过。

- [ ] **Step 6: 提交并推送**

```powershell
git add lumira-server/packages/backend/src/modules/ai/ai-image-task.service.ts lumira-server/packages/backend/src/modules/ai/ai-image-task.service.spec.ts
git commit -m "feat(ai-trace): 批量姿势图链路接入采集，生图内 LLM 调用实时可见"
git push origin master
git push github master
```

---

### Task 5: 后台 —— 类型对齐 + 共享 `TraceCallCard` 组件

**Files:**
- Modify: `lumira-server/packages/admin/src/types/admin.ts`
- Create: `lumira-server/packages/admin/src/components/ai-create/trace-call-card.tsx`

**Interfaces:**
- Consumes: Task 1 / Task 4 的后端字段
- Produces:
  - `types/admin.ts`：`AiTraceEvent` 加 `rawResponse?: string; attempts?: number`；`AiBatchImageTraceEvent` 加 `kind?: 'pose' | 'llm' | 'search'` + `systemPrompt?` / `userPrompt?` / `response?` / `rawResponse?` / `attempts?`
  - `trace-call-card.tsx` 导出：
    - `TraceCallCardData`（`{ type?: 'llm' | 'search'; title: string; model?: string; status?: 'running' | 'done' | 'fail' | 'error' | 'pending'; systemPrompt?: string; userPrompt?: string; response?: string; rawResponse?: string; resultBrief?: string; error?: string; durationMs?: number }`）
    - `TraceCallCard({ ev, defaultOpen }: { ev: TraceCallCardData; defaultOpen?: boolean })`
    - `TraceTextBlock({ label, text, defaultOpen }: { label: string; text: string; defaultOpen?: boolean })`

> **评审增补（与用户确认后补记）**：后端 `startCall` 每次调用会产出 `running`（含 System/User 提示词）与 `done`/`fail`（含 response/rawResponse/attempts/durationMs）**两条**事件。若按 1:1 渲染，则一次调用出现两张卡片，且提示词那张会永久停在「等待响应…」。因此新增纯函数 `collapseTraceCalls`（按 title+model 就近配对，合并成一条数据、key 沿用 running 的 seq，使卡片原位补齐而非新增一张），归入 Task 6 Step 0 落地，Task 6/7 的调用点统一经它渲染。

- [ ] **Step 1: 扩展类型**

`types/admin.ts` 的 `AiTraceEvent` 内、`response?: string;` 之后加：

```ts
  /** 上游原始响应体全文（LLM 为原始 JSON 文本；检索为原始返回） */
  rawResponse?: string;
  /** 实际发出的请求次数（含降级/重试；1 表示一次成功） */
  attempts?: number;
```

`types/admin.ts` 的 `AiBatchImageTraceEvent` 内、`status` 之后加：

```ts
  /** 事件种类：缺省 'pose'（姿势图生命周期）；'llm'/'search' 为该张图生成过程中的模型调用 */
  kind?: 'pose' | 'llm' | 'search';
  /** 模型调用的原始数据（kind='llm'/'search'） */
  systemPrompt?: string;
  userPrompt?: string;
  response?: string;
  rawResponse?: string;
  attempts?: number;
```

- [ ] **Step 2: 新建共享组件**

创建 `lumira-server/packages/admin/src/components/ai-create/trace-call-card.tsx`（完整文件）：

```tsx
'use client';

// src/components/ai-create/trace-call-card.tsx
// 单次 LLM / 检索调用的「原始数据」卡片（识别流与姿势图流共用）：
// 分区展示 请求提示词（system / user）、模型输出（提取）、上游原始响应（JSON），
// 默认全部展开、限高内部滚动，每块可一键复制，便于排查问题时直接取证。

import * as React from 'react';
import { useState } from 'react';
import { Copy } from '@phosphor-icons/react/dist/csr/Copy';
import { Check } from '@phosphor-icons/react/dist/csr/Check';
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';

export interface TraceCallCardData {
  type?: 'llm' | 'search';
  title: string;
  model?: string;
  status?: 'running' | 'done' | 'fail' | 'error' | 'pending';
  systemPrompt?: string;
  userPrompt?: string;
  response?: string;
  rawResponse?: string;
  /** 实际发出的请求次数（含降级/重试；> 1 时卡片显示「请求 N 次」） */
  attempts?: number;
  resultBrief?: string;
  error?: string;
  durationMs?: number;
}

function formatDuration(ms?: number): string | null {
  if (typeof ms !== 'number') return null;
  if (ms < 1000) return `${ms}ms`;
  return `${(ms / 1000).toFixed(1)}s`;
}

function statusText(ev: TraceCallCardData): string | null {
  if (ev.status === 'running' || ev.status === 'pending') return '等待响应…';
  if (ev.status === 'fail' || ev.status === 'error') return '失败';
  return ev.resultBrief ?? null;
}

/** 复制到剪贴板；环境不支持时返回 false（由调用方提示） */
async function copyText(text: string): Promise<boolean> {
  try {
    if (typeof navigator !== 'undefined' && navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(text);
      return true;
    }
  } catch {
    // 非安全上下文 / 权限被拒：交给调用方提示
  }
  return false;
}

export function TraceCallCard({ ev, defaultOpen = true, className }: { ev: TraceCallCardData; defaultOpen?: boolean; className?: string }) {
  const duration = formatDuration(ev.durationMs);
  const isSearch = ev.type === 'search';
  const status = statusText(ev);
  return (
    <div className={cn('rounded-md border border-border bg-muted/40 px-3 py-2', className)}>
      <div className="flex flex-wrap items-center gap-1.5">
        <Badge variant="outline" className="font-mono text-[10px]">{isSearch ? '联网检索' : 'LLM'}</Badge>
        <span className="truncate text-xs font-medium text-foreground">{ev.title}</span>
        {ev.model && <span className="font-mono text-[10px] text-muted-foreground">{ev.model}</span>}
        <span className="ml-auto flex shrink-0 items-center gap-2 text-[10px] text-muted-foreground">
          {status && <span className={cn(ev.status === 'fail' || ev.status === 'error' ? 'text-destructive' : ev.status === 'running' || ev.status === 'pending' ? 'text-primary' : undefined)}>{status}</span>}
          {typeof ev.attempts === 'number' && ev.attempts > 1 && <span>请求 {ev.attempts} 次</span>}
          {duration && <span>{duration}</span>}
        </span>
      </div>

      {ev.systemPrompt && <TraceTextBlock label="System 提示词" text={ev.systemPrompt} defaultOpen={defaultOpen} />}
      {ev.userPrompt && <TraceTextBlock label={isSearch ? '检索词' : 'User 提示词'} text={ev.userPrompt} defaultOpen={defaultOpen} />}
      {ev.response && <TraceTextBlock label={isSearch ? '命中摘要' : '模型输出（提取）'} text={ev.response} defaultOpen={defaultOpen} />}
      {ev.rawResponse && <TraceTextBlock label="上游原始响应（JSON）" text={ev.rawResponse} defaultOpen={defaultOpen} />}
      {ev.error && !ev.response && <p className="mt-1.5 whitespace-pre-wrap break-all text-xs text-destructive">{ev.error}</p>}
    </div>
  );
}

export function TraceTextBlock({ label, text, defaultOpen = true }: { label: string; text: string; defaultOpen?: boolean }) {
  const [open, setOpen] = useState(defaultOpen);
  const [copied, setCopied] = useState(false);
  const [failed, setFailed] = useState(false);

  const onCopy = async () => {
    const ok = await copyText(text);
    if (ok) {
      setCopied(true);
      setFailed(false);
      setTimeout(() => setCopied(false), 1500);
    } else {
      setFailed(true);
      setTimeout(() => setFailed(false), 1500);
    }
  };

  return (
    <div className="mt-1.5">
      <div className="flex items-center gap-2">
        <button
          type="button"
          onClick={() => setOpen((o) => !o)}
          className="text-[11px] text-muted-foreground hover:text-foreground"
        >
          {open ? '▾' : '▸'} {label}（{text.length} 字）
        </button>
        <button
          type="button"
          onClick={onCopy}
          className="ml-auto flex items-center gap-1 text-[10px] text-muted-foreground hover:text-foreground"
        >
          {copied ? <Check size={11} /> : <Copy size={11} />}
          {copied ? '已复制' : failed ? '复制失败' : '复制'}
        </button>
      </div>
      {open && (
        <pre className="mt-1 max-h-56 overflow-auto rounded bg-muted p-2 text-[11px] leading-relaxed whitespace-pre-wrap break-all">
          {text}
        </pre>
      )}
    </div>
  );
}
```

> 图标导入按仓库既有约定使用逐图标子路径（`dist/csr/Copy` / `dist/csr/Check`，已确认 `packages/admin/node_modules/@phosphor-icons/react/dist/csr/` 下存在）。

- [ ] **Step 3: 构建确认通过**

Run: `pnpm --filter @lumira/admin build`
Expected: 编译通过；`trace-call-card.tsx` 暂无引用方，不应有 unused 报错（`next build` 不报未引用组件）。

- [ ] **Step 4: 提交并推送**

```powershell
git add lumira-server/packages/admin/src/types/admin.ts lumira-server/packages/admin/src/components/ai-create/trace-call-card.tsx
git commit -m "feat(admin): 新增共享溯源卡片 TraceCallCard，类型对齐原始响应字段"
git push origin master
git push github master
```

---

### Task 6: 后台 —— 识别流接入共享卡片（默认展开 + 复制）

**Files:**
- Modify: `lumira-server/packages/admin/src/components/ai-create/trace-call-card.tsx`（新增 `collapseTraceCalls`）
- Modify: `lumira-server/packages/admin/src/components/ai-create/analyze-trace-stream.tsx`

**Interfaces:**
- Consumes: Task 5 的 `TraceCallCard` / `TraceCallCardData`
- Produces: `trace-call-card.tsx` 新增导出 `TraceCallSource`、`TraceCallItem`、`collapseTraceCalls(sources): TraceCallItem[]`

- [ ] **Step 0: 新增 `collapseTraceCalls`（每次调用合并成一张卡片）**

后端 `startCall` 每次调用产两条事件（`running` 带提示词 → `done`/`fail` 带响应）。若 1:1 渲染，一次调用会出现两张卡片、且提示词那张永久停在「等待响应…」。故加纯函数按 `type/kind + title + model` 就近配对合并，**key 沿用 running 事件的 seq**，使卡片原位补齐而非新增一张。追加到 `trace-call-card.tsx` 末尾：

```tsx
/** 可参与合并的事件源（识别流 AiTraceEvent 与批次流 AiBatchImageTraceEvent 的公共子集） */
export interface TraceCallSource {
  seq: number;
  /** 识别流用 type；批次流用 kind */
  type?: 'llm' | 'search' | 'step' | 'note' | 'pose';
  kind?: 'pose' | 'llm' | 'search';
  title: string;
  model?: string;
  status: string;
  systemPrompt?: string;
  userPrompt?: string;
  response?: string;
  rawResponse?: string;
  attempts?: number;
  resultBrief?: string;
  error?: string;
  durationMs?: number;
}

export interface TraceCallItem {
  key: number;
  ev: TraceCallCardData;
}

/** 只覆盖有值的字段，避免 done 事件把 running 已记录的提示词清成 undefined */
function mergeDefined<T extends object>(base: T, patch: Partial<T>): T {
  const out: Record<string, unknown> = { ...base };
  for (const [k, v] of Object.entries(patch)) if (v !== undefined) out[k] = v;
  return out as T;
}

/**
 * 把「一次调用的两条事件」折叠成一张卡片的数据：
 * running/pending 开一个待配对槽位并占据当前位置；随后同 种类+title+model 的 done/fail/error
 * 原位补齐响应字段（key 不变 → React 不重建节点，表现为同一张卡片内容变完整）。
 * 未能配对的事件各自单独成条（如只有 done 的历史事件、并发同名调用）。
 */
export function collapseTraceCalls(sources: TraceCallSource[]): TraceCallItem[] {
  const items: TraceCallItem[] = [];
  const open = new Map<string, number>();
  for (const src of sources) {
    const isSearch = src.kind === 'search' || src.type === 'search';
    const ev: TraceCallCardData = {
      type: isSearch ? 'search' : 'llm',
      title: src.title,
      model: src.model,
      status: src.status as TraceCallCardData['status'],
      systemPrompt: src.systemPrompt,
      userPrompt: src.userPrompt,
      response: src.response,
      rawResponse: src.rawResponse,
      attempts: src.attempts,
      resultBrief: src.resultBrief,
      error: src.error,
      durationMs: src.durationMs,
    };
    const key = `${isSearch ? 'search' : 'llm'}|${src.title}|${src.model ?? ''}`;
    const waiting = src.status === 'running' || src.status === 'pending';
    if (waiting) {
      if (open.has(key)) continue; // 同一次调用不会重复 running；重复时忽略以免卡片抖动
      open.set(key, items.length);
      items.push({ key: src.seq, ev });
      continue;
    }
    const idx = open.get(key);
    if (typeof idx === 'number') {
      open.delete(key);
      items[idx] = { key: items[idx].key, ev: mergeDefined(items[idx].ev, ev) };
      continue;
    }
    items.push({ key: src.seq, ev });
  }
  return items;
}
```

- [ ] **Step 1: 替换 CallCard 与 Collapsible**

`analyze-trace-stream.tsx`：

1) import 区加：

```ts
import { TraceCallCard, collapseTraceCalls } from '@/components/ai-create/trace-call-card';
```

2) 删除文件末尾的本地 `CallCard` 与 `Collapsible` 两个函数（整段删除）。

3) 两处调用点替换：

- `AnalyzeTraceStream` 的孤立事件渲染（原 `{timeline.orphans.map((ev) => <CallCard key={ev.seq} ev={ev} />)}`）：

```tsx
            {collapseTraceCalls(timeline.orphans).map(({ key, ev }) => (
              <TraceCallCard
                key={key}
                ev={{
                  type: ev.type,
                  title: ev.title,
                  model: ev.model,
                  status: ev.status,
                  systemPrompt: ev.systemPrompt,
                  userPrompt: ev.userPrompt,
                  response: ev.response,
                  rawResponse: ev.rawResponse,
                  attempts: ev.attempts,
                  resultBrief: ev.resultBrief,
                  error: ev.error,
                  durationMs: ev.durationMs,
                }}
              />
            ))}
```

> 说明：`collapseTraceCalls` 已把 `AiTraceEvent` 映射为 `TraceCallCardData`，上面显式列字段仅为可读性；若嫌冗长可直接 `<TraceCallCard key={key} ev={ev} />`（等价）。

- `PhaseRow` 内的调用列表（原 `{phase.calls.map((ev) => <CallCard key={ev.seq} ev={ev} />)}`）：

```tsx
          {collapseTraceCalls(phase.calls).map(({ key, ev }) => (
            <TraceCallCard
              key={key}
              ev={{
                type: ev.type,
                title: ev.title,
                model: ev.model,
                status: ev.status,
                systemPrompt: ev.systemPrompt,
                userPrompt: ev.userPrompt,
                response: ev.response,
                rawResponse: ev.rawResponse,
                attempts: ev.attempts,
                resultBrief: ev.resultBrief,
                error: ev.error,
                durationMs: ev.durationMs,
              }}
            />
          ))}
```

> 同样可用等价简写 `<TraceCallCard key={key} ev={ev} />`。两处调用点都必须经 `collapseTraceCalls`，否则每次调用会渲染出「提示词卡（永远显示等待响应…）+ 响应卡」两张卡片。

4) 文件头注释同步（原第 5-7 行「该阶段的 LLM/检索调用折叠收纳到阶段下，默认收拢。…提示词/响应可折叠。」）改为：

```
// 该阶段的 LLM/检索调用收纳到阶段下，提示词与上游原始响应默认展开、可一键复制（见 TraceCallCard）。
```

- [ ] **Step 2: 构建确认通过**

Run: `pnpm --filter @lumira/admin build`
Expected: 编译通过，无未使用变量 / 未定义引用报错。

- [ ] **Step 3: 提交并推送**

```powershell
git add lumira-server/packages/admin/src/components/ai-create/analyze-trace-stream.tsx
git commit -m "feat(admin): 识别流改用共享溯源卡片，提示词与原始响应默认展开可复制"
git push origin master
git push github master
```

---

### Task 7: 后台 —— 姿势图流内嵌 LLM 子事件 + pose 状态灯过滤修复

**Files:**
- Modify: `lumira-server/packages/admin/src/components/ai-create/pose-trace-stream.tsx`

**Interfaces:**
- Consumes: Task 4 的 `AiBatchImageTraceEvent.kind` 等字段；Task 5 的 `TraceCallCard` / `TraceTextBlock`；Task 6 的 `collapseTraceCalls`
- Produces: 无新导出

> **必须同时修的回归（Task 4 评审遗留 Important）**：`PoseRow` 现在的状态灯 / 时间 / 模型 / 耗时都来自 `evs` 全量事件，而 Task 4 起 `evs` 里混进了 `kind='llm'/'search'` 子事件，会导致：
> 1. `latest = evs[evs.length - 1]` 被模型调用事件覆盖 → 状态灯在姿势图仍在跑时反复跳成「生成中/完成」、时间戳显示的是模型调用时间；
> 2. `finished = evs.find(e => e.status === 'done' || e.status === 'error')` 会命中第一个 LLM done → 提前判定该张「完成」，且 `prompt` / `model` / `durationMs` 取到模型调用的值。
>
> 修法：先把 `evs` 按 `kind` 分成「姿势图生命周期事件」与「模型调用事件」两路，头部状态只用前者。

- [ ] **Step 1: 渲染子事件与默认展开的提示词**

`pose-trace-stream.tsx`：

1) import 区加：

```ts
import { TraceCallCard, TraceTextBlock, collapseTraceCalls } from '@/components/ai-create/trace-call-card';
```

2) 把 `PoseRow` 函数体开头（现为 `const latest = evs[evs.length - 1]!;` 到 `const duration = formatDuration(finished?.durationMs);`）整段替换为：

```ts
  // 头部状态只认姿势图生命周期事件（kind 缺省即 'pose'），避免被模型调用子事件污染
  const poseEvs = evs.filter((e) => !e.kind || e.kind === 'pose');
  const latest = poseEvs[poseEvs.length - 1] ?? evs[evs.length - 1]!;
  const meta = STATUS_META[latest.status] ?? STATUS_META.pending;
  const finished = poseEvs.find((e) => e.status === 'done' || e.status === 'error');
  const prompt = finished?.prompt;
  const model = finished?.model;
  const duration = formatDuration(finished?.durationMs);
  const calls = collapseTraceCalls(evs.filter((e) => e.kind === 'llm' || e.kind === 'search'));
```

> `latest` 的兜底 `?? evs[evs.length - 1]!` 是为了极端情况下（只有子事件、还没有 pose 事件）不崩；此时 `poseEvs` 为空数组。

3) `PoseRow` 返回值最后，把原 `<details>` 提示词块替换为下面整段：

```tsx
      {calls.map(({ key, ev }) => (
        <TraceCallCard key={key} className="mt-1.5" ev={ev} />
      ))}
      {prompt && <TraceTextBlock label="最终生图提示词" text={prompt} />}
```

> `collapseTraceCalls` 的入参类型是 `TraceCallSource`，`AiBatchImageTraceEvent` 结构上满足（`kind` 为 `'pose'|'llm'|'search'`，其中 `'pose'` 已被上面的 filter 排除），无需手写映射。

4) 文件头注释同步：把「（折叠 prompt）」改为「（prompt 默认展开）」，并补一句：

```
// 该张图生成过程中的模型调用（kind='llm'/'search'）以其原始数据卡片内嵌展示，不参与头部状态灯计算。
```

- [ ] **Step 2: 构建确认通过**

Run: `pnpm --filter @lumira/admin build`
Expected: 编译通过。

- [ ] **Step 3: 提交并推送**

```powershell
git add lumira-server/packages/admin/src/components/ai-create/pose-trace-stream.tsx
git commit -m "feat(admin): 姿势图流内嵌 LLM 调用原始数据卡片"
git push origin master
git push github master
```

---

## 收尾验收（全部任务完成后）

- [ ] 后端：`pnpm --filter @lumira/backend exec jest llm-trace llm-client web-search-qwen ai-image-task` 全绿
- [ ] 后端：`pnpm --filter @lumira/backend build` 通过
- [ ] 后台：`pnpm --filter @lumira/admin build` 通过
- [ ] 双远程均已推送：`git push origin master` / `git push github master`（CI 会自动部署后端，Vercel 自动构建后台）
- [ ] 人工走查（可选）：后台「AI 一键生成」跑一次完整流程，确认
  1. 「风格识别」Tab 里每次 LLM 调用都能看到 System/User 提示词与「上游原始响应（JSON）」，默认展开、可复制；
  2. 研究阶段的千问联网搜索同时出现「联网检索」卡片与「千问联网搜索 · 大模型调用」卡片；
  3. 「姿势图生成」Tab 里每张图下能看到其提示词整理的 LLM 调用与原始响应。