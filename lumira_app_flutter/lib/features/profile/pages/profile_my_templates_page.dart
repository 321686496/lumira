import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/dao/templates_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/number_format.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/effects/pressable_recess.dart';
import '../../../shared/widgets/effects/recessed_surface.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../capture/data/capture_state.dart';
import '../../templates/services/template_exporter.dart';
import '../../templates/services/template_image_store.dart';
import '../../templates/widgets/template_cover_image.dart';
import '../../templates/widgets/template_import_sheet.dart';
import '../../templates/data/templates_providers.dart';
import '../data/profile_content_mock_data.dart';

/// 用户自定义模板列表（is_builtin=0），从 DAO 读取
///
/// Plan A Task A5：替换 `ProfileContentMockData.customTemplates`（deprecated）
/// 作为 My Templates 页的数据源。`TemplatesEditorPage._onSave` 保存模板后
/// 通过 `ref.invalidate(customTemplatesProvider)` 触发刷新。
final customTemplatesProvider = FutureProvider<List<CustomTemplate>>((ref) async {
  final dao = await ref.watch(templatesDaoProvider.future);
  final records = await dao.getCustomOnly();
  return records.map(_recordToCustomTemplate).toList();
});

/// `TemplateRecord` → `CustomTemplate` 映射
///
/// 仅提取 My Templates 页渲染所需字段；usageCount / isFavorite 暂无持久化
/// 字段，按 brief 简化方案置为 0 / false（后续如需追踪使用次数与收藏状态，
/// 应扩展 `TemplateRecord` 而非在此处 hack）。
CustomTemplate _recordToCustomTemplate(TemplateRecord r) {
  return CustomTemplate(
    id: r.id,
    name: r.name,
    coverUrl: r.cover.isEmpty ? null : r.cover,
    coverData: r.coverData,
    category: _stringToCategory(r.category),
    tags: r.tags,
    exposureCompensation: (r.camera['exposureCompensation'] as num?)?.toInt() ?? 0,
    iso: (r.camera['iso'] as num?)?.toInt() ?? 100,
    shutterSpeed: (r.camera['shutterSpeed'] as String?) ?? '1/125',
    usageCount: 0,
    isFavorite: false,
  );
}

TemplateCategory _stringToCategory(String s) {
  switch (s) {
    case 'portrait':
      return TemplateCategory.portrait;
    case 'landscape':
      return TemplateCategory.landscape;
    case 'food':
      return TemplateCategory.food;
    case 'street':
      return TemplateCategory.street;
    case 'night':
      return TemplateCategory.night;
    case 'macro':
      return TemplateCategory.macro;
    case 'still-life':
      return TemplateCategory.stillLife;
    default:
      return TemplateCategory.portrait;
  }
}

/// 我的模板页
///
/// 视觉规格来源：lumira-app/src/pages/profile/my-templates.vue（658 行）
/// 5 个 section + 1 个 ActionSheet：
/// 1. StatsBar（自定义模板数 / 使用次数 / 收藏数）
/// 2. ActionBar（新建模板 / 导入模板）
/// 3. FilterBar（5 个筛选 pills：全部/人像/风光/美食/其他）
/// 4. TplList（自定义模板列表）或 EmptyState
/// 5. ActionSheet（长按模板：编辑/套用/复制/导出/删除）
class ProfileMyTemplatesPage extends ConsumerStatefulWidget {
  const ProfileMyTemplatesPage({super.key});

  @override
  ConsumerState<ProfileMyTemplatesPage> createState() =>
      _ProfileMyTemplatesPageState();
}

enum _FilterKey {
  all,
  portrait,
  landscape,
  food,
  other,
  favorites,
}

class _ProfileMyTemplatesPageState extends ConsumerState<ProfileMyTemplatesPage> {
  _FilterKey _activeFilter = _FilterKey.all;
  bool _actionSheetVisible = false;
  CustomTemplate? _activeTemplate;

  /// 当前激活的模板（用于 ActionSheet 标题）
  CustomTemplate? get _activeTpl => _activeTemplate;

