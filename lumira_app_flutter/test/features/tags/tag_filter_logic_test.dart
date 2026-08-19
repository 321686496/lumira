import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/tags/tag_filter_logic.dart';

void main() {
  test('containsIgnoreCase 不区分大小写', () {
    expect(containsIgnoreCase('Portrait', 'port'), isTrue);
    expect(containsIgnoreCase('人像', '像'), isTrue);
    expect(containsIgnoreCase('Street', 'xx'), isFalse);
  });

  test('templateMatchesKeyword 匹配名称/分类/系统标签/空关键词', () {
    expect(templateMatchesKeyword('港风人像', 'portrait', const [], '港风'), isTrue);
    expect(templateMatchesKeyword('人像', 'portrait', const ['胶片'], '胶片'), isTrue);
    expect(templateMatchesKeyword('人像', 'portrait', const [], ''), isTrue);
    expect(templateMatchesKeyword('人像', 'portrait', const [], '夜景'), isFalse);
  });

  test('sceneMatchesKeyword 匹配名称/氛围/分类', () {
    expect(sceneMatchesKeyword('窗光人像', '温暖', 'indoor', '窗光'), isTrue);
    expect(sceneMatchesKeyword('窗光人像', '温暖', 'indoor', '温暖'), isTrue);
    expect(sceneMatchesKeyword('窗光人像', '温暖', 'indoor', 'indoor'), isTrue);
    expect(sceneMatchesKeyword('窗光人像', '温暖', 'indoor', '大理'), isFalse);
  });

  test('filterTagsByKeyword 过滤标签并对齐大小写顺序', () {
    final tags = <MapEntry<String, int>>[
      const MapEntry('人像', 3),
      const MapEntry('日系', 2),
      const MapEntry('复古', 5),
    ];
    final hits = filterTagsByKeyword(tags, '系');
    expect(hits.map((e) => e.key), ['日系']);
  });
}