# Lumira 全局组件体系设计

> Date: 2026-08-04
> Status: Approved (用户已确认，跳过 spec review gate，直接进入实施)
> Author: brainstorming session
> Scope: 将 Flutter 项目中所有原生 Material 交互组件替换为主题感知的自定义全局组件

## 1. 背景与动机

### 1.1 现状问题
当前 `lumira_app_flutter/lib/` 中存在两类问题：

**A. 大量直接使用原生 Material 组件**
| 组件 | 使用次数 | 问题 |
|------|---------|------|
| `ScaffoldMessenger.showSnackBar` | 60+ 处 | 默认配色与品牌完全脱节 |
| `CircularProgressIndicator` / `LinearProgressIndicator` | ~50 处 | 默认蓝色 indicator |
| `TextField` / `TextFormField` | ~30 处 | 默认下划线/边框 |
| `TextButton` / `ElevatedButton` | 35+ 处 | 默认 Material 配色 |
| `ListTile` | 20+ 处 | 默认 padding/配色 |
| `IconButton` | 10+ 处 | 默认 splash/高亮 |
| `Slider` | 7 处 | 默认蓝色 |
| `Switch` | 5 处 | 默认 Material 开关 |
| `AlertDialog` (via `showDialog`) | 11 处 | 默认 Material 对话框 |
| `showModalBottomSheet` | 11 处 | 容器样式与品牌不符 |
| `DropdownButton` | 5 处 | 默认 Material 下拉 |
| `PopupMenuButton` | 1 处 | 默认 Material 菜单 |
| `showDatePicker` | 1 处 | 默认 Material 日历 |
| `FloatingActionButton` | 1 处 | 默认 Material FAB |
| `BottomNavigationBar` | 4 处 | 默认 Material 底部栏 |
| `TabBar` | 多处 | 已有 FloatingTabBar 但内嵌 Tab 仍用原生 |

**B. 局部重复封装**
- `capture_scene_manage_page.dart`、`profile_collection_edit_page.dart` 各自定义 `_TextField`
- 多个 capture/scenes 页面各自定义 `_NavIconButton`
- `gallery_edit_page.dart` 等仍硬编码 `Color(0xFFC9A96E)`

### 1.2 现有可复用基础设施
- `ThemeTokens`（`core/theme/theme_tokens.dart`）：8 套主题（warmWhite/ink/retro/fresh/cozy/macaron/morandi/rosegold）的完整色板与阴影系统
- `AppThemeData`（`core/theme/app_theme.dart`）：4 种 UI 风格（neumorphic/flat/glass/female）的卡片规格，通过 `appThemeProvider` Riverpod provider 暴露
- `NeuCard`（`shared/widgets/cards/neu_card.dart`）：4 风格分支渲染的优秀参考实现
- `LumiraToast`（`shared/widgets/feedback/lumira_toast.dart`）：已有 Overlay 实现，但颜色硬编码（`#1C1A17` / `#C9A96E` / `#FAF7F2`），不随主题变化
- `FloatingTabBar`：已主题化，本次不动

### 1.3 目标
- 所有交互组件的颜色、形态、阴影随 8 主题 × 4 风格变化
- 颜色零硬编码（除少量白色透明度叠加层，glass/female 风格必需）
- 消除局部重复封装，建立统一组件库
- 替换全部调用点，零原生 Material 交互组件残留

## 2. 架构设计

### 2.1 目录结构
```
lib/shared/widgets/lumira/
├── lumira.dart                      # barrel export
├── feedback/
│   ├── lumira_toast.dart            # 改造现有
│   └── lumira_progress.dart         # circular + linear + dot
├── buttons/
│   ├── lumira_button.dart           # primary/secondary/ghost/danger
│   └── lumira_icon_button.dart      # standard/filled/outlined
├── form/
│   ├── lumira_text_field.dart       # 替换所有局部 _TextField
│   ├── lumira_dropdown.dart         # + FormField 变体
│   ├── lumira_slider.dart
│   ├── lumira_switch.dart
│   └── lumira_checkbox.dart         # + ListTile 变体
├── dialog/
│   ├── lumira_dialog.dart           # showLumiraDialog + LumiraAlertDialog
│   ├── lumira_bottom_sheet.dart     # showLumiraBottomSheet
│   └── lumira_menu.dart             # showLumiraMenu + LumiraPopupMenuButton
├── picker/
│   └── lumira_date_picker.dart      # showLumiraDatePicker
├── nav/
│   ├── lumira_list_tile.dart
│   ├── lumira_tab_bar.dart          # 内嵌 Tab，与 FloatingTabBar 区分
│   ├── lumira_fab.dart
│   └── lumira_bottom_nav.dart
└── _internal/
    └── lumira_theme_resolver.dart   # 4 风格解析工具
```

