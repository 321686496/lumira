# Task 5 报告：「全部模板」页收藏过滤 toggle

**Status:** DONE_WITH_CONCERNS

## 实现了什么

在 `lumira_app_flutter/lib/features/templates/pages/templates_all_page.dart` 实现「全部模板」页的收藏过滤 toggle：

1. **`_CustomToggle` 泛化**：增加构造参数 `icon` / `activeIcon` / `label`（带默认值 `Icons.bookmark_border_outlined` / `Icons.bookmark` / `'我的'`），保持原「我的」调用不变，供「收藏」与「我的」两个 toggle 复用。
2. **新增收藏过滤数据流**：
   - `_TemplatesAllPageState` 新增 `bool _showFavorites` 状态 + `_toggleFavorites()` 方法。
   - `_loadData` 在 `_priceFilter` 分支之后、`return _AllPageData` 之前，用 `ref.read(favoriteTemplateIdsProvider).valueOrNull` 取收藏 id 集合，非空时 `filtered = filtered.where((t) => favIds.contains(t.id)).toList()`，与分类/价格/「我的」筛选取交集（逻辑 AND）。
   - build 顶部 `ref.watch(favoriteTemplateIdsProvider)`（无条件调用）→ 收藏变化触发重建 → 重新生成 future → 自动刷新列表。
3. **`_FilterSection` 渲染「收藏」+「我的」两个 toggle 并排**：传入 `showFavorites` / `onToggleFavorites` 参数，收藏 toggle 用 `Icons.favorite_border` / `Icons.favorite` + 文案「收藏」。

改动量：1 file，+51 / -9。

## 测试与验证

- `flutter analyze lib/features/templates/pages/templates_all_page.dart` → **No issues found**。
- `flutter test test/features/templates` → 224+ 通过；**10 个失败**全部集中在 `test/features/templates/templates_page_test.dart`（模板**入口页**，如 recommendation 卡片 / "发现" 标题 / 滚动 nav），与本任务改动无关（此前已通过 stash + 干净状态验证为预存失败）。本任务相关的 `templates_all_page_test.dart` 与 `templates_editor_page_test.dart` 全部通过。

## 变更文件

- `lumira_app_flutter/lib/features/templates/pages/templates_all_page.dart`（M）

## 提交

- `260939f1 feat(templates): 全部模板页新增收藏过滤 toggle`（仅 commit，未 push）

## 自审

- **完整性**：brief 三类要点（`_CustomToggle` 泛化、过滤数据流、响应收藏变化）均已落地。
- **质量/纪律**：十字口仅改目标文件，未牵动其它 import；`ref.watch` 在 build 顶部无条件调用，符合 Riverpod 规范；收藏 provider import 已从 `templates_providers.dart` 引入，未动其它 provider。
- **YAGNI**：未新增多余抽象或测试，仅按 brief 实现最小改动。

## 关注点

- `templates_page_test.dart` 的 10 个失败为**预存问题**，非本次改动引入，建议单独跟进（涉及模板入口页 recommendation 相关断言，可能与屏幕尺寸/滚动偏移有关）。