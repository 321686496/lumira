# AI 一键建模向导 UI / 交互打磨 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 打磨后台「AI 一键建模」向导的四处交互缺陷 —— Step1 输入区去重与层级、过程面板提示、Step3 封面候选卡操作、步骤条 + 预览面板 + 全自动中止。

**Architecture:** 纯前端改动，集中在 `lumira-server/packages/admin`。`lib/ai-task.ts` 为三个长轮询函数增加 `AbortSignal` 支持；`components/ai-create/` 下的 `wizard.tsx`、`generate-progress-panel.tsx`、`step-cover.tsx` 三个文件的展示层与交互层调整。后端接口、事件结构、提示词均不动。

**Tech Stack:** Next.js 14 (App Router) + React 18 + TypeScript + Tailwind + shadcn/ui + @phosphor-icons/react。

**设计文档：** `docs/superpowers/specs/2026-09-24-ai-create-wizard-ui-polish-design.md`

## Global Constraints

- 不改后端：`lumira-server/packages/backend/**` 一律不动。
- 不改后端接口与事件结构：`AiTraceEvent` / `AiBatchImageTraceEvent` / `AiAnalyzeStatusResult` 等类型字段不变。
- 不改识别 / 生图 / 剪影业务逻辑与提示词。
- 中止**不做服务端真取消**：只停止前端等待，服务端任务继续跑完。
- 不做候选图拖拽排序；预览折叠状态不持久化。
- `pnpm --filter @lumira/admin build` 必须通过（本包 `test` 脚本存在但**无 vitest 配置与既有用例**，因此本计划的验证关口是 build + 人工走查，不新增测试基建）。
- 每次改动后台代码后，按 `AGENTS.md` commit 并推送双远程：`git push origin master` + `git push github master`。
- 文案用中文；不新增 emoji。

---

### Task 1: 轮询层支持中止（`lib/ai-task.ts`）

**Files:**
- Modify: `lumira-server/packages/admin/src/lib/ai-task.ts`

**Interfaces:**
- Consumes: 无
- Produces:
  - `pollAiAnalyzeTask(taskId: string, options: AiTaskPollOptions & { onEvents?: (events: AiTraceEvent[]) => void; signal?: AbortSignal }, onTick?)`（新增 `signal`，中止时 reject `AiTaskPollError('已中止')`）
  - `generateAiPoseImages(options: { ...原有字段; signal?: AbortSignal })`
  - `generateAiSilhouettes(options: { ...原有字段; signal?: AbortSignal })`

- [ ] **Step 1: 新增中止检查辅助函数**

在 `lib/ai-task.ts` 的 `sleep` 函数之后插入：

```ts
/** 中止信号已触发时抛出统一的「已中止」错误（与超时 / 上游失败共用 AiTaskPollError） */
function throwIfAborted(signal?: AbortSignal): void {
  if (signal?.aborted) throw new AiTaskPollError('已中止');
}
```

- [ ] **Step 2: `generateAiPoseImages` 接入 signal**

把函数签名与解构改为（仅新增 `signal` 一处）：

```ts
export function generateAiPoseImages(options: {
  draft: Record<string, unknown>;
  referenceFile?: File | null;
  extraPrompt?: string | null;
  /** 识别阶段的网络趋势研究结果（透传给后端生图提示词组织器，与草稿同源保持一致） */
  research?: AiResearchRef[] | null;
  /** 中止信号：命中后抛 AiTaskPollError('已中止')，仅供前端停止等待（不取消服务端任务） */
  signal?: AbortSignal;
  onResult?: (result: AiTaskFileResult) => void;
  onProgress?: (progress: AiPoseProgress) => void;
  /** 逐张实时过程事件（按 seq 增量累积；用于可溯源的姿势图过程展示） */
  onEvents?: (events: AiBatchImageTraceEvent[]) => void;
}): Promise<AiTaskFileResult[]> {
  const { draft, referenceFile, extraPrompt, research, signal, onResult, onProgress, onEvents } = options;
  return (async () => {
    throwIfAborted(signal);
```

并把该函数内的轮询循环开头改为（`while (Date.now() < deadline) {` 之后首行插入）：

