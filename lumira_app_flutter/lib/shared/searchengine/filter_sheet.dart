import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/dao/tags_dao.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import 'search_filters.dart';
import 'search_scope.dart';

/// 分类下拉选项（key→中文标签）。
class CategoryOption {
  final String key;
  final String label;
  const CategoryOption(this.key, this.label);
}

/// 弹出全量筛选弹层，返回用户确认后的新筛选状态；取消（点遮罩/返回）返回 null。
Future<SearchFilters?> showSearchFilterSheet({
  required BuildContext context,
  required SearchScope scope,
  required SearchFilters current,
  required List<TagWithCount> userTags,
  required List<CategoryOption> categoryOptions,
  required List<String> sceneStyleOptions,
  required List<String> sceneCategoryOptions,
  required List<CategoryOption> academyTopicOptions,
  required List<CategoryOption> academyLevelOptions,
}) async {
  final result = await showModalBottomSheet<SearchFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FilterSheet(
      scope: scope,
      initial: current,
      userTags: userTags,
      categoryOptions: categoryOptions,
      sceneStyleOptions: sceneStyleOptions,
      sceneCategoryOptions: sceneCategoryOptions,
      academyTopicOptions: academyTopicOptions,
      academyLevelOptions: academyLevelOptions,
    ),
  );
  return result;
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({
    required this.scope,
    required this.initial,
    required this.userTags,
    required this.categoryOptions,
    required this.sceneStyleOptions,
    required this.sceneCategoryOptions,
    required this.academyTopicOptions,
    required this.academyLevelOptions,
  });

  final SearchScope scope;
  final SearchFilters initial;
  final List<TagWithCount> userTags;
  final List<CategoryOption> categoryOptions;
  final List<String> sceneStyleOptions;
  final List<String> sceneCategoryOptions;
  final List<CategoryOption> academyTopicOptions;
  final List<CategoryOption> academyLevelOptions;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late SearchFilters _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final scope = widget.scope;
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(tokens),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (scope == SearchScope.template) ...[
                      _categorySection(tokens),
                      _priceSection(tokens),
                      _sourceSection(tokens),
                    ],
                    if (scope == SearchScope.scene) ...[
                      _sceneCategorySection(tokens),
                      _styleSection(tokens),
                    ],
                    if (scope == SearchScope.academy) ...[
                      _topicSection(tokens),
                      _levelSection(tokens),
                    ],
                    if (scope != SearchScope.academy && widget.userTags.isNotEmpty)
                      _userTagSection(tokens),
                  ],
                ),
              ),
            ),
            _footer(tokens),
          ],
        ),
      ),
    );
  }

  Widget _section(ThemeTokens tokens, String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tokens.textSecondary)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }

  Widget _header(ThemeTokens tokens) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          TextButton(
            onPressed: () => setState(() => _draft = _draft.reset()),
            child: Text('重置',
                style: TextStyle(color: tokens.textSecondary)),
          ),
          const Spacer(),
          Text('筛选',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary)),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_draft),
            child: Text('确定',
                style: TextStyle(
                    color: tokens.brand, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _categorySection(ThemeTokens tokens) {
    return _section(tokens, '分类', [
      _Pill(
        label: '全部',
        active: _draft.category == null,
        tokens: tokens,
        onTap: () =>
            setState(() => _draft = _draft.copyWith(category: () => null)),
      ),
      for (final o in widget.categoryOptions)
        _Pill(
          label: o.label,
          active: _draft.category == o.key,
          tokens: tokens,
          onTap: () =>
              setState(() => _draft = _draft.copyWith(category: () => o.key)),
        ),
    ]);
  }

  Widget _sceneCategorySection(ThemeTokens tokens) {
    return _section(tokens, '分类', [
      _Pill(
        label: '全部',
        active: _draft.category == null,
        tokens: tokens,
        onTap: () =>
            setState(() => _draft = _draft.copyWith(category: () => null)),
      ),
      for (final c in widget.sceneCategoryOptions)
        _Pill(
          label: c,
          active: _draft.category == c,
          tokens: tokens,
          onTap: () =>
              setState(() => _draft = _draft.copyWith(category: () => c)),
        ),
    ]);
  }

  Widget _styleSection(ThemeTokens tokens) {
    return _section(tokens, '风格', [
      _Pill(
        label: '全部',
        active: _draft.sceneStyle == null,
        tokens: tokens,
        onTap: () =>
            setState(() => _draft = _draft.copyWith(sceneStyle: () => null)),
      ),
      for (final s in widget.sceneStyleOptions)
        _Pill(
          label: s,
          active: _draft.sceneStyle == s,
          tokens: tokens,
          onTap: () =>
              setState(() => _draft = _draft.copyWith(sceneStyle: () => s)),
        ),
    ]);
  }

  Widget _topicSection(ThemeTokens tokens) {
    return _section(tokens, '主题', [
      _Pill(
        label: '全部',
        active: _draft.academyTopic == null,
        tokens: tokens,
        onTap: () =>
            setState(() => _draft = _draft.copyWith(academyTopic: () => null)),
      ),
      for (final o in widget.academyTopicOptions)
        _Pill(
          label: o.label,
          active: _draft.academyTopic == o.key,
          tokens: tokens,
          onTap: () => setState(
              () => _draft = _draft.copyWith(academyTopic: () => o.key)),
        ),
    ]);
  }

  Widget _levelSection(ThemeTokens tokens) {
    return _section(tokens, '等级', [
      _Pill(
        label: '全部',
        active: _draft.academyLevel == null,
        tokens: tokens,
        onTap: () =>
            setState(() => _draft = _draft.copyWith(academyLevel: () => null)),
      ),
      for (final o in widget.academyLevelOptions)
        _Pill(
          label: o.label,
          active: _draft.academyLevel == o.key,
          tokens: tokens,
          onTap: () => setState(
              () => _draft = _draft.copyWith(academyLevel: () => o.key)),
        ),
    ]);
  }

  Widget _priceSection(ThemeTokens tokens) {
    return _section(tokens, '价格', [
      for (final p in SearchPriceFilter.values)
        _Pill(
          label: _priceLabel(p),
          active: _draft.price == p,
          tokens: tokens,
          onTap: () => setState(() => _draft = _draft.copyWith(price: p)),
        ),
    ]);
  }

  Widget _sourceSection(ThemeTokens tokens) {
    return _section(tokens, '来源', [
      _Pill(
        label: '全部',
        active: !_draft.ownedOnly,
        tokens: tokens,
        onTap: () => setState(() => _draft = _draft.copyWith(ownedOnly: false)),
      ),
      _Pill(
        label: '我拥有的',
        active: _draft.ownedOnly,
        tokens: tokens,
        onTap: () => setState(() => _draft = _draft.copyWith(ownedOnly: true)),
      ),
    ]);
  }

  Widget _userTagSection(ThemeTokens tokens) {
    return _section(tokens, '用户标签', [
      for (final e in widget.userTags)
        _Pill(
          label: '${e.tag.name} (${e.count})',
          active: _draft.userTagIds.contains(e.tag.id),
          tokens: tokens,
          onTap: () {
            setState(() {
              final ids = {..._draft.userTagIds};
              if (!ids.add(e.tag.id)) ids.remove(e.tag.id);
              _draft = _draft.copyWith(userTagIds: ids);
            });
          },
        ),
    ]);
  }

  Widget _footer(ThemeTokens tokens) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(top: BorderSide(color: tokens.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _draft = _draft.reset()),
              child: const Text('重置'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_draft),
              child: const Text('确定'),
            ),
          ),
        ],
      ),
    );
  }

  static String _priceLabel(SearchPriceFilter p) {
    switch (p) {
      case SearchPriceFilter.all:
        return '全部';
      case SearchPriceFilter.free:
        return '免费';
      case SearchPriceFilter.paid:
        return '付费';
    }
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.active,
    required this.tokens,
    required this.onTap,
  });

  final String label;
  final bool active;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? tokens.brand : tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(9999),
          border: active
              ? null
              : Border.all(color: tokens.divider, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: active ? tokens.textInverse : tokens.textSecondary,
          ),
        ),
      ),
    );
  }
}
