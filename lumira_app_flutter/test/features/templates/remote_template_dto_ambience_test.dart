import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/templates/data/remote_template_dto.dart';

void main() {
  group('RemoteTemplateAmbienceDto', () {
    test('fromJson parses season/weather/timeTone', () {
      final a = RemoteTemplateAmbienceDto.fromJson({
        'seasons': ['summer'],
        'weathers': ['sunny'],
        'timeTones': ['goldenHour'],
      });
      expect(a.seasons, ['summer']);
      expect(a.weathers, ['sunny']);
      expect(a.timeTones, ['goldenHour']);
      expect(a.isEmpty, isFalse);
    });

    test('missing/empty object isEmpty==true', () {
      expect(RemoteTemplateAmbienceDto.fromJson(null).isEmpty, isTrue);
      expect(const RemoteTemplateAmbienceDto().isEmpty, isTrue);
    });

    test('toJson roundtrips', () {
      const a = RemoteTemplateAmbienceDto(
        seasons: ['winter'],
        weathers: ['snow'],
        timeTones: ['night'],
      );
      final back = RemoteTemplateAmbienceDto.fromJson(a.toJson());
      expect(back.seasons, ['winter']);
      expect(back.weathers, ['snow']);
      expect(back.timeTones, ['night']);
    });
  });

  group('RemoteTemplateMetaDto', () {
    test('parses shortDesc & ambience', () {
      final m = RemoteTemplateMetaDto.fromJson({
        'id': 't1',
        'name': 'n',
        'category': 'portrait',
        'price': 0,
        'coverUrl': '',
        'description': '',
        'referenceSource': '',
        'tags': <String>[],
        'tagIds': <String>[],
        'classification': <String, dynamic>{},
        'sortOrder': 0,
        'updatedAt': 1,
        'shortDesc': '初夏甜点',
        'ambience': {'timeTones': ['warm']},
      });
      expect(m.shortDesc, '初夏甜点');
      expect(m.ambience.timeTones, ['warm']);
    });

    test('defaults when fields missing', () {
      final m = RemoteTemplateMetaDto.fromJson({
        'id': 't1',
        'name': 'n',
        'category': 'portrait',
        'price': 0,
        'coverUrl': '',
        'description': '',
        'referenceSource': '',
        'tags': <String>[],
        'tagIds': <String>[],
        'classification': <String, dynamic>{},
        'sortOrder': 0,
        'updatedAt': 1,
      });
      expect(m.shortDesc, '');
      expect(m.ambience.isEmpty, isTrue);
    });
  });
}