```ts
    while (Date.now() < deadline) {
      throwIfAborted(signal);
      const res = await aiGenerateImageBatchStatusAction(batchId, since);
```

- [ ] **Step 3: `generateAiSilhouettes` 接入 signal**

把签名与解构改为：

```ts
export function generateAiSilhouettes(options: {
  images: File[];
  mode: 'sketch' | 'solid';
  crop: boolean;
  engine: 'ai' | 'local';
  /** 中止信号：命中后每张任务抛出「已中止」，聚合结果按 error 返回 */
  signal?: AbortSignal;
  onCompleted?: (completed: number) => void;
}): Promise<AiTaskFileResult[]> {
  const { images, mode, crop, engine, signal, onCompleted } = options;
  const generated = new Array<File | undefined>(images.length).fill(undefined);
  const publish = () => onCompleted?.(generated.filter(Boolean).length);

  return (async () => Promise.all(images.map(async (image, index) => {
    try {
      throwIfAborted(signal);
      const source = await compressImage(image, { maxDim: 640, quality: 0.6 });
```

- [ ] **Step 4: `pollAiAnalyzeTask` 接入 signal**

把签名、解构与循环开头改为：

```ts
export function pollAiAnalyzeTask(
  taskId: string,
  options: AiTaskPollOptions & {
    onEvents?: (events: AiTraceEvent[]) => void;
    /** 中止信号：命中后 reject AiTaskPollError('已中止') */
    signal?: AbortSignal;
  } = {},
  onTick?: (status: AiAnalyzeStatusResult['status']) => void,
): Promise<AiAnalyzeStatusResult> {
  const { intervalMs = DEFAULT_INTERVAL_MS, timeoutMs = DEFAULT_TIMEOUT_MS, onEvents, signal } = options;
```

并把 `return (async () => {` 之后的循环开头改为：

```ts
  return (async () => {
    while (Date.now() < deadline) {
      throwIfAborted(signal);
      const res = await aiAnalyzeStatusAction(taskId, since);
```

- [ ] **Step 5: 构建确认通过**

Run: `pnpm --filter @lumira/admin build`（工作目录 `lumira-server/`）
Expected: 编译通过，无 TS 报错。

- [ ] **Step 6: 提交并推送**

```powershell
git add lumira-server/packages/admin/src/lib/ai-task.ts
git commit -m "feat(admin): ai-task 轮询层支持 AbortSignal，中止抛「已中止」"
git push origin master
git push github master
```

---

### Task 2: Step1 输入区去重与层级（`components/ai-create/wizard.tsx`）

**Files:**
- Modify: `lumira-server/packages/admin/src/components/ai-create/wizard.tsx`

**Interfaces:**
- Consumes: 无（Task 1 的 `signal` 本任务不用）
- Produces: 无新导出（组件内部状态 `advancedOpen` / `advancedFilledCount`）

- [ ] **Step 1: 补 icon 与状态**

1) import 区新增 `CaretDown`（与 `Check` 同一段）：

```tsx
import { CaretDown } from '@phosphor-icons/react/dist/csr/CaretDown';
```

2) 在 `const [poseCount, setPoseCount] = useState('auto');` 之后新增：

```tsx
  /** Step1「高级设置」折叠区是否展开（低频参数：补充创作要求 / 姿势个数） */
  const [advancedOpen, setAdvancedOpen] = useState(false);
```

3) 在 `const hasInput = ...` 之后新增：

```tsx
  /** 高级设置已填项数（用于折叠态提示） */
  const advancedFilledCount = (creationReq.trim() !== '' ? 1 : 0) + (poseCount !== 'auto' ? 1 : 0);
```

- [ ] **Step 2: 用「高级设置」折叠区替换原「创作要求 + 姿势个数」两块**

把 Step1 卡片内从 `{/* 附加输入：影响 AI 识别草稿（识别与全自动均生效） */}` 开始、到 `姿势个数` 那一段 `<p className="text-xs text-muted-foreground">…在 1~6 个范围内决定姿势数量</p></div>` 结束的整段 JSX，替换为：

