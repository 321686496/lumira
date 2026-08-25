import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camerawesome_ohos/camerawesome_plugin.dart';
import 'package:camerawesome_ohos/pigeon.dart';
import 'package:camerawesome_ohos/src/orchestrator/models/camera_display_rotation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

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

  StreamSubscription? _displayRotationStreamSub;
  CameraDisplayRotation? _displayRotation;

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

    // 用 name 判断 OHOS：TargetPlatform.ohos 仅在 HarmonyOS fork 的 Flutter SDK 存在，
    // 标准 Flutter（iOS/Android）无该枚举值，直接引用会在非 OHOS 构建时报编译错误。
    if (defaultTargetPlatform.name == 'ohos') {
      _displayRotationStreamSub =
          CamerawesomePlugin.listenDisplayRotation()!.listen(
        (res) async {
          if (mounted && _previewSize != null && _displayRotation != res) {
            _displayRotation = res;
            final previewSize = await widget.state.previewSize();
            setState(() {
              _previewSize = previewSize;
            });
          } else if (mounted && _previewSize != null) {
            final previewSize = await widget.state.previewSize();
            // 判断宽高是否改变
            if (previewSize.width != _previewSize!.width ||
                previewSize.height != _previewSize!.height) {
              setState(() {
                _previewSize = previewSize;
              });
            }
          }
        },
      );
    }
  }

  @override
  void dispose() {
    _sensorConfigSubscription?.cancel();
    _aspectRatioSubscription?.cancel();
    _displayRotationStreamSub?.cancel();
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
                final previewRatio = _previewSize!.width / _previewSize!.height;

                // Calculate target size based on width
                final double targetWidthByWidth = constrainedSize.width;
                final double targetHeightByWidth =
                    constrainedSize.width / previewRatio;

                // Calculate target size based on height
                final double targetWidthByHeight =
                    constrainedSize.height * previewRatio;
                final double targetHeightByHeight = constrainedSize.height;

                // Choose the larger dimension that ensures full coverage
                final bool useWidth =
                    targetHeightByWidth >= constrainedSize.height;

                final double finalWidth =
                    useWidth ? targetWidthByWidth : targetWidthByHeight;
                final double finalHeight =
                    useWidth ? targetHeightByWidth : targetHeightByHeight;

                maxSize = Size(finalWidth, finalHeight);
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

            final previewTexture = Texture(textureId: _textureId!);

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
                                        // 取景框坐标，否则黄色对焦框相对手指触点偏移。
                                        final offset = Offset(
                                          (constrainedSize.width -
                                                  _flutterPreviewSize!.width) /
                                              2,
                                          (constrainedSize.height -
                                                  _flutterPreviewSize!.height) /
                                              2,
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

  PreviewSize _croppedPreviewSize(Size constrainedSize, double aspectRatio) {
    // 根据 previewFit 计算裁剪区域
    Size croppedSize;
    switch (widget.previewFit) {
      case CameraPreviewFit.cover:
        final previewRatio = _previewSize!.width / _previewSize!.height;
        final constrainedRatio = constrainedSize.width / constrainedSize.height;
        // 基于 previewRatio 和 constrainedSize 计算裁剪区域
        if (constrainedRatio > previewRatio) {
          // 以高度为基准
          final width = constrainedSize.height * previewRatio;
          croppedSize = Size(width, constrainedSize.height);
        } else {
          // 以宽度为基准
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
        child: ClipRect(
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
