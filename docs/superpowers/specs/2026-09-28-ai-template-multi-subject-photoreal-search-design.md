# AI 一键生成模板：多人物支持 / 去噪高清写实 / 搜索内容落地姿势图

- 日期：2026-09-28
- 范围：`lumira-server/packages/backend`（主）+ `lumira-server/packages/admin`（少量）+ `deploy/searxng`
- 关联：`2026-09-21-ai-template-trend-orchestrator-design.md`、`2026-09-24-ai-llm-raw-trace-design.md`、`2026-09-28-ai-template-aesthetics-style-profile-design.md`
- Flutter 端：不涉及

---

## 1. 背景与问题

后台「AI 一键生成模板」当前存在四类问题：

1. **人像只能有一个人物**。生图提示词在单姿势模式下无条件拼接「画面中只有一个人物」（`image-prompt.composer.ts` L353、`image-prompt.builder.ts` L231-238），识别契约示例与一致性硬约束也都按单人写。情侣照、全家福、多人聚餐等场景无法正确生成。
2. **人物质感与光影不真实**。提示词把人写成「肤色不均匀、T 区油光、黑眼圈、碎发」的缺陷集合，而非高清写实的细节分辨力。
3. **gpt-image2 噪点严重**。三处提示词源在主动要求噪点：
   - `image-client.ts` L162-167 `ENGLISH_PHOTOREAL_ANCHOR` 含 `slight sensor noise`，对所有 gpt-image 家族无条件追加；
   - `image-prompt.builder.ts` L217-219 / `image-prompt.composer.ts` L305-307：`postProcess.grain > 0` 即写「带轻微/明显颗粒感」，而识别契约示例 `grain: 18`，实际几乎总非零；
   - `image-prompt.composer.ts` L344-345 强制写「弱光场景用高 ISO，画面带自然噪点」。
4. **联网搜索结果未真正用于姿势图生成**。生图阶段只用 `buildResearchLines(items)` 的 `title:snippet` 原文（`image-prompt.composer.ts` L285-290）；结构化趋势结论 `ResearchBrief`（含 `poseIdeas` / `colorLight` / `visualElements`）既未回传前端、也未透传到生图。检索源也未限定到小红书/抖音等社交平台。

## 2. 目标与非目标

### 目标

- 支持 1 / 2 / 3+ 人物场景，AI 自动推断 + 可在 Step3 手动覆盖。
- 彻底移除提示词中的噪点/颗粒/瑕疵要求，转向高清干净写实。
- 把结构化趋势结论（`ResearchBrief`）透传到姿势图生成提示词，并接入社交平台站点限定检索。
- （期2）从社交平台检索图片，做纯视觉识别转文字，反哺姿势图生成；用后删除临时图片。

### 非目标

- 不改动 Flutter 端。
- 不把平台图片作为 img2img 参考图（规避版权/相似风险）。
- 不新增第三方图片存储；期2 只用临时目录且必删。
- 不重构 orchestrator 主流程骨架。

---

## 3. 期 1：人物数量 + 去噪写实 + 搜索内容落地

### 3.1 A. 多人物支持

#### A1. 数据字段

新增草稿字段 `meta.subjectCount`：

- 类型：整数，取值 `1..8`，缺省 `1`。
- 语义：画面中的主要人物数量。`1`=单人；`2`=情侣/双人；`3+`=全家福/闺蜜团/聚餐合影。
- 由 AI 从用户描述（文字/创作要求）与参考图推断；Step3 允许人工覆盖。

**`normalize.ts`**（`src/modules/ai/normalize.ts`）：

- `meta` 是白名单构建（L247-321），必须显式放行 `subjectCount`，否则被丢弃。
- 用 `setClampField(meta, 'subjectCount', rawMeta.subjectCount, 1, 8, 'meta.subjectCount', warnings)` 做整数夹取；缺失/非法时回落 `1` 并写一条 warning（`未提供 meta.subjectCount，已按 1 人处理`）。

#### A2. 识别侧（`analyze.prompt.ts`）

