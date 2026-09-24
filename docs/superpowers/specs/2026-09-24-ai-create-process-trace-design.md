# AI 一键生成：识别 & 姿势图实时过程溯源优化设计

日期：2026-09-24
模块：后台 `lumira-server/packages/admin` + 后端 `lumira-server/packages/backend`
状态：已确认

## 背景与痛点

后台「AI 一键生成模板」页在识别 / 生成姿势图时，现有的实时过程展示存在如下问题：

1. **识别实时过程 UI 太乱**：`AnalyzeTraceStream` 把后端事件流当作扁平列表逐条渲染。后端每个阶段会发**两条**事件（先 `running` 再 `done`），前端各渲染一行 → 每个阶段出现两行，第一行永远挂着"执行中…"（其 status 永不更新），既冗乱又造成"明明到下一步了、上一步还执行中"的错觉。
2. **识别详情只在第一步/第二步可见**：实时过程只渲染在 Step1；「查看识别详情/过程」按钮只在 Step2。切换到 Step3~5 后无法再看到识别过程。
3. **姿势图无可溯源的实时过程**：后端批量生图只暴露每张的 `status` 快照（排队/生成中/完成/失败），没有每张的 prompt、模型、时间戳、事件序列；前端只显示"第 X/Y 张"计数。

## 目标

- 让识别实时过程**清晰、按阶段归纳、状态正确流转**（不再每个阶段两行、不再残留"执行中"）。
- 识别过程**常驻于顶部步骤栏上方**，跨 Step1~5 可见；识别结束后自动收拢成窄条，可点击再展开回看。
- 姿势图生成提供**可溯源到每张图**的实时过程（排队→生成中→完成/失败 + 耗时 + prompt + 模型 + 失败原因）。

## 决策（已与用户确认）

- 常驻面板内「风格识别」与「姿势图生成」**用 Tab 切换**（同一时间只活跃一个，更清爽）。
- 常驻面板**运行中自动展开，结束后自动收拢成窄条**，点击可再展开。

## 方案

### A. 后端增强 —— 姿势图批量任务「事件化」

文件：

- `backend/src/modules/ai/ai-image-task.service.ts`
- `backend/src/modules/ai/ai-generate-image.service.ts`
- `backend/src/modules/ai/ai-templates.controller.ts`

改动：

1. `ImageTask` 增加字段：`startedAt: number`、`finishedAt: number`、`prompt?: string`、`model?: string`。
   - `composeImagePrompt`（`ai-generate-image.service.ts`）产出 prompt 后写回 `task.prompt`；记录所用 model。
   - `run()` 进入时记 `startedAt`，结束（done/error）记 `finishedAt`。
2. 批内维护**事件日志** `events: AiBatchImageTraceEvent[]`（仿 analyze 的 `seq` 增量机制）与 `lastSeq`。每张图按 `排队(pending) → 生成中(running) → 完成/失败(done/error)` 发事件，事件带：`{ seq, ts, type:'image'|'note', index, title, status, prompt?, model?, error?, durationMs? }`。
3. `AiBatchProgress` 增加 `events` / `lastSeq`；`AiBatchResultItem` 增加 `startedAt` / `finishedAt` / `prompt` / `model`。
4. 批量状态接口支持 `GET .../templates/ai-generate-image/batch/:batchId?since=`，按 `since` 增量返回新事件（`lastSeq` 用于游标）；前端照 `seq` 去重累积。
5. 沿用 `MAX_TRACE_EVENTS`（或同类上限）防止事件无限增长。

### B. 前端 —— 常驻「生成过程」面板（步骤栏上方）

文件：`admin/src/components/ai-create/wizard.tsx` + 新组件 `admin/src/components/ai-create/generate-progress-panel.tsx`

行为：

