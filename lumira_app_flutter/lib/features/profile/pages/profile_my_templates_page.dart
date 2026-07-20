import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/number_format.dart';
import '../../../shared/widgets/buttons/lumira_buttons.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/profile_content_mock_data.dart';

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
}

class _ProfileMyTemplatesPageState extends ConsumerState<ProfileMyTemplatesPage> {
  _FilterKey _activeFilter = _FilterKey.all;
  bool _actionSheetVisible = false;
  CustomTemplate? _activeTemplate;

  /// 当前激活的模板（用于 ActionSheet 标题）
  CustomTemplate? get _activeTpl => _activeTemplate;

  List<CustomTemplate> get _filteredTemplates {
    const all = ProfileContentMockData.customTemplates;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1000),
      ),
    );
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

  void _handleActionExport() {
    _closeActionSheet();
    _showSnack('导出中...');
  }

  void _handleActionDelete() {
    _closeActionSheet();
    _showSnack('已删除');
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '我的模板',
        transparent: true,
        leading: _BackButton(tokens: tokens),
        actions: [
          _ImportButton(tokens: tokens),
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
                    _StatsBar(tokens: tokens),
                    _ActionBar(tokens: tokens),
                    _FilterBar(
                      tokens: tokens,
                      activeFilter: _activeFilter,
                      onSelect: (f) => setState(() => _activeFilter = f),
                    ),
                    if (_filteredTemplates.isNotEmpty)
                      _TplList(
                        tokens: tokens,
                        templates: _filteredTemplates,
                        onTap: (tpl) => GoRouter.of(context).push(
                          RouteNames.withTemplateId(RouteNames.templatesEditor, tpl.id),
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
  const _ImportButton({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => GoRouter.of(context).push(RouteNames.templatesEditor),
      behavior: HitTestBehavior.opaque,
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
  const _StatsBar({required this.tokens});
  final ThemeTokens tokens;

  Widget _statItem(String num, String label) {
    return Column(
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
          _statItem('${ProfileContentMockData.customTemplates.length}', '自定义模板'),
          _divider(),
          // 4+ 位数必须用 formatThousands（totalUsage = 1280+856+432+215+88 = 2871）
          _statItem(formatThousands(ProfileContentMockData.totalUsage), '使用次数'),
          _divider(),
          _statItem('${ProfileContentMockData.favoriteCount}', '收藏'),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.tokens});
  final ThemeTokens tokens;

  void _showImportSheet(BuildContext context, ThemeTokens tokens) {
    // Forced fix: 之前"导入模板"按钮错误跳转到 templatesEditor（新建模板）。
    // 正确行为：弹出导入方式选择 BottomSheet（文件 / 链接 / 扫码）。
    // mock 阶段选择后显示 SnackBar 提示。
    showModalBottomSheet(
      context: context,
      backgroundColor: tokens.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '导入模板',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _ImportOption(
                icon: Icons.insert_drive_file_outlined,
                title: '从文件导入',
                subtitle: '支持 .json / .lumira 模板文件',
                tokens: tokens,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('文件导入功能即将上线'),
                      duration: Duration(milliseconds: 1500),
                    ),
                  );
                },
              ),
              _ImportOption(
                icon: Icons.link_outlined,
                title: '从链接导入',
                subtitle: '粘贴分享链接',
                tokens: tokens,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('链接导入功能即将上线'),
                      duration: Duration(milliseconds: 1500),
                    ),
                  );
                },
              ),
              _ImportOption(
                icon: Icons.qr_code_scanner_outlined,
                title: '扫码导入',
                subtitle: '扫描模板分享二维码',
                tokens: tokens,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('扫码导入功能即将上线'),
                      duration: Duration(milliseconds: 1500),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), // 40rpx/32rpx/0 → 20/16/0
      child: Row(
        children: [
          Expanded(
            child: LumiraButton(
              label: '新建模板',
              icon: Icons.add,
              expand: true,
              onPressed: () => GoRouter.of(context).push(RouteNames.templatesEditor),
            ),
          ),
          const SizedBox(width: 10), // 20rpx → 10dp gap
          Expanded(
            child: LumiraButton(
              label: '导入模板',
              icon: Icons.download_outlined,
              variant: LumiraButtonVariant.ghost,
              expand: true,
              onPressed: () => _showImportSheet(context, tokens),
            ),
          ),
        ],
      ),
    );
  }
}

/// 导入方式选项
class _ImportOption extends StatelessWidget {
  const _ImportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tokens,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tokens.brand.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: tokens.brand),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: tokens.textTertiary,
                    ),
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

class _FilterPill extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // 32rpx/16rpx → 16/8dp
        decoration: BoxDecoration(
          // active: linear gradient brand→brandDeep（硬编码颜色，与 uni-app 一致）
          gradient: active
              ? LinearGradient(colors: [tokens.brand, tokens.brandDeep])
              : null,
          color: active ? null : tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(9999),
          boxShadow: active
              ? tokens.shadowPressed
              : tokens.shadowConvexSubtle,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13, // 26rpx → 13dp
            fontWeight: active ? FontWeight.w500 : FontWeight.w400,
            color: active ? Colors.white : tokens.textSecondary,
          ),
        ),
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
                    child: t.coverUrl != null
                        ? Image.network(
                            t.coverUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: tokens.surfaceAlt,
                              child: Icon(Icons.broken_image_outlined, color: tokens.textTertiary),
                            ),
                          )
                        : Container(color: tokens.surfaceAlt),
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
            label: '创建模板',
            icon: Icons.add,
            onPressed: () => GoRouter.of(context).push(RouteNames.templatesEditor),
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
  final VoidCallback onExport;
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
                    icon: Icons.upload_outlined,
                    label: '导出 .pptpl',
                    onTap: onExport,
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
