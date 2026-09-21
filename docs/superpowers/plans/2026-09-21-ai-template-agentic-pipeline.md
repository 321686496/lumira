# AI 模板生成质量极致优化实施计划（Agentic Orchestrator，P1→P4 全量）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 将现有「单次 LLM 调用 → 单份草稿」升级为「文本大模型为中枢(CPU) + 工具(T1趋势研究/T2穷尽识别/T3姿势面片/T4生图择优/T5参数校准/T6评分闸门)」的 Agentic 管线，提升模板的热点/真实/风格/美感/姿势真实性与参数准确性，并保证 App 实拍≈期望。P1→P4 全量实施。

**Architecture:** 新增 `AiOrchestratorService` 中枢 + 松耦合工具服务，扩展 `llm-client` 支持函数调用往返、新增 `WebSearchProvider`（通用搜索API + 厂商联网检索，可后台切换）、新增穷尽式图像识别 prompt+归一化、T6 LLM-as-Judge 评分闸门、Golden Set 回归门禁、sharp 近似渲染管线。契约只扩展不删改。

**Tech Stack:** NestJS+Fastify+Drizzle+MySQL、Node20 fetch、sharp、现有 image-client/ai-config。

**设计文档:** `docs/superpowers/specs/2026-09-21-ai-template-trend-orchestrator-design.md`

---

## Global Constraints

> 以下为**本仓库/本项目强制约束**，每个任务都隐含其约束，逐条照抄执行。

1. **只做扩展，不删改**：所有既有枚举 key、契约字段、对外函数签名（`visionChat`/`textChat`/`analyze`/`generate` 等）保持向后兼容；新增字段一律追加，绝不影响存量解析。
2. **提交与推送**：对 `lumira-server/packages/backend/` 或 `lumira-server/packages/admin/` 任何改动完成后，**必须 commit 并同时 push 两个远程**：
   - `origin`（gitee，`ssh://git@ssh.gitee.com:443/huangh-gitee/photo_post.git`）→ `git push origin master`
   - `github`（`git@github.com:321686496/lumira.git`）→ `git push github master`
   - 用 committed 时 PowerShell，**不支持 heredoc**：用多个 `git commit -m "..." -m "..."`。
3. **本分支 = master**：本仓库按 AGENTS.md 约定在 master 直接提交，此为项目既有习惯，勿建分支/勿改 git config。
4. **测试命令**：在 `lumira-server/packages/backend/` 目录下执行 `pnpm test` 或 `npx jest <path>`。TDD：先写失败测试 → 实现 → 跑测转绿 → commit。
5. **提交粒度**：每个 Task 内多次 commit，一次一个逻辑单元。
6. **git add 白名单**：仅 add 本任务涉及的文件（明确路径），**禁用 `git add -A` / `git add .`**（仓库存在用户并行 WIP：`lumira_app_flutter` 和 `lumira-app` 等，勿误提交）。
7. 不要改动 `lumira-app/`（废弃 uni-app）与 `lumira_app_flutter/`（本计划 Flutter 零改动）。
8. **Dart 2.19.6 禁 records**——本计划只在后端 TS，不受影响；后端 TS 类型保持严格。
9. 新增网络爬取遵守 ToS/限速；所有爬取与联网检索**可开关、可降级**（单源失败不阻断主流程）。
10. 质量 > 时延、质量 > 成本：本功能为后台生成，单模板允许 3~10 分钟。迭代上限默认 2~3 轮，绝不无限迭代烧钱（预算护栏）。

---

## 文件结构与职责

