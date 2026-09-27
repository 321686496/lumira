# AI 一键生成模板：风格档案分流 + 全链路提示词美学改造 + 美学评审闸门

- 日期：2026-09-28
- 范围：`lumira-server/packages/backend/src/modules/ai/`（后端 AI 一键生成模板链路）
- 状态：设计已确认，待实施

## 1. 背景与问题

管理员用「AI 一键生成模板」产出的姿势图质量差：没构图、没摄影参数、姿势/穿搭/表情不美、画面平平无奇。逐环节排查后的根因：

| # | 根因 | 位置 |
| --- | --- | --- |
| 1 | 出口加固无条件把画面拉成「随手抓拍」：恒定追加「像随手抓拍的实拍照片 + 轻微噪点与白平衡偏差」，并明令禁止「影楼写真、网红精修风」，与「时尚大片 / 摄影写真 / 小红书网感」直接互斥 | `ai-generate-image.service.ts` `PHOTO_REALISM_PREFIX/SUFFIX` |
| 2 | 全链路只有一套「人像向」统一提示词，无意图识别与风格分流；非人像大类（风景/美食/街拍/夜景/微距/静物）缺构图与术语引导 | `analyze.prompt.ts` `buildAnalyzeSystemPrompt/buildTextOnlySystemPrompt` |
| 3 | 素材里不存在「审美层」字段：`pose[].description` 无表情、无穿搭要求；`poseRefSheet.perPose.subjectPose` 是自由对象、无字段级要求；`shared.outfit` 只是一个词 | `analyze.prompt.ts`、`pose-ref-sheet.service.ts` |
| 4 | 组装器禁止模型补美感：「只使用素材中出现的信息组织画面，不新增素材没有的元素」 | `image-prompt.composer.ts` `COMPOSE_SYSTEM_PROMPT` 规则 9 |
| 5 | 美学闸门形同虚设：8 个维度揉成一个总分（≥0.85 pass），审美只是其中一项；且**无参考图时整段跳过评审**，纯文字一键生成完全不过闸门；`suggests` 也没有针对审美的整改口径 | `ai-orchestrator.service.ts`（无图 break）、`image-score.service.ts` |

### 「真实」的准确含义（用户口径）

不是「随手抓拍」，而是：**不要动漫/插画/二次元质感、不要假光线假皮肤假布料、不要现实中拍不出来的画面、不要摆不出来的动作、不要肢体与面部畸变**。真实是底线，美感（时尚大片 / 摄影写真 / 随拍松弛 / 小红书抖音网感）是可选的取向。

## 2. 目标与非目标

**目标**

1. 先做意图识别：由模型判定本次要做的**大类**与**风格取向档案**，后续所有提示词按该档案分流（不再用一套统一提示词覆盖所有大类）。
2. 全链路补齐审美引导：构图、摄影参数、姿势线条、穿搭、表情、光线层次。
3. 真实底线恒定保留（反动漫 / 反假材质 / 反不可能物理 / 反畸变），但与「美感」互斥的表述按档案分档。
4. 生图前增设**美学评审闸门**（只评草稿），审美不达标就整改，且纯文字路径不再跳过评审。

**非目标**

- 不做「生成图视觉评审 + 重生成」闭环（成本与耗时高，本次不做，登记到 `docs/future-optimizations.md`）。
- 不做后台可维护的 DB 风格档案（本次为代码内置固定档案）。
- 不改 App 端模板数据结构与展示；不修改 `lumira-app/`（废弃 uni-app）。

## 3. 方案总览

```
创作要求 / 文字描述 / 参考图
        │
        ▼
① 风格定位 style-profile ──► StyleProfile{ category, archetype, styling, expression, ... }
        │                              │
        │                              ├─► ② analyze（草稿生成，按档案分流）
        │                              ├─► ② image-describe（识别补 expression/styling/styleRead）
        │                              ├─► ② pose-ref-sheet（姿势面片字段级要求）
        │                              ├─► ③ image-score 美学评审闸门（含无图路径）
        │                              │        └─ retry → draft-refine 逐项整改
        │                              └─► 定稿写入 draft.styleProfile
        ▼
生图：per-pose draft ──► buildImagePrompt(兜底) ──► composeImagePrompt(+档案) ──► hardenPhotoRealism(按 retouchLevel 分档) ──► 生图模型
```

