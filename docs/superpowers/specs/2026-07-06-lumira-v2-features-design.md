# 如画 Lumira v2.0 功能扩展设计文档

> 文档版本：v1.0
> 创建日期：2026-07-06
> 文档类型：产品功能扩展设计规格
> 基础产品：如画 Lumira v1.0（完全离线随身摄影工具）
> 配套文档：`2026-07-03-lumira-prd.md` · `2026-07-03-lumira-frontend.md` · `2026-07-03-lumira-brand.md`

---

## 0. 设计原则

| 原则 | 说明 |
|---|---|
| **完全离线** | 所有新增功能不依赖网络连接，零网络权限约束不变 |
| **女性用户优先** | 受众画像为女性用户，所有交互与视觉设计以柔和、精致、情感化为导向 |
| **可配置优先** | 商业化内容通过配置文件管理，后续新增/修改无需改代码 |
| **克制扩展** | 不破坏 v1.0 的极简编辑式调性，功能增量以"补全体验"而非"堆叠功能"为目标 |

---

## 1. 游戏化成长体系

### 1.1 成就/勋章系统

面向女性用户设计的轻盈水彩/手绘线稿风格成就徽章，暖金 + 淡粉点缀色。

**成就列表：**

| ID | 名称 | 解锁条件 | 类别 |
|---|---|---|---|
| `ach_first_shot` | 「初露锋芒」 | 完成第1次拍摄 | 新手 |
| `ach_shutter_100` | 「快门达人」 | 累计拍摄100张照片 | 进阶 |
| `ach_all_templates` | 「模板收藏家」 | 使用过所有内置模板 | 探索 |
| `ach_composition_50` | 「构图大师」 | 使用构图模板拍摄50次 | 技能 |
| `ach_editor_50` | 「后期魔法师」 | 完成50次后期编辑 | 技能 |
| `ach_5_categories` | 「百变达人」 | 使用过5个不同类别模板 | 探索 |
| `ach_sunrise_10` | 「晨光猎人」 | 在日出时段拍摄10次 | 场景 |
| `ach_night_20` | 「夜拍精灵」 | 在夜晚模式下拍摄20次 | 挑战 |
| `ach_7_days` | 「持之以恒」 | 连续7天每天至少拍摄1张 | 坚持 |
| `ach_30_days` | 「摄影信徒」 | 连续30天每天至少拍摄1张 | 坚持（隐藏） |
| `ach_outfit_first` | 「今日份好看」 | 首次使用穿搭日记功能 | 女性向 |
| `ach_group_10` | 「闺蜜拍照王」 | 使用合拍模板拍摄10次 | 女性向 |
| `ach_scene_20` | 「探店达人」 | 拍摄超过20个不同场景标签 | 女性向 |
| `ach_outfit_7` | 「穿搭灵感」 | 连续7天记录穿搭 | 女性向 |
| `ach_mood_30` | 「温柔以待」 | 使用「温柔」心情标签超过30次 | 女性向 |
| `ach_share_master` | 「分享达人」 | 裂变分享达到10次有效 | 隐藏 |

**存储结构：**

```sql
CREATE TABLE Achievements (
  achievementId TEXT PRIMARY KEY,
  unlockedAt INTEGER,
  notified INTEGER DEFAULT 0     -- 是否已展示解锁通知
);
```

### 1.2 经验等级系统

**经验值获取：**

| 行为 | XP |
|---|---|
| 拍摄一张照片 | +10 |
| 使用模板拍摄 | +5（叠加） |
| 完成一次后期编辑 | +5 |
| 完成每日挑战 | +30 |
| 解锁一个成就 | +50 |
| 有效分享一次 | +20 |

**等级与称号：**

| 等级范围 | 称号 | 升级所需总 XP |
|---|---|---|
| Lv.1-10 | 摄影新人 | 起始 |
| Lv.11-20 | 入门学徒 | 500 |
| Lv.21-30 | 进阶能手 | 1500 |
| Lv.31-40 | 高手达人 | 3500 |
| Lv.41-50 | 摄影大师 | 7000 |

