# AI 一键生成模板：断点续跑 + 中断原因详情 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把「AI 一键建模」的识别 → 生图 → 剪影三阶段收敛到后端一个内存 job（前端只持 `jobId`），任意阶段中断时给出分类明确的中断详情并提供「继续」按钮（优先重连、否则重跑失败阶段）；同时修复「添加参考图后识别流程报『查询识别任务失败』」——透传真因、轮询容错、响应体收敛。

**Architecture:** 后端新增 `AiPipelineJobService`（内存 `Map` + TTL/sweeper）承载输入与产物，直接复用 `AiAnalyzeService` / `AiGenerateImageService` / `AiSilhouetteService` 三个模型服务（不经过既有 task service，避免任务嵌套）；阶段产物与统一事件流由 job 持有，`GET` 端点按 `since` 增量、轻量返回（终态才给 base64 产物），从源头消除轮询响应体膨胀。前端把 `ai-task.ts` 的轮询重构为 `startPipelineJob` / `pollPipelineJob` / `resumePipelineJob`，`wizard.tsx` 两个入口（手动识别、一键全自动）共用同一 job，新增断点 banner 与「继续 / 放弃」按钮，`jobId` 存 localStorage 支持刷新恢复。

**Tech Stack:** NestJS 10 + Fastify + TypeScript（后端，jest + ts-jest）；Next.js 14 App Router + Server Actions + React 18（后台，vitest）；不涉及数据库、Flutter、`lumira-app/`。

## Global Constraints

- 设计依据：`docs/superpowers/specs/2026-09-29-ai-pipeline-resume-design.md`（§1–§9 全部适用）。
- **不改数据库表结构**；job 仅存后端内存，沿用 `RESULT_TTL_MS = 60 * 60 * 1000` / `SWEEP_INTERVAL_MS = 60 * 1000` + `sweeper.unref?.()` 模式。
- **不改 Flutter 端（`lumira_app_flutter/`）与废弃原型（`lumira-app/`）**。
- **不改既有端点行为**：`ai-analyze`、`ai-analyze/tasks/:taskId`、`ai-generate-image`、`ai-generate-image/batch`、`ai-generate-image/tasks/:taskId`、`ai-generate-silhouette`、`ai-generate-silhouette/tasks`、`ai-generate-silhouette/tasks/:taskId` 全部保持原样，供手动 Step3/Step4 复用。
- **不改既有 3 个 task service**（`AiAnalyzeTaskService` / `AiImageTaskService` / `AiSilhouetteTaskService`）的对外行为。
- 后端测试命令：`cd lumira-server/packages/backend; pnpm test`（jest，`testMatch: src/**/*.spec.ts`，与被测文件同目录）。
- 后台测试命令：`cd lumira-server/packages/admin; pnpm test`（vitest，用例放 `src/lib/__tests__/*.test.ts`，`@` 别名指向 `src`）。
- 类型检查命令：`cd lumira-server/packages/backend; pnpm build` 与 `cd lumira-server/packages/admin; pnpm build`。
- 后端/admin 每完成一个任务都要提交，并按项目规则推送到两个远程：`git push origin master`（gitee）与 `git push github master`（github）。
- 前端不硬编码颜色：admin 一律用既有 Tailwind token（`text-foreground` / `border-destructive/50` 等）。
- 后端不改动 `nanoid` 用法（`nanoid@3`，`nanoid(16)` 返回字符串）。
- 时长展示统一用 `formatSec(ms)`（已存在于 `src/lib/ai-task.ts`）。

## 与设计文档的五处实现收敛（已与需求方口头确认方向，实现时以本节为准）

1. **§9.3.D「只重识别失败的示例图」→ 收敛为「示例图逐张失败不致命」。**
   现状：`describeMany` 逐张串行，任一张抛错即整体抛错，被编排器 `wrapStep` 兜底后 → 5 张图里 1 张超时会导致**全部图片描述丢失**（这才是「添加参考图后」症状的直接放大点）。
   改为：逐张 `try/catch`，失败张跳过并在事件流标注「示例图识别跳过 #N」，其余张正常合并；**全部失败**才抛结构化 `AiUpstreamError`。重跑 analyze 阶段时重跑全部示例图（不做「按失败下标局部重识别」，避免引入跨阶段描述合并的复杂度）。
2. **§9.3.C「改 llm-trace 截断档位」→ 收敛为「在 job 序列化层截断」。**
   `llm-trace.ts` 的 `TRACE_TEXT_CAP = 50_000` 保持不变（既有端点仍依赖它）；新增的 job 端点在做响应序列化时按 `running`（更紧）与终态/verbose（放宽）分档截断，效果等价且不触碰既有热路径。
3. **§3 的 job 状态 `waiting` 不实现。**
   §3 曾设想「阶段完成、等外部推动」的 `waiting`。实际落地后不存在该状态：`analyze-only` 模式的 job 在识别完成后即 `done`（后续 Step3/Step4 由用户手动走**既有未改动**的 `ai-generate-image/batch` 与 `ai-generate-silhouette/tasks` 端点），**auto** 模式则一口气跑到 `silhouette`，中途无外部推动点。故 `JobStatus = 'running' | 'done' | 'error'`，不引入永不进入的死状态。
4. **`generate-progress-panel.tsx` 不修改。**
   文件表曾列「接受 pipeline 事件并标红失败节点」。实际不必：job 事件在后台经 `toRecogEvents` / `toPoseEvents` 转换为**既有**的 `AiTraceEvent` / `AiBatchImageTraceEvent`（含 `fail` / `error` 状态），既有 `AnalyzeTraceStream` / `PoseTraceStream` 已能渲染失败节点，改面板属多余改动。
5. **不新增 `ApiHttpError`，改在 `pipeline-task.ts` 内做文案分类。**
   文件表曾列「`api.ts` 新增 `ApiHttpError`（带 status）」。实际不必：`api.ts` 依赖 `next/headers`（server-only），客户端 `pipeline-task.ts` 无法 import 其错误类；而 server action 只把 `(e as Error).message` 透给客户端，`status` 字段到不了客户端。故保留 `api.ts` 抛错文案不变（`API_ERROR: <status> <detail>`），由 `pipeline-task.ts` 的 `classifyPipelineError` 对**本仓库自己生成**的稳定文案做分类（404→`job_missing`、413→`payload_too_large`、`无法连接后端`→`network` 等），确定且无额外抽象。富信息（错误码 + 分层详情）由后端 job 的 `error: InterruptionInfo` 权威提供。

---

## 文件结构

### 后端（`lumira-server/packages/backend/`）

| 文件 | 动作 | 职责 |
| --- | --- | --- |
| `src/modules/ai/ai-upstream-error.ts` | 新增 | 上游错误的结构化表示 + 分类归一化（`AiUpstreamError` / `classifyUpstreamError` / `isRetryableUpstream`） |
| `src/modules/ai/ai-upstream-error.spec.ts` | 新增 | 分类规则单测 |
| `src/modules/ai/llm-client.ts` | 修改 | 4 处抛错点改为抛 `AiUpstreamError`（文案不变，只加 code/status） |
| `src/modules/ai/image-describe.service.ts` | 修改 | `describe` 支持 `timeoutMs`；`describeMany` 逐张失败不致命 + 返回 `failedIndexes` |
| `src/modules/ai/ai-orchestrator.service.ts` | 修改 | 适配 `describeMany` 新返回值，把跳过的图片写入事件流 |
| `src/modules/ai/ai-pipeline-job.service.ts` | 新增 | job 模型 + 三阶段执行 + 续跑 + 序列化（本计划核心） |
| `src/modules/ai/ai-pipeline-job.service.spec.ts` | 新增 | job 单测（生命周期/序列化 + 三阶段 + 续跑） |
| `src/modules/ai/ai-templates.controller.ts` | 修改 | 新增 4 个 job 端点；`parseAiMultipart` 增补 `jobMode`/`silMode`/`silCrop`/`silEngine` 字段 |
| `src/modules/ai/ai.module.ts` | 修改 | 注册 `AiPipelineJobService` |

### 后台（`lumira-server/packages/admin/`）

| 文件 | 动作 | 职责 |
| --- | --- | --- |
| `src/types/admin.ts` | 修改 | 新增 job 相关类型（`AiPipelineStatusResult` / `AiPipelineEvent` / `AiInterruptionInfo` / `AiInterruptionCode` 等） |
| `src/lib/api.ts` | 修改 | 4 个 pipeline API（`aiPipelineStart` / `aiPipelineStatus` / `aiPipelineResume` / `aiPipelineCancel`）；抛错文案保持原样（分类见收敛 #5） |
| `src/actions/ai.ts` | 修改 | 4 个 pipeline server actions |
| `src/lib/ai-task.ts` | 修改 | 导出 `base64ToFile` 与 `formatSec`（`pipeline-task` 内部转 File、`pipeline-task`/`interruption-banner` 展示耗时） |
| `src/lib/pipeline-task.ts` | 新增 | `startPipelineJob` / `pollPipelineJob` / `resumePipelineJob` / `cancelPipelineJob` / 错误分类 / 退避重试 / 事件转换 |
| `src/lib/__tests__/pipeline-task.test.ts` | 新增 | 轮询 / 退避重试 / 错误分类 / 事件转换单测 |
| `src/lib/ai-job-storage.ts` | 新增 | localStorage 读写 `jobId`（单键，刷新恢复） |
| `src/components/ai-create/interruption-banner.tsx` | 新增 | 断点详情展示（错误码/阶段/耗时/上游原文/建议 + 继续/放弃） |
| `src/components/ai-create/wizard.tsx` | 修改 | 两入口改走 pipeline、断点 banner、继续/放弃、挂载时刷新恢复 |

---

## Task 1: 上游错误结构化模块

**Files:**
- Create: `lumira-server/packages/backend/src/modules/ai/ai-upstream-error.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/ai-upstream-error.spec.ts`

**Interfaces:**
- Consumes: 无
- Produces:
  - `type UpstreamErrorCode = 'upstream_timeout' | 'upstream_http' | 'upstream_empty' | 'network' | 'internal'`
  - `class AiUpstreamError extends Error`，字段 `code: UpstreamErrorCode`、`status?: number`、`upstream?: string`、`failedIndexes?: number[]`
  - `function isRetryableUpstream(code: UpstreamErrorCode, status?: number): boolean`
  - `interface ClassifiedUpstreamError { code: UpstreamErrorCode; message: string; status?: number; upstream?: string; failedIndexes?: number[] }`
  - `function classifyUpstreamError(err: unknown): ClassifiedUpstreamError`

- [ ] **Step 1: 写失败测试**

创建 `lumira-server/packages/backend/src/modules/ai/ai-upstream-error.spec.ts`：

```ts
// lumira-server/packages/backend/src/modules/ai/ai-upstream-error.spec.ts
import { AiUpstreamError, classifyUpstreamError, isRetryableUpstream } from './ai-upstream-error';

describe('AiUpstreamError', () => {
  it('结构化错误原样透传 code/status/upstream/failedIndexes', () => {
    const err = new AiUpstreamError('upstream_timeout', 'AI 请求超时，请稍后重试', {
      status: 504,
      upstream: 'gateway timeout',
      failedIndexes: [1],
    });
    const r = classifyUpstreamError(err);
    expect(err.code).toBe('upstream_timeout');
    expect(err.status).toBe(504);
    expect(r).toEqual({
      code: 'upstream_timeout',
      message: 'AI 请求超时，请稍后重试',
      status: 504,
      upstream: 'gateway timeout',
      failedIndexes: [1],
    });
  });

  it('既有中文文案（未结构化）按规则推断 code', () => {
    expect(classifyUpstreamError(new Error('AI 请求超时，请稍后重试')).code).toBe('upstream_timeout');
    expect(classifyUpstreamError(new Error('AI 服务无法连接，请检查 baseUrl')).code).toBe('network');
    expect(classifyUpstreamError(new Error('AI 服务返回内容为空')).code).toBe('upstream_empty');
    expect(classifyUpstreamError(new Error('生图失败：HTTP 503 Service Unavailable'))).toEqual({
      code: 'upstream_http',
      message: '生图失败：HTTP 503 Service Unavailable',
      status: 503,
      upstream: '生图失败：HTTP 503 Service Unavailable',
    });
    expect(classifyUpstreamError(new Error('AI 服务认证失败（apiKey 无效或无权限/欠费），请到后台「AI 设置」检查')).code).toBe(
      'upstream_http',
    );
    expect(classifyUpstreamError(new Error('完全看不懂的异常')).code).toBe('internal');
  });

  it('非 Error 入参不炸，返回 internal', () => {
    expect(classifyUpstreamError('字符串错误').code).toBe('internal');
    expect(classifyUpstreamError(undefined).code).toBe('internal');
  });

  it('可重试判定：超时/空响应/网络可重试；5xx 与 429 可重试，4xx 不可', () => {
    expect(isRetryableUpstream('upstream_timeout')).toBe(true);
    expect(isRetryableUpstream('upstream_empty')).toBe(true);
    expect(isRetryableUpstream('network')).toBe(true);
    expect(isRetryableUpstream('upstream_http', 503)).toBe(true);
    expect(isRetryableUpstream('upstream_http', 429)).toBe(true);
    expect(isRetryableUpstream('upstream_http', 400)).toBe(false);
    expect(isRetryableUpstream('internal')).toBe(false);
  });
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd lumira-server/packages/backend; pnpm test -- ai-upstream-error`
Expected: FAIL —— `Cannot find module './ai-upstream-error'`

- [ ] **Step 3: 实现模块**

创建 `lumira-server/packages/backend/src/modules/ai/ai-upstream-error.ts`：

```ts
// lumira-server/packages/backend/src/modules/ai/ai-upstream-error.ts
// 上游（LLM / 生图 / 剪影 / 检索）错误的统一结构化表示。
// 目的：让 job 层按 code/status/upstream 归类生成中断详情，而不是靠正则猜中文文案。

export type UpstreamErrorCode =
  | 'upstream_timeout'
  | 'upstream_http'
  | 'upstream_empty'
  | 'network'
  | 'internal';

export interface AiUpstreamErrorOptions {
  status?: number;
  /** 原始上游响应片段（截断后） */
  upstream?: string;
  /** 触发该错误的图片/姿势下标（describe、生图、剪影逐张场景） */
  failedIndexes?: number[];
  cause?: unknown;
}

export class AiUpstreamError extends Error {
  readonly code: UpstreamErrorCode;
  readonly status?: number;
  readonly upstream?: string;
  readonly failedIndexes?: number[];

  constructor(code: UpstreamErrorCode, message: string, options: AiUpstreamErrorOptions = {}) {
    super(message);
    this.name = 'AiUpstreamError';
    this.code = code;
    this.status = options.status;
    this.upstream = options.upstream;
    this.failedIndexes = options.failedIndexes;
    if (options.cause !== undefined) {
      (this as { cause?: unknown }).cause = options.cause;
    }
  }
}

/** 可重试判定（供 LLM / 生图有界重试复用）：超时、空响应、网络抖动、5xx/429 可重试 */
export function isRetryableUpstream(code: UpstreamErrorCode, status?: number): boolean {
  if (code === 'upstream_timeout' || code === 'upstream_empty' || code === 'network') return true;
  if (code === 'upstream_http') return status === undefined || status === 429 || status >= 500;
  return false;
}

export interface ClassifiedUpstreamError {
  code: UpstreamErrorCode;
  message: string;
  status?: number;
  upstream?: string;
  failedIndexes?: number[];
}

/** 从既有中文文案推断 code（兼容尚未改造成结构化错误的调用方） */
function inferFromMessage(message: string): { code: UpstreamErrorCode; status?: number } {
  const httpMatch = /HTTP\s+(\d{3})/.exec(message);
  if (httpMatch) return { code: 'upstream_http', status: Number(httpMatch[1]) };
  if (/认证失败/.test(message)) return { code: 'upstream_http', status: 401 };
  if (/超时|Timeout|timeout/.test(message)) return { code: 'upstream_timeout' };
  if (/无法连接|连接失败|ECONN|fetch failed/.test(message)) return { code: 'network' };
  if (/返回内容为空|内容为空|EMPTY/.test(message)) return { code: 'upstream_empty' };
  return { code: 'internal' };
}

/** 归一化任意异常 → 可直接写入 InterruptionInfo 的结构 */
export function classifyUpstreamError(err: unknown): ClassifiedUpstreamError {
  if (err instanceof AiUpstreamError) {
    return {
      code: err.code,
      message: err.message,
      status: err.status,
      upstream: err.upstream,
      failedIndexes: err.failedIndexes,
    };
  }
  const message = (err as Error)?.message || String(err) || '未知错误';
  const inferred = inferFromMessage(message);
  return { code: inferred.code, message, status: inferred.status, upstream: message };
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `cd lumira-server/packages/backend; pnpm test -- ai-upstream-error`
Expected: PASS（4 个用例全绿）

- [ ] **Step 5: 提交**

```bash
git add lumira-server/packages/backend/src/modules/ai/ai-upstream-error.ts lumira-server/packages/backend/src/modules/ai/ai-upstream-error.spec.ts
git commit -m "feat(ai): add structured upstream error classification for pipeline jobs"
git push origin master
git push github master
```

---

## Task 2: llm-client 抛结构化错误（文案保持不变）

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/llm-client.ts`（`mapNetworkError` L82-89、401/403 L183-185、`!res.ok` L186、空内容 L211）
- Test: 复用既有 `lumira-server/packages/backend/src/modules/ai/llm-client.spec.ts`（不得改其断言）

**Interfaces:**
- Consumes: Task 1 的 `AiUpstreamError`
- Produces: `llm-client` 在网络/HTTP/空响应场景抛出的错误 `instanceof AiUpstreamError`，`message` 与改动前逐字一致（既有断言与前端文案不变）

- [ ] **Step 1: 先跑既有测试确认当前基线为绿**

Run: `cd lumira-server/packages/backend; pnpm test -- llm-client`
Expected: PASS（记录当前通过数，改完必须保持一致）

- [ ] **Step 2: 加 import**

在 `llm-client.ts` 顶部（`import { traceLlmCall } from './llm-trace';` 之后）插入：

```ts
import { AiUpstreamError } from './ai-upstream-error';
```

