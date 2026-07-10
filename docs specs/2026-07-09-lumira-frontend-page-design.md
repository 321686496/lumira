# 如画 Lumira 前端页面设计文档

> 文档版本：v2.1
> 创建日期：2026-07-09
> 文档类型：前端页面综合设计规格
> 基础产品：如画 Lumira（完全离线随身摄影工具）
> 配套文档：`2026-07-03-lumira-prd.md` · `2026-07-03-lumira-brand.md` · `2026-07-06-lumira-v2-features-design.md` · `2026-07-06-lumira-v2-business-optimization.md` · `2026-07-08-lumira-v2-theme-system-design.md`

---

## 0. 文档说明

本文档基于 V1 核心功能重建设计、V2 功能扩展设计、V2 商业化优化设计、V2 主题系统设计四份文档的综合，重新编写前端页面设计文档，统一描述所有页面的布局、交互、导航与视觉规格。

### 0.1 设计原则

| 原则 | 说明 |
|---|---|
| 完全离线 | 零网络权限约束，所有功能本地化 |
| 女性优先 | 面向女性用户，柔和、精致、情感化设计 |
| 品牌一致 | 严格遵循暖金+米白+墨色体系，编辑式留白风格 |
| 主题驱动 | 4套主题可变，布局参数化配置 |
| 克制扩展 | 不破坏极简调性，功能增量"补全体验" |

### 0.2 品牌与视觉基础

承接 `2026-07-03-lumira-brand.md` 定义的品牌体系：

- **品牌色**：暖金 `#C9A96E` + 米白 `#FAF7F2` + 墨色 `#1A1A1A`
- **字体**：思源宋体（标题/Serif）+ 思源黑体（正文/Sans）+ SF Mono（数字）
- **间距**：8px 栅格系统，常用 24/32/48/64
- **圆角**：按钮 6px，卡片 12px，徽章 pill
- **风格**：东方编辑式留白，稀疏排版，暖金点缀

---

## 1. 导航架构

### 1.1 悬浮 Tab 栏（5+1 布局）

```
  ╭──────────────────────────────────────────────╮
  │   ◪       ▦              ◉              🎯   │
  │  首页    [模板]         [拍摄]         挑战  │
  │                                           ○  │
  │                                          我的│
  ╰──────────────────────────────────────────────╯
```

| 位置 | 页面 | 类型 | 路径 | 图标 |
|---|---|---|---|---|
| 左1 | 首页 | Tab | `/pages/home/index` | 取景框 |
| 左2 | 模板库 | Tab | `/pages/templates/index` | 叠图方框 |
| **中** | **拍摄** | **浮动按钮** | `/pages/capture/index` | 快门圆 |
| 右1 | 挑战 | Tab | `/pages/challenge/index` | 目标星 |
| 右2 | 我的 | Tab | `/pages/profile/index` | 人像 |

**导航设计原则**：
- **首页**：聚合入口，快速触达核心操作
- **模板库**：高频功能前置，方便用户浏览发现拍摄模板
- **拍摄**：核心功能，居中浮动突出
- **挑战**：游戏化驱动，提升日活与留存
- **我的**：个人中心，设置与管理入口

**浮动拍摄按钮规格**：
- 直径 56px，暖金描边 `#C9A96E` 2px，内圈纯白 `#FFFFFF`
- 突出 Tab 栏上沿 12px，视觉上"浮起"
- 按下：`scale(0.92)` + 轻柔振动
- 位于 Tab 栏正中央，不与左/右 Tab 重叠

### 1.2 TabBar 主题变体

根据当前主题，TabBar 呈现不同形态（详见第 8 章主题系统）：

| 主题 | TabBar 样式 | 路径 |
|---|---|---|
| warm（暖米白） | 悬浮胶囊 | `TabBarFloating.vue` |
| ink（浓墨） | 悬浮胶囊（深色态） | `TabBarFloating.vue` |
| retro（胶片复古） | 紧凑横条 | `TabBarCompact.vue` |
| fresh（日系清新） | 极简线条 | `TabBarMinimal.vue` |

### 1.3 完整路由表

| 路径 | 页面 | Tab | 导航方式 |
|---|---|---|---|
| `/pages/splash/index` | 启动页 | 否 | 冷启动自动展示 |
| `/pages/home/index` | 首页 | **是** | Tab 左1 |
| `/pages/templates/index` | 模板库 | **是** | Tab 左2 |
| `/pages/capture/index` | 拍摄页 | **中按钮** | Tab 中按钮 |
| `/pages/capture/preview` | 拍摄预览 | 否 | 拍摄后 push |
| `/pages/capture/parameters` | 参数面板 | 否 | 半屏弹窗 |
| `/pages/capture/scene-guide` | 场景向导 | 否 | 底部弹窗 |
| `/pages/templates/detail` | 模板详情 | 否 | **入口页**，从首页/模板库进入 |
| `/pages/templates/unlock` | 模板解锁面板 | 否 | 弹出式（付费模板） |
| `/pages/templates/editor` | 模板编辑器 | 否 | 从我的页进入 |
| `/pages/templates/import` | 模板导入 | 否 | 从我的页进入 |
| `/pages/challenge/index` | 每日挑战 | **是** | Tab 右1 |
| `/pages/challenge/detail` | 挑战详情 | 否 | 单个挑战的完整描述与进度 |
| `/pages/gallery/index` | 相册 | 否 | 从首页进入 |
| `/pages/gallery/detail` | 照片详情/后期 | 否 | 从相册/预览进入 |
| `/pages/gallery/diary` | 拍摄日记 | 否 | 时间轴视图 |
| `/pages/profile/index` | 我的 | **是** | Tab 右2 |
| `/pages/profile/settings` | 设置 | 否 | 从我的页进入 |
| `/pages/profile/settings/theme` | 主题选择 | 否 | 从设置页进入 |
| `/pages/profile/growth` | 成长中心 | 否 | 成就/等级/统计 |
| `/pages/profile/invite` | 邀请有礼 | 否 | 裂变分享入口 |
| `/pages/profile/academy` | 摄影美学院 | 否 | 教程列表 |
| `/pages/profile/academy-detail` | 教程详情 | 否 | 单篇教程阅读 |
| `/pages/profile/collections` | 精选集管理 | 否 | 创建/编辑精选集 |
| `/pages/profile/collection-detail` | 精选集详情 | 否 | 精选集内照片 |

### 1.4 全局导航流

```
[Splash] ──自动──→ [Tab: 首页]

[Tab: 首页]
  ├── 今日灵感"试试看" ──→ /capture/index（带模板ID）
  ├── 最近拍摄点击 ──→ /gallery/detail
  ├── "我的相册" ──→ /gallery/index → /gallery/detail
  ├── 推荐模板点击 ──→ /templates/detail  ← 入口页
  │     ├── "套用此模板拍摄" ──→ /capture/index（带模板ID）
  │     └── "查看全部" ──→ /templates/index
  ├── 拍摄场景标签 ──→ /templates/index（带场景筛选）
  └── 统计概览 ──→ /profile/index

[Tab: 模板库]
  ├── 分类筛选（人像/风光/美食/夜景...）
  ├── 模板卡片点击 ──→ /templates/detail
  │     ├── "套用此模板拍摄" ──→ /capture/index（带模板ID）
  │     └── 付费模板 ──→ /templates/unlock
  └── 搜索功能

[中按钮: 拍摄] ──→ /capture/index
  ├── 拍摄完成 ──→ /capture/preview
  │     ├── 后期编辑 ──→ /gallery/detail
  │     └── 生成对比卡
  ├── 场景向导 ──→ /capture/scene-guide
  └── 参数面板 ──→ /capture/parameters

[Tab: 挑战]
  ├── 今日主挑战 ──→ /challenge/detail
  ├── 支线挑战A ──→ /challenge/detail
  ├── 支线挑战B ──→ /challenge/detail
  ├── "去完成" ──→ /capture/index（带模板ID）
  └── 挑战历史/成就

[Tab: 我的]
  ├── 成长中心 ──→ /profile/growth
  ├── 摄影美学院 ──→ /profile/academy
  ├── 邀请有礼 ──→ /profile/invite
  ├── 我的相册 ──→ /gallery/index
  ├── 拍摄日记 ──→ /gallery/diary
  ├── 精选集 ──→ /profile/collections
  ├── 创建模板 ──→ /templates/editor
  ├── 导入模板 ──→ /templates/import
  └── 设置 ──→ /profile/settings
```