### 2.2 主题扩展
在 `core/theme/app_theme.dart` 的 `AppThemeData` 上新增组件级 token（不破坏现有 `cardRadius`/`surfaceAlpha` 等）：

```dart
// 组件级尺寸（rpx 原值，widget 内部 /2 转 dp，与现有 cardRadius 保持一致）
double get buttonRadius;       // neumorphic:28, flat:20, glass:28, female:48
double get inputRadius;        // neumorphic:12, flat:8,  glass:12, female:24
double get popupRadius;        // neumorphic:20, flat:16, glass:20, female:32
double get sliderTrackHeight;  // neumorphic:6,  flat:4,  glass:6,  female:8
double get fabRadius;          // neumorphic:24, flat:20, glass:24, female:32

// 4 风格的按钮背景解析（Widget 调用）
ButtonVisual buttonVisual(ButtonVariant variant);  // primary/secondary/ghost/danger
InputVisual inputVisual(InputState state);          // default/focused/error/disabled
```

### 2.3 4 风格分支渲染约定
所有组件按 `NeuCard` 现有模式分支：
- `neumorphic`：surface 同色 + 双向阴影 + convex
- `flat`：surfaceAlt 背景 + divider 边框 + 无阴影
- `glass`：白色多层渐变 + backdrop blur + 双层边框
- `female`：brandSubtle→surface→brandLight 渐变 + 径向高光 + hairline 边框 + brand 阴影

### 2.4 API 风格约定
| 类型 | API 形态 | 示例 |
|------|---------|------|
| 反馈/弹层 | 函数式 | `LumiraToast.show()` / `showLumiraDialog()` / `showLumiraBottomSheet()` / `showLumiraMenu()` / `showLumiraDatePicker()` |
| 弹层容器 widget | Widget 类 | `LumiraAlertDialog` / `LumiraBottomSheet` |
| 表单/按钮/列表/滑块 | Widget 组件 | `LumiraButton` / `LumiraTextField` / `LumiraDropdown` / `LumiraListTile` |
| Popup 触发器 | Widget 包装 | `LumiraPopupMenuButton`（内部调用 `showLumiraMenu`） |

API 形状贴近原生以降低替换成本（如 `LumiraButton` 保留 `onPressed` / `child` 必填，新增 `variant` 必填）。

## 3. 组件规格

### 3.1 Phase 1：反馈与按钮

#### LumiraToast（改造）
- 移除硬编码颜色，改用 `ref.watch(appThemeProvider)` 读取 tokens
- 深色主题（ink）：背景 `tokens.canvasDeep` + brand 装饰条
- 浅色主题：背景 `tokens.canvas` 90% + brand 装饰条
- 文字：`tokens.textInverse`（深色主题）或 `tokens.textPrimary`（浅色主题，使用更深的 brandText）
- 行动按钮：`brandSubtle` 背景 + `brandText` 文字
- API 保持兼容：`LumiraToast.show(context, message, {action, duration, position})`

#### LumiraProgress
- `LumiraProgress.circular({strokeWidth, size})`：color = tokens.brand
- `LumiraProgress.linear({value})`：track = divider，progress = brand
- `LumiraProgress.dot()`：3 个 brand 色圆点呼吸动画（替代部分 circular 场景）
- 4 风格：glass 风格下 circular 加白色透明背景圆环；female 风格下用 brandLight 渐变

