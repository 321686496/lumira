# 联网研究二次整理 + 识别流程时间线重构（设计）

- 日期：2026-09-26
- 范围：`lumira-server/packages/backend`（NestJS） + `lumira-server/packages/admin`（Next.js）
- 相关既有文档：
  - `docs/specs/2026-09-09-ai-template-one-click-creation-design.md`
  - `docs/superpowers/specs/2026-09-21-ai-template-trend-orchestrator-design.md`
  - `docs/superpowers/specs/2026-09-24-ai-create-process-trace-design.md`
  - `docs/superpowers/specs/2026-09-24-ai-llm-raw-trace-design.md`

## 1. 背景与问题

### 1.1 联网搜索结果在做无用功

现状：识别前会执行趋势研究（联网检索），检索命中的条目经 **纯规则** 的 `buildResearchDigest`
（`trend-research/research-digest.ts`）截断后拼成「标题：摘要」若干行，作为 `网络趋势参考`
注入模板生成提示词（`analyze.prompt.ts` 的 `extrasLines`）。

缺陷：没有任何 LLM 二次整理。裸域名条目、排版残留、与主题无关的摘要原样进入提示词，
模型倾向忽略，联网检索的产出没有真正转化为可写进模板字段的信息。

### 1.2 后台实时流程时间线错乱

`ai-analyze.service.ts` 的 `traceStep('research', '趋势研究（联网检索）')` 包住
`trendResearch.research()`，而 `reorganize`（查询词重组）是在其内部先执行的。但
`llm-trace.ts` 的 `traceStep` 在 fn 执行前就 emit `running`，且事件没有父子字段；
前端 `analyze-trace-stream.tsx` 用 `Map<step>` 按 first-seen 顺序把扁平事件拍平成同级行，
于是「趋势研究」先建行、「查询重组」后建行，呈现为 **因果倒置** 的
`趋势研究 → 查询重组 → 文字构思模板草稿 → 姿势参考面片 → 参数校准`。

另外两处错乱：

1. `ai-orchestrator.service.ts` 在复用识别前置检索结果时补发一条 `traceNote('research', …)`，
   前端把 `note` 事件统一追加到列表末尾 → 「趋势研究」在时间线尾部重复出现。
2. 前端 `Map<step>` 把编排循环中的多轮 `paramValidate / imageScore / draftRefine`
   合并成一行，状态反复 running→done→running，最终只显示最后一轮的结论与耗时。

## 2. 设计决策（已与用户确认）

| 决策点 | 选择 |
| --- | --- |
| 二次整理的产出形态 | 结构化 JSON 字段（`ResearchBrief`），注入提示词时渲染为带分节小标题的文本块 |
| 「资料整理」在时间线中的呈现 | 「趋势研究」下的子步骤（与 `查询重组` / `联网检索` 并列缩进） |
| 开销控制 | 总是执行 + 进程内 LRU 缓存；失败降级为规则摘要，不阻断识别 |
| 时间线方案 | 后端事件增加 `parentStep`，前端渲染带竖轨的嵌套时间线；`note` 就地插入 |

## 3. 后端设计

### 3.1 新增 `trend-research/research-brief.ts`（纯函数）

```ts
export interface ResearchBrief {
  summary: string;                              // 一句话结论（后台展示 / resultBrief）
  themes: string[];                             // 交叉验证的流行主题 / 题材
  styles: string[];                             // 风格倾向
  colorLight: string[];                         // 色彩与光影倾向
  visualElements: string[];                     // 可复现的视觉元素 / 场景 / 道具
  seasons: string[];                            // 时令 / 节日 / 档期（含年份月份）
  poseIdeas: string[];                          // 姿势 / 构图灵感
  sources: { title: string; url?: string }[];   // 可信来源（供人工核对）
}

/** 渲染为带分节小标题的文本块（注入模板生成提示词） */
export function renderResearchBrief(brief: ResearchBrief): string;
/** 是否含有效内容（全空 → 视为整理失败） */
export function briefHasContent(brief: ResearchBrief): boolean;
```

