# AI 一键建模增强实施计划（textModel / 多输入 / 润色 / 实时预览）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为「AI 一键建模」增加可选文本模型（生图 prompt 润色）、三种输入方式（图/文/图文）、向导层常驻 sticky 实时预览。

**Architecture:** 后端 `ai` 模块扩展——`ai_provider_config` 加可选 `text_model` 列（留空回退 `vision_model`）；`llm-client` 抽公共 `chatRequest` 并新增 `textChat`；`ai-analyze` 接受可选 image + 可选 text，prompt 按输入组合分叉；生图前经 `prompt-polisher`（textModel 转写，失败静默回退拼接 prompt）。Admin 端：AI 设置页加文本模型字段，向导 Step1 加文字输入，预览面板经 React portal 从 TemplateForm 提升到向导层 sticky 右栏。

**Tech Stack:** NestJS + Fastify + Drizzle（mysql2）；Next.js App Router + react-hook-form + Tailwind；Jest + ts-jest（单测）/ supertest（e2e）。

**设计文档：** `docs/specs/2026-09-10-ai-create-enhancement-design.md`

## Global Constraints

- Flutter 端（`lumira_app_flutter/`）**零改动**。
- 后端/后台每次功能完成必须 commit 并 push 双远程：`git push origin master`（gitee）+ `git push github master`。
- 无新 npm 依赖（LLM 调用均为原生 fetch）；Docker 镜像不变。
- TypeScript 严格模式：spec 文件中 jest mock 需带参数类型，unknown 字段需类型断言（CI typecheck 全量跑）。
- 既有 6 步向导交互与现有仅图模式行为保持不变（向后兼容）。
- 测试命令：后端单测 `pnpm --filter @lumira/backend exec jest <pattern>`；typecheck `pnpm --filter @lumira/backend exec tsc --noEmit` / `pnpm --filter @lumira/admin exec tsc --noEmit`（均在 `lumira-server/` 目录下执行）。
- e2e 需本地 MySQL（`lumira_test` 库），若环境不可用则以单测 + typecheck 为准并在提交信息注明。

---

### Task 1: 后端 — migration 031 + ai-config textModel 存取/回退/连通测试

**Files:**
- Create: `lumira-server/packages/backend/src/database/migrations/031_ai_text_model.sql`
- Modify: `lumira-server/packages/backend/src/database/schema.ts:334-344`（aiProviderConfig 表定义）
- Modify: `lumira-server/packages/backend/src/modules/ai/dto/update-ai-config.dto.ts`
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-config.service.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/ai-config.service.spec.ts`（新建）
- Test: `lumira-server/packages/backend/test/ai-config.e2e-spec.ts`（更新断言）

**Interfaces:**
- Consumes: `visionChat`/`textChat`（`./llm-client`，textChat 在 Task 2 实现——本任务 spec 先 mock 它，实现顺序上 Task 2 也可先行；本任务 test() 中对 textChat 的调用写成存在性安全形式，Task 2 完成后全绿）
- Produces（后续任务依赖的精确签名）:
  - `ActiveAiConfig { provider: string; baseUrl: string; apiKey: string; visionModel: string; imageModel: string; textModel: string; hasCustomTextModel: boolean }`（`textModel` 为**有效值** = 存储值 || visionModel）
  - `AiConfigView { configured: true; provider; baseUrl; apiKeyMasked; visionModel; imageModel; textModel: string; effectiveTextModel: string; enabled: boolean }`（`textModel` 为**存储值**，可为 `''`）
  - `AiConfigTestResult { vision: {...}; text?: { ok: boolean; latencyMs?: number; error?: string }; note: string }`
  - `UpdateAiConfigDto.textModel?: string`（`''`/缺省 = 清除回退）

- [ ] **Step 1: 写失败测试（ai-config.service.spec.ts，新建）**

```ts
// lumira-server/packages/backend/src/modules/ai/ai-config.service.spec.ts
// ai-config.service 单测：textModel 存取 / 留空回退 / 连通测试分支
// jest.mock llm-client（visionChat + textChat），DatabaseService 手工 stub

import { ServiceUnavailableException } from '@nestjs/common';
import { AiConfigService } from './ai-config.service';
import { DatabaseService } from '../../database/database.service';
import { visionChat, textChat } from './llm-client';

jest.mock('./llm-client', () => ({
  visionChat: jest.fn(),
  textChat: jest.fn(),
}));

const visionChatMock = visionChat as jest.MockedFunction<typeof visionChat>;
const textChatMock = textChat as jest.MockedFunction<typeof textChat>;

/** DB 行夹具（列名对齐 drizzle schema camelCase 映射） */
function row(overrides: Record<string, unknown> = {}) {
  return {
    id: 1,
    provider: 'qwen',
    baseUrl: 'https://x.example',
    apiKey: 'sk-1234567890',
    visionModel: 'qwen-vl-max',
    imageModel: 'wanx2.1-t2i-turbo',
    textModel: null,
    enabled: 1,
    createdAt: 1,
    updatedAt: 1,
    ...overrides,
  };
}

/** 只读 db mock（get / getActiveConfig / test 用）：query.aiProviderConfig.findFirst 恒返回 row */
function readonlyDb(r: Record<string, unknown> | undefined) {
  return {
    getDb: () => ({ query: { aiProviderConfig: { findFirst: async () => r } } }),
  } as unknown as DatabaseService;
}

describe('AiConfigService — textModel', () => {
  beforeEach(() => {
    visionChatMock.mockReset();
    textChatMock.mockReset();
    visionChatMock.mockResolvedValue('ok');
    textChatMock.mockResolvedValue('ok');
  });

  it('get() 无 textModel 列值 → textModel 空串、effectiveTextModel 回退 visionModel', async () => {
    const service = new AiConfigService(readonlyDb(row()));
    const view = await service.get();
    expect(view.configured).toBe(true);
    if (view.configured !== true) return;
    expect(view.textModel).toBe('');
    expect(view.effectiveTextModel).toBe('qwen-vl-max');
  });

  it('get() 有 textModel 列值 → 存储值原样、effectiveTextModel 同值', async () => {
    const service = new AiConfigService(readonlyDb(row({ textModel: 'qwen-plus' })));
    const view = await service.get();
    if (view.configured !== true) throw new Error('should be configured');
    expect(view.textModel).toBe('qwen-plus');
    expect(view.effectiveTextModel).toBe('qwen-plus');
  });

  it('getActiveConfig() 未配置独立 textModel → textModel=visionModel、hasCustomTextModel=false', async () => {
    const service = new AiConfigService(readonlyDb(row()));
    const cfg = await service.getActiveConfig();
    expect(cfg.textModel).toBe('qwen-vl-max');
    expect(cfg.hasCustomTextModel).toBe(false);
  });

  it('getActiveConfig() 配置独立 textModel → 有效值 + hasCustomTextModel=true', async () => {
    const service = new AiConfigService(readonlyDb(row({ textModel: 'qwen-plus' })));
    const cfg = await service.getActiveConfig();
    expect(cfg.textModel).toBe('qwen-plus');
    expect(cfg.hasCustomTextModel).toBe(true);
  });

  it('getActiveConfig() 未启用 → 503', async () => {
    const service = new AiConfigService(readonlyDb(row({ enabled: 0 })));
    await expect(service.getActiveConfig()).rejects.toThrow(ServiceUnavailableException);
  });

  it('test() 无独立 textModel → 不调 textChat，结果无 text 字段', async () => {
    const service = new AiConfigService(readonlyDb(row()));
    const result = await service.test();
    expect(result.vision.ok).toBe(true);
    expect(textChatMock).not.toHaveBeenCalled();
    expect('text' in result && result.text).toBeFalsy();
  });

  it('test() 有独立 textModel → 调 textChat，结果含 text', async () => {
    const service = new AiConfigService(readonlyDb(row({ textModel: 'qwen-plus' })));
    const result = await service.test();
    expect(textChatMock).toHaveBeenCalledTimes(1);
    expect(result.text?.ok).toBe(true);
  });

  it('test() textChat 失败 → text.ok=false 且 vision 不受影响', async () => {
    textChatMock.mockRejectedValue(new Error('boom'));
    const service = new AiConfigService(readonlyDb(row({ textModel: 'qwen-plus' })));
    const result = await service.test();
    expect(result.vision.ok).toBe(true);
    expect(result.text?.ok).toBe(false);
    expect(result.text?.error).toBe('boom');
  });
});