  /// 按 `_activeFilter` 过滤自定义模板
  ///
  /// Plan A Task A5：参数 `customs` 现为 DAO 返回的用户自定义模板列表
  /// （`customTemplatesProvider`），不再合并 `ProfileContentMockData.customTemplates`。
  /// 所有导入的模板（文件/链接/扫码）均持久化到 DAO，当前页面展示 DAO 中
  /// 的全部用户自定义模板（与 brief Step 4 一致）。
  List<CustomTemplate> _filteredTemplatesWith(
    List<CustomTemplate> customs,
    Set<String> favIds,
  ) {
    final all = customs;
    switch (_activeFilter) {
      case _FilterKey.all:
        return all;
      case _FilterKey.portrait:
        return all.where((t) => t.category == TemplateCategory.portrait).toList();
      case _FilterKey.landscape:
        return all.where((t) => t.category == TemplateCategory.landscape).toList();
      case _FilterKey.food:
        return all.where((t) => t.category == TemplateCategory.food).toList();
      case _FilterKey.other:
        // 其他 = 除 portrait/landscape/food 之外的所有分类（street/night/macro/stillLife）
        return all.where((t) {
          switch (t.category) {
            case TemplateCategory.portrait:
            case TemplateCategory.landscape:
            case TemplateCategory.food:
              return false;
            case TemplateCategory.street:
            case TemplateCategory.night:
            case TemplateCategory.macro:
            case TemplateCategory.stillLife:
              return true;
          }
        }).toList();
      case _FilterKey.favorites:
        // 收藏筛选：仅显示已收藏的自定义模板（favIds 来自 template_favorites）
        return all.where((t) => favIds.contains(t.id)).toList();
    }
  }

  void _openActionSheet(CustomTemplate tpl) {
    setState(() {
      _activeTemplate = tpl;
      _actionSheetVisible = true;
    });
  }

  void _closeActionSheet() {
    setState(() {
      _actionSheetVisible = false;
    });
  }

  void _showSnack(String msg) {
    LumiraToast.show(context, msg, duration: const Duration(milliseconds: 1000));
  }

  void _handleActionEdit(CustomTemplate tpl) {
    _closeActionSheet();
    GoRouter.of(context).push(
      RouteNames.withTemplateId(RouteNames.templatesEditor, tpl.id),
    );
  }

  void _handleActionApply(CustomTemplate tpl) {
    _closeActionSheet();
    GoRouter.of(context).push(
      RouteNames.withTemplateId(RouteNames.capture, tpl.id),
    );
  }

  void _handleActionDuplicate() {
    _closeActionSheet();
    _showSnack('已复制');
  }

  void _handleActionExport(CustomTemplate tpl) {
    _closeActionSheet();
    _exportTemplate(tpl);
  }

  /// 导出模板：先从 DAO 加载 TemplateRecord，再弹出格式选择 Sheet
  Future<void> _exportTemplate(CustomTemplate tpl) async {
    try {
      final dao = await ref.read(templatesDaoProvider.future);
      final record = await dao.getById(tpl.id);

      if (record == null) {
        // 自定义模板可能尚未持久化（来自 mock），构造一个最小 record
        _showSnack('模板未持久化，请先保存到我的模板');
        return;
      }

      if (!mounted) return;
      await _showExportFormatSheet(record);
    } catch (e) {
      _showSnack('导出失败：$e');
    }
  }