链路顺序：`styleProfile` →（已有）research →（已有）describe →（已有）poseRefSheet →（已有）paramValidate →（改造）imageScore 美学闸门 →（改造）draftRefine → 定稿写入 `draft.styleProfile`。

## 4. 数据契约

### 4.1 StyleProfile

```ts
export type StyleArchetype =
  | 'fashion_editorial'      // 时尚大片：强设计感、戏剧光比、大片调性
  | 'photo_portrait'         // 摄影写真：干净通透、柔和布光、精致妆造
  | 'candid_lifestyle'       // 随拍松弛：生活化光线、松弛瞬间感
  | 'social_media_trendy'    // 网感网红：小红书/抖音审美、明亮干净、强穿搭感
  | 'documentary_street'     // 纪实街拍：环境叙事、真实光比、抓拍瞬间
  | 'landscape_fine_art'     // 风景意境：层次、留白、光时窗
  | 'food_lifestyle';        // 美食生活：质感、器皿、暖调氛围

export interface StyleProfile {
  category: 'portrait' | 'landscape' | 'food' | 'street' | 'night' | 'macro' | 'still-life';
  archetype: StyleArchetype;
  aestheticTarget: string;   // 一句话美学目标
  subjectStyling: string;    // 穿搭/妆造/材质/配饰要点（非人像可为空）
  expressionMood: string;    // 表情与情绪（非人像可为空）
  poseLanguage: string;      // 姿势语言：张力/舒展/松弛/戏剧
  lightingSignature: string; // 光比与光线特征
  compositionBias: string;   // 构图偏好
  paletteHint: string;       // 色调倾向
  retouchLevel: 'none' | 'light' | 'polished';
  extraNotes: string;        // 现场补充的个性细节（不得改写档案底线）
}
```

### 4.2 档案表（内置固定）

新增 `style-profile.presets.ts`，每个 `archetype` 预置一个约束块（用于注入各环节提示词）：

| archetype | retouchLevel 默认 | 光线 | 构图偏好 | 禁忌（仅本档案级） |
| --- | --- | --- | --- | --- |
| fashion_editorial | polished | 硬光/高光比/轮廓光 | 对角线、框架式、大留白 | 忌生活化杂乱、忌平光 |
| photo_portrait | light | 柔和布光/窗光 | 三分法、居中、浅景深 | 忌脏乱背景 |
| candid_lifestyle | none | 自然光/环境光 | 三分法、环境人像 | 忌刻意摆拍痕迹 |
| social_media_trendy | light | 明亮通透/顺光 | 居中、对称、九宫格 | 忌脏乱、忌暗调沉闷 |
| documentary_street | none | 现场光/高光比 | 引导线、抓拍视角 | 忌摆拍、忌影棚光 |
| landscape_fine_art | light | 黄金时刻/低角度光 | 大面积留白、层叠层次 | 忌杂乱前景 |
| food_lifestyle | light | 侧逆光/柔光 | 俯拍/45°、器皿构图 | 忌冷调、忌塑料质感 |

**底线（所有档案共享，恒定注入，不随档案变化）**：真实照片媒介（非动漫/插画/漫画/赛璐璐/厚涂/CG/3D 渲染/油画/游戏立绘）、真实人体结构与解剖（无肢体/手指/面部畸变）、可实拍复现（无无源光、无不可能透视与姿势）、真实材质（皮肤毛孔与绒毛、布料纹理、环境光衰减与阴影过渡）。

**现场补充规则**：`extraNotes` 与 `aestheticTarget` 只允许在档案允许范围内补个性细节；若与档案底线冲突，以底线为准（在提示词中显式声明该优先级）。

### 4.3 草稿透传

`styleProfile` 作为草稿顶层字段（与 `poseRefSheet` 同级）由 orchestrator 写入 `draft.styleProfile`，并需在 `normalize.ts` 的白名单中放行（只扩展不破坏既有字段）。

## 5. 模块改动明细

### 5.1 新增 `style-profile.service.ts`

