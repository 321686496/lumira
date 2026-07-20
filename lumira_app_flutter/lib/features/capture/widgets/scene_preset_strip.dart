import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/capture_state.dart';
import '../data/scene_presets_data.dart';

/// 场景预设横向滚动条。
/// `compact=true` 显示前 6 个场景（底部条），`compact=false` 显示全部 18 个（展开面板）。
/// 点击场景卡片切换 `activeScenePresetIdProvider`。
///
/// 注意：`ScenePreset.icon` 是 phosphor 图标名（如 'ph-coffee'），但 Flutter 项目
/// 未集成 phosphor_flutter 包。此处用 `Icons.place` 作占位符，未来可替换为真实图标映射。
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
      height: compact ? 80 : 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: presets.length,
        itemBuilder: (ctx, i) {
          final preset = presets[i];
          final active = preset.id == activeId;
          return GestureDetector(
            onTap: () => ref
                .read(CaptureState.activeScenePresetIdProvider.notifier)
                .state = preset.id,
            child: Container(
              width: compact ? 60 : 72,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: active ? Border.all(color: Colors.amber, width: 2) : null,
                color: Colors.white12,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.place,
                    color: active ? Colors.amber : Colors.white54,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preset.name,
                    style: TextStyle(
                      color: active ? Colors.amber : Colors.white70,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
