# 拍摄预览页「心情 + 场景」标记带重构设计

- 日期：2026-09-20
- 范围：`lumira_app_flutter` 拍摄预览页（`capture_preview_page.dart`）底部编辑 dock 顶部的「心情 | 场景」选择区
- 决策人：用户已确认采用「方案 B：双行标记带」

## 1. 背景与问题

拍摄预览页底部编辑 dock 顶部当前是 `PreviewTagPillRow`（`preview_tag_pill_row.dart`），一条仅 44px 高的横向紧凑 pill 行：

- 左半区：7 个「心情」纯文字 pill
- 右半区：7+1 个「场景」纯文字 pill（含首项「不标记」）

问题：

1. **情绪没有图标**：`MoodOption` 数据里已含 `icon` 字段（`Icons.sentiment_satisfied` 等），但当前未渲染，仅纯文字。
2. **场景没有场景图**：`ScenePillOption` 仅有 Material `icon`，无缩略图；社区里现成的场景图资源（`assets/images/scenes/*.jpg`）+ `ScenePreset.exampleImages` 未被使用。
3. **存在感过低**：一条窄窄的纯文字行叠在工具条上方，视觉权重不足。

目标：**提升存在感，让「心情有图标、场景有图」，同时保持 UI 简洁**，不挤占照片与工具条空间。

## 2. 方案 B：双行标记带

把单行升级为**两行紧凑标记带**，仍位于编辑 dock 顶部、工具条上方：

- 第 1 行：**心情** — 图 + 文胶囊（icon 徽标 + 文字），横向滑动
- 第 2 行：**场景** — 圆角方形场景图缩略卡 + 文案，横向滑动

两行之间用细分隔线与首项「不标记」胶囊区分视觉层次，并延续现有 `LumiraSurface` 卡片语言。

### 2.1 情绪行设计

- 心情胶囊：`圆形 icon 徽标（32dp）＋ 标签文字`，横向 `ListView`，item 间距 8。
- 选中态：品牌渐变底（`[brand, brandDeep]`）+ 反色文字 + 图标着 `textInverse`，圆角 `1000`。
- 未选态：`surfaceAlt` 底 + `textSecondary` 图标与文字。
- 交互保持：点选中项再点一次 = 取消（等同旧「跳过」），回调 `onSelectMood` 不变。
- 高度约 48dp。

### 2.2 场景行设计

- 场景卡：`圆角方形缩略图（约 56×56）＋ 下方小字场景名`，横向 `ListView`，item 间距 8。
- 缩略图数据：为 `ScenePillOption` 增加 `image`（asset 路径）字段，映射到现成 `assets/images/scenes/*.jpg`；无图时回退到原 `icon`（`Icons.place` 风格占位图）。
- 选中态：缩略图外圈品牌色描边（`tokens.brand`, width 2）+ 右上角小勾标记；未选态：`surfaceAlt` 细描边。
- 首项「不标记」：保持图标胶囊样式（无图），选中 = `selectedSceneId == null`。
- 交互：点击回调 `onSelectScene(id / null)` 不变。
- 高度约 78dp（图 56 + 文案 18 + 间距）。

### 2.3 整体布局与风格

- 不做玻璃、不挂外阴影、不做渐变底整行——保持在卡片内「纯色 + 细描边 / 浮雕」的分层语义内，符合项目 UI 规范第 1~4 条（新拟态/扁平/玻璃/女性美学 4 风格自适应）。
- 两行之间以 `tokens.divider` 细分隔；与下方工具条之间沿用现有 `divider`。
- 所有颜色/圆角/阴影一律从 `tokens`（`brand/brandDeep/surfaceAlt/textPrimary/textSecondary/textInverse/divider/providers`）派生，禁止硬编码 `Colors.xxx`（照片上黑/白半透明遮罩除外）。
- 新增约 126dp 垂直空间，仍远小于工具条 + 滑出面板，不显著挤占照片区域。

## 3. 场景 → 图片资源映射

为 `ScenePillOption` 增加 `image` 字段，映射现成资源（缺失则 icon 兜底）：

| id | name | image |
| -- | ---- | ---- |
| cafe | 咖啡馆 | `assets/images/scenes/scene_cafe.jpg` |
| street | 街头 | `assets/images/scenes/scene_street.jpg` |
| park | 公园 | `assets/images/scenes/scene_park-lawn.jpg` |
| home | 居家 | `assets/images/scenes/scene_home.jpg` |
| studio | 工作室 | `assets/images/scenes/scene_dance-studio.jpg` |
| restaurant | 餐厅 | `assets/images/scenes/scene_noodle-shop.jpg` |
| travel | 旅行 | `assets/images/scenes/scene_road-sunset.jpg` |
| night | 夜景 | `assets/images/scenes/scene_night-market.jpg` |

## 4. 代码改动

1. **数据**：`capture_preview_mock_data.dart`
   - `ScenePillOption` 增加 `image` 字段（`String?`），默认值在 8 个场景常量里补齐；保留 `icon` 作兜底。
2. **组件**：`preview_tag_pill_row.dart`
   - 重写 `PreviewTagPillRow` 为两行 `Column`：
     - 第 1 行 `_MoodBand`：遍历 `moods`，渲染「icon + text」胶囊（复用 `_TagPill` 的选中样式，新增图标）。
     - 第 2 行 `_SceneBand`：首项「不标记」胶囊 + 遍历 `scenes` 渲染缩略图卡（`Image.asset` 或 `AssetImage`；无 `image`/加载失败回退 `icon`）。
     - 两行间 `Container(height:1, color: tokens.divider)`。
   - `_TagPill` 扩展支持 icon（可选前置图标）。
3. **调用方**：`capture_preview_page.dart` `_buildEditDock`
   - `PreviewTagPillRow` 调用参数不变（仍传 `moods/selectedSceneId/onSelectMood/onSelectScene/tokens`）；内部高度由新组件占据，无需改外部布局。
4. **场景图加载**：复用本地 asset，用 `Image.asset` 即可；无需引入网络缓存。

## 5. 测试与验证

- `flutter analyze` 通过。
- 手动验证：4 套 UI 风格（neumorphic/flat/glass/female）× 若干主题色下，情绪图标、场景缩略图、选中态描边/勾选、横向滑动、取消选中、首项「不标记」均正常。
- 交互/状态（`_selectMood`/`_selectScene`、写入数据库）不变，仅视觉层重构。

## 6. 不做的事（YAGNI）

- 不改动心情/场景的选择状态逻辑与持久化。
- 不把场景选择与 `ScenePreset` 过滤/滤镜联动（那是拍摄流程另一套能力，预览页标记语义保持独立）。
- 不做弹出面板、不做动画入场、不增加设置项。