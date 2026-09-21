# AI 一键建模板质量极致优化 · 趋势研究 + 中枢编排（Agentic Orchestrator）

> **目标**：把当前「一次 LLM 调用 → 单份草稿」升级为「以文本大模型为中枢（CPU），按需调度 趋势爬取 / 图片识别 / 姿势参考 / 生图 / 校验 等工具，做多步研究 + 生成 + 验证 的 Agentic Pipeline」，从根上提升成品的**真实 / 热点 / 风格 / 美感 / 姿势图真实性 / 参数准确性**，并保证 App 实拍效果与模板期望高度一致。
>
> **质量优先原则（最高纲领）**：AI 模板生成是本项目最重要的功能，唯一目标是模板极高质量。本功能为后台生成（非实时链路），一切取舍**质量 > 时延、质量 > 成本**——允许单模板 3~10 分钟生成、多候选多轮迭代、更高 token 预算。
>
> **状态**：设计文档 v2（✅ 已完成第二轮查漏补缺，待评审）
> **配套实施**：见文末「落地路径（分阶段任务分解）」

---

## 一、现状诊断（基于代码实证）

| 环节 | 现状（文件） | 缺陷 |
| --- | --- | --- |
| 识别编排 | `ai-modules/ai/ai-analyze.service.ts`：单次 `visionChat`/`textChat` → JSON → `normalizeDraft` | 一次生成、无研究、无 agent loop、无验证；模型凭"想象"填参，无热点/真实参考 |
| 文本模型 | 仅 `prompt-polisher.ts` 做生图 prompt 润色 | 未担任中枢调度角色 |
| LLM 客户端 | `llm-client.ts`：仅 `chat/completions`，不支持 tool/function calling | 无法实现「模型调工具」 |
| 生图 | `ai-generate-image.service.ts` → `buildImagePrompt` → `polishPrompt` → `generateImage` | 一次性生图、无多候选择优、无反向校验 |
| 剪影/姿势 | `ai-generate-silhouette.service.ts`；姿势参数来自草稿 `pose[]` | 姿势图与参考值脱节，无「姿势参考面片」输入 |
| 草稿契约 | `analyze.prompt.ts` 的 `DRAFT_JSON_EXAMPLE` + `normalize.ts` | **缺** `fillLight`（补光灯）、`legStretch`、`cameraDirection`，而 App 端 `photo_template.dart` 已支持 → 今天 AI 模板无法携带补光灯 |
| 热点 | 无任何爬取/搜索能力 | 无「前沿性/潮流性」来源 |

> 补充确认的依据文件：
> - 草稿归一化白名单：`normalize.ts`（postProcess 只收 color/smooth/sharpen/vignette/grain/lut，**不收 fillLight/legStretch**）
> - App 模型能力：`lumira_app_flutter/lib/features/capture/domain/photo_template.dart`（`PostProcess.fillLight`、`legStretch`、`CameraParams.iso/isoMode/lensSuggestion`、`Pose.cameraDirection` 均已序列化）

---

## 二、目标架构：文本模型为中枢的 Agentic Harness

```
用户指令 + 参考图(可选)
        │
        ▼
┌─────────────────────────────────────────────────────────────┐
│              AI_ORCHESTRATOR  Harness（后端 NestJS）          │
│                                                             │
│  ①  Context 组装（System Prompt + 参数契约 + 少样本 + 用户输入）│
│  ②  Agent Loop：文本大模型(中枢)  ←→  Tool Registry(函数调用)  │
│        │ loop 每轮：模型 decide → call tool → 观察结果 → 再 plan│
│        ▼                                                      │
│  Tools（MCP 风格，类型化 tool definition）：                  │
│   T1  trendResearch  热点研究（抖音/小红书/权威摄影穿搭网站）     │
│   T2  imageDescribe  图片识别 → 结构化文本描述（视觉模型）       │
│   T3  poseRefSheet   姿势参考面片生成（人设/时长/角度/参数对齐）  │
│   T4  imageGenerate  封面/姿势图生图（多候选 + 子择优）          │
│   T5  paramValidate  参数-App效果校验（校准器）                 │
│   T6  imageScore     LLM-as-Judge 评分（质量/一致性闸门）        │
│                                                             │
│  ③  收束：模型产出「最终模板 JSON」→ 扩展 normalize（补光灯等）  │
└─────────────────────────────────────────────────────────────┘
        │
        ▼
  成品模板（含 fillLight / legStretch / cameraDirection / pose 面片）
        │
        ▼
  后台向导渲染 + 入库
```

