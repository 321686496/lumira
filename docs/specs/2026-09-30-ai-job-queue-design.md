# AI 一键生成模板 · 任务队列化设计

- 日期：2026-09-30
- 范围：`lumira-server/packages/backend`（AI 模块、存储抽象、AI 设置）、`lumira-server/packages/admin`（任务队列页、详情页、向导）
- 前置文档：`docs/specs/2026-09-09-ai-template-one-click-creation-design.md`、`docs/specs/2026-09-10-ai-create-enhancement-design.md`

## 1. 背景与问题

现有「AI 一键建模」由 `AiPipelineJobService` 驱动（识别 → 批量姿势图 → 剪影），存在四个结构性缺陷：

1. **任务只在内存**：`jobs: Map<string, AiPipelineJob>`，TTL 60 分钟，后端重启即丢。
2. **页面强绑定**：前端只在 `localStorage` 存一个 `jobId`（`ai-job-storage.ts`），同一时间只能跟踪一个任务；换设备、清缓存、任务终态后引用即失效。
3. **无任务视图**：看不到「现在有哪些任务在跑、排到第几、跑到哪一步」，也无法在不进向导的情况下查看。
4. **响应体膨胀**：终态响应回传 base64 产物（3~9 张姿势图 + 剪影），单次响应可达数 MB。
5. **无并发治理**：每个任务创建即开跑，多个任务同时抢生图额度，互相拖慢。

## 2. 目标

- 任务落库 + 产物/详情落存储，**刷新页面、退出页面、换设备、后端重启后进度都还在**。
- 新增**任务队列页**：看排队中/进行中的任务及实时进度、排位、耗时。
- 新增**任务详情页**：看完整实时过程（提示词 / 模型输出 / 上游原始响应）、产物预览。
- 支持**排队调度**（并发上限 + 排队位次），并发数在后台「AI 设置」可配置。
- 支持**停止运行中的任务**、**继续中断的任务**、**删除已完成任务并连带删除其文件**。

## 3. 非目标（YAGNI）

- 不做自动续跑（后端重启后 `running` 任务标 `interrupted`，由人工点「继续」）。
- 不做任务改名、任务分组、任务优先级。
- 不做终态任务自动过期清理（只提供手动删除 + 批量清理已完成）。
- 不做多副本/分布式调度（单进程内存队列 + DB 为真相源，与现有单容器部署一致）。
- 不做旧接口向后兼容（admin 与 backend 同仓同发，旧 `ai-job` 端点直接改造）。
- 不做运行中事件流的周期性落盘（事件流只在终态写一次）。

## 4. 关键决策（已与用户确认）

| 决策点 | 结论 |
|---|---|
| 流程形态 | 后台化 + 队列列表页；**向导保留**为「提交输入 + 审核产物」工作台 |
| 排队语义 | **真队列**：并发上限 + `queued` 排队中 + 排位 |
| 产物存储 | 走现有 `StorageAdapter` 落文件，DB 只存引用与计数 |
| 列表数据 | DB 只存列表展示字段；完整事件流/草稿等大体积数据落存储文件，DB 通过 `detail_key` 关联 |
| 删除 | 终态任务可删，删 DB 行 + 删任务文件夹 |
| 停止 | 运行中/排队中可「停止」，协作式取消，停在检查点并保留已产出 |
| 并发数 | 在后台「AI 设置」配置（默认 2，范围 1~5） |

## 5. 数据模型

### 5.1 新表 `ai_template_jobs`（迁移 `051_ai_template_jobs.sql`）

```sql
CREATE TABLE `ai_template_jobs` (
  `id` TEXT PRIMARY KEY,
  `status` TEXT NOT NULL,                 -- queued | running | done | error | stopped | interrupted
  `mode` TEXT NOT NULL,                   -- auto | analyze-only
  `title` TEXT NOT NULL,                  -- 自动生成：文字描述前 20 字，否则「N 张示例图」
  `current_stage` TEXT,                   -- analyze | image | silhouette
  `pose_total` INT NOT NULL DEFAULT 0,
  `pose_done` INT NOT NULL DEFAULT 0,
  `sil_total` INT NOT NULL DEFAULT 0,
  `sil_done` INT NOT NULL DEFAULT 0,
  `queue_pos` INT NOT NULL DEFAULT 0,     -- 仅 queued 有意义；1 = 下一个出队，0 = 未排队
  `input_summary_json` TEXT,              -- 列表展示用的输入摘要（不含图片字节）
  `error_code` TEXT,
  `error_message` TEXT,
  `detail_key` TEXT,                      -- /uploads/ai-jobs/{id}/
  `created_at` INT NOT NULL,
  `started_at` INT,
  `finished_at` INT
);
CREATE INDEX idx_ai_template_jobs_status_created ON ai_template_jobs (status, created_at);
```