  Future<void> _showExportFormatSheet(TemplateRecord record) async {
    final tokens = ref.watch(themeTokensProvider);
    final result = await showLumiraBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              '选择导出格式',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
          ),
          LumiraListTile(
            leading: Icon(Icons.description_outlined, color: tokens.brand),
            title: const Text('完整 .pptpl（推荐）'),
            subtitle: const Text('含构图/姿势/相机/场景/后期全参数'),
            onTap: () => Navigator.pop(ctx, 'pptpl'),
          ),
          LumiraListTile(
            leading: Icon(Icons.code_outlined, color: tokens.brand),
            title: const Text('简化 .lumira'),
            subtitle: const Text('仅元信息+相机核心参数'),
            onTap: () => Navigator.pop(ctx, 'lumira'),
          ),
          LumiraListTile(
            title: Center(
              child: Text('取消',
                  style: TextStyle(color: tokens.textSecondary)),
            ),
            onTap: () => Navigator.pop(ctx, null),
          ),
        ],
      ),
    );

    if (result == null) return;
    if (!mounted) return;

    final usePptpl = result == 'pptpl';
    LumiraToast.show(context, '正在导出 ${record.name}...');

    try {
      final filePath = await TemplateExporter.exportToTempFile(record, usePptpl: usePptpl);
      if (!mounted) return;
      
      context.push(
        RouteNames.templatesExportDetail,
        extra: {
          'filePath': filePath,
          'templateName': record.name,
          'usePptpl': usePptpl,
        },
      );
    } catch (e) {
      if (!mounted) return;
      LumiraToast.show(context, '导出失败：$e');
    }
  }

  Future<void> _handleActionDelete() async {
    final tpl = _activeTpl;
    _closeActionSheet();
    if (tpl == null) return;
    try {
      final dao = await ref.read(templatesDaoProvider.future);
      await dao.delete(tpl.id);
      // 清理模板图片目录（删除文件失败不阻塞"已删除"提示，包在独立 try/catch）
      try {
        await TemplateImageStore.deleteAll(tpl.id);
      } catch (e) {
        debugPrint('[MyTemplates] delete images failed for ${tpl.id}: $e');
      }
      ref.invalidate(customTemplatesProvider);
      // 刷新 Capture 页模板缓存（系统 + 自定义），使删除立即反映
      ref.invalidate(CaptureState.allTemplatesProvider);
      _showSnack('已删除');
    } catch (e) {
      _showSnack('删除失败：$e');
    }
  }

  void _showImportSheet() {
    TemplateImportSheet.show(
      context,
      onImported: (_) {
        // 导入后切换到"全部"以确保新模板可见
        setState(() => _activeFilter = _FilterKey.all);
        // 关键：customTemplatesProvider 是缓存的 FutureProvider，
        // 必须 invalidate 才会重新查询 DAO，否则列表仍是旧数据
        ref.invalidate(customTemplatesProvider);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final customAsync = ref.watch(customTemplatesProvider);
    // watch 收藏集：收藏/取消后重建列表，「收藏」筛选与顶部收藏数实时更新
    final favoriteAsync = ref.watch(favoriteTemplateIdsProvider);
    final favoriteIds = favoriteAsync.valueOrNull ?? const <String>{};
    final filtered = customAsync.when(
      loading: () => const <CustomTemplate>[],
      error: (_, __) => const <CustomTemplate>[],
      data: (customs) => _filteredTemplatesWith(customs, favoriteIds),
    );

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '我的模板',
        transparent: true,
        leading: _BackButton(tokens: tokens),
        actions: [
          _ImportButton(tokens: tokens, onTap: _showImportSheet),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.8, -0.6),
                radius: 1.2,
                colors: [
                  tokens.brandSubtle.withOpacity(0.35),
                  tokens.canvas.withOpacity(0.0),
                ],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StatsBar(
                      tokens: tokens,
                      totalCount: filtered.length,
                      // Plan A Task A5：usageCount 暂未持久化到 DAO，
                      // 按 brief 简化方案置为 0（后续扩展 TemplateRecord 时再恢复）
                      totalUsage: 0,
                      favoriteCount: favoriteIds.length,
                      onFavoriteTap: () => GoRouter.of(context)
                          .push(RouteNames.templatesFavorites),
                    ),
                    _ActionBar(tokens: tokens, onImport: _showImportSheet),
                    _FilterBar(
                      tokens: tokens,
                      activeFilter: _activeFilter,
                      onSelect: (f) => setState(() => _activeFilter = f),
                    ),
                    if (filtered.isNotEmpty)
                      _TplList(
                        tokens: tokens,
                        templates: filtered,
                        onTap: (tpl) => GoRouter.of(context).push(
                          RouteNames.withTemplateId(RouteNames.templatesDetail, tpl.id),
                        ),
                        onLongPress: _openActionSheet,
                        onApply: (tpl) => GoRouter.of(context).push(
                          RouteNames.withTemplateId(RouteNames.capture, tpl.id),
                        ),
                        onEdit: (tpl) => GoRouter.of(context).push(
                          RouteNames.withTemplateId(RouteNames.templatesEditor, tpl.id),
                        ),
                      )
                    else
                      _EmptyState(tokens: tokens),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          if (_actionSheetVisible && _activeTpl != null)
            _ActionSheet(
              tokens: tokens,
              template: _activeTpl!,
              onClose: _closeActionSheet,
              onEdit: _handleActionEdit,
              onApply: _handleActionApply,
              onDuplicate: _handleActionDuplicate,
              onExport: _handleActionExport,
              onDelete: _handleActionDelete,
            ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context);
        } else {
          GoRouter.of(context).go(RouteNames.profile);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(Icons.arrow_back_ios_new, size: 20, color: tokens.textPrimary),
      ),
    );
  }
}