### 为什么以「文本模型」为中枢
- 文本大模型具备**多步推理 + 计划 + 判定**能力（与用户设想一致，它是 CPU）。
- 图片识别（视觉）、生图、爬取均为**可被调用的工具**，各自只做单点任务、结果回传中枢决策。
- 视觉模型/生图模型可作为各自独立的 `LlmEndpoint` 配置（现有 `ai_config` 已支持分平台，无需新架构）。

---

## 三、六个工具设计（Tool Registry）

> 复用现有能力，新增部分保持 OpenAI 兼容（qwen/doubao/zhipu 已支持 `tools` 函数调用；扩展 `llm-client.ts` 支持 `tool_calls` 往返 + 结构化工具结果）。

### T1 · trendResearch —— 热点/前沿研究（本次最核心新增）
- **职责**：给定创作意图与主题，从多源抓取「最新 + 最火」的摄影/穿搭/氛围素材与图片，返回结构化研究简报（可溯源）。
- **来源优先级**（可配置、可开关）：
  1. **实时社交**（优先级高，内容受用户喜爱、时令性强）：抖音（公开话题/热门），小红书（笔记搜索）。走公开可爬的搜索/详情接口，尊重 robots/ToS、限速、SDK 密钥可配。
  2. **权威专业站**（保证专业性/美感/独特性）：站酷、500px、视觉中国、图虫、Pinterest（穿搭）、专业摄影博客、当季趋势主页（如 VOGUE 穿搭趋势、小红书官方风格页）。
- **实现**：`WebSearchProvider` 抽象接口 + 适配器（bing-search / baidu / serpapi / 直连 source）。统一输出 `ResearchItem { source, title, snippet, keywords[], imgUrl?, popularity?, date, url }`。
- **工程约束**：进程内 LRU 缓存（键=查询+来源+日）、超时、并发限流、失败优雅降级（单源挂掉跳过）、可观测日志。
- **图片副产物**：命中且带图的条目 → 进入 `imageJobs` 队列，交给 T2 识别。

### T2 · imageDescribe —— 穷尽式图片识别（视觉模型 VLM）
**核心原则：穷尽式（exhaustive）描述，任何信息不省略、不概括成"大概/一些"。**
要求识别模型像"专业摄影师 + 检察官"一样逐区格扫描，把一张图的所有信息尽可能完整抽成结构化文本，供中枢做参数对齐与姿势生成；识别信息越细，后面生图一致性才越高。