渲染规则：只输出非空分节；`sources` 渲染为 `标题` + 可选 URL；总长上限沿用 2400 字。

### 3.2 新增 `trend-research/research-digest.service.ts`

- `@Injectable()`，注入 `AiConfigService`。
- `summarize(topic: string, items: ResearchItem[]): Promise<ResearchBrief | null>`
  - 空条目 → `null`（不调用 LLM）。
  - LRU 缓存（max 100），key = `topic` + 条目标题/摘要指纹（简易 djb2 hash），命中直接返回。
  - `textChat(cfg.text, { jsonMode: true, temperature: 0.3, timeoutMs: 30_000 })`。
  - 提示词约束：
    - 剔除裸域名条目、排版残留（表格/标题符号）、与创作意图无关的内容；
    - 只保留可复现、可直接写进模板字段的结论；
    - 时间/节日/时令换算成具体可检索的年月表述；
    - 不得编造来源中不存在的内容；无法判断的字段留空数组/空串。
    - 只输出 JSON，字段与 `ResearchBrief` 对齐。
  - 失败 / 超时 / 解析失败 / `briefHasContent` 为假 → 返回 `null`（调用方回退规则摘要）。
- 内部以 `traceStep('researchDigest', '资料整理', …)` 包裹 LLM 调用，使该步骤自动携带
  `parentStep = 'research'`。

### 3.3 接线 `trend-research.service.ts`

- 注入 `ResearchDigestService`。
- `research()` 在去重完成后、返回前，若 `out.length > 0`：

```ts
const brief = await this.digest.summarize(topic, out);
return { items: out, sourceErrors, brief };
```

放在 `research()` **内部**是关键：`ai-analyze` 层的 `traceStep('research', …)` 仍是父阶段，
`reorganize` / `researchDigest` / `search` 全部成为其子节点。
- `ResearchResult` 增加 `brief?: ResearchBrief | null`。
- `index.ts` 导出新类型与服务。

### 3.4 注入模板生成提示词

`ai-analyze.service.ts`：

```ts
research = r.items;
researchBrief = r.brief ?? null;
researchDigest = r.brief ? renderResearchBrief(r.brief) : buildResearchDigest(r.items);
```

`analyze.prompt.ts`：`网络趋势参考` 段文案改为「已由模型二次整理的趋势结论（分节给出）」，
其余约束（与创作要求冲突时以创作要求为准）保留；`researchUnavailable` 的防编造约束不变。
规则版 `buildResearchDigest` **保留为降级路径**。

### 3.5 事件模型：`parentStep`

`llm-trace.ts`：

- `AiTraceEvent` 新增 `parentStep?: string`。
- `TraceStore.currentStep` 改为 `stack: { step: string; title: string }[]`；
  `currentTraceStep()` 取栈顶（对外语义不变）。
- `traceStep`：进入前 `parentStep = 栈顶?.step` 写入 `running` 事件，然后入栈；`finally` 出栈。
- `startCall` / `traceNote`：`parentStep = 栈顶?.step`。
- 效果：`research.running` 的 seq 仍最早（父节点先建），但子事件携带 `parentStep`，
  前端可正确嵌套，不再因果倒置。

`ai-orchestrator.service.ts`：删除复用分支中重复的 `traceNote('research', …)`。

### 3.6 调用关联：`callId`

同一来源的多组短查询是**并行**发出的，其 `title`（`联网检索 · 来源名`）完全相同。仅按
「种类+标题+模型」配对会把并发的 running 占位丢弃、甚至把响应错配到别的调用上。故：

- `llm-trace.ts` 的 `startCall` 生成模块级递增的 `callId`（`c1`、`c2`…，进程内唯一），
  running / done / fail 三条事件都带该字段；
