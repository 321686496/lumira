# AI 一键生成模板 · 创作意图解析设计

- 日期：2026-09-30
- 状态：已评审通过，进入实施
- 适用范围：后端 `lumira-server/packages/backend/src/modules/ai/`，后台 `lumira-server/packages/admin/src/components/ai-create/`

## 1. 问题

创作要求是用户的唯一权威指令，但当前链路把它降级成了「弱提示」：

- 用户在 Step1 提供的多格参考图（如九宫格）被识别阶段按「图中可见人物数」推断 `meta.subjectCount`，九宫格被数成 8~9 人，`normalize.ts` 又夹到 8；
- 生图阶段每张姿势图都注入「画面中有 8 位人物」，同时 `image-prompt.builder.ts` 的 singlePose 分支又硬写「不要生成连拍、多宫格或姿势对比图」——两句自相矛盾，产出过「同一个人的 7~8 个分身同框」「整张九宫格海报」；
- 用户在创作要求里写「把九宫格里九个人合成一张多人合拍图」或「按每格拆成九张独立单人姿势图」时，没有任何显式通道让后端照办，行为被写死。

结论：需要把「创作要求」解析成**显式的结构化创作意图**，并让识别与生图两个阶段都由该意图驱动，而不是各自猜测。

## 2. 目标与非目标

目标：

1. 创作要求（含 Step1 文字描述）明确写出的产出形态（逐格拆分 / 单张 / 多姿势连拍 / 合并多人合拍）必须被严格执行。
2. 创作要求没提时，AI 先给出建议意图，并在过程面板明写「AI 默认判定：…（可在创作要求改写）」；用户写了就覆盖。
3. 消除「多格拼图人数被按格子数累加」的错误推断。
4. `subjectCount` 上限由 8 放宽到 9，避免 9 人合拍被夹断。

非目标（YAGNI）：

- 不加前端意图开关（意图只由创作要求 + AI 建议决定）；
- 不把一个模板拆成多个模板；
- 不改 Flutter 端展示逻辑（Flutter 侧无 `subjectCount` 字段）；
- 不引入视觉模型二次判定参考图形态（参考图形态信息已由识别阶段的示例图视觉得到，意图解析只需文本）。

## 3. 创作意图数据结构

新增单一事实来源，写入草稿顶层 `draft.creationIntent`（与 `draft.styleProfile` 同层，由 `normalizeDraft` 白名单放行）：

```ts
export type CreationIntentMode = 'split-per-cell' | 'single' | 'multi-pose' | 'merge-group';

export interface CreationIntent {
  outputMode: CreationIntentMode;
  /** 期望产出张数 1~9 */
  imageCount: number;
  /** 每张画面内人数 1~9 */
  subjectPerImage: number;
  /** 跨图是否为同一人物（false = 每张是不同的人） */
  sameSubjectAcross: boolean;
  /** 判定依据（用户原话片段或 AI 建议理由），面板展示用 */
  reason: string;
  /** llm = 文本模型解析；fallback = 解析失败/无创作要求时的启发式兜底 */
  source: 'llm' | 'fallback';
}
```

语义约定：

| outputMode | 含义 | 典型创作要求 |
| --- | --- | --- |
| `split-per-cell` | 参考图每一格拆成一张独立图，跨图同一人物 | 「按九宫格每格拆成九张单人姿势图」 |
| `multi-pose` | 同一主体的多个姿势各一张 | 「九种不同姿势」「三连拍」 |
| `single` | 只出一张 | 无数量要求 |
| `merge-group` | 把参考图各格人物合并成一张多人合拍 | 「把九格里的九个人合成一张多人合拍图」 |

## 4. 判定优先级

```
Step2 显式姿势数 / 人数  >  创作要求原话（llm 解析）  >  参考图形态 / 现有默认（fallback）
```

- Step2 显式 `poseCount` / `subjectCount` 为最高优先，直接覆盖意图对应字段；
- 创作要求原话由「创作意图解析」步骤（轻量文本 LLM）解析；**只有 `source==='llm'` 时解析结果才作为强制值**（避免兜底值把「模型自行判断姿势数」的既有能力写死）；
- 解析失败或创作要求为空 → `source='fallback'`，`imageCount` 仅取显式 `poseCount`（未给则不强制数量，仍交模型判断），`subjectPerImage` 取显式 `subjectCount`，其余取现有默认（1 张 / 1 人 / 同一人物）。

解析失败**不阻断**识别，只降级。

## 5. 注入点

### 5.1 新增 `creation-intent.ts`

- `CreationIntent` 类型 + `normalizeCreationIntent(raw, { poseCount, subjectCount })`（夹取、枚举校验、显式值覆盖）；
- `fallbackCreationIntent({ poseCount, subjectCount })`；
- `buildCreationIntentParsePrompt(input)`：system + user，要求模型输出严格 JSON（outputMode / imageCount / subjectPerImage / sameSubjectAcross / reason），并给出四种话术的映射示例；
- `parseCreationIntent(...)`：调 `textChatJson`，失败返回 fallback；
- `creationIntentOfDraft(draft)`：从草稿读回并规范化（下游共用，缺失返回 `null`）；
- `renderCreationIntentLines(intent)`：注入识别提示词的中文意图块（含「可在创作要求改写」）；
- `describeCreationIntent(intent)`：面板一行摘要（如「逐格拆分 · 9 张 · 每张 1 人 · 跨图同一人物」）。