#### LumiraButton
- 4 variant × 4 风格：
  - `primary`：brand 背景 + textInverse 文字
  - `secondary`：surface 背景 + brandText 文字 + convexSubtle 阴影（neumorphic）/ divider 边框（flat）/ 白透明（glass）/ brandSubtle 渐变（female）
  - `ghost`：透明背景 + brandText 文字，按下时 brandSubtle 背景
  - `danger`：danger 背景 + 白色文字
- 必填 `variant` + `onPressed` + `child`，可选 `padding` / `radius` / `enableHoverScale`
- 按压缩放 0.97（neumorphic/flat/glass）/ 0.96（female），沿用 `NeuCard._ScaleTap`

#### LumiraIconButton
- 3 variant：`standard`（透明）/ `filled`（surface + 阴影）/ `outlined`（divider 边框）
- 必填 `icon`（PhosphorIcons）+ `onPressed`

### 3.2 Phase 2：弹层

#### showLumiraDialog
- 函数签名：`Future<T?> showLumiraDialog<T>({required WidgetBuilder builder, bool barrierDismissible = true})`
- 容器：`LumiraDialogContainer`，背景 = tokens.surface，圆角 = popupRadius，阴影 = shadowFloat
- 4 风格：glass 风格加 backdrop blur 25 + 白透明渐变；female 风格加 brandSubtle 渐变 + hairline
- 自动避开状态栏与底部安全区

#### LumiraAlertDialog
- 预设 `showLumiraDialog` 的常用形态：`title` + `content` + `actions[]`
- 标题用 displayMedium，正文用 bodyMedium
- actions 用 `LumiraButton.secondary` / `LumiraButton.primary` 渲染

#### showLumiraBottomSheet
- 函数签名：`Future<T?> showLumiraBottomSheet<T>({required WidgetBuilder builder, bool isScrollControlled = false})`
- 容器：背景 = tokens.surface，顶部圆角 = popupRadius，顶部 8dp 拖柄（brandLight）
- 4 风格：glass 风格下用 BackdropFilter blur 20 + 白透明 0.6

#### showLumiraMenu + LumiraPopupMenuButton
- `showLumiraMenu<T>({required List<LumiraMenuItem<T>> items, Offset? position})` 函数式
- `LumiraPopupMenuButton<T>` Widget 包装，内部计算位置调用 `showLumiraMenu`
- 菜单项：surface 背景，hover 时 brandSubtle，选中时 brand + textInverse

### 3.3 Phase 3：表单

#### LumiraTextField
- 替换所有局部 `_TextField`，统一 InputDecoration
- 必填 `controller` + 可选 `hintText` / `labelText` / `errorText` / `prefixIcon` / `suffixIcon`
- 4 风格：
  - neumorphic：surface 凹陷阴影 `shadowConcaveSubtle` + 无边框 + 12dp 圆角
  - flat：surfaceAlt 背景 + divider 边框 + 8dp 圆角
  - glass：白透明 0.4 背景 + 白透明 0.6 边框 + backdrop blur 8
  - female：brandSubtle 渐变背景 + hairline 边框 + 24dp 圆角
- 状态：focused 时 brand 色高亮（边框/阴影），error 时 danger 色，disabled 时 textTertiary
- 文字：textPrimary，hint：textTertiary

#### LumiraDropdown + LumiraDropdownFormField
- API 贴近原生：`value` / `items` / `onChanged` / `hintText`
- 触发器：复用 `LumiraTextField` 视觉（只读 + 右侧 chevron-down 图标）
- 弹出层：调用 `showLumiraBottomSheet`（移动端友好，避免原生 dropdown 在小屏的滚动问题）

#### LumiraSlider
- 必填 `value` + `min` + `max` + `onChanged`
- 4 风格：
  - track：divider 色，active 段 = brand
  - thumb：brand + shadowConvexSubtle（neumorphic）/ brand 圆点（flat）/ 白透明 + brand 边框（glass）/ brandLight 渐变（female）
- trackHeight = sliderTrackHeight

#### LumiraSwitch
- 必填 `value` + `onChanged`
- 关闭态：surfaceAlt 背景 + divider 边框
- 开启态：brand 背景 + 白色 thumb + shadowConvexSubtle
- thumb 切换动画 200ms easeOut

