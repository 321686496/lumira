import 'package:flutter/material.dart';

import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';

/// 悬浮「对比」按钮（修改前/修改后切换），拍摄预览页与后期修图页共用。
///
/// 两种形态（遵循项目 UI 铁律「叠照片浮层取向」）：
/// - [overlayOnImage] = false：纯色画布上（后期修图页）— surface 底 + 柔和凸阴影
/// - [overlayOnImage] = true：叠在照片上（拍摄预览页）— 半透明深色底 + 细白描边，
///   无外阴影、无模糊（照片无法承接同色双向浮雕阴影）
class ComparePhotoButton extends StatelessWidget {
  const ComparePhotoButton({
    Key? key,
    required this.comparing,
    required this.tokens,
    required this.onTap,
    this.overlayOnImage = false,
  }) : super(key: key);

  final bool comparing;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  /// 是否叠在照片上（决定浮层视觉取向）
  final bool overlayOnImage;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = comparing
        ? tokens.brand
        : (overlayOnImage ? Colors.white : tokens.textSecondary);
    final BoxDecoration decoration = overlayOnImage
        ? BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
          )
        : BoxDecoration(
            color: tokens.surface,
            shape: BoxShape.circle,
            boxShadow: tokens.shadowConvexSubtle,
          );
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 40,
        height: 40,
        decoration: decoration,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.chrome_reader_mode_outlined,
              size: 20,
              color: iconColor,
            ),
            if (comparing)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: tokens.brand,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
