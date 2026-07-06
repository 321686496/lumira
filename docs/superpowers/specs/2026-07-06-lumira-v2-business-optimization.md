# 如画 Lumira v2.0 商业化与裂变优化设计

> 基于 v2.0 功能扩展设计的运营优化方案，聚焦模板解锁、裂变传播、游戏化留存、轻量变现四大模块。

---

## 1. 设计总纲

### 1.1 核心设计原则

| 原则 | 说明 |
|---|---|
| 纯离线可用 | 所有机制不依赖网络，数据通过本地存储 + 文件 EXIF 传递 |
| 获客为主，变现为辅 | 如画是获客引擎，画集是变现引擎；如画内部仅轻量变现 |
| 行为即价值 | 用户拍摄/分享/活跃行为本身就是「支付」，优先用行为解锁替代金钱支付 |
| 多路径选择 | 用户可自由选择广告/分享/行为/兑换码/购买多种路径解锁同一内容 |

### 1.2 全局配置架构

```typescript
// static/rewards/business-config.json
// 集中管理所有商业化配置，修改此文件无需改核心代码

interface BusinessConfig {
  version: number                           // 配置文件版本
  
  // 模板分级与解锁策略
  templateTiers: {
    free: string[]                          // 免费模板 ID 列表（开箱即用）
    premium: PremiumTemplateConfig[]        // 精选模板配置
    master: PremiumTemplateConfig[]         // 大师模板配置（复用 PremiumTemplateConfig 结构，运营侧仅开放 ad/code/iap）
  }

  // 裂变奖励阶梯
  referralTiers: ReferralTier[]

  // 广告配置
  adConfig: AdConfig

  // 兑换码
  redemptionCodes: RedemptionCodeStash

  // 运营活动
  weeklyFreeRotation: WeeklyFreeRotation
}

interface PremiumTemplateConfig {
  templateId: string
  label: string
  coverImage: string
  unlockPaths: {
    ad?: { adCount: number }
    share?: { requiredShares: number }
    behavior?: { photoCount?: number; templateUsed?: number; editCount?: number }
    code?: { /* 兑换码由独立配置管理 */ }
    iap?: { priceInCents: number; productId: string }
  }
}

// 大师模板复用 PremiumTemplateConfig 结构
// 区别在于运营侧：大师模板 unlockPaths 通常仅开放 ad/code/iap

interface ReferralTier {
  tier: number
  requiredShares: number
  rewards: {
    type: 'template' | 'template_pack' | 'achievement' | 'master_template'
    id: string
    label: string
  }[]
}

interface AdConfig {
  enabled: boolean
  rewardedUnlock: {
    enabled: boolean
    eligibleTemplateIds: string[]           // 支持广告解锁的模板列表
  }
}

interface RedemptionCodeStash {
  enabled: boolean
  // 实际运行时仅存 SHA256 哈希，不存明文
}

interface WeeklyFreeRotation {
  enabled: boolean
  premiumCount: number                      // 每周限免精选模板数（默认2）
  masterCount: number                       // 每周限免大师模板数（默认1）
  rotationDay: number                       // 轮换日（5 = 周五）
  rotationHour: number                      // 轮换小时（20 = 20:00）
  durationHours: number                     // 限免时长（48）
}
```

---

## 2. 模板多路径解锁体系

### 2.1 三级模板金字塔

| 等级 | 占比 | 用户感知 | 解锁方式 | 运营目的 |
|---|---|---|---|---|
| 🆓 免费模板 | ~60% | "这 APP 真大方" | 开箱即用，无需任何条件 | 基础留存，V0 核心体验 |
| ⭐ 精选模板 | ~30% | "我需要解锁它" | 行为/分享/广告/兑换码/IAP 任选 | 驱动核心行为 |
| 💎 大师模板 | ~10% | "高级货，值" | 广告/兑换码/IAP | 变现锚点 + 高阶荣誉 |

### 2.2 多路径解锁面板

用户点击锁定的精选/大师模板时，弹出解锁选择面板，展示所有可用路径及当前进度：