**存储：**

```sql
CREATE TABLE UserLevel (
  level INTEGER DEFAULT 1,
  currentXp INTEGER DEFAULT 0,
  totalXp INTEGER DEFAULT 0,
  title TEXT DEFAULT '摄影新人'
);
```

### 1.3 每日本地挑战

本地算法根据当前日期哈希值，从预置挑战池中选取一个任务。

**挑战池（不少于 50 条）：**

| 类型 | 示例 |
|---|---|
| 主题类 | "拍摄一张以「红色」为主色调的照片" |
| 技术类 | "使用三分法构图拍摄一张人像" |
| 模板类 | "用「日落逆光」模板拍一张" |
| 创意类 | "尝试用树叶做前景拍一张" |
| 场景类 | "在暖光环境下拍一张饮品" |
| 心情类 | "拍一张让你感到『温柔』的画面" |

- 完成挑战在拍摄页获得"今日挑战 ✓"标记
- 每日零点自动刷新
- 挑战数据仅存本地日期 + 完成状态

### 1.4 女性向特色功能

**穿搭日记：**

- 拍摄页新增「穿搭」模式入口
- 每次拍摄可标记为穿搭记录，关联时尚类模板（咖啡馆/街拍/探店）
- 按日期形成个人穿搭日记时间线，每日一张
- 以杂志排版风格展示："今日穿搭 · 7月6日"

**合拍指南：**

- 专门的双人/多人合照模板，含位置指引标注（"你站这里，她站这里"）
- 姿势参考图包含双人互动姿势（侧身对视、背影、牵手等）
- 取景框同时标注两个人的位置

**心情标签：**

- 拍摄/后期完成后可为照片添加心情标签
- 可选标签：开心 / 甜酷 / 温柔 / 复古 / 清新 / 文艺 / 治愈
- 相册支持按心情筛选查看

**探店打卡：**

- 拍摄时可通过场景向导选择地点标签（咖啡馆、花店、海边、民宿等）
- 相册按地点标签自动归类
- 统计已打卡场景数

### 1.5 拍摄统计与成长轨迹

**统计维度（展示在「我的」页统计区）：**

- 总拍摄张数
- 本月拍摄张数
- 已使用不同模板数
- 累计后期编辑数
- 最常用模板 TOP5
- 最常用分类标签

**日历热力图：**

- 以年份为维度，展示一年中各天是否有拍摄记录的格点图
- 色块深浅代表当日拍摄数量

**成长轨迹时间线：**

- 用户可查看自己的"摄影成长之路"
- 自动选取里程碑照片（第1张、第50张、第100张……）
- 每条里程碑显示日期、模板名、简单统计

---

## 2. 内容与学习体系

### 2.1 内置「摄影美学院」教程

以图文卡片形式展示，每个教程 3-5 屏可滑动。教程末尾关联推荐模板。

| 章节 | 标题 | 内容概要 |
|---|---|---|
| 第1课 | 找到你的最佳角度 | 自拍/他拍的角度技巧，45度角、俯拍、平拍效果 |
| 第2课 | 光线是最好的滤镜 | 顺光/逆光/侧光/散射光入门，适配咖啡馆/落日场景 |
| 第3课 | 构图其实很简单 | 三分法/居中/框架构图/引导线，适配探店/旅行 |
| 第4课 | 显高显瘦的秘密 | 机位选择、广角运用、脚贴底边法则 |
| 第5课 | 后期调色入门 | LUT 滤镜选择、亮度/色温/饱和度的含义与搭配 |

**存储：** 教程内容以本地 JSON/HTML 形式内置在 `static/lessons/` 目录。

### 2.2 每日灵感卡片

- APP 本地轮换展示一条摄影技巧/灵感
- 展示位置：拍摄页顶部轻触展开、「我的」页灵感卡片组件
- 每天显示不同的内容，由日期哈希值决定
- 包含"用此灵感拍摄"快捷链接，关联推荐模板
- 灵感池不少于 100 条

**示例：**

