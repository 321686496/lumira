# AI 一键模板录入设计

> 日期：2026-09-09
> 范围：后端（`lumira-server/packages/backend/`）+ 后台（`lumira-server/packages/admin/`）
> Flutter 端：**零改动**（产出仍走现有模板数据链路）

## 背景与目标

拍摄风格在互联网中迭代极快，运营需持续把新风格录入为线上模板。当前录入流程是 6 步表单手工填写（几十个字段：分类、构图、相机、场景、后期），单模板录入成本高。

本功能让运营**上传一张示例图，系统自动识别风格 / 类型 / 相机与后期参数，生成可直接进入后端线上模板库的表单数据**，并可选用生图模型生成模板效果图作封面、自动生成剪影姿势，最后人工确认（或一键全自动）上架。

四个目标：

1. **一键识别**：示例图 → 视觉大模型分析 → 模板草稿（结构与现有 `.pptpl` 导入格式一致，回填零适配）；
2. **封面双来源**：可选「示例图作封面」或「生图模型生成同风格效果图作封面」；
3. **剪影自动化**：人物抠图（本地 ONNX 推理）→ 线稿化/实心化 → 可选自动裁剪 → 透明底 PNG 剪影，替代当前手工流程；
4. **决策权分级**：向导每步可人工干预，也可全部走默认「一键生成并上架」。

## 非目标 / 范围界定

- **不引入** Dify / Coze 工作流（本次代码直连模型 API；工作流方案已保留为后续演进，见「演进方向」）。
- **不做**视觉模型自训练/微调，仅用各厂商现成视觉大模型。
- **不改** Flutter 端任何代码；产出模板与现有线上模板完全同构。
- 全自动模式只生成 **1 个姿势**；多姿势仍走既有编辑页（已登记后续优化）。
- 不做批量上传（一次一张，先跑通单张链路）。

## 架构总览

```
admin「AI 一键建模」向导页（/dashboard/templates/ai-create）
  Step1 上传示例图 ──(可选全自动)──────────────────────────┐
  Step2 风格识别 → 草稿回填 TemplateForm（复用 pptpl 导入回填链路）│
  Step3 封面决策：[示例图] / [生图效果图]（可重roll/多张/排序）   │ 全自动：顺序编排，
  Step4 剪影决策：选源图 → 线稿/实心 → 裁剪否 → 预览 → 应用    │ 失败停在对应步骤
  Step5 提交：上架 / 保存为未上架（走现有 createTemplate）      │ 转人工，草稿不丢
                                                             ┘
后端 ai 模块（src/modules/ai/，AdminAuthGuard 保护）：
  ai-config     配置 CRUD + 连通性测试（厂商/ baseUrl / apiKey / 模型名，存 DB 单行）
  ai-analyze    示例图 → 草稿 JSON（vision chat completions）
  ai-generate-image  草稿 → 生图（文生图或图生图，按厂商适配）
  ai-generate-silhouette  源图 → 透明底剪影 PNG（本地管线，不走厂商 API）
```

**关键复用**：`TemplateForm` 已有 `.pptpl` 导入回填逻辑（`template-form.tsx` 的 `handlePptplUpload`），提取为 `applyTemplateJson(json)` 供向导复用；封面/剪影进入现有 `imageFiles` / 姿势编辑器，排序与微调用现有交互（`moveImage`、position/scale/rotation）。

## 一、多厂商模型接入

四家厂商均提供 **OpenAI 兼容 Chat Completions**，一套客户端代码全覆盖；差异收敛为「厂商预设」：

| type | 默认 baseUrl | 视觉模型示例 | 生图方式 |
|---|---|---|---|
| `qwen` 阿里通义 | `https://dashscope.aliyuncs.com/compatible-mode/v1` | `qwen-vl-max` / `qwen-vl-plus` | wanx 异步任务（创建任务 + 轮询），单独适配 |
| `doubao` 字节豆包 | `https://ark.cn-beijing.volces.com/api/v3` | `doubao-1.5-vision-pro-32k` 或接入点 `ep-xxx` | `/images/generations`，支持参考图（Seedream，i2i 首选） |
| `zhipu` 智谱 | `https://open.bigmodel.cn/api/paas/v4` | `glm-4v-plus` / `glm-4v-flash` | `/images/generations`（CogView，纯文生图） |
| `openai` | `https://api.openai.com/v1` | `gpt-4o` / `gpt-4o-mini` | 参考图走 `/images/edits`，纯文生图走 `/images/generations` |

