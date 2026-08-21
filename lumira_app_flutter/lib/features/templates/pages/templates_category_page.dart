import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lumira_app_flutter/core/utils/image_cache.dart';

import '../../../core/db/dao/templates_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/effects/breathing_tap.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/builtin_category_icons.dart';
import '../data/remote_templates_providers.dart';

/// 二级分类独立页
///
/// 视觉规格来源：spec 2026-08-17-template-category-4level-design.md §6.1
///
/// 固定两级钻取的第一层：进入某题材（一级分类）后，展示该题材的
/// **直接子分类**（大风格 / 浅层风格）卡片，封面用 [TemplateCategoryRecord.iconUrl]。
///
/// - 分类数据来自已扁平同步到 sqflite 的远程分类表（已有 `level/parentKey/iconUrl`），
///   按 `parentKey === 题材.key` 过滤（[TemplatesDao.getCategoriesByParent]）。
/// - 点击某个二级分类 → 跳转 `TemplatesAllPage(category=该二级key)`，
///   模板列表按该二级分类的子树 key 集合过滤（见 spec §6.3）。
class TemplatesCategoryPage extends ConsumerStatefulWidget {
  const TemplatesCategoryPage({super.key, this.category});

  /// 一级分类 key（题材，如 portrait），来自 `templatesAll` 概览导航传入
  final String? category;

  @override
  ConsumerState<TemplatesCategoryPage> createState() =>
      _TemplatesCategoryPageState();
}

class _TemplatesCategoryPageState extends ConsumerState<TemplatesCategoryPage> {
  /// 题材名称（用于导航栏标题与页头），从分类表按 key 读取
  String _typeName = '分类';
  /// 题材简短描述（可空，来自后端），用于页头副标题
  String _typeDesc = '';

  @override
  void initState() {
    super.initState();
    _resolveTypeName();
  }

  /// 从 sqflite 读取题材名称与简短描述（level=1 且 key 匹配）。
  /// 标题在 data 加载前先用 key 兜底，加载完成后刷新。
  Future<void> _resolveTypeName() async {
    final dao = await ref.read(templatesDaoProvider.future);
    final cats = await dao.getCategories(activeOnly: true, level: 1);
    for (final c in cats) {
      if (c.key == widget.category) {
        if (mounted) {
          setState(() {
            _typeName = c.name;
            _typeDesc = c.description;
          });
        }
        return;
      }
    }
  }

  void _goTemplates(String categoryKey) {
    GoRouter.of(context).push(
      RouteNames.build(
        RouteNames.templatesAll,
        {RouteNames.paramCategory: categoryKey},
      ),
    );
  }

