# 水印编辑器 & 管理页 风格自适应设计

日期：2026-08-20
主题：修复水印编辑页的丑陋样式、黑边问题，并让编辑页/管理页完全遵循项目 4 套 UI 风格 × 8+1 主题色的自适应规范。

## 1. 背景与问题

当前 `watermark_editor_page.dart` 存在三类问题：

1. **黑边**：`Scaffold(backgroundColor: Colors.black)` + `SafeArea`，导致顶部状态栏区域、底部 Home indicator 区域、预览区四周均为硬编码死黑；与浅色主题外壳之间形成明显黑缝。
2. **风格不分化**：整个外壳（导航栏背景、底部面板、Tab、`_miniButton`/`_elementChip`/`_spaceOption`/`_frameOption`/`_toggleChip`/`_alignChip`/Slider/TextField/颜色选择圆点）大量使用死板的 `tokens.surfaceAlt` + 平板直边框，没有任何 neumorphic 浮雕 / female 渐变 / glass 磨砂 / flat 细边的差异化，该有阴影无阴影、该圆角无圆角。
3. **预览区死黑**：`Container(color: Colors.black)` 应改用主题深色（保持沉浸看图）而非死黑。

管理页 `watermark_manage_page.dart` 已使用 `NeuCard` / `LumiraButton` / `LumiraIconButton`，基本合规；只发现 `_LayoutSegments`、`_MenuButton`（PopupMenu）等少数控件是风格不分的平板样式，一并轻量修复。

## 2. 设计方向（用户已确认）

- **外壳（导航栏 / 底部面板 / Tab / 按钮小组件）**：完全跟随当前 UI 风格（neumorphic / flat / glass / female）与主题色，风格分化。该圆角圆角、该阴影阴影。
- **预览区**：保持「深色沉浸看图」，但改为「主题深色」而非死黑。
- **浅外壳 + 深预览**：导航栏与底部面板跟随主题（通常浅色），照片预览区用深色沉浸底，二者之间无黑边、自然衔接。

> 补充（项目管理）：用户在 7/iStown 样本中提到"标题栏上部分、页面下部分有黑色留边"，即 SafeArea 区域的黑边必须消除。本项目对 SafeArea 的处理采用「外壳走系统配色 + 预览区走深色」的方式，状态栏/Home indicator 背景与外壳同色。

## 3. 编辑器外壳结构重构

### 3.1 页面骨架（替换 `Scaffold(backgroundColor: Colors.black)`）

```dart
// 外壳背景，不再死黑
return Scaffold(
  backgroundColor: tokens.canvas,
  body: Column(
    children: [
      _buildNav(tokens),          // 顶部导航（跟随主题，LumiraNav 已自适应）
      Expanded(child: _buildPreviewArea(tokens, style)), // 深色预览区
      _buildBottomPanel(tokens, style),                 // 底部面板（风格自适应）
    ],
  ),
);
```

- 移除字符串包裹的 `SafeArea`，改由 `LumiraNav` 内部处理顶部安全区；底部面板用 `SafeArea(top: false)` 处理 Home indicator，背景与面板 surface 同色 → 消除黑边。
- 预览区顶部若与浅色外壳拼接，允许存在一条细分隔（`tokens.divider`）或无缝过渡，按风格定。

### 3.2 底部操作栏面板（`_buildBottomPanel`）

按 4 风格渲染，参考 `LumiraNav._scrolledDecoration` 与 `NeuCard`：

| 风格 | 面板表面 | 顶部分隔 |
|---|---|---|
| neumorphic | 实心 `tokens.surface` | 细边 `tokens.divider` 0.5dp |
| flat | 实心 `tokens.surface` | 实色分隔 1dp |
| glass | 该风格半透明 + 允许 blur（自风格） | 白 0.4 |
| female | 品牌渐变 `brandSubtle→surface` | 品牌色 0.25 + 柔和投影 |

实现为共享小部件或本地私有构造，复用现有 tokens.shadow* 系列（shadowConvex / shadowFloat 等）。

### 3.3 底部 Tab 按钮（`_buildTabButton`）

由「`surfaceAlt` + 直边框 10dp 圆角平板」改为风格自适应：

- **neumorphic**：激活态用 `brandSubtle` + `shadowConvexSubtle`（内凹/凸起），圆角 12dp。
- **flat**：激活态 `brandSubtle` 实色块 + 无阴影，圆角 8dp。
- **glass**：激活态白 0.4 半透明 + 细白边（自风格玻璃），圆角 12dp。
- **female**：激活态 `brandSubtle` 渐变底 + 柔和品牌投影，圆角 12dp。

采用本地私有封装（如 `_adaptiveChip` / `_adaptiveButton`），接收 `active` / `onTap` / `label` / `child`，集中表达风格分支。

### 3.4 面板内所有"小按钮/芯片/选项"控件

