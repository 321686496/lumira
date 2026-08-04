import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/lumira/lumira.dart' as lumira;
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/templates_browse_mock_data.dart';
import '../data/templates_management_mock_data.dart';

/// 草稿箱页
///
/// 视觉规格来源：lumira-app/src/pages/templates/drafts.vue (152 行)
/// 4 个 section：StatsBar / DraftList / EmptyState（二选一）+ LumiraNav
class TemplatesDraftsPage extends ConsumerStatefulWidget {
  const TemplatesDraftsPage({super.key, this.initialDrafts});

  /// 测试用注入草稿列表（默认 null → 用 [DraftsMockData.drafts]）
  /// 生产环境由路由构造时不传该参数
  final List<DraftItem>? initialDrafts;

  @override
  ConsumerState<TemplatesDraftsPage> createState() =>
      _TemplatesDraftsPageState();
}

class _TemplatesDraftsPageState extends ConsumerState<TemplatesDraftsPage> {
  late List<DraftItem> _drafts;
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _drafts = List<DraftItem>.from(
      widget.initialDrafts ?? DraftsMockData.drafts,
    );
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final scrolled = _scrollController.offset > 20;
    if (scrolled != _isScrolled) {
      setState(() => _isScrolled = scrolled);
    }
  }

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.of(context).go(RouteNames.profileMyTemplates);
    }
  }

  void _onResume(String draftId) {
    GoRouter.of(context).push('/templates/editor?draftId=$draftId');
  }

  void _onCreate() {
    GoRouter.of(context).push(RouteNames.templatesEditor);
  }

  void _onDelete(String draftId, String name) {
    lumira.LumiraAlertDialog.show<void>(
      context: context,
      title: const Text('删除草稿'),
      content: Text('确定删除草稿"$name"吗？'),
      actions: [
        lumira.LumiraButton(
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        lumira.LumiraButton(
          variant: ButtonVariant.danger,
          onPressed: () {
            Navigator.pop(context);
            setState(() {
              _drafts.removeWhere((d) => d.id == draftId);
            });
            lumira.LumiraToast.show(context, '已删除');
          },
          child: const Text('确认'),
        ),
      ],
    );
  }

  void _onClearAll() {
    lumira.LumiraAlertDialog.show<void>(
      context: context,
      title: const Text('清空草稿箱'),
      content: const Text('确定删除所有草稿吗？此操作不可恢复。'),
      actions: [
        lumira.LumiraButton(
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        lumira.LumiraButton(
          variant: ButtonVariant.danger,
          onPressed: () {
            Navigator.pop(context);
            setState(() {
              _drafts.clear();
            });
            lumira.LumiraToast.show(context, '已清空');
          },
          child: const Text('确认'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);

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
                  title: '草稿箱',
                  transparent: true,
                  scrolled: _isScrolled,
                  leading: _BackButton(tokens: tokens, onTap: _back),
                  actions: _drafts.isNotEmpty
                      ? [
                          _TrashButton(
                            tokens: tokens,
                            onTap: _onClearAll,
                          ),
                        ]
                      : null,
                ),
                Expanded(
                  child: _drafts.isEmpty
                      ? _EmptyState(
                          tokens: tokens,
                          onCreate: _onCreate,
                        )
                      : ListView(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(bottom: 32),
                          children: [
                            _StatsBar(
                              tokens: tokens,
                              count: _drafts.length,
                            ),
                            _DraftList(
                              tokens: tokens,
                              drafts: _drafts,
                              onResume: _onResume,
                              onDelete: _onDelete,
                            ),
                          ],
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

class _TrashButton extends StatelessWidget {
  const _TrashButton({required this.tokens, required this.onTap});
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
          Icons.delete_outline,
          size: 20,
          color: tokens.textSecondary,
        ),
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.tokens, required this.count});
  final ThemeTokens tokens;
  final int count;

  @override
  Widget build(BuildContext context) {
    return FadeUp(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: tokens.shadowConvexSubtle,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontFamily: 'Noto Serif SC',
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
                height: 1,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '个草稿',
              style: TextStyle(
                fontSize: 11,
                color: tokens.textTertiary,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftList extends StatelessWidget {
  const _DraftList({
    required this.tokens,
    required this.drafts,
    required this.onResume,
    required this.onDelete,
  });

  final ThemeTokens tokens;
  final List<DraftItem> drafts;
  final void Function(String draftId) onResume;
  final void Function(String draftId, String name) onDelete;

  @override
  Widget build(BuildContext context) {
    return FadeUp(
      delay: const Duration(milliseconds: 80),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(
          children: [
            for (int i = 0; i < drafts.length; i++) ...[
              _DraftRow(
                tokens: tokens,
                draft: drafts[i],
                onResume: () => onResume(drafts[i].id),
                onDelete: () => onDelete(drafts[i].id, drafts[i].name),
              ),
              if (i < drafts.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _DraftRow extends StatelessWidget {
  const _DraftRow({
    required this.tokens,
    required this.draft,
    required this.onResume,
    required this.onDelete,
  });

  final ThemeTokens tokens;
  final DraftItem draft;
  final VoidCallback onResume;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: tokens.shadowConvexSubtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DraftContent(
            tokens: tokens,
            draft: draft,
            onTap: onResume,
          ),
          const SizedBox(height: 10),
          _DraftActions(
            tokens: tokens,
            onResume: onResume,
            onDelete: onDelete,
          ),
        ],
      ),
    );
  }
}

class _DraftContent extends StatelessWidget {
  const _DraftContent({
    required this.tokens,
    required this.draft,
    required this.onTap,
  });

  final ThemeTokens tokens;
  final DraftItem draft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  draft.name,
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
              const SizedBox(width: 8),
              Text(
                formatDraftTime(draft.updatedAt),
                style: TextStyle(
                  fontSize: 11,
                  color: tokens.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: tokens.brandSubtle,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  TemplatesBrowseMockData.categoryLabel(draft.category),
                  style: TextStyle(
                    fontSize: 10,
                    color: tokens.brandText,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _ParamItem(tokens: tokens, text: 'EV ${formatEv(draft.exposureCompensation)}'),
              _ParamItem(tokens: tokens, text: 'ISO ${draft.iso}'),
              _ParamItem(tokens: tokens, text: draft.shutterSpeed),
            ],
          ),
        ],
      ),
    );
  }
}

class _ParamItem extends StatelessWidget {
  const _ParamItem({required this.tokens, required this.text});
  final ThemeTokens tokens;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color: tokens.textTertiary,
        fontFamily: 'SF Mono',
        letterSpacing: 0.2,
      ),
    );
  }
}

class _DraftActions extends ConsumerWidget {
  const _DraftActions({
    required this.tokens,
    required this.onResume,
    required this.onDelete,
  });

  final ThemeTokens tokens;
  final VoidCallback onResume;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNeumorphic = ref.watch(uiStyleProvider) == UIStyle.neumorphic;
    return Container(
      padding: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: tokens.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onResume,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                // 硬编码颜色，与 uni-app 一致 (linear-gradient brand → brandDeep)
                // neumorphic 风格下：移除渐变，用 brand 纯色 + shadowConvex
                gradient: isNeumorphic
                    ? null
                    : LinearGradient(
                        colors: [tokens.brand, tokens.brandDeep]),
                color: isNeumorphic ? tokens.brand : null,
                borderRadius: BorderRadius.circular(9999),
                boxShadow: isNeumorphic
                    ? tokens.shadowConvex
                    : tokens.shadowConvexBrand,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.edit_outlined, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    '继续编辑',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onDelete,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: tokens.surfaceAlt,
                borderRadius: BorderRadius.circular(9999),
                boxShadow: tokens.shadowConvexSubtle,
              ),
              child: Icon(
                Icons.delete_outline,
                size: 14,
                color: tokens.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tokens, required this.onCreate});
  final ThemeTokens tokens;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return FadeUp(
      delay: const Duration(milliseconds: 80),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: 0.35,
              child: Icon(
                Icons.edit_note,
                size: 60,
                color: tokens.textTertiary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '还没有草稿',
              style: TextStyle(
                fontFamily: 'Noto Serif SC',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '在模板编辑器中填写内容时会自动保存草稿',
              style: TextStyle(
                fontSize: 12,
                color: tokens.textTertiary,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: lumira.LumiraButton(
                variant: ButtonVariant.primary,
                onPressed: onCreate,
                child: SizedBox(
                  width: double.infinity,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.add),
                      SizedBox(width: 8),
                      Text('新建模板'),
                    ],
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