---

## 2. Splash 启动页

### 2.1 页面规格

| 属性 | 规格 |
|---|---|
| 路径 | `/pages/splash/index` |
| 展示时机 | APP 冷启动 |
| 背景 | 暖米白 `#FAF7F2` |
| 中心内容 | LOGO 符号标（取景框+斜光），居中 |
| 底部文字 | "如画 Lumira"（衬线）+ "如你所见，皆成画卷"（caption 灰） |
| 动效 | LOGO opacity 0→1（600ms），文字延迟 200ms 淡入 |
| 最短展示 | 1.5s（品牌曝光），最长不超过 3s |
| 跳转 | 自动跳转首页 `/pages/home/index` |

### 2.2 页面线框

```
┌─────────────────────────────┐
│                             │
│                             │
│          ┌─────────┐        │
│          │  ◧ / ●  │        │
│          └─────────┘        │
│                             │
│         如画 Lumira          │
│       如你所见，皆成画卷      │
│                             │
│                             │
└─────────────────────────────┘
```

---

## 3. 首页设计

### 3.1 首页定位

首页是 APP 的门面，核心职责：
1. **吸引打开** — 每次打开有新鲜感
2. **快速行动** — 2 秒内触达核心操作
3. **展示价值** — 让用户看到 APP 能力
4. **建立习惯** — 每日灵感轮换

### 3.2 区块设计

| 区块 | 作用 | 内容来源 | 交互 |
|---|---|---|---|
| 品牌标题 | 品牌温度感 | 静态品牌文案 | 无 |
| 今日灵感 | 教育+灵感 | 灵感池哈希展开 | "试试看"→ 带模板进拍摄 |
| 最近拍摄 | 快速回顾+成就感 | SQLite 最近 6 张 | 点击→照片详情，"查看全部"→相册 |
| 推荐模板 | 核心价值展示 | 精选 4-6 个模板 | 点击→模板详情（入口页） |
| 拍摄场景 | 场景化导航 | 8 个场景标签 | 点击→模板库带场景筛选 |
| 统计概览 | 成就感+引导 | 本地计数 | 点击→我的页 |
| 碎片收集 | 游戏化驱动 | 碎片集齐进度 | 点击→成长中心 |

> **注意**：每日挑战已从首页移除，作为独立 Tab 页存在，专注于游戏化驱动与留存。

### 3.3 首页区块顺序（按主题变化）

根据当前主题，首页区块呈现不同顺序：

| 主题 | 区块顺序 |
|---|---|
| warm | 品牌→灵感→最近→推荐→场景→统计→碎片 |
| ink | 同 warm |
| retro | 品牌→场景→推荐→灵感→最近→碎片→统计 |
| fresh | 品牌→灵感→推荐→场景→最近→碎片→统计 |

### 3.4 页面线框

```
┌─────────────────────────────┐
│  如画                        │  ← Serif 大标题
│  如你所见，皆成画卷            │  ← caption 灰副标语
├─────────────────────────────┤
│  💡 今日灵感                  │
│  "侧身站立+回头看镜头，       │  ← 可展开灵感卡片
│   显瘦又自然 🌿"              │
│         [试试看 →]            │
├─────────────────────────────┤
│  最近拍摄           查看全部 → │
│  ┌────┐ ┌────┐ ┌────┐       │  ← 横滑照片条
│  │ 📷 │ │ 📷 │ │ 📷 │       │
│  └────┘ └────┘ └────┘       │
├─────────────────────────────┤
│  推荐模板           查看全部 → │
│  ┌──────────┐┌──────────┐   │  ← 横滑模板卡片
│  │  ☕ 咖啡馆  ││ 🌅 日落   │   │     带场景标签
│  │  半身人像  ││ 逆光剪影  │   │
│  └──────────┘└──────────┘   │
├─────────────────────────────┤
│  拍摄场景                    │
│  ☕ 咖啡馆  🌸 花店  🏖️ 海边  │  ← 场景快选 pill
│  🏙️ 街拍  🛍️ 探店  🏠 居家   │
│  🎂 纪念日  👭 合照           │
├─────────────────────────────┤
│  🧩 碎片收集                  │
│  ┌────┐┌────┐┌────┐┌────┐    │
│  │人像││风光││美食││街拍│    │  ← 4列进度砖
│  │3/5 ││1/5 ││2/5 ││0/5 │    │
│  └────┘└────┘└────┘└────┘    │
├─────────────────────────────┤
│  128     36      12    Lv.12 │  ← 统计概览
│  拍摄张  模板   收藏   等级    │
│      ╭───────────────╮      │
│      │  ◪   ◉   ○     │      │  ← 悬浮 Tab（5+1 布局）
│      ╰───────────────╯      │
└─────────────────────────────┘
```

### 3.5 首页 Composable

| Composable | 职责 |
|---|---|
| `useDailyInspiration` | 每日灵感轮换（日期哈希） |
| `useSceneGuide` | 8 场景定义与模板筛选 |
| `useTemplateFragment` | 碎片收集进度管理 |

---

## 4. 关键页面布局

### 4.1 拍摄页（沉浸深色）

| 属性 | 规格 |
|---|---|
| 路径 | `/pages/capture/index` |
| 入口 | Tab 中按钮 / 模板详情"套用拍摄" / 首页灵感"试试看" |
| 核心功能 | 取景器+叠图+快门 |
| 主题 | 深色沉浸，Tab 栏切换深色玻璃态 |

```
┌─────────────────────────────┐
│ ≡ 旅行人像       🌐 ⚙      │  ← 半透明顶栏（设置+场景）
│                             │
│  ┌─ ─ ┬─ ─ ┬─ ─ ┐          │
│  │    │    │    │           │  ← 取景器全屏 + 三分法叠图
│  ├─ ─ ┼─ ─ ┼─ ─ ┤          │     品牌金半透明线
│  │    │ ◇  │    │           │  ← 姿势剪影叠图（可选）
│  ├─ ─ ┼─ ─ ┼─ ─ ┤          │
│  │    │    │    │           │
│  └─ ─ ┴─ ─ ┴─ ─ ┘          │
│                             │
│ ⊹ 水平  EV+0.3  WB 5200K    │  ← 参数指示 pill
│          （ ◉ ）             │  ← 快门按钮 56px 圆
│  ┌───┐ ┌───┐ ┌───┐ ┌───┐   │  ← 底部最近模板横滑
│  │模板││模板││模板││模板│   │
│  └───┘ └───┘ └───┘ └───┘   │
│    ╭───────────────────╮    │
│    │  ◪   ◉   ○        │    │  ← 悬浮 Tab（深色态）
│    ╰───────────────────╯    │
└─────────────────────────────┘
```

**快捷手势**：
| 手势 | 操作 |
|---|---|
| 双击取景器 | 切换前后摄像头 |
| 长按画面 | 锁定曝光/对焦 |
| 双指捏合 | 数码变焦 |
| 左滑/右滑取景器 | 快速切换最近模板 |

**底部最近模板画廊**：
- 最多显示最近 6 个模板
- 点击直接切换模板，叠图立即更新，无跳转

### 4.2 场景向导页

**入口**：拍摄页右上角场景图标按钮（`🌐`）

