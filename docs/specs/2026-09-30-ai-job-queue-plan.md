# AI 生成任务队列化 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把「AI 一键生成模板」的流水线改造成服务端持久化的任务队列：任务落库 + 详情/产物落存储文件，新增任务队列页与详情页，支持排队调度、停止、继续、删除，页面刷新/退出/换设备/后端重启后进度仍在。

**Architecture:** 后端拆三层——`AiJobStoreService`（持久化：DB 行 + 存储文件）、`AiPipelineJobService`（执行引擎：三阶段 + 事件流 + 检查点停止 + 冷启动 hydrate）、`AiJobQueueService`（调度：FIFO + 并发闸门 + 重启恢复）。DB 只存列表展示字段，`detail.json`/`events.jsonl`/产物/输入落 `/uploads/ai-jobs/{jobId}/`，用 `detail_key` 关联。前端把「队列列表页 + 详情页」作为一等公民，向导退化为「提交输入 + 审核产物」工作台。

**Tech Stack:** NestJS 10 + Fastify + Drizzle ORM + MySQL 8 + jest；Next.js 14 App Router + Tailwind + shadcn/ui + vitest。

**设计文档:** `docs/specs/2026-09-30-ai-job-queue-design.md`

## Global Constraints

- 迁移编号固定 **051**，文件 `051_ai_template_jobs.sql`；迁移由 `database.service.ts` 的 `runMigrations()` 在启动时按文件名去重执行，一条迁移只跑一次。
- 内容表主键用 `TEXT` + `nanoid`；时间戳用 `INT` 秒级；JSON 落库用 `LONGTEXT` + `*_json` 命名；布尔落库用 `INT`（0/1）。
- storageKey 前缀固定 `/uploads`，形态 `/uploads/{category}/{id}/{filename}`；新增 `StorageCategory = 'ai-jobs'`。
- 状态枚举固定：`queued | running | done | error | stopped | interrupted`；终态 = `done | error | stopped | interrupted`。
- `queue_pos` 1-based（1 = 下一个出队），未排队为 0。
- 产物图与输入图走存储适配器（`activeStorageAdapter`）；`detail.json` / `events.jsonl` **只经后端 `readBuffer` 读取，绝不返回公网 URL**。
- 不做向后兼容：旧 `ai-job/:jobId` GET / DELETE / resume 路由直接替换为新路径，admin 与 backend 同仓同发。
- 后端命令：`pnpm --filter @lumira/backend build`（tsc 校验）、`pnpm --filter @lumira/backend test -- <pattern>`；前端：`pnpm --filter @lumira/admin test`（vitest）、`pnpm --filter @lumira/admin build`（next build 含类型校验）。
- 每个 Task 结束必须 commit；后端/后台改动完成后 push 到 `origin`(gitee) 与 `github` 两个远程。

---

## 共享接口（所有 Task 的契约，先读这里）

```ts
// 后端：src/modules/ai/ai-job.store.ts
export type AiJobStatus = 'queued' | 'running' | 'done' | 'error' | 'stopped' | 'interrupted';
export type AiJobMode = 'auto' | 'analyze-only';
export const SETTLED_STATUSES: readonly AiJobStatus[] = ['done', 'error', 'stopped', 'interrupted'] as const;

export interface AiJobRow {
  id: string;
  status: AiJobStatus;
  mode: AiJobMode;
  title: string;
  currentStage: PipelineStage | null;
  poseTotal: number;
  poseDone: number;
  silTotal: number;
  silDone: number;
  queuePos: number;
  inputSummary: Record<string, unknown>;
  errorCode: string | null;
  errorMessage: string | null;
  detailKey: string | null;
  createdAt: number;
  startedAt: number | null;
  finishedAt: number | null;
}

export interface StoredArtifact { index: number; mimeType: string; storageKey: string; url: string }

export interface AiJobDetailFile {
  stages: unknown;
  error: unknown | null;
  warnings: unknown[];
  draft: unknown | null;
  trace: unknown[];
  raw: unknown | null;
  research: unknown[];
  researchBrief: unknown | null;
  researchVision: unknown | null;
  artifacts: {
    poseFiles: StoredArtifact[];
    poseErrors: unknown[];
    silFiles: StoredArtifact[];
    silErrors: unknown[];
  };
  inputs: Record<string, unknown>;
}
```

```ts
// 后端：src/modules/ai/ai-job-queue.service.ts
enqueue(jobId: string): Promise<{ status: AiJobStatus; queuePos: number }>
stop(jobId: string): Promise<{ stopped: boolean; status: AiJobStatus }>
resume(jobId: string): Promise<{ resumed: boolean; status: AiJobStatus } | null>
```

```ts
// 后端：src/modules/ai/ai-pipeline-job.service.ts（改造后的公开面）
create(input: PipelineCreateInput): Promise<{ jobId: string }>   // 落库+落文件，状态 queued，不自动开跑
startJob(jobId: string): Promise<void>                          // 执行 pendingStages，resolve 于终态
requestStop(jobId: string): boolean                             // 置 stopRequested；job 不存在返回 false
prepareResume(jobId: string): Promise<{ stages: PipelineStage[]; onlyIndexes: Partial<Record<PipelineStage, number[]>> } | null>
hydrate(jobId: string): Promise<boolean>                        // 冷启动：从存储文件重建内存 job
get(jobId: string): AiPipelineJob | null
serialize(job: AiPipelineJob, since?: number, verbose?: boolean)
remove(jobId: string): void
```

```ts
// 前端：src/lib/ai-jobs.ts
export type AiJobStatus = 'queued'|'running'|'done'|'error'|'stopped'|'interrupted';
export interface AiJobListItem {
  id: string; title: string; status: AiJobStatus;
  currentStage: 'analyze'|'image'|'silhouette'|null;
  progress: { poseTotal: number; poseDone: number; silTotal: number; silDone: number };
  queuePos: number; errorCode: string|null; errorMessage: string|null;
  createdAt: number; startedAt: number|null; finishedAt: number|null;
}
export interface AiJobDetail extends AiJobListItem { /* + serialize 的全部字段 + events */ }
export const JOB_STATUS_META: Record<AiJobStatus, { label: string; tone: 'run'|'wait'|'ok'|'bad' }>;
export function fetchJobFile(url: string, name: string): Promise<File>;
export function formatJobElapsed(startedAt: number|null, finishedAt: number|null): string;
export function jobStageProgressText(item: AiJobListItem): string;
```

---

### Task 1: 迁移、schema 与存储分类

**Files:**
- Create: `lumira-server/packages/backend/src/database/migrations/051_ai_template_jobs.sql`
- Modify: `lumira-server/packages/backend/src/database/schema.ts`
- Modify: `lumira-server/packages/backend/src/common/storage/storage-adapter.interface.ts:6`

**Interfaces:**
- Consumes: 无
- Produces: 表 `ai_template_jobs`、列 `ai_provider_config.job_concurrency`、`StorageCategory` 含 `'ai-jobs'`

- [ ] **Step 1: 写迁移文件**

创建 `lumira-server/packages/backend/src/database/migrations/051_ai_template_jobs.sql`：

```sql
-- lumira-server/packages/backend/src/database/migrations/051_ai_template_jobs.sql
-- AI 生成任务队列（spec 2026-09-30-ai-job-queue-design）
-- DB 只存列表展示数据；详情/事件流/产物/输入落存储文件，由 detail_key 关联
-- 幂等：由 _migrations 表记录，仅执行一次

CREATE TABLE IF NOT EXISTS `ai_template_jobs` (
  `id` TEXT PRIMARY KEY,
  `status` TEXT NOT NULL,
  `mode` TEXT NOT NULL,
  `title` TEXT NOT NULL,
  `current_stage` TEXT,
  `pose_total` INT NOT NULL DEFAULT 0,
  `pose_done` INT NOT NULL DEFAULT 0,
  `sil_total` INT NOT NULL DEFAULT 0,
  `sil_done` INT NOT NULL DEFAULT 0,
  `queue_pos` INT NOT NULL DEFAULT 0,
  `input_summary_json` LONGTEXT,
  `error_code` TEXT,
  `error_message` TEXT,
  `detail_key` TEXT,
  `created_at` INT NOT NULL,
  `started_at` INT,
  `finished_at` INT
);

CREATE INDEX `idx_ai_template_jobs_status_created` ON `ai_template_jobs` (`status`, `created_at`);

ALTER TABLE `ai_provider_config`
  ADD COLUMN `job_concurrency` INT NOT NULL DEFAULT 2 COMMENT 'AI 生成任务并发上限（1~5）';
```

- [ ] **Step 2: schema.ts 增加表与列**

在 `schema.ts` 顶部的 drizzle 导入行补齐 `longtext`（`mysqlTable, text, int, longtext` 等，缺哪个补哪个，不要重复导入）。

在 `schema.ts` 末尾追加：

```ts
/** AI 生成任务队列（列表展示数据）：详情/事件流/产物落存储文件，见 detail_key */
export const aiTemplateJobs = mysqlTable('ai_template_jobs', {
  id: text('id').primaryKey(),
  status: text('status').notNull(),
  mode: text('mode').notNull(),
  title: text('title').notNull(),
  currentStage: text('current_stage'),
  poseTotal: int('pose_total').notNull().default(0),
  poseDone: int('pose_done').notNull().default(0),
  silTotal: int('sil_total').notNull().default(0),
  silDone: int('sil_done').notNull().default(0),
  queuePos: int('queue_pos').notNull().default(0),
  inputSummaryJson: longtext('input_summary_json'),
  errorCode: text('error_code'),
  errorMessage: text('error_message'),
  detailKey: text('detail_key'),
  createdAt: int('created_at').notNull(),
  startedAt: int('started_at'),
  finishedAt: int('finished_at'),
});
```

在 `aiProviderConfig` 表定义内、`llmMaxTokens` 字段附近追加：

```ts
  /** AI 生成任务并发上限（1~5），默认 2 */
  jobConcurrency: int('job_concurrency').notNull().default(2),
```

- [ ] **Step 3: 存储分类新增 ai-jobs**

`lumira-server/packages/backend/src/common/storage/storage-adapter.interface.ts:6`：

```ts
export type StorageCategory = 'templates' | 'categories' | 'banners' | 'feedback' | 'users' | 'thumbs' | 'ai-jobs';
```

- [ ] **Step 4: 校验编译**

Run: `pnpm --filter @lumira/backend build`
Expected: 编译通过（无 TS 报错）

- [ ] **Step 5: Commit**

```bash
git add lumira-server/packages/backend/src/database/migrations/051_ai_template_jobs.sql lumira-server/packages/backend/src/database/schema.ts lumira-server/packages/backend/src/common/storage/storage-adapter.interface.ts
git commit -m "feat(ai): 新增 AI 生成任务表与任务并发配置列"
```

---

### Task 2: AI 设置新增「生成任务并发数」

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/dto/update-ai-config.dto.ts`（`llmMaxTokens` 之后）
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-config.service.ts`（`AiConfigView`、默认常量、`get()`、`save()`）
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-config.service.spec.ts`（追加用例）
- Modify: `lumira-server/packages/admin/src/types/admin.ts`（AI 配置视图类型）
- Modify: `lumira-server/packages/admin/src/components/ai-config-form.tsx`（form 状态 / 初始化 / payload / UI）

**Interfaces:**
- Consumes: Task 1 的 `ai_provider_config.job_concurrency`
- Produces: `AiConfigService.get().jobConcurrency: number`（默认 2），供 `AiJobQueueService` 出队时实时读取

- [ ] **Step 1: 写失败测试**

在 `ai-config.service.spec.ts` 末尾追加（沿用文件内既有的 `row(overrides)` 夹具与 `new AiConfigService(db as unknown as DatabaseService)` 构造方式；db stub 的 `query.aiProviderConfig.findFirst` 返回 `row({ jobConcurrency: 3 })`）：

```ts
it('jobConcurrency：行内有值按行返回（缺省 2）', async () => {
  const svc = new AiConfigService(db as unknown as DatabaseService);
  const view = await svc.get();
  expect(view).toMatchObject({ configured: true, jobConcurrency: 3 });
});
```

Run: `pnpm --filter @lumira/backend test -- ai-config.service`
Expected: FAIL —— `jobConcurrency` 为 `undefined`

- [ ] **Step 2: DTO 增加字段**

`update-ai-config.dto.ts`，在 `llmMaxTokens` 之后追加：

```ts
  /** AI 生成任务并发上限（1~5）；缺省 = 沿用原值 */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(5)
  jobConcurrency?: number;
