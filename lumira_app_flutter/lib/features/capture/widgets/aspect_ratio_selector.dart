import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../data/capture_state.dart';

/// 照片比例切换器（毛玻璃胶囊设计）
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
    final tokens = ref.watch(themeTokensProvider);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
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
              BoxShadow(
                color: Colors.white.withOpacity(0.04),
                blurRadius: 1,
                offset: const Offset(0, 0.5),
              ),
            ],
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
                    color: active
                        ? const Color(0xFFC9A96E)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: const Color(0xFFC9A96E).withOpacity(0.25),
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
                        color: active ? Colors.black : Colors.white.withOpacity(0.5),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        opt.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          color: active ? Colors.black : Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
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