```
┌─────────────────────────────┐
│                             │
│  ╭───────────────────────╮  │
│  │                       │  │
│  │   场景向导（底部弹窗）  │  │
│  │                       │  │
│  │  ┌─────┐ ┌─────┐      │  │
│  │  │ ☕  │ │ 🌸  │      │  │
│  │  │咖啡馆│ │花店 │      │  │
│  │  └─────┘ └─────┘      │  │
│  │  ┌─────┐ ┌─────┐      │  │
│  │  │ 🏖️  │ │ 🏙️  │      │  │
│  │  │海边 │ │街拍 │      │  │
│  │  └─────┘ └─────┘      │  │
│  │  ┌─────┐ ┌─────┐      │  │
│  │  │ 🛍️  │ │ 🏠  │      │  │
│  │  │探店 │ │居家 │      │  │
│  │  └─────┘ └─────┘      │  │
│  │  ┌─────┐ ┌─────┐      │  │
│  │  │ 🎂  │ │ 👭  │      │  │
│  │  │纪念日│ │合照 │      │  │
│  │  └─────┘ └─────┘      │  │
│  │                       │  │
│  └───────────────────────┘  │
└─────────────────────────────┘
```

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

### 4.3 模板详情页（入口页）

**核心变更**：模板详情页作为拍摄入口，带"套用此模板拍摄"墨黑 CTA。

```
┌─────────────────────────────┐
│ ← 模板详情                   │
│                             │
│ ┌─────────────────────────┐ │
│ │    叠图预览大图           │ │  ← 构图叠图+姿势轮廓
│ │   （可切换显示/隐藏）      │ │
│ └─────────────────────────┘ │
│                             │
│ 日落逆光剪影 ⭐精选           │  ← Serif 标题 + 等级标签
│ ◆构图 ◆姿势 ◆参数 ◆后期     │  ← 能力标签
│                             │
│ ─── 场景指南 ───             │
│ 💡 光线：逆光               │
│ 📏 距离：3-5m               │
│ 🎩 道具：宽檐帽、纱巾        │
│ 📝 让模特侧身，轮廓更清晰    │
│                             │
│ ─── 相机参数建议 ───         │
│ EV -0.7  ISO 100  1/200s    │  ← 等宽字体
│ WB: 日光  镜头: 主摄         │
│                             │
│ ─── 示例作品 ───             │
│ ┌──────┐┌──────┐            │
│ │ 示例1 ││ 示例2 │            │
│ └──────┘└──────┘            │
│                             │
│ ─── 解锁状态 ───             │
│ ✅ 已解锁 / 🔒 待解锁        │  ← 付费模板显示解锁面板入口
│                             │
│ [ 套用此模板拍摄 ]            │  ← 墨黑 CTA
└─────────────────────────────┘
```

### 4.4 模板解锁面板

点击锁定的精选/大师模板时，弹出解锁选择面板，展示所有可用路径及当前进度：