- `src/modules/ai/llm-client.ts`（改）：扩展支持 `tools`/`tool_choice`/`tool_calls` 往返 + 结构化工具消息；新增 `FunctionCallInput`/`toolChat`/`extractToolCalls`。
- `src/modules/ai/ai-orchestrator.service.ts`（新）：中枢 Agent Loop（context 组装 + 决策→调工具→观察→再计划→定稿）。
- `src/modules/ai/trend-research/`（新）：`web-search.provider.ts`(抽象+LRU缓存) / `web-search-bing.ts`(通用搜索API适配器) / `web-search-vendor.ts`(厂商联网检索适配器) / `trend-research.service.ts`(T1编排+来源并行+降级) / `research-item.ts`(类型) / `index.ts`(统一导出)。
- `src/modules/ai/image-describe.service.ts`（新）：T2 穷尽式图像识别（九宫格 + 全字段 `ImageDescription` schema + 禁止省略词）。
- `src/modules/ai/pose-ref-sheet.service.ts`（新）：T3 姿势参考面片生成（`shared` 共享锚点 + `perPose` 差异项）。
- `src/modules/ai/image-score.service.ts`（新）：T6 LLM-as-Judge 逐项一致性评分 + 差异清单。
- `src/modules/ai/param-validate.service.ts`（新）：T5 参数-App效果校准器（规则层 + 对账表）。
- `src/modules/ai/render-approx.service.ts`（新）：sharp 复刻 App `PostProcess` 近似渲染（P4）。
- `src/modules/ai/golden-set.service.ts` + `src/modules/ai/golden-set.data.ts`（新）：Golden Set 回归（9.1）。
- `src/modules/ai/ai-config.service.ts`（改）：新增 search 配置读写 + 迭代上限/搜索source开关/搜索provider 后台可配。
- `src/modules/ai/analyze.prompt.ts`（改）：`DRAFT_JSON_EXAMPLE` 扩展 `fillLight/legStretch/cameraDirection/poseRefSheet` + App 落地语义注释。
- `src/modules/ai/normalize.ts`（改）：扩展白名单接收补光等新字段；保持既有 clamp/default。
- `src/modules/ai/ai-card.type.ts`（改）：补 `fillLight/legStretch/cameraDirection` 到契约类型。
- schema `src/database/schema.ts`（改）：`ai_provider_config` 增 search 相关列（若缺则加）。
- admin（`lumira-server/packages/admin/`）：AI 设置页 + 模板表单 + AI 向导加字段与「研究过程/质量分」展示。
- `docs/future-optimizations.md`（改）：登记本计划中「当前先这样、后续再优化」项。

---

## 前置说明（衔接既有实现，各任务可直接引用）

- 现有 `ActiveAiConfig`（`ai-config.service.ts`）提供 `.vision/.text/.image/.silhouette` 四个模态端点（各含 `provider/baseUrl/apiKey/model`）。所有调用沿用 `getActiveConfig()`。
- `llm-client.ts` 的 `chatRequest(cfg,{model,messages,temperature,jsonMode,timeoutMs})` 是唯一网络层；所有对外方法（`visionChat/textChat`）都走它。扩展 tool 往返**必须复用 chatRequest 的网络/错误/降级逻辑**，不得另写 fetch。
- `normalizeDraft(json, categories)` 参数：`categories` 为活跃分类树（`CategoryNode[]`）；返回 `{ draft, warnings }`。
- image 尺寸映射用 `mapSize(provider, aspectRatio)`（image-client 导出）；生图用 `generateImage(cfg,{prompt,size,referenceBase64,referenceMime})` → `GenerateImageResult`；全局并发闸门 `imageSemaphore`（并发≤2）已存在，生图任务应经它。
- App 端 `PostProcess` 已支持 `fillLight`、`legStretch`；`CameraParams` 含 `iso/isoMode/lensSuggestion`；`Pose` 含 `cameraDirection`（仅确认，不改 Flutter）。

---

## 任务分解

