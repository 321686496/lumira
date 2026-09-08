# 搜索页：比例筛选 + 抖音式标签搜索

> 日期：2026-09-08
> 模块：Flutter 端 —— 统一全局搜索页（`features/search`）+ 搜索筛选（`shared/searchengine`）+ 模板检索（`features/templates/search`）

## 一、背景与目标

当前搜索页（`GlobalSearchPage`）通过**筛选弹层**提供模板分类/价格/来源、场景分类/风格、美学院主题/等级的筛选，并通过排序 chips 排序。用户希望：

1. 增加**按照片比例筛选**：1:1、3:4、4:3、9:16、16:9，入口放在现有「筛选弹层」内，作为模板栏目下的新分组。
2. 增加**抖音式 `#` 标签搜索**：在搜索框输入 `#` 进入标签搜索，`#标签名` 精确按模板标签过滤；输入时给出**联想标签下拉**；模板卡片/列表上的 **`#标签` 可点击**，点击后跳转按该标签搜索。

### 数据事实
- 模板照片比例存于 `TemplateRecord.composition['aspectRatio']`（内置/自定义模板由 mapper 写入），缺失时回退 `postProcess['cropRatio']`。现有内置模板中 1:1 / 3:4 / 9:16 / 16:9 均有数据，4:3 仅 1 款。
- 模板的 `tags`（`List<String>`）为风格/情绪标签，当前仅在「多字段关键词搜索」中被顺带命中，卡片 UI 未展示为可点击标签。

## 二、设计

### A. 比例筛选

1. **`SearchFilters`（`lib/shared/searchengine/search_filters.dart`）**
   - 新增字段 `String? ratio`（模板照片比例，值为 `1:1` / `3:4` / `4:3` / `9:16` / `16:9`，null=全部）。
   - 同步 `copyWith`、`reset()`（保留 sort，清空条件）、`hasActiveConditions`（`ratio != null` 计入）。

2. **比例候选常量**
   - 定义 `const List<String> kTemplateAspectRatios = ['1:1','3:4','4:3','9:16','16:9'];`（放在 `search_filters.dart`，供筛选弹层与检索共用）。

3. **筛选弹层（`lib/shared/searchengine/filter_sheet.dart`）**
   - `showSearchFilterSheet` 新增入参 `current` 已含 `ratio`（复用 `SearchFilters`，无需额外参数）。
   - 在 **template 分支**（`scope == SearchScope.template`）以及 **「全部」合并面板的模板部分**新增「比例」分组：`全部` + 5 档单选 `LumiraFilterChip`，写入 `_draft.ratio`。

4. **检索过滤（`lib/features/templates/search/template_search_service.dart`）**
   - `search()` 在分类、价格过滤之后，新增比例过滤：
     - 模板比例取 `t.composition['aspectRatio']`，为空时回退 `t.postProcess['cropRatio']`；
     - 与 `filters.ratio` 全等匹配（`ratio != null` 时生效）。

5. **后端能力判定（`template_remote_search_service.dart`）**
   - `isBackendCapable`：当 `ratio` 非空时返回 `false`（后端搜索接口不支持比例），搜索页据此回退本地全量检索。

6. **搜索页接线（`global_search_page.dart`）**
   - `_openFilter` 已把 `_filters` 作为 `current` 传入，比例随 `SearchFilters` 一并携带；确认「确定」后 `_filters.ratio` 生效并 `_recompute()`。
   - 因 `ratio` 非空触发本地全量检索路径，`_templateResultsFrom` 已复用 `TemplateSearchService.search`，自动覆盖比例过滤。

### B. 抖音式 `#` 标签搜索

1. **标签搜索判定与匹配**
   - 判定：关键词 `trim()` 后以 `#` 开头即为标签搜索模式，`#` 后的文本为标签词（空标签词=全部带标签模板）。
   - 匹配：标签模式下**仅**对模板 `tags`（`List<String>`）逐项做 `containsIgnoreCase(tag, 标签词)`；不再命中 name / 分类 / 描述等其它字段。
   - 在 `TemplateSearchService` 增加标签模式的处理：`matchesKeyword` 分支——`keyword` 为 `#` 前缀时仅扫描 `t.tags`；`#` 前缀可携带尾随空格（如选手动输入带空格），内部仍按 `#` 后文本匹配。

2. **输入联想标签下拉**
   - 标签库：搜索页加载各模板的 `tags`，去重聚合为 `{ 标签 → 模板数量 }`（在 `_load()` 中从 `_allTemplates` 构建）。
   - 交互：`onChanged` 时若输入为 `#` 模式，计算与标签词匹配的候选（`containsIgnoreCase`），在搜索栏下方渲染候选列表（`#标签 (N)`），点击候选 → 以 `#标签` 替换输入框并搜索。
   - 实现：页面新增强 `List<({String name, int count})> _tagSuggestions`；在 `_buildSearchBar` 与 `_buildScopeBar` 之间的 Column 内追加下拉面板（仅 `#` 模式且候选非空时显示）。

3. **点标签卡片跳搜索**
   - `SearchResultCard` / `SearchResultListTile` 新增回调 `ValueChanged<String>? onTagTap`。
   - 模板分支信息区在现有分类/氛围胶囊之后追加可点击的 `#标签` chips（取 `r.template.tags`，最多展示前 N 个），chips 用独立 `InkWell`/`GestureDetector`，命中后调用 `onTagTap('#标签')`，不触发整卡 `onTap` 打开详情。
   - 搜索页把 `onTagTap` 接到 `_submitSearch(tag)`，从而「点标签即搜该标签」。

### C. 边界与取舍
- **远端模板比例**：远端模板仅当本地已缓存到**详情**（`composition` 有 `aspectRatio`）时才参与比例命中；未拉取详情的远端模板不进入比例过滤结果（已知限制，暂不改后端/不引入新增字段）。
- **标签模式空词**：输入纯 `#` 时展示全部带标签模板，并显示全部联想候选，便于浏览。
- 比例与标签筛选与现有分类/价格/来源等筛选可叠加（`SearchFilters` 内不同字段各自生效）。

## 三、涉及文件清单

| 文件 | 改动 |
|---|---|
| `lib/shared/searchengine/search_filters.dart` | 新增 `ratio` 字段、`kTemplateAspectRatios`、同步 copyWith/reset/hasActiveConditions |
| `lib/shared/searchengine/filter_sheet.dart` | template 及 all 面板新增「比例」分组 |
| `lib/features/templates/search/template_search_service.dart` | 比例过滤 + `#` 标签模式匹配 |
| `lib/features/templates/search/template_remote_search_service.dart` | `isBackendCapable` 对 ratio 返回 false |
| `lib/features/search/pages/global_search_page.dart` | 聚合标签库、联想下拉、onTagTap 接线 |
| `lib/features/search/widgets/search_result_card.dart` | 卡片/列表模板分支追加可点击 `#标签` chips |

## 四、验证
- `flutter analyze` 通过。
- 模板搜索：比例为本地全量路径，比例筛选、`#` 标签筛选、点标签跳搜、联想下拉在 4 套 UI 风格下渲染正常。