# AI 识别链路 JSON 容错与重试稳定性 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 AI 一键生成模板的全部 JSON 识别步骤在「输出非法 JSON / 截断 / 超时 / 5xx / 空输出」时先做结构补救再自动重试（次数后台可配，默认 2），单次超时与输出上限后台可配，消除静默跳过与频繁超时。

**Architecture:** 三层解耦——① 配置层（`ai_provider_config` 3 新列 → `ActiveAiConfig.runtime`）② 解析容错层（`normalize.extractJson` 追加结构性修复）③ 重试层（新 `llm-json.ts` 纯函数封装 `visionChatJson`/`textChatJson`，内部循环「调用 → extractJson → 按原因判定重试」）。六个识别服务只把 `visionChat/textChat + extractJson + throw` 换成一行封装调用，业务降级语义不变。

**Tech Stack:** NestJS + Fastify + Drizzle ORM + MySQL 8（`mysql2`）、Jest、Next.js App Router + Tailwind（admin）、TypeScript。

**设计文档：** `docs/superpowers/specs/2026-09-28-ai-llm-json-resilience-design.md`

## Global Constraints

- 单步超时默认 **300000ms（5 分钟）**：与现有 `llm-client.DEFAULT_TIMEOUT_MS` 一致，避免把最重的 `analyze` 视觉调用从 300s 收紧到 180s（收紧会与「减少超时」的目标相悖）；仍可后台在 10000~600000 之间调。
- 输出上限默认 **8192**（由 4096 提升），后台可配 1024~16384。
- 重试次数默认 **2**，合法范围 **0~3**，语义 = **失败后额外重试次数**（`retryCount=2` → 总调用 ≤ 3 次）。
- **可重试原因**：JSON 解析失败（含截断）、超时、HTTP 5xx、空输出。**不可重试**：401/403/400/404 等鉴权与请求错误，原样抛出。
- 修复层**只做结构性闭合**（去尾随逗号、补未闭合括号、取平衡子串），绝不臆造字段值。
- 各步骤**既有业务降级语义不变**：`质量评分`仍回退 `{score:0,verdict:'retry'}`、`草稿细化`仍回退 `null`、`示例图识别`失败仍由编排 `wrapStep` 兜底。
- 前端识别任务轮询总预算 600s → **900s**；生图 / 剪影保持 600s。
- 后端改动完成后按项目规则 commit + push 到 `origin`(gitee) 与 `github` 两个远程。
- 注释与文案统一中文。

---

### Task 1: 配置层（迁移 047 + schema + ActiveAiConfig.runtime + DTO）

