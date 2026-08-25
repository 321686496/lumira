// test/features/templates/services/template_mapper_multi_pose_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/templates/services/template_mapper.dart';

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

  group('TemplateMapper 多姿势映射往返', () {
    test('toPhotoTemplate 读取新版 List pose_json → 多姿势', () {
      final rec = TemplateRecord(
        id: 't1',
        name: 'n',
        author: '',
        version: '1.0',
        category: 'portrait',
        classification: {'type': 'portrait'},
        tags: const [],
        tagIds: const [],
        price: 0,
        cover: 'u0',
        description: '',
        referenceSource: '',
        composition: const {},
        pose: [
          {'name': 'a'},
          {'name': 'b', 'description': 'x'},
        ],
        camera: const {},
        sceneGuide: const {},
        postProcess: const {},
        createdAt: 1,
        updatedAt: 1,
        isBuiltin: true,
        isRecommended: false,
      );
      final t = TemplateMapper.toPhotoTemplate(rec);
      expect(t.poses.length, 2);
      expect(t.meta.cover, 'u0'); // cover 字段直接读取
      expect(t.pose.name, 'a');
    });

    test('toPhotoTemplate 兼容旧单 Map pose_json → 单姿势数组', () {
      final rec = TemplateRecord(
        id: 't1',
        name: 'n',
        author: '',
        version: '1.0',
        category: 'portrait',
        classification: {'type': 'portrait'},
        tags: const [],
        tagIds: const [],
        price: 0,
        cover: '',
        description: '',
        referenceSource: '',
        composition: const {},
        pose: {
          'silhouette': {'type': 'builtin', 'data': 'none'}
        },
        camera: const {},
        sceneGuide: const {},
        postProcess: const {},
        createdAt: 1,
        updatedAt: 1,
        isBuiltin: true,
        isRecommended: false,
      );
      final t = TemplateMapper.toPhotoTemplate(rec);
      expect(t.poses.length, 1);
    });

    test('toRecord 将多姿势写为数组', () {
      const tpl = PhotoTemplate(
        meta: TemplateMeta(
          id: 't1',
          name: 'n',
          category: 'portrait',
          classification: TemplateClassification(type: 'portrait'),
          cover: 'u0',
        ),
        composition: Composition(),
        poses: [Pose(name: 'a', description: 'first'), Pose(name: 'b')],
        camera: CameraParams(),
        sceneGuide: SceneGuide(),
        postProcess: PostProcess(color: PostProcessColor()),
      );
      final rec = TemplateMapper.toRecord(tpl, createdAt: 1);
      expect(rec.pose, isA<List>());
      expect((rec.pose as List).length, 2);
      expect((rec.pose as List).first['name'], 'a');
    });
  });
}
