import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/dao/tags_dao.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../widgets/lumira/lumira.dart'
    show
        ButtonVariant,
        LumiraBottomSheetContainer,
        LumiraButton,
        LumiraFilterChip;
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
    builder: (_) => LumiraBottomSheetContainer(
      isScrollControlled: true,
      padding: EdgeInsets.zero,
      child: _FilterSheet(
        scope: scope,
        initial: current,
        userTags: userTags,
        categoryOptions: categoryOptions,
        sceneStyleOptions: sceneStyleOptions,
        sceneCategoryOptions: sceneCategoryOptions,
        academyTopicOptions: academyTopicOptions,
        academyLevelOptions: academyLevelOptions,
      ),
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
    final isAll = widget.scope == SearchScope.all;

    return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(tokens),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 「全部」统一合并面板：一次展示所有类型的维度。
                  if (isAll) ...[
                    _section(tokens, '模板 · 分类', _categoryItems()),
                    _section(tokens, '模板 · 价格', _priceItems()),
                    _section(tokens, '模板 · 来源', _sourceItems()),
                    _section(tokens, '场景 · 分类', _sceneCategoryItems()),
                    _section(tokens, '场景 · 风格', _sceneStyleItems()),
                    _section(tokens, '美学院 · 主题', _topicItems()),
                    _section(tokens, '美学院 · 等级', _levelItems()),
                    if (widget.userTags.isNotEmpty)
                      _section(tokens, '用户标签', _userTagItems()),
                  ] else ...[
                    if (widget.scope == SearchScope.template) ...[
                      _section(tokens, '分类', _categoryItems()),
                      _section(tokens, '价格', _priceItems()),
                      _section(tokens, '来源', _sourceItems()),
                    ],
                    if (widget.scope == SearchScope.scene) ...[
                      _section(tokens, '分类', _sceneCategoryItems()),
                      _section(tokens, '风格', _sceneStyleItems()),
                    ],
                    if (widget.scope == SearchScope.academy) ...[
                      _section(tokens, '主题', _topicItems()),
                      _section(tokens, '等级', _levelItems()),
                    ],
                    if (widget.scope != SearchScope.academy &&
                        widget.userTags.isNotEmpty)
                      _section(tokens, '用户标签', _userTagItems()),
                  ],
                ],
              ),
            ),
          ),
          _footer(tokens),
        ],
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
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }

  Widget _header(ThemeTokens tokens) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
      child: Row(
        children: [
          const Spacer(),
          Text('筛选',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary)),
          const Spacer(),
        ],
      ),
    );
  }

  // === 各分组选项（返回 LumiraFilterChip 列表） ===

  List<Widget> _categoryItems() {
    return [
      LumiraFilterChip(
        label: '全部',
        active: _draft.category == null,
        onTap: () =>
            setState(() => _draft = _draft.copyWith(category: () => null)),
      ),
      for (final o in widget.categoryOptions)
        LumiraFilterChip(
          label: o.label,
          active: _draft.category == o.key,
          onTap: () =>
              setState(() => _draft = _draft.copyWith(category: () => o.key)),
        ),
    ];
  }

  List<Widget> _sceneCategoryItems() {
    return [
      LumiraFilterChip(
        label: '全部',
        active: _draft.sceneCategory == null,
        onTap: () => setState(() =>
            _draft = _draft.copyWith(sceneCategory: () => null)),
      ),
      for (final c in widget.sceneCategoryOptions)
        LumiraFilterChip(
          label: c,
          active: _draft.sceneCategory == c,
          onTap: () =>
              setState(() => _draft = _draft.copyWith(sceneCategory: () => c)),
        ),
    ];
  }

  List<Widget> _sceneStyleItems() {
    return [
      LumiraFilterChip(
        label: '全部',
        active: _draft.sceneStyle == null,
        onTap: () =>
            setState(() => _draft = _draft.copyWith(sceneStyle: () => null)),
      ),
      for (final s in widget.sceneStyleOptions)
        LumiraFilterChip(
          label: s,
          active: _draft.sceneStyle == s,
          onTap: () =>
              setState(() => _draft = _draft.copyWith(sceneStyle: () => s)),
        ),
    ];
  }

  List<Widget> _topicItems() {
    return [
      LumiraFilterChip(
        label: '全部',
        active: _draft.academyTopic == null,
        onTap: () =>
            setState(() => _draft = _draft.copyWith(academyTopic: () => null)),
      ),
      for (final o in widget.academyTopicOptions)
        LumiraFilterChip(
          label: o.label,
          active: _draft.academyTopic == o.key,
          onTap: () => setState(
              () => _draft = _draft.copyWith(academyTopic: () => o.key)),
        ),
    ];
  }

  List<Widget> _levelItems() {
    return [
      LumiraFilterChip(
        label: '全部',
        active: _draft.academyLevel == null,
        onTap: () =>
            setState(() => _draft = _draft.copyWith(academyLevel: () => null)),
      ),
      for (final o in widget.academyLevelOptions)
        LumiraFilterChip(
          label: o.label,
          active: _draft.academyLevel == o.key,
          onTap: () => setState(
              () => _draft = _draft.copyWith(academyLevel: () => o.key)),
        ),
    ];
  }

  List<Widget> _priceItems() {
    return [
      for (final p in SearchPriceFilter.values)
        LumiraFilterChip(
          label: _priceLabel(p),
          active: _draft.price == p,
          onTap: () => setState(() => _draft = _draft.copyWith(price: p)),
        ),
    ];
  }

  List<Widget> _sourceItems() {
    return [
      LumiraFilterChip(
        label: '全部',
        active: !_draft.ownedOnly,
        onTap: () => setState(() => _draft = _draft.copyWith(ownedOnly: false)),
      ),
      LumiraFilterChip(
        label: '我拥有的',
        active: _draft.ownedOnly,
        onTap: () => setState(() => _draft = _draft.copyWith(ownedOnly: true)),
      ),
    ];
  }

  List<Widget> _userTagItems() {
    return [
      for (final e in widget.userTags)
        LumiraFilterChip(
          label: '${e.tag.name} (${e.count})',
          active: _draft.userTagIds.contains(e.tag.id),
          onTap: () {
            setState(() {
              final ids = {..._draft.userTagIds};
              if (!ids.add(e.tag.id)) ids.remove(e.tag.id);
              _draft = _draft.copyWith(userTagIds: ids);
            });
          },
        ),
    ];
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
            child: LumiraButton(
              variant: ButtonVariant.secondary,
              onPressed: () => setState(() => _draft = _draft.reset()),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: const Text('重置'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LumiraButton(
              variant: ButtonVariant.primary,
              onPressed: () => Navigator.of(context).pop(_draft),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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