- 图片统一 `content: [{type:'text'},{type:'image_url'}]` base64 格式；豆包模型名为自由输入（接入点 ID），不校验枚举。
- 厂商预设只影响默认值，baseUrl / 模型名均可在设置页手改（覆盖预设）。

## 二、数据库

新表 `ai_provider_config`（**单行** upsert，id 恒为 1）：

```sql
CREATE TABLE ai_provider_config (
  id           INT PRIMARY KEY DEFAULT 1,
  provider     VARCHAR(32)  NOT NULL,            -- qwen | doubao | zhipu | openai
  base_url     VARCHAR(255) NOT NULL,
  api_key      VARCHAR(255) NOT NULL,
  vision_model VARCHAR(64)  NOT NULL,
  image_model  VARCHAR(64)  NOT NULL,
  enabled      TINYINT(1)   NOT NULL DEFAULT 0,
  created_at   DATETIME     NOT NULL,
  updated_at   DATETIME     NOT NULL
);
```

- `provider` 值为厂商预设标识，**为将来接入 `dify` / `coze` 工作流预留**——届时新增 provider 类型 + 对应 client 实现，配置页扩展即可。
- apiKey 存 DB（与 `.env` 中 ADMIN_TOKEN 同风险级别）；GET 接口脱敏返回（`sk-****ab`），PUT 时该字段留空 = 不修改原值。

## 三、后端接口（全部挂 `/api/v1/admin`，AdminAuthGuard）

### 1. 配置：`ai-config.controller.ts`

- `GET /admin/ai-config`：读取（apiKey 脱敏）
- `PUT /admin/ai-config`：保存（baseUrl/apiKey/visionModel/imageModel/enabled）
- `POST /admin/ai-config/test`：连通性测试——发最小 vision 请求（1px 图 + "ping"），返回各模型可用性明细

### 2. 识别：`POST /admin/templates/ai-analyze`（multipart: `image`）

编排（`ai-analyze.service.ts`）：

1. 校验图片（jpg/png/webp，≤5MB，与现有封面校验一致）
2. 读 `template_categories` 表 → 文本化为四级分类约束
3. 读 `ai_provider_config`（未配置 / 未启用 → 503，报错提示去 AI 设置）
4. 图片转 base64 → OpenAI 兼容 Chat Completions（温度 0.3，`response_format: json_object`，不支持时靠 code fence 剥离兜底）
5. 解析 LLM 输出 → **归一化**（见第六节）→ 返回

### 3. 生图：`POST /admin/templates/ai-generate-image`（multipart: 可选 `reference` + `meta` 草稿）

- **prompt 由后端统一构建**（`image-prompt.builder.ts`，从草稿的风格/场景/主体/光线字段合成），前端不拼 prompt。
- 有参考图优先 **图生图**（豆包/OpenAI 支持传参考图；智谱纯文生图靠草稿详细 prompt 补偿；阿里 wanx 走异步任务轮询）。
- 生成尺寸按草稿 `aspectRatio` 映射到厂商最接近的支持尺寸。
- 返回 base64 → 前端转 File 进入 `imageFiles`。

### 4. 剪影：`POST /admin/templates/ai-generate-silhouette`（multipart: `image` + `meta: {mode, crop}`）

服务端本地管线（**不依赖任何厂商 API**）：

```
源图（示例图 / 生成的效果图，任选）
① 人物抠图：onnxruntime-node + RMBG-1.4 量化版（模型文件打入 docker 镜像）
② 线稿化（mode='sketch'）：sharp 对 cutout → 灰度 → 反相 → 高斯模糊 → dodge 叠加 → 黑白线稿
   实心剪影（mode='solid'）：cutout alpha 直接生成实心
③ 自动裁剪（可选）：alpha 包围盒 + 少量 padding；不裁则保留原画面框
④ 输出透明底 PNG（base64）→ 前端转 File → 进入姿势编辑器
```