**Files:**
- Create: `lumira-server/packages/backend/src/database/migrations/047_ai_config_llm_stability.sql`
- Modify: `lumira-server/packages/backend/src/database/schema.ts`（`aiProviderConfig` 表，约 L387 之后）
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-config.service.ts`（`AiConfigView` L15-61、`ActiveAiConfig` L71-96、`get()` L154-198、`save()` L201-374、`getActiveConfig()` L515-555）
- Modify: `lumira-server/packages/backend/src/modules/ai/dto/update-ai-config.dto.ts`（L128-133 之后）
- Test: `lumira-server/packages/backend/src/modules/ai/ai-config.service.spec.ts`

**Interfaces:**
- Consumes: 无（本任务是其它任务的基础）
- Produces:
  - `ActiveAiConfig.runtime: { retryCount: number; timeoutMs: number; maxTokens: number }`
  - `AiConfigView.llmRetryCount: number; llmTimeoutMs: number; llmMaxTokens: number`
  - `UpdateAiConfigDto.llmRetryCount?: number; llmTimeoutMs?: number; llmMaxTokens?: number`

- [ ] **Step 1: 写失败测试**

在 `ai-config.service.spec.ts` 末尾追加：

```ts
describe('AiConfigService — 识别稳定性（runtime / retryCount / timeout / maxTokens）', () => {
  it('get() 行含三列 → 视图原样返回', async () => {
    const svc = new AiConfigService(readonlyDb(row({ llmRetryCount: 3, llmTimeoutMs: 240_000, llmMaxTokens: 12_288 })) as unknown as DatabaseService);
    const view = await svc.get();
    expect(view).toMatchObject({ configured: true, llmRetryCount: 3, llmTimeoutMs: 240_000, llmMaxTokens: 12_288 });
  });

  it('get() 行缺三列（老数据 / 未选列）→ 回退默认 2 / 300000 / 8192', async () => {
    const svc = new AiConfigService(readonlyDb(row()) as unknown as DatabaseService);
    const view = await svc.get();
    expect(view).toMatchObject({ llmRetryCount: 2, llmTimeoutMs: 300_000, llmMaxTokens: 8192 });
  });

  it('getActiveConfig() → runtime 取自三列', async () => {
    const svc = new AiConfigService(readonlyDb(row({ llmRetryCount: 1, llmTimeoutMs: 120_000, llmMaxTokens: 4096 })) as unknown as DatabaseService);
    const cfg = await svc.getActiveConfig();
    expect(cfg.runtime).toEqual({ retryCount: 1, timeoutMs: 120_000, maxTokens: 4096 });
  });

  it('getActiveConfig() 行缺三列 → runtime 用默认值', async () => {
    const svc = new AiConfigService(readonlyDb(row()) as unknown as DatabaseService);
    const cfg = await svc.getActiveConfig();
    expect(cfg.runtime).toEqual({ retryCount: 2, timeoutMs: 300_000, maxTokens: 8192 });
  });

  it('save() 更新带三字段 → update set 收到三列', async () => {
    const { service, updateSet } = writableDb(row());
    await service.save({
      provider: 'qwen', baseUrl: 'https://x.example', visionModel: 'qwen-vl-max', imageModel: 'wanx2.1-t2i-turbo',
      enabled: true, llmRetryCount: 3, llmTimeoutMs: 240_000, llmMaxTokens: 12_288,
    });
    expect(updateSet).toHaveBeenCalledWith(expect.objectContaining({ llmRetryCount: 3, llmTimeoutMs: 240_000, llmMaxTokens: 12_288 }));
  });

  it('save() 更新缺三字段 → 保留存量值', async () => {
    const { service, updateSet } = writableDb(row({ llmRetryCount: 3, llmTimeoutMs: 240_000, llmMaxTokens: 12_288 }));
    await service.save({ provider: 'qwen', baseUrl: 'https://x.example', visionModel: 'qwen-vl-max', imageModel: 'wanx2.1-t2i-turbo', enabled: true });
    expect(updateSet).toHaveBeenCalledWith(expect.objectContaining({ llmRetryCount: 3, llmTimeoutMs: 240_000, llmMaxTokens: 12_288 }));
  });

  it('save() 首次保存缺三字段 → insert values 收到默认值', async () => {
    const { service, insertValues } = writableDb(undefined);
    await service.save({
      provider: 'qwen', baseUrl: 'https://x.example', apiKey: 'sk-1', visionModel: 'qwen-vl-max', imageModel: 'wanx2.1-t2i-turbo', enabled: true,
    });
    expect(insertValues).toHaveBeenCalledWith(expect.objectContaining({ llmRetryCount: 2, llmTimeoutMs: 300_000, llmMaxTokens: 8192 }));
  });
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `pnpm --filter @lumira/backend test -- ai-config.service.spec`
Expected: FAIL —— `row()` 无新列时 `view.llmRetryCount` 为 `undefined`（不等于 2），且 `cfg.runtime` 为 `undefined`。

- [ ] **Step 3: 新增迁移**

`047_ai_config_llm_stability.sql`：

```sql
-- lumira-server/packages/backend/src/database/migrations/047_ai_config_llm_stability.sql
-- AI 识别链路稳定性配置：JSON 解析失败重试次数 / 单次 LLM 调用超时 / 单次输出 token 上限
-- 幂等：由 _migrations 表记录，仅执行一次；NOT NULL DEFAULT 保证存量行零数据迁移

ALTER TABLE `ai_provider_config`
  ADD COLUMN `llm_retry_count` INT NOT NULL DEFAULT 2 COMMENT '识别步骤失败后额外重试次数（0~3；总调用 ≤ 次数+1）',
  ADD COLUMN `llm_timeout_ms` INT NOT NULL DEFAULT 300000 COMMENT '单次 LLM 调用超时（毫秒）',
  ADD COLUMN `llm_max_tokens` INT NOT NULL DEFAULT 8192 COMMENT '单次 LLM 输出 token 上限';
```

- [ ] **Step 4: schema 补列**

在 `schema.ts` 的 `aiProviderConfig` 中 `maxIterations` 之后插入：

```ts
  /** ===== 识别链路稳定性（spec 2026-09-28）===== */
  /** 识别步骤失败后额外重试次数（0~3；总调用次数 ≤ 次数 + 1） */
  llmRetryCount: int('llm_retry_count').notNull().default(2),
  /** 单次 LLM 调用超时（毫秒） */
  llmTimeoutMs: int('llm_timeout_ms').notNull().default(300_000),
  /** 单次 LLM 输出 token 上限 */
  llmMaxTokens: int('llm_max_tokens').notNull().default(8192),
```

- [ ] **Step 5: 服务暴露 runtime**

`ai-config.service.ts`：

1) `AiConfigView` 末尾（`searchQwenOfficialModel` 之后）追加：

```ts
  /** 识别稳定性：失败后额外重试次数（默认 2） */
  llmRetryCount: number;
  /** 识别稳定性：单次 LLM 调用超时（毫秒，默认 300000） */
  llmTimeoutMs: number;
  /** 识别稳定性：单次 LLM 输出 token 上限（默认 8192） */
  llmMaxTokens: number;
```

2) 文件级常量（放在 `ALL_TEST_TARGETS` 附近）：

```ts
/** 识别链路稳定性默认值（老数据 / 未配置列的回退口径，与迁移 047 的 DEFAULT 一致） */
const DEFAULT_LLM_RETRY_COUNT = 2;
const DEFAULT_LLM_TIMEOUT_MS = 300_000;
const DEFAULT_LLM_MAX_TOKENS = 8192;
```

3) `ActiveAiConfig` 末尾追加：

```ts
  /** 识别链路稳定性（JSON 识别步骤重试 / 超时 / 输出上限） */
  runtime: {
    /** 失败后额外重试次数（0 = 不重试） */
    retryCount: number;
    /** 单次 LLM 调用超时（毫秒） */
    timeoutMs: number;
    /** 单次 LLM 输出 token 上限 */
    maxTokens: number;
  };
```

4) `get()` 返回对象中 `searchQwenOfficialModel` 之后追加：

```ts
      llmRetryCount: row.llmRetryCount ?? DEFAULT_LLM_RETRY_COUNT,
      llmTimeoutMs: row.llmTimeoutMs ?? DEFAULT_LLM_TIMEOUT_MS,
      llmMaxTokens: row.llmMaxTokens ?? DEFAULT_LLM_MAX_TOKENS,
```

5) `getActiveConfig()` 返回对象中 `search: {...}` 之后追加：

```ts
      runtime: {
        retryCount: row.llmRetryCount ?? DEFAULT_LLM_RETRY_COUNT,
        timeoutMs: row.llmTimeoutMs ?? DEFAULT_LLM_TIMEOUT_MS,
        maxTokens: row.llmMaxTokens ?? DEFAULT_LLM_MAX_TOKENS,
      },
```

6) `save()` 中，`maxIterations` 常量声明之后追加：

```ts
    const llmRetryCount = dto.llmRetryCount ?? existing?.llmRetryCount ?? DEFAULT_LLM_RETRY_COUNT;
    const llmTimeoutMs = dto.llmTimeoutMs ?? existing?.llmTimeoutMs ?? DEFAULT_LLM_TIMEOUT_MS;
    const llmMaxTokens = dto.llmMaxTokens ?? existing?.llmMaxTokens ?? DEFAULT_LLM_MAX_TOKENS;
```

并在 `insert(...).values({...})` 的 `maxIterations,` 之后与 `update(...).set({...})` 的 `maxIterations,` 之后，各追加：

```ts
        llmRetryCount,
        llmTimeoutMs,
        llmMaxTokens,
```