```
┌────────────────────────────────────────┐
│           ⭐ 日系胶片 · 精选模板          │
│          解锁方式任选其一                 │
│                                        │
│  ┌───────────────────────────────────┐ │
│  │ 📺 看广告解锁（30秒）              │ │
│  └───────────────────────────────────┘ │
│  ┌───────────────────────────────────┐ │
│  │ 📤 分享给好友（2/3）████████░░ 67%│ │
│  └───────────────────────────────────┘ │
│  ┌───────────────────────────────────┐ │
│  │ 🎯 拍摄 5 张照片（3/5）███░░░ 60% │ │
│  └───────────────────────────────────┘ │
│  ┌───────────────────────────────────┐ │
│  │ 🔑 输入兑换码                     │ │
│  └───────────────────────────────────┘ │
│  ┌───────────────────────────────────┐ │
│  │ 💎 ¥3.00 直接购买                 │ │
│  └───────────────────────────────────┘ │
└────────────────────────────────────────┘
```

**交互规则：**
- 用户可随时切换已选择的解锁路径
- 行为解锁路径在模板卡片缩略图上显示进度条
- 用户选择「分享解锁」后直接唤起分享面板，分享后自动累加
- 用户选择「行为解锁」后，拍摄/编辑/模板使用会自动计数，无需额外操作

### 2.3 DRM 保护：导出即标记

付费模板（精选/大师）在导出为 `.pptpl` 文件时，自动在 `meta.license` 中注入标记。

**类型扩展：**

```typescript
// src/types/template.ts 新增

interface LicenseInfo {
  sourceTemplateId: string       // 来源付费模板 ID
  requiresUnlock: boolean       // 是否需要解锁
  issuedByDevice: string        // 签发设备指纹前8位
  issuedAt: number              // 签发时间戳
}

// TemplateMeta 新增可选字段
interface TemplateMeta {
  // ... 现有字段
  license?: LicenseInfo
}
```

**导出/导入逻辑：**

| 场景 | 导出 .pptpl | 导入 .pptpl |
|---|---|---|
| 免费模板 | 无 license 字段 | 正常导入，无限制 |
| 付费模板（已解锁） | 注入 `license { requiresUnlock: true }` | 检测到 license → 弹出解锁面板 |
| 编辑器自创模板 | 无 license | 正常导入 |
| 带 license 的文件被手动删改 | — | 校验签名，取消则视为无 license（可接受） |

**防绕过说明（离线环境下的实际策略）：**

纯离线环境不存在完美 DRM。本设计的核心目标是 **摩擦足够高，覆盖 95% 普通用户**：
- 普通用户不会手动编辑 JSON 文件 → 走正规解锁路径
- 少数技术用户可手动删改 license 字段 → 这类用户本身也是核心价值用户
- 真正的商业变现来自画集社区，如画层面的「保护」只需挡住普通分享即可

**商业层面补充：**
A 付费→导出→分享给 B → B 导入看到解锁面板 → B 选择看广告/分享/行为解锁 → **如画仍获得一次变现或裂变机会**。付费用户分享不是损失，是为如画创造新的转化入口。

---

## 3. 两段式离线裂变

### 3.1 设计背景

如画 APP 为纯离线应用，无 INTERNET 权限。设备间无法通过服务器中转数据，所有信息通过**文件本身的 EXIF/metadata 嵌入**传递。

### 3.2 两段式闭环

