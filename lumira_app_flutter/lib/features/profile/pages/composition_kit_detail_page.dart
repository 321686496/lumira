import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/dao/scenes_dao.dart';
import '../../../core/db/dao/templates_dao.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../templates/widgets/template_cover_image.dart';
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
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          SafeArea(
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
        ],
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
    final sceneAsync = ref.watch(compositionKitSceneProvider(kit.sceneId));
    final templateAsync = kit.templateId == null
        ? null
        : ref.watch(compositionKitTemplateProvider(kit.templateId!));
    final scene = sceneAsync.valueOrNull;
    final template = templateAsync?.valueOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CoverPreview(tokens: tokens, kit: kit, scene: scene, template: template),
          const SizedBox(height: 16),
          _TitleSection(tokens: tokens, kit: kit),
          const SizedBox(height: 16),
          _LinkedSection(tokens: tokens, kit: kit, scene: scene, template: template),
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
  const _CoverPreview({
    required this.tokens,
    required this.kit,
    required this.scene,
    required this.template,
  });
  final ThemeTokens tokens;
  final CompositionKit kit;
  final SceneRecord? scene;
  final TemplateRecord? template;

  @override
  Widget build(BuildContext context) {
    final cover = resolveKitCover(kit, scene: scene, template: template);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 3.0 / 4.0,
        child: cover.hasImage
            ? TemplateCoverImage(
                cover: cover.cover,
                coverData: cover.coverData,
                fit: BoxFit.cover,
                fallback: _CoverFallback(tokens: tokens),
                errorFallback: _CoverFallback(tokens: tokens),
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

/// 场景 / 模板关联卡片区块：以卡片形式展示并可跳转到对应详情页。
class _LinkedSection extends StatelessWidget {
  const _LinkedSection({
    required this.tokens,
    required this.kit,
    required this.scene,
    required this.template,
  });

  final ThemeTokens tokens;
  final CompositionKit kit;
  final SceneRecord? scene;
  final TemplateRecord? template;

  @override
  Widget build(BuildContext context) {
    final sceneName = (scene != null && scene!.name.isNotEmpty)
        ? scene!.name
        : kit.sceneId;
    final sceneCover = _sceneCover(scene);
    final sceneSub = scene == null ? '场景已不存在' : (scene!.category.isNotEmpty ? scene!.category : '场景');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LinkedCard(
          tokens: tokens,
          label: '场景',
          title: sceneName,
          subtitle: sceneSub,
          cover: sceneCover,
          onTap: () => GoRouter.of(context).push(
            RouteNames.withSceneId(RouteNames.captureSceneDetail, kit.sceneId),
          ),
        ),
        const SizedBox(height: 12),
        if (template == null && kit.templateId == null)
          _LinkedCard(
            tokens: tokens,
            label: '模板',
            title: '未关联模板',
            subtitle: '纯场景组合，可跳过',
            cover: const KitCoverSource(),
          )
        else
          _LinkedCard(
            tokens: tokens,
            label: '模板',
            title: (template != null && template!.name.isNotEmpty)
                ? template!.name
                : (kit.templateId ?? '模板'),
            subtitle: template == null ? '模板已不存在' : '点击查看模板详情',
            cover: _templateCover(template),
            onTap: () => GoRouter.of(context).push(
              RouteNames.withTemplateId(RouteNames.templatesDetail, kit.templateId!),
            ),
          ),
      ],
    );
  }

  KitCoverSource _sceneCover(SceneRecord? scene) {
    if (scene == null) return const KitCoverSource();
    if (scene.coverUrl.isNotEmpty) return KitCoverSource(cover: scene.coverUrl);
    if (scene.exampleImages.isNotEmpty) {
      return KitCoverSource(cover: scene.exampleImages.first);
    }
    return const KitCoverSource();
  }

  KitCoverSource _templateCover(TemplateRecord? template) {
    if (template == null) return const KitCoverSource();
    if (template.coverData != null && template.coverData!.isNotEmpty) {
      return KitCoverSource(coverData: template.coverData);
    }
    if (template.cover.isNotEmpty) return KitCoverSource(cover: template.cover);
    return const KitCoverSource();
  }
}

class _LinkedCard extends StatelessWidget {
  const _LinkedCard({
    required this.tokens,
    required this.label,
    required this.title,
    required this.subtitle,
    required this.cover,
    this.onTap,
  });

  final ThemeTokens tokens;
  final String label;
  final String title;
  final String subtitle;
  final KitCoverSource cover;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: NeuCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56,
                height: 56,
                child: cover.hasImage
                    ? TemplateCoverImage(
                        cover: cover.cover,
                        coverData: cover.coverData,
                        fit: BoxFit.cover,
                        fallback: _LinkedImagePlaceholder(tokens: tokens),
                        errorFallback: _LinkedImagePlaceholder(tokens: tokens),
                      )
                    : _LinkedImagePlaceholder(tokens: tokens),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 11, color: tokens.textTertiary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: tokens.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, size: 18, color: tokens.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _LinkedImagePlaceholder extends StatelessWidget {
  const _LinkedImagePlaceholder({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: tokens.surface,
      child: Icon(Icons.layers_outlined, color: tokens.textTertiary, size: 24),
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