- 输入：`creationReq` / `text`（创作要求优先，其次文字描述）+ 可选 `ImageDescription`（有参考图时）。
- 调用：`textChat(cfg.text, { systemPrompt, userText, temperature: 0.3, jsonMode: true, timeoutMs: 60_000 })`。
- 输出：解析 `extractJson` → 归一化（`category`/`archetype` 不在枚举内 → 兜底 `candid_lifestyle` + `portrait`；`retouchLevel` 非法 → 取档案默认）。
- 降级：调用失败/解析失败 → 返回 `candid_lifestyle` 档案的默认档案（不抛错、不阻断链路），trace 记 `fail:` + 兜底说明。
- 编排接入：`ai-orchestrator.service.ts` 的 `STEP_TITLES` 增加 `styleProfile: '风格定位'`，并在 research 之前**消费**调用方传入的档案，输出一条 trace（含 `archetype`/`category`/`retouchLevel`），供后续各阶段与后台时间线使用。

> 说明：analyze（草稿生成）在 `ai-analyze.service.ts` 中**先于** `orchestrator.run` 执行，因此风格定位必须在 analyze 之前完成。实现方式：在 `ai-analyze.service.ts` 中先调用 `styleProfile.resolve(...)`，把结果通过 `analyze.prompt` 的注入参数传给草稿生成，再作为 `opts.styleProfile` 传给 `orchestrator.run`——**只判定一次**，orchestrator 不再重复调用。

### 5.2 `analyze.prompt.ts`

- 新增注入参数 `styleProfile`（可选）：在系统提示词中插入「## 本次风格档案（必须遵守）」段落，含档案约束块 + `subjectStyling` / `expressionMood` / `poseLanguage` / `lightingSignature` / `compositionBias` / `paletteHint` / `retouchLevel` / `extraNotes`。
- 身份从「资深人像摄影模板编辑」改为「资深摄影/视觉模板编辑（按风格档案作业）」。
- `pose[].description` 新增硬要求：**表情**（眼神方向与强度、嘴角、下颌与颈部线的松紧）、**穿搭**（颜色、材质、廓形、配饰与褶皱状态）、**肢体线条**（与档案 `poseLanguage` 一致：舒展/张力/松弛）。
- 创作质量要求第 1/2/4 条按 `category` 分流：人像用现有口径；非人像大类（风景/美食/街拍/夜景/微距/静物）改为对应术语（如风景：层次/光时窗/前景引导；美食：器皿与质感的摆放逻辑），禁止对人像以外题材套用「重心与支撑腿」「手部落点」。
- 保留现有硬约束（参数互洽、参考图客观事实不得美化、构图不佳时给更好建议等）。

### 5.3 `image-describe.prompt.ts` / `image-describe.service.ts`

- `people[]` 增加 `expression`（表情与眼神）、`styling`（妆造与穿搭质感）字段。
- `global` 增加 `styleRead`：从图中读到的风格取向（对应 `archetype` 口径）与精修程度（`retouchLevel` 口径），供风格定位与评审使用。
- 契约扩展不破坏既有字段（缺失时下游按空串处理）。

### 5.4 `pose-ref-sheet.service.ts`

- `shared` 增加 `styling`、`expressionMood`（与 StyleProfile 对齐，保证跨姿势一致）。
- `perPose.subjectPose` 由自由对象改为字段级契约（缺失即视为不合格，normalize 补齐默认）：
  `headFraming`（下巴高低/视线方向）、`torsoTwist`（躯干朝向与转动角度）、`shoulderHipOffset`（肩胯错位）、`armAndHand`（左右手分别的动作与落点）、`legStance`（重心与支撑腿）、`expression`（本张表情）。
- 提示词新增要求：姿势必须"有设计感的线条"（避免正面僵直、双手对称、关节正对镜头、手臂紧贴身体）；并按档案 `poseLanguage` 定调。
- 注入 StyleProfile 约束块；`timeoutMs` 维持 120s。

### 5.5 `image-prompt.composer.ts`