`_miniButton`（＋文本/＋日期/复制/删除）、`_elementChip`、`_spaceOption`、`_frameOption`、`_toggleChip`、`_alignChip`、`_LayoutSegments`：

统一改用风格自适应容器（私有 `_adaptiveChip`），核心逻辑：
- **底**：非激活 `tokens.surfaceAlt`（flat/neumorphic）/ 白透明（glass）/ `brandSubtle` 渐变（female）。
- **激活**：`brandSubtle` + 风格阴影 + 圆角。
- **圆角**：风格自适应取 `appTheme.cardRadius` 比例派生（小控件取较小值）。
- **边框**：flat 细边、fem 品牌 hairline、glass 白 0.6、neu 无直边（靠浮雕阴影表达）。

### 3.5 样式 Tab 的输入控件

- **TextField**：改为 `LumiraTextField`（若存在）或风格自适应边框（圆角 `cardRadius/2`、focused 用 `tokens.brand`、filled 色 `surfaceAlt→surface` 随风格）。
- **Slider**：保留 `tokens.brand` 主色；轨道/thumb 阴影按风格微调（flat 无阴影、neu 可加 subtle）。
- **颜色选点**（`_buildElementPalette` / `_buildFramePalette`）：在选点外圈描边上按风格表达选中，且白色圆点在浅色背景下需描边可见。

### 3.6 顶栏（`_buildNav`）

已是 `LumiraNav`（内部风格自适应）。只做小幅调整：
- 取消/保存按钮从裸文本改为风格自适应文本按钮（激活态用 `brand`，取消用 `textSecondary`，并带合适的点按反馈）。
- 移除包裹在 `Container(color: tokens.canvas)` 的外部容器，让 `LumiraNav` 自身背景负责，消除重复底色与黑边。

### 3.7 预览区（`_buildPreviewArea`）

- 背景由 `Colors.black` 改为「深色沉浸底」：优先取 `tokens.canvasDeep`（ink 主题即墨色 `0xFF151310`，观感佳）。对 canvasDeep 过浅的暖/浅主题（warmWhite/retro/fresh/cozy/macaron/morandi/rosegold），用固定深色常量 `Color(0xFF1B1A18)`（经灰度通道判断 `canvasDeep.computeLuminance() > 0.3` 时启用回退），确保任何主题下都有沉浸感。该常量为「叠在照片上的深色背景」，属跨风格叠加视觉的合法例外，非主题色硬编码。
- 元素选中框（前景白描边）保留；缩放/拖拽手势不变。
- 拍立得白边 overlay、space 基准矩形逻辑不变。

## 4. 管理页轻量修复

- `_LayoutSegments`：改为风格自适应分段控件（背景 `surfaceAlt`、激活段用 `brand` 描边 + 风格阴影、圆角自适应）。
- `_MenuButton` 的 PopupMenu：内容文字跟随 tokens（编辑/复制/删除已部分跟随），弹层容器可包一层风格化表面。
- 卡片：已是 `NeuCard`，保持，不重做。

## 5. 测试

- 保持既有测试通过：`test/features/watermark/**`（编辑器、管理页、模型、渲染器）。
- 关键断言不依赖具体颜色值，避免因风格切换而脆弱：
  - 编辑页存在「元素/样式/边框」三个 Tab 的 key（wm-tab-element / wm-tab-style / wm-tab-border）。
  - 底部面板展开/折叠 key（wm-panel-collapse / wm-panel-expand）。
  - 预览区 key `wm-preview-area` 仍存在。
  - 管理页布局切换 key `watermark-layout-toggle`。
- 新增/更新 1 个风格自适应控件的 widget 测试（可挂 4 风格跑一遍断言存在 & 不抛异常），覆盖 neumorphic/flat/glass/female 四分支。

## 6. 风险与规避

- **风格分支不混用**：严格按项目规则——`_adaptiveChip` 只使用"当前风格自己的元素"，不借玻璃到新拟态、不借浮雕到扁平。以 `appTheme.style` 分支。
- **不硬编码**：除"深色沉浸底"常量外，全部颜色/阴影/圆角来自 `appTheme.tokens` / `appTheme.cardRadius` / `appTheme.multiGradient`。
- **不回归手势**：预览区点选/拖拽/缩放逻辑不动，只改壳。
- **热点**：列表/管理页已有测试，改 `_LayoutSegments` 时注意 key 与其测试。

## 7. 交付文件

- 修改：`lumira_app_flutter/lib/features/watermark/pages/watermark_editor_page.dart`（主）
- 修改：`lumira_app_flutter/lib/features/watermark/pages/watermark_manage_page.dart`（轻量、布局分段控件）
- 若新增可复用的小控件（可放编辑页私有或 `lib/features/watermark/widgets/`），确保 4 风格验证通过。
- 测试：`test/features/watermark/**` 保持通过；新增风格自适应控件测试。