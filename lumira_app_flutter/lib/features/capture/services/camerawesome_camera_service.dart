import 'dart:async';
import 'dart:io';

import 'package:camerawesome_ohos/camerawesome_plugin.dart' as ohos;
import 'package:camerawesome/camerawesome_plugin.dart' as ca;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' show getDatabasesPath;

import 'camera_service.dart';
import 'camerawesome_delegate.dart';

/// camerawesome 系列三端共用实现。
/// 通过 [CamerawesomeDelegate] 区分平台行为差异。
///
/// 两个 camerawesome 包（ohos fork / 原版 1.4.0）的 API 几乎一致，
/// 通过 import 别名隔离。运行时按 [CamerawesomeDelegate.platformTag]
/// 选择调用哪个包的符号。各端只会实例化对应平台的代码路径，
/// 不会触发另一端的插件调用。
class CamerawesomeCameraService implements CameraService {
  CamerawesomeCameraService(this._delegate);

  final CamerawesomeDelegate _delegate;

  // 内部持有 camerawesome 的 CameraState（类型按平台不同）
  // 用 dynamic 持有，避免在类型层面区分两个包的 CameraState
  dynamic _cameraState; // ohos.CameraState 或 ca.CameraState
  final _readyController = StreamController<bool>.broadcast();

  @override
  Stream<bool> get readyStream => _readyController.stream;

  @override
  Future<void> initialize({required String facing}) async {
    // camerawesome 的初始化通过 CameraAwesomeBuilder 隐式完成，
    // 此处只发信号。真正的初始化在 buildPreview() 的 builder 回调中触发。
    _readyController.add(false);
  }

  @override
  Future<void> dispose() async {
    try {
      if (_delegate.platformTag == 'ohos') {
        ohos.CamerawesomePlugin.stop();
      } else {
        ca.CamerawesomePlugin.stop();
      }
    } catch (_) {}
    await _readyController.close();
  }

  @override
  Future<CaptureResult> capture({required CaptureConfig config}) async {
    // 实际拍照：调用 camerawesome 的 takePhoto，监听 captureState$ 流获取文件路径
    // 返回一个 Future，在 captureState$ 监听器中 complete
    final completer = Completer<CaptureResult>();

    if (_cameraState == null) {
      throw StateError('Camera not initialized');
    }

    StreamSubscription? sub;
    sub = _cameraState.captureState$.listen((media) {
      if (media == null) return;
      // 两个包的 MediaCaptureStatus 枚举类型不同，需按平台选择比较目标
      final isSuccess = _delegate.platformTag == 'ohos'
          ? media.status == ohos.MediaCaptureStatus.success
          : media.status == ca.MediaCaptureStatus.success;
      if (isSuccess && media.filePath.isNotEmpty) {
        sub?.cancel();
        completer.complete(CaptureResult(
          filePath: media.filePath,
          sensorWidth: 0, // camerawesome 1.4.0 不暴露，后续从 JPEG 解析
          sensorHeight: 0,
          orientation: SensorOrientation.portrait,
        ));
      }
    });

    try {
      _cameraState.when(
        onPhotoMode: (photoState) => photoState.takePhoto(),
      );
    } catch (e) {
      sub?.cancel();
      completer.completeError(e);
    }

    return completer.future;
  }

  @override
  Future<void> switchCamera(String facing) async {
    // camerawesome 通过重建 CameraAwesomeBuilder 切换 sensor
    // 由 buildPreview() 的 sensor 参数驱动，此处仅发信号
    _readyController.add(false);
  }

  @override
  void setZoom(double multiplier) {
    if (_delegate.zoomIsMultiplier) {
      // OHOS: 直接传真实倍数
      try {
        ohos.CamerawesomePlugin.setZoom(multiplier);
      } catch (_) {}
    } else {
      // iOS/Android: SensorConfig.setZoom 归一化 [0,1]
      // normalized 计算依赖 minZoom/maxZoom，此处简化为直接用 multiplier-1 clamp
      try {
        final normalized = (multiplier - 1.0).clamp(0.0, 1.0);
        _cameraState?.sensorConfig?.setZoom(normalized);
      } catch (_) {}
    }
  }

  @override
  void setFlashMode(CameraFlashMode mode) {
    final flashMode = _mapFlashMode(mode);
    try {
      _cameraState?.sensorConfig?.setFlashMode(flashMode);
    } catch (_) {}
  }

