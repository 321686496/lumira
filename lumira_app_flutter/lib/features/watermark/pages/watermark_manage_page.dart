import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/lumira/buttons/lumira_button.dart';
import '../../../shared/widgets/lumira/buttons/lumira_icon_button.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/watermark_providers.dart';
import '../models/watermark_settings.dart';
import '../models/watermark_template.dart';
import '../widgets/watermark_preview.dart';

/// 水印管理页：合并展示预置 + 自定义水印模板，支持单列 / 双列布局切换
/// （经 [setWatermarkManageLayout] 持久化），卡片缩略图以真实照片为底、
/// 叠加水印元素预览。支持选择 / 新建 / 编辑 / 复制 / 删除。
class WatermarkManagePage extends ConsumerStatefulWidget {
  const WatermarkManagePage({super.key, this.showPhotoBackground = true});

  /// 是否在缩略图中加载示例照片底图。测试可传 false 避免图片解码带来不稳定，
  /// 从而聚焦于布局 / 交互断言。
  final bool showPhotoBackground;

  @override
  ConsumerState<WatermarkManagePage> createState() =>
      _WatermarkManagePageState();
}

class _WatermarkManagePageState extends ConsumerState<WatermarkManagePage> {
  static const String _samplePhoto = 'assets/images/watermark_sample.jpg';

  @override
  void initState() {
    super.initState();
    // 启动时从 DAO 加载自定义水印模板，与预置模板一起展示。
    Future.microtask(() =>
        loadCustomWatermarks(ProviderScope.containerOf(context, listen: false)));
  }

  ImageProvider? _photoBackground() {
    if (!widget.showPhotoBackground) return null;
    return const AssetImage(_samplePhoto);
  }

  void _onToggleLayout() {
    final container = ProviderScope.containerOf(context, listen: false);
    final current = ref.read(watermarkSettingsProvider).manageLayout;
    setWatermarkManageLayout(
      container,
      current == WatermarkManageLayout.grid
          ? WatermarkManageLayout.list
          : WatermarkManageLayout.grid,
    );
  }

  void _onNew() {
    context.push(RouteNames.profileSettingsWatermarkEdit);
  }

  void _onEdit(WatermarkTemplate template) {
    context.push(
      '${RouteNames.profileSettingsWatermarkEdit}'
      '?${RouteNames.paramTemplateId}=${template.id}',
    );
  }

  void _onSelect(WatermarkTemplate template) {
    final container = ProviderScope.containerOf(context, listen: false);
    setWatermarkActive(container, template.id);
    if (context.canPop()) {
      context.pop();
    }
  }

  Future<void> _onCopy(WatermarkTemplate template) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final copy = WatermarkTemplate(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: '${template.name}副本',
      type: WatermarkTemplateType.custom,
      createdAt: DateTime.now(),
      frame: template.frame,
      elements: [
        for (final e in template.elements) e.copyWith(id: '${e.id}_c'),
      ],
    );
    try {
      final dao = await ref.read(watermarkDaoProvider.future);
      await dao.insert(copy);
      if (!mounted) return;
      ref.read(customWatermarksProvider.notifier).state = [
        copy,
        ...ref.read(customWatermarksProvider),
      ];
    } catch (e) {
      debugPrint('[watermark-manage] copy template failed: $e');
    }
  }

  Future<void> _onDelete(WatermarkTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ref.read(themeTokensProvider).surface,
        title: Text(
          '删除水印',
          style: TextStyle(
            color: ref.read(themeTokensProvider).textPrimary,
            fontSize: 17,
          ),
        ),
        content: Text(
          '确定删除「${template.name}」吗？',
          style: TextStyle(
            color: ref.read(themeTokensProvider).textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              '取消',
              style: TextStyle(
                color: ref.read(themeTokensProvider).textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              '删除',
              style: TextStyle(color: ref.read(themeTokensProvider).danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final dao = await ref.read(watermarkDaoProvider.future);
      await dao.delete(template.id);
      if (!mounted) return;
      ref.read(customWatermarksProvider.notifier).state = ref
          .read(customWatermarksProvider)
          .where((t) => t.id != template.id)
          .toList();
    } catch (e) {
      debugPrint('[watermark-manage] delete template failed: $e');
    }
  }

  void _onMenuAction(WatermarkTemplate template, String action) {
    switch (action) {
      case 'edit':
        _onEdit(template);
        break;
      case 'copy':
        _onCopy(template);
        break;
      case 'delete':
        _onDelete(template);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final settings = ref.watch(watermarkSettingsProvider);
    final presets = ref.watch(presetWatermarksProvider);
    final customs = ref.watch(customWatermarksProvider);

    final templates = [...presets, ...customs];
    final activeId = settings.activeTemplateId;
    final layout = settings.manageLayout;
    final isGrid = layout == WatermarkManageLayout.grid;

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '水印管理',
        transparent: true,
        actions: [
          LumiraIconButton(
            key: const ValueKey('watermark-layout-toggle'),
            icon: isGrid ? Icons.view_agenda : Icons.grid_view,
            variant: LumiraIconButtonVariant.filled,
            color: tokens.brandText,
            onPressed: _onToggleLayout,
          ),
          const SizedBox(width: 6),
          LumiraButton(
            variant: ButtonVariant.primary,
            onPressed: _onNew,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: const Text('＋新建'),
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _layoutHeader(tokens, layout)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 32),
              sliver: isGrid
                  ? _buildGrid(templates, activeId, tokens)
                  : _buildList(templates, activeId, tokens),
            ),
          ],
        ),
      ),
    );
  }

  Widget _layoutHeader(ThemeTokens tokens, WatermarkManageLayout layout) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          Text(
            '模板',
            style: TextStyle(
              fontSize: 13,
              color: tokens.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          _LayoutSegments(
            value: layout,
            onChanged: (next) => setWatermarkManageLayout(
              ProviderScope.containerOf(context, listen: false),
              next,
            ),
            tokens: tokens,
          ),
        ],
      ),
    );
  }

  SliverGrid _buildGrid(
    List<WatermarkTemplate> templates,
    String? activeId,
    ThemeTokens tokens,
  ) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 256,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final template = templates[index];
          final selected = template.id == activeId;
          return _GridCard(
            template: template,
            selected: selected,
            tokens: tokens,
            background: _photoBackground(),
            onSelect: () => _onSelect(template),
            onMenuAction: (a) => _onMenuAction(template, a),
          );
        },
        childCount: templates.length,
      ),
    );
  }

  SliverList _buildList(
    List<WatermarkTemplate> templates,
    String? activeId,
    ThemeTokens tokens,
  ) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final template = templates[index];
          final selected = template.id == activeId;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ListCard(
              template: template,
              selected: selected,
              tokens: tokens,
              background: _photoBackground(),
              onSelect: () => _onSelect(template),
              onMenuAction: (a) => _onMenuAction(template, a),
            ),
          );
        },
        childCount: templates.length,
      ),
    );
  }
}