> "侧身站立 + 回头看镜头，显瘦又自然 🌿"
> "📌 试试用「街拍回眸」模板"

> "日落前 30 分钟是拍人像的黄金时刻 🌇"
> "📌 试试用「日落逆光」模板"

### 2.3 场景向导

**入口：** 拍摄页右上角场景图标按钮

**场景列表：**

| 场景 | 图标 | 适合模板类型 |
|---|---|---|
| 咖啡馆/甜品店 | ☕ | 咖啡馆半身、氛围感 |
| 花店/花园 | 🌸 | 人像花丛、清新 |
| 海边/日落 | 🏖️ | 日落逆光、旅行人像 |
| 城市街拍 | 🏙️ | 街拍、回眸 |
| 探店/买手店 | 🛍️ | 穿搭、侧身 |
| 居家/民宿 | 🏠 | 居家慵懒、生活感 |
| 生日/纪念日 | 🎂 | 生日纪念 |
| 闺蜜/情侣合照 | 👭 | 双人合拍 |

- 选择场景后自动筛选该场景的模板列表
- 展示场景拍摄小贴士

### 2.4 模板示例画廊

- 每个内置模板详情页关联 2-3 张内置示例作品
- 示例作品在模板制作时一并打包
- 展示位置：模板详情页 → 切换至「示例作品」tab
- 示例图片右下角标注：拍摄参数简要说明

---

## 3. 品牌传播体系（裂变基础层）

### 3.1 品牌水印系统

导出时可选水印样式：

| 风格 | 位置 | 内容 | 适用 |
|---|---|---|---|
| 极简金标 | 右下角 | 「如画 Lumira」暖金文字 + LOGO 符号 | 日常分享 |
| 参数标签 | 左下角 | 📷 f/1.8 1/200s ISO100 + Lumira | 摄影爱好者 |
| 文艺角标 | 右下角 | Lumira · 如画，衬线小字 | 小红书/朋友圈 |
| 无标纯净 | — | 无水印 | 个人收藏 |

- 默认导出为「极简金标」风格
- 水印在导出前可选，设置在设置页持久化

### 3.2 前后对比卡

模板使用后，在拍摄预览页新增「生成对比卡」按钮。

**对比卡排版：**

```
┌─────────────────────────┐
│    如画 Lumira · 模板    │
│  ┌──────┐  ┌──────┐    │
│  │ 原片  │  │ 成片  │    │
│  └──────┘  └──────┘    │
│  咖啡馆半身 · 模板      │
│  「如你所见，皆成画卷」  │
└─────────────────────────┘
```

- 左右分屏，原片（未经后期）vs 成片（应用模板后期参数后）
- 底部固定品牌信息行
- 保存到相册供分享

### 3.3 EXIF 艺术卡片

生成一张包含拍摄信息与品牌信息的精美信息卡。

**排版：**

```
┌─────────────────────────┐
│      [照片缩略图]        │
│                         │
│  标题/场景               │
│  ───────────────────    │
│  📷 如画 Lumira          │
│  模板：咖啡馆半身         │
│  EV +0.3  ISO 100       │
│  f/1.8  1/200s          │
│  后期：暖色调 LUT        │
│                         │
│  "框住光，皆成画卷"      │
└─────────────────────────┘
```

- 入口：照片详情/后期页 → 分享 → 「生成 EXIF 卡片」

### 3.4 每月摄影手帐

每月末自动提示用户生成"本月摄影手帐"。

- 自动选择本月最佳照片（按编辑次数/收藏标记评估）
- 杂志风排版长图：封面 + 照片网格 + 日期标注 + 模板名称
- 封面："我的 7 月摄影手帐 · Lumira"
- 可导出为长图或 PDF
- 末页自动附带引导页："你也想拍出这样的照片吗？📸"

---

## 4. 离线裂变传播方案

### 4.1 裂变闭环总图

```
User A (已有APP)                 User B (新用户)
                                  │
1. 生成邀请信息(加密字符串)         │
   │──系统分享──▶ 2. 下载如画APP   │
                    3. 拍照/使用模板
                    4. 生成本人分享信息(加密串)
   ◀──回传分享信息──┤
5. 解析验证
6. 解锁奖励
```