对应运营当前手工做法（效果图转黑白线稿 → 抠图脚本 → 手动裁剪），全步骤自动化且每步可跳过。

## 四、识别字段范围与草稿 JSON 契约

草稿 JSON **顶层结构与现有 `.pptpl` 导入格式完全一致**（`meta / composition / pose / camera / sceneGuide / postProcess`），示例：

```jsonc
{
  "meta": {
    "name": "晴空田园少女人像侧拍",          // 场景+主体+风格+角度，12~30字（硬约束）
    "category": "portrait",                 // 必须命中分类树一级 key
    "shortDesc": "把夏天拍进眼睛里",          // 情绪化文案，≤20字
    "description": "…结构化长描述（光线/氛围/主体/背景）…",
    "tags": ["日系", "田园", "清新"],
    "ambience": { "seasons": ["summer"], "weathers": ["sunny"], "timeTones": ["day"] },
    "classification": { "type": "portrait", "majorStyle": "…", "style": "…", "method": "" }
  },
  "composition": { "overlayType": "rule_of_thirds", "aspectRatio": "3:4", "opacity": 0.5,
    "description": "…", "subjectFrame": { "x": 0.3, "y": 0.2, "w": 0.4, "h": 0.6 } },
  "pose": [{ "name": "侧身回眸", "description": "身体微侧45度，下巴略抬…",
    "position": { "x": 0.5, "y": 0.45 }, "scale": 1.0, "rotation": 0 }],
  "camera": { "exposureCompensation": 0.3, "isoMode": "manual", "iso": 200,
    "shutterSpeed": "1/400", "whiteBalance": "daylight", "whiteBalanceK": 5500,
    "flashMode": "off", "focusMode": "auto", "lensType": "85mm f/1.8",
    "lensSuggestion": "telephoto" },
  "sceneGuide": { "lightDirection": "侧逆光", "shootingDistance": "2-3米",
    "background": "田野与天空", "props": ["草帽"], "bestTime": "午后4-6点",
    "tips": ["对焦眼睛", "避免正午顶光"] },
  "postProcess": { "cropRatio": "3:4",
    "color": { "brightness": 5, "contrast": 8, "saturation": -10, "temperature": 10,
      "tint": 3, "highlights": -5, "shadows": 8 },
    "smoothStrength": 15, "sharpen": 10, "vignette": 12, "grain": 18,
    "lut": "japanese_fresh" }
}
```

**AI 填**：名称、分类（四级链路，从 DB 分类树中选）、描述、短简介（情绪化，非长描述缩写）、标签、氛围、构图（含主体框估计）、姿势文字描述、相机推荐参数（模板语义=复现该风格的建议参数，模型估算合理值）、场景引导、后期参数（LUT 从 24 枚举中按中文标签选最接近项）。

**AI 不填**（默认/运营填）：

- `price`——价格由用户定义，不属 AI 范畴（默认 0）
- `silhouette`——剪影由管线单独生成，AI 只给姿势文字
- `author / sortOrder / isActive`——表单默认值
- 封面——前端将示例图或生成的效果图设为封面（`imageFiles` 首图）

**响应包裹**：`{ draft, warnings: string[] }`——归一化中被丢弃/修正的非法值逐条返回，前端黄条提示运营重点复核。

## 五、提示词与归一化

**识别提示词**（`analyze.prompt.ts`，随代码维护）：

- 系统角色：资深人像摄影模板编辑，分析示例图产出可直接上线的模板表单
- 动态注入：DB 分类树（四级路径 + 每级 key）、全部枚举值及中文标签（overlayType / 白平衡 / 镜头建议 / LUT 24 项等）、姿势描述示例
- 硬约束：只输出 JSON 不带解释；名称具体化；shortDesc 情绪化；未知枚举字段省略不编造；分类必须从给定树中选

**归一化层**（`normalize.ts`，识别与生图共用）：

