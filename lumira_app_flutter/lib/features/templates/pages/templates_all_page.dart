import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/dao/templates_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/builtin_category_icons.dart';
import '../data/templates_browse_mock_data.dart';
import '../widgets/template_cover_image.dart';
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

class _TemplatesAllPageState extends ConsumerState<TemplatesAllPage> {
  String? _selectedType;
  String? _selectedStyle;
  String? _selectedMethod;
  bool _showCustom = false;

  @override
  void initState() {
    super.initState();
    // onLoad: 接收 scene 参数映射到 _selectedType
    final scene = widget.scene;
    if (scene != null) {
      final cat = sceneToCategoryMap[scene];
      if (cat != null) _selectedType = cat;
    }
    // 或接收 category 参数直接作为 _selectedType
    if (widget.category != null) {
      _selectedType = widget.category;
    }
  }

  /// 从 DAO 加载全部数据并按当前筛选条件计算过滤后的列表与计数。
  ///
  /// brief 规定：
  /// - _showCustom==true → 只显示 isCustom==true（DAO getCustomOnly + imported）
  /// - _showCustom==false → 只显示 isCustom==false（DAO getBuiltin）
  /// - _selectedType 非空时进一步按 category 过滤
  ///
  /// 计数（allCount / unlockedCount / categoryCounts）始终基于 builtin + custom + imported 全集，
  /// 与原 mock 阶段 `TemplatesBrowseMockData.allTemplates` 行为一致。
  ///
  /// v14: 同时加载分类列表（dao.getCategories），作为分类瀑布流数据源。
  Future<_AllPageData> _loadData(
    TemplatesDao dao,
    List<AllTemplateItem> imported,
  ) async {
    final builtins = await dao.getBuiltin();
    final customs = await dao.getCustomOnly();
    final categories = await dao.getCategories(activeOnly: true);

    final builtinItems =
        builtins.map((r) => _recordToItem(r, isCustom: false)).toList();
    final customItems =
        customs.map((r) => _recordToItem(r, isCustom: true)).toList();
    final customWithImported = <AllTemplateItem>[...customItems, ...imported];

    final allItems = <AllTemplateItem>[...builtinItems, ...customWithImported];
    final allCount = allItems.length;
    final unlockedCount = allItems.where((t) => t.price == 0).length;

    final categoryCounts = <String, int>{};
    for (final t in allItems) {
      categoryCounts[t.category] = (categoryCounts[t.category] ?? 0) + 1;
    }

    final source = _showCustom ? customWithImported : builtinItems;
    final filtered = _selectedType != null
        ? source.where((t) => t.category == _selectedType).toList()
        : source;

    return _AllPageData(
      allCount: allCount,
      unlockedCount: unlockedCount,
      categoryCounts: categoryCounts,
      filtered: filtered,
      categories: categories,
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

  void _showImportSheet() {
    TemplateImportSheet.show(
      context,
      onImported: (_) {
        // 导入后自动切换到"我的"视图
        setState(() => _showCustom = true);
      },
    );
  }

  /// 选中某个一级分类，进入二级分类页面
  void _selectCategory(String category) {
    setState(() {
      _selectedType = category;
      _selectedStyle = null;
      _selectedMethod = null;
    });
  }

  /// 返回分类概览
  void _backToCategories() {
    setState(() {
      _selectedType = null;
      _selectedStyle = null;
      _selectedMethod = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
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
                  leading: _BackButton(
                    tokens: tokens,
                    onTap: isOverview ? _back : _backToCategories,
                  ),
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
                        return SingleChildScrollView(
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
                                      selectedType: _selectedType,
                                      selectedStyle: _selectedStyle,
                                      selectedMethod: _selectedMethod,
                                      showCustom: _showCustom,
                                      onLayerSelect: _onLayerSelect,
                                      onToggleCustom: _toggleCustom,
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
                                      ),
                                  ],
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
    required this.selectedType,
    required this.selectedStyle,
    required this.selectedMethod,
    required this.showCustom,
    required this.onLayerSelect,
    required this.onToggleCustom,
  });

  final ThemeTokens tokens;
  final String? selectedType;
  final String? selectedStyle;
  final String? selectedMethod;
  final bool showCustom;
  final void Function(int layer, String? value) onLayerSelect;
  final void Function(bool) onToggleCustom;

  static const _typeLabels = <LabelValue>[
    LabelValue('portrait', '人像'),
    LabelValue('landscape', '风光'),
    LabelValue('food', '美食'),
    LabelValue('street', '街拍'),
    LabelValue('night', '夜景'),
    LabelValue('macro', '微距'),
    LabelValue('still-life', '静物'),
  ];

  @override
  Widget build(BuildContext context) {
    final styleOptions =
        selectedType != null ? (styleMap[selectedType] ?? <LabelValue>[]) : <LabelValue>[];
    final methodOptions = selectedStyle != null
        ? (methodMap[selectedStyle] ?? <LabelValue>[])
        : <LabelValue>[];

    return FadeUp(
      delay: const Duration(milliseconds: 80),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Layer 0: Type pills
            _PillRow(
              tokens: tokens,
              options: _typeLabels,
              selected: selectedType,
              onSelect: (v) => onLayerSelect(0, v),
            ),
            if (styleOptions.isNotEmpty) ...[
              const SizedBox(height: 8),
              _PillRow(
                tokens: tokens,
                options: styleOptions,
                selected: selectedStyle,
                onSelect: (v) => onLayerSelect(1, v),
              ),
            ],
            if (methodOptions.isNotEmpty) ...[
              const SizedBox(height: 8),
              _PillRow(
                tokens: tokens,
                options: methodOptions,
                selected: selectedMethod,
                onSelect: (v) => onLayerSelect(2, v),
              ),
            ],
            const SizedBox(height: 12),
            // TagSelector 占位 + 我的 toggle
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _TagChip('人像', tokens: tokens),
                        _TagChip('风光', tokens: tokens),
                        _TagChip('美食', tokens: tokens),
                        _TagChip('夜景', tokens: tokens),
                        _TagChip('街拍', tokens: tokens),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _CustomToggle(
                  tokens: tokens,
                  active: showCustom,
                  onTap: () => onToggleCustom(!showCustom),
                ),
              ],
            ),
          ],
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

class _TagChip extends ConsumerWidget {
  const _TagChip(this.label, {required this.tokens});
  final String label;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNeu = ref.watch(uiStyleProvider) == UIStyle.neumorphic;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isNeu ? tokens.surface : tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(9999),
        boxShadow: isNeu ? tokens.shadowConvexSubtle : null,
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: tokens.textTertiary,
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
  });