### 4.2 邀请有礼 —— 离线加密验证

**分享信息数据结构：**

```typescript
interface ShareInfo {
  version: 1
  deviceTag: string              // 设备ID的SHA256前8位，去重标识
  alias: string                  // 用户自定义昵称（可选）
  generatedAt: number            // 生成时间戳
  usageProof: {
    photoCount: number           // 已拍摄照片数
    templateUsed: number         // 使用过的不同模板数
    hasFirstPhoto: boolean       // 是否完成第一次拍摄
    hasEditedPhoto: boolean      // 是否做过后期编辑
  }
  signature: string              // HMAC-SHA256 签名
}
```

**签名机制：**

```
签名密钥 = SHA256(设备ID + "Lumira_Offline_V1")
待签名数据 = version + deviceTag + alias + generatedAt + JSON(usageProof)
signature = HMAC-SHA256(待签名数据, 签名密钥)
分享信息字符串 = Base64(JSON({...不含signature})) + "." + Base64(signature)
```

**验证规则（User A 导入时）：**

| 校验项 | 规则 |
|---|---|
| 格式校验 | 正确解码 JSON + 签名 |
| 签名校验 | HMAC 匹配 |
| 新鲜度 | generatedAt 在 30 天内 |
| 去重 | deviceTag 未在已处理列表中 |
| 使用门槛 | usageProof.photoCount >= 1（排除下载后未使用的空数据） |

**防刷机制：**

- 同一 deviceTag 30 天内不重复计数
- 单日最多记录 3 次有效分享
- 有效期 30 天
- 已处理 deviceTag 列表存储在本地 SQLite

**用户交互设计：**

- **User A**：「推荐给朋友」→ 生成邀请码 → 系统分享
- **User B**：首次启动引导 / 设置页「输入邀请码」→ 输入粘贴 → 生成本人分享信息 → 自动复制到剪贴板 → 提示"复制成功，发给邀请你的好友吧！"
- **User A**：「邀请有礼」页面 → 输入 User B 的分享信息 → 验证 → 解锁奖励

### 4.3 奖励阶梯配置

参见第 7 章「可配置商业化体系」的 rewardTiers 设计。

### 4.4 模板文件裂变

- 导出的 `.pptpl` 文件后缀追加 `_via_Lumira`
- 模板文件 meta 中自动标记创建来源
- 被分享者需安装如画 APP 才能导入使用

### 4.5 推荐图卡

- 「我的」页固定入口「📤 推荐如画」
- 展示预置精美推荐图卡，用户可直接分享
- 图卡内容：米白底 + 如画 LOGO + 副标题 + 一句话推荐语 + 二维码占位区域

### 4.6 分享文案预设

导出/分享时预置可修改的分享文案：

- "用 @如画 Lumira 拍的，一键出片 📸"
- "模板太好用了！咖啡馆人像一键出片 ✨"
- "如画 · 框住光，皆成画卷"
- 自定义

### 4.7 裂变统计（本地）

统计维度均在本地计算，展示在「我的」页：

- 累计导出照片数
- 模板分享次数
- 推荐图卡分享次数
- 对比卡生成次数
- 有效邀请次数

---

## 5. 体验增强模块

### 5.1 取景器辅助工具

- **水平仪**：取景器内叠加半圆形水平指示器（暖金色），通过陀螺仪传感器驱动
- **实时直方图**：取景器角落显示亮度直方图（可开关）
- **快门振动反馈**：拍摄时轻柔振动（支持设备时）

### 5.2 快捷手势

| 手势 | 操作 |
|---|---|
| 双击取景器 | 切换前后摄像头 |
| 长按画面 | 锁定曝光/对焦 (AE/AF Lock) |
| 双指捏合 | 数码变焦 |
| 左滑/右滑取景器 | 快速切换最近使用的模板 |
| 相册长按进入多选 | 批量操作模式 |

### 5.3 模板快速切换

