import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/capture_appearance.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/lumira/_internal/lumira_theme_resolver.dart';
import '../data/capture_state.dart';

/// RAW 模式切换开关：禁用所有滤镜和后期处理。
/// 激活时背景为强调色（immersive=金 / theme=brand），未激活时为弱底色。
class RawModeToggle extends ConsumerWidget {
  const RawModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final raw = ref.watch(CaptureState.rawModeProvider);
    // 双模式视觉：immersive=金色激活 / theme=当前主题 accent 与前景
    final visual = LumiraThemeResolver.captureOverlayVisual(
      tokens: ref.watch(themeTokensProvider),
      style: ref.watch(appThemeProvider).style,
      appearance: ref.watch(CaptureState.captureAppearanceProvider),
      role: CaptureOverlayRole.pill,
      radiusDp: 16,
    );
    return GestureDetector(
      onTap: () =>
          ref.read(CaptureState.rawModeProvider.notifier).state = !raw,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: raw ? visual.accent : visual.fillSubtle,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'RAW',
          style: TextStyle(
            color: raw ? visual.onAccent : visual.foregroundSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