  @override
  void focusOnPoint(Offset flutterPosition, Size flutterPreviewSize) {
    try {
      _cameraState?.when(
        onPhotoMode: (photoState) => photoState.focusOnPoint(
          flutterPosition: flutterPosition,
          pixelPreviewSize: flutterPreviewSize,
          flutterPreviewSize: flutterPreviewSize,
        ),
      );
    } catch (_) {}
  }

  @override
  Widget buildPreview({required CameraPreviewConfig config}) {
    if (_delegate.platformTag == 'ohos') {
      return _buildOhos(config);
    }
    return _buildNative(config);
  }

  Widget _buildOhos(CameraPreviewConfig config) {
    return ohos.CameraAwesomeBuilder.custom(
      saveConfig: ohos.SaveConfig.photo(
        pathBuilder: () async {
          final ts = DateTime.now().millisecondsSinceEpoch;
          try {
            final dir = await _getTempDir();
            return '${dir.path}/capture_$ts.jpg';
          } catch (_) {
            final dbPath = await _getDbPath();
            return '$dbPath/capture_$ts.jpg';
          }
        },
      ),
      sensor: config.facing == 'front' ? ohos.Sensors.front : ohos.Sensors.back,
      previewFit: _mapPreviewFitOhos(config.fit),
      builder: (cameraState, previewSize, previewRect) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _cameraState = cameraState;
          config.onReady?.call();
          _readyController.add(true);
        });
        return const SizedBox.shrink();
      },
      onPreviewTapBuilder: (state) => ohos.OnPreviewTap(
        onTap: (position, flutterPreviewSize, pixelPreviewSize) {
          config.onTapFocus?.call(
            position,
            Size(flutterPreviewSize.width, flutterPreviewSize.height),
          );
        },
      ),
      onPreviewScaleBuilder: (state) => ohos.OnPreviewScale(
        onScale: (scale) {
          config.onScaleZoom?.call(1.0 + scale.clamp(0.0, 1.0));
        },
      ),
    );
  }

  Widget _buildNative(CameraPreviewConfig config) {
    return ca.CameraAwesomeBuilder.custom(
      saveConfig: ca.SaveConfig.photo(
        pathBuilder: () async {
          final ts = DateTime.now().millisecondsSinceEpoch;
          final dir = await _getTempDir();
          return '${dir.path}/capture_$ts.jpg';
        },
      ),
      sensor: config.facing == 'front' ? ca.Sensors.front : ca.Sensors.back,
      previewFit: _mapPreviewFitNative(config.fit),
      builder: (cameraState, previewSize, previewRect) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _cameraState = cameraState;
          config.onReady?.call();
          _readyController.add(true);
        });
        return const SizedBox.shrink();
      },
      onPreviewTapBuilder: (state) => ca.OnPreviewTap(
        onTap: (position, flutterPreviewSize, pixelPreviewSize) {
          config.onTapFocus?.call(
            position,
            Size(flutterPreviewSize.width, flutterPreviewSize.height),
          );
        },
      ),
      onPreviewScaleBuilder: (state) => ca.OnPreviewScale(
        onScale: (scale) {
          config.onScaleZoom?.call(1.0 + scale.clamp(0.0, 1.0));
        },
      ),
    );
  }

  ohos.CameraPreviewFit _mapPreviewFitOhos(CameraPreviewFit fit) {
    return fit == CameraPreviewFit.cover
        ? ohos.CameraPreviewFit.cover
        : ohos.CameraPreviewFit.contain;
  }

  ca.CameraPreviewFit _mapPreviewFitNative(CameraPreviewFit fit) {
    return fit == CameraPreviewFit.cover
        ? ca.CameraPreviewFit.cover
        : ca.CameraPreviewFit.contain;
  }

  dynamic _mapFlashMode(CameraFlashMode mode) {
    if (_delegate.platformTag == 'ohos') {
      switch (mode) {
        case CameraFlashMode.off:
          return ohos.FlashMode.none;
        case CameraFlashMode.on:
          return ohos.FlashMode.always;
        case CameraFlashMode.auto:
          return ohos.FlashMode.auto;
        case CameraFlashMode.torch:
          return ohos.FlashMode.always;
      }
    } else {
      switch (mode) {
        case CameraFlashMode.off:
          return ca.FlashMode.none;
        case CameraFlashMode.on:
          return ca.FlashMode.always;
        case CameraFlashMode.auto:
          return ca.FlashMode.auto;
        case CameraFlashMode.torch:
          return ca.FlashMode.always;
      }
    }
  }

  Future<Directory> _getTempDir() => getTemporaryDirectory();
  Future<String> _getDbPath() => getDatabasesPath();
}
