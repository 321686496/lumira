# 画集 Lumira Studio 产品需求文档（PRD）

> 文档版本：v1.0
> 创建日期：2026-07-03
> 文档类型：产品设计规格（PRD）
> 产品定位：联网的模板市场 + 作品社区 + 云端 AI 增强的摄影服务平台
> 配套品牌文档：`2026-07-03-lumira-studio-brand.md`

---

## 0. 文档说明

本文档定义独立产品「画集 Lumira Studio」的完整需求：

**画集 Lumira Studio** —— 联网的模板市场 + 作品社区 + 云端 AI 增强的摄影服务平台。通过创作者上传的拍摄模板市场、用户作品的社区分享与挑战赛、云端 AI 增强功能，构建一个完整的摄影创作生态。

产品英文名 Lumira Studio（Lumi=光，-ra 后缀，Studio=创作空间），中文名「画集」取"万千画卷，集于此处"之意。

---

## 1. 产品概述

### 1.1 一句话定位

让普通人拍出专业级好照片的摄影服务社区平台——通过"拍摄模板市场"将专业摄影师的构图、姿势、参数、后期经验固化为可复用方案并自由流通，辅以作品社区、挑战赛和云端 AI 增强，构建创作者的变现生态。

### 1.2 解决的痛点

- 普通人不会构图、不会摆姿、不懂参数、不会后期 → 拍不出好照片
- 想用好的模板但找不到高质量的资源库
- 拍了照片没人看、没法交流提高
- 专业摄影师有经验但缺平台变现
- 想拍同款但没有专业指导

### 1.3 解决方案

- 模板市场让创作者发布模板变现，用户付费下载即套用
- 作品社区让上传的作品标注模板来源，形成"作品→模板"转化闭环
- 挑战赛激发创作热情与社区活跃度
- 云端 AI 提供场景识别、构图评分、智能修图等增强能力

### 1.4 核心差异化定位

| 维度 | 画集 Lumira Studio |
|---|---|
| 网络依赖 | 全功能联网（需网络使用） |
| AI 能力 | 云端 AI 增强（场景识别/构图评分/人像/智能修图） |
| 模板来源 | 创作者发布到市场 + 平台官方出品 |
| 模板流通 | 平台发布/下载/购买/评价 + 导出 `.pptpl` 到单机版 |
| 账户体系 | 手机/微信/Apple 登录，创作者实名认证 |
| 商业模式 | 模板付费分成（平台30%/创作者70%）+ 会员 + 广告 |
| 工程形态 | 独立 uni-app 工程 |

### 1.5 核心价值主张

把"专业摄影师的经验"变成"创作者可变现的数字资产，小白可一键使用的拍摄方案"。

### 1.6 品牌身份

- 中文名：画集
- 英文名：Lumira Studio
- 副标语：万千画卷，集于此处
- LOGO：三框交织 + 中心四角星光核（暖橙 + 米白 + 深棕）
- 设计风格：暖意 bento 社区，无衬线主导，内容驱动

---

## 2. 用户角色与典型场景

### 2.1 用户角色

| 角色 | 说明 | 核心诉求 |
|---|---|---|
| 摄影小白（C 端消费者） | 不懂参数，想拍出好看照片 | 找模板套用出片 |
| 进阶爱好者 | 有基础，想提升 | 学习模板、参加挑战赛 |
| 创作者（PGC） | 专业摄影师/博主 | 发布模板变现、积累粉丝 |
| 平台运营 | — | 运营挑战赛、推荐位、内容审核 |

### 2.2 典型场景

1. **模板消费**：小白打开「画集」→ 浏览模板市场首页 → 看到"日落逆光剪影"模板（★4.8，下载量2k+）→ 付费 ¥6.9 下载 → 取景器叠加模板叠图 → 拍摄 → 出片。
2. **拍同款转化**：刷到一张好看的社区作品 → 点击下方"拍同款" → 直接跳转对应模板 → 下载使用。
3. **创作者变现**：摄影师上传一套"城市夜景"模板 → 定价 ¥9.9 → 平台审核通过 → 上架 → 一个月内下载 300 次 → 收入 ¥2079（扣除平台 30%）。
4. **挑战赛**：参加"#夏日海边人像"挑战赛 → 选择相关模板拍摄 → 提交作品 → 社区点赞投票 → 上榜获流量曝光。
5. **AI 修图**：用户拍了一张原片 → 进入后期 → 提交云端 AI 智能修图 → 返回一键修好的人像大片。
6. **离线分享**：在「画集」下载的模板可导出为 `.pptpl` 文件 → 分享给使用单机版「如画」的朋友。