- [ ] **Step 6: DTO 补字段**

`update-ai-config.dto.ts` 中 `maxIterations` 声明之后追加：

```ts
  /** 识别稳定性：失败后额外重试次数（0~3）；缺省 = 沿用原值 */
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(3)
  llmRetryCount?: number;

  /** 识别稳定性：单次 LLM 调用超时（毫秒，10000~600000）；缺省 = 沿用原值 */
  @IsOptional()
  @IsInt()
  @Min(10_000)
  @Max(600_000)
  llmTimeoutMs?: number;

  /** 识别稳定性：单次 LLM 输出 token 上限（1024~16384）；缺省 = 沿用原值 */
  @IsOptional()
  @IsInt()
  @Min(1024)
  @Max(16_384)
  llmMaxTokens?: number;
```

- [ ] **Step 7: 运行测试确认通过**

Run: `pnpm --filter @lumira/backend test -- ai-config.service.spec`
Expected: PASS（新增 7 条 + 原有全部用例通过）。

- [ ] **Step 8: 提交**

```bash
git add lumira-server/packages/backend/src/database/migrations/047_ai_config_llm_stability.sql lumira-server/packages/backend/src/database/schema.ts lumira-server/packages/backend/src/modules/ai/ai-config.service.ts lumira-server/packages/backend/src/modules/ai/dto/update-ai-config.dto.ts lumira-server/packages/backend/src/modules/ai/ai-config.service.spec.ts
git commit -m "feat(ai): 识别稳定性配置列（重试次数/单次超时/输出上限）+ runtime 透出"
```

---

### Task 2: `extractJson` 结构性补救

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/normalize.ts`（L75-105）
- Test: `lumira-server/packages/backend/src/modules/ai/normalize.spec.ts`（L81-98 的 `describe('extractJson')`）

**Interfaces:**
- Consumes: 无
- Produces: `extractJson(text: string): Record<string, unknown> | null`（签名不变，行为增强）；新增内部（非导出）函数 `closeUnbalancedJson(candidate: string): string`

- [ ] **Step 1: 写失败测试**

在 `normalize.spec.ts` 的 `describe('extractJson')` 内、现有 4 条之后追加：

```ts
  it('5. 截断 JSON（缺尾部括号）→ 补全括号后解析成功', () => {
    expect(extractJson('{"a":1,"b":{"c":[1,2')).toEqual({ a: 1, b: { c: [1, 2] } });
  });

  it('6. 尾随逗号 → 去掉后解析成功', () => {
    expect(extractJson('{"a":1,"b":[1,2,],}')).toEqual({ a: 1, b: [1, 2] });
  });

  it('7. 截断发生在字符串内 → 仍是非法 JSON，返回 null（不臆造内容）', () => {
    expect(extractJson('{"a":"未闭合的字符串')).toBeNull();
  });

  it('8. 首个 { 之后存在多个 JSON 块 → 取能成功解析的最长平衡子串', () => {
    expect(extractJson('{"a":1} 中间说明 {"b":2}')).toEqual({ a: 1, b: 2 });
  });
```

- [ ] **Step 2: 运行测试确认失败**

Run: `pnpm --filter @lumira/backend test -- normalize.spec`
Expected: FAIL —— 用例 5/6 返回 `null`（当前只有直解 / 剥围栏 / 首末截取三步，无修复）；用例 8 返回 `{a:1,b:2}` 属误判需修正断言前先观察实际输出。

> 实现前先跑一次，按真实输出校正用例 8 的期望值（若当前实现已返回 `{a:1,b:2}`，则该条应改为验证「尾部多余内容不影响」并保留）。

- [ ] **Step 3: 实现修复层**

把 `normalize.ts` 的 `extractJson` 整体替换为：

```ts
/**
 * 结构性闭合：去掉对象/数组尾随逗号，并按括号栈补齐未闭合的 } / ]。
 * 仅做语法层修复，绝不臆造字段或值；字符串内的截断无法修复（由重试层负责）。
 */
function closeUnbalancedJson(candidate: string): string | null {
  let text = candidate.replace(/,\s*([}\]])/g, '$1');

  const stack: string[] = [];
  let inString = false;
  let escaped = false;
  for (let i = 0; i < text.length; i += 1) {
    const ch = text[i];
    if (inString) {
      if (escaped) escaped = false;
      else if (ch === '\\') escaped = true;
      else if (ch === '"') inString = false;
      continue;
    }
    if (ch === '"') inString = true;
    else if (ch === '{') stack.push('}');
    else if (ch === '[') stack.push(']');
    else if (ch === '}' || ch === ']') {
      if (stack[stack.length - 1] === ch) stack.pop();
      else return null; // 括号错配（多出右括号）→ 交给其它分支
    }
  }
  // 截断发生在字符串内部：闭合引号也换不回合法 JSON，直接放弃
  if (inString) return null;
  return text + stack.reverse().join('');
}

/** 从首个 { 起，按深度切出最后一个「括号平衡」的 {…} 子串（容忍尾部多余 JSON / 废话） */
function balancedSubstring(candidate: string): string | null {
  const start = candidate.indexOf('{');
  if (start === -1) return null;
  let depth = 0;
  let inString = false;
  let escaped = false;
  for (let i = start; i < candidate.length; i += 1) {
    const ch = candidate[i];
    if (inString) {
      if (escaped) escaped = false;
      else if (ch === '\\') escaped = true;
      else if (ch === '"') inString = false;
      continue;
    }
    if (ch === '"') inString = true;
    else if (ch === '{') depth += 1;
    else if (ch === '}') {
      depth -= 1;
      if (depth === 0) return candidate.slice(start, i + 1);
    }
  }
  return null;
}

/**
 * LLM 输出容错提取：直解 → 剥 code fence → 首个 { 到末个 } 截取 → 结构性闭合 → 平衡子串；失败返回 null。
 * 仅接受 plain object（数组 / 标量一律 null）。
 */