- 批次流（`ai-image-task.service.ts`）透传 `callId`；
- 前端 `collapseTraceCalls` **优先按 `callId` 精确配对**，无 `callId` 的历史事件退回
  「种类+标题+模型」FIFO 配对。

管理端 `types/admin.ts` 的 `AiTraceEvent` 同步增加 `parentStep?: string`、`callId?: string`。

## 4. 前端设计：嵌套竖轨时间线

`admin/src/components/ai-create/analyze-trace-stream.tsx` 重写 `buildTimeline` 与渲染。

### 4.1 建树（按发生次数）

- 每个 `step` + `running` 事件新建一个节点（不再按 `step` 合并多轮迭代）。
- `step` + `done/fail` 关闭**最近的同名开放节点**（栈内从顶向下查找），写入状态/结论/耗时。
- `llm` / `search` / `note` 挂到 `parentStep` 匹配的最近开放节点；无匹配则作为顶层叶子。
- 允许重复阶段，重复时展示序号角标（`参数校准 #2`）。

### 4.2 展开顺序

按 seq 顺序做先序遍历：父阶段行 → 其子项（子阶段缩进、调用/说明卡片）→ 下一个顶层节点。
`note` 因此就地插入，不再堆到列表末尾。

### 4.3 视觉

- 每行结构：`[竖轨列：竖线 + 状态圆点] + [内容]`。
- 子项容器 `ml-4 border-l border-border pl-3` 形成缩进层级（最深 2 层）。
- 阶段节点：圆点（running 脉冲 / done ✓ / fail !）+ 标题 + step 标识 + 耗时 + 时间戳，
  可展开收起子项。
- 调用/说明节点缩进接入既有 `TraceCallCard`。
- 无 `parentStep` 的历史事件自然退化为平铺，向后兼容。

## 5. 降级与风险

- 整理 LLM 失败 / 超时 → 回退规则摘要，与现状等价，不阻断识别。
- 多一次串行 LLM 调用：LRU 缓存 + 30s 超时兜底；同主题重复识别命中缓存不再调用。
- 缓存为进程内，多实例 / 重启不共享 → 登记 `docs/future-optimizations.md`。
- 生图链路本次不动：`image-prompt.composer.ts` 本身已由 LLM 二次整理（提示词明确要求忽略
  排版残留），不构成无用功；「生图复用同一份整理结果」登记为后续优化。

## 6. 验证

- 后端：`pnpm --filter @lumira/backend typecheck`；e2e。
- 新增单测：`traceStep` 的 `parentStep` 采集；`ResearchDigestService` 的缓存命中与降级。
- 管理端：`pnpm --filter @lumira/admin build`。
- 手工：跑一次真实风格识别，确认时间线层级与顺序为
  `趋势研究 > (查询重组, 资料整理, 联网检索…) → 文字构思模板草稿 → 姿势参考面片 → 参数校准 #1 …`。
- 完成后按 `AGENTS.md` 推送 `origin`(gitee) 与 `github` 两个远程。

## 7. 文件清单

| 文件 | 动作 |
| --- | --- |
| `backend/.../trend-research/research-brief.ts` | 新增 |
| `backend/.../trend-research/research-digest.service.ts` | 新增 |
| `backend/.../trend-research/trend-research.service.ts` | 改：注入 digest、子步骤、返回 brief |
| `backend/.../trend-research/index.ts` | 改：导出新类型/服务 |
| `backend/.../llm-trace.ts` | 改：`parentStep` + 阶段栈 |
| `backend/.../ai-analyze.service.ts` | 改：brief 渲染注入 |
| `backend/.../analyze.prompt.ts` | 改：`网络趋势参考` 文案 |
| `backend/.../ai-orchestrator.service.ts` | 改：去重复 note |
| `backend/.../ai.module.ts` | 改：注册 `ResearchDigestService` |
| `admin/src/types/admin.ts` | 改：`parentStep` |
| `admin/src/components/ai-create/analyze-trace-stream.tsx` | 重写时间线 |
| `docs/future-optimizations.md` | 追加 2 项 |