- `DRAFT_JSON_EXAMPLE` 的 `meta` 增加 `"subjectCount": 1`，注释说明取值口径与推断依据（情侣/结婚/闺蜜/全家福/聚餐等场景应 ≥2）。
- 硬约束新增一条：`meta.subjectCount 必须根据用户描述或参考图中实际可见的人物数量给出；出现「情侣/结婚/闺蜜/全家福/合影/聚餐/多人」等场景时不得写 1`。
- `poseConsistencyLine`（L157-164）人像分支改为**按人数分档**：
  - `subjectCount === 1`：保持原文（不得改变人物长相、服装、发型、体型、场景、道具、光线或整体风格）。
  - `subjectCount >= 2`：改为「多姿势模板默认视为同一组人物的同一套连续拍摄：每个 pose.description 只描述动作、身体角度、重心、手部、视线与**人物之间的相对位置/互动关系**差异；不得改变每位人物的长相、服装、发型，也不得改变人物数量、身高差与互动关系」。
  - 该分档依赖 `subjectCount`，而 `buildSystemPromptBody` 目前只有 `categories` + `styleProfile` 入参。实现上：把 `subjectCount` 作为 `styleProfile` 之外的可选参数从 `ai-analyze.service.ts` 传入；识别阶段尚无草稿，故用**用户文字/创作要求的关键词**做一次轻量预判（`inferSubjectCountHint(text, creationReq)`，命中 `情侣/结婚/婚纱/闺蜜/全家福/合影/聚餐/多人/双人/一对` 等词返回 `>=2`，否则返回 `1`），仅用于措辞分档，最终值仍以模型输出为准。

#### A3. 生图侧

**`image-prompt.builder.ts`**：

- 新增纯函数 `describeSubjectCount(n: number): string`：
  - `n <= 1` → `画面中只有一位人物`
  - `n === 2` → `画面中有两位人物（如情侣/同伴），注意两人之间的距离与互动关系`
  - `n >= 3` → `画面中有 ${n} 位人物（如全家福/朋友合影），注意站位层次与相互呼应`
- 替换 L231-238 `isSinglePose` 分支中的「画面中只有一个人物…」，改为 `segments.push(describeSubjectCount(subjectCount))` 后再拼「只呈现姿势…」；「不要合并多个姿势/多宫格」保留。
- L265-281 portrait 瑕疵句重写（见 B 节）。

**`image-prompt.composer.ts`**：

- `COMPOSE_SYSTEM_PROMPT` L27 系统角色从写死「顶级人像摄影艺术指导」改为按一级大类派生：
  `你是顶级${主体类型}摄影艺术指导兼生图提示词工程师`，其中主体类型由 `CATEGORY_SUBJECT_LABELS[categoryKey]` 取得。`buildComposeSystemPrompt(categoryKey?)` 增加可选参数；`composeImagePrompt` 调用处从 `input.draft` 解析出 `categoryKey` 后传入。
- L352-362 的「画面中只有一个人物」改为 `- ${describeSubjectCount(subjectCount)}，只呈现上述「本张姿势」；不要合并多个姿势…`。
- 一致性行 L356-360 按人数分档（≥2 时改为「多位人物各自的长相、服装、发型，以及人物之间的相对位置与互动保持一致」）。
- `buildPromptMaterial` 的【模板基本信息】增加一行 `- 画面主体人数：${n}（${单人/双人/合影}）`。
- L348 portrait 瑕疵句重写（见 B 节）。

#### A4. 前端（admin）

- Step3 草稿编辑区新增「人物数量」选择控件（选项：`1 人` / `2 人` / `3 人以上`，`3+` 映射为 `3`，并允许数字覆盖）。默认显示识别推断值 `meta.subjectCount`。
- 修改后写回草稿 `meta.subjectCount`，随 `fd.set('meta', ...)`（`admin/src/lib/ai-task.ts` L76-79）透传，无需改后端生图接口。

### 3.2 B. 去噪 + 高清写实

统一取向：**高清干净写实**——删除全部噪点/颗粒/瑕疵要求，改为「细节分辨力 + 光影层次 + 真实材质」。

#### B1. `image-client.ts` L162-167（噪点根因 #1）

`ENGLISH_PHOTOREAL_ANCHOR` 改写为：

```
Photorealistic photograph taken with a real camera: highly detailed realistic skin texture with visible pores and fine vellus hair in sharp focus; distinguishable fabric fibers and weave; individual strands of hair; directional natural light with realistic falloff and layered shadow transitions; clean and crisp image with controlled noise and no grain. Strictly not anime, not illustration, not painting, not 3D render, not AI-retouched; no airbrushed or plastic skin.
```

