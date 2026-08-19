import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/core/services/deep_link_service.dart';
import 'package:lumira_app_flutter/features/templates/services/template_share_code.dart';

class TemplateRecordForTest {
  static TemplateRecord make() {
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('isTemplateLink：lumira://tpl 深链为 true', () {
    final link = TemplateShareCode.buildShareLink(TemplateRecordForTest.make());
    expect(DeepLinkService.isTemplateLink(link), isTrue);
  });

  test('isTemplateLink：非模板链接为 false', () {
    expect(DeepLinkService.isTemplateLink('https://example.com'), isFalse);
    expect(DeepLinkService.isTemplateLink('lumira://other/abc'), isFalse);
  });
}