### 5.2 `ai-analyze.service.ts`

- 在取配置后、草稿生成前，用 `traceStep('intent', '创作意图解析', …)` 包住解析 → 面板自动出现「创作意图解析」阶段（`analyze-trace-stream.tsx` 按 step 事件通用渲染，无需前端改动）；
- 强制值：`forcedPoseCount = poseCount ?? (intent.source==='llm' ? intent.imageCount : null)`；`forcedSubjectCount = subjectCount ?? (intent.source==='llm' ? intent.subjectPerImage : null)`；
- `subjectCountHint`（系统提示措辞分档）改为 `subjectCount ?? intent.subjectPerImage`；
- 两个 `buildXxxUserPrompt` 增传 `creationIntent`，两个 `buildXxxSystemPrompt` 的 `subjectCountHint` 随之；
- 归一化前 `json.creationIntent = intent`；归一化后按实际 `pose` 条数回填 `draft.creationIntent.imageCount`（意图与实际产出对齐，供面板展示）。

### 5.3 `analyze.prompt.ts`

- `subjectCountLine` / `poseCountLine` 接受由意图驱动的值（上限 8 → 9）；
- 硬约束 excise `meta.subjectCount` 规则新增：**参考图为多格拼图时，同一个人出现在多个格子里视为同一主体，人数按「单格内人数」计，不按格子数累加**；
- `extrasLines` 注入 `renderCreationIntentLines`（含 merge-group 的「把各格人物合并到同一画面」指令）。

### 5.4 `normalize.ts`

- `meta.subjectCount` 夹取上限 8 → 9（warning 文案同步）；
- 新增 `creationIntent` 白名单块（形状校验：合法 `outputMode` + 有限数值，非法丢弃）。

### 5.5 `image-prompt.builder.ts`

singlePose 分支改由意图驱动：

- 人数句：`subjectPerImage`（读 `draft.creationIntent`，缺失回退 `meta.subjectCount`）；
- `merge-group`：改为「N 位人物同框合拍……把参考图各格人物合并到同一场景、同一光线下的真实合拍」+「不要生成多宫格、分屏、拼贴或姿势对比图」（**不再**注入原「不要合并多个姿势」句）；
- `split-per-cell` 且 `subjectPerImage===1`：额外注入「画面中只有一位人物，禁止同一人物在画面中重复出现（不是分身、不是连拍合成）」；
- 一致性句：`sameSubjectAcross===false` 或 `outputMode==='merge-group'` 时**不注入**「保持同一人物长相……」句。

### 5.6 `ai-generate-image.service.ts`

`describeReferences` 的 system prompt 增加约束：识别结论**仅用于人物形象 / 场景 / 光线 / 风格**，**不得据此推断画面人数**。

### 5.7 `ai-pipeline-job.service.ts`

- 读 `creationIntentOfDraft(draft)`；`sameSubjectAcross===false` 时，依赖张（index>0）不传锚点图（`refs=undefined`、`anchor=false`）、`consistency` 降级为 `{ mode:'loose' }`（跳过一致性句）；
- 目标张数天然等于「意图驱动的 `pose` 数组条数」，不再额外裁剪；
- 生图重试（`generateWithRetry`）在每次重试前补一条 `note` 事件（含尝试次数与退避秒数），让「上游在重试」在面板可见，避免出现「停在姿势图生成中」的误判。

### 5.8 后台 `wizard.tsx`

「人物数量」下拉由 1/2/3 扩展到 1~9，与后端新上限对齐。

## 6. 面板呈现

- 识别 Tab 时间线新增「创作意图解析」阶段，结论行即 `describeCreationIntent(intent)`，末尾附「（AI 建议，可在创作要求改写）」或「（按创作要求）」；
- 意图与实际产出不符（`imageCount !== pose 条数`）时，在结论里标出实际张数与原因。

## 7. 测试

- `creation-intent.spec.ts`（新增）：三种话术映射（九格拆分 / 九人合拍 / 九种姿势）；显式 `poseCount`/`subjectCount` 覆盖；解析失败落 `fallback`；`normalizeCreationIntent` 越界夹取。
- `analyze.prompt.spec.ts`：`subjectCountLine` 支持 9；多格拼图人数规则句存在；意图块注入。
- `normalize.spec.ts`：`subjectCount=9` 不被夹到 8；非法 `creationIntent` 被丢弃。
- `image-prompt.builder.spec.ts`：`merge-group` 不出现「不要生成连拍、多宫格」；`subjectPerImage=1` 出现「画面中只有一位人物」「禁止同一人物在画面中重复出现」；`sameSubjectAcross=false` 不出现一致性句。
- `ai-pipeline-job.service.spec.ts`：`sameSubjectAcross=false` 时依赖张不传锚点。

## 8. 验收

1. 九宫格参考图 + 「按每格拆成九张单人姿势图」→ 9 张，每张 1 人，无分身/多宫格；
2. 九宫格参考图 + 「把九个人合成一张多人合拍图」→ 1 张，画面 9 人，无九宫格拼贴；
3. 创作要求为空 → 面板明写 AI 默认判定，行为与改动前一致；
4. 面板可见「创作意图解析」阶段与生图重试事件。