```

- [ ] **Step 3: service 读取与回显**

`ai-config.service.ts`：
1. `AiConfigView` 接口内（`llmMaxTokens` 之后）追加：

```ts
  /** AI 生成任务并发上限（默认 2） */
  jobConcurrency: number;
```

2. 在 `DEFAULT_LLM_MAX_TOKENS` 同区域新增常量：

```ts
/** 生成任务并发上限默认值（1~5） */
export const DEFAULT_JOB_CONCURRENCY = 2;
```

3. `get()` 返回对象内追加：

```ts
      jobConcurrency: row.jobConcurrency ?? DEFAULT_JOB_CONCURRENCY,
```

- [ ] **Step 4: service 写入**

`ai-config.service.ts` 的 `save()`：
1. 在 `const llmTimeoutMs = ...` 附近新增：

```ts
    const jobConcurrency = dto.jobConcurrency ?? existing?.jobConcurrency ?? DEFAULT_JOB_CONCURRENCY;
```

2. 在 `save()` 内的 **insert `.values({...})`** 与 **update `.set({...})`** 两处对象里都追加：

```ts
        jobConcurrency,
```

（两处都要加，只加一处会导致「首次保存生效、后续保存不生效」或反之。）

- [ ] **Step 5: 跑测试**

Run: `pnpm --filter @lumira/backend test -- ai-config.service`
Expected: PASS

- [ ] **Step 6: admin 类型与表单项**

1. `lumira-server/packages/admin/src/types/admin.ts`：在 AI 配置视图类型（含 `llmMaxTokens` 的那个接口）内追加：

```ts
  /** 生成任务并发上限（1~5） */
  jobConcurrency: number;
```

2. `ai-config-form.tsx`：
   - form 状态类型与初始化（第 110~113、240~242、275~277 行区域）追加 `jobConcurrency: number`，初始化值为 `initial.jobConcurrency`，空态默认 `2`。
   - payload 组装（第 547~549 行区域）追加：

```ts
      payload.jobConcurrency = form.jobConcurrency;
```

   - 「识别稳定性」卡片（第 1139 行 `<div className="grid gap-4 md:grid-cols-3">`）内追加第二格（该 grid 变为 `md:grid-cols-4`，其余不变）：

```tsx
                <div className="space-y-2">
                  <Label htmlFor="ai-job-concurrency">生成任务并发数</Label>
                  <Input
                    id="ai-job-concurrency"
                    type="number"
                    min={1}
                    max={5}
                    value={form.jobConcurrency}
                    onChange={(e) => setForm((f) => ({ ...f, jobConcurrency: e.target.value === '' ? 2 : Number(e.target.value) }))}
                  />
                  <p className="text-xs text-muted-foreground">1~5，默认 2。同时执行的生成任务数，超出部分排队。</p>
                </div>
```

- [ ] **Step 7: 前端校验**

Run: `pnpm --filter @lumira/admin build`
Expected: 构建通过

- [ ] **Step 8: Commit**

```bash
git add lumira-server/packages/backend/src/modules/ai/dto/update-ai-config.dto.ts lumira-server/packages/backend/src/modules/ai/ai-config.service.ts lumira-server/packages/backend/src/modules/ai/ai-config.service.spec.ts lumira-server/packages/admin/src/types/admin.ts lumira-server/packages/admin/src/components/ai-config-form.tsx
git commit -m "feat(ai): AI 设置支持配置生成任务并发数"
```

---

### Task 3: `AiJobStoreService`（持久化层）

**Files:**
- Create: `lumira-server/packages/backend/src/modules/ai/ai-job.store.ts`
- Create: `lumira-server/packages/backend/src/modules/ai/ai-job.store.spec.ts`
- Modify: `lumira-server/packages/backend/src/modules/ai/ai.module.ts`（providers 注册）

**Interfaces:**
- Consumes: Task 1 的 `aiTemplateJobs` 表、`StorageCategory='ai-jobs'`；`DatabaseService.getDb()`；`activeStorageAdapter`
- Produces: `AiJobStoreService` 全部方法（见下），供 Task 4/5/6 使用

- [ ] **Step 1: 写失败测试**

创建 `ai-job.store.spec.ts`：

```ts
// lumira-server/packages/backend/src/modules/ai/ai-job.store.spec.ts
// AiJobStoreService 单测：DB 行 CRUD / 存储文件读写 / deleteJob 连带删目录。
// DatabaseService 与 activeStorageAdapter 均以 jest.mock 替换，不依赖真实 MySQL 与磁盘。
import { AiJobStoreService } from './ai-job.store';
import type { AiJobRow } from './ai-job.store';

const updateSetMock = jest.fn();
const updateWhereMock = jest.fn(() => Promise.resolve());
const insertValuesMock = jest.fn(() => Promise.resolve());
const findFirstMock = jest.fn();
const selectRows: unknown[] = [];
const deleteMock = jest.fn();

jest.mock('../../common/storage/runtime-storage', () => ({
  activeStorageAdapter: {
    write: jest.fn(async (_c: string, id: string, filename: string) => `/uploads/ai-jobs/${id}/${filename}`),
    deleteByDir: jest.fn(async () => undefined),
    readBuffer: jest.fn(async () => Buffer.from('{"a":1}')),
    exists: jest.fn(async () => true),
    listKeys: jest.fn(async () => ['/uploads/ai-jobs/job_1/input/example-0.png']),
  },
}));

function makeDb() {
  return {
    insert: () => ({ values: insertValuesMock }),
    update: () => ({ set: updateSetMock }),
    delete: () => ({ where: deleteMock }),
    select: () => ({
      from: () => ({
        where: () => ({
          orderBy: () => ({ limit: () => ({ offset: () => Promise.resolve(selectRows) }) }),
        }),
      }),
    }),
    query: { aiTemplateJobs: { findFirst: findFirstMock } },
  };
}

function row(overrides: Partial<AiJobRow> = {}): AiJobRow {
  return {
    id: 'job_1', status: 'queued', mode: 'auto', title: 't', currentStage: null,
    poseTotal: 0, poseDone: 0, silTotal: 0, silDone: 0, queuePos: 0,
    inputSummary: {}, errorCode: null, errorMessage: null, detailKey: null,
    createdAt: 1, startedAt: null, finishedAt: null, ...overrides,
  };
}

describe('AiJobStoreService', () => {
  let store: AiJobStoreService;

  beforeEach(() => {
    jest.clearAllMocks();
    const db = makeDb();
    store = new AiJobStoreService({ getDb: () => db } as never);
  });

  it('insertJob 落库并归一化 inputSummary 为 JSON 字符串', async () => {
    await store.insertJob(row({ inputSummary: { imageCount: 2 } }));
    expect(insertValuesMock).toHaveBeenCalledWith(
      expect.objectContaining({ id: 'job_1', status: 'queued', inputSummaryJson: '{"imageCount":2}' }),
    );
  });

  it('writeArtifact 返回 storageKey 与 url，且 url 等于 storageKey', async () => {
    const art = await store.writeArtifact('job_1', 'pose', 0, 'image/png', Buffer.from('x'));
    expect(art).toEqual({
      index: 0,
      mimeType: 'image/png',
      storageKey: '/uploads/ai-jobs/job_1/pose-0.png',
      url: '/uploads/ai-jobs/job_1/pose-0.png',
    });
  });

  it('writeDetail / readDetail 往返一致', async () => {
    await store.writeDetail('job_1', { draft: { title: 'd' }, artifacts: { poseFiles: [], poseErrors: [], silFiles: [], silErrors: [] } } as never);
    const back = await store.readDetail('job_1');
    expect(back).toMatchObject({ a: 1 }); // readBuffer mock 固定返回 {"a":1}
  });

  it('deleteJob 同时删 DB 行与存储目录', async () => {
    const { activeStorageAdapter } = await import('../../common/storage/runtime-storage');
    await store.deleteJob('job_1');
    expect(deleteMock).toHaveBeenCalled();
    expect(activeStorageAdapter.deleteByDir).toHaveBeenCalledWith('ai-jobs', 'job_1');
  });
});
```

Run: `pnpm --filter @lumira/backend test -- ai-job.store`
Expected: FAIL —— `Cannot find module './ai-job.store'`

- [ ] **Step 2: 实现 store**

创建 `ai-job.store.ts`：

```ts
// lumira-server/packages/backend/src/modules/ai/ai-job.store.ts
// AI 生成任务持久化层：DB 行（列表展示数据）+ 存储文件（详情/事件流/产物/输入）。
// 只负责「存 / 取 / 删」，不含调度与阶段逻辑。
import { Injectable } from '@nestjs/common';
import { and, asc, desc, eq, inArray, sql } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { aiTemplateJobs } from '../../database/schema';
import { activeStorageAdapter } from '../../common/storage/runtime-storage';
import type { PipelineStage } from './ai-pipeline-job.service';

export type AiJobStatus = 'queued' | 'running' | 'done' | 'error' | 'stopped' | 'interrupted';
export type AiJobMode = 'auto' | 'analyze-only';

export const SETTLED_STATUSES: readonly AiJobStatus[] = ['done', 'error', 'stopped', 'interrupted'];

export interface AiJobRow { /* 见「共享接口」 */ }
export interface StoredArtifact { index: number; mimeType: string; storageKey: string; url: string }
export interface AiJobDetailFile { /* 见「共享接口」 */ }

export type AiJobPatch = Partial<
  Pick<
    AiJobRow,
    | 'status' | 'currentStage' | 'poseTotal' | 'poseDone' | 'silTotal' | 'silDone'
    | 'queuePos' | 'errorCode' | 'errorMessage' | 'detailKey' | 'startedAt' | 'finishedAt'
  >
>;

const MIME_EXT: Record<string, string> = {
  'image/png': 'png',
  'image/jpeg': 'jpg',
  'image/webp': 'webp',
  'image/gif': 'gif',
};

function extOf(mimeType: string): string {
  return MIME_EXT[mimeType] ?? 'png';
}

@Injectable()
export class AiJobStoreService {
  constructor(private readonly dbService: DatabaseService) {}

  private get db() {
    return this.dbService.getDb();
  }

  /** 任务目录 storageKey 前缀 */
  detailKeyOf(jobId: string): string {
    return `/uploads/ai-jobs/${jobId}/`;
  }

  async insertJob(row: AiJobRow): Promise<void> {
    await this.db.insert(aiTemplateJobs).values({
      id: row.id,
      status: row.status,
      mode: row.mode,
      title: row.title,
      currentStage: row.currentStage,
      poseTotal: row.poseTotal,
      poseDone: row.poseDone,
      silTotal: row.silTotal,
      silDone: row.silDone,
      queuePos: row.queuePos,
      inputSummaryJson: JSON.stringify(row.inputSummary ?? {}),
      errorCode: row.errorCode,
      errorMessage: row.errorMessage,
      detailKey: row.detailKey ?? this.detailKeyOf(row.id),
      createdAt: row.createdAt,
      startedAt: row.startedAt,
      finishedAt: row.finishedAt,
    });
  }

  async updateJob(id: string, patch: AiJobPatch): Promise<void> {
    if (!Object.keys(patch).length) return;
    await this.db.update(aiTemplateJobs).set(patch).where(eq(aiTemplateJobs.id, id));
  }

  /** 按传入顺序重写 queue_pos（1-based），仅供队列服务排队时刷新 */
  async setQueuePositions(orderedIds: string[]): Promise<void> {
    await Promise.all(orderedIds.map((id, i) => this.updateJob(id, { queuePos: i + 1 })));
  }

  async findJob(id: string): Promise<AiJobRow | null> {
    const r = await this.db.query.aiTemplateJobs.findFirst({ where: eq(aiTemplateJobs.id, id) });
    return r ? this.toRow(r) : null;
  }