describe('AiConfigService — save() textModel 语义', () => {
  /** 可写 db mock：findFirst 状态化；insert/update 后同步内存行（save 末尾 get() 重新读取） */
  function writableDb(existing: Record<string, unknown> | undefined) {
    let current = existing;
    const insertValues = jest.fn(async (v: Record<string, unknown>) => {
      current = { ...row(), ...v };
    });
    const updateWhere = jest.fn(async () => undefined);
    const updateSet = jest.fn((patch: Record<string, unknown>) => {
      current = { ...(current as Record<string, unknown>), ...patch };
      return { where: updateWhere };
    });
    return {
      service: new AiConfigService({
        getDb: () => ({
          query: { aiProviderConfig: { findFirst: async () => current } },
          insert: () => ({ values: insertValues }),
          update: () => ({ set: updateSet }),
        }),
      } as unknown as DatabaseService),
      insertValues,
      updateSet,
    };
  }

  const dto = (textModel?: string) => ({
    provider: 'qwen',
    baseUrl: 'https://x.example',
    apiKey: 'sk-1234567890',
    visionModel: 'qwen-vl-max',
    imageModel: 'wanx2.1-t2i-turbo',
    ...(textModel !== undefined ? { textModel } : {}),
    enabled: true,
  });

  it('首次保存带 textModel → insert 收到该值', async () => {
    const { service, insertValues } = writableDb(undefined);
    const view = await service.save(dto('qwen-plus'));
    expect(insertValues).toHaveBeenCalledWith(expect.objectContaining({ textModel: 'qwen-plus' }));
    expect(view.effectiveTextModel).toBe('qwen-plus');
  });

  it('更新时 textModel 空串 → 清除（update 收到 textModel: ""）', async () => {
    const { service, updateSet } = writableDb(row({ textModel: 'qwen-plus' }));
    const view = await service.save(dto(''));
    expect(updateSet).toHaveBeenCalledWith(expect.objectContaining({ textModel: '' }));
    expect(view.textModel).toBe('');
    expect(view.effectiveTextModel).toBe('qwen-vl-max');
  });

  it('更新时缺省 textModel → 同样清除为空串（不保留旧值）', async () => {
    const { service, updateSet } = writableDb(row({ textModel: 'qwen-plus' }));
    await service.save(dto());
    expect(updateSet).toHaveBeenCalledWith(expect.objectContaining({ textModel: '' }));
  });
});
```

注意：`service.save(dto(...))` 的 dto 是普通对象字面量，如 typecheck 报缺 index 签名，在测试文件内声明 `const dto = (textModel?: string): UpdateAiConfigDto => ({ ... } as UpdateAiConfigDto);`（import 该类型）。

- [ ] **Step 2: 运行测试确认失败**

Run: `pnpm --filter @lumira/backend exec jest ai-config.service`
Expected: FAIL（`textModel`/`effectiveTextModel`/`hasCustomTextModel` 属性不存在；textChat 未导出导致 mock 模块缺 key 报错——若因 Task 2 未实施而 import 报错，可先仅跑 `--testPathPattern ai-config.service` 确认 FAIL 原因为属性缺失）

- [ ] **Step 3: 写 migration 031**

```sql
-- 031: AI 配置新增可选文本模型列（空 = 回退视觉模型）
-- 设计文档：docs/specs/2026-09-10-ai-create-enhancement-design.md 第一节
ALTER TABLE ai_provider_config
  ADD COLUMN text_model VARCHAR(64) NULL AFTER vision_model;
```

- [ ] **Step 4: 更新 schema.ts**

`aiProviderConfig` 表定义中 `visionModel` 行后插入：

```ts
  textModel: varchar('text_model', { length: 64 }),
```

（drizzle 无 `.notNull()` 即可空，返回类型 `string | null`）

- [ ] **Step 5: 更新 DTO**

`update-ai-config.dto.ts` 的 `visionModel` 字段后插入：

```ts
  /** 空串 / 缺省 = 清除（回退视觉模型） */
  @IsOptional()
  @IsString()
  @MaxLength(64)
  textModel?: string;
```

- [ ] **Step 6: 更新 ai-config.service.ts**

按以下完整 diff 修改（顶部 import 增加 `textChat`）：

```ts
import { visionChat, textChat } from './llm-client';
```

`AiConfigView` 接口增加两个字段：

```ts
export interface AiConfigView {
  configured: true;
  provider: string;
  baseUrl: string;
  apiKeyMasked: string;
  visionModel: string;
  imageModel: string;
  /** 存储值（'' = 未配置独立文本模型） */
  textModel: string;
  /** 有效文本模型 = textModel || visionModel */
  effectiveTextModel: string;
  enabled: boolean;
}
```

`ActiveAiConfig` 接口：

```ts
export interface ActiveAiConfig {
  provider: string;
  baseUrl: string;
  apiKey: string;
  visionModel: string;
  imageModel: string;
  /** 有效文本模型（= textModel 配置值 || visionModel，永不为空） */
  textModel: string;
  /** 是否配置了独立文本模型 */
  hasCustomTextModel: boolean;
}
```

`AiConfigTestResult` 接口：

```ts
export interface AiConfigTestResult {
  vision: { ok: boolean; latencyMs?: number; error?: string };
  /** 配置了独立文本模型时才有此字段 */
  text?: { ok: boolean; latencyMs?: number; error?: string };
  note: string;
}
```

`get()` 中 return 增加（`apiKeyMasked` 行后）：

```ts
      textModel: row.textModel ?? '',
      effectiveTextModel: row.textModel || row.visionModel,
```

`save()` 的 insert `.values({...})` 与 update `.set({...})` 中均在 `imageModel` 后增加：

```ts
        textModel: dto.textModel ?? '',
```

`test()` 整体替换为：

```ts
  /** 最小请求连通性测试：vision（1px PNG + ping）；配置独立 textModel 时追加纯文本测试 */
  async test(): Promise<AiConfigTestResult> {
    const cfg = await this.getActiveConfig();
    const t0 = Date.now();
    let vision: AiConfigTestResult['vision'];
    try {
      await visionChat(
        { provider: cfg.provider, baseUrl: cfg.baseUrl, apiKey: cfg.apiKey, visionModel: cfg.visionModel },
        {
          systemPrompt: 'You are a connectivity test.',
          userText: 'ping',
          imageBase64: TINY_1PX_PNG_B64,
          imageMime: 'image/png',
          temperature: 0,
          timeoutMs: 30_000,
        },
      );
      vision = { ok: true, latencyMs: Date.now() - t0 };
    } catch (e) {
      vision = { ok: false, error: (e as Error).message };
    }

    let text: AiConfigTestResult['text'];
    if (cfg.hasCustomTextModel) {
      const t1 = Date.now();
      try {
        await textChat(
          { provider: cfg.provider, baseUrl: cfg.baseUrl, apiKey: cfg.apiKey, visionModel: cfg.visionModel, textModel: cfg.textModel },
          {
            systemPrompt: 'You are a connectivity test.',
            userText: 'ping',
            temperature: 0,
            timeoutMs: 30_000,
          },
        );
        text = { ok: true, latencyMs: Date.now() - t1 };
      } catch (e) {
        text = { ok: false, error: (e as Error).message };
      }
    }

    return text ? { vision, text, note: TEST_NOTE } : { vision, note: TEST_NOTE };
  }
