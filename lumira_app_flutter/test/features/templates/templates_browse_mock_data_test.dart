import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/features/templates/data/templates_browse_mock_data.dart';

/// 模板详情分类补全回归测试。
///
/// 处于二级分类下的模板，详情应能显示完整分类路径。
/// 覆盖两类来源：
/// - registry 内模板（如 cafe_portrait / goldnen_landscape）：由 registry 权威分级补齐
/// - registry 外的 mock 详情（如 portrait_bokeh / still_life_warm）：由兜底声明补齐
void main() {
  group('TemplatesBrowseMockData.findDetailById 分类补全', () {
    test('registry 外 mock 详情仍能补齐二级分类（不全只显示一级）', () {
      final d = TemplatesBrowseMockData.findDetailById('portrait_bokeh');
      expect(d, isNotNull);
      expect(d!.majorStyle, 'emotional'); // 二级
      expect(d.method, 'wide'); // 四级
    });

    test('still_life_warm 布丁补齐二级/四级', () {
      final d = TemplatesBrowseMockData.findDetailById('still_life_warm');
      expect(d, isNotNull);
      expect(d!.majorStyle, 'minimal');
      expect(d.method, 'single');
    });

    test('registry 内模板由 registry 补齐二级分类', () {
      final d = TemplatesBrowseMockData.findDetailById('cafe_portrait');
      expect(d, isNotNull);
      expect(d!.majorStyle, 'japanese');
      expect(d.method, 'normal');
    });

    test('registry 内模板 goldnen_landscape 补齐分类', () {
      final d = TemplatesBrowseMockData.findDetailById('golden_landscape');
      expect(d, isNotNull);
      expect(d!.majorStyle, 'fresh');
      expect(d.method, 'wide');
    });

    test('未知 id 返回 null（不返回 guess 数据）', () {
      expect(TemplatesBrowseMockData.findDetailById('no_such_template'),
          isNull);
    });
  });
}