- [ ] **Step 3: 改造 4 处抛错点**

把 `mapNetworkError` 改为：

```ts
/** 网络层错误 → 运营可读 message：AbortError/TimeoutError 视为超时，其余视为连接失败 */
function mapNetworkError(err: unknown): never {
  const name = (err as { name?: string } | null | undefined)?.name;
  if (name === 'AbortError' || name === 'TimeoutError') {
    throw new AiUpstreamError('upstream_timeout', 'AI 请求超时，请稍后重试', { cause: err });
  }
  throw new AiUpstreamError('network', 'AI 服务无法连接，请检查 baseUrl', { cause: err });
}
```

401/403 分支改为：

```ts
  if (res.status === 401 || res.status === 403) {
    throw new AiUpstreamError(
      'upstream_http',
      'AI 服务认证失败（apiKey 无效或无权限/欠费），请到后台「AI 设置」检查',
      { status: res.status },
    );
  }
```

`!res.ok` 分支改为（注意 `upstreamError(res)` 会消费响应体，只读一次）：

```ts
  if (!res.ok) {
    const msg = await upstreamError(res);
    throw new AiUpstreamError('upstream_http', msg, { status: res.status, upstream: msg });
  }
```

`chatRequest` 的空内容分支改为：

```ts
  if (typeof content !== 'string' || !content) {
    throw new AiUpstreamError('upstream_empty', 'AI 服务返回内容为空');
  }
```

- [ ] **Step 4: 跑测试与类型检查**

Run: `cd lumira-server/packages/backend; pnpm test -- llm-client`
Expected: PASS（与 Step 1 数量一致；若有断言 `rejects.toThrow('AI 请求超时，请稍后重试')` 仍成立，因为 message 未变）

Run: `cd lumira-server/packages/backend; pnpm build`
Expected: 无 TS 错误

- [ ] **Step 5: 提交**

```bash
git add lumira-server/packages/backend/src/modules/ai/llm-client.ts
git commit -m "refactor(ai): throw AiUpstreamError from llm-client without changing messages"
git push origin master
git push github master
```

---

## Task 3: 示例图逐张失败不致命（修复「添加参考图」症状的直接放大点）

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/image-describe.service.ts`（`describe` L204-218、`describeMany` L220-228）
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-orchestrator.service.ts`（describe 调用处 L173-191 区域）
- Test: `lumira-server/packages/backend/src/modules/ai/image-describe.service.spec.ts`（追加用例）

**Interfaces:**
- Consumes: Task 1 的 `AiUpstreamError` / `classifyUpstreamError`
- Produces:
  - `describe(image: { base64: string; mime: string }, timeoutMs?: number): Promise<ImageDescription>`
  - `describeMany(images, options?: { timeoutMs?: number; onImageFailure?: (index: number, err: unknown) => void }): Promise<{ description: ImageDescription; failedIndexes: number[] }>`
  - 编排器 `describe` 步骤在事件流中新增「示例图识别跳过 #N」note 事件

- [ ] **Step 1: 写失败测试**

在 `image-describe.service.spec.ts` 末尾追加（文件顶部若无 `AiUpstreamError` 引入则一并加上）：

```ts
import { AiUpstreamError } from './ai-upstream-error';
```

```ts
describe('ImageDescribeService.describeMany（逐张失败不致命）', () => {
  it('部分图片失败：返回成功图片的合并描述 + failedIndexes，并回调失败下标', async () => {
    const service = new ImageDescribeService({} as never);
    const calls: number[] = [];
    const failures: number[] = [];
    jest
      .spyOn(service, 'describe')
      .mockImplementation(async (_img, _timeout, ) => {
        const n = calls.length;
        calls.push(n);
        if (n === 1) throw new Error('AI 请求超时，请稍后重试');
        return { global: { subject: `s${n}` } } as never;
      });

    const r = await service.describeMany(
      [
        { base64: 'a', mime: 'image/png' },
        { base64: 'b', mime: 'image/png' },
        { base64: 'c', mime: 'image/png' },
      ],
      { onImageFailure: (i) => failures.push(i) },
    );

    expect(r.failedIndexes).toEqual([1]);
    expect(failures).toEqual([1]);
    expect(r.description.people).toEqual([]);
  });

  it('全部图片失败：抛 AiUpstreamError，带全部失败下标', async () => {
    const service = new ImageDescribeService({} as never);
    jest.spyOn(service, 'describe').mockRejectedValue(new Error('AI 请求超时，请稍后重试'));

    await expect(
      service.describeMany([
        { base64: 'a', mime: 'image/png' },
        { base64: 'b', mime: 'image/png' },
      ]),
    ).rejects.toMatchObject({ name: 'AiUpstreamError', code: 'upstream_timeout', failedIndexes: [0, 1] });
  });
});
```

> 注：`ImageDescribeService` 构造函数只依赖 `AiConfigService`；测试里被 mock 掉的 `describe` 不会真正读取配置，因此传 `{}` 即可。

- [ ] **Step 2: 运行测试确认失败**

Run: `cd lumira-server/packages/backend; pnpm test -- image-describe`
Expected: FAIL —— `describeMany` 目前返回 `ImageDescription`（无 `failedIndexes`），且部分失败会整体抛错

- [ ] **Step 3: 实现**

在 `image-describe.service.ts` 顶部加 import：

```ts
import { AiUpstreamError, classifyUpstreamError } from './ai-upstream-error';
```

`describe` 增加可选 `timeoutMs`：

```ts
  /** 穷尽式识别：visionChatJson（jsonMode + 有界重试）→ normalizeImageDescription（缺字段兜底） */
  async describe(image: { base64: string; mime: string }, timeoutMs?: number): Promise<ImageDescription> {
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
      timeoutMs ? { ...cfg.runtime, timeoutMs } : cfg.runtime,
    );
    return normalizeImageDescription(json);
  }
```

`describeMany` 改为：

```ts
  /**
   * 多图穷尽识别：用户上传多张参考图时逐张识别后合并为一份描述。
   * 逐张失败不致命（单张超时/上游报错时跳过该张，其余正常合并并在事件流标注），
   * 全部失败才抛 AiUpstreamError（带全部失败下标）。
   */
  async describeMany(
    images: { base64: string; mime: string }[],
    options: { timeoutMs?: number; onImageFailure?: (index: number, err: unknown) => void } = {},
  ): Promise<{ description: ImageDescription; failedIndexes: number[] }> {
    const done: ImageDescription[] = [];
    const failedIndexes: number[] = [];
    let firstError: unknown;
    for (let i = 0; i < images.length; i += 1) {
      try {
        done.push(await this.describe(images[i]!, options.timeoutMs));
      } catch (err) {
        if (firstError === undefined) firstError = err;
        failedIndexes.push(i);
        options.onImageFailure?.(i, err);
      }
    }
    if (done.length === 0) {
      const classified = classifyUpstreamError(firstError);
      throw new AiUpstreamError(
        classified.code === 'internal' ? 'upstream_timeout' : classified.code,
        `示例图识别全部失败（共 ${images.length} 张）：${classified.message}`,
        { status: classified.status, upstream: classified.upstream, failedIndexes },
      );
    }
    return { description: mergeImageDescriptions(done), failedIndexes };
  }
```

- [ ] **Step 4: 适配编排器**

在 `ai-orchestrator.service.ts` 中，把 describe 调用处（`wrapStep<ImageDescription>('describe', 'image-describe', trace, () => this.imageDescribe.describeMany(...))`）改为消费新返回值：

```ts
    let desc: ImageDescription | undefined;
    if (input.images?.length) {
      desc = await this.wrapStep<{ description: ImageDescription; failedIndexes: number[] }>(
        'describe',
        'image-describe',
        trace,
        () =>
          this.imageDescribe.describeMany(input.images as { base64: string; mime: string }[], {
            onImageFailure: (index, err) => {
              traceNote(
                'describe',
                `示例图识别跳过 #${index + 1}`,
                (err as Error)?.message || '该张识别失败',
              );
            },
          }),
      ).then((r) => {
        if (r.failedIndexes.length) {
          traceNote(
            'describe',
            '示例图识别部分跳过',
            `${r.failedIndexes.length} 张失败（#${r.failedIndexes.map((i) => i + 1).join('、')}），已用其余图片继续`,
          );
        }
        return r.description;
      });
    } else {
      trace.push({ step: 'describe', resultBrief: 'skip-describe（无图）' });
    }
```

> 若 `wrapStep` 的 `brief` 形参已传，保持原 `brief` 不变；`traceNote` 已在该文件 import（`import { traceNote, traceStep } from './llm-trace';`）。

- [ ] **Step 5: 跑测试与类型检查**

Run: `cd lumira-server/packages/backend; pnpm test -- image-describe`
Expected: PASS

Run: `cd lumira-server/packages/backend; pnpm test -- ai-orchestrator`
Expected: PASS（既有编排器用例不受影响）

Run: `cd lumira-server/packages/backend; pnpm build`
Expected: 无 TS 错误

- [ ] **Step 6: 提交**

```bash
git add lumira-server/packages/backend/src/modules/ai/image-describe.service.ts lumira-server/packages/backend/src/modules/ai/image-describe.service.spec.ts lumira-server/packages/backend/src/modules/ai/ai-orchestrator.service.ts
git commit -m "fix(ai): keep image describe partial results when one reference image times out"
git push origin master
git push github master
```

---

## Task 4: `AiPipelineJobService` 实现（核心）

**Files:**
- Create: `lumira-server/packages/backend/src/modules/ai/ai-pipeline-job.service.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/ai-pipeline-job.service.spec.ts`（本任务只写生命周期与序列化用例；三阶段与续跑用例见 Task 5）

**Interfaces:**
- Consumes: Task 1 的 `AiUpstreamError` / `classifyUpstreamError` / `isRetryableUpstream`；既有 `AiAnalyzeService.analyze` / `AiGenerateImageService.generate + acquireImageSlot + releaseImageSlot` / `AiSilhouetteService.generate`；`llm-trace` 的 `runWithTrace` / `traceNote` / `TraceSink`
- Produces（供 Task 5/6 与控制器使用）：
  - `type PipelineStage = 'analyze' | 'image' | 'silhouette'`
  - `type StageStatus = 'pending' | 'running' | 'done' | 'error'`
  - `type JobStatus = 'running' | 'done' | 'error'`；`type JobMode = 'auto' | 'analyze-only'`
  - `type InterruptionCode`（含 `job_missing` / `upstream_timeout` / `upstream_http` / `upstream_empty` / `poll_timeout` / `network` / `payload_too_large` / `aborted` / `invalid_input` / `internal`）
  - `interface InterruptionInfo` / `interface StageState` / `interface AiPipelineEvent extends AiTraceEvent { stage; index?; prompt? }`
  - `interface AiPipelineJob` / `interface PipelineCreateInput` / `interface PipelinePoseFile` / `interface PipelineStageFailure`
  - `class AiPipelineJobService`：`create(input)` / `get(jobId)` / `remove(jobId)` / `resume(jobId)` / `serialize(job, since?, verbose?)`

- [ ] **Step 1: 写失败测试（生命周期与序列化）**

创建 `lumira-server/packages/backend/src/modules/ai/ai-pipeline-job.service.spec.ts`：

```ts
// lumira-server/packages/backend/src/modules/ai/ai-pipeline-job.service.spec.ts
// job 生命周期与序列化单测：create 快速失败 / get+remove / running 态响应收敛 / since 增量。
// 三阶段与续跑用例见 Task 5 追加。
import { BadRequestException } from '@nestjs/common';
import { AiPipelineJobService } from './ai-pipeline-job.service';
import { AiAnalyzeService } from './ai-analyze.service';
import { AiGenerateImageService } from './ai-generate-image.service';
import { AiSilhouetteService } from './ai-generate-silhouette.service';

const ANALYZE_RESULT = { draft: { title: '草稿' }, warnings: [], trace: [], raw: {}, research: [] };