```

`getActiveConfig()` return 增加两个字段（`imageModel` 后）：

```ts
      textModel: (row.textModel ?? '').trim() !== '' ? (row.textModel as string) : row.visionModel,
      hasCustomTextModel: (row.textModel ?? '').trim() !== '',
```

- [ ] **Step 7: 运行测试确认通过**

Run: `pnpm --filter @lumira/backend exec jest ai-config.service`
Expected: PASS（全部用例）。若 `textChat` mock 报「not a function」因 Task 2 未实施，先实施 Task 2 再回来自证。

- [ ] **Step 8: 更新 ai-config.e2e-spec.ts 断言**

「保存完整配置返回脱敏视图」用例的断言块（`expect(res.body.provider).toBe('qwen')` 附近）追加：

```ts
    expect(res.body.textModel).toBe('');
    expect(res.body.effectiveTextModel).toBe('qwen-vl-max');
```

- [ ] **Step 9: typecheck + commit**

Run: `pnpm --filter @lumira/backend exec tsc --noEmit`
Expected: 无输出（通过）

```bash
git add lumira-server/packages/backend/src/database/migrations/031_ai_text_model.sql lumira-server/packages/backend/src/database/schema.ts lumira-server/packages/backend/src/modules/ai/dto/update-ai-config.dto.ts lumira-server/packages/backend/src/modules/ai/ai-config.service.ts lumira-server/packages/backend/src/modules/ai/ai-config.service.spec.ts lumira-server/packages/backend/test/ai-config.e2e-spec.ts
git commit -m "feat(backend-ai): optional textModel config with vision fallback (migration 031)"
```

---

### Task 2: 后端 — llm-client 抽 chatRequest + 新增 textChat

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/llm-client.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/llm-client.spec.ts`（追加用例）

**Interfaces:**
- Consumes: 无（纯函数层重构，`visionChat` 对外签名不变）
- Produces:
  - `LlmConfig { provider: string; baseUrl: string; apiKey: string; visionModel: string; textModel?: string }`
  - `TextChatInput { systemPrompt: string; userText: string; temperature?: number; jsonMode?: boolean; timeoutMs?: number }`
  - `textChat(cfg: LlmConfig, input: TextChatInput): Promise<string>`（model 取 `cfg.textModel ?? cfg.visionModel`）

- [ ] **Step 1: 写失败测试（llm-client.spec.ts 追加）**

先阅读现有 `llm-client.spec.ts` 的 fetch mock 方式并沿用其模式；若现有文件用 `global.fetch = jest.fn()`，追加以下用例：

```ts
// ===== textChat（Task 2 追加）=====
describe('textChat', () => {
  const cfg = {
    provider: 'qwen',
    baseUrl: 'https://x.example/v1',
    apiKey: 'sk-test',
    visionModel: 'qwen-vl-max',
    textModel: 'qwen-plus',
  };

  it('请求体为纯文本 messages（无 image_url），model 取 textModel', async () => {
    fetchMock.mockResolvedValueOnce(okResponse('hello'));
    const out = await textChat(cfg, { systemPrompt: 'sys', userText: 'hi' });
    expect(out).toBe('hello');
    const body = JSON.parse(fetchMock.mock.calls[0][1].body);
    expect(body.model).toBe('qwen-plus');
    expect(body.messages).toEqual([
      { role: 'system', content: 'sys' },
      { role: 'user', content: 'hi' },
    ]);
  });

  it('未配置 textModel → model 回退 visionModel', async () => {
    fetchMock.mockResolvedValueOnce(okResponse('hello'));
    await textChat(
      { provider: 'qwen', baseUrl: 'https://x.example/v1', apiKey: 'sk-test', visionModel: 'qwen-vl-max' },
      { systemPrompt: 'sys', userText: 'hi' },
    );
    const body = JSON.parse(fetchMock.mock.calls[0][1].body);
    expect(body.model).toBe('qwen-vl-max');
  });

  it('jsonMode 400 时自动降级重试（复用 visionChat 同款逻辑）', async () => {
    fetchMock
      .mockResolvedValueOnce(badRequestResponse())
      .mockResolvedValueOnce(okResponse('{"a":1}'));
    const out = await textChat(cfg, { systemPrompt: 'sys', userText: 'hi', jsonMode: true });
    expect(out).toBe('{"a":1}');
    expect(fetchMock).toHaveBeenCalledTimes(2);
    expect(JSON.parse(fetchMock.mock.calls[0][1].body).response_format).toEqual({ type: 'json_object' });
    expect(JSON.parse(fetchMock.mock.calls[1][1].body).response_format).toBeUndefined();
  });
});
```

`okResponse`/`badRequestResponse`/`fetchMock` 复用现有文件的辅助（若命名不同，按现有文件实际命名适配；`okResponse(text)` 返回 `new Response(JSON.stringify({ choices: [{ message: { content: text } }] }), { status: 200 })`）。

- [ ] **Step 2: 运行测试确认失败**

Run: `pnpm --filter @lumira/backend exec jest llm-client`
Expected: FAIL（`textChat` 未导出）

- [ ] **Step 3: 重构 llm-client.ts**

整文件替换为（保留原注释精神，`mapNetworkError`/`upstreamError` 原样保留）：

```ts
// lumira-server/packages/backend/src/modules/ai/llm-client.ts
// OpenAI 兼容 chat 客户端（qwen / doubao / zhipu / openai 通用）
// visionChat：带图（content 数组）；textChat：纯文本（content 字符串）
// 两者共享 chatRequest（fetch + 错误映射 + jsonMode 降级）

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

/** 网络层错误 → 运营可读 message（原样保留） */
function mapNetworkError(err: unknown): never {
  const name = (err as { name?: string } | null | undefined)?.name;
  if (name === 'AbortError' || name === 'TimeoutError') {
    throw new Error('AI 请求超时，请稍后重试');
  }
  throw new Error('AI 服务无法连接，请检查 baseUrl');
}

/** 解析上游错误响应体（原样保留） */
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

/** 公共请求层：messages + model → fetch → 错误映射 → jsonMode 降级 → 取 content */
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
```

- [ ] **Step 4: 运行全部 llm-client 测试（新旧用例都过）**

Run: `pnpm --filter @lumira/backend exec jest llm-client`
Expected: PASS（含原有 visionChat 用例——重构不破坏行为）

- [ ] **Step 5: 回跑 Task 1 测试 + typecheck + commit**

Run: `pnpm --filter @lumira/backend exec jest ai-config.service` → PASS
Run: `pnpm --filter @lumira/backend exec tsc --noEmit` → 无输出

```bash
git add lumira-server/packages/backend/src/modules/ai/llm-client.ts lumira-server/packages/backend/src/modules/ai/llm-client.spec.ts
git commit -m "feat(backend-ai): extract chatRequest and add textChat with model fallback"
```

---

### Task 3: 后端 — ai-analyze 多输入（image 可选 + text 字段）+ prompt 分叉

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-templates.controller.ts`（analyze 端点 + parseAiMultipart）
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-analyze.service.ts`
- Modify: `lumira-server/packages/backend/src/modules/ai/analyze.prompt.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/ai-analyze.service.spec.ts`（更新+追加）
- Test: `lumira-server/packages/backend/test/ai-analyze.e2e-spec.ts`（更新）

**Interfaces:**
- Consumes: `textChat`（Task 2）、`ActiveAiConfig.textModel`（Task 1）
- Produces:
  - `ParsedAiMultipart { meta: string | null; text?: string; image?: UploadFile; reference?: UploadFile }`
  - `AiAnalyzeService.analyze(image: UploadFile | undefined, text: string | undefined): Promise<{ draft: Record<string, unknown>; warnings: string[] }>`
  - `buildAnalyzeUserPrompt(userText?: string): string`（签名扩展，可选参数）
  - `buildTextOnlySystemPrompt(categories: CategoryNode[]): string`
  - `buildTextOnlyUserPrompt(userText: string): string`

