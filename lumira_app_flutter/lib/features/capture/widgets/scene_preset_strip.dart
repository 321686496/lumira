import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/capture_appearance.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/lumira/_internal/lumira_theme_resolver.dart';
import '../../../core/utils/image_cache.dart';
import '../../usage/usage_providers.dart';
import '../../../core/db/dao/usage_dao.dart';
import '../data/capture_scene_providers.dart';
import '../data/capture_state.dart';
import '../data/scene_presets_data.dart';
import '../domain/scene_preset.dart';

/// 拍摄页底部工具栏场景条。
///
/// 数据来自 [captureScenePresetsProvider]：场景管理全量场景 + 最近拍摄使用顺序。
/// 展开面板最多显示 10 个，超过时显示「查看更多」，由外部弹出完整抽屉。
class ScenePresetStrip extends ConsumerWidget {
  const ScenePresetStrip({
    super.key,
    this.compact = false,
    this.onShowMore,
  });

  final bool compact;
  final VoidCallback? onShowMore;

  static const _stripMax = 10;
  static const _compactMax = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeId = ref.watch(CaptureState.activeScenePresetIdProvider);
    final scenesAsync = ref.watch(captureScenePresetsProvider);
    final visual = LumiraThemeResolver.captureOverlayVisual(
      tokens: ref.watch(themeTokensProvider),
      style: ref.watch(appThemeProvider).style,
      appearance: ref.watch(CaptureState.captureAppearanceProvider),
      role: CaptureOverlayRole.panel,
      radiusDp: 8,
    );

    return scenesAsync.when(
      loading: () => SizedBox(
        height: compact ? 60 : 78,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: visual.foregroundMuted,
            ),
          ),
        ),
      ),
      error: (_, __) => _buildEmptyState(visual),
      data: (allScenes) {
        final presets = _moveActiveToFront(allScenes, activeId);
        final max = compact ? _compactMax : _stripMax;
        final hasMore = !compact && presets.length > max && onShowMore != null;
        final visible = presets.take(max).toList();
        if (visible.isEmpty) return _buildEmptyState(visual);

        return SizedBox(
          height: compact ? 60 : 78,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: visible.length + (hasMore ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (hasMore && i == visible.length) {
                return _buildShowMoreItem(visual);
              }
              final preset = visible[i];
              return _SceneCard(
                preset: preset,
                width: compact ? 45 : 54,
                active: preset.id == activeId,
                visual: visual,
                onTap: () => _selectScene(ref, preset.id),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(CaptureOverlayVisual visual) {
    return SizedBox(
      height: compact ? 60 : 78,
      child: Center(
        child: Text(
          '暂无场景',
          style: TextStyle(color: visual.foregroundMuted, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildShowMoreItem(CaptureOverlayVisual visual) {
    return GestureDetector(
      onTap: onShowMore,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: compact ? 45 : 60,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: visual.border,
          color: visual.fillSubtle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.expand_more,
              color: visual.foregroundSecondary,
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              '查看更多',
              style: TextStyle(
                color: visual.foregroundSecondary,
                fontSize: 9,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _selectScene(WidgetRef ref, String sceneId) {
    final active = ref.read(CaptureState.activeScenePresetIdProvider);
    final nextId = active == sceneId ? null : sceneId;
    ref.read(CaptureState.activeScenePresetIdProvider.notifier).state = nextId;
    if (nextId == null) {
      CaptureState.applySceneFilter(ref, const SceneFilter(lut: 'none'));
      return;
    }

    final preset = ref
        .read(captureScenePresetsProvider)
        .value
        ?.firstWhere((scene) => scene.id == sceneId);
    if (preset != null) {
      CaptureState.applySceneFilter(ref, preset.filter);
      _reportSceneSelect(ref, sceneId, preset);
    }
  }

  /// 将当前选中场景移到列表第一位（不在列表内时保持原顺序）。
  List<ScenePreset> _moveActiveToFront(
    List<ScenePreset> presets,
    String? activeId,
  ) {
    if (activeId == null) return presets;
    final index = presets.indexWhere((scene) => scene.id == activeId);
    if (index <= 0) return presets;
    final result = [...presets];
    final item = result.removeAt(index);
    result.insert(0, item);
    return result;
  }

  Future<void> _reportSceneSelect(
    WidgetRef ref,
    String sceneId,
    ScenePreset preset,
  ) async {
    final isSystem = ScenePresetsData.getScenePreset(sceneId) != null;
    if (!isSystem && !preset.isCustom) return;
    try {
      final recorder = await ref.read(usageEventRecorderProvider.future);
      await recorder.recordScene(
        sceneId: sceneId,
        creator: isSystem ? 'system' : 'user',
        event: UsageEventType.sceneSelect,
      );
    } catch (_) {
      // 上报失败静默
    }
  }
}

class _SceneCard extends StatelessWidget {
  const _SceneCard({
    required this.preset,
    required this.width,
    required this.active,
    required this.visual,
    required this.onTap,
  });

  final ScenePreset preset;
  final double width;
  final bool active;
  final CaptureOverlayVisual visual;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cover = sceneCoverUrl(preset);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        selected: active,
        button: true,
        label: preset.name,
        child: Container(
          width: width,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: active
                ? Border.all(color: visual.accent, width: 2)
                : Border.all(color: visual.fillSubtle, width: 0.5),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: cover.isEmpty
                    ? Container(
                        color: visual.fillSubtle,
                        child: Icon(
                          Icons.place,
                          color:
                              active ? visual.accent : visual.foregroundMuted,
                          size: 24,
                        ),
                      )
                    : _buildCover(cover),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(6),
                      bottomRight: Radius.circular(6),
                    ),
                  ),
                  child: Text(
                    preset.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              if (active)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: visual.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: visual.onAccent,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCover(String url) {
    if (url.startsWith('data:')) {
      return Image.memory(
        UriData.parse(url).contentAsBytes(),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: visual.fillSubtle,
          child: Icon(
            Icons.place,
            color: visual.foregroundMuted,
            size: 24,
          ),
        ),
      );
    }
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: visual.fillSubtle,
          child: Icon(
            Icons.place,
            color: visual.foregroundMuted,
            size: 24,
          ),
        ),
      );
    }
    return CachedNetworkImage(
      url: url,
      fit: BoxFit.cover,
      errorWidget: Container(
        color: visual.fillSubtle,
        child: Icon(
          Icons.place,
          color: visual.foregroundMuted,
          size: 24,
        ),
      ),
    );
  }
}