- 拍摄页底部新增「最近使用的模板」横向滚动画廊
- 最多显示最近 6 个模板
- 点击直接切换模板，叠图立即更新，无跳转

### 5.4 批量操作

- 相册中长按进入多选模式
- 支持：批量删除、批量导出（无水印/带水印/带对比卡）
- 滑动连选手势：长按第一个后滑动至最后一个

### 5.5 全局深色模式

- 跟随系统自动切换 / 手动切换
- 深色配色方案遵循品牌文档 `2026-07-03-lumira-brand.md` 中的深色色板
- 取景器场景自动进入深色模式

### 5.6 照片收藏与精选集

- 爱心图标收藏照片
- 可建立个人精选集（如「我最爱的九张」「旅行精选」「穿搭合集」）
- 精选集支持导出为九宫格拼图

### 5.7 交互反馈规范

- 拍摄完成：轻柔快门声 + 微振动
- 保存成功：右下角淡入 toast "已保存到相册 📸"
- 模板切换：叠图层淡入淡出过渡（200ms）
- 操作失误：底部 tips 轻柔提示，不弹模态窗
- 所有动效仅动画 transform 与 opacity

---

## 6. 数据模型扩展

### 6.1 新增 SQLite 表

```sql
-- 成就表
CREATE TABLE Achievements (
  achievementId TEXT PRIMARY KEY,
  unlockedAt INTEGER NOT NULL,
  notified INTEGER DEFAULT 0
);

-- 用户等级
CREATE TABLE UserLevel (
  id INTEGER PRIMARY KEY CHECK(id = 1),
  level INTEGER DEFAULT 1,
  currentXp INTEGER DEFAULT 0,
  totalXp INTEGER DEFAULT 0,
  title TEXT DEFAULT '摄影新人'
);

-- 每日挑战
CREATE TABLE DailyChallenges (
  date TEXT PRIMARY KEY,
  challengeId TEXT NOT NULL,
  completed INTEGER DEFAULT 0
);

-- 心情标签
ALTER TABLE LocalPhoto ADD COLUMN moodTag TEXT DEFAULT NULL;

-- 照片收藏
ALTER TABLE LocalPhoto ADD COLUMN isFavorite INTEGER DEFAULT 0;

-- 精选集
CREATE TABLE Collections (
  collectionId TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  coverPhotoId TEXT,
  createdAt INTEGER,
  updatedAt INTEGER
);

-- 精选集-照片关联
CREATE TABLE CollectionPhotos (
  collectionId TEXT NOT NULL,
  photoId TEXT NOT NULL,
  sortOrder INTEGER,
  PRIMARY KEY (collectionId, photoId)
);

-- 用户奖励解锁状态
CREATE TABLE UserRewards (
  rewardId TEXT PRIMARY KEY,
  rewardType TEXT NOT NULL,        -- 'template' | 'template_pack' | 'achievement'
  source TEXT NOT NULL,            -- 'share' | 'purchase' | 'builtin' | 'redemption'
  unlockedAt INTEGER NOT NULL,
  metaJson TEXT
);

-- 已处理的裂变分享
CREATE TABLE ProcessedShares (
  deviceTag TEXT PRIMARY KEY,
  processedAt INTEGER NOT NULL,
  alias TEXT
);

-- 已使用的兑换码
CREATE TABLE UsedCodes (
  codeHash TEXT PRIMARY KEY,
  usedAt INTEGER NOT NULL
);

-- 穿搭日记
ALTER TABLE LocalPhoto ADD COLUMN isOutfit INTEGER DEFAULT 0;

-- 场景标签
ALTER TABLE LocalPhoto ADD COLUMN sceneTag TEXT DEFAULT NULL;
```

### 6.2 本地存储目录扩展

```
static/
├── rewards/
│   ├── reward-catalog.json         # 奖励配置（可修改）
│   └── redemption-codes.json       # 兑换码配置（加密）
├── lessons/                        # 摄影教程
│   ├── lesson-01.json
│   ├── lesson-02.json
│   └── ...
├── inspiration/                    # 每日灵感池
│   └── tips.json
├── challenges/                     # 每日挑战池
│   └── challenges.json
├── share-cards/                    # 推荐图卡
│   ├── card-01.png
│   └── card-02.png
└── luts/                           # LUT 滤镜（已有）
```

