import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/capture_state.dart';
import '../domain/filter_recipe.dart';

/// 所有系统滤镜名称（与 filter_recipe.dart 中 systemFilterLabel 的 keys 一致）。
const _allSystemFilters = [
  'none',
  'vivid',
  'vivid_warm',
  'vivid_cool',
  'mono',
  'silver',
  'noir',
];

/// 所有 LUT 预设名称（与 filter_recipe.dart 中 lutLabel 的 keys 一致）。
const _allLuts = [
  'none',
  'cinematic',
  'vintage',
  'bw',
  'warm_film',
  'cool_film',
  'pastel',
  'fuji',
  'portrait',
  'japanese',
  'cyberpunk',
  'sepia_classic',
  'mist',
  'rouge',
  'twilight',
  'cyan',
];

/// 滤镜选择器：一个不可见的触发 widget。
/// 当 `filterPickerVisibleProvider` 变为 true 时，通过 post-frame callback
/// 弹出 `showModalBottomSheet` 显示系统滤镜和 LUT 预设的选择器。
/// 关闭时自动将 `filterPickerVisibleProvider` 重置为 false。
///
/// 注意：使用 post-frame callback 是为了避免在 build 阶段调用 showModalBottomSheet
/// （会触发 "setState was called during build" 错误）。
class FilterPicker extends ConsumerWidget {
  const FilterPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(CaptureState.filterPickerVisibleProvider);

    if (!visible) return const SizedBox.shrink();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final currentVisible = ref.read(CaptureState.filterPickerVisibleProvider);
      if (!currentVisible) return;
      _showSheet(context, ref);
    });

    return const SizedBox.shrink();
  }

  void _showSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2E),
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final raw = ref.watch(CaptureState.rawModeProvider);
          final editable = ref.watch(CaptureState.editableTemplateProvider);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '系统滤镜',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allSystemFilters.map((f) {
                    final active = editable?.postProcess.systemFilter == f ||
                        (f == 'none' && editable?.postProcess.systemFilter == null);
                    return ChoiceChip(
                      label: Text(
                        systemFilterLabel(f),
                        style: const TextStyle(color: Colors.white),
                      ),
                      selected: active,
                      onSelected: raw
                          ? null
                          : (_) {
                              final tpl = editable?.copyWith(
                                postProcess: editable.postProcess.copyWith(
                                  systemFilter: f == 'none' ? null : f,
                                ),
                              );
                              ref
                                  .read(CaptureState.editableTemplateProvider.notifier)
                                  .state = tpl;
                            },
                      backgroundColor: Colors.white12,
                      selectedColor: Colors.amber,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'LUT 预设',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allLuts.map((lut) {
                    final active = editable?.postProcess.lut == lut;
                    return ChoiceChip(
                      label: Text(
                        lutLabel(lut),
                        style: const TextStyle(color: Colors.white),
                      ),
                      selected: active,
                      onSelected: raw
                          ? null
                          : (_) {
                              final tpl = editable?.copyWith(
                                postProcess: editable.postProcess.copyWith(lut: lut),
                              );
                              ref
                                  .read(CaptureState.editableTemplateProvider.notifier)
                                  .state = tpl;
                            },
                      backgroundColor: Colors.white12,
                      selectedColor: Colors.amber,
                    );
                  }).toList(),
                ),
                if (raw)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'RAW 模式下不可用',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      ref.read(CaptureState.filterPickerVisibleProvider.notifier).state = false;
    });
  }
}
