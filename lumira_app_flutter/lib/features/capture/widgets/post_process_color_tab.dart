import 'package:flutter/material.dart';
import '../domain/photo_template.dart';
import 'post_process_slider_row.dart';

/// 共享色彩编辑 Tab（受控纯展示）。
///
/// 接收全量 [PostProcess]，UI 只读字段并通过 [onChanged] 回调新的全量值。
/// 全量↔增量换算由上层负责（PreviewEditPanel 用 deltaOf，ParamPanel 用
/// CaptureState.updatePostProcess），本组件不感知 baked 基线。
class PostProcessColorTab extends StatelessWidget {
  final PostProcess full;
  final ValueChanged<PostProcess> onChanged;

  const PostProcessColorTab({
    super.key,
    required this.full,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = full.color;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      children: [
        PostProcessSliderRow(
          label: '亮度',
          value: c.brightness,
          min: -100,
          max: 100,
          onChanged: (v) => onChanged(full.copyWith(
            color: c.copyWith(brightness: v),
          )),
        ),
        PostProcessSliderRow(
          label: '对比度',
          value: c.contrast,
          min: -100,
          max: 100,
          onChanged: (v) => onChanged(full.copyWith(
            color: c.copyWith(contrast: v),
          )),
        ),
        PostProcessSliderRow(
          label: '饱和度',
          value: c.saturation,
          min: -100,
          max: 100,
          onChanged: (v) => onChanged(full.copyWith(
            color: c.copyWith(saturation: v),
          )),
        ),
        PostProcessSliderRow(
          label: '色温',
          value: c.temperature,
          min: -100,
          max: 100,
          onChanged: (v) => onChanged(full.copyWith(
            color: c.copyWith(temperature: v),
          )),
        ),
        PostProcessSliderRow(
          label: '色调',
          value: c.tint,
          min: -100,
          max: 100,
          onChanged: (v) => onChanged(full.copyWith(
            color: c.copyWith(tint: v),
          )),
        ),
        PostProcessSliderRow(
          label: '高光',
          value: c.highlights ?? 0,
          min: -100,
          max: 100,
          onChanged: (v) => onChanged(full.copyWith(
            color: c.copyWith(highlights: v),
          )),
        ),
        PostProcessSliderRow(
          label: '阴影',
          value: c.shadows ?? 0,
          min: -100,
          max: 100,
          onChanged: (v) => onChanged(full.copyWith(
            color: c.copyWith(shadows: v),
          )),
        ),
        PostProcessSliderRow(
          label: '黑点',
          value: c.blackPoint ?? 0,
          min: -100,
          max: 100,
          onChanged: (v) => onChanged(full.copyWith(
            color: c.copyWith(blackPoint: v),
          )),
        ),
        PostProcessSliderRow(
          label: '自然饱和度',
          value: c.vibrance ?? 0,
          min: -100,
          max: 100,
          onChanged: (v) => onChanged(full.copyWith(
            color: c.copyWith(vibrance: v),
          )),
        ),
        PostProcessSliderRow(
          label: '明亮度',
          value: c.brilliance ?? 0,
          min: -100,
          max: 100,
          onChanged: (v) => onChanged(full.copyWith(
            color: c.copyWith(brilliance: v),
          )),
        ),
      ],
    );
  }
}