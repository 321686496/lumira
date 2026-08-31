import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lumira_app_flutter/core/utils/image_cache.dart';

import '../../../core/db/dao/templates_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/searchengine/search_scope.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/builtin_category_icons.dart';
import '../data/remote_templates_providers.dart';
import '../data/templates_browse_mock_data.dart';
import '../data/templates_providers.dart';
import '../services/template_mapper.dart';
import '../widgets/adaptive_cover_image.dart';
import '../widgets/ambience_badges.dart';
import '../widgets/template_import_sheet.dart';

/// 全部模板页
///
/// 视觉规格来源：lumira-app/src/pages/templates/all.vue
/// 5 个 section：
/// 1. HeroCard（模板库 + X 个模板等你探索 + 已解锁 Y 个）
/// 2. FilterSection（3 层级联分类 Type→Style→Method + TagSelector 占位 + 我的 toggle）
/// 3. ActionRow（仅 _showCustom=true 时显示：导入模板 + 新建模板）
/// 4. TemplateGrid（2 列网格）或 EmptyState
class TemplatesAllPage extends ConsumerStatefulWidget {
  const TemplatesAllPage({super.key, this.scene, this.category});

  final String? scene;
  final String? category;

  @override
  ConsumerState<TemplatesAllPage> createState() => _TemplatesAllPageState();
}

/// 价格筛选：全部 / 免费 / 付费
enum PriceFilter {
  all,
  free,
  paid,
}

class _TemplatesAllPageState extends ConsumerState<TemplatesAllPage> {
  String? _selectedType;
  String? _selectedStyle;
  String? _selectedMethod;
  bool _showCustom = false;
  bool _showFavorites = false;
  PriceFilter _priceFilter = PriceFilter.all;
  /// 当前分类的完整路径 segments（根→叶），如 ['food','overhead']。
  ///
  /// 从「一级→二级」独立页进入时，category 参数携带完整父级链路（如
  /// 'food/overhead'），据此过滤模板须以该前缀开头，避免共享叶子 key
  /// （'overhead'/'flat'）导致跨题材误归。为空表示未选择分类（概览视图）。
  List<String> _categoryPath = const [];

  @override
  void initState() {
    super.initState();
    // onLoad: 优先接收 category 参数（可能为完整分类路径 根→叶，如 'food/overhead'）
    final categoryParam = widget.category;
    if (categoryParam != null && categoryParam.isNotEmpty) {
      final segs = categoryParam
          .split('/')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (segs.isNotEmpty) {
        _categoryPath = segs;
        // 叶子段作为当前选择的分类（用于级联查询其子分类）
        _selectedType = segs.last;
      }
    } else {
      // 退而求其次：接收 scene 参数映射到一级分类
      final scene = widget.scene;
      if (scene != null) {
        final cat = sceneToCategoryMap[scene];
        if (cat != null) {
          _categoryPath = [cat];
          _selectedType = cat;
        }
      }
    }
    // 远程模板同步由上游 TemplatesPage（入口页）的 initState 触发，
    // 本页不重复触发，避免在测试环境中因网络调用导致 pumpAndSettle 超时。
    // 同步完成后 DAO 缓存已更新，用户返回并重新进入本页时 FutureBuilder 会重新读取。
  }