describe('AiPipelineJobService（生命周期与序列化）', () => {
  let service: AiPipelineJobService;
  let analyzeMock: jest.Mock;
  let generateMock: jest.Mock;
  let silhouetteMock: jest.Mock;

  beforeEach(() => {
    analyzeMock = jest.fn().mockResolvedValue(ANALYZE_RESULT);
    generateMock = jest.fn().mockResolvedValue({ base64: 'aW1n', mimeType: 'image/png', prompt: 'p', model: 'm' });
    silhouetteMock = jest.fn().mockResolvedValue({ image: 'c2ls', mimeType: 'image/png' });
    service = new AiPipelineJobService(
      { analyze: analyzeMock } as unknown as AiAnalyzeService,
      {
        acquireImageSlot: jest.fn().mockResolvedValue(0),
        releaseImageSlot: jest.fn(),
        generate: generateMock,
      } as unknown as AiGenerateImageService,
      { generate: silhouetteMock } as unknown as AiSilhouetteService,
    );
  });

  afterEach(() => {
    service.onModuleDestroy();
    jest.restoreAllMocks();
  });

  async function waitStatus(jobId: string, status: string): Promise<void> {
    for (let i = 0; i < 6000; i += 1) {
      if (service.get(jobId)?.status === status) return;
      await new Promise((r) => setTimeout(r, 2));
    }
    throw new Error(`timed out waiting for job status ${status}`);
  }

  it('create 快速失败：示例图与文字都缺 → 400，且不建 job、不调识别服务', async () => {
    await expect(service.create({ mode: 'auto' })).rejects.toThrow(BadRequestException);
    await expect(service.create({ mode: 'auto', text: '   ' })).rejects.toThrow(BadRequestException);
    expect(analyzeMock).not.toHaveBeenCalled();
  });

  it('get / remove：不存在返回 null；remove 后不可见', async () => {
    analyzeMock.mockImplementation(() => new Promise(() => undefined));
    const { jobId } = await service.create({ text: '文字', mode: 'analyze-only' });
    expect(service.get(jobId)?.id).toBe(jobId);
    service.remove(jobId);
    expect(service.get(jobId)).toBeNull();
    expect(service.get('job_nope')).toBeNull();
  });

  it('serialize：running 态收敛（丢弃 rawResponse、截断长文本、不返回 base64 产物）', async () => {
    analyzeMock.mockImplementation(
      () => new Promise((resolve) => { setTimeout(() => resolve(ANALYZE_RESULT), 40); }),
    );
    const { jobId } = await service.create({ text: '文字', mode: 'analyze-only' });
    const job = service.get(jobId)!;
    job.events.push({
      seq: 9999, ts: Date.now(), stage: 'analyze', type: 'llm', step: 'analyze', title: '调用模型',
      status: 'running', response: 'a'.repeat(5000), rawResponse: 'b'.repeat(5000),
    });
    job.artifacts.poseFiles = [{ index: 0, base64: 'AAA', mimeType: 'image/png' }];

    const running = service.serialize(job, 0, false);
    expect(running.status).toBe('running');
    const llm = running.events.find((e) => e.type === 'llm')!;
    expect(llm.rawResponse).toBeUndefined();
    expect(llm.response!.length).toBeLessThan(5000);
    expect(running.poseImages).toEqual([]);
    expect(running.draft).toBeNull();

    await waitStatus(jobId, 'done');
    const done = service.serialize(service.get(jobId)!, 0, false);
    expect(done.poseImages).toHaveLength(1);
    expect(done.draft).toEqual({ title: '草稿' });
  });

  it('serialize：since 只返回增量事件；lastSeq 为最大 seq', async () => {
    const { jobId } = await service.create({ text: '文字', mode: 'analyze-only' });
    await waitStatus(jobId, 'done');
    const job = service.get(jobId)!;
    const all = service.serialize(job, 0, false);
    expect(all.events.length).toBeGreaterThan(0);
    expect(all.lastSeq).toBe(job.events[job.events.length - 1]!.seq);

    const since = all.lastSeq - 1;
    const incremental = service.serialize(job, since, false);
    expect(incremental.events.length).toBe(1);
    expect(incremental.events[0]!.seq).toBe(all.lastSeq);
  });
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd lumira-server/packages/backend; pnpm test -- ai-pipeline-job`
Expected: FAIL —— `Cannot find module './ai-pipeline-job.service'`

- [ ] **Step 3: 实现服务**

创建 `lumira-server/packages/backend/src/modules/ai/ai-pipeline-job.service.ts`：

```ts
// lumira-server/packages/backend/src/modules/ai/ai-pipeline-job.service.ts
// AI 一键建模流水线 job（识别 → 批量姿势图 → 剪影）：
// 把三阶段的输入与产物收在一个内存 job 里，前端只持 jobId；
// 任意阶段中断时保留已完成阶段的产物与统一事件流，支持「继续」（重连 / 重跑失败阶段）。
// 直接复用 AiAnalyzeService / AiGenerateImageService / AiSilhouetteService，
// 不经过既有 3 个 task service（避免任务嵌套与跨服务状态同步）。

import { BadRequestException, Injectable, OnModuleDestroy } from '@nestjs/common';
import { nanoid } from 'nanoid';
import { UploadFile } from '../templates/admin-templates.service';
import { AiAnalyzeService } from './ai-analyze.service';
import type { AiAnalyzeResult } from './ai-analyze.service';
import { AiGenerateImageService } from './ai-generate-image.service';
import { AiSilhouetteService } from './ai-generate-silhouette.service';
import { AiUpstreamError, classifyUpstreamError, isRetryableUpstream } from './ai-upstream-error';
import { runWithTrace, traceNote } from './llm-trace';
import type { AiTraceEvent, TraceSink } from './llm-trace';

export type PipelineStage = 'analyze' | 'image' | 'silhouette';
export type StageStatus = 'pending' | 'running' | 'done' | 'error';
export type JobStatus = 'running' | 'done' | 'error';
export type JobMode = 'auto' | 'analyze-only';

/** 中断分类错误码（前端据此选文案与建议，不再靠中文正则猜） */
export type InterruptionCode =
  | 'job_missing'
  | 'upstream_timeout'
  | 'upstream_http'
  | 'upstream_empty'
  | 'poll_timeout'
  | 'network'
  | 'payload_too_large'
  | 'aborted'
  | 'invalid_input'
  | 'internal';

/** 一次中断的分层详情：错误码 + 阶段 + 上游原文 + 耗时 + 失败下标 + 处置建议 */
export interface InterruptionInfo {
  code: InterruptionCode;
  stage: PipelineStage;
  /** 运营可读的粗粒度原因（保留上游原文中的关键信息） */
  message: string;
  /** 上游原始响应/异常文案（截断后） */
  upstream?: string;
  /** 上游 HTTP 状态码 */
  status?: number;
  /** 该阶段已耗时（ms） */
  elapsedMs?: number;
  /** 失败下标（示例图/姿势图/剪影，0-based） */
  failedIndexes?: number[];
  /** 处置建议 */
  hint?: string;
  at: number;
}

export interface StageState {
  status: StageStatus;
  startedAt?: number;
  finishedAt?: number;
  error?: InterruptionInfo;
}

/** 统一事件流事件：在既有 AiTraceEvent 之上补 stage / index / prompt（前端据此分流到两个 Tab） */
export interface AiPipelineEvent extends AiTraceEvent {
  stage: PipelineStage;
  /** 姿势图 / 剪影下标（0-based） */
  index?: number;
  /** 姿势图完成后的最终生图提示词 */
  prompt?: string;
}

export interface PipelinePoseFile {
  index: number;
  base64: string;
  mimeType: string;
}

export interface PipelineStageFailure {
  index: number;
  error: string;
}

export interface AiPipelineJob {
  id: string;
  createdAt: number;
  status: JobStatus;
  mode: JobMode;
  inputs: {
    images?: UploadFile[];
    text?: string;
    extra: {
      textDesc?: string | null;
      creationReq?: string | null;
      poseCount?: string | null;
      subjectCount?: string | null;
    };
    references?: UploadFile[];
    extraPrompt?: string | null;
    silhouette: { mode: 'sketch' | 'solid'; crop: boolean; engine: 'ai' | 'local' };
  };
  stages: Record<PipelineStage, StageState>;
  events: AiPipelineEvent[];
  error?: InterruptionInfo;
  artifacts: {
    analyze?: AiAnalyzeResult;
    poseFiles: PipelinePoseFile[];
    poseErrors: PipelineStageFailure[];
    silFiles: PipelinePoseFile[];
    silErrors: PipelineStageFailure[];
  };
}

export interface PipelineCreateInput {
  images?: UploadFile[];
  text?: string;
  extra?: {
    textDesc?: string | null;
    creationReq?: string | null;
    poseCount?: string | null;
    subjectCount?: string | null;
  };
  references?: UploadFile[];
  extraPrompt?: string | null;
  mode: JobMode;
  silhouette?: { mode: 'sketch' | 'solid'; crop: boolean; engine: 'ai' | 'local' };
}

/** 已完成/错误 job 保留时长（对齐既有 task service：60 分钟，覆盖前端 60 分钟轮询预算） */
const RESULT_TTL_MS = 60 * 60 * 1000;
const SWEEP_INTERVAL_MS = 60 * 1000;
/** 单 job 事件上限（超出静默丢弃，兜住异常长流程的内存占用） */
const MAX_JOB_EVENTS = 1200;
/** running 态序列化时单个文本字段上限（终态 / verbose 沿用 llm-trace 的 50k 上限） */
const COMPACT_TEXT_CAP = 2000;
/** 单张姿势图生图重试上限（与既有 AiImageTaskService 一致） */
const GENERATE_RETRY_LIMIT = 4;

const STAGE_TITLES: Record<PipelineStage, string> = {
  analyze: '示例图识别',
  image: '封面姿势图生成',
  silhouette: '剪影生成',
};

const HINTS: Record<InterruptionCode, string> = {
  job_missing: '任务已失效（后端重启或超过 1 小时保留期被清理），请重新开始',
  upstream_timeout: '上游模型响应超时；可在「AI 设置 → 识别稳定性」调大单次 LLM 超时后点「继续」重试',
  upstream_http: '上游返回错误状态；请检查「AI 设置」中的模型与 apiKey（含权限/额度）',
  upstream_empty: '上游返回空内容（多为瞬时故障）；点「继续」重试该阶段',
  poll_timeout: '前端等待超时但后端可能仍在运行；点「继续」重连接着等',
  network: '网络中断或后端不可达；恢复后点「继续」重连',
  payload_too_large: '上传内容过大被网关拒绝；请压缩示例图（建议 ≤3MB/张）后重新开始',
  aborted: '已手动中止；点「继续」可从当前阶段续跑',
  invalid_input: '输入不合法；请按提示修正后重新开始',
  internal: '未归类异常；详情见上方事件流，可点「继续」重试该阶段',
};

/** running 态事件收敛：长文本截断 + 丢弃原始响应体（终态会重新全量返回） */
function capEvent(e: AiPipelineEvent): AiPipelineEvent {
  const cut = (s?: string): string | undefined =>
    typeof s === 'string' && s.length > COMPACT_TEXT_CAP
      ? `${s.slice(0, COMPACT_TEXT_CAP)}…（已截断，原长 ${s.length} 字）`
      : s;
  return {
    ...e,
    systemPrompt: cut(e.systemPrompt),
    userPrompt: cut(e.userPrompt),
    response: cut(e.response),
    rawResponse: undefined,
  };
}

@Injectable()
export class AiPipelineJobService implements OnModuleDestroy {
  private readonly jobs = new Map<string, AiPipelineJob>();
  private readonly sweeper: NodeJS.Timeout;

  constructor(
    private readonly aiAnalyzeService: AiAnalyzeService,
    private readonly aiGenerateImageService: AiGenerateImageService,
    private readonly aiSilhouetteService: AiSilhouetteService,
  ) {
    this.sweeper = setInterval(() => this.sweep(), SWEEP_INTERVAL_MS);
    // unref：不因清理定时器阻止进程退出（测试友好）
    this.sweeper.unref?.();
  }

  /** 惰性清理过期 job（含产物，防 base64 占用内存） */
  private sweep(): void {
    const now = Date.now();
    for (const [id, job] of this.jobs) {
      if (now - job.createdAt > RESULT_TTL_MS) this.jobs.delete(id);
    }
  }

  private emptyStages(): Record<PipelineStage, StageState> {
    return {
      analyze: { status: 'pending' },
      image: { status: 'pending' },
      silhouette: { status: 'pending' },
    };
  }

  /** 追加一条事件（分配 seq/ts；达上限静默丢弃） */
  private append(job: AiPipelineJob, ev: Omit<AiPipelineEvent, 'seq' | 'ts'>): void {
    if (job.events.length >= MAX_JOB_EVENTS) return;
    job.events.push({ ...ev, seq: job.events.length + 1, ts: Date.now() });
  }

  /**
   * 创建 job：先快速失败（示例图与文字都缺 → 400），登记 job 后后台跑流水线并立即返回 jobId。
   * 其余输入合法性（图片格式/大小、poseCount 范围、文字长度）在识别阶段由 AiAnalyzeService 校验，
   * 失败会以 invalid_input 中断详情的形式暴露，不会让前端空等。
   */
  async create(input: PipelineCreateInput): Promise<{ jobId: string }> {
    const text = (input.text ?? '').trim();
    if (!input.images?.length && !text) {
      throw new BadRequestException('请至少提供示例图或文字描述之一');
    }
    const mode: JobMode = input.mode === 'analyze-only' ? 'analyze-only' : 'auto';
    const job: AiPipelineJob = {
      id: `job_${nanoid(16)}`,
      createdAt: Date.now(),
      status: 'running',
      mode,
      inputs: {
        images: input.images,
        text: text || undefined,
        extra: input.extra ?? {},
        references: input.references,
        extraPrompt: input.extraPrompt ?? null,
        silhouette: input.silhouette ?? { mode: 'sketch', crop: true, engine: 'local' },
      },
      stages: this.emptyStages(),
      events: [],
      artifacts: { poseFiles: [], poseErrors: [], silFiles: [], silErrors: [] },
    };
    this.jobs.set(job.id, job);
    void this.runPipeline(job, {
      stages: mode === 'analyze-only' ? ['analyze'] : ['analyze', 'image', 'silhouette'],
    });
    return { jobId: job.id };
  }

  /**
   * 顺序执行指定阶段；任一阶段失败即写入分层中断详情并停在 error（已完成阶段与产物保留，供续跑）。
   * 已处于 done 的阶段跳过（续跑时复用上游成果）。
   */
  private async runPipeline(
    job: AiPipelineJob,
    opts: { stages: PipelineStage[]; onlyIndexes?: Partial<Record<PipelineStage, number[]>> },
  ): Promise<void> {
    job.status = 'running';
    for (const stage of opts.stages) {
      const state = job.stages[stage];
      if (state.status === 'done') continue;
      state.status = 'running';
      state.startedAt = Date.now();
      state.error = undefined;
      try {
        const onlyIndexes = opts.onlyIndexes?.[stage];
        if (stage === 'analyze') await this.runAnalyzeStage(job);
        else if (stage === 'image') await this.runImageStage(job, onlyIndexes);
        else await this.runSilhouetteStage(job, onlyIndexes);
        state.status = 'done';
        state.finishedAt = Date.now();
      } catch (err) {
        const info = this.buildInterruption(job, stage, err);
        state.status = 'error';
        state.finishedAt = Date.now();
        state.error = info;
        job.status = 'error';
        job.error = info;
        this.append(job, {
          stage,
          type: 'note',
          step: stage,
          title: `${STAGE_TITLES[stage]}中断`,
          status: 'fail',
          error: info.message,
          resultBrief: info.hint,
        });
        return;
      }
    }
    job.status = 'done';
    job.error = undefined;
    const lastStage = opts.stages[opts.stages.length - 1] ?? 'analyze';
    this.append(job, {
      stage: lastStage,
      type: 'note',
      step: 'pipeline',
      title: '流水线完成',
      status: 'done',
      resultBrief: '产物已就绪，可进入下一步',
    });
  }

  /** 把任意异常归一化为分层中断详情（BadRequestException → invalid_input） */
  private buildInterruption(job: AiPipelineJob, stage: PipelineStage, err: unknown): InterruptionInfo {
    const startedAt = job.stages[stage].startedAt;
    if (err instanceof BadRequestException) {
      return {
        code: 'invalid_input',
        stage,
        message: err.message,
        hint: HINTS.invalid_input,
        at: Date.now(),
      };
    }
    const c = classifyUpstreamError(err);
    const code: InterruptionCode =
      c.code === 'upstream_timeout' || c.code === 'upstream_http' || c.code === 'upstream_empty' || c.code === 'network'
        ? c.code
        : 'internal';
    return {
      code,
      stage,
      message: c.message,
      upstream: c.upstream,
      status: c.status,
      failedIndexes: c.failedIndexes,
      elapsedMs: startedAt ? Date.now() - startedAt : undefined,
      hint: HINTS[code],
      at: Date.now(),
    };
  }

  // ===== 阶段执行 =====

  /** ① 识别：跑在 trace 采集上下文内，事件统一落 stage='analyze' */
  private async runAnalyzeStage(job: AiPipelineJob): Promise<void> {
    const sink: TraceSink = (ev) => this.append(job, { ...ev, stage: 'analyze' });
    const result = await runWithTrace(sink, async () => {
      traceNote(
        'task',
        '任务已提交',
        `输入：${job.inputs.images?.length ? `${job.inputs.images.length} 张示例图` : '无图'}${
          job.inputs.text ? ' + 文字描述' : ''
        }`,
      );
      return this.aiAnalyzeService.analyze(job.inputs.images, job.inputs.text, job.inputs.extra);
    });
    job.artifacts.analyze = result;
    this.append(job, {
      stage: 'analyze',
      type: 'note',
      step: 'task',
      title: '识别完成',
      status: 'done',
      resultBrief: '草稿已生成，可进入下一步',
    });
  }

  /** 草稿 → 姿势目标列表（与 AiImageTaskService.submitBatch 同口径） */
  private targetsFor(draft: Record<string, unknown> | undefined): Array<Record<string, unknown> | undefined> {
    const rawPose = draft?.pose;
    const poses = Array.isArray(rawPose)
      ? rawPose.filter(
          (pose): pose is Record<string, unknown> => typeof pose === 'object' && pose !== null && !Array.isArray(pose),
        )
      : rawPose && typeof rawPose === 'object' && !Array.isArray(rawPose)
        ? [rawPose as Record<string, unknown>]
        : [];
    return poses.length > 0 ? poses : [undefined];
  }

  /** 识别阶段研究结果 → 生图阶段 research JSON（与既有前端口径一致：{ items, brief, vision }） */
  private buildResearchJson(job: AiPipelineJob): string | null {
    const a = job.artifacts.analyze;
    if (!a) return null;
    const items = a.research ?? [];
    const brief = a.brief ?? null;
    const vision = a.researchVision ?? null;
    if (!items.length && !brief && !vision) return null;
    return JSON.stringify({ items, brief, vision });
  }

  /** 生图有界重试：仅对可重试分类重试（超时/空响应/网络/5xx/429） */
  private async generateWithRetry(
    references: UploadFile[] | undefined,
    metaJson: string,
    extraPrompt: string | null,
    research: string | null,
  ): Promise<{ base64: string; mimeType: string; prompt: string; model: string }> {
    let lastError: unknown;
    for (let attempt = 1; attempt <= GENERATE_RETRY_LIMIT; attempt += 1) {
      try {
        return await this.aiGenerateImageService.generate(references, metaJson, extraPrompt, research);
      } catch (err) {
        lastError = err;
        const c = classifyUpstreamError(err);
        if (!isRetryableUpstream(c.code, c.status) || attempt >= GENERATE_RETRY_LIMIT) break;
        await new Promise((resolve) => setTimeout(resolve, attempt * attempt * 1000));
      }
    }
    throw lastError instanceof Error ? lastError : new Error('生图失败，请重试');
  }

  /**
   * ② 批量姿势图：首张锚点先生成，其余张以锚点成片为参考并发生成（并发上限由生图服务信号量控制）。
   * onlyIndexes 给定时只补这些下标（续跑「仅补失败/缺失张」）；未给定的下标视为已完成、直接复用产物。
   */
  private async runImageStage(job: AiPipelineJob, onlyIndexes?: number[]): Promise<void> {
    const draft = job.artifacts.analyze?.draft;
    if (!draft) throw new BadRequestException('缺少识别草稿，无法生成姿势图');
    const targets = this.targetsFor(draft);
    const total = targets.length;

    const byIndex = new Map<number, PipelinePoseFile>();
    for (const f of job.artifacts.poseFiles) byIndex.set(f.index, f);

    const todo = (onlyIndexes ?? Array.from({ length: total }, (_, i) => i)).filter(
      (i) => Number.isInteger(i) && i >= 0 && i < total,
    );
    if (!todo.length) return;

    const references = job.inputs.references;
    const research = this.buildResearchJson(job);
    const failed: number[] = [];

    for (const index of todo) {
      this.append(job, {
        stage: 'image',
        type: 'note',
        step: 'pose',
        index,
        title: `姿势图 #${index + 1} 排队中`,
        status: 'running',
        resultBrief: '等待生图额度',
      });
    }

    const runOne = async (index: number, refs: UploadFile[] | undefined): Promise<void> => {
      const startedAt = Date.now();
      const queuedMs = await this.aiGenerateImageService.acquireImageSlot();
      try {
        this.append(job, {
          stage: 'image',
          type: 'note',
          step: 'pose',
          index,
          title: `姿势图 #${index + 1} 生成中`,
          status: 'running',
          durationMs: queuedMs > 0 ? queuedMs : undefined,
        });
        const sink: TraceSink = (ev) => this.append(job, { ...ev, stage: 'image', index });
        const meta = JSON.stringify({
          ...draft,
          pose: targets[index],
          singlePose: true,
          consistency: index === 0 ? { mode: 'strict' } : { mode: 'strict', anchor: 'first' },
        });
        const r = await runWithTrace(sink, () =>
          this.generateWithRetry(refs, meta, job.inputs.extraPrompt ?? null, research),
        );
        byIndex.set(index, { index, base64: r.base64, mimeType: r.mimeType });
        this.append(job, {
          stage: 'image',
          type: 'note',
          step: 'pose',
          index,
          title: `姿势图 #${index + 1} 完成`,
          status: 'done',
          prompt: r.prompt,
          model: r.model,
          durationMs: Date.now() - startedAt,
        });
      } catch (err) {
        failed.push(index);
        byIndex.delete(index);
        this.append(job, {
          stage: 'image',
          type: 'note',
          step: 'pose',
          index,
          title: `姿势图 #${index + 1} 失败`,
          status: 'fail',
          error: (err as Error)?.message || '生图失败，请重试',
          durationMs: Date.now() - startedAt,
        });
      } finally {
        this.aiGenerateImageService.releaseImageSlot();
      }
    };

    if (todo.includes(0)) await runOne(0, references);

    const anchor = byIndex.get(0);
    const rest = todo.filter((i) => i !== 0);
    if (!anchor) {
      // 锚点不可用：依赖张全部标记失败（与既有批次语义一致），阶段整体失败
      for (const index of rest) {
        failed.push(index);
        this.append(job, {
          stage: 'image',
          type: 'note',
          step: 'pose',
          index,
          title: `姿势图 #${index + 1} 失败`,
          status: 'fail',
          error: '首张锚点姿势图不可用，已停止后续生成',
        });
      }
    } else {
      const anchorRef: UploadFile = {
        buffer: Buffer.from(anchor.base64, 'base64'),
        filename: 'anchor.png',
        mimetype: anchor.mimeType,
      };
      // 依赖张并发提交（真正的多路上游并行由生图服务内部并发额度控制）
      await Promise.all(rest.map((index) => runOne(index, [anchorRef])));
    }

    job.artifacts.poseFiles = [...byIndex.values()].sort((a, b) => a.index - b.index);
    job.artifacts.poseErrors = failed.map((index) => ({ index, error: '姿势图生成失败' }));

    if (failed.length) {
      throw new AiUpstreamError(
        'upstream_http',
        `共 ${failed.length}/${total} 张姿势图生成失败（#${failed.map((i) => i + 1).join('、')}）`,
        { failedIndexes: failed },
      );
    }
  }

  /**
   * ③ 剪影：源 = 已生成的姿势图（base64），mode/crop/engine 取 job 创建时的选项。
   * onlyIndexes 给定时只补这些下标；未给定的下标复用既有产物。
   */
  private async runSilhouetteStage(job: AiPipelineJob, onlyIndexes?: number[]): Promise<void> {
    const sources = job.artifacts.poseFiles;
    if (!sources.length) throw new BadRequestException('缺少姿势图，无法生成剪影');
    const { mode, crop, engine } = job.inputs.silhouette;

    const byIndex = new Map<number, PipelinePoseFile>();
    for (const f of job.artifacts.silFiles) byIndex.set(f.index, f);

    const todo = (onlyIndexes ?? sources.map((s) => s.index)).filter((i) => sources.some((s) => s.index === i));
    if (!todo.length) return;

    const failed: number[] = [];
    let firstError: unknown;

    await Promise.all(
      todo.map(async (index) => {
        const src = sources.find((s) => s.index === index)!;
        const startedAt = Date.now();
        try {
          this.append(job, {
            stage: 'silhouette',
            type: 'note',
            step: 'silhouette',
            index,
            title: `剪影 #${index + 1} 生成中`,
            status: 'running',
          });
          const file: UploadFile = {
            buffer: Buffer.from(src.base64, 'base64'),
            filename: `pose-${index}.png`,
            mimetype: src.mimeType,
          };
          const sink: TraceSink = (ev) => this.append(job, { ...ev, stage: 'silhouette', index });
          const r = await runWithTrace(sink, () =>
            this.aiSilhouetteService.generate(file, JSON.stringify({ mode, crop, engine })),
          );
          byIndex.set(index, { index, base64: r.image, mimeType: r.mimeType });
          this.append(job, {
            stage: 'silhouette',
            type: 'note',
            step: 'silhouette',
            index,
            title: `剪影 #${index + 1} 完成`,
            status: 'done',
            durationMs: Date.now() - startedAt,
          });
        } catch (err) {
          if (firstError === undefined) firstError = err;
          failed.push(index);
          byIndex.delete(index);
          this.append(job, {
            stage: 'silhouette',
            type: 'note',
            step: 'silhouette',
            index,
            title: `剪影 #${index + 1} 失败`,
            status: 'fail',
            error: (err as Error)?.message || '剪影生成失败，请重试',
            durationMs: Date.now() - startedAt,
          });
        }
      }),
    );

    job.artifacts.silFiles = [...byIndex.values()].sort((a, b) => a.index - b.index);
    job.artifacts.silErrors = failed.map((index) => ({ index, error: '剪影生成失败' }));

    if (failed.length) {
      const c = classifyUpstreamError(firstError);
      throw new AiUpstreamError(c.code, `共 ${failed.length}/${todo.length} 张剪影生成失败（#${failed.map((i) => i + 1).join('、')}）`, {
        status: c.status,
        upstream: c.upstream,
        failedIndexes: failed,
      });
    }
  }

  /**
   * 续跑：
   * - job 不存在 → null（控制器转 404，前端提示「任务已失效」并提供重新开始）
   * - running → { resumed: false }（后端仍在跑，前端重新挂上轮询即可）
   * - done   → { resumed: false }（无需续跑）
   * - error  → 从失败阶段重跑（上游阶段与产物保留；image/silhouette 只补失败/缺失下标）
   */
  async resume(jobId: string): Promise<{ resumed: boolean; status: JobStatus } | null> {
    const job = this.jobs.get(jobId);
    if (!job) return null;
    if (job.status === 'running') return { resumed: false, status: 'running' };
    if (job.status === 'done') return { resumed: false, status: 'done' };

    const failedStage = job.error?.stage ?? 'analyze';
    const requested: PipelineStage[] = job.mode === 'analyze-only' ? ['analyze'] : ['analyze', 'image', 'silhouette'];
    const stages = requested.slice(requested.indexOf(failedStage));
    if (!stages.length) return { resumed: false, status: job.status };

    const onlyIndexes: Partial<Record<PipelineStage, number[]>> = {};
    if (failedStage === 'analyze') {
      // 识别重跑会产出新草稿 → 下游产物作废并全量重跑
      job.artifacts.poseFiles = [];
      job.artifacts.poseErrors = [];
      job.artifacts.silFiles = [];
      job.artifacts.silErrors = [];
    } else if (failedStage === 'image') {
      onlyIndexes.image = job.artifacts.poseErrors.length
        ? job.artifacts.poseErrors.map((e) => e.index)
        : undefined;
      onlyIndexes.silhouette = job.artifacts.poseFiles
        .filter((s) => !job.artifacts.silFiles.some((x) => x.index === s.index))
        .map((s) => s.index);
    } else {
      onlyIndexes.silhouette = job.artifacts.silErrors.length ? job.artifacts.silErrors.map((e) => e.index) : undefined;
    }

    for (const stage of stages) job.stages[stage] = { status: 'pending' };
    job.status = 'running';
    job.error = undefined;
    this.append(job, {
      stage: failedStage,
      type: 'note',
      step: 'resume',
      title: `从「${STAGE_TITLES[failedStage]}」继续`,
      status: 'done',
      resultBrief: '已保留上游产物，仅重跑失败部分',
    });
    void this.runPipeline(job, { stages, onlyIndexes });
    return { resumed: true, status: 'running' };
  }

  /**
   * 序列化（响应体收敛的关键）：
   * - running 且非 verbose：事件按 since 增量返回并收紧（长文本截断、丢弃 rawResponse），
   *   不返回 base64 产物与草稿（避免每轮整包回传导致响应体随耗时膨胀）。
   * - 终态（done/error）或 verbose=1：返回完整事件（含 rawResponse）与全部产物，供前端最后一次性取回。
   */
  serialize(job: AiPipelineJob, since = 0, verbose = false) {
    const compact = job.status === 'running' && !verbose;
    const a = job.artifacts.analyze;
    return {
      jobId: job.id,
      status: job.status,
      mode: job.mode,
      stages: job.stages,
      error: job.error ?? null,
      events: job.events.filter((e) => e.seq > since).map((e) => (compact ? capEvent(e) : e)),
      lastSeq: job.events.length ? job.events[job.events.length - 1]!.seq : 0,
      draft: compact ? null : (a?.draft ?? null),
      warnings: compact ? [] : (a?.warnings ?? []),
      trace: compact ? [] : (a?.trace ?? []),
      raw: compact ? null : (a?.raw ?? null),
      research: compact ? [] : (a?.research ?? []),
      researchBrief: compact ? null : (a?.brief ?? null),
      researchImages: compact ? [] : (a?.researchImages ?? []),
      researchVision: compact ? null : (a?.researchVision ?? null),
      poseImages: compact ? [] : job.artifacts.poseFiles,
      poseErrors: compact ? [] : job.artifacts.poseErrors,
      silhouetteImages: compact ? [] : job.artifacts.silFiles,
      silhouetteErrors: compact ? [] : job.artifacts.silErrors,
    };
  }

  /** 查询 job；不存在返回 null（前端据此提示任务失效） */
  get(jobId: string): AiPipelineJob | null {
    return this.jobs.get(jobId) ?? null;
  }

  /** 删除 job（放弃本次生成；前端「放弃」按钮调用）。幂等：不存在也不报错 */
  remove(jobId: string): void {
    this.jobs.delete(jobId);
  }

  onModuleDestroy(): void {
    clearInterval(this.sweeper);
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `cd lumira-server/packages/backend; pnpm test -- ai-pipeline-job`
Expected: PASS（4 个用例全绿）

Run: `cd lumira-server/packages/backend; pnpm build`
Expected: 无 TS 错误

- [ ] **Step 5: 提交**

```bash
git add lumira-server/packages/backend/src/modules/ai/ai-pipeline-job.service.ts lumira-server/packages/backend/src/modules/ai/ai-pipeline-job.service.spec.ts
git commit -m "feat(ai): add in-memory pipeline job service for one-click template creation"
git push origin master
git push github master
```

---

## Task 5: 三阶段流水线与续跑单测

**Files:**
- Test: `lumira-server/packages/backend/src/modules/ai/ai-pipeline-job.service.spec.ts`（追加；不改动 Task 4 已写的用例）
- 不改实现文件（Task 4 已实现完整逻辑；本任务用测试锁住行为，若测试暴露缺陷则在本任务内修正实现）

**Interfaces:**
- Consumes: Task 4 的 `AiPipelineJobService`（`create` / `resume` / `get` / `serialize`）
- Produces: 无（仅测试）

- [ ] **Step 1: 追加三阶段与续跑用例**

在 `ai-pipeline-job.service.spec.ts` 末尾追加：

```ts
describe('AiPipelineJobService（三阶段与续跑）', () => {
  let service: AiPipelineJobService;
  let analyzeMock: jest.Mock;
  let generateMock: jest.Mock;
  let silhouetteMock: jest.Mock;

  const DRAFT = { pose: [{ index: 0 }, { index: 1 }] };

  beforeEach(() => {
    analyzeMock = jest.fn().mockResolvedValue({
      draft: DRAFT, warnings: [], trace: [], raw: {}, research: [], brief: null, researchVision: null,
    });
    generateMock = jest.fn().mockResolvedValue({ base64: 'aW1n', mimeType: 'image/png', prompt: 'p', model: 'm' });
    silhouetteMock = jest.fn().mockResolvedValue({ image: 'c2ls', mimeType: 'image/png' });
    service = new AiPipelineJobService(
      { analyze: analyzeMock } as unknown as AiAnalyzeService,
      {
        acquireImageSlot: jest.fn().mockResolvedValue(0),
        releaseImageSlot: jest.fn(),
        generate: generateMock,
      } as unknown as AiGenerateImageService,
      { generate: silhouetteMock } as unknown as AiSilhouetteService,
    );
  });

  afterEach(() => {
    service.onModuleDestroy();
    jest.restoreAllMocks();
  });

  async function waitStatus(jobId: string, status: string): Promise<void> {
    for (let i = 0; i < 12000; i += 1) {
      if (service.get(jobId)?.status === status) return;
      await new Promise((r) => setTimeout(r, 2));
    }
    throw new Error(`timed out waiting for job status ${status}`);
  }

  it('auto：识别 → 2 张姿势图 → 2 张剪影 → done，产物齐备且事件带 stage/index', async () => {
    const { jobId } = await service.create({ text: '文字描述', mode: 'auto' });
    await waitStatus(jobId, 'done');
    const job = service.get(jobId)!;
    expect(job.stages.analyze.status).toBe('done');
    expect(job.stages.image.status).toBe('done');
    expect(job.stages.silhouette.status).toBe('done');
    expect(job.artifacts.poseFiles.map((f) => f.index)).toEqual([0, 1]);
    expect(job.artifacts.silFiles.map((f) => f.index)).toEqual([0, 1]);
    // 首张锚点先用用户参考图（此处无参考图 → undefined），依赖张以锚点为参考
    expect(generateMock).toHaveBeenCalledTimes(2);
    expect(job.events.some((e) => e.stage === 'image' && e.index === 1 && e.title === '姿势图 #2 完成')).toBe(true);
    expect(job.events.some((e) => e.stage === 'silhouette' && e.index === 0)).toBe(true);
    // seq 严格递增 1..n
    expect(job.events.map((e) => e.seq)).toEqual(job.events.map((_, i) => i + 1));
  });

  it('auto：单张姿势图失败 → image 阶段 error，中断详情带失败下标且不继续到剪影', async () => {
    generateMock.mockImplementation((_refs: unknown, metaJson: string) => {
      const meta = JSON.parse(metaJson) as { pose?: { index?: number } };
      if (meta.pose?.index === 1) return Promise.reject(new Error('AI 请求超时，请稍后重试'));
      return Promise.resolve({ base64: 'aW1n', mimeType: 'image/png', prompt: 'p', model: 'm' });
    });

    const { jobId } = await service.create({ text: '文字描述', mode: 'auto' });
    await waitStatus(jobId, 'error');
    const job = service.get(jobId)!;
    expect(job.error?.stage).toBe('image');
    expect(job.error?.code).toBe('upstream_timeout');
    expect(job.error?.failedIndexes).toEqual([1]);
    expect(job.artifacts.poseFiles.map((f) => f.index)).toEqual([0]);
    expect(job.stages.silhouette.status).toBe('pending');
    expect(silhouetteMock).not.toHaveBeenCalled();
  });

  it('resume：image 失败后只补失败张，成功后继续跑剪影到 done', async () => {
    generateMock.mockImplementation((_refs: unknown, metaJson: string) => {
      const meta = JSON.parse(metaJson) as { pose?: { index?: number } };
      if (meta.pose?.index === 1) return Promise.reject(new Error('AI 请求超时，请稍后重试'));
      return Promise.resolve({ base64: 'aW1n', mimeType: 'image/png', prompt: 'p', model: 'm' });
    });

    const { jobId } = await service.create({ text: '文字描述', mode: 'auto' });
    await waitStatus(jobId, 'error');
    const callsBeforeResume = generateMock.mock.calls.length;

    generateMock.mockResolvedValue({ base64: 'aW1n', mimeType: 'image/png', prompt: 'p', model: 'm' });
    const resumed = await service.resume(jobId);
    expect(resumed).toEqual({ resumed: true, status: 'running' });

    await waitStatus(jobId, 'done');
    const job = service.get(jobId)!;
    // 仅补失败张：resume 后只多调了 1 次生图（未重跑已成功的 #1）
    expect(generateMock.mock.calls.length - callsBeforeResume).toBe(1);
    expect(job.artifacts.poseFiles.map((f) => f.index)).toEqual([0, 1]);
    expect(job.artifacts.silFiles.map((f) => f.index)).toEqual([0, 1]);
  });

  it('resume：running 的 job 不重跑（前端重连即可）；不存在的 jobId 返回 null', async () => {
    analyzeMock.mockImplementation(() => new Promise(() => undefined));
    const { jobId } = await service.create({ text: '文字', mode: 'analyze-only' });
    await expect(service.resume(jobId)).resolves.toEqual({ resumed: false, status: 'running' });
    await expect(service.resume('job_nope')).resolves.toBeNull();
  });

  it('识别失败：bad request → invalid_input 中断，分析服务被调用一次', async () => {
    analyzeMock.mockRejectedValue(new BadRequestException('示例图不能超过 8MB（当前 9.00MB）'));
    const { jobId } = await service.create({ text: '文字', mode: 'analyze-only' });
    await waitStatus(jobId, 'error');
    const job = service.get(jobId)!;
    expect(job.error?.code).toBe('invalid_input');
    expect(job.error?.stage).toBe('analyze');
    expect(job.error?.message).toContain('8MB');
  });
});
```

- [ ] **Step 2: 运行测试**

Run: `cd lumira-server/packages/backend; pnpm test -- ai-pipeline-job`
Expected: PASS（Task 4 的 4 个 + 本任务 5 个用例全绿；若失败，按报错修正 Task 4 实现而非放宽断言）

- [ ] **Step 3: 提交**

```bash
git add lumira-server/packages/backend/src/modules/ai/ai-pipeline-job.service.spec.ts
git commit -m "test(ai): cover pipeline job stages and resume behaviour"
git push origin master
git push github master
```

---

## Task 6: job 端点（4 个）+ `parseAiMultipart` 扩展 + 模块注册

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-templates.controller.ts`（imports、构造函数、4 个新端点、`ParsedAiMultipart` 与 `TEXT_FIELDS`）
- Modify: `lumira-server/packages/backend/src/modules/ai/ai.module.ts`（providers）

**Interfaces:**
- Consumes: Task 4 的 `AiPipelineJobService`；既有 `parseAiMultipart`
- Produces（供 Task 7-14 的 admin 端对齐）：
  - `POST /api/v1/admin/templates/ai-job` → `{ jobId }`
  - `GET /api/v1/admin/templates/ai-job/:jobId?since=&verbose=1` → Task 4 `serialize()` 的返回值；job 不存在 → 404
  - `POST /api/v1/admin/templates/ai-job/:jobId/resume` → `{ resumed, status }`；job 不存在 → 404
  - `DELETE /api/v1/admin/templates/ai-job/:jobId` → `{ ok: true }`

- [ ] **Step 1: 扩展 multipart 解析字段**

在 `ai-templates.controller.ts` 的 `ParsedAiMultipart` 接口末尾（`references?: UploadFile[];` 之后、`}` 之前）加入：

```ts
  /** pipeline job 模式：'auto'（一键全自动）/ 'analyze-only'（仅识别）；缺省按 auto */
  jobMode?: string;
  /** 剪影模式：'sketch' / 'solid'；缺省 sketch */
  silMode?: string;
  /** 剪影是否自动裁剪：'0' 关闭，其余视为开启；缺省开启 */
  silCrop?: string;
  /** 剪影引擎：'ai' / 'local'；缺省 local */
  silEngine?: string;
```

把 `TEXT_FIELDS` 常量改为：

```ts
const TEXT_FIELDS = ['meta', 'text', 'textDesc', 'creationReq', 'poseCount', 'subjectCount', 'extraPrompt', 'research', 'jobMode', 'silMode', 'silCrop', 'silEngine'] as const;
```

- [ ] **Step 2: 注册服务到模块**

在 `ai.module.ts` 顶部新增 import：

```ts
import { AiPipelineJobService } from './ai-pipeline-job.service';
```

并把 providers 数组第一行改为（仅追加 `AiPipelineJobService`）：

```ts
    AiConfigService, AiAnalyzeService, AiAnalyzeTaskService, AiGenerateImageService, AiImageTaskService, AiSilhouetteService, AiSilhouetteTaskService, AiPipelineJobService,
```

- [ ] **Step 3: 新增 4 个端点**

在 `ai-templates.controller.ts` 顶部把 `@nestjs/common` 的 import 改为（增加 `Delete`）：

```ts
import { Controller, Post, Get, Delete, Param, Query, Req, UseGuards, BadRequestException, NotFoundException, Logger } from '@nestjs/common';
```

新增 import：

```ts
import { AiPipelineJobService } from './ai-pipeline-job.service';
import type { JobMode } from './ai-pipeline-job.service';
```

构造函数改为（追加一个依赖）：

```ts
  constructor(
    private readonly aiAnalyzeTaskService: AiAnalyzeTaskService,
    private readonly aiImageTaskService: AiImageTaskService,
    private readonly aiSilhouetteService: AiSilhouetteService,
    private readonly aiSilhouetteTaskService: AiSilhouetteTaskService,
    private readonly aiPipelineJobService: AiPipelineJobService,
  ) {}
```

在类末尾（最后一个 `getSilhouetteTask` 方法之后、类结束的 `}` 之前）新增：

```ts
  /**
   * 创建 AI 流水线 job（识别 → 姿势图 → 剪影）：multipart 字段同 ai-analyze（image/images + text/textDesc +
   * creationReq/poseCount/subjectCount）+ reference/references（姿势参考图）+ extraPrompt，
   * 另加 jobMode（auto / analyze-only）、silMode / silCrop / silEngine（剪影选项）。
   * 立即返回 { jobId }，前端轮询 GET ai-job/:jobId。
   */
  @Post('ai-job')
  async createAiJob(@Req() req: FastifyRequest) {
    const p = await parseAiMultipart(req);
    const mode: JobMode = p.jobMode === 'analyze-only' ? 'analyze-only' : 'auto';
    return this.aiPipelineJobService.create({
      images: p.images,
      text: p.text ?? p.textDesc ?? undefined,
      extra: {
        textDesc: p.textDesc,
        creationReq: p.creationReq,
        poseCount: p.poseCount,
        subjectCount: p.subjectCount,
      },
      references: p.references,
      extraPrompt: p.extraPrompt,
      mode,
      silhouette: {
        mode: p.silMode === 'solid' ? 'solid' : 'sketch',
        crop: p.silCrop !== '0',
        engine: p.silEngine === 'ai' ? 'ai' : 'local',
      },
    });
  }

  /**
   * 查询 job 状态：running 态响应体收敛（事件按 since 增量、长文本收紧、不返回 base64 产物），
   * 终态或 verbose=1 返回完整事件与全部产物；job 不存在（后端重启/超期清理）→ 404。
   */
  @Get('ai-job/:jobId')
  async getAiJob(@Param('jobId') jobId: string, @Query('since') since?: string, @Query('verbose') verbose?: string) {
    const job = this.aiPipelineJobService.get(jobId);
    if (!job) throw new NotFoundException('AI pipeline job not found');
    const sinceSeq = Number.isFinite(Number(since)) ? Number(since) : 0;
    return this.aiPipelineJobService.serialize(job, sinceSeq, verbose === '1');
  }

  /** 续跑：running → 不重跑（前端重连）；error → 从失败阶段重跑并复用上游产物；不存在 → 404 */
  @Post('ai-job/:jobId/resume')
  async resumeAiJob(@Param('jobId') jobId: string) {
    const result = await this.aiPipelineJobService.resume(jobId);
    if (!result) throw new NotFoundException('AI pipeline job not found');
    return result;
  }

  /** 放弃本次生成：删除 job（幂等） */
  @Delete('ai-job/:jobId')
  async deleteAiJob(@Param('jobId') jobId: string) {
    this.aiPipelineJobService.remove(jobId);
    return { ok: true };
  }
```

- [ ] **Step 4: 编译与回归既有测试**

Run: `cd lumira-server/packages/backend; pnpm build`
Expected: 无 TS 错误

Run: `cd lumira-server/packages/backend; pnpm test`
Expected: PASS（含既有 `ai-analyze-task` / `ai-image-task` / `ai-orchestrator` / `image-describe` / `llm-client` 等全部用例；本任务不改这些文件的行为）

- [ ] **Step 5: 提交**

```bash
git add lumira-server/packages/backend/src/modules/ai/ai-templates.controller.ts lumira-server/packages/backend/src/modules/ai/ai.module.ts
git commit -m "feat(ai): expose pipeline job endpoints (create/status/resume/delete)"
git push origin master
git push github master
```

---

## Task 7: 后台 job 类型定义（与后端 `serialize()` 结构对齐）

**Files:**
- Modify: `lumira-server/packages/admin/src/types/admin.ts`（在 `AiAnalyzeStatusResult` 定义之后、`// ===== 图片存储迁移（R2 迁移）=====` 之前插入）

**Interfaces:**
- Consumes: 既有 `AiTraceEvent` / `AiAnalyzeTraceEntry` / `AiResearchRef` / `AiResearchBrief` / `AiResearchImage` / `AiResearchVision`
- Produces（后续 Task 8/9/10/11/13/14 全部依赖）：`AiPipelineStage` / `AiPipelineStageStatus` / `AiPipelineJobStatus` / `AiPipelineJobMode` / `AiInterruptionCode` / `AiInterruptionInfo` / `AiPipelineStageState` / `AiPipelineEvent` / `AiPipelinePoseFile` / `AiPipelineStageFailure` / `AiPipelineStatusResult` / `AiPipelineJobId` / `AiPipelineResumeResult`

- [ ] **Step 1: 追加上类型定义**

在 `src/types/admin.ts` 中 `AiAnalyzeStatusResult` 接口的结束 `}` 之后（约 L819）、`// ===== 图片存储迁移（R2 迁移）=====`（约 L821）之前插入：

```ts
// ===== AI 流水线 job（识别 → 姿势图 → 剪影；后端内存 job 承载，前端只持 jobId）=====
// 字段与后端 AiPipelineJobService.serialize() 的返回结构一一对应，勿单边改名。

/** 流水线阶段：analyze 示例图识别 / image 批量姿势图 / silhouette 剪影 */
export type AiPipelineStage = 'analyze' | 'image' | 'silhouette';
/** 单阶段状态 */
export type AiPipelineStageStatus = 'pending' | 'running' | 'done' | 'error';
/** job 整体状态（后端仅维护三态） */
export type AiPipelineJobStatus = 'running' | 'done' | 'error';
/** job 模式：auto 全自动（识别→姿势图→剪影）/ analyze-only 仅识别 */
export type AiPipelineJobMode = 'auto' | 'analyze-only';

/** 中断分类错误码（前端据此选文案与建议，不再靠中文正则猜） */
export type AiInterruptionCode =
  | 'job_missing'
  | 'upstream_timeout'
  | 'upstream_http'
  | 'upstream_empty'
  | 'poll_timeout'
  | 'network'
  | 'payload_too_large'
  | 'aborted'
  | 'invalid_input'
  | 'internal';

/** 一次中断的分层详情（后端 job 失败时权威给出；传输层失败由前端合成） */
export interface AiInterruptionInfo {
  code: AiInterruptionCode;
  stage: AiPipelineStage;
  /** 运营可读的粗粒度原因（保留上游原文中的关键信息） */
  message: string;
  /** 上游原始响应/异常文案（截断后） */
  upstream?: string;
  /** 上游 HTTP 状态码 */
  status?: number;
  /** 该阶段已耗时（ms） */
  elapsedMs?: number;
  /** 失败下标（示例图/姿势图/剪影，0-based） */
  failedIndexes?: number[];
  /** 处置建议 */
  hint?: string;
  /** 发生时间（ms epoch） */
  at: number;
}

/** 单阶段运行状态 */
export interface AiPipelineStageState {
  status: AiPipelineStageStatus;
  startedAt?: number;
  finishedAt?: number;
  error?: AiInterruptionInfo;
}

/** 流水线事件：在既有 AiTraceEvent 之上补 stage / index / prompt */
export interface AiPipelineEvent extends AiTraceEvent {
  stage: AiPipelineStage;
  /** 姿势图 / 剪影下标（0-based） */
  index?: number;
  /** 姿势图完成后的最终生图提示词 */
  prompt?: string;
}

/** 序列化返回的单张产物（base64） */
export interface AiPipelinePoseFile {
  index: number;
  base64: string;
  mimeType: string;
}

/** 单张产物的结构化失败 */
export interface AiPipelineStageFailure {
  index: number;
  error: string;
}

/** 查询流水线 job 状态（与后端 serialize() 返回结构一致） */
export interface AiPipelineStatusResult {
  jobId: string;
  status: AiPipelineJobStatus;
  mode: AiPipelineJobMode;
  stages: Record<AiPipelineStage, AiPipelineStageState>;
  error: AiInterruptionInfo | null;
  events: AiPipelineEvent[];
  lastSeq: number;
  draft: Record<string, unknown> | null;
  warnings: string[];
  trace: AiAnalyzeTraceEntry[];
  raw: Record<string, unknown> | null;
  research: AiResearchRef[];
  researchBrief: AiResearchBrief | null;
  researchImages: AiResearchImage[];
  researchVision: AiResearchVision | null;
  poseImages: AiPipelinePoseFile[];
  poseErrors: AiPipelineStageFailure[];
  silhouetteImages: AiPipelinePoseFile[];
  silhouetteErrors: AiPipelineStageFailure[];
}

/** 提交流水线 job → 立即返回 jobId */
export interface AiPipelineJobId {
  jobId: string;
}

/** resume 结果（resumed=false + status=running 表示任务仍在跑，前端只需重连） */
export interface AiPipelineResumeResult {
  resumed: boolean;
  status: AiPipelineJobStatus;
}
```

- [ ] **Step 2: 类型检查**

Run: `cd lumira-server/packages/admin; npx tsc --noEmit`
Expected: 无 TS 错误（既有代码未受影响）

- [ ] **Step 3: 提交**

```bash
git add lumira-server/packages/admin/src/types/admin.ts
git commit -m "feat(admin): add AI pipeline job types"
```

---

## Task 8: `api.ts` 新增 4 个 pipeline API

**Files:**
- Modify: `lumira-server/packages/admin/src/lib/api.ts`

**Interfaces:**
- Consumes: Task 7 的 `AiPipelineJobId` / `AiPipelineStatusResult` / `AiPipelineResumeResult`；既有 `adminFetch` / `AI_ENDPOINT_TIMEOUT_MS`
- Produces（Task 9 依赖）：`api.aiPipelineStart` / `api.aiPipelineStatus` / `api.aiPipelineResume` / `api.aiPipelineCancel`

- [ ] **Step 1: 追加类型导入**

在 `src/lib/api.ts` 顶部 `from '@/types/admin'` 的类型导入块中，`AiSilhouetteStatusResult,` 之后追加：

```ts
  AiPipelineJobId,
  AiPipelineStatusResult,
  AiPipelineResumeResult,
```

- [ ] **Step 2: 追加 4 个 API 方法**

在 `api` 对象中，`aiGenerateSilhouette`（兼容保留的那个，约 L615-619）之后、`// ===== 图片存储迁移（R2 迁移）=====` 之前插入：

```ts
  // ===== AI 流水线 job（识别 → 姿势图 → 剪影，断点续跑）=====
  /** multipart：示例图 image/image + text/textDesc + creationReq/poseCount/subjectCount + 参考图 reference/references
   *  + extraPrompt + jobMode（auto / analyze-only）+ silMode/silCrop/silEngine → 立即返回 jobId */
  aiPipelineStart: (formData: FormData) =>
    adminFetch<AiPipelineJobId>('/templates/ai-job', {
      method: 'POST',
      body: formData,
    }, AI_ENDPOINT_TIMEOUT_MS),

  /** 查询 job：since>0 只取增量事件；verbose=1 强制返回全量事件与 base64 产物（job 不存在 → 404） */
  aiPipelineStatus: (jobId: string, since?: number, verbose?: boolean) =>
    adminFetch<AiPipelineStatusResult>(
      `/templates/ai-job/${jobId}?since=${typeof since === 'number' && since > 0 ? since : 0}${
        verbose ? '&verbose=1' : ''
      }`,
    ),

  /** 续跑：running → 仅重连（resumed=false）；error → 从失败阶段重跑并复用上游产物（resumed=true） */
  aiPipelineResume: (jobId: string) =>
    adminFetch<AiPipelineResumeResult>(`/templates/ai-job/${jobId}/resume`, {
      method: 'POST',
      body: JSON.stringify({}),
    }),

  /** 放弃本次生成：删除 job（幂等，不存在也返回 ok） */
  aiPipelineCancel: (jobId: string) =>
    adminFetch<{ ok: true }>(`/templates/ai-job/${jobId}`, { method: 'DELETE' }),
```

> 注：`aiPipelineResume` 显式传 `body: JSON.stringify({})`，避免 Fastify 在 `Content-Type: application/json` 且空 body 时抛 `FST_ERR_CTP_EMPTY_JSON_BODY`（与既有 `testAiConfig` 写法一致）。

- [ ] **Step 3: 类型检查**

Run: `cd lumira-server/packages/admin; npx tsc --noEmit`
Expected: 无 TS 错误

- [ ] **Step 4: 提交**

```bash
git add lumira-server/packages/admin/src/lib/api.ts
git commit -m "feat(admin): add AI pipeline job api calls"
```

---

## Task 9: `actions/ai.ts` 新增 4 个 pipeline server actions

**Files:**
- Modify: `lumira-server/packages/admin/src/actions/ai.ts`

**Interfaces:**
- Consumes: Task 8 的 4 个 api 方法；Task 7 的 3 个结果类型
- Produces（Task 11 依赖）：`aiPipelineStartAction` / `aiPipelineStatusAction` / `aiPipelineResumeAction` / `aiPipelineCancelAction`

- [ ] **Step 1: 追加类型导入**

在 `src/actions/ai.ts` 的 `from '@/types/admin'` 类型导入块中，`AiSilhouetteStatusResult,` 之后追加：

```ts
  AiPipelineJobId,
  AiPipelineStatusResult,
  AiPipelineResumeResult,
```

- [ ] **Step 2: 追加上 4 个 action**

在文件末尾（`aiGenerateSilhouetteStatusAction` 之后）追加：

```ts
/** formData：识别/全自动共用的 pipeline job 提交（示例图 + 文字 + 附加输入 + 参考图 + jobMode/silMode/silCrop/silEngine） */
export async function aiPipelineStartAction(
  formData: FormData,
): Promise<AiPipelineJobId | { error: string }> {
  try {
    return await api.aiPipelineStart(formData);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
}

/** 轮询 pipeline job；since 传上个 lastSeq 只取增量事件，verbose=true 强制全量（含 base64 产物） */
export async function aiPipelineStatusAction(
  jobId: string,
  since?: number,
  verbose?: boolean,
): Promise<AiPipelineStatusResult | { error: string }> {
  try {
    return await api.aiPipelineStatus(jobId, since, verbose);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
}

/** 断点续跑：running 仅重连、error 从失败阶段重跑（job 不存在 → 404 文案由 api 透传） */
export async function aiPipelineResumeAction(
  jobId: string,
): Promise<AiPipelineResumeResult | { error: string }> {
  try {
    return await api.aiPipelineResume(jobId);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
}

/** 放弃本次生成（删除 job，幂等） */
export async function aiPipelineCancelAction(
  jobId: string,
): Promise<{ ok: true } | { error: string }> {
  try {
    return await api.aiPipelineCancel(jobId);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
}
```

- [ ] **Step 3: 类型检查**

Run: `cd lumira-server/packages/admin; npx tsc --noEmit`
Expected: 无 TS 错误

- [ ] **Step 4: 提交**

```bash
git add lumira-server/packages/admin/src/actions/ai.ts
git commit -m "feat(admin): add AI pipeline server actions"
```

---

## Task 10: 导出 `base64ToFile` 与 `formatSec`（供 pipeline 复用）

**Files:**
- Modify: `lumira-server/packages/admin/src/lib/ai-task.ts:52,141`

**Interfaces:**
- Consumes: 无
- Produces（Task 11/13/14 依赖）：`export function base64ToFile(b64: string, mime: string, name: string): File`、`export function formatSec(ms: number): string`

- [ ] **Step 1: 两个内部函数改为导出**

将 `src/lib/ai-task.ts` 第 141 行：

```ts
function base64ToFile(b64: string, mime: string, name: string): File {
```

改为：

```ts
export function base64ToFile(b64: string, mime: string, name: string): File {
```

将同文件第 52 行：

```ts
function formatSec(ms: number): string {
```

改为：

```ts
export function formatSec(ms: number): string {
```

（两函数体与各自上方注释保持不变；文件内既有调用不受影响。）

- [ ] **Step 2: 类型检查 + 既有测试回归**

Run: `cd lumira-server/packages/admin; npx tsc --noEmit`
Expected: 无 TS 错误

Run: `cd lumira-server/packages/admin; pnpm test`
Expected: PASS（既有 `ai-task.test.ts` 全部用例不受影响）

- [ ] **Step 3: 提交**

```bash
git add lumira-server/packages/admin/src/lib/ai-task.ts
git commit -m "refactor(admin): export base64ToFile and formatSec for reuse"
```

---

## Task 11: 新增 `src/lib/pipeline-task.ts` + 单测

**Files:**
- Create: `lumira-server/packages/admin/src/lib/pipeline-task.ts`
- Test: `lumira-server/packages/admin/src/lib/__tests__/pipeline-task.test.ts`

**Interfaces:**
- Consumes: Task 9 的 4 个 action；Task 10 的 `base64ToFile`；Task 7 的 pipeline 类型；既有 `AiPoseProgress`（`@/lib/ai-task`）、`formatSec`（`@/lib/ai-task`）
- Produces（Task 12/13/14 依赖）：
  - `class PipelinePollError extends Error { code?: AiInterruptionCode }`
  - `classifyPipelineError(message: string): AiInterruptionCode`
  - `isRetryablePipelineError(code: AiInterruptionCode): boolean`
  - `interruptionFromPollError(err: unknown, stage: AiPipelineStage): AiInterruptionInfo`
  - `withRetry<T>(fn, options?: { attempts?: number; delaysMs?: number[]; signal?: AbortSignal }): Promise<T>`
  - `startPipelineJob(formData: FormData): Promise<string>`
  - `fetchPipelineStatus(jobId: string, since?: number, verbose?: boolean): Promise<AiPipelineStatusResult>`
  - `pollPipelineJob(jobId: string, options?: PollPipelineOptions): Promise<AiPipelineStatusResult>`
  - `resumePipelineJob(jobId: string): Promise<AiPipelineResumeResult>`
  - `cancelPipelineJob(jobId: string): Promise<void>`
  - `toRecogEvents(events: AiPipelineEvent[]): AiTraceEvent[]`
  - `toPoseEvents(events: AiPipelineEvent[]): AiBatchImageTraceEvent[]`
  - `toAnalyzeDetail(result: AiPipelineStatusResult): AiAnalyzeStatusResult`
  - `currentPipelineStage(result: Pick<AiPipelineStatusResult, 'stages' | 'mode'>): AiPipelineStage`
  - `poseProgressFromEvents(events: AiPipelineEvent[]): AiPoseProgress | null`
  - `pipelineStageLabel(stage: AiPipelineStage): string`
  - `pipelineFiles(files: AiPipelinePoseFile[]): Array<{ index: number; file: File }>`

- [ ] **Step 1: 写失败测试**

创建 `src/lib/__tests__/pipeline-task.test.ts`：

```ts
// src/lib/__tests__/pipeline-task.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest';

vi.mock('@/actions/ai', () => ({
  aiPipelineStartAction: vi.fn(),
  aiPipelineStatusAction: vi.fn(),
  aiPipelineResumeAction: vi.fn(),
  aiPipelineCancelAction: vi.fn(),
}));

import { aiPipelineStatusAction } from '@/actions/ai';
import type {
  AiBatchImageTraceEvent,
  AiPipelineEvent,
  AiPipelineStatusResult,
  AiTraceEvent,
} from '@/types/admin';
import {
  PipelinePollError,
  classifyPipelineError,
  currentPipelineStage,
  isRetryablePipelineError,
  pipelineFiles,
  pollPipelineJob,
  poseProgressFromEvents,
  toAnalyzeDetail,
  toPoseEvents,
  toRecogEvents,
  withRetry,
} from '../pipeline-task';

const statusMock = vi.mocked(aiPipelineStatusAction);

/** 造一个最小可用的 AiPipelineStatusResult */
function mkStatus(over: Partial<AiPipelineStatusResult> = {}): AiPipelineStatusResult {
  return {
    jobId: 'job_1',
    status: 'running',
    mode: 'auto',
    stages: {
      analyze: { status: 'pending' },
      image: { status: 'pending' },
      silhouette: { status: 'pending' },
    },
    error: null,
    events: [],
    lastSeq: 0,
    draft: null,
    warnings: [],
    trace: [],
    raw: null,
    research: [],
    researchBrief: null,
    researchImages: [],
    researchVision: null,
    poseImages: [],
    poseErrors: [],
    silhouetteImages: [],
    silhouetteErrors: [],
    ...over,
  };
}

function mkEvent(over: Partial<AiPipelineEvent>): AiPipelineEvent {
  return {
    seq: 1,
    ts: 1,
    type: 'note',
    step: 'pose',
    title: 'x',
    status: 'running',
    stage: 'image',
    ...over,
  };
}

describe('classifyPipelineError', () => {
  it('按后端/网关稳定文案分类', () => {
    expect(classifyPipelineError('API_ERROR: 404 AI pipeline job not found')).toBe('job_missing');
    expect(classifyPipelineError('API_ERROR: 413 Payload Too Large')).toBe('payload_too_large');
    expect(classifyPipelineError('无法连接后端服务，请检查网络与后端状态')).toBe('network');
    expect(classifyPipelineError('请求后端超时（300s），可能后端处理较慢或网络不通，请稍后重试')).toBe('network');
    expect(classifyPipelineError('API_ERROR: 400 封面图片不能超过 5MB')).toBe('invalid_input');
    expect(classifyPipelineError('莫名其妙')).toBe('internal');
  });
});

describe('isRetryablePipelineError', () => {
  it('传输/上游类可重试；失效/入参类不可', () => {
    expect(isRetryablePipelineError('upstream_timeout')).toBe(true);
    expect(isRetryablePipelineError('network')).toBe(true);
    expect(isRetryablePipelineError('poll_timeout')).toBe(true);
    expect(isRetryablePipelineError('job_missing')).toBe(false);
    expect(isRetryablePipelineError('payload_too_large')).toBe(false);
    expect(isRetryablePipelineError('invalid_input')).toBe(false);
  });
});

describe('withRetry', () => {
  it('可重试错误按退避重试后成功', async () => {
    let calls = 0;
    const fn = vi.fn(async () => {
      calls += 1;
      if (calls < 3) throw new PipelinePollError('无法连接后端服务，请检查网络与后端状态');
      return 'ok';
    });
    await expect(
      withRetry(fn, { attempts: 4, delaysMs: [1, 1, 1, 1] }),
    ).resolves.toBe('ok');
    expect(fn).toHaveBeenCalledTimes(3);
  });

  it('不可重试错误立即抛出', async () => {
    const fn = vi.fn(async () => {
      throw new PipelinePollError('API_ERROR: 404 AI pipeline job not found');
    });
    await expect(withRetry(fn, { attempts: 4, delaysMs: [1] })).rejects.toThrow(
      'API_ERROR: 404',
    );
    expect(fn).toHaveBeenCalledTimes(1);
  });

  it('达到上限后抛最后一次错误', async () => {
    const fn = vi.fn(async () => {
      throw new PipelinePollError('无法连接后端服务，请检查网络与后端状态');
    });
    await expect(withRetry(fn, { attempts: 3, delaysMs: [1, 1, 1] })).rejects.toThrow(
      '无法连接后端服务',
    );
    expect(fn).toHaveBeenCalledTimes(3);
  });
});

describe('pollPipelineJob', () => {
  beforeEach(() => statusMock.mockReset());

  it('单次查询抖动不中断：重试后继续轮询到 done', async () => {
    statusMock
      .mockRejectedValueOnce(new Error('无法连接后端服务，请检查网络与后端状态'))
      .mockResolvedValueOnce(
        mkStatus({
          status: 'done',
          stages: {
            analyze: { status: 'done' },
            image: { status: 'done' },
            silhouette: { status: 'done' },
          },
          draft: { name: 'd' },
          poseImages: [{ index: 0, base64: 'AAA', mimeType: 'image/png' }],
        }),
      );
    const res = await pollPipelineJob('job_1', {
      intervalMs: 1,
      timeoutMs: 2000,
      retryDelaysMs: [1, 1, 1, 1],
    });
    expect(res.status).toBe('done');
    expect(res.draft).toEqual({ name: 'd' });
  });

  it('job 不存在（404）→ 抛 PipelinePollError 且 code=job_missing', async () => {
    // 真实链路：server action 捕获 api 抛错后返回 { error }（不抛出），故此处 mock resolve
    statusMock.mockResolvedValue({ error: 'API_ERROR: 404 AI pipeline job not found' });
    await expect(
      pollPipelineJob('job_x', { intervalMs: 1, timeoutMs: 500, retryDelaysMs: [1] }),
    ).rejects.toMatchObject({ code: 'job_missing' });
  });

  it('job 阶段失败（status=error）时返回结果而非抛错（由调用方展示中断详情）', async () => {
    statusMock.mockResolvedValue(
      mkStatus({
        status: 'error',
        stages: {
          analyze: { status: 'done' },
          image: { status: 'error' },
          silhouette: { status: 'pending' },
        },
        error: {
          code: 'upstream_timeout',
          stage: 'image',
          message: '共 1/3 张姿势图生成失败（#2）',
          hint: '点「继续」重试该阶段',
          at: 1,
        },
      }),
    );
    const res = await pollPipelineJob('job_1', { intervalMs: 1, timeoutMs: 2000 });
    expect(res.status).toBe('error');
    expect(res.error?.code).toBe('upstream_timeout');
  });

  it('增量事件按 seq 累积并回调', async () => {
    statusMock
      .mockResolvedValueOnce(mkStatus({ events: [mkEvent({ seq: 1 })], lastSeq: 1 }))
      .mockResolvedValueOnce(mkStatus({ events: [mkEvent({ seq: 2 })], lastSeq: 2 }))
      .mockResolvedValueOnce(mkStatus({ status: 'done', events: [], lastSeq: 2 }));
    const seen: number[] = [];
    const res = await pollPipelineJob('job_1', {
      intervalMs: 1,
      timeoutMs: 2000,
      onEvents: (evs) => seen.push(evs.length),
    });
    expect(res.status).toBe('done');
    expect(seen[seen.length - 1]).toBe(2);
    // 第二次查询带 since=1（增量）
    expect(statusMock.mock.calls[1]?.[1]).toBe(1);
  });
});

describe('事件转换', () => {
  it('toRecogEvents 只留 analyze 阶段', () => {
    const events: AiPipelineEvent[] = [
      mkEvent({ seq: 1, stage: 'analyze', step: 'describe' }),
      mkEvent({ seq: 2, stage: 'image' }),
      mkEvent({ seq: 3, stage: 'silhouette' }),
    ];
    const out: AiTraceEvent[] = toRecogEvents(events);
    expect(out.map((e) => e.seq)).toEqual([1]);
  });

  it('toPoseEvents 保留 index、fail→error、kind 由 type 推断', () => {
    const events: AiPipelineEvent[] = [
      mkEvent({ seq: 1, type: 'note', index: 0, status: 'running' }),
      mkEvent({ seq: 2, type: 'llm', index: 0, status: 'fail', callId: 'c1' }),
      mkEvent({ seq: 3, type: 'note', index: 1, status: 'done', prompt: 'p' }),
    ];
    const out: AiBatchImageTraceEvent[] = toPoseEvents(events);
    expect(out.map((e) => e.index)).toEqual([0, 0, 1]);
    expect(out.map((e) => e.kind)).toEqual(['pose', 'llm', 'pose']);
    expect(out.map((e) => e.status)).toEqual(['running', 'error', 'done']);
    expect(out[2]!.prompt).toBe('p');
  });

  it('poseProgressFromEvents 统计完成/进行中/总数', () => {
    const events: AiPipelineEvent[] = [
      mkEvent({ seq: 1, index: 0, status: 'done' }),
      mkEvent({ seq: 2, index: 1, status: 'running' }),
      mkEvent({ seq: 3, index: 2, status: 'running' }),
      mkEvent({ seq: 4, index: 0, type: 'llm', status: 'done' }),
    ];
    expect(poseProgressFromEvents(events)).toEqual({ current: 2, total: 3, status: 'running' });
    expect(poseProgressFromEvents([])).toBeNull();
  });

  it('currentPipelineStage 优先 running，其次 error，再次最后 done', () => {
    expect(
      currentPipelineStage(
        mkStatus({
          stages: {
            analyze: { status: 'done' },
            image: { status: 'running' },
            silhouette: { status: 'pending' },
          },
        }),
      ),
    ).toBe('image');
    expect(
      currentPipelineStage(
        mkStatus({
          stages: {
            analyze: { status: 'done' },
            image: { status: 'error' },
            silhouette: { status: 'pending' },
          },
        }),
      ),
    ).toBe('image');
    expect(
      currentPipelineStage(
        mkStatus({
          stages: {
            analyze: { status: 'done' },
            image: { status: 'pending' },
            silhouette: { status: 'pending' },
          },
        }),
      ),
    ).toBe('analyze');
  });

  it('toAnalyzeDetail 把 job 结果映射成识别详情结构', () => {
    const detail = toAnalyzeDetail(
      mkStatus({
        status: 'done',
        draft: { name: 'd' },
        warnings: ['w'],
        events: [mkEvent({ seq: 1, stage: 'analyze', step: 'describe' })],
        lastSeq: 1,
      }),
    );
    expect(detail.status).toBe('done');
    expect(detail.draft).toEqual({ name: 'd' });
    expect(detail.events?.map((e) => e.seq)).toEqual([1]);
  });

  it('pipelineFiles 按 index 排序并转 File', () => {
    const files = pipelineFiles([
      { index: 1, base64: btoa('b'), mimeType: 'image/png' },
      { index: 0, base64: btoa('a'), mimeType: 'image/png' },
    ]);
    expect(files.map((f) => f.index)).toEqual([0, 1]);
    expect(files[0]!.file).toBeInstanceOf(File);
  });
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd lumira-server/packages/admin; pnpm test -- pipeline-task`
Expected: FAIL（`Failed to resolve import "../pipeline-task"`）

- [ ] **Step 3: 实现 `src/lib/pipeline-task.ts`**

创建 `src/lib/pipeline-task.ts`：

```ts
// src/lib/pipeline-task.ts
// AI 流水线 job 的前端驱动：提交 / 轮询（增量事件 + 退避重试）/ 续跑 / 放弃，
// 并把 job 事件转换为既有「风格识别」「姿势图生成」两个 Tab 所需的既有事件类型。
import {
  aiPipelineCancelAction,
  aiPipelineResumeAction,
  aiPipelineStartAction,
  aiPipelineStatusAction,
} from '@/actions/ai';
import { base64ToFile, formatSec, type AiPoseProgress } from '@/lib/ai-task';
import type {
  AiAnalyzeStatusResult,
  AiBatchImageTraceEvent,
  AiInterruptionCode,
  AiInterruptionInfo,
  AiPipelineEvent,
  AiPipelinePoseFile,
  AiPipelineResumeResult,
  AiPipelineStage,
  AiPipelineStatusResult,
  AiTraceEvent,
} from '@/types/admin';

/** 前端可读的 job 轮询错误（带分类错误码，供中断 Banner 选文案） */
export class PipelinePollError extends Error {
  constructor(
    message: string,
    public readonly code?: AiInterruptionCode,
  ) {
    super(message);
    this.name = 'PipelinePollError';
  }
}

/** 轮询总预算：对齐后端 job 保留期（60 分钟）。超出后前端放弃等待，但 job 仍可「继续」重连 */
const PIPELINE_TIMEOUT_MS = 3_600_000;
const DEFAULT_INTERVAL_MS = 2000;
/** 传输层失败退避：1s / 2s / 4s / 8s（最多 4 次尝试） */
const RETRY_DELAYS_MS = [1000, 2000, 4000, 8000];

/** 分类建议文案（后端 job 的 error.hint 优先；此处仅覆盖传输层合成的中断） */
const HINTS: Record<AiInterruptionCode, string> = {
  job_missing: '任务已失效（后端重启或超过 1 小时保留期被清理），请重新开始',
  upstream_timeout: '上游模型响应超时；可点「继续」重试该阶段，或调大「AI 设置 → 识别稳定性」的单次 LLM 超时',
  upstream_http: '上游返回错误状态；请检查「AI 设置」中的模型与 apiKey（含权限/额度）',
  upstream_empty: '上游返回空内容（多为瞬时故障）；点「继续」重试该阶段',
  poll_timeout: '前端等待超时但后端可能仍在运行；点「继续」重连接着等',
  network: '网络中断或后端不可达；恢复后点「继续」重连',
  payload_too_large: '上传内容过大被网关拒绝；请压缩示例图（建议 ≤3MB/张）后重新开始',
  aborted: '已手动中止；点「继续」可从当前阶段续跑',
  invalid_input: '输入不合法；请按提示修正后重新开始',
  internal: '未归类异常；详情见「生成过程」面板，可点「继续」重试该阶段',
};

const STAGE_LABELS: Record<AiPipelineStage, string> = {
  analyze: '示例图识别',
  image: '封面姿势图生成',
  silhouette: '剪影生成',
};

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function throwIfAborted(signal?: AbortSignal): void {
  if (signal?.aborted) throw new PipelinePollError('已中止', 'aborted');
}

export function pipelineStageLabel(stage: AiPipelineStage): string {
  return STAGE_LABELS[stage];
}

/**
 * 传输层错误分类：只匹配本仓库自己生成的稳定文案（api.ts 的 `API_ERROR: <status> <detail>`、
 * 超时 / 无法连接 / 空响应），不猜上游自由文本；上游真因由后端 job 的 error 权威给出。
 */
export function classifyPipelineError(message: string): AiInterruptionCode {
  const m = message || '';
  if (/API_ERROR:\s*404/.test(m) || /not found/i.test(m)) return 'job_missing';
  if (/API_ERROR:\s*413/.test(m) || /过大|too large|payload/i.test(m)) return 'payload_too_large';
  if (/API_ERROR:\s*4\d\d/.test(m)) return 'invalid_input';
  if (/超时|无法连接后端|Failed to fetch|NetworkError|ECONNREFUSED|fetch failed/i.test(m)) return 'network';
  return 'internal';
}

/** 是否值得「继续」（可重试）：传输/上游瞬时类可；job 失效、入参错误不可 */
export function isRetryablePipelineError(code: AiInterruptionCode): boolean {
  return (
    code === 'upstream_timeout' ||
    code === 'upstream_http' ||
    code === 'upstream_empty' ||
    code === 'poll_timeout' ||
    code === 'network' ||
    code === 'aborted' ||
    code === 'internal'
  );
}

/** 把传输层异常合成为中断详情（用于 Banner；stage 取当前阶段） */
export function interruptionFromPollError(err: unknown, stage: AiPipelineStage): AiInterruptionInfo {
  const message = err instanceof Error ? err.message : String(err);
  const code = err instanceof PipelinePollError && err.code ? err.code : classifyPipelineError(message);
  return { code, stage, message, hint: HINTS[code], at: Date.now() };
}

/** 有界退避重试：仅对可重试分类重试（默认 1/2/4/8s，共 4 次） */
export async function withRetry<T>(
  fn: () => Promise<T>,
  options: { attempts?: number; delaysMs?: number[]; signal?: AbortSignal } = {},
): Promise<T> {
  const attempts = options.attempts ?? 4;
  const delays = options.delaysMs ?? RETRY_DELAYS_MS;
  let last: unknown;
  for (let i = 1; i <= attempts; i += 1) {
    try {
      return await fn();
    } catch (err) {
      last = err;
      if (options.signal?.aborted) throw err;
      const message = err instanceof Error ? err.message : String(err);
      const code = err instanceof PipelinePollError && err.code ? err.code : classifyPipelineError(message);
      if (!isRetryablePipelineError(code) || i >= attempts) throw err;
      await sleep(delays[i - 1] ?? delays[delays.length - 1] ?? 1000);
    }
  }
  throw last;
}

/** 提交 job → jobId（提交本身失败直接抛，不做重试：入参错误重试无意义） */
export async function startPipelineJob(formData: FormData): Promise<string> {
  const started = await aiPipelineStartAction(formData);
  if ('error' in started) {
    // server action 只透传 message（收敛 #5）：在此按自有稳定文案补分类，供 Banner 展示与「继续」判定
    const message = started.error || '提交生成任务失败';
    throw new PipelinePollError(message, classifyPipelineError(message));
  }
  return started.jobId;
}

/** 单次查询 job 状态（verbose=true 取全量事件与 base64 产物） */
export async function fetchPipelineStatus(
  jobId: string,
  since = 0,
  verbose = false,
): Promise<AiPipelineStatusResult> {
  const res = await aiPipelineStatusAction(jobId, since, verbose);
  if ('error' in res) {
    const message = res.error || '查询生成任务失败';
    throw new PipelinePollError(message, classifyPipelineError(message));
  }
  return res;
}

export interface PollPipelineOptions {
  intervalMs?: number;
  timeoutMs?: number;
  signal?: AbortSignal;
  /** 增量事件累积回调（供两个 Tab 实时渲染） */
  onEvents?: (events: AiPipelineEvent[]) => void;
  /** 每次成功查询回调（供阶段栏 / 进度更新） */
  onStatus?: (result: AiPipelineStatusResult) => void;
  /** 传输层重试退避（测试注入小值） */
  retryDelaysMs?: number[];
}

/**
 * 轮询 job 到终态：
 * - 单次查询失败 → 退避重试（1/2/4/8s），不因一次抖动就中断（原「查询识别任务失败」的致盲点）
 * - running → 按 since 增量吸收事件后继续
 * - done/error → 直接返回该次响应（终态响应后端已放宽为全量：含 draft / 产物 / error 详情）
 * - 超过总预算 → 抛 PipelinePollError(code=poll_timeout)，前端展示「继续」重连
 */
export async function pollPipelineJob(
  jobId: string,
  options: PollPipelineOptions = {},
): Promise<AiPipelineStatusResult> {
  const { intervalMs = DEFAULT_INTERVAL_MS, timeoutMs = PIPELINE_TIMEOUT_MS, signal, onEvents, onStatus, retryDelaysMs } =
    options;
  const startedAt = Date.now();
  const deadline = startedAt + timeoutMs;
  let since = 0;
  const events: AiPipelineEvent[] = [];

  const absorb = (res: AiPipelineStatusResult) => {
    if (!res.events?.length) return;
    since = res.lastSeq ?? since;
    events.push(...res.events);
    onEvents?.(events.slice());
  };

  while (Date.now() < deadline) {
    throwIfAborted(signal);
    const res = await withRetry(() => fetchPipelineStatus(jobId, since), {
      signal,
      delaysMs: retryDelaysMs,
    });
    absorb(res);
    onStatus?.(res);
    if (res.status === 'done' || res.status === 'error') return res;
    await sleep(intervalMs);
  }
  throw new PipelinePollError(
    `等待超时：已等待 ${formatSec(Date.now() - startedAt)}，后端任务可能仍在运行`,
    'poll_timeout',
  );
}

/** 续跑：running → resumed=false（仅重连）；error → resumed=true（从失败阶段重跑） */
export async function resumePipelineJob(jobId: string): Promise<AiPipelineResumeResult> {
  const res = await aiPipelineResumeAction(jobId);
  if ('error' in res) {
    const message = res.error || '续跑请求失败';
    throw new PipelinePollError(message, classifyPipelineError(message));
  }
  return res;
}

/** 放弃本次生成（删除 job，幂等） */
export async function cancelPipelineJob(jobId: string): Promise<void> {
  const res = await aiPipelineCancelAction(jobId);
  if ('error' in res) {
    const message = res.error || '放弃任务失败';
    throw new PipelinePollError(message, classifyPipelineError(message));
  }
}

/** 取 analyze 阶段事件（喂「风格识别」Tab） */
export function toRecogEvents(events: AiPipelineEvent[]): AiTraceEvent[] {
  return events.filter((e) => e.stage === 'analyze');
}

/** 取 image 阶段事件并转成批次事件类型（喂「姿势图生成」Tab；fail→error、type→kind） */
export function toPoseEvents(events: AiPipelineEvent[]): AiBatchImageTraceEvent[] {
  return events
    .filter((e) => e.stage === 'image')
    .map((e) => ({
      seq: e.seq,
      ts: e.ts,
      index: e.index ?? 0,
      title: e.title,
      status: e.status === 'fail' ? 'error' : e.status,
      kind: e.type === 'llm' ? 'llm' : e.type === 'search' ? 'search' : 'pose',
      callId: e.callId,
      prompt: e.prompt,
      model: e.model,
      systemPrompt: e.systemPrompt,
      userPrompt: e.userPrompt,
      response: e.response,
      rawResponse: e.rawResponse,
      attempts: e.attempts,
      error: e.error,
      durationMs: e.durationMs,
    }));
}

/** 姿势图实时进度（第 current/total 张） */
export function poseProgressFromEvents(events: AiPipelineEvent[]): AiPoseProgress | null {
  const img = events.filter((e) => e.stage === 'image' && typeof e.index === 'number');
  if (!img.length) return null;
  const total = new Set(img.map((e) => e.index)).size;
  if (!total) return null;
  const doneSet = new Set(img.filter((e) => e.status === 'done').map((e) => e.index));
  const running = img.some((e) => e.status === 'running');
  const current = Math.min(total, doneSet.size + (running ? 1 : 0));
  return {
    current,
    total,
    status: doneSet.size >= total ? 'done' : running ? 'running' : 'pending',
  };
}

/** 当前阶段：优先 running，其次 error，再次最后一个 done，缺省首个阶段 */
export function currentPipelineStage(
  result: Pick<AiPipelineStatusResult, 'stages' | 'mode'>,
): AiPipelineStage {
  const order: AiPipelineStage[] =
    result.mode === 'analyze-only' ? ['analyze'] : ['analyze', 'image', 'silhouette'];
  const running = order.find((s) => result.stages[s]?.status === 'running');
  if (running) return running;
  const errored = order.find((s) => result.stages[s]?.status === 'error');
  if (errored) return errored;
  const lastDone = [...order].reverse().find((s) => result.stages[s]?.status === 'done');
  return lastDone ?? order[0]!;
}

/** job 产物（base64）→ File[]（按 index 升序，剪影需与姿势图同序） */
export function pipelineFiles(files: AiPipelinePoseFile[]): Array<{ index: number; file: File }> {
  return [...files]
    .sort((a, b) => a.index - b.index)
    .map((f) => ({
      index: f.index,
      file: base64ToFile(f.base64, f.mimeType, `ai-pipeline-${Date.now()}-${f.index}.png`),
    }));
}

/** job 结果 → 既有「识别详情」弹窗所需结构 */
export function toAnalyzeDetail(result: AiPipelineStatusResult): AiAnalyzeStatusResult {
  const err = result.error;
  return {
    taskId: result.jobId,
    status: result.status,
    draft: result.draft ?? undefined,
    warnings: result.warnings,
    trace: result.trace,
    raw: result.raw ?? undefined,
    research: result.research,
    researchBrief: result.researchBrief,
    researchImages: result.researchImages,
    researchVision: result.researchVision,
    events: toRecogEvents(result.events),
    lastSeq: result.lastSeq,
    error: err ? `${err.message}${err.upstream ? `（上游：${err.upstream}）` : ''}` : undefined,
  };
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `cd lumira-server/packages/admin; pnpm test -- pipeline-task`
Expected: PASS（全部用例绿）

- [ ] **Step 5: 提交**

```bash
git add lumira-server/packages/admin/src/lib/pipeline-task.ts lumira-server/packages/admin/src/lib/__tests__/pipeline-task.test.ts
git commit -m "feat(admin): add AI pipeline polling/retry/event-adaptation helpers"
```

---

## Task 12: 新增 `src/lib/ai-job-storage.ts`（localStorage 单键）

**Files:**
- Create: `lumira-server/packages/admin/src/lib/ai-job-storage.ts`

**Interfaces:**
- Consumes: Task 7 的 `AiPipelineJobMode`
- Produces（Task 14 依赖）：`AiJobRef` / `saveJobRef(ref)` / `readJobRef()` / `clearJobRef()`

- [ ] **Step 1: 实现**

创建 `src/lib/ai-job-storage.ts`：

```ts
// src/lib/ai-job-storage.ts
// 在浏览器 localStorage 记一个「进行中的 AI 流水线 job」引用，供页面刷新后恢复/续跑。
// 单键设计：同一时间只允许一个进行中的 job（换图/重开流程会覆盖）。
'use client';

import type { AiPipelineJobMode } from '@/types/admin';

const STORAGE_KEY = 'lumira.aiCreateJob';

export interface AiJobRef {
  jobId: string;
  mode: AiPipelineJobMode;
  savedAt: number;
}

export function saveJobRef(ref: { jobId: string; mode: AiPipelineJobMode }): void {
  if (typeof window === 'undefined') return;
  try {
    const payload: AiJobRef = { ...ref, savedAt: Date.now() };
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(payload));
  } catch {
    // 隐私模式/配额满：忽略（刷新恢复是增强，不影响主流程）
  }
}

export function readJobRef(): AiJobRef | null {
  if (typeof window === 'undefined') return null;
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as Partial<AiJobRef>;
    if (typeof parsed?.jobId !== 'string' || !parsed.jobId) return null;
    return {
      jobId: parsed.jobId,
      mode: parsed.mode === 'analyze-only' ? 'analyze-only' : 'auto',
      savedAt: typeof parsed.savedAt === 'number' ? parsed.savedAt : Date.now(),
    };
  } catch {
    return null;
  }
}

