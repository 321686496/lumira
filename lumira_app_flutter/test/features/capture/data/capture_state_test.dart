import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';

void main() {
  group('CaptureState', () {
    test('originalTemplateProvider returns null when no template selected', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(CaptureState.originalTemplateProvider), isNull);
    });

    test('originalTemplateProvider returns template when id is set', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(CaptureState.currentTemplateIdProvider.notifier).state = 'soft_portrait';
      final tpl = container.read(CaptureState.originalTemplateProvider);
      expect(tpl, isNotNull);
      expect(tpl!.meta.id, 'soft_portrait');
      expect(tpl.meta.name, '窗边柔光人像');
    });

    test('editableTemplateProvider initializes as copy of original', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(CaptureState.currentTemplateIdProvider.notifier).state = 'soft_portrait';
      final original = container.read(CaptureState.originalTemplateProvider);
      final editable = container.read(CaptureState.editableTemplateProvider);
      expect(editable, isNotNull);
      expect(editable!.meta.id, 'soft_portrait');
      // Not the same instance (copyWith creates a new object)
      expect(identical(editable, original), false);
      // But equal by value
      expect(editable == original, true);
    });

    test('appliedProvider is true when editable matches original', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(CaptureState.currentTemplateIdProvider.notifier).state = 'soft_portrait';
      // Read to initialize
      container.read(CaptureState.editableTemplateProvider);
      expect(container.read(CaptureState.appliedProvider), true);
    });

    test('appliedProvider is false when editable differs from original', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(CaptureState.currentTemplateIdProvider.notifier).state = 'soft_portrait';
      // Read to initialize
      final editable = container.read(CaptureState.editableTemplateProvider);
      // Modify editable
      container.read(CaptureState.editableTemplateProvider.notifier).state =
          editable!.copyWith(camera: editable.camera.copyWith(iso: 800));
      expect(container.read(CaptureState.appliedProvider), false);
    });

    test('appliedProvider is false when no template selected', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(CaptureState.appliedProvider), false);
    });

    test('editableTemplateProvider resets when template changes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(CaptureState.currentTemplateIdProvider.notifier).state = 'soft_portrait';
      final editable1 = container.read(CaptureState.editableTemplateProvider);
      expect(editable1!.meta.id, 'soft_portrait');
      // Change template
      container.read(CaptureState.currentTemplateIdProvider.notifier).state = 'cafe_table';
      final editable2 = container.read(CaptureState.editableTemplateProvider);
      expect(editable2!.meta.id, 'cafe_table');
    });

    test('rawModeProvider defaults to false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(CaptureState.rawModeProvider), false);
    });

    test('panelExpandedProvider defaults to false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(CaptureState.panelExpandedProvider), false);
    });

    test('activeSceneFilterProvider returns null when no scene selected', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(CaptureState.activeSceneFilterProvider), isNull);
    });

    test('activeSceneFilterProvider returns lut when scene selected', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(CaptureState.activeScenePresetIdProvider.notifier).state = 'cafe-window';
      // activeSceneFilterProvider returns a SceneFilter (lut + systemFilter)
      final filter = container.read(CaptureState.activeSceneFilterProvider);
      expect(filter, isNotNull);
      expect(filter!.lut, 'warm_film');
    });

    test('levelEnabledProvider defaults to true', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(CaptureState.levelEnabledProvider), true);
    });

    test('resetAll does not reset persisted levelEnabledProvider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // levelEnabledProvider 是持久化设置（DB 驱动），resetAll 不应重置它
      container.read(CaptureState.levelEnabledProvider.notifier).state = false;
      CaptureState.resetAll(container);
      expect(container.read(CaptureState.levelEnabledProvider), false);
    });

    group('delayTimerProvider', () {
      test('defaults to 0 (disabled / instant capture)', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        expect(container.read(CaptureState.delayTimerProvider), 0);
      });

      test('can be set to a selected seconds value', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(CaptureState.delayTimerProvider.notifier).state = 5;
        expect(container.read(CaptureState.delayTimerProvider), 5);
      });

      test('delayOptions exposes off/3/5/10 seconds', () {
        expect(CaptureState.delayOptions, [0, 3, 5, 10]);
      });
    });

    test('resetAll clears all new providers', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Set some state
      container.read(CaptureState.currentTemplateIdProvider.notifier).state = 'soft_portrait';
      container.read(CaptureState.rawModeProvider.notifier).state = true;
      container.read(CaptureState.panelExpandedProvider.notifier).state = true;
      container.read(CaptureState.activeScenePresetIdProvider.notifier).state = 'cafe-window';
      container.read(CaptureState.levelEnabledProvider.notifier).state = false;
      // Reset
      CaptureState.resetAll(container);
      // Verify cleared
      expect(container.read(CaptureState.currentTemplateIdProvider), isNull);
      expect(container.read(CaptureState.rawModeProvider), false);
      expect(container.read(CaptureState.panelExpandedProvider), false);
      expect(container.read(CaptureState.activeScenePresetIdProvider), isNull);
      // levelEnabledProvider 为持久化设置，resetAll 后保持原值（false）
      expect(container.read(CaptureState.levelEnabledProvider), false);
      expect(container.read(CaptureState.originalTemplateProvider), isNull);
      expect(container.read(CaptureState.editableTemplateProvider), isNull);
    });
  });
}
