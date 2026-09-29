# AI 一键生成模板：断点续跑 + 中断原因详情 设计

- 日期：2026-09-29
- 范围：`lumira-server/packages/backend`（AI 模块）、`lumira-server/packages/admin`（AI 一键建模向导）
- 不涉及：数据库表结构、Flutter 端、`lumira-app`

## 1. 背景与问题

当前「AI 一键建模」由前端 `wizard.tsx` 顺序驱动 4 个阶段：

`analyzing`（识别）→ `generating-image`（批量姿势图作封面）→ `generating-silhouette`（剪影）→ `submitting`（提交上架）

每个阶段各自调用后端异步任务端点并轮询：

| 阶段 | 端点 | 前端轮询预算 |
| --- | --- | --- |
| analyzing | `POST /admin/templates/ai-analyze` → `GET .../ai-analyze/tasks/:taskId` | 60 min |
| generating-image | `POST .../ai-generate-image/batch` → `GET .../batch/:batchId` | 单张 15 min / 批次 60 min |
| generating-silhouette | `POST .../ai-generate-silhouette/tasks` → `GET .../tasks/:taskId` | 10 min |

存在的问题：

1. **没有断点续跑**：任一阶段中断（前端超时、网络/网关错误、用户中止、页面刷新、后端任务失败或超时清理），流程就停在对应步骤，已消耗的识别 / 生图成果无法复用于继续；用户只能从头再来。
2. **句柄易丢**：`taskId` / `batchId` 只存在 React state，页面刷新即丢失，无法重新挂回仍在运行的后端任务。
3. **中断原因不详细**：前端只拿到一个字符串错误（如「生成超时」），无法区分「上游超时 / 上游 HTTP 错误 / 网关网络错误 / 任务被清理 / 用户中止 / 前端等待预算耗尽」，也没有「停在哪个阶段、已耗时、最后一次成功的步骤、原始上游错误」等定位信息。
4. **带参考图识别会报「查询识别任务失败」（专项 bug）**：上传参考图后，识别常停在「示例图识别」并以固定文案失败，真实原因（单张视觉识别超时 / 轮询响应体过大 / 轮询无容错）被掩盖。详见 §9。

目标：把整条流水线的状态与产物收敛到后端一个「生成任务（job）」上，前端只持有一个 `jobId`；任意阶段中断时，给出**详细、分类明确的中断原因**，并提供**「继续」按钮**，优先重连仍在运行的任务，否则从失败阶段重跑并复用已完成成果。

## 2. 已确认的设计决策

| # | 决策 | 结论 |
| --- | --- | --- |
| 1 | 「继续」的语义 | **两者都要**：优先重连（后端任务仍在跑/已完成 → 挂回继续等/取结果）；任务不存在或真失败 → 从失败阶段重跑并复用已完成成果 |
| 2 | 续跑有效范围 | **后端「生成任务 job」承载**：产物与输入由后端保存，前端只持一个 `jobId` |
| 3 | 持久化深度 | **仅后端内存**（同现有任务机制）；`jobId` 持久化到浏览器（URL/localStorage）。后端重启/超时清理导致 job 消失时，UI 明确提示「任务已失效」并允许重跑 |
| 4 | 中断原因形式 | **分类错误码 + 分层详情**（阶段 / 摘要 / 原始上游错误 / 耗时 / 建议），过程面板时间线对应节点同步标红 |
| 5 | job 覆盖入口 | **手动「开始识别」与「一键生成并上架」共用同一 job**：手动 = 跑完识别阶段即停；全自动 = 跑全部阶段 |
| 6 | 后端落地结构 | **新建 `AiPipelineJobService` 承载输入 + 产物**，内部复用现有三个模型服务，不重写模型逻辑 |

## 3. 数据模型（后端内存）

