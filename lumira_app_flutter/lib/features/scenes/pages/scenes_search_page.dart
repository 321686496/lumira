import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/dao/scenes_dao.dart';
import '../../../core/db/dao/tags_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/lumira/lumira.dart' show LumiraIconButton;
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../tags/tag_filter_logic.dart';

/// 场景搜索页：关键词（名称/氛围/分类）+ 用户标签筛选 + 结果 2 列网格。
class ScenesSearchPage extends ConsumerStatefulWidget {
  const ScenesSearchPage({super.key});

  @override
  ConsumerState<ScenesSearchPage> createState() => _ScenesSearchPageState();
}

class _ScenesSearchPageState extends ConsumerState<ScenesSearchPage> {
  final TextEditingController _controller = TextEditingController();
  String _keyword = '';
  // 已被选中的用户标签 tagId
  final Set<int> _selectedTagIds = <int>{};
  // 已加载的全部场景
  List<SceneRecord> _allScenes = const [];
  // 全部用户标签（name -> tagId,count）
  List<TagWithCount> _allTags = const [];
  // 用户标签 AND 过滤后的结果（Task 8）
  List<SceneRecord> _userTagFiltered = const [];
  // 场景全站流行度（sceneId -> 合并计数），用于搜索结果排序
  Map<String, int> _scenePopularity = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sDao = await ref.read(scenesDaoProvider.future);
    final tagDao = await ref.read(userTagsDaoProvider.future);
    final scenes = await sDao.getAll();
    final tags = await tagDao.allTags(itemType: TagItemType.scene);
    // 全站流行度：离线/无 usage_stats 表（测试 fixture）时读取失败不降级，保持空 map
    Map<String, int> pop = const {};
    try {
      final usageDao = await ref.read(usageDaoProvider.future);
      pop = <String, int>{};
      for (final s in scenes) {
        final useS = await usageDao.countFor('scene', s.id, 'use_shoot');
        final openD = await usageDao.countFor('scene', s.id, 'open_detail');
        final sel = await usageDao.countFor('scene', s.id, 'scene_select');
        pop[s.id] = (useS * 55 + openD * 25 + sel * 20);
      }
    } catch (_) {
      pop = const {};
    }
    if (!mounted) return;
    setState(() {
      _allScenes = scenes;
      _allTags = tags;
      _scenePopularity = pop;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 关键词命中的场景。
  List<SceneRecord> _keywordHits() {
    final q = _keyword.trim();
    return _allScenes
        .where((s) => sceneMatchesKeyword(s.name, s.vibe, s.category, q))
        .toList();
  }

  /// 在关键词命中结果上叠加「用户标签 AND」过滤，并按全站流行度降序。
  Future<void> _refreshUserTagFilter(List<SceneRecord> keywordHits) async {
    if (_selectedTagIds.isEmpty) {
      if (!mounted) return;
      setState(() => _userTagFiltered = _sortByPopularity(keywordHits));
      return;
    }
    final dao = await ref.read(userTagsDaoProvider.future);
    var keep = keywordHits.map((e) => e.id).toSet();
    for (final tagId in _selectedTagIds) {
      final ids = (await dao.itemIdsByTag(
        itemType: TagItemType.scene,
        tagId: tagId,
      )).toSet();
      keep = keep.intersection(ids);
    }
    final filtered = keywordHits.where((s) => keep.contains(s.id)).toList();
    if (!mounted) return;
    setState(() => _userTagFiltered = _sortByPopularity(filtered));
  }

  /// 按全站流行度（sceneId -> 合并计数）降序排序。
  List<SceneRecord> _sortByPopularity(List<SceneRecord> list) {
    final sorted = [...list];
    final pop = _scenePopularity;
    sorted.sort((a, b) => ((pop[b.id] ?? 0)).compareTo(pop[a.id] ?? 0));
    return sorted;
  }

  void _updateKeyword(String v) {
    setState(() => _keyword = v);
    _refreshUserTagFilter(_keywordHits());
  }

  void _toggleTag(int tagId) {
    setState(() {
      if (_selectedTagIds.contains(tagId)) {
        _selectedTagIds.remove(tagId);
      } else {
        _selectedTagIds.add(tagId);
      }
    });
    _refreshUserTagFilter(_keywordHits());
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
      title: '搜索场景',
      transparent: true,
      leading: LumiraIconButton(
        icon: Icons.arrow_back_ios_new,
        onPressed: () => Navigator.of(context).pop(),
        size: 20,
      ),
      actions: [
        LumiraIconButton(
          icon: Icons.label_outline,
          onPressed: () => GoRouter.of(context).push(RouteNames.myTags),
          size: 20,
        ),
      ],
    );
  }

  Widget _buildKeywordField(ThemeTokens tokens) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: TextField(
        controller: _controller,
        onChanged: _updateKeyword,
        decoration: InputDecoration(
          hintText: '搜索场景名称或氛围',
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
            onTap: () => _toggleTag(e.tag.id),
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
                  color: active ? tokens.textInverse : tokens.textSecondary, // 跟随主题
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResults(ThemeTokens tokens) {
    final results = _userTagFiltered;
    if (results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: Text('未找到相关场景')),
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
        childAspectRatio: 0.58,
      ),
      itemCount: results.length,
      itemBuilder: (_, index) {
        final s = results[index];
        return GestureDetector(
          onTap: () => GoRouter.of(context).push(
            RouteNames.withSceneId(RouteNames.captureSceneDetail, s.id),
          ),
          child: _SceneSearchCard(scene: s, tokens: tokens),
        );
      },
    );
  }
}

class _SceneSearchCard extends StatelessWidget {
  const _SceneSearchCard({required this.scene, required this.tokens});

  final SceneRecord scene;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final first =
        scene.exampleImages.isNotEmpty ? scene.exampleImages.first : null;
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.divider, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              color: tokens.brandSubtle,
              child: first != null
                  ? Image.network(
                      first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(tokens),
                    )
                  : _placeholder(tokens),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scene.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  scene.vibe,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: tokens.brand,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(ThemeTokens tokens) => Center(
        child: Icon(Icons.image_outlined, size: 28, color: tokens.brand),
      );
}