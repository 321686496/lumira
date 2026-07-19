import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 闪光灯模式
enum CaptureFlashMode {
  off,
  on,
  auto,
  torch,
}

/// 拍摄页状态 providers
///
/// 修复 uni-app 中"退出拍摄页后 currentTemplateId 残留影响后续自由拍摄"的 bug。
/// 所有状态在 LumiraRouteObserver.didPop 离开拍摄页时通过 _clearCaptureState 重置。
class CaptureState {
  CaptureState._();

  /// 当前模板 ID（null = 自由拍摄模式）
  /// 来源：URL query param `?templateId=xxx`
  static final currentTemplateIdProvider = StateProvider<String?>((ref) => null);

  /// 闪光灯模式
  static final flashModeProvider = StateProvider<CaptureFlashMode>((ref) => CaptureFlashMode.off);

  /// 全屏取景器开关
  static final isFullscreenProvider = StateProvider<bool>((ref) => false);

  /// 显示/隐藏模板叠图
  static final showTemplateProvider = StateProvider<bool>((ref) => true);

  /// 显示/隐藏姿势剪影
  static final showSilhouetteProvider = StateProvider<bool>((ref) => true);

  /// 最近拍摄照片路径（点击缩略图跳转预览页）
  static final lastPhotoPathProvider = StateProvider<String?>((ref) => null);

  /// 当前摄像头方向（front / back）
  static final cameraFacingProvider = StateProvider<String>((ref) => 'back');

  /// 重置所有拍摄页状态（在 LumiraRouteObserver._clearCaptureState 中调用）
  ///
  /// Forced fix: brief 原签名 `resetAll(Ref ref)` 与测试调用
  /// `CaptureState.resetAll(container.read)` 不兼容（`container.read` 是
  /// 函数引用而非 `Ref`）。改为接收 `ProviderContainer`，因为
  /// `ProviderContainer.read(provider.notifier).state = ...` 与 `Ref` 行为一致。
  /// 调用方 `LumiraRouteObserver._clearCaptureState` 传 `_ref.container`。
  static void resetAll(ProviderContainer container) {
    container.read(currentTemplateIdProvider.notifier).state = null;
    container.read(flashModeProvider.notifier).state = CaptureFlashMode.off;
    container.read(isFullscreenProvider.notifier).state = false;
    container.read(showTemplateProvider.notifier).state = true;
    container.read(showSilhouetteProvider.notifier).state = true;
    container.read(lastPhotoPathProvider.notifier).state = null;
    container.read(cameraFacingProvider.notifier).state = 'back';
  }
}
