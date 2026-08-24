import 'dart:async';
import 'dart:io' show Platform;

import 'package:camerawesome_ohos/camerawesome_plugin.dart' as ohos;
import 'package:camerawesome/camerawesome_plugin.dart' as ca;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' show getDatabasesPath;

import 'camera_service.dart';
import 'camerawesome_delegate.dart';
import 'white_balance.dart';

/// camerawesome 系列三端共用实现。
///
/// 重置说明（三端默认成像）：
/// - setZoom 统一传 [0,1] 归一化值（camerawesome 默认语义）
/// - buildPreview 使用默认 cover 填充
/// - capture 走 camerawesome 默认 SaveConfig.photo 流程
/// - 双指捏合缩放在 App 层（CameraPreview._PinchZoomCamera）统一处理，
///   不再使用 camerawesome 内置 onPreviewScale，仅保留点击对焦
/// - 不查询设备真实 minZoom/maxZoom，不做任何重映射
class CamerawesomeCameraService implements CameraService {
  CamerawesomeCameraService(this._delegate);

  final CamerawesomeDelegate _delegate;

  /// camerawesome 的 CameraState（按平台不同，用 dynamic 持有避免类型冲突）
  dynamic _cameraState;
  final _readyController = StreamController<bool>.broadcast();

  /// 设备真实缩放范围缓存（避免每次 zoom 都查询）
  double? _cachedMaxZoom;
  double? _cachedMinZoom;

  /// 上次 buildPreview 时的 facing，仅在 facing 切换时清空缩放缓存
  String? _lastBuildFacing;

  @override
  Stream<bool> get readyStream => _readyController.stream;

  @override
  Future<void> initialize({required String facing}) async {
    // 拍摄页可能被重复进入/退出，相机服务是 app 级单例，必须保证每次进入
    // 都从干净状态开始：
    // 1. 清除上一会话持有的 cameraState，避免后续 capture() 复用已释放实例
    // 2. 清除缩放能力缓存，保证重新查询当前会话的设备能力
    // 3. 先发 false 再等待上一会话的插件 stop 完成（幂等，已停止时立即返回）
    _cameraState = null;
    _cachedMaxZoom = null;
    _cachedMinZoom = null;
    _lastBuildFacing = null;
    if (!_readyController.isClosed) {
      _readyController.add(false);
    }
    try {
      if (_delegate.platformTag == 'ohos') {
        await ohos.CamerawesomePlugin.stop();
      } else {
        await ca.CamerawesomePlugin.stop();
      }
    } catch (e) {
      debugPrint('[camera] initialize stop failed: $e');
    }
  }

  @override
  Future<void> dispose() async {
    // 相机资源由 CameraAwesomeBuilder 自身的 CameraContext.dispose() 在卸载时停止，
    // 此处仅作幂等兜底：await 等待 stop 完成、清除 cameraState、防重复 close。
    // 注意：服务是 app 级单例，若在此关闭 _readyController 会导致再次进入拍摄页时
    // 取景器就绪流失效，因此保留 controller 不关闭（只清状态）。
    try {
      if (_delegate.platformTag == 'ohos') {
        await ohos.CamerawesomePlugin.stop();
      } else {
        await ca.CamerawesomePlugin.stop();
      }
    } catch (e) {
      debugPrint('[camera] dispose stop failed: $e');
    }
    _cameraState = null;
  }

