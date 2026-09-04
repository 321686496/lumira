import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/images/lumira_image.dart';
import '../data/gallery_models.dart';

/// 多选触发长按时长（默认 kLongPressTimeout=500ms 偏久，调短以提升滑动多选流畅度）。
const Duration _kQuickLongPressDuration = Duration(milliseconds: 300);

class PhotoCell extends ConsumerWidget {
  const PhotoCell({
    super.key,
    required this.photo,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isMultiSelectMode = false,
  });

  final GalleryPhoto photo;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isMultiSelectMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;

    // OHOS 滚动优化：把整格照片（含裁切圆角 + 可选遮罩）隔离成独立图层，
    // 滚动时复用缓存层，避免每帧重新合成，降低相册/flutter 网格滚动掉帧。
    //
    // 手势分流：
    // - 非多选态：注册快速长按 _QuickLongPressRecognizer（300ms → 进入多选）
    //   与 TapGestureRecognizer（单击 → 打开详情）。
    // - 多选态（onLongPress==null）：不注册任何手势识别器，格子在多选态下完全由
    //   SweepAlbumGrid 的裸 Listener 接管（按下即选 + 滑动连续选择），
    //   避免与点击/长按在竞技场里双触发（SweepAlbumGrid 的 Listener 不进竞技场，
    //   因此辅以去竞技场确保无冲突）。
    // - 网格搜索态：同理，onTap/onLongPress 均为 null 时去手势，仅展示。
    final hasTap = onTap != null;
    final hasLongPress = onLongPress != null;
    final hasGesture = hasTap || hasLongPress;

    final child = ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: AspectRatio(
        aspectRatio: 1 / 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildImage(context, tokens),
            if (isMultiSelectMode)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? tokens.brand
                        : Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white70, width: 1.5),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check,
                          size: 14, color: Colors.white)
                      : null,
                ),
              ),
            if (isSelected)
              Container(
                color: tokens.brand.withOpacity(0.2),
              ),
          ],
        ),
      ),
    );

    if (!hasGesture) {
      // 多选态 / 无手势：直接返回纯展示格，不包任何手势识别器。
      // SweepAlbumGrid 的裸 Listener 通过 GlobalObjectKey 命中测试定位并驱动滑动选择。
      return RepaintBoundary(child: child);
    }

    // 非多选态：注册快速长按 + 单击识别器
    return RepaintBoundary(
      child: RawGestureDetector(
        gestures: {
          if (hasLongPress)
            _QuickLongPressRecognizer: GestureRecognizerFactoryWithHandlers<
                _QuickLongPressRecognizer>(
              () => _QuickLongPressRecognizer(),
              (instance) {
                instance.onLongPress = onLongPress;
              },
            ),
          if (hasTap)
            TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<
                TapGestureRecognizer>(
              () => TapGestureRecognizer(),
              (instance) {
                instance.onTap = onTap;
              },
            ),
        },
        behavior: HitTestBehavior.opaque,
        child: child,
      ),
    );
  }

  Widget _buildImage(BuildContext context, ThemeTokens tokens) {
    final url = photo.displayUrl;
    final placeholder = Container(
      color: tokens.surfaceAlt,
      child: Icon(Icons.image_outlined, size: 32, color: tokens.textTertiary),
    );
    if (url == null || url.isEmpty) {
      return placeholder;
    }
    // 走统一加载组件：磁盘缓存 + 按实际渲染尺寸×DPR 降采样（自动识别网络/本地文件）
    return LumiraImage(
      url,
      fit: BoxFit.cover,
      errorWidget: placeholder,
    );
  }
}

/// 缩短触发时长的长按识别器：覆盖默认 kLongPressTimeout(500ms)，改为 [_kQuickLongPressDuration]。
///
/// 仅替换长按；单击 / 双击 / 滚动识别不受影响（各自仍按原规则参与竞技场）。
class _QuickLongPressRecognizer extends LongPressGestureRecognizer {
  _QuickLongPressRecognizer()
      : super(duration: _kQuickLongPressDuration);
}
