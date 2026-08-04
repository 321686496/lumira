import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/composition_kit_models.dart';
import '../providers/composition_kits_providers.dart';

/// 组合套件详情页
///
/// 显示套件预览（场景图 + 模板叠图描述 + 参数表）+「立即使用此套件拍照」按钮
class CompositionKitDetailPage extends ConsumerWidget {
  const CompositionKitDetailPage({super.key, required this.kitId});

  final String kitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final kitAsync = ref.watch(compositionKitByIdProvider(kitId));

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '套件详情',
        transparent: true,
        leading: _BackButton(tokens: tokens),
      ),
      body: SafeArea(
        child: kitAsync.when(
          loading: () => Center(child: LumiraProgress.circular()),
          error: (e, _) => Center(child: Text('加载失败：$e')),
          data: (kit) {
            if (kit == null) {
              return _NotFound(tokens: tokens);
            }
            return _KitDetailContent(tokens: tokens, kit: kit);
          },
        ),
      ),
      bottomNavigationBar: kitAsync.maybeWhen(
        data: (kit) => kit == null
            ? null
            : _BottomCaptureBar(tokens: tokens, kit: kit),
        orElse: () => null,
      ),
    );
  }
}

class _KitDetailContent extends ConsumerWidget {
  const _KitDetailContent({required this.tokens, required this.kit});
  final ThemeTokens tokens;
  final CompositionKit kit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CoverPreview(tokens: tokens, kit: kit),
          const SizedBox(height: 16),
          _TitleSection(tokens: tokens, kit: kit),
          const SizedBox(height: 16),
          _MetaSection(tokens: tokens, kit: kit),
          const SizedBox(height: 16),
          if (kit.cameraOverrides.isNotEmpty) ...[
            _ParamsSection(tokens: tokens, kit: kit),
            const SizedBox(height: 16),
          ],
          if (kit.note.isNotEmpty) ...[
            _NoteSection(tokens: tokens, kit: kit),
            const SizedBox(height: 16),
          ],
          _UsageSection(tokens: tokens, kit: kit),
        ],
      ),
    );
  }
}

class _CoverPreview extends StatelessWidget {
  const _CoverPreview({required this.tokens, required this.kit});
  final ThemeTokens tokens;
  final CompositionKit kit;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 3.0 / 4.0,
        child: kit.coverUrl != null && kit.coverUrl!.isNotEmpty
            ? Image.network(
                kit.coverUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _CoverFallback(tokens: tokens),
              )
            : _CoverFallback(tokens: tokens),
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: tokens.surface,
      child: Center(
        child: Icon(Icons.layers_outlined, size: 56, color: tokens.textTertiary),
      ),
    );
  }
}

class _TitleSection extends StatelessWidget {
  const _TitleSection({required this.tokens, required this.kit});
  final ThemeTokens tokens;
  final CompositionKit kit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kit.name,
          style: TextStyle(
            fontFamily: 'Noto Serif SC',
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '创建于 ${_formatDate(kit.createdAt)}',
          style: TextStyle(fontSize: 12, color: tokens.textTertiary),
        ),
      ],
    );
  }

  String _formatDate(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _MetaSection extends ConsumerWidget {
  const _MetaSection({required this.tokens, required this.kit});
  final ThemeTokens tokens;
  final CompositionKit kit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MetaRow(
            tokens: tokens,
            label: '场景',
            value: 'ID: ${kit.sceneId}',
          ),
          const SizedBox(height: 8),
          _MetaRow(
            tokens: tokens,
            label: '模板',
            value: kit.templateId == null ? '未关联' : 'ID: ${kit.templateId}',
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.tokens, required this.label, required this.value});
  final ThemeTokens tokens;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: tokens.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 13, color: tokens.textPrimary),
          ),
        ),
      ],
    );
  }
}

class _ParamsSection extends StatelessWidget {
  const _ParamsSection({required this.tokens, required this.kit});
  final ThemeTokens tokens;
  final CompositionKit kit;

  @override
  Widget build(BuildContext context) {
    final params = kit.cameraOverrides;
    final ev = (params['exposureCompensation'] as num?)?.toDouble();
    final iso = (params['iso'] as num?)?.toInt();
    final shutter = params['shutterSpeed'] as String?;

    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '参数',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (ev != null)
                _ParamChip(tokens: tokens, label: 'EV', value: _formatEv(ev)),
              if (iso != null)
                _ParamChip(tokens: tokens, label: 'ISO', value: '$iso'),
              if (shutter != null)
                _ParamChip(tokens: tokens, label: '快门', value: shutter),
            ],
          ),
        ],
      ),
    );
  }

  String _formatEv(double ev) {
    if (ev > 0) return '+${ev.toStringAsFixed(1)}';
    return ev.toStringAsFixed(1);
  }
}

class _ParamChip extends ConsumerWidget {
  const _ParamChip({required this.tokens, required this.label, required this.value});
  final ThemeTokens tokens;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final isNeu = appTheme.style == UIStyle.neumorphic;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isNeu ? tokens.surface : tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        boxShadow: isNeu ? tokens.shadowConvexSubtle : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: tokens.textTertiary),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: tokens.textPrimary,
              fontFamily: 'Courier New',
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteSection extends StatelessWidget {
  const _NoteSection({required this.tokens, required this.kit});
  final ThemeTokens tokens;
  final CompositionKit kit;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '备注',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            kit.note,
            style: TextStyle(fontSize: 13, color: tokens.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _UsageSection extends StatelessWidget {
  const _UsageSection({required this.tokens, required this.kit});
  final ThemeTokens tokens;
  final CompositionKit kit;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.history, size: 16, color: tokens.textTertiary),
          const SizedBox(width: 8),
          Text(
            '使用 ${kit.usageCount} 次 · ${kit.lastUsedAt == null ? "未使用" : "最近: ${_formatDate(kit.lastUsedAt!)}"}',
            style: TextStyle(fontSize: 12, color: tokens.textTertiary),
          ),
        ],
      ),
    );
  }

  String _formatDate(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.month}-${dt.day}';
  }
}

class _BottomCaptureBar extends StatelessWidget {
  const _BottomCaptureBar({required this.tokens, required this.kit});
  final ThemeTokens tokens;
  final CompositionKit kit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(
          color: tokens.canvas,
          border: Border(top: BorderSide(color: tokens.divider, width: 0.5)),
        ),
        child: GestureDetector(
          onTap: () => GoRouter.of(context).push(RouteNames.build(
            RouteNames.capture,
            {
              RouteNames.paramScene: kit.sceneId,
              RouteNames.paramTemplateId: kit.templateId ?? '',
              RouteNames.paramKitId: kit.id,
            },
          )),
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: tokens.textPrimary,
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            child: Text(
              '立即使用此套件拍照',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: tokens.canvas,
              ),
            ),
          ),
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
          GoRouter.of(context).go(RouteNames.profileCompositionKits);
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

class _NotFound extends StatelessWidget {
  const _NotFound({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: tokens.textTertiary),
          const SizedBox(height: 12),
          Text('套件不存在或已删除',
              style: TextStyle(fontSize: 16, color: tokens.textPrimary)),
        ],
      ),
    );
  }
}
