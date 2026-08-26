# Task 3: 收藏状态 Provider

> 项目：Flutter 客户端 `lumira_app_flutter/`（模板收藏功能）。所有命令在 `lumira_app_flutter/` 目录下执行。
> 分支：feat/template-favorite（当前 head `e0ea6789`）。只 commit，不 push。

**Files:**
- Modify: `lib/features/templates/data/templates_providers.dart`

**Interfaces:**
- Consumes: `templatesFavoriteDaoProvider`（Task 1 实现，已在该文件 import 的 `core/db/database_provider.dart` 中）、方法 `getFavoriteIds()`。
- Produces: provider `favoriteTemplateIdsProvider`（`FutureProvider<Set<String>>`）——已收藏的模板 id 集合，收藏/取消后应 `ref.invalidate(favoriteTemplateIdsProvider)` 由使用方重建。

- [ ] **Step 1: 新增 provider**

在 `templates_providers.dart` 文件**末尾**追加：

```dart

/// 已收藏的模板 id 集合（收藏状态 UI 的唯一数据源）。
/// 收藏/取消后 `ref.invalidate(favoriteTemplateIdsProvider)` 触发重建。
final favoriteTemplateIdsProvider = FutureProvider<Set<String>>((ref) async {
  final dao = await ref.watch(templatesFavoriteDaoProvider.future);
  final ids = await dao.getFavoriteIds();
  return ids.toSet();
});
```

> 该文件顶部已 `import '../../../core/db/database_provider.dart';`（第 13 行），`templatesFavoriteDaoProvider` 可直接使用，无需新增 import。文件尾部确保有换行结尾。

- [ ] **Step 2: analyze**

Run: `flutter analyze lib/features/templates/data`
Expected: 无新增 error。

- [ ] **Step 3: Commit**

```bash
git add lib/features/templates/data/templates_providers.dart
git commit -m "feat(templates): 新增收藏状态 provider"
```

> 提交前确认 git status 暂存内容仅含该文件。**只 commit，不 push。**