```tsx
              {/* 附加输入：低频参数收进折叠区，避免与主文字描述语义重复 */}
              <div className="rounded-lg border border-border">
                <button
                  type="button"
                  onClick={() => setAdvancedOpen((o) => !o)}
                  className="flex w-full items-center gap-2 px-4 py-3 text-left"
                >
                  <span className="text-sm font-medium text-foreground">高级设置（可选）</span>
                  {advancedFilledCount > 0 && (
                    <span className="rounded bg-primary/10 px-1.5 py-0.5 text-[10px] text-primary">
                      已填 {advancedFilledCount} 项
                    </span>
                  )}
                  <CaretDown
                    size={14}
                    className={cn('ml-auto text-muted-foreground transition-transform', advancedOpen && 'rotate-180')}
                  />
                </button>
                {advancedOpen && (
                  <div className="space-y-4 border-t border-border p-4">
                    <div className="space-y-2">
                      <Label htmlFor="ai-creation-req">补充创作要求（可选）</Label>
                      <Textarea
                        id="ai-creation-req"
                        value={creationReq}
                        onChange={(e) => setCreationReq(e.target.value)}
                        placeholder="对 AI 的额外创作指令，如「偏胶片感」「避开正午顶光」"
                        rows={3}
                        disabled={busy}
                      />
                    </div>

                    <div className="space-y-2 md:max-w-xs">
                      <Label>姿势个数</Label>
                      <Select value={poseCount} onValueChange={setPoseCount} disabled={busy}>
                        <SelectTrigger className="w-full">
                          <SelectValue placeholder="AI 自动判断" />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="auto">AI 自动判断</SelectItem>
                          {[1, 2, 3, 4, 5, 6].map((n) => (
                            <SelectItem key={n} value={String(n)}>
                              固定 {n} 个
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                      <p className="text-xs text-muted-foreground">
                        选「AI 自动判断」时，将结合文字描述 / 补充创作要求（含示例图中可见的文字要求）在 1~6 个范围内决定姿势数量
                      </p>
                    </div>
                  </div>
                )}
              </div>
```

- [ ] **Step 3: 主文字描述块去掉重复标签**

把该块的 Label 文案与说明改为：

```tsx
                <Label htmlFor="ai-input-text" className="text-sm font-medium text-foreground">
                  文字描述（可选）
                </Label>
                <p className="mt-0.5 text-xs text-muted-foreground">
                  无示例图时可仅用文字描述；也可与示例图同用，AI 将向你的要求倾斜
                </p>
```

- [ ] **Step 4: 按钮主次 + 就近 caption**

把原按钮行与紧随其后的整段尾注 `<p className="text-xs text-muted-foreground">全自动：识别 → …</p>`，替换为：

```tsx
              <div className="flex flex-wrap items-start gap-4">
                <div className="space-y-1">
                  <Button disabled={!hasInput || busy} onClick={handleAnalyze}>
                    {analyzing ? '识别中…' : '开始识别'}
                  </Button>
                  <p className="text-xs text-muted-foreground">只产出草稿，后续步骤可逐步确认</p>
                </div>
                <div className="space-y-1">
                  <Button variant="outline" disabled={!hasInput || busy} onClick={runAutoAll}>
                    <MagicWand size={14} className="mr-1" /> 一键生成并上架
                  </Button>
                  <p className="max-w-xs text-xs text-muted-foreground">
                    识别 → 生图作封面 → 线稿剪影 → 创建上架；任一步失败停在对应步骤转人工，已成功资产保留
                  </p>
                </div>
              </div>
```

- [ ] **Step 5: 构建确认通过**

Run: `pnpm --filter @lumira/admin build`（工作目录 `lumira-server/`）
Expected: 编译通过。

- [ ] **Step 6: 提交并推送**

```powershell
git add lumira-server/packages/admin/src/components/ai-create/wizard.tsx
git commit -m "feat(admin): Step1 输入区去重——低频参数收进高级设置折叠区，按钮差异就近说明"
git push origin master
git push github master
```

---

### Task 3: 步骤条四态 + 预览面板折叠（`components/ai-create/wizard.tsx`）

**Files:**
- Modify: `lumira-server/packages/admin/src/components/ai-create/wizard.tsx`

