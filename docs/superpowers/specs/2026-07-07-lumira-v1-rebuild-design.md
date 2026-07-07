# 如画 Lumira v1.0 核心功能重建设计文档

> 文档版本：v1.0
> 创建日期：2026-07-07
> 文档类型：功能与布局优化设计规格
> 基础产品：如画 Lumira（完全离线随身摄影工具）
> 配套文档：`2026-07-03-lumira-prd.md` · `2026-07-03-lumira-frontend.md` · `2026-07-03-lumira-brand.md`
> 实施策略：核心功能优先 + 骨架先行（Harness Engineering）

---

## 0. 设计背景

### 0.1 重建原因

现有 `lumira-app/` 代码仅有骨架占位符，核心功能（拍摄、叠图、模板、后期、相册）均未实现。本次重建按照已有文档体系，从零实现 v1.0 核心功能，同时优化导航架构与页面布局。

### 0.2 核心变更

| 变更项 | 原设计 | 新设计 | 理由 |
|---|---|---|---|
| 首页 | 拍摄页即首页 | 首页与拍摄页分离 | 首页作为 APP 门面，需聚合入口与展示价值 |
| Tab 结构 | 3 Tab（拍摄/模板/我的） | 3+1（首页/拍摄按钮/我的） | 中间拍摄按钮突出核心功能，模板库从首页进入 |
| Splash | 无 | 新增品牌启动页 | 品牌曝光，提升品质感 |
| 模板详情 | 普通详情页 | 入口页（"套用拍摄"CTA） | 缩短从发现模板到拍摄的路径 |

### 0.3 设计原则

| 原则 | 说明 |
|---|---|
| 完全离线 | 零网络权限约束不变 |
| 骨架先行 | 按 Harness Engineering 范式：骨架→接口→实现→验证 |
| 品牌一致 | 严格遵循品牌文档暖金+米白+墨色体系，编辑式留白风格 |
| v2.0 可扩展 | 核心功能实现中预留 v2.0 游戏化/裂变/品牌传播的衔接点 |

---

## 1. 导航架构

### 1.1 悬浮 Tab 栏（3+1 布局）

```
  ╭──────────────────────────────────╮
  │   ◪              ◉              │
  │  首页          [拍摄]           │
  │                              ○  │
  │                             我的│
  ╰──────────────────────────────────╯
```

| 位置 | 页面 | 类型 | 路径 |
|---|---|---|---|
| 左 | 首页 | Tab | `/pages/home/index` |
| **中** | **拍摄** | **浮动按钮** | `/pages/capture/index` |
| 右 | 我的 | Tab | `/pages/profile/index` |

**浮动拍摄按钮规格**：
- 直径 56px，暖金描边 `#C9A96E` 2px，内圈纯白 `#FFFFFF`
- 突出 Tab 栏上沿 12px，视觉上"浮起"
- 按下：`scale(0.92)` + 轻柔振动
- 位于 Tab 栏正中央，不与左/右 Tab 重叠

### 1.2 完整路由表

| 路径 | 页面 | Tab | 导航方式 |
|---|---|---|---|
| `/pages/splash/index` | 启动页 | 否 | 冷启动自动展示 |
| `/pages/home/index` | 首页 | **是** | Tab 左 |
| `/pages/capture/index` | 拍摄页 | **中按钮** | Tab 中按钮 |
| `/pages/capture/preview` | 拍摄预览 | 否 | 拍摄后 push |
| `/pages/capture/parameters` | 参数面板 | 否 | 半屏弹窗 |
| `/pages/templates/index` | 模板库 | 否 | 从首页进入 |
| `/pages/templates/detail` | 模板详情 | 否 | **入口页**，从首页/模板库进入 |
| `/pages/templates/editor` | 模板编辑器 | 否 | 从我的页进入 |
| `/pages/templates/import` | 模板导入 | 否 | 从我的页进入 |
| `/pages/gallery/index` | 相册 | 否 | 从首页进入 |
| `/pages/gallery/detail` | 照片详情/后期 | 否 | 从相册/预览进入 |
| `/pages/profile/index` | 我的 | **是** | Tab 右 |
| `/pages/profile/settings` | 设置 | 否 | 从我的页进入 |

### 1.3 导航流

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

[中按钮: 拍摄] ──→ /capture/index
  ├── 拍摄完成 ──→ /capture/preview
  │     └── 后期编辑 ──→ /gallery/detail
  └── 参数面板 ──→ /capture/parameters

