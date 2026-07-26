import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/number_format.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/composition_kit_models.dart';
import '../providers/composition_kits_providers.dart';

/// 组合套件列表页
///
/// 视觉规格：对齐 ProfileMyTemplatesPage 结构
/// 1. 顶部 StatsBar：总数 / 总使用次数 / 最近使用
/// 2. 套件列表卡片：封面 + 名称 + 场景标签 + 模板标签 + 上次使用 + 使用次数
/// 3. FAB "新建套件"
/// 4. 卡片点击 → 详情页；长按 → ActionSheet（套用/编辑/复制/删除）
class CompositionKitsPage extends ConsumerWidget {
  const CompositionKitsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final kitsAsync = ref.watch(compositionKitsProvider);
    final statsAsync = ref.watch(compositionKitsStatsProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '我的组合',
        transparent: true,
        leading: _BackButton(tokens: tokens),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => GoRouter.of(context).push(RouteNames.captureSceneManage),
        backgroundColor: tokens.brand,
        child: Icon(Icons.add, color: tokens.canvas),
      ),
      body: SafeArea(
        child: kitsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('加载失败：$e')),
          data: (kits) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(compositionKitsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                _StatsBar(tokens: tokens, stats: statsAsync),
                const SizedBox(height: 16),
                if (kits.isEmpty)
                  _EmptyState(tokens: tokens)
                else
                  for (var i = 0; i < kits.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _KitCard(
                      tokens: tokens,
                      kit: kits[i],
                      onTap: () => GoRouter.of(context).push(
                        '${RouteNames.profileCompositionKitDetail}'
                        '?${RouteNames.paramKitId}=${kits[i].id}',
                      ),
                      onLongPress: () => _showActionSheet(context, ref, kits[i]),
                    ),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showActionSheet(BuildContext context, WidgetRef ref, CompositionKit kit) {
    final tokens = ref.read(themeTokensProvider);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: tokens.brand),
              title: const Text('套用拍照'),
              onTap: () {
                Navigator.pop(ctx);
                GoRouter.of(context).push(RouteNames.build(RouteNames.capture, {
                  RouteNames.paramScene: kit.sceneId,
                  RouteNames.paramTemplateId: kit.templateId ?? '',
                  RouteNames.paramKitId: kit.id,
                }));
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: tokens.danger),
              title: Text('删除', style: TextStyle(color: tokens.danger)),
              onTap: () async {
                Navigator.pop(ctx);
                final messenger = ScaffoldMessenger.of(context);
                final dao = await ref.read(compositionKitsDaoProvider.future);
                await dao.delete(kit.id);
                ref.invalidate(compositionKitsProvider);
                messenger.showSnackBar(
                  const SnackBar(content: Text('已删除')),
                );
              },
            ),
            ListTile(
              title: Center(
                child: Text('取消',
                    style: TextStyle(color: tokens.textSecondary)),
              ),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
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

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.tokens, required this.stats});
  final ThemeTokens tokens;
  final AsyncValue<CompositionKitsStats> stats;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: stats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const SizedBox.shrink(),
        data: (s) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
                tokens: tokens, value: '${s.totalCount}', label: '套件总数'),
            _Divider(tokens: tokens),
            _StatItem(
                tokens: tokens,
                value: formatThousands(s.totalUsage),
                label: '总使用次数'),
            _Divider(tokens: tokens),
            _StatItem(
                tokens: tokens,
                value: s.lastUsedAt == null
                    ? '—'
                    : _formatDate(s.lastUsedAt!),
                label: '最近使用'),
          ],
        ),
      ),
    );
  }

  String _formatDate(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.month}-${dt.day}';
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.tokens, required this.value, required this.label});
  final ThemeTokens tokens;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Noto Serif SC',
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: tokens.textTertiary),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(width: 0.5, height: 28, color: tokens.divider);
  }
}

class _KitCard extends StatelessWidget {
  const _KitCard({
    required this.tokens,
    required this.kit,
    required this.onTap,
    required this.onLongPress,
  });

  final ThemeTokens tokens;
  final CompositionKit kit;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: NeuCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 80,
                height: 80,
                child: kit.coverUrl != null && kit.coverUrl!.isNotEmpty
                    ? Image.network(
                        kit.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _CoverPlaceholder(tokens: tokens),
                      )
                    : _CoverPlaceholder(tokens: tokens),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    kit.name,
                    style: TextStyle(
                      fontFamily: 'Noto Serif SC',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _Tag(tokens: tokens, text: '场景: ${_shortId(kit.sceneId)}'),
                      if (kit.templateId != null)
                        _Tag(tokens: tokens, text: '模板: ${_shortId(kit.templateId!)}'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '使用 ${kit.usageCount} 次 · ${_formatLastUsed(kit.lastUsedAt)}',
                    style: TextStyle(fontSize: 11, color: tokens.textTertiary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: tokens.textTertiary),
          ],
        ),
      ),
    );
  }

  String _shortId(String id) {
    // 取 id 中第一个 - 之前的部分作为简短标签
    final idx = id.indexOf('-');
    return idx == -1 ? id : id.substring(0, idx);
  }

  String _formatLastUsed(int? ms) {
    if (ms == null) return '未使用';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inHours < 1) return '刚刚';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${dt.month}-${dt.day}';
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: tokens.surfaceAlt,
      child: Icon(Icons.layers_outlined, color: tokens.textTertiary, size: 28),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.tokens, required this.text});
  final ThemeTokens tokens;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: tokens.brandSubtle,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: tokens.brandText),
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
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 40),
      child: Column(
        children: [
          Icon(Icons.layers_outlined, size: 60, color: tokens.textTertiary.withOpacity(0.35)),
          const SizedBox(height: 10),
          Text(
            '还没有组合套件',
            style: TextStyle(
              fontFamily: 'Noto Serif SC',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '在场景详情页点击"加入组合"即可创建',
            style: TextStyle(fontSize: 12, color: tokens.textTertiary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => GoRouter.of(context).push(RouteNames.scenes),
            child: const Text('去逛逛场景'),
          ),
        ],
      ),
    );
  }
}