**Interfaces:**
- Consumes: 无
- Produces: 无新导出（组件内部状态 `previewCollapsed`）

- [ ] **Step 1: 预览折叠状态 + 首次断点测量设默认值**

1) 在 `const [isXl, setIsXl] = useState(true);` 之后新增：

```tsx
  /** 预览面板是否收起；首次断点测量时按 xl 与否设默认值（<xl 默认收起，xl 默认展开） */
  const [previewCollapsed, setPreviewCollapsed] = useState(false);
  const previewInitRef = useRef(false);
```

2) 把现有断点 effect 整体替换为：

```tsx
  useEffect(() => {
    const mq = window.matchMedia('(min-width: 1280px)');
    const update = () => {
      setIsXl(mq.matches);
      if (!previewInitRef.current) {
        previewInitRef.current = true;
        setPreviewCollapsed(!mq.matches);
      }
    };
    update();
    mq.addEventListener('change', update);
    return () => mq.removeEventListener('change', update);
  }, []);
```

- [ ] **Step 2: 预览面板加折叠开关（宿主保持挂载）**

把 `const previewPanel = (…);` 整体替换为：

```tsx
  const previewPanel = (
    <div className="rounded-lg border border-border bg-card p-4">
      <div className="mb-3 flex items-center justify-between gap-2">
        <h3 className="text-sm font-medium text-foreground">实时预览</h3>
        <button
          type="button"
          onClick={() => setPreviewCollapsed((o) => !o)}
          className="text-xs text-muted-foreground hover:text-foreground"
        >
          {previewCollapsed ? '展开' : '收起'}
        </button>
      </div>
      {/* 折叠用 hidden 而非卸载，保住 TemplateForm 的 portal 宿主 */}
      <div className={cn(previewCollapsed && 'hidden')}>
        {!formActivated ? (
          <div className="flex h-[480px] items-center justify-center rounded-md border border-dashed border-border px-4 text-center text-sm text-muted-foreground">
            识别完成后此处实时预览参数、姿势与封面效果
          </div>
        ) : (
          <div ref={setPreviewHost} />
        )}
      </div>
      {previewCollapsed && (
        <div className="rounded-md border border-dashed border-border px-4 py-2 text-center text-xs text-muted-foreground">
          预览已收起
        </div>
      )}
    </div>
  );
```

- [ ] **Step 3: 步骤条改四态**

把顶部 stepper 的 `<div className="flex items-center gap-2 overflow-x-auto pb-1">…</div>` 整块替换为：

```tsx
        <div className="flex items-center gap-2 overflow-x-auto pb-1">
          {WIZARD_STEPS.map((s, i) => {
            const reached = s.n <= maxStep;
            const isCurrent = s.n === step;
            const isDone = s.n < step;
            return (
              <div key={s.n} className="flex items-center gap-2 shrink-0">
                <button
                  type="button"
                  disabled={busy || !reached}
                  onClick={() => setStep(s.n)}
                  className={cn(
                    'flex items-center gap-2 rounded-md px-3 py-1.5 text-sm transition-colors',
                    isCurrent
                      ? 'bg-primary text-primary-foreground'
                      : isDone
                        ? 'bg-primary/10 text-primary'
                        : reached
                          ? 'border border-border text-foreground'
                          : 'bg-muted text-muted-foreground',
                  )}
                >
                  <span className="flex h-5 w-5 items-center justify-center rounded-full border border-current text-[10px]">
                    {isDone ? <Check size={10} /> : s.n}
                  </span>
                  <span className="font-medium">{s.title}</span>
                </button>
                {i < WIZARD_STEPS.length - 1 && (
                  <span className={cn(isDone ? 'text-primary/40' : 'text-muted-foreground/50')}>→</span>
                )}
              </div>
            );
          })}
        </div>
```

- [ ] **Step 4: 构建确认通过**

Run: `pnpm --filter @lumira/admin build`（工作目录 `lumira-server/`）
Expected: 编译通过。

- [ ] **Step 5: 提交并推送**

```powershell
git add lumira-server/packages/admin/src/components/ai-create/wizard.tsx
git commit -m "feat(admin): 步骤条四态可辨 + 预览面板可折叠"
git push origin master
git push github master
```