```
                   第一段：分享即得 50%

A（已有APP）
  │  ① 点击「邀请有礼」→ 生成挑战卡
  │  ② 挑战卡 EXIF 嵌入加密邀请数据
  │  ③ 通过系统分享发出（微信/隔空投送等）
  │  ④ APP 本地记录 {challengeId, timestamp, status:'shared'}
  ▼
✅ A 即时获得 50% 进度（纯本地记录，无需网络）


                   第二段：回传即得 50%

B（新用户）
  │  ① 收到挑战卡 → 扫码/接收 → 下载如画
  │  ② 首次启动 → APP 读取挑战卡 EXIF → 检测到邀请数据
  │  ③ 完成首次拍摄
  │  ④ APP 自动生成「确认照片」，EXIF 嵌入验证信息
  │  ⑤ 提示"把照片发给邀请你的好友，你们都能获得奖励"
  │  ⑥ B 通过系统分享发给 A
  ▼
A
  │  ⑦ A 收到照片 → 在如画 APP 中打开/导入
  │  ⑧ APP 读取 EXIF → 提取 challengeId → 匹配本地记录
  │  ⑨ 验证签名/新鲜度/去重
  ▼
✅ A 获得剩余 50% → 累加至奖励阶梯
✅ B 自动解锁「新人专属模板」× 1
```

### 3.3 关键数据结构

```typescript
// A 分享时嵌入挑战卡图片 EXIF 的邀请数据
interface ChallengeCardData {
  inviterTag: string              // A 设备指纹 SHA256 前8位
  inviterAlias: string            // A 昵称（可选）
  challengeId: string             // 随机 UUID
  templateId?: string            // 可选：建议使用的模板
  generatedAt: number
  signature: string               // HMAC-SHA256
}

// B 回传时嵌入确认照片 EXIF 的验证数据
interface ChallengeConfirmData {
  deviceTag: string               // B 设备指纹前8位
  challengeId: string             // 匹配 A 的 challengeId
  hasFirstPhoto: boolean          // 已完成首次拍摄
  photoCount: number              // B 当前拍摄数
  templateUsed: number            // 使用的模板数
  timestamp: number
  signature: string               // HMAC-SHA256
}
```

### 3.4 加密签名方案

```
签名密钥 = SHA256(设备ID + "Lumira_Offline_V1")
待签名数据 = version + deviceTag + alias + generatedAt + JSON(usageProof)
signature = HMAC-SHA256(待签名数据, 签名密钥)
```

**验证规则（A 导入确认照片时）：**

| 校验项 | 规则 |
|---|---|
| 格式校验 | 正确解码 JSON + 签名 |
| 签名校验 | HMAC 匹配 |
| 新鲜度 | timestamp 在 30 天内 |
| 去重 | deviceTag 未在已处理列表中 |
| 挑战匹配 | challengeId 在 A 已发起的挑战列表中 |
| 使用门槛 | hasFirstPhoto = true |

### 3.5 防刷规则

| 规则 | 阈值 |
|---|---|
| 单日最多有效分享 | 5 条（对 A 生效） |
| 同一 deviceTag 重复计数 | 30 天内不重复（对 A/B 同时生效） |
| 确认照片有效期限 | 30 天 |
| 一个 challengeId 完成次数 | 1 次 |
| B 的新人奖励 | 同一 deviceTag 仅一次 |

### 3.6 挑战卡样式

挑战卡是一张精美的品牌图片，A 可直接分享到社交平台：

```
┌───────────────────────────────────┐
│                                   │
│         📸 照片挑战                │
│                                   │
│   [精美样片占位图]                 │
│                                   │
│   "用 @如画 Lumira 拍一张          │
│    咖啡馆人像，分享你的作品"        │
│                                   │
│   发起人：小美                     │
│                                   │
│   [二维码 · 扫码下载如画]          │
│                                   │
│   如画 · 框住光，皆成画卷          │
└───────────────────────────────────┘
```

### 3.7 裂变奖励阶梯

| 层级 | 有效分享次数 | 解锁内容 |
|---|---|---|
| 1 | 1 | 精选模板「日系胶片」× 1 |
| 2 | 2 | 精选模板包「法式复古」（含 3 个模板） |
| 3 | 3 | 精选模板包「氛围感写真」（含 5 个模板） |
| 4 | 5 | 大师模板「电影调色」× 1 |
| 5 | 8 | 「分享达人」专属成就 + 全部精选模板包 |
| 6 | 12 | 全部大师模板 + 专属称号「裂变之神」 |

B 侧奖励：完成首次拍摄 + 回传确认 → 解锁「新人专属模板」× 1

---

