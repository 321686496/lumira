// lib/features/gallery/widgets/photo_crop_layer.dart
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/images/lumira_image.dart';
import '../../capture/domain/photo_template.dart';
import 'crop_overlay.dart';

/// 照片上的裁剪叠加层（iPhone / 主流拍摄软件风格）
///
/// 将可拖拽裁剪框直接叠加在照片本体上，而不是在底部操作栏里放一个小预览框。
/// 复用 [CropPreview] 的取像逻辑：加载图片 intrinsic 尺寸 → 按可用空间计算
/// 适配后的图片显示区域（居中）→ 在图片区域上叠加 [CropOverlay]。
///
/// 坐标系统：裁剪框用相对坐标（0.0-1.0）表示，映射到【原图】坐标，
/// 与导出的 `customCropRect` 坐标系一致（裁剪发生在旋转/翻转之前）。
class PhotoCropLayer extends StatefulWidget {
  /// 图片路径（文件路径或 URL）
  final String photoUrl;

  /// 当前裁剪框（相对坐标），null = 使用默认居中
  final Rect? initialCrop;

  /// 锁定宽高比（null = 自由）
  final double? aspectRatio;

  /// 裁剪框变化回调（相对坐标）
  final ValueChanged<Rect> onChanged;

  /// 主题色板（用于裁剪框配色）
  final ThemeTokens tokens;

  /// 背景颜色（默认纯黑，与照片区域一致）
  final Color? background;

  /// 照片变换（旋转/翻转/拉直），叠加在照片上，使裁剪下方的操作所见即所得。
  final TransformParams? transform;

  const PhotoCropLayer({
    super.key,
    required this.photoUrl,
    required this.onChanged,
    required this.tokens,
    this.initialCrop,
    this.aspectRatio,
    this.background,
    this.transform,
  });

  @override
  State<PhotoCropLayer> createState() => _PhotoCropLayerState();
}

class _PhotoCropLayerState extends State<PhotoCropLayer> {
  /// 图片宽高比（width / height），加载后确定
  double? _imageAspect;

  ImageStream? _imageStream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(PhotoCropLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.photoUrl != oldWidget.photoUrl) {
      _loadImage();
    }
  }

  @override
  void dispose() {
    _imageStream?.removeListener(_listener!);
    super.dispose();
  }

  void _loadImage() {
    if (widget.photoUrl.isEmpty) {
      if (mounted) setState(() => _imageAspect = null);
      return;
    }
    _imageStream?.removeListener(_listener!);
    if (widget.photoUrl.startsWith('http')) {
      _imageStream = NetworkImage(widget.photoUrl)
          .resolve(const ImageConfiguration());
    } else {
      _imageStream =
          FileImage(File(widget.photoUrl)).resolve(const ImageConfiguration());
    }
    _listener = ImageStreamListener((info, _) {
      if (mounted) {
        setState(() {
          _imageAspect = info.image.width / info.image.height;
        });
      }
    });
    _imageStream!.addListener(_listener!);
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.background ?? Colors.black;
    if (widget.photoUrl.isEmpty) {
      return Container(
        color: bg,
        child: const Center(
          child: Icon(Icons.photo, color: Colors.white38, size: 64),
        ),
      );
    }
    if (_imageAspect == null) {
      return Container(
        color: bg,
        child: const Center(
          child: Icon(Icons.image_outlined, color: Colors.white38, size: 48),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        final ratio = _imageAspect!;
        double w, h;
        if (maxW / maxH > ratio) {
          // 受高度约束
          h = maxH;
          w = h * ratio;
        } else {
          // 受宽度约束
          w = maxW;
          h = w / ratio;
        }
        final left = (maxW - w) / 2;
        final top = (maxH - h) / 2;
        final imageRect = Rect.fromLTWH(left, top, w, h);

        // 照片 widget（BoxFit.fill 填满适配区域，保证与裁剪框坐标对齐）
        final photo = LumiraImage(
          widget.photoUrl,
          fit: BoxFit.fill,
          errorWidget: _buildErrorWidget(),
        );

        return Container(
          color: bg,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 裁剪叠加层：照片可缩放/平移 + 裁剪框可移动/缩放（iPhone 风格）
              Positioned.fromRect(
                rect: imageRect,
                child: CropOverlay(
                  photo: photo,
                  initialRect: widget.initialCrop,
                  aspectRatio: widget.aspectRatio,
                  onChanged: widget.onChanged,
                  tokens: widget.tokens,
                  transform: widget.transform,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: widget.tokens.surfaceAlt,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined,
                size: 32, color: widget.tokens.textTertiary),
            const SizedBox(height: 8),
            Text('图片加载失败',
                style: TextStyle(
                    fontSize: 12, color: widget.tokens.textTertiary)),
          ],
        ),
      ),
    );
  }
}