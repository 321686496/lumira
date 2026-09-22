# AI 识别结果详情弹窗：过程 trace + 原始结构化数据 + 参考 URL（数据分析）

## Context（背景）

上一轮已把「AI 开始识别」改成异步任务 + 前端轮询，识别完成后前端拿到 `{ draft, warnings }`（研究管线开启时还隐含 trace，但后端没把它透出到任务结果，前端也无入口查看全程）。

现在运营要做**数据分析**，希望识别完成后有一个弹窗能查看三样东西：
1. **整个识别过程** —— Agentic 研究管线逐步执行的 trace（研究/识别/姿势面片/评分等 step）。
2. **原始 AI 生成的结构性数据** —— LLM 直接吐出的原始 JSON（`extractJson` 后、`normalizeDraft` 之前那份 `json`），便于对比归一化后的 draft。
3. **AI 参考的 URL 列表** —— 趋势研究阶段命中的来源（`ResearchItem[]` 已含 `url/title/source`，bing/vendor 适配器都填充 url）。

现状缺口：`AiAnalyzeService.analyze` 返回 `{draft,warnings}`（orchestrator 分支返回 `{draft,warnings,trace}`，但**没有 raw、没有 research 列表**）；异步任务 `AiAnalyzeTask.result` 只存 `{draft,warnings}`；前端 wizard 只消费 `draft/warnings`，无详情入口。

目标：端到端把 `trace / raw / research(URL)` 从后端一路透到前端，识别完成后以弹窗（Tab）展示这三部分，供数据分析。

---

## Backend 改动

### 1. `ai-orchestrator.service.ts` —— 让结果带上研究参考
- `OrchestratorResult` 增加字段 `research: ResearchItem[]`（`ResearchItem` 已 import）。
- `run(...)` 结尾 `return { draft, warnings, trace, research }`（`research` 变量已在本方法内维护，默认 `[]`）。
- 仅新增字段，不破坏既有字段（golden-set / 其它调用方只消费 draft/warnings/trace，安全）。

### 2. `ai-analyze.service.ts` —— 统一返回 `{ draft, warnings, trace, raw, research }`
文件里 `analyze()` 已持有 `json`（extractJson 原始输出，位于 L121）与 `normalized`。
- import `type ResearchItem`（仅类型）。
- 返回类型声明从 `{ draft; warnings }` 扩为 `{ draft; warnings; trace: AiAnalyzeTraceEntry[]; raw: Record<string, unknown>; research: ResearchItem[] }`（`AiAnalyzeTraceEntry` 结构照搬 orchestrator 的 trace 项，或直接复用其类型导出）。
- orchestrator 分支（L132-141）：`const r = await this.orchestrator.run(...)` → `return { draft: r.draft, warnings: r.warnings, trace: r.trace, raw: json, research: r.research ?? [] }`。
- 非 orchestrator 分支（L143）：`return { ...normalized, trace: [], raw: json, research: [] }`。

### 3. `ai-analyze-task.service.ts` —— 任务结果存全量
`AiAnalyzeTask.result` 扩为 `{ draft; warnings; trace; raw; research }`；`run()` 里把 analyze 返回的 `trace/raw/research` 一并存入。

### 4. `ai-templates.controller.ts` —— GET 状态多透出字段
`GET ai-analyze/tasks/:taskId` 返回体追加 `trace`、`raw`、`research`（同 draft 一样 `?? null`/`?? []` 兜底）。

---

## Admin 改动

### 5. `types/admin.ts`
- 新增 `AiResearchRef { source: string; title: string; url?: string; snippet?: string }`。
- `AiAnalyzeStatusResult` 增加 `trace?: AiAnalyzeTraceEntry[]`（已有）、`raw?: Record<string, unknown>`、`research?: AiResearchRef[]`。

### 6. `wizard.tsx` —— 存全量结果 + 挂详情入口
- 手动 `handleAnalyze` 与全自动 `runAutoAll` 的识别成功分支，除现有 `setDraft/setWarnings/setTrace` 外，把完整 `result`（含 `raw`、`research`）存到组件级 state（如 `analyzeDetail`）。
- 在识别成功后（Step2 区域）增加一个按钮「查看识别详情/过程」，打开详情弹窗（条件渲染：`analyzeDetail` 存在即显示；研究未开启时 trace/research 为空，弹窗内友好降级）。

### 7. 新增 `components/ai-create/analyze-result-dialog.tsx`
复用项目已有的 shadcn `Dialog` + `Tabs`（`@/components/ui/dialog`、`@/components/ui/tabs`），三个 Tab：
- **识别过程**：把 `trace` 渲染成时间线（step + tool + resultBrief + score），每步一个条目；空则提示「研究管线未开启，本次为单次识别」。
- **原始结构数据**：`raw` 与归一化 `draft` 用 `<pre>` 分别 `JSON.stringify(…, null, 2)` 展示，便于对比（两个 code block 或左右两栏）。
- **参考来源（URL）**：`research` 列表，每项展示 `title`（可点击外链 `url`）+ `source` 标签 + 摘要；过滤无 url 项目，并给出总数；空则提示「本次未启用趋势研究」。

---

## 关键决策

| 决策点 | 选择 | 理由 |
|---|---|---|
| raw 取哪份 | `extractJson` 后、`normalizeDraft` 前的 `json` | 正是「LLM 原始结构化输出」，与归一化 draft 形成对照 |
| research 从哪透出 | orchestrator 结果新增 `research` 字段（`run` 内已持有 `research` 变量） | 研究在 orchestrator 内执行，只能由此带回；不重复研究 |
| 弹窗实现 | 新 Dialog 组件 + shadcn Dialog/Tabs | 复用现有 UI 体系，三块内容用 Tab 分开 |
| 数据体量 | research 默认 ≤ 若干项（limitPerSource 5）；raw 为单次 JSON | 可接受，直接存内存任务/React state |

## 验证

1. 后端 `cd lumira-server/packages/backend && pnpm run build`（exit 0）；`npx jest src/modules/ai/ai-analyze.service.spec.ts src/modules/ai/ai-orchestrator.service.spec.ts` 无回退（新增字段不影响既有断言）。
2. admin `cd lumira-server/packages/admin && pnpm run build`（next build，类型+lint）。
3. 手动（本地起后端，配置研究管线开启 + 关闭两种）：
   - 开启：识别完成后弹窗三 Tab 均在——过程时间线有 step、原始数据为 LLM 原始 JSON、参考列表有 title+url 可点。
   - 关闭：弹窗正常打开，过程/参考 Tab 显示"未开启"降级文案，原始数据 Tab 仍有内容。
4. 按 AGENTS.md 后端/后台改动完成即 commit + push gitee(origin) + github 双远程，触发后端部署 CI。