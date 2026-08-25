import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/templates/data/templates_editor_mock_data.dart';
import 'package:lumira_app_flutter/features/templates/services/template_mapper.dart';

void main() {
  group('EditorForm 兼容 pose getter', () {
    test('返回 poses.first', () {
      final f = EditorForm(
        meta: EditorFormMeta(name: 'n'),
        composition: EditorFormComposition(),
        poses: [
          EditorFormPose(description: 'a'),
          EditorFormPose(description: 'b'),
        ],
        camera: EditorFormCamera(),
        sceneGuide: EditorFormSceneGuide(),
        postProcess: EditorFormPostProcess(),
      );
      expect(f.poses.length, 2);
      expect(f.pose.description, 'a');
    });

    test('pose 参数可包装为单元素 poses', () {
      final f = EditorForm(
        meta: EditorFormMeta(name: 'n'),
        composition: EditorFormComposition(),
        pose: EditorFormPose(description: 'single'),
        camera: EditorFormCamera(),
        sceneGuide: EditorFormSceneGuide(),
        postProcess: EditorFormPostProcess(),
      );
      expect(f.poses.length, 1);
      expect(f.pose.description, 'single');
    });
  });

  group('EditorFormMeta images / coverImage', () {
    test('封面为第 0 张，coverImage getter 读首张', () {
      final m = EditorFormMeta(name: 'n')
        ..images = [
          EditorFormMetaImage(data: 'u0'),
          EditorFormMetaImage(data: 'u1'),
        ];
      expect(m.coverImage, 'u0');
    });

    test('coverImage 构造参数兼容：未传 images 时作为首张', () {
      final m = EditorFormMeta(name: 'n', coverImage: 'u0');
      expect(m.images.length, 1);
      expect(m.images.first.data, 'u0');
      expect(m.coverImage, 'u0');
    });

    test('setCoverImage 替换首张；addImage 追加', () {
      final m = EditorFormMeta(name: 'n');
      m.setCoverImage('cover');
      expect(m.coverImage, 'cover');
      m.addImage('img2');
      expect(m.images.length, 2);
      expect(m.images[1].data, 'img2');
      m.setCoverImage('newCover');
      expect(m.coverImage, 'newCover');
      expect(m.images[1].data, 'img2'); // 非首张保留
    });

    test('copy 深拷贝 images（互不影响）', () {
      final m = EditorFormMeta(name: 'n')
        ..images = [EditorFormMetaImage(data: 'a')];
      final c = m.copy();
      c.images.first.data = 'b';
      expect(m.images.first.data, 'a');
    });
  });

  group('fromEditorForm / toEditorForm 多姿势 / 多图', () {
    test('fromEditorForm 写多姿势数组 + 多图', () {
      final f = EditorForm(
        meta: (EditorFormMeta(name: 'n')
          ..images = [
            EditorFormMetaImage(data: 'u0'),
            EditorFormMetaImage(data: 'u1'),
          ]),
        composition: EditorFormComposition(),
        poses: [
          EditorFormPose(description: 'a', name: 'p1'),
          EditorFormPose(description: 'b'),
        ],
        camera: EditorFormCamera(),
        sceneGuide: EditorFormSceneGuide(),
        postProcess: EditorFormPostProcess(),
      );
      final rec = TemplateMapper.fromEditorForm(f, createdAt: 1);
      expect(rec.pose, isA<List<dynamic>>());
      expect((rec.pose as List).length, 2);
      expect(((rec.pose as List).first as Map)['name'], 'p1');
      expect(rec.images!.length, 2);
      expect(rec.images![0].data, 'u0');
      expect(rec.coverData, 'u0'); // 封面兼容回写
    });

    test('fromEditorForm 过滤空占位图', () {
      final f = EditorForm(
        meta: (EditorFormMeta(name: 'n')
          ..images = [
            EditorFormMetaImage(data: ''),
            EditorFormMetaImage(data: 'u1'),
          ]),
        composition: EditorFormComposition(),
        pose: EditorFormPose(description: 'a'),
        camera: EditorFormCamera(),
        sceneGuide: EditorFormSceneGuide(),
        postProcess: EditorFormPostProcess(),
      );
      final rec = TemplateMapper.fromEditorForm(f, createdAt: 1);
      expect(rec.images!.length, 1);
      expect(rec.images![0].data, 'u1');
    });

    test('toEditorForm 读多姿势 + 多图', () {
      final f = EditorForm(
        meta: (EditorFormMeta(name: 'n')
          ..images = [
            EditorFormMetaImage(data: 'u0'),
            EditorFormMetaImage(data: 'u1'),
          ]),
        composition: EditorFormComposition(),
        poses: [
          EditorFormPose(description: 'a', name: 'p1'),
          EditorFormPose(description: 'b', name: 'p2'),
        ],
        camera: EditorFormCamera(),
        sceneGuide: EditorFormSceneGuide(),
        postProcess: EditorFormPostProcess(),
      );
      final rec = TemplateMapper.fromEditorForm(f, createdAt: 1);
      final back = TemplateMapper.toEditorForm(rec);
      expect(back.poses.length, 2);
      expect(back.poses[0].name, 'p1');
      expect(back.poses[0].description, 'a');
      expect(back.meta.images.length, 2);
      expect(back.meta.coverImage, 'u0');
    });

    test('toEditorForm 兼容旧单 pose Map + 单 coverData', () {
      final f = EditorForm(
        meta: EditorFormMeta(name: 'n', coverImage: 'u0'),
        composition: EditorFormComposition(),
        pose: EditorFormPose(description: 'single'),
        camera: EditorFormCamera(),
        sceneGuide: EditorFormSceneGuide(),
        postProcess: EditorFormPostProcess(),
      );
      final rec = TemplateMapper.fromEditorForm(f, createdAt: 1);
      final back = TemplateMapper.toEditorForm(rec);
      expect(back.poses.length, 1);
      expect(back.poses[0].description, 'single');
      expect(back.meta.coverImage, 'u0');
    });
  });
}