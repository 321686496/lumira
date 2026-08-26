# Task 5: 「全部模板」页收藏过滤 toggle

> 项目：Flutter 客户端 `lumira_app_flutter/`（模板收藏功能）。所有命令在 `lumira_app_flutter/` 目录下执行。
> 分支：feat/template-favorite（当前 head `3aa19828`）。只 commit，不 push。

**Files:**
- Modify: `lib/features/templates/pages/templates_all_page.dart`

**Interfaces:**
- Consumes:
  - `favoriteTemplateIdsProvider`（`FutureProvider<Set<String>>`，位于 `lib/features/templates/data/templates_providers.dart`，需新增 import）
  - 现有 `_FilterSection` / `_CustomToggle` / `_TemplatesAllPageState`（`_TemplatesAllPageState` 是 `ConsumerState`，build 中可 `ref.watch`）
  - `templates_providers.dart` 里已有的 `templateCategoryProvider` 与 `remoteTemplatesSyncProvider` 等 —— 只加收藏 provider 的 import，不要动其它。
- Produces: 「收藏」toggle 与「我的」toggle 并排；命中时仅展示已收藏模板；收藏过滤与分类/价格/「我的」筛选取交集。

## 关键设计要点

1. **`_CustomToggle` 泛化**：让它支持自定义 icon/label，供「我的」与「收藏」两个 toggle 复用。当前默认 `Icons.bookmark`/`Icons.bookmark_border_outlined` + 文案「我的」，改为构造参数（带默认值，保持原调用不变）。
2. **过滤数据流**：收藏过滤加在 `_loadData` 的 `_priceFilter` 分支之后、`return _AllPageData(...)` 之前（`var filtered` 之上）。用 `ref.read(favoriteTemplateIdsProvider).valueOrNull` 取收藏 id 集合，非空时 `filtered = filtered.where((t) => favIds.contains(t.id)).toList()`。
3. **响应收藏变化**：`_loadData` 是异步方法、由 build 里内联的 `FutureBuilder` future 驱动。要在收藏变化后自动刷新列表，须在 `build()` 顶部 `ref.watch(favoriteTemplateIdsProvider)`（触发重建 → 重新生成 future → 重新执行 `_loadData`）。注意：`ref.watch` 必须在 build 顶部无条件调用。

---

- [ ] **Step 1: 新增 import**

在 `templates_all_page.dart` import 区（`data/templates_providers.dart` 相关行附近）加：

```dart
import '../data/templates_providers.dart';
```

若该文件已 import `templates_providers.dart`（含 `templateCategoryProvider`），则跳过此步，只需确认 `favoriteTemplateIdsProvider` 可访问。

- [ ] **Step 2: 泛化 `_CustomToggle` 以支持 icon/label**

将 `_CustomToggle` 构造参数扩展为可选图标与文案，默认值保持「我的」现状：

```dart
class _CustomToggle extends ConsumerWidget {
  const _CustomToggle({
    required this.tokens,
    required this.active,
    required this.onTap,
    this.icon = Icons.bookmark_border_outlined,
    this.activeIcon = Icons.bookmark,
    this.label = '我的',
  });

  final ThemeTokens tokens;
  final bool active;
  final VoidCallback onTap;
  final IconData icon;
  final IconData activeIcon;
  final String label;
```

build 内 / 文本两处改为读参数：
- `Icon(active ? activeIcon : icon, size: 14, color: active ? Colors.white : tokens.textSecondary),`
- `Text(label, style: ...)`

> 保持 `Colors.white`（激活态文字/图标），与原实现一致；非激活态用 `tokens.textSecondary`。此 toggle 不在照片（非纯色底）上，保留现有渐变/阴影即可，勿改动观感。

- [ ] **Step 3: state 新增 `_showFavorites`**

在 `_TemplatesAllPageState` 中，`_showCustom` 同域加：

```dart
  bool _showFavorites = false;
```

并在 `_toggleCustom` 旁新增回调：

