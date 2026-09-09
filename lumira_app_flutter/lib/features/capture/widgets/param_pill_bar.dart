import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/capture_appearance.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/lumira/_internal/lumira_theme_resolver.dart';
import '../data/capture_state.dart';
import '../domain/photo_template.dart';
import 'apply_button.dart';
import 'raw_mode_toggle.dart';

/// 顶部参数 Pill 栏（双模式浮层胶囊）：横向滚动的 EV / WB / ISO 标签 + ApplyButton + RawModeToggle + 滤镜入口。
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
    // 双模式视觉：immersive=暗色胶囊 / theme=当前风格的叠照片浮层取向
    final visual = LumiraThemeResolver.captureOverlayVisual(
      tokens: ref.watch(themeTokensProvider),
      style: ref.watch(appThemeProvider).style,
      appearance: ref.watch(CaptureState.captureAppearanceProvider),
      role: CaptureOverlayRole.pill,
      radiusDp: 20,
    );

    final Widget capsule = Container(
      decoration: BoxDecoration(
        color: visual.background,
        borderRadius: BorderRadius.circular(20),
        border: visual.border,
        boxShadow: visual.shadows,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          children: [
            _Pill(
              text: _evDisplay(cam),
              onTap: () => _openPanel(ref),
              visual: visual,
            ),
            _Pill(
              text: _isoDisplay(cam),
              onTap: () => _openPanel(ref),
              visual: visual,
            ),
            const ApplyButton(),
            const RawModeToggle(),
          ].map((w) => Padding(padding: const EdgeInsets.only(right: 4), child: w)).toList(),
        ),
      ),
    );

    // backdropBlurSigma>0 才包毛玻璃；新拟态双轨下 sigma=0 直接呈现胶囊本体
    return visual.backdropBlurSigma > 0
        ? ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: visual.backdropBlurSigma,
                sigmaY: visual.backdropBlurSigma,
              ),
              child: capsule,
            ),
          )
        : capsule;
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
  final CaptureOverlayVisual visual;
  const _Pill({
    this.icon,
    this.text,
    required this.onTap,
    required this.visual,
  });

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
            if (icon != null) Icon(icon, size: 12, color: visual.foreground),
            if (icon != null && text != null) const SizedBox(width: 4),
            if (text != null)
              Text(
                text!,
                style: TextStyle(color: visual.foreground, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}