---

## 7. 可配置商业化体系

### 7.1 奖励与付费配置（核心配置文件）

```typescript
// static/rewards/reward-catalog.json

interface RewardCatalog {
  version: number                    // 配置文件版本
  rewardTiers: RewardTier[]          // 分享解锁奖励阶梯
  paidTemplatePacks: PaidPack[]      // 付费模板包定义
  paidTemplates: PaidTemplate[]      // 单个付费模板定义
  redemptionCodes: RedemptionCode[]  // 兑换码（实际运行时加密存储）
  adConfig: AdConfig                 // 广告预留配置
}

interface RewardTier {
  tier: number
  requiredShares: number
  rewards: RewardItem[]
}

interface RewardItem {
  type: 'template' | 'template_pack' | 'achievement'
  id: string
  label: string
}

interface PaidPack {
  packId: string
  label: string
  templates: string[]
  coverImage: string
}

interface PaidTemplate {
  templateId: string
  label: string
  category: string
  tags: string[]
}

interface AdConfig {
  enabled: boolean
  rewardedAdUnlock: {
    enabled: boolean
    eligibleTemplates: string[]
  }
}

interface RedemptionCode {
  codeHash: string
  rewardType: 'template' | 'template_pack' | 'all_paid'
  rewardId: string
  maxUses: number
  validUntil: number
}
```

### 7.2 默认奖励阶梯配置

| 层级 | 有效分享次数 | 解锁内容 |
|---|---|---|
| 1 | 1 | 付费模板「日系胶片」× 1 |
| 2 | 3 | 付费模板包「法式复古」（含 3 个模板） |
| 3 | 5 | 付费模板包「氛围感写真」（含 5 个模板） |
| 4 | 10 | 「分享达人」专属成就 + 全部付费模板包 |

### 7.3 兑换码系统

- 完全本地运行，不可见入口（隐蔽方式触发）
- 兑换码内置加密哈希列表，不存储明文
- 验证：输入 → SHA256 → 比对码库 → 解锁奖励
- 防重复：已兑换码记录到 `UsedCodes` 表

### 7.4 广告接入预留

- 代码层预留广告位配置 `adConfig`，默认 `enabled: false`
- APP 上架性质：单机离线工具
- 后续可通过应用市场提供广告能力，在不改核心代码的前提下开启

### 7.5 扩展性清单

| 操作 | 修改文件 | 是否需改核心代码 |
|---|---|---|
| 新增付费模板 | `static/templates/` 添加文件 + `reward-catalog.json` 注册 | 否 |
| 新增付费模板包 | `reward-catalog.json` 新增 `paidTemplatePacks` 条目 | 否 |
| 调整分享解锁门槛 | 修改 `rewardTiers[].requiredShares` | 否 |
| 新增奖励阶梯 | `rewardTiers` 数组新增 `tier` | 否 |
| 新增兑换码 | 更新 `redemption-codes.json` 加密条目 | 否（需发版） |
| 开启看广告解锁 | 修改 `adConfig.enabled=true` + 集成渠道广告 SDK | 否（需接入广告 SDK） |
| 调整奖励内容 | 修改 `rewardTiers[].rewards` | 否 |

---

## 8. 页面与路由扩展

### 8.1 新增页面

| 路径 | 页面 | 说明 |
|---|---|---|
| `/pages/profile/growth` | 成长中心 | 成就展示、等级、统计、成长轨迹 |
| `/pages/profile/invite` | 邀请有礼 | 裂变分享入口、奖励展示、邀请记录 |
| `/pages/profile/academy` | 摄影美学院 | 内置教程列表 |
| `/pages/profile/academy-detail` | 教程详情 | 单篇教程阅读页 |
| `/pages/profile/collections` | 精选集管理 | 创建/编辑/查看精选集 |
| `/pages/profile/collection-detail` | 精选集详情 | 精选集内照片列表 |
| `/pages/gallery/diary` | 拍摄日记 | 时间轴视图，按日归集 |
| `/pages/capture/scene-guide` | 场景向导 | 场景选择器 |