export function extractJson(text: string): Record<string, unknown> | null {
  if (typeof text !== 'string' || text.trim() === '') return null;

  // 1. 直接解析（模型开了 response_format: json_object 时的常态路径）
  try {
    const direct = JSON.parse(text);
    if (isPlainObject(direct)) return direct;
  } catch {
    // 继续走容错提取
  }

  // 2. 剥 code fence（```json ... ``` 或 ``` ... ```）
  const fence = text.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
  const candidate = fence ? fence[1] : text;

  // 3. 首个 { 到末个 } 截取（容忍前后废话）
  const start = candidate.indexOf('{');
  const end = candidate.lastIndexOf('}');
  if (start !== -1 && end > start) {
    try {
      const parsed = JSON.parse(candidate.slice(start, end + 1));
      if (isPlainObject(parsed)) return parsed;
    } catch {
      // fallthrough
    }
  }

  // 4. 结构性闭合（治截断 / 尾随逗号）
  if (start !== -1) {
    const closed = closeUnbalancedJson(candidate.slice(start));
    if (closed) {
      try {
        const parsed = JSON.parse(closed);
        if (isPlainObject(parsed)) return parsed;
      } catch {
        // fallthrough
      }
    }
  }

  // 5. 平衡子串回退（首个 { 起切出第一个深度归零的完整对象）
  const balanced = balancedSubstring(candidate);
  if (balanced) {
    try {
      const parsed = JSON.parse(balanced);
      if (isPlainObject(parsed)) return parsed;
    } catch {
      // fallthrough
    }
  }

  return null;
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `pnpm --filter @lumira/backend test -- normalize.spec`
Expected: PASS（新增 4 条 + 原有 4 条全绿；确认原用例 4「完全不是 JSON → null」仍为 null）。

- [ ] **Step 5: 提交**

```bash
git add lumira-server/packages/backend/src/modules/ai/normalize.ts lumira-server/packages/backend/src/modules/ai/normalize.spec.ts
git commit -m "feat(ai): extractJson 增加结构性闭合与平衡子串补救（治截断/尾随逗号）"
```

---

### Task 3: `llm-client` maxTokens 参数化

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/llm-client.ts`（L20-36 输入接口、L75-77 常量、L106-132 `ChatRequestBase`/`buildChatBody`、L204-259 `visionChat`/`textChat`）
- Test: `lumira-server/packages/backend/src/modules/ai/llm-client.spec.ts`

**Interfaces:**
- Consumes: 无
- Produces:
  - `VisionChatInput.maxTokens?: number`、`TextChatInput.maxTokens?: number`
  - `ChatRequestBase.maxTokens?: number`；`buildChatBody` 输出 `max_tokens = input.maxTokens ?? 8192`
  - `const MAX_TOKENS = 8192`（默认值提升）

- [ ] **Step 1: 写失败测试**

在 `llm-client.spec.ts` 追加（若无 `buildChatBody` 的 import，则在文件顶部补 `import { buildChatBody } from './llm-client';`）：

```ts
describe('buildChatBody — max_tokens 参数化', () => {
  const base = { model: 'm', messages: [], temperature: 0.3, jsonMode: false, timeoutMs: 1000 };

  it('未传 maxTokens → 默认 8192', () => {
    expect(buildChatBody(base).max_tokens).toBe(8192);
  });

  it('传 maxTokens → 原样使用', () => {
    expect(buildChatBody({ ...base, maxTokens: 2048 }).max_tokens).toBe(2048);
  });
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `pnpm --filter @lumira/backend test -- llm-client.spec`
Expected: FAIL —— 未传时为 4096；传 `maxTokens` 时仍为 4096。

- [ ] **Step 3: 实现**

`llm-client.ts`：

1) `MAX_TOKENS` 常量改为：

```ts
/** 单次输出 token 默认上限（调用方可经 maxTokens 覆盖；后台「识别稳定性」可配） */
const MAX_TOKENS = 8192;
```

2) `VisionChatInput` / `TextChatInput` 各追加一行：

```ts
  maxTokens?: number;       // 单次输出 token 上限；默认 8192
```

3) `ChatRequestBase` 追加：

```ts
  maxTokens?: number;
```

4) `buildChatBody` 中 `max_tokens: MAX_TOKENS,` 改为：

```ts
    max_tokens: input.maxTokens ?? MAX_TOKENS,
```

5) `visionChat` 与 `textChat` 内传给 `chatRequest` 的对象中，`timeoutMs: input.timeoutMs ?? DEFAULT_TIMEOUT_MS,` 之后各追加：

```ts
      maxTokens: input.maxTokens,
```

- [ ] **Step 4: 运行测试确认通过**

Run: `pnpm --filter @lumira/backend test -- llm-client.spec`
Expected: PASS（新增 2 条 + 原有全绿）。

- [ ] **Step 5: 提交**

```bash
git add lumira-server/packages/backend/src/modules/ai/llm-client.ts lumira-server/packages/backend/src/modules/ai/llm-client.spec.ts
git commit -m "feat(ai): llm-client max_tokens 参数化，默认 4096→8192"
```

---

### Task 4: 重试封装 `llm-json.ts`

**Files:**
- Create: `lumira-server/packages/backend/src/modules/ai/llm-json.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/llm-json.spec.ts`

**Interfaces:**
- Consumes: `visionChat` / `textChat`（Task 3 后的签名）、`extractJson`（Task 2 后）、`traceNote` / `currentTraceStep`（`llm-trace.ts`）
- Produces:
  - `interface LlmJsonRuntime { retryCount: number; timeoutMs: number; maxTokens: number }`
  - `interface JsonChatInput { systemPrompt: string; userText: string; temperature?: number; timeoutMs?: number; maxTokens?: number }`
  - `class LlmJsonError extends Error`
  - `visionChatJson(endpoint: LlmEndpoint, input: JsonChatInput & { imageBase64: string; imageMime: string }, runtime: LlmJsonRuntime): Promise<Record<string, unknown>>`
  - `textChatJson(endpoint: LlmEndpoint, input: JsonChatInput, runtime: LlmJsonRuntime): Promise<Record<string, unknown>>`
  - `runJsonChat(runtime: LlmJsonRuntime, callChat: (userText: string) => Promise<string>, baseUserText: string): Promise<Record<string, unknown>>`（导出供单测）