[Tab: 我的]
  ├── 我的相册 ──→ /gallery/index
  ├── 模板库 ──→ /templates/index
  ├── 创建模板 ──→ /templates/editor
  ├── 导入模板 ──→ /templates/import
  └── 设置 ──→ /profile/settings
```

---

## 2. Splash 启动页

### 2.1 规格

| 属性 | 规格 |
|---|---|
| 展示时机 | APP 冷启动 |
| 背景 | 暖米白 `#FAF7F2` |
| 中心内容 | LOGO 符号标（取景框+斜光），居中 |
| 底部文字 | "如画 Lumira"（衬线）+ "如你所见，皆成画卷"（caption 灰） |
| 动效 | LOGO opacity 0→1（600ms），文字延迟 200ms 淡入 |
| 最短展示 | 1.5s（品牌曝光），最长不超过 3s |
| 跳转 | 自动跳转首页 `/pages/home/index` |

### 2.2 线框

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
| 今日灵感 | 每日新鲜感+教育 | 日期哈希从灵感池选取 | "试试看"→ 带模板进拍摄 |
| 最近拍摄 | 快速回顾+成就感 | SQLite 最近 6 张 | 点击→照片详情，"查看全部"→相册 |
| 推荐模板 | 核心价值展示 | 精选 4-6 个模板 | 点击→模板详情（入口页） |
| 拍摄场景 | 场景化导航 | 8 个场景标签 | 点击→模板库带场景筛选 |
| 统计概览 | 成就感+引导 | 本地计数 | 点击→我的页 |

### 3.3 线框

```
┌─────────────────────────────┐
│  如画                        │  ← Serif 大标题
│  如你所见，皆成画卷            │  ← caption 灰副标语
├─────────────────────────────┤
│  💡 今日灵感                  │
│  "侧身站立+回头看镜头，       │  ← 可展开灵感卡片
│   显瘦又自然 🌿"              │     关联推荐模板
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
│  128              36         │  ← 统计概览
│  拍摄张数        使用模板     │
└─────────────────────────────┘
```

### 3.4 首页 Composable

| Composable | 职责 |
|---|---|
| `useDailyInspiration` | 日期哈希从灵感池选取当日灵感 |
| `useSceneGuide` | 8 场景定义与模板筛选 |

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
│ ≡ 旅行人像           ⚙      │  ← 半透明顶栏
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
│    ╭───────────────────╮    │
│    │  ◪   ◉   ○        │    │  ← 悬浮 Tab（深色态）
│    ╰───────────────────╯    │
└─────────────────────────────┘
```

### 4.2 模板详情页（入口页）

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
│ 日落逆光剪影                 │  ← Serif 标题
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
│ [ 套用此模板拍摄 ]            │  ← 墨黑 CTA
└─────────────────────────────┘
```

### 4.3 模板库页

双列瀑布流，分类横滑 pill 筛选。从首页"查看全部"或"拍摄场景"标签进入。

### 4.4 我的页

统计 Bento 卡 + 功能列表。统计数字为 Serif 大字。

### 4.5 后期编辑页

全屏工作台（不显示 Tab），工具横滑标签 + 参数滑块 + 墨黑导出 CTA。

---

## 5. 组件树

```
App.vue
├── FloatingTabBar.vue              # 悬浮胶囊（3项+中按钮）
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
│   └── StatsSummary.vue            # 统计概览卡
│
├── [中按钮: 拍摄] CaptureIndex.vue
│   ├── CaptureHeader.vue           # 半透明顶栏
│   ├── CameraViewfinder.vue        # 取景器（全屏）
│   │   ├── OverlayLayer.vue
│   │   │   ├── RuleOfThirdsGrid.vue
│   │   │   ├── GuideLines.vue
│   │   │   └── PoseOverlay.vue
│   │   └── ParameterBar.vue
│   └── ShutterButton.vue
│
├── CapturePreview.vue
│   └── CompareToggle.vue
│
├── [Tab: 我的] ProfileIndex.vue
│   ├── ProfileStats.vue
│   └── ProfileMenu.vue
│
├── TemplateIndex.vue               # 从首页进入
│   ├── CategoryTabs.vue
│   └── TemplateCard.vue[]
│
├── TemplateDetail.vue              # 入口页
│   ├── OverlayPreview.vue
│   ├── SceneGuidePanel.vue
│   ├── CameraParamsPanel.vue
│   └── ExampleGallery.vue
│
├── TemplateEditor.vue
│   ├── EditorCanvas.vue
│   └── ControlPanel.vue
│
├── GalleryIndex.vue
│   └── PhotoGrid.vue
│
├── GalleryDetail.vue
│   ├── ImageEditor.vue
│   │   ├── AdjustmentPanel.vue
│   │   │   ├── ColorSliders.vue
│   │   │   ├── LutSelector.vue
│   │   │   ├── CropFrame.vue
│   │   │   ├── SmoothSlider.vue
│   │   │   └── SharpenSlider.vue
│   │   └── CompareToggle.vue
│   └── PhotoInfo.vue
│
└── SettingsPage.vue
    └── SettingItem.vue[]
```