- **职责**：对参考图 / 爬取图中任一张，产出**全程可反查的穷尽式结构化描述**。
- **复用**：现有 `visionChat` 保留；新增「穷尽式研究图描述」专用 system prompt，**与普通描述分开**（预算更高、token 上限更高、禁止用"等/等等/大概/类似"这类省略词）。
- **识别网格（GraphOverlay 协议）**：先把图像按九宫格 + 中心放大格做区域标注，识别模型对**每个格子**分别回答，保证无盲区、不遗漏角落细节。
- **输出 Schema（扩展，字段全必填，无信息则显式写 `unknown`**）：
  ```
  ImageDescription {
    global: {
      subject,                // 拍摄主体(人/动物/静物/建筑/风景) + 主体质量+状态
      mood,                   // 氛围基调（温暖慵懒/清冷高级/复古胶片…）
      season, timeOfDay,      // 季节 + 时段（决定曝光/K/POSE 语境）
      palette,                // 全局色板：占主导的3~5个色(hex) + 冷暖倾向 + 明度分布
      light: {                // 光源细节
        dir, kind,            // 方向(顶/侧/逆/顺) + 类型(自然/窗光/灯/混合)
        colorTemp, tone,      // 冷暖 + 通透度(雾/晴朗/阴)
        contrast, key,        // 对比度 + 明调/中间调/暗调
        softness, shadowDir   // 软硬 + 影子方向（用于补光灯/阴影方向推断）
      },
      composition: {          // 构图信息（逐项）
        ruleOfThirds, leadLines, framing, },  // 三分线/引导线/框式/对称中心
        subjectFrame, cropRatio,               // 主体外接框(相对画面) + 比例
        negativeSpace, depthOfField           // 留白 + 景深(浅中深)
      },
      reproducibility: {      // 本图是否可被手机实拍复现 + 复现建议
        level,                // high/medium/low + 原因(是否需要补光/能否在手机复现光线)
        enableFillLight, lightHint
      }
    },
    people: [{                // 每个人物（人像必有）
      role,                   // 主体/陪衬
      face: { expression, gazeDir, headTilt, angle, openMouth }, // 表情/视线/头倾/朝向
      body: { posture, shoulders, hips, legStretchSuggest },      // 躯干/肩/胯 姿态
      limbs: { armL, armR, handL, handR, legL, legR, weightShift },
      outfit: {               // 穿搭逐件拆分
        top: { type, length, color, material, sleeve, neckline, fit },
        bottom: { type, length, color, material, fit },   + shoes + accessory{s} + hair{style,color}
      },
      anchors: { positionInFrame, scaleRatio, rotationDegree },  // 落地到 subjectFrame 的锚点
      lightOnPerson: { dir, keyVsFill, faceShadow }              // 脸上光影→补光灯/侧光推断
    }],
    scene: {
      location, depthLayers,   // 地点 + 前/中/背景的元素清单（每层 panel 描述）
      props, furniture,       // 关键道具/家居（位置+作用）
      texture, cleanliness    // 纹理 + 干净程度（决定磨皮/锐化要不要、参数大小）
    },
    cameraLike: {             // 场景/光线反推的"拍摄参数建议"（供 paramValidate 对账）
      lightSuggestion,        // 补光灯开/关 + 颜色 + 强度建议
      wbSuggestion, evSuggestion, focusDepth  // 只在可推断时给；否则 unknown
    }
  }
  ```
- **多图汇总**：同一模板可能识别多张参考图 → 中枢把多份 `ImageDescription` 去重/合并/投票出**一致性高的锚点（anchor）**，弱一致项降权，避免互相矛盾。
- **输出给下游**：作为 T1/T3/生成 prompt 的"事实层"，并对 T4/T6 反向校验作比对基准。

### T3 · poseRefSheet —— 姿势参考面片生成（保证姿势图真实感）
- **核心动机**：让「姿势图尽可能真实、有美感、风格质感、且参数匹配」；**姿势图是模板"能不能拍出那个感觉"的最关键落点，因此每个姿势都要逐项细化**。
- 中枢基于「用户的姿势要求 + T1 研究 + T2 识别的 `people`/`pose` 细节 + T5 参数」产出**每个姿势的参考面片**：
  ```
  poseRefSheet {
    shared: {                      // ★ 跨姿势共享锚点（同一模板所有姿势必须一致）
      outfit,                      // 统一穿搭（逐件：类型/长度/色块/材质/版型）← 来自 T2 outfit 投票
      scene,                       // 统一场景（前/中/背景逐层）
      light,                       // 统一光线（方向/类型/色温/软硬）
      aspectRatio, mood, palette   // 统一比例 / 氛围 / 色板
    },
    perPose: [{                    // 每姿势只允许差异项：动作 / 机位 / 框位
      name,                        // 姿势名（如「侧身回眸」）
      subjectPose: {               // 逐部位精确（供生图/剪影一一执行）
        torso/shoulder/hip,        // 躯干朝向、肩胯连线、重心落腿
        head: { tilt, rotation, gazeDir, expression },   // 头倾/旋转/视线/表情
        armLR/handLR, legLR,       // 每条肢体 + 手部动作（握持/撑腿/叉腰…）
        weightShift, naturalMotion // 重心转移 + 动态感（静止/微动/转身…）
      },
      camera: { angle, distance, lensSuggestion, height }, // 机位高度/角度/焦距
      frame: { subjectFrame, position, scale, rotation },  // 与 composition 锚点一致
      lightOnPose: { dir, keyVsFill, enableFillLight, fillColor },  // 补光灯按机位可微调
      differentiationNote          // ★ 本姿势与其他姿势的差异说明（保证多姿势不雷同）
    }]
  }
  ```
