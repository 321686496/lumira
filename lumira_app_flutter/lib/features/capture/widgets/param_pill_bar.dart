import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../data/capture_state.dart';
import '../domain/photo_template.dart';
import 'apply_button.dart';
import 'raw_mode_toggle.dart';

/// 顶部参数 Pill 栏（毛玻璃胶囊设计）：横向滚动的 EV / WB / ISO 标签 + ApplyButton + RawModeToggle + 滤镜入口。
///
/// 修复 Bug 2：自由拍摄模式（无模板）下也显示此栏，通过 effectiveCameraProvider
/// 读取统一的相机参数，使自由模式也能打开参数面板和滤镜选择器
class ParamPillBar extends ConsumerWidget {
  const ParamPillBar({super.key});

  String _evDisplay(CameraParams c) {
    final ev = c.exposureCompensation;
    return ev == 0 ? 'EV 0' : 'EV ${ev >= 0 ? '+' : ''}${ev.toStringAsFixed(1)}';
  }

  String _isoDisplay(CameraParams c) {
    return 'ISO ${c.isoMode == 'manual' ? c.iso.toString() : 'Auto'}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 修复 Bug 2：使用 effectiveCameraProvider，自由模式下也能获取参数
    final cam = ref.watch(CaptureState.effectiveCameraProvider);
    // 新拟态双轨：叠在相机/动态画面上禁止 blur(毛玻璃)，退回半透明暗底浮层
    final isNeu = ref.watch(appThemeProvider).style == UIStyle.neumorphic;

    final Widget capsule = Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141416).withOpacity(0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          children: [
            _Pill(text: _evDisplay(cam), onTap: () => _openPanel(ref)),
            _Pill(text: _isoDisplay(cam), onTap: () => _openPanel(ref)),
            const ApplyButton(),
            const RawModeToggle(),
          ].map((w) => Padding(padding: const EdgeInsets.only(right: 4), child: w)).toList(),
        ),
      ),
    );

    // 新拟态不引入毛玻璃；其余风格保留玻璃胶囊
    return isNeu
        ? capsule
        : ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: capsule,
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