- `PromptComposeInput` 增加 `styleProfile`（从 draft 读取兜底）。
- 规则 9 改为：**可在档案允许范围内补足审美细节**（表情、穿搭、肢体线条、光线层次、前景层次），但不得引入与档案冲突的风格，也不得新增现实中拍不出来的元素。
- 组织顺序新增「表情与穿搭」，并把档案的 `aestheticTarget` / `retouchLevel` 落到质感描述。
- `buildPromptMaterial` 新增下发：【风格档案】段落（含 `archetype` 中文名、穿搭/表情/姿势语言/光线/构图偏好/色调/精修档）。
- 失败/超时回退不变。

### 5.6 `image-prompt.builder.ts`（机械兜底）

- 同步接收 `styleProfile`：按档案补「穿搭 / 表情 / 姿势语言」短语，并按 `retouchLevel` 选择质感结尾句（`none` → 自然随拍质感；`light` → 干净通透、保留真实质感；`polished` → 精致大片质感但材质仍真实），替换现有写死的「画面带自然噪点…」单一表述。

### 5.7 `hardenPhotoRealism`（`ai-generate-image.service.ts`）

- 签名改为 `hardenPhotoRealism(prompt, { selfie, retouchLevel })`（默认 `retouchLevel: 'none'` 保持对旧调用兼容；`generate()` 内从 draft 读取）。
- **恒定保留**：真实照片媒介声明 + 反动漫/CG/插画负面清单 + 真实人体结构 + 真实材质（皮肤毛孔、布料纹理、真实光源衰减）。
- **删除**与风格冲突的恒定表述：「像随手抓拍的实拍照片」「画面带轻微噪点与白平衡偏差」「禁止影楼写真、网红精修风」。
- **按档输出**：
  - `none`：自然环境光、轻微噪点、生活化瞬间感；
  - `light`：干净通透、光比克制、皮肤保留真实毛孔与绒毛（不磨皮）；
  - `polished`：精致布光与高级质感、调色考究，但皮肤/布料/道具仍为真实材质纹理。
- 自拍（`SELFIE_DEVICE_SUFFIX`）逻辑不变。

### 5.8 `image-score.service.ts`（美学评审闸门）

- rubric 输出结构化分项（既有单值 `score` 保留给抽屉逻辑与后台展示）：

```json
{
  "aesthetics": {"composition":0,"pose":0,"styling":0,"expression":0,"lighting":0,"styleHit":0},
  "realism": {"anatomy":0,"material":0,"physical":0},
  "consistency": 0, "params": 0, "metadata": 0,
  "score": 0,
  "reasons": ["..."],
  "suggests": ["..."]
}
```

- **闸门条件**（`verdict=pass` 需同时满足）：
  - `score >= 0.85`
  - `min(aesthetics.*) >= 0.75`
  - `min(realism.*) >= 0.85`（真实底线更严）
  - 分项缺失/非法 → 视为未达标（保守 retry）。
- `suggests` 必须落到具体字段与具体补法（如「pose[0].description 缺表情与左手落点，补：嘴角放松上提、左手扶帽檐」），供 `draft-refine` 直接使用。
- 评审输入新增 `styleProfile`（核对 `styleHit`：画面是否命中档案取向），并加入 `retouchLevel` 允许区间判定（`none` 档出现影楼感也算不达标）。
- **无参考图路径**：`ai-orchestrator.service.ts` 不再 `break` 跳过评审，改为对草稿做纯文本美学评审（不做逐项一致性核对，`consistency` 不计入闸门），阈值放宽为 `min(aesthetics.*) >= 0.70`、`score >= 0.8`；`min(realism.*) >= 0.85` 照旧（评审草稿的物理合理性与可实拍性）；评审迭代预算沿用 `MAX_SCORE_ITERATIONS`。
- 评分分项写入 trace（后台时间线可见）。

### 5.9 `draft-refine.service.ts`

- 提示词增加：按评审**未达标维度逐项整改**，只改相关字段（`pose[]` / `sceneGuide` / `composition` / `postProcess`），不得破坏真实底线与档案取向；输出仍是完整草稿 JSON。
- 注入 StyleProfile 约束块。

### 5.10 `param-validate.service.ts`

- 仅补一处：`retouchLevel=none` 时不强制开启 `fillLight` 之外的"美化"参数（保持现状），并确保 `legStretch` 等 App 变现字段不被评审整改引入的夸张值破坏（沿用现有裁剪）。

