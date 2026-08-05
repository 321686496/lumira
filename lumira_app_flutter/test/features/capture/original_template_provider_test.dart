import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';

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

  test('originalTemplateProvider returns custom template from cache', () async {
    // Create a custom template not in TemplateRegistry
    final customTemplate = PhotoTemplate(
      meta: TemplateMeta(
        id: 'custom_test_template_001',
        name: '测试自定义模板',
        author: 'test',
        version: '1.0.0',
        category: 'portrait',
        classification: TemplateClassification(type: 'portrait'),
        tags: [],
        tagIds: [],
        price: 0,
        cover: '',
        description: 'test',
        referenceSource: '',
      ),
      composition: Composition(),
      pose: Pose(),
      camera: CameraParams(),
      sceneGuide: SceneGuide(),
      postProcess: PostProcess(color: PostProcessColor()),
    );

    final container = ProviderContainer(
      overrides: [
        CaptureState.allTemplatesProvider.overrideWith((ref) async => [customTemplate]),
      ],
    );
    addTearDown(container.dispose);

    // Wait for allTemplatesProvider to load
    await container.read(CaptureState.allTemplatesProvider.future);

    // Set the current template to the custom template's id
    container.read(CaptureState.currentTemplateIdProvider.notifier).state =
        'custom_test_template_001';

    // Now originalTemplateProvider should find it in the cache
    final template = container.read(CaptureState.originalTemplateProvider);
    expect(template, isNotNull);
    expect(template!.meta.id, 'custom_test_template_001');
  });
}