export function clearJobRef(): void {
  if (typeof window === 'undefined') return;
  try {
    window.localStorage.removeItem(STORAGE_KEY);
  } catch {
    // 忽略
  }
}
```

- [ ] **Step 2: 类型检查**

Run: `cd lumira-server/packages/admin; npx tsc --noEmit`
Expected: 无 TS 错误

- [ ] **Step 3: 提交**

```bash
git add lumira-server/packages/admin/src/lib/ai-job-storage.ts
git commit -m "feat(admin): persist in-flight AI pipeline job ref in localStorage"
```

---

## Task 13: 新增 `src/components/ai-create/interruption-banner.tsx`

**Files:**
- Create: `lumira-server/packages/admin/src/components/ai-create/interruption-banner.tsx`

**Interfaces:**
- Consumes: Task 7 的 `AiInterruptionInfo` / `AiInterruptionCode`；Task 11 的 `pipelineStageLabel` / `isRetryablePipelineError`；既有 `Button`（`@/components/ui/button`）、`formatSec`（`@/lib/ai-task`）
- Produces（Task 14 依赖）：`InterruptionBanner`

- [ ] **Step 1: 实现**

创建 `src/components/ai-create/interruption-banner.tsx`：

```tsx
'use client';

// src/components/ai-create/interruption-banner.tsx
// 断点详情横幅：分类错误码 + 阶段 + 耗时 + 上游原文 + 处置建议，并提供「继续 / 重新开始 / 放弃」。
// 「继续」= 优先重连（后端仍在跑/已完成），否则从失败阶段重跑并复用已完成成果（后端 resume 语义）。

