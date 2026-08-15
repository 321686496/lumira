import 'package:flutter/material.dart';

/// 共享后处理滑块行：细线轨道（3px）+ 圆形把手（16px，命中区域 24x24）+ 品牌色填充
/// 用 LayoutBuilder + Stack 实现，支持拖拽（onPanStart + onPanUpdate）。
///
/// 拍摄页（ParamPanel）与预览/后期修图页（PreviewEditPanel）共用此组件，统一两处观感。
/// 修复要点：使用绝对位置（details.localPosition.dx）而非增量（delta.dx），
/// 避免多次 pan 事件共用过时 t 导致拖拽不灵敏；移除重复的轨道 GestureDetector。
class PostProcessSliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  /// 可选提示文字（如"导出后生效"），显示在滑块下方。
  final String? hint;

  const PostProcessSliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final slider = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 标签宽 64 + 数值宽 32，剩余为轨道宽度
          const labelWidth = 64.0;
          const valueWidth = 32.0;
          final trackWidth =
              (constraints.maxWidth - labelWidth - valueWidth).clamp(0.0, double.infinity);
          final t = ((value - min) / (max - min)).clamp(0.0, 1.0);
          final thumbX = labelWidth + (trackWidth * t);

          // 整体高度 32，把手 16px，垂直居中
          const rowHeight = 32.0;
          const thumbSize = 16.0;
          const trackHeight = 3.0;
          const trackTop = (rowHeight - trackHeight) / 2;

          // 绝对位置计算：将 localPosition.dx（相对 Stack 左上角）映射到轨道比例
          void updateFromLocal(double localDx) {
            if (trackWidth <= 0) return;
            final localX = localDx - labelWidth;
            final newT = (localX / trackWidth).clamp(0.0, 1.0);
            onChanged(min + newT * (max - min));
          }

          return SizedBox(
            height: rowHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) =>
                  updateFromLocal(details.localPosition.dx),
              onPanUpdate: (details) =>
                  updateFromLocal(details.localPosition.dx),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 标签
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: labelWidth,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        label,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white70),
                      ),
                    ),
                  ),
                  // 轨道背景
                  Positioned(
                    left: labelWidth,
                    right: valueWidth,
                    top: trackTop,
                    height: trackHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // 已填充部分
                  Positioned(
                    left: labelWidth,
                    top: trackTop,
                    width: (trackWidth * t).clamp(0.0, trackWidth),
                    height: trackHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5C07B),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // 把手（纯视觉，手势由外层 GestureDetector 统一处理）
                  Positioned(
                    left: thumbX - thumbSize / 2,
                    top: (rowHeight - thumbSize) / 2,
                    child: Container(
                      width: thumbSize,
                      height: thumbSize,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x44000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 数值
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: valueWidth,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        value.toStringAsFixed(0),
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white54),
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

    if (hint == null) return slider;
    // 有 hint 时在滑块下方显示提示文字
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        slider,
        Padding(
          padding: const EdgeInsets.only(left: 64, bottom: 2),
          child: Text(
            hint!,
            style: const TextStyle(fontSize: 9, color: Colors.white38),
          ),
        ),
      ],
    );
  }
}