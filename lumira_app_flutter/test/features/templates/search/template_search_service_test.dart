import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/features/templates/search/template_search_service.dart';
import 'package:lumira_app_flutter/shared/searchengine/search_filters.dart';

TemplateRecord _tpl({
  required String id,
  required String name,
  String category = 'portrait',
  Map<String, dynamic> classification = const {},
  List<String> tags = const [],
  String description = '',
  String referenceSource = '',
  Map<String, dynamic> composition = const {},
  Map<String, dynamic> postProcess = const {},
  int price = 0,
  bool isRecommended = false,
  String source = 'builtin',
}) {
  return TemplateRecord(
    id: id, name: name, author: '', version: '1.0.0', category: category,
    classification: classification, tags: tags, tagIds: const [], price: price,
    cover: '', description: description, referenceSource: referenceSource,
    composition: composition, pose: const {}, camera: const {},
    sceneGuide: const {}, postProcess: postProcess, createdAt: 1, updatedAt: 1,
    isBuiltin: true, isRecommended: isRecommended, source: source,
  );
}

void main() {
  test('多字段命中：name/分类标签/分类树key标签/description/lut标签', () {
    final list = <TemplateRecord>[
      _tpl(id: 'a', name: '港风人像'),
      _tpl(id: 'b', name: '窗光', classification: {'type': 'portrait', 'subStyle': 'japanese'}),
      _tpl(id: 'c', name: '胶片', postProcess: {'lut': 'vintage'}),
      _tpl(id: 'd', name: '街头', description: '雨夜霓虹'),
    ];
    const labelByKey = {'portrait': '人像', 'japanese': '日系'};
    expect(TemplateSearchService.matchesKeyword(list[0], '港风', categoryLabelByKey: labelByKey), isTrue);
    expect(TemplateSearchService.matchesKeyword(list[1], '日系', categoryLabelByKey: labelByKey), isTrue);
    expect(TemplateSearchService.matchesKeyword(list[2], '复古', categoryLabelByKey: labelByKey), isTrue); // lut 中文标签
    expect(TemplateSearchService.matchesKeyword(list[3], '霓虹', categoryLabelByKey: labelByKey), isTrue);
    expect(TemplateSearchService.matchesKeyword(list[0], '夜景', categoryLabelByKey: labelByKey), isFalse);
  });

  test('category 筛选命中子树 key 集合', () {
    final list = <TemplateRecord>[
      _tpl(id: 'a', name: '人像', category: 'portrait'),
      _tpl(id: 'b', name: '日系', classification: {'majorStyle': 'japanese'}),
      _tpl(id: 'c', name: '美食', category: 'food'),
    ];
    final filters = SearchFilters(category: 'portrait');
    // portrait 子树 = {portrait, japanese}
    final result = TemplateSearchService.search(
      all: list, keyword: '', filters: filters,
      categoryLabelByKey: const {},
    );
    expect(result.map((e) => e.id).toSet(), {'a', 'b'});
  });

  test('价格/来源/用户标签 allowedIds 过滤', () {
    final list = <TemplateRecord>[
      _tpl(id: 'a', name: '免费内置', price: 0),
      _tpl(id: 'b', name: '付费内置', price: 30),
      _tpl(id: 'c', name: '我的自定义', price: 30, source: 'custom'),
    ];
    final free = TemplateSearchService.search(
      all: list, keyword: '', filters: SearchFilters(price: SearchPriceFilter.free),
    );
    expect(free.map((e) => e.id), ['a']);

    final owned = TemplateSearchService.search(
      all: list, keyword: '', filters: SearchFilters(ownedOnly: true),
    );
    expect(owned.map((e) => e.id), ['c']);

    final allowed = TemplateSearchService.search(
      all: list, keyword: '', filters: SearchFilters(),
      allowedIds: {'b', 'c'},
    );
    expect(allowed.map((e) => e.id).toSet(), {'b', 'c'});
  });

  test('hot 排序：recommended 优先', () {
    final list = <TemplateRecord>[
      _tpl(id: 'a', name: '普通', isRecommended: false),
      _tpl(id: 'b', name: '推荐', isRecommended: true),
    ];
    final result = TemplateSearchService.search(
      all: list, keyword: '', filters: SearchFilters(sort: SearchSort.hot),
    );
    expect(result.first.id, 'b');
  });
}
