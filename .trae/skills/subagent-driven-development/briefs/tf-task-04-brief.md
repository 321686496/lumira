# Task 4: 模板详情页红心收藏按钮

> 项目：Flutter 客户端 `lumira_app_flutter/`（模板收藏功能）。所有命令在 `lumira_app_flutter/` 目录下执行。
> 分支：feat/template-favorite（当前 head `558ad6d4`）。只 commit，不 push。

**Files:**
- Modify: `lib/features/templates/pages/templates_detail_page.dart`

**Interfaces:**
- Consumes:
  - `favoriteTemplateIdsProvider`（`FutureProvider<Set<String>>`，位于 `lib/features/templates/data/templates_providers.dart`，需新增 import）
  - `templatesFavoriteDaoProvider`（位于 `../../../core/db/database_provider.dart`，该文件顶部已 import 第 9 行）；`TemplatesFavoriteDao.toggleFavorite(String) → Future<bool>`
  - `tokens.brand` / `tokens.textSecondary`；`LumiraIconButton`（已有 import `shared/widgets/lumira/lumira.dart`）
- Produces: 收藏红心按钮始终为 `LumiraNav.actions` 第一个；`_FavoriteToggle`（ConsumerWidget）内部点击 toggleFavorite 并 `ref.invalidate(favoriteTemplateIdsProvider)`。

要点：详情页为 `ConsumerStatefulWidget`（state 已能访问 `ref`）。收藏 id 用 `_template?.id ?? ''`，为空时不显示红心（返回 null）。

- [ ] **Step 1: 新增 import**

在 `templates_detail_page.dart` import 区（`../data/owned_templates_repository.dart` 附近）加：

```dart
import '../data/templates_providers.dart';
```

- [ ] **Step 2: 重构 `_navActions`**

将现有 `_navActions(ThemeTokens tokens, bool isLocked)` 方法整体替换为「收藏按钮恒在首位 + 原分支按钮」：

```dart
  List<Widget>? _navActions(ThemeTokens tokens, bool isLocked) {
    final id = _template?.id ?? '';
    final heart = id.isEmpty
        ? null
        : _FavoriteToggle(
            templateId: id,
            tokens: tokens,
          );
    final rest = <Widget>[
      if (_isMyTemplate) ...[
        if (_isCustomTemplate)
          LumiraIconButton(
            icon: Icons.ios_share,
            onPressed: _goExport,
            color: tokens.textPrimary,
            size: 20,
          ),
        LumiraIconButton(
          icon: Icons.edit_outlined,
          onPressed: _goEdit,
          color: tokens.textPrimary,
          size: 20,
        ),
      ],
      if (isLocked) _CreditBalanceChip(onTap: _goPointsWallet),
    ];
    if (heart == null && rest.isEmpty) return null;
    return [if (heart != null) heart, ...rest];
  }
```

- [ ] **Step 3: 新增 `_FavoriteToggle` widget**

在文件顶层（与其他非私有成员同级，文件末尾追加）：

```dart
/// 详情页红心收藏按钮：跟随收藏状态切换空心/实心，点击切换收藏并刷新收藏集。
class _FavoriteToggle extends ConsumerWidget {
  const _FavoriteToggle({required this.templateId, required this.tokens});

  final String templateId;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteIds =
        ref.watch(favoriteTemplateIdsProvider).valueOrNull ?? const <String>{};
    final isFav = favoriteIds.contains(templateId);
    return LumiraIconButton(
      icon: isFav ? Icons.favorite : Icons.favorite_border,
      onPressed: () async {
        final dao = await ref.read(templatesFavoriteDaoProvider.future);
        await dao.toggleFavorite(templateId);
        ref.invalidate(favoriteTemplateIdsProvider);
      },
      color: isFav ? tokens.brand : tokens.textSecondary,
      size: 20,
    );
  }
}
```

> `valueOrNull` 需要 `flutter_riverpod` 的 AsyncValue 扩展（文件已 import flutter_riverpod）。若当前文件中没有其它 `.valueOrNull` 用法，可不加前缀（`FavoriteTemplateIdsAsync.valueOrNull` 方式仅在歧义时需全名）。`LumiraIconButton` 已可访问。

- [ ] **Step 4: analyze**

Run: `flutter analyze lib/features/templates/pages/templates_detail_page.dart`
Expected: 无新增 error（允许既有 info）。

- [ ] **Step 5: Commit**

```bash
git add lib/features/templates/pages/templates_detail_page.dart
git commit -m "feat(templates): 详情页新增红心收藏按钮"
```

> 提交前确认 git status 暂存内容仅含该文件。**只 commit，不 push。**

若遇到 `LumiraIconButton` 或 `valueOrNull` 相关编译/类型问题，报告时详细说明实际情况，注明你为适配既有组件签名所做的必要调整。