# AI 封面生图改「异步任务 + 轮询」，修复第3步卡死"生成中"

## Context（背景与目标）

后台 AI 一键建模向导第3步「生成封面效果图」在**线上 Vercel** 上点击「生成效果图」后**永远卡在「生成中…」**，且感觉"API 没被调用"。

根因（已定位并确认环境）：
- 当前是**完全同步**链路：`StepCover.generate()` → `aiGenerateImageAction`（Vercel 上的 Next server action）→ 后端 `POST admin/templates/ai-generate-image` → 后端 [ai-generate-image.service.ts](file:///d:/app/projects/photo_post/lumira-server/packages/backend/src/modules/ai/ai-generate-image.service.ts#L34-L60) 先调文本模态 `polishPrompt`、再调图片模态 `generateImage`（[image-client.ts](file:///d:/app/projects/photo_post/lumira-server/packages/backend/src/modules/ai/image-client.ts#L189-L236) qwen 轮询上限 60s、同步厂商单请求 120s）。
- 整条生图耗时约 60~120 秒，远超 Vercel serverless 函数执行时长上限（Hobby 默认约 10s）。Vercel 掐断 server action 后，浏览器侧 `await aiGenerateImageAction(fd)` 永不结算 → `generating` 一直 true → 卡死。Nest 默认不打印每个请求日志，所以后端日志看似"没请求"。
- 对比可反证：第2步「开始识别」快（秒级）所以正常；唯独分钟级的生图超时。

目标：把封面生图改为**提交任务 → 立即返回 taskId → 前端轮询状态**，每次 Vercel 调用都很短，任何套餐都能真正生成并回填封面，不再卡死。仅改造封面生图（第2步识别很快、第4步剪影是本地计算很快，均不改）。

## 后端改造（`lumira-server/packages/backend/src/modules/ai/`）

### 1. 新增任务服务 `ai-image-task.service.ts`

用**内存 Map** 存任务（后端是单容器，图片 base64 结果是瞬态数据；重启丢失可接受——前端对"任务不存在"给出可重试提示）。不依赖 Redis/REDIS_URL（[redis.service.ts](file:///d:/app/projects/photo_post/lumira-server/packages/backend/src/common/redis/redis.service.ts#L12-L30) 可用但可能未配置，此处不做额外依赖）。

数据结构与行为：
```ts
type ImageTaskStatus = 'pending' | 'running' | 'done' | 'error';
interface ImageTask {
  id: string;                 // nanoid()
  status: ImageTaskStatus;
  createdAt: number;
  result?: { image: string; mimeType: string };  // 仅 done
  error?: string;             // 仅 error
}
```
方法：
- `async submit(reference, metaJson): Promise<{ taskId }>` — 先 `await aiConfigService.getActiveConfig()` 做**快速失败**（未配置仍 503 直接返回，避免用户空等）；创建 pending 任务并存入 Map；`void this.run(taskId, reference, metaJson)`（不 await）后立即返回 `{ taskId }`。
- `async run(taskId, reference, metaJson)` — 置 running；`try { const r = await aiGenerateImageService.generate(reference, metaJson); result = { image: r.base64, mimeType: r.mimeType }; status='done' } catch(e){ status='error'; error=e.message }`（复用现成的 [AiGenerateImageService.generate()](file:///d:/app/projects/photo_post/lumira-server/packages/backend/src/modules/ai/ai-generate-image.service.ts#L34-L60)，内部已有各类超时，不会无限挂起）。
- `get(taskId): ImageTask | null` — 供查询；`done` 时带 result。
- 惰性清理：`setInterval` 每 ~60s 删除 `createdAt` 超过 15 分钟的已完成/错误任务，防内存泄漏。`run()` 内部已有后端超时兜底，不会真卡。

依赖注入：`AiConfigService`、`AiGenerateImageService`。

### 2. 控制器 `ai-templates.controller.ts`

- **变更** `@Post('ai-generate-image')`：`parseAiMultipart` 后调用 `taskService.submit(reference, meta)` → 返回 `{ taskId }`（原来是 `{ image, mimeType }`，契约改变）。
- **新增** `@Get('ai-generate-image/tasks/:taskId')`：`task = taskService.get(taskId)`；不存在 → 抛 `NotFoundException`（adminFetch 会转 404 错误）；存在 → 返回
  `{ taskId, status, image?, mimeType?, error? }`（仅 done 带 image/mimeType，仅 error 带 error）。

### 3. 模块 `ai.module.ts`
注册 `AiImageTaskService` 到 providers/controllers 依赖（`AiTemplatesController` 新增注入）。启动清理 `setInterval` 在服务 `OnModuleInit`/构造函数里初始化。

### 4. 后端测试（TDD）
新增 `ai-image-task.service.spec.ts`（jest）：mock `AiGenerateImageService` + `AiConfigService`：
- submit 快速失败：配置未启用 → 抛 503 且不生成。
- submit 返回 taskId，初始 pending；`get` 到 running/pending。
- 完成后 status='done' 且带 result；失败 status='error' 带 error。
- `get` 不存在的 id → null。
现有 `ai-generate-image.service.spec.ts` 保持不变（execute 核心未动）。

## 后台改造（`lumira-server/packages/admin/src/`）

### 5. 类型 `types/admin.ts`
- 新增 `AiImageTaskId = { taskId: string }`。
- 新增 `AiImageStatusResult = { taskId: string; status: 'pending'|'running'|'done'|'error'; image?: string; mimeType?: string; error?: string }`。
- 保留 `AiImageResult`（剪影仍是同步大结果）。

### 6. API 客户端 `lib/api.ts`
- `aiGenerateImageStart(formData)` → `adminFetch<AiImageTaskId>('/templates/ai-generate-image', { POST, body: formData })`。
- `aiGenerateImageStatus(taskId)` → `adminFetch<AiImageStatusResult>('/templates/ai-generate-image/tasks/' + taskId)`。
- 移除旧同步 `aiGenerateImage`（或改为 `aiGenerateImageStart`，避免残留误用）。

### 7. Server actions `actions/ai.ts`
- `aiGenerateImageStartAction(formData)` / `aiGenerateImagePollAction(taskId)`：同现有风格薄封装，`catch` 回 `{ error }`，`UnauthenticatedError` → `redirect('/login')`。

### 8. 抽轮询工具 `lib/ai-task.ts`（step-cover 与 wizard 复用）
纯函数 + Promise，手搓轮询（后台无 SWR/react-query，见 [package.json](file:///d:/app/projects/photo_post/lumira-server/packages/admin/package.json)）：
```ts
pollAiImage(taskId, { intervalMs=2000, timeoutMs=180000, tick }): Promise<AiImageStatusResult>
```
- `setInterval` 调用 `aiGenerateImagePollAction`；
- `done` 立即 resolve；`error` reject(Error)；`not 存在`(404) reject；超过 `timeoutMs` reject('生成超时，请重试')；
- 返回的 Promise 带清理，确保调用方 `finally` 复位 `generating`。

### 9. `step-cover.tsx` → `generate()`
`setGenerating(true)` → `aiGenerateImageStartAction(fd)`，失败即 toast+复位；成功拿 taskId → `pollAiImage`；成功 → `base64ToFile` 加入 `candidates` 并 toast；任何失败 → toast + `finally setGenerating(false)`。按钮文案保持 `生成中…`/`生成效果图`。

### 10. `wizard.tsx` → `runAutoAll` ② 段
把 `await aiGenerateImageAction(genFd)` 换成 start+poll；失败行为保持现有「停在 Step3、示例图保底、草稿保留」（[wizard.tsx](file:///d:/app/projects/photo_post/lumira-server/packages/admin/src/components/ai-create/wizard.tsx#L216-L228)）。成功后再给剪影/提交注入 `aiCover`，逻辑不变。

### 11. 后台测试
- `lib/__tests__/api.test.ts`：为两个新 api 方法补测。
- 新增 `lib/__tests__/ai-task.test.ts`：mock `aiGenerateImagePollAction`，测 done/error/timeout 三条路径。

## 关键文件清单
后端：
- 新增 `src/modules/ai/ai-image-task.service.ts`、`src/modules/ai/ai-image-task.service.spec.ts`
- 改 `src/modules/ai/ai-templates.controller.ts`、`src/modules/ai/ai.module.ts`

后台：
- 改 `src/types/admin.ts`、`src/lib/api.ts`、`src/actions/ai.ts`
- 新增 `src/lib/ai-task.ts`、`src/lib/__tests__/ai-task.test.ts`
- 改 `src/components/ai-create/step-cover.tsx`、`src/components/ai-create/wizard.tsx`

复用现有：`AiGenerateImageService.generate`、`AiConfigService.getActiveConfig`、`base64ToFile`、`adminFetch`、Nest `NotFoundException`。

## Verification（验证）
1. 后端：`cd lumira-server/packages/backend && npx jest src/modules/ai`（含新增任务服务用例）+ `tsc -p tsconfig.build.json`.
2. 后台：`cd lumira-server/packages/admin && vitest run`（api/ai-task 用例）。
3. 手工（本地起后端 `npm run dev` + 后台 `npm run dev`）：AI 建模 → 仅文字描述 → 开始识别 → 第3步点「生成效果图」→ 观察按钮进入「生成中…」并在模型返回后自动出现封面候选、不再永久转圈；Network 里看到的是 `/ai-generate-image` 返回 `taskId` 后的一组短轮询。
4. 全自动流程：点「全自动生成并上架」，验证识别→生图(轮询)→剪影→提交全链路成功。
5. 回归：剪影生成（仍同步）与后端原有测试不受影响。

## 交付
按 AGENTS.md：后端/后台改动完成后分别 `git commit` 并同时 `git push origin master`（gitee）+ `git push github master`。