---

## 3. 模板体系

### 3.1 模板定义

「拍摄模板」是一份可复用的"拍摄方案包"，是产品的最小价值单元，也是平台流通的核心数字商品。

### 3.2 模板文件格式（`.pptpl` JSON 格式）

```json
{
  "meta": {
    "id": "tmpl_xxx",
    "name": "日落逆光剪影",
    "author": "creator_user_id",
    "version": "1.0.0",
    "category": "人像",
    "tags": ["逆光", "剪影", "日落"],
    "price": 6.9,
    "cover": "oss_cover_url",
    "description": "适合黄昏海边/山顶的逆光人像剪影"
  },
  "composition": {
    "overlayType": "rule_of_thirds | grid | leading_lines | custom",
    "overlayResource": "oss_svg_url",
    "subjectFrame": { "x": 0.3, "y": 0.2, "w": 0.4, "h": 0.6 },
    "opacity": 0.5
  },
  "pose": {
    "referenceImage": "oss_png_url",
    "position": { "x": 0.5, "y": 0.5 },
    "scale": 1.0,
    "rotation": 0
  },
  "camera": {
    "exposureCompensation": -0.7,
    "isoMode": "auto | manual",
    "iso": 100,
    "shutterSpeed": "1/200",
    "whiteBalance": "daylight | cloudy | auto",
    "focusMode": "auto | manual",
    "filterPreset": "warm",
    "lensSuggestion": "main | wide | tele"
  },
  "sceneGuide": {
    "lightDirection": "backlight",
    "shootingDistance": "3-5m",
    "background": "天空/水面，避免杂物",
    "props": ["宽檐帽", "纱巾"],
    "tips": "让模特侧身，轮廓更清晰"
  },
  "postProcess": {
    "cropRatio": "3:4",
    "color": {
      "brightness": 0.1,
      "contrast": 0.15,
      "saturation": -0.1,
      "temperature": 0.2,
      "tint": 0.0
    },
    "smoothStrength": 0.3,
    "sharpen": 0.2,
    "vignette": 0.3,
    "grain": 0.1,
    "lut": "warm_sunset.cube"
  }
}
```

### 3.3 模板流通路径

- 创作者编辑 → 提交审核 → 上架市场 → 用户浏览/下载/购买 → 评价反馈
- 用户购买后可在取景器中套用
- 导出 `.pptpl` 文件分享给单机版「如画」用户
- 互通性：单机版导出的模板可上传到市场发布（需创作者账号）

### 3.4 模板兼容性

含 `version` 字段，引擎向后兼容。旧版本模板自动迁移或提示升级。

### 3.5 模板创建工具

内置「模板编辑器」，支持云端草稿与多端同步：

- 上传姿势参考图（透明 PNG，存放 OSS）
- 绘制构图叠图（路径/九宫格/三分法/自定义形状）
- 调试相机参数
- 调试后期参数（实时预览效果）
- 预览 → 保存草稿/提交审核/发布

---

## 4. 功能设计

### 4.1 功能架构

```
画集 Lumira Studio
├── 拍摄模块（继承单机版能力 + 云端 AI 增强）
│   ├── 模板套用拍摄（同单机版）
│   ├── AI 实时辅助（云端）：智能场景识别、构图评分、最佳拍摄时机提示
│   └── AI 人像增强（云端）：智能美颜、背景虚化、人像分割
├── 后期模块（本地算法 + 云端 AI）
│   ├── 本地算法后期（同单机版 + 瘦脸等 AI 人像功能）
│   ├── 云端 AI 后期：智能修图、一键大片调色、AI 抠图换背景
│   └── 云端渲染队列（高清/复杂任务异步处理）
├── 模板市场（核心）
│   ├── 模板浏览（分类/榜单/搜索/标签/推荐流）
│   ├── 模板详情（预览/作者/价格/评价/用量）
│   ├── 购买/下载/收藏/使用
│   └── 模板上传（创作者发布、审核、定价、版本更新）
├── 作品社区
│   ├── 作品广场（瀑布流/分类/话题）
│   ├── 作品发布（带模板来源标注，可点击跳转同款模板）
│   ├── 互动（点赞/评论/收藏/分享/关注作者）
│   └── 挑战赛（官方/UGC 话题、参赛、投票、榜单、奖励）
├── 创作者中心
│   ├── 数据看板（下载量/收入/粉丝/作品表现）
│   ├── 收益提现（模板分成）
│   ├── 粉丝管理/消息通知
│   └── 创作者认证（专业资质审核）
├── 账户与支付
│   ├── 注册登录（手机/微信/Apple）
│   ├── 钱包（充值/消费/分成余额）
│   ├── 订单管理
│   └── 会员体系（可选，订阅解锁部分权益）
└── 设置（推送/隐私/缓存/关于）
```

