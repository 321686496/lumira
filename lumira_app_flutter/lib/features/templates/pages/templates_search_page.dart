import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/dao/tags_dao.dart';
import '../../../core/db/dao/templates_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../tags/tag_filter_logic.dart';
import '../data/templates_browse_mock_data.dart';
import '../widgets/template_cover_image.dart';

/// 模板搜索页：关键词（名称/分类/系统标签）+ 标签筛选 + 结果 2 列网格。
class TemplatesSearchPage extends ConsumerStatefulWidget {
  const TemplatesSearchPage({super.key});

  @override
  ConsumerState<TemplatesSearchPage> createState() =>
      _TemplatesSearchPageState();
}

class _TemplatesSearchPageState extends ConsumerState<TemplatesSearchPage> {
  final TextEditingController _controller = TextEditingController();
  String _keyword = '';
  // 已被选中的用户标签 tagId
  final Set<int> _selectedTagIds = <int>{};
  // 已加载的全部模板
  List<TemplateRecord> _allTemplates = const [];
  // 全部用户标签（name -> tagId,count）
  List<TagWithCount> _allTags = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tDao = await ref.read(templatesDaoProvider.future);
    final tagDao = await ref.read(userTagsDaoProvider.future);
    final builtin = await tDao.getBuiltinAndRemote();
    final customs = await tDao.getCustomOnly();
    final tags = await tagDao.allTags(itemType: TagItemType.template);
    if (!mounted) return;
    setState(() {
      _allTemplates = [...builtin, ...customs];
      _allTags = tags;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _buildNav(tokens),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildKeywordField(tokens),
                    if (_allTags.isNotEmpty) _buildTagBar(tokens),
                    _buildResults(tokens),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNav(ThemeTokens tokens) {
    return LumiraNav(
      title: '搜索模板',
      transparent: true,
      leading: LumiraIconButton(
        icon: Icons.arrow_back_ios_new,
        onPressed: () => Navigator.of(context).pop(),
        size: 20,
      ),
    );
  }

  Widget _buildKeywordField(ThemeTokens tokens) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: TextField(
        controller: _controller,
        onChanged: (v) => setState(() => _keyword = v),
        decoration: InputDecoration(
          hintText: '搜索模板名称、分类或标签',
          prefixIcon: Icon(Icons.search, size: 18, color: tokens.textSecondary),
          isDense: true,
          filled: true,
          fillColor: tokens.surfaceAlt,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildTagBar(ThemeTokens tokens) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _allTags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final e = _allTags[i];
          final active = _selectedTagIds.contains(e.tag.id);
          return GestureDetector(
            onTap: () {
              setState(() {
                if (active) {
                  _selectedTagIds.remove(e.tag.id);
                } else {
                  _selectedTagIds.add(e.tag.id);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active ? tokens.brand : tokens.surfaceAlt,
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Text(
                '${e.tag.name} (${e.count})',
                style: TextStyle(
                  fontSize: 12,
                  color: active ? Colors.white : tokens.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResults(ThemeTokens tokens) {
    final q = _keyword.trim();
    // 关键词过滤（名称/分类/系统标签）
    final hits = _allTemplates
        .where((t) =>
            templateMatchesKeyword(t.name, t.category, t.tags, q))
        .toList();
    // 用户标签 AND 筛选（需 DB join: itemIdsByTag 交集）由 Task 8 主导完成，
    // 本任务先展示关键词命中的结果（标签栏选中态可切换，结果过滤留待 Task 8 接入）。
    final results = hits;

    if (results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: Text('未找到相关模板')),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.56,
      ),
      itemCount: results.length,
      itemBuilder: (_, index) {
        final t = results[index];
        return GestureDetector(
          onTap: () => GoRouter.of(context).push(
            RouteNames.withTemplateId(RouteNames.templatesDetail, t.id),
          ),
          child: _SearchTplCard(template: t, tokens: tokens),
        );
      },
    );
  }
}

class _SearchTplCard extends ConsumerWidget {
  const _SearchTplCard({required this.template, required this.tokens});

  final TemplateRecord template;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.divider, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                TemplateCoverImage(
                  cover: template.cover.isEmpty ? null : template.cover,
                  coverData: template.coverData,
                  fit: BoxFit.cover,
                  fallback: Container(
                    color: tokens.surfaceAlt,
                    child: Icon(Icons.photo_outlined,
                        color: tokens.textTertiary, size: 28),
                  ),
                  errorFallback: Container(
                    color: tokens.surfaceAlt,
                    child: Icon(Icons.broken_image_outlined,
                        color: tokens.textTertiary),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Noto Serif SC',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  TemplatesBrowseMockData.categoryLabel(template.category),
                  style: TextStyle(fontSize: 11, color: tokens.brand),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}