  /// 从 DAO 加载全部数据并按当前筛选条件计算过滤后的列表与计数。
  ///
  /// brief 规定：
  /// - _showCustom==true → 只显示 isCustom==true（DAO getCustomOnly + imported）
  /// - _showCustom==false → 只显示 isCustom==false（DAO getBuiltinAndRemote，含内置+远程）
  /// - _selectedType 非空时进一步按 category 过滤
  /// - _selectedStyle 非空时按 classification.style 过滤（v17 修复：原 bug 不生效）
  /// - _selectedMethod 非空时按 classification.method 过滤（v17 修复：原 bug 不生效）
  ///
  /// 计数（allCount / unlockedCount / categoryCounts）始终基于 builtin + remote + custom + imported 全集，
  /// 与原 mock 阶段 `TemplatesBrowseMockData.allTemplates` 行为一致。
  ///
  /// v14: 同时加载分类列表（dao.getCategories），作为分类瀑布流数据源。
  /// v17: 改为加载三级树形分类（level=1 用于概览，level=2/3 用于筛选级联）。
  /// v18 修复：默认视图使用 getBuiltinAndRemote 包含服务器下发的远程模板，
  /// getCustomOnly 严格按 source='custom' 过滤，不再把远程模板误归为自定义。
  Future<_AllPageData> _loadData(
    TemplatesDao dao,
    List<AllTemplateItem> imported,
  ) async {
    final builtinsAndRemotes = await dao.getBuiltinAndRemote();
    final customs = await dao.getCustomOnly();
    // v35: 各模板在本机已拍照片数（模板卡片右下角「已拍 N 张」用）
    final galleryDao = await ref.read(galleryDaoProvider.future);
    final usageCounts = await galleryDao.countByTemplate();
    // v17: 仅加载一级分类用于概览页（level=1, parent_key IS NULL）
    final categories = await dao.getCategories(activeOnly: true, level: 1);
    // v17: 按当前选中状态加载二三级分类选项（级联筛选）
    final styleOptions = _selectedType != null
        ? await dao.getCategoriesByParent(_selectedType!)
        : <TemplateCategoryRecord>[];
    final methodOptions = _selectedStyle != null
        ? await dao.getCategoriesByParent(_selectedStyle!)
        : <TemplateCategoryRecord>[];

    final builtinItems =
        builtinsAndRemotes.map((r) => _recordToItem(r, isCustom: false)).toList();
    final customItems =
        customs.map((r) => _recordToItem(r, isCustom: true)).toList();
    final customWithImported = <AllTemplateItem>[...customItems, ...imported];

    final allItems = <AllTemplateItem>[...builtinItems, ...customWithImported];
    final allCount = allItems.length;
    final unlockedCount = allItems.where((t) => t.price == 0).length;

    // 一级分类卡片计数与筛选同口径：模板完整分类路径以该一级 key 为首段即算。
    // 用前缀匹配（path[0]==c.key 等价于 t.category==c.key），避免共享的下级 key
    // （如某模板分类 path 含 method='macro'）造成跨题材计数误归。
    final categoryCounts = <String, int>{};
    if (categories.isNotEmpty) {
      for (final t in allItems) {
        for (final c in categories) {
          if (t.matchesCategoryPathPrefix([c.key])) {
            categoryCounts[c.key] = (categoryCounts[c.key] ?? 0) + 1;
          }
        }
      }
    }

    // v17 修复筛选 bug：三级级联过滤（原代码仅按 type 过滤，style/method 不生效）。
    // 过滤口径改为「完整分类路径前缀匹配」：把当前已确定的分类链路（根→叶）拼成
    // [prefix]，要求模板的完整分类路径以其为前缀。相比旧「key 在路径任意位置命中」
    //（matchesCategoryPath）的宽匹配，能避免共享 style/method key
    // （如 'overhead'/'flat'）导致跨题材误归：街拍-几何-俯拍 `[street,geometric,overhead]`
    // 不以 `[food, overhead]` 为前缀，不会被「美食→俯拍」误归；
    // 风光-清新-平拍 `[landscape,fresh,flat]` 不以 `[still-life, flat]` 为前缀，
    // 不会被「静物→扁平」误归。
    var filtered = _showCustom ? customWithImported : builtinItems;
    final filterPath = <String>[..._categoryPath];
    if (_selectedStyle != null && !filterPath.contains(_selectedStyle!)) {
      filterPath.add(_selectedStyle!);
    }
    if (_selectedMethod != null && !filterPath.contains(_selectedMethod!)) {
      filterPath.add(_selectedMethod!);
    }
    if (filterPath.isNotEmpty) {
      filtered = filtered
          .where((t) => t.matchesCategoryPathPrefix(filterPath))
          .toList();
    }
    // 价格筛选：免费（price == 0）/ 付费（price > 0）/ 全部
    if (_priceFilter == PriceFilter.free) {
      filtered = filtered.where((t) => t.price == 0).toList();
    } else if (_priceFilter == PriceFilter.paid) {
      filtered = filtered.where((t) => t.price > 0).toList();
    }

    // 收藏过滤：仅保留已收藏模板（与分类、价格、我的 toggle 取交集）
    if (_showFavorites) {
      final favIds = ref.read(favoriteTemplateIdsProvider).valueOrNull;
      if (favIds != null) {
        filtered = filtered.where((t) => favIds.contains(t.id)).toList();
      }
    }

    return _AllPageData(
      allCount: allCount,
      unlockedCount: unlockedCount,
      categoryCounts: categoryCounts,
      usageCounts: usageCounts,
      filtered: filtered,
      categories: categories,
      styleOptions: styleOptions,
      methodOptions: methodOptions,
    );
  }

  void _onLayerSelect(int layer, String? value) {
    setState(() {
      if (layer == 0) {
        // 选 Type：清空 Style + Method（若点击已选 Type 则取消选择）
        _selectedType = (_selectedType == value) ? null : value;
        _selectedStyle = null;
        _selectedMethod = null;
      } else if (layer == 1) {
        _selectedStyle = (_selectedStyle == value) ? null : value;
        _selectedMethod = null;
      } else {
        _selectedMethod = (_selectedMethod == value) ? null : value;
      }
    });
  }