class _ImportButton extends StatelessWidget {
  const _ImportButton({required this.tokens, required this.onTap});
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableRecess(
      onTap: onTap,
      borderRadius: 24,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Icons.download_outlined,
          size: 22,
          color: tokens.textPrimary,
        ),
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({
    required this.tokens,
    required this.totalCount,
    required this.totalUsage,
    required this.favoriteCount,
    this.onFavoriteTap,
  });
  final ThemeTokens tokens;
  final int totalCount;
  final int totalUsage;
  final int favoriteCount;
  /// 「收藏」数可点击进入「我的收藏」页；为空则不响应点击。
  final VoidCallback? onFavoriteTap;

  Widget _statItem(String num, String label, {VoidCallback? onTap}) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          num,
          style: TextStyle(
            fontFamily: 'Noto Serif SC',
            fontSize: 24, // 48rpx → 24dp
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11, // 22rpx → 11dp
            color: tokens.textTertiary,
            letterSpacing: 0.04 * 11,
          ),
        ),
      ],
    );
    if (onTap == null) return content;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }

  Widget _divider() {
    return Container(
      width: 0.5,
      height: 28, // 56rpx → 28dp
      color: tokens.divider,
    );
  }

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0), // 40rpx/24rpx/0 → 20/12/0
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18), // 32rpx/36rpx → 16/18dp
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('$totalCount', '自定义模板'),
          _divider(),
          // 4+ 位数必须用 formatThousands
          _statItem(formatThousands(totalUsage), '使用次数'),
          _divider(),
          _statItem('$favoriteCount', '收藏', onTap: onFavoriteTap),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.tokens, required this.onImport});
  final ThemeTokens tokens;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), // 40rpx/32rpx/0 → 20/16/0
      child: Row(
        children: [
          Expanded(
            child: LumiraButton(
              variant: ButtonVariant.primary,
              // 主色 CTA：按下保持品牌色（加深+扁平化+缩小），不切凹陷表面
              keepBrandOnPress: true,
              onPressed: () => GoRouter.of(context).push(RouteNames.templatesEditor),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.add, size: 18),
                  SizedBox(width: 8),
                  Text('新建模板'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10), // 20rpx → 10dp gap
          Expanded(
            child: LumiraButton(
              variant: ButtonVariant.ghost,
              onPressed: onImport,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.download_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('导入模板'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.tokens,
    required this.activeFilter,
    required this.onSelect,
  });

  final ThemeTokens tokens;
  final _FilterKey activeFilter;
  final void Function(_FilterKey) onSelect;

  static const _filters = <_FilterConfig>[
    _FilterConfig(key: _FilterKey.all, label: '全部'),
    _FilterConfig(key: _FilterKey.portrait, label: '人像'),
    _FilterConfig(key: _FilterKey.landscape, label: '风光'),
    _FilterConfig(key: _FilterKey.food, label: '美食'),
    _FilterConfig(key: _FilterKey.other, label: '其他'),
    _FilterConfig(key: _FilterKey.favorites, label: '收藏'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4), // 40rpx/32rpx/8rpx → 20/16/4dp
      child: Row(
        children: [
          for (var i = 0; i < _filters.length; i++) ...[
            if (i > 0) const SizedBox(width: 8), // 16rpx → 8dp
            _FilterPill(
              tokens: tokens,
              label: _filters[i].label,
              active: _filters[i].key == activeFilter,
              onTap: () => onSelect(_filters[i].key),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterConfig {
  const _FilterConfig({required this.key, required this.label});
  final _FilterKey key;
  final String label;
}

class _FilterPill extends ConsumerStatefulWidget {
  const _FilterPill({
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
  ConsumerState<_FilterPill> createState() => _FilterPillState();
}

class _FilterPillState extends ConsumerState<_FilterPill> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final isNeu = ref.watch(appThemeProvider).style == UIStyle.neumorphic;
    // 新拟态：选中/按压态 = 凹陷表面（上/左暗、下/右亮、中心平底）；
    // 其余 UI 风格沿用品牌渐变选中态。
    final recessed = isNeu && (widget.active || _pressed);

    const pad = EdgeInsets.symmetric(horizontal: 16, vertical: 8); // 32rpx/16rpx → 16/8dp

    final Widget pill;
    if (recessed) {
      pill = RecessedSurface(
        tokens: tokens,
        borderRadius: 999,
        depth: 0.7,
        rimFraction: 0.34,
        child: Padding(
          padding: pad,
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: widget.active ? FontWeight.w500 : FontWeight.w400,
              color:
                  widget.active ? tokens.textPrimary : tokens.textSecondary,
            ),
          ),
        ),
      );
    } else {
      pill = AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: pad,
        decoration: BoxDecoration(
          // active: linear gradient brand→brandDeep（硬编码颜色，与 uni-app 一致）
          gradient: widget.active
              ? LinearGradient(colors: [tokens.brand, tokens.brandDeep])
              : null,
          color: widget.active ? null : tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(9999),
          boxShadow: widget.active
              ? const []
              : tokens.shadowConvexSubtle,
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: widget.active ? FontWeight.w500 : FontWeight.w400,
            color: widget.active ? Colors.white : tokens.textSecondary,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: _pressed ? 0.94 : 1.0),
        duration: Duration(milliseconds: _pressed ? 140 : 260),
        curve: _pressed ? Curves.easeIn : Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: pill,
      ),
    );
  }
}

class _TplList extends StatelessWidget {
  const _TplList({
    required this.tokens,
    required this.templates,
    required this.onTap,
    required this.onLongPress,
    required this.onApply,
    required this.onEdit,
  });

  final ThemeTokens tokens;
  final List<CustomTemplate> templates;
  final void Function(CustomTemplate) onTap;
  final void Function(CustomTemplate) onLongPress;
  final void Function(CustomTemplate) onApply;
  final void Function(CustomTemplate) onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), // 40rpx/24rpx/48rpx → 20/12/24dp
      child: Column(
        children: [
          for (var i = 0; i < templates.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _TplRow(
              tokens: tokens,
              template: templates[i],
              onTap: () => onTap(templates[i]),
              onLongPress: () => onLongPress(templates[i]),
              onApply: () => onApply(templates[i]),
              onEdit: () => onEdit(templates[i]),
            ),
          ],
        ],
      ),
    );
  }
}

String _categoryLabel(TemplateCategory c) {
  switch (c) {
    case TemplateCategory.portrait:
      return '人像';
    case TemplateCategory.landscape:
      return '风光';
    case TemplateCategory.food:
      return '美食';
    case TemplateCategory.street:
      return '街拍';
    case TemplateCategory.night:
      return '夜景';
    case TemplateCategory.macro:
      return '微距';
    case TemplateCategory.stillLife:
      return '静物';
  }
}

class _TplRow extends StatelessWidget {
  const _TplRow({
    required this.tokens,
    required this.template,
    required this.onTap,
    required this.onLongPress,
    required this.onApply,
    required this.onEdit,
  });

  final ThemeTokens tokens;
  final CustomTemplate template;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onApply;
  final VoidCallback onEdit;

  String get _evText {
    final ev = template.exposureCompensation;
    if (ev > 0) return '+$ev EV';
    return '$ev EV';
  }

  @override
  Widget build(BuildContext context) {
    final t = template;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: NeuCard(
        padding: const EdgeInsets.all(12), // 24rpx → 12dp
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TplCoverWrap
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10), // 20rpx → 10dp
                  child: SizedBox(
                    width: 100, // 200rpx → 100dp
                    height: 100,
                    child: TemplateCoverImage(
                      cover: t.coverUrl,
                      coverData: t.coverData,
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
                  ),
                ),
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), // 14rpx/4rpx → 7/2dp
                    decoration: BoxDecoration(
                      // 硬编码颜色，与 uni-app 一致 (rgba(0,0,0,0.55))
                      color: const Color(0x8C000000),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text(
                      _categoryLabel(t.category),
                      style: const TextStyle(
                        fontSize: 10, // 20rpx → 10dp
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // TplContent
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t.name,
                    style: TextStyle(
                      fontFamily: 'Noto Serif SC',
                      fontSize: 15, // 30rpx → 15dp
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // TplTags: tags.slice(0, 3)
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final tag in t.tags.take(3))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: tokens.brandSubtle,
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 10, // 20rpx → 10dp
                              color: tokens.brandText,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // TplParamSummary
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _ParamItem(text: _evText, tokens: tokens),
                      _ParamItem(text: '${t.iso} ISO', tokens: tokens),
                      _ParamItem(text: t.shutterSpeed, tokens: tokens),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // TplActions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _ApplyBtn(tokens: tokens, onTap: onApply),
                      const SizedBox(width: 8),
                      _EditBtn(tokens: tokens, onTap: onEdit),
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

class _ParamItem extends StatelessWidget {
  const _ParamItem({required this.text, required this.tokens});
  final String text;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11, // 22rpx → 11dp
        color: tokens.textTertiary,
        fontFamily: 'Courier New',
      ),
    );
  }
}

class _ApplyBtn extends StatelessWidget {
  const _ApplyBtn({required this.tokens, required this.onTap});
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // 24rpx/12rpx → 12/6dp
        decoration: BoxDecoration(
          // 硬编码颜色，与 uni-app 一致 (gradient brand → brandDeep)
          gradient: LinearGradient(colors: [tokens.brand, tokens.brandDeep]),
          borderRadius: BorderRadius.circular(9999),
          boxShadow: tokens.shadowConvexBrand,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.camera_alt_outlined, size: 14, color: Colors.white),
            SizedBox(width: 4),
            Text(
              '拍摄',
              style: TextStyle(
                fontSize: 12, // 24rpx → 12dp
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditBtn extends StatelessWidget {
  const _EditBtn({required this.tokens, required this.onTap});
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
          color: tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(9999),
          boxShadow: tokens.shadowConvexSubtle,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_outlined, size: 14, color: tokens.textSecondary),
            const SizedBox(width: 4),
            Text(
              '编辑',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: tokens.textSecondary,
              ),
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
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 24), // 40rpx/80rpx/48rpx → 20/40/24dp
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Opacity(
            opacity: 0.35,
            child: Icon(
              Icons.layers_outlined, // ph-stack
              size: 60, // 120rpx → 60dp
              color: tokens.textTertiary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '还没有自定义模板',
            style: TextStyle(
              fontFamily: 'Noto Serif SC',
              fontSize: 16, // 32rpx → 16dp
              fontWeight: FontWeight.w600,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '创建你的第一个模板，或从 .pptpl 文件导入',
            style: TextStyle(
              fontSize: 12, // 24rpx → 12dp
              color: tokens.textTertiary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          LumiraButton(
            variant: ButtonVariant.primary,
            // 主色 CTA：按下保持品牌色，不切凹陷表面
            keepBrandOnPress: true,
            onPressed: () => GoRouter.of(context).push(RouteNames.templatesEditor),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.add, size: 18),
                SizedBox(width: 8),
                Text('创建模板'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionSheet extends StatelessWidget {
  const _ActionSheet({
    required this.tokens,
    required this.template,
    required this.onClose,
    required this.onEdit,
    required this.onApply,
    required this.onDuplicate,
    required this.onExport,
    required this.onDelete,
  });

  final ThemeTokens tokens;
  final CustomTemplate template;
  final VoidCallback onClose;
  final void Function(CustomTemplate) onEdit;
  final void Function(CustomTemplate) onApply;
  final VoidCallback onDuplicate;
  final void Function(CustomTemplate) onExport;
  final VoidCallback onDelete;

  Widget _item({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), // 40rpx/28rpx → 20/14dp
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? tokens.textSecondary),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15, // 30rpx → 15dp
                color: textColor ?? tokens.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Mask
        GestureDetector(
          onTap: onClose,
          behavior: HitTestBehavior.opaque,
          child: Container(
            // 硬编码颜色，与 uni-app 一致 (rgba(0,0,0,0.5))
            color: const Color(0x80000000),
          ),
        ),
        // Sheet
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), // 32rpx → 16dp
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8), // 40rpx/24rpx/16rpx → 20/12/8dp
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: tokens.divider, width: 0.5),
                      ),
                    ),
                    child: Text(
                      template.name,
                      style: TextStyle(
                        fontFamily: 'Noto Serif SC',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _item(
                    icon: Icons.edit_outlined,
                    label: '编辑模板',
                    onTap: () => onEdit(template),
                  ),
                  _item(
                    icon: Icons.camera_alt_outlined,
                    label: '套用拍摄',
                    onTap: () => onApply(template),
                  ),
                  _item(
                    icon: Icons.copy_outlined,
                    label: '复制模板',
                    onTap: onDuplicate,
                  ),
                  _item(
                    icon: Icons.ios_share_outlined,
                    label: '导出模板',
                    onTap: () => onExport(template),
                  ),
                  _item(
                    icon: Icons.delete_outline,
                    label: '删除模板',
                    onTap: onDelete,
                    iconColor: tokens.danger,
                    textColor: tokens.danger,
                  ),
                  // Cancel
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: tokens.surfaceAlt,
                      borderRadius: BorderRadius.circular(10), // 20rpx → 10dp
                    ),
                    child: Center(
                      child: GestureDetector(
                        onTap: onClose,
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          '取消',
                          style: TextStyle(
                            fontSize: 15, // 30rpx → 15dp
                            fontWeight: FontWeight.w500,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
