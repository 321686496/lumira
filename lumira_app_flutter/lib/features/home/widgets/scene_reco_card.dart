import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumira_app_flutter/core/utils/image_cache.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/images/lumira_image.dart';
import '../data/home_mock_data.dart';

/// 场景推荐卡片
///
/// 视觉规格来源：lumira-app/src/components/ScenePresetView.vue card variant
/// + lumira-app/src/pages/home/index.vue line 132-150
/// - 2 列网格（home 页负责 GridView，本卡片只负责单个卡片）
/// - 28rpx→14dp 圆角
/// - 图片 aspect ratio 3:4 (padding-bottom 133.33%)
/// - 标签：左上角，圆角 9999rpx，brand bg 或 dark bg
class SceneRecoCard extends ConsumerWidget {
  const SceneRecoCard({
    super.key,
    required this.scene,
    required this.onTap,
    this.showPhotoCount = true,
    this.footer,
  });

  final SceneReco scene;
  final VoidCallback onTap;
  final bool showPhotoCount;
  final Widget? footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          // 叠照片遮罩（半透明黑）为跨风格合法例外
          color: Colors.black.withOpacity(0.0),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildCoverImage(tokens),
            // 底部渐变遮罩：压暗保证文字可读
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.55),
                  ],
                ),
              ),
            ),
            // 左上角标签
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scene.badgeBrand
                      ? tokens.brand
                      : Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(1000),
                ),
                child: Text(
                  scene.badgeText,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    letterSpacing: 0.04 * 10,
                    height: 1.2,
                  ),
                ),
              ),
            ),
            // 左下角：场景名 + 氛围
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    scene.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    scene.vibe,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.85),
                      height: 1.3,
                    ),
                  ),
                  if (showPhotoCount) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.photo_library_outlined,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${scene.photoCount}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 封面图：data:image/http(s)/本地路径 → LumiraImage 统一加载（自动降采样，
  /// 避免网格/卡片按全尺寸解码）；网络路径保留原 CachedNetworkImage。
  Widget _buildCoverImage(ThemeTokens tokens) {
    final placeholder = Container(
      color: tokens.surfaceAlt,
      child: Icon(
        Icons.image_outlined,
        size: 32,
        color: tokens.textTertiary,
      ),
    );
    final cover = scene.coverUrl;
    if (cover.isEmpty) return placeholder;
    // base64 data URL / 本地图片路径 → LumiraImage（自动降采样 + base64 字节级缓存）
    if (!cover.startsWith('http://') && !cover.startsWith('https://')) {
      return LumiraImage(
        cover,
        fit: BoxFit.cover,
        errorWidget: placeholder,
      );
    }
    // 网络图片：保留原 CachedNetworkImage
    return CachedNetworkImage(
      url: cover,
      fit: BoxFit.cover,
      placeholder: placeholder,
      errorWidget: placeholder,
    );
  }
}