- **跨姿势一致性铁律**：同模板内多姿势**共享 `shared` 锚点**（穿搭/场景/光线/比例不变），只有动作、机位、框位在变——这是"同一模板"的语义底线；同时姿势之间必须有**差异度**（T6 增加「姿势间区分度」评分项），避免生成四个雷同姿势。
- 该面片**同时喂给**：① `imageGenerate` 生姿势图（作为强约束）；② 剪影引擎（`ai-generate-silhouette`）生成分割线稿，保证姿势与描述一一对应。
- **后置**：对姿势图反向 `imageDescribe` 校验「每项是否忠于面片」→ 逐项打分，不满足则附修正意见重生成（纳入 T6/T3 循环）。
- **可复现约束**：面片里只允许出现 App 实拍能呈现的姿势/光线/构图，凡涉及补光/角度/比例，必须与 `fillLight`/`subjectFrame`/`aspectRatio` 数值自洽。

### T4 · imageGenerate —— 极致一致性生图（多候选 + 择优）
**核心原则：生成 prompt 与识别信息双向强约束，让"生成图"尽可能== "模板理想实拍图"。**
- **prompt 来源（反哺闭环）**：`buildImagePrompt` 不再只凭草稿；而是把 **T2 穷尽识别(原始像素事实) + T3 姿势面片(姿势事实) + T5 参数(落地数值) 三重信息**映射成细粒度提示词。
- **细节强度**：prompt 按 T2 的层级填入——
  - **人物**：精确到表情、视线方向、头倾角、肩胯朝向、双臂/双腿/手部/重心每一个动作项（非"一个女生叉腰"这类粗描述）。
  - **穿搭**：逐件拆分（上装/下装/鞋/配饰/发型），每件含类型/长度/用色/材质/版型。
  - **光线/氛围**：光源方向/类型/色温/软硬/影子方向/明暗调用词 → 与补光灯、K、EV 对齐。
  - **构图**：三分线/引导线/景深/留白/主体外接框比例 → 与 `subjectFrame`/`cropRatio`/`aspectRatio` 一致。
  - **场景**：前/中/背景逐层 panel 描述 + 道具/纹理。
- **一致性硬约束（写在 prompt 首部的指令）**：仅允许"可被手机复现"的光线/场景/景深；禁止引入参考图没有的元素；负面词补全（防畸变/重复脸/塑料感/额外人物/乱入道具）。
- **伸展通道**：生成图与 `ImageDescription` 的锚点做**像素级反查**（逆向 T2），超阈值差异 → 打回 + 附修正意见重生成。
- **复用收益**：同 prompt 出 N 个候选（seed 变化，`image-client.generateImage` 复用）→ `imageScore` 择优，杜绝运气式盲选。

### T5 · paramValidate —— 参数—App 效果校准器（保证实拍≈期望）
- **职责**：把生成的数字参数校验到「App 实际会怎样呈现」的语义上，规避"看着对、落不了地"。
- **对账表**（以 App 实际控件/模型为准，见 `enums.ts` + `photo_template.dart`）：
  | App 实拍能力 | 校验点 |
  | --- | --- |
  | EV `-3~3`、ISO `auto/manual`、快门 | 手滑数值合理性、与 WB/EV 自洽 |
  | WB 预设+ `whiteBalanceK 2000~10000` | 偏暖→K~5500+ / 暗部→曝光补正自洽 |
  | `fillLight{enabled,color,intensity}` | **新增支持**：暗部/夜景模板默认开 + 推荐色温色 + 强度 |
  | 构图 `overlayType/aspectRatio/opacity/subjectFrame` | 与主题（人像/街拍/食物）匹配、subjectFrame 落在人像合理框 |
  | 后期 `color7轴 + smooth/sharpen/vignette/grain/lut` | 与 LUT 色板不自相矛盾、值域合理 |
  | 照片比例（全屏/3:4/4:3/16:9/1:1/9:16） | 与构图/场景匹配 |
  | `legStretch` | 仅人像全身/半身模板给 >0 |
