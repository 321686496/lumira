import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/features/templates/data/remote_template_dto.dart';
import 'package:lumira_app_flutter/features/templates/data/templates_editor_mock_data.dart'
    as editor;
import 'package:lumira_app_flutter/features/templates/services/template_mapper.dart';

editor.EditorForm _createBlankEditorForm() {
  return editor.EditorForm(
    meta: editor.EditorFormMeta(),
    composition: editor.EditorFormComposition(),
    pose: editor.EditorFormPose(),
    camera: editor.EditorFormCamera(),
    sceneGuide: editor.EditorFormSceneGuide(),
    postProcess: editor.EditorFormPostProcess(),
  );
}

void main() {
  group('TemplateMapper.fromEditorForm (四级分类 + 新字段)', () {
    test('fromEditorForm writes 4-level classification + shortDesc + ambience', () {
      final f = _createBlankEditorForm();
      f.meta.category = 'portrait';
      f.meta.style = 'mood';
      f.meta.subStyle = 'cold';
      f.meta.method = 'selfie';
      f.meta.shortDesc = '暗调人像';
      f.meta.ambience = const RemoteTemplateAmbienceDto(
        seasons: ['autumn'],
        weathers: ['overcast'],
      );
      final r = TemplateMapper.fromEditorForm(f, createdAt: 1700000000000);
      expect(r.classification['type'], 'portrait');
      expect(r.classification['majorStyle'], 'mood');
      expect(r.classification['subStyle'], 'cold');
      expect(r.classification['method'], 'selfie');
      expect(r.shortDesc, '暗调人像');
      expect(
        TemplateMapper.ambienceFromJson(r.ambienceJson).seasons,
        ['autumn'],
      );
    });
  });

  group('TemplateMapper.toEditorForm (向后兼容)', () {
    test('toEditorForm reads legacy {type,style,method} classification', () {
      final Map<String, Object?> r = {
        'id': 't1',
        'name': 'x',
        'author': '',
        'version': '1.0.0',
        'category': 'portrait',
        'classification_json':
            jsonEncode({'type': 'portrait', 'style': 'mood', 'method': 'cold'}),
        'tags_json': '[]',
        'tag_ids_json': '[]',
        'price': 0,
        'cover': '',
        'description': '',
        'reference_source': '',
        'short_desc': '',
        'ambience_json': '{}',
        'composition_json': '{}',
        'pose_json': '{}',
        'camera_json': '{}',
        'scene_guide_json': '{}',
        'post_process_json': '{}',
        'created_at': 0,
        'updated_at': 0,
        'is_builtin': 0,
        'is_recommended': 0,
        'source': 'custom',
      };
      final rec = TemplateRecord.fromRow(r);
      final form = TemplateMapper.toEditorForm(rec);
      expect(form.meta.style, 'mood');
      expect(form.meta.subStyle, 'cold');
      expect(form.meta.method, isNull);
    });
  });
}