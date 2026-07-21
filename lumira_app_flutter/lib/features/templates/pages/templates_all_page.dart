import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/imported_templates_provider.dart';
import '../data/templates_browse_mock_data.dart';
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
  const TemplatesAllPage({super.key, this.scene});

  final String? scene;

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
  }

  /// mock 阶段简化筛选 — 只按 _selectedType + _showCustom 过滤
  /// brief 明确规定：_showCustom==true 只显示 isCustom==true；false 只显示 isCustom==false
  ///
  /// 注意：导入的模板（来自 importedAllTemplatesProvider）始终合并到 isCustom=true 视图中
  List<AllTemplateItem> _filteredTemplatesWith(
      List<AllTemplateItem> imported) {
    final all = [...TemplatesBrowseMockData.allTemplates, ...imported];
    return all.where((t) {
      if (_showCustom && !t.isCustom) return false;
      if (!_showCustom && t.isCustom) return false;
      if (_selectedType != null && t.category != _selectedType) return false;
      return true;
    }).toList();
  }

  int get _allTemplatesCount => TemplatesBrowseMockData.allTemplates.length;
  int get _unlockedCount =>
      TemplatesBrowseMockData.allTemplates.where((t) => t.price == 0).length;

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

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final importedAll = ref.watch(importedAllTemplatesProvider);
    final filtered = _filteredTemplatesWith(importedAll);

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
                  title: '全部模板',
                  transparent: true,
                  leading: _BackButton(tokens: tokens, onTap: _back),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _HeroCard(
                          tokens: tokens,
                          allCount: _allTemplatesCount,
                          unlockedCount: _unlockedCount,
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

class _TagChip extends StatelessWidget {
  const _TagChip(this.label, {required this.tokens});
  final String label;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(9999),
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
                  Image.network(
                    'https://picsum.photos/seed/${template.coverSeed}/400/600',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
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