- [ ] **Step 1: 写失败测试（ai-analyze.service.spec.ts 追加）**

现有文件已 `jest.mock('./llm-client', () => ({ visionChat: jest.fn() }))`——改为同时 mock textChat：

```ts
jest.mock('./llm-client', () => ({
  visionChat: jest.fn(),
  textChat: jest.fn(),
}));

const textChatMock = textChat as jest.MockedFunction<typeof textChat>;
```

（import 行补 `textChat`；沿用现有 `buildService` / `visionChatMock` 夹具与 `RAW_DRAFT` 输出夹具。）追加用例：

```ts
describe('AiAnalyzeService — 多输入', () => {
  it('图文都为空 → 400「请至少提供示例图或文字描述之一」', async () => {
    const { service } = buildService();
    await expect(service.analyze(undefined, undefined)).rejects.toThrow(
      '请至少提供示例图或文字描述之一',
    );
    await expect(service.analyze(undefined, '   ')).rejects.toThrow(
      '请至少提供示例图或文字描述之一',
    );
  });

  it('text 超 500 字 → 400', async () => {
    const { service } = buildService();
    await expect(service.analyze(undefined, '长'.repeat(501))).rejects.toThrow('文字描述不能超过 500 字');
  });

  it('仅文字 → 走 textChat（visionChat 不被调），返回归一化草稿', async () => {
    const { service } = buildService();
    visionChatMock.mockResolvedValue(JSON.stringify(RAW_DRAFT));
    textChatMock.mockResolvedValue(JSON.stringify(RAW_DRAFT));
    const res = await service.analyze(undefined, '日系田园风，午后侧逆光');
    expect(textChatMock).toHaveBeenCalledTimes(1);
    expect(visionChatMock).not.toHaveBeenCalled();
    expect(res.draft.meta.category).toBe('portrait');
    // textChat 入参：模型用有效 textModel、userPrompt 含用户文字
    const cfg = textChatMock.mock.calls[0][0];
    expect(cfg.textModel).toBe('qwen-plus');
    expect(textChatMock.mock.calls[0][1].userText).toContain('日系田园风');
  });

  it('图 + 文 → visionChat 的 userText 注入「用户补充要求」', async () => {
    const { service } = buildService();
    visionChatMock.mockResolvedValue(JSON.stringify(RAW_DRAFT));
    await service.analyze(makeImage(), '要侧拍');
    expect(visionChatMock).toHaveBeenCalledTimes(1);
    expect(visionChatMock.mock.calls[0][1].userText).toContain('用户补充要求：要侧拍');
  });

  it('仅图（无文字）→ userText 不含补充要求段（现状不变）', async () => {
    const { service } = buildService();
    visionChatMock.mockResolvedValue(JSON.stringify(RAW_DRAFT));
    await service.analyze(makeImage(), undefined);
    expect(visionChatMock.mock.calls[0][1].userText).not.toContain('用户补充要求');
  });
});
```

`makeImage()` 与 `RAW_DRAFT` 复用现有文件夹具（现有 spec 已有构造合法 image 与模型 RAW 输出的夹具，按实际命名适配；若 `RAW_DRAFT` 不存在则用现有成功路径用例中的模型输出值抽为常量）。`buildService` 的 db mock 需返回分类树行（现有夹具 `CATEGORY_ROWS`）；其配置行需带 `textModel: 'qwen-plus'`（`getActiveConfig` 经 `aiConfigService` stub 或真实 service + db 行——按现有 spec 的 stub 方式，给 ActiveAiConfig stub 补 `textModel: 'qwen-plus', hasCustomTextModel: true`）。

- [ ] **Step 2: 运行测试确认失败**

Run: `pnpm --filter @lumira/backend exec jest ai-analyze.service`
Expected: FAIL（`analyze` 现要求 image 必填；`buildTextOnlySystemPrompt` 未导出；userText 无补充要求逻辑）

- [ ] **Step 3: 改 controller（image 可选 + 解析 text 字段）**

`ai-templates.controller.ts`：

`ParsedAiMultipart` 接口加字段：

```ts
export interface ParsedAiMultipart {
  meta: string | null;
  /** 用户文字描述/创作要求（ai-analyze 可选输入） */
  text?: string;
  image?: UploadFile;
  reference?: UploadFile;
}
```

`parseAiMultipart` 的 field 分支改为：

```ts
    if (part.type === 'field') {
      if (part.fieldname === 'meta') {
        result.meta = part.value as string;
      } else if (part.fieldname === 'text') {
        result.text = part.value as string;
      }
    }
```

analyze 端点改为（校验下沉到 service）：

```ts
  /** AI 识别 → 模板草稿（multipart：image 文件与 text 文本至少一项） */
  @Post('ai-analyze')
  async analyze(@Req() req: FastifyRequest) {
    const { image, text } = await parseAiMultipart(req);
    return this.aiAnalyzeService.analyze(image, text);
  }
```

- [ ] **Step 4: 改 ai-analyze.service.ts（签名 + 分支）**

`analyze` 方法整体替换：

```ts
  /**
   * 示例图（可选）+ 文字描述（可选）→ 模板草稿：
   * 校验（至少一项；text ≤ 500 字）→ 读活跃分类树 → 取启用配置 →
   * 图存在走 visionChat（文字作补充要求）/ 仅文字走 textChat → JSON 容错提取 → 归一化
   */
  async analyze(
    image: UploadFile | undefined,
    text: string | undefined,
  ): Promise<{ draft: Record<string, unknown>; warnings: string[] }> {
    // 1. 输入校验：至少一项；text 长度
    const trimmedText = (text ?? '').trim();
    if (!image && !trimmedText) {
      throw new BadRequestException('请至少提供示例图或文字描述之一');
    }
    if (trimmedText.length > 500) {
      throw new BadRequestException('文字描述不能超过 500 字');
    }
    if (image) {
      if (!ALLOWED_IMAGE_MIMES.includes(image.mimetype)) {
        throw new BadRequestException('仅支持 jpg/png/webp 图片');
      }
      if (image.buffer.byteLength > MAX_IMAGE_BYTES) {
        const mb = (MAX_IMAGE_BYTES / 1024 / 1024).toFixed(0);
        throw new BadRequestException(`示例图不能超过 ${mb}MB（当前${(image.buffer.byteLength / 1024 / 1024).toFixed(2)}MB）`);
      }
    }

    // 2. 读 DB 活跃分类树（现状不变）
    const db = this.dbService.getDb();
    const rows = await db.select().from(templateCategories).where(eq(templateCategories.isActive, 1));
    const categories: CategoryNode[] = rows.map((r) => ({
      key: r.key,
      name: r.name,
      parentKey: r.parentKey,
      level: r.level,
    }));

    // 3. 取启用配置（未配置/未启用 → 503 透传）
    const cfg = await this.aiConfigService.getActiveConfig();

    // 4. 按输入组合分叉：有图走视觉模型（文字作补充要求），仅文字走文本模型
    let content: string;
    if (image) {
      content = await visionChat(cfg, {
        systemPrompt: buildAnalyzeSystemPrompt(categories),
        userText: buildAnalyzeUserPrompt(trimmedText || undefined),
        imageBase64: image.buffer.toString('base64'),
        imageMime: image.mimetype,
        temperature: 0.3,
        jsonMode: true,
      });
    } else {
      content = await textChat(cfg, {
        systemPrompt: buildTextOnlySystemPrompt(categories),
        userText: buildTextOnlyUserPrompt(trimmedText),
        temperature: 0.3,
        jsonMode: true,
      });
    }

    // 5. 容错提取 JSON（现状不变）
    const json = extractJson(content);
    if (!json) {
      throw new BadRequestException('模型输出无法解析为 JSON，请重试识别');
    }

    // 6. 归一化（现状不变）
    return normalizeDraft(json, categories);
  }
```

