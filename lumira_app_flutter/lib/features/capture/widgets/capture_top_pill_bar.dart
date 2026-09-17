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

/// 拍摄页顶部合并参数胶囊条：延时 / 取景比例 / EV / 应用 / RAW 统一为一行。
///
/// 取代原先纵向堆叠的独立胶囊（DelayTimerButton + AspectRatioSelector + ParamPillBar），
/// 用一个胶囊外壳、分段式竖分隔线呈现，显著压缩顶部浮层的垂直占位。
///
/// 全屏 / 试用模式下整条隐藏。
class CaptureTopPillBar extends ConsumerWidget {
  const CaptureTopPillBar({super.key});

  String _evDisplay(CameraParams c) {
    final ev = c.exposureCompensation;
    return ev == 0 ? 'EV 0' : 'EV ${ev >= 0 ? '+' : ''}${ev.toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cam = ref.watch(CaptureState.effectiveCameraProvider);
    // 双模式视觉：immersive=暗色胶囊 / theme=当前风格的叠照片浮层取向
    final visual = LumiraThemeResolver.captureOverlayVisual(
      tokens: ref.watch(themeTokensProvider),
      style: ref.watch(appThemeProvider).style,
      appearance: ref.watch(CaptureState.captureAppearanceProvider),
      role: CaptureOverlayRole.pill,
      radiusDp: 18,
    );

    Widget divider() => Container(
          width: 1,
          height: 16,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          color: visual.foreground.withOpacity(0.14),
        );

    final Widget capsule = Container(
      decoration: BoxDecoration(
        color: visual.background,
        borderRadius: BorderRadius.circular(18),
        border: visual.border,
        boxShadow: visual.shadows,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Row(
          children: [
            _DelaySegment(visual: visual),
            divider(),
            _AspectSegment(visual: visual),
            divider(),
            _Pill(
              text: _evDisplay(cam),
              onTap: () => _openPanel(ref),
              visual: visual,
            ),
            const SizedBox(width: 2),
            const ApplyButton(),
            const RawModeToggle(),
          ],
        ),
      ),
    );

    // backdropBlurSigma>0 才包毛玻璃；新拟态双轨下 sigma=0 直接呈现胶囊本体
    return visual.backdropBlurSigma > 0
        ? ClipRRect(
            borderRadius: BorderRadius.circular(18),
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

/// 延时场景：紧凑分段（时钟图标 + 已选秒数），点按弹出 关闭/3s/5s/10s 菜单。
class _DelaySegment extends ConsumerWidget {
  final CaptureOverlayVisual visual;
  const _DelaySegment({required this.visual});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final delay = ref.watch(CaptureState.delayTimerProvider);
    final isActive = delay > 0;
    final isThemed =
        ref.watch(CaptureState.captureAppearanceProvider) ==
            CaptureAppearance.theme;
    final tokens = ref.watch(themeTokensProvider);

    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: isActive ? visual.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 13,
            color: isActive ? visual.onAccent : visual.foreground,
          ),
          if (isActive) ...[
            const SizedBox(width: 3),
            Text(
              '${delay}s',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: visual.onAccent,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );

    return PopupMenuButton<int>(
      tooltip: '延迟拍照',
      onSelected: (v) =>
          ref.read(CaptureState.delayTimerProvider.notifier).state = v,
      color: isThemed ? tokens.surface : const Color(0xFF26262A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      offset: const Offset(0, -6),
      itemBuilder: (context) => [
        for (final d in CaptureState.delayOptions)
          PopupMenuItem(
            value: d,
            height: 40,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  d == 0 ? '关闭' : '$d秒',
                  style: TextStyle(
                    color: isThemed ? tokens.textPrimary : Colors.white,
                    fontSize: 14,
                  ),
                ),
                if (d == delay) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check, size: 16, color: visual.accent),
                ],
              ],
            ),
          ),
      ],
      child: child,
    );
  }
}

/// 取景比例：全屏 / 4:3 / 1:1 紧凑分段。
class _AspectSegment extends ConsumerWidget {
  final CaptureOverlayVisual visual;
  const _AspectSegment({required this.visual});

  static const _options = <_AspectOption>[
    _AspectOption(id: 'fullscreen', label: '全屏', icon: Icons.fullscreen),
    _AspectOption(id: '4:3', label: '4:3', icon: Icons.crop_3_2),
    _AspectOption(id: '1:1', label: '1:1', icon: Icons.crop_square),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(CaptureState.aspectRatioProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _options.map((opt) {
        final active = opt.id == current;
        return GestureDetector(
          onTap: () {
            ref.read(CaptureState.aspectRatioProvider.notifier).state = opt.id;
            CaptureState.persistAspectRatio(
                ProviderScope.containerOf(context, listen: false), opt.id);
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: active ? visual.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: visual.accent.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(opt.icon,
                    size: 12,
                    color: active
                        ? visual.onAccent
                        : visual.foregroundSecondary),
                const SizedBox(width: 3),
                Text(
                  opt.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active
                        ? visual.onAccent
                        : visual.foregroundSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final CaptureOverlayVisual visual;
  const _Pill({
    required this.text,
    required this.onTap,
    required this.visual,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          text,
          style: TextStyle(color: visual.foreground, fontSize: 11),
        ),
      ),
    );
  }
}

class _AspectOption {
  final String id;
  final String label;
  final IconData icon;
  const _AspectOption({
    required this.id,
    required this.label,
    required this.icon,
  });
}