# AI 一键建模向导 UI / 交互打磨（设计）

日期：2026-09-24
模块：后台 `lumira-server/packages/admin`
状态：已确认
上游文档：
- `docs/superpowers/specs/2026-09-24-ai-create-process-trace-design.md`（实时过程溯源首版）
- `docs/superpowers/specs/2026-09-24-ai-llm-raw-trace-design.md`（LLM 原始数据实时可见）

## 1. 背景与痛点

「AI 一键建模」向导（`/dashboard/templates/ai-create`）已具备常驻过程面板、阶段时间线、逐次 LLM 原始数据卡片。本轮不再改数据链路，只打磨**输入区信息层级、过程面板提示、封面候选卡操作、步骤条与预览面板**四处交互缺陷：

1. **Step1 输入区语义重复**：`wizard.tsx` 三块输入平铺，其中「创作要求」（`creationReq`）与「文字描述 / 创作要求」（`inputText`）标签重复，用户无法分辨二者差异；「姿势个数」Select 夹在两者之间打断阅读流。底部两个按钮主次说明只靠一大段尾注小字承载。
2. **过程面板提示缺失**：`GenerateProgressPanel` Tab 切在「风格识别」时，「姿势图生成」Tab 有新事件无任何提示；收拢成窄条后只剩计数，看不出当前跑到哪。
3. **Step3 候选卡操作拥挤**：单张候选图的「左移 / 右移 / 设为参考 / 设为封面 / 删除」挤成一行 10px 文字按钮，命中区小、误触高；候选图无序号，与 Step4 剪影「按源图顺序应用」的姿势序号对不上。
4. **步骤条状态不可辨**：`s.n < step || s.n <= maxStep` 让所有「已到达」步骤渲染成同一种 `bg-primary/10`，分不出「已完成 / 当前 / 可回看」；预览面板在 <xl 断点下以长条形式占据内容上方且不可折叠。
5. **全自动无法中止**：`runAutoAll` 一旦启动只能等它跑完或失败，轮询层（`lib/ai-task.ts`）没有任何中止能力。

## 2. 目标

- Step1 形成「图 / 文 / 图文」三态直觉，重复标签消除，低频参数收进折叠区，按钮差异就近说明。
- 过程面板在任意 Tab、任意展开状态下都能看出「哪有新内容 / 现在跑到哪」。
- 封面候选卡操作可辨、可点、序号与姿势顺序对应。
- 步骤条四态可辨；预览面板可折叠；全自动可中止。

非目标：

- 不改后端接口、事件结构、提示词与生图/剪影业务逻辑。
- 中止**不做服务端真取消**：只停止前端等待，服务端任务继续跑完。
- 不做拖拽排序（候选图顺序仍用左右移动按钮调整）。
- 预览折叠状态不持久化（仅组件 state，刷新即回默认）。

## 3. 决策（已与用户确认）

- Step1 底部按钮**保持「开始识别」为主按钮（primary）**，「一键生成并上架」为次按钮（outline）；二者差异由按钮下方就近 caption 承载，不再靠尾注大段小字。
- 四块（A 输入区 / B 过程面板 / C 封面卡 / D 步骤条 + 预览 + 中止）同批实施。

## 4. 方案

### A. Step1 输入区去重与层级（`components/ai-create/wizard.tsx`）

1. 主区保留两块：
   - 「示例图（可选）」：现有 dashed 上传框 + 预览，文案不变。
   - 「文字描述（可选）」：现有 `inputText` textarea + `n/500` 计数，标题去掉冗余的「/ 创作要求」。
2. 新增「高级设置（可选）」折叠区（默认收起）：
   - 触发条为 `<button>`，左侧 CaretDown（复用面板的旋转写法），右侧显示已填项数（如「已填 1 项」）。
   - 内含「补充创作要求（可选）」（`creationReq`）与「姿势个数」（`poseCount` Select），两者沿用现有受控状态与 `busy` 禁用。
3. 主按钮仍为「开始识别」（primary），次按钮为「一键生成并上架」（outline，MagicWand）；把原尾注拆成两行 caption，分别挂在两个按钮下方：
   - 识别：「只产出草稿，后续步骤可逐步确认」
   - 全自动：「识别 → 生图作封面 → 线稿剪影 → 创建上架；任一步失败停在对应步骤转人工，已成功资产保留」

### B. 过程面板交互提示（`components/ai-create/generate-progress-panel.tsx` + wizard 传参）

1. **Tab 未读角标**：面板内以 `readCounts: Record<TabKey, number>` 记录每个 Tab 已读事件数；当某 Tab 事件数 > 已读数且非当前 Tab 时，Tab 上渲染小圆点 + 新增条数（`+N`）。切到该 Tab 时把已读数对齐到当前事件数。
2. **自动归位**：以 `userSwitchedTabRef` 标记用户是否手动切过 Tab；未手动切过时，若 `poseEvents` 首次出现且 `recogRunning` 已结束，则自动切到「姿势图生成」。用户手动切过一次后不再抢。
3. **收拢态进度文案**：新增可选 prop `statusText?: string | null`，wizard 传入（如 `进行中 · 姿势图 3/6`、`全自动 · 正在生成剪影`）；窄条右侧优先显示它，缺省回落到现有计数。
4. **点击区分离**：标题展开区与「识别详情」「关闭」之间加分隔线（`border-l` + 间距），降低误触。