- [ ] **Step 1: 写失败测试**

创建 `llm-json.spec.ts`：

```ts
// lumira-server/packages/backend/src/modules/ai/llm-json.spec.ts
// 识别链路 JSON 重试封装（Task 4，TDD）：解析失败 / 超时 / 5xx / 空输出 → 有界重试；鉴权类错误不重试

import { LlmJsonError, runJsonChat } from './llm-json';

const RT = { retryCount: 2, timeoutMs: 300_000, maxTokens: 8192 };

describe('runJsonChat', () => {
  it('第 1 次即合法 JSON → 直接返回，不重试', async () => {
    const call = jest.fn(async () => '{"a":1}');
    await expect(runJsonChat(RT, call, 'u')).resolves.toEqual({ a: 1 });
    expect(call).toHaveBeenCalledTimes(1);
  });

  it('解析失败后重试成功 → 第 2 次返回对象，且重试请求带纠正指令', async () => {
    const call = jest.fn()
      .mockResolvedValueOnce('不是 JSON')
      .mockResolvedValueOnce('{"a":2}');
    await expect(runJsonChat(RT, call, '原始提问')).resolves.toEqual({ a: 2 });
    expect(call).toHaveBeenCalledTimes(2);
    expect(call.mock.calls[1][0]).toContain('原始提问');
    expect(call.mock.calls[1][0]).toContain('JSON');
  });

  it('超时错误后重试成功 → 共 2 次调用', async () => {
    const call = jest.fn()
      .mockRejectedValueOnce(new Error('AI 请求超时，请稍后重试'))
      .mockResolvedValueOnce('{"ok":true}');
    await expect(runJsonChat(RT, call, 'u')).resolves.toEqual({ ok: true });
    expect(call).toHaveBeenCalledTimes(2);
  });

  it('5xx 与空输出同样可重试', async () => {
    const call = jest.fn()
      .mockRejectedValueOnce(new Error('AI 上游错误（HTTP 503）'))
      .mockRejectedValueOnce(new Error('AI 服务返回内容为空'))
      .mockResolvedValueOnce('{"ok":true}');
    await expect(runJsonChat(RT, call, 'u')).resolves.toEqual({ ok: true });
    expect(call).toHaveBeenCalledTimes(3);
  });

  it('鉴权错误不重试 → 原样抛出且只调用 1 次', async () => {
    const call = jest.fn().mockRejectedValue(new Error('AI 服务认证失败（apiKey 无效或无权限/欠费），请到后台「AI 设置」检查'));
    await expect(runJsonChat(RT, call, 'u')).rejects.toThrow('认证失败');
    expect(call).toHaveBeenCalledTimes(1);
  });

  it('用尽重试仍解析失败 → 抛 LlmJsonError 且含「已重试 2 次」', async () => {
    const call = jest.fn(async () => '始终不是 JSON');
    await expect(runJsonChat(RT, call, 'u')).rejects.toBeInstanceOf(LlmJsonError);
    await expect(runJsonChat(RT, call, 'u')).rejects.toThrow('已重试 2 次');
    expect(call).toHaveBeenCalledTimes(6); // 两轮 × 3 次
  });

  it('retryCount=0 → 不重试，仅 1 次调用', async () => {
    const call = jest.fn(async () => '不是 JSON');
    await expect(runJsonChat({ ...RT, retryCount: 0 }, call, 'u')).rejects.toBeInstanceOf(LlmJsonError);
    expect(call).toHaveBeenCalledTimes(1);
  });
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `pnpm --filter @lumira/backend test -- llm-json.spec`
Expected: FAIL —— `Cannot find module './llm-json'`。

- [ ] **Step 3: 实现**

创建 `llm-json.ts`：

```ts
// lumira-server/packages/backend/src/modules/ai/llm-json.ts
// 识别链路 JSON 结构化输出的容错封装：调用 → extractJson → 按失败原因有界重试。
// 设计文档：docs/superpowers/specs/2026-09-28-ai-llm-json-resilience-design.md
//
// 重试只针对「可恢复」失败：JSON 解析失败（含截断）/ 超时 / HTTP 5xx / 空输出；
// 鉴权与请求错误（401/403/400/404）原样抛出，不做无意义重试。
// 每次尝试都会经 visionChat / textChat 落一条 llm 事件，实时过程面板因此天然可见。

import { textChat, visionChat, type LlmEndpoint } from './llm-client';
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

/** 纯文本 JSON 识别：textChat(jsonMode) → extractJson → 失败按 runtime 有界重试 */
export async function textChatJson(
  endpoint: LlmEndpoint,
  input: JsonChatInput,
  runtime: LlmJsonRuntime,
): Promise<Record<string, unknown>> {
  return runJsonChat(
    runtime,
    (userText) =>
      textChat(endpoint, {
        systemPrompt: input.systemPrompt,
        userText,
        temperature: input.temperature,
        jsonMode: true,
        timeoutMs: input.timeoutMs ?? runtime.timeoutMs,
        maxTokens: input.maxTokens ?? runtime.maxTokens,
      }),
    input.userText,
  );
}
```

> 注：`traceNote` 内部以 `topStep()` 自动归属父阶段，重试提示会挂在当前识别步骤（如 `describe`）之下。

- [ ] **Step 4: 运行测试确认通过**

Run: `pnpm --filter @lumira/backend test -- llm-json.spec`
Expected: PASS（7 条全绿）。

- [ ] **Step 5: 提交**

```bash
git add lumira-server/packages/backend/src/modules/ai/llm-json.ts lumira-server/packages/backend/src/modules/ai/llm-json.spec.ts
git commit -m "feat(ai): 新增 llm-json 重试封装（解析失败/超时/5xx/空输出有界重试）"
```

---

### Task 5: 六个识别服务接线

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/image-describe.service.ts`（L200-221）
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-analyze.service.ts`（L161-211）
- Modify: `lumira-server/packages/backend/src/modules/ai/pose-ref-sheet.service.ts`（L127-178）
- Modify: `lumira-server/packages/backend/src/modules/ai/image-score.service.ts`（L185-205）
- Modify: `lumira-server/packages/backend/src/modules/ai/draft-refine.service.ts`（L79-104）
- Test: `image-describe.service.spec.ts` / `pose-ref-sheet.service.spec.ts` / `image-score.service.spec.ts` / `draft-refine.service.spec.ts` / `ai-analyze.service.spec.ts`

**Interfaces:**
- Consumes: `visionChatJson` / `textChatJson` / `LlmJsonError`（Task 4）、`cfg.runtime`（Task 1）
- Produces: 六个服务对外签名不变（`describe` / `analyze` / `generate` / `score` / `refine`）

- [ ] **Step 1: 改 `image-describe.service.ts`**

1) import 调整：把 `import { visionChat } from './llm-client';` 改为 `import { visionChatJson } from './llm-json';`（若文件内还用了 `extractJson` 则从 import 中移除；`ImageDescription` 类型 import 不动）。

2) `describe` 方法体替换为：

```ts
  /** 穷尽式识别：visionChatJson（jsonMode + 有界重试）→ normalizeImageDescription（缺字段兜底） */
  async describe(image: { base64: string; mime: string }): Promise<ImageDescription> {
    const cfg = await this.aiConfigService.getActiveConfig();
    const json = await visionChatJson(
      cfg.vision,
      {
        systemPrompt: buildExhaustiveSystemPrompt(),
        userText: '请对这张图片做穷尽式识别：按九宫格逐格描述，并输出 JSON。',
        imageBase64: image.base64,
        imageMime: image.mime,
        temperature: 0.4,
      },
      cfg.runtime,
    );
    return normalizeImageDescription(json);
  }
