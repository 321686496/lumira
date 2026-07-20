// test/features/capture/data/capture_state_test.dart
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
      expect(tpl.meta.name, '柔光人像');
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
      container.read(CaptureState.currentTemplateIdProvider.notifier).state = 'cafe_portrait';
      final editable2 = container.read(CaptureState.editableTemplateProvider);
      expect(editable2!.meta.id, 'cafe_portrait');
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
      expect(container.read(CaptureState.activeSceneFilterProvider), 'warm_film');
    });

    test('levelEnabledProvider defaults to true', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(CaptureState.levelEnabledProvider), true);
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
      expect(container.read(CaptureState.levelEnabledProvider), true);
      expect(container.read(CaptureState.originalTemplateProvider), isNull);
      expect(container.read(CaptureState.editableTemplateProvider), isNull);
    });
  });
}
