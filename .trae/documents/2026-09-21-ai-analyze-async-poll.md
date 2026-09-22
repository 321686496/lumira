# AI「开始识别」改造成异步任务 + 前端轮询

## Context（背景）

module `AI 一键生成模板` 向导里的「开始识别/识别中」环节，走的是 **同步长请求**：admin 的 server action `aiAnalyzeAction` 直接 `POST /admin/templates/ai-analyze`，后端在该次 HTTP 请求内跑完 LLM 调用（`AiAnalyzeService.analyze` → `visionChat/textChat` + 可选 `AiOrchestratorService.run`），动辄几十秒。由于 admin 部署在 Vercel 且后端正前方有 nginx `proxy_read_timeout`，一旦超过网关/Serverless 时长，请求就被无声掐断 → 前端一直停在「识别中」，且没有可恢复的中间态。

**目标**：把 analyze 改造成与已有「生图 / 剪影」完全一致的 **异步任务 + 前端轮询** 模式——后端提交任务立即返回 `taskId`，前端用短请求轮询状态直到拿到 `draft`。从而规避网关系列超时，长耗时任务与前端解耦。

**复用现有模式（不要新造轮子）**：

- 后端任务范式参照 `AiImageTaskService`（`lumira-server/packages/backend/src/modules/ai/ai-image-task.service.ts`）：内存 `Map` 存任务 + 状态机 `pending→running→done/error` + 结果/错误字段 + sweeper 清理；controller 侧 `POST xxx`(返回 taskId) + `GET xxx/tasks/:taskId`(返回状态)。
- admin 轮询范式参照 `lumira-server/packages/admin/src/lib/ai-task.ts` 的 `pollAiSilhouetteTask`/`pollAiImageTask`（浏览器端循环调用 status server action，间隔 2s、超时 600s）。
- Server action 薄封装参照 `lumira-server/packages/admin/src/actions/ai.ts`。

---

## Backend 改动

### 1. 新增 `AiAnalyzeTaskService`
新建 `lumira-server/packages/backend/src/modules/ai/ai-analyze-task.service.ts`，`@Injectable()`。

- 注入 `AiAnalyzeService`。
- 内存任务表 `private tasks = new Map<string, AnalyzeTask>()`；`AnalyzeTask { id, status: 'pending'|'running'|'done'|'error', draft?, warnings?, trace?, error? }`（仿 `AiImageTaskService`）。
- `submit(image, text, opts): Promise<{ taskId }>`：
  - 入参校验（至少 image 或 text 之一，否则 `BadRequestException`），fail-fast 在创建任务前完成（对齐现状 analyze 的入参校验）。
  - 生成 `taskId`，写入 `pending`，随即后台（`void this.run(id, image, text, opts).catch(...)`）执行。
- `run(id, ...)`: 置 `running` → `this.analyzeService.analyze(image, text, opts)` → 置 `done` 并存 `draft/warnings/trace`；异常则置 `error` 并写 `error.message`。
- `get(id): AnalyzeTask | undefined`。
- sweeper：参照 `AiImageTaskService` 的 `setInterval` + `unref`，定期清理已完成任务（保留窗口约在现有服务一致即可）。
- 在 `AiModule` providers 增加 `AiAnalyzeTaskService`（`ai.module.ts`）。

### 2. `ai-templates.controller.ts` 改造
- 构造器注入 `AiAnalyzeTaskService`。
- `POST ai-analyze`（原 `analyze`）：保留 `parseAiMultipart`，改为
  `return this.aiAnalyzeTaskService.submit(image, text ?? textDesc ?? undefined, { textDesc, creationReq, poseCount });`
  → 返回 `{ taskId }`（同步、毫秒级返回）。
- 新增 `GET ai-analyze/tasks/:taskId`（仿生图任务的 `getImageTask`）：
  ```ts
  const task = this.aiAnalyzeTaskService.get(taskId);
  if (!task) throw new NotFoundException('Analyze task not found');
  return { taskId: task.id, status: task.status, draft: task.draft ?? null, warnings: task.warnings ?? [], trace: task.trace ?? null, error: task.error };
  ```