---

## 6. 数据流与状态管理

### 6.1 数据流架构

```
[用户操作] → [Vue 组件] → [Composable] → [Service] → [SQLite/原生插件]
                  ↑                           │
                  └───── Pinia Store ←────────┘
```

### 6.2 Composable 清单

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
| `useDailyInspiration` | 每日灵感轮换（日期哈希） |
| `useSceneGuide` | 场景筛选模板 |

### 6.3 Store 清单

| Store | 核心状态 |
|---|---|
| `capture` | isActive, activeTemplateId, overlaySettings, cameraParameters, alignmentStatus |
| `gallery` | photos, currentPhotoId, editingHistory |
| `templates` | builtinTemplates, importedTemplates, currentCategory, searchQuery |
| `settings` | theme, defaultWatermark, language |

### 6.4 Service 层接口

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

### 6.5 SQLite 数据模型

```sql
CREATE TABLE LocalTemplate (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  source TEXT NOT NULL,          -- 'builtin' | 'imported' | 'created'
  pptplJson TEXT NOT NULL,
  coverPath TEXT,
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL
);

CREATE TABLE LocalPhoto (
  id TEXT PRIMARY KEY,
  templateId TEXT,
  imagePath TEXT NOT NULL,
  exifJson TEXT,
  createdAt INTEGER NOT NULL
);

CREATE TABLE LocalSetting (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE LocalDeviceId (
  id TEXT PRIMARY KEY
);
```

---

## 7. 实施阶段

| 阶段 | 内容 | 交付物 |
|---|---|---|
| **Phase 0** | 设计 Token + 路由骨架 + 悬浮 Tab 栏 + Splash 页 | 可运行骨架 APP |
| **Phase 1** | 首页完整实现 | 首页所有区块功能可用 |
| **Phase 2** | 模板库 + 模板详情（入口页）+ 模板导入/导出 | 模板系统闭环 |
| **Phase 3** | 拍摄页（取景器+叠图+快门+参数面板+预览） | 拍摄功能闭环 |
| **Phase 4** | 后期编辑（调色/LUT/磨皮/锐化/裁剪/导出） | 后期编辑闭环 |
| **Phase 5** | 相册（照片网格+详情+收藏）+ 我的页 | 相册与管理闭环 |
| **Phase 6** | 模板编辑器 + SQLite 迁移 + 集成测试 | 完整 v1.0 |

每个 Phase 内部按 Harness Engineering：骨架→接口→实现→验证。

---

## 8. 文档同步清单

| 文档 | 变更内容 |
|---|---|
| `2026-07-03-lumira-frontend.md` | 路由表新增首页/Splash、TabBar 改 3+1、组件树新增首页组件、导航图更新、首页页面 Spec |
| `2026-07-03-lumira-prd.md` | 功能架构增加首页聚合模块、模板详情入口页说明 |
| `AGENT.md` | 更新文档索引、目录结构约定 |
| `lumira-app/src/pages.json` | 新增首页/Splash 路由，清理旧路由 |

---

## 9. v2.0 衔接预留

| v1.0 模块 | v2.0 扩展方向 |
|---|---|
| 今日灵感 | 扩展为"1+2 弹性模式"每日挑战 |
| 拍摄场景快选 | 扩展为场景向导详情页 |
| 统计概览 | 扩展为等级/成就/成长轨迹 |
| 模板详情 | 增加示例画廊和多路径解锁面板 |
| 首页 | 增加穿搭日记/摄影手帐/裂变入口 |

---

## 10. 性能目标

| 指标 | 目标 |
|---|---|
| 冷启动→首页 | < 3s |
| Splash 展示 | 1.5-3s |
| 相机启动 | < 1s |
| 叠图渲染 | < 50ms/帧 |
| 快门响应 | < 100ms |
| 后期处理 (1080P) | < 2s |
| 模板列表加载 | < 500ms |
| 安装包体积 | < 40MB |
