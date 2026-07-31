import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/capture_state.dart';
import '../domain/photo_template.dart';
import 'apply_button.dart';
import 'raw_mode_toggle.dart';

/// 顶部参数 Pill 栏：横向滚动的 EV / WB / ISO 标签 + ApplyButton + RawModeToggle + 滤镜入口。
///
/// 修复 Bug 2：自由拍摄模式（无模板）下也显示此栏，通过 effectiveCameraProvider
/// 读取统一的相机参数，使自由模式也能打开参数面板和滤镜选择器
class ParamPillBar extends ConsumerWidget {
  const ParamPillBar({super.key});

  String _evDisplay(CameraParams c) {
    final ev = c.exposureCompensation;
    return ev == 0 ? 'EV 0' : 'EV ${ev >= 0 ? '+' : ''}${ev.toStringAsFixed(1)}';
  }

  String _wbDisplay(CameraParams c) {
    const labels = {
      'auto': '自动',
      'daylight': '日光',
      'cloudy': '阴天',
      'shade': '阴影',
      'tungsten': '白炽灯',
      'fluorescent': '荧光',
      'custom': '自定义',
    };
    return 'WB ${labels[c.whiteBalance] ?? c.whiteBalance}';
  }

  String _isoDisplay(CameraParams c) {
    return 'ISO ${c.isoMode == 'manual' ? c.iso.toString() : 'Auto'}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 修复 Bug 2：使用 effectiveCameraProvider，自由模式下也能获取参数
    final cam = ref.watch(CaptureState.effectiveCameraProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Pill(text: _evDisplay(cam), onTap: () => _openPanel(ref)),
          _Pill(text: _wbDisplay(cam), onTap: () => _openPanel(ref)),
          _Pill(text: _isoDisplay(cam), onTap: () => _openPanel(ref)),
          const ApplyButton(),
          const RawModeToggle(),
        ].map((w) => Padding(padding: const EdgeInsets.only(right: 8), child: w)).toList(),
      ),
    );
  }

  /// 打开参数面板
  void _openPanel(WidgetRef ref) {
    ref.read(CaptureState.panelExpandedProvider.notifier).state = true;
  }
}

class _Pill extends StatelessWidget {
  final IconData? icon;
  final String? text;
  final VoidCallback onTap;
  const _Pill({this.icon, this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Icon(icon, size: 12, color: Colors.white),
            if (icon != null && text != null) const SizedBox(width: 4),
            if (text != null)
              Text(
                text!,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}
