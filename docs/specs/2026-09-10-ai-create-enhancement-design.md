# AI 一键建模增强设计（文本模型 / 多输入方式 / 实时预览）

> 日期：2026-09-10
> 范围：后端（`lumira-server/packages/backend/`）+ 后台（`lumira-server/packages/admin/`）
> 前置：`docs/specs/2026-09-09-ai-template-one-click-creation-design.md`（本文档为其增强迭代）
> Flutter 端：**零改动**

## 背景与问题

已上线的「AI 一键建模」存在三个短板：

1. **生图 prompt 质量低**：`image-prompt.builder.ts` 用纯代码拼接生图提示词（「一张 3:4 竖构图的人像摄影作品，风格日系、田园、清新…」），缺乏光影氛围、镜头语言等专业摄影表达，直接拉低封面生图质量；且模型配置只有视觉 + 生图两个模型，纯文本任务无处安放。
2. **输入方式单一**：Step1 强制上传一张示例图；运营手里有时只有一段风格描述/创作要求（无成片参考），无法启动建模。
3. **无实时预览**：识别后 TemplateForm 在页面下方常驻，但预览（PhonePreview）在表单内部右侧、需滚动才能看到；向导步骤进行中（选封面、调姿势）对参数效果无感知。

## 目标

1. **可选 textModel**：配置新增可选「文本模型」字段，留空自动回退 visionModel；现有部署零改动。
2. **多输入方式**：支持「一张示例图 / 一段文字 / 文字 + 示例图」三种输入，至少填一项即可开始识别。
3. **生图 prompt 润色**：生图前用文本模型把草稿转写为专业摄影描述，失败自动回退现有拼接 prompt（不阻塞流程）。
4. **向导层常驻 sticky 预览**：AI 建模页右侧固定手机预览面板，实时反映草稿回填、封面、姿势、参数的所有变化。

## 非目标

- 不改 Flutter 端；产出模板与现有线上模板同构。
- 不做多图输入（多张参考图），仍为单图。
- 不做润色结果的人工编辑界面（润色对运营透明，失败静默回退）。
- 不引入流式输出（SSE），生图/润色仍为同步等待。

## 一、AI 配置扩展：可选 textModel

### DB（migration 编号顺延）

```sql
ALTER TABLE ai_provider_config
  ADD COLUMN text_model VARCHAR(64) NULL AFTER vision_model;
```

### 后端

- `AiConfigService.getActiveConfig()` 返回值新增：

```ts
export interface ActiveAiConfig {
  provider: string;
  baseUrl: string;
  apiKey: string;
  visionModel: string;
  imageModel: string;
  textModel: string;   // = row.textModel || row.visionModel（有效值，永不为空）
}
```

- `UpdateAiConfigDto` 新增可选 `textModel?: string`（空串 = 清除、回到回退逻辑）；save 时原样存入（`textModel: dto.textModel ?? ''`）。
- `AiConfigView` 新增 `textModel: string`（存储值，可为空串）+ `effectiveTextModel: string`（回退后的有效值），供前端展示。
- 连通性测试：`textModel` 有独立配置值时，`test()` 追加一项**纯文本连通测试**（无图 chat），结果并入现有 `{ vision, note }` 返回结构，扩展为 `{ vision, text?, note }`。

### Admin「AI 设置」页

- 新增可选输入框「文本模型」：placeholder「留空则使用视觉模型」；预设切换时填入该厂商默认文本模型（qwen → `qwen-plus`、doubao → `doubao-1.5-pro-32k`、zhipu → `glm-4-flash`、openai → `gpt-4o-mini`），可手改、可清空。
- 测试结果区在配置了独立文本模型时显示两行（视觉 / 文本）。

## 二、输入方式扩展：示例图 / 文字 / 图文组合

### 后端 ai-analyze