import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { formatSec } from '@/lib/ai-task';
import { isRetryablePipelineError, pipelineStageLabel } from '@/lib/pipeline-task';
import type { AiInterruptionInfo } from '@/types/admin';

export function InterruptionBanner({
  info,
  resuming,
  onResume,
  onRestart,
  onDismiss,
}: {
  info: AiInterruptionInfo;
  /** 「继续」请求中（按钮置灰防重复点击） */
  resuming?: boolean;
  onResume: () => void;
  onRestart: () => void;
  onDismiss: () => void;
}) {
  const [showUpstream, setShowUpstream] = useState(false);
  const retryable = isRetryablePipelineError(info.code);

  return (
    <div className="rounded-md border border-destructive/50 bg-destructive/10 p-4 text-sm text-destructive">
      <div className="flex flex-wrap items-center gap-2 font-medium">
        <span>生成中断（{pipelineStageLabel(info.stage)}）</span>
        <code className="rounded bg-destructive/15 px-1.5 py-0.5 text-[11px] font-mono">{info.code}</code>
        {typeof info.elapsedMs === 'number' && (
          <span className="text-xs opacity-80">该阶段已耗时 {formatSec(info.elapsedMs)}</span>
        )}
        {info.failedIndexes && info.failedIndexes.length > 0 && (
          <span className="text-xs opacity-80">
            失败项 #{info.failedIndexes.map((i) => i + 1).join('、')}
          </span>
        )}
      </div>

      <p className="mt-2 whitespace-pre-wrap">{info.message}</p>

      {info.hint && <p className="mt-1 text-xs opacity-90">建议：{info.hint}</p>}

      {(info.upstream || typeof info.status === 'number') && (
        <div className="mt-2">
          <button
            type="button"
            className="text-xs underline underline-offset-2"
            onClick={() => setShowUpstream((v) => !v)}
          >
            {showUpstream ? '收起上游原始信息' : '查看上游原始信息'}
          </button>
          {showUpstream && (
            <pre className="mt-1 max-h-40 overflow-auto whitespace-pre-wrap break-all rounded bg-background/60 p-2 text-[11px] text-foreground">
              {typeof info.status === 'number' ? `HTTP ${info.status}\n` : ''}
              {info.upstream || '（无）'}
            </pre>
          )}
        </div>
      )}

      <div className="mt-3 flex flex-wrap items-center gap-2">
        {retryable ? (
          <Button size="sm" disabled={resuming} onClick={onResume}>
            {resuming ? '继续中…' : '继续'}
          </Button>
        ) : (
          <Button size="sm" disabled={resuming} onClick={onRestart}>
            重新开始
          </Button>
        )}
        {retryable && (
          <Button size="sm" variant="outline" disabled={resuming} onClick={onRestart}>
            重新开始
          </Button>
        )}
        <Button size="sm" variant="ghost" disabled={resuming} onClick={onDismiss}>
          放弃本次生成
        </Button>
      </div>
    </div>
  );
}
```

> 注：任务失效（`job_missing`）与入参错误（`payload_too_large` / `invalid_input`）不可续跑，Banner 主按钮直接变为「重新开始」；其余情况主按钮为「继续」（重连/重跑失败阶段）。

- [ ] **Step 2: 类型检查**

Run: `cd lumira-server/packages/admin; npx tsc --noEmit`
Expected: 无 TS 错误

- [ ] **Step 3: 提交**

```bash
git add lumira-server/packages/admin/src/components/ai-create/interruption-banner.tsx
git commit -m "feat(admin): add AI pipeline interruption banner with resume"
```

---

## Task 14: `wizard.tsx` 两入口改走 pipeline + 断点继续 + 刷新恢复

**Files:**
- Modify: `lumira-server/packages/admin/src/components/ai-create/wizard.tsx`

**Interfaces:**
- Consumes: Task 11 的 `startPipelineJob` / `pollPipelineJob` / `resumePipelineJob` / `cancelPipelineJob` / `fetchPipelineStatus` / `interruptionFromPollError` / `toRecogEvents` / `toPoseEvents` / `toAnalyzeDetail` / `currentPipelineStage` / `poseProgressFromEvents` / `pipelineFiles` / `pipelineStageLabel` / `PipelinePollError`；Task 12 的 `saveJobRef` / `readJobRef` / `clearJobRef`；Task 13 的 `InterruptionBanner`（`base64ToFile` 由 `pipelineFiles` 内部使用，wizard 不直接 import）
- Produces: 无（叶子改动）

**说明：** 本任务只替换 wizard 中「识别提交 / 全自动执行」两条链路为 pipeline job 驱动，并新增断点 Banner 与刷新恢复；Step3 手动生成封面、Step4 手动剪影仍走**既有未改动**的 `step-cover.tsx` / `step-silhouette.tsx`。

- [ ] **Step 1: 替换 import 块**

把 `src/components/ai-create/wizard.tsx` 顶部的这段导入：

```ts
import {
  aiAnalyzeStartAction,
  getAiConfigAction,
} from '@/actions/ai';
import { generateAiPoseImages, generateAiSilhouettes, pollAiAnalyzeTask, type AiPoseProgress } from '@/lib/ai-task';
import type { TemplateCategory, AiAnalyzeTraceEntry, AiAnalyzeStatusResult, AiTraceEvent, AiBatchImageTraceEvent } from '@/types/admin';
```

替换为：

```ts
import {
  getAiConfigAction,
} from '@/actions/ai';
import { type AiPoseProgress } from '@/lib/ai-task';
import {
  cancelPipelineJob,
  currentPipelineStage,
  fetchPipelineStatus,
  interruptionFromPollError,
  pipelineFiles,
  pipelineStageLabel,
  PipelinePollError,
  pollPipelineJob,
  poseProgressFromEvents,
  resumePipelineJob,
  startPipelineJob,
  toAnalyzeDetail,
  toPoseEvents,
  toRecogEvents,
} from '@/lib/pipeline-task';
import { clearJobRef, readJobRef, saveJobRef } from '@/lib/ai-job-storage';
import { InterruptionBanner } from './interruption-banner';
import type {
  TemplateCategory,
  AiAnalyzeTraceEntry,
  AiAnalyzeStatusResult,
  AiBatchImageTraceEvent,
  AiInterruptionInfo,
  AiPipelineEvent,
  AiPipelineJobMode,
  AiPipelineStage,
  AiPipelineStatusResult,
  AiTraceEvent,
} from '@/types/admin';
```

- [ ] **Step 2: 追加状态与阶段映射**

在 `AutoStage` / `AUTO_STAGES` / `AUTO_STAGE_TEXT` 定义（约 L51-59）之后追加：

```ts
/** AiPipelineStage → 全自动进度条阶段文案键 */
const AUTO_STAGE_OF: Record<AiPipelineStage, AutoStage> = {
  analyze: 'analyzing',
  image: 'generating-image',
  silhouette: 'generating-silhouette',
};
```

在组件内 `poseTraceRunning` 状态（约 L105）之后追加：

```ts
  /** 进行中的 pipeline jobId（断点续跑与刷新恢复的锚点） */
  const [jobId, setJobId] = useState<string | null>(null);
  /** 本次 job 的模式（决定识别完成后如何应用产物） */
  const [jobMode, setJobMode] = useState<AiPipelineJobMode>('auto');
  /** 当前 pipeline 阶段（喂进度文案） */
  const [pipelineStage, setPipelineStage] = useState<AiPipelineStage | null>(null);
  /** 中断详情（非空 = 展示断点 Banner 与「继续」） */
  const [interruption, setInterruption] = useState<AiInterruptionInfo | null>(null);
  /** 「继续」请求中 */
  const [resuming, setResuming] = useState(false);
  /** abort 时记录当前阶段（供异常合成为中断详情） */
  const stageRef = useRef<AiPipelineStage>('analyze');
