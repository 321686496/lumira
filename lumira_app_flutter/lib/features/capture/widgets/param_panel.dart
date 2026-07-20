import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/capture_state.dart';
import '../domain/photo_template.dart';

/// 底部抽屉式参数编辑面板。
/// 5 个 Tab：相机 / 色彩 / 细节 / 构图 / 场景。
/// 通过 panelExpandedProvider 控制展开/收起（AnimatedPositioned）。
class ParamPanel extends ConsumerWidget {
  const ParamPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(CaptureState.panelExpandedProvider);
    final editable = ref.watch(CaptureState.editableTemplateProvider);
    final original = ref.watch(CaptureState.originalTemplateProvider);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      left: 0,
      right: 0,
      bottom: expanded ? 0 : -400,
      height: 400,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // 拖动条
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white38,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Tab 切换 + 内容
            Expanded(
              child: DefaultTabController(
                length: 5,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: '相机'),
                        Tab(text: '色彩'),
                        Tab(text: '细节'),
                        Tab(text: '构图'),
                        Tab(text: '场景'),
                      ],
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white54,
                      indicatorColor: Colors.amber,
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _CameraTab(),
                          _ColorTab(),
                          _DetailTab(),
                          _CompositionTab(),
                          _SceneTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 底部"应用模板参数"按钮：仅当有模板且 editable 与 original 不一致时显示
            // （appliedProvider 为 true 时不显示，但这里简化为 editable != null && original != null）
            if (editable != null && original != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () {
                      ref
                          .read(CaptureState.editableTemplateProvider.notifier)
                          .state = original.copyWith();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                    child: const Text(
                      '应用模板参数',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
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

// ─────────────────────────────────────────────────────────────────────
// 相机 Tab：EV / ISO / 快门 / 白平衡 / 闪光 / 对焦
// ─────────────────────────────────────────────────────────────────────
class _CameraTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editable = ref.watch(CaptureState.editableTemplateProvider);
    final cam = editable?.camera ?? const CameraParams();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _SliderRow(
          label: 'EV',
          value: cam.exposureCompensation,
          min: -3.0,
          max: 3.0,
          divisions: 120,
          display:
              '${cam.exposureCompensation >= 0 ? '+' : ''}${cam.exposureCompensation.toStringAsFixed(1)}',
          onChanged: (v) {
            final tpl = editable!.copyWith(
              camera: cam.copyWith(exposureCompensation: v),
            );
            ref.read(CaptureState.editableTemplateProvider.notifier).state = tpl;
          },
        ),
        _SliderRow(
          label: 'ISO',
          value: cam.iso.toDouble(),
          min: 100,
          max: 6400,
          divisions: 63,
          display: cam.iso.toString(),
          onChanged: (v) {
            final tpl = editable!.copyWith(camera: cam.copyWith(iso: v.round()));
            ref.read(CaptureState.editableTemplateProvider.notifier).state = tpl;
          },
        ),
        _DropdownRow(
          label: '快门',
          value: cam.shutterSpeed,
          items: const ['1/30', '1/60', '1/125', '1/200', '1/500', '1/1000'],
          onChanged: (v) {
            final tpl = editable!.copyWith(camera: cam.copyWith(shutterSpeed: v));
            ref.read(CaptureState.editableTemplateProvider.notifier).state = tpl;
          },
        ),
        _DropdownRow(
          label: '白平衡',
          value: cam.whiteBalance,
          items: const ['daylight', 'cloudy', 'shade', 'tungsten', 'fluorescent', 'custom'],
          displayLabels: const {
            'daylight': '日光',
            'cloudy': '阴天',
            'shade': '阴影',
            'tungsten': '白炽灯',
            'fluorescent': '荧光',
            'custom': '自定义',
          },
          onChanged: (v) {
            final tpl = editable!.copyWith(camera: cam.copyWith(whiteBalance: v));
            ref.read(CaptureState.editableTemplateProvider.notifier).state = tpl;
          },
        ),
        _DropdownRow(
          label: '闪光',
          value: cam.flashMode,
          items: const ['off', 'on', 'auto', 'torch'],
          onChanged: (v) {
            final tpl = editable!.copyWith(camera: cam.copyWith(flashMode: v));
            ref.read(CaptureState.editableTemplateProvider.notifier).state = tpl;
          },
        ),
        _DropdownRow(
          label: '对焦',
          value: cam.focusMode,
          items: const ['auto', 'manual', 'continuous'],
          onChanged: (v) {
            final tpl = editable!.copyWith(camera: cam.copyWith(focusMode: v));
            ref.read(CaptureState.editableTemplateProvider.notifier).state = tpl;
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 色彩 Tab：亮度 / 对比度 / 饱和度 / 色温 / 色调 / 高光 / 阴影 / 黑点 / 鲜明度 / 明度
// 写入 PostProcessColor（通过 PostProcess.copyWith(color: ...)）
// ─────────────────────────────────────────────────────────────────────
class _ColorTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editable = ref.watch(CaptureState.editableTemplateProvider);
    final color = editable?.postProcess.color ?? const PostProcessColor();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _SliderRow(
          label: '亮度',
          value: color.brightness,
          min: -100,
          max: 100,
          divisions: 200,
          display: color.brightness.toStringAsFixed(0),
          onChanged: (v) => _setColor(ref, editable, (c) => c.copyWith(brightness: v)),
        ),
        _SliderRow(
          label: '对比度',
          value: color.contrast,
          min: -100,
          max: 100,
          divisions: 200,
          display: color.contrast.toStringAsFixed(0),
          onChanged: (v) => _setColor(ref, editable, (c) => c.copyWith(contrast: v)),
        ),
        _SliderRow(
          label: '饱和度',
          value: color.saturation,
          min: -100,
          max: 100,
          divisions: 200,
          display: color.saturation.toStringAsFixed(0),
          onChanged: (v) => _setColor(ref, editable, (c) => c.copyWith(saturation: v)),
        ),
        _SliderRow(
          label: '色温',
          value: color.temperature,
          min: -100,
          max: 100,
          divisions: 200,
          display: color.temperature.toStringAsFixed(0),
          onChanged: (v) => _setColor(ref, editable, (c) => c.copyWith(temperature: v)),
        ),
        _SliderRow(
          label: '色调',
          value: color.tint,
          min: -100,
          max: 100,
          divisions: 200,
          display: color.tint.toStringAsFixed(0),
          onChanged: (v) => _setColor(ref, editable, (c) => c.copyWith(tint: v)),
        ),
        _SliderRow(
          label: '高光',
          value: color.highlights ?? 0,
          min: -100,
          max: 100,
          divisions: 200,
          display: (color.highlights ?? 0).toStringAsFixed(0),
          onChanged: (v) => _setColor(ref, editable, (c) => c.copyWith(highlights: v)),
        ),
        _SliderRow(
          label: '阴影',
          value: color.shadows ?? 0,
          min: -100,
          max: 100,
          divisions: 200,
          display: (color.shadows ?? 0).toStringAsFixed(0),
          onChanged: (v) => _setColor(ref, editable, (c) => c.copyWith(shadows: v)),
        ),
        _SliderRow(
          label: '黑点',
          value: color.blackPoint ?? 0,
          min: -100,
          max: 100,
          divisions: 200,
          display: (color.blackPoint ?? 0).toStringAsFixed(0),
          onChanged: (v) => _setColor(ref, editable, (c) => c.copyWith(blackPoint: v)),
        ),
        _SliderRow(
          label: '鲜明度',
          value: color.vibrance ?? 0,
          min: -100,
          max: 100,
          divisions: 200,
          display: (color.vibrance ?? 0).toStringAsFixed(0),
          onChanged: (v) => _setColor(ref, editable, (c) => c.copyWith(vibrance: v)),
        ),
        _SliderRow(
          label: '明度',
          value: color.brilliance ?? 0,
          min: -100,
          max: 100,
          divisions: 200,
          display: (color.brilliance ?? 0).toStringAsFixed(0),
          onChanged: (v) => _setColor(ref, editable, (c) => c.copyWith(brilliance: v)),
        ),
      ],
    );
  }

  static void _setColor(
    WidgetRef ref,
    PhotoTemplate? editable,
    PostProcessColor Function(PostProcessColor) updater,
  ) {
    if (editable == null) return;
    final newColor = updater(editable.postProcess.color);
    final newPost = editable.postProcess.copyWith(color: newColor);
    ref.read(CaptureState.editableTemplateProvider.notifier).state =
        editable.copyWith(postProcess: newPost);
  }
}

// ─────────────────────────────────────────────────────────────────────
// 细节 Tab：清晰度 (clarity) / 锐化 (sharpen) / 磨皮 (smoothStrength) / 暗角 (vignette) / 颗粒 (grain)
// clarity 在 PostProcessColor 上，其他 4 个在 PostProcess 上
// ─────────────────────────────────────────────────────────────────────
class _DetailTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editable = ref.watch(CaptureState.editableTemplateProvider);
    final post = editable?.postProcess ?? const PostProcess(color: PostProcessColor());
    final color = post.color;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _SliderRow(
          label: '清晰度',
          value: color.clarity ?? 0,
          min: 0,
          max: 100,
          divisions: 100,
          display: (color.clarity ?? 0).toStringAsFixed(0),
          onChanged: (v) {
            if (editable == null) return;
            final newColor = color.copyWith(clarity: v);
            final newPost = editable.postProcess.copyWith(color: newColor);
            ref.read(CaptureState.editableTemplateProvider.notifier).state =
                editable.copyWith(postProcess: newPost);
          },
        ),
        _SliderRow(
          label: '锐化',
          value: post.sharpen.toDouble(),
          min: 0,
          max: 100,
          divisions: 100,
          display: post.sharpen.toString(),
          onChanged: (v) {
            if (editable == null) return;
            final newPost = editable.postProcess.copyWith(sharpen: v.round());
            ref.read(CaptureState.editableTemplateProvider.notifier).state =
                editable.copyWith(postProcess: newPost);
          },
        ),
        _SliderRow(
          label: '磨皮',
          value: post.smoothStrength.toDouble(),
          min: 0,
          max: 100,
          divisions: 100,
          display: post.smoothStrength.toString(),
          onChanged: (v) {
            if (editable == null) return;
            final newPost = editable.postProcess.copyWith(smoothStrength: v.round());
            ref.read(CaptureState.editableTemplateProvider.notifier).state =
                editable.copyWith(postProcess: newPost);
          },
        ),
        _SliderRow(
          label: '暗角',
          value: post.vignette.toDouble(),
          min: 0,
          max: 100,
          divisions: 100,
          display: post.vignette.toString(),
          onChanged: (v) {
            if (editable == null) return;
            final newPost = editable.postProcess.copyWith(vignette: v.round());
            ref.read(CaptureState.editableTemplateProvider.notifier).state =
                editable.copyWith(postProcess: newPost);
          },
        ),
        _SliderRow(
          label: '颗粒',
          value: post.grain.toDouble(),
          min: 0,
          max: 100,
          divisions: 100,
          display: post.grain.toString(),
          onChanged: (v) {
            if (editable == null) return;
            final newPost = editable.postProcess.copyWith(grain: v.round());
            ref.read(CaptureState.editableTemplateProvider.notifier).state =
                editable.copyWith(postProcess: newPost);
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 构图 Tab：叠图类型选择器 + 透明度滑块
// ─────────────────────────────────────────────────────────────────────
class _CompositionTab extends ConsumerWidget {
  static const _overlayTypes = {
    'rule_of_thirds': '三分法',
    'golden_ratio': '黄金比例',
    'center': '居中',
    'diagonal': '对角线',
    'symmetry': '对称',
    'none': '无',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editable = ref.watch(CaptureState.editableTemplateProvider);
    final comp = editable?.composition ?? const Composition();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _DropdownRow(
          label: '构图类型',
          value: comp.overlayType,
          items: _overlayTypes.keys.toList(),
          displayLabels: _overlayTypes,
          onChanged: (v) {
            if (editable == null) return;
            final newComp = editable.composition.copyWith(overlayType: v);
            ref.read(CaptureState.editableTemplateProvider.notifier).state =
                editable.copyWith(composition: newComp);
          },
        ),
        _SliderRow(
          label: '透明度',
          value: comp.opacity,
          min: 0,
          max: 1,
          divisions: 100,
          display: '${(comp.opacity * 100).round()}%',
          onChanged: (v) {
            if (editable == null) return;
            final newComp = editable.composition.copyWith(opacity: v);
            ref.read(CaptureState.editableTemplateProvider.notifier).state =
                editable.copyWith(composition: newComp);
          },
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            comp.description.isEmpty ? '（此模板无构图说明）' : comp.description,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 场景 Tab：场景指南文本预览（只读）
// ─────────────────────────────────────────────────────────────────────
class _SceneTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editable = ref.watch(CaptureState.editableTemplateProvider);
    final sg = editable?.sceneGuide ?? const SceneGuide();

    final rows = <MapEntry<String, String>>[
      MapEntry('光线方向', sg.lightDirection),
      MapEntry('拍摄距离', sg.shootingDistance),
      MapEntry('背景建议', sg.background),
      MapEntry('最佳时段', sg.bestTime),
      if (sg.bestTimeFrom != null && sg.bestTimeTo != null)
        MapEntry('时段范围', '${sg.bestTimeFrom} - ${sg.bestTimeTo}'),
      if (sg.presetId != null) MapEntry('场景预设', sg.presetId!),
      if (sg.props.isNotEmpty) MapEntry('推荐道具', sg.props.join('、')),
      if (sg.tips.isNotEmpty) MapEntry('拍摄贴士', sg.tips.join('\n• ')),
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    row.key,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Text(
                    row.value.isEmpty ? '—' : row.value,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────
class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              label: display,
              activeColor: Colors.amber,
              inactiveColor: Colors.white24,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              display,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownRow extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final Map<String, String>? displayLabels;
  final ValueChanged<String> onChanged;
  const _DropdownRow({
    required this.label,
    required this.value,
    required this.items,
    this.displayLabels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
          Expanded(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : null,
              dropdownColor: const Color(0xFF1C1C1E),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              underline: Container(height: 1, color: Colors.white24),
              isExpanded: true,
              items: items
                  .map((v) => DropdownMenuItem(
                        value: v,
                        child: Text(displayLabels?[v] ?? v),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}