- 删除 `slight sensor noise`、`candid imperfect framing`。
- 删除 `subtle oily shine and uneven skin tone`。

#### B2. `grain > 0` 分支（噪点根因 #2）

- `image-prompt.builder.ts` L217-220：删除 `grain` 段与 `GRAIN_STRONG_THRESHOLD` 常量（若无其他引用）。
- `image-prompt.composer.ts` L305-308：删除 `grain` 参数行。
- 识别契约示例 `analyze.prompt.ts` L144 的 `"grain": 18` 改为 `"grain": 0`，并加注释「grain 仅作为 App 后期参数保留，不写入生图提示词」。

#### B3. 强制噪点句（噪点根因 #3）

`image-prompt.composer.ts` L342-346 两条 `必须写入具体摄影参数` 改为：

- 自拍：`- 必须写入具体摄影参数：前置摄像头等效焦距与光圈、快门与感光度、白平衡轻微偏移；弱光场景下要求画面干净、细节不糊、噪点受控`
- 他拍：`- 必须写入具体摄影参数：镜头与光圈（如 85mm f/1.8 浅景深或手机主摄直出）、快门与感光度、白平衡轻微偏移；弱光场景下要求画面干净、细节不糊、噪点受控`

#### B4. 瑕疵句 → 细节分辨力

`image-prompt.builder.ts` L265-277（portrait 段）替换为：

- `人物皮肤纹理清晰不糊：毛孔与细小绒毛可辨、肤色过渡自然，不做美颜磨皮，无塑料质感`
- `头发发丝根根分明、有自然蓬松与层次；衣物布料纤维与褶皱纹理可辨`
- `光影有明确方向与衰减层次：面部明暗过渡自然可信、有受光面与暗部的层次，避免平光无层次`
- `五官、头发、衣服纹理与手部细节贴合真实人体结构，无肢体或手指畸变；姿势经过设计：身体朝向与重心明确、肩胯有错位、双手落点具体，画面水平`
- 负面清单去掉「高饱和炫彩」保留其余（`不过度磨皮、不完美对称脸、不锥子脸卡通化、不镜面质感、不影棚式浮夸打光、不精致摆拍`）

`image-prompt.composer.ts` L347-351（portrait 段）替换为对应表述：

- `- 人物皮肤纹理清晰：毛孔与细小绒毛可辨、肤色过渡自然，不做美颜磨皮，无塑料或镜面质感`
- `- 头发发丝分明有层次，衣物布料纤维与褶皱纹理可辨；光影有明确方向与衰减层次，明暗过渡自然`
- `- 表情松弛自然像被抓拍的瞬间；五官头发手部贴合真实人体结构无畸变；构图讲究：主体落位与留白经设计、肢体线条舒展有延伸感`
- 负面清单同步调整（去掉「肤色不均匀/油光」隐含的缺陷导向）

#### B5. `hardenPhotoRealism`（`ai-generate-image.service.ts` L81-112）

- 去掉任何与「颗粒/噪点/瑕疵」冲突的表述。
- 强化「高清、干净、光影有方向与层次、真实材质纹理」。

#### B6. `RETOUCH_TEXTURE_LINES`（`image-prompt.builder.ts` L45-49）

三档真实质感句保持结构，去掉可能被解读为噪点的词（当前已无噪点字样，仅复核「保留真实环境的明暗与轻微白平衡偏移」不引入 grain 语义）。

### 3.3 C. 搜索结果落地姿势图 + 社交平台检索

#### C1. 打通 `ResearchBrief` 到生图

现状断点：`ai-analyze.service.ts` L134-135 已算出 `brief` 但只用于识别阶段；`ai-templates.controller.ts` L48-61 的状态响应不含 `brief`；`admin/src/lib/ai-task.ts` L83 只透传 `items`。

改动：

