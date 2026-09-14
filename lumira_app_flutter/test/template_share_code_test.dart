import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/features/templates/services/template_share_code.dart';

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
  group('TemplateShareCode.buildShareCode', () {
    test('生成 LUMIRA-分类-名称', () {
      final code = TemplateShareCode.buildShareCode(_makeRecord());
      expect(code, 'LUMIRA-portrait-测试模板');
    });

    test('分类/名称中的 - 被替换为 _（保证可回解析）', () {
      final record = _makeRecord().copyWith(
        category: 'still-life',
        name: '电影-夜景',
      );
      final code = TemplateShareCode.buildShareCode(record);
      expect(code, 'LUMIRA-still_life-电影_夜景');
    });

    test('非通用（女）模板生成 v2 分享码携带性别', () {
      final record = _makeRecord().copyWith(gender: 'female');
      final code = TemplateShareCode.buildShareCode(record);
      expect(code, 'LUMIRA-v2-portrait-female-测试模板');
    });

    test('非通用（男）模板生成 v2 分享码携带性别', () {
      final record = _makeRecord().copyWith(gender: 'male');
      final code = TemplateShareCode.buildShareCode(record);
      expect(code, 'LUMIRA-v2-portrait-male-测试模板');
    });

    test('v2 分享码经 parseCode 往返保留性别', () {
      final record = _makeRecord().copyWith(gender: 'female');
      final code = TemplateShareCode.buildShareCode(record);
      final parsed = TemplateShareCode.parseCode(code);
      expect(parsed, isNotNull);
      expect(parsed!['category'], 'portrait');
      expect(parsed['gender'], 'female');
      expect(parsed['name'], '测试模板');
    });
  });

  group('TemplateShareCode.buildShareLink / parseLink 往返', () {
    test('简化 .lumira 链接可被 parseLink 解析出完整 JSON', () {
      final record = _makeRecord();
      final link = TemplateShareCode.buildShareLink(record, usePptpl: false);
      expect(link, startsWith('lumira://tpl/'));

      final parsed = TemplateShareCode.parseLink(link);
      expect(parsed, isNotNull);
      expect(parsed!['name'], '测试模板');
      expect(parsed['meta'], isA<Map>());
      expect(parsed['format'], 'lumira');
      expect((parsed['meta'] as Map)['gender'], 'unisex');
    });

    test('完整 .pptpl 链接可被 parseLink 解析', () {
      final record = _makeRecord();
      final link = TemplateShareCode.buildShareLink(record, usePptpl: true);
      final parsed = TemplateShareCode.parseLink(link);
      expect(parsed, isNotNull);
      expect(parsed!['format'], 'pptpl');
      expect(parsed['pose'], isA<Map>());
    });

    test('parseLink 兼容标准 base64（带 +/= 填充）', () {
      const json = '{"name":"A","meta":{}}';
      final b64 = base64Encode(utf8.encode(json));
      final parsed = TemplateShareCode.parseLink('lumira://tpl/$b64');
      expect(parsed, isNotNull);
      expect(parsed!['name'], 'A');
    });

    test('非模板链接返回 null', () {
      expect(TemplateShareCode.parseLink('https://example.com'), isNull);
      expect(TemplateShareCode.parseLink('lumira://other/xxx'), isNull);
      expect(TemplateShareCode.parseLink('不是链接'), isNull);
    });
  });

  group('TemplateShareCode.parseCode', () {
    test('解析 LUMIRA-分类-名称', () {
      final parsed = TemplateShareCode.parseCode('LUMIRA-portrait-测试模板');
      expect(parsed, isNotNull);
      expect(parsed!['name'], '测试模板');
      expect(parsed['category'], 'portrait');
    });

    test('非法分类回退 still-life', () {
      final parsed = TemplateShareCode.parseCode('LUMIRA-unknown-模板A');
      expect(parsed!['category'], 'still-life');
    });

    test('v2 男性分享码解析出 gender=male', () {
      final parsed = TemplateShareCode.parseCode('LUMIRA-v2-portrait-male-模板A');
      expect(parsed!['category'], 'portrait');
      expect(parsed['gender'], 'male');
      expect(parsed['name'], '模板A');
    });

    test('旧格式分享码无 gender 字段', () {
      final parsed = TemplateShareCode.parseCode('LUMIRA-portrait-模板A');
      expect(parsed!['gender'], isNull);
    });

    test('非 LUMIRA 前缀返回 null', () {
      expect(TemplateShareCode.parseCode('HELLO-x-y'), isNull);
    });
  });
}
