import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/capture_state.dart';
import '../data/scene_presets_data.dart';

/// 场景预设横向滚动条。
/// `compact=true` 显示前 6 个场景（底部条），`compact=false` 显示全部 18 个（展开面板）。
/// 点击场景卡片切换 `activeScenePresetIdProvider`，并通过 `activeSceneFilterProvider`
/// 自动套用滤镜到取景器（修复 Bug 3）。
///
/// 修复 Bug 3：使用 ScenePreset.exampleImages 第一张作为封面图，选中后显示完整信息
class ScenePresetStrip extends ConsumerWidget {
  final bool compact;
  const ScenePresetStrip({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeId = ref.watch(CaptureState.activeScenePresetIdProvider);
    final presets = compact
        ? ScenePresetsData.allScenePresets.take(6).toList()
        : ScenePresetsData.allScenePresets;

    return SizedBox(
      height: compact ? 80 : 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: presets.length,
        itemBuilder: (ctx, i) {
          final preset = presets[i];
          final active = preset.id == activeId;
          final cover = preset.exampleImages.isNotEmpty
              ? preset.exampleImages.first
              : '';

          return GestureDetector(
            onTap: () {
              // 切换场景预设（activeSceneFilterProvider 会自动派生并应用到取景器）
              ref.read(CaptureState.activeScenePresetIdProvider.notifier).state =
                  preset.id;
              // 选中场景后，把对应的 LUT 和 systemFilter 同步到 freeModePostProcess
              // 这样即使无模板，取景器也会应用场景滤镜
              final currentPost = ref.read(
                  CaptureState.freeModePostProcessProvider);
              ref.read(CaptureState.freeModePostProcessProvider.notifier).state =
                  currentPost.copyWith(
                lut: preset.filter.lut,
                systemFilter: preset.filter.systemFilter,
              );
              // 如果有模板，也同步到 editableTemplate
              final editable = ref.read(CaptureState.editableTemplateProvider);
              if (editable != null) {
                ref.read(CaptureState.editableTemplateProvider.notifier).state =
                    editable.copyWith(
                  postProcess: editable.postProcess.copyWith(
                    lut: preset.filter.lut,
                    systemFilter: preset.filter.systemFilter,
                  ),
                );
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: compact ? 60 : 72,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: active
                    ? Border.all(color: Colors.amber, width: 2)
                    : Border.all(color: Colors.white12, width: 0.5),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 封面图
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: cover.isEmpty
                        ? Container(
                            color: Colors.white12,
                            child: Icon(
                              Icons.place,
                              color: active ? Colors.amber : Colors.white54,
                              size: 24,
                            ),
                          )
                        : Image.network(
                            cover,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.white12,
                              child: Icon(
                                Icons.place,
                                color: active ? Colors.amber : Colors.white54,
                                size: 24,
                              ),
                            ),
                          ),
                  ),
                  // 渐变遮罩，确保文字清晰
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
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
                  // 选中标记
                  if (active)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.black,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