- `POST /api/v1/admin/ai/analyze` 请求变化：`image`（文件）**改为可选**，新增 `text`（字符串）**可选**；两者都为空 → 400「请至少提供示例图或文字描述之一」。
- `text` 长度校验：trim 后 > 500 字 → 400「文字描述不能超过 500 字」。
- `image` 存在时沿用现有校验（mimetype / ≤ MAX_IMAGE_BYTES）。

### llm-client：新增 textChat

```ts
export interface TextChatInput {
  systemPrompt: string;
  userText: string;
  temperature?: number;   // 默认 0.3
  jsonMode?: boolean;     // 同 visionChat 的降级逻辑
  timeoutMs?: number;     // 默认 90_000
}
export async function textChat(cfg: LlmConfig & { textModel?: string }, input: TextChatInput): Promise<string>;
```

- 与 `visionChat` 共享底层请求逻辑（抽私有 `doChatRequest`：拼 messages → fetch → 错误映射 → jsonMode 降级）；messages 不含 `image_url`。
- `LlmConfig` 增加可选 `textModel`；请求体 `model` 取 `textModel ?? visionModel`。

### 提示词按输入组合分叉（analyze.prompt.ts）

| 输入 | 调用 | userPrompt 附加内容 |
|---|---|---|
| 仅图 | `visionChat`（现状不变） | — |
| 图 + 文 | `visionChat` | 注入「用户补充要求：{text}。识别结果需向该要求倾斜（如用户要求侧拍/秋日氛围，则构图、场景、后期相应调整）」 |
| 仅文 | `textChat` | systemPrompt 替换为「文字构思版」：无图可看，基于文字描述构思一个可上线的拍摄模板，输出同一六段 JSON 结构 |

- 三种输入产出**完全相同的草稿结构**，归一化管线（extractJson → normalizeDraft）复用不变。
- 纯文字模式无参考图：下游 `ai-generate-image` 的 `reference` 本就可选（文生图），无需改动；Step4 剪影源 = 生成的封面图（无示例图可选）。

### Admin 向导 Step1（wizard.tsx）

- 示例图上传区标注「可选」；新增 textarea「文字描述 / 创作要求」（≤500 字，placeholder 示例：「日系田园风，午后侧逆光，少女侧身回眸，清新通透」）。
- 「开始识别」「全自动生成并上架」按钮的禁用条件改为：**图和文字都为空**。
- 换图或改文字触发流程重置（沿用现有 reset 逻辑，文字变更同样重置下游状态）。
- 全自动流程在纯文字模式下：生图无参考图 → 文生图；封面候选仅 AI 生成图；剪影源 = AI 封面图。

## 三、生图 prompt 润色（textModel 转写）

### 时机与链路

润色发生在**每次生图请求时**（非识别时）——Step2 修改草稿后，生图用的是最新数据：

```
ai-generate-image.generate()
  → buildImagePrompt(draft)          // 现有拼接 prompt（作为润色输入 + 回退值）
  → polishPrompt(rawPrompt, draft)   // 新增：textChat 转写（新 prompt，内部文件 prompt-polisher.ts）
  → generateImage(cfg, { prompt: polished })   // 失败 → 直接用 rawPrompt，不抛错
```

### prompt-polisher.ts（新文件）

```ts
export async function polishPrompt(
  cfg: ActiveAiConfig,
  rawPrompt: string,
  draft: Record<string, unknown>,
): Promise<{ prompt: string; polished: boolean }>
```

- systemPrompt：「你是专业摄影艺术指导。将给定的模板参数描述转写为一段高质量的中文生图提示词，融入光影氛围、镜头语言、色彩层次、景深质感等专业摄影表达。保留原有全部关键信息（主体、构图、风格、光线、背景、色调），只做表达升级，不新增与模板无关的元素。直接输出转写后的提示词，不要任何解释。」
- userText = rawPrompt（拼接 prompt 已含全部草稿关键信息）。
- temperature 0.4；不启用 jsonMode（输出为自由文本）。
- **失败静默回退**：textChat 抛错 / 返回空串 / 超时 → 返回 `{ prompt: rawPrompt, polished: false }`，不阻塞生图。
- 超时独立控制：`timeoutMs: 30_000`（润色挂了不能拖垮生图整体等待）。