## Admin 改动

### 3. `src/lib/api.ts`
新增（仿 `aiGenerateImageStart`/`aiGenerateImageStatus`）：
- `aiAnalyzeStart(formData)` → POST `/templates/ai-analyze` → `{ taskId }`。
- `aiAnalyzeStatus(taskId)` → GET `/templates/ai-analyze/tasks/${taskId}` → `{ taskId, status, draft?, warnings?, trace?, error? }`。
- 移除/停用旧的同步 `aiAnalyze`（改为不再被引用）。

### 4. `src/types/admin.ts`
新增类型：`AiAnalyzeTaskId { taskId: string }`、`AiAnalyzeStatusResult { taskId: string; status: 'pending'|'running'|'done'|'error'; draft?: Record<string, unknown>; warnings?: string[]; trace?: ...; error?: string }`（trace 复用现有 analyze trace 结构）。

### 5. `src/actions/ai.ts`
- 新增 `aiAnalyzeStartAction(fd)` → `AiAnalyzeTaskId | { error }`。
- 新增 `aiAnalyzeStatusAction(taskId)` → `AiAnalyzeStatusResult | { error }`。
- 删除 `aiAnalyzeAction`（不再被引用）。

### 6. `src/lib/ai-task.ts`
新增 `pollAiAnalyzeTask(taskId, options?, onTick?)`，结构完全仿 `pollAiSilhouetteTask`：
- 循环 `aiAnalyzeStatusAction(taskId)`；
- `status==='done'` → resolve `{ draft, warnings, trace }`；
- `status==='error'` 或查询失败 → reject `AiTaskPollError(error)`；
- 超时（默认 600s）→ reject `AiTaskPollError('识别超时…')`。

### 7. `src/components/ai-create/wizard.tsx`
两处调用点（`handleAnalyze` ~L208、`runAutoAll` ~L253）由 `await aiAnalyzeAction(analyzeFd)` 改为：
```ts
const started = await aiAnalyzeStartAction(analyzeFd);
if (!started || 'error' in started) { setErrorText(started?.error || '识别提交失败，请重试'); return; }
const resultRes = await pollAiAnalyzeTask(started.taskId);   // 抛出 AiTaskPollError 会走既有 catch
```
沿用 `resultRes.draft / .warnings / .trace`，其余回填/跳步逻辑不变。已有 `try/catch/finally`（含 `setAnalyzing(false)`）天然覆盖轮询的抛错，确保不卡「识别中」。

---

## 关键决策

| 决策点 | 选择 | 理由 |
|---|---|---|
| 轮询跑在哪 | **浏览器端**（`pollAiAnalyzeTask` 循环调 status server action） | 每次调用是毫秒级短请求；避免在 server action 里长循环再次触碰 Vercel server-action 时长限制 |
| 任务存储 | 后端内存 `Map` + sweeper，同 `AiImageTaskService` | 与已上线的生图/剪影一致，同一进程内可被 admin 轮询到 |
| 端到端兼容 | 删旧同步 `aiAnalyze`/`aiAnalyzeAction` | 唯一调用方是本向导/server action，同仓同步改，无第三方 |
| 结果体量 | status 返回完整 draft+warnings+trace | 与生图 status 返回 base64 大图一致，量级可接受 |

## 验证

1. 后端：`cd lumira-server/packages/backend && pnpm run build`（exit 0）；跑 `npx jest` 看 analyze/controller 相关既有测试无回退（本改动未改 analyze 核心逻辑）。
2. admin：`cd lumira-server/packages/admin && pnpm run build`（typecheck+lint）。
3. 手动（本地起后端 + admin）：
   - 点「开始识别」→ 立即从「识别中」进入（后端入口日志出现）→ 完成后草稿回填 Step2，全程按钮不复位卡死。
   - 人为断开后端网络再识别 → 轮询超时/报错，toast 提示「识别失败」，回到可重试状态（不永久 loading）。
   - 全自动「一键生成」：识别阶段同样轮询，成功后自动进入生图→剪影。
4. 按 AGENTS.md：改动完成即 commit + push gitee(origin) + github 双远程，触发后端部署 CI。