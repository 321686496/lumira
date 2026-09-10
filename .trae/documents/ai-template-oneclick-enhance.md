# AI 一键生成模板：问题修复 + 功能增强计划

## 一、问题诊断结论（先回答你的疑问）

### 1. 为什么「生成剪影」一直卡在"生成中"，后端 API 像没被调用？

代码层面的直接缺陷（相互叠加导致卡死）：

- [step-silhouette.tsx](e:\Project\photo_post\lumira-server\packages\admin\src\components\ai-create\step-silhouette.tsx) 的 `generate()` 与 [wizard.tsx](e:\Project\photo_post\lumira-server\packages\admin\src\components\ai-create\wizard.tsx) 的 `runAutoAll()` **没有 try/catch/finally**：server action 一旦抛错（网络错误 / 框架层错误 / redirect），`setGenerating(false)` 永远不会执行 → 按钮永久停在"生成中…"。
- [api.ts](e:\Project\photo_post\lumira-server\packages\admin\src\lib\api.ts) 的 `adminFetch` **没有超时**：剪影走的是后端本地 RMBG-1.4 ONNX 推理（1024×1024 纯 CPU），在弱 CPU 服务器上可能耗时数十秒甚至更久；期间 NestJS 默认 logger **只在请求完成后才输出日志**（进行中的请求无任何日志）→ 观感上就是"后端 API 没被调用"。
- 链路上还存在两处硬超时会"无声"掐断请求：nginx `proxy_read_timeout 60s`（见 [nginx-lumira.conf.example](e:\Project\photo_post\deploy\nginx-lumira.conf.example#L109)）和 Vercel serverless 函数默认时长（admin 部署在 Vercel）；被掐断的错误同样因无 catch 而被吞。
- 后端剪影管线 [silhouette.pipeline.ts](e:\Project\photo_post\lumira-server\packages\backend\src\modules\ai\silhouette.pipeline.ts) **无任何阶段耗时日志**，无法观测到底慢在哪 / 是否开始执行。

### 2. 为什么点「上架 / 保存为未上架」没有任何反应？

- [template-form.tsx](e:\Project\photo_post\lumira-server\packages\admin\src\components\template-form.tsx#L966-L968) 的 `doSubmit` 调用 `handleSubmit(onSubmit)()` **没有传 `onInvalid` 回调**：react-hook-form + zod 校验失败时是"静默失败"（只把 errors 写到各字段），不弹任何提示。
- 出错的字段在表单内部的**其他 step**（表单自身有 6 步），用户停留在向导 Step5，根本看不到错误。
- 存在**后端归一化与前端校验范围错位**的实际踩雷点：
  - `normalize.ts` 把 `exposureCompensation` clamp 到 **-5..5**，但表单 schema 要求 **-3..3** → AI 输出 4 时提交必然静默失败；
  - `shortDesc` 提示词要求 ≤20 字但无截断，LLM 超一个字就校验失败；
  - `name` 提示词要求 12~30 字但 schema 上限 100，超长同样失败。

### 3. 目前封面生图的提示词是怎么喂给 AI 的？

后端统一拼接（前端不拼 prompt）：[image-prompt.builder.ts](e:\Project\photo_post\lumira-server\packages\backend\src\modules\ai\image-prompt.builder.ts) 的 `buildImagePrompt(draft)` 从草稿 JSON 按固定顺序合成中文一段式：`一张{画幅}{主体类型}摄影作品，风格{tags}，{构图描述}，{光线}，背景{…}，可搭配{道具}，整体呈{LUT}色调，带{颗粒感}，传递「{shortDesc}」的情绪。`——**目前没有任何用户自定义附加提示词的通道**。

### 4. 姿势个数目前是怎么定的？

提示词 [analyze.prompt.ts](e:\Project\photo_post\lumira-server\packages\backend\src\modules\ai\analyze.prompt.ts) 的 JSON 契约示例只给了 1 个姿势、无数量指令 → **AI 实际上基本固定输出 1 个**。下游其实已具备多姿势能力（`normalizeDraft` 支持 pose 数组、`applyTemplateJson` 支持数组导入），只差提示词与输入控制。

---

## 二、实施方案

### Phase 1：修复两个卡死/无反应 Bug（最高优先级）

#### 1.1 admin `src/lib/api.ts` — adminFetch 增加超时
- `adminFetch<T>(path, init?, timeoutMs?)`：`fetch` 增加 `signal: AbortSignal.timeout(timeoutMs)`（与现有 init.signal 逻辑合并）。
- AI 三个端点（`aiAnalyze` / `aiGenerateImage` / `aiGenerateSilhouette`）传 `300_000`（生图内部已有 120s 请求 + 60s 轮询，剪影本地推理慢，给足 5 分钟）。
- 超时错误文案带秒数，便于区分。

#### 1.2 admin `step-silhouette.tsx` — generate() 加兜底
```ts
const generate = async () => {
  ...
  setGenerating(true);
  try {
    const result = await aiGenerateSilhouetteAction(fd);
    if ('error' in result) { toast(...); return; }
    ...
  } catch (e) {
    toast({ variant: 'destructive', title: '剪影生成失败', description: (e as Error).message });
  } finally {
    setGenerating(false);
  }
};
```

#### 1.3 admin `step-cover.tsx` — generate() 同样加 try/catch/finally（同 1.2 结构）。

#### 1.4 admin `wizard.tsx` — handleAnalyze / runAutoAll 加兜底
- `handleAnalyze`：try/catch/finally（`setAnalyzing(false)` 放 finally）。
- `runAutoAll`：整体 try/catch；意外异常 → `setAutoState({ running: false, stage: 当前阶段, error: message })` 并停在当时步骤（复用现有失败 UI）。

#### 1.5 admin `ai-create/page.tsx` — 增加 Vercel 函数时长
```ts
export const maxDuration = 60;
```
（尽力延长 server action 所在函数时长，本地 dev 无影响。）

#### 1.6 backend — 剪影端点可观测性
- `ai-templates.controller.ts` 的 `generateSilhouette`：入口即 `Logger.log('ai-generate-silhouette: request received ...')`（文件大小 / mode / engine）。
- `silhouette.pipeline.ts` 的 `generateSilhouettePng`：阶段耗时日志——RMBG 推理 / alpha 缩放 / 合成 / 裁剪 / 总计（对齐项目工程惯例「stage time breakdown」）。

#### 1.7 backend `normalize.ts` — 校验范围对齐表单
- `exposureCompensation` clamp 范围 -5..5 → **-3..3**（与表单 schema 一致）。
- `shortDesc` 超过 20 字 → 截断 + warning（`meta.shortDesc 长度 X 超 20 字已截断`）。
- `name` 超过 100 字 → 截断 + warning。

#### 1.8 admin `template-form.tsx` — 提交失败可见化
- 新增 `FIELD_STEP` 映射（form 字段 → 表单内部步骤 0~5）：
  - step 0 基本信息：name / category / price / description / shortDesc / author / tags / referenceSource
  - step 2 构图：overlayType / gridType / aspectRatio / opacity / subjectFrame* / compositionDescription
  - step 3 相机参数：exposureCompensation / isoMode / iso / shutterSpeed / whiteBalance / whiteBalanceK / flashMode / focusMode / lensType / lensSuggestion
  - step 4 场景引导：lightDirection / shootingDistance / background / props / bestTime / tips
  - step 5 后期处理：cropRatio / color* / smoothStrength / sharpen / vignette / grain / lut / systemFilter / fillLight*
- `onInvalid(errors)` 回调：取第一个错误字段 → `setStep(FIELD_STEP[field])` 跳到对应步骤 → toast 显示「{字段中文名}：{错误信息}」→ 表单容器 `scrollIntoView({ behavior: 'smooth' })`。
- `doSubmit` 与 `<form onSubmit>` 两处均改为 `handleSubmit(onSubmit, onInvalid)`。

### Phase 2：AI 剪影生成（模型 = 生图模型 或 单独指定）

#### 2.1 DB 迁移 `migrations/031_ai_silhouette_model.sql`
```sql
ALTER TABLE `ai_provider_config`
  ADD COLUMN `silhouette_model` VARCHAR(64) NULL AFTER `image_model`;
```
语义：**NULL/空 = 与生图模型一致（默认）；非空 = 单独指定的专用剪影模型**。（database.service.ts 运行时自动执行 migrations，Dockerfile 已含拷贝步骤。）

#### 2.2 backend `schema.ts` / `update-ai-config.dto.ts` / `ai-config.service.ts`
- drizzle 表增加 `silhouetteModel: varchar('silhouette_model', { length: 64 })`（nullable）。
- DTO 增加 `@IsOptional() @IsString() @MaxLength(64) silhouetteModel?: string`；保存时空串归一为 null。
- `AiConfigView` / `UpdateAiConfigPayload`（admin types 同步）增加 `silhouetteModel: string | null`。
- `getActiveConfig()` 返回 `silhouetteModel: row.silhouetteModel ?? row.imageModel`（调用方直接拿"生效的剪影模型名"）。

#### 2.3 backend `ai-generate-silhouette.service.ts` — 新增 AI 引擎
- `meta` 扩展：`{ mode, crop, engine }`，`engine: 'local' | 'ai'`，缺省 `'local'`（向后兼容）。
- `engine = 'ai'` 流程：
  1. `aiConfigService.getActiveConfig()`（未配置/未启用 → 503，文案引导去 AI 设置）；
  2. 构建 AI 剪影提示词（solid：`纯白背景上的黑色实心人形剪影插画，完整保留参考图中人物的姿势、比例与画面位置，边缘干净利落，无背景细节无文字无阴影`；sketch：`纯白背景上的单色人物线稿插画，干净细线条勾勒参考图中人物的姿势轮廓与衣物结构，保留姿势比例与画面位置，无底色无文字`）；
  3. 复用 `image-client.ts` 的 `generateImage(cfg, { prompt, size: mapSize(provider, 源图最近似比例), referenceBase64: 源图 })` — doubao/openai 走图生图保持姿势，qwen/zhipu 内部忽略参考图走文生图（既有行为）；
  4. sharp 后处理转透明底：`grayscale` → 阈值二值化（solid：像素 < 235 → 纯黑，≥ 235 → 透明；sketch：≥ 245 → 透明，< 245 → 纯黑线条）→ 可选 `computeAlphaBbox` 裁剪（复用现有函数）。
- `engine = 'local'` 保持现有 RMBG 管线不变（AI 设置未配置时的兜底）。

#### 2.4 admin `step-silhouette.tsx` — 生成方式选择
- 新增「生成方式」单选：`AI 生成` / `本地抠图`；默认值：AI 已配置并启用 → `ai`，否则 `local`（页面加载时经 `getAiConfigAction` 判断，同时显示「将使用模型：{silhouetteModel ?? imageModel}」小字）。
- `generate()` 的 meta 带 `engine`；本地方式沿用 RMBG。

#### 2.5 admin `ai-config-form.tsx` — 剪影模型字段
- 新增输入「剪影模型（可选）」：占位说明「留空 = 使用生图模型」；旁边「同生图模型」快捷按钮把 `imageModel` 填入。
- `FormState` / 保存 payload / types 同步增加 `silhouetteModel`。

#### 2.6 admin `wizard.tsx` — 全自动流程剪影阶段
- 已获取 AI 配置（2.4 的同一个请求）时，stage ③ 的 meta 传 `engine: 'ai'`；未配置则 `local`。

### Phase 3：Step1「文字描述 / 创作要求」+ 姿势个数控制

#### 3.1 admin `wizard.tsx` Step1 UI
- 新增 `textarea 文字描述`（可选多行）与 `textarea 创作要求（可选）`。
- 新增「姿势个数」选择：`AI 自动判断`（默认）或固定 `1~6`。
- `handleAnalyze` / `runAutoAll` 的 FormData 增加 `textDesc` / `creationReq` / `poseCount`（空 = 自动）。

#### 3.2 backend `ai-templates.controller.ts` — `parseAiMultipart` 扩展
- 文本字段解析增加：`textDesc` / `creationReq` / `poseCount` / `extraPrompt`（Phase 4 用），`analyze` 端点透传给 service。

#### 3.3 backend `analyze.prompt.ts` — 提示词改造
- `buildAnalyzeUserPrompt(textDesc?, creationReq?, poseCount?)`：
  - 文字描述非空：`用户文字描述：{textDesc}`；
  - 创作要求非空：`创作要求：{creationReq}`；
  - 姿势数量指令：
    - 固定 N：`pose 数组必须恰好输出 {N} 个姿势，每个姿势有独立的 name / description / position`；
    - 自动：`请根据文字描述与创作要求（包括示例图中可见的文字要求）判断需要多少个姿势，在 1~6 个范围内输出，每个姿势有独立的 name / description / position`。
- 系统提示词硬约束追加：`pose 数组数量规则见用户消息；无明确要求时输出 1 个`；`DRAFT_JSON_EXAMPLE` 的 pose 项注释标注「可多元素」。

#### 3.4 backend `ai-analyze.service.ts`
- `analyze(image, textDesc, creationReq, poseCount)` 透传（校验 poseCount 为 1~6 整数或空）。

#### 3.5 backend `normalize.ts`
- pose 数组 > 6 个 → 截断至 6 + warning（防止 LLM 失控输出）。

（多姿势回填链路 `applyTemplateJson` 已支持 pose 数组，无需改动。）

### Phase 4：封面生图「附加提示词」

#### 4.1 admin `step-cover.tsx`
- 新增 `textarea 附加提示词（可选）`：说明「附加到 AI 生成效果图的提示词末尾，可表达对封面图的额外要求」。
- `generate()` FormData 增加 `extraPrompt`（trim 后非空才传）。
- 全自动流程不增加该输入（全自动定位即无人工介入；失败/重 roll 在 Step3 可用附加提示词补生成）。

#### 4.2 backend `ai-generate-image.service.ts` + controller
- controller 解析 `extraPrompt` 文本字段；`generate(reference, metaJson, extraPrompt)`。

#### 4.3 backend `image-prompt.builder.ts`
- `buildImagePrompt(draft, extraPrompt?)`：extraPrompt 非空时在最后附加一段 `额外要求：{extraPrompt}`（用户显式要求置于末尾，权重最高）。

### Phase 5：验证与收尾

1. **单测**（更新既有 spec，遵循 TDD 习惯）：
   - `image-prompt.builder.spec.ts`：extraPrompt 附加 / 空 / 空白用例；
   - `normalize.spec.ts`：exposureCompensation -3..3 clamp、shortDesc/name 截断、pose 6 上限；
   - `ai-generate-silhouette.service.spec.ts`：engine='local' 缺省兼容 + engine='ai' 分支（mock image-client 与 sharp）；
   - `ai-analyze.service.spec.ts`：新参数透传。
   - 命令：`cd lumira-server; pnpm --filter @lumira/backend test`
2. **admin 构建验证**：`pnpm --filter @lumira/admin build`（typecheck + lint 随构建）。
3. **手动验证清单**：
   - 本地起后端，点「生成剪影」→ 观察后端入口日志 + 阶段耗时日志（验证"API 是否被调用"从此可直接观测）；
   - 人为停掉后端再点生成 → 按钮 5 分钟内恢复并弹错误 toast（不再永久"生成中"）；
   - AI 草稿把曝光补偿改成 4（或 shortDesc 超 20 字）→ 点「上架」→ toast 提示 + 表单自动跳到对应步骤；
   - AI 设置页保存剪影模型（留空 / 同生图 / 单独指定三种态）；
   - Step4 切「AI 生成」→ 生成实心/线稿剪影 → 透明棋盘格预览正常 → 应用到姿势；
   - Step1 填文字描述「三连拍姿势」+ 姿势个数 3 → 识别草稿回填 3 个姿势；选「AI 自动判断」→ 由描述决定个数；
   - Step3 填附加提示词「人物戴草帽」→ 生成效果图中出现草帽。
4. **提交与推送**（AGENTS.md 约定：backend/admin 改动完成即 commit + push 双远程）：
   - commit 后 `git push origin master` + `git push github master`（后端部署 CI 与 Vercel 自动接管；migration 031 由后端重启时自动执行）。

## 三、关键决策与假设

| 决策点 | 选择 | 理由 |
|---|---|---|
| 剪影模型语义 | NULL = 同生图模型；非空 = 专用模型 | 与"可一致可不一致"的需求一一对应，默认零配置即用 |
| AI 剪影技术路线 | AI 生成"白底剪影/线稿图" + sharp 阈值二值化转透明 | 生图模型无法直接输出透明 PNG；参考图走图生图可保姿势（qwen/zhipu 退化为文生图，既有能力） |
| Step4 默认引擎 | AI 已配置 → 'ai'，否则 'local' | 用户主诉要 AI 剪影；本地 RMBG 保留为兜底 |
| 姿势个数上限 | 1~6 | 与模板表单姿势编辑器规模匹配；防止 LLM 失控 |
| extraPrompt 注入位置 | 拼接在 buildImagePrompt 末尾 | 用户显式额外要求权重最高；实现最简单、向后兼容 |
| 范围对齐方向 | normalize 收紧到表单 schema（-3..3） | 表单/Flutter 端口径为 -3..3，改后端不动前端校验 |
| 全自动流程 extraPrompt | 不加输入 | 全自动定位为零人工介入；Step3 重 roll 已覆盖 |
