import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/templates/services/template_mapper.dart';

void main() {
  test('toRecord 写多张效果图到 images', () {
    final tpl = const PhotoTemplate(
      meta: TemplateMeta(
        id: 't1', name: 'n', category: 'portrait',
        classification: TemplateClassification(type: 'portrait'),
        images: [TemplateImage(url: 'u0'), TemplateImage(url: 'u1')],
      ),
      composition: Composition(),
      pose: Pose(name: 'a'),
      camera: CameraParams(),
      sceneGuide: SceneGuide(),
      postProcess: PostProcess(color: PostProcessColor()),
    );
    final rec = TemplateMapper.toRecord(tpl, createdAt: 1);
    expect(rec.images!.length, 2);
    expect(rec.images![0].url, 'u0');
    expect(rec.cover, 'u0'); // 首图兼容回写
  });

  test('toPhotoTemplate 优先读 images_json（多图）', () {
    final rec = TemplateRecord(
      id: 't1', name: 'n', author: '', version: '1.0', category: 'portrait',
      classification: const {'type': 'portrait'}, tags: const [], tagIds: const [],
      price: 0, cover: 'u0', description: '', referenceSource: '',
      composition: const {}, pose: <dynamic>[], camera: const {}, sceneGuide: const {},
      postProcess: const {}, createdAt: 1, updatedAt: 1,
      isBuiltin: true, isRecommended: false,
      images: const [TemplateImage(url: 'a'), TemplateImage(url: 'b')],
    );
    final tpl = TemplateMapper.toPhotoTemplate(rec);
    expect(tpl.meta.images.length, 2);
    expect(tpl.meta.cover, 'a');
  });

  test('无 images_json 时由 cover 派生单图（兼容）', () {
    final rec = TemplateRecord(
      id: 't1', name: 'n', author: '', version: '1.0', category: 'portrait',
      classification: const {'type': 'portrait'}, tags: const [], tagIds: const [],
      price: 0, cover: 'u0', description: '', referenceSource: '',
      composition: const {}, pose: <dynamic>[], camera: const {}, sceneGuide: const {},
      postProcess: const {}, createdAt: 1, updatedAt: 1,
      isBuiltin: true, isRecommended: false,
    );
    final tpl = TemplateMapper.toPhotoTemplate(rec);
    expect(tpl.meta.images.length, 1);
    expect(tpl.meta.cover, 'u0');
  });
}