```
┌────────────────────────────────────────┐
│           ⭐ 日系胶片 · 精选模板          │
│          解锁方式任选其一                 │
│                                        │
│  ┌───────────────────────────────────┐ │
│  │ 📺 看广告解锁（30秒）       [去观看]│ │
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

**交互规则**：
- 用户可随时切换已选择的解锁路径
- 行为解锁路径在模板卡片缩略图上显示进度条
- 用户选择「分享解锁」后直接唤起分享面板，分享后自动累加
- 用户选择「行为解锁」后，拍摄/编辑/模板使用会自动计数

### 4.5 模板库页

双列瀑布流（fresh 主题为单列大卡），分类横滑 pill 筛选。

```
┌─────────────────────────────┐
│  模板                        │  ← Serif 大标题
│  108 个内置模板               │  ← 副标题
│                             │
│ ［全部］人像  风光  美食  夜景 │  ← 分类横滑标签
│                             │
│ ┌───────────┐ ┌───────────┐ │
│ │     ⭐    │ │     💎    │ │  ← 付费标记
│ │   缩略图   │ │   缩略图   │ │
│ │           │ │           │ │
│ │ 晨光人像   │ │ 电影调色   │ │
│ │ ◆ 构图·参数 │ │ ◆ 大师模板 │ │
│ └───────────┘ └───────────┘ │
│ ┌───────────┐ ┌───────────┐ │
│ │           │ │           │ │
│ │ ...      │ │  ...      │ │
│ └───────────┘ └───────────┘ │
│      ╭───────────────╮      │
│      │  ◪   ◉   ○     │      │  ← 悬浮 Tab
│      ╰───────────────╯      │
└─────────────────────────────┘
```

**网格列数按主题变化**：
| 主题 | 列数 | 卡片宽高比 |
|---|---|---|
| warm/ink/retro | 2列 | 3:4 / 1:1 |
| fresh | 1列（杂志感） | 4:5 |

### 4.6 每日挑战页

每日挑战作为独立 Tab，是游戏化体系的核心入口，驱动日活与留存。

| 属性 | 规格 |
|---|---|
| 路径 | `/pages/challenge/index` |
| 入口 | Tab 右1 |
| 核心功能 | 今日挑战展示、进度追踪、奖励领取 |

```
┌─────────────────────────────┐
│  挑战                        │  ← Serif 大标题
│  今日挑战 · 2026年7月9日      │  ← 日期副标题
│                             │
│ ┌─────────────────────────┐ │
│ │  🎯 今日主挑战            │ │
│ │  ───────────────────    │ │
│ │  用三分法构图拍一张人像    │ │  ← 主挑战卡片（暖金边框）
│ │                         │ │
│ │  进度：○ 未完成          │ │
│ │  奖励：+30 XP            │ │
│ │                         │ │
│ │  [ 去完成 → ]            │ │  ← 墨黑 CTA
│ └─────────────────────────┘ │
│                             │
│ ─── 支线挑战 ───             │
│ ┌─────────────────────────┐ │
│ │ 🎯 支线A                  │ │
│ │ 用3个不同模板各拍一张      │ │
│ │ ████████░░ 2/3  +15 XP  │ │  ← 进度条 + 奖励
│ └─────────────────────────┘ │
│ ┌─────────────────────────┐ │
│ │ 🎯 支线B                  │ │
│ │ 调色并导出1张照片         │ │
│ │ ░░░░░░░░░░ 0/1  +20 XP  │ │
│ └─────────────────────────┘ │
│                             │
│ ─── 连续打卡 ───             │
│ 🔥 连续打卡 7 天              │  ← 打卡天数
│ ━━━━━━━━░░░░░░░░░░░         │  ← 本周打卡热力
│ 一 二 三 四 五 六 日          │
│ ✓  ✓  ✓  ✓  ✓  ✓  ○         │
│                             │
│ ─── 挑战成就 ───             │
│ ┌─────────────────────────┐ │
│ │ 🏆 初露锋芒  ✓ 已解锁     │ │  ← 成就徽章横滑
│ │ 🏆 快门手    ✓ 已解锁     │ │
│ │ 🔒 构图达人  ○ 未解锁     │ │
│ └─────────────────────────┘ │
│                             │
│ ─── 挑战历史 ───             │
│ 7月8日 · 咖啡馆探店    已完成  │
│ 7月7日 · 日落逆光      已完成  │
│ 7月6日 · 今日份好看    已完成  │
│                             │
│      ╭───────────────╮      │
│      │  ◪   ◉   ○     │      │  ← 悬浮 Tab
│      ╰───────────────╯      │
└─────────────────────────────┘
```

**交互说明**：
| 操作 | 行为 |
|---|---|
| 点击"去完成" | 跳转拍摄页，自动加载对应模板 |
| 点击已完成挑战 | 查看挑战详情与完成作品 |
| 点击成就徽章 | 查看详情与解锁条件 |
| 下拉刷新 | 检查是否有新挑战（每日 0 点刷新） |
| 打卡 | 完成任意挑战自动打卡 |

**每日挑战内容池**：
| 类型 | 示例 | 奖励 |
|---|---|---|
| 主挑战 | 用指定模板拍一张照片 | +30 XP |
| 支线A | 用 N 个不同模板各拍一张 | +15 XP |
| 支线B | 调色并导出 / 分享给好友 | +20 XP |
| 特殊挑战 | 节日/季节限定主题 | +50 XP + 专属模板 |

### 4.7 我的页

统计 Bento 卡 + 功能列表 + 成长入口。

```
┌─────────────────────────────┐
│                             │
│         我的                 │  ← Serif 标题
│                             │
│ ┌─────────────────────────┐ │
│ │  128      36     12   Lv.12│ ← 统计 Bento：拍摄/模板/收藏/等级
│ │  拍摄张   使用模板  收藏  等级│ │
│ └─────────────────────────┘ │
│                             │
│  ┌───────────────────────┐   │
│  │ 🧩 碎片收集            │   │  ← 碎片进度入口
│  │ 人像 3/5 │ 风光 1/5    │   │
│  └───────────────────────┘   │
│                             │
│  ▸ 成长中心 ─────────── Lv.12 │  ← 成就/等级/统计入口
│  ▸ 摄影美学院                │  ← 教程入口
│  ▸ 邀请有礼 ──────────── 2/3  │  ← 裂变入口（带进度）
│  ─────────────────────────  │
│  ▸ 拍摄日记                  │  ← 时间轴视图
│  ▸ 我的精选集                │  ← 精选集管理
│  ▸ 穿搭日记                  │  ← 穿搭打卡入口
│  ─────────────────────────  │
│  ▸ 我的相册                  │
│  ▸ 创建模板                  │
│  ▸ 导入模板                  │
│  ─────────────────────────  │
│  ▸ 设置                      │
│  ▸ 推荐如画       📤         │  ← 分享 APP 入口
│  ▸ 关于如画                  │
│      ╭───────────────╮      │
│      │  ◪   ◉   ○     │      │
│      ╰───────────────╯      │
└─────────────────────────────┘
```

### 4.8 成长中心页

```
┌─────────────────────────────┐
│ ← 成长中心                   │
│                             │
│ ┌─────────────────────────┐ │
│ │      Lv.12 · 进阶能手     │ │  ← 等级大徽章
│ │    ━━━━━━━━░░░░░░░░░░░   │ │  ← 经验进度条
│ │    3500 / 7000 XP        │ │
│ └─────────────────────────┘ │
│                             │
│ ─── 成就墙 ───               │
│ ┌────┐┌────┐┌────┐┌────┐    │
│ │ 🏆 ││ 🏆 ││ 🔒 ││ 🔒 │    │  ← 水彩/线稿风格徽章
│ │初露 ││快门 ││构图 ││后期 │    │
│ └────┘└────┘└────┘└────┘    │
│ ┌────┐┌────┐┌────┐┌────┐    │
│ │ 🔒 ││ 🔒 ││ 🔒 ││ 🔒 │    │
│ │百变 ││晨光 ││夜拍 ││坚持 │    │
│ └────┘└────┘└────┘└────┘    │
│                             │
│ ─── 拍摄统计 ───             │
│ 总拍摄 128 张                │
│ 本月拍摄 36 张               │
│ 已用模板 12 个               │
│ 累计编辑 45 次               │
│                             │
│ ─── 成长轨迹 ───             │
│ 2026-07-09  第100张！        │
│ 2026-06-15  解锁「街拍」模板  │
│ 2026-05-20  首次拍摄         │
└─────────────────────────────┘
```

### 4.9 摄影美学院页

```
┌─────────────────────────────┐
│ ← 摄影美学院                 │
│                             │
│  摄影美学院                  │
│  从入门到进阶的摄影教程        │
│                             │
│ ┌─────────────────────────┐ │
│ │  第1课                   │ │
│ │  找到你的最佳角度         │ │
│ │  自拍/他拍的角度技巧      │ │
│ │  ［开始学习 →］           │ │
│ └─────────────────────────┘ │
│                             │
│ ┌─────────────────────────┐ │
│ │  第2课                   │ │
│ │  光线是最好的滤镜         │ │
│ │  顺光/逆光/侧光入门      │ │
│ │  ［开始学习 →］           │ │
│ └─────────────────────────┘ │
│                             │
│ ┌─────────────────────────┐ │
│ │  第3课                   │ │
│ │  构图其实很简单           │ │
│ │  三分法/居中/框架构图     │ │
│ │  ［未解锁，完成前一课解锁］ │ │
│ └─────────────────────────┘ │
│                             │
│  第4课 · 显高显瘦的秘密（锁定）│
│  第5课 · 后期调色入门（锁定）  │
└─────────────────────────────┘
```

### 4.10 邀请有礼页

```
┌─────────────────────────────┐
│ ← 邀请有礼                   │
│                             │
│ ┌─────────────────────────┐ │
│ │   📸 照片挑战             │ │
│ │   ─────────────          │ │
│ │   邀请好友一起拍照         │ │
│ │                           │ │
│ │   [生成挑战卡]             │ │  ← 生成精美挑战卡
│ │                           │ │
│ │   已邀请 2/3 人           │ │
│ └─────────────────────────┘ │
│                             │
│ ─── 奖励阶梯 ───             │
│ ┌─────────────────────────┐ │
│ │ ⭐ 1人  ✓ 已解锁          │ │
│ │   日系胶片模板 ×1         │ │
│ ├─────────────────────────┤ │
│ │ ⭐ 3人  ● 进行中 (2/3)    │ │
│ │   法式复古模板包 ×1       │ │
│ ├─────────────────────────┤ │
│ │ ⭐ 5人  ○ 未解锁          │ │
│ │   氛围感写真模板包 ×1     │ │
│ ├─────────────────────────┤ │
│ │ 💎 8人  ○ 未解锁          │ │
│ │   全部精选 + 分享达人成就  │ │
│ └─────────────────────────┘ │
│                             │
│ ─── 邀请记录 ───             │
│ 2026-07-08  小美 ✓ 已确认   │
│ 2026-07-07  小丽 ✓ 已确认   │
│ 2026-07-05  小芳 ⏳ 待确认   │
└─────────────────────────────┘
```

### 4.11 后期编辑页

全屏工作台（不显示 Tab），工具横滑标签 + 参数滑块 + 墨黑导出 CTA。

```
┌─────────────────────────────┐
│ ✕  照片详情          对比 ⇄   │  ← 顶栏：关闭 + 前后对比
│ ┌─────────────────────────┐ │
│ │                         │ │
│ │        图像画布          │ │  ← 主画布区（居中，深色背景衬托）
│ │                         │ │
│ └─────────────────────────┘ │
│                             │
│ 调色  LUT  裁剪  磨皮  锐化   │  ← 工具横滑标签
│ ─────────────────────────── │
│  亮度   ●───────────  +12   │  ← 参数滑块区
│  对比   ────●────────   -4   │
│  饱和   ──────●──────    0   │
│  色温   ─────●───────   +8   │
│                             │
│      ［ EXIF 卡片 ］          │  ← 生成 EXIF 艺术卡片
│                             │
│      ［ 重置 ］  ［ 导出 ］    │  ← 底部操作按钮（导出为墨黑 CTA）
└─────────────────────────────┘
```

**导出选项**：
| 风格 | 内容 | 适用 |
|---|---|---|
| 极简金标 | 「如画 Lumira」暖金文字 + LOGO | 日常分享 |
| 参数标签 | 📷 f/1.8 1/200s ISO100 | 摄影爱好者 |
| 文艺角标 | Lumira · 如画，衬线小字 | 小红书/朋友圈 |
| 无标纯净 | 无水印 | 个人收藏 |

### 4.12 相册页

网格列数按主题变化（warm/ink 3列，retro/fresh 2列）。

```
┌─────────────────────────────┐
│  相册                日记 📅 │  ← 顶部切换：网格/日记视图
│  128 张照片                  │
│                             │
│ ┌────┐ ┌────┐ ┌────┐       │
│ │    │ │ ❤️ │ │    │       │  ← 收藏标记
│ │    │ │    │ │    │       │
│ └────┘ └────┘ └────┘       │
│ ┌────┐ ┌────┐ ┌────┐       │
│ │ 🎽 │ │    │ │ ☕ │       │  ← 穿搭/场景标签
│ │    │ │    │ │    │       │
│ └────┘ └────┘ └────┘       │
│ ┌────┐ ┌────┐ ┌────┐       │
│ │    │ │    │ │    │       │
│ └────┘ └────┘ └────┘       │
│                             │
│ ─── 筛选 ───                 │
│ 全部  穿搭  收藏  咖啡馆  街拍│  ← 心情/场景筛选 pill
│                             │
│      ╭───────────────╮      │
│      │  ◪   ◉   ○     │      │
│      ╰───────────────╯      │
└─────────────────────────────┘
```

**批量操作**：
- 长按进入多选模式
- 支持：批量删除、批量导出（无水印/带水印/带对比卡）
- 滑动连选手势

### 4.13 拍摄日记页

```
┌─────────────────────────────┐
│ ← 拍摄日记                   │
│                             │
│ ─── 2026年7月 ───            │
│ ┌─────────────────────────┐ │
│ │ 7月9日 · 咖啡馆半身       │ │
│ │ ┌────┐ ┌────┐           │ │
│ │ │ 📷 │ │ 📷 │           │ │
│ │ └────┘ └────┘           │ │
│ └─────────────────────────┘ │
│ ┌─────────────────────────┐ │
│ │ 7月8日 · 日落逆光         │ │
│ │ ┌────┐                  │ │
│ │ │ 📷 │                  │ │
│ │ └────┘                  │ │
│ └─────────────────────────┘ │
│ ┌─────────────────────────┐ │
│ │ 7月6日 · 今日份好看 🎽    │ │  ← 穿搭日记标记
│ │ ┌────┐ ┌────┐ ┌────┐    │ │
│ │ │ 📷 │ │ 📷 │ │ 📷 │    │ │
│ │ └────┘ └────┘ └────┘    │ │
│ └─────────────────────────┘ │
│                             │
│      ╭───────────────╮      │
│      │  ◪   ◉   ○     │      │
│      ╰───────────────╯      │
└─────────────────────────────┘
```

### 4.14 穿搭日记页

```
┌─────────────────────────────┐
│ ← 穿搭日记                   │
│                             │
│  连续打卡 7 天 🔥             │  ← 连续打卡天数
│                             │
│ ─── 本周穿搭 ───             │
│ ┌─────────────────────────┐ │
│ │     今日穿搭 · 7月9日     │ │  ← 杂志封面排版
│ │  ┌─────────────────┐    │ │
│ │  │                 │    │ │
│ │  │    当日照片      │    │ │
│ │  │                 │    │ │
│ │  └─────────────────┘    │ │
│ │  模板：咖啡馆半身          │ │
│ │  心情：温柔               │ │
│ └─────────────────────────┘ │
│                             │
│ ─── 打卡日历 ───             │
│  一  二  三  四  五  六  日    │
│  ✓   ✓   ✓   ✓   ✓   ✓   ○   │  ← 日历打卡热力图
│                             │
│ ─── 打卡奖励 ───             │
│  3天 ✓ 极简日记              │
│  7天 ✓ 一周穿搭合成图        │
│ 14天 ○ 杂志风排版            │
│ 30天 ○ 月度手帐长图          │
└─────────────────────────────┘
```

### 4.15 精选集管理页

```
┌─────────────────────────────┐
│ ← 我的精选集          + 新建 │
│                             │
│ ┌─────────────────────────┐ │
│ │ ┌────┐                  │ │
│ │ │ 📷 │  我最爱的九张      │ │
│ │ └────┘  9张照片          │ │
│ └─────────────────────────┘ │
│ ┌─────────────────────────┐ │
│ │ ┌────┐                  │ │
│ │ │ 📷 │  旅行精选         │ │
│ │ └────┘  15张照片         │ │
│ └─────────────────────────┘ │
│ ┌─────────────────────────┐ │
│ │ ┌────┐                  │ │
│ │ │ 📷 │  穿搭合集 🎽      │ │
│ │ └────┘  23张照片         │ │
│ └─────────────────────────┘ │
│                             │
│      ╭───────────────╮      │
│      │  ◪   ◉   ○     │      │
│      ╰───────────────╯      │
└─────────────────────────────┘
```

### 4.16 设置页

```
┌─────────────────────────────┐
│ ← 设置                       │
│                             │
│  ▸ 主题 ─────────── 暖米白   │  ← 跳转主题选择页
│  ▸ 网格显示 ──────── 3列     │
│  ▸ 水平仪 ────────── 开      │
│  ▸ 直方图 ────────── 关      │
│  ▸ 快门振动 ──────── 开      │
│  ▸ 水印样式 ──────── 极简金标 │
│  ─────────────────────────  │
│  ▸ 导出质量 ──────── 高质量  │
│  ▸ 默认镜头 ──────── 主摄    │
│  ▸ 保留 EXIF ─────── 开     │
│  ─────────────────────────  │
│  ▸ 存储管理                  │
│  ▸ 清除缓存                  │
│  ─────────────────────────  │
│  ▸ 打赏支持                  │  ← ¥6/12/18 三档
│  ▸ 推荐如画       📤         │
│  ▸ 关于如画 ──── v1.0.0     │  ← 长按LOGO隐藏入口
│                             │
│      ╭───────────────╮      │
│      │  ◪   ◉   ○     │      │
│      ╰───────────────╯      │
└─────────────────────────────┘
```

### 4.17 主题选择页

```
┌─────────────────────────────────┐
│  ←  主题选择                     │
├─────────────────────────────────┤
│                                 │
│  ┌───────────┐  ┌───────────┐  │
│  │  暖米白 ✓  │  │  浓墨     │  │
│  │  ━━━━━━━ │  │  ━━━━━━━ │  │
│  │  温暖留白  │  │  深色沉浸 │  │
│  │  [floating]│  │ [floating]│  │
│  └───────────┘  └───────────┘  │
│                                 │
│  ┌───────────┐  ┌───────────┐  │
│  │ 胶片复古   │  │ 日系清新  │  │
│  │  ━━━━━━━ │  │  ━━━━━━━ │  │
│  │  暖橘深棕  │  │  淡粉米白 │  │
│  │  [compact] │  │ [minimal] │  │
│  └───────────┘  └───────────┘  │
│                                 │
│  ─────────────────────────────  │
│  跟随系统                  [ ]  │
│  （仅浅色/深色自动切换）         │
│                                 │
│  ─────────────────────────────  │
│  效果预览                        │
│  ┌─────────────────────────┐   │
│  │                         │   │
│  │    [主题效果实时预览]     │   │
│  │                         │   │
│  └─────────────────────────┘   │
│                                 │
│      ╭───────────────╮         │
│      │  ◪   ◉   ○     │         │
│      ╰───────────────╯         │
└─────────────────────────────────┘
```

**预览卡设计**：
- 背景：该主题的 bg-canvas 色
- 顶部色条：该主题的 brand-primary 色
- 中部：3 行示例文字（用 text-primary/secondary/tertiary 色）
- 底部：mini TabBar 缩略（floating/compact/minimal 三种形态示意）
- 当前主题：右上角暖金勾选标记 ✓
- 点击：立即切换 data-theme，所有预览卡实时更新颜色

---

## 5. 特殊组件与弹窗

### 5.1 前后对比卡

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

### 5.2 EXIF 艺术卡片

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

### 5.3 每月摄影手帐

```
┌─────────────────────────┐
│                         │
│   我的 7 月摄影手帐      │
│      · Lumira ·         │
│                         │
│  ┌────┐┌────┐┌────┐     │
│  │ 📷 ││ 📷 ││ 📷 │     │
│  └────┘└────┘└────┘     │
│  ┌────┐┌────┐┌────┐     │
│  │ 📷 ││ 📷 ││ 📷 │     │
│  └────┘└────┘└────┘     │
│                         │
│  7/9 咖啡馆半身          │
│  7/8 日落逆光            │
│  7/6 今日份好看          │
│                         │
│  ───────────────────    │
│  本月统计                │
│  拍摄 36 张 | 模板 8 个  │
│                         │
│  你也想拍出这样的照片吗？ │
│       📸 下载如画        │
└─────────────────────────┘
```

### 5.4 成就解锁通知

```
┌─────────────────────────┐
│                         │
│           🏆             │
│                         │
│      「初露锋芒」         │
│      成就解锁！           │
│                         │
│   完成第1次拍摄           │
│                         │
│      [ 领取奖励 ]        │
│                         │
└─────────────────────────┘
```

### 5.5 心情标签选择器

```
┌─────────────────────────────┐
│                             │
│     今天的心情是？            │
│                             │
│  [😊开心] [😎甜酷] [🌸温柔]   │
│  [📷复古] [🍃清新] [🎨文艺]   │
│  [🌿治愈]                   │
│                             │
│       [ 跳过 ]              │
│                             │
└─────────────────────────────┘
```

---

## 6. 组件树

```
App.vue
├── FloatingTabBar.vue / TabBarCompact.vue / TabBarMinimal.vue  # TabBar 变体
│
├── [Splash] SplashPage.vue
│   └── BrandLogo.vue
│
├── [Tab: 首页] HomePage.vue
│   ├── BrandHeader.vue             # 品牌标题区
│   ├── DailyInspiration.vue        # 今日灵感卡片
│   ├── RecentPhotos.vue            # 最近拍摄横滑
│   ├── FeaturedTemplates.vue       # 推荐模板横滑
│   ├── SceneQuickAccess.vue        # 拍摄场景快选
│   ├── StatsSummary.vue            # 统计概览卡
│   └── FragmentProgress.vue        # 碎片收集进度
│
├── [Tab: 模板库] TemplateIndex.vue
│   ├── CategoryTabs.vue            # 分类横滑标签
│   └── TemplateCard.vue[]          # 模板卡片列表
│
├── [中按钮: 拍摄] CaptureIndex.vue
│   ├── CaptureHeader.vue           # 半透明顶栏
│   ├── CameraViewfinder.vue        # 取景器（全屏）
│   │   ├── OverlayLayer.vue
│   │   │   ├── RuleOfThirdsGrid.vue
│   │   │   ├── GuideLines.vue
│   │   │   └── PoseOverlay.vue
│   │   └── ParameterBar.vue
│   ├── ShutterButton.vue
│   ├── QuickTemplateBar.vue        # 最近模板横滑
│   └── SceneGuideSheet.vue         # 场景向导底部弹窗
│
├── CapturePreview.vue
│   ├── CompareToggle.vue
│   └── BeforeAfterCard.vue         # 生成对比卡按钮
│
├── [Tab: 挑战] ChallengeIndex.vue
│   ├── ChallengeHeader.vue         # 挑战页顶栏
│   ├── MainChallengeCard.vue       # 今日主挑战卡片
│   ├── SubChallengeList.vue        # 支线挑战列表
│   ├── StreakCalendar.vue          # 连续打卡日历
│   ├── AchievementBadgeRow.vue     # 成就徽章横滑
│   └── ChallengeHistory.vue        # 挑战历史列表
│
├── ChallengeDetail.vue             # 挑战详情
│
├── [Tab: 我的] ProfileIndex.vue
│   ├── ProfileStats.vue            # 统计 Bento + 等级
│   ├── FragmentProgress.vue        # 碎片收集
│   └── ProfileMenu.vue             # 功能列表
│
├── CaptureParams.vue               # 参数面板（半屏弹窗）
│
├── TemplateDetail.vue              # 模板详情（入口页）
│   ├── OverlayPreview.vue
│   ├── SceneGuidePanel.vue
│   ├── CameraParamsPanel.vue
│   ├── ExampleGallery.vue
│   └── UnlockButton.vue            # 解锁/套用按钮
│
├── TemplateUnlock.vue              # 解锁面板（弹出式）
│   └── UnlockPathList.vue          # 解锁路径列表
│
├── TemplateEditor.vue
│   ├── EditorCanvas.vue
│   └── ControlPanel.vue
│
├── TemplateImport.vue
│
├── GalleryIndex.vue
│   ├── PhotoGrid.vue
│   └── BatchBar.vue                # 批量操作栏
│
├── GalleryDetail.vue               # 后期编辑
│   ├── ImageEditor.vue
│   │   ├── AdjustmentPanel.vue
│   │   │   ├── ColorSliders.vue
│   │   │   ├── LutSelector.vue
│   │   │   ├── CropFrame.vue
│   │   │   ├── SmoothSlider.vue
│   │   │   └── SharpenSlider.vue
│   │   └── CompareToggle.vue
│   ├── PhotoInfo.vue
│   ├── ExifCard.vue                # EXIF 卡片组件
│   └── WatermarkPreview.vue        # 水印预览
│
├── GalleryDiary.vue                # 拍摄日记
│   └── DiaryTimeline.vue           # 时间轴
│
├── GrowthCenter.vue                # 成长中心
│   ├── AchievementGrid.vue         # 成就墙
│   ├── LevelProgress.vue           # 等级进度条
│   ├── GrowthTimeline.vue          # 成长时间线
│   └── StatsPanel.vue              # 详细统计
│
├── AcademyIndex.vue                # 摄影美学院
│   ├── LessonCard.vue              # 教程卡片
│   └── LessonProgress.vue          # 教程进度
│
├── AcademyDetail.vue               # 教程详情
│   └── LessonSlide.vue             # 教程幻灯片
│
├── InvitePage.vue                  # 邀请有礼
│   ├── ChallengeCard.vue           # 挑战卡预览
│   ├── RewardTierList.vue          # 奖励阶梯
│   └── InviteRecord.vue            # 邀请记录
│
├── CollectionsManagement.vue       # 精选集管理
│   └── CollectionCard.vue
│
├── CollectionDetail.vue            # 精选集详情
│
├── OutfitDiary.vue                 # 穿搭日记
│   ├── StreakCalendar.vue          # 打卡日历
│   ├── OutfitCard.vue              # 穿搭卡片
│   └── StreakRewardPanel.vue       # 打卡奖励
│
├── SettingsPage.vue
│   └── SettingItem.vue[]
│
├── ThemeSelectPage.vue             # 主题选择
│   └── ThemePreviewCard.vue        # 主题预览卡
│
└── AboutPage.vue                   # 关于如画
    └── HiddenCodeInput.vue         # 隐藏兑换码输入