```

- [ ] **Step 3: `resetFlow` 增加清理**

`resetFlow`（约 L178-197）函数体末尾（`setStep(1); setMaxStep(1);` 之后）追加：

```ts
    setJobId(null);
    setPipelineStage(null);
    setInterruption(null);
    setResuming(false);
    clearJobRef();
```

- [ ] **Step 4: 替换 `handleAnalyze` 为 analyze-only job**

把整个 `handleAnalyze` 函数（约 L266-318，从 `/** 手动识别：成功后草稿回填 ... */` 到其结束 `};`）替换为：

```tsx
  /** 组装 pipeline 提交表单（识别/全自动共用：示例图 + 文字 + 附加输入 + 参考图 + jobMode/剪影选项） */
  const buildPipelineFormData = (mode: AiPipelineJobMode): FormData => {
    const fd = new FormData();
    for (const f of exampleFiles) fd.append('image', f);
    if (inputText.trim()) fd.set('text', inputText.trim());
    setAnalyzeExtras(fd);
    fd.set('jobMode', mode);
    if (mode === 'auto') {
      for (const f of poseReferenceFiles) fd.append('reference', f);
      fd.set('silMode', 'sketch');
      fd.set('silCrop', '1');
      fd.set('silEngine', aiSilhouetteAvailable ? 'ai' : 'local');
    }
    return fd;
  };

  /** 把 job 增量事件分流到两个 Tab 并更新阶段/进度（两入口共用） */
  const drivePipelineEvents = (events: AiPipelineEvent[]) => {
    setTraceEvents(toRecogEvents(events));
    setPoseTraceEvents(toPoseEvents(events));
    const p = poseProgressFromEvents(events);
    if (p) setPoseProgress(p);
  };

  /** 把识别产物回填草稿/研究过程（返回是否有草稿） */
  const applyAnalyze = (res: AiPipelineStatusResult): boolean => {
    if (!res.draft) return false;
    setDraft(res.draft);
    setWarnings(res.warnings ?? []);
    setTrace(res.trace ?? []);
    setAnalyzeDetail(toAnalyzeDetail(res));
    return true;
  };

  /** 识别完成 → 示例图作默认封面候选并回填表单（纯文模式候选为空） */
  const finishAnalyzeOnly = (res: AiPipelineStatusResult) => {
    if (!applyAnalyze(res)) {
      setErrorText('识别结果为空，请重试');
      return;
    }
    if (exampleFiles.length > 0) {
      setCandidates(
        exampleFiles.map((f, i) => ({
          id: i === 0 ? 'example' : `example-${i}`,
          file: f,
          url: URL.createObjectURL(f),
          source: 'example',
        })),
      );
      inject({ json: res.draft!, images: exampleFiles, replaceImages: true });
    } else {
      setCandidates([]);
      inject({ json: res.draft! });
    }
    setFormActivated(true);
    setJobId(null);
    setPipelineStage(null);
    setInterruption(null);
    clearJobRef();
    goto(2);
  };

  /** 手动识别（analyze-only job）：只产出草稿，后续步骤走既有手动端点 */
  const handleAnalyze = async () => {
    if (!hasInput) return;
    setAnalyzing(true);
    setErrorText(null);
    setInterruption(null);
    setTraceEvents([]);
    setPoseTraceEvents([]);
    setProgressPanelHidden(false);
    setJobMode('analyze-only');
    stageRef.current = 'analyze';
    try {
      const jobIdLocal = await startPipelineJob(buildPipelineFormData('analyze-only'));
      setJobId(jobIdLocal);
      saveJobRef({ jobId: jobIdLocal, mode: 'analyze-only' });
      const res = await pollPipelineJob(jobIdLocal, {
        onEvents: drivePipelineEvents,
        // 内联 onStatus：避免引用 jobMode state 造成 stale closure（此时 jobMode 仍是上一次的值）
        onStatus: (r) => {
          const stage = currentPipelineStage(r);
          stageRef.current = stage;
          setPipelineStage(stage);
        },
      });
      if (res.status === 'error') {
        // 阶段失败：保留已完成草稿（若可用则允许直接进下一步），展示详细中断并提供「继续」
        if (applyAnalyze(res)) setFormActivated(true);
        setInterruption(res.error ?? interruptionFromPollError(new Error('识别失败'), currentPipelineStage(res)));
        const msg = res.error?.message || '识别失败';
        setErrorText(msg);
        toast({ variant: 'destructive', title: '识别中断', description: msg });
        return;
      }
      finishAnalyzeOnly(res);
    } catch (e) {
      const info = interruptionFromPollError(e, stageRef.current);
      setInterruption(info);
      setErrorText(info.message);
      toast({ variant: 'destructive', title: '识别失败', description: info.message });
    } finally {
      setAnalyzing(false);
    }
  };
