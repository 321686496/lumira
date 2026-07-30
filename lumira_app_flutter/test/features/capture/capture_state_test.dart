import 'package:flutter/material.dart';
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

    test('toolbar and fillLight providers have correct defaults', () {
      final container = ProviderContainer();

      // 工具栏默认激活 'templates'
      expect(container.read(CaptureState.activeToolProvider), 'templates');

      // 补光默认关闭
      expect(container.read(CaptureState.fillLightEnabledProvider), isFalse);
      expect(container.read(CaptureState.fillLightColorProvider),
          const Color(0xFFFFE5B4));
      expect(container.read(CaptureState.fillLightIntensityProvider), 0.6);

      // fillLightStateProvider 在禁用时返回 null
      expect(container.read(CaptureState.fillLightStateProvider), isNull);

      container.dispose();
    });

    test('fillLightStateProvider returns snapshot when enabled', () {
      final container = ProviderContainer();

      // 启用补光
      container.read(CaptureState.fillLightEnabledProvider.notifier).state =
          true;
      container.read(CaptureState.fillLightColorProvider.notifier).state =
          const Color(0xFFFFB347); // 黄金
      container.read(CaptureState.fillLightIntensityProvider.notifier).state =
          0.8;

      final state = container.read(CaptureState.fillLightStateProvider);
      expect(state, isNotNull);
      expect(state!.color, const Color(0xFFFFB347));
      expect(state.intensity, 0.8);

      // 关闭后返回 null
      container.read(CaptureState.fillLightEnabledProvider.notifier).state =
          false;
      expect(container.read(CaptureState.fillLightStateProvider), isNull);

      container.dispose();
    });

    test('activeToolProvider toggles between tools', () {
      final container = ProviderContainer();

      // 默认 'templates'
      expect(container.read(CaptureState.activeToolProvider), 'templates');

      // 切换到 'fillLight'
      container.read(CaptureState.activeToolProvider.notifier).state =
          'fillLight';
      expect(container.read(CaptureState.activeToolProvider), 'fillLight');

      // 收起（设为 null）
      container.read(CaptureState.activeToolProvider.notifier).state = null;
      expect(container.read(CaptureState.activeToolProvider), isNull);

      container.dispose();
    });

    test('resetAll resets toolbar and fillLight providers', () {
      final container = ProviderContainer();

      // 设置非默认值
      container.read(CaptureState.activeToolProvider.notifier).state =
          'fillLight';
      container.read(CaptureState.fillLightEnabledProvider.notifier).state =
          true;
      container.read(CaptureState.fillLightColorProvider.notifier).state =
          const Color(0xFF8FD3F4);
      container.read(CaptureState.fillLightIntensityProvider.notifier).state =
          0.9;

      // 重置
      CaptureState.resetAll(container);

      // 验证恢复默认
      expect(container.read(CaptureState.activeToolProvider), 'templates');
      expect(container.read(CaptureState.fillLightEnabledProvider), isFalse);
      expect(container.read(CaptureState.fillLightColorProvider),
          const Color(0xFFFFE5B4));
      expect(container.read(CaptureState.fillLightIntensityProvider), 0.6);

      container.dispose();
    });
  });
}