```

---

## 7. 数据流与状态管理

### 7.1 数据流架构

```
[用户操作] → [Vue 组件] → [Composable] → [Service] → [SQLite/原生插件]
                  ↑                           │
                  └───── Pinia Store ←────────┘
```

### 7.2 Composable 清单

| Composable | 职责 |
|---|---|
| `useCamera` | 相机控制、叠图、拍摄 |
| `useOverlay` | 叠图渲染与切换 |
| `useImageProcessing` | 后期处理（调色/LUT/磨皮/锐化/裁剪） |
| `useTemplateEngine` | 模板解析/应用/序列化 |
| `useTemplateParser` | .pptpl JSON 解析 |
| `useFileShare` | 文件导入/导出/系统分享 |
| `useGallery` | 相册 CRUD、搜索、筛选 |
| `useDevice` | 设备信息、传感器 |
| `useDailyChallenge` | 每日挑战生成、完成状态 |
| `useDailyInspiration` | 每日灵感轮换（日期哈希） |
| `useSceneGuide` | 场景筛选模板 |
| `useAchievements` | 成就检测、解锁、通知 |
| `useLevelSystem` | 经验值管理、等级升降、称号 |
| `useMoodTag` | 心情标签存储、筛选 |
| `useCollections` | 精选集 CRUD |
| `useInviteShare` | 裂变分享信息生成/验证（离线加密引擎） |
| `useWatermark` | 水印合成（Canvas） |
| `useCompareCard` | 前后对比卡生成 |
| `useExifCard` | EXIF 艺术卡片生成 |
| `useMonthlyDigest` | 摄影手帐排版生成 |
| `useRedemptionCode` | 兑换码验证（隐藏入口） |
| `useThemeStore` | 主题切换与管理 |
| `useTemplateFragment` | 碎片收集进度管理 |
| `useOutfitDiary` | 穿搭日记打卡管理 |

### 7.3 Store 清单

| Store | 核心状态 |
|---|---|
| `capture` | isActive, activeTemplateId, overlaySettings, cameraParameters, alignmentStatus |
| `gallery` | photos, currentPhotoId, editingHistory, moodFilter, sceneFilter |
| `templates` | builtinTemplates, importedTemplates, createdTemplates, currentCategory, searchQuery, unlockRecords |
| `settings` | theme, defaultWatermark, gridColumns, histogram, shutterVibration, exportQuality |
| `growth` | achievements, userLevel, xp, totalXp, title |
| `challenge` | todayMain, todaySubA, todaySubB, completedStatus |
| `invite` | validShareCount, challengeRecords, claimedRewards |
| `fragment` | portrait, landscape, food, street counts |
| `diary` | currentStreak, longestStreak, lastCheckinDate |

### 7.4 Service 层接口

**CameraService**：
```typescript
interface CameraService {
  initialize(config: CameraConfig): Promise<void>
  startPreview(viewContainer: HTMLElement): Promise<void>
  stopPreview(): Promise<void>
  setOverlay(layer: OverlayLayer): Promise<void>
  setOverlayOpacity(opacity: number): Promise<void>
  setParameters(params: CameraParams): Promise<void>
  getParameters(): Promise<CameraParams>
  capture(): Promise<string>
  switchCamera(): Promise<void>
  detectLevel(): Promise<{ isLevel: boolean; angle: number }>
  release(): Promise<void>
}
```

**ImageProcessingService**：
```typescript
interface ImageProcessingService {
  load(path: string): Promise<ImageHandle>
  adjustColor(handle: ImageHandle, params: ColorParams): Promise<ImageHandle>
  applyLut(handle: ImageHandle, lutPath: string): Promise<ImageHandle>
  smooth(handle: ImageHandle, strength: number): Promise<ImageHandle>
  sharpen(handle: ImageHandle, strength: number): Promise<ImageHandle>
  crop(handle: ImageHandle, rect: CropRect): Promise<ImageHandle>
  rotate(handle: ImageHandle, angle: number): Promise<ImageHandle>
  vignette(handle: ImageHandle, strength: number): Promise<ImageHandle>
  grain(handle: ImageHandle, strength: number): Promise<ImageHandle>
  applyPostProcess(handle: ImageHandle, params: PostProcessParams): Promise<ImageHandle>
  export(handle: ImageHandle, options: ExportOptions): Promise<string>
  release(handle: ImageHandle): void
}
```

**TemplateEngine**：
```typescript
interface TemplateEngine {
  parse(json: string): Promise<ResolvedTemplate>
  serialize(template: LocalTemplate): Promise<string>
  validate(template: RawTemplate): ValidationResult
  checkCompatibility(version: string): CompatibilityResult
  migrate(template: RawTemplate): Promise<ResolvedTemplate>
}
```

**InviteEngine**：
```typescript
interface InviteEngine {
  generateChallengeCard(): Promise<string>
  verifyAndParse(shareString: string): Promise<VerifyResult>
  recordValidShare(deviceTag: string): Promise<void>
  getValidShareCount(): Promise<number>
  checkRewardTier(tier: number): Promise<RewardStatus>
  claimReward(tier: number): Promise<void>
  getClaimedRewards(): Promise<RewardItem[]>
}
```

### 7.5 SQLite 数据模型

```sql
-- 模板表
CREATE TABLE LocalTemplate (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  source TEXT NOT NULL,          -- 'builtin' | 'imported' | 'created'
  tier TEXT NOT NULL DEFAULT 'free',  -- 'free' | 'premium' | 'master'
  pptplJson TEXT NOT NULL,
  coverPath TEXT,
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL,
  licenseJson TEXT               -- DRM 许可信息
);

