import 'dart:async';
import 'package:flutter/material.dart';

import 'white_balance.dart';

/// 平台无关的相机服务接口。
/// 阶段一：三端实现各自封装 camerawesome（ohos fork / 原版 1.4.0）
/// 阶段二：替换为各端原生相机层，本接口零改动
abstract class CameraService {
  /// 初始化相机。facing = 'front' | 'back'
  Future<void> initialize({required String facing});

  /// 释放相机资源
  Future<void> dispose();

  /// 拍照。返回原始 JPEG 文件路径（传感器直出，未做任何后处理）。
  Future<CaptureResult> capture({required CaptureConfig config});

  /// 切换前后摄像头
  Future<void> switchCamera(String facing);

  /// 设置缩放（真实倍数，1.0 = 1x，0.5 = 0.5x）
  void setZoom(double multiplier);

  /// 设置闪光灯模式
  void setFlashMode(CameraFlashMode mode);

  /// 设置亮度校正（0.0~1.0，0.5 为中性）
  /// 用于将 EV 补偿映射到取景器亮度预览
  void setBrightness(double brightness);

  /// 设置传感器级白平衡（预设 + 手动色温 K）。取景实时生效，直出即带。
  void setWhiteBalance(WhiteBalanceSettings settings);

  /// 点击对焦
  void focusOnPoint(Offset flutterPosition, Size flutterPreviewSize);

  /// 锁定/解锁对焦与曝光（长按锁定 AE/AF）。
  /// locked=true 时必传 position+previewSize；locked=false 时忽略坐标，恢复连续自动对焦/曝光。
  void setFocusAndExposureLock({
    required bool locked,
    Offset? position,
    Size? previewSize,
  });

  /// 取景器 widget（平台实现负责构建原生预览）
  Widget buildPreview({required CameraPreviewConfig config});

  /// 相机就绪状态流（用于 UI 显示"正在初始化"提示）
  Stream<bool> get readyStream;

  /// 设置缩放倍数（真实倍数，如 0.5/1.0/2.0）。
  /// 内部按平台转换：OHOS 传真实倍数，iOS/Android 转归一化 [0,1]。
  void setZoomMultiplier(double multiplier);

  /// 获取设备最大缩放倍数（真实倍数）。
  /// 失败时返回 fallback 值 10.0。
  Future<double> getMaxZoomMultiplier();

  /// 获取设备最小缩放倍数（真实倍数）。
  /// iOS 固定 1.0，OHOS/Android 可 < 1.0（支持超广角时）。
  /// 失败时返回 fallback 值 1.0。
  Future<double> getMinZoomMultiplier();

  /// 是否支持超广角（minZoom < 1.0）。
  Future<bool> supportsUltraWide();
}

/// 拍照结果（平台无关，不携带 camerawesome 的 MediaCapture）
class CaptureResult {
  const CaptureResult({
    required this.filePath,
    required this.sensorWidth,
    required this.sensorHeight,
    required this.orientation,
    this.timestampMs,
  });
  final String filePath;
  final int sensorWidth;
  final int sensorHeight;
  final SensorOrientation orientation;
  final int? timestampMs;
}

/// 拍照配置快照（按下快门时的状态）
class CaptureConfig {
  const CaptureConfig({
    required this.facing,
    required this.zoomMultiplier,
    required this.flashMode,
    this.evCompensation,
  });
  final String facing;
  final double zoomMultiplier;
  final CameraFlashMode flashMode;
  final double? evCompensation;
}

enum CameraFlashMode { off, on, auto, torch }
enum SensorOrientation { portrait, landscape, portraitUpsideDown, landscapeLeft }

/// 取景器配置
class CameraPreviewConfig {
  const CameraPreviewConfig({
    required this.facing,
    this.fit = CameraPreviewFit.cover,
    this.onReady,
    this.onTapFocus,
  });
  final String facing;
  final CameraPreviewFit fit;
  final VoidCallback? onReady;
  final void Function(Offset, Size)? onTapFocus;
}

enum CameraPreviewFit { cover, contain }