```

- [ ] **Step 2: 改 `ai-analyze.service.ts`**

1) import：`visionChat, textChat` 改为从 `./llm-json` 引入 `visionChatJson, textChatJson, LlmJsonError`（若本文件其它地方仍需要 `visionChat/textChat` 则保留对应 import）。

2) L161-211 的分叉与解析段替换为：

```ts
    // 4. 按输入组合分叉：有图走视觉模型，仅文字走文本模型；两者均带 JSON 有界重试
    let json: Record<string, unknown>;
    try {
      if (image) {
        json = await traceStep(
          'analyze',
          '识图生成模板草稿',
          () =>
            visionChatJson(
              cfg.vision,
              {
                systemPrompt: buildAnalyzeSystemPrompt(categories, styleProfile, subjectCountHint),
                userText: buildAnalyzeUserPrompt({
                  textDesc: extra.textDesc?.trim() || trimmedText || undefined,
                  creationReq: extra.creationReq,
                  poseCount,
                  subjectCount,
                  researchDigest,
                  researchUnavailable,
                }),
                imageBase64: image.buffer.toString('base64'),
                imageMime: image.mimetype,
                temperature: 0.3,
              },
              cfg.runtime,
            ),
          (r) => `模型输出 ${Object.keys(r).length} 个字段`,
        );
      } else {
        json = await traceStep(
          'analyze',
          '文字构思模板草稿',
          () =>
            textChatJson(
              cfg.text,
              {
                systemPrompt: buildTextOnlySystemPrompt(categories, styleProfile, subjectCountHint),
                userText: buildTextOnlyUserPrompt({
                  textDesc: trimmedText,
                  creationReq: extra.creationReq,
                  poseCount,
                  subjectCount,
                  researchDigest,
                  researchUnavailable,
                }),
                temperature: 0.3,
              },
              cfg.runtime,
            ),
          (r) => `模型输出 ${Object.keys(r).length} 个字段`,
        );
      }
    } catch (err) {
      // 重试用尽仍无法解析 → 保持原 400 引导重试语义
      if (err instanceof LlmJsonError) {
        throw new BadRequestException('模型输出无法解析为 JSON，请重试识别');
      }
      throw err;
    }
```

3) 删除紧随其后的原「5. 容错提取 JSON」段（`const json = extractJson(content); if (!json) throw new BadRequestException(...)`），保留其后的归一化注释与 `if (styleResolve) json.styleProfile = ...`。

- [ ] **Step 3: 改 `pose-ref-sheet.service.ts`**

`generate` 方法内 L166-178 替换为：

```ts
    const json = await textChatJson(
      cfg.text,
      { systemPrompt, userText, temperature: 0.4 },
      cfg.runtime,
    );
    return normalizePoseRefSheet(json, poseCount);
```

并把 import 中 `textChat` 换为 `textChatJson`（来自 `./llm-json`），移除不再使用的 `extractJson` 导入。

- [ ] **Step 4: 改 `image-score.service.ts`**

L194-205 段替换为：

```ts
    let json: Record<string, unknown> | null = null;
    try {
      json = await textChatJson(
        endpoint,
        {
          systemPrompt: buildScoreSystemPrompt(profile),
          userText: buildScoreUserText(input),
          temperature: 0.3,
        },
        cfg.runtime,
      );
    } catch {
      // 重试用尽 → 保守回退（既有语义：不抛，交给编排再判）
      json = null;
    }
    if (!json) {
      return { score: 0, verdict: 'retry', reasons: ['评分为空'], suggests: [] };
    }
```

提示词内容与 temperature 保持原值不变。并把 import 中 `textChat` 换为 `textChatJson`（来自 `./llm-json`），移除 `extractJson` 导入。

- [ ] **Step 5: 改 `draft-refine.service.ts`**

L87-103 段替换为：

```ts
    let json: Record<string, unknown> | null = null;
    try {
      json = await textChatJson(
        endpoint,
        {
          systemPrompt: buildRefineSystemPrompt(input.styleProfile),
          userText: buildRefineUserText(input),
          temperature: 0.5,
        },
        cfg.runtime,
      );
    } catch {
      return null; // 重试用尽 → 编排层保留原稿（既有语义）
    }

    const inner = json.draft;
    if (!inner || typeof inner !== 'object' || Array.isArray(inner)) return null;
    return inner as Record<string, unknown>;
