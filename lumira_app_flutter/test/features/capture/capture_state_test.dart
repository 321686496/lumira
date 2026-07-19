import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';

void main() {
  group('CaptureState', () {
    test('providers have correct default values', () {
      final container = ProviderContainer();

      expect(container.read(CaptureState.currentTemplateIdProvider), isNull);
      expect(container.read(CaptureState.flashModeProvider),
          CaptureFlashMode.off);
      expect(container.read(CaptureState.isFullscreenProvider), isFalse);
      expect(container.read(CaptureState.showTemplateProvider), isTrue);
      expect(container.read(CaptureState.showSilhouetteProvider), isTrue);
      expect(container.read(CaptureState.lastPhotoPathProvider), isNull);
      expect(container.read(CaptureState.cameraFacingProvider), 'back');

      container.dispose();
    });

    test('resetAll resets all providers to defaults', () {
      final container = ProviderContainer();

      // 设置非默认值
      container.read(CaptureState.currentTemplateIdProvider.notifier).state =
          'tpl_123';
      container.read(CaptureState.flashModeProvider.notifier).state =
          CaptureFlashMode.torch;
      container.read(CaptureState.isFullscreenProvider.notifier).state = true;
      container.read(CaptureState.showTemplateProvider.notifier).state = false;
      container.read(CaptureState.showSilhouetteProvider.notifier).state =
          false;
      container.read(CaptureState.lastPhotoPathProvider.notifier).state =
          '/tmp/photo.jpg';
      container.read(CaptureState.cameraFacingProvider.notifier).state =
          'front';

      // 重置
      // Forced fix: brief 写法 `CaptureState.resetAll(container.read)` 与
      // `resetAll(ProviderContainer container)` 签名不匹配（container.read 是
      // 函数引用）。改为直接传 container。
      CaptureState.resetAll(container);

      // 验证
      expect(container.read(CaptureState.currentTemplateIdProvider), isNull);
      expect(container.read(CaptureState.flashModeProvider),
          CaptureFlashMode.off);
      expect(container.read(CaptureState.isFullscreenProvider), isFalse);
      expect(container.read(CaptureState.showTemplateProvider), isTrue);
      expect(container.read(CaptureState.showSilhouetteProvider), isTrue);
      expect(container.read(CaptureState.lastPhotoPathProvider), isNull);
      expect(container.read(CaptureState.cameraFacingProvider), 'back');

      container.dispose();
    });
  });
}