### 不改动的部分

- `image-prompt.builder.ts` 拼接逻辑保留（润化的输入 + 回退值 + 单测基线）。
- 剪影管线、模板提交链路零改动。

## 四、向导层常驻 sticky 实时预览

### 布局

```
AI 建模页（/dashboard/templates/ai-create）
┌─────────────────────────────┬──────────────┐
│ stepper + 当前步骤卡片       │  手机预览面板 │
│ （Step1~5 内容区）           │  (sticky)    │
│                             │  PhonePreview │
│ 模板表单（formActivated 后） │  实时 watch   │
└─────────────────────────────┴──────────────┘
        ≥ xl 双栏                < xl 预览置顶折叠
```

### 技术方案：表单实例提升

- `TemplateForm` 新增 prop `onFormReady?: (form: UseFormReturn<FormValues>) => void`：`useEffect` 中把 `form` 实例回调给父级（向导层）。
- 向导层 `AiCreateWizard` 持有 `formRef`，把 PhonePreview 渲染在右侧 sticky 面板，数据源全部来自 `form.watch()`（与表单内预览同源，天然实时）。
- 预览面板字段与表单内 PhonePreview 完全一致（cover / silhouette / position / scale / rotation / aspectRatio / overlay / 后期参数 / 相机参数 / name）。
- 封面图来源：向导层维护 `previewCoverUrl` 状态——识别回填 / Step3 换封面 / AI 生图时同步更新（injection 的 images 首张 blob URL）。
- **去重**：wizardMode 下 TemplateForm 隐藏自带右侧预览（`wizardMode` 已传入，加条件渲染即可）；非 wizard 模式（普通新建/编辑页）不受影响。
- 识别前空态：面板显示占位文案「识别完成后此处实时预览参数效果」+ 手机外框。
- 小屏（< xl）：预览面板渲染在 stepper 下方、步骤卡片上方，非 sticky（现有 xl 断点行为对齐）。

## 五、错误处理汇总

| 场景 | 行为 |
|---|---|
| 图文都为空点识别 | 400 → 前端按钮禁用 + 后端兜底 400 |
| text 超 500 字 | 400，前端 textarea maxLength + 计数提示 |
| textModel 未配置（回退 visionModel）但 visionModel 不支持纯文本 | 仅文模式识别报错 → 引导「请在 AI 设置中配置文本模型」；润色静默回退拼接 prompt |
| 润色超时/失败 | 静默回退 rawPrompt，生图正常继续 |
| 纯文模式全自动 | 生图走文生图（reference 空）；其余流程同现状 |

## 六、测试

- **后端单测**：
  - `textChat`：请求体无 image_url / model 取 textModel 回退 / jsonMode 降级复用
  - `ai-analyze`：图文都空 400 / text 超长 400 / 仅文走 textChat / 图 + 文 prompt 注入
  - `prompt-polisher`：成功返回润色值 / textChat 抛错回退 / 空输出回退 / polished 标记
  - `ai-config`：textModel 存取 / 留空回退 / 连通性测试 text 分支
- **后端 e2e**：ai-analyze 仅文模式（mock 上游）。
- **Admin**：typecheck 通过；手动验证向导三输入组合 + 预览实时性。
- migration 编号顺延现有序号；无新 npm 依赖（LLM 均为原生 fetch HTTP 调用，Docker 镜像不变）。

## 七、实施顺序（供 writing-plans 展开）

1. migration + `ai-config` 扩展（textModel 存取/回退/连通测试）+ Admin 设置页
2. `llm-client` 抽 `doChatRequest` + 新增 `textChat`
3. `ai-analyze` 输入扩展 + prompt 分叉 + Admin Step1 输入区改造
4. `prompt-polisher` + `ai-generate-image` 接入润色（含回退）
5. 向导层 sticky 预览（TemplateForm `onFormReady` + 向导布局改造 + 预览去重）
6. 全量验证 + 双远程推送
