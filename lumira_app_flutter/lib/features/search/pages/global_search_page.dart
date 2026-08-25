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
import '../../academy/data/academy_content.dart';
import '../../academy/data/academy_models.dart';
import '../../academy/search/academy_search_service.dart';
import '../../scenes/search/scene_search_service.dart';
import '../../templates/data/remote_template_dto.dart';
import '../../templates/data/remote_templates_providers.dart';
import '../../templates/search/template_remote_search_service.dart';
import '../../templates/search/template_search_service.dart';
import '../../templates/services/template_mapper.dart';
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
  Map<String, int> _templateUsageCounts = const {};

  List<SearchResult> _results = const [];
  SearchStore? _store;

  /// 结果布局：true=瀑布流（双列），false=单列列表。
  bool _layoutWaterfall = true;

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

    Map<String, int> templateUsage = const {};
    try {
      final usage = await ref.read(galleryDaoProvider.future);
      templateUsage = await usage.countByTemplate();
    } catch (_) {
      templateUsage = const {};
    }
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
      _templateUsageCounts = templateUsage;
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

  /// 提交搜索。可选 [scope]：点击推荐卡片时切换到对应栏目后再搜索。
  Future<void> _submitSearch(String keyword, {SearchScope? scope}) async {
    if (scope != null && scope != _scope) {
      setState(() => _scope = scope);
    }
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

  /// 点击推荐卡片：按卡片目标 scope 搜索。
  void _submitFromRecommend(SearchRecommendItem item) =>
      _submitSearch(item.keyword, scope: item.scope);

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
      // all 混合排序：hot/photos 按热度/拍摄数，name 按名称，其余保持类型分组顺序
      switch (_filters.sort) {
        case SearchSort.hot:
          results.sort((a, b) => _hotScore(b).compareTo(_hotScore(a)));
          break;
        case SearchSort.photos:
          results.sort((a, b) => _photoScore(b).compareTo(_photoScore(a)));
          break;
        case SearchSort.name:
          results.sort((a, b) => a.title.compareTo(b.title));
          break;
        case SearchSort.comprehensive:
        case SearchSort.latest:
          break;
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

  /// 模板检索：
  /// - 无高级筛选（价格/仅我拥有/用户标签）时，优先实时走后端搜索接口拿最新
  ///   后台运营模板（全站热度 2:1 由后端排序），再与本地内置/自定义合并；
  /// - 命中后端不支持的筛选，或后端请求失败/离线时，回退本地 sqflite 全量检索。
  Future<List<SearchResult>> _buildTemplateResults() async {
    final allowed = await _allowedTemplateIds();
    if (!TemplateRemoteSearchService.isBackendCapable(_filters)) {
      // 后端不支持价格/仅我拥有/用户标签 → 纯本地全量检索
      return _templateResultsFrom(_allTemplates, allowed: allowed);
    }

    final List<RemoteTemplateSearchItemDto> remoteItems;
    try {
      final repo = await ref.read(remoteTemplatesRepositoryProvider.future);
      final resp = await TemplateRemoteSearchService.search(
        repo,
        keyword: _keyword,
        filters: _filters,
      );
      remoteItems = resp.items;
    } catch (_) {
      // 网络失败/离线 → 回退本地全量缓存（含已同步的 remote 模板）
      return _templateResultsFrom(_allTemplates, allowed: allowed);
    }

    // 后台实时模板 + 本地内置/自定义（排除已同步 remote，避免与后台结果重复）
    final remoteHot = {
      for (final it in remoteItems) it.meta.id: it.hotScore,
    };
    final remoteShoot = {
      for (final it in remoteItems) it.meta.id: it.shootCount,
    };
    final remote = [
      for (final it in remoteItems)
        SearchResult(
          scope: SearchScope.template,
          template: TemplateMapper.metaToRecord(it.meta),
          usageCount: _templateUsageCounts[it.meta.id] ?? 0,
          categoryLabels: _categoryLabelByKey,
        ),
    ];
    final localPool = _allTemplates.where((t) => t.source != 'remote').toList();
    final local = _templateResultsFrom(localPool, allowed: allowed);

    return _mergeTemplateResults(
      remote: remote,
      local: local,
      remoteHot: remoteHot,
      remoteShoot: remoteShoot,
    );
  }

  /// 本地检索并映射为搜索结果（内置/自定义或回退全量时复用）。
  List<SearchResult> _templateResultsFrom(
    List<TemplateRecord> all, {
    Set<String>? allowed,
  }) {
    final list = TemplateSearchService.search(
      all: all,
      keyword: _keyword,
      filters: _filters,
      categoryLabelByKey: _categoryLabelByKey,
      allowedIds: allowed,
      usageCounts: _templateUsageCounts,
    );
    return list
        .map((t) => SearchResult(
              scope: SearchScope.template,
              template: t,
              usageCount: _templateUsageCounts[t.id] ?? 0,
              categoryLabels: _categoryLabelByKey,
            ))
        .toList();
  }

  /// 合并远程（后台实时）+ 本地（内置/自定义）结果并统一排序。
  /// 远程模板用后端全站热度/拍摄数，本地用降级分（recommended / 本地拍摄数）。
  List<SearchResult> _mergeTemplateResults({
    required List<SearchResult> remote,
    required List<SearchResult> local,
    required Map<String, int> remoteHot,
    required Map<String, int> remoteShoot,
  }) {
    var combined = [...remote, ...local];
    switch (_filters.sort) {
      case SearchSort.comprehensive:
        // 综合：远程按后台 sortOrder（后端已排序），本地保持默认顺序置后
        break;
      case SearchSort.hot:
        combined.sort((a, b) {
          final ha = _remoteScore(a.id, remoteHot,
              fallback: a.template?.isRecommended == true ? 1 : 0);
          final hb = _remoteScore(b.id, remoteHot,
              fallback: b.template?.isRecommended == true ? 1 : 0);
          if (ha != hb) return hb.compareTo(ha);
          return _templateUpdatedAtMs(b).compareTo(_templateUpdatedAtMs(a));
        });
        break;
      case SearchSort.photos:
        combined.sort((a, b) {
          final pa = _remoteScore(a.id, remoteShoot, fallback: a.usageCount);
          final pb = _remoteScore(b.id, remoteShoot, fallback: b.usageCount);
          if (pa != pb) return pb.compareTo(pa);
          return a.title.compareTo(b.title);
        });
        break;
      case SearchSort.latest:
        combined.sort(
            (a, b) => _templateUpdatedAtMs(b).compareTo(_templateUpdatedAtMs(a)));
        break;
      case SearchSort.name:
        combined.sort((a, b) => a.title.compareTo(b.title));
        break;
    }
    return combined;
  }

  int _remoteScore(String id, Map<String, int> map, {required int fallback}) =>
      map[id] ?? fallback;

  int _templateUpdatedAtMs(SearchResult r) => r.template?.updatedAt ?? 0;

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

  /// 拍摄照片数得分（mixed 排序用）。
  int _photoScore(SearchResult r) {
    if (r.template != null) return r.usageCount;
    if (r.scope == SearchScope.scene) return _scenePopularity[r.id] ?? 0;
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
        bottom: false,
        child: Column(
          children: [
            _buildSearchBar(tokens),
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

  /// 顶部搜索栏：返回按钮 + 搜索框 +（有关键词时）筛选入口。
  /// 将搜索框直接嵌入导航栏，消除原先「导航标题 + 独立搜索框」两行的冗余排版。
  Widget _buildSearchBar(ThemeTokens tokens) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 4),
      child: Row(
        children: [
          LumiraIconButton(
            icon: Icons.arrow_back_ios_new,
            onPressed: () => Navigator.of(context).pop(),
            size: 20,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: _onKeywordChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => _submitSearch(v),
              decoration: InputDecoration(
                hintText: '搜索模板 / 场景 / 美学院',
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: tokens.textSecondary,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 34,
                  maxHeight: 34,
                ),
                suffixIcon: _keyword.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 16,
                          color: tokens.textSecondary,
                        ),
                        onPressed: () {
                          _controller.clear();
                          _onKeywordChanged('');
                        },
                      ),
                isDense: true,
                filled: true,
                fillColor: tokens.surfaceAlt,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeBar(ThemeTokens tokens) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
      child: Row(
        children: [
          for (final s in SearchScope.values)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => _switchScope(s),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: _scope == s ? tokens.brand : tokens.surfaceAlt,
                    borderRadius: BorderRadius.circular(999),
                    border: _scope == s
                        ? null
                        : Border.all(color: tokens.divider, width: 1),
                  ),
                  child: Text(
                    s.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          _scope == s ? FontWeight.w600 : FontWeight.w500,
                      color: _scope == s
                          ? tokens.textInverse
                          : tokens.textSecondary,
                    ),
                  ),
                ),
              ),
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
                  items: d.templateItems,
                  onTap: _submitFromRecommend,
                ),
                SearchRecommendSceneSection(
                  items: d.sceneItems,
                  onTap: _submitFromRecommend,
                ),
                SearchRecommendAcademySection(
                  items: d.academyItems,
                  onTap: _submitFromRecommend,
                ),
              ] else if (_scope == SearchScope.template)
                SearchRecommendTemplateSection(
                  items: d.templateItems,
                  onTap: _submitFromRecommend,
                )
              else if (_scope == SearchScope.scene)
                SearchRecommendSceneSection(
                  items: d.sceneItems,
                  onTap: _submitFromRecommend,
                )
              else
                SearchRecommendAcademySection(
                  items: d.academyItems,
                  onTap: _submitFromRecommend,
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
    return [
      SearchInitialData(
        history: history,
        hot: hot,
        templateItems: _buildTemplateRecommendItems(),
        sceneItems: _buildSceneRecommendItems(),
        academyItems: _buildAcademyRecommendItems(),
      ),
    ];
  }

  // === 推荐卡片封面选取 ===

  /// 模板推荐：每个一级分类取该关键词下「最火爆（拍摄数最多）的模板」做封面，
  /// 火爆并列时取最新（createdAt 大）的模板；卡片展示分类中文名、在模板栏目内搜索。
  List<SearchRecommendItem> _buildTemplateRecommendItems() {
    final items = <SearchRecommendItem>[];
    for (final c in _level1Categories) {
      TemplateRecord? best;
      var bestUsage = -1;
      for (final t in _allTemplates) {
        if (!TemplateSearchService.matchesKeyword(t, c.name,
            categoryLabelByKey: _categoryLabelByKey)) {
          continue;
        }
        final usage = _templateUsageCounts[t.id] ?? 0;
        if (best == null ||
            usage > bestUsage ||
            (usage == bestUsage && t.createdAt > best.createdAt)) {
          best = t;
          bestUsage = usage;
        }
      }
      items.add(SearchRecommendItem(
        scope: SearchScope.template,
        keyword: c.name,
        label: c.name,
        cover: best?.cover,
        coverData: best?.coverData,
        fallbackIcon: Icons.photo_camera_outlined,
      ));
    }
    return items;
  }

  /// 场景推荐：按风格去重，每风格取该关键词下「最新日期（createdAt 大）的场景」做代表，
  /// 日期相同时取第一个；卡片展示该场景的名称与封面、在场景栏目内按场景名搜索。
  List<SearchRecommendItem> _buildSceneRecommendItems() {
    final items = <SearchRecommendItem>[];
    final seenStyles = <String>{};
    for (final s in _allScenes) {
      if (s.style.isEmpty || !seenStyles.add(s.style)) continue;
      final rep = _latestSceneForStyle(s.style);
      if (rep == null) continue;
      final cover = rep.coverUrl.isNotEmpty
          ? rep.coverUrl
          : (rep.exampleImages.isNotEmpty ? rep.exampleImages.first : '');
      items.add(SearchRecommendItem(
        scope: SearchScope.scene,
        keyword: rep.name,
        label: rep.name,
        cover: cover.isNotEmpty ? cover : null,
        fallbackIcon: Icons.camera_roll_outlined,
      ));
      if (items.length >= 6) break;
    }
    return items;
  }

  /// 场景风格下最新日期的场景（_allScenes 已按 createdAt DESC，首个命中即最新/并列首个）。
  SceneRecord? _latestSceneForStyle(String style) {
    for (final s in _allScenes) {
      if (s.style == style) return s;
    }
    return null;
  }

  /// 美学院推荐：主题 + 等级，各取该关键词下「第一个相关内容（课程优先、知识卡在后）的封面」。
  List<SearchRecommendItem> _buildAcademyRecommendItems() {
    final items = <SearchRecommendItem>[];
    for (final t in AcademyTopic.values) {
      items.add(SearchRecommendItem(
        scope: SearchScope.academy,
        keyword: t.label,
        label: t.label,
        cover: _firstAcademyCover(t.label),
        fallbackIcon: Icons.menu_book_outlined,
      ));
    }
    for (final l in AcademyLevel.values) {
      items.add(SearchRecommendItem(
        scope: SearchScope.academy,
        keyword: l.label,
        label: l.label,
        cover: _firstAcademyCover(l.label),
        fallbackIcon: Icons.school_outlined,
      ));
    }
    return items;
  }

  String? _firstAcademyCover(String keyword) {
    for (final c in AcademyContent.courses) {
      if (AcademySearchService.courseMatchesKeyword(c, keyword)) {
        return c.coverImage;
      }
    }
    for (final k in AcademyContent.knowledgeCards) {
      if (AcademySearchService.cardMatchesKeyword(k, keyword)) {
        return k.coverImage;
      }
    }
    return null;
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

  /// 工具栏展示的排序选项（用户要求的排序方式）。
  static const List<SearchSort> _sortOptions = [
    SearchSort.comprehensive,
    SearchSort.hot,
    SearchSort.photos,
    SearchSort.name,
    SearchSort.latest,
  ];

  static String _sortLabel(SearchSort s) {
    switch (s) {
      case SearchSort.comprehensive:
        return '综合';
      case SearchSort.hot:
        return '火爆';
      case SearchSort.photos:
        return '拍摄数';
      case SearchSort.name:
        return '名称';
      case SearchSort.latest:
        return '最新';
    }
  }

  Widget _buildResultView(ThemeTokens tokens) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 40),
          child: _buildEmpty(tokens),
        ),
      );
    }
    return Column(
      children: [
        _buildToolbar(tokens),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: _onResultScroll,
            child:
                _layoutWaterfall ? _buildWaterfallView(tokens) : _buildListView(tokens),
          ),
        ),
      ],
    );
  }

  /// 排序 chips + 布局切换。
  Widget _buildToolbar(ThemeTokens tokens) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final s in _sortOptions) ...[
                    _SortChip(
                      label: _sortLabel(s),
                      active: _filters.sort == s,
                      tokens: tokens,
                      onTap: () {
                        if (_filters.sort == s) return;
                        setState(() => _filters = _filters.copyWith(sort: s));
                        _recompute();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              _layoutWaterfall ? Icons.view_list : Icons.grid_view,
              size: 20,
              color: tokens.textSecondary,
            ),
            tooltip: _layoutWaterfall ? '切换到列表' : '切换到瀑布流',
            onPressed: () => setState(() => _layoutWaterfall = !_layoutWaterfall),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.tune, size: 20, color: tokens.textSecondary),
            tooltip: '筛选',
            onPressed: _openFilter,
          ),
        ],
      ),
    );
  }

  bool _onResultScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
      _loadMore();
    }
    return false;
  }

  /// 瀑布流：双列等高平衡，卡片各自固有高度（解决固定高网格导致的溢出）。
  Widget _buildWaterfallView(ThemeTokens tokens) {
    final screenW = MediaQuery.of(context).size.width;
    final cardW = (screenW - 40 - 12) / 2; // 左右 padding 20*2 + 列间距 12
    final n = _pager.visible.clamp(0, _results.length);

    final left = <Widget>[];
    final right = <Widget>[];
    double lh = 0, rh = 0;
    for (var i = 0; i < n; i++) {
      final r = _results[i];
      final card = SearchResultCard(
        result: r,
        showTypeBadge: _scope == SearchScope.all,
        onTap: () => _openResult(r),
      );
      final h = _estimateCardHeight(r, cardW) + 12;
      final item = Padding(
          padding: const EdgeInsets.only(bottom: 12), child: card);
      if (lh <= rh) {
        left.add(item);
        lh += h;
      } else {
        right.add(item);
        rh += h;
      }
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Column(children: left)),
              const SizedBox(width: 12),
              Expanded(child: Column(children: right)),
            ],
          ),
          _buildFooter(tokens),
        ],
      ),
    );
  }

  /// 估算卡片高度（用于瀑布流左右列平衡分配，非精确值）。
  double _estimateCardHeight(SearchResult r, double w) {
    final coverRatio = r.scope == SearchScope.academy ? 4 / 3 : 3 / 4;
    final coverH = w / coverRatio;
    var body = 46.0; // 上下 padding + 标题行
    if (r.template != null) {
      body += r.shortDesc.isNotEmpty ? 3 + 14 : 0; // 描述行
      body += 6 + 16; // 标签行
    } else if (r.scene != null) {
      body += 6 + 22;
    } else {
      body += 6 + 20;
    }
    return coverH + body;
  }

  /// 列表布局：单列横向卡。
  Widget _buildListView(ThemeTokens tokens) {
    final n = _pager.visible.clamp(0, _results.length);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      itemCount: n,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final r = _results[i];
        return SearchResultListTile(
          result: r,
          showTypeBadge: _scope == SearchScope.all,
          onTap: () => _openResult(r),
        );
      },
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
  final List<SearchRecommendItem> templateItems;
  final List<SearchRecommendItem> sceneItems;
  final List<SearchRecommendItem> academyItems;

  const SearchInitialData({
    required this.history,
    required this.hot,
    required this.templateItems,
    required this.sceneItems,
    required this.academyItems,
  });
}

/// 排序 chip（工具栏用）。
class _SortChip extends StatelessWidget {
  const _SortChip({
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
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? tokens.brand : tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: active
              ? null
              : Border.all(color: tokens.divider, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? tokens.textInverse : tokens.textSecondary,
          ),
        ),
      ),
    );
  }
}