`input_summary_json` 结构：`{ imageCount, refCount, hasText, textPreview(≤80 字), poseCount, subjectCount, silMode, silEngine, refAnchor }`。
`error_code` 复用现有 `InterruptionCode`，另增 `interrupted`（后端重启）。

**明确不存**：事件流、draft、research、base64、图片字节。

### 5.2 AI 设置新增列（同一迁移）

```sql
ALTER TABLE `ai_provider_config`
  ADD COLUMN `job_concurrency` INT NOT NULL DEFAULT 2 COMMENT 'AI 生成任务并发上限（1~5）';
```

## 6. 存储布局

新增 `StorageCategory = 'ai-jobs'`，一个任务一个目录：`/uploads/ai-jobs/{jobId}/`

```
{jobId}/
├── detail.json          # draft / warnings / trace / raw / research / brief / vision / stages / error / inputSummary
├── events.jsonl         # 完整事件流（逐行 JSON，含 systemPrompt / userPrompt / response / rawResponse）
├── input/
│   ├── example-{i}.{ext}    # 示例图（供停止后续跑 / 重启后续跑）
│   └── ref-{i}.{ext}        # 姿势参考图
├── pose-{i}.{ext}       # 姿势图产物
└── sil-{i}.{ext}        # 剪影产物
```

**读写规则**

| 文件 | 写入时机 | 读取方式 |
|---|---|---|
| `input/*` | 任务创建时 | `readBuffer`（仅续跑用） |
| `pose-{i}` / `sil-{i}` | 每张生成完成即写 | 公网 URL（`/uploads/...`） |
| `detail.json` | analyze 完成、image 完成、终态各写一次 | `readBuffer`（详情 API 内部读） |
| `events.jsonl` | 仅终态写一次（全量事件） | `readBuffer`（详情 API 内部读） |

- 产物图**一次写入不覆盖**，沿用 `/uploads` 的 `immutable` 强缓存；前端用相对路径 `/uploads/...` 经 admin 的 `next.config.js` rewrite 代理，避免 CORS 与 Mixed Content。
- `detail.json` / `events.jsonl` **不暴露公网 URL**，只经 admin API `readBuffer` 读取（规避 immutable 缓存导致内容不更新，并降低文本外泄面）。
- 运行中任务的详情（草稿/研究/事件流）直接读**内存**，不读文件，保证实时性；终态/重启后读文件。

## 7. 后端架构

拆成三个职责单一的服务 + 一个控制器：

### 7.1 `AiJobStoreService`（持久化层，无业务）

- DB 行 CRUD：`insert` / `updateStatus` / `updateProgress` / `updateQueuePos` / `list` / `find` / `remove`
- 详情文件：`writeDetail(jobId, detail)`、`readDetail(jobId)`、`writeEvents(jobId, events)`、`readEvents(jobId)`
- 产物与输入：`writePose(jobId, index, buf)`、`writeSil(...)`、`writeInput(...)`、`readInput(jobId, kind, index)`
- 删除：`deleteJob(jobId)` → DB 行 + `deleteByDir('ai-jobs', jobId)`
- 对外只暴露「存/取/删」，不含调度与阶段逻辑，可独立单测。

### 7.2 `AiPipelineJobService`（执行引擎，改造现有文件）