import 行补 `textChat` 与两个新 prompt 函数：

```ts
import { visionChat, textChat } from './llm-client';
import {
  buildAnalyzeSystemPrompt,
  buildAnalyzeUserPrompt,
  buildTextOnlySystemPrompt,
  buildTextOnlyUserPrompt,
} from './analyze.prompt';
```

- [ ] **Step 5: 改 analyze.prompt.ts（prompt 分叉）**

`buildAnalyzeSystemPrompt` 现有函数体拆分：把首行角色描述之后的内容（从 `## 分类树` 到硬约束结尾）抽为模块私有 `buildSystemPromptBody(categories)`，然后：

```ts
/** 视觉识别版系统提示词（现状行为不变，仅结构拆分） */
export function buildAnalyzeSystemPrompt(categories: CategoryNode[]): string {
  return `你是资深人像摄影模板编辑，分析用户上传的示例图，产出可直接上线的摄影模板表单数据。\n\n${buildSystemPromptBody(categories)}`;
}

/** 纯文字构思版系统提示词（无示例图，基于文字描述构思模板） */
export function buildTextOnlySystemPrompt(categories: CategoryNode[]): string {
  return `你是资深人像摄影模板编辑。用户将提供一段风格描述或创作要求（没有示例图），请据此构思一个可直接上线的摄影模板，产出模板表单数据。描述未提及的字段，给出符合该风格的合理建议值（相机参数为复现该风格的估算值）。\n\n${buildSystemPromptBody(categories)}`;
}
```

`buildAnalyzeUserPrompt` 替换为（签名扩展可选参数）：

```ts
/** 视觉识别版用户提示词（userText = 用户补充要求，识别结果向其倾斜） */
export function buildAnalyzeUserPrompt(userText?: string): string {
  const supplement = userText
    ? `\n用户补充要求：${userText}\n识别结果需向该要求倾斜（如用户要求侧拍/秋日氛围，则构图、场景、后期相应调整）。`
    : '';
  return `请分析这张示例图，按系统提示给出的输出 JSON 契约返回模板草稿。${supplement}`;
}

/** 纯文字版用户提示词 */
export function buildTextOnlyUserPrompt(userText: string): string {
  return `请基于以下文字描述，按系统提示给出的输出 JSON 契约构思并返回模板草稿：\n${userText}`;
}
```

- [ ] **Step 6: 运行单测确认通过**

Run: `pnpm --filter @lumira/backend exec jest ai-analyze.service`
Expected: PASS（含原有用例——原「缺 image 400」相关单测若存在，改为断言新 400 文案或删除，以实际文件内容为准）

- [ ] **Step 7: 更新 e2e（ai-analyze.e2e-spec.ts）**

「缺 image 文件返回 400」用例语义变化（现在缺 image 但有 text 不再 400），替换为：

```ts
  it('POST /api/v1/admin/templates/ai-analyze — 图文都缺返回 400', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/admin/templates/ai-analyze')
      .set('Authorization', `Bearer ${adminToken}`)
      .field('meta', 'x')
      .expect(400);

    expect(res.body.message).toContain('示例图或文字描述');
  });

  it('POST /api/v1/admin/templates/ai-analyze — text 超 500 字返回 400', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/admin/templates/ai-analyze')
      .set('Authorization', `Bearer ${adminToken}`)
      .field('text', '长'.repeat(501))
      .expect(400);

    expect(res.body.message).toContain('500');
  });
```

- [ ] **Step 8: typecheck + commit**

Run: `pnpm --filter @lumira/backend exec tsc --noEmit` → 无输出

```bash
git add lumira-server/packages/backend/src/modules/ai/ai-templates.controller.ts lumira-server/packages/backend/src/modules/ai/ai-analyze.service.ts lumira-server/packages/backend/src/modules/ai/analyze.prompt.ts lumira-server/packages/backend/src/modules/ai/ai-analyze.service.spec.ts lumira-server/packages/backend/test/ai-analyze.e2e-spec.ts
git commit -m "feat(backend-ai): ai-analyze accepts image/text/both with prompt branching"
```

---

### Task 4: 后端 — prompt-polisher + 生图接入润色

**Files:**
- Create: `lumira-server/packages/backend/src/modules/ai/prompt-polisher.ts`
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-generate-image.service.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/prompt-polisher.spec.ts`（新建）
- Test: `lumira-server/packages/backend/src/modules/ai/ai-generate-image.service.spec.ts`（更新）

**Interfaces:**
- Consumes: `textChat`（Task 2）、`ActiveAiConfig`（Task 1）
- Produces:
  - `polishPrompt(cfg: ActiveAiConfig, rawPrompt: string): Promise<{ prompt: string; polished: boolean }>`（永不抛错）

- [ ] **Step 1: 写失败测试（prompt-polisher.spec.ts，新建）**

```ts
// lumira-server/packages/backend/src/modules/ai/prompt-polisher.spec.ts
// prompt 润色单测：成功 / 抛错回退 / 空白回退 / 入参断言

import { polishPrompt } from './prompt-polisher';
import { textChat } from './llm-client';
import type { ActiveAiConfig } from './ai-config.service';

jest.mock('./llm-client', () => ({
  textChat: jest.fn(),
}));

const textChatMock = textChat as jest.MockedFunction<typeof textChat>;

const CFG: ActiveAiConfig = {
  provider: 'qwen',
  baseUrl: 'https://x.example',
  apiKey: 'sk-test',
  visionModel: 'qwen-vl-max',
  imageModel: 'wanx2.1-t2i-turbo',
  textModel: 'qwen-plus',
  hasCustomTextModel: true,
};