## 4. 游戏化留存体系

### 4.1 每日挑战「1+2」弹性模式

将原有单条每日挑战扩展为三级结构：

```
每日零点刷新（按日期哈希从 50+ 条挑战池选取）

主挑战（必做）
├── 主题/技术/模板/创意/场景/心情（随机轮换）
├── 单人行为即可完成
├── +30 XP
└── 示例："用模板拍一张人像照片"

支线 A（主挑战完成后解锁）
├── 与主挑战互补类型
├── 轻度扩展要求
├── +15 XP
└── 示例："用3个不同模板分别拍一张"

支线 B（支线 A 完成后解锁）
├── 创意型高难度
├── +20 XP + 10% 概率掉落模板碎片
└── 示例："拍一张照片完成调色并导出"
```

用户体验三档：
- 轻度：完成主挑战 → +30 XP（约 2 分钟）
- 中度：完成主+支线A → +45 XP（约 5 分钟）
- 重度：全部完成 → +65 XP + 碎片机会（约 10 分钟）

### 4.2 模板碎片收集系统

| 机制 | 说明 |
|---|---|
| 碎片类型 | 人像 / 风光 / 美食 / 街拍 四种标签 |
| 掉落来源 | 每日挑战支线 B 10% 概率获得 |
| 收集门槛 | 同类型集齐 5 个碎片 → 随机解锁该类型一个精选模板 |
| 进度展示 | 「我的」页新增「碎片收集」卡片，四列进度砖 0/5 |
| 跨类型收集 | 用户可同时收集多种类型 |
| 心理钩子 | 差 1 个凑齐时的驱动——"差最后一个，明天再来" |

### 4.3 等级里程碑奖励

| 等级 | 称号 | 解锁奖励 | 累计 XP |
|---|---|---|---|
| Lv.5 | 摄影新手 | 解锁「摄影美学院」第 1 课 | 500 |
| Lv.10 | 入门学徒 | 解锁全部课程 + 精选模板碎片 × 1 | 2000 |
| Lv.20 | 进阶能手 | 自选 2 个精选模板 | 8000 |
| Lv.30 | 高手达人 | 「穿搭日记」高级排版样式 | 20000 |
| Lv.40 | 摄影大师 | 全部免费模板高级变体 | 45000 |
| Lv.50 | 光影诗人 | 称号动画 + 金色个人主页 + 3 个大师模板 | 80000 |

### 4.4 穿搭日记连续打卡

| 连续天数 | 解锁内容 |
|---|---|
| 3 天 | 「极简日记」排版样式 |
| 7 天 | 「一周穿搭」自动合成图 + 50 XP |
| 14 天 | 「杂志风」高级排版 |
| 30 天 | 月度穿搭手帐长图 + 100 XP + 精选模板碎片 × 1 |
| 断签 | 从 0 重新开始 |

### 4.5 限时免费轮换

```
机制：
├── 每周五 20:00 自动轮换（本地时间计算）
├── 2 个精选模板 → 限时免费 48 小时
├── 1 个大师模板 → 限时免费 24 小时
├── 限时期间正常使用所有功能
└── 到期后恢复锁定状态

运营价值：
├── "试用上瘾"——用户用过后如想继续使用，走解锁路径
├── "每周五刷模板"——培养固定使用习惯
└── "错过就没"——制造限时稀缺感
```

### 4.6 经验值（XP）计分表

| 行为 | XP | 每日上限 |
|---|---|---|
| 拍摄一张照片 | +10 | 无 |
| 使用模板拍摄 | +5（可叠加） | 无 |
| 完成一次后期编辑 | +5 | 无 |
| 完成每日主挑战 | +30 | 1次 |
| 完成支线 A | +15 | 1次 |
| 完成支线 B | +20 | 1次 |
| 解锁一个成就 | +50 | 无 |
| 有效分享一次 | +20 | 5次 |
| 穿搭日记打卡 | +10/天 | 1次 |

---

## 5. 轻量变现路径

### 5.1 收入渠道总览