-- 照片表
CREATE TABLE LocalPhoto (
  id TEXT PRIMARY KEY,
  templateId TEXT,
  imagePath TEXT NOT NULL,
  exifJson TEXT,
  moodTag TEXT DEFAULT NULL,     -- 心情标签
  sceneTag TEXT DEFAULT NULL,    -- 场景标签
  isFavorite INTEGER DEFAULT 0,  -- 收藏
  isOutfit INTEGER DEFAULT 0,    -- 穿搭标记
  createdAt INTEGER NOT NULL
);

-- 用户设置
CREATE TABLE LocalSetting (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

-- 设备ID
CREATE TABLE LocalDeviceId (
  id TEXT PRIMARY KEY
);

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
CREATE TABLE DailyChallenge (
  date TEXT NOT NULL,
  type TEXT NOT NULL,            -- 'main' | 'sub_a' | 'sub_b'
  challengeId TEXT NOT NULL,
  completedAt INTEGER NOT NULL,
  PRIMARY KEY (date, type)
);

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

-- 用户解锁记录
CREATE TABLE UnlockRecord (
  templateId TEXT PRIMARY KEY,
  unlockMethod TEXT NOT NULL,    -- 'ad' | 'share' | 'behavior' | 'code' | 'iap' | 'free_rotation'
  unlockedAt INTEGER NOT NULL,
  extraData TEXT
);

-- 用户奖励解锁状态
CREATE TABLE UserRewards (
  rewardId TEXT PRIMARY KEY,
  rewardType TEXT NOT NULL,        -- 'template' | 'template_pack' | 'achievement' | 'master_template'
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

-- 挑战记录表（用于裂变）
CREATE TABLE ChallengeRecord (
  challengeId TEXT PRIMARY KEY,
  inviterDeviceTag TEXT NOT NULL,
  status TEXT NOT NULL,          -- 'shared' | 'confirmed'
  generatedAt INTEGER NOT NULL,
  confirmedAt INTEGER,
  confirmDeviceTag TEXT
);

-- 碎片收集表
CREATE TABLE TemplateFragment (
  fragmentType TEXT NOT NULL,    -- 'portrait' | 'landscape' | 'food' | 'street'
  count INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (fragmentType)
);

-- 打卡连续记录
CREATE TABLE DiaryStreak (
  streakType TEXT PRIMARY KEY,   -- 'diary'
  currentStreak INTEGER NOT NULL DEFAULT 0,
  longestStreak INTEGER NOT NULL DEFAULT 0,
  lastCheckinDate TEXT
);

-- 裂变统计
CREATE TABLE ReferralStats (
  statDate TEXT NOT NULL,
  sharesSent INTEGER NOT NULL DEFAULT 0,
  confirmsReceived INTEGER NOT NULL DEFAULT 0,
  dailyScore INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (statDate)
);

-- 教程进度
CREATE TABLE LessonProgress (
  lessonId TEXT PRIMARY KEY,
  completed INTEGER DEFAULT 0,
  completedAt INTEGER
);
```

### 7.6 本地存储目录扩展

```
static/
├── rewards/
│   ├── reward-catalog.json         # 奖励配置（可修改）
│   ├── redemption-codes.json       # 兑换码配置（加密）
│   └── business-config.json        # 商业化配置
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

## 8. 主题系统

### 8.1 主题配置层级

```
ThemeConfig
├── colors            颜色层（bg/text/brand/semantic/tag/capture ~26 token）
├── typography        字体层（font-family/size/weight/line-height ~15 token）
├── shape             形状层（radius/shadow ~6 token）
├── motion            动效层（duration/easing ~6 token，各主题共享）
├── iconStyle         图标风格（'line' | 'fill' | 'handdrawn'）
├── layout            布局参数层（新增）
│   ├── homeSectionOrder      首页区块顺序 string[]
│   ├── templateGridColumns   模板库网格列数 number
│   ├── galleryGridColumns    相册网格列数 number
│   ├── cardAspectRatio       卡片宽高比 string
│   └── tabBarStyle           TabBar 样式 'floating' | 'compact' | 'minimal'
└── componentVariant  组件变体标识
```

### 8.2 四套主题规范

#### 核心颜色对比

| Token | 暖米白 (warm) | 浓墨 (ink) | 胶片复古 (retro) | 日系清新 (fresh) |
|-------|--------------|-----------|-----------------|-----------------|
| `--color-bg-canvas` | #FAF7F2 | #1C1A17 | #F5E6D3 | #FAF7F2 |
| `--color-bg-card` | #FFFFFF | #262320 | #FAF0E0 | #FFFFFF |
| `--color-bg-surface` | #F2EEE6 | #2E2A26 | #EDDFC8 | #F5F0EA |
| `--color-text-primary` | #1A1A1A | #F2EEE6 | #3D2817 | #4A3F35 |
| `--color-text-secondary` | #5C5852 | #9C9690 | #6B4C2F | #8C7F70 |
| `--color-text-tertiary` | #9C9690 | #6B6660 | #9C8060 | #B8AEA0 |
| `--color-brand-primary` | #C9A96E | #D4B57A | #D4865C | #E8B4A0 |
| `--color-brand-secondary` | #A88550 | #BFA060 | #B06440 | #D89888 |
| `--color-danger` | #B85450 | #C8625C | #A04030 | #C87878 |
| `--color-success` | #7A8B5C | #8A9B6C | #6B7B4C | #9AAB7C |
| `--color-border` | #EAE5DC | #3A3530 | #E0D0B8 | #F0E8E0 |
| `--color-tag-gold-bg` | #F5EDDB | #3A3328 | #F0E0C8 | #F8EDE0 |
| `--color-tag-gold-text` | #8C7340 | #D4B57A | #8C5A30 | #A07860 |

#### 字体/形状/图标

| 维度 | warm | ink | retro | fresh |
|------|------|-----|-------|-------|
| 主字体 | PingFang SC | PingFang SC | Noto Serif SC | PingFang SC |
| 标题字体 | Noto Serif SC | Noto Serif SC | Noto Serif SC | PingFang SC |
| `--radius-button` | 6px | 6px | 4px | 8px |
| `--radius-card` | 12px | 12px | 8px | 16px |
| 图标风格 | line | line | handdrawn | line |
| 组件变体 | default | default-dark | retro | fresh |

#### 布局参数

| 参数 | warm | ink | retro | fresh |
|------|------|-----|-------|-------|
| 首页区块顺序 | 品牌→灵感→最近→推荐→场景→统计→碎片 | 同 warm | 品牌→场景→推荐→灵感→最近→碎片→统计 | 品牌→灵感→推荐→场景→最近→碎片→统计 |
| 模板库列数 | 2 | 2 | 2 | 1（单列大卡） |
| 相册列数 | 3 | 3 | 2 | 2 |
| 卡片宽高比 | 3:4 | 3:4 | 1:1 | 4:5 |
| TabBar 样式 | floating | floating | compact | minimal |

### 8.3 运行时机制

**useThemeStore** 管理当前主题，通过 `document.documentElement.setAttribute('data-theme', themeId)` 切换。布局参数通过 store 的 computed 暴露，组件直接消费。

**跟随系统**：
- H5：`matchMedia('(prefers-color-scheme: dark)')`
- APP：`uni.getSystemInfoSync().theme` + `uni.onThemeChange()`
- 仅 warm ↔ ink 自动切换

---

## 9. 性能目标

| 指标 | 目标 |
|---|---|
| 冷启动→首页 | < 3s |
| Splash 展示 | 1.5-3s |
| 相机启动 | < 1s |
| 叠图渲染 | < 50ms/帧 |
| 快门响应 | < 100ms |
| 后期处理 (1080P) | < 2s |
| 模板列表加载 | < 500ms |
| 成就检测 | < 5ms |
| 对比卡生成 | < 1s |
| EXIF 卡片生成 | < 500ms |
| 水印叠加 | < 100ms |
| 手帐排版 | < 3s |
| 分享信息生成/验证 | < 10ms |
| 安装包体积 | < 40MB |

---

## 10. 交互反馈规范

| 场景 | 反馈 |
|---|---|
| 拍摄完成 | 轻柔快门声 + 微振动 |
| 保存成功 | 右下角淡入 toast "已保存到相册" |
| 模板切换 | 叠图层淡入淡出过渡（200ms） |
| 操作失误 | 底部 tips 轻柔提示，不弹模态窗 |
| 成就解锁 | 全屏弹窗 + 徽章动画 |
| 打卡成功 | 日历格子弹动 + 连续天数更新 |
| 等级升级 | 进度条动画 + 新等级展示 |

**动效性能纪律**：所有动效仅动画 `transform` 与 `opacity`，不触发 layout。

---

## 11. 实施阶段

| 阶段 | 内容 | 交付物 |
|---|---|---|
| **Phase 0** | 设计 Token + 路由骨架 + 悬浮 Tab 栏 + Splash 页 | 可运行骨架 APP |
| **Phase 1** | 首页完整实现（含灵感、碎片收集） | 首页所有区块功能可用 |
| **Phase 2** | 模板库 + 模板详情（入口页）+ 模板导入/导出 + 解锁面板 | 模板系统闭环 |
| **Phase 3** | 拍摄页（取景器+叠图+快门+参数面板+预览+场景向导） | 拍摄功能闭环 |
| **Phase 4** | 后期编辑（调色/LUT/磨皮/锐化/裁剪/导出+EXIF卡片） | 后期编辑闭环 |
| **Phase 5** | 相册（照片网格+详情+收藏+日记+精选集）+ 批量操作 | 相册与管理闭环 |
| **Phase 6** | 每日挑战 + 成长中心 + 摄影美学院 + 邀请有礼 + 穿搭日记 | 游戏化体系闭环 |
| **Phase 7** | 主题系统（4套主题 + TabBar 变体 + 布局参数化） | 主题切换闭环 |
| **Phase 8** | 模板编辑器 + SQLite 迁移 + 集成测试 | 完整 v2.1 |

每个 Phase 内部按 Harness Engineering：骨架→接口→实现→验证。

---

## 12. 安全与合规

- 所有用户数据仅存本地 SQLite 和文件系统
- 兑换码明文本地不存储，仅存 SHA256 哈希
- 裂变分享信息含设备签名，防篡改
- 无用户数据收集，无第三方 SDK（广告接入前）
- APP 上架分类：单机离线工具
- 广告功能接入前，manifest 保持零网络权限

---

##附录 A：女性向视觉规范补充

| 元素 | 规范 |
|---|---|
| 成就徽章 | 手绘水彩/线稿风格，暖金描边 + 淡粉/米白底，解锁前灰色半透明 |
| 等级标识 | 圆形徽章，内含等级数字，渐变暖金→米白 |
| 心情标签 | 软圆角 pill，淡彩色底（淡粉/淡紫/淡蓝等） |
| 穿搭日记 | 杂志封面排版风格，日期 + 当日照片 + 模板标签 |
| 拍照按钮 | 外圈暖金描边，内圈纯白，按压时缩小轻颤 |
| 卡片阴影 | `0 2px 12px rgba(0,0,0,0.04)`（温馨感） |
| 圆角增强 | 操作按钮 `8px`，卡片 `14px`（更柔和） |

## 附录 B：兑换码隐蔽入口设计

- **方式一**：「关于如画」页面，连续点击品牌 LOGO 区域 7 次
- **方式二**：设置页，在「版本号」文字上长按 3 秒
- 输入框无视觉提示，仅在符合触发条件时动态渲染
- 兑换成功/失败均仅 toast 提示，不留痕迹

## 附录 C：可配置商业化配置

```typescript
// static/rewards/business-config.json
interface BusinessConfig {
  version: number
  templateTiers: {
    free: string[]
    premium: PremiumTemplateConfig[]
    master: PremiumTemplateConfig[]
  }
  referralTiers: ReferralTier[]
  adConfig: AdConfig
  redemptionCodes: RedemptionCodeStash
  weeklyFreeRotation: WeeklyFreeRotation
}
```

**奖励阶梯**：
| 层级 | 有效分享次数 | 解锁内容 |
|---|---|---|
| 1 | 1 | 精选模板「日系胶片」× 1 |
| 2 | 2 | 精选模板包「法式复古」（含 3 个模板） |
| 3 | 3 | 精选模板包「氛围感写真」（含 5 个模板） |
| 4 | 5 | 大师模板「电影调色」× 1 |
| 5 | 8 | 「分享达人」专属成就 + 全部精选模板包 |
| 6 | 12 | 全部大师模板 + 专属称号「裂变之神」 |