import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/capture_appearance.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/lumira/_internal/lumira_theme_resolver.dart';
import '../data/capture_state.dart';

/// 延迟拍照按钮（iOS 原相机风格）
///
/// 取景器顶部居中的小号圆形「时钟」图标按钮。点按弹出锚定气泡菜单
/// （关闭 / 3s / 5s / 10s）。选中后高亮并显示所选秒数角标。
/// 双模式视觉：immersive=暗底金强调 / theme=当前风格的叠照片浮层取向。
class DelayTimerButton extends ConsumerWidget {
  const DelayTimerButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final delay = ref.watch(CaptureState.delayTimerProvider);
    final isActive = delay > 0;
    final isThemed =
        ref.watch(CaptureState.captureAppearanceProvider) ==
            CaptureAppearance.theme;
    final tokens = ref.watch(themeTokensProvider);
    // 双模式视觉：immersive=暗色圆钮 / theme=当前风格的叠照片浮层取向
    final visual = LumiraThemeResolver.captureOverlayVisual(
      tokens: tokens,
      style: ref.watch(appThemeProvider).style,
      appearance: ref.watch(CaptureState.captureAppearanceProvider),
      role: CaptureOverlayRole.pill,
      radiusDp: 22,
    );

    final Widget capsule = GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: visual.background,
          border: visual.border,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.timer_outlined,
              size: 20,
              color: isActive ? visual.accent : visual.foreground,
            ),
            if (isActive)
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: visual.accent,
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                  ),
                  child: Text(
                    '${delay}s',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: visual.onAccent,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return PopupMenuButton<int>(
      tooltip: '延迟拍照',
      onSelected: (v) =>
          ref.read(CaptureState.delayTimerProvider.notifier).state = v,
      // 菜单底：immersive=暗底 / theme=主题 surface
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
      child: capsule,
    );
  }
}