---

### Task 4: 全自动中止按钮（`components/ai-create/wizard.tsx`）

**Files:**
- Modify: `lumira-server/packages/admin/src/components/ai-create/wizard.tsx`

**Interfaces:**
- Consumes: Task 1 的 `signal?: AbortSignal`（`pollAiAnalyzeTask` / `generateAiPoseImages` / `generateAiSilhouettes`）
- Produces: 无新导出

- [ ] **Step 1: 新增 abortRef**

在 `const stampRef = useRef(0);` 之后新增：

```tsx
  /** 全自动流程的中止控制器（每次 runAutoAll 新建；结束/中止后清空） */
  const abortRef = useRef<AbortController | null>(null);
```

- [ ] **Step 2: runAutoAll 透传 signal**

把 `runAutoAll` 开头改为：

```tsx
  const runAutoAll = async () => {
    if (!hasInput) return;
    setErrorText(null);
    const controller = new AbortController();
    abortRef.current = controller;
    const { signal } = controller;
    let stage: AutoStage = 'analyzing';
    setTraceEvents([]);
    setPoseTraceEvents([]);
    setPoseTraceRunning(false);
    setProgressPanelHidden(false);
    setAutoState({ running: true, stage });
```

把该函数内三处调用分别加上 `signal`：

```tsx
      const analyzeResult = await pollAiAnalyzeTask(started.taskId, { onEvents: setTraceEvents, signal });
```

```tsx
      const poseResults = await generateAiPoseImages({
        draft: draftLocal,
        referenceFile: poseReferenceFile ?? exampleFile,
        research: analyzeResult.research,
        signal,
        onProgress: setPoseProgress,
        onResult: appendGeneratedPose,
        onEvents: setPoseTraceEvents,
      });
```

```tsx
      const silResults = await generateAiSilhouettes({
        images: poseFiles,
        mode: 'sketch',
        crop: true,
        engine: aiSilhouetteAvailable ? 'ai' : 'local',
        signal,
      });
```

- [ ] **Step 3: 中止时不弹 toast，停在当前步骤**

把 `runAutoAll` 的 catch 块替换为：

```tsx
    } catch (e) {
      // 意外异常（网络中断 / 框架层错误）或用户中止：停在当前阶段，错误透出，不再永久卡「进行中」
      const msg = e instanceof Error ? e.message : String(e);
      const aborted = msg === '已中止';
      setAutoState({ running: false, stage, error: aborted ? '已中止，可人工继续或调整后重试' : msg });
      if (!aborted) {
        toast({
          variant: 'destructive',
          title: `全自动在「${AUTO_STAGE_TEXT[stage]}」阶段异常`,
          description: msg,
        });
      }
    } finally {
      abortRef.current = null;
    }
```

- [ ] **Step 4: 进度卡加「中止」按钮**

把 `{autoState?.running && (` 那段进度卡里的标题行替换为：

```tsx
            <div className="flex items-center gap-2 text-sm font-medium text-primary">
              <MagicWand size={16} /> 全自动进行中：{AUTO_STAGE_TEXT[autoState.stage]}
              {autoState.stage === 'generating-image' && poseProgress
                ? `（第 ${poseProgress.current}/${poseProgress.total} 张）`
                : ''}
              <button
                type="button"
                onClick={() => abortRef.current?.abort()}
                className="ml-auto shrink-0 rounded border border-primary/40 px-2 py-0.5 text-xs text-primary transition-colors hover:bg-primary/10"
              >
                中止
              </button>
            </div>
```

- [ ] **Step 5: 构建确认通过**

Run: `pnpm --filter @lumira/admin build`（工作目录 `lumira-server/`）
Expected: 编译通过。

- [ ] **Step 6: 提交并推送**

```powershell
git add lumira-server/packages/admin/src/components/ai-create/wizard.tsx
git commit -m "feat(admin): 全自动支持中止——轮询透传 AbortSignal，停在当前步骤保留资产"
git push origin master
git push github master
```

---

### Task 5: 过程面板未读角标 / 自动归位 / 收拢态进度（`generate-progress-panel.tsx` + wizard 传参）

