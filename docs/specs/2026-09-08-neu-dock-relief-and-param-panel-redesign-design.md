# 拍摄预览页新拟态浮雕修复 + 拍摄页参数弹出栏重设计

- 日期：2026-09-08
- 状态：已批准（待实现）
- 关联：`docs/specs/2026-09-07-capture-preview-edit-redesign-design.md`（预览页改版，本设计延续其工具条交互模式）

## 1. 背景与问题

### 1.1 预览页编辑卡片无浮雕（新拟态风格）

拍摄预览页（`capture_preview_page.dart`）Scaffold 画布硬编码 `Colors.black`（沉浸式看图），底部编辑 dock 用 `LumiraSurface` 渲染。新拟态风格下 `LumiraThemeResolver.cardVisual` 输出浅色卡面（`tokens.surface`，如 warmWhite `#FDFBF7`）+ 为同色浅画布调校的双向外阴影（浅灰暗影 `#C6C0B5` + 白高光 `#FFFFFF`）。黑底上：

- 浅灰暗影 ≈ 不可见（黑底吸掉）
- 白高光只会把卡边缘染亮，无立体方向感
- 结果：卡片是一块「亮色平面」，无浮雕

### 1.2 拍摄页参数弹出栏（ParamPanel）UI/UX 落后

`param_panel.dart` 现状：

- 520px 固定高底部抽屉 + 5 个文字 Tab（相机/色彩/细节/构图/场景），遮挡近 2/3 取景器
- 大量硬编码视觉：黑 0.4 半透明底、金色 `0xFFC9A96E` 强调（违反「样式跟随 UI 风格 + 主题」铁律，不随 4 风格 × 8 主题变化）
- 控件形态（label+slider+value 网格行、_SectionCard 分组卡）与预览页/修图页已落地的 iPhone 式「横向圆形图标调节条 + 单滑块」（`AdjustPanel`）不一致
- 白平衡预设 pill、闪光 PopupMenu 等交互偏重

## 2. 目标

1. 新拟态风格下，预览页黑底上的编辑 dock 呈现**真浮雕**（凸起感），且完全从 tokens 派生、不硬编码
2. ParamPanel 交互对齐预览页工具条模式：**图标工具条 + 点选滑出控件区**，总高 ≤220，减少取景器遮挡
3. ParamPanel 视觉主题化：颜色全部从 `appThemeProvider` 派生（4 风格 × 8 主题），暗色语境文字用白色系
4. 控件质感对齐 `AdjustPanel`（与预览页/修图页一致）

## 3. 方案设计

### 3.1 Part 1：暗色语境新拟态浮雕（LumiraSurface.darkContext）

**核心思路**：新拟态「组件与背景同色」铁律在黑画布上的推论——卡面应为「近黑 + 主题色调」，双向阴影用「更深黑（暗影）+ 比卡面微亮（高光）」。ink 主题的暗色新拟态配方（`_inkTokens.shadowConvex`：`#0B0A08` 暗影 + `#2D2821` 高光）验证过该取向成立；本方案不复制 ink 色值，而是从**当前主题 tokens** 派生，保证 8 主题下均有正确色调。

**改动点**：

1. `LumiraThemeResolver.cardVisual` 新增 `bool darkContext = false` 参数
2. neumorphic 分支 + `darkContext` 时输出：
   - 卡面：`Color.lerp(Colors.black, tokens.canvas, 0.10)`
   - 右下暗影：`Color.lerp(Colors.black, tokens.canvas, 0.03)`，offset (6,6) blur 14
   - 左上高光：`Color.lerp(Colors.black, tokens.canvas, 0.22)`，offset (-6,-6) blur 14
   - 亮度关系：高光 0.22 > 卡面 0.10 > 暗影 0.03，形成正确的明暗梯度
3. `LumiraSurface` 新增 `darkContext` 参数透传给 resolver
4. `capture_preview_page.dart` 的 `_buildEditDock` 传 `darkContext: true`
5. flat / glass / female 分支不受 `darkContext` 影响（叠照片浮层取向已有约定，黑底表现不变）

**验证方式**：切换 4 风格 × 8 主题矩阵，确认 neumorphic + 各主题下 dock 在黑底上均有浮雕，其余风格不变。

### 3.2 Part 2：ParamPanel 重构（图标工具条 + 点选滑出）

**结构**（自上而下）：

```
┌──────────────────────────────────────┐
│ 把手行：拖动条 + 模板/自由徽标 + 重置 (约32dp)
├──────────────────────────────────────┤
│ 图标工具条：EV | WB | 闪光 | 色彩 | 细节 | 构图 | 场景  (约56dp)
├──────────────────────────────────────┤
│ 控件区（AnimatedSize 滑出，0~约128dp）
│   点图标 → 展开该组；再点同图标 → 收起控件区
└──────────────────────────────────────┘
```