```dart
  void _toggleFavorites(bool value) {
    setState(() => _showFavorites = value);
  }
```

- [ ] **Step 4: 收藏过滤逻辑**

在 `_loadData` 的 `_priceFilter` 分支之后、`return _AllPageData(...)` 之前插入（`var filtered` 之上追加收缩）：

```dart
    // 收藏过滤：仅保留已收藏模板（与分类、价格、我的 toggle 取交集）
    if (_showFavorites) {
      final favIds = ref.read(favoriteTemplateIdsProvider).valueOrNull;
      if (favIds != null) {
        filtered = filtered.where((t) => favIds.contains(t.id)).toList();
      }
    }
```

> 位置：紧跟现有 `if (_priceFilter == ...)` 价格筛选块之后。`ref` 在 `ConsumerState` 的 method 内可用（`_loadData` 中已有 `ref.read(galleryDaoProvider.future)` 用法，保持一致）。

- [ ] **Step 5: build 顶watch 收藏 provider**

在 `build()` 顶部（`final tokens = ref.watch(themeTokensProvider);` 附近）加一行 watch 以响应收藏变化并触发列表刷新：

```dart
    // watch 收藏集合：收藏/取消后重建 future，自动刷新「收藏」过滤列表
    ref.watch(favoriteTemplateIdsProvider);
```

> 必须在 build 顶部无条件调用，不允许放在条件分支里（Riverpod 约束）。

- [ ] **Step 6: `_FilterSection` 新增「收藏」toggle**

在 `_FilterSection` 构造参数中补充 `showFavorites` 与 `onToggleFavorites`：

```dart
    required this.showFavorites,
    required this.onToggleFavorites,
```

对应字段：
```dart
  final bool showFavorites;
  final void Function(bool) onToggleFavorites;
```

在 `_FilterSection` 的 build 中，将现有「我的」toggle 改为与「收藏」toggle 并排（`Align` → `Row`，两 toggle 之间加 `SizedBox(width: 8)`）。即把当前：

```dart
            Align(
              alignment: Alignment.centerRight,
              child: _CustomToggle(
                tokens: tokens,
                active: showCustom,
                onTap: () => onToggleCustom(!showCustom),
              ),
            ),
```

替换为：

```dart
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CustomToggle(
                    tokens: tokens,
                    active: showFavorites,
                    onTap: () => onToggleFavorites(!showFavorites),
                    icon: Icons.favorite_border,
                    activeIcon: Icons.favorite,
                    label: '收藏',
                  ),
                  const SizedBox(width: 8),
                  _CustomToggle(
                    tokens: tokens,
                    active: showCustom,
                    onTap: () => onToggleCustom(!showCustom),
                  ),
                ],
              ),
            ),
```

在调用处（build 内 `_FilterSection(...)`）传入：
```dart
                                        showFavorites: _showFavorites,
                                        onToggleFavorites: _toggleFavorites,
```

> 布局：`Row` + `mainAxisSize: MainAxisSize.min` 保证右对齐并排不换行，与「我的」toggle 对齐。

- [ ] **Step 7: analyze**

Run: `flutter analyze lib/features/templates/pages/templates_all_page.dart`
Expected: 无新增 error（允许既有 info）。

- [ ] **Step 8: 运行既有相关测试**

Run: `flutter test test/features/templates`
Expected: 既有相关测试仍全部通过（本任务不改 DAO/SQL，仅 UI 过滤）。若测试目录/命名不同，用 `flutter test` 定位到 templates 相关测试文件即可。

- [ ] **Step 9: Commit**

```bash
git add lib/features/templates/pages/templates_all_page.dart
git commit -m "feat(templates): 全部模板页新增收藏过滤 toggle"
```

> 提交前确认 git status 暂存内容仅含该文件。**只 commit，不 push。**

若遇到 `_CustomToggle` 泛化后既有「我的」toggle 渲染差异、或 `ref.watch` 位置导致的编译问题，报告时详细说明实际情况与你的适配方式。