import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/features/templates/data/remote_template_dto.dart';
import 'package:lumira_app_flutter/features/templates/services/template_mapper.dart';
import 'package:lumira_app_flutter/features/templates/widgets/ambience_label.dart';

void main() {
  group('TemplateRecord roundtrip', () {
    test('keeps shortDesc & ambienceJson', () {
      final r = TemplateRecord(
        id: 't',
        name: 'n',
        author: 'Lumira',
        version: '1.0.0',
        category: 'portrait',
        classification: {},
        tags: [],
        tagIds: [],
        price: 0,
        cover: '',
        description: '',
        referenceSource: '',
        composition: {},
        pose: {},
        camera: {},
        sceneGuide: {},
        postProcess: {},
        createdAt: 1,
        updatedAt: 1,
        isBuiltin: true,
        isRecommended: false,
        shortDesc: '初夏甜点',
        ambienceJson: '{"timeTones":["warm"]}',
      );
      final back = TemplateRecord.fromRow(r.toRow());
      expect(back.shortDesc, '初夏甜点');
      expect(back.ambienceJson, contains('warm'));
    });
  });

  group('TemplateMapper ambience helpers', () {
    test('ambienceToJson encodes all groups', () {
      final json = TemplateMapper.ambienceToJson(const RemoteTemplateAmbienceDto(
        seasons: ['summer'],
        weathers: ['rain'],
        timeTones: ['night'],
      ));
      expect(json, contains('summer'));
      expect(json, contains('rain'));
      expect(json, contains('night'));
    });

    test('ambienceFromJson roundtrips and falls back empty', () {
      final a = TemplateMapper.ambienceFromJson(
          '{"seasons":["winter"],"weathers":[],"timeTones":["cool"]}');
      expect(a.seasons, ['winter']);
      expect(a.timeTones, ['cool']);
      expect(TemplateMapper.ambienceFromJson('').isEmpty, isTrue);
      expect(TemplateMapper.ambienceFromJson('not json').isEmpty, isTrue);
    });
  });

  group('AmbienceLabel', () {
    test('labelsFor returns mapped chinese labels in season>weather>tone order',
        () {
      final a = const RemoteTemplateAmbienceDto(
        seasons: ['summer'],
        weathers: ['sunny'],
        timeTones: ['goldenHour'],
      );
      expect(AmbienceLabel.labelsFor(a), ['夏季', '晴天', '黄金时刻']);
    });

    test('labelsFor null/empty returns empty', () {
      expect(AmbienceLabel.labelsFor(null), isEmpty);
      expect(AmbienceLabel.labelsFor(const RemoteTemplateAmbienceDto()), isEmpty);
    });

    test('unknown keys are dropped', () {
      expect(
          AmbienceLabel.labelsFor(
              const RemoteTemplateAmbienceDto(seasons: ['xxx'])),
          isEmpty);
    });
  });
}