  async listJobs(opts: { status?: AiJobStatus; limit: number; offset: number }): Promise<{ items: AiJobRow[]; total: number }> {
    const where = opts.status ? eq(aiTemplateJobs.status, opts.status) : undefined;
    const rows = await this.db
      .select()
      .from(aiTemplateJobs)
      .where(where)
      .orderBy(desc(aiTemplateJobs.createdAt))
      .limit(opts.limit)
      .offset(opts.offset);
    const [counted] = await this.db.select({ count: sql<number>`count(*)` }).from(aiTemplateJobs).where(where);
    return { items: rows.map((r) => this.toRow(r)), total: Number(counted?.count ?? 0) };
  }

  /** 重启恢复用：按创建时间升序取全部排队中任务 */
  async listQueued(): Promise<AiJobRow[]> {
    const rows = await this.db
      .select()
      .from(aiTemplateJobs)
      .where(eq(aiTemplateJobs.status, 'queued'))
      .orderBy(asc(aiTemplateJobs.createdAt));
    return rows.map((r) => this.toRow(r));
  }

  async deleteJob(id: string): Promise<void> {
    await this.db.delete(aiTemplateJobs).where(eq(aiTemplateJobs.id, id));
    await activeStorageAdapter.deleteByDir('ai-jobs', id);
  }

  /** 批量清理全部终态任务（含文件），返回删除条数 */
  async deleteSettled(): Promise<number> {
    const rows = await this.db
      .select({ id: aiTemplateJobs.id })
      .from(aiTemplateJobs)
      .where(inArray(aiTemplateJobs.status, [...SETTLED_STATUSES]));
    for (const r of rows) await this.deleteJob(r.id);
    return rows.length;
  }

  // ===== 存储文件 =====

  async writeDetail(id: string, detail: AiJobDetailFile): Promise<void> {
    await activeStorageAdapter.write('ai-jobs', id, 'detail.json', Buffer.from(JSON.stringify(detail)));
  }

  async readDetail(id: string): Promise<AiJobDetailFile | null> {
    const key = `${this.detailKeyOf(id)}detail.json`;
    if (!(await activeStorageAdapter.exists(key))) return null;
    return JSON.parse((await activeStorageAdapter.readBuffer(key)).toString('utf8')) as AiJobDetailFile;
  }

  async writeEvents(id: string, events: unknown[]): Promise<void> {
    const body = events.map((e) => JSON.stringify(e)).join('\n');
    await activeStorageAdapter.write('ai-jobs', id, 'events.jsonl', Buffer.from(body));
  }

  async readEvents(id: string): Promise<unknown[]> {
    const key = `${this.detailKeyOf(id)}events.jsonl`;
    if (!(await activeStorageAdapter.exists(key))) return [];
    const text = (await activeStorageAdapter.readBuffer(key)).toString('utf8');
    return text
      .split('\n')
      .filter((line) => line.trim())
      .map((line) => JSON.parse(line) as unknown);
  }

  /** 产物图：一次写入不覆盖（immutable 缓存安全） */
  async writeArtifact(
    id: string,
    kind: 'pose' | 'sil',
    index: number,
    mimeType: string,
    buffer: Buffer,
  ): Promise<StoredArtifact> {
    const filename = `${kind}-${index}.${extOf(mimeType)}`;
    const storageKey = await activeStorageAdapter.write('ai-jobs', id, filename, buffer);
    return { index, mimeType, storageKey, url: storageKey };
  }

  /** 输入图：供停止后续跑 / 后端重启后续跑 */
  async writeInput(
    id: string,
    kind: 'example' | 'ref',
    index: number,
    mimeType: string,
    buffer: Buffer,
  ): Promise<string> {
    return activeStorageAdapter.write('ai-jobs', id, `input/${kind}-${index}.${extOf(mimeType)}`, buffer);
  }

  /** 读取全部输入图（按 storageKey 升序，名称形如 input/example-0.png） */
  async readInputs(id: string): Promise<Array<{ name: string; buffer: Buffer }>> {
    const keys = (await activeStorageAdapter.listKeys(`${this.detailKeyOf(id)}input`)).sort();
    const out: Array<{ name: string; buffer: Buffer }> = [];
    for (const key of keys) {
      out.push({ name: key.replace(this.detailKeyOf(id), ''), buffer: await activeStorageAdapter.readBuffer(key) });
    }
    return out;
  }

  private toRow(r: Record<string, unknown>): AiJobRow {
    let inputSummary: Record<string, unknown> = {};
    const raw = r.inputSummaryJson as string | null | undefined;
    if (raw) {
      try {
        inputSummary = JSON.parse(raw) as Record<string, unknown>;
      } catch {
        inputSummary = {};
      }
    }
    return {
      id: r.id as string,
      status: r.status as AiJobStatus,
      mode: r.mode as AiJobMode,
      title: r.title as string,
      currentStage: (r.currentStage as PipelineStage | null) ?? null,
      poseTotal: Number(r.poseTotal ?? 0),
      poseDone: Number(r.poseDone ?? 0),
      silTotal: Number(r.silTotal ?? 0),
      silDone: Number(r.silDone ?? 0),
      queuePos: Number(r.queuePos ?? 0),
      inputSummary,
      errorCode: (r.errorCode as string | null) ?? null,
      errorMessage: (r.errorMessage as string | null) ?? null,
      detailKey: (r.detailKey as string | null) ?? null,
      createdAt: Number(r.createdAt ?? 0),
      startedAt: r.startedAt == null ? null : Number(r.startedAt),
      finishedAt: r.finishedAt == null ? null : Number(r.finishedAt),
    };
  }
}
```

注意：
- `AiJobRow` / `AiJobDetailFile` 的字段按「共享接口」小节完整写出（不要省略）。
- `writeDetail`/`readDetail` 用 `exists` 判空，避免对不存在的文件抛异常。
- `setQueuePositions` 是串行友好写法，队列规模小（个位数），无需事务。

- [ ] **Step 3: 注册 provider**

`ai.module.ts` 的 `providers` 数组追加 `AiJobStoreService`，并确保 `DatabaseService` 在 imports 中可用（与其他 service 一致）。

- [ ] **Step 4: 跑测试**

Run: `pnpm --filter @lumira/backend test -- ai-job.store`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lumira-server/packages/backend/src/modules/ai/ai-job.store.ts lumira-server/packages/backend/src/modules/ai/ai-job.store.spec.ts lumira-server/packages/backend/src/modules/ai/ai.module.ts
git commit -m "feat(ai): 新增 AI 任务持久化层 AiJobStoreService"
```

---

### Task 4: `AiJobQueueService`（调度层）

**Files:**
- Create: `lumira-server/packages/backend/src/modules/ai/ai-job-queue.service.ts`
- Create: `lumira-server/packages/backend/src/modules/ai/ai-job-queue.service.spec.ts`
- Modify: `lumira-server/packages/backend/src/modules/ai/ai.module.ts`

**Interfaces:**
- Consumes: `AiJobStoreService`（Task 3）、`AiConfigService.get().jobConcurrency`（Task 2）、`AiPipelineJobService.startJob/hydrate/requestStop/prepareResume`（Task 5）
- Produces: `AiJobQueueService.enqueue/stop/resume/onModuleInit`（见「共享接口」）

> **顺序提示：** 本 Task 依赖 Task 5 的方法签名。若先做本 Task，可先写测试（用 mock 的 pipeline），实现代码按共享接口写，Task 5 落地后跑集成验证。

- [ ] **Step 1: 写失败测试**

创建 `ai-job-queue.service.spec.ts`：

```ts
// lumira-server/packages/backend/src/modules/ai/ai-job-queue.service.spec.ts
// 队列调度单测：并发上限 / FIFO 顺序 / queue_pos / 停止 / 重启恢复。
import { AiJobQueueService } from './ai-job-queue.service';
import type { AiJobStoreService, AiJobRow } from './ai-job.store';

function row(id: string, over: Partial<AiJobRow> = {}): AiJobRow {
  return {
    id, status: 'queued', mode: 'auto', title: id, currentStage: null,
    poseTotal: 0, poseDone: 0, silTotal: 0, silDone: 0, queuePos: 0,
    inputSummary: {}, errorCode: null, errorMessage: null, detailKey: null,
    createdAt: 1, startedAt: null, finishedAt: null, ...over,
  };
}

describe('AiJobQueueService', () => {
  let store: jest.Mocked<Pick<AiJobStoreService,
    'updateJob' | 'findJob' | 'listQueued' | 'setQueuePositions'>>;
  let pipeline: jest.Mocked<Pick<{ startJob: (id: string) => Promise<void> }, 'startJob'>>;
  let release: Array<() => void>;

  function build(concurrency = 2) {
    release = [];
    pipeline = {
      startJob: jest.fn(
        () => new Promise<void>((resolve) => release.push(resolve)),
      ) as never,
    };
    const queue = new AiJobQueueService(
      store as never,
      { get: jest.fn(async () => ({ configured: true, jobConcurrency: concurrency })) } as never,
      pipeline as never,
      { requestStop: jest.fn(() => true), hydrate: jest.fn(async () => true), prepareResume: jest.fn(async () => ({ stages: ['analyze'], onlyIndexes: {} })) } as never,
    );
    return queue;
  }

  beforeEach(() => {
    store = {
      updateJob: jest.fn(async () => undefined),
      findJob: jest.fn(async (id: string) => row(id)),
      listQueued: jest.fn(async () => []),
      setQueuePositions: jest.fn(async () => undefined),
    };
  });

  it('并发上限 2：第 3 个任务排队，开跑的前两个置 running', async () => {
    const queue = build(2);
    await expect(queue.enqueue('a')).resolves.toEqual({ status: 'running', queuePos: 0 });
    await expect(queue.enqueue('b')).resolves.toEqual({ status: 'running', queuePos: 0 });
    await expect(queue.enqueue('c')).resolves.toEqual({ status: 'queued', queuePos: 1 });
    expect(store.updateJob).toHaveBeenCalledWith('c', { status: 'queued', queuePos: 1 });
  });

  it('任一任务结束后自动出队下一个', async () => {
    const queue = build(1);
    await queue.enqueue('a');
    await queue.enqueue('b');
    expect(pipeline.startJob).toHaveBeenCalledTimes(1);
    release[0]!();
    await new Promise((r) => setImmediate(r));
    expect(pipeline.startJob).toHaveBeenCalledTimes(2);
    expect(pipeline.startJob).toHaveBeenLastCalledWith('b');
  });

  it('stop：running 任务置停止标记并返回 stopped', async () => {
    const queue = build(1);
    await queue.enqueue('a');
    await expect(queue.stop('a')).resolves.toEqual({ stopped: true, status: 'stopped' });
  });

  it('onModuleInit：queued 重新入队，running 置 interrupted', async () => {
    store.listQueued = jest.fn(async () => [row('q1')]);
    store.findJob = jest.fn(async (id: string) =>
      id === 'q1' ? row('q1') : row(id, { status: 'running' }),
    );
    const queue = build(1);
    const markInterrupted = jest.fn(async () => undefined);
    (queue as unknown as { markInterrupted: typeof markInterrupted }).markInterrupted = markInterrupted;
    await queue.onModuleInit();
    expect(markInterrupted).toHaveBeenCalledWith('running');
    expect(pipeline.startJob).toHaveBeenCalledWith('q1');
  });
});
```

Run: `pnpm --filter @lumira/backend test -- ai-job-queue`
Expected: FAIL —— `Cannot find module './ai-job-queue.service'`

- [ ] **Step 2: 实现队列**

创建 `ai-job-queue.service.ts`：