**Files:**
- Modify: `lumira-server/packages/admin/src/components/ai-create/generate-progress-panel.tsx`
- Modify: `lumira-server/packages/admin/src/components/ai-create/wizard.tsx`

**Interfaces:**
- Consumes: 无
- Produces: `GenerateProgressPanelProps` 新增可选 prop `statusText?: string | null`

- [ ] **Step 1: 组件新增 statusText prop**

把 props 接口与解构改为：

```tsx
interface GenerateProgressPanelProps {
  recogEvents: AiTraceEvent[];
  recogRunning: boolean;
  poseEvents: AiBatchImageTraceEvent[];
  poseRunning: boolean;
  /** 收拢态优先展示的进度文案（如「进行中 · 姿势图 3/6」）；缺省回落 Tab 计数 */
  statusText?: string | null;
  /** 点「识别详情」时触发（打开原有数据分析弹窗） */
  onOpenDetail: () => void;
  /** 手动关闭整个面板（仅隐藏本次展示，不清空已采集过程） */
  onClose: () => void;
}

export function GenerateProgressPanel({
  recogEvents,
  recogRunning,
  poseEvents,
  poseRunning,
  statusText,
  onOpenDetail,
  onClose,
}: GenerateProgressPanelProps) {
```

- [ ] **Step 2: 未读角标 + 自动归位状态**

在 `const wasRunningRef = useRef(false);` 之后新增：

```tsx
  /** 各 Tab 已读事件数（用于未读角标） */
  const [readCounts, setReadCounts] = useState<Record<TabKey, number>>({ recog: 0, pose: 0 });
  /** 用户是否手动切过 Tab：切过之后不再自动归位 */
  const userSwitchedTabRef = useRef(false);
  const autoSwitchedRef = useRef(false);
```

在 `if (!anyRunning && !anyContent) return null;` 之前插入：

```tsx
  const totals: Record<TabKey, number> = { recog: recogEvents.length, pose: poseEvents.length };

  // 当前 Tab 的已读数跟随事件数（停留或切到该 Tab 都视为已读）
  useEffect(() => {
    setReadCounts((prev) => (prev[tab] === totals[tab] ? prev : { ...prev, [tab]: totals[tab] }));
  }, [tab, totals.recog, totals.pose]);

  // 用户未手动切过 Tab 时，生图事件首次出现且识别已结束 → 自动归位到「姿势图生成」
  useEffect(() => {
    if (userSwitchedTabRef.current || autoSwitchedRef.current) return;
    if (poseEvents.length > 0 && !recogRunning) {
      autoSwitchedRef.current = true;
      setTab('pose');
    }
  }, [poseEvents.length, recogRunning]);

  /** 非当前 Tab 的未读条数 */
  const unread = (t: TabKey) => (t === tab ? 0 : Math.max(0, totals[t] - readCounts[t]));
```

- [ ] **Step 3: 收拢态文案 + 分隔线**

把标题栏里这段计数 span 替换为：

```tsx
          <span className="shrink-0 text-xs text-muted-foreground">
            {statusText ?? (tab === 'recog' ? `识别 ${recogCount} 项` : `姿势图 ${poseCount} 张`)}
          </span>
```

把「识别详情」按钮前插入分隔线，即：

```tsx
        <span className="h-4 w-px shrink-0 bg-primary/20" />
        <button type="button" onClick={onOpenDetail} className="shrink-0 rounded px-1.5 py-0.5 text-xs text-primary underline-offset-2 hover:underline">
          识别详情
        </button>
```

- [ ] **Step 4: Tab 未读角标 + 手动切换标记**

把 Tab 渲染改为：

```tsx
            {([
              { key: 'recog', label: '风格识别' },
              { key: 'pose', label: '姿势图生成' },
            ] as const).map((t) => (
              <button
                key={t.key}
                type="button"
                onClick={() => {
                  userSwitchedTabRef.current = true;
                  setTab(t.key);
                }}
                className={cn(
                  'rounded px-2.5 py-1 text-xs font-medium transition-colors',
                  tab === t.key ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:text-foreground',
                )}
              >
                {t.label}
                {unread(t.key) > 0 && (
                  <span className="ml-1.5 rounded-full bg-primary px-1.5 py-0.5 text-[10px] text-primary-foreground">
                    +{unread(t.key)}
                  </span>
                )}
              </button>
            ))}
```