#### LumiraCheckbox + LumiraCheckboxListTile
- 选中：brand 背景 + 白色对勾（PhosphorIcons.check）
- 未选中：divider 边框 + 透明背景
- `LumiraCheckboxListTile`：复用 `LumiraListTile` + leading `LumiraCheckbox`

### 3.4 Phase 4：日期选择器

#### showLumiraDatePicker
- 函数签名：`Future<DateTime?> showLumiraDatePicker({required DateTime initialDate, DateTime? firstDate, DateTime? lastDate})`
- 内部用 `showLumiraDialog` 容器
- 自定义日历 widget：
  - 顶部：月份切换（左右 chevron + 当前年月，displayMedium 字号）
  - 周标题行：日 一 二 三 四 五 六，textTertiary
  - 日期网格：
    - 当日：brand 圆形背景 + textInverse
    - 今日：brand 边框 + brandText
    - 范围外：textTertiary
    - 周末：textSecondary
  - 底部：取消 / 确定 `LumiraButton`
- 4 风格：容器复用 LumiraDialogContainer，日历内部颜色全用 tokens

### 3.5 Phase 5：列表与导航

#### LumiraListTile
- API 贴近原生：`leading` / `title` / `subtitle` / `trailing` / `onTap` / `enableFeedback`
- 4 风格：
  - neumorphic：点击时 surface 凹陷 `shadowPressed` 短暂闪烁
  - flat：点击时 brandSubtle 背景
  - glass：透明背景，点击时白透明 0.2
  - female：透明背景，点击时 brandSubtle 0.3
- 默认 padding：horizontal 20，vertical 12

#### LumiraTabBar
- 用于内嵌 Tab（区别于主导航 FloatingTabBar）
- API 贴近原生：`tabs` / `controller` / `onTap`
- 选中 tab：brand 文字 + brand 下划线（2dp）
- 未选中：textSecondary
- 4 风格：glass 风格下背景白透明 0.3 + backdrop blur 10

#### LumiraFloatingActionButton
- 必填 `onPressed` + `child`，可选 `tooltip`
- 4 风格：
  - neumorphic：surface + shadowConvex
  - flat：brand 背景 + 白色 child
  - glass：白透明 0.7 + backdrop blur + brand 边框
  - female：brandLight 渐变 + hairline + brand 阴影
- 圆角 = fabRadius，按压缩放 0.95

#### LumiraBottomNavigationBar
- 必填 `items` + `currentIndex` + `onTap`
- 选中项：brand 图标 + brandText 文字
- 未选中：textTertiary
- 背景：surface + 顶部 divider 边框
- glass 风格：白透明 0.6 + backdrop blur 20

## 4. 实施策略

### 4.1 并行多 Agent 划分
```
Phase 0（主线串行）
    │
    ▼
Phase 1 ─┬─ Phase 2 ─┬─ Phase 3 ─┬─ Phase 4 ─┬─ Phase 5
（5 个 subagent 并行，互不依赖）
    │
    ▼
Phase 6（调用点替换，主线协调多 subagent 按文件并行）
```

### 4.2 Phase 间依赖
- Phase 0 必须先完成（提供 `AppThemeData` 扩展 token + 目录结构）
- Phase 1-5 互不依赖，可并行
- Phase 6 依赖 1-5 全部完成

### 4.3 接口约定（subagent 协作关键）
所有 subagent 必须遵守：
1. 组件放在 `lib/shared/widgets/lumira/<group>/` 下
2. 所有颜色从 `ref.watch(appThemeProvider).tokens` 取，零硬编码（glass/female 白透明叠加除外）
3. 4 风格分支渲染，参考 `NeuCard` 模式
4. 在 `lib/shared/widgets/lumira/lumira.dart` barrel 中 export 新组件
5. 配套单元测试 `test/shared/widgets/lumira/<group>/`

### 4.4 测试策略
- 每个组件配套单元测试：验证 8 主题 × 4 风格下渲染无异常
- 关键页面 golden test：capture_preview_page / profile_settings_page / templates_editor_page
- Phase 6 替换后跑全量 `flutter analyze` + `flutter test`

