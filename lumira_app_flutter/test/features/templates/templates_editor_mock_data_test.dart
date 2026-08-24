import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/templates/data/remote_template_dto.dart';
import 'package:lumira_app_flutter/features/templates/data/templates_editor_mock_data.dart';

void main() {
  group('EditorFormMeta new fields', () {
    test('blank form defaults are empty', () {
      final f = createBlankEditorForm();
      expect(f.meta.shortDesc, '');
      expect(f.meta.ambience, isNull);
      expect(f.meta.subStyle, isNull);
      expect(f.meta.method, isNull);
    });

    test('copy carries new fields', () {
      final f = createBlankEditorForm();
      f.meta.shortDesc = '森林暗调';
      f.meta.ambience = const RemoteTemplateAmbienceDto(seasons: ['autumn']);
      f.meta.subStyle = 's1';
      f.meta.method = 'm1';
      final c = f.copy();
      expect(c.meta.shortDesc, '森林暗调');
      expect(c.meta.ambience!.seasons, ['autumn']);
      expect(c.meta.subStyle, 's1');
      expect(c.meta.method, 'm1');
      // 深拷贝隔离：改原对象不影响副本
      c.meta.method = 'm2';
      expect(f.meta.method, 'm1');
    });
  });
}