- 枚举校验：先做**中英文标签映射**（`三等分→rule_of_thirds`、`日系清新→japanese_fresh`），映射失败丢弃 + 记 warning
- 分类校验：category 必须在树中；majorStyle/style/method 逐级校验父子关系，断裂则截断到合法层
- 数值夹取：subjectFrame / position 相对坐标夹 0~1；色彩参数夹 -100~100；opacity 夹 0~1
- JSON 容错提取：剥 code fence → 首个 `{` 到末个 `}` 截取 → 仍失败报「模型输出无法解析」

## 六、admin 前端

### AI 设置页 `/dashboard/ai-config`（sidebar 新增「AI 设置」）

- 厂商四卡选择（qwen/doubao/zhipu/openai）→ 自动填 baseUrl 与推荐模型名，均可手改
- 字段：baseUrl、apiKey（password 输入，编辑时脱敏显示，留空=不改）、visionModel、imageModel、enabled
- 「测试连接」按钮 → 调 `POST /admin/ai-config/test`，展示各模型可用性明细
- 保存提示：需保存后新请求才生效

### 一键建模向导页 `/dashboard/templates/ai-create`（模板管理组加入口）

```
Step 1 上传示例图（jpg/png/webp ≤5MB）
Step 2 风格识别 → 草稿回填 TemplateForm（全部字段可改）
Step 3 封面决策：[用示例图] / [生成效果图]（可重roll、可多张、可排序，首图=封面）
Step 4 剪影决策：选源图 → 线稿/实心 → 自动裁剪否 → 透明棋盘格预览 → 应用到姿势
Step 5 提交：上架（isActive=true）/ 保存为未上架
```

- 每步有默认值，任何一步可跳过（不决策=一路下一步）：Step 3 默认**示例图作封面**；Step 4 默认**源图=封面图、线稿模式、自动裁剪**
- **全自动按钮**（Step 1 即可点）：识别 → 生图作封面 → 生成线稿剪影 → 创建并上架；逐步显示进度，失败停在对应步骤转人工，已成功资产保留
- 实现：`actions/templates.ts` 加 server actions；`TemplateForm` 提取 `applyTemplateJson()` 复用函数 + 新增可选 props（AI 草稿 + 示例图 File）

## 七、错误处理

| 场景 | 行为 |
|---|---|
| 未配置 / 未启用 | 503 + 「请先在 AI 设置中配置」 |
| apiKey 无效 / 欠费 | 上游 401/403 透传明确错误 + 引导去设置页 |
| 生图 / 剪影失败 | 向导停当前步、可重试，草稿不丢（前端 state 保持） |
| 模型输出非法 JSON | 归一化失败 → 「重试识别」按钮 |
| 全自动中途失败 | 停在对应步骤转人工，已成功资产（草稿/封面）保留 |

## 八、测试

- **归一化单测**（纯函数，重点）：枚举映射 / 夹取 / 分类树校验 / JSON 容错
- **ai-config**：CRUD + 脱敏（e2e，沿用现有 supertest 体系）
- **ai-analyze controller**：mock llm client，验证 multipart 校验、warnings 透传、未配置 503
- **生图 prompt builder 单测**
- **剪影管线**：集成测试，小尺寸测试图跑通抠图→线稿→透明 PNG
- **admin**：`pnpm build` 通过 + 手动验收清单（文档提供四厂商真实 key 冒烟步骤）

## 九、部署注意

- Dockerfile 加 `onnxruntime-node` + `sharp` 依赖层
- RMBG-1.4 模型文件（~44MB）：构建时下载或 git-lfs，打入 runner 层
- 无新增环境变量（配置全部在 DB，经设置页维护）

## 演进方向（已登记 `docs/future-optimizations.md`）

1. **Dify / Coze 工作流接入**：本次代码直连；后续可将 `ai-analyze` / `ai-generate-image` 切换为工作流 API（Dify Workflow / Coze），配置表 `provider` 字段已预留扩展位，提示词与模型选型届时移入工作流侧可视化维护。
2. **全自动多姿势**：当前全自动只生成 1 个姿势；后续可识别图中多个可复现姿势并批量生成剪影。