- 保留三阶段执行、事件流（`AiTraceEvent`）、逐张重试、`resume` 语义。
- **变更点**
  - job 不再有 TTL 清理；新增 `stopRequested` 标记。
  - 创建任务改为「入队」：创建内存 job + 落 DB 行 + 落 `input/*`，状态 `queued`，交由队列服务调度（不再 `create()` 里直接 `runPipeline`）。
  - 每张图生成完成 → 立即 `writePose/writeSil` + 更新 DB 计数。
  - analyze 完成 / image 完成 / 终态 → `writeDetail`；终态额外 `writeEvents`。
  - 检查点：`runPipeline` 每阶段开始前、`runOne` 每张开始前、`generateWithRetry` 每次重试前检查 `stopRequested`；命中抛 `JobStoppedError` → 状态 `stopped`（保留已完成产物与草稿，写 detail + events）。
  - 续跑（`error` / `stopped` / `interrupted`）前先 `readDetail` + `readInput` 把内存态补全，再走现有 `resume` 逻辑。
- **产物响应改为 URL**：`poseImages` / `silhouetteImages` 返回 `{ index, url, storageKey, mimeType }`，不再回传 base64。

### 7.3 `AiJobQueueService`（调度层）

- 内存 FIFO 队列（按 `created_at` 升序）+ 运行计数；DB 为真相源。
- `enqueue(jobId)`：有空位则立即 `startJob`（置 `running`），否则置 `queued` 并刷新全部排队任务的 `queue_pos`。
- 任一任务进入终态 → `onSettled` → 出队下一个；出队时**实时**读取 `AiConfigService` 的 `jobConcurrency`（改动无需重启即生效）。
- `stop(jobId)`：`queued` → 直接取消排队置 `stopped`；`running` → 置 `stopRequested`，等执行引擎停在检查点。
- `onModuleInit()` 重启恢复：
  - `status='queued'` → 按 `created_at` 重建队列并调度
  - `status='running'` → 置 `interrupted`（`error_code='interrupted'`，`error_message` 说明后端重启）
  - 终态不动

### 7.4 控制器 `AiTemplatesController`（改造）

新端点（全部在 `AdminAuthGuard` 下）；旧 `ai-job` 系列端点改造为新语义：

```
POST   /api/v1/admin/templates/ai-job                      提交（入队）→ { jobId, status, queuePos }
GET    /api/v1/admin/templates/ai-jobs?status=&limit=&offset=   列表 → { items, total }
GET    /api/v1/admin/templates/ai-jobs/:id[?since=]            详情（含事件增量、产物 URL）
POST   /api/v1/admin/templates/ai-jobs/:id/stop               停止
POST   /api/v1/admin/templates/ai-jobs/:id/resume             继续
DELETE /api/v1/admin/templates/ai-jobs/:id                    删除（连带清文件）
POST   /api/v1/admin/templates/ai-jobs/cleanup                 批量清理全部终态任务（含其文件）
```

- 列表项字段：`id / title / status / mode / currentStage / progress{poseTotal,poseDone,silTotal,silDone} / queuePos / errorCode / errorMessage / createdAt / startedAt / finishedAt`。
- 详情字段：列表项全部 + `stages / error / draft / warnings / trace / raw / research / researchBrief / researchVision / poseImages[URL] / poseErrors / silhouetteImages[URL] / silhouetteErrors / events / lastSeq`。
- 运行中详情支持 `?since=` 增量；终态返回全量（沿用现有 `serialize` 的收敛策略，但不再有 base64 大字段）。

## 8. 状态机

```
              ┌── enqueue（有空位） ──────────────► running ──全部阶段成功──► done
queued ───────┤                                      │
   ▲          └── enqueue（无空位，排队中 queue_pos>0） │
   │                                                 ├── 阶段失败 ──────► error
   │                                                 ├── 用户停止 ──────► stopped
   │                                                 └── 进程重启 ──────► interrupted
   │                                                        │
   └──────────── resume（人工点「继续」）◄──────────────────┘
                     （error / stopped / interrupted）
```

- `queued` 点「停止」→ `stopped`（终态）；点「继续」→ 重新入队。
- 终态 = `done | error | stopped | interrupted`，仅终态可删除。

## 9. 前端设计

### 9.1 任务队列列表页 `/dashboard/templates/ai-tasks`

- 顶部：状态筛选（全部 / 排队中 / 进行中 / 已完成 / 失败 / 已中断 / 已停止）+「清理已完成」+「刷新」。
- 任务行：标题、模式徽章（一键全自动 / 仅识别）、状态徽章、当前阶段、进度（`第 x/y 张`）、排队位次、耗时、创建时间、操作（查看详情 / 停止 / 继续 / 删除）。
- 自动刷新：存在非终态任务时 3s 轮询，全部终态则停止轮询。