  /// 下拉刷新：重新拉取远程分类/模板并同步到本地，随后重载当前分类下的子分类。
  Future<void> _onRefresh() async {
    ref.invalidate(remoteCategoriesSyncProvider);
    ref.invalidate(remoteTemplatesSyncProvider);
    await Future.wait([
      ref.read(remoteCategoriesSyncProvider.future).catchError((_) {}),
      ref.read(remoteTemplatesSyncProvider.future).catchError((_) {}),
    ]);
    // 重新触发 FutureBuilder + 刷新题材名称兜底。
    if (mounted) {
      setState(() {});
      _resolveTypeName();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final asyncDao = ref.watch(templatesDaoProvider);
    final typeKey = widget.category;

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
                  title: _typeName,
                  transparent: true,
                  leading: _BackButton(
                    tokens: tokens,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: tokens.brand,
                    backgroundColor: tokens.surface,
                    onRefresh: _onRefresh,
                    child: asyncDao.when(
                      loading: () => Center(child: LumiraProgress.circular()),
                      error: (e, _) => const Center(child: Text('加载失败')),
                      data: (dao) => FutureBuilder<List<TemplateCategoryRecord>>(
                        future: dao.getCategoriesByParent(typeKey ?? ''),
                        builder: (context, snap) {
                          if (!snap.hasData) {
                            return Center(child: LumiraProgress.circular());
                          }
                          final children = snap.data!;
                          if (children.isEmpty) {
                            // 浅层题材：无二级分类，直接提供进入模板列表入口
                            return _ShallowFallback(
                              tokens: tokens,
                              onTap: () => _goTemplates(typeKey!),
                            );
                          }
                          return _SubCategoryGrid(
                            tokens: tokens,
                            typeName: _typeName,
                            typeDesc: _typeDesc,
                            categories: children,
                            onTap: _goTemplates,
                          );
                        },
                      ),
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

/// 背景径向渐变装饰（glass 风格 backdrop-filter 可见性，与 TemplatesAllPage 一致）
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

/// 二级分类卡片网格
///
/// 展示一级分类下的直接子分类（大风格 / 浅层风格），封面用 iconUrl
/// （非空用 Image.network，为空回退 Material Icon 映射）。
class _SubCategoryGrid extends ConsumerWidget {
  const _SubCategoryGrid({
    required this.tokens,
    required this.typeName,
    required this.typeDesc,
    required this.categories,
    required this.onTap,
  });

  final ThemeTokens tokens;
  final String typeName;
  final String typeDesc;
  final List<TemplateCategoryRecord> categories;
  final void Function(String categoryKey) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNeu = ref.watch(uiStyleProvider) == UIStyle.neumorphic;
    final daoAsync = ref.watch(templatesDaoProvider);
    final subKeys = categories.map((c) => c.key).toList();

    // 预取二级分类封面图（限并发暖缓存），加速卡片封面显示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ImageCacheUtil.prefetch(
        categories.map((c) => c.iconUrl).toList(),
      );
    });

    return daoAsync.when(
      loading: () =>
          Center(child: LumiraProgress.circular()),
      error: (e, _) => Center(child: Text('加载失败', style: TextStyle(color: tokens.textTertiary))),
      data: (dao) => FutureBuilder<Map<String, int>>(
        future: dao.countTemplatesBySubtree(subKeys),
        builder: (context, snap) {
          final counts = snap.data ?? const <String, int>{};
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(), // 支持下拉刷新
            padding: const EdgeInsets.only(bottom: 32),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                                typeName,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                // 有后端简短描述时展示，否则回退默认文案
                                typeDesc.isNotEmpty ? typeDesc : '选择一个子分类继续',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: tokens.textSecondary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: _buildColumn(0, counts),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: _buildColumn(1, counts),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 按列分隔构建二级分类卡片，偶数索引在左列、奇数在右列。
  List<Widget> _buildColumn(int offset, Map<String, int> counts) {
    final list = <Widget>[];
    for (var i = offset; i < categories.length; i += 2) {
      final cat = categories[i];
      list.add(
        _SubCategoryCard(
          tokens: tokens,
          record: cat,
          templateCount: counts[cat.key] ?? 0,
          onTap: () => onTap(cat.key),
        ),
      );
    }
    return list;
  }
}

/// 单个二级分类卡片
///
/// 封面：iconUrl 非空用 Image.network 展示（二级封面图），
/// 为空回退到 [categoryIconForKey] Material Icon。
class _SubCategoryCard extends ConsumerWidget {
  const _SubCategoryCard({
    required this.tokens,
    required this.record,
    required this.templateCount,
    required this.onTap,
  });

  final ThemeTokens tokens;
  final TemplateCategoryRecord record;
  /// 该二级分类子树（含三级）下的模板数量
  final int templateCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallbackIcon = categoryIconForKey(record.key);
    final appTheme = ref.watch(appThemeProvider);
    return BreathingTap(
      onTap: onTap,
      pressedScale: appTheme.style == UIStyle.female ? 0.96 : 0.98,
      child: FadeUp(
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: NeuCard(
            padding: EdgeInsets.zero,
            // 有封面图：整卡平铺为封面大图；无封面图：保留原占位内容
            child: record.iconUrl.isNotEmpty
                ? _buildCoverCard(fallbackIcon)
                : _buildPlaceholderCard(fallbackIcon),
          ),
        ),
      ),
    );
  }

  /// 有封面图：封面平铺整卡为背景大图 + 底部渐变遮罩 + 信息叠加
  Widget _buildCoverCard(IconData fallbackIcon) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 封面大图
          CachedNetworkImage(
            url: record.iconUrl,
            fit: BoxFit.cover,
            placeholder: ColoredBox(color: tokens.surfaceAlt),
            errorWidget: Container(
              color: tokens.surfaceAlt,
              child: Icon(
                fallbackIcon,
                size: 40,
                color: tokens.textTertiary,
              ),
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
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          record.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$templateCount 套模板',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.85),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 无封面图：3:4 图标占位 + 名称/数量信息（占位内容）
  Widget _buildPlaceholderCard(IconData fallbackIcon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: Container(
            color: tokens.surfaceAlt,
            child: Icon(
              fallbackIcon,
              size: 40,
              color: tokens.textTertiary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.name,
                      style: TextStyle(
                        fontFamily: 'Noto Serif SC',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$templateCount 套模板',
                      style: TextStyle(
                        fontSize: 11,
                        color: tokens.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: tokens.textTertiary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 浅层题材兜底视图：题材下无二级分类时，提供直接进入模板列表的入口
class _ShallowFallback extends ConsumerWidget {
  const _ShallowFallback({required this.tokens, required this.onTap});

  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: 0.35,
              child: Icon(
                Icons.category_outlined,
                size: 60,
                color: tokens.textTertiary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '该题材暂无子分类',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '可直接查看该题材下的全部模板',
              style: TextStyle(
                fontSize: 12,
                color: tokens.textTertiary,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient:
                      LinearGradient(colors: [tokens.brand, tokens.brandDeep]),
                  borderRadius: BorderRadius.circular(9999),
                  boxShadow: tokens.shadowConvexBrand,
                ),
                child: const Text(
                  '查看全部模板',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