- **实现**：参数归一化层扩展 + 一组规则 + 可选一次 LLM 复核（`paramValidate` 二段：规则初筛 → 模型修正）。**所有数值最终仍过 `normalizeDraft` 夹取**，保证绝不越界。

### T6 · imageScore —— LLM-as-Judge 质量/一致性闸门
- **职责**：对封面图/姿势图/最终模板打分并给可执行反馈，驱动 retry loop。
- **评分维度**：与参考/意图**逐项一致性**（把生成图再走一次 T2 识别，对比原始 `ImageDescription` 每个字段——人物动作/表情/穿搭、光线/色温、构图锚点、场景逐层——出来差异清单 itemByItem）、风格成熟度、审美、物理合理性（肢体/光影/纹理）、参数与图像自洽、**可实拍复现度**（画面里是否有手机拍不出的东西）。
- **输出**：`{ score, verdict: pass|retry, reasons[], suggests[] }`。
- **闸门**：低于阈值 → 原始 `decisions`（研究/姿势面片）微调后重跑（有迭代上限）。

---

## 四、Agent Loop（harness · context · prompt · loop）

### 4.1 · Context 组装（每次进入 loop 前动态组装）
```
[SystemPrompt]＝角色(资深摄影/时尚编辑) + 参数契约(JSON Schema) + 少样本(3~5 份已知优质模板作示例) + 行为约束
[UserPrompt] ＝用户原始指令 + 参考图压缩描述(已由 T2 预处理，不塞原图进文本循环) 
[Progress]    ＝已研究摘要 + 已生成候选 + 校验报告（每轮追加的"工作记忆"）
[ToolSchema]  ＝T1~T6 的类型化 tool definitions（转成 tool_calls）
```

### 4.2 · Prompt 分层策略（版本化 + 可观测）
- **契约层**：扩展 `DRAFT_JSON_EXAMPLE`，新增 `fillLight` / `legStretch` / `cameraDirection` / `poseRefSheet`，并对每个枚举给「App 实际效果语义」注释（让模型理解数值落地到实拍的效果）。
- **角色层**：`analyze.prompt.ts` 收敛为「研究→决策小模型共用」的中枢 prompt；`image-prompt.builder` / `prompt-polisher` 保留为 T4 内部工具。
- **少样本库**：内置目录里挑 3~5 份「同主题、高质」模板（`lumira_app_flutter/lib/features/capture/data/templates/*.dart`）转成示例，提升格式与风格稳定性。
- System prompt 版本号写入 DB/日志，便于 A/B。

### 4.3 · loop 终止条件
- 达到质量分（T6 ≥ 阈值）→ **pass 收束**
- 达到最大迭代（默认 2~3 轮）→ 取最佳候选并 `warnings` 标注
- 任意工具连续失败 N 次 → 该工具降级（爬取失败→仅用 T2/T4；生图失败→跳过择优）
- 全程可观测：每轮 `{step, tool, action, latency, resultBrief, score}` 写入任务日志（供后台展示研究与校验过程）。

### 4.4 · 中枢行为纪律（Plan → Execute → Synthesize + 反思定稿）
- **先计划后执行**：中枢进入 loop 前必须先产出「研究计划」——研究哪些主题词/来源、需要识别几张参考图、姿势方向候选有哪些——避免盲目乱爬浪费轮次。
- **执行后综合**：工具结果回传后必须「综合定稿」，而非边走边拼碎片。
- **反思步（Reflection before finalize）**：定稿前中枢自查——契约字段齐全？参数与研究/姿势面片自洽？多姿势共享锚点且有差异度？元数据（名称/描述/关键词/sceneGuide/难度）质量达标？review 记录随 traceId 落库。
- **结构化输出强制**：最终模板与各工具返回一律走「JSON Schema / tool 约束的结构化输出」（qwen/doubao/gemini 均支持），**禁止自由文本 + 正则解析**，解析失败率压到 ≈0。
- **自洽性采样（Self-consistency）**：关键数值决策（相机/色彩参数）可并行采样 N 次取中位数/多数投票，压单次幻觉。

---

## 五、对既有资产的兼容与最小改动