  final ThemeTokens tokens;
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? Icons.bookmark : Icons.bookmark_border_outlined,
              size: 14,
              color: active ? Colors.white : tokens.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              '我的',
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
  });

  final ThemeTokens tokens;
  final List<AllTemplateItem> templates;

  @override
  Widget build(BuildContext context) {
    return FadeUp(
      delay: const Duration(milliseconds: 160),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            // Forced fix: 0.72 → 0.62 修复 emulator 上 32px 溢出，但在 360dp 小屏上仍会溢出 ~25px
            // 计算小屏（360dp）：card_width=154 → image_h=205 + text_section=53 = 258 > card_h=248（0.62 ratio）
            // 改为 0.56 → card_h=275，留 17dp 文字空间，与 home_page.dart 一致
            childAspectRatio: 0.56,
          ),
          itemCount: templates.length,
          itemBuilder: (_, index) => _TplCard(
            tokens: tokens,
            template: templates[index],
          ),
        ),
      ),
    );
  }
}

class _TplCard extends StatelessWidget {
  const _TplCard({required this.tokens, required this.template});

  final ThemeTokens tokens;
  final AllTemplateItem template;

  @override
  Widget build(BuildContext context) {
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
            // 3:4 aspect ratio image
            AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TemplateCoverImage(
                    cover: template.cover,
                    coverData: template.coverData,
                    fit: BoxFit.cover,
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
                  ),
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
                    style: TextStyle(
                      fontFamily: 'Noto Serif SC',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Forced fix: 原 Row 在 isCustom=true 时溢出 11px（category + 自定义 tag 超宽）。
                  // 改用 Wrap 自动换行避免横向溢出。
                  Wrap(
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
        // 硬编码颜色，与 uni-app 一致 (rgba(90, 122, 72, 0.85))
        color: const Color(0xFF5A7A48).withOpacity(0.85),
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
        '¥$price',
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
        desc: presentation.desc,
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 渐变背景
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: meta.gradient,
                ),
              ),
            ),
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
                    // v14: iconUrl 非空用 Image.network，为空回退到 Material Icon
                    child: meta.iconUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              meta.iconUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                meta.icon,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : Icon(meta.icon, size: 18, color: Colors.white),
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
    required this.filtered,
    required this.categories,
  });

  final int allCount;
  final int unlockedCount;
  final Map<String, int> categoryCounts;
  final List<AllTemplateItem> filtered;
  /// v14: 从 sqflite template_categories 表加载的分类列表
  final List<TemplateCategoryRecord> categories;
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
    coverSeed: r.id,
    cover: r.cover.isEmpty ? null : r.cover,
    coverData: r.coverData,
    price: r.price,
    isCustom: isCustom,
  );
}