1. **后端任务结果补 `brief`**：`ai-analyze.service.ts` 两条返回路径（L210、L214）增加 `brief` 字段；`ai-analyze-task.service.ts` 的任务结果类型同步。
2. **状态接口回传**：`ai-templates.controller.ts` L48-61 增加 `researchBrief: task.result?.brief ?? null`。
3. **admin 类型**：`admin/src/types/admin.ts` 的 `AiAnalyzeStatusResult` 增加 `researchBrief?: AiResearchBrief | null`，并定义 `AiResearchBrief`（与后端 `ResearchBrief` 对齐）。
4. **透传到生图**：`admin/src/lib/ai-task.ts` L83 的 `fd.set('research', ...)` 从 `JSON.stringify(research)` 改为 `JSON.stringify({ items: research, brief })`。
5. **后端解析兼容**：`parseAiMultipart` / `ai-image-task.service.ts` 的 `research` 仍为字符串，`ai-generate-image.service.ts` L146-150 解析时兼容两种形态：
   - 数组 → 旧行为（仅 items，`brief` 为 null）；
   - 对象 `{ items, brief }` → 分别取出。
6. **composer 消费 `brief`**：
   - `PromptComposeInput` 增加 `brief?: ResearchBrief | null`。
   - `buildPromptMaterial` 在【网络趋势参考】之后新增一区块【趋势要点（结构化）】，用 `renderResearchBrief(brief)` 输出 `poseIdeas / visualElements / colorLight / styles / seasons`（不输出 `sources`，避免污染提示词）。
   - `COMPOSE_SYSTEM_PROMPT` 规则 6 强化为：「【趋势要点】中的姿势灵感（poseIdeas）必须逐条转化为本张姿势可见的身体朝向、重心、手部落点与视线；视觉元素（visualElements）转化为服装/道具/场景细节，使画面贴合当下审美」。

#### C2. 社交平台站点限定检索

**`SearchSourceConfig`**（`trend-research.service.ts` L31-45）已有 `site` 字段，searxng 适配器已支持 `site:` 前缀（`web-search-searxng.ts` L46）。改造点在于**配置默认来源**与**查询词语感**：

- 后端 `ai-config.service.ts` 的搜索来源默认值（`getSearchConfig`，L431+）新增/调整为多条 searxng 来源：
  - `searxng-xhs`：`site: xiaohongshu.com`（主）
  - `searxng-douyin`：`site: douyin.com`
  - `searxng-weibo`：`site: weibo.com`
  - `searxng-zhihu`：`site: zhihu.com`（补充，偏图文方法论）
  - 保留一条无 site 的综合来源作兜底。
- 并行执行、单源失败降级（沿用现有 `Promise.allSettled`）。
- **`reorganizeQuery`（L88-125）追加平台语感词**：规则 1 补充「在关键词组中补充社交平台常见语感词（如『穿搭』『拍照姿势』『出片』『氛围感』『怎么拍』），提高在小红书/抖音内容中的命中率」。
- `qwen` / `qwen-official` / `vendor` 来源不受 site 影响，保持可用。

#### C3. SearXNG 配置

`deploy/searxng/settings.yml`：

- 目前仅启用 `sogou`、`bing` 综合引擎。期1 不改引擎（站点限定检索走综合引擎即可）；期2 需要图片检索时再启用 `sogou images`（见 4.1）。
- `search.formats` 已含 `json`，无需改动。

### 3.4 期1 数据契约变更汇总

| 位置 | 变更 |
|------|------|
| 草稿 `meta.subjectCount` | 新增，整数 1..8，缺省 1 |
| `AiAnalyzeStatusResult.researchBrief` | 新增，`ResearchBrief \| null` |
| `fd.set('research', ...)` | 由 `ResearchItem[]` 改为 `{ items, brief }` |
| `PromptComposeInput.brief` | 新增可选 |
| `image-prompt.builder` `GRAIN_STRONG_THRESHOLD` | 删除 |
| `buildComposeSystemPrompt(categoryKey?)` | 增加可选参数 |

---

## 4. 期 2：平台图片 → 视觉识别转文字 → 反哺姿势图

> 期2 是新增子系统，待期1 验证后再单独出实现计划。

### 4.1 检索图片

- `deploy/searxng/settings.yml` 启用 `sogou images` 引擎（`name: sogou images`），并确认 `categories: images` 可用。
- `web-search-searxng.ts`：
  - `WebSearchQuery` 增加可选 `categories?: string`；请求参数带 `categories=images`。
  - `SearxngResult` 增加 `img_src?: unknown`、`thumbnail_src?: unknown`；映射为 `ResearchItem.imgUrl`（`research-item.ts` L15 已有该字段，当前无人消费）。
