import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/features/templates/services/template_exporter.dart';

TemplateRecord _makeRecord() {
  return TemplateRecord(
    id: 'r1',
    name: '测试模板',
    author: 'tester',
    version: '1.0.0',
    category: 'portrait',
    classification: {},
    tags: ['人像'],
    tagIds: [],
    price: 0,
    cover: '',
    description: '',
    referenceSource: '',
    composition: {'overlayType': 'rule_of_thirds', 'subjectFrame': {'x': 0.1, 'y': 0.2, 'w': 0.3, 'h': 0.4}, 'opacity': 0.5, 'aspectRatio': '3:4', 'description': '三分法'},
    pose: {'silhouette': {'type': 'builtin', 'data': 'standing-profile'}, 'position': {'x': 0.5, 'y': 0.5}, 'scale': 1.0, 'rotation': 0, 'description': ''},
    camera: {'exposureCompensation': 0.3, 'iso': 200, 'shutterSpeed': '1/200', 'whiteBalance': 'daylight', 'whiteBalanceK': 5500, 'flashMode': 'off', 'focusMode': 'auto', 'lensSuggestion': 'main'},
    sceneGuide: {'lightDirection': 'front', 'shootingDistance': '2m', 'background': 'wall', 'props': <String>[], 'bestTime': 'morning', 'tips': <String>['keep steady']},
    postProcess: {'cropRatio': '3:4', 'color': {'brightness': 0, 'contrast': 0, 'saturation': 0, 'temperature': 0, 'tint': 0}, 'smoothStrength': 0, 'sharpen': 0, 'vignette': 0, 'grain': 0, 'lut': 'none'},
    createdAt: 1700000000000,
    updatedAt: 1700000000000,
    isBuiltin: false,
    isRecommended: false,
  );
}

void main() {
  group('TemplateExporter.exportToPptpl', () {
    test('生成完整 .pptpl JSON（含所有 5 字段）', () {
      final json = TemplateExporter.exportToPptpl(_makeRecord());
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect(data['format'], 'pptpl');
      expect(data['version'], '1.0');
      expect(data['meta'], isA<Map>());
      expect(data['composition'], isA<Map>());
      expect(data['pose'], isA<Map>());
      expect(data['camera'], isA<Map>());
      expect(data['sceneGuide'], isA<Map>());
      expect(data['postProcess'], isA<Map>());

      expect(data['meta']['id'], 'r1');
      expect(data['composition']['subjectFrame'], isNotNull);
      expect(data['pose']['silhouette'], isNotNull);
    });
  });

  group('TemplateExporter.exportToLumira', () {
    test('生成简化 .lumira JSON（仅 meta + camera + composition.overlayType）', () {
      final json = TemplateExporter.exportToLumira(_makeRecord());
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect(data['format'], 'lumira');
      expect(data['version'], '1.0');
      expect(data['meta'], isA<Map>());
      expect(data['camera'], isA<Map>());
      expect(data['composition'], isA<Map>());

      expect(data.containsKey('pose'), isFalse);
      expect(data.containsKey('sceneGuide'), isFalse);
      expect(data.containsKey('postProcess'), isFalse);

      expect(data['composition']['overlayType'], 'rule_of_thirds');
      expect(data['composition'].containsKey('subjectFrame'), isFalse);
    });
  });

  group('TemplateExporter.embedCoverData', () {
    test('data: URL cover is copied directly to coverData', () async {
      final record = _makeRecord().copyWith(
        cover: 'data:image/jpeg;base64,abc123',
      );
      final result = await TemplateExporter.embedCoverData(record);
      expect(result.coverData, 'data:image/jpeg;base64,abc123');
    });

    test('http URL cover leaves coverData null (offline app)', () async {
      final record = _makeRecord().copyWith(
        cover: 'https://picsum.photos/seed/test/400/600',
      );
      final result = await TemplateExporter.embedCoverData(record);
      expect(result.coverData, isNull);
    });

    test('empty cover leaves coverData null', () async {
      final record = _makeRecord(); // cover = ''
      final result = await TemplateExporter.embedCoverData(record);
      expect(result.coverData, isNull);
    });

    test('asset path cover loads bytes and encodes to base64 data URL', () async {
      final record = _makeRecord().copyWith(
        cover: 'assets/images/templates/cafe_portrait.jpg',
      );
      final fakeBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]); // JPEG magic bytes
      final result = await TemplateExporter.embedCoverData(
        record,
        assetLoader: (_) async => fakeBytes,
      );
      expect(result.coverData, isNotNull);
      expect(result.coverData!, startsWith('data:image/jpeg;base64,'));
    });

    test('coverData exceeding 500KB is skipped', () async {
      final record = _makeRecord().copyWith(
        cover: 'assets/images/templates/huge.jpg',
      );
      final hugeBytes = Uint8List(600 * 1024); // 600KB > 500KB limit
      final result = await TemplateExporter.embedCoverData(
        record,
        assetLoader: (_) async => hugeBytes,
      );
      expect(result.coverData, isNull);
    });
  });

  group('TemplateExporter.exportToPptpl with coverData', () {
    test('meta includes coverData when record has it', () {
      final record = _makeRecord().copyWith(
        coverData: 'data:image/jpeg;base64,abc123',
      );
      final json = TemplateExporter.exportToPptpl(record);
      final data = jsonDecode(json) as Map<String, dynamic>;
      expect(data['meta']['coverData'], 'data:image/jpeg;base64,abc123');
    });

    test('meta omits coverData when null', () {
      final record = _makeRecord(); // coverData = null
      final json = TemplateExporter.exportToPptpl(record);
      final data = jsonDecode(json) as Map<String, dynamic>;
      expect(data['meta'].containsKey('coverData'), isFalse);
    });
  });

  group('resolveCoverUrl', () {
    test('returns coverData when present', () {
      final record = _makeRecord().copyWith(
        cover: 'assets/images/templates/test.jpg',
        coverData: 'data:image/jpeg;base64,abc',
      );
      expect(TemplateExporter.resolveCoverUrl(record), 'data:image/jpeg;base64,abc');
    });

    test('returns cover when coverData is null', () {
      final record = _makeRecord().copyWith(
        cover: 'assets/images/templates/test.jpg',
      );
      expect(TemplateExporter.resolveCoverUrl(record), 'assets/images/templates/test.jpg');
    });
  });
}