### 4.5 范围边界（不做的事）
- 不动 `FloatingTabBar` / `NeuCard` / 已自定义的 Chip（已是主题感知）
- 不替换 `Material` / `Scaffold` / `AppBar` / `SafeArea` 等容器（仅主题化配置）
- 不重写路由系统
- 不修改后端代码

## 5. 调用点替换清单（Phase 6）

按文件并行替换，每个文件独立 commit：

### 5.1 反馈组件替换
- 全部 `ScaffoldMessenger.of(context).showSnackBar(...)` → `LumiraToast.show(...)`
- 全部 `CircularProgressIndicator(...)` → `LumiraProgress.circular(...)`
- 全部 `LinearProgressIndicator(...)` → `LumiraProgress.linear(...)`

### 5.2 弹层替换
- 全部 `showDialog(...)` → `showLumiraDialog(...)`
- 全部 `AlertDialog(...)` → `LumiraAlertDialog(...)`
- 全部 `showModalBottomSheet(...)` → `showLumiraBottomSheet(...)`
- 全部 `showDatePicker(...)` → `showLumiraDatePicker(...)`
- 全部 `PopupMenuButton(...)` → `LumiraPopupMenuButton(...)`

### 5.3 表单替换
- 全部 `TextField` / `TextFormField` → `LumiraTextField`
- 删除所有局部 `_TextField` 类
- 全部 `DropdownButton` / `DropdownButtonFormField` → `LumiraDropdown` / `LumiraDropdownFormField`
- 全部 `Slider` → `LumiraSlider`
- 全部 `Switch` → `LumiraSwitch`
- 全部 `CheckboxListTile` → `LumiraCheckboxListTile`

### 5.4 按钮与列表替换
- 全部 `TextButton` / `ElevatedButton` → `LumiraButton`（按语义选 variant）
- 全部 `IconButton` → `LumiraIconButton`
- 删除所有局部 `_NavIconButton` 类
- 全部 `ListTile` → `LumiraListTile`
- 全部 `TabBar` → `LumiraTabBar`
- 全部 `FloatingActionButton` → `LumiraFloatingActionButton`
- 全部 `BottomNavigationBar` → `LumiraBottomNavigationBar`

### 5.5 颜色硬编码清理
- 全部 `Color(0xFFC9A96E)` 等硬编码品牌色 → `tokens.brand`
- 全部 `Colors.white` 在交互组件中 → 对应 tokens 值或显式白透明叠加

## 6. 验收标准

- [ ] `flutter analyze` 零警告
- [ ] `flutter test` 全部通过
- [ ] 切换 8 主题 × 4 风格，所有页面视觉一致
- [ ] 零原生 Material 交互组件残留（仅容器类 Material/Scaffold/AppBar 保留）
- [ ] 零硬编码品牌色（除 glass/female 风格的白透明叠加层）
- [ ] 删除所有局部 `_TextField` / `_NavIconButton` 重复封装
- [ ] 关键页面 golden test 通过

## 7. 风险与缓解

| 风险 | 缓解 |
|------|------|
| subagent 接口约定不一致 | Phase 0 主线先建立 `lumira_theme_resolver.dart` 工具与示例代码，subagent 严格参考 |
| 调用点替换体量大（60+ 文件） | Phase 6 按文件并行，每文件独立 commit，便于回滚 |
| 4 风格分支渲染代码膨胀 | 抽取 `_LumiraThemeResolver` 工具类，统一处理 4 风格背景/边框/阴影 |
| glass/female 性能（backdrop blur） | 仅在容器类组件（Dialog/BottomSheet/Card）使用 blur，输入框等高频组件用静态颜色模拟 |
| 主题切换不刷新 | 所有组件 ConsumerWidget + ref.watch(appThemeProvider)，由 Riverpod 自动管理 |

## 8. 参考实现

- `NeuCard`（`shared/widgets/cards/neu_card.dart`）：4 风格分支渲染的标杆
- `ThemeTokens`（`core/theme/theme_tokens.dart`）：完整色板与阴影系统
- `AppThemeData`（`core/theme/app_theme.dart`）：4 风格的卡片规格
- `LumiraToast`（`shared/widgets/feedback/lumira_toast.dart`）：Overlay 实现参考（需改造颜色）