- `SearchSourceConfig` 增加可选 `categories?: string`，图片来源单独配置（如 `searxng-xhs-images`：`site: xiaohongshu.com` + `categories: images`）。

### 4.2 下载与识别（只转文字，不做参考图）

新增模块 `src/modules/ai/trend-research/image-fetcher.ts`：

- 输入：`ResearchItem[]` 中带 `imgUrl` 的前 N 条（默认 N=3）。
- 约束：单图体积上限 2MB、MIME 白名单 `image/jpeg|png|webp`、超时 8s、并发上限 2；不满足则跳过该条。
- 落盘到临时目录（`os.tmpdir()` 下 `lumira-research-<taskId>/`），返回 `{ path, mime }`。
- 失败/超时静默降级（不阻断识别）。

识别：复用 `ImageDescribeService.describe({ base64, mime })`（`image-describe.service.ts` L205-220 只接受本地字节）。产出 `ImageDescription` → 提炼为**简短视觉要点文本**（构图/姿势/光线/穿搭），作为新的趋势信号。

### 4.3 注入姿势图生成

- 将图片视觉要点合成为 `visualNotes: string[]`，随 `brief` 一起透传到生图（复用期1 的 `{ items, brief, visualNotes }` 结构）。
- `buildPromptMaterial` 新增【平台图片视觉参考】区块，系统规则要求「转化为本张姿势的构图、姿势线条、光线与穿搭细节」。

### 4.4 资源清理（硬要求）

- 下载的临时图片**在识别完成后的 `finally` 中立即删除**（比「模板制作结束后删除」更严格，确保任何时刻都不残留）。
- 兜底清扫：服务启动时 + 定时（每小时）清理 `lumira-research-*` 目录中超过 1 小时的孤儿文件。
- 不写入任何持久化存储，不进入七牛/本地 uploads。

---

## 5. 错误处理与降级

| 场景 | 行为 |
|------|------|
| `meta.subjectCount` 缺失/非法 | 回落 1，记 warning |
| 文本模型整理生图提示词失败 | 回退机械拼接 prompt（现有行为不变） |
| `brief` 缺失（旧后端/整理失败） | 生图仅用 items（现有行为），不报错 |
| 单个社交站点检索失败 | `allSettled` 跳过并记 `sourceErrors` |
| 期2 图片下载/识别失败 | 静默跳过该图，不阻断；临时文件仍清理 |

## 6. 测试策略

后端 spec 与实现同目录（`*.spec.ts`）：

- `normalize.spec.ts`：`subjectCount` 白名单保留、夹取、缺省回落 + warning。
- `image-prompt.builder.spec.ts`：`describeSubjectCount` 三档输出；无「颗粒感」「只有一个人物」字样；无噪点词。
- `image-prompt.composer.spec.ts`：`buildPromptMaterial` 含主体人数行；`brief` 非空时输出【趋势要点（结构化）】；`brief` 为空时不输出该区块；系统角色按 category 派生。
- `image-client.spec.ts`：英文锚点不含 `sensor noise`。
- `trend-research.service.spec.ts`：`site` 限定来源并行 + 单源失败降级。
- `ai-analyze.service.spec.ts`：返回体含 `brief`。
- `ai-generate-image.service.spec.ts`：`research` 既支持数组也支持 `{items, brief}`。
- （期2）`image-fetcher.spec.ts`：体积/MIME/超时拦截、临时文件清理。

admin：`pnpm --filter @lumira/admin build` 类型校验通过。
backend：`pnpm --filter @lumira/backend test` + typecheck 通过。

## 7. 分期与实施顺序

- **期1**（本 spec 的实现范围）：3.1 多人物 → 3.2 去噪写实 → 3.3 搜索落地 + 社交检索。纯提示词与数据流改动，风险低、见效快。
- **期2**（待期1 验证后单独出实现计划）：4.x 图片子系统。

## 8. 风险与登记

- 社交站点限定检索可能因搜索引擎收录变化导致命中下降 → 保留无 site 综合来源兜底；效果不理想时登记 `docs/future-optimizations.md`。
- 「高清干净写实」为全局取向，可能弱化部分胶片/复古风格档案的颗粒观感 → 若后续需要，按风格档案分档重新引入（登记为后续优化，不在本期实现）。
- 期2 平台图片识别涉及第三方内容，仅转文字不落地图片、用后即删，规避版权与存储风险。
