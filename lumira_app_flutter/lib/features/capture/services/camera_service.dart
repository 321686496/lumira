import 'dart:async';
import 'package:flutter/material.dart';

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

  /// 点击对焦
  void focusOnPoint(Offset flutterPosition, Size flutterPreviewSize);

  /// 取景器 widget（平台实现负责构建原生预览）
  Widget buildPreview({required CameraPreviewConfig config});

  /// 相机就绪状态流（用于 UI 显示"正在初始化"提示）
  Stream<bool> get readyStream;
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
    this.onScaleZoom,
  });
  final String facing;
  final CameraPreviewFit fit;
  final VoidCallback? onReady;
  final void Function(Offset, Size)? onTapFocus;
  final void Function(double)? onScaleZoom;
}

enum CameraPreviewFit { cover, contain }