| 资产 | 改动策略 |
| --- | --- |
| `llm-client.ts` | 扩展支持 `tools`/`tool_choice`/`tool_calls` 往返；**保留** `visionChat`/`textChat` 对外签名（向后兼容） |
| `ai-config.service.ts` | 新增工具相关端点（可选）：爬取服务商/密钥、研究开关、迭代上限；现有 vision/text/image 不动 |
| `normalize.ts` / `analyze.prompt.ts` | **扩展**契约与归一化，新增 `fillLight`/`legStretch`/`cameraDirection`/`poseRefSheet`；**不改变**既有枚举校验口径 |
| `ai-generate-image / ai-silhouette` | 保留既有能力，作为 T4/剪影的底层；T3 姿势面片新增喂入 |
| 后台向导 `wizard.tsx` | 新增「研究来源/过程/质量分」展示区；模板表单因契约扩展自动出现补光灯等字段（沿用已有 `TemplateForm`） |
| App 端 Flutter | **零改动**（参数模型已支持） |

---

## 六、落地路径（分阶段任务分解，建议按序实施）

> 遵循本项目 AGENTS.md：后端/后台每次完成后 commit 并**同时 push 双远程**（origin=gitee, github）；Flutter 零改动。测试命令在 `lumira-server/` 下执行。

### P1 · 打通「中枢 + 工具」骨架（价值最大、可独立交付）
- **T1-P1**：扩展 `llm-client.ts` 支持函数调用往返（tools/tool_calls），纯函数 + 单测。
- **T1-P2**：`WebSearchProvider` 抽象 + 至少一个可用适配器（如 bing/baidu 搜索）+ 缓存/限速/降级/日志；`trendResearch` 服务接入，产出 `ResearchItem[]`；中小型 e2e 打通。
- **T1-P3**：中枢 `AiOrchestratorService`：context 组装 + loop（调用 T1→T2→T4→T6，先跑通「研究→识别→生图→校验」单条链路，固定 1 姿势、迭代上限 1）。
- **T1-P4**：契约扩展 `fillLight/legStretch/cameraDirection` + `normalize` + admin 表单字段（后台无需新表，复用既有模板 JSON 列）。
- **交付**：仍走 `POST admin/templates/ai-analyze` + 现有异步任务；后台新增流程可视化（研究源/过程/分）暂以日志 + 简易展示。

### P2 · 质量强化（姿势面片 + 参数校准 + 迭代择优 + 度量基建）
- **T2**：穷尽式 `imageDescribe`（九宫格网格 + 全字段 schema + 禁止省略词）实现 + 研究图批量识别（图片队列）；参考图也走同一穷尽识别。
- **T3**：`poseRefSheet`（**shared 共享锚点 + perPose 差异项**）生成 + 喂入生图与剪影；姿势图反向逐项校验重生成。
- **T4-P5**：multi-source prompt（识别+姿势面片+参数 三重）入 `buildImagePrompt`；多候选生图 + `imageScore` 择优；negative prompt 补充（防肢体/塑料感/重复脸/乱入元素）；图像锚点像素级反查。
- **T5**：`paramValidate` 规则层 + 对账表落地 + 模型复核；确保实拍≈期望。
- **T6**：LLM-as-Judge 完整评分（含逐项一致性差异清单、姿势间区分度、元数据质量、可实拍复现度）与 retry 循环（迭代上限 2~3、decisions 微调）。
- **质量基建（9.1 + 4.4）**：结构化输出强制 + 自洽性采样 + 反思步；**Golden Set + 每夜回归管线 + 质量门禁**——P2 起所有 prompt 改动必须带 golden set 分数对比。

### P3 · 平台化、知识沉淀与人工复核
- 抖音/小红书适配器接入（验证公开通道可行性，失败则降级权威站）。
- **趋势索引（新鲜度衰减）+ 姿势库 + 失败案例库**（9.3）：研究结果资产化，质量随使用量复利。
- **人工复核队列（9.6）**：AI 生成 → 待审 → 发布；并排对比 + 局部重生成；结论回流失败案例库。
- **查重闸门（9.4）+ 内容安全（9.5）**：防同质化 + 参考图/生成图安全复核。
- 后台 AI 设置新增工具开关/来源启停/密钥/迭代上限/模型选型矩阵与降级链（9.7）；研究过程与质量分可视化。
- `provider` 预留给 dify/coze 工作流（已有字段）作为可选项。

