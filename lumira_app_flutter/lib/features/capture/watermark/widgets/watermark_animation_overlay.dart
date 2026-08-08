import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/watermark_template.dart';

/// 水印相框入场动画 overlay。
///
/// 拍照完成且水印 + 动画开关均开启时，由拍摄页挂到 Stack 顶层播放：
/// - Phase 1 (0–14%)：照片淡入（冻结在屏幕中央）
/// - Phase 2 (14–45%)：水印元素淡入 + 轻微放大 (0.8→1.0)
/// - Phase 3 (45–68%)：保持显示
/// - Phase 4 (68–86%)：照片 + 水印向角标缩略图目标矩形缩小并平移
/// - Phase 5 (86–100%)：在目标位置最终淡出
///
/// 使用 [IgnorePointer] 不拦截手势，[ui.Image] 与 [AnimationController]
/// 在 dispose 中释放，[ui.Codec] 在抽帧后立即释放。
class WatermarkAnimationOverlay extends StatefulWidget {
  final String photoPath;
  final WatermarkTemplate watermarkTemplate;
  final Rect targetRect;
  final VoidCallback onAnimationComplete;

  const WatermarkAnimationOverlay({
    super.key,
    required this.photoPath,
    required this.watermarkTemplate,
    required this.targetRect,
    required this.onAnimationComplete,
  });

  @override
  State<WatermarkAnimationOverlay> createState() =>
      _WatermarkAnimationOverlayState();
}

class _WatermarkAnimationOverlayState extends State<WatermarkAnimationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _photoFade;
  late Animation<double> _watermarkFade;
  late Animation<double> _shrink;
  ui.Image? _photoImage;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _photoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.14, curve: Curves.easeOut),
    );
    _watermarkFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.14, 0.45, curve: Curves.easeOut),
    );
    _shrink = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.68, 0.86, curve: Curves.easeInCubic),
    );
    _loadImage();
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete();
      }
    });
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await File(widget.photoPath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() => _photoImage = frame.image);
      } else {
        frame.image.dispose();
      }
      codec.dispose();
    } catch (e) {
      debugPrint('[watermark-anim] image load failed: $e');
    }
  }

  @override
  void dispose() {
    _photoImage?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_photoImage == null) return const SizedBox.shrink();

        final photoOpacity = _photoFade.value;
        final watermarkOpacity = _watermarkFade.value;
        final shrinkValue = _shrink.value;

        // Phase 4：向目标缩略图位置缩小 + 平移
        final scale = 1.0 - (shrinkValue * 0.85);
        final photoOpacityFinal = shrinkValue > 0
            ? photoOpacity * (1.0 - shrinkValue * 0.3)
            : photoOpacity;

        // 平移：屏幕中心 → 目标矩形中心
        final screenCenter =
            Offset(screenSize.width / 2, screenSize.height / 2);
        final targetCenter = widget.targetRect.center;
        final dx = (targetCenter.dx - screenCenter.dx) * shrinkValue;
        final dy = (targetCenter.dy - screenCenter.dy) * shrinkValue;

        return IgnorePointer(
          child: Stack(
            children: [
              // Phase 1~4：黑色半透明遮罩（随 shrink 一起淡出）
              if (_controller.value < 0.86)
                Container(
                    color:
                        Colors.black.withOpacity(0.4 * (1 - shrinkValue))),

              // 照片
              Center(
                child: Transform.translate(
                  offset: Offset(dx, dy),
                  child: Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: photoOpacityFinal,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8 * shrinkValue),
                        child: SizedBox(
                          width: screenSize.width,
                          height: screenSize.height,
                          child: RawImage(
                            image: _photoImage,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 水印文本元素（Phase 2 淡入，与照片同步缩放/平移）
              if (watermarkOpacity > 0)
                ...widget.watermarkTemplate.elements.map((element) {
                  if (element.type != WatermarkElementType.text ||
                      element.text.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Positioned(
                    left: element.x * screenSize.width,
                    top: element.y * screenSize.height,
                    child: Transform.translate(
                      offset: Offset(dx, dy),
                      child: Transform.scale(
                        scale: scale * (0.8 + 0.2 * watermarkOpacity),
                        child: Opacity(
                          opacity: watermarkOpacity * element.opacity,
                          child: Text(
                            element.text,
                            style: TextStyle(
                              color: element.color,
                              fontSize: element.fontSize * screenSize.width,
                              fontWeight: element.bold
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontStyle: element.italic
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