```

提示词内容与 temperature 保持原值不变。并把 import 中 `textChat` 换为 `textChatJson`（来自 `./llm-json`），移除 `extractJson` 导入。

- [ ] **Step 6: 适配五个 spec 的 mock**

对 `image-describe.service.spec.ts` / `pose-ref-sheet.service.spec.ts` / `image-score.service.spec.ts` / `draft-refine.service.spec.ts` / `ai-analyze.service.spec.ts` 逐个执行：

1. 把 `jest.mock('./llm-client', () => ({ visionChat: jest.fn() }))`（或含 `textChat` 的版本）改为：

```ts
jest.mock('./llm-json', () => ({
  visionChatJson: jest.fn(),
  textChatJson: jest.fn(),
  LlmJsonError: class LlmJsonError extends Error {},
}));
```

2. 顶部 import 与 mock 句柄同步改为：

```ts
import { textChatJson, visionChatJson } from './llm-json';

const visionChatJsonMock = visionChatJson as jest.MockedFunction<typeof visionChatJson>;
const textChatJsonMock = textChatJson as jest.MockedFunction<typeof textChatJson>;
```

3. 把原 `mockResolvedValue(JSON.stringify(某对象))` 改为 `mockResolvedValue(某对象)`（内容不变，仅从字符串改为对象）。

4. 把所有 `getActiveConfig: async () => ({ vision: VISION })` / `({ text: TEXT })` 之类的 mock 补上 runtime：

```ts
{ vision: VISION, text: TEXT, runtime: { retryCount: 0, timeoutMs: 300_000, maxTokens: 8192 } }
```

（`retryCount: 0` 保证单测不触发重试、调用次数断言稳定；缺哪个模态就补哪个。）

5. `image-describe.service.spec.ts` 中原「非法 JSON → 抛可读错误」用例：把断言改为

```ts
await expect(svc.describe({ base64: 'aGk=', mime: 'image/jpeg' })).rejects.toThrow(/无法解析为 JSON/);
```

6. `ai-analyze.service.spec.ts` 中原「无法解析 JSON → BadRequest」用例：mock 改为抛被 mock 的 `LlmJsonError` 实例，断言保持 `BadRequestException`：

```ts
import { LlmJsonError, visionChatJson, textChatJson } from './llm-json';

(visionChatJson as jest.Mock).mockRejectedValue(new LlmJsonError('AI 输出无法解析为 JSON（已重试 2 次）：输出不是合法 JSON'));
await expect(svc.analyze(/* 原入参 */)).rejects.toThrow(BadRequestException);
```

- [ ] **Step 7: 运行相关测试**

Run: `pnpm --filter @lumira/backend test -- image-describe pose-ref-sheet image-score draft-refine ai-analyze`
Expected: PASS（五个 spec 全绿）。

- [ ] **Step 8: 全量回归 + 类型检查**

Run: `pnpm --filter @lumira/backend test`
Expected: PASS（501+ 用例全绿）。

Run: `pnpm --filter @lumira/backend typecheck`
Expected: 无输出（exit 0）。

- [ ] **Step 9: 提交**

```bash
git add lumira-server/packages/backend/src/modules/ai/image-describe.service.ts lumira-server/packages/backend/src/modules/ai/ai-analyze.service.ts lumira-server/packages/backend/src/modules/ai/pose-ref-sheet.service.ts lumira-server/packages/backend/src/modules/ai/image-score.service.ts lumira-server/packages/backend/src/modules/ai/draft-refine.service.ts lumira-server/packages/backend/src/modules/ai/*.spec.ts
git commit -m "feat(ai): 全部 JSON 识别步骤接入重试封装，超时改取后台配置"
```

---

### Task 6: 后台表单「识别稳定性」+ 前端识别预算放宽

**Files:**
- Modify: `lumira-server/packages/admin/src/types/admin.ts`（`AiProviderConfigView` 约 L477、`UpdateAiConfigPayload` 约 L521）
- Modify: `lumira-server/packages/admin/src/components/ai-config-form.tsx`（`FormState` L80-96、初始 state L204-232、payload 组装 L487-488 附近、研究分区渲染 L1000-1015 附近）
- Modify: `lumira-server/packages/admin/src/lib/ai-task.ts`（L27-28、L239）

**Interfaces:**
- Consumes: 后端 `llmRetryCount` / `llmTimeoutMs` / `llmMaxTokens`（Task 1）
- Produces: 后台可编辑的三项稳定性配置；`pollAiAnalyzeTask` 默认预算 900s

- [ ] **Step 1: 补 admin 类型**

`types/admin.ts` 的 `AiProviderConfigView` 中 `maxIterations: number;` 之后追加：

```ts
  /** 识别稳定性：失败后额外重试次数（默认 2） */
  llmRetryCount: number;
  /** 识别稳定性：单次 LLM 调用超时（毫秒，默认 300000） */
  llmTimeoutMs: number;
  /** 识别稳定性：单次 LLM 输出 token 上限（默认 8192） */
  llmMaxTokens: number;
```

`UpdateAiConfigPayload` 中 `maxIterations?: number;` 之后追加：

```ts
  /** 识别稳定性：失败后额外重试次数（0~3） */
  llmRetryCount?: number;
  /** 识别稳定性：单次 LLM 调用超时（毫秒，10000~600000） */
  llmTimeoutMs?: number;
  /** 识别稳定性：单次 LLM 输出 token 上限（1024~16384） */
  llmMaxTokens?: number;
```

- [ ] **Step 2: 补表单状态与默认值**

`ai-config-form.tsx`：

1) `FormState` 中 `maxIterations: number;` 之后追加：

```ts
  // 识别稳定性（spec 2026-09-28）
  llmRetryCount: number; // 失败后额外重试次数 0~3
  llmTimeoutSeconds: number; // 单次调用超时（秒，入库时 ×1000）
  llmMaxTokens: number; // 单次输出 token 上限
```

2) `initial?.configured` 分支中 `maxIterations: initial.maxIterations,` 之后追加：

```ts
          llmRetryCount: initial.llmRetryCount,
          llmTimeoutSeconds: Math.max(1, Math.round(initial.llmTimeoutMs / 1000)),
          llmMaxTokens: initial.llmMaxTokens,