### C. Step3 封面候选卡（`components/ai-create/step-cover.tsx`）

1. **序号徽标**：每张候选图左上角渲染 `#${i + 1}`；首图额外并列渲染「封面」徽标（`#1` 与「封面」并排，二者语义不同不互相替代）。
2. **操作区重排**：底部工具栏改为
   - 左侧：左移 / 右移，图标按钮，命中区放大到 28×28，禁用态沿用现有 `disabled`。
   - 右侧：「设为封面」（仅 `i !== 0` 显示）、「设为参考」、「删除」三个图标按钮，全部带 `title` tooltip；移除 10px 文字按钮。
3. **放大查看增强**：Dialog 内监听 `ArrowLeft` / `ArrowRight` 翻页、`Escape` 由 Dialog 原生关闭；标题显示 `#${viewIndex + 1} / 共 ${candidates.length}`；保留「保存到本地」。

### D. 步骤条 + 预览面板 + 全自动中止（`wizard.tsx` + `lib/ai-task.ts`）

1. **步骤条四态**（替换现有三元 className）：
   - 未到达（`s.n > maxStep`）：`bg-muted text-muted-foreground`，禁用（`busy` 时全部禁用点击，但视觉仍按四态呈现）
   - 当前（`s.n === step`）：`bg-primary text-primary-foreground`
   - 已完成（`s.n < step`）：`bg-primary/10 text-primary` + Check 图标
   - 可回看（`step < s.n <= maxStep`）：描边（`border border-border`）+ 常规字色，可点
   连接线：已完成段 `text-primary/40`，其余 `text-muted-foreground/50`。
2. **预览面板折叠**：新增 `previewCollapsed` state；xl 右栏与 <xl 内联都提供折叠开关。默认值：xl 展开、<xl 收起。收起时折叠态只留一行开关条（带「实时预览」标题）。
3. **全自动中止**：
   - `lib/ai-task.ts`：`pollAiAnalyzeTask` / `generateAiPoseImages` / `generateAiSilhouettes` 的 options 增加 `signal?: AbortSignal`；在每次 `sleep` 前后与轮询循环入口检查 `signal?.aborted`，命中则抛 `new AiTaskPollError('已中止')`。既有调用方不传 `signal`，行为不变。
   - `wizard.tsx`：`abortRef = useRef<AbortController | null>(null)`；`runAutoAll` 开始时新建 controller 并把 `signal` 透传给上述三个调用；进度卡右侧渲染「中止」按钮 → `abortRef.current?.abort()`。
   - 中止后：`autoState` 置为 `{ running: false, stage, error: '已中止' }`，停在当前步骤并保留已生成资产（草稿 / 候选图 / 剪影），提示文案「已中止，可人工继续或调整后重试」。

## 5. 数据流与接口

无新增后端接口。前端新增/变更：

- `GenerateProgressPanel` 新增 props：`statusText?: string | null`（其余不变）。
- `lib/ai-task.ts` 三个函数新增可选 `signal`；中止以既有 `AiTaskPollError` 抛出，文案固定为「已中止」。
- `wizard.tsx` 新增 state/ref：`previewCollapsed`、`abortRef`。

## 6. 错误处理

- 中止与超时/上游失败共用 `AiTaskPollError`，wizard 现有 `catch` 分支已能透出错误并停在当前阶段；中止文案直接落到提示区，不额外弹 toast（避免与既有 `toast` 重复打扰）。
- 面板未读角标、自动归位均为纯展示逻辑，不影响事件累积与识别/生图主流程；`statusText` 缺省时回落旧行为。

## 7. 验收标准

- Step1：主区仅「示例图」「文字描述」两块，无重复「创作要求」；「补充创作要求」「姿势个数」在默认收起的「高级设置」内；「开始识别」为 primary 且其下方 caption 说明与「一键生成并上架」的差异。
- 过程面板：非当前 Tab 有新事件时出现 `+N` 角标，切过去即清零；用户未手动切过 Tab 时生图开始会自动归位到「姿势图生成」；收拢态显示阶段进度文案；「识别详情」与标题区间有分隔线。
- Step3：每张候选图显示 `#序号`，首图并列「封面」徽标；操作全部为图标按钮且命中区不小于 28×28；放大查看可用 ←/→ 翻页、Esc 关闭，标题显示 `#序号 / 共 N`。
- 步骤条：未到达/当前/已完成/可回看四种视觉可区分；预览面板在 xl 与 <xl 下均可折叠。
- 全自动：点「中止」后停在当前步骤并提示「已中止，可人工继续或调整后重试」，已生成的草稿/候选图/剪影保留。
- `pnpm --filter @lumira/admin build` 通过。

## 8. 风险

- 中止只停前端等待，服务端生图/剪影任务仍会跑完并占用额度；若需真取消，需后端补 `cancel` 接口（本轮不做，必要时登记到 `docs/future-optimizations.md`）。
- 自动归位依赖 `poseEvents` 首次出现的时机；仅对「未手动切过 Tab」的用户生效，已手动切换者不受影响。