```

- [ ] **Step 5: 替换 `runAutoAll` 为 auto job**

把整个 `runAutoAll` 函数（约 L320-480，从 `/** 全自动：识别 → 生图作封面 ... */` 到其结束 `};`）替换为：

```tsx
  /** 全自动 job 跑完后应用产物：候选封面 + 注入表单 + 剪影 + 触发提交 */
  const finishAuto = (res: AiPipelineStatusResult) => {
    if (!applyAnalyze(res)) {
      setAutoState(null);
      setErrorText('识别结果为空，请重试');
      return;
    }
    setFormActivated(true);
    const draftLocal = res.draft!;
    const exampleCandidates: CoverCandidate[] = exampleFiles.map((f, i) => ({
      id: i === 0 ? 'example' : `example-${i}`,
      file: f,
      url: URL.createObjectURL(f),
      source: 'example',
    }));
    const poseFiles = pipelineFiles(res.poseImages);
    if (poseFiles.length === 0) {
      setCandidates(exampleCandidates);
      if (exampleFiles.length > 0) inject({ json: draftLocal, images: exampleFiles, replaceImages: true });
      else inject({ json: draftLocal });
      goto(3);
      setAutoState({ running: false, stage: 'generating-image', error: '姿势图生成失败' });
      return;
    }
    const generatedCandidates: CoverCandidate[] = poseFiles.map((p) => ({
      id: `ai-${Date.now()}-${p.index}`,
      file: p.file,
      url: URL.createObjectURL(p.file),
      source: 'ai',
    }));
    setCandidates([...generatedCandidates, ...exampleCandidates]);
    inject({ json: draftLocal, images: poseFiles.map((p) => p.file), replaceImages: true });

    const silFiles = pipelineFiles(res.silhouetteImages);
    if (silFiles.length !== poseFiles.length) {
      goto(4);
      setAutoState({
        running: false,
        stage: 'generating-silhouette',
        error: res.silhouetteErrors[0]?.error || '部分剪影生成失败',
      });
      return;
    }
    setSilhouetteFile(silFiles[0]!.file);
    goto(5);
    setJobId(null);
    setPipelineStage(null);
    setInterruption(null);
    clearJobRef();
    setAutoState({ running: true, stage: 'submitting' });
    inject({ silhouettes: silFiles.map((p) => p.file), isActive: true, autoSubmit: true });
  };

  /** 全自动：一个 auto job 提交后只轮询（识别 → 姿势图 → 剪影 → 触发上架） */
  const runAutoAll = async () => {
    if (!hasInput) return;
    setErrorText(null);
    setInterruption(null);
    const controller = new AbortController();
    abortRef.current = controller;
    const { signal } = controller;
    setTraceEvents([]);
    setPoseTraceEvents([]);
    setPoseTraceRunning(false);
    setPoseProgress(null);
    setProgressPanelHidden(false);
    setJobMode('auto');
    stageRef.current = 'analyze';
    setPipelineStage('analyze');
    setAutoState({ running: true, stage: 'analyzing' });
    try {
      const jobIdLocal = await startPipelineJob(buildPipelineFormData('auto'));
      setJobId(jobIdLocal);
      saveJobRef({ jobId: jobIdLocal, mode: 'auto' });
      const res = await pollPipelineJob(jobIdLocal, {
        signal,
        onEvents: drivePipelineEvents,
        onStatus: (r) => {
          const stage = currentPipelineStage(r);
          stageRef.current = stage;
          setPipelineStage(stage);
          setAutoState({ running: true, stage: AUTO_STAGE_OF[stage] });
        },
      });
      if (res.status === 'error') {
        applyAnalyze(res);
        setFormActivated(true);
        const info = res.error ?? interruptionFromPollError(new Error('生成中断'), currentPipelineStage(res));
        setInterruption(info);
        const stage = currentPipelineStage(res);
        stageRef.current = stage;
        setAutoState({ running: false, stage: AUTO_STAGE_OF[stage], error: info.message });
        // 已生成的姿势图/剪影尽量保留在候选与表单里
        if (res.poseImages.length > 0) {
          const poseFiles = pipelineFiles(res.poseImages);
          const exampleCandidates: CoverCandidate[] = exampleFiles.map((f, i) => ({
            id: i === 0 ? 'example' : `example-${i}`,
            file: f,
            url: URL.createObjectURL(f),
            source: 'example',
          }));
          setCandidates([
            ...poseFiles.map((p) => ({
              id: `ai-${Date.now()}-${p.index}`,
              file: p.file,
              url: URL.createObjectURL(p.file),
              source: 'ai' as const,
            })),
            ...exampleCandidates,
          ]);
          inject({ json: res.draft!, images: poseFiles.map((p) => p.file), replaceImages: true });
          setFormActivated(true);
          // 已生成可用姿势图且失败在生图阶段：推进到封面选择步骤，让用户基于已产出图继续
          if (stage === 'image') goto(3);
        }
        toast({ variant: 'destructive', title: `生成中断（${info.code}）`, description: info.message });
        return;
      }
      finishAuto(res);
    } catch (e) {
      const aborted = e instanceof PipelinePollError && e.code === 'aborted';
      const info = interruptionFromPollError(e, stageRef.current);
      setInterruption(info);
      setAutoState({ running: false, stage: AUTO_STAGE_OF[stageRef.current], error: info.message });
      if (!aborted) {
        toast({
          variant: 'destructive',
          title: `全自动在「${AUTO_STAGE_TEXT[AUTO_STAGE_OF[stageRef.current]]}」阶段异常`,
          description: info.message,
        });
      }
    } finally {
      abortRef.current = null;
    }
  };

  /** 断点「继续」：优先重连（后端仍在跑），否则从失败阶段重跑并复用已完成成果 */
  const resumeFromInterruption = async () => {
    if (!jobId) return;
    setResuming(true);
    const wasAuto = jobMode === 'auto';
    const controller = new AbortController();
    abortRef.current = controller;
    try {
      // 后端语义：running → 仅重连；error → 从失败阶段重跑并复用已完成成果。前端只需要结果
      await resumePipelineJob(jobId);
      setInterruption(null);
      if (!wasAuto) setAnalyzing(true);
      else setAutoState({ running: true, stage: AUTO_STAGE_OF[stageRef.current] });
      const res = await pollPipelineJob(jobId, {
        signal: controller.signal,
        onEvents: drivePipelineEvents,
        onStatus: (s) => {
          const stage = currentPipelineStage(s);
          stageRef.current = stage;
          setPipelineStage(stage);
          if (wasAuto) setAutoState({ running: true, stage: AUTO_STAGE_OF[stage] });
        },
      });
      if (res.status === 'error') {
        applyAnalyze(res);
        const info = res.error ?? interruptionFromPollError(new Error('续跑中断'), currentPipelineStage(res));
        setInterruption(info);
        if (wasAuto) setAutoState({ running: false, stage: AUTO_STAGE_OF[currentPipelineStage(res)], error: info.message });
        else setErrorText(info.message);
        return;
      }
      if (wasAuto) finishAuto(res);
      else finishAnalyzeOnly(res);
    } catch (e) {
      const info = interruptionFromPollError(e, stageRef.current);
      setInterruption(info);
      if (wasAuto) setAutoState({ running: false, stage: AUTO_STAGE_OF[stageRef.current], error: info.message });
      else setErrorText(info.message);
    } finally {
      setResuming(false);
      setAnalyzing(false);
      abortRef.current = null;
    }
  };

  /** 放弃本次生成：删除后端 job + 清本地引用 + 重置流程 */
  const discardJob = async () => {
    if (jobId) {
      try {
        await cancelPipelineJob(jobId);
      } catch {
        // 删除失败不影响本地重置（后端有 1 小时 TTL 兜底）
      }
    }
    setInterruption(null);
    resetFlow();
  };
