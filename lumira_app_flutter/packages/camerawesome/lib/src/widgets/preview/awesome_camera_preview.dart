import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:camerawesome/pigeon.dart';
import 'package:camerawesome/preview_fit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum CameraPreviewFit {
  fitWidth,
  fitHeight,
  contain,
  cover,
}

/// This is a fullscreen camera preview
/// some part of the preview are cropped so we have a full sized camera preview
class AwesomeCameraPreview extends StatefulWidget {
  final CameraPreviewFit previewFit;
  final Widget? loadingWidget;
  final CameraState state;
  final OnPreviewTap? onPreviewTap;
  final OnPreviewScale? onPreviewScale;
  final CameraLayoutBuilder interfaceBuilder;
  final CameraLayoutBuilder? previewDecoratorBuilder;
  final EdgeInsets padding;
  final Alignment alignment;

  /// 拉腿强度（0-100）。>0 时以「双层 GPU 合成」渲染取景器纹理（见 [_AwesomeCameraPreviewState._buildTexture]）。
  final int legStretch;

  const AwesomeCameraPreview({
    super.key,
    this.loadingWidget,
    required this.state,
    this.onPreviewTap,
    this.onPreviewScale,
    this.previewFit = CameraPreviewFit.cover,
    required this.interfaceBuilder,
    this.previewDecoratorBuilder,
    required this.padding,
    required this.alignment,
    this.legStretch = 0,
  });

  @override
  State<StatefulWidget> createState() {
    return AwesomeCameraPreviewState();
  }
}

class AwesomeCameraPreviewState extends State<AwesomeCameraPreview> {
  PreviewSize? _previewSize;
  PreviewSize? _flutterPreviewSize;
  int? _textureId;

  PreviewSize? get pixelPreviewSize => _previewSize;

  PreviewSize? get flutterPreviewSize => _flutterPreviewSize;
  StreamSubscription? _sensorConfigSubscription;
  StreamSubscription? _aspectRatioSubscription;
  CameraAspectRatios? _aspectRatio;
  double? _aspectRatioValue;

  Size? _previousCroppedSize;
  Size? _croppedSize;