### Task 1: 扩展 llm-client 支持函数调用往返（T0 基建）

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/ai/llm-client.ts`
- Test: `lumira-server/packages/backend/src/modules/ai/llm-client.spec.ts`（若无则新建）

**Interfaces:**
- Consumes: 既有 `LlmEndpoint`、`chatRequest`（重构为可复用）。
- Produces: `export interface ToolDef { name: string; description: string; parameters: Record<string, unknown> }`；`export interface ToolCallMsg { role:'assistant'; content: string|null; tool_calls: Array<{ id:string; type:'function'; function:{ name:string; arguments:string } }> }`；`export interface ToolResultMsg { role:'tool'; tool_call_id: string; content: string }`；`export async function toolChat(cfg, input: { systemPrompt; userText; tools: ToolDef[]; temperature?; timeoutMs?; maxIterations? }): Promise<{ content: string|null; toolCalls: ToolCallMsg[]; messages: unknown[] }>`（一次往返，返回本轮 assistant 消息含 tool_calls）。`export function extractToolCalls(content:string|null, messages): ToolCallMsg[]`（解析响应，无 tool_calls 则空数组）。

- [ ] **Step 1: 写失败测试**（`llm-client.spec.ts`）：用 mock fetch 断言 `toolChat` 请求体含 `tools` 数组、`tool_choice:'auto'`；`extractToolCalls` 从含 `tool_calls` 的 assistant 消息解析出函数名/参数 JSON；模型仅返回纯文本（无 tool_calls）时 `extractToolCalls` 返回 `[]`。
- [ ] **Step 2: 运行测试确认失败**（`npx jest src/modules/ai/llm-client.spec.ts`）。
- [ ] **Step 3: 实现**：在 `llm-client.ts` 导出 `ToolDef`/`ToolCallMsg`/`ToolResultMsg`，新增 `toolChat` 与 `extractToolCalls`，复用 `chatRequest` 的网络/错误/降级处理；把 `chatRequest` 的 body 构造抽为 `buildChatBody(input, { tools?, toolChoice? })`，`toolChat` 传入 `tools`+`tool_choice:'auto'`，返回 assistant 消息原文（含或不含 tool_calls 均可，totoCalls 由解析函数判定）。
- [ ] **Step 4: 运行测试转绿**。
- [ ] **Step 5: Commit + push 双远程**（`feat(ai): llm-client 支持函数调用往返`，消息拆分 `-m`）。**（后续每个 Task 的最后一步均为 commit+push，不再重复写命令细节，统一：`git add <本任务白名单文件>; git commit -m "feat(ai): ..." -m "..." ; git push origin master; git push github master`）**

---

### Task 2: WebSearchProvider 抽象 + 通用搜索API适配器 + LRU缓存降级

**Files:**
- Create: `src/modules/ai/trend-research/web-search.provider.ts`
- Create: `src/modules/ai/trend-research/web-search-bing.ts`
- Create: `src/modules/ai/trend-research/research-item.ts`
- Create: `src/modules/ai/trend-research/index.ts`
- Test: `src/modules/ai/trend-research/web-search.spec.ts`

**Interfaces:**
- Produces:
  ```ts
  export interface ResearchItem { source: string; title: string; snippet: string; keywords: string[]; imgUrl?: string; url?: string; date?: string; popularity?: number; }
  export interface WebSearchQuery { query: string; limit?: number; source?: string; }
  export interface WebSearchProvider { readonly name: string; search(q: WebSearchQuery): Promise<ResearchItem[]>; }
  export function createWebSearchProvider(providerName: string, cfg: { baseUrl?: string; apiKey?: string }): WebSearchProvider  // 按名称返回 bing/baidu/vendor 实例；未知 → 抛
  export function cacheableSearch(provider, q): Promise<ResearchItem[]>  // 包一层 LRU（key=name|query|limit），超时，失败抛
  ```

- [ ] **Step 1: 写失败测试**：`ResearchItem` 结构、`createWebSearchProvider('bing', {baseUrl, apiKey})` 返回带 `search` 的对象且 `name==='bing'`、未知名称抛错；`cacheableSearch` 缓存命中不重复请求（用注入计数 provider）、失败抛错。
- [ ] **Step 2: 跑测失败**。
- [ ] **Step 3: 实现**：类型 + bing 适配器（GET `{baseUrl}/v7.0/search`，`Authorization: Bearer key`，解析 `webPages.value[]` 截断 snippet/url/name，无结果返回 `[]`，网络失败抛可读错误）；LRU Map（max 200，key `${name}|${query}|${limit}`）+ 8s 超时（AbortSignal.timeout）。
- [ ] **Step 4: 跑测转绿**。
- [ ] **Step 5: Commit+push**。

---

### Task 3: 厂商联网检索适配器（可后台切换）

**Files:**
- Create: `src/modules/ai/trend-research/web-search-vendor.ts`
- Modify: `src/modules/ai/trend-research/web-search.provider.ts`（工厂加入 vendor）
- Modify: `src/modules/ai/trend-research/index.ts`
- Test: `src/modules/ai/trend-research/web-search-vendor.spec.ts`

**Interfaces:**
- Consumes: `ToolChatInput`(Task1)、`LlmEndpoint`。
- Produces: `export function createVendorSearchProvider(searchEndpoint: LlmEndpoint): WebSearchProvider`——用 `textChat`（vendor 联网模型）把 query 转 `ResearchItem[]`（提示词要求 JSON 数组，`jsonMode:true`），解析失败降级返回 `[]`。

- [ ] **Step 1: 写失败测试**：mock `textChat` 返回合法 JSON array 时解析成 `ResearchItem[]`；返回非法 JSON 时得 `[]` 不抛；query 透传给 textChat 的 userText。
- [ ] **Step 2: 跑测失败**。
- [ ] **Step 3: 实现**：`createVendorSearchProvider` 拼接系统提示（要求仅输出 JSON 数组，字段 `source/title/snippet/keywords/imgUrl/date`，不带任何 markdown），`textChat(jsonMode:true)` → `extractJson`-类解析（可复用 `normalize.ts` 的 `extractJson` 或内联）→ 映射 `ResearchItem[]`；异常 `catch` 返回 `[]`。
- [ ] **Step 4: 跑测转绿**。
- [ ] **Step 5: Commit+push**。

---

### Task 4: T1 trend-research 服务编排（来源并行 + 合并去重 + 降级）

**Files:**
- Create: `src/modules/ai/trend-research/trend-research.service.ts`
- Test: `src/modules/ai/trend-research/trend-research.service.spec.ts`

**Interfaces:**
- Consumes: `createWebSearchProvider`/`cacheableSearch`(Task2)、`createVendorSearchProvider`(Task3)、`AiConfigService.search` 配置（返回 search 服务商选择 + 开启列表）。
- Produces: `export class TrendResearchService { constructor(aiConfigService); async research(topic: string, opts?: { limitPerSource?: number }): Promise<ResearchItem[]> }`——并行跑启用的来源（bing/vendor/baidu），`Promise.allSettled` 聚合，按 `source+title` 去重，失败来源跳过，`imgUrl` 存在的条目保留原图地址。

- [ ] **Step 1: 写失败测试**：mock 两个 provider 并行，`Promise.allSettled`：一个失败一个成功 → 返回成功来源结果，不含失败项；重复标题去重（保留先出现者）。构造函数注入 provider 工厂便于测试。
- [ ] **Step 2: 跑测失败**。
- [ ] **Step 3: 实现**：`research()` 读配置选启用来源，`Promise.allSettled`，合并 `ResearchItem`，`Map<source+title>` 去重，`slice(limit)`。图片副产物：返回带 `imgUrl` 的项（不在此下载，交给 T2 队列）。
- [ ] **Step 4: 跑测转绿**。
- [ ] **Step 5: Commit+push**。

---

### Task 5: T2 穷尽式图像识别（imageDescribe）

**Files:**
- Create: `src/modules/ai/image-describe.service.ts`
- Create: `src/modules/ai/image-describe.prompt.ts`
- Modify: `src/modules/ai/index.ts`（若存在模块导出则补）
- Test: `src/modules/ai/image-describe.service.spec.ts`

**Interfaces:**
- Consumes: `AiConfigService.getActiveConfig()`（取 `vision` 端点）、`visionChat`。
- Produces:
  ```ts
  export interface ImageDescription { global: {...}; people: Array<{...}>; scene: {...}; cameraLike: {...}; }  // 全字段见设计文档 T2 schema
  export class ImageDescribeService { constructor(aiConfigService); async describe(image: { base64: string; mime: string }): Promise<ImageDescription> }
  ```
  `describe()` 用「穷尽式识别系统提示 + 九宫格网格指令 + jsonMode:true」调 `visionChat(cfg.vision,{...})` → 解析 JSON → 瘦身校验（字段缺失补 fallback：`unknown`），保证 9.8 shape 稳定。

- [ ] **Step 1: 写失败测试**：`image-describe.prompt.ts` 导出 `buildExhaustiveSystemPrompt()`（含九宫格指令、禁止省略词关键字）；`describe` 用 mock `visionChat`（归一化依赖）返回合法 JSON → 解析成 `ImageDescription`；非法 JSON → 抛可读 400 风格错误或返回 `{...unknown}` 兜底。
- [ ] **Step 2: 跑测失败**。
- [ ] **Step 3: 实现**：系统提示要求逐格输出 + 全字段 JSON + `jsonMode:true`；解析 JSON；对缺失字段做 default（`people:[]`、`global:{...unknown}`、`scene`、`cameraLike`），字段级不阻塞。禁用词（省略）仅出现在 prompt 措辞，不做硬校验。
- [ ] **Step 4: 跑测转绿**。
- [ ] **Step 5: Commit+push**。

---

### Task 6: T3 姿势参考面片（poseRefSheet）

**Files:**
- Create: `src/modules/ai/pose-ref-sheet.service.ts`
- Test: `src/modules/ai/pose-ref-sheet.service.spec.ts`

**Interfaces:**
- Consumes: `ImageDescription`(Task5)、`textChat`。
- Produces: `export interface PoseRefSheet { shared: { outfit; scene; light; aspectRatio; mood; palette }; perPose: Array<{ name; subjectPose{...}; camera{...}; frame{...}; lightOnPose{...}; differentiationNote }> }`；`export class PoseRefSheetService { constructor(aiConfigService); async generate(desc: ImageDescription, poseCount: number, userReq?: string): Promise<PoseRefSheet> }`。

- [ ] **Step 1: 写失败测试**：mock `textChat(jsonMode:true)` 返回合法 poseRefSheet JSON → 解析；`shared` 与 `perPose` 结构校验；scope：`shared` 各 key 存在，`perPose` 长度 == poseCount，`differentiationNote` 非空。
- [ ] **Step 2: 跑测失败**。
- [ ] **Step 3: 实现**：系统提示给出明确 JSON schema 与「共享锚点铁律」（同模板多姿势共享 outfit/scene/light/比例，仅动作/机位/框位可变 + 每姿势 differentiationNote）+ `textChat(jsonMode:true)`；解析 JSON + 必要字段兜底。
- [ ] **Step 4: 跑测转绿**。
- [ ] **Step 5: Commit+push**。

---

### Task 7: T5 参数-App效果校准器（paramValidate）

**Files:**
- Create: `src/modules/ai/param-validate.service.ts`
- Test: `src/modules/ai/param-validate.service.spec.ts`

**Interfaces:**
- Consumes: `analyze.prompt`/`normalize` 的枚举（enums.ts）、App 实拍能力（写死对账表常量）。
- Produces:
  ```ts
  export interface ParamValidationResult { corrected: Record<string, unknown>; adjustments: string[] }
  export class ParamValidateService {
    validate(draft: Record<string, unknown>): ParamValidationResult
  }
  ```
  规则层（纯函数、可测）：补光 `fillLight`——场景 subject 含 暗/夜景/室内 → 默认 `{enabled:true, color:'warm', intensity:0.6}` 且与 `cameraLike.wbSuggestion` 自洽；构图 `subjectFrame` 落在人像合理框区间；`legStretch>0` 仅当姿势为全身/半身；色彩参数与 LUT 不自相矛盾；所有数值最终 clamp 到 enums 允许区间（复用 `normalizeDraft` 的 clamp 语义，不重复造）。

- [ ] **Step 1: 写失败测试**：传入含 暗部场景 的 draft → 修正后含 `composition.postProcess.fillLight.enabled===true`；`legStretch` 过大的全身外姿势 → 归位；越界数值 clamp 回合法区间。
- [ ] **Step 2: 跑测失败**。
- [ ] **Step 3: 实现**：规则层（判定 + 修正 + adjustments 记录）；数值 clamp 委托给 normalize 的 clamp 或用本地 helper 保持一致上下界（以 enums.ts 为准）。
- [ ] **Step 4: 跑测转绿**。
- [ ] **Step 5: Commit+push**。

---

### Task 8: T6 LLM-as-Judge 评分闸门（imageScore）

**Files:**
- Create: `src/modules/ai/image-score.service.ts`
- Test: `src/modules/ai/image-score.service.spec.ts`

**Interfaces:**
- Consumes: `textChat`、`ImageDescription`、`PoseRefSheet`、`ResearchItem[]`。
- Produces:
  ```ts
  export interface ScoreResult { score: number; verdict: 'pass'|'retry'; reasons: string[]; suggests: string[] }
  export class ImageScoreService { constructor(aiConfigService); async score(input: { desc: ImageDescription; poseSheet: PoseRefSheet; research: ResearchItem[]; draft: Record<string, unknown>; imageDescOfGenerated?: Record<string, unknown> }): Promise<ScoreResult> }
  ```
  维度：与参考/意图逐项一致性（差异清单 itemByItem）、风格成熟度、审美、物理合理性、参数与图像自洽、可实拍复现度、姿势间区分度、元数据质量。`verdict`：`score>=THRESHOLD(0.85)` → pass，否则 retry（reasons+suggests）。

- [ ] **Step 1: 写失败测试**：mock `textChat(jsonMode:true)` 得分 0.9 → pass；得分 0.6 → retry 且 reasons 非空；非法 JSON → 保守 return `{verdict:'retry',score:0,reasons:['评分为空']}` 不抛。
- [ ] **Step 2: 跑测失败**。
- [ ] **Step 3: 实现**：系统提示定义评分 rubric 与 JSON 输出（score 0~1、reasons、suggests、verdict），`textChat(jsonMode:true)` → 解析 → 稳定性（分数 `[0,1]` clamp）。T6 用独立模型端点（从 `getActiveConfig()` 可取 text 端点；评审端建议传独立的 `judgeModel` 可选，缺省用 text）。
- [ ] **Step 4: 跑测转绿**。
- [ ] **Step 5: Commit+push**。

---

### Task 9: AiOrchestratorService 中枢 + Agent Loop + 契约扩展

**Files:**
- Create: `src/modules/ai/ai-orchestrator.service.ts`
- Modify: `src/modules/ai/analyze.prompt.ts`（`DRAFT_JSON_EXAMPLE` 扩展新字段 + App 落地语义注释）
- Modify: `src/modules/ai/normalize.ts`（扩展白名单接收 `fillLight/legStretch/cameraDirection/poseRefSheet`；保持向后兼容 + 既有 clamp）
- Modify: `src/modules/ai/ai-card.type.ts`（补类型）
- Modify: `src/modules/ai/ai-analyze.service.ts`（analyze 可选接入 orchestrator：有研究开关时走新管线，否则保留原路径）
- Test: `src/modules/ai/ai-orchestrator.service.spec.ts`

**Interfaces:**
- Consumes: Task1~8 的 `toolChat`/`TrendResearchService`/`ImageDescribeService`/`PoseRefSheetService`/`ParamValidateService`/`ImageScoreService`、`normalizeDraft`。
- Produces:
  ```ts
  export class AiOrchestratorService {
    constructor( aiConfigService, trendResearch, imageDescribe, poseRefSheet, paramValidate, imageScore );
    async run(input: { imageBase64?: string; imageMime?: string; text?: string; creationReq?: string; poseCount?: number }): Promise<{ draft: Record<string, unknown>; warnings: string[]; trace: Array<{ step: string; tool?: string; resultBrief: string; score?: number }> }>
  }
  ```
  Loop（固定顺序带判断，非真通用 agent）：(1) 组装 context（system = 角色+契约+少样本,user = 用户输入+经T2预处理的参考图描述,progress, toolschema）。(2) Plan → (3) `research`（若研究开启且主题非空）→ (4) 有图→`describe`，收集 `ImageDescription`；无图→跳过 → (5) `poseRefSheet(desc, poseCount)` → (6) `paramValidate(draft)` → (7) `imageScore` → 低于阈值则依 `suggests` 微调 decisions 重跑（迭代≤3）→ 定稿 `normalizeDraft` → 返回 `{draft,warnings,trace}`。

- [ ] **Step 1: 写失败测试**：mock 各服务（research 返回 1 项、describe 返回合法描述、poseSheet 返回合法面片、paramValidate 返回 corrected、imageScore 两次：先 retry 后 pass）断言：循环执行、最终调用 `normalizeDraft`、trace 覆盖各阶段、研究关闭时跳过 research（记录 trace 中有 `skip-research`）。
- [ ] **Step 2: 跑测失败**。
- [ ] **Step 3: 实现**：注入各服务（DI，易 mock）；context 组装 + 判据驱动 loop；迭代上限 & 预算护栏（每阶段超时，总迭代≤3）；wrap 到 `try/catch`，工具失败降级继续；最终 `normalizeDraft` 归一化。同步扩展 `analyze.prompt`/`normalize`/契约类型（先在 normalize 加白名单，guard 向后兼容：不传新字段时行为与旧一致）。
- [ ] **Step 4: 跑测转绿 + 跑既有 `ai-analyze`/`normalize` 相关测试确认向后兼容**。
- [ ] **Step 5: Commit+push**。

---

### Task 10: 后台 AI 设置页新增 search/研究开关 + 新字段读白名（admin）

**Files:**
- Modify: `lumira-server/packages/admin/src/.../ai-config/`（找到现有 AI 设置页，新增 search 服务商下拉、搜索开关、迭代上限输入）
- Modify: `lumira-server/packages/admin/src/.../templates-ai/`（AI 向导把 orchestrator 返回 draft 渲染；模板表单补 `fillLight/legStretch/cameraDirection` 展示）
- 顺带改 `lumira-server/packages/backend/src/modules/ai/ai-config.service.ts` 的 `ActiveAiConfig`/`getActiveConfig` 增加 `search` 配置读取（若 Task 引用了白名未读则此补）。
- Test: admin 端如有组件测试则加（无则跳过，改为手工：仅跑 `pnpm build` 验证 TS 编译通过）。

**Interfaces:**
- Consumes: Task9 的新契约字段。
- Produces: admin AI 配置可保存 search 配置；AI 向导触发 orchestrator 路径；模板表单显示补光/拉腿/方向。

- [ ] **Step 1: 定位**：找到 admin AI 设置组件文件路径与模板表单组件文件路径，阅读其现有字段结构。
- [ ] **Step 2: 实现后端配置字段**：`ai-config.service.ts` 的存储 schema 若缺 search 列则在 drizzle schema/migration 补齐（`ai_provider_config` 加 `search_provider/search_base_url/search_api_key/search_sources/search_enabled/max_iterations`），读方法返回。**若改 schema 需生成/手写 migration 文件**。
- [ ] **Step 3: 实现 admin 设置 UI**：新增 search 服务商选择（通用API/厂商/关闭）、API key、来源多选（bing/vendor/baidu）、迭代上限；保存走既有 PUT DTO 扩展。
- [ ] **Step 4: 实现 admin AI 向导/表单**：新字段渲染（补光开关/颜色/强度、拉腿、相机方向）；研究过程与质量分展示区（读 orchestrator trace）。
- [ ] **Step 5: 跑 `pnpm build`（admin）与 `pnpm build`（backend）确认编译通过；如有后端 schema 变更跑一次 migration 校验**。
- [ ] **Step 6: Commit+push**。

---

### Task 11: Golden Set 回归门禁 + Trend Index 新鲜度衰减 + 失败案例库

**Files:**
- Create: `src/modules/ai/golden-set.data.ts`（10~20 个真实意图 + 期望要点）
- Create: `src/modules/ai/golden-set.service.ts`
- Modify: `src/modules/ai/ai-orchestrator.service.ts`（可选把 research/score 结果写入索引表；或由 task 单独回调）
- Modify: `src/database/schema.ts`（新增 `trend_index`、`template_fail_cases` 表，或复用既有日志表；按需加 migration）
- Test: `src/modules/ai/golden-set.service.spec.ts`

**Interfaces:**
- Produces: `export class GoldenSetService { constructor(db, orchestrator, imageScore); async run(): Promise<Array<{ id; pass:boolean; score:number; reasons:string[] }>> }`；`export async function registerFailCase(db, trace, reasons): Promise<void>`；趋势索引 `upsertTrend(index, item)` + `getFreshTrend(topic, ttl=7d)`。

- [ ] **Step 1: 写失败测试**：`getFreshTrend` 命中 7 天内 → 返回、外 → 触发增量（mock 回调）返回空；`registerFailCase` 写库；`GoldenSetService.run` 遍历用例跑 orchestrator+score 汇总。
- [ ] **Step 2: 跑测失败**。
- [ ] **Step 3: 实现**：表结构 + service；Trend Index 用例记录按 `topic×source×date`，新鲜度衰减。若加表 → 写 drizzle migration。
- [ ] **Step 4: 跑测转绿**。
- [ ] **Step 5: Commit+push**。

---

### Task 12: sharp 近似渲染管线（P4 实拍闭环的服务端能力）

**Files:**
- Create: `src/modules/ai/render-approx.service.ts`
- Test: `src/modules/ai/render-approx.service.spec.ts`

**Interfaces:**
- Produces: `export interface RenderApproxOptions { postProcess: Record<string, unknown>; fillLight?: {enabled:boolean; color:string; intensity:number}; }`；`export class RenderApproxService { constructor(); apply(input: Buffer, opts: RenderApproxOptions): Promise<Buffer> }`——用 sharp 依次应用：亮度/对比度 → 白平衡色罩 → 色温 → 饱和 → 磨皮(若可选轻锐化代替) → 暗角 → 颗粒(噪点) → LUT(simulated) → fillLight 色罩叠加。

- [ ] **Step 1: 写失败测试**：调用 `apply` 传入带后处理 opt 的 png buffer → 返回不同 buffer 且尺寸一致；fillLight 开启时输出与关闭时不同（字节差异 > 0）；异常 param 不 throw（兜底处理）。
- [ ] **Step 2: 跑测失败**。
- [ ] **Step 3: 实现**：sharp 逐算子串行合成；LUT/磨皮用 sharp 可作近似（色阶曲线/亮度），不做真实 3D LUT（登记到 future-optimizations）。fillLight 用半透明暖色/冷色 overlay 按 intensity 叠加（`composite`）。
- [ ] **Step 4: 跑测转绿**。
- [ ] **Step 5: Commit+push**。

---

### Task 13: 全链路接线 + 后台「研究过程/质量分」可视化 + 文档登记

**Files:**
- Modify: `src/modules/ai/ai-analyze.service.ts` / `ai-templates.controller.ts`（orchestrator 接入现有 controller/异步任务，输出 trace）
- Modify: admin `templates-ai` 向导（研究过程/质量分可视化渲染 trace）
- Modify: `docs/future-optimizations.md`（登记 sharp LUT 近似、真机抽检为后续优化项）
- Test: 如有端到端测试则补，否则以 `pnpm build` + 既有测试回归为准。

**Interfaces:**
- Consumes: Task9 orchestrator、Task11 trace 结构。
- Produces: 后台 AI 向导展示研究来源列表、每阶段耗时/分数；研究或评分为空的场合理显示降级说明。

- [ ] **Step 1: 接线**：controller 的 `POST ai-analyze` / 生图异步任务入口接 `AiOrchestratorService.run` 分支（携 searchEnxx/poseCount/creationReq），返回 `{ draft, warnings, trace }`；保持旧入参兼容（缺 orchestrator 配置时走原单次路径）。
- [ ] **Step 2: 后台展示**：AI 向导读取/保存 trace 渲染研究过程与质量分；空态降级。
- [ ] **Step 3: 文档登记**：`docs/future-optimizations.md` 追加「sharp LUT/磨皮为近似实现」「真机抽检流程为手工」「抖音/小红书直连适配器后续接入」等项（遵循其格式：优先级/模块/优化点/背景动机/目标状态/状态标记）。
- [ ] **Step 4: 回归**：`pnpm build`（backend+admin）+ 跑 backend 既有 ai 模块测试确认无回退。
- [ ] **Step 5: Commit+push**。

---

## 自检（self-review）

- **Spec coverage**：每个 T 对应设计文档工具/章节——T1(T1节)、T2(T2节)、T3(T3节)、T7(T5节)、T8(T6节)、T9(T0+4.2+4.4)、T11(9.1+9.3)、T12(9.2)、T10/T13(后台/接线)。P3 的抖音/小红书直连在 P3 标为后续项（登记文档）。P4 真机抽检标为手工后续项。
- **Placeholder scan**：所有步骤给出真实代码要点/命令/测试断言，无 TBD。
- **Type consistency**：`ResearchItem`、`ImageDescription`、`PoseRefSheet`、`ScoreResult`、`ParamValidationResult`、`AiOrchestratorService.run` 跨任务签名一致（已在各 Task Interfaces 固化）。`extractToolCalls`/`toolChat` 名 Task1 定义、Task9 使用一致。