新增 `AiPipelineJobService`（`lumira-server/packages/backend/src/modules/ai/ai-pipeline-job.service.ts`），内存 `Map<string, AiPipelineJob>` + 定时清理（沿用现有 `RESULT_TTL_MS = 60min` / `SWEEP_INTERVAL_MS = 60s` 模式，`sweeper.unref()`）。

```ts
type PipelineStage = 'analyze' | 'image' | 'silhouette';
type StageStatus = 'idle' | 'pending' | 'running' | 'done' | 'error';
type JobStatus = 'pending' | 'running' | 'waiting' | 'done' | 'error';

interface AiPipelineJob {
  id: string;                 // job_<nanoid>
  createdAt: number;
  updatedAt: number;
  /** 全自动 = 依次跑 3 个阶段；手动识别 = 只跑 analyze 后停在 waiting（等用户下一步） */
  mode: 'analyze-only' | 'auto';
  status: JobStatus;
  stage: PipelineStage;       // 当前/最后所处阶段
  stages: Record<PipelineStage, StageState>;
  /** 提交时一次性存下的输入，供「重跑失败阶段」复用，无需前端重新上传 */
  inputs: {
    exampleImages?: UploadFile[];
    referenceImages?: UploadFile[];
    text?: string;
    textDesc?: string | null;
    creationReq?: string | null;
    poseCount?: string | null;
    subjectCount?: string | null;
    /** 生图/剪影选项（全自动模式下由前端提交时指定） */
    options: {
      silhouetteMode: 'sketch' | 'solid';
      silhouetteCrop: boolean;
      silhouetteEngine: 'ai' | 'local';
    };
  };
  /** 阶段产物 */
  artifacts: {
    draft?: Record<string, unknown>;
    warnings?: string[];
    trace?: AiAnalyzeTraceEntry[];
    research?: AiResearchRef[];
    researchBrief?: AiResearchBrief | null;
    researchVision?: AiResearchVision | null;
    /** 已出图的姿势（按 index 排序；锚点 = index 0） */
    poseFiles?: Array<{ index: number; base64: string; mimeType: string }>;
    /** 已生成的剪影（按源姿势顺序） */
    silFiles?: Array<{ index: number; base64: string; mimeType: string }>;
  };
  /** 统一事件时间线（合并三阶段事件，事件带 stage 归属；按 seq 递增） */
  events: AiPipelineEvent[];
  lastSeq: number;
  /** 当前断点详情（存在即代表最近一次中断） */
  error?: InterruptionInfo;
}

interface StageState {
  status: StageStatus;
  startedAt?: number;
  finishedAt?: number;
  /** 生图 / 剪影阶段的逐张进度 */
  progress?: { current: number; total: number; done: number; failed: number };
  error?: InterruptionInfo;
}

interface InterruptionInfo {
  code: InterruptionCode;
  stage: PipelineStage;
  /** 人读短句，如「姿势图生成中断」 */
  title: string;
  /** 详细说明：停在哪个阶段、已耗时、最后一次成功的步骤、建议操作 */
  detail: string;
  /** 原始上游错误（HTTP 状态码 / 响应片段 / 模型返回），便于排查 */
  upstream?: string;
  elapsedMs?: number;
  at: number;
  /** 是否可「继续」（重连或重跑失败阶段） */
  retriable: boolean;
  /** 触发该断点的姿势/剪影 index（生图、剪影阶段可能只有个别张失败） */
  failedIndexes?: number[];
}

interface AiPipelineEvent {
  seq: number;
  ts: number;
  stage: PipelineStage;
  type: 'step' | 'note' | 'llm' | 'search' | 'pose' | 'progress';
  title: string;
  status: 'running' | 'done' | 'fail' | 'pending' | 'error';
  // —— 与现有 llm-trace 对齐的字段（透传/复用）——
  parentStep?: string;
  callId?: string;
  model?: string;
  systemPrompt?: string;
  userPrompt?: string;
  response?: string;
  rawResponse?: string;
  attempts?: number;
  error?: string;
  durationMs?: number;
  /** 生图/剪影逐张标识 */
  index?: number;
  resultBrief?: string;
}
```

