import 'package:flutter/material.dart';
import '../domain/photo_template.dart';
import 'post_process_slider_row.dart';

/// 共享细节编辑 Tab（受控纯展示）。
///
/// 接收全量 [PostProcess]，UI 只读字段并通过 [onChanged] 回调新的全量值。
/// 全量↔增量换算由上层负责（PreviewEditPanel 用 deltaOf，ParamPanel 用
/// CaptureState.updatePostProcess），本组件不感知 baked 基线。
class PostProcessDetailTab extends StatelessWidget {
  final PostProcess full;
  final ValueChanged<PostProcess> onChanged;

  const PostProcessDetailTab({
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
          label: '清晰度',
          value: c.clarity ?? 0,
          min: -100,
          max: 100,
          onChanged: (v) => onChanged(full.copyWith(
            color: c.copyWith(clarity: v),
          )),
        ),
        PostProcessSliderRow(
          label: '锐化',
          value: full.sharpen.toDouble(),
          min: 0,
          max: 100,
          hint: '导出后生效',
          onChanged: (v) => onChanged(full.copyWith(sharpen: v.round())),
        ),
        PostProcessSliderRow(
          label: '磨皮',
          value: full.smoothStrength.toDouble(),
          min: 0,
          max: 100,
          hint: '导出后生效',
          onChanged: (v) =>
              onChanged(full.copyWith(smoothStrength: v.round())),
        ),
        PostProcessSliderRow(
          label: '晕影',
          value: full.vignette.toDouble(),
          min: 0,
          max: 100,
          onChanged: (v) => onChanged(full.copyWith(vignette: v.round())),
        ),
        PostProcessSliderRow(
          label: '颗粒',
          value: full.grain.toDouble(),
          min: 0,
          max: 100,
          onChanged: (v) => onChanged(full.copyWith(grain: v.round())),
        ),
      ],
    );
  }
}