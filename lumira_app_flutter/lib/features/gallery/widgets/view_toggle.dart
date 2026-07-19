import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';

/// 相册主页顶部视图切换（照片 / 拍摄日记）
///
/// 视觉规格来源：lumira-app/src/pages/gallery/index.vue line 18-33
class ViewToggle extends ConsumerWidget {
  const ViewToggle({
    super.key,
    required this.activeTab,
    required this.onPhotoTap,
    required this.onDiaryTap,
  });

  final String activeTab; // 'photo' / 'diary'
  final VoidCallback onPhotoTap;
  final VoidCallback onDiaryTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;

    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(1000),
      ),
      padding: const EdgeInsets.all(3), // 6rpx → 3dp
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildItem('照片', activeTab == 'photo', tokens, onPhotoTap),
          _buildItem('拍摄日记', activeTab == 'diary', tokens, onDiaryTap),
        ],
      ),
    );
  }

  Widget _buildItem(String label, bool active, ThemeTokens tokens, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6), // 36rpx 12rpx → 18dp 6dp
        decoration: BoxDecoration(
          color: active ? tokens.canvas : Colors.transparent,
          borderRadius: BorderRadius.circular(1000),
          boxShadow: active
              ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 3, offset: const Offset(0, 1))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13, // 26rpx → 13dp
            fontWeight: FontWeight.w500,
            color: active ? tokens.textPrimary : tokens.textTertiary,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