### 3.1 中断错误码（InterruptionCode）

```ts
type InterruptionCode =
  | 'job_missing'        // 任务不存在（后端重启 / 超过 TTL 被清理）——404
  | 'upstream_timeout'   // 上游模型/生图/搜索超时
  | 'upstream_http'      // 上游返回非 2xx（含状态码，写入 upstream）
  | 'upstream_empty'     // 上游返回内容为空
  | 'poll_timeout'       // 前端等待预算耗尽，但后端任务仍在跑（可继续重连）
  | 'network'            // 前端网络 / 网关（504 等）/ 连接失败
  | 'payload_too_large'  // 状态查询响应体过大（413 / 网关负载上限 / 响应截断），见 §9.3.C
  | 'aborted'            // 用户主动中止（job 仍在后台跑，可继续）
  | 'invalid_input'      // 入参 / 草稿 JSON 不合法
  | 'internal';          // 其他内部异常
```

> 说明：`job_expired` 与 `backend_restart` 合并为 `job_missing`。原因是后端为无状态 404，无法区分「重启丢内存」与「超时被清理」；UI 文案统一覆盖两种可能（「任务已失效：服务重启或超过 60 分钟被清理」）。这是对前期澄清中「job_expired / backend_restart 分列」的一处收敛，请评审时确认。

错误码来源：
- 后端阶段执行抛出异常时，由 `AiPipelineJobService` 归类写入 `StageState.error` / `job.error` 与一条 `fail` 事件；上游错误的 `code/status/原文` 由模型客户端层（`image-client.ts`、`llm-client.ts`）抛出**结构化错误**（见 §4.2）后透传，避免仅靠字符串正则。
- `poll_timeout` / `network` / `aborted` 由前端分类（前端持有 AbortSignal 与等待预算）。
- `job_missing` 由前端据 HTTP 404 判定。

## 4. 后端设计

### 4.1 端点（扩展 `ai-templates.controller.ts`）

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| POST | `/admin/templates/ai-job` | multipart：`image`（示例图，多张）/ `reference`（参考图，多张）/ `text`、`textDesc`、`creationReq`、`poseCount`、`subjectCount` / `mode`（`analyze-only` \| `auto`）/ `options`（JSON：`silhouetteMode`/`silhouetteCrop`/`silhouetteEngine`）。创建 job、保存输入、后台执行，返回 `{ jobId }` |
| GET | `/admin/templates/ai-job/:jobId?since=` | 返回 job 快照：`status`/`stage`/`stages`/`artifacts`/`events`（增量）/`lastSeq`/`error`。job 不存在 → 404（前端归为 `job_missing`） |
| POST | `/admin/templates/ai-job/:jobId/resume` | 断点续跑：阶段仍在 `running` → 不重启，仅回报当前状态（即「重连」）；停在 `error` → 从失败阶段重跑（规则见 §4.3）。返回 `{ resumed: boolean; stage: PipelineStage; code?: InterruptionCode }`；job 不存在 → 404 |
| DELETE | `/admin/templates/ai-job/:jobId` | 「放弃」：释放 job 内存（前端点「放弃」时调用） |

- `analyze-only` 模式：跑完 `analyze` 阶段即置 `status='waiting'`（前端据此进入 Step2）；`auto` 模式：`analyze` → `image` → `silhouette` 全跑完后置 `status='done'`（`submitting` 仍由前端驱动，见 §5.4）。
- 保留 `ai-analyze`、`ai-generate-image`、`ai-generate-image/batch`、`ai-generate-silhouette` 等既有端点不变，供手动 Step3 生图（`step-cover.tsx` 的 `generateAiPoseImages`）、Step4 剪影（`step-silhouette.tsx`）复用。
- 在 `ai.module.ts` 注册 `AiPipelineJobService`。

