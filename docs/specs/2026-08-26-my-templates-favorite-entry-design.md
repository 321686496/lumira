# 「我的模板」页收藏入口设计

> 状态：Draft（待评审）
> 关联：上一功能「模板收藏」（`docs/specs/2026-08-26-template-favorite-design.md`）已完成落地：`template_favorites` 表 + `TemplatesFavoriteDao` + `favoriteTemplateIdsProvider`。

## 1. 背景与目标

「我的模板」页（`features/profile/pages/profile_my_templates_page.dart`）顶部的 `_StatsBar` 目前展示「自定义模板 / 使用次数 / 收藏」三项统计，其中**收藏数写死为 0**（Plan A Task A5 占位，未接任何真实数据源）。

本功能目标：
1. **顶部收藏数真实化**：改为读取真实模板收藏数（`template_favorites` 表），不再恒为 0。
2. **新增收藏入口**：顶部「收藏」统计可点击，进入一个独立的「我的收藏」页，展示**全部来源**（内置 / 自定义 / 远程）已收藏的模板。
3. **页内收藏筛选**：「我的模板」页下方筛选栏新增「收藏」筛选，将当前列表（仅自定义模板）过滤为已收藏的自定义模板。

## 2. 决策

- 收藏唯一数据源仍为 `template_favorites` + `favoriteTemplateIdsProvider`，不引入新的存储。
- 独立「我的收藏」页覆盖全来源（内置/自定义/远程），按收藏时间倒序。
- 「我的模板」页内「收藏」筛选仅作用于该页的自定义模板列表（该页本就只展示自定义模板），与独立收藏页的全来源语义不冲突。
- 复用既有模板卡片渲染：从 `templates_all_page.dart` 抽取 `_TemplateGrid`/`_TplCard`/`AllTemplateItem`/`_recordToItem` 为共享组件，供全部模板页与「我的收藏」页共用，避免复制渲染逻辑。
- **详情页收藏心覆盖全部来源**：详情页 `_navActions` 的收藏心 id 原先取自 mock 快路径（`_template`），对自定义/远程模板（不在 mock 列表）会隐藏。现改为取 `effectiveTemplate?.id`（mock/异步解析后的有效 id），保证**内置 + 自定义 + 远程模板详情**都展示红心收藏按钮。

## 3. 交互与视觉

### 3.1 我的模板页

- `_StatsBar`：
  - 「收藏」项数字改为 `favoriteTemplateIdsProvider` 的集合大小（真实收藏数）。
  - 「收藏」项整体可点击 → `push`「我的收藏」页。
- 保持 `_StatsBar`、`_FilterBar` 现有结构；收藏数与「使用次数」一样可能是 4+ 位，按钮/文本样式沿用 `_statItem`。

### 3.2 我的收藏页（新页面 `/templates/favorites`）

- `LumiraNav`：标题「我的收藏」，左侧返回。
- 内容：复用共享的 `TemplateGrid`，双列瀑布流展示已收藏模板卡片；点击卡片进详情页。
- 空态：无收藏时显示「暂无收藏」占位。
- 排序：按收藏时间倒序（`getFavoriteIds()` 已按 `created_at DESC`）。

## 4. 数据层

已存在，无需改动数据库结构。

复用/新增 Provider：
- `favoriteTemplateIdsProvider`（已有，`Set<String>`）：用于计数与「我的模板」页内收藏筛选。
- 新增 `favoriteTemplatesProvider`（`FutureProvider<List<TemplateGridItem>>`）：按收藏时间倒序返回全来源已收藏模板的卡片数据，供「我的收藏」页渲染。

实现方式（`favoriteTemplatesProvider`）：
1. `getFavoriteIds()` 取收藏有序 id（`created_at DESC`）。
2. `TemplatesDao.getBuiltinAndRemote()` + `getCustomOnly()` 取全来源模板记录，构建 `id → TemplateRecord` 映射。
3. 按收藏有序 id 遍历，命中映射的记录转为 `TemplateGridItem` 并按顺序输出。
4. 收藏 id 无序 / 对应模板已删时静默跳过（边缘情况，符合既有静默降级）。

## 5. 改动文件清单

| 文件 | 改动 |
|---|---|
| `features/templates/data/template_grid_item.dart`（新） | 抽出 `TemplateGridItem` 模型与 `templateGridItemFromRecord()` 工厂 |
| `features/templates/widgets/template_grid.dart`（新） | 抽出 `TemplateGrid` / `TemplateCard`（瀑布流双列 + 卡片） |
| `features/templates/pages/templates_all_page.dart` | 删除私有 `AllTemplateItem`/`_recordToItem`/`_TemplateGrid`/`_TplCard`，改为 import 共享组件 |
| `features/templates/data/templates_providers.dart` | 新增 `favoriteTemplatesProvider`（有序全来源收藏列表） |
| `features/templates/pages/templates_favorites_page.dart`（新） | 「我的收藏」页 |
| `core/router/route_names.dart` | 新增 `templatesFavorites = '/templates/favorites'` |
| `app/router.dart` | 注册新路由 → `TemplatesFavoritesPage` |
| `features/profile/pages/profile_my_templates_page.dart` | `_StatsBar` 收藏数接真数据 + 可点击进收藏页；`_FilterBar` 新增「收藏」筛选 |
| `features/templates/pages/templates_detail_page.dart` | `_navActions` 收藏心 id 改用 `effectiveTemplate?.id`，覆盖自定义/远程模板 |

## 6. 错误处理与边界

- 收藏 provider / DAO 读取失败：沿用静默降级，收藏数显示 0 / 列表空，不弹错。
- 模板已删除但仍在收藏表：映射查不到时跳过该 id（边缘，登记后续可选清理）。
- 空收藏：「我的收藏」页显示占位；「我的模板」页内收藏筛选命中为空时显示既有空态。

## 7. 测试

- 新增 `favoriteTemplatesProvider` 相关单测（或集成测试）：全来源命中 + 有序 + 模板删除跳过。
- 抽取共享网格后回归：`templates_all_page` 相关测试仍通过。
- 手工：顶部收藏数真实随收藏变化；点击进收藏页全来源列表；页内收藏筛选生效；主题/风格切换配色跟随。

## 8. 后续优化（登记 `docs/future-optimizations.md`）

- 清理已删除模板的孤立收藏记录（上一设计已登记）。