| 收入来源 | 触发场景 | 定价区间 | 运营阶段 |
|---|---|---|---|
| IAP 直购 | 用户不想等待行为累积 | ¥1-3/模板 | 画集上线前即可 |
| 兑换码售卖 | 品牌合作/社群运营/粉丝群 | ¥6-18/码 | 冷启动后 |
| 激励广告 | 用户主动选择看广告解锁 | 广告主付费 | 接入广告 SDK 后 |
| 打赏支持 | 「关于如画」低调入口 | ¥6/12/18 三档 | 持续 |

### 5.2 广告接入设计

**前提：如画当前为纯离线 APP，manifest 不含 INTERNET 权限。**

接入广告时需：
1. 在 manifest.json 中添加必要的网络权限声明
2. 在 `business-config.json` 中设置 `adConfig.enabled = true`
3. 集成对应渠道广告 SDK（如穿山甲/优量汇）

**广告位设计（非侵入式，用户主动选择）：**

| 广告位 | 触发方式 | 展示形式 | 预估 eCPM |
|---|---|---|---|
| 激励视频 | 用户点击「看广告解锁」 | 30 秒激励视频 | ¥30-80 |
| 开屏广告 | 启动 3 秒后 | 可跳过 | ¥15-40 |

**重要：如画不采用插屏/信息流等打断式广告。** 用户仅在主动选择「看广告解锁」路径时才会看到广告。

### 5.3 兑换码系统

```
触发入口（隐蔽，不干扰普通用户）：
├── 方式 A：「关于如画」连续点击 LOGO 7 次
├── 方式 B：设置页长按版本号 3 秒
└── 触发后弹出兑换码输入框

验证流程：
├── 输入兑换码
├── APP 计算 SHA256(输入值)
├── 比对预置哈希列表
├── 如匹配 → 解锁对应奖励
└── 如不匹配 → 提示无效码

防重用：
├── 已兑换码哈希存入 LocalSetting 表
├── 同一兑换码仅可使用一次
└── 兑换码定义（加密存储于 static/rewards/codes.json）
```

**兑换码类型：**

| 类型 | 奖励内容 | 用途场景 |
|---|---|---|
| `template` | 单个精选模板 | 品牌联名/活动 |
| `template_pack` | 精选模板包 | 付费社群/粉丝团 |
| `all_paid` | 全部付费模板 | 极少数高阶用户/KOL |

---

## 6. 数据模型扩展

### 6.1 SQLite 表结构变更

```sql
-- 模板表新增 license 字段
ALTER TABLE LocalTemplate ADD COLUMN licenseJson TEXT;

-- 用户解锁记录表（新增）
CREATE TABLE IF NOT EXISTS UnlockRecord (
  templateId TEXT PRIMARY KEY,
  unlockMethod TEXT NOT NULL,    -- 'ad' | 'share' | 'behavior' | 'code' | 'iap' | 'free_rotation'
  unlockedAt INTEGER NOT NULL,
  extraData TEXT                 -- JSON，存储路径相关的额外数据
);

-- 每日挑战完成记录（新增）
CREATE TABLE IF NOT EXISTS DailyChallenge (
  date TEXT NOT NULL,            -- '2026-07-06' 格式
  type TEXT NOT NULL,            -- 'main' | 'sub_a' | 'sub_b'
  challengeId TEXT NOT NULL,
  completedAt INTEGER NOT NULL,
  PRIMARY KEY (date, type)
);

-- 挑战记录表（用于裂变）
CREATE TABLE IF NOT EXISTS ChallengeRecord (
  challengeId TEXT PRIMARY KEY,
  inviterDeviceTag TEXT NOT NULL,
  status TEXT NOT NULL,          -- 'shared' | 'confirmed'
  generatedAt INTEGER NOT NULL,
  confirmedAt INTEGER,
  confirmDeviceTag TEXT
);

-- 碎片收集表（新增）
CREATE TABLE IF NOT EXISTS TemplateFragment (
  fragmentType TEXT NOT NULL,    -- 'portrait' | 'landscape' | 'food' | 'street'
  count INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (fragmentType)
);

-- 打卡连续记录（新增）
CREATE TABLE IF NOT EXISTS DiaryStreak (
  streakType TEXT PRIMARY KEY,   -- 'diary'
  currentStreak INTEGER NOT NULL DEFAULT 0,
  longestStreak INTEGER NOT NULL DEFAULT 0,
  lastCheckinDate TEXT
);
```