### P4 · 实拍闭环（终极验证，与 P3 可并行）
- **服务端渲染近似管线**（9.2）：sharp 复刻 App `PostProcess` 近似渲染 + 补光色罩 → 理想参考图过管线 → 参数自动微调（T5 动态校准段）。
- **真机抽检流程 + 偏差量化**：色彩 ΔE / 构图 IoU / 氛围评分回流，形成「模板→实拍」偏差基线。
- **成本与时延预算护栏 + traceId 全链路 A/B**（9.8）。

---

## 七、风险与对策

| 风险 | 对策 |
| --- | --- |
| 社交平台搜索/爬取不可用（反爬/合规） | WebSearchProvider 多适配器 + 权威站兜底 + 优雅降级；全部可开关 |
| 函数调用增加延迟/成本 | 迭代上限 + 单轮超时 + 进程内 LRU 缓存（研究/识别/润色结果按哈希缓存）+ 预算护栏（超限取最佳收束） |
| 生成数值与 App 实拍偏差 | T5 参数校准器（规则 + 渲染近似动态校准）+ normalize 夹取 + 真机抽检偏差回流 |
| 姿势图与模板不一致 | T3 姿势面片 + 反向识别校验 + 重生成闸门 |
| LLM-as-Judge 与人评漂移/自我偏好 | T6 用与中枢不同模型 + 每月人评校准（9.1） |
| AI 批量产同质模板 | 查重闸门 + 差异化重生成（9.4） |
| 内容安全/肖像风险 | 参考图+生成图安全复核 100% 覆盖（9.5） |
| prompt 改动引入质量回退 | Golden Set 回归门禁：分数下降即阻塞（9.1） |
| 存量枚举/契约破坏 | 只做**扩展**（新增字段），不删不改既有 key；向后兼容 |

---

## 八、验收标准（可量化）

1. **热点**：同意图下，开启研究后的模板 keyword/季节/主题显著贴近"当季爆款"（人工抽查命中率 ≥ 一定比例）。
2. **参数落地**：生成模板 JSON 100% 过 `normalizeDraft` 且含 `fillLight`（暗部/夜景场景默认开）；在 App 套用后实拍与一张同场景实拍参考图观感偏差明显收敛。
3. **姿势真实**：姿势图提出后**再走一次 T2**，与 `poseRefSheet` 在人物动作/表情/穿搭/机位/光影五项上逐项一致性评分 ≥ 阈值。
4. **识别穷尽**：T2 输出字段完整率 ≥ 某阈值（无 `unknown` 可避免项），九宫格各格均产描述、无跳格遗漏。
5. **生成一致**：封面/姿势图经像素级锚点反查 + T6 逐项差异清单，可实拍复现度 ≥ 阈值（画面不含手机排不出的元素）。
6. **稳定**：全程无例外抛出（工具失败均进降级分支）；后台可见研究源与质量分。
7. **回归门禁**：golden set 上质量分不回退；prompt/模型/工具任何变更必须带新旧分数对比，下降即阻塞。
8. **实拍偏差**：抽样真机实拍 vs 封面期望——色彩 ΔE 与构图 IoU（subjectFrame vs 实拍主体框）落在基线区间内。
9. **防同质**：新模板与库内既有模板语义相似度低于阈值；同模板多姿势区分度 ≥ 阈值。
10. **安全**：参考图/生成图安全复核 100% 覆盖（NSFW/敏感/肖像提示）。

---

## 九、质量保障体系（第二轮查漏补缺 · 唯一目标：模板极高质量）

> AI 模板生成是本项目**最高优先级功能**，一切取舍以模板质量为先。本章补齐前八章未覆盖的质量基建——**没有度量就没有优化，没有闭环就没有保证**。质量优先原则：本功能为后台生成（非实时链路），允许更长生成时长（单模板 3~10 分钟）、更高 token 成本、多候选多轮迭代，换取极致质量。

