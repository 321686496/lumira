import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';

void main() {
  TemplateRecord base({dynamic pose = const <dynamic>[], List<TemplateImage>? images}) =>
      TemplateRecord(
        id: 't1', name: 'n', author: '', version: '1.0', category: 'portrait',
        classification: const {'type': 'portrait'}, tags: const [], tagIds: const [],
        price: 0, cover: 'u0', description: '', referenceSource: '',
        composition: const {}, pose: pose, camera: const {}, sceneGuide: const {},
        postProcess: const {}, createdAt: 1, updatedAt: 1,
        isBuiltin: true, isRecommended: false, images: images,
      );

  test('toRow/fromRow 往返保留多张效果图', () {
    final rec = base(images: [
      const TemplateImage(url: 'u0'),
      const TemplateImage(url: 'u1', data: 'data:image/png;base64,abc'),
    ]);
    final row = rec.toRow();
    final back = TemplateRecord.fromRow(row);
    expect(back.images, isNotNull);
    expect(back.images!.length, 2);
    expect(back.images![0].url, 'u0');
    expect(back.images![1].data, 'data:image/png;base64,abc');
  });

  test('fromRow 兼容旧数据（无 images_json → images=null）', () {
    final row = base().toRow()..remove('images_json');
    final back = TemplateRecord.fromRow(row);
    expect(back.images, isNull);
  });
}