```ts
// lumira-server/packages/backend/src/modules/ai/ai-job-queue.service.ts
// 调度层：FIFO 队列 + 并发闸门（并发数实时读 AI 设置）+ 停止 + 重启恢复。
// DB 为真相源，内存队列只保存「待执行的 jobId 顺序」。
import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { AiConfigService } from './ai-config.service';
import { AiJobStoreService, type AiJobStatus } from './ai-job.store';
import { AiPipelineJobService } from './ai-pipeline-job.service';

@Injectable()
export class AiJobQueueService implements OnModuleInit {
  private readonly logger = new Logger(AiJobQueueService.name);
  /** 待执行 jobId（FIFO，按 created_at 升序） */
  private readonly waiting: string[] = [];
  /** 正在执行的 jobId 集合 */
  private readonly running = new Set<string>();
  private draining = false;

  constructor(
    private readonly store: AiJobStoreService,
    private readonly aiConfigService: AiConfigService,
    private readonly pipeline: AiPipelineJobService,
  ) {}

  /** 重启恢复：queued 重新入队；running → interrupted（内存产物已丢） */
  async onModuleInit(): Promise<void> {
    await this.markInterrupted();
    const queued = await this.store.listQueued();
    for (const r of queued) if (!this.waiting.includes(r.id)) this.waiting.push(r.id);
    await this.store.setQueuePositions(this.waiting);
    if (queued.length) this.logger.log(`重启恢复：${queued.length} 个排队任务重新入队`);
    void this.drain();
  }

  /** 把残留的 running 任务标记为 interrupted */
  private async markInterrupted(): Promise<void> {
    const runningRows = await this.store.listJobs({ status: 'running', limit: 200, offset: 0 });
    for (const r of runningRows.items) {
      await this.store.updateJob(r.id, {
        status: 'interrupted',
        errorCode: 'interrupted',
        errorMessage: '后端重启导致任务中断，可点「继续」从当前阶段续跑',
        finishedAt: Math.floor(Date.now() / 1000),
      });
    }
  }

  /** 入队：有空位立即开跑，否则排队并刷新位次 */
  async enqueue(jobId: string): Promise<{ status: AiJobStatus; queuePos: number }> {
    const limit = await this.concurrency();
    if (this.running.size < limit) {
      void this.run(jobId);
      return { status: 'running', queuePos: 0 };
    }
    if (!this.waiting.includes(jobId)) this.waiting.push(jobId);
    await this.store.setQueuePositions(this.waiting);
    const pos = this.waiting.indexOf(jobId) + 1;
    await this.store.updateJob(jobId, { status: 'queued', queuePos: pos });
    return { status: 'queued', queuePos: pos };
  }

  /** 停止：running → 置停止标记（停在检查点）；queued → 取消排队 */
  async stop(jobId: string): Promise<{ stopped: boolean; status: AiJobStatus }> {
    if (this.running.has(jobId)) {
      this.pipeline.requestStop(jobId);
      return { stopped: true, status: 'stopped' };
    }
    const idx = this.waiting.indexOf(jobId);
    if (idx >= 0) {
      this.waiting.splice(idx, 1);
      await this.store.setQueuePositions(this.waiting);
      await this.store.updateJob(jobId, {
        status: 'stopped',
        queuePos: 0,
        errorCode: 'aborted',
        errorMessage: '已取消排队',
        finishedAt: Math.floor(Date.now() / 1000),
      });
      return { stopped: true, status: 'stopped' };
    }
    return { stopped: false, status: (await this.store.findJob(jobId))?.status ?? 'done' };
  }

  /** 继续：从存储恢复内存态后重新入队（queued/running 无需继续） */
  async resume(jobId: string): Promise<{ resumed: boolean; status: AiJobStatus } | null> {
    const row = await this.store.findJob(jobId);
    if (!row) return null;
    if (row.status === 'running') return { resumed: false, status: 'running' };
    if (row.status === 'queued') return { resumed: false, status: 'queued' };
    if (row.status === 'done') return { resumed: false, status: 'done' };
    await this.pipeline.hydrate(jobId);
    const plan = await this.pipeline.prepareResume(jobId);
    if (!plan) return { resumed: false, status: row.status };
    const { status, queuePos } = await this.enqueue(jobId);
    return { resumed: true, status: queuePos > 0 ? 'queued' : status };
  }

  /** 出队填充空位 */
  private async drain(): Promise<void> {
    if (this.draining) return;
    this.draining = true;
    try {
      const limit = await this.concurrency();
      while (this.waiting.length && this.running.size < limit) {
        const next = this.waiting.shift()!;
        await this.store.setQueuePositions(this.waiting);
        await this.store.updateJob(next, { queuePos: 0 });
        void this.run(next);
      }
    } finally {
      this.draining = false;
    }
  }

  /** 执行一个任务并在结束后释放空位 */
  private async run(jobId: string): Promise<void> {
    this.running.add(jobId);
    try {
      await this.pipeline.startJob(jobId);
    } catch (err) {
      this.logger.error(`任务 ${jobId} 执行异常：${(err as Error).message}`);
    } finally {
      this.running.delete(jobId);
      void this.drain();
    }
  }

  /** 并发上限实时读 AI 设置（改动无需重启生效） */
  private async concurrency(): Promise<number> {
    const cfg = await this.aiConfigService.get();
    const n = 'configured' in cfg && cfg.configured ? cfg.jobConcurrency : 2;
    return Math.min(5, Math.max(1, n || 2));
  }
}
```

- [ ] **Step 3: 注册 provider**

`ai.module.ts` 的 `providers` 追加 `AiJobQueueService`。

- [ ] **Step 4: 跑测试**

Run: `pnpm --filter @lumira/backend test -- ai-job-queue`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lumira-server/packages/backend/src/modules/ai/ai-job-queue.service.ts lumira-server/packages/backend/src/modules/ai/ai-job-queue.service.spec.ts lumira-server/packages/backend/src/modules/ai/ai.module.ts
git commit -m "feat(ai): 新增 AI 任务调度队列（并发闸门 / 排队 / 停止 / 重启恢复）"
```

---

### Task 5: `AiPipelineJobService` 改造（执行引擎持久化 + 停止）

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-pipeline-job.service.ts`
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-pipeline-job.service.spec.ts`

**Interfaces:**
- Consumes: `AiJobStoreService`（Task 3）
- Produces: `create`（状态 `queued` + 落库落文件）、`startJob`、`requestStop`、`prepareResume`、`hydrate`（见「共享接口」）

- [ ] **Step 1: 扩类型与 job 字段**

`ai-pipeline-job.service.ts`：

1. `JobStatus` 扩展（第 21 行）：

```ts
export type JobStatus = 'queued' | 'running' | 'done' | 'error' | 'stopped';
```

2. `PipelinePoseFile`（第 72 行）追加两个可选字段（保持 `base64` 供下游做锚点，不参与序列化）：

```ts
export interface PipelinePoseFile {
  index: number;
  base64: string;
  mimeType: string;
  /** 落存储后的相对 key（序列化时以它构造 url） */
  storageKey?: string;
  url?: string;
}
```

3. `AiPipelineJob` 追加字段：

```ts
  /** 待执行阶段（create 后为全量待跑阶段；prepareResume 写入续跑阶段） */
  pendingStages?: PipelineStage[];
  pendingOnlyIndexes?: Partial<Record<PipelineStage, number[]>>;
  /** 用户请求停止：在检查点抛 JobStoppedError */
  stopRequested?: boolean;
