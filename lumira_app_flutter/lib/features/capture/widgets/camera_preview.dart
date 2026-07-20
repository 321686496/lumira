import 'package:camerawesome_ohos/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/capture_state.dart';

/// 相机预览组件
///
/// 使用 camerawesome_ohos 1.0.2（CPF-Flutter Harmony 适配版本，对应原 camerawesome 1.4.0）实现。
/// 在真实设备上渲染相机预览；在 widget 测试中通过 cameraPreviewOverrideProvider 覆盖为占位 widget。
///
/// 视觉规格来源：lumira-app/src/pages/capture/index.vue line 44-68
///
/// Forced fix: brief 原代码使用 camerawesome 1.5+ 的 API（sensorConfig / SingleCaptureRequest /
/// CaptureRequestType / mediaCapture.capture(onSuccess:, onImage:) / builder:），与已锁定的
/// camerawesome 1.4.0 实际 API 不匹配。1.4.0 的 `.awesome()` 工厂仅接受 `sensor:` 和 `flashMode:`
/// 两个独立参数；`SaveConfig.photo(pathBuilder:)` 的 pathBuilder 返回 `Future<String>`；
/// `onMediaTap` 在用户点击已保存媒体缩略图时触发，参数为 `MediaCapture` 数据类（无 capture 方法）。
///
/// Harmony 适配：pub.dev 上的 camerawesome 无 ohos 实现，平台通道无人响应会导致取景器一直转圈。
/// 改用 CPF-Flutter fork 的 camerawesome_ohos 包（gitcode.com/CPF-Flutter/fluttertpc_camerawesome）。
class CameraPreview extends ConsumerWidget {
  const CameraPreview({super.key, required this.onCaptured});

  /// 拍照完成回调（传入文件路径）
  final void Function(String path) onCaptured;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overrideWidget = ref.watch(cameraPreviewOverrideProvider);

    if (overrideWidget != null) {
      return overrideWidget;
    }

    final flashMode = ref.watch(CaptureState.flashModeProvider);
    final facing = ref.watch(CaptureState.cameraFacingProvider);

    return CameraAwesomeBuilder.awesome(
      saveConfig: SaveConfig.photo(
        pathBuilder: () async {
          // 1.4.0: pathBuilder 返回 Future<String>（路径），由调用方决定保存位置
          // 实际生产中应使用 path_provider 生成时间戳路径；MVP 阶段先返回空字符串占位
          return '';
        },
      ),
      sensor: facing == 'front' ? Sensors.front : Sensors.back,
      flashMode: _mapFlashMode(flashMode),
      onMediaTap: (mediaCapture) {
        // 1.4.0: onMediaTap 在用户点击已保存媒体的缩略图时触发
        // mediaCapture 是数据类，包含 filePath 与 status（无 capture 方法）
        if (mediaCapture.status == MediaCaptureStatus.success &&
            mediaCapture.filePath.isNotEmpty) {
          onCaptured(mediaCapture.filePath);
        }
      },
    );
  }

  FlashMode _mapFlashMode(CaptureFlashMode mode) {
    switch (mode) {
      case CaptureFlashMode.off:
        return FlashMode.none;
      case CaptureFlashMode.on:
        return FlashMode.always;
      case CaptureFlashMode.auto:
        return FlashMode.auto;
      case CaptureFlashMode.torch:
        return FlashMode.always;
    }
  }
}

/// 测试覆写 provider（生产环境为 null，测试中注入占位 widget）
final cameraPreviewOverrideProvider = Provider<Widget?>((ref) => null);