  @override
  void initState() {
    super.initState();
    Future.wait([
      widget.state.previewSize(),
      widget.state.textureId(),
    ]).then((data) {
      if (mounted) {
        setState(() {
          _previewSize = data[0] as PreviewSize;
          _textureId = data[1] as int;
        });
      }
    });

    _sensorConfigSubscription =
        widget.state.sensorConfig$.listen((sensorConfig) {
      _aspectRatioSubscription?.cancel();
      _aspectRatioSubscription =
          sensorConfig.aspectRatio$.listen((event) async {
        final previewSize = await widget.state.previewSize();
        if ((_previewSize != previewSize || _aspectRatio != event) && mounted) {
          setState(() {
            _aspectRatio = event;
            switch (event) {
              case CameraAspectRatios.ratio_16_9:
                _aspectRatioValue = 16 / 9;
                break;
              case CameraAspectRatios.ratio_4_3:
                _aspectRatioValue = 4 / 3;
                break;
              case CameraAspectRatios.ratio_1_1:
                _aspectRatioValue = 1;
                break;
            }
            _previewSize = previewSize;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _sensorConfigSubscription?.cancel();
    _aspectRatioSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_textureId == null || _previewSize == null || _aspectRatio == null) {
      return widget.loadingWidget ??
          Center(
            child: Platform.isIOS
                ? const CupertinoActivityIndicator()
                : const CircularProgressIndicator(),
          );
    }

    return Container(
      color: Colors.black,
      child: OrientationBuilder(builder: (context, orientation) {
        return LayoutBuilder(
          builder: (_, constraints) {
            final size = Size(_previewSize!.width, _previewSize!.height);

            final constrainedSize = Size(
              constraints.maxWidth - widget.padding.left - widget.padding.right,
              constraints.maxHeight -
                  widget.padding.top -
                  widget.padding.bottom,
            );

            final ratioW = constrainedSize.width / size.width;
            final ratioH = constrainedSize.height / size.height;

            // maxSize doesn't take account of the aspect ratio
            Size maxSize;
            switch (widget.previewFit) {
              case CameraPreviewFit.fitWidth:
                maxSize = Size(constrainedSize.width, size.height * ratioW);
                break;
              case CameraPreviewFit.fitHeight:
                maxSize = Size(size.width * ratioH, constrainedSize.height);
                break;
              case CameraPreviewFit.cover:
                // 修复（移植自 camerawesome_ohos 1.0.2）：
                // 原版 cover 始终按取景框高度缩放竖屏纹理，4:3/1:1 取景框
                // 下会留黑边而不是裁切，导致取景器与成片不一致（非 WYSIWYG）。
                maxSize = computeCoverPreviewSize(
                  textureSize:
                      Size(_previewSize!.width, _previewSize!.height),
                  boxSize: constrainedSize,
                );
                break;
              case CameraPreviewFit.contain:
                final ratio = min(ratioW, ratioH);
                maxSize = Size(size.width * ratio, size.height * ratio);
                break;
            }

            final center = Size(constrainedSize.width, constrainedSize.height)
                .center(Offset.zero);
            _flutterPreviewSize =
                PreviewSize(width: maxSize.width, height: maxSize.height);
            // croppedPreviewSize takes care of the aspectRatio
            final croppedPreviewSize =
                _croppedPreviewSize(constrainedSize, _aspectRatioValue!);
            _previousCroppedSize = _croppedSize;
            _croppedSize =
                Size(croppedPreviewSize.width, croppedPreviewSize.height);
            // if croppedSize was null before
            _previousCroppedSize ??=
                Size(_croppedSize!.width, _croppedSize!.height);

            final previewTexture = _buildTexture();

            final preview = SizedBox(
              width: constrainedSize.width,
              height: constrainedSize.height,
              child: ClipRect(
                child: OverflowBox(
                  maxWidth: double.infinity,
                  maxHeight: double.infinity,
                  child: Center(
                    child: SizedBox(
                      // Use the max preview size (not the cropped one) and crop it later if needed (ratio 1:1 for example)
                      width: _flutterPreviewSize!.width,
                      height: _flutterPreviewSize!.height,
                      child: AwesomeCameraGestureDetector(
                        onPreviewTapBuilder:
                            widget.onPreviewTap != null && _previewSize != null
                                ? OnPreviewTapBuilder(
                                    pixelPreviewSizeGetter: () => _previewSize!,
                                    // 对焦归一化基准 = 取景框（可见区域）尺寸，
                                    // 而非被裁剪的 croppedPreviewSize。
                                    flutterPreviewSizeGetter: () =>
                                        PreviewSize(
                                      width: constrainedSize.width,
                                      height: constrainedSize.height,
                                    ),
                                    onPreviewTap: OnPreviewTap(
                                      onTap: (position, flutterPreviewSize,
                                          pixelPreviewSize) {
                                        // 手势层覆盖整张纹理（cover 模式纹理比取景框大并
                                        // 居中裁切、contain 模式比取景框小并居中留边），
                                        // localPosition 相对纹理左上角。加上偏移换算回
                                        // 取景框坐标，否则黄色对焦框相对手指触点偏移
                                        // （iOS 全屏取景框 + 4:3 纹理时明显偏右）。
                                        final offset = computePreviewTapOffset(
                                          textureSize: Size(
                                            _flutterPreviewSize!.width,
                                            _flutterPreviewSize!.height,
                                          ),
                                          boxSize: constrainedSize,
                                        );
                                        widget.onPreviewTap!.onTap(
                                          position + offset,
                                          flutterPreviewSize,
                                          pixelPreviewSize,
                                        );
                                      },
                                      onTapPainter:
                                          widget.onPreviewTap!.onTapPainter,
                                      tapPainterDuration: widget
                                          .onPreviewTap!.tapPainterDuration,
                                    ),
                                  )
                                : null,
                        onPreviewScale: widget.onPreviewScale,
                        initialZoom: widget.state.sensorConfig.zoom,
                        // if there is no filter, just display texture
                        // to improve a little bit performances
                        child: StreamBuilder<AwesomeFilter>(
                            stream: widget.state.filter$,
                            builder: (context, snapshot) {
                              return snapshot.hasData &&
                                      snapshot.data != AwesomeFilter.None
                                  ? ColorFiltered(
                                      colorFilter: snapshot.data!.preview,
                                      child: previewTexture,
                                    )
                                  : previewTexture;
                            }),
                      ),
                    ),
                  ),
                ),
              ),
            );

            final centeredPreview = SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Center(child: preview),
            );

            if ([
              CameraPreviewFit.fitHeight,
              CameraPreviewFit.fitWidth,
              CameraPreviewFit.contain
            ].contains(widget.previewFit)) {
              return Stack(children: [
                Positioned.fill(
                  child: TweenAnimationBuilder<Size>(
                    builder: (context, anim, _) {
                      return _CroppedPreview(
                        croppedSize: anim,
                        alignment: widget.alignment,
                        padding: widget.padding,
                        child: centeredPreview,
                      );
                    },
                    tween: Tween<Size>(
                      begin: _previousCroppedSize,
                      end: _croppedSize,
                    ),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.fastLinearToSlowEaseIn,
                  ),
                ),
                if (widget.previewDecoratorBuilder != null)
                  Positioned.fill(
                    child: widget.previewDecoratorBuilder!(
                      widget.state,
                      _flutterPreviewSize!,
                      Rect.fromCenter(
                        center: center,
                        width: croppedPreviewSize.width,
                        height: croppedPreviewSize.height,
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: widget.interfaceBuilder(
                    widget.state,
                    _flutterPreviewSize!,
                    Rect.fromCenter(
                      center: center,
                      width: croppedPreviewSize.width,
                      height: croppedPreviewSize.height,
                    ),
                  ),
                ),
              ]);
            } else {
              return Stack(children: [
                Positioned.fill(child: centeredPreview),
                if (widget.previewDecoratorBuilder != null)
                  Positioned.fill(
                    child: widget.previewDecoratorBuilder!(
                      widget.state,
                      _flutterPreviewSize!,
                      Rect.fromCenter(
                        center: center,
                        width: croppedPreviewSize.width,
                        height: croppedPreviewSize.height,
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: widget.interfaceBuilder(
                    widget.state,
                    _flutterPreviewSize!,
                    Rect.fromCenter(
                      center: center,
                      width: croppedPreviewSize.width,
                      height: croppedPreviewSize.height,
                    ),
                  ),
                ),
              ]);
            }
          },
        );
      }),
    );
  }

  /// 构建取景器纹理。
  ///
  /// `legStretch > 0` 时使用「双层 GPU 合成」实时预览拉腿：
  /// - 以取景器 60% 高度为锚点；
  /// - 锚点上方：恒等显示原纹理（第 1 层）；
  /// - 锚点下方：用 [Transform] 以锚点为轴纵向放大 k 倍（第 2 层），
  ///   k = destRegion / srcRegion，与成片 legStretchRgba 的几何完全一致；
  /// - 超出取景框的部分由外层 [ClipRect] 裁掉。
  ///
  /// 全程纯 GPU 合成：零 GPU 读回（无 toImage/toByteData）、零 CPU 逐像素拉伸、
  /// 零半透明叠层，因此取景器帧率不受影响（无卡顿），也不会出现新旧帧重影。
  /// 与旧「帧快照 + isolate 拉伸 + 半透明幽灵叠加」方案相比，这是根本性替换。
  Widget _buildTexture() {
    final texture = Texture(textureId: _textureId!);
    if (widget.legStretch <= 0) return texture;

    final size = _flutterPreviewSize!;
    final w = size.width;
    final h = size.height;
    final anchor = h * 0.60;
    final strength = (widget.legStretch / 100.0).clamp(0.0, 1.0);
    final stretchFactor = strength * 0.20;
    if (stretchFactor < 0.001) return texture;

    final outH = h * (1 + stretchFactor);
    final srcRegion = h - anchor;
    final destRegion = outH - anchor;
    final k = destRegion / srcRegion;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        // 第 1 层：锚点上方，恒等。源 [0, anchor] → 目标 [0, anchor]。
        ClipRect(
          clipper: _PreviewRectClipper(Rect.fromLTRB(0, 0, w, anchor)),
          child: texture,
        ),
        // 第 2 层：锚点下方，以锚点为轴纵向放大 k。源 [anchor, h] → 目标 [anchor, outH]。
        // 目标 y = k*srcY + anchor*(1-k)；超出取景框(0..h) 的部分由外层 ClipRect 裁掉，
        // 恰好对应成片「锚点下方拉伸、底部内容被推出画面」的 WYSIWYG 效果。
        ClipRect(
          clipper: _PreviewRectClipper(Rect.fromLTRB(0, anchor, w, outH)),
          child: Transform(
            transform: Matrix4.identity()
              ..setEntry(1, 1, k)
              ..setEntry(1, 3, anchor * (1 - k)),
            child: texture,
          ),
        ),
      ],
    );
  }

  PreviewSize _croppedPreviewSize(Size constrainedSize, double aspectRatio) {
    // 修复（移植自 camerawesome_ohos 1.0.2）：
    // 按 previewFit 计算实际可见区域，供手势/对焦坐标换算使用，
    // 避免 cover 模式下坐标与实际画面不一致。
    Size croppedSize;
    switch (widget.previewFit) {
      case CameraPreviewFit.cover:
        final previewRatio = _previewSize!.width / _previewSize!.height;
        final constrainedRatio = constrainedSize.width / constrainedSize.height;
        if (constrainedRatio > previewRatio) {
          final width = constrainedSize.height * previewRatio;
          croppedSize = Size(width, constrainedSize.height);
        } else {
          final height = constrainedSize.width / previewRatio;
          croppedSize = Size(constrainedSize.width, height);
        }
        break;
      case CameraPreviewFit.contain:
        final ratio = min(
          constrainedSize.width / _previewSize!.width,
          constrainedSize.height / _previewSize!.height,
        );
        croppedSize = Size(
          _previewSize!.width * ratio,
          _previewSize!.height * ratio,
        );
        break;
      default:
        croppedSize = constrainedSize;
    }
    return PreviewSize(width: croppedSize.width, height: croppedSize.height);
  }
}

class _CroppedPreview extends StatelessWidget {
  final Widget child;
  final Size croppedSize;
  final Alignment alignment;
  final EdgeInsets padding;
  final Duration animDuration = const Duration(milliseconds: 300);

  const _CroppedPreview({
    required this.croppedSize,
    required this.alignment,
    required this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      alignment: alignment,
      duration: animDuration,
      curve: Curves.easeInOut,
      padding: padding,
      child: SizedBox(
        width: croppedSize.width,
        height: croppedSize.height,
        child: ClipPath(
          clipper: _CenterCropClipper(
            width: croppedSize.width,
            height: croppedSize.height,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _CenterCropClipper extends CustomClipper<Path> {
  final double width;
  final double height;

  const _CenterCropClipper({
    required this.width,
    required this.height,
  });

  @override
  Path getClip(Size size) {
    final center = size.center(Offset.zero);
    return Path()
      ..addRect(
        Rect.fromCenter(
          center: center,
          width: width,
          height: height,
        ),
      );
  }

  @override
  bool shouldReclip(covariant _CenterCropClipper oldClipper) {
    return width != oldClipper.width || height != oldClipper.height;
  }
}

/// 拉腿双层合成用矩形裁剪器：把同源纹理裁剪到指定矩形区域。
class _PreviewRectClipper extends CustomClipper<Rect> {
  final Rect rect;

  const _PreviewRectClipper(this.rect);

  @override
  Rect getClip(Size size) => rect;

  @override
  bool shouldReclip(covariant _PreviewRectClipper oldClipper) =>
      rect != oldClipper.rect;
}