### 5.11 明确不改动的部分

- `prompt-polisher.ts` 已不在链路上被调用（`ai-generate-image.service` 走 `composeImagePrompt`），本次不改，也不删除（留作后续清理登记）。
- `normalize.ts` 仅做一处扩展：白名单放行顶层 `styleProfile`（形状校验 + 非法时丢弃），其余归一化口径不变。
- `ai-image-task.service.ts` 的生图并发网关、重试与惰性清理逻辑不变。

## 6. 错误处理与降级

| 环节 | 失败表现 | 降级策略 |
| --- | --- | --- |
| 风格定位 | 调用失败 / JSON 非法 / 枚举越界 | 兜底 `candid_lifestyle` + `portrait`，trace 记 fail，链路继续 |
| 草稿生成 | 现状不变 | 现状不变 |
| 姿势面片 | JSON 非法 | 现状不变（抛错由 orchestrator 降级为空面片） |
| 美学闸门 | 无图 / 调用失败 / 解析失败 | 无图 → 纯文本评审（阈值为 5.8 的放宽值）；失败 → 保守 retry；达上限 → 用历史最高分草稿收束（沿用现有逻辑） |
| 提示词组装 | 失败 / 超时 | 现状不变（回退机械拼接 prompt） |

## 7. 测试计划（单测）

1. `style-profile.service.spec.ts`：正常解析；枚举越界兜底；`retouchLevel` 非法取档案默认；调用失败降级不抛错；`extraNotes` 不覆盖底线。
2. `analyze.prompt.spec.ts`：注入档案后系统提示词含档案段落；非人像不出现「重心与支撑腿」等人类专属要求；`pose.description` 含表情/穿搭要求。
3. `pose-ref-sheet.service.spec.ts`：`subjectPose` 字段级契约补齐默认；`shared.styling/expressionMood` 透传。
4. `image-prompt.composer.spec.ts`：档案段落下发；规则 9 新表述存在；审美细节允许补充的语义生效。
5. `image-prompt.builder.spec.ts`：三种 `retouchLevel` 产出不同质感结尾句。
6. `ai-generate-image.service.spec.ts`：`hardenPhotoRealism` 分档；确定性断言「不再包含『禁止影楼写真』『轻微噪点』」；真实底线条目仍在。
7. `image-score.service.spec.ts`：分项闸门四种不达标情形（总分够但审美不够 / 真实不够 / 分项缺失 / 全达标）；`suggests` 落到字段的格式要求。
8. `ai-orchestrator.service.spec.ts`：无图路径**不再跳过**评审；阈值差异生效；trace 含 `styleProfile` 步骤。
9. `draft-refine.service.spec.ts`：按未达标维度整改的提示词内容。

人工回归：4 组创作要求（时尚大片 / 随拍松弛 / 网感网红 / 1 个非人像大类），比对改动前后姿势图的构图、参数、姿势线条、穿搭、表情与真实底线。

## 8. 风险与待确认项

1. **admin 端草稿回传**：每张姿势图生图时，admin 是否原样回传 analyze 产出的完整草稿（含新增 `styleProfile` 字段）？若不回传，需在 admin 请求体里补该字段透传。实施前需确认（见实施计划首个验证点）。
2. **成本与耗时**：新增一次风格定位调用（~千级 token）；美学闸门在无图路径不再跳过，纯文字路径耗时增加一轮评审 + 可能 1~2 轮 refine。
3. **契约兼容**：`styleProfile`、`people[].expression/styling`、`global.styleRead`、`subjectPose` 字段级契约均为**扩展**，下游缺失按空处理；`normalize.ts` 白名单需放行 `styleProfile`。
4. **阈值风险**：闸门阈值（0.85/0.75/0.85、无图 0.8/0.70）为初值，实施后用真实跑批校准；若 retry 频繁空转，按现有「无法产生有效改进即收束」逻辑兜底。

## 9. 后续优化登记（本次不做，登记到 `docs/future-optimizations.md`）

- 生成图视觉评审 + 不达标重生成闭环（视觉模型对每个姿势图打分，限次重生成）。
- 风格档案改由后台维护（DB 配置 + 管理界面），支持运营自定义取向。