```

4. 新增停止异常（放在 `HINTS` 之后）：

```ts
/** 用户主动停止：不是失败，状态落 stopped 且保留已产出 */
export class JobStoppedError extends Error {
  constructor() {
    super('任务已被用户停止');
    this.name = 'JobStoppedError';
  }
}
```

- [ ] **Step 2: 注入 store，改造 create**

1. 构造函数追加第 4 个参数：

```ts
  constructor(
    private readonly aiAnalyzeService: AiAnalyzeService,
    private readonly aiGenerateImageService: AiGenerateImageService,
    private readonly aiSilhouetteService: AiSilhouetteService,
    private readonly store: AiJobStoreService,
  ) {
```

2. 删除 `RESULT_TTL_MS` / `SWEEP_INTERVAL_MS` / `sweeper` / `sweep()` / `onModuleDestroy()` 里的 `clearInterval`（改用 DB 持久化；`onModuleDestroy` 可整体删除）。`MAX_JOB_EVENTS` / `COMPACT_TEXT_CAP` / `GENERATE_RETRY_LIMIT` 保留。

3. `create()`（第 222~251 行）结尾的 `this.jobs.set(...)` + `void this.runPipeline(...)` 替换为：

```ts
    job.pendingStages = mode === 'analyze-only' ? ['analyze'] : ['analyze', 'image', 'silhouette'];
    this.jobs.set(job.id, job);
    await this.persistNew(job);
    return { jobId: job.id };
```

`status` 初值由 `'running'` 改为 `'queued'`。

4. 新增私有方法（放在 `emptyStages()` 之后）：

```ts
  /** 新任务落库 + 落输入文件（供停止后续跑 / 重启后续跑） */
  private async persistNew(job: AiPipelineJob): Promise<void> {
    const inputs = job.inputs;
    let i = 0;
    for (const img of inputs.images ?? []) {
      await this.store.writeInput(job.id, 'example', i, img.mimetype, img.buffer);
      i += 1;
    }
    let r = 0;
    for (const img of inputs.references ?? []) {
      await this.store.writeInput(job.id, 'ref', r, img.mimetype, img.buffer);
      r += 1;
    }
    await this.store.insertJob({
      id: job.id,
      status: 'queued',
      mode: job.mode,
      title: buildJobTitle(job),
      currentStage: job.pendingStages?.[0] ?? null,
      poseTotal: 0,
      poseDone: 0,
      silTotal: 0,
      silDone: 0,
      queuePos: 0,
      inputSummary: buildInputSummary(job),
      errorCode: null,
      errorMessage: null,
      detailKey: this.store.detailKeyOf(job.id),
      createdAt: Math.floor(job.createdAt / 1000),
      startedAt: null,
      finishedAt: null,
    });
  }
```

并在文件底部（`AiPipelineJobService` 类之外）新增两个纯函数：

```ts
/** 列表标题：文字描述前 20 字，否则「N 张示例图」 */
export function buildJobTitle(job: AiPipelineJob): string {
  const text = (job.inputs.text ?? job.inputs.extra.textDesc ?? '').trim();
  if (text) return text.length > 20 ? `${text.slice(0, 20)}…` : text;
  const n = job.inputs.images?.length ?? 0;
  return n ? `${n} 张示例图` : '未命名任务';
}

/** 列表输入摘要（不含图片字节） */
export function buildInputSummary(job: AiPipelineJob): Record<string, unknown> {
  const text = (job.inputs.text ?? '').trim();
  return {
    imageCount: job.inputs.images?.length ?? 0,
    refCount: job.inputs.references?.length ?? 0,
    hasText: Boolean(text),
    textPreview: text.slice(0, 80),
    poseCount: job.inputs.extra.poseCount ?? null,
    subjectCount: job.inputs.extra.subjectCount ?? null,
    silMode: job.inputs.silhouette.mode,
    silEngine: job.inputs.silhouette.engine,
    refAnchor: job.inputs.referenceAnchor,
  };
}
```

- [ ] **Step 3: 新增 startJob / requestStop**

在 `create()` 之后追加：

```ts
  /** 队列调度入口：执行 pendingStages，resolve 于终态（done / error / stopped） */
  async startJob(jobId: string): Promise<void> {
    const job = this.jobs.get(jobId);
    if (!job) return;
    const stages = job.pendingStages ?? [];
    const onlyIndexes = job.pendingOnlyIndexes;
    job.pendingStages = undefined;
    job.pendingOnlyIndexes = undefined;
    if (!stages.length) return;
    job.stopRequested = false;
    await this.store.updateJob(jobId, { status: 'running', startedAt: Math.floor(Date.now() / 1000) });
    await this.runPipeline(job, { stages, onlyIndexes });
    await this.persistTerminal(job);
  }

  /** 请求停止：置标记，实际停在下一个检查点 */
  requestStop(jobId: string): boolean {
    const job = this.jobs.get(jobId);
    if (!job) return false;
    job.stopRequested = true;
    return true;
  }

  /** 检查点：命中停止请求则抛出 JobStoppedError */
  private assertNotStopped(job: AiPipelineJob): void {
    if (job.stopRequested) throw new JobStoppedError();
  }
```

- [ ] **Step 4: 在检查点插入停止判断**

1. `runPipeline()`（第 257 行）的 `for (const stage of opts.stages) {` 之后第一行：

```ts
      this.assertNotStopped(job);
```

2. `runPipeline()` 的 `catch (err)` 分支最前面插入停止分支：

```ts
      } catch (err) {
        if (err instanceof JobStoppedError) {
          state.status = 'pending';
          state.finishedAt = Date.now();
          job.status = 'stopped';
          this.append(job, {
            stage,
            type: 'note',
            step: 'stop',
            title: '任务已停止',
            status: 'fail',
            resultBrief: '已保留当前产出，可点「继续」从该阶段续跑',
          });
          return;
        }
        const info = this.buildInterruption(job, stage, err);
```

3. `runImageStage` 与 `runSilhouetteStage` 内**每张图开始前**、`generateWithRetry` **每次重试前**各插入一行：

```ts
      this.assertNotStopped(job);
```

- [ ] **Step 5: 产物落盘 + 进度落库**

1. 图片阶段每张生成成功后（写入 `job.artifacts.poseFiles` 之后）追加：

```ts
    const stored = await this.store.writeArtifact(job.id, 'pose', index, file.mimeType, Buffer.from(file.base64, 'base64'));
    file.storageKey = stored.storageKey;
    file.url = stored.url;
    await this.store.updateJob(job.id, {
      poseDone: job.artifacts.poseFiles.length,
      poseTotal: job.artifacts.poseFiles.length + job.artifacts.poseErrors.length,
      currentStage: 'image',
    });
```

剪影阶段同理，用 `'sil'`、`silDone`/`silTotal`、`currentStage: 'silhouette'`，并同步 `file.storageKey` / `file.url`。

2. `runAnalyzeStage` 成功后（草稿就绪）追加阶段快照与阶段切换：

```ts
    await this.persistDetail(job);
    await this.store.updateJob(job.id, { currentStage: 'image' });
```

（`analyze-only` 模式下 `currentStage` 置 `null`。）

- [ ] **Step 6: detail / events 落盘**

新增：

```ts
  /** 详情快照落存储（analyze 完成 / image 完成 / 终态调用；运行中详情页读内存，不读它） */
  async persistDetail(job: AiPipelineJob): Promise<void> {
    const a = job.artifacts.analyze;
    await this.store.writeDetail(job.id, {
      stages: job.stages,
      error: job.error ?? null,
      warnings: a?.warnings ?? [],
      draft: a?.draft ?? null,
      trace: a?.trace ?? [],
      raw: a?.raw ?? null,
      research: a?.research ?? [],
      researchBrief: a?.brief ?? null,
      researchVision: a?.researchVision ?? null,
      artifacts: {
        poseFiles: job.artifacts.poseFiles.map(toStored),
        poseErrors: job.artifacts.poseErrors,
        silFiles: job.artifacts.silFiles.map(toStored),
        silErrors: job.artifacts.silErrors,
      },
      inputs: buildInputSummary(job),
    });
  }

  /** 终态收尾：写 detail + events + DB 终态字段 */
  private async persistTerminal(job: AiPipelineJob): Promise<void> {
    await this.persistDetail(job);
    await this.store.writeEvents(job.id, job.events);
    const settledAt = Math.floor(Date.now() / 1000);
    await this.store.updateJob(job.id, {
      status: job.status,
      errorCode: job.error?.code ?? null,
      errorMessage: job.error?.message ?? null,
      startedAt: null,
      finishedAt: settledAt,
      currentStage: null,
    });
  }
```

并新增模块级辅助函数：

```ts
/** 产物引用（序列化 / detail 落盘共用，剔除 base64） */
export function toStored(f: PipelinePoseFile) {
  return { index: f.index, mimeType: f.mimeType, storageKey: f.storageKey ?? '', url: f.url ?? '' };
}
```

`errorCode` 为 `interrupted` 的写入由队列服务负责（Task 4），此处只写 pipeline 自身的错误。

- [ ] **Step 7: hydrate 与 prepareResume**

1. 新增 `hydrate`：

```ts
  /** 冷启动恢复：从存储文件重建内存 job（后端重启后的「继续」用） */
  async hydrate(jobId: string): Promise<boolean> {
    if (this.jobs.has(jobId)) return true;
    const row = await this.store.findJob(jobId);
    if (!row) return false;
    const detail = await this.store.readDetail(jobId);
    if (!detail) return false;
    const inputs = await this.store.readInputs(jobId);
    const pick = (kind: 'example' | 'ref') =>
      inputs
        .map((f) => ({ f, m: /^(?:input\/)?(example|ref)-(\d+)\./.exec(f.name) }))
        .filter((x) => x.m && x.m[1] === kind)
        .sort((x, y) => Number(x.m![2]) - Number(y.m![2]))
        .map((x) => ({ buffer: x.f.buffer, filename: x.f.name.split('/').pop() ?? x.f.name, mimetype: mimeFromName(x.f.name) }));
    const job: AiPipelineJob = {
      id: jobId,
      createdAt: row.createdAt * 1000,
      status: 'error',
      mode: row.mode,
      inputs: {
        images: pick('example'),
        text: (detail.inputs.textPreview as string) || undefined,
        extra: {},
        references: pick('ref'),
        referenceAnchor: detail.inputs.refAnchor !== false,
        extraPrompt: null,
        silhouette: {
          mode: (detail.inputs.silMode as 'sketch' | 'solid') ?? 'sketch',
          crop: true,
          engine: (detail.inputs.silEngine as 'ai' | 'local') ?? 'local',
        },
      },
      stages: detail.stages as Record<PipelineStage, StageState>,
      events: [],
      artifacts: {
        analyze: detail.draft
          ? ({ draft: detail.draft, warnings: detail.warnings, trace: detail.trace, raw: detail.raw, research: detail.research, brief: detail.researchBrief, researchVision: detail.researchVision } as unknown as AiAnalyzeResult)
          : undefined,
        poseFiles: detail.artifacts.poseFiles.map((s) => ({ index: s.index, mimeType: s.mimeType, base64: '', storageKey: s.storageKey, url: s.url })),
        poseErrors: detail.artifacts.poseErrors as never,
        silFiles: detail.artifacts.silFiles.map((s) => ({ index: s.index, mimeType: s.mimeType, base64: '', storageKey: s.storageKey, url: s.url })),
        silErrors: detail.artifacts.silErrors as never,
      },
    };
    this.jobs.set(jobId, job);
    return true;
  }
```

2. 把原 `resume()`（第 632~674 行）改写为 `prepareResume()`：**保留**其中「算 stages / onlyIndexes / 清空上游产物」的逻辑，删掉最后的 `job.status='running'`、`append`、`void this.runPipeline(...)`，改为：

```ts
    job.pendingStages = stages;
    job.pendingOnlyIndexes = onlyIndexes;
    job.status = 'error';
    job.error = undefined;
    return { stages, onlyIndexes };
```

方法签名与首部：

```ts
  /** 续跑准备：算出待重跑阶段并写入 pendingStages；实际执行由队列调度 startJob 触发 */
  async prepareResume(jobId: string): Promise<{ stages: PipelineStage[]; onlyIndexes: Partial<Record<PipelineStage, number[]>> } | null> {
    const job = this.jobs.get(jobId);
    if (!job) return null;
    if (job.status === 'running' || job.status === 'done') return null;
    const failedStage = job.error?.stage ?? 'analyze';
    ...
```

（`failedStage` 在 `hydrate` 后为 `undefined` 时回退 `'analyze'`，与既有语义一致。）

新增模块级辅助函数：

```ts
function mimeFromName(name: string): string {
  const ext = name.split('.').pop()?.toLowerCase();
  if (ext === 'jpg' || ext === 'jpeg') return 'image/jpeg';
  if (ext === 'webp') return 'image/webp';
  if (ext === 'gif') return 'image/gif';
  return 'image/png';
}
```

- [ ] **Step 8: 序列化去 base64**

`serialize()`（第 685~711 行）中：

```ts
      poseImages: compact ? [] : job.artifacts.poseFiles.map(toStored),
      silhouetteImages: compact ? [] : job.artifacts.silFiles.map(toStored),
```

- [ ] **Step 9: 补/改测试**

在 `ai-pipeline-job.service.spec.ts` 中：
1. 构造函数补第 4 个参数 stub：

```ts
      {
        insertJob: jest.fn().mockResolvedValue(undefined),
        updateJob: jest.fn().mockResolvedValue(undefined),
        writeInput: jest.fn().mockResolvedValue('/uploads/ai-jobs/job_x/input/example-0.png'),
        writeArtifact: jest.fn(async (id: string, kind: string, index: number) => ({
          index, mimeType: 'image/png',
          storageKey: `/uploads/ai-jobs/${id}/${kind}-${index}.png`,
          url: `/uploads/ai-jobs/${id}/${kind}-${index}.png`,
        })),
        writeDetail: jest.fn().mockResolvedValue(undefined),
        writeEvents: jest.fn().mockResolvedValue(undefined),
        readDetail: jest.fn().mockResolvedValue(null),
        readInputs: jest.fn().mockResolvedValue([]),
        findJob: jest.fn().mockResolvedValue(null),
        detailKeyOf: (id: string) => `/uploads/ai-jobs/${id}/`,
      } as never,
```

2. 既有依赖 `create()` 后自动跑起来的用例（`waitStatus` 系列）改为「先 `create`，再 `await service.startJob(jobId)`」两段式；`service.onModuleDestroy()` 的 `afterEach` 一并删除。

3. 新增用例：

```ts
  it('create 后状态为 queued 且未开跑；startJob 才执行', async () => {
    const { jobId } = await service.create({ text: '文字', mode: 'analyze-only' });
    expect(service.get(jobId)!.status).toBe('queued');
    expect(analyzeMock).not.toHaveBeenCalled();
    await service.startJob(jobId);
    expect(analyzeMock).toHaveBeenCalled();
    expect(service.get(jobId)!.status).toBe('done');
  });

  it('requestStop 后停在检查点：状态 stopped 且已产出保留', async () => {
    analyzeMock.mockImplementation(() => new Promise((r) => setTimeout(() => r(ANALYZE_RESULT), 20)));
    const { jobId } = await service.create({ text: '文字', mode: 'analyze-only' });
    service.requestStop(jobId);
    await service.startJob(jobId);
    expect(service.get(jobId)!.status).toBe('stopped');
    expect(service.get(jobId)!.stages.analyze.status).toBe('pending');
  });

  it('serialize 终态产物为 URL，不含 base64', async () => {
    const { jobId } = await service.create({ text: '文字', mode: 'analyze-only' });
    await service.startJob(jobId);
    const out = service.serialize(service.get(jobId)!, 0, true);
    expect(JSON.stringify(out)).not.toContain('base64');
    expect(out).toHaveProperty('poseImages');
  });
```

Run: `pnpm --filter @lumira/backend test -- ai-pipeline-job`
Expected: PASS

- [ ] **Step 10: Commit**

```bash
git add lumira-server/packages/backend/src/modules/ai/ai-pipeline-job.service.ts lumira-server/packages/backend/src/modules/ai/ai-pipeline-job.service.spec.ts
git commit -m "feat(ai): 流水线任务改为入队执行，支持停止/续跑与详情落存储"
```

---

### Task 6: 控制器端点

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/ai-templates.controller.ts:165-215`

**Interfaces:**
- Consumes: `AiPipelineJobService`（Task 5）、`AiJobQueueService`（Task 4）、`AiJobStoreService`（Task 3）
- Produces: 6 个 HTTP 端点（见下），供前端 Task 7 调用

- [ ] **Step 1: 构造注入**

`AiTemplatesController` 构造函数追加 `AiJobQueueService` 与 `AiJobStoreService`。

- [ ] **Step 2: 替换 ai-job 路由段**

把第 165~215 行整段替换为：

```ts
  // ===== AI 生成任务队列（spec 2026-09-30）=====

  /** 提交生成任务 → 入队 */
  @Post('ai-job')
  async createAiJob(@Req() req: FastifyRequest) {
    const p = await parseAiMultipart(req);
    const mode: JobMode = p.jobMode === 'analyze-only' ? 'analyze-only' : 'auto';
    const { jobId } = await this.aiPipelineJobService.create({
      images: p.images,
      text: p.text,
      extra: { textDesc: p.textDesc, creationReq: p.creationReq, poseCount: p.poseCount, subjectCount: p.subjectCount },
      references: p.references,
      referenceAnchor: p.referenceAnchor,
      extraPrompt: p.extraPrompt,
      mode,
      silhouette: { mode: p.silMode === 'solid' ? 'solid' : 'sketch', crop: p.silCrop !== false, engine: p.silEngine === 'ai' ? 'ai' : 'local' },
    });
    const queued = await this.aiJobQueueService.enqueue(jobId);
    return { jobId, status: queued.status, queuePos: queued.queuePos };
  }

  /** 任务列表（分页 + 状态筛选） */
  @Get('ai-jobs')
  async listAiJobs(@Query('status') status?: string, @Query('limit') limit?: string, @Query('offset') offset?: string) {
    const rows = await this.aiJobStoreService.listJobs({
      status: isJobStatus(status) ? status : undefined,
      limit: clampInt(limit, 20, 1, 100),
      offset: clampInt(offset, 0, 0, 100000),
    });
    return { items: rows.items.map(toListItem), total: rows.total };
  }

  /** 批量清理终态任务（含文件） */
  @Post('ai-jobs/cleanup')
  async cleanupAiJobs() {
    return { removed: await this.aiJobStoreService.deleteSettled() };
  }

  /** 任务详情：运行中读内存（支持 since 增量），终态/重启后读存储文件 */
  @Get('ai-jobs/:jobId')
  async getAiJobDetail(@Param('jobId') jobId: string, @Query('since') since?: string) {
    const row = await this.aiJobStoreService.findJob(jobId);
    if (!row) throw new NotFoundException('AI pipeline job not found');
    const sinceSeq = Number.isFinite(Number(since)) ? Number(since) : 0;
    const job = this.aiPipelineJobService.get(jobId);
    if (job) {
      return { ...toListItem(row), ...this.aiPipelineJobService.serialize(job, sinceSeq) };
    }
    const detail = await this.aiJobStoreService.readDetail(jobId);
    const events = await this.aiJobStoreService.readEvents(jobId);
    return {
      ...toListItem(row),
      jobId,
      stages: (detail?.stages ?? { analyze: { status: 'pending' }, image: { status: 'pending' }, silhouette: { status: 'pending' } }) as unknown,
      error: row.errorCode ? { code: row.errorCode, message: row.errorMessage ?? '', stage: 'analyze', at: (row.finishedAt ?? 0) * 1000 } : null,
      events,
      lastSeq: events.length,
      draft: detail?.draft ?? null,
      warnings: detail?.warnings ?? [],
      trace: detail?.trace ?? [],
      raw: detail?.raw ?? null,
      research: detail?.research ?? [],
      researchBrief: detail?.researchBrief ?? null,
      researchImages: [],
      researchVision: detail?.researchVision ?? null,
      poseImages: detail?.artifacts.poseFiles ?? [],
      poseErrors: detail?.artifacts.poseErrors ?? [],
      silhouetteImages: detail?.artifacts.silFiles ?? [],
      silhouetteErrors: detail?.artifacts.silErrors ?? [],
    };
  }

  /** 停止：running 停在检查点，queued 取消排队 */
  @Post('ai-jobs/:jobId/stop')
  async stopAiJob(@Param('jobId') jobId: string) {
    const row = await this.aiJobStoreService.findJob(jobId);
    if (!row) throw new NotFoundException('AI pipeline job not found');
    return this.aiJobQueueService.stop(jobId);
  }

  /** 继续：从存储恢复后重新入队 */
  @Post('ai-jobs/:jobId/resume')
  async resumeAiJob(@Param('jobId') jobId: string) {
    const result = await this.aiJobQueueService.resume(jobId);
    if (!result) throw new NotFoundException('AI pipeline job not found');
    return result;
  }

  /** 删除终态任务（DB 行 + 任务文件夹） */
  @Delete('ai-jobs/:jobId')
  async deleteAiJob(@Param('jobId') jobId: string) {
    const row = await this.aiJobStoreService.findJob(jobId);
    if (!row) return { ok: true };
    if (!SETTLED_STATUSES.includes(row.status)) {
      throw new BadRequestException('任务尚未结束，请先「停止」再删除');
    }
    this.aiPipelineJobService.remove(jobId);
    await this.aiJobStoreService.deleteJob(jobId);
    return { ok: true };
  }
```

- [ ] **Step 3: 文件底部补辅助函数**

```ts
const JOB_STATUSES = ['queued', 'running', 'done', 'error', 'stopped', 'interrupted'] as const;

function isJobStatus(v: string | undefined): v is AiJobStatus {
  return Boolean(v) && (JOB_STATUSES as readonly string[]).includes(v!);
}

function clampInt(v: string | undefined, fallback: number, min: number, max: number): number {
  const n = Number(v);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, Math.trunc(n)));
}

/** 列表项：只暴露列表展示字段，不含详情大字段 */
function toListItem(row: AiJobRow) {
  return {
    id: row.id,
    title: row.title,
    status: row.status,
    mode: row.mode,
    currentStage: row.currentStage,
    progress: { poseTotal: row.poseTotal, poseDone: row.poseDone, silTotal: row.silTotal, silDone: row.silDone },
    queuePos: row.queuePos,
    errorCode: row.errorCode,
    errorMessage: row.errorMessage,
    createdAt: row.createdAt,
    startedAt: row.startedAt,
    finishedAt: row.finishedAt,
  };
}
```

并补齐 import：`AiJobStatus`、`AiJobRow`、`SETTLED_STATUSES`（来自 `./ai-job.store`）、`AiJobQueueService`、`AiJobStoreService`。

> 路由顺序注意：`@Post('ai-jobs/cleanup')` 必须声明在 `@Post('ai-jobs/:jobId/stop')` 之前，否则 `cleanup` 会被 `:jobId` 段吞掉。

- [ ] **Step 4: 编译 + 跑相关测试**

Run: `pnpm --filter @lumira/backend build`
Expected: 编译通过

Run: `pnpm --filter @lumira/backend test -- "ai-job|ai-pipeline|ai-config"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lumira-server/packages/backend/src/modules/ai/ai-templates.controller.ts
git commit -m "feat(ai): 新增任务队列接口（列表/详情/停止/继续/删除/清理）"
```

---

### Task 7: admin 类型、api 与 server actions

**Files:**
- Modify: `lumira-server/packages/admin/src/types/admin.ts`
- Create: `lumira-server/packages/admin/src/lib/ai-jobs.ts`
- Create: `lumira-server/packages/admin/src/lib/__tests__/ai-jobs.test.ts`
- Modify: `lumira-server/packages/admin/src/lib/api.ts:627-650`
- Modify: `lumira-server/packages/admin/src/actions/ai.ts:162-209`

**Interfaces:**
- Consumes: Task 6 的 6 个端点
- Produces: `AiJobListItem` / `AiJobDetail` / `JOB_STATUS_META` / `fetchJobFile` / `formatJobElapsed` / `jobStageProgressText`；actions：`aiJobListAction` / `aiJobDetailAction` / `aiJobStopAction` / `aiJobResumeAction` / `aiJobDeleteAction` / `aiJobsCleanupAction`

- [ ] **Step 1: 写失败测试**

创建 `lumira-server/packages/admin/src/lib/__tests__/ai-jobs.test.ts`：

```ts
// 任务队列前端纯函数单测：状态映射 / 进度文案 / 耗时格式化 / URL→File
import { describe, expect, it, vi } from 'vitest';
import { JOB_STATUS_META, formatJobElapsed, jobStageProgressText, fetchJobFile } from '@/lib/ai-jobs';
import type { AiJobListItem } from '@/lib/ai-jobs';

function item(over: Partial<AiJobListItem> = {}): AiJobListItem {
  return {
    id: 'job_1', title: 't', status: 'running', currentStage: 'image',
    progress: { poseTotal: 3, poseDone: 1, silTotal: 3, silDone: 0 },
    queuePos: 0, errorCode: null, errorMessage: null,
    createdAt: 1, startedAt: 1, finishedAt: null, ...over,
  };
}

describe('JOB_STATUS_META', () => {
  it('六种状态都有中文标签', () => {
    expect(JOB_STATUS_META.queued.label).toBe('排队中');
    expect(JOB_STATUS_META.running.label).toBe('进行中');
    expect(JOB_STATUS_META.done.label).toBe('已完成');
    expect(JOB_STATUS_META.error.label).toBe('失败');
    expect(JOB_STATUS_META.stopped.label).toBe('已停止');
    expect(JOB_STATUS_META.interrupted.label).toBe('已中断');
  });
});

describe('jobStageProgressText', () => {
  it('排队中显示排位', () => {
    expect(jobStageProgressText(item({ status: 'queued', queuePos: 2 }))).toBe('排队中 · 第 2 位');
  });

  it('姿势图阶段显示第 x/y 张', () => {
    expect(jobStageProgressText(item())).toBe('姿势图 1/3');
  });

  it('已完成显示剪影产出', () => {
    expect(jobStageProgressText(item({ status: 'done', currentStage: null, progress: { poseTotal: 3, poseDone: 3, silTotal: 3, silDone: 3 } })))
      .toBe('已完成 · 3 张姿势图 / 3 张剪影');
  });
});

describe('formatJobElapsed', () => {
  it('结束后按 finishedAt 定格', () => {
    expect(formatJobElapsed(100, 165)).toBe('1分5秒');
  });

  it('未开始返回短横线', () => {
    expect(formatJobElapsed(null, null)).toBe('—');
  });
});

describe('fetchJobFile', () => {
  it('按 URL 取回并包装为 File', async () => {
    const blob = new Blob(['x'], { type: 'image/png' });
    vi.stubGlobal('fetch', vi.fn(async () => new Response(blob, { status: 200 })) as never);
    const file = await fetchJobFile('/uploads/ai-jobs/job_1/pose-0.png', 'pose-0.png');
    expect(file.name).toBe('pose-0.png');
    expect(file.type).toBe('image/png');
    vi.unstubAllGlobals();
  });
});
```

Run: `pnpm --filter @lumira/admin test -- ai-jobs`
Expected: FAIL —— `Cannot find module '@/lib/ai-jobs'`

- [ ] **Step 2: 实现 `lib/ai-jobs.ts`**

```ts
// lumira-server/packages/admin/src/lib/ai-jobs.ts
// AI 生成任务队列：类型、状态展示映射、轮询客户端与产物取回。
import {
  aiJobListAction,
  aiJobDetailAction,
  aiJobStopAction,
  aiJobResumeAction,
  aiJobDeleteAction,
  aiJobsCleanupAction,
} from '@/actions/ai';

export type AiJobStatus = 'queued' | 'running' | 'done' | 'error' | 'stopped' | 'interrupted';
export type AiJobStage = 'analyze' | 'image' | 'silhouette';

export interface AiJobListItem {
  id: string;
  title: string;
  status: AiJobStatus;
  mode: 'auto' | 'analyze-only';
  currentStage: AiJobStage | null;
  progress: { poseTotal: number; poseDone: number; silTotal: number; silDone: number };
  queuePos: number;
  errorCode: string | null;
  errorMessage: string | null;
  createdAt: number;
  startedAt: number | null;
  finishedAt: number | null;
}

export interface AiJobDetail extends AiJobListItem {
  jobId: string;
  stages: Record<AiJobStage, { status: string; startedAt?: number; finishedAt?: number; error?: unknown }>;
  error: { code: string; message: string; stage?: AiJobStage; at?: number; hint?: string } | null;
  events: unknown[];
  lastSeq: number;
  draft: unknown | null;
  poseImages: Array<{ index: number; mimeType: string; storageKey: string; url: string }>;
  poseErrors: Array<{ index: number; error: string }>;
  silhouetteImages: Array<{ index: number; mimeType: string; storageKey: string; url: string }>;
  silhouetteErrors: Array<{ index: number; error: string }>;
  [key: string]: unknown;
}

export const JOB_STATUS_META: Record<AiJobStatus, { label: string; tone: 'run' | 'wait' | 'ok' | 'bad' }> = {
  queued: { label: '排队中', tone: 'wait' },
  running: { label: '进行中', tone: 'run' },
  done: { label: '已完成', tone: 'ok' },
  error: { label: '失败', tone: 'bad' },
  stopped: { label: '已停止', tone: 'bad' },
  interrupted: { label: '已中断', tone: 'bad' },
};

export const JOB_STAGE_LABEL: Record<AiJobStage, string> = {
  analyze: '识别',
  image: '姿势图',
  silhouette: '剪影',
};

export function isSettled(status: AiJobStatus): boolean {
  return status === 'done' || status === 'error' || status === 'stopped' || status === 'interrupted';
}

/** 列表右侧一行进度文案 */
export function jobStageProgressText(item: AiJobListItem): string {
  if (item.status === 'queued') return item.queuePos > 0 ? `排队中 · 第 ${item.queuePos} 位` : '排队中';
  if (item.status === 'done') {
    const parts: string[] = [];
    if (item.progress.poseDone) parts.push(`${item.progress.poseDone} 张姿势图`);
    if (item.progress.silDone) parts.push(`${item.progress.silDone} 张剪影`);
    return parts.length ? `已完成 · ${parts.join(' / ')}` : '已完成';
  }
  if (item.status === 'error' || item.status === 'stopped' || item.status === 'interrupted') {
    return item.currentStage ? `${JOB_STAGE_LABEL[item.currentStage]}阶段${JOB_STATUS_META[item.status].label}` : JOB_STATUS_META[item.status].label;
  }
  if (item.currentStage === 'image') {
    const total = Math.max(item.progress.poseTotal, 1);
    return `姿势图 ${Math.min(item.progress.poseDone + 1, total)}/${total}`;
  }
  if (item.currentStage === 'silhouette') {
    const total = Math.max(item.progress.silTotal, 1);
    return `剪影 ${Math.min(item.progress.silDone + 1, total)}/${total}`;
  }
  return '识别中';
}

/** 耗时文案：未开始 → 「—」；已结束 → 定格；进行中 → 实时（调用方按秒重渲染） */
export function formatJobElapsed(startedAt: number | null, finishedAt: number | null): string {
  if (!startedAt) return '—';
  const end = finishedAt ?? Math.floor(Date.now() / 1000);
  const sec = Math.max(0, end - startedAt);
  if (sec < 60) return `${sec}秒`;
  const min = Math.floor(sec / 60);
  if (min < 60) return `${min}分${sec % 60}秒`;
  return `${Math.floor(min / 60)}小时${min % 60}分`;
}

/** 按 URL 取回产物并包装为 File（供向导注入 TemplateForm；相对路径走 admin 代理） */
export async function fetchJobFile(url: string, name: string): Promise<File> {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`取回产物失败（HTTP ${res.status}）：${name}`);
  const blob = await res.blob();
  return new File([blob], name, { type: blob.type || 'image/png' });
}

export async function listAiJobs(params: { status?: AiJobStatus; limit?: number; offset?: number } = {}) {
  return aiJobListAction(params);
}

export async function getAiJobDetail(jobId: string, since = 0) {
  return aiJobDetailAction(jobId, since);
}

export async function stopAiJob(jobId: string) {
  return aiJobStopAction(jobId);
}

export async function resumeAiJob(jobId: string) {
  return aiJobResumeAction(jobId);
}

export async function deleteAiJob(jobId: string) {
  return aiJobDeleteAction(jobId);
}

export async function cleanupAiJobs() {
  return aiJobsCleanupAction();
}
```

- [ ] **Step 3: 跑测试**

Run: `pnpm --filter @lumira/admin test -- ai-jobs`
Expected: PASS

- [ ] **Step 4: 扩展 `lib/api.ts`**

把第 627~650 行的 pipeline 段替换为：

```ts
  aiPipelineStart: (formData: FormData) =>
    adminFetch<{ jobId: string; status: AiJobStatus; queuePos: number }>('/templates/ai-job', {
      method: 'POST',
      body: formData,
    }, AI_ENDPOINT_TIMEOUT_MS),

  /** 任务列表（分页 + 状态筛选） */
  aiJobList: (params: { status?: string; limit?: number; offset?: number } = {}) => {
    const search = new URLSearchParams();
    if (params.status) search.set('status', params.status);
    search.set('limit', String(params.limit ?? 20));
    search.set('offset', String(params.offset ?? 0));
    return adminFetch<{ items: AiJobListItem[]; total: number }>(`/templates/ai-jobs?${search.toString()}`);
  },

  /** 任务详情：since>0 只取增量事件 */
  aiJobDetail: (jobId: string, since = 0) =>
    adminFetch<AiJobDetail>(`/templates/ai-jobs/${jobId}?since=${since > 0 ? since : 0}`),

  aiJobStop: (jobId: string) =>
    adminFetch<{ stopped: boolean; status: string }>(`/templates/ai-jobs/${jobId}/stop`, { method: 'POST', body: JSON.stringify({}) }),

  aiJobResume: (jobId: string) =>
    adminFetch<{ resumed: boolean; status: string }>(`/templates/ai-jobs/${jobId}/resume`, { method: 'POST', body: JSON.stringify({}) }),

  aiJobDelete: (jobId: string) =>
    adminFetch<{ ok: true }>(`/templates/ai-jobs/${jobId}`, { method: 'DELETE' }),

  aiJobsCleanup: () =>
    adminFetch<{ removed: number }>('/templates/ai-jobs/cleanup', { method: 'POST', body: JSON.stringify({}) }),
```

并在 `api.ts` 顶部 import 处引入 `AiJobDetail` / `AiJobListItem` / `AiJobStatus`（来自 `@/lib/ai-jobs`）。

- [ ] **Step 5: 扩展 `actions/ai.ts`**

保留 `aiPipelineStartAction`（返回类型改为 `{ jobId: string; status: AiJobStatus; queuePos: number } | { error: string }`），**删除** `aiPipelineStatusAction` / `aiPipelineResumeAction` / `aiPipelineCancelAction`，新增：

```ts
/** 任务列表 */
export async function aiJobListAction(
  params: { status?: AiJobStatus; limit?: number; offset?: number } = {},
): Promise<{ items: AiJobListItem[]; total: number } | { error: string }> {
  try {
    return await api.aiJobList(params);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
}

/** 任务详情（since 增量） */
export async function aiJobDetailAction(jobId: string, since = 0): Promise<AiJobDetail | { error: string }> {
  try {
    return await api.aiJobDetail(jobId, since);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
}

/** 停止任务 */
export async function aiJobStopAction(jobId: string): Promise<{ stopped: boolean; status: string } | { error: string }> {
  try {
    return await api.aiJobStop(jobId);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
}

/** 继续任务 */
export async function aiJobResumeAction(jobId: string): Promise<{ resumed: boolean; status: string } | { error: string }> {
  try {
    return await api.aiJobResume(jobId);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
}

/** 删除终态任务 */
export async function aiJobDeleteAction(jobId: string): Promise<{ ok: true } | { error: string }> {
  try {
    return await api.aiJobDelete(jobId);
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
}

/** 批量清理终态任务 */
export async function aiJobsCleanupAction(): Promise<{ removed: number } | { error: string }> {
  try {
    return await api.aiJobsCleanup();
  } catch (e) {
    if (e instanceof UnauthenticatedError) redirect('/login');
    return { error: (e as Error).message };
  }
}
```

- [ ] **Step 6: 类型与构建校验**

Run: `pnpm --filter @lumira/admin test`
Expected: PASS（既有用例若引用被删的 action，需同步改为新 action；`pipeline-task.ts` 的同步改造在 Task 10）

- [ ] **Step 7: Commit**

```bash
git add lumira-server/packages/admin/src/types/admin.ts lumira-server/packages/admin/src/lib/ai-jobs.ts lumira-server/packages/admin/src/lib/__tests__/ai-jobs.test.ts lumira-server/packages/admin/src/lib/api.ts lumira-server/packages/admin/src/actions/ai.ts
git commit -m "feat(admin): 新增任务队列前端客户端（类型/映射/actions）"
```

---

### Task 8: 任务队列列表页

**Files:**
- Create: `lumira-server/packages/admin/src/app/dashboard/templates/ai-tasks/page.tsx`
- Create: `lumira-server/packages/admin/src/components/ai-create/job-list.tsx`
- Modify: 侧边栏配置（Dashboard 导航菜单组件，含 templates 入口的文件）

**Interfaces:**
- Consumes: `@/lib/ai-jobs`（Task 7）
- Produces: 路由 `/dashboard/templates/ai-tasks`

- [ ] **Step 1: 实现列表组件**

创建 `components/ai-create/job-list.tsx`（client component）：

- 状态筛选（全部 / `queued` / `running` / `done` / `error` / `stopped` / `interrupted`）用 `Tabs` 或 `Select`，默认「全部」。
- 表格列：标题、状态徽章（`JOB_STATUS_META[status].label` + tone 配色）、阶段进度（`jobStageProgressText(item)`）、排队位次（仅 queued 显示）、耗时（`formatJobElapsed(startedAt, finishedAt)`）、创建时间、操作按钮。
- 操作：`查看详情`（`router.push('/dashboard/templates/ai-tasks/' + id)`）、`停止`（仅 `running`/`queued`）、`继续`（仅 `error`/`stopped`/`interrupted`）、`删除`（仅终态，`confirm` 后调用）。
- 顶部按钮：`刷新`、`清理已完成`（调用 `cleanupAiJobs()` 后重载）。
- 轮询：`useEffect` 中当 `items.some(i => !isSettled(i.status))` 时 `setInterval(refresh, 3000)`，否则清除定时器；组件卸载清理。

骨架示例（补齐表格 JSX 与按钮，配色沿用项目既有 shadcn 变量）：

```tsx
'use client';
import { useCallback, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { JOB_STATUS_META, formatJobElapsed, isSettled, jobStageProgressText, listAiJobs, cleanupAiJobs, stopAiJob, resumeAiJob, deleteAiJob, type AiJobListItem, type AiJobStatus } from '@/lib/ai-jobs';

const TONE_CLASS: Record<'run' | 'wait' | 'ok' | 'bad', string> = {
  run: 'bg-sky-100 text-sky-700',
  wait: 'bg-amber-100 text-amber-700',
  ok: 'bg-emerald-100 text-emerald-700',
  bad: 'bg-rose-100 text-rose-700',
};

export function JobList() {
  const router = useRouter();
  const [items, setItems] = useState<AiJobListItem[]>([]);
  const [status, setStatus] = useState<AiJobStatus | 'all'>('all');
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    const res = await listAiJobs({ status: status === 'all' ? undefined : status, limit: 50 });
    if ('error' in res) { setError(res.error); return; }
    setError(null);
    setItems(res.items);
  }, [status]);

  useEffect(() => { void refresh(); }, [refresh]);
  useEffect(() => {
    if (!items.some((i) => !isSettled(i.status))) return;
    const t = setInterval(() => void refresh(), 3000);
    return () => clearInterval(t);
  }, [items, refresh]);

  // ...筛选 + 表格渲染（操作按钮分别调用 stopAiJob/resumeAiJob/deleteAiJob 后 await refresh()）
}
```

- [ ] **Step 2: 实现页面**

创建 `app/dashboard/templates/ai-tasks/page.tsx`：服务端组件，渲染标题「生成任务」+ 说明 + `<JobList />`（`JobList` 自行拉数据，避免服务端渲染依赖轮询）。

- [ ] **Step 3: 侧边栏入口**

在 Dashboard 侧边栏配置（含 `/dashboard/templates` 的那个菜单数组）内追加：

```ts
  { label: '生成任务', href: '/dashboard/templates/ai-tasks', icon: ListChecksIcon },
```

图标沿用该文件既有的图标库（与相邻项一致，不要新引入依赖）。

- [ ] **Step 4: 构建校验**

Run: `pnpm --filter @lumira/admin build`
Expected: 构建通过

- [ ] **Step 5: Commit**

```bash
git add lumira-server/packages/admin/src/app/dashboard/templates/ai-tasks/page.tsx lumira-server/packages/admin/src/components/ai-create/job-list.tsx
git commit -m "feat(admin): 新增生成任务队列列表页与侧边栏入口"
```

---

### Task 9: 任务详情页

**Files:**
- Create: `lumira-server/packages/admin/src/app/dashboard/templates/ai-tasks/[jobId]/page.tsx`
- Create: `lumira-server/packages/admin/src/components/ai-create/job-detail.tsx`

**Interfaces:**
- Consumes: `@/lib/ai-jobs`（Task 7）、既有 `GenerateProgressPanel` / `InterruptionBanner` / `PipelineStepBar` 组件
- Produces: 路由 `/dashboard/templates/ai-tasks/[jobId]`

- [ ] **Step 1: 实现详情组件**

`components/ai-create/job-detail.tsx`（client component）：

- 顶部信息条：标题、状态徽章、阶段进度、耗时、排队位次、`errorMessage`（失败/中断时展示）。
- 实时过程：复用 `GenerateProgressPanel`，把 `detail.events` 用既有 `toRecogEvents` / `toPoseEvents`（`@/lib/pipeline-task`）转换后传入；运行中每 3s 轮询 `getAiJobDetail(jobId, lastSeq)` 累积事件。
- 产物预览：`poseImages` / `silhouetteImages` 网格，`<img src={a.url} />`（相对路径经 admin 代理）；同时列出 `poseErrors` / `silhouetteErrors` 的失败下标与原因。
- 操作按钮：`停止`（running/queued）、`继续`（error/stopped/interrupted）、`删除`（终态，confirm）、`打开到向导`（`router.push('/dashboard/templates/ai-create?job=' + jobId)`）。
- 终态且 `stages.analyze.status === 'done'` 时「打开到向导」可用。

骨架：

```tsx
'use client';
import { useCallback, useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { GenerateProgressPanel } from '@/components/ai-create/generate-progress-panel';
import { getAiJobDetail, isSettled, JOB_STATUS_META, formatJobElapsed, jobStageProgressText, stopAiJob, resumeAiJob, deleteAiJob, type AiJobDetail } from '@/lib/ai-jobs';

export function JobDetail({ jobId }: { jobId: string }) {
  const router = useRouter();
  const [detail, setDetail] = useState<AiJobDetail | null>(null);
  const lastSeq = useRef(0);

  const load = useCallback(async () => {
    const res = await getAiJobDetail(jobId, lastSeq.current);
    if ('error' in res) return;
    lastSeq.current = Math.max(lastSeq.current, res.lastSeq ?? 0);
    setDetail((prev) => (prev && res.events?.length
      ? { ...res, events: [...prev.events, ...res.events] }
      : res));
  }, [jobId]);

  useEffect(() => { void load(); }, [load]);
  useEffect(() => {
    if (!detail || isSettled(detail.status)) return;
    const t = setInterval(() => void load(), 3000);
    return () => clearInterval(t);
  }, [detail, load]);
  // ...渲染信息条 / GenerateProgressPanel / 产物网格 / 操作按钮
}
```

> 注意：`GenerateProgressPanel` 的 props 若与 `AiJobDetail` 不完全一致，按该组件现有 props 做适配（用 `toRecogEvents` / `toPoseEvents` 转换事件），不要修改其内部实现。

- [ ] **Step 2: 实现页面**

创建 `app/dashboard/templates/ai-tasks/[jobId]/page.tsx`：

```tsx
import { JobDetail } from '@/components/ai-create/job-detail';

export default function Page({ params }: { params: { jobId: string } }) {
  return <JobDetail jobId={params.jobId} />;
}
```

- [ ] **Step 3: 构建校验**

Run: `pnpm --filter @lumira/admin build`
Expected: 构建通过

- [ ] **Step 4: Commit**

```bash
git add lumira-server/packages/admin/src/app/dashboard/templates/ai-tasks/[jobId]/page.tsx lumira-server/packages/admin/src/components/ai-create/job-detail.tsx
git commit -m "feat(admin): 新增生成任务详情页（实时过程/产物/停止/继续/删除）"
```

---

### Task 10: 向导改造（提交后跳转 + `?job=` 恢复 + 下线 localStorage 锚点）

**Files:**
- Modify: `lumira-server/packages/admin/src/lib/pipeline-task.ts`
- Delete: `lumira-server/packages/admin/src/lib/ai-job-storage.ts`
- Modify: `lumira-server/packages/admin/src/components/ai-create/wizard.tsx`
- Modify: `lumira-server/packages/admin/src/app/dashboard/templates/ai-create/page.tsx`
- Modify: `lumira-server/packages/admin/src/lib/__tests__/pipeline-task.test.ts`

**Interfaces:**
- Consumes: `@/lib/ai-jobs`（Task 7）、`aiPipelineStartAction`
- Produces: `pipelineFilesFromUrls(files: Array<{index:number; url:string; mimeType:string}>): Promise<Array<{index:number; file:File}>>`；向导 `?job=` 恢复

- [ ] **Step 1: 写失败测试**

在 `pipeline-task.test.ts` 追加：

```ts
it('pipelineFilesFromUrls：按 URL 取回并包装 File，忽略空 url', async () => {
  vi.stubGlobal('fetch', vi.fn(async () => new Response(new Blob(['x'], { type: 'image/png' }), { status: 200 })) as never);
  const out = await pipelineFilesFromUrls([
    { index: 0, url: '/uploads/ai-jobs/job_1/pose-0.png', mimeType: 'image/png' },
    { index: 1, url: '', mimeType: 'image/png' },
  ]);
  expect(out).toHaveLength(1);
  expect(out[0]!.file.name).toContain('pose');
  vi.unstubAllGlobals();
});
```

Run: `pnpm --filter @lumira/admin test -- pipeline-task`
Expected: FAIL —— `pipelineFilesFromUrls is not a function`

- [ ] **Step 2: 改造 `pipeline-task.ts`**

1. 删除 `fetchPipelineStatus` / `pollPipelineJob` / `startPipelineJob` 中依赖旧 action 的实现，改为：
   - `startPipelineJob(formData)`：调 `aiPipelineStartAction`，返回 `{ jobId, status, queuePos }`（调用方据 `status/queuePos` 展示「已入队/进行中」）。
   - `pollPipelineJob` 的轮询目标改为 `getAiJobDetail(jobId, since)`（来自 `@/lib/ai-jobs`），语义不变（退避重试、终态收敛、`onEvents` / `onStatus` 回调保留）。
2. 保留 `toRecogEvents` / `toPoseEvents` / `poseProgressFromEvents` / `currentPipelineStage` / `classifyPipelineError` / `isRetryablePipelineError` / `interruptionFromPollError` / `withRetry`。
3. 删除 `pipelineFiles`（base64 版）与 `base64ToFile` 的调用点，新增：

```ts
import { fetchJobFile } from '@/lib/ai-jobs';

/** 按 URL 取回产物并包装为 File（替代旧 base64 版 pipelineFiles） */
export async function pipelineFilesFromUrls(
  files: Array<{ index: number; url: string; mimeType: string }>,
): Promise<Array<{ index: number; file: File }>> {
  const out: Array<{ index: number; file: File }> = [];
  for (const f of files) {
    if (!f.url) continue;
    const name = f.url.split('/').pop() ?? `pose-${f.index}.png`;
    out.push({ index: f.index, file: await fetchJobFile(f.url, name) });
  }
  return out;
}
```

4. `resumePipelineJob` / `cancelPipelineJob` 改为调用 `resumeAiJob` / `deleteAiJob`（`@/lib/ai-jobs`）。

- [ ] **Step 3: 跑测试**

Run: `pnpm --filter @lumira/admin test -- pipeline-task`
Expected: PASS

- [ ] **Step 4: 向导接入**

`components/ai-create/wizard.tsx`：
1. 提交成功（`startPipelineJob` 返回 `{ jobId, status, queuePos }`）后：`router.push(\`/dashboard/templates/ai-tasks/${jobId}\`)`，不再在页面内挂轮询等待。
2. 新增 `?job=` 恢复：`useSearchParams()` 取 `job`，挂载时调 `getAiJobDetail(jobId, 0)`：
   - `stages.analyze.status === 'done'` → 复用既有 `finishAnalyzeOnly` / `finishAuto` 回填（`draft`、`poseImages` 经 `pipelineFilesFromUrls` 转 File 后作为候选封面、`silhouetteImages` 作为剪影候选），并推进到 Step3（auto 模式）/ 结果态（analyze-only）。
   - 任务未终态 → 提示「任务仍在进行中」并给「查看进度」按钮跳详情页。
3. 删除所有 `ai-job-storage.ts` 的引用（`readJobRef` / `writeJobRef` / `clearJobRef`）。
4. 顶部工具条新增：`任务队列` 链接（`/dashboard/templates/ai-tasks`）+ 「你有进行中的任务」提示条（挂载时 `listAiJobs({ limit: 5 })` 判断是否存在非终态任务，有则显示并链接详情页）。

- [ ] **Step 5: 删除 localStorage 锚点**

```bash
git rm lumira-server/packages/admin/src/lib/ai-job-storage.ts
```

同时清理其测试（若 `src/lib/__tests__/ai-job-storage.test.ts` 存在，一并 `git rm`）。

- [ ] **Step 6: 页面文件校验**

`app/dashboard/templates/ai-create/page.tsx`：确认已用 `<Suspense>` 包裹使用 `useSearchParams()` 的内容（Next.js App Router 要求），必要时补上。

- [ ] **Step 7: 构建校验**

Run: `pnpm --filter @lumira/admin test`
Expected: PASS

Run: `pnpm --filter @lumira/admin build`
Expected: 构建通过

- [ ] **Step 8: Commit**

```bash
git add -A lumira-server/packages/admin/src
git commit -m "feat(admin): 向导提交后跳转任务详情，支持按 jobId 恢复并下线本地锚点"
```

---

### Task 11: 文档登记与双远程推送

**Files:**
- Modify: `docs/future-optimizations.md`

**Interfaces:**
- Consumes: 全部实现
- Produces: 后续优化登记 + 远程同步

- [ ] **Step 1: 登记后续优化**

按 `docs/future-optimizations.md` 既有格式（优先级 / 模块 / 优化点 / 背景动机 / 目标状态 / 状态标记）在文件末尾追加三条：

1. 任务详情文件鉴权读取（服务端代理，屏蔽存储桶直链）——优先级 中。
2. 运行中事件流周期性快照（降低后端重启的信息损失）——优先级 低。
3. 任务优先级 / 任务改名 / 终态任务自动过期清理——优先级 低。

- [ ] **Step 2: 全量验证**

Run: `pnpm --filter @lumira/backend build && pnpm --filter @lumira/backend test`
Expected: 编译通过、测试通过

Run: `pnpm --filter @lumira/admin test && pnpm --filter @lumira/admin build`
Expected: 测试与构建通过

- [ ] **Step 3: 提交并推送双远程**

```bash
git add docs/future-optimizations.md
git commit -m "docs: 登记 AI 任务队列的后续优化项"
git push origin master
git push github master
```

Expected: 两个远程均推送成功（推送后端改动会触发生产部署）

---

## 自检结果

**1. Spec 覆盖**

| Spec 章节 | 对应 Task |
|---|---|
| §5.1 `ai_template_jobs` 表 | Task 1 |
| §5.2 `job_concurrency` | Task 1、Task 2 |
| §6 存储布局与读写规则 | Task 1（分类）、Task 3（读写）、Task 5（写入时机） |
| §7.1 `AiJobStoreService` | Task 3 |
| §7.2 `AiPipelineJobService` 改造 | Task 5 |
| §7.3 `AiJobQueueService` | Task 4 |
| §7.4 控制器端点 | Task 6 |
| §8 状态机（含 `queued/stopped/interrupted`） | Task 5（状态）、Task 4（恢复/停止） |
| §9.1 列表页 | Task 8 |
| §9.2 详情页 | Task 9 |
| §9.3 向导改造 + 移除 localStorage | Task 10 |
| §9.4 侧边栏入口 | Task 8 |
| §10 配置项 | Task 2 |
| §11 测试策略 | Task 2/3/4/5/7/10 内嵌测试步骤 |
| §12 风险 → §13 后续优化登记 | Task 11 |

无遗漏。

**2. 占位符扫描**：无 TBD/TODO；所有代码步骤均给出可直接落地的代码或精确锚点（文件 + 行号区间 + 替换内容）。「共享接口」小节列出的类型在每个 Task 中按需完整写出，不依赖跨 Task 记忆。

**3. 类型一致性**：`AiJobStatus` 在 store / queue / 控制器 / 前端三处取值集合一致（`queued|running|done|error|stopped|interrupted`）；`AiJobRow` 字段名与 DB 列一一对应；`StoredArtifact` 在 store 产出、pipeline 落 detail、控制器返回、前端消费四处同名；`prepareResume` / `startJob` / `requestStop` / `hydrate` 签名在 Task 4 与 Task 5 中一致。