- 识别启动或全自动进行时（`analyzing` 或 `autoState.running` 或已有 `traceEvents`/`poseTraceEvents`），在**顶部 stepper 上方**渲染「生成过程」持久面板。
- 面板跨 Step1~5 常驻；识别/生成完成后保留。
- 面板内 **Tab 切换**：
  - `风格识别` → 渲染优化后的 `AnalyzeTraceStream`（见 C）。
  - `姿势图生成` → 渲染新的 `PoseTraceStream`（见 D）；仅在生图阶段开始后有内容。
- **运行中自动展开；结束后自动收拢成窄条**（只留标题栏 + 状态点 + 各 Tab 计数），点击标题可再展开回看。
- 右上角可手动关闭本面板（仅隐藏本次，识别详情弹窗仍保留兜底）；再次有新的识别/生图任务时重新出现。
- 把「查看识别详情 / 过程」（弹窗入口）从仅 Step2 移到面板内，保证任意步骤可达。

### C. 识别实时过程展示重构（纯前端）

文件：`admin/src/components/ai-create/analyze-trace-stream.tsx`

- 由扁平 `AiTraceEvent[]` **重建为「阶段时间线」**：
  - 每个阶段**只渲染一行**，状态**原位流转** `running → done/fail`（用同一节点的状态字段覆盖，从根上消除"每阶段两行 + 执行中残留"）。
  - 阶段行含：状态圆点（执行中 spinner / 完成对勾 / 失败红）、阶段名、步骤序号、结果摘要、耗时、时间。
  - `note` 事件渲染为独立说明行。
- 属于该阶段的 LLM/检索调用卡片**折叠收纳到阶段下**（默认收拢），点开查看提示词 / 响应 / 检索命中，减少杂乱。
- 运行中自动滚动到底（用户上滑回看历史时不打断）；结束后正常展示全部。
- 兼容 `title={null}` 场景（在弹窗/ Tab 内复用，去掉头部）。

### D. 姿势图实时过程 trace

文件：`admin/src/lib/ai-task.ts` + 新组件 `admin/src/components/ai-create/pose-trace-stream.tsx`

- `generateAiPoseImages` 轮询时额外通过 `since` 消费 batch 的 `events` 增量，累积并把每张姿势图的实时事件回调给 `onEvents`。
- `PoseTraceStream` 逐张渲染卡片：**排队 → 生成中 → 完成/失败**，展示每张的序号、耗时、模型（折叠展示 prompt）、失败原因。
- 结束后可整体回看本次每一张从排队到完成的全过程。

## 数据流

```
识别: aiAnalyzeStartAction → pollAiAnalyzeTask(onEvents) → traceEvents → GenerateProgressPanel[风格识别] → AnalyzeTraceStream(阶段时间线)
生图: aiGenerateImageBatchStartAction → pollAiGenerateImageBatch(since,onEvents) → poseTraceEvents → GenerateProgressPanel[姿势图生成] → PoseTraceStream(逐张过程)
```

## 错误处理与文化约束

- 姿势图事件若后端未及时返回 / `since` 游标异常：不阻断主流程，前端对已轮询到的 `results[]` 快照仍可降级渲染（至少显示每张的排队/生成中/完成/失败）。
- 识别事件沿用现有"拉到即累计、按 seq 去重"逻辑，不改变。

## 验收标准

- 识别期间：步骤栏上方出现「生成过程」面板，自动展开，「风格识别」Tab 实时显示阶段时间线；每个阶段一行、状态从执行中流转到完成/失败，**无每阶段两行、无残留"执行中"**。
- 识别结束后：面板自动收拢成窄条，跨 Step1~5 常驻可见，点击标题可展开回看每阶段及提示词/响应。
- 全自动流程进入生图阶段时，「姿势图生成」Tab 实时逐张显示每张姿势图的排队→生成中→完成/失败、耗时、prompt、模型、失败原因；结束后可整体回看。
- 任意步骤（Step1~5）都能通过面板（及其内的详情弹窗入口）看到识别与生图过程。
- `npm run build` / typecheck 通过；后端 `pnpm --filter @lumira/backend start:dev` 与相关测试通过。