  void _toggleCustom(bool value) {
    setState(() => _showCustom = value);
  }

  void _toggleFavorites(bool value) {
    setState(() => _showFavorites = value);
  }

  void _onPriceFilter(PriceFilter value) {
    setState(() => _priceFilter = value);
  }

  void _goEditor() {
    GoRouter.of(context).push(RouteNames.templatesEditor);
  }

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.of(context).go(RouteNames.templates);
    }
  }

  /// 下拉刷新：重新拉取远程模板/分类并同步到本地，随后重载并重新筛选列表。
  Future<void> _onRefresh() async {
    ref.invalidate(remoteCategoriesSyncProvider);
    ref.invalidate(remoteTemplatesSyncProvider);
    await Future.wait([
      ref.read(remoteCategoriesSyncProvider.future).catchError((_) {}),
      ref.read(remoteTemplatesSyncProvider.future).catchError((_) {}),
    ]);
    // 重新触发 _loadData：FutureBuilder 的 future 在 build 时会重新生成并读取最新 DAO 数据。
    if (mounted) setState(() {});
  }

  void _showImportSheet() {
    TemplateImportSheet.show(
      context,
      onImported: (_) {
        // 导入后自动切换到"我的"视图
        setState(() => _showCustom = true);
      },
    );
  }

  /// 选中某个一级分类，进入二级分类独立页
  void _selectCategory(String category) {
    GoRouter.of(context).push(
      RouteNames.build(
        RouteNames.templatesCategory,
        {RouteNames.paramCategory: category},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    // watch 收藏集合：收藏/取消后重建 future，自动刷新「收藏」过滤列表
    ref.watch(favoriteTemplateIdsProvider);
    // 导入的模板现在持久化到 DAO，不再需要内存 provider
    final importedAll = <AllTemplateItem>[];
    final asyncDao = ref.watch(templatesDaoProvider);
    final isOverview = _selectedType == null;

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          _BackgroundDecoration(tokens: tokens),
          SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: [
                LumiraNav(
                  title: isOverview ? '模板库' : '全部模板',
                  transparent: true,
                  // v4level（spec 2026-08-17-template-category-4level-design.md §6.2）：
                  // 本页通过 push 进入（概览页 / 二级分类独立页 / 带 category 的模板列表），
                  // 返回一律 pop 回上一页；无法 pop 时回退到模板入口页。
                  leading: _BackButton(
                    tokens: tokens,
                    onTap: _back,
                  ),
                  actions: [
                    GestureDetector(
                      onTap: () => GoRouter.of(context).push(
                        RouteNames.withScope(
                            RouteNames.search, SearchScope.template.name),
                      ),
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Icon(Icons.search, size: 20),
                      ),
                    ),
                    _FavoritesButton(
                      tokens: tokens,
                      onTap: () => context.push(RouteNames.templatesFavorites),
                    ),
                  ],
                ),
                Expanded(
                  child: asyncDao.when(
                    loading: () =>
                        Center(child: LumiraProgress.circular()),
                    error: (e, _) => const Center(child: Text('加载失败')),
                    data: (dao) => FutureBuilder<_AllPageData>(
                      future: _loadData(dao, importedAll),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return Center(
                              child: LumiraProgress.circular());
                        }
                        final data = snap.data!;
                        final filtered = data.filtered;
                        return RefreshIndicator(
                          color: tokens.brand,
                          backgroundColor: tokens.surface,
                          onRefresh: _onRefresh,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 32),
                            child: isOverview
                                ? _CategoryOverview(
                                    tokens: tokens,
                                    allCount: data.allCount,
                                    unlockedCount: data.unlockedCount,
                                    categoryCounts: data.categoryCounts,
                                    onSelectCategory: _selectCategory,
                                    categories: data.categories,
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _HeroCard(
                                        tokens: tokens,
                                        allCount: data.allCount,
                                        unlockedCount: data.unlockedCount,
                                      ),
                                      _FilterSection(
                                        tokens: tokens,
                                        categories: data.categories,
                                        styleOptions: data.styleOptions,
                                        methodOptions: data.methodOptions,
                                        selectedType: _selectedType,
                                        selectedStyle: _selectedStyle,
                                        selectedMethod: _selectedMethod,
                                        showCustom: _showCustom,
                                        priceFilter: _priceFilter,
                                        onLayerSelect: _onLayerSelect,
                                        onToggleCustom: _toggleCustom,
                                        onPriceFilter: _onPriceFilter,
                                        showFavorites: _showFavorites,
                                        onToggleFavorites: _toggleFavorites,
                                      ),
                                      if (_showCustom)
                                        _ActionRow(
                                          tokens: tokens,
                                          onImport: _showImportSheet,
                                          onCreate: _goEditor,
                                        ),
                                      if (filtered.isEmpty)
                                        _EmptyState(tokens: tokens)
                                      else
                                        _TemplateGrid(
                                          tokens: tokens,
                                          templates: filtered,
                                          usageCounts: data.usageCounts,
                                        ),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 背景径向渐变装饰（glass 风格 backdrop-filter 可见性）
class _BackgroundDecoration extends StatelessWidget {
  const _BackgroundDecoration({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.6, -0.8),
              radius: 1.4,
              colors: [
                tokens.brandSubtle.withOpacity(0.45),
                tokens.canvas.withOpacity(0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.tokens, required this.onTap});
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Icons.arrow_back_ios_new,
          size: 20,
          color: tokens.textPrimary,
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.tokens,
    required this.allCount,
    required this.unlockedCount,
  });

  final ThemeTokens tokens;
  final int allCount;
  final int unlockedCount;

  @override
  Widget build(BuildContext context) {
    return FadeUp(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: NeuCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.layers_outlined, size: 20, color: tokens.brand),
                  const SizedBox(width: 8),
                  Text(
                    '模板库',
                    style: TextStyle(
                      fontFamily: 'Noto Serif SC',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$allCount 个模板等你探索',
                style: TextStyle(
                  fontSize: 13,
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tokens.brandSubtle,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  '已解锁 $unlockedCount 个',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: tokens.brandText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.tokens,
    required this.categories,
    required this.styleOptions,
    required this.methodOptions,
    required this.selectedType,
    required this.selectedStyle,
    required this.selectedMethod,
    required this.showCustom,
    required this.onToggleCustom,
    required this.showFavorites,
    required this.onToggleFavorites,
    required this.priceFilter,
    required this.onLayerSelect,
    required this.onPriceFilter,
  });

  final ThemeTokens tokens;
  /// v17: 从 sqflite 加载的一级分类（type），替代原硬编码 _typeLabels
  final List<TemplateCategoryRecord> categories;
  /// v17: 当前 selectedType 下的二级分类（style），从 DAO 级联查询
  final List<TemplateCategoryRecord> styleOptions;
  /// v17: 当前 selectedStyle 下的三级分类（method），从 DAO 级联查询
  final List<TemplateCategoryRecord> methodOptions;
  final String? selectedType;
  final String? selectedStyle;
  final String? selectedMethod;
  final bool showCustom;
  /// 价格筛选：全部 / 免费 / 付费
  final PriceFilter priceFilter;
  final void Function(int layer, String? value) onLayerSelect;
  final void Function(bool) onToggleCustom;
  final bool showFavorites;
  final void Function(bool) onToggleFavorites;
  final void Function(PriceFilter) onPriceFilter;

  @override
  Widget build(BuildContext context) {
    // 一级分类（Type pills）不再展示：用户通过「一级 → 二级独立页」进入本页时，
    // category 参数（二级 key）已确定分类范围（spec 2026-08-17-template-category-4level-design.md §6.2）。
    // 此处仅展示该分类下的级联子分类（子风格/方法）pill + "我的" toggle。
    final styleLabels = styleOptions
        .map((c) => LabelValue(c.key, c.name))
        .toList();
    final methodLabels = methodOptions
        .map((c) => LabelValue(c.key, c.name))
        .toList();

    return FadeUp(
      delay: const Duration(milliseconds: 80),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (styleLabels.isNotEmpty)
              _PillRow(
                tokens: tokens,
                options: styleLabels,
                selected: selectedStyle,
                onSelect: (v) => onLayerSelect(1, v),
              ),
            if (methodLabels.isNotEmpty) ...[
              const SizedBox(height: 8),
              _PillRow(
                tokens: tokens,
                options: methodLabels,
                selected: selectedMethod,
                onSelect: (v) => onLayerSelect(2, v),
              ),
            ],
            const SizedBox(height: 12),
            // 免费 / 付费筛选行（默认"全部"）
            _PriceFilterRow(
              tokens: tokens,
              filter: priceFilter,
              onSelect: onPriceFilter,
            ),
            const SizedBox(height: 12),
            // "收藏" + "我的" toggle：过滤已收藏 / 用户自定义模板
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
          ],
        ),
      ),
    );
  }
}

/// 免费 / 付费筛选行
class _PriceFilterRow extends StatelessWidget {
  const _PriceFilterRow({
    required this.tokens,
    required this.filter,
    required this.onSelect,
  });

  final ThemeTokens tokens;
  final PriceFilter filter;
  final void Function(PriceFilter) onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final f in PriceFilter.values) ...[
          _PricePill(
            tokens: tokens,
            label: f == PriceFilter.all
                ? '全部'
                : f == PriceFilter.free
                    ? '免费'
                    : '付费',
            active: filter == f,
            onTap: () => onSelect(f),
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _PricePill extends ConsumerWidget {
  const _PricePill({
    required this.tokens,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final ThemeTokens tokens;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNeumorphic = ref.watch(uiStyleProvider) == UIStyle.neumorphic;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: active
              ? (isNeumorphic
                  ? null
                  : LinearGradient(colors: [tokens.brand, tokens.brandDeep]))
              : null,
          color: active
              ? (isNeumorphic ? tokens.brand : null)
              : tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(9999),
          boxShadow: active
              ? (isNeumorphic ? tokens.shadowConvex : tokens.shadowPressed)
              : tokens.shadowConvexSubtle,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? Colors.white : tokens.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _PillRow extends StatelessWidget {
  const _PillRow({
    required this.tokens,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final ThemeTokens tokens;
  final List<LabelValue> options;
  final String? selected;
  final void Function(String?) onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final opt = options[index];
          final isSelected = selected == opt.value;
          return _Pill(
            tokens: tokens,
            label: opt.label,
            active: isSelected,
            onTap: () => onSelect(opt.value),
          );
        },
      ),
    );
  }
}

class _Pill extends ConsumerWidget {
  const _Pill({
    required this.tokens,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final ThemeTokens tokens;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNeumorphic = ref.watch(uiStyleProvider) == UIStyle.neumorphic;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          // active: linear gradient brand→brandDeep（硬编码颜色，与 uni-app 一致）
          // neumorphic 风格下：移除渐变，激活态用 brand 纯色 + shadowConvex
          gradient: active
              ? (isNeumorphic
                  ? null
                  : LinearGradient(colors: [tokens.brand, tokens.brandDeep]))
              : null,
          color: active
              ? (isNeumorphic ? tokens.brand : null)
              : tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(9999),
          boxShadow: active
              ? (isNeumorphic ? tokens.shadowConvex : tokens.shadowPressed)
              : tokens.shadowConvexSubtle,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? Colors.white : tokens.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNeumorphic = ref.watch(uiStyleProvider) == UIStyle.neumorphic;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          // active: linear gradient brand→brandDeep（硬编码颜色，与 uni-app 一致）
          // neumorphic 风格下：移除渐变，激活态用 brand 纯色 + shadowConvex
          gradient: active
              ? (isNeumorphic
                  ? null
                  : LinearGradient(colors: [tokens.brand, tokens.brandDeep]))
              : null,
          color: active
              ? (isNeumorphic ? tokens.brand : null)
              : tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(9999),
          boxShadow: active
              ? (isNeumorphic ? tokens.shadowConvex : tokens.shadowPressed)
              : tokens.shadowConvexSubtle,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? activeIcon : icon,
              size: 14,
              color: active ? Colors.white : tokens.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? Colors.white : tokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.tokens,
    required this.onImport,
    required this.onCreate,
  });

  final ThemeTokens tokens;
  final VoidCallback onImport;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return FadeUp(
      delay: const Duration(milliseconds: 160),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(
          children: [
            Expanded(
              child: _ActionButton(
                tokens: tokens,
                icon: Icons.download_outlined,
                label: '导入模板',
                onPressed: onImport,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                tokens: tokens,
                icon: Icons.add,
                label: '新建模板',
                primary: true,
                onPressed: onCreate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends ConsumerWidget {
  const _ActionButton({
    required this.tokens,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final ThemeTokens tokens;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNeumorphic = ref.watch(uiStyleProvider) == UIStyle.neumorphic;
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          // primary: linear gradient brand→brandDeep（硬编码颜色，与 uni-app 一致）
          // neumorphic 风格下：移除渐变，主按钮用 brand 纯色 + shadowConvex
          gradient: primary
              ? (isNeumorphic
                  ? null
                  : LinearGradient(colors: [tokens.brand, tokens.brandDeep]))
              : null,
          color: primary
              ? (isNeumorphic ? tokens.brand : null)
              : tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          boxShadow: primary
              ? (isNeumorphic ? tokens.shadowConvex : tokens.shadowConvexBrand)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: primary ? Colors.white : tokens.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: primary ? Colors.white : tokens.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
      child: Column(
        children: [
          Opacity(
            opacity: 0.35,
            child: Icon(
              Icons.search_off,
              size: 60,
              color: tokens.textTertiary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '该分类暂无模板',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '试试切换其他分类或切换回全部',
            style: TextStyle(
              fontSize: 12,
              color: tokens.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateGrid extends StatelessWidget {
  const _TemplateGrid({
    required this.tokens,
    required this.templates,
    required this.usageCounts,
  });

  final ThemeTokens tokens;
  final List<AllTemplateItem> templates;
  final Map<String, int> usageCounts;

  /// 估算单张模板卡片总高度，用于瀑布流双列按高度配平（仅分配用，非精确值）。
  ///
  /// 结构：图(宽×4/3) + 文字区(内边距 24 + 名称 20 + [短描述 3+30] + 间距 6 + 徽标行 22)。
  double _estimateCardHeight(AllTemplateItem t, double cardWidth) {
    final imageH = cardWidth / kDefaultCoverRatio;
    final hasDesc = t.shortDesc.isNotEmpty || t.description.isNotEmpty;
    final textH = 20 + (hasDesc ? 33 : 0) + 6 + 22 + 24;
    return imageH + textH;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 40 - 12) / 2; // 页面左右 padding 20 + 列间距 12

    // 瀑布流双列：按估算高度累加，把下一张卡放到当前更矮的一列，视觉上近似等高收尾。
    final left = <Widget>[];
    final right = <Widget>[];
    var leftH = 0.0;
    var rightH = 0.0;
    for (final t in templates) {
      final card = Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _TplCard(
          tokens: tokens,
          template: t,
          usageCount: usageCounts[t.id] ?? 0,
        ),
      );
      final h = _estimateCardHeight(t, cardWidth);
      if (leftH <= rightH) {
        left.add(card);
        leftH += h;
      } else {
        right.add(card);
        rightH += h;
      }
    }

    return FadeUp(
      delay: const Duration(milliseconds: 160),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right)),
          ],
        ),
      ),
    );
  }
}

class _TplCard extends StatelessWidget {
  const _TplCard({
    required this.tokens,
    required this.template,
    required this.usageCount,
  });

  final ThemeTokens tokens;
  final AllTemplateItem template;
  final int usageCount;

  @override
  Widget build(BuildContext context) {
    final shortDesc = template.shortDesc.isNotEmpty
        ? template.shortDesc
        : _truncate(template.description);
    return GestureDetector(
      onTap: () => GoRouter.of(context).push(
        '/templates/detail?templateId=${template.id}',
      ),
      behavior: HitTestBehavior.opaque,
      child: NeuCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面：真实比例自适应（9:16 温和削减），宽度 100%
            AdaptiveCoverImage(
              cover: template.cover,
              coverData: template.coverData,
              fallback: Container(
                color: tokens.surfaceAlt,
                child: Icon(
                  Icons.photo_outlined,
                  color: tokens.textTertiary,
                  size: 28,
                ),
              ),
              errorFallback: Container(
                color: tokens.surfaceAlt,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: tokens.textTertiary,
                ),
              ),
              overlay: [
                if (template.price == 0)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _FreeBadge(tokens: tokens),
                  )
                else
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _PremiumBadge(
                        tokens: tokens, price: template.price),
                  ),
                // 已拍照片数：叠在封面右下角（半透明深色 pill），
                // 避免占用下方信息行横向空间，导致季节/天气等氛围标签换行变纵向。
                if (usageCount > 0)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.camera_alt_outlined,
                              size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            '已拍 $usageCount 张',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    style: TextStyle(
                      fontFamily: 'Noto Serif SC',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (shortDesc.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      shortDesc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.3,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              TemplatesBrowseMockData.categoryLabel(
                                  template.category),
                              style: TextStyle(
                                fontSize: 11,
                                color: tokens.brand,
                              ),
                            ),
                            if (template.isCustom)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: tokens.brandSubtle,
                                  borderRadius: BorderRadius.circular(9999),
                                ),
                                child: Text(
                                  '自定义',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: tokens.brandText,
                                  ),
                                ),
                              ),
                            AmbienceBadges(
                              ambience: template.ambience,
                              tokens: tokens,
                              maxItems: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FreeBadge extends StatelessWidget {
  const _FreeBadge({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        // 免费徽标绿（色值跟随主题 success 色）
        color: tokens.success.withOpacity(0.85),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: const Text(
        '免费',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge({required this.tokens, required this.price});
  final ThemeTokens tokens;
  final int price;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        // 硬编码颜色，与 uni-app 一致 (gradient brand → brandDeep)
        gradient: LinearGradient(colors: [tokens.brand, tokens.brandDeep]),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        '$price 积分',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// 分类概览：大卡片 + 瀑布流排版展示一级分类
///
/// v14: 数据源从硬编码 7 类改为 DAO [TemplateCategoryRecord] 列表。
/// 图标渲染：iconUrl 非空用 Image.network，为空回退到 [builtinCategoryIcons] 映射。
/// 展示数据（desc/gradient/height）保留在 [_presentationMap] 中按 key 查找，
/// 未命中的分类使用默认展示值。
class _CategoryOverview extends ConsumerWidget {
  const _CategoryOverview({
    required this.tokens,
    required this.allCount,
    required this.unlockedCount,
    required this.categoryCounts,
    required this.onSelectCategory,
    required this.categories,
  });

  final ThemeTokens tokens;
  final int allCount;
  final int unlockedCount;
  final Map<String, int> categoryCounts;
  final void Function(String category) onSelectCategory;
  /// 从 sqflite 加载的分类列表（v14 新增）
  final List<TemplateCategoryRecord> categories;

  /// 分类展示数据（desc / gradient / height）按 key 查找的回退映射。
  ///
  /// 7 个系统分类保留原有视觉规格（gradient 配色 + 高度 + 描述）。
  /// 后端新增的自定义分类未命中此映射时，使用 [_defaultPresentation] 兜底。
  static const Map<String, _CategoryPresentation> _presentationMap = {
    'portrait': _CategoryPresentation(
      desc: '自然光、逆光、氛围感人像',
      gradient: [Color(0xFFE8B4B8), Color(0xFFC97B84)],
      height: 200,
    ),
    'landscape': _CategoryPresentation(
      desc: '黄金时刻、城市天际线',
      gradient: [Color(0xFF8FA06A), Color(0xFF5A7A48)],
      height: 170,
    ),
    'food': _CategoryPresentation(
      desc: '平铺构图、暖色调美食',
      gradient: [Color(0xFFD4A574), Color(0xFFB8860B)],
      height: 190,
    ),
    'street': _CategoryPresentation(
      desc: '黑白街头、都市节奏',
      gradient: [Color(0xFF6B7280), Color(0xFF374151)],
      height: 160,
    ),
    'night': _CategoryPresentation(
      desc: '霓虹灯、城市夜景人像',
      gradient: [Color(0xFF5B6CB5), Color(0xFF2D3561)],
      height: 180,
    ),
    'macro': _CategoryPresentation(
      desc: '花草微距、细节之美',
      gradient: [Color(0xFF7BA87B), Color(0xFF4A7C59)],
      height: 165,
    ),
    'still-life': _CategoryPresentation(
      desc: '室内静物、咖啡馆时光',
      gradient: [Color(0xFFC9A96E), Color(0xFF8B7355)],
      height: 175,
    ),
  };

  static const _CategoryPresentation _defaultPresentation = _CategoryPresentation(
    desc: '探索更多模板',
    gradient: [Color(0xFF9E9E9E), Color(0xFF616161)],
    height: 170,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNeu = ref.watch(uiStyleProvider) == UIStyle.neumorphic;
    // 预取一级分类封面图（限并发暖缓存），加速卡片整卡大图显示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ImageCacheUtil.prefetch(
        categories.map((c) => c.iconUrl).toList(),
      );
    });
    // 瀑布流：两列交替分布
    final left = <Widget>[];
    final right = <Widget>[];
    for (var i = 0; i < categories.length; i++) {
      final cat = categories[i];
      final presentation =
          _presentationMap[cat.key] ?? _defaultPresentation;
      final meta = _TemplateCategoryMeta(
        id: cat.key,
        name: cat.name,
        iconUrl: cat.iconUrl,
        icon: categoryIconForKey(cat.key),
        // 有后端简短描述时优先展示，否则回退内置文案
        desc: cat.description.isNotEmpty ? cat.description : presentation.desc,
        gradient: presentation.gradient,
        height: presentation.height,
      );
      final card = _CategoryCard(
        meta: meta,
        count: categoryCounts[cat.key] ?? 0,
        tokens: tokens,
        onTap: () => onSelectCategory(cat.key),
      );
      if (i % 2 == 0) {
        left.add(card);
      } else {
        right.add(card);
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部摘要
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isNeu ? tokens.surface : null,
              gradient: isNeu
                  ? null
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        tokens.brandSubtle,
                        tokens.brand.withOpacity(0.08)
                      ],
                    ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: isNeu ? tokens.shadowConvex : null,
            ),
            child: Row(
              children: [
                Icon(Icons.layers_outlined, size: 28, color: tokens.brand),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '模板库',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$allCount 个模板等你探索 · 已解锁 $unlockedCount 个',
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '浏览分类',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          // 瀑布流双列
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Column(children: left)),
              const SizedBox(width: 12),
              Expanded(child: Column(children: right)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TemplateCategoryMeta {
  const _TemplateCategoryMeta({
    required this.id,
    required this.name,
    required this.icon,
    required this.desc,
    required this.gradient,
    required this.height,
    this.iconUrl = '',
  });
  final String id;
  final String name;
  /// 后端托管的图标 URL（非空时优先用 Image.network 渲染）
  final String iconUrl;
  /// iconUrl 为空时回退使用的 Material Icon
  final IconData icon;
  final String desc;
  final List<Color> gradient;
  final double height;
}

/// 分类展示数据（不含 id/name/iconUrl，仅视觉规格）
class _CategoryPresentation {
  const _CategoryPresentation({
    required this.desc,
    required this.gradient,
    required this.height,
  });
  final String desc;
  final List<Color> gradient;
  final double height;
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.meta,
    required this.count,
    required this.tokens,
    required this.onTap,
  });
  final _TemplateCategoryMeta meta;
  final int count;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: meta.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: meta.gradient.last.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        // 有封面图：整卡平铺为封面大图；无封面图：保留渐变占位内容
        child: meta.iconUrl.isNotEmpty
            ? _buildCoverStack()
            : _buildGradientStack(),
      ),
    );
  }

  /// 有封面图：封面平铺整卡为背景大图 + 底部渐变遮罩 + 信息叠加
  Widget _buildCoverStack() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 封面大图（加载失败回退为渐变占位 + 分类图标）
        CachedNetworkImage(
          url: meta.iconUrl,
          fit: BoxFit.cover,
          placeholder: _buildGradientLayer(),
          errorWidget: Stack(
            fit: StackFit.expand,
            children: [
              _buildGradientLayer(),
              Center(
                child: Icon(meta.icon, size: 40, color: Colors.white70),
              ),
            ],
          ),
        ),
        // 底部渐变遮罩（提升文字可读性）
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.55),
                  ],
                ),
              ),
            ),
          ),
        ),
        // 信息（底部对齐）
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  meta.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  meta.desc,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.85),
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    '$count 个模板',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 无封面图：渐变背景 + 装饰圆 + 左上角图标 + 信息（占位内容）
  Widget _buildGradientStack() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildGradientLayer(),
        // 装饰圆
        Positioned(
          top: -20,
          right: -15,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
        ),
        // 内容
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(meta.icon, size: 18, color: Colors.white),
              ),
              const Spacer(),
              Text(
                meta.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                meta.desc,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.85),
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  '$count 个模板',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 渐变占位层
  Widget _buildGradientLayer() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: meta.gradient,
        ),
      ),
    );
  }
}

/// 全部模板页加载的数据包（counts + filtered list + categories）
class _AllPageData {
  const _AllPageData({
    required this.allCount,
    required this.unlockedCount,
    required this.categoryCounts,
    required this.usageCounts,
    required this.filtered,
    required this.categories,
    required this.styleOptions,
    required this.methodOptions,
  });

  final int allCount;
  final int unlockedCount;
  final Map<String, int> categoryCounts;
  /// 各模板在本机已拍照片数（卡片右下角「已拍 N 张」用）。
  final Map<String, int> usageCounts;
  final List<AllTemplateItem> filtered;
  /// v14: 从 sqflite template_categories 表加载的一级分类列表
  final List<TemplateCategoryRecord> categories;
  /// v17: 当前 selectedType 下的二级分类（style）选项，selectedType 为空时为空列表
  final List<TemplateCategoryRecord> styleOptions;
  /// v17: 当前 selectedStyle 下的三级分类（method）选项，selectedStyle 为空时为空列表
  final List<TemplateCategoryRecord> methodOptions;
}

/// TemplateRecord → AllTemplateItem 适配
/// DAO 模板数据 → TemplatesAllPage grid 所需类型
///
/// `isCustom` 由调用方根据 `r.isBuiltin` 决定：builtin=false 表示用户自定义模板。
AllTemplateItem _recordToItem(TemplateRecord r, {required bool isCustom}) {
  return AllTemplateItem(
    id: r.id,
    name: r.name,
    category: r.category,
    style: (r.classification['style'] as String?),
    method: (r.classification['method'] as String?),
    // v4level：四级分类扩展字段（spec 2026-08-17-template-category-4level-design.md §4.1）
    majorStyle: (r.classification['majorStyle'] as String?),
    subStyle: (r.classification['subStyle'] as String?),
    coverSeed: r.id,
    cover: r.cover.isEmpty
        ? null
        : TemplateMapper.normalizeAssetUrl(r.cover),
    coverData: r.coverData,
    price: r.price,
    isCustom: isCustom,
    shortDesc: r.shortDesc,
    description: r.description,
    ambience: TemplateMapper.ambienceFromJson(r.ambienceJson),
  );
}

/// 截断长描述到约 [maxLen] 字符并追加省略号（卡片短简介兜底用）。
String _truncate(String s, {int maxLen = 24}) {
  if (s.characters.length <= maxLen) return s;
  return '${s.characters.take(maxLen)}…';
}

/// 收藏入口：从模板一级分类页直接查看收藏的模板。
class _FavoritesButton extends StatelessWidget {
  const _FavoritesButton({required this.tokens, required this.onTap});
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Icons.favorite_border,
          size: 22,
          color: tokens.textPrimary,
        ),
      ),
    );
  }
}