### 8.2 页面路由注册

```json
{
  "pages": [
    // ... 原有 v1.0 路由保持不变
    
    // v2.0 新增
    { "path": "pages/profile/growth", "style": { "navigationBarTitleText": "成长中心" } },
    { "path": "pages/profile/invite", "style": { "navigationBarTitleText": "邀请有礼" } },
    { "path": "pages/profile/academy", "style": { "navigationBarTitleText": "摄影美学院" } },
    { "path": "pages/profile/academy-detail", "style": { "navigationBarTitleText": "教程" } },
    { "path": "pages/profile/collections", "style": { "navigationBarTitleText": "我的精选集" } },
    { "path": "pages/profile/collection-detail", "style": { "navigationBarTitleText": "精选集" } },
    { "path": "pages/gallery/diary", "style": { "navigationBarTitleText": "拍摄日记" } },
    { "path": "pages/capture/scene-guide", "style": { "navigationStyle": "custom" } }
  ]
}
```

### 8.3 导航变更

- **「我的」页**：新增「成长中心」「摄影美学院」「邀请有礼」入口
- **拍摄页**：右上角新增「场景向导」入口
- **相册页**：顶部新增「拍摄日记」切换入口
- **拍摄预览页**：新增「生成对比卡」按钮
- **后期编辑页**：新增「生成 EXIF 卡片」按钮

---

## 9. 组件树扩展

```
App.vue（新增组件）
├── [新增] GrowthCenter.vue
│   ├── AchievementGrid.vue        # 成就墙（Bento 网格）
│   ├── LevelProgress.vue          # 等级进度条
│   └── GrowthTimeline.vue         # 成长时间线
│
├── [新增] DailyChallenge.vue       # 每日本地挑战卡片
├── [新增] DailyInspiration.vue     # 每日灵感卡片
├── [新增] SceneGuideSheet.vue      # 场景选择器（底部弹窗）
├── [新增] BeforeAfterCard.vue      # 前后对比卡组件
├── [新增] ExifCard.vue             # EXIF 艺术卡片组件
├── [新增] WatermarkPreview.vue     # 水印预览组件
├── [新增] MoodTagPicker.vue        # 心情标签选择器
├── [新增] ComparedToggle.vue       # 前后对比手势组件（增强）
├── [新增] BatchBar.vue            # 相册批量操作栏
├── [新增] RecommendToFriend.vue    # 推荐图卡组件
└── [新增] InviteCodeInput.vue      # 邀请码输入组件（隐藏入口）
```

---

## 10. 新增 Composable

| Composable | 功能 |
|---|---|
| `useAchievements.ts` | 成就检测、解锁、通知 |
| `useLevelSystem.ts` | 经验值管理、等级升降、称号 |
| `useDailyChallenge.ts` | 每日挑战生成、完成状态 |
| `useMoodTag.ts` | 心情标签存储、筛选 |
| `useCollections.ts` | 精选集 CRUD |
| `useInviteShare.ts` | 裂变分享信息生成/验证（核心离线加密引擎） |
| `useWatermark.ts` | 水印合成（Canvas） |
| `useCompareCard.ts` | 前后对比卡生成 |
| `useExifCard.ts` | EXIF 艺术卡片生成 |
| `useMonthlyDigest.ts` | 摄影手帐排版生成 |
| `useRedemptionCode.ts` | 兑换码验证（隐藏入口） |

---

## 11. 性能目标

| 指标 | 目标 |
|---|---|
| 成就检测 | < 5ms（纯本地 SQLite 查询） |
| 对比卡生成 | < 1s（1080P） |
| EXIF 卡片生成 | < 500ms |
| 水印叠加 | < 100ms（Canvas 合成） |
| 手帐排版 | < 3s（20 张照片以内） |
| 分享信息生成/验证 | < 10ms |
| 新增存储占用 | < 5MB（含教程/灵感/挑战池） |