### 4.2 云端 AI 能力清单

| AI 能力 | 用途 | 触发时机 |
|---|---|---|
| 场景识别 | 识别拍摄场景（人像/风景/美食/夜景），推荐匹配模板 | 拍摄前/取景器实时 |
| 构图评分 | 实时评估当前画面构图，0-100 分 + 改进建议 | 取景器实时 |
| 人像分割 | 背景虚化/换背景 | 后期 |
| 人脸关键点 | 智能美颜/瘦脸/五官精修 | 后期 |
| 智能修图 | 一键调色/画质增强/去瑕疵 | 后期 |
| 姿态识别 | 评估拍摄对象姿势与模板姿势的匹配度 | 拍摄中（可选） |

**实现策略**：AI 能力封装在云端，APP 通过 API 调用。重型任务（如高清 AI 修图）走异步渲染队列，完成后推送通知。

### 4.3 模板市场机制

**模板生命周期**：创作者编辑 → 提交审核 → 上架 → 用户购买/下载 → 评价反馈 → 版本迭代 → 下架。

**审核机制**：机器初筛（违禁词/版权图）+ 人工复审（内容质量/原创性）。

**定价与分成**：

- 创作者可设免费或付费（1-999 元档位，平台抽成 30%）
- 平台精选模板可官方补贴/买断
- 分成按实际成交结算

**分发维度**：分类（人像/风景/美食/夜景/旅行/亲子...）、榜单（热门/新作/好评/本周精选）、标签、搜索、个性化推荐流。

### 4.4 作品社区与挑战赛

**作品发布**：用户发布成片时自动标注所用模板，其他用户点击"拍同款"直接跳转该模板，形成"作品 → 模板"转化闭环。

**挑战赛**：

- 官方发起主题挑战（如"#夏日海边人像"），设定模板范围或自由创作
- 用户参赛提交作品，社区投票 + 评委评分
- 榜单展示，奖励（流量曝光/模板免费券/创作者分成加成/实物奖品）

**社区治理**：举报/敏感图识别/水军防控/创作者原创保护。

### 4.5 创作者生态

- **入驻**：实名认证 + 作品审核 → 创作者身份
- **成长体系**：新手/进阶/签约摄影师，等级对应流量倾斜与分成比例
- **变现**：模板付费分成 + 挑战赛奖金 + 未来可扩展"付费课程/约拍"

---

## 5. 技术架构

### 5.1 技术选型

| 层 | 选择 |
|---|---|
| 前端框架 | uni-app (Vue3 + TS) |
| 相机/图像 | uni-app camera 组件 + 原生插件 + 云端 AI SDK |
| 本地算法 | OpenCV.js / 原生 C++ 插件 |
| 后端 | Node.js (NestJS) + 微服务 |
| 数据库 | PostgreSQL + Redis + OSS |
| AI 服务 | Python (FastAPI) + ONNX/TensorFlow Serving |
| 存储 | 阿里云 OSS + CDN |
| 搜索 | Elasticsearch |
| 部署 | Docker + K8s |

### 5.2 整体架构

```
[APP 端] ──HTTPS/WSS──→ [API 网关]
                          ├── 用户服务（注册/登录/鉴权/创作者认证）
                          ├── 模板服务（市场/搜索/下载/审核/版本）
                          ├── 社区服务（作品/互动/挑战赛/消息）
                          ├── 支付服务（订单/钱包/分成/提现）
                          ├── AI 服务（场景识别/构图评分/人像/修图）
                          ├── 推送服务（消息/通知）
                          └── 内容安全服务（审核/风控）
                                  ↓
                    [数据层] PostgreSQL / Redis / OSS / ES
                                  ↓
                    [基础设施] K8s + 监控（Prometheus）+ 日志（ELK）
```

### 5.3 模板文件互通规范

`.pptpl` 为统一的 JSON 格式文件。模板引擎使用独立的 TS 类型定义与序列化/反序列化逻辑，确保与单机版「如画」互通：

- 下载的模板可导出为 `.pptpl` 供单机版导入使用
- 单机版导出的模板可上传到市场发布（需创作者账号）
- 模板含 `version` 字段，向后兼容

---

## 6. 核心数据模型