```

3) `else`（未配置）分支中 `maxIterations: 2,` 之后追加：

```ts
          llmRetryCount: 2,
          llmTimeoutSeconds: 300,
          llmMaxTokens: 8192,
```

- [ ] **Step 3: 补 payload 组装**

在 `payload.maxIterations = form.maxIterations;` 之后追加：

```ts
      payload.llmRetryCount = form.llmRetryCount;
      payload.llmTimeoutMs = Math.round(form.llmTimeoutSeconds * 1000);
      payload.llmMaxTokens = form.llmMaxTokens;
```

- [ ] **Step 4: 加 UI 分区**

在 `ai-config-form.tsx` 研究管线分区结束处（`迭代上限` 输入块所在的条件块之后）插入：

```tsx
            <div className="space-y-4 border-t pt-4">
              <div>
                <p className="text-sm font-medium">识别稳定性</p>
                <p className="text-xs text-muted-foreground">
                  识别步骤（示例图识别 / 草稿生成 / 姿势面片 / 质量评分 / 草稿细化）遇到输出非法 JSON、超时、上游 5xx 或空输出时，
                  会先做结构补救再自动重试；鉴权类错误不重试。
                </p>
              </div>
              <div className="grid gap-4 md:grid-cols-3">
                <div className="space-y-2">
                  <Label htmlFor="ai-llm-retry-count">失败重试次数</Label>
                  <Input
                    id="ai-llm-retry-count"
                    type="number"
                    min={0}
                    max={3}
                    value={form.llmRetryCount}
                    onChange={(e) => setForm((f) => ({ ...f, llmRetryCount: Number(e.target.value) }))}
                  />
                  <p className="text-xs text-muted-foreground">0~3，默认 2。总调用次数 ≤ 次数 + 1。</p>
                </div>
                <div className="space-y-2">
                  <Label htmlFor="ai-llm-timeout">单次调用超时（秒）</Label>
                  <Input
                    id="ai-llm-timeout"
                    type="number"
                    min={10}
                    max={600}
                    value={form.llmTimeoutSeconds}
                    onChange={(e) => setForm((f) => ({ ...f, llmTimeoutSeconds: Number(e.target.value) }))}
                  />
                  <p className="text-xs text-muted-foreground">10~600，默认 300（5 分钟）。含图识别建议不低于 120。</p>
                </div>
                <div className="space-y-2">
                  <Label htmlFor="ai-llm-max-tokens">单次输出上限（token）</Label>
                  <Input
                    id="ai-llm-max-tokens"
                    type="number"
                    min={1024}
                    max={16384}
                    value={form.llmMaxTokens}
                    onChange={(e) => setForm((f) => ({ ...f, llmMaxTokens: Number(e.target.value) }))}
                  />
                  <p className="text-xs text-muted-foreground">1024~16384，默认 8192。穷尽式识别输出大，过低会导致 JSON 被截断。</p>
                </div>
              </div>
            </div>
```

- [ ] **Step 5: 前端识别预算放宽**

`ai-task.ts`：`const DEFAULT_TIMEOUT_MS = 600_000;` 之后追加：

```ts
/** 识别任务总预算：链路含重试，比生图长，单独放宽（生图 / 剪影仍用 600s） */
const ANALYZE_TIMEOUT_MS = 900_000;
```

并把 `pollAiAnalyzeTask` 中的解构改为：

```ts
  const { intervalMs = DEFAULT_INTERVAL_MS, timeoutMs = ANALYZE_TIMEOUT_MS, onEvents, signal } = options;
```

- [ ] **Step 6: 验证 admin 构建**

Run: `pnpm --filter @lumira/admin build`
Expected: exit 0（无 TS 报错）。

- [ ] **Step 7: 提交**

```bash
git add lumira-server/packages/admin/src/types/admin.ts lumira-server/packages/admin/src/components/ai-config-form.tsx lumira-server/packages/admin/src/lib/ai-task.ts
git commit -m "feat(admin): AI 设置新增识别稳定性分区（重试/超时/输出上限），识别轮询预算 900s"
```

---

### Task 7: 全量验证与双远程推送

**Files:**
- Modify: `docs/future-optimizations.md`（仅当实现过程中产生了「先这样、后续再优化」项时追加；无则跳过）

**Interfaces:**
- Consumes: Task 1~6 全部产出
- Produces: 可部署的后端 + admin

- [ ] **Step 1: 后端全量测试**

Run: `pnpm --filter @lumira/backend test`
Expected: PASS，全绿无 skipped。

- [ ] **Step 2: 后端类型检查**

Run: `pnpm --filter @lumira/backend typecheck`
Expected: exit 0。

- [ ] **Step 3: admin 构建**

Run: `pnpm --filter @lumira/admin build`
Expected: exit 0。

- [ ] **Step 4: 推送双远程**

```bash
git push origin master
git push github master
```

Expected: 两个远程均成功；push 触发 `.github/workflows/backend-deploy.yml` 自动部署（改动路径含 `lumira-server/packages/backend/**` 与 `packages/admin/**`）。

- [ ] **Step 5: 部署后确认迁移生效（人工核对，无需改代码）**

在服务器执行：

```bash
docker compose -f /opt/lumira/backend/docker-compose.prod.yml exec backend sh -lc 'echo ok'
docker compose -f /opt/lumira/backend/docker-compose.prod.yml logs --tail=200 backend | grep -i migration
```

Expected: 日志出现 `047_ai_config_llm_stability.sql` 已应用；后台「AI 设置」页出现「识别稳定性」分区且三项有值（默认 2 / 300 / 8192）。

---

## 已知边界（实现时不要额外扩大范围）

- **最坏耗时**：单步 300s × (1+2) 次重试 = 900s，理论上单个步骤即可顶满前端识别预算；实测失败的代价已由前端 900s 与任务后台继续执行兜住，不在本轮引入「全局时间预算」机制。
- **不做**：不改生图 / 剪影链路的重试与超时；不为 `web-search-qwen.ts` 等非识别调用接入新封装；不引入 provider 原生 structured-output 协议。
- **失败仍降级**：质量评分 / 草稿细化 / 示例图识别在重试用尽后仍按既有语义降级，不改为抛错中断。