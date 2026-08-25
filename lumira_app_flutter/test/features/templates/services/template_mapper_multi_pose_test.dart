// test/features/templates/services/template_mapper_multi_pose_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';

void main() {
  group('TemplateMeta images/cover 派生', () {
    test('images 由 cover/coverData 派生（首张即封面）', () {
      const meta = TemplateMeta(
        id: 't1',
        name: 'n',
        category: 'portrait',
        classification: TemplateClassification(type: 'portrait'),
        cover: 'u0',
      );
      expect(meta.cover, 'u0');
      expect(meta.images.length, 1);
      expect(meta.images.first.url, 'u0');
      expect(meta.images.first.data, isNull);
    });

    test('cover 为空时 images 为空列表', () {
      const meta = TemplateMeta(
        id: 't1',
        name: 'n',
        category: 'portrait',
        classification: TemplateClassification(type: 'portrait'),
      );
      expect(meta.cover, '');
      expect(meta.images, isEmpty);
    });
  });

  group('PhotoTemplate poses', () {
    test('poses 列表 + pose 兼容 getter 返回 poses.first', () {
      const t = PhotoTemplate(
        meta: TemplateMeta(
          id: 't1',
          name: 'n',
          category: 'portrait',
          classification: TemplateClassification(type: 'portrait'),
        ),
        composition: Composition(),
        poses: <Pose>[Pose(name: 'a'), Pose(name: 'b', description: 'x')],
        camera: CameraParams(),
        sceneGuide: SceneGuide(),
        postProcess: PostProcess(color: PostProcessColor()),
      );
      expect(t.poses.length, 2);
      expect(t.poses.first.name, 'a');
      expect(t.pose.name, 'a');
    });

    test('构造仍兼容旧 pose: 单参数', () {
      const t = PhotoTemplate(
        meta: TemplateMeta(
          id: 't1',
          name: 'n',
          category: 'portrait',
          classification: TemplateClassification(type: 'portrait'),
        ),
        composition: Composition(),
        pose: Pose(name: 'legacy'),
        camera: CameraParams(),
        sceneGuide: SceneGuide(),
        postProcess: PostProcess(color: PostProcessColor()),
      );
      expect(t.poses.length, 1);
      expect(t.poses.first.name, 'legacy');
      expect(t.pose.name, 'legacy');
    });
  });
}