### 4.2 上游结构化错误

在 `image-client.ts` / `llm-client.ts`（`lumira-server/packages/backend/src/modules/ai/`）中，把现有字符串错误升级为携带元信息的错误对象：

```ts
class AiUpstreamError extends Error {
  code: 'upstream_timeout' | 'upstream_http' | 'upstream_empty' | 'network' | 'internal';
  status?: number;      // HTTP 状态码
  upstream?: string;    // 原始响应片段（截断至合理长度）
}
```

- `AiGenerateImageService` / `AiAnalyzeService` / `AiSilhouetteService` 抛错时保留该类型（或在 task service 层包装时保留 `code/status/upstream`）。
- `AiPipelineJobService` 捕获后据此生成 `InterruptionInfo`（不再靠正则匹配中文文案）。
- 现有 `generateWithRetry` 的可重试判定改为按 `code` 判定（`upstream_timeout` / `upstream_http`(5xx,429) / `upstream_empty` / `network` 可重试）。

### 4.3 阶段执行与续跑规则

**analyze 阶段**：调用 `AiAnalyzeService.analyze(exampleImages, text, {textDesc, creationReq, poseCount, subjectCount})`（复用现有 `runWithTrace` 采集，事件打上 `stage='analyze'`）。产出写入 `artifacts.draft/warnings/trace/research/...`。

- **续跑规则（describe 子步骤）**：若上次中断发生在 `describe`（示例图识别）且仅个别图片失败/超时，重跑时**只重识别失败/缺失的图片**（`failedIndexes`），已成功图片的描述保留合并；其余子步骤（research / poseRefSheet / paramValidate / imageScore / draftRefine）整体重跑（见 §9.3.D）。

**image 阶段**（批量姿势图）：
- 复用现有 `AiGenerateImageService.generate` 与全局生图信号量（≤2）。
- 锚点（`index=0`）先生成；成功后用锚点图作为参考并发跑其余依赖张（对齐现有 `startDependents` 语义）。
- 逐张完成即写入 `artifacts.poseFiles`，并 emit `progress` 事件与 `stages.image.progress`。
- **续跑规则**：
  - `index 0` 失败 → 重跑锚点，成功后重跑全部依赖张（依赖张依赖锚点成片）。
  - `index 0` 成功、部分依赖张失败 → **只重跑失败/缺失的依赖张**，锚点图取 `artifacts.poseFiles` 中 `index=0`，不重新生成锚点。
  - 全部成功 → 阶段 `done`。

**silhouette 阶段**：
- 源 = `artifacts.poseFiles`（全自动流程）；`engine`/`mode`/`crop` 取自 `inputs.options`。
- 逐张完成写入 `artifacts.silFiles`。
- **续跑规则**：只重跑失败/缺失的 index，已成功的保留。

**resume 端点行为**：
1. `job` 不存在 → 404。
2. 当前阶段 `status === 'running'` → `{ resumed: false, stage }`（前端继续轮询即可，等价重连）。
3. 当前阶段 `status === 'error'` → 按上述规则重跑该阶段（清空该阶段 `error`、把该阶段置 `running`、从失败 index 续跑），返回 `{ resumed: true, stage }`。
4. `status === 'done' | 'waiting'` → `{ resumed: false }`。

### 4.4 与现有 3 个 task service 的关系

- `AiAnalyzeTaskService` / `AiImageTaskService` / `AiSilhouetteTaskService` **保留**（既有端点与手动步骤仍在使用）。
- `AiPipelineJobService` 直接注入并调用三个**模型服务**（`AiAnalyzeService` / `AiGenerateImageService` / `AiSilhouetteService`），**不经过** task service，避免任务嵌套；job 自身即持有阶段产物与事件流。
- 事件采集复用 `llm-trace.ts` 的 `runWithTrace(sink, fn)`，在 sink 中补 `stage` 字段后写入 `job.events`。

