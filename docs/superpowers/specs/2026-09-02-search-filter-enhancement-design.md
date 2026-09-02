# 搜索筛选功能完善 + 多风格自适配设计

日期：2026-09-02
状态：已批准，待实现

## 背景与问题

搜索页（`GlobalSearchPage`）的筛选面板（`filter_sheet.dart`）存在两个问题：

1. **「全部」scope 筛选项为空**：模板/场景/美学院的筛选项只在各自的子 scope 下才显示，默认的「全部」几乎没有任何筛选项。
2. **UI 未适配多套 UI 风格/主题**：面板只用颜色 token（`themeTokensProvider`），没有读取 `uiStyleProvider`（neumorphic/flat/glass/female），且使用 Material 原生 `showModalBottomSheet` / `OutlinedButton` / `FilledButton`，违背「组件随设置切换风格」的规范铁律。

## 目标

- 「全部」scope 下有完整、可用的筛选项（统一合并面板）。
- 筛选面板整体（容器、筛选 chip、底部按钮）严格适配 4 套 UI 风格 × 8 套主题，随设置切换。
- 子 scope（模板/场景/美学院）筛选行为不变，仅切换为自适配组件。

## 方案

### 1. 数据模型解耦（scene 分类独立字段）

问题：`SearchFilters.category` 单一字段在「全部」下同时承载模板分类（key）与场景分类（中文名），互不兼容、相互冲突。

改动：新增独立字段 `sceneCategory`。

- 模板分类始终读 `category`。
- 场景分类始终读 `sceneCategory`（`SceneSearchService.search` 读取 `filters.sceneCategory`；为兼容旧状态，读不到时回退到 `filters.category`）。
- 「全部」下两者可并存，互不干扰。

涉及文件：
- `lumira_app_flutter/lib/shared/searchengine/search_filters.dart`
- `lumira_app_flutter/lib/features/scenes/search/scene_search_service.dart`

### 2. 面板容器改用 Lumira

- `showSearchFilterSheet` 内部改用 `showLumiraBottomSheet` + `LumiraBottomSheetContainer`（已具备 4 风格自适配：neumorphic surface+shadowFloat、flat 顶边边框、glass 半透明玻璃、female 渐变）。
- 删除自定义 Material Container 与 `Colors.transparent` 的 `showModalBottomSheet` 调用。
- 底部「重置 / 确定」改用 `LumiraButton`（secondary / primary）；去掉 header 中重复的「重置/确定」，header 保留唯一标题「筛选」。

### 3. 新增自适配筛选 chip：`LumiraFilterChip`

放在 `lumira_app_flutter/lib/shared/widgets/lumira/form/lumira_filter_chip.dart`，并在 `lumira.dart` barrel 导出。

按 `appThemeProvider`（tokens + style）渲染 4 风格：
- neumorphic：未选中 `surface` + `shadowConvexSubtle`（浮雕凸起），选中 `brand` + `shadowConvexBrand`。
- flat：未选中 `surfaceAlt` + `divider` 细边，选中 `brand`（N 阴影）。
- glass：未选中 `glassFill` + 白细边，选中 `brand` + 柔和玻璃阴影。
- female：未选中 `brandSubtle` + 白 hairline + 品牌柔和阴影，选中 `brand`（扁平微渐变）。
- 选中文字 `textInverse`，未选中 `textSecondary`；圆角随 `appTheme.buttonRadius / 2` 变化。
- 带按下呼吸反馈（复用 `_ScaleTap` 思路）。

### 4. 「全部」统一合并面板

`_FilterSheet.build` 对 `scope == SearchScope.all` 额外渲染所有类型维度的分组，分组标题标注所属类型：

- 模板 · 分类（读 `category`）
- 模板 · 价格
- 模板 · 来源
- 场景 · 分类（读 `sceneCategory`）
- 场景 · 风格（读 `sceneStyle`）
- 美学院 · 主题
- 美学院 · 等级
- 用户标签

子 scope 保持各自原有分组，仅替换为 `LumiraFilterChip`。

### 5. 工具栏筛选入口激活态

`_buildToolbar` 的筛选 IconButton：当 `_filters` 存在任一非默认筛选条件时，`Icons.tune` 用品牌色高亮（提示有筛选生效）。

## 验证

- `flutter analyze` 通过，无新增告警。
- 在 4 风格 × 代表主题（warmWhite/ink/morandi/rosegold）目测筛选面板渲染正确。
- 功能回归：模板/场景/美学院子 scope 筛选结果与原逻辑一致；「全部」下模板分类只过滤模板、场景分类只过滤场景。

## 不做（范围外）

- 不改后端 / 后台 / 共享类型。
- 不做遥控排序入口重构、不新增筛选维度（如拍摄场景、日期区间）。
- 不做筛选结果「已选条件」的即时预览条。