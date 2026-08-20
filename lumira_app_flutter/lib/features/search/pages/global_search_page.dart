import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/dao/scenes_dao.dart';
import '../../../core/db/dao/tags_dao.dart';
import '../../../core/db/dao/templates_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/searchengine/filter_sheet.dart';
import '../../../shared/searchengine/paged_results_controller.dart';
import '../../../shared/searchengine/search_filters.dart';
import '../../../shared/searchengine/search_scope.dart';
import '../../../shared/searchengine/search_store.dart';
import '../../../shared/widgets/lumira/lumira.dart' show LumiraIconButton;
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../academy/data/academy_content.dart';
import '../../academy/data/academy_models.dart';
import '../../academy/search/academy_search_service.dart';
import '../../scenes/search/scene_search_service.dart';
import '../../templates/search/template_search_service.dart';
import '../data/search_result.dart';
import '../widgets/search_initial_sections.dart';
import '../widgets/search_result_card.dart';

/// 统一全局搜索页。
/// [scope] 决定初始范围；页面内 scope 切换栏可随时切换。
class GlobalSearchPage extends ConsumerStatefulWidget {
  const GlobalSearchPage({super.key, required this.scope});

  final SearchScope scope;

  @override
  ConsumerState<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends ConsumerState<GlobalSearchPage> {
  final TextEditingController _controller = TextEditingController();
  final PagedResultsController _pager = PagedResultsController(pageSize: 20);

  late SearchScope _scope;
  String _keyword = '';
  SearchFilters _filters = SearchFilters();

  bool _loaded = false;

  List<TemplateRecord> _allTemplates = const [];
  List<SceneRecord> _allScenes = const [];
  List<TagWithCount> _allTags = const [];
  Map<String, int> _scenePopularity = const {};
  Map<String, String> _categoryLabelByKey = const {};
  List<TemplateCategoryRecord> _level1Categories = const [];

  List<SearchResult> _results = const [];
  SearchStore? _store;

  @override
  void initState() {
    super.initState();
    _scope = widget.scope;
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final tDao = await ref.read(templatesDaoProvider.future);
    final sDao = await ref.read(scenesDaoProvider.future);
    final tagDao = await ref.read(userTagsDaoProvider.future);
    final store = await ref.read(searchStoreProvider.future);

    final builtin = await tDao.getBuiltinAndRemote();
    final customs = await tDao.getCustomOnly();
    final categories = await tDao.getCategories(activeOnly: true);
    final scenes = await sDao.getAll();
    final tTags = await tagDao.allTags(itemType: TagItemType.template);
    final sTags = await tagDao.allTags(itemType: TagItemType.scene);
    // 合并两类标签（按 tag.id 去重）
    final seenIds = <int>{};
    final mergedTags = <TagWithCount>[
      for (final e in [...tTags, ...sTags])
        if (seenIds.add(e.tag.id)) e,
    ];

    Map<String, int> scenePop = const {};
    try {
      final usageDao = await ref.read(usageDaoProvider.future);
      final counts =
          await usageDao.countMap('scene', scenes.map((s) => s.id).toList());
      scenePop = <String, int>{
        for (final s in scenes)
          if (counts[s.id] != null)
            s.id: counts[s.id]!.useShoot * 55 +
                counts[s.id]!.openDetail * 25 +
                counts[s.id]!.sceneSelect * 20,
      };
    } catch (_) {
      scenePop = const {};
    }

    if (!mounted) return;
    setState(() {
      _allTemplates = [...builtin, ...customs];
      _allScenes = scenes;
      _allTags = mergedTags;
      _scenePopularity = scenePop;
      _categoryLabelByKey = {for (final c in categories) c.key: c.name};
      _level1Categories =
          categories.where((c) => c.level == 1).toList();
      _store = store;
      _loaded = true;
    });
  }

  // === 关键词与搜索 ===

  void _onKeywordChanged(String v) {
    setState(() => _keyword = v);
    if (v.trim().isEmpty) {
      _pager.reset();
      setState(() => _results = const []);
    } else {
      _recompute();
    }
  }

  Future<void> _submitSearch(String keyword) async {
    final store = _store;
    if (store != null) {
      await store.record(_scope, keyword);
    }
    if (mounted) {
      setState(() {
        _keyword = keyword;
        _controller.text = keyword;
      });
      await _recompute();
    }
  }

  Future<void> _recompute() async {
    _pager.reset();
    final r = await _buildResults();
    if (!mounted) return;
    setState(() => _results = r);
    _loadMore(); // 加载第一页
  }

  Future<List<SearchResult>> _buildResults() async {
    final results = <SearchResult>[];
    if (_scope == SearchScope.all) {
      results.addAll(await _buildTemplateResults());
      results.addAll(await _buildSceneResults());
      results.addAll(_buildAcademyResults());
      // all 混合排序：hot 按热度，其余保持类型分组顺序
      if (_filters.sort == SearchSort.hot) {
        results.sort((a, b) => _hotScore(b).compareTo(_hotScore(a)));
      }
    } else if (_scope == SearchScope.template) {
      results.addAll(await _buildTemplateResults());
    } else if (_scope == SearchScope.scene) {
      results.addAll(await _buildSceneResults());
    } else {
      results.addAll(_buildAcademyResults());
    }
    return results;
  }

  Future<List<SearchResult>> _buildTemplateResults() async {
    final allowed = await _allowedTemplateIds();
    final list = TemplateSearchService.search(
      all: _allTemplates,
      keyword: _keyword,
      filters: _filters,
      categoryLabelByKey: _categoryLabelByKey,
      allowedIds: allowed,
    );
    return list
        .map((t) => SearchResult(scope: SearchScope.template, template: t))
        .toList();
  }

  Future<List<SearchResult>> _buildSceneResults() async {
    final allowed = await _allowedSceneIds();
    final list = SceneSearchService.search(
      all: _allScenes,
      keyword: _keyword,
      filters: _filters,
      allowedIds: allowed,
      popularity: _scenePopularity,
    );
    return list
        .map((s) => SearchResult(scope: SearchScope.scene, scene: s))
        .toList();
  }

  List<SearchResult> _buildAcademyResults() {
    final courses = AcademySearchService.searchCourses(
      all: AcademyContent.courses,
      keyword: _keyword,
      filters: _filters,
    );
    final cards = AcademySearchService.searchCards(
      all: AcademyContent.knowledgeCards,
      keyword: _keyword,
      filters: _filters,
    );
    final result = <SearchResult>[
      for (final c in courses)
        SearchResult(scope: SearchScope.academy, course: c),
      for (final k in cards)
        SearchResult(scope: SearchScope.academy, knowledgeCard: k),
    ];
    if (_filters.sort == SearchSort.latest) {
      // latest：课程在前，知识卡片在后（卡片保持原顺序）
      result.sort((a, b) {
        if (a.isCourse != b.isCourse) return a.isCourse ? -1 : 1;
        return 0;
      });
    }
    return result;
  }

  // === 用户标签 AND 交集（按 scope 定向查 item_type） ===

  Future<Set<String>?> _allowedTemplateIds() {
    if (_filters.userTagIds.isEmpty) return Future.value(null);
    return _intersect(TagItemType.template);
  }

  Future<Set<String>?> _allowedSceneIds() {
    if (_filters.userTagIds.isEmpty) return Future.value(null);
    return _intersect(TagItemType.scene);
  }

  Future<Set<String>> _intersect(String itemType) async {
    final dao = await ref.read(userTagsDaoProvider.future);
    var keep = <String>{};
    var first = true;
    for (final tagId in _filters.userTagIds) {
      final ids =
          (await dao.itemIdsByTag(itemType: itemType, tagId: tagId)).toSet();
      keep = first ? ids : keep.intersection(ids);
      first = false;
    }
    return keep;
  }

  int _hotScore(SearchResult r) {
    if (r.scope == SearchScope.scene) {
      return _scenePopularity[r.id] ?? 0;
    }
    if (r.template != null) {
      return r.template!.isRecommended ? 100 : 0;
    }
    if (r.course != null) return r.course!.rewardXP;
    return 0;
  }

  // === UI ===

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final isSearching = _keyword.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _buildNav(tokens),
            _buildKeywordField(tokens),
            _buildScopeBar(tokens),
            const Divider(height: 1, thickness: 0.5),
            Expanded(
              child:
                  isSearching ? _buildResultView(tokens) : _buildInitialView(tokens),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNav(ThemeTokens tokens) {
    return LumiraNav(
      title: '搜索',
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: TextField(
        controller: _controller,
        onChanged: _onKeywordChanged,
        textInputAction: TextInputAction.search,
        onSubmitted: (v) => _submitSearch(v),
        decoration: InputDecoration(
          hintText: '搜索模板 / 场景 / 美学院',
          prefixIcon: Icon(Icons.search, size: 18, color: tokens.textSecondary),
          suffixIcon: _keyword.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close, size: 16, color: tokens.textSecondary),
                  onPressed: () {
                    _controller.clear();
                    _onKeywordChanged('');
                  },
                ),
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

  Widget _buildScopeBar(ThemeTokens tokens) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          for (final s in SearchScope.values)
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: GestureDetector(
                onTap: () => _switchScope(s),
                child: Text(
                  s.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        _scope == s ? FontWeight.w700 : FontWeight.w500,
                    color: _scope == s ? tokens.brand : tokens.textSecondary,
                  ),
                ),
              ),
            ),
          const Spacer(),
          if (_keyword.trim().isNotEmpty)
            GestureDetector(
              onTap: _openFilter,
              child: Text('筛选 ▾',
                  style: TextStyle(fontSize: 13, color: tokens.textPrimary)),
            ),
        ],
      ),
    );
  }

  void _switchScope(SearchScope s) {
    if (s == _scope) return;
    setState(() => _scope = s);
    _pager.reset();
    if (_keyword.trim().isNotEmpty) {
      _recompute();
    }
  }

  // === 初始页 ===

  Widget _buildInitialView(ThemeTokens tokens) {
    return FutureBuilder<List<SearchInitialData>>(
      future: _initialData(),
      builder: (context, snap) {
        final data = snap.data;
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final d = data.first;
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SearchHistorySection(
                keywords: d.history,
                onTap: (k) => _submitSearch(k),
                onDelete: (k) => _deleteHistory(k),
                onClear: () => _clearHistory(),
              ),
              SearchHotSection(keywords: d.hot, onTap: (k) => _submitSearch(k)),
              if (_scope == SearchScope.all) ...[
                SearchRecommendTemplateSection(
                  items: d.templateCategories,
                  onTap: (k) => _submitSearch(k),
                ),
                SearchRecommendSceneSection(
                  styles: d.sceneStyles,
                  onTap: (k) => _submitSearch(k),
                ),
                SearchRecommendAcademySection(
                  topics: d.academyTopics,
                  levels: d.academyLevels,
                  onTap: (k) => _submitSearch(k),
                ),
              ] else if (_scope == SearchScope.template)
                SearchRecommendTemplateSection(
                  items: d.templateCategories,
                  onTap: (k) => _submitSearch(k),
                )
              else if (_scope == SearchScope.scene)
                SearchRecommendSceneSection(
                  styles: d.sceneStyles,
                  onTap: (k) => _submitSearch(k),
                )
              else
                SearchRecommendAcademySection(
                  topics: d.academyTopics,
                  levels: d.academyLevels,
                  onTap: (k) => _submitSearch(k),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<List<SearchInitialData>> _initialData() async {
    final store = _store;
    final history = store == null
        ? const <String>[]
        : await store.recentKeywords(_scope);
    final hot = store == null
        ? const <String>[]
        : await store.hotKeywords(_scope);
    final templateCategories = _level1Categories
        .map((c) => MapEntry(c.key, c.name))
        .toList();
    final sceneStyleSet = <String>{};
    for (final s in _allScenes) {
      if (s.style.isNotEmpty) sceneStyleSet.add(s.style);
    }
    final sceneStyles = sceneStyleSet.take(6).toList();
    final academyTopics = <String>[
      for (final t in AcademyTopic.values) t.label,
    ];
    final academyLevels = <String>[
      for (final l in AcademyLevel.values) l.label,
    ];
    return [
      SearchInitialData(
        history: history,
        hot: hot,
        templateCategories: templateCategories,
        sceneStyles: sceneStyles,
        academyTopics: academyTopics,
        academyLevels: academyLevels,
      ),
    ];
  }

  Future<void> _deleteHistory(String keyword) async {
    await _store?.deleteKeyword(_scope, keyword);
    if (mounted) setState(() {});
  }

  Future<void> _clearHistory() async {
    await _store?.clear(_scope);
    if (mounted) setState(() {});
  }

  // === 结果页 ===

  Widget _buildResultView(ThemeTokens tokens) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200 &&
            n.metrics.axis == Axis.vertical) {
          _loadMore();
        }
        return false;
      },
      child: CustomScrollView(
        slivers: [
          if (_results.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmpty(tokens),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.56,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final r = _results[index];
                    return SearchResultCard(
                      result: r,
                      showTypeBadge: _scope == SearchScope.all,
                      onTap: () => _openResult(r),
                    );
                  },
                  childCount: _pager.visible.clamp(0, _results.length),
                ),
              ),
            ),
          SliverToBoxAdapter(child: _buildFooter(tokens)),
        ],
      ),
    );
  }

  Widget _buildEmpty(ThemeTokens tokens) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.search_off, size: 48, color: tokens.textTertiary),
        const SizedBox(height: 12),
        Text('换个关键词试试',
            style: TextStyle(fontSize: 14, color: tokens.textSecondary)),
      ],
    );
  }

  Widget _buildFooter(ThemeTokens tokens) {
    if (_results.isEmpty) return const SizedBox.shrink();
    if (_pager.hasMore(_results.length)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text('加载中…',
              style: TextStyle(fontSize: 12, color: tokens.textSecondary)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text('已经到底了',
            style: TextStyle(fontSize: 12, color: tokens.textTertiary)),
      ),
    );
  }

  void _loadMore() {
    final total = _results.length;
    if (_pager.loadMore(total)) {
      setState(() {});
      // 延迟一帧结束 loading，避免同一帧内连续触发
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pager.finishLoading();
      });
    }
  }

  Future<void> _openFilter() async {
    final categoryOptions = _level1Categories
        .map((c) => CategoryOption(c.key, c.name))
        .toList();
    final sceneStyles = <String>{};
    for (final s in _allScenes) {
      if (s.style.isNotEmpty) sceneStyles.add(s.style);
    }
    final sceneCategories = <String>{};
    for (final s in _allScenes) {
      if (s.category.isNotEmpty) sceneCategories.add(s.category);
    }
    final result = await showSearchFilterSheet(
      context: context,
      scope: _scope,
      current: _filters,
      userTags: _allTags,
      categoryOptions: categoryOptions,
      sceneStyleOptions: sceneStyles.toList(),
      sceneCategoryOptions: sceneCategories.toList(),
      academyTopicOptions: [
        for (final t in AcademyTopic.values) CategoryOption(t.name, t.label),
      ],
      academyLevelOptions: [
        for (final l in AcademyLevel.values) CategoryOption(l.name, l.label),
      ],
    );
    if (result != null) {
      setState(() => _filters = result);
      _recompute();
    }
  }

  void _openResult(SearchResult r) {
    if (r.template != null) {
      GoRouter.of(context).push(
        RouteNames.withTemplateId(RouteNames.templatesDetail, r.template!.id),
      );
    } else if (r.scene != null) {
      GoRouter.of(context).push(
        RouteNames.withSceneId(RouteNames.captureSceneDetail, r.scene!.id),
      );
    } else if (r.isCourse) {
      GoRouter.of(context).push(RouteNames.build(RouteNames.profileAcademyDetail,
          {RouteNames.paramAcademyId: r.course!.id}));
    } else {
      GoRouter.of(context).push(RouteNames.build(
          RouteNames.profileAcademyKnowledge,
          {RouteNames.paramAcademyId: r.knowledgeCard!.id}));
    }
  }
}

/// 初始页数据快照。
class SearchInitialData {
  final List<String> history;
  final List<String> hot;
  final List<MapEntry<String, String>> templateCategories;
  final List<String> sceneStyles;
  final List<String> academyTopics;
  final List<String> academyLevels;

  const SearchInitialData({
    required this.history,
    required this.hot,
    required this.templateCategories,
    required this.sceneStyles,
    required this.academyTopics,
    required this.academyLevels,
  });
}