  @override
  Future<CaptureResult> capture({required CaptureConfig config}) async {
    final completer = Completer<CaptureResult>();

    if (_cameraState == null) {
      throw StateError('Camera not initialized');
    }

    // 标记 takePhoto 是否已调用：过滤订阅时立即收到的旧事件
    bool captureInitiated = false;

    StreamSubscription? sub;
    sub = _cameraState.captureState$.listen((media) {
      if (media == null) return;
      final isSuccess = _delegate.platformTag == 'ohos'
          ? media.status == ohos.MediaCaptureStatus.success
          : media.status == ca.MediaCaptureStatus.success;
      if (isSuccess && media.filePath.isNotEmpty) {
        if (!captureInitiated) return;
        sub?.cancel();
        completer.complete(CaptureResult(
          filePath: media.filePath,
          sensorWidth: 0,
          sensorHeight: 0,
          orientation: SensorOrientation.portrait,
        ));
      }
    });

    // 关键：等待一个事件循环，让 BehaviorSubject 的微任务先执行完毕。
    // captureState$ 是 BehaviorSubject，listen 时会在微任务中异步发出上一次的
    // success 事件。如果立即设置 captureInitiated=true 并调用 takePhoto()，
    // 微任务执行时 captureInitiated 已为 true，旧事件会被误匹配，导致连续拍照时
    // 返回前一次的文件路径。这里用 Future.delayed(Duration.zero) 让出执行权，
    // 使旧事件在 captureInitiated=false 时被过滤，然后再开始本次拍照。
    await Future.delayed(Duration.zero);

    captureInitiated = true;
    try {
      _cameraState.when(
        onPhotoMode: (photoState) => photoState.takePhoto(),
      );
    } catch (e) {
      sub?.cancel();
      completer.completeError(e);
    }

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        sub?.cancel();
        throw TimeoutException('Camera capture timed out');
      },
    );
  }

  @override
  Future<void> switchCamera(String facing) async {
    // 切换摄像头后设备缩放范围可能变化，清空缓存强制下次重新查询
    _cachedMaxZoom = null;
    _cachedMinZoom = null;
    _readyController.add(false);
  }

  @override
  void setZoom(double normalized) {
    // 统一传 [0,1] 归一化值（camerawesome 默认语义）
    final clamped = normalized.clamp(0.0, 1.0);
    try {
      if (_delegate.platformTag == 'ohos') {
        ohos.CamerawesomePlugin.setZoom(clamped);
      } else {
        _cameraState?.sensorConfig?.setZoom(clamped);
      }
    } catch (e) {
      debugPrint('[camera] setZoom failed: $e');
    }
  }

  @override
  void setZoomMultiplier(double multiplier) {
    if (_delegate.platformTag == 'ohos') {
      // OHOS: setZoom 接收真实倍数
      try {
        ohos.CamerawesomePlugin.setZoom(multiplier);
      } catch (e) {
        debugPrint('[camera] OHOS setZoom failed: $e');
      }
    } else {
      // iOS/Android: setZoom 接收 [0,1] 归一化值
      // 注意：若 _cachedMaxZoom/_cachedMinZoom 为 null（查询未完成或失败），
      // 不能用 fallback 10.0/1.0 计算，否则前置摄像头会用后置的 maxZoom 范围
      // 归一化，导致 2x 对应的归一化值过小，实际 zoom 几乎不变（表现为点击无效）。
      // 此时改为异步查询真实范围后再设置。
      final maxZoom = _cachedMaxZoom;
      final minZoom = _cachedMinZoom;
      if (maxZoom == null || minZoom == null) {
        _setZoomMultiplierAsync(multiplier);
        return;
      }
      try {
        final normalized = ((multiplier - minZoom) / (maxZoom - minZoom))
            .clamp(0.0, 1.0);
        _cameraState?.sensorConfig?.setZoom(normalized);
      } catch (e) {
        debugPrint('[camera] native setZoom failed: $e');
      }
    }
  }

  /// 异步查询缩放范围后设置 zoom（用于缓存未就绪时的 fallback）。
  Future<void> _setZoomMultiplierAsync(double multiplier) async {
    try {
      final maxZoom = await getMaxZoomMultiplier();
      final minZoom = await getMinZoomMultiplier();
      final normalized = ((multiplier - minZoom) / (maxZoom - minZoom))
          .clamp(0.0, 1.0);
      _cameraState?.sensorConfig?.setZoom(normalized);
    } catch (e) {
      debugPrint('[camera] async setZoom failed: $e');
    }
  }

  @override
  Future<double> getMaxZoomMultiplier() async {
    if (_cachedMaxZoom != null) return _cachedMaxZoom!;
    // OHOS: camerawesome fork 的 getMaxZoom() 返回类型不稳定（int vs double?），
    // 且 CamerawesomePlugin 声明为 Future<double?> 但实际返回 int，导致类型转换异常。
    // 直接返回默认值 10.0，避免每次启动打印类型转换错误。
    if (_delegate.platformTag == 'ohos') {
      _cachedMaxZoom = 10.0;
      return 10.0;
    }
    try {
      final raw = await ca.CamerawesomePlugin.getMaxZoom();
      final maxZoom = raw is num ? raw.toDouble() : (double.tryParse(raw.toString()) ?? 10.0);
      _cachedMaxZoom = maxZoom.clamp(1.0, 50.0);
      return _cachedMaxZoom!;
    } catch (e) {
      debugPrint('[camera] getMaxZoom failed: $e');
      _cachedMaxZoom = 10.0;
      return 10.0;
    }
  }

  @override
  Future<double> getMinZoomMultiplier() async {
    if (_cachedMinZoom != null) return _cachedMinZoom!;
    try {
      if (_delegate.platformTag == 'ohos') {
        // OHOS fork 的 CamerawesomePlugin 未暴露 getMinZoom（仅 getMaxZoom），
        // 统一按 0.5 兜底（等价于原有「查询失败/未就绪」的 fallback 分支）
        _cachedMinZoom = 0.5;
        return _cachedMinZoom!;
      }
      if (Platform.isIOS) {
        // iOS: camerawesome 1.4.0 硬编码 minZoom=1.0
        _cachedMinZoom = 1.0;
        return 1.0;
      }
      // Android: camerawesome 未暴露 getMinZoomRatio，假设 0.5
      // setLinearZoom(0.0) 会到 minZoomRatio，UI 显示 0.5x 视觉正确
      _cachedMinZoom = 0.5;
      return 0.5;
    } catch (e) {
      debugPrint('[camera] getMinZoom failed: $e');
      _cachedMinZoom = _delegate.platformTag == 'ohos' ? 0.5 : 1.0;
      return _cachedMinZoom!;
    }
  }

  @override
  Future<bool> supportsUltraWide() async {
    final minZoom = await getMinZoomMultiplier();
    return minZoom < 1.0;
  }

  @override
  void setFlashMode(CameraFlashMode mode) {
    final flashMode = _mapFlashMode(mode);
    try {
      _cameraState?.sensorConfig?.setFlashMode(flashMode);
    } catch (e) {
      debugPrint('[camera] setFlashMode failed: $e');
    }
  }

  @override
  void setBrightness(double brightness) {
    try {
      _cameraState?.sensorConfig?.setBrightness(brightness.clamp(0.0, 1.0));
    } catch (e) {
      debugPrint('[camera] setBrightness failed: $e');
    }
  }

  @override
  void setWhiteBalance(WhiteBalanceSettings settings) {
    final mode = settings.mode.name;
    debugPrint(
        '[camera] setWhiteBalance DISPATCH mode=$mode k=${settings.temperatureK} platform=${_delegate.platformTag}');
    try {
      if (_delegate.platformTag == 'ohos') {
        ohos.CamerawesomePlugin.setWhiteBalance(mode, settings.temperatureK);
      } else {
        ca.CamerawesomePlugin.setWhiteBalance(mode, settings.temperatureK);
      }
    } catch (e) {
      debugPrint('[camera] setWhiteBalance failed: $e');
    }
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
    } catch (e) {
      debugPrint('[camera] focusOnPoint failed: $e');
    }
  }

  @override
  Widget buildPreview({required CameraPreviewConfig config}) {
    // 每次构建预览都从空状态开始，防止复用上一会话已释放的 cameraState
    // （CameraAwesomeBuilder 就绪后 builder 回调会重新赋值）。
    _cameraState = null;
    // 仅在 facing 切换时清空缩放缓存（不同摄像头的 maxZoom/minZoom 不同）。
    // 比例切换、参数调整等重建不再重复查询，避免 OHOS 平台 getMaxZoom/getMinZoom
    // 方法通道报错（PlatformException / int-double 类型转换异常）。
    if (_lastBuildFacing != config.facing) {
      _cachedMaxZoom = null;
      _cachedMinZoom = null;
      _lastBuildFacing = config.facing;
      // 摄像头切换开始：通知上层相机未就绪。
      // 快速连点切换会触发 CameraAwesomeBuilder 反复销毁重建，而原生相机的
      // init/start（PreparingCameraState.start 内含 500ms 异步延迟、且 dispose
      // 不会取消该延迟任务）可能重叠执行，导致取景器黑屏卡住。
      // 上层（capture_page）收到 false 后在切换完成（builder 回调发 true）前
      // 忽略再次切换，串行化摄像头切换。
      if (!_readyController.isClosed) {
        _readyController.add(false);
      }
    }
    if (_delegate.platformTag == 'ohos') {
      return _buildOhos(config);
    }
    return _buildNative(config);
  }

  Widget _buildOhos(CameraPreviewConfig config) {
    return ohos.CameraAwesomeBuilder.custom(
      saveConfig: ohos.SaveConfig.photo(
        pathBuilder: () async => await _buildPath(),
      ),
      sensor: config.facing == 'front' ? ohos.Sensors.front : ohos.Sensors.back,
      previewFit: _mapPreviewFitOhos(config.fit),
      builder: (cameraState, previewSize, previewRect) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _cameraState = cameraState;
          config.onReady?.call();
          if (!_readyController.isClosed) {
            _readyController.add(true);
          }
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
    );
  }

  Widget _buildNative(CameraPreviewConfig config) {
    return ca.CameraAwesomeBuilder.custom(
      saveConfig: ca.SaveConfig.photo(
        pathBuilder: () async => await _buildPath(),
      ),
      sensor: config.facing == 'front' ? ca.Sensors.front : ca.Sensors.back,
      previewFit: _mapPreviewFitNative(config.fit),
      builder: (cameraState, previewSize, previewRect) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _cameraState = cameraState;
          config.onReady?.call();
          if (!_readyController.isClosed) {
            _readyController.add(true);
          }
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
    );
  }

  /// 统一的拍照文件路径生成（三端共用，带兜底）
  Future<String> _buildPath() async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    try {
      final dir = await getTemporaryDirectory();
      return '${dir.path}/capture_$ts.jpg';
    } catch (e) {
      debugPrint('[camera] getTemporaryDirectory failed, fallback to dbPath: $e');
      final dbPath = await getDatabasesPath();
      return '$dbPath/capture_$ts.jpg';
    }
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
}