### 6.2 本地统计表（裂变数据）

```sql
CREATE TABLE IF NOT EXISTS ReferralStats (
  statDate TEXT NOT NULL,        -- '2026-07-06'
  sharesSent INTEGER NOT NULL DEFAULT 0,
  confirmsReceived INTEGER NOT NULL DEFAULT 0,
  dailyScore INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (statDate)
);
```

---

## 7. 页面与路由扩展

| 路径 | 页面 | 说明 |
|---|---|---|
| `/pages/templates/unlock` | 模板解锁面板 | 弹出式，展示多路径解锁选项 |
| `/pages/profile/invite` | 邀请有礼 | 挑战卡生成、进度展示、奖励阶梯、邀请记录 |
| `/pages/profile/growth` | 成长中心 | 成就展示、等级/经验、每日挑战、碎片收集 |
| `/pages/profile/academy` | 摄影美学院 | 内置教程列表 |
| `/pages/profile/academy-detail` | 教程详情 | 单篇教程阅读页 |
| `/pages/gallery/diary` | 拍摄日记 / 穿搭日记 | 时间轴视图 |
| `/pages/profile/collections` | 精选集管理 | 创建/编辑/查看精选集 |
| `/pages/profile/collection-detail` | 精选集详情 | 精选集内照片列表 |

---

## 8. 预期运营指标

### 8.1 关键预估 KPI

| 指标 | 优化前（v1.0 基线） | 优化后（v2.0） |
|---|---|---|
| 裂变 K 因子 | ~0.1 | 0.3-0.5 |
| 分享→激活转化率 | 15-30% | 25-40% |
| B 回传率 | 10-20%（单向回传） | 55-70%（B 有新人奖励动机） |
| 每日挑战参与率 | ~30%（单条） | 50-65%（1+2 弹性） |
| 精选模板解锁率 | ~5%（纯付费） | 20-35%（多路径选择） |
| 7 日留存 | 预估 25% | 35-45% |
| 月 ARPU（轻量变现） | ¥0 | ¥0.3-0.8 |
| 穿搭日记 7 天打卡率 | — | 25-35%（女性用户） |

### 8.2 流量增长预估（冷启动 3-6 月）

| 月 | DAU | MAU | 日新增 | 单日裂变新增占比 |
|---|---|---|---|---|
| 第 1 月 | 200-500 | 3000-8000 | 30-80 | 10% |
| 第 2 月 | 500-1200 | 8000-20000 | 80-200 | 25% |
| 第 3 月 | 1200-3000 | 20000-50000 | 200-500 | 40% |
| 第 6 月 | 3000-8000 | 50000-150000 | 500-1500 | 50%+ |

---

## 9. 扩展性清单

| 操作 | 修改文件 | 是否需要改核心代码 |
|---|---|---|
| 新增付费模板 | `static/templates/` + `business-config.json` | 否 |
| 调整解锁路径（增减广告/分享选项） | `business-config.json` 的 `unlockPaths` | 否 |
| 调整裂变奖励阶梯 | 修改 `referralTiers[]` | 否 |
| 调整限时免费轮换参数 | 修改 `weeklyFreeRotation` | 否 |
| 新增兑换码 | 更新 `codes.json` 加密条目 | 否（需发版） |
| 开启广告 | `business-config.json` 设置 `adConfig.enabled=true` + 集成 SDK | 是（需接入广告 SDK） |
| 新增每日挑战 | 向挑战池 JSON 新增条目 | 否 |
| 新增碎片类型 | `business-config.json` 新增类型条目 | 否 |
| 调整 XP 计分 | 修改 `xpRules` 配置 | 否 |