---

## 12. 安全与合规

- 所有用户数据仅存本地 SQLite 和文件系统
- 兑换码明文本地不存储，仅存 SHA256 哈希
- 裂变分享信息含设备签名，防篡改
- 无用户数据收集，无第三方 SDK（广告接入前）
- APP 上架分类：单机离线工具
- 广告功能接入前，manifest 保持零网络权限

---

## 13. 实现优先级建议

| 阶段 | 模块 | 依赖 | 周期估算 |
|---|---|---|---|
| P0 | 体验增强（手势/深色/批量/反馈） | 无 | 1 周 |
| P0 | 照片收藏与精选集 | 无 | 1 周 |
| P0 | 心情标签与场景标签 | 无 | 3 天 |
| P1 | 游戏化成长（成就/等级/统计） | 基础功能完善 | 2 周 |
| P1 | 品牌传播（水印/对比卡/EXIF卡） | 后期模块已有 | 1.5 周 |
| P1 | 场景向导 | 无 | 4 天 |
| P2 | 内容体系（教程/灵感/挑战池） | 内容资源准备 | 2 周 |
| P2 | 穿搭日记/合拍指南 | 场景标签 | 1 周 |
| P2 | 拍摄日记/时间轴 | 相册已有 | 4 天 |
| P3 | 裂变体系（邀请有礼/推荐图卡） | 加密引擎开发 | 1.5 周 |
| P3 | 每月摄影手帐 | 品牌传播基础 | 1 周 |
| P3 | 兑换码系统 | 无 | 3 天 |
| 后续 | 广告接入 | 渠道审核 | 待定 |

---

## 附录 A：裂变加密引擎接口定义

```typescript
// services/invite-engine.service.ts

interface InviteEngine {
  /** 生成我的分享信息（User B 端） */
  generateMyShareInfo(): Promise<string>

  /** 解析并验证他人的分享信息（User A 端） */
  verifyAndParse(shareString: string): Promise<VerifyResult>

  /** 记录一次有效分享 */
  recordValidShare(deviceTag: string): Promise<void>

  /** 获取我的有效分享次数 */
  getValidShareCount(): Promise<number>

  /** 检查是否可领取某层奖励 */
  checkRewardTier(tier: number): Promise<RewardStatus>

  /** 领取奖励 */
  claimReward(tier: number): Promise<void>

  /** 获取已领取奖励列表 */
  getClaimedRewards(): Promise<RewardItem[]>
}

interface VerifyResult {
  valid: boolean
  reason?: string     // 验证失败原因
  shareInfo?: ShareInfo
}

interface RewardStatus {
  shareCount: number
  tier: number
  required: number
  canClaim: boolean
  claimed: boolean
}
```

## 附录 B：兑换码隐蔽入口设计

- **方式一**：「关于如画」页面，连续点击品牌 LOGO 区域 7 次 → 弹出输入框
- **方式二**：设置页，在「版本号」文字上长按 3 秒 → 弹出输入框
- 输入框无视觉提示，仅在符合触发条件时动态渲染
- 兑换成功/失败均仅 toast 提示，不留痕迹

## 附录 C：女性向视觉规范补充

| 元素 | 规范 |
|---|---|
| 成就徽章 | 手绘水彩/线稿风格，暖金描边 + 淡粉/米白底，解锁前灰色半透明 |
| 等级标识 | 圆形徽章，内含等级数字，渐变暖金→米白 |
| 心情标签 | 软圆角 pill，淡彩色底（淡粉/淡紫/淡蓝等） |
| 穿搭日记 | 杂志封面排版风格，日期 + 当日照片 + 模板标签 |
| 拍照按钮 | 外圈暖金描边，内圈纯白，按压时缩小轻颤 |
| 卡片阴影 | `0 2px 12px rgba(0,0,0,0.04)`（比 v1.0 增加极微阴影，提升卡片温馨感） |
| 圆角增强 | 操作按钮 `8px`，卡片 `14px`（比 v1.0 略大，更柔和） |