- [ ] **Step 5: wizard 传入 statusText**

在 wizard 里 `const stageIndex = autoState ? AUTO_STAGES.indexOf(autoState.stage) : -1;` 之后新增：

```tsx
  /** 面板收拢态展示的进度文案 */
  const progressStatusText = analyzing
    ? '正在识别…'
    : autoState?.running
      ? `进行中 · ${AUTO_STAGE_TEXT[autoState.stage]}${
          autoState.stage === 'generating-image' && poseProgress
            ? ` ${poseProgress.current}/${poseProgress.total}`
            : ''
        }`
      : null;
```

并在 `<GenerateProgressPanel` 的 props 中、`poseRunning={...}` 之后插入：

```tsx
            statusText={progressStatusText}
```

- [ ] **Step 6: 构建确认通过**

Run: `pnpm --filter @lumira/admin build`（工作目录 `lumira-server/`）
Expected: 编译通过。

- [ ] **Step 7: 提交并推送**

```powershell
git add lumira-server/packages/admin/src/components/ai-create/generate-progress-panel.tsx lumira-server/packages/admin/src/components/ai-create/wizard.tsx
git commit -m "feat(admin): 过程面板 Tab 未读角标、自动归位与收拢态进度文案"
git push origin master
git push github master
```

---

### Task 6: Step3 封面候选卡序号与图标操作区（`step-cover.tsx`）

**Files:**
- Modify: `lumira-server/packages/admin/src/components/ai-create/step-cover.tsx`

**Interfaces:**
- Consumes: 无
- Produces: 无新导出

- [ ] **Step 1: 补 import 与图标**

1) 把顶部 React import 行替换为：

```tsx
import type { Dispatch, ReactNode, SetStateAction } from 'react';
import { useEffect, useRef, useState } from 'react';
```

2) 在 `import { X } from '@phosphor-icons/react/dist/csr/X';` 之后新增：

```tsx
import { ArrowUp } from '@phosphor-icons/react/dist/csr/ArrowUp';
import { Target } from '@phosphor-icons/react/dist/csr/Target';
```

- [ ] **Step 2: 新增本地 IconButton 组件**

在 `export interface CoverCandidate { … }` 之后插入：

```tsx
/** 候选图操作区图标按钮：28×28 命中区 + title/aria-label 提示 */
function IconButton({
  label,
  disabled,
  danger,
  onClick,
  children,
}: {
  label: string;
  disabled?: boolean;
  danger?: boolean;
  onClick: () => void;
  children: ReactNode;
}) {
  return (
    <button
      type="button"
      title={label}
      aria-label={label}
      disabled={disabled}
      onClick={onClick}
      className={cn(
        'flex h-7 w-7 items-center justify-center rounded text-muted-foreground transition-colors hover:bg-muted hover:text-foreground disabled:opacity-30 disabled:hover:bg-transparent',
        danger && 'hover:text-destructive',
      )}
    >
      {children}
    </button>
  );
}
```

- [ ] **Step 3: 放大查看支持 ←/→ 翻页**

在 `const viewing = viewIndex != null ? candidates[viewIndex] : null;` 之后插入：

```tsx
  // 放大查看：←/→ 翻页（Esc 由 Dialog 原生处理）
  useEffect(() => {
    if (viewIndex == null) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'ArrowLeft') {
        setViewIndex((v) => (v == null ? v : Math.max(0, v - 1)));
      } else if (e.key === 'ArrowRight') {
        setViewIndex((v) => (v == null ? v : Math.min(candidates.length - 1, v + 1)));
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [viewIndex, candidates.length]);
```

- [ ] **Step 4: 候选图序号徽标 + 图标操作区**

把候选图循环里 `<div className="relative">…</div>` 与紧随其后的 `<div className="flex items-center justify-between border-t border-border bg-card px-1 py-1">…</div>` 两块，替换为：