describe('polishPrompt', () => {
  beforeEach(() => textChatMock.mockReset());

  it('成功 → 返回 trim 后的润色值 + polished: true', async () => {
    textChatMock.mockResolvedValue('  润色后的提示词  ');
    const res = await polishPrompt(CFG, '原始拼接 prompt');
    expect(res).toEqual({ prompt: '润色后的提示词', polished: true });
  });

  it('textChat 抛错 → 静默回退 rawPrompt + polished: false', async () => {
    textChatMock.mockRejectedValue(new Error('timeout'));
    const res = await polishPrompt(CFG, '原始拼接 prompt');
    expect(res).toEqual({ prompt: '原始拼接 prompt', polished: false });
  });

  it('textChat 返回空白 → 回退 rawPrompt', async () => {
    textChatMock.mockResolvedValue('   ');
    const res = await polishPrompt(CFG, '原始拼接 prompt');
    expect(res).toEqual({ prompt: '原始拼接 prompt', polished: false });
  });

  it('入参：temperature 0.4、timeoutMs 30s、userText = rawPrompt、模型取有效 textModel', async () => {
    textChatMock.mockResolvedValue('润色');
    await polishPrompt(CFG, '原始拼接 prompt');
    const [cfgArg, inputArg] = textChatMock.mock.calls[0];
    expect(cfgArg.textModel).toBe('qwen-plus');
    expect(inputArg.userText).toBe('原始拼接 prompt');
    expect(inputArg.temperature).toBe(0.4);
    expect(inputArg.timeoutMs).toBe(30_000);
    expect(inputArg.systemPrompt).toContain('摄影');
  });
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `pnpm --filter @lumira/backend exec jest prompt-polisher`
Expected: FAIL（模块不存在）

- [ ] **Step 3: 实现 prompt-polisher.ts**

```ts
// lumira-server/packages/backend/src/modules/ai/prompt-polisher.ts
// 生图 prompt 润色：拼接 prompt → textChat 转写为专业摄影描述；失败静默回退（不阻塞生图）
// 设计文档：docs/specs/2026-09-10-ai-create-enhancement-design.md 第三节

import { textChat } from './llm-client';
import type { ActiveAiConfig } from './ai-config.service';

const POLISH_SYSTEM_PROMPT = `你是专业摄影艺术指导。将给定的模板参数描述转写为一段高质量的中文生图提示词，融入光影氛围、镜头语言、色彩层次、景深质感等专业摄影表达。保留原有全部关键信息（主体、构图、风格、光线、背景、色调），只做表达升级，不新增与模板无关的元素。直接输出转写后的提示词，不要任何解释。`;

export interface PolishResult {
  prompt: string;
  polished: boolean;
}

/**
 * 润色生图 prompt。永不抛错：textChat 失败/超时/空白输出时返回原始 prompt。
 */
export async function polishPrompt(cfg: ActiveAiConfig, rawPrompt: string): Promise<PolishResult> {
  try {
    const out = await textChat(cfg, {
      systemPrompt: POLISH_SYSTEM_PROMPT,
      userText: rawPrompt,
      temperature: 0.4,
      timeoutMs: 30_000,
    });
    const trimmed = out.trim();
    if (!trimmed) return { prompt: rawPrompt, polished: false };
    return { prompt: trimmed, polished: true };
  } catch {
    return { prompt: rawPrompt, polished: false };
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `pnpm --filter @lumira/backend exec jest prompt-polisher`
Expected: PASS

- [ ] **Step 5: 接入 ai-generate-image.service.ts**

先读现有 `ai-generate-image.service.spec.ts`，确认其对 `./image-client` 的 mock 方式。service 修改：

```ts
import { polishPrompt } from './prompt-polisher';
```

`generate()` 第 3 步替换为：

```ts
    // 3. 构建 prompt（拼接 → textModel 润色，失败回退拼接值）+ 按厂商映射尺寸 → 生图
    const rawPrompt = buildImagePrompt(draft);
    const { prompt } = await polishPrompt(cfg, rawPrompt);
    return generateImage(cfg, {
      prompt,
      size: mapSize(cfg.provider, extractAspectRatio(draft)),
      referenceBase64: reference?.buffer.toString('base64'),
      referenceMime: reference?.mimetype,
    });
```

- [ ] **Step 6: 更新 ai-generate-image.service.spec.ts**

在文件顶部 mock 块追加 llm-client（与 image-client mock 并列）：

```ts
jest.mock('./llm-client', () => ({
  textChat: jest.fn(async () => '润色后的提示词'),
}));
```

现有断言 `generateImage` 收到的 `prompt` 值从拼接值改为 `'润色后的提示词'`（按现有用例逐个更新），并追加回退用例：

```ts
  it('润色失败 → generateImage 收到原始拼接 prompt', async () => {
    const { textChat } = jest.requireMock('./llm-client') as { textChat: jest.Mock };
    textChat.mockRejectedValueOnce(new Error('timeout'));
    // ...按现有用例方式构造 service 并调用 generate，断言 generateImage mock 收到的 prompt 为 buildImagePrompt 输出
  });
```

（具体构造代码沿用该文件现有用例的 stub 模式——`AiConfigService` stub 返回有效 cfg。）

- [ ] **Step 7: 运行测试 + typecheck + commit**

Run: `pnpm --filter @lumira/backend exec jest prompt-polisher ai-generate-image`
Expected: PASS
Run: `pnpm --filter @lumira/backend exec tsc --noEmit` → 无输出

```bash
git add lumira-server/packages/backend/src/modules/ai/prompt-polisher.ts lumira-server/packages/backend/src/modules/ai/prompt-polisher.spec.ts lumira-server/packages/backend/src/modules/ai/ai-generate-image.service.ts lumira-server/packages/backend/src/modules/ai/ai-generate-image.service.spec.ts
git commit -m "feat(backend-ai): polish image prompt via text model with silent fallback"
```

---

### Task 5: Admin — AI 设置页文本模型字段 + 类型扩展

**Files:**
- Modify: `lumira-server/packages/admin/src/types/admin.ts:385-415`（AI 相关接口）
- Modify: `lumira-server/packages/admin/src/components/ai-config-form.tsx`

**Interfaces:**
- Consumes: 后端 Task 1 的响应结构（`AiConfigView` + `textModel`/`effectiveTextModel`；`AiConfigTestResult` + `text?`）
- Produces:
  - `AiProviderConfigView { ...; textModel: string; effectiveTextModel: string }`
  - `UpdateAiConfigPayload { ...; textModel?: string }`
  - `AiConfigTestResult { vision; text?; note }`
  - `PROVIDER_PRESETS[key].textModel`：qwen → `'qwen-plus'`、doubao → `'doubao-1.5-pro-32k'`、zhipu → `'glm-4-flash'`、openai → `'gpt-4o-mini'`

- [ ] **Step 1: 更新 types/admin.ts**

```ts
export interface AiProviderConfigView {
  configured: boolean;
  provider: string;
  baseUrl: string;
  apiKeyMasked: string;
  visionModel: string;
  imageModel: string;
  /** 存储值（'' = 未配置独立文本模型） */
  textModel: string;
  /** 有效文本模型 = textModel || visionModel */
  effectiveTextModel: string;
  enabled: boolean;
}

export interface UpdateAiConfigPayload {
  provider: string;
  baseUrl: string;
  apiKey?: string;
  visionModel: string;
  imageModel: string;
  /** 空串/缺省 = 清除（回退视觉模型） */
  textModel?: string;
  enabled: boolean;
}

export interface AiConfigTestResult {
  vision: { ok: boolean; latencyMs?: number; error?: string };
  /** 配置了独立文本模型时返回 */
  text?: { ok: boolean; latencyMs?: number; error?: string };
  note: string;
}
```

- [ ] **Step 2: 更新 ai-config-form.tsx**

`PROVIDER_PRESETS` 四个厂商各加 `textModel` 字段（值见 Interfaces）。`FormState` 加 `textModel: string`。`touched` 初始状态的 key 类型与值补 `textModel`：

```ts
  const [touched, setTouched] = useState<Record<'baseUrl' | 'visionModel' | 'imageModel' | 'textModel', boolean>>({
    baseUrl: configured,
    visionModel: configured,
    imageModel: configured,
    textModel: configured,
  });
```

`useState<FormState>` 初始化：configured 分支加 `textModel: initial.textModel`（后端已保证返回 `''` 而非 undefined）；未配置分支加 `textModel: PROVIDER_PRESETS.qwen.textModel`。`selectProvider` 中 spread 后补：

```ts
      textModel: touched.textModel ? f.textModel : PROVIDER_PRESETS[key].textModel,
```

表单 UI：在「视觉模型」输入框之后、「生图模型」之前插入（沿用现有 Label+Input 模式，`value={form.textModel}` `onChange` 同其他字段并标记 touched）：

```tsx
  <div className="space-y-2">
    <Label htmlFor="textModel">文本模型（可选）</Label>
    <Input
      id="textModel"
      value={form.textModel}
      onChange={(e) => {
        setForm((f) => ({ ...f, textModel: e.target.value }));
        setTouched((t) => ({ ...t, textModel: true }));
      }}
      placeholder="留空则使用视觉模型（用于文字识别与生图提示词润色）"
    />
    {form.textModel.trim() === '' && (
      <p className="text-xs text-muted-foreground">当前生效：{/* 此行放在预览态，见下 */}</p>
    )}
  </div>
```

（placeholder 下的小字提示可选做；若做，configured 态显示 `initial.effectiveTextModel`。）提交 payload 加 `textModel: form.textModel`。

测试结果展示区：现有 vision 行之后追加（存在才渲染）：

```tsx
  {testResult.text && (
    <div className={cn('flex items-center justify-between rounded-md border p-3 text-sm',
      testResult.text.ok ? 'border-green-200 bg-green-50 text-green-800'
        : 'border-destructive/50 bg-destructive/10 text-destructive')}>
      <span>文本模型</span>
      <span>{testResult.text.ok ? `连通 ${testResult.text.latencyMs}ms` : testResult.text.error}</span>
    </div>
  )}
```

（样式类对齐现有 vision 行的写法，以文件实际代码为准。）

- [ ] **Step 3: typecheck + 手动验证 + commit**

Run: `pnpm --filter @lumira/admin exec tsc --noEmit`
Expected: 无输出

手动验证（本地起 admin dev + backend dev）：AI 设置页出现文本模型输入框；保存后重新加载回显；留空保存不报错。

```bash
git add lumira-server/packages/admin/src/types/admin.ts lumira-server/packages/admin/src/components/ai-config-form.tsx
git commit -m "feat(admin): text model field in AI config with provider presets"
```

---

### Task 6: Admin — 向导 Step1 文字输入 + 纯文模式联动

**Files:**
- Modify: `lumira-server/packages/admin/src/components/ai-create/wizard.tsx`

**Interfaces:**
- Consumes: 后端 Task 3 的 `ai-analyze`（multipart `image` 可选 + `text` 可选）；`aiAnalyzeAction` FormData 直传（actions/ai.ts 与 lib/api.ts 无需改动）
- Produces: 向导状态 `inputText: string`（供 Task 7 预览面板布局共存）

- [ ] **Step 1: 抽取 resetFlow + 新增 inputText 状态**

wizard.tsx 中（`const [exampleFile, ...]` 附近）：

```tsx
  const [inputText, setInputText] = useState('');
```

将 `handleExamplePick` 中现有重置块（`setDraft(null)` 到 `setMaxStep(1)` 七行）抽为：

```tsx
  /** 换图 / 改文字 = 重置整个下游流程 */
  const resetFlow = () => {
    setDraft(null);
    setWarnings([]);
    setCandidates([]);
    setSilhouetteFile(null);
    setInjection(null);
    setFormActivated(false);
    setAutoState(null);
    setStep(1);
    setMaxStep(1);
  };
```

`handleExamplePick` 原重置块改调 `resetFlow()`。文字输入 handler：

```tsx
  const handleTextChange = (v: string) => {
    setInputText(v);
    // 流程已启动后修改输入 = 重新开始
    if (formActivated || step > 1) resetFlow();
  };
```

- [ ] **Step 2: 按钮禁用条件 + FormData 组装**

两个按钮（开始识别 / 全自动）禁用条件统一改为：

```tsx
  const hasInput = Boolean(exampleFile) || inputText.trim() !== '';
  // disabled={!exampleFile || busy} → disabled={!hasInput || busy}
```

`handleAnalyze` 与 `runAutoAll` 中的 analyze FormData：

```tsx
    const analyzeFd = new FormData();
    if (exampleFile) analyzeFd.set('image', exampleFile);
    if (inputText.trim()) analyzeFd.set('text', inputText.trim());
```

`handleAnalyze` 成功后：示例图候选与 images 注入仅在有图时（纯文模式封面候选初始为空）：

```tsx
    setDraft(result.draft);
    setWarnings(result.warnings);
    if (exampleFile) {
      setCandidates([{
        id: 'example',
        file: exampleFile,
        url: URL.createObjectURL(exampleFile),
        source: 'example',
      }]);
      inject({ json: result.draft, images: [exampleFile], replaceImages: true });
    } else {
      setCandidates([]);
      inject({ json: result.draft });
    }
    setFormActivated(true);
    goto(2);
```

`runAutoAll` 中：
- `exampleCandidate` 构造包在 `if (exampleFile)` 内；
- 生图 `genFd.set('reference', exampleFile)` 改为 `if (exampleFile) genFd.set('reference', exampleFile);`
- 生图成功后的 candidates：`[aiCover 候选, ...(exampleFile ? [exampleCandidate] : [])]`，`inject({ json: draftLocal, images: [aiCover], replaceImages: true })`（现状）；
- 生图失败回退：`setCandidates(exampleFile ? [exampleCandidate] : []);`，`inject` 仅在有图时带 images；
- 其余（剪影源 = aiCover、提交）不变。

- [ ] **Step 3: Step1 UI 改造**

「示例图（该风格的成片参考）」标题改为「示例图（可选，该风格的成片参考）」；上传区之后插入文字输入卡片：

```tsx
            <div className="rounded-lg border border-border p-4">
              <Label htmlFor="ai-input-text" className="text-sm font-medium text-foreground">
                文字描述 / 创作要求（可选）
              </Label>
              <p className="mt-0.5 text-xs text-muted-foreground">
                无示例图时可仅用文字描述；也可与示例图同用，AI 将向你的要求倾斜
              </p>
              <textarea
                id="ai-input-text"
                className="mt-2 min-h-[88px] w-full rounded-md border border-border bg-background p-2 text-sm"
                maxLength={500}
                placeholder="例：日系田园风，午后侧逆光，少女侧身回眸，画面清新通透"
                value={inputText}
                onChange={(e) => handleTextChange(e.target.value)}
              />
              <div className="mt-1 text-right text-xs text-muted-foreground">{inputText.length}/500</div>
            </div>
```

（import `Label` from `@/components/ui/label`；CardDescription 文案「jpg / png / webp，≤ 8MB…」保持。）

- [ ] **Step 4: typecheck + 手动验证 + commit**

Run: `pnpm --filter @lumira/admin exec tsc --noEmit` → 无输出

手动验证三组合：仅图（现状不变）/ 仅文字 / 图文混合，识别按钮启用态正确；纯文模式 Step3 无示例候选、Step4 源图仅封面。

```bash
git add lumira-server/packages/admin/src/components/ai-create/wizard.tsx
git commit -m "feat(admin): ai-create wizard accepts text-only or image+text input"
```

---

### Task 7: Admin — 向导层常驻 sticky 实时预览（portal 方案）

**Files:**
- Modify: `lumira-server/packages/admin/src/components/template-form.tsx`（props + 预览块提取 + portal）
- Modify: `lumira-server/packages/admin/src/components/ai-create/wizard.tsx`（布局 + 预览面板）

**Interfaces:**
- Consumes: 现有 `PhonePreview` 组件（props 同表单内预览，`template-form.tsx:2066-2098`）
- Produces:
  - `TemplateFormProps.previewPortalTarget?: HTMLElement | null`（向导传入宿主节点；wizardMode + target 时预览经 `createPortal` 渲染到宿主，否则原位渲染）

- [ ] **Step 1: TemplateForm 加 portal 支持**

import 区加：

```ts
import { createPortal } from 'react-dom';
```

`TemplateFormProps` 加：

```ts
  /** 向导模式预览宿主节点：提供时预览面板经 portal 渲染到该节点（向导层 sticky 布局） */
  previewPortalTarget?: HTMLElement | null;
```

组件参数解构加 `previewPortalTarget = null`。

将现有右侧预览块（`<div className="hidden xl:block w-[300px] shrink-0">…</div>`，约 2062-2101 行）替换为：

```tsx
      {(() => {
        const previewNode = (
          <div className="rounded-lg border border-border bg-card p-4">
            <h3 className="text-sm font-medium text-foreground mb-3">模板预览</h3>
            <PhonePreview
              coverUrl={coverPreviewSrc}
              silhouetteUrl={currentPose ? poseSilhouettePreview(currentPose) : null}
              silhouetteType={currentPose?.silhouetteType ?? 'builtin'}
              silhouetteBuiltinKey={currentPose?.silhouetteBuiltinKey ?? ''}
              positionX={currentPose?.positionX ?? 0.5}
              positionY={currentPose?.positionY ?? 0.5}
              scale={currentPose?.scale ?? 1}
              rotation={currentPose?.rotation ?? 0}
              aspectRatio={watchedValues.aspectRatio}
              overlayType={watchedValues.overlayType}
              opacity={watchedValues.opacity}
              cropRatio={watchedValues.cropRatio}
              lut={watchedValues.lut}
              colorBrightness={watchedValues.colorBrightness}
              colorContrast={watchedValues.colorContrast}
              colorSaturation={watchedValues.colorSaturation}
              colorTemperature={watchedValues.colorTemperature}
              colorTint={watchedValues.colorTint}
              smoothStrength={watchedValues.smoothStrength}
              sharpen={watchedValues.sharpen}
              vignette={watchedValues.vignette}
              grain={watchedValues.grain}
              exposureCompensation={watchedValues.exposureCompensation}
              isoMode={watchedValues.isoMode}
              iso={watchedValues.iso}
              shutterSpeed={watchedValues.shutterSpeed}
              whiteBalance={watchedValues.whiteBalance}
              flashMode={watchedValues.flashMode}
              focusMode={watchedValues.focusMode}
              lensSuggestion={watchedValues.lensSuggestion}
              name={watchedValues.name}
            />
          </div>
        );
        // 向导模式 + 宿主就绪 → portal 到向导 sticky 面板（避免双预览）
        if (wizardMode && previewPortalTarget) {
          return createPortal(previewNode, previewPortalTarget);
        }
        return (
          <div className="hidden xl:block w-[300px] shrink-0">
            <div className="sticky top-6 space-y-4">{previewNode}</div>
          </div>
        );
      })()}
```

（PhonePreview 的 props 以文件当前实际代码为准逐项对齐，不得遗漏现有 props。）

- [ ] **Step 2: wizard 布局改造 + 预览面板**

wizard.tsx 顶部 import 加：

```tsx
import { useEffect } from 'react';   // 并入现有 react import
```

组件内加状态与断点监听：

```tsx
  /** 预览宿主（TemplateForm portal 目标）与 xl 断点（决定宿主位置：右栏 sticky / stepper 下方） */
  const [previewHost, setPreviewHost] = useState<HTMLDivElement | null>(null);
  const [isXl, setIsXl] = useState(true);

  useEffect(() => {
    const mq = window.matchMedia('(min-width: 1280px)');
    const update = () => setIsXl(mq.matches);
    update();
    mq.addEventListener('change', update);
    return () => mq.removeEventListener('change', update);
  }, []);
```

预览面板 JSX（组件 return 前定义）：

```tsx
  /** 常驻预览面板：识别前占位，识别后由 TemplateForm portal 填充宿主 */
  const previewPanel = (
    <div className="rounded-lg border border-border bg-card p-4">
      <h3 className="text-sm font-medium text-foreground mb-3">实时预览</h3>
      {!formActivated ? (
        <div className="flex h-[480px] items-center justify-center rounded-md border border-dashed border-border px-4 text-center text-sm text-muted-foreground">
          识别完成后此处实时预览参数、姿势与封面效果
        </div>
      ) : (
        <div ref={setPreviewHost} />
      )}
    </div>
  );
```

页面最外层结构改为（现有全部内容移入左列；`<div ref>` 宿主常驻，避免 portal 目标闪断）：

```tsx
  return (
    <div className="flex flex-col gap-4 xl:flex-row">
      {/* 左列：向导主体 */}
      <div className="min-w-0 flex-1 space-y-4">
        {/* 现有：标题区、stepper、auto 进度、step1~5 卡片、模板表单 全部原样移入 */}
        ...
        {/* 非 xl：预览面板置底（stepper 之后首个位置，见下） */}
      </div>
      {/* xl：右栏 sticky 预览 */}
      {isXl && (
        <div className="hidden w-[300px] shrink-0 xl:block">
          <div className="sticky top-6">{previewPanel}</div>
        </div>
      )}
    </div>
  );
```

非 xl 放置：左列内、stepper 之后（auto 进度提示之前）插入 `{!isXl && previewPanel}`。模板表单区 `<TemplateForm ... />` 增加 prop：

```tsx
          <TemplateForm
            categories={categories}
            backendUrl={backendUrl}
            wizardMode
            aiInjection={injection}
            previewPortalTarget={previewHost}
          />
```

- [ ] **Step 3: typecheck + 手动验证 + commit**

Run: `pnpm --filter @lumira/admin exec tsc --noEmit` → 无输出

手动验证：
1. 识别前右栏显示占位卡（xl 屏）；
2. 识别完成后预览出现在右栏并随表单修改实时变化（改 LUT/构图比例/姿势位置/换封面）；
3. TemplateForm 自身右侧不再出现第二个预览；
4. 缩窄窗口到 <xl：预览移到 stepper 下方；
5. 普通新建/编辑模板页（非 wizard）预览行为不变。

```bash
git add lumira-server/packages/admin/src/components/template-form.tsx lumira-server/packages/admin/src/components/ai-create/wizard.tsx
git commit -m "feat(admin): wizard-level sticky live preview via portal"
```

---

### Task 8: 收尾 — 全量验证 + 双远程推送

**Files:**
- 无新文件（验证 + 推送）

- [ ] **Step 1: 后端全量单测**

Run（`lumira-server/` 目录）: `pnpm --filter @lumira/backend exec jest 2>&1 | Select-Object -Last 10`
Expected: 全部 PASS（含本次新增 ai-config.service / prompt-polisher / llm-client / ai-analyze.service / ai-generate-image 及既有全部套件）

- [ ] **Step 2: e2e（本地 MySQL 可用时）**

Run: `pnpm --filter @lumira/backend run test:e2e`
Expected: 全部 PASS（重点：ai-config / ai-analyze 更新后的用例）。环境不可用则跳过并注明由 CI 兜底。

- [ ] **Step 3: 双端 typecheck**

Run: `pnpm --filter @lumira/backend exec tsc --noEmit; pnpm --filter @lumira/admin exec tsc --noEmit`
Expected: 均无输出

- [ ] **Step 4: 双远程推送**

```bash
git push origin master
git push github master
```

（若远程有新提交被拒：`git pull --rebase origin master` 后重推。）

- [ ] **Step 5: 部署确认**

推送后 GitHub Actions 自动触发 `backend-deploy.yml`（backend 路径变更）；admin 由 Vercel 自动部署。无 `gh` CLI 时通过仓库 Actions 页面确认。

---

## Self-Review 记录

- **Spec 覆盖**：设计文档第一节（textModel 配置）→ Task 1/2/5；第二节（三输入）→ Task 3/6；第三节（润色）→ Task 4；第四节（sticky 预览）→ Task 7；第五节错误处理 → Task 3（400 用例）/ Task 4（静默回退）；第六节测试 → 各任务 TDD + Task 8 全量。✅
- **占位符扫描**：无 TBD/TODO；所有代码步骤含完整代码。Task 5/6 中「对齐现有文件写法」的说明均附了具体代码。✅
- **类型一致性**：`ActiveAiConfig.textModel/hasCustomTextModel`（Task 1 定义，Task 3/4 消费）；`textChat(cfg: LlmConfig, input: TextChatInput)`（Task 2 定义，Task 1/3/4 消费——`ActiveAiConfig` 结构兼容 `LlmConfig`（含可选 textModel））；`ParsedAiMultipart.text`（Task 3 内闭环）；`previewPortalTarget`（Task 7 内闭环）。✅
- **执行顺序依赖**：Task 1 的 spec mock 了 Task 2 的 `textChat`——若 Task 1 先执行，Step 7 会因 `textChat` 未导出而失败，此时先做 Task 2 Step 3 再回来自证（计划已在 Task 1 Step 7 注明）。