```
User(id TEXT PK, phone TEXT, nickname TEXT, avatar TEXT, role TEXT[user|creator|admin], creatorLevel INT, balance DECIMAL, createdAt TIMESTAMP, ...)
Template(id TEXT PK, name TEXT, authorId TEXT FK, category TEXT, tags TEXT[], price DECIMAL, cover TEXT, pptplUrl TEXT, downloads INT, rating DECIMAL, status TEXT, version TEXT, createdAt TIMESTAMP, ...)
TemplateVersion(templateId TEXT FK, version TEXT, pptplUrl TEXT, changelog TEXT, createdAt TIMESTAMP)
Order(id TEXT PK, userId TEXT FK, templateId TEXT FK, amount DECIMAL, platformFee DECIMAL, creatorRevenue DECIMAL, status TEXT, paidAt TIMESTAMP)
Work(id TEXT PK, userId TEXT FK, templateId TEXT FK, imageUrl TEXT, description TEXT, likes INT, comments INT, challengeId TEXT FK, createdAt TIMESTAMP, ...)
Challenge(id TEXT PK, title TEXT, rules TEXT, startAt TIMESTAMP, endAt TIMESTAMP, templateIds TEXT[], status TEXT, prize TEXT)
Comment(id TEXT PK, workId TEXT FK, userId TEXT FK, content TEXT, parentId TEXT FK, createdAt TIMESTAMP)
Wallet(userId TEXT PK, balance DECIMAL, frozenBalance DECIMAL)
WalletTx(id TEXT PK, userId TEXT FK, type TEXT[recharge|consume|rebate|withdraw], amount DECIMAL, relatedOrderId TEXT FK, status TEXT, createdAt TIMESTAMP)
Follow(followerId TEXT, followeeId TEXT, createdAt TIMESTAMP)
Notification(id TEXT PK, userId TEXT FK, type TEXT, content TEXT, refId TEXT, read BOOLEAN, createdAt TIMESTAMP)
```

---

## 7. 商业化与运营

### 7.1 收入来源

1. **模板付费分成**（平台 30%，创作者 70%）
2. **创作者会员/会员订阅**（可选，解锁高级模板包/无限下载）
3. **信息流广告**（开屏/插屏/信息流原生广告）
4. **挑战赛品牌赞助**（商业化后期）

### 7.2 冷启动策略

- 种子期签约 50-100 位摄影 KOL/创作者产出优质模板
- 平台官方出品 50+ 精选模板覆盖核心场景
- 首批挑战赛引爆社区氛围
- 单机版「如画」作为引流入口（导出模板 → 引导下载「画集」获取更多模板）

### 7.3 分成结算

T+15，最低提现门槛 100 元，支持微信/支付宝提现。

---

## 8. 版本路线图

| 版本 | 核心交付 |
|---|---|
| v1.0 | 账户体系 + 模板市场（浏览/下载/购买/上传）+ 基础社区（作品发布/互动）+ 创作者分成 |
| v1.5 | 云端 AI 能力（场景识别/构图评分/人像/智能修图）+ 挑战赛 |
| v2.0 | 创作者成长体系 + 个性化推荐 + 广告接入 + 性能优化 |

---

## 9. 非功能性需求

| 维度 | 要求 |
|---|---|
| 性能 | 市场列表首屏 < 1.5s，模板下载 < 3s，AI 接口 P95 < 3s |
| 安全 | JWT 鉴权 + 风控 + 支付安全 + 内容审核 |
| 包体 | < 60MB |
| 兼容 | iOS 12+ / Android 7+ |
| 合规 | 个人信息保护法 / 内容审核备案 / 支付资质 |
| 可扩展 | 微服务化，支持横向扩容 |

---

## 10. 风险与开放问题

| 风险/问题 | 说明 | 应对 |
|---|---|---|
| 创作者冷启动 | 早期模板供给不足 | 签约 KOL + 官方出品精选模板 |
| 内容版权与合规 | UGC 模板与作品可能侵权 | 上传审核 + 投诉下架机制 |
| 支付资质 | 涉及虚拟商品支付 | 需办理相应支付资质/对接合规支付渠道 |
| 社区质量 | 低质量内容泛滥 | 推荐算法 + 人工巡检 |

---

## 附录 A：术语表

- **模板（Template / `.pptpl`）**：一份可复用的拍摄方案包，包含构图叠图、姿势参考、相机参数、场景指南、后期参数。
- **叠图（Overlay）**：取景器上覆盖的半透明引导图层（构图线/姿势轮廓/主体框）。
- **LUT（Look-Up Table）**：颜色查找表，用于实现滤镜与调色。
- **PGC**：专业生产内容（Professional Generated Content）。
- **EXIF**：图像文件元数据，记录相机参数等信息。