```

- [ ] **Step 6: 挂载时刷新恢复**

在 Step 5 新增的 `discardJob` 之后、`const stageIndex = …` 之前插入这个 useEffect（必须放在 `finishAuto` / `finishAnalyzeOnly` / `drivePipelineEvents` 等本地 const 之后，否则会触发 `no-use-before-define`）：

```tsx
  /** 挂载时恢复上次未完成的 job：running → 重连轮询；error → 展示断点；done → 回填后清理 */
  useEffect(() => {
    const ref = readJobRef();
    if (!ref) return;
    let cancelled = false;
    void (async () => {
      try {
        const res = await fetchPipelineStatus(ref.jobId, 0, true);
        if (cancelled) return;
        setJobId(ref.jobId);
        setJobMode(res.mode);
        const stage = currentPipelineStage(res);
        stageRef.current = stage;
        setPipelineStage(stage);
        if (res.mode === 'auto') setAutoState({ running: res.status === 'running', stage: AUTO_STAGE_OF[stage] });
        else setAnalyzing(res.status === 'running');
        drivePipelineEvents(res.events);
        if (res.status === 'error') {
          applyAnalyze(res);
          setInterruption(res.error ?? interruptionFromPollError(new Error('生成中断'), stage));
          return;
        }
        if (res.status === 'done') {
          if (res.mode === 'auto') finishAuto(res);
          else finishAnalyzeOnly(res);
          return;
        }
        // running：立即重连轮询（job 输入在后端，无需重传）
        const polled = await pollPipelineJob(ref.jobId, {
          onEvents: drivePipelineEvents,
          onStatus: (r) => {
            const s = currentPipelineStage(r);
            stageRef.current = s;
            setPipelineStage(s);
            if (res.mode === 'auto') setAutoState({ running: true, stage: AUTO_STAGE_OF[s] });
          },
        });
        if (cancelled) return;
        if (polled.status === 'error') {
          applyAnalyze(polled);
          setInterruption(polled.error ?? interruptionFromPollError(new Error('生成中断'), currentPipelineStage(polled)));
          return;
        }
        if (polled.mode === 'auto') finishAuto(polled);
        else finishAnalyzeOnly(polled);
      } catch (e) {
        if (cancelled) return;
        // 失效/网络等问题：保留 job 引用并展示断点，让用户决定「继续」或「重新开始」
        setJobId(ref.jobId);
        setJobMode(ref.mode);
        setInterruption(interruptionFromPollError(e, stageRef.current));
      } finally {
        if (!cancelled) {
          setAnalyzing(false);
          setAutoState((prev) => (prev ? { ...prev, running: false } : prev));
        }
      }
    })();
    return () => {
      cancelled = true;
    };
    // 仅在挂载时恢复一次（jobId 锚点来自 localStorage，不需要进依赖）
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
```

- [ ] **Step 7: 接线 Banner 到渲染**

把渲染里的既有失败块（约 L639-644）：

```tsx
        {autoState && !autoState.running && autoState.error && (
          <div className="rounded-md border border-destructive/50 bg-destructive/10 p-3 text-sm text-destructive">
            全自动在「{AUTO_STAGE_TEXT[autoState.stage]}」阶段失败：{autoState.error}
            。已停在当前步骤，可人工继续或调整后重试，已生成的草稿 / 封面已保留。
          </div>
        )}
```

替换为：

```tsx
        {interruption && !busy && (
          <InterruptionBanner
            info={interruption}
            resuming={resuming}
            onResume={resumeFromInterruption}
            onRestart={resetFlow}
            onDismiss={discardJob}
          />
        )}
        {autoState && !autoState.running && autoState.error && !interruption && (
          <div className="rounded-md border border-destructive/50 bg-destructive/10 p-3 text-sm text-destructive">
            全自动在「{AUTO_STAGE_TEXT[autoState.stage]}」阶段失败：{autoState.error}
            。已停在当前步骤，可人工继续或调整后重试，已生成的草稿 / 封面已保留。
          </div>
        )}
```

并把 `progressStatusText`（约 L500-512）改为优先反映 pipeline 阶段：

```tsx
  /** 面板收拢态展示的进度文案（运行中优先，缺省回落 Tab 计数；失败时显示「已失败」） */
  const progressStatusText = analyzing
    ? `正在识别…${pipelineStage ? `（${pipelineStageLabel(pipelineStage)}）` : ''}`
    : autoState?.running
      ? `进行中 · ${AUTO_STAGE_TEXT[autoState.stage]}${
          autoState.stage === 'generating-image' && poseProgress
            ? ` ${poseProgress.current}/${poseProgress.total}`
            : ''
        }`
      : interruption
        ? `已中断 · ${interruption.code}`
        : errorText
          ? '识别失败'
          : autoState?.error
            ? '已失败'
            : null;
```

- [ ] **Step 8: 类型检查 + 构建**

Run: `cd lumira-server/packages/admin; npx tsc --noEmit`
Expected: 无 TS 错误

Run: `cd lumira-server/packages/admin; pnpm test`
Expected: PASS（含 `pipeline-task.test.ts`）

Run: `cd lumira-server/packages/admin; pnpm build`
Expected: 构建成功（ESLint 的 `react-hooks/exhaustive-deps` 仅为 warning，不阻塞构建）

- [ ] **Step 9: 提交**

```bash
git add lumira-server/packages/admin/src/components/ai-create/wizard.tsx
git commit -m "feat(admin): drive AI create wizard via resumable pipeline job"
git push origin master
git push github master
```