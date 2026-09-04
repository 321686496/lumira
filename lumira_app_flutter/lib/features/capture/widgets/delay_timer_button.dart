import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../data/capture_state.dart';

/// 延迟拍照按钮（iOS 原相机风格）
///
/// 取景器顶部居中的小号圆形「时钟」图标按钮。点按弹出锚定气泡菜单
/// （关闭 / 3s / 5s / 10s）。选中后高亮并显示所选秒数角标。
/// 视觉遵循项目「叠照片浮层」取向：半透明暗底 + 细描边，无 blur、无外阴影；
/// 激活态强调色统一用半球胶囊强调色 0xFFC9A96E。
class DelayTimerButton extends ConsumerWidget {
  const DelayTimerButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final delay = ref.watch(CaptureState.delayTimerProvider);
    final isActive = delay > 0;
    final isNeu = ref.watch(appThemeProvider).style == UIStyle.neumorphic;

    final Widget capsule = GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF141416).withOpacity(0.72),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.timer_outlined,
              size: 20,
              color: isActive ? const Color(0xFFC9A96E) : Colors.white,
            ),
            if (isActive)
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: const BoxDecoration(
                    color: Color(0xFFC9A96E),
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  child: Text(
                    '${delay}s',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
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
      color: const Color(0xFF26262A),
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
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                if (d == delay) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check, size: 16, color: Color(0xFFC9A96E)),
                ],
              ],
            ),
          ),
      ],
      child: isNeu ? capsule : capsule,
    );
  }
}