```tsx
                <div className="relative">
                  <span className="absolute left-2 top-2 z-10 flex items-center gap-1">
                    <span className="rounded bg-background/80 px-1.5 py-0.5 text-[10px] font-medium text-foreground">
                      #{i + 1}
                    </span>
                    {i === 0 && (
                      <span className="rounded bg-primary px-1.5 py-0.5 text-[10px] font-medium text-primary-foreground">
                        封面
                      </span>
                    )}
                  </span>
                  {/* 点击放大查看 */}
                  <button
                    type="button"
                    className="block w-full cursor-zoom-in"
                    onClick={() => setViewIndex(i)}
                    aria-label={`放大查看第 ${i + 1} 张候选图`}
                  >
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={c.url} alt="封面候选" className="aspect-[3/4] w-full object-cover" />
                  </button>
                </div>
                <div className="flex items-center justify-between border-t border-border bg-card px-1 py-1">
                  <div className="flex items-center">
                    <IconButton label="左移" disabled={i === 0} onClick={() => move(i, -1)}>
                      <ArrowLeft size={14} />
                    </IconButton>
                    <IconButton
                      label="右移"
                      disabled={i === candidates.length - 1}
                      onClick={() => move(i, 1)}
                    >
                      <ArrowRight size={14} />
                    </IconButton>
                  </div>
                  <div className="flex items-center">
                    {i !== 0 && (
                      <IconButton label="设为封面" disabled={disabled} onClick={() => toTop(i)}>
                        <ArrowUp size={14} />
                      </IconButton>
                    )}
                    <IconButton label="设为参考" disabled={disabled} onClick={() => onReferenceChange(c.file, c.url)}>
                      <Target size={14} />
                    </IconButton>
                    <IconButton
                      label="删除"
                      danger
                      disabled={candidates.length <= 1}
                      onClick={() => remove(i)}
                    >
                      <X size={14} />
                    </IconButton>
                  </div>
                </div>
```

- [ ] **Step 5: 放大查看标题带序号**

把放大弹窗里的计数 span 替换为：

```tsx
              <span className="text-sm text-muted-foreground">
                {viewing && viewIndex != null ? `#${viewIndex + 1} / 共 ${candidates.length}` : ''}
              </span>
```

- [ ] **Step 6: 构建确认通过**

Run: `pnpm --filter @lumira/admin build`（工作目录 `lumira-server/`）
Expected: 编译通过。

- [ ] **Step 7: 提交并推送**

```powershell
git add lumira-server/packages/admin/src/components/ai-create/step-cover.tsx
git commit -m "feat(admin): 封面候选卡加序号徽标与图标操作区，放大查看支持左右翻页"
git push origin master
git push github master
```

---

## 收尾验收（全部任务完成后）

- [ ] 构建：`pnpm --filter @lumira/admin build`（工作目录 `lumira-server/`）通过。
- [ ] 双远程均已推送：`git push origin master` / `git push github master`（Vercel 自动构建后台）。
- [ ] 人工走查（后台「模板管理 → AI 一键建模」）：
  1. Step1 主区只剩「示例图」「文字描述」；「补充创作要求 / 姿势个数」在默认收起的「高级设置」里，填写后折叠条显示「已填 N 项」；「开始识别」为实心主按钮且下方有 caption。
  2. 步骤条四种状态可区分；预览面板在 xl 默认展开、<xl 默认收起，点「收起/展开」可切换且预览内容不丢失（TemplateForm 的实时预览仍正常刷新）。
  3. 全自动跑到生图阶段时，过程面板「姿势图生成」Tab 出现 `+N` 角标；用户未手动切过 Tab 时会自动归位；收拢窄条显示「进行中 · …」；「识别详情」左侧有分隔线。
  4. 全自动进行中点「中止」→ 停在当前步骤并提示「已中止，可人工继续或调整后重试」，已生成的候选图/剪影保留，无错误 toast。
  5. Step3 每张候选图左上角有 `#序号`（首图并列「封面」），操作全部为图标按钮且 hover 有 tooltip；点图放大后可用 ←/→ 翻页、Esc 关闭，标题显示 `#序号 / 共 N`。