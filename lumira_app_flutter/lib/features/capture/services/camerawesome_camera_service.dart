import 'dart:async';
import 'dart:io';

import 'package:camerawesome_ohos/camerawesome_plugin.dart' as ohos;
import 'package:camerawesome_ohos/pigeon.dart' as ohos_pigeon;
import 'package:camerawesome/camerawesome_plugin.dart' as ca;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
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
    // 兜底：上一会话若处于锁定态，重置为连续自动对焦/曝光（新会话原生默认即自动，此调用幂等）
    setFocusAndExposureLock(locked: false);
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

  /// 拍照请求串行闸门（仅 Android/iOS）。
  ///
  /// 这两端的 native takePhoto 不支持并发：
  /// - Android cameraX 在上一张未完成时再次 takePicture 会直接失败；
  /// - iOS 并发调用会让 native 内部的「本次路径 ↔ 回调」配对错乱；
  /// 因此按发起顺序串行执行，每个请求一定能拿到**属于自己**的文件。
  ///
  /// OHOS 已放开并发（2026-09-26 原生修复①②③，见 docs/future-optimizations.md）：
  /// - ① ctx 仅在 photoOutput.capture() 受理成功后入队（FIFO = 受理顺序），
  ///   失败请求不再滞留队列导致后续帧错配；
  /// - ② capture() 抛 7400102（忙窗口，实测 0.4-0.7s）时原生内部按 300ms 间隔
  ///   重试排队（≤20 次 ≈6s < Dart 10s 超时），不把错误抛回 Dart；
  /// - ③ 增强兜底 path/result/ctx 改为 per-ctx 注入，result 必达恰好一次。
  /// 连拍各帧的 capture 立即发起，帧时刻贴近按快门瞬间（原串行使第 2..n 张的
  /// capture 推迟 ~1.9s×(n-1)，取到的帧比按快门时刻晚——正是「成片帧不对」根因）。
  Future<void> _captureChain = Future<void>.value();

  @override
  Future<CaptureResult> capture({required CaptureConfig config}) {
    // OHOS：原生已支持并发受理（忙窗口重试 + per-ctx result 必达），直接发起。
    if (_delegate.platformTag == 'ohos') {
      return _captureOnce(config);
    }
    // Android/iOS：本次请求排在所有已发起请求之后；链上错误不阻断后续请求排队。
    final result = _captureChain.then((_) => _captureOnce(config));
    _captureChain = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  /// 单次拍照体（Android/iOS 由 [_captureChain] 串行；OHOS 并发，原生保证配对）。
  Future<CaptureResult> _captureOnce(CaptureConfig config) async {
    if (_cameraState == null) {
      throw StateError('Camera not initialized');
    }

    // 直接 await 本次 takePhoto() 的返回值拿到**本次**文件路径，
    // 不再订阅共享广播流做事件匹配（并发时会串拍，返回他人的路径）。
    Future<String>? takePhotoFuture;
    _cameraState.when(
      onPhotoMode: (photoState) => takePhotoFuture = photoState.takePhoto(),
    );
    final pending = takePhotoFuture;
    if (pending == null) {
      throw StateError('Camera not in photo mode');
    }

    final path = await pending.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('Camera capture timed out'),
    );

    // takePhoto() 无论成败都会返回路径（失败时不落盘），据此判定本次结果。
    final file = File(path);
    if (!await file.exists() || await file.length() == 0) {
      throw StateError('Camera capture failed: $path');
    }

    return CaptureResult(
      filePath: path,
      sensorWidth: 0,
      sensorHeight: 0,
      orientation: SensorOrientation.portrait,
      // iOS 非闪光模式成片=取景器 video 帧直出（WYSIWYG），与 _mapFlashMode
      // 的 iOS 映射（off→none→原生 FlashOff）保持一致。
      isWysiwyg: _delegate.platformTag == 'ios' &&
          config.flashMode == CameraFlashMode.off,
    );
  }

  @override
  Future<String?> captureFrameForAnimation() async {
    // 仅 iOS 支持取景器帧直出；OHOS/Android 动画源走已拍原片硬解码，返回 null。
    if (_delegate.platformTag != 'ios') return null;
    try {
      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = p.join(dir.path, 'anim_frame_$ts.jpg');
      final ok = await ca.CamerawesomePlugin.captureFrameForAnimation(path);
      if (!ok) return null;
      return path;
    } catch (e) {
      debugPrint('[camera] captureFrameForAnimation failed: $e');
      return null;
    }
  }

  @override
  Stream<String> photoEarlyFrames() {
    // 仅 OHOS 支持分阶段拍照早帧；iOS 走取景器帧直出，Android 无早帧机制。
    if (_delegate.platformTag != 'ohos') return Stream<String>.empty();
    return ohos.CamerawesomePlugin.listenPhotoEarlyFrame() ?? Stream<String>.empty();
  }

  @override
  Stream<String> nativeLogs() {
    // 原生诊断日志桥：仅 OHOS 插件推送；其余平台返回空流。
    if (_delegate.platformTag != 'ohos') return Stream<String>.empty();
    return ohos.CamerawesomePlugin.listenNativeLog() ?? Stream<String>.empty();
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
        // OHOS：仅「手动拖动色温滑块」（manualK=true）下发连续色温 k（原生走
        // MANUAL 路径，仅后置支持）；预设 pill 点击（manualK=false）只下发 mode
        // 走 setWhiteBalanceMode 预设模式（前后置均支持）——前置 HDI 未实现
        // 手动色温接口，若把预设联动值 k 也下发会走 MANUAL 导致前置档位失效。
        ohos.CamerawesomePlugin.setWhiteBalance(
            mode, settings.manualK ? settings.temperatureK : null);
      } else {
        ca.CamerawesomePlugin.setWhiteBalance(mode, settings.temperatureK);
      }
    } catch (e) {
      debugPrint('[camera] setWhiteBalance failed: $e');
    }
  }

  @override
  void setFocusAndExposureLock({
    required bool locked,
    Offset? position,
    Size? previewSize,
  }) {
    try {
      // locked=false 时忽略坐标（恢复连续自动对焦/曝光）；locked=true 时做
      // iOS 前置镜像补偿（理由见 _mapToPreviewPoint）。
      final mapped = (locked && position != null && previewSize != null)
          ? _mapToPreviewPoint(
              _lastBuildFacing ?? 'back', position, previewSize)
          : position;
      if (_delegate.platformTag == 'ohos') {
        ohos.CamerawesomePlugin.setFocusAndExposureLock(
            locked: locked, position: mapped, previewSize: previewSize);
      } else {
        ca.CamerawesomePlugin.setFocusAndExposureLock(
            locked: locked, position: mapped, previewSize: previewSize);
      }
    } catch (e) {
      debugPrint('[camera] setFocusAndExposureLock failed: $e');
    }
  }

  /// iOS 前置预览层镜像补偿。
  ///
  /// iOS 侧 `CameraPreview.m` 对前置传感器设置了 `setVideoMirrored:(Sensor == Front)`，
  /// 预览画面水平镜像；而 Dart 侧手势触点是按「未镜像」的取景框坐标归一化后下发，
  /// 直接使用会导致「点左侧、实际对焦到画面右侧」。这里做水平翻转补偿
  /// （AVCam 官方做法 `devicePoint.x = 1 - devicePoint.x`）。
  /// Android（TextureView 管线，无 MIRROR_MODE）与 OHOS 预览未镜像，不翻转。
  Offset _mapToPreviewPoint(String facing, Offset position, Size previewSize) =>
      (Platform.isIOS && facing == 'front')
          ? Offset(previewSize.width - position.dx, position.dy)
          : position;

  @override
  void focusOnPoint(Offset flutterPosition, Size flutterPreviewSize) {
    try {
      // iOS 前置取景器镜像补偿（其余平台原样返回）
      final position = _mapToPreviewPoint(
          _lastBuildFacing ?? 'back', flutterPosition, flutterPreviewSize);
      if (_delegate.platformTag == 'ohos') {
        // OHOS: camerawesome_ohos 的 focusOnPoint 需要 pigeon 的 PreviewSize，
        // 不能直接传 Flutter 的 Size，否则抛「type 'Size' is not a subtype of
        // type 'PreviewSize'」被 catch 吞掉，原生对焦从未被调用
        // （表现为「黄框出现但画面无任何对焦效果」）。
        final ps = ohos_pigeon.PreviewSize(
          width: flutterPreviewSize.width,
          height: flutterPreviewSize.height,
        );
        _cameraState?.when(
          onPhotoMode: (photoState) => photoState.focusOnPoint(
            flutterPosition: position,
            pixelPreviewSize: ps,
            flutterPreviewSize: ps,
          ),
        );
      } else {
        _cameraState?.when(
          onPhotoMode: (photoState) => photoState.focusOnPoint(
            flutterPosition: position,
            pixelPreviewSize: flutterPreviewSize,
            flutterPreviewSize: flutterPreviewSize,
          ),
        );
      }
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
      legStretch: config.legStretch,
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
        // 屏蔽 camerawesome 默认白色对焦框：金色对焦框由 App 层 _FocusOverlay 渲染
        onTapPainter: null,
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
      legStretch: config.legStretch,
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
        // 屏蔽 camerawesome 默认白色对焦框：金色对焦框由 App 层 _FocusOverlay 渲染
        onTapPainter: null,
      ),
    );
  }

  /// 统一的拍照文件路径生成（三端共用）。
  ///
  /// 照片必须写入**持久化目录**（数据库同目录下的 `photos/` 子目录），不能写入
  /// 临时目录：iOS 在 App 更新/重装时会被系统清空 `tmp/`，导致已拍照片文件丢失
  /// （相册数据库记录仍在、文件却消失，表现为“更新后照片都没了”）。
  /// 鸿蒙端 path_provider 缺 ohos 原生实现，`getTemporaryDirectory()` 会抛
  /// `MissingPluginException`，此前依赖 catch 兜底落到 `getDatabasesPath()`（持久
  /// 目录），因此 OHOS 恰好不受影响。这里统一改为持久目录，三端行为一致。
  ///
  /// 防御性收紧：**绝不静默写进 tmp/**。持久目录依次取
  ///  1) `getDatabasesPath()`（iOS=Documents、OHOS=应用数据目录，均更新后保留）；
  ///  2) `getApplicationDocumentsDirectory()`（iOS 兜底，同样 Documents）。
  /// 两者都失败时宁可让本次拍照失败并明确抛错，也不把照片写进 tmp 造成
  /// “更新后文件无声消失、数据库记录仍在”的幽灵照片。
  Future<String> _buildPath() async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    String? chosen;
    String? lastErr;
    for (final base in await _persistentBases()) {
      try {
        final photosDir = Directory(p.join(base, 'photos'));
        if (!await photosDir.exists()) {
          await photosDir.create(recursive: true);
        }
        chosen = p.join(photosDir.path, 'capture_$ts.jpg');
        debugPrint('[camera] 照片存储路径(持久): $chosen');
        return chosen;
      } catch (e) {
        lastErr = e.toString();
      }
    }
    // 持久目录全部不可用：宁可拍照失败，也不写 tmp 造成更新后照片无声丢失
    debugPrint('[camera] 持久化照片目录全部不可用，放弃本次拍照(绝不写 tmp): $lastErr');
    throw StateError('持久化照片目录不可用，无法保存照片');
  }

  /// 候选持久目录基址（依次尝试）。
  Future<List<String>> _persistentBases() async {
    final bases = <String>[];
    try {
      bases.add(await getDatabasesPath());
    } catch (e) {
      debugPrint('[camera] getDatabasesPath 不可用: $e');
    }
    try {
      bases.add((await getApplicationDocumentsDirectory()).path);
    } catch (e) {
      debugPrint('[camera] getApplicationDocumentsDirectory 不可用: $e');
    }
    return bases;
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