/// 布局切换分段控件：单列 / 双列
class _LayoutSegments extends StatelessWidget {
  const _LayoutSegments({
    required this.value,
    required this.onChanged,
    required this.tokens,
  });

  final WatermarkManageLayout value;
  final ValueChanged<WatermarkManageLayout> onChanged;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seg(tokens, Icons.view_agenda, WatermarkManageLayout.list),
          const SizedBox(width: 3),
          _seg(tokens, Icons.grid_view, WatermarkManageLayout.grid),
        ],
      ),
    );
  }

  Widget _seg(
    ThemeTokens tokens,
    IconData icon,
    WatermarkManageLayout layout,
  ) {
    final active = value == layout;
    return GestureDetector(
      onTap: () => onChanged(layout),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? tokens.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: active ? Border.all(color: tokens.brand, width: 1) : null,
        ),
        child: Icon(
          icon,
          size: 20,
          color: active ? tokens.brandText : tokens.textSecondary,
        ),
      ),
    );
  }
}

/// 双列网格卡片：照片底缩略 + 名称 + 类型标签 + 选中描边 / ⋮ 菜单
class _GridCard extends StatelessWidget {
  const _GridCard({
    required this.template,
    required this.selected,
    required this.tokens,
    required this.background,
    required this.onSelect,
    required this.onMenuAction,
  });

  final WatermarkTemplate template;
  final bool selected;
  final ThemeTokens tokens;
  final ImageProvider? background;
  final VoidCallback onSelect;
  final ValueChanged<String> onMenuAction;

  @override
  Widget build(BuildContext context) {
    Widget card = NeuCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onSelect,
            behavior: HitTestBehavior.opaque,
            child: WatermarkPreview(
              template: template,
              width: double.infinity,
              height: 150,
              background: background,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  template.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _TypeTag(type: template.type, tokens: tokens),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (selected)
                _SelectedBadge(tokens: tokens)
              else
                const SizedBox.shrink(),
              const Spacer(),
              _MenuButton(
                isCustom: template.type == WatermarkTemplateType.custom,
                tokens: tokens,
                onAction: onMenuAction,
              ),
            ],
          ),
        ],
      ),
    );

    if (selected) {
      card = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tokens.brand, width: 2),
        ),
        child: card,
      );
    }
    return card;
  }
}

/// 单列横向卡片：左侧照片底缩略，右侧名称 + 类型标签，选中✓ / ⋮ 菜单
class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.template,
    required this.selected,
    required this.tokens,
    required this.background,
    required this.onSelect,
    required this.onMenuAction,
  });

  final WatermarkTemplate template;
  final bool selected;
  final ThemeTokens tokens;
  final ImageProvider? background;
  final VoidCallback onSelect;
  final ValueChanged<String> onMenuAction;

  @override
  Widget build(BuildContext context) {
    Widget card = NeuCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onSelect,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                WatermarkPreview(
                  template: template,
                  width: 96,
                  height: 124,
                  background: background,
                ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        template.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      _TypeTag(type: template.type, tokens: tokens),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (selected) ...[
            _SelectedBadge(tokens: tokens),
            const SizedBox(width: 8),
          ],
          _MenuButton(
            isCustom: template.type == WatermarkTemplateType.custom,
            tokens: tokens,
            onAction: onMenuAction,
          ),
        ],
      ),
    );

    if (selected) {
      card = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tokens.brand, width: 2),
        ),
        child: card,
      );
    }
    return card;
  }
}

class _TypeTag extends StatelessWidget {
  const _TypeTag({required this.type, required this.tokens});
  final WatermarkTemplateType type;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final label = type == WatermarkTemplateType.preset ? '预置' : '自定义';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tokens.brandSubtle,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: tokens.brandText,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _SelectedBadge extends StatelessWidget {
  const _SelectedBadge({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: tokens.brand,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check, size: 16, color: Colors.white),
    );
  }
}

/// 卡片右上 ⋮ 菜单：编辑（全部）/ 复制 / 删除（自定义专属）
class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.isCustom,
    required this.tokens,
    required this.onAction,
  });

  final bool isCustom;
  final ThemeTokens tokens;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: tokens.textSecondary, size: 20),
      onSelected: onAction,
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'edit', child: Text('编辑')),
        if (isCustom) ...[
          const PopupMenuItem(value: 'copy', child: Text('复制')),
          PopupMenuItem(
            value: 'delete',
            child: Text('删除', style: TextStyle(color: tokens.danger)),
          ),
        ],
      ],
    );
  }
}
