import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';

void main() {
  test('originalTemplateProvider returns system template by id', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(CaptureState.currentTemplateIdProvider.notifier).state =
        'soft_portrait';
    final template = container.read(CaptureState.originalTemplateProvider);
    expect(template, isNotNull);
    expect(template!.meta.id, 'soft_portrait');
  });

  test('originalTemplateProvider returns null when templateId is null', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(CaptureState.currentTemplateIdProvider.notifier).state =
        null;
    final template = container.read(CaptureState.originalTemplateProvider);
    expect(template, isNull);
  });

  test('originalTemplateProvider returns null for unknown id (not in registry or cache)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(CaptureState.currentTemplateIdProvider.notifier).state =
        'nonexistent_template_id';
    // In test environment, DAO is unavailable, so templateCacheProvider falls back
    // to systemMap (system templates only). Unknown id is not in systemMap → null.
    final template = container.read(CaptureState.originalTemplateProvider);
    expect(template, isNull);
  });
}
