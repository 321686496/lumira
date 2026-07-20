// test/features/capture/domain/photo_template_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';

void main() {
  group('PhotoTemplate', () {
    final defaultColor = PostProcessColor(brightness: 0, contrast: 1, saturation: 1, temperature: 0, tint: 0);
    final defaultPost = PostProcess(color: defaultColor);
    final defaultMeta = TemplateMeta(id: 'test', name: 'Test', category: 'portrait',
        classification: TemplateClassification(type: 'portrait'));
    final defaultComp = Composition();
    final defaultPose = Pose();
    final defaultCam = CameraParams();
    final defaultGuide = SceneGuide();

    final template = PhotoTemplate(
      meta: defaultMeta,
      composition: defaultComp,
      pose: defaultPose,
      camera: defaultCam,
      sceneGuide: defaultGuide,
      postProcess: defaultPost,
    );

    test('copyWith preserves unchanged fields', () {
      final copy = template.copyWith();
      expect(copy.meta.id, 'test');
      expect(copy.camera.iso, 200);
    });

    test('copyWith overrides specified fields', () {
      final copy = template.copyWith(camera: CameraParams(iso: 800));
      expect(copy.camera.iso, 800);
      expect(copy.meta.id, 'test'); // unchanged
    });

    test('== compares all fields', () {
      final copy = template.copyWith();
      expect(copy == template, true);
      final diff = template.copyWith(camera: CameraParams(iso: 400));
      expect(diff == template, false);
    });

    test('hashCode equal for equal objects', () {
      final copy = template.copyWith();
      expect(copy.hashCode, template.hashCode);
    });
  });

  group('CameraParams', () {
    test('default iso is 200', () {
      expect(const CameraParams().iso, 200);
    });
    test('copyWith preserves nullable fields when not set', () {
      const cam = CameraParams(lensType: '1x');
      final copy = cam.copyWith(iso: 400);
      expect(copy.lensType, '1x');
      expect(copy.iso, 400);
    });
  });

  group('PostProcessColor', () {
    test('nullable fields default to null', () {
      const color = PostProcessColor();
      expect(color.highlights, isNull);
      expect(color.shadows, isNull);
      expect(color.clarity, isNull);
    });
    test('copyWith handles nullable fields', () {
      const color = PostProcessColor();
      final copy = color.copyWith(highlights: -10);
      expect(copy.highlights, -10);
    });
  });

  group('Pose defaults', () {
    test('default silhouette is builtin/none', () {
      const pose = Pose();
      expect(pose.silhouette.type, 'builtin');
      expect(pose.silhouette.data, 'none');
    });
    test('default position is center (0.5, 0.5)', () {
      const pose = Pose();
      expect(pose.position.x, 0.5);
      expect(pose.position.y, 0.5);
    });
  });
}
