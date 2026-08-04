import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../data/capture_state.dart';

/// 照片比例切换器
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _options.map((opt) {
          final active = opt.id == current;
          return GestureDetector(
            onTap: () => ref
                .read(CaptureState.aspectRatioProvider.notifier)
                .state = opt.id,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: active ? tokens.brand.withOpacity(0.9) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    opt.icon,
                    size: 14,
                    color: active ? tokens.textInverse : Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    opt.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: active ? tokens.textInverse : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
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