- 总高：收起态约 96dp（把手 + 工具条 + 底部 inset），展开态 ≤220dp
- 底部手势条：展开时 ParamPanel 覆盖 `_BottomControlArea`（bottom: 0 起），容器背景铺满到底边，内容用 `MediaQuery.viewPadding.bottom` 作底部内边距（与 `_BottomControlArea` 同款「背景到底 + 内容留 inset」方案）

**工具项与控件区映射**：

| 工具 | 图标 | 控件区内容 |
|---|---|---|
| 曝光 EV | `Icons.exposure` | 单滑块 `_EditSlider` 质感（-3.0~+3.0，60 档） |
| 白平衡 | `Icons.wb_sunny_outlined` | 预设 pill 行（自动/日光/阴天/荧光/白炽）+ 色温滑块（非 auto 且 iOS/Android 时） |
| 闪光 | `Icons.flash_on_outlined` | 4 选项 pill 单选（关闭/常亮/自动/手电筒） |
| 色彩 | `Icons.tune` | `AdjustPanel(colorAdjustDefs)` 复用 |
| 细节 | `Icons.auto_fix_high_outlined` | `AdjustPanel(detailAdjustDefs)` 复用 |
| 构图 | `Icons.grid_4x4_outlined` | 类型 pill 行（6 类）+ 透明度滑块 |
| 场景 | `Icons.tips_and_updates_outlined` | 紧凑 label:value 只读列表（可滚动） |

- 重置按钮收进把手行右侧（小图标 pill），行为与现 PanelFooter 一致（模板模式重置为模板原始值，自由模式重置默认值并持久化）
- 「完成」按钮删除：收起 = 点把手行收起图标 / 点取景器空白处，与预览页工具条「点同图标收起」一致；不再需要显式完成按钮

**交互细节**：

- 点工具图标：`HapticFeedback.lightImpact()` + `AnimatedSize(260ms, easeOutCubic)` 滑出
- 再点同图标：收起控件区（工具条仍显示）
- 点取景器空白：关闭整栏（保留现有 `panelExpandedProvider` 状态与 GestureDetector 拦截逻辑）
- 白平衡逻辑（`_applyWhiteBalance`、预设→色温联动、OHOS 隐藏色温滑块）**原样迁移**，不改行为
- 场景 Tab 的空态（自由模式无指南）保留为场景控件区的空态文案

**视觉主题化**：

- 容器按当前风格取向（全部从 `appThemeProvider` 派生）：
  - neumorphic：半透明暗底（Part 1 同套 lerp 派生，叠动态画面无阴影无模糊）+ 细边
  - glass：暗玻璃（`BackdropFilter` + 暗色半透明，与 ParamPillBar 玻璃胶囊同取向）
  - flat：半透明暗底 + 细边（现取向，颜色换 tokens）
  - female：暗渐变底 + 柔和细边
- 强调色 `0xFFC9A96E` → `tokens.brand`；选中/未选中/轨道/填充全部走 tokens
- 暗语境文字白色系（`Colors.white`/`white70` 系，与 ParamPillBar 拍摄页先例一致——拍摄页控件文字压在暗底/取景器上，白色保证可读性，非主题皮肤色）
- `_EditSlider`（AdjustPanel 内）tokens 为 null 时已是暗色 fallback，ParamPanel 传 `tokens: null` 即可获得暗色质感，选中填充色需要传 brand → 增加一个 `brandColor` 可选参数（或传 `ThemeTokens` 但指定暗色文字）——实现时取最小改动：给 `AdjustPanel` 增加 `accentColor` 可选参数，null 时回退现 fallback

**删除内容**：`_PanelHeader`、`_TabBarSection`、`_PanelFooter`、`_CameraTab`、`_ColorTab`、`_DetailTab`、`_CompositionTab`、`_SceneTab`、`_SectionCard`、`_SliderRow`、`_PopupRow` 的旧结构（`_WbPresetRow` 迁移保留、主题化改造），文件整体重写但保持 `ParamPanel` 类名与挂载点（`capture_page.dart` Stack 内 `const ParamPanel()`）不变。

## 4. 涉及文件

| 文件 | 改动 |
|---|---|
| `lib/shared/widgets/lumira/_internal/lumira_theme_resolver.dart` | `cardVisual` 增加 `darkContext` 分支 |
| `lib/shared/widgets/common/lumira_surface.dart` | 透传 `darkContext` |
| `lib/features/capture/pages/capture_preview_page.dart` | `_buildEditDock` 传 `darkContext: true` |
| `lib/features/capture/widgets/param_panel.dart` | 整体重构为工具条 + 滑出面板 |
| `lib/features/capture/widgets/post_process_adjust_panel.dart` | `AdjustPanel`/`_EditSlider` 增加暗语境 accent 支持（最小改动） |

## 5. 不做的事

- 不改 ParamPillBar（顶部胶囊已按风格双轨处理）
- 不改拍摄页底部控制区布局
- 不改任何参数写入逻辑（CaptureState/whiteBalance/cameraService 行为原样）
- 不做 520 抽屉的向后兼容（直接替换）
