import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/capture_appearance.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/lumira/_internal/lumira_theme_resolver.dart';
import '../data/capture_state.dart';

/// 照片比例切换器（双模式浮层胶囊）
///
/// 在取景器顶部显示，用户可切换：
/// - 全屏（与取景器显示一致，9:16 或 16:9）
/// - 4:3（标准相机比例）
/// - 1:1（正方形）
///
/// 切换后取景器会显示对应比例的遮罩区域，
/// 拍照后的照片按此比例裁剪。
class AspectRatioSelector extends ConsumerWidget {
  const AspectRatioSelector({super.key});

  static const _options = <_AspectRatioOption>[
    _AspectRatioOption(id: 'fullscreen', label: '全屏', icon: Icons.fullscreen),
    _AspectRatioOption(id: '4:3', label: '4:3', icon: Icons.crop_3_2),
    _AspectRatioOption(id: '1:1', label: '1:1', icon: Icons.crop_square),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(CaptureState.aspectRatioProvider);
    // 双模式视觉：immersive=暗色胶囊 / theme=当前风格的叠照片浮层取向
    final visual = LumiraThemeResolver.captureOverlayVisual(
      tokens: ref.watch(themeTokensProvider),
      style: ref.watch(appThemeProvider).style,
      appearance: ref.watch(CaptureState.captureAppearanceProvider),
      role: CaptureOverlayRole.pill,
      radiusDp: 20,
    );

    final Widget capsule = Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: visual.background,
        borderRadius: BorderRadius.circular(20),
        border: visual.border,
        boxShadow: visual.shadows,
      ),
      child: Row(
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: active ? visual.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
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
                  Icon(
                    opt.icon,
                    size: 12,
                    color:
                        active ? visual.onAccent : visual.foregroundSecondary,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    opt.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color:
                          active ? visual.onAccent : visual.foregroundSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
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
}

class _AspectRatioOption {
  final String id;
  final String label;
  final IconData icon;
  const _AspectRatioOption({
    required this.id,
    required this.label,
    required this.icon,
  });
}