### 9.1 · 黄金测试集与回归门禁（度量先行，最高优先缺口）
- **Golden Set**：30~50 个典型创作意图（含「初秋女生人像四种姿势」这类**季节+人群+姿势数**的真实输入）+ 参考图 + 期望要点清单（应命中关键词/参数区间/姿势数量/风格锚点）。
- **自动回归管线**：每夜对 golden set 跑全流程 → T6 评分 + 参数校验 + 姿势一致性 → 质量看板；**prompt/模型/工具任何改动必须在 golden set 上跑分，分数下降即阻塞上线**。
- **人评校准**：每月抽样人工盲评，校准 LLM-as-Judge 与人评的相关性，防止裁判模型自我偏好/漂移（T6 用与中枢不同的模型，避免同源偏好）。

### 9.2 · 实拍闭环（「套用后≈理想」的终极验证）
T5 规则只能静态推断，真正保证 App 实拍贴近期望必须闭环：
- **服务端渲染近似管线**：后端用 sharp 复刻 App `PostProcess` 的**近似渲染**（色彩7轴/磨皮/锐化/暗角/颗粒/LUT 映射 + 补光灯色罩叠加）→ 把「理想参考图」喂进管线，检验「参数能否把接近的底图变成期望效果」→ 偏差大则参数自动微调（构成 T5 的**动态校准段**，与规则层互补）。
- **真机抽检**：每批 AI 模板抽样 → 真机按模板实拍 → 与封面/期望对比 → 偏差数据回流，持续修正对账表与渲染近似的映射。
- **偏差量化指标**：色彩 ΔE、构图 IoU（subjectFrame vs 实拍主体框）、氛围评分，形成「模板→实拍」偏差基线，作为长期质量北极星。

### 9.3 · 知识沉淀（越用越准，质量随使用量复利）
- **趋势索引（Trend Index）**：T1 结果按「主题×季节×来源」入库；**新鲜度衰减**（>7 天降权，命中陈旧数据时触发增量爬取）——研究从一次性成本变为滚动资产。
- **姿势库**：高分姿势面片+姿势图入库，后续生成可复用/做变体；姿势质量随使用量滚动提升。
- **失败案例库**：T6 打回原因 + 人工复核打回原因归档 → 注入中枢 prompt 的「避免清单」，同类错误不再重犯。

### 9.4 · 防同质化与元数据质量
- **查重闸门**：与库内既有模板做语义相似度比对（关键词+参数向量+姿势面片）→ 相似度过高则要求**差异化重生成**，防止 AI 批量产同质模板稀释模板库。
- **元数据质量**：模板名/描述/关键词/sceneGuide/难度分级**纳入 T6 评分维度**——对最终用户的可读性与可搜索性也是质量的一部分（App 端搜索/推荐直接依赖）。

### 9.5 · 内容安全与合规
- 参考图安全检查（NSFW/敏感内容）先行；生成图（封面/姿势图）安全复核纳入 T6 检查项；参考图含真实人脸时提示肖像权授权。

### 9.6 · 人工复核工作流（发布前最后闸门）
- Admin 增加「**AI 生成 → 待审 → 发布**」队列：参考图 vs 生成封面**并排对比**、T6 逐项差异清单可视化、**局部重生成**（只重跑某个姿势/封面，不整单重跑）。
- 复核结论（通过/打回原因）回流失败案例库。
- 放行策略：初期全部人工审；质量稳定后按 T6 分数**自动放行高分、低分进人工**，逐步减少人力但保留兜底。

### 9.7 · 模型选型矩阵与降级链（后台可配）
| 阶段 | 选型要求 | 备选降级触发 |
| --- | --- | --- |
| 中枢（文本） | 强推理 + 原生函数调用 | 超时/连续结构化解析失败 → 降级备选模型 |
| T2 识别 | 高细节长上下文 VLM | 同上 |
| T4 生图 | 现有 image provider（支持参考图/seed） | 生成失败或候选全低分 → 备选 provider |
| T6 评分 | **与中枢不同的模型**（避免同源偏好） | - |

### 9.8 · 成本与时延预算（质量优先下的护栏）
- 各阶段 token/时延预算表 + 总预算；超限时「取当前最佳候选收束」，绝不无限迭代烧钱。
- 全链路 traceId：每步记录 模型/版本/prompt 版本/耗时/token/分数 落库；支持同一 golden set 上 A/B 对比新旧 prompt 得分，让每次"改 prompt 提质量"都有数据依据。