## 5. 前端设计（admin）

### 5.1 类型与 API 层

- `src/types/admin.ts`：新增 `AiPipelineJobId`、`AiPipelineStatusResult`、`AiPipelineStage`、`AiPipelineEvent`、`InterruptionInfo`、`InterruptionCode`、`AiPipelineResumeResult`。
- `src/lib/api.ts`：
  - 新增 `aiPipelineStart(formData)` / `aiPipelineStatus(jobId, since?)` / `aiPipelineResume(jobId)` / `aiPipelineCancel(jobId)`。
  - `adminFetch`（[api.ts](file:///e:/Project/photo_post/lumira-server/packages/admin/src/lib/api.ts) 第 63 行起）改为抛出携带 `status` 的错误（新增 `ApiHttpError extends Error { status: number }`），以便前端区分 404（`job_missing`）与其他错误。
- `src/actions/ai.ts`：新增对应 server actions，错误返回体带上 `status`（如 `{ error: string; status?: number }`），避免 404 信息丢失。

### 5.2 轮询与 jobId 持久化

新增/重构 `src/lib/ai-task.ts` 中的轮询工具为 `startPipelineJob` + `pollPipelineJob`：

- `startPipelineJob(inputs, mode)`：组装 FormData → `aiPipelineStart` → 返回 `jobId`，并写入 `localStorage`（键如 `lumira.aiCreateJob`，值 `{ jobId, mode, createdAt }`）。
- `pollPipelineJob(jobId, { onEvents, onProgress, onArtifacts, signal })`：按 `since` 增量拉取事件；`done`/`waiting` 结束；`error` 时抛携带 `InterruptionInfo` 的 `AiTaskPollError`；超过**前端等待预算**（统一对齐后端 job TTL，即 60 分钟，替代现有 analyze/batch/silhouette 各自的 60/60/10 分钟）且 job 仍在跑 → 抛 `poll_timeout`（**不停止后端 job**，用户可「继续」重连）。
- `resumePipelineJob(jobId)`：调用 resume 端点。
- 401/网络失败按 `network` 归类；HTTP 404 按 `job_missing` 归类。
- 现有 `generateAiPoseImages` / `generateAiSilhouettes` / `pollAiAnalyzeTask` **保留**（`step-cover.tsx`、`step-silhouette.tsx` 手动步骤仍用）。

### 5.3 wizard 改造（`wizard.tsx`）

- `handleAnalyze`（手动）与 `runAutoAll`（全自动）改为：`startPipelineJob` → `pollPipelineJob`，不再各自拼 FormData / 分别轮询。
  - 手动：`mode='analyze-only'`，`waiting` 后进入 Step2；
  - 全自动：`mode='auto'`，`done` 后进入 Step5（`submitting`）。
- **刷新恢复**：mount 时读 localStorage 的 `jobId` → `aiPipelineStatus(jobId)`：
  - `running`/`waiting`/`done`/`error` → 从 `artifacts` 水合草稿、候选封面（pose files）、剪影，恢复到对应 `step`，并展示进度 / 「继续」；
  - 404 → 清本地 `jobId`，显示 `job_missing` 提示与「重新开始」。
- **断点状态**：新增状态 `pipelineBreak: InterruptionInfo | null`（替代现有 `errorText` / `autoState.error` 的字符串形式，二者保留为派生展示）。
- **「继续」按钮**：断点 banner 中，`pipelineBreak.retriable` 为真时展示：
  - 若后端 job 仍在跑（`resume` 返回 `resumed:false`）→ 仅恢复轮询（重连）；
  - 否则调 `resume`（重跑失败阶段）→ 再次 `pollPipelineJob`。
- **「中止」语义调整**：现有「中止」按钮当前 `abortRef.abort()` 停止等待；改为**仅停止前端等待**（job 继续在后台跑），banner 变为可「继续」的 `aborted` 断点；新增「放弃」按钮调用 `aiPipelineCancel` 释放 job。
- **失败阶段跳转**：`analyze` 失败 → Step1；`image`/`silhouette` 失败 → 对应 Step3/Step4，与现有「失败停在对应步骤」行为一致。

### 5.4 submitting 阶段

`submitting` 由 `TemplateForm` 的 `autoSubmit` 驱动（前端），不属于后端 job 阶段。失败时：
- 用 `artifacts` 重新注入表单资产（`poseFiles` → 效果图、`silFiles` → 剪影），刷新后也可从 job artifacts 恢复；
- 中断原因沿用同一套 `InterruptionInfo`（`code` 多为 `network`/`invalid_input`/`internal`），保持展示一致。

### 5.5 中断详情展示

- `GenerateProgressPanel`（[generate-progress-panel.tsx](file:///e:/Project/photo_post/lumira-server/packages/admin/src/components/ai-create/generate-progress-panel.tsx)）：状态条「已中断」，时间线中对应阶段 / 调用节点标红。
- `analyze-trace-stream.tsx` / `trace-call-card.tsx`：接受统一事件（含 `stage` 与 `fail` 状态），失败节点标红并显示 `error`。
- 新增/复用「查看详情」：展示 `InterruptionInfo` 的阶段、错误码、`detail`、`upstream`、`elapsedMs`、（若有）`failedIndexes` 与建议操作。

## 6. 边界与限制

1. **后端重启 / 超时清理后 job 整体消失**：因仅内存持久化，输入与产物同时丢失，**无法原地续跑**。此时按 `job_missing` 明确提示；会话内（前端仍持有输入）可「重新开始」重建 job，刷新后则引导重新上传（回到 Step1）。
2. **多标签页 / 多次提交**：同一浏览器仅保留最近一个 `jobId`（localStorage 单键）；不做多 job 并存。
3. **不改数据库**；沿用内存 TTL（60 min）与 sweeper。
4. **不改 Flutter 端与 `lumira-app`**。
5. 现有三个异步任务端点与 task service 保留，避免影响手动步骤与既有单测。

## 7. 验收标准

1. 全自动流程在 `analyzing`/`generating-image`/`generating-silhouette` 任一阶段因上游超时、HTTP 错误、空响应、网络/网关错误而中断时，界面出现「继续」按钮；点击后：
   - 若后端 job 仍在跑（例如前端等待预算耗尽）→ 重连并继续等待，不重新生成；
   - 若该阶段已 `error` → 只重跑失败阶段；生图/剪影**只补失败或缺失的张**，已成功的张不重生成。
2. 生成中途刷新页面：仍能按 localStorage 的 `jobId` 恢复进度并「继续」。
3. 中止后界面提示「已中止（可在后台继续）」，可点「继续」重连；「放弃」后 job 释放。
4. 任一断点均展示分类错误码 + 阶段 + 摘要 + 可展开的原始上游错误 + 已耗时 + 建议；过程面板时间线对应节点标红。
5. 后端重启导致 job 不存在时，提示 `job_missing`（服务重启或超时清理），并提供「重新开始」。
6. 手动「开始识别」与全自动两条入口的中断 / 续跑 / 错误码表现一致。
7. 现有后端单测全部通过；新增 `AiPipelineJobService`、`resume` 端点、错误分类的前端工具函数单测。

## 8. 影响的文件清单

**后端**
- 新增：`lumira-server/packages/backend/src/modules/ai/ai-pipeline-job.service.ts`（+ spec）
- 修改：`ai-templates.controller.ts`（新增 4 个端点 + §9.3.C 状态响应体收敛：增量/`verbose`/终态分档）、`ai.module.ts`（注册）、`image-client.ts`/`llm-client.ts`（结构化上游错误）、`ai-generate-image.service.ts`（保留错误元信息）、`image-describe.service.ts`（单张超时可配 + 抛结构化错误带下标 + 支持按下标重识别，§9.3.D）、`llm-trace.ts`（轮询态更紧截断档位，§9.3.C）

**后台**
- 修改：`src/types/admin.ts`、`src/lib/api.ts`（新增 API + `ApiHttpError.status` + `payload_too_large` 判定）、`src/actions/ai.ts`、`src/lib/ai-task.ts`（新增 pipeline 轮询/续跑 + §9.3.B 指数退避重试）、`src/components/ai-create/wizard.tsx`、`generate-progress-panel.tsx`、`analyze-trace-stream.tsx`、`trace-call-card.tsx`

**文档**
- 本设计文档；实现后按需更新 `docs/future-optimizations.md`（如「job 落库以支持重启续跑」作为后续优化登记）

## 9. 「查询识别任务失败」专项修复

本节是追加需求：「为什么添加参考图之后识别流程会出现『查询识别任务失败』？」——与 §1 的断点续跑同属「中断原因不可诊断 + 轮询不健壮」的同一根因族，故合并处理。

### 9.1 症状与证据

- 报错文案：**「查询识别任务失败」**（用户确认原文即此句）。
- 触发条件：**上传参考图后**（纯文本识别不触发）。
- 时机：**流程走到后面几步之后**才报错。
- 关键证据：过程面板显示「**示例图识别：失败 300.7s**」。

### 9.2 根因

三层缺陷叠加，缺一不会出现该症状：

1. **单张视觉识别调用挂到 ~300s 超时（直接诱因）**
   - 「示例图识别」= 编排器 `describe` 阶段（[ai-orchestrator.service.ts](file:///e:/Project/photo_post/lumira-server/packages/backend/src/modules/ai/ai-orchestrator.service.ts) `STEP_TITLES.describe`），走 [image-describe.service.ts](file:///e:/Project/photo_post/lumira-server/packages/backend/src/modules/ai/image-describe.service.ts) 的**穷尽式九宫格视觉识别**。
   - `describeMany` 对多张参考图**串行逐张**调用 `visionChatJson`（[image-describe.service.ts](file:///e:/Project/photo_post/lumira-server/packages/backend/src/modules/ai/image-describe.service.ts#L222-L228)）；单张调用超时阈值 300s，用户实测 300.7s 即命中该阈值。多图时总耗时线性累加，极易撞上前端等待预算 / 网关超时。

2. **轮询响应体不收敛（放大因素）**
   - 状态端点每轮整包回传 `trace` / `rawResponse` / `research` / `researchImages` / `researchVision`；`llm-trace.ts` 单字段上限 `TRACE_TEXT_CAP = 50_000`、事件上限 `MAX_TRACE_EVENTS = 300`（[llm-trace.ts](file:///e:/Project/photo_post/lumira-server/packages/backend/src/modules/ai/llm-trace.ts)）。
   - 识别越久、LLM 调用越多，事件流越大；而**每一轮轮询都重复回传全量事件**，响应体随耗时单调膨胀，最终可能超出后台 Server Action / Vercel 响应体上限，使状态查询拿不到结果。

3. **轮询无容错 + 兜底文案掩盖真因（致盲因素）**
   - [ai-task.ts](file:///e:/Project/photo_post/lumira-server/packages/admin/src/lib/ai-task.ts#L424-L438) 轮询循环里，`aiAnalyzeStatusAction` 返回 `!res || 'error' in res` 即**一次即失败**，抛出固定文案「查询识别任务失败」/「识别失败，请重试」；`pollAiImageTask` / `pollAiSilhouetteTask` 有同样兜底（「查询生图任务失败」/「查询剪影任务失败」）。
   - 该文案把「上游超时 / 网关网络错误 / 响应体过大 / 任务被清理」全部压成同一句，导致**用户与开发者都无法从报错判断真实原因**。

> 结论：诱因是 `describe` 多图串行 + 单次 LLM 300s 超时；放大因素是轮询响应体不收敛；致盲因素是「一次失败即中断 + 兜底文案」。三者由本次 job 设计统一收口（§3、§4、§5）。

### 9.3 修复

**A. 中断原因必须透传真因（对齐 §3 `InterruptionInfo` + §3.1 错误码）**
- 在 §3.1 错误码基础上，**新增 `payload_too_large`**：当状态查询因响应体过大失败（Server Action / 网关返回 413 / `FUNCTION_PAYLOAD_TOO_LARGE` / 响应截断）时归入该类，`upstream` 记录原始报错。
- 兜底文案规则：`code` 与 `detail` **必须携带真实来源**——错误码、阶段、已耗时、（上游场景）HTTP 状态码与响应片段。禁止再用单一固定文案覆盖真实原因。
- `describe` 阶段的失败若源于单张图超时，`InterruptionInfo.failedIndexes` 记录超时图片下标，`upstream` 记录模型返回/超时信息，`detail` 提示「可点继续仅重识别失败图片」。

**B. 轮询容错（前端，替代「一次失败即中断」）**
- `pollPipelineJob`（§5.2）对状态查询失败**先指数退避重试**（如 1s/2s/4s/8s，上限 N=4 次）再判定为 `network` 断点；重试期间保持 job 状态（不丢 `since` 游标）。
- HTTP 404 → `job_missing`（不重试）；413 / 响应过大 → `payload_too_large`（不重试，直接提示，并触发 §9.3.C 的收敛）。
- 前端等待预算不变（60 min，对齐 job TTL）；预算耗尽而 job 仍在跑 → `poll_timeout`，可「继续」重连。

**C. 后端状态响应体收敛（根源性修复）**
- 状态端点（`GET /admin/templates/ai-job/:jobId`）改为**只回传增量事件 + 轻量快照**：
  - 事件按 `since` 增量返回（已有），并**不再每轮回传全量 `trace` / `rawResponse`**；
  - `rawResponse`（原始模型响应）与完整 `systemPrompt/userPrompt` **仅在显式请求 `verbose=1` 或终态（`done`/`error`）时**返回；常规轮询只带 `resultBrief` / `status` / 摘要字段；
  - 对单个事件的可选重字段做**更紧的截断**（如轮询态截断至 2,000 字符，verbose/终态才放宽到 `TRACE_TEXT_CAP`）。
- 目标：轮询响应体与「已完成事件数」解耦，避免长任务把响应体撑爆，从源头消除 `payload_too_large`。

**D. `describe` 阶段健壮性（降低诱因发生概率）**
- `describeMany` 的**逐张失败不致命**语义保留（现有 `wrapStep` 兜底），但：
  - 单张图识别超时阈值**可配**，并在超时时抛出**结构化错误**（`AiUpstreamError.code='upstream_timeout'`、带图片下标），供 job 记录 `failedIndexes`；
  - 续跑时（§4.3 `resume`）**只重识别失败/缺失的图片**，已成功图片的描述保留合并，避免整段重跑。
- 说明：多图**并行**识别属于性能优化，涉及全局并发与配额控制，本次**不做**，登记到 `docs/future-optimizations.md`（避免与生图信号量争抢）。

### 9.4 验收标准（追加）

8. 带参考图触发识别、某张图识别超时失败时，界面展示的错误码为 `upstream_timeout`（或对应上游码），`detail` 含「示例图识别 / 已耗时 / 建议」，`upstream` 含原始超时信息；不再出现无信息的「查询识别任务失败」。
9. 轮询期间状态查询偶发失败（网络抖动 / 网关 5xx）：前端退避重试后自动恢复，任务继续，不误报断点。
10. 长任务（事件数接近上限）在轮询过程中**不因响应体过大而失败**；`done` 终态仍可取到完整 trace 与 `rawResponse`（verbose/终态路径）。
11. 点击「继续」重跑 `describe` 时，只重识别失败图片；已成功图片描述复用。