### 9.2 任务详情页 `/dashboard/templates/ai-tasks/[jobId]`

- 复用 `GenerateProgressPanel`（风格识别 / 姿势图生成 两 Tab）与 `InterruptionBanner`。
- 顶部：标题、状态、当前阶段、耗时、排队位次。
- 产物预览：姿势图 / 剪影网格（直接用 `/uploads` URL）。
- 操作：停止 / 继续 / 删除 / **打开到向导**（`/dashboard/templates/ai-create?job={id}`）。
- 运行中轮询 `?since=` 增量吸收事件。

### 9.3 向导 `/dashboard/templates/ai-create`（改造）

- 提交（「开始识别」/「一键生成并上架」）后：任务入队 → **跳转到任务详情页**，提示「已加入队列，可离开此页」。
- 新增 `?job={id}` 恢复模式：从详情 API 加载结果，复用现有 `finishAnalyzeOnly` / `finishAuto` 回填草稿、候选封面、剪影并推进到对应步骤（Step3 / Step4 / Step5）。
- 顶部新增「任务队列」入口 + 「你有进行中的任务」提示条（链接到详情页）。
- **移除** `ai-job-storage.ts` 的单任务 localStorage 锚点（改由队列页/URL 承载恢复）。
- 产物注入表单所需的 `File` 对象：新增按 URL 取回的异步转换（`fetch(url)` → `Blob` → `File`），URL 用相对路径 `/uploads/...` 走 admin 代理。

### 9.4 侧边栏

新增「生成任务」入口，指向 `/dashboard/templates/ai-tasks`。

## 10. 配置项（AI 设置）

| 层 | 改动 |
|---|---|
| 迁移 | `job_concurrency INT NOT NULL DEFAULT 2` |
| DTO | `jobConcurrency?: number`（`@IsInt @Min(1) @Max(5)`，缺省沿用原值） |
| `AiConfigService.get()` | 返回 `jobConcurrency: row.jobConcurrency ?? 2` |
| `AiConfigService.save()` | 与 `llmRetryCount` 同模式落库 |
| `ai-config-form.tsx` | 「识别稳定性」卡片内新增「生成任务并发数」（数字输入 1~5，含说明文案） |

## 11. 测试策略

- `ai-job-store.service.spec.ts`：DB 行 CRUD、`detail.json`/`events.jsonl` 读写、产物与输入写读、`deleteJob` 连带删目录。
- `ai-job-queue.service.spec.ts`：并发上限（上限 2 时第 3 个 `queued`）、FIFO 顺序、`queue_pos` 随出队更新、`stop` 出队、重启恢复（`queued` 重入队 / `running` 置 `interrupted`）、并发数读配置改动即生效。
- `ai-pipeline-job.service.spec.ts`：停止停在检查点且保留已产出、终态写 detail/events、续跑从存储恢复内存态、产物响应为 URL 而非 base64。
- `ai-config.service.spec.ts`：`jobConcurrency` 读写与默认值。
- 前端：`pnpm --filter @lumira/admin typecheck` + 构建；后端 `typecheck` + jest。

## 12. 风险与取舍

| 项 | 说明 | 处置 |
|---|---|---|
| 详情文本文件落在 R2/S3 桶内，路径不可枚举但无鉴权 | 与既有图片同一套「不可猜路径」策略 | 登记 `docs/future-optimizations.md`：改为服务端代理鉴权读取 |
| 运行中事件流不落盘 → 后端此刻重启会丢运行中事件 | 只影响「重启前最后的运行过程」 | 登记后续优化：运行中周期性快照 |
| 并发数=1 时长任务会让后续任务久等 | 列表已显示排位 | 可接受；后台可调大并发 |
| 停止为协作式，不中断已发出的上游 LLM 请求 | 最坏等当前调用返回 | 列表/详情明确提示「正在停止…」 |

## 13. 后续优化登记（写入 `docs/future-optimizations.md`）

1. 任务详情文件的鉴权读取（服务端代理，屏蔽存储桶直链）。
2. 运行中事件流的周期性快照（降低后端重启的信息损失）。
3. 任务优先级 / 任务改名 / 终态任务自动过期清理。