import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/db/dao/scenes_dao.dart';
import 'package:lumira_app_flutter/features/scenes/search/scene_search_service.dart';
import 'package:lumira_app_flutter/shared/searchengine/search_filters.dart';

SceneRecord _scene({
  required String id,
  required String name,
  String category = 'indoor',
  String style = '',
  String vibe = '',
  String description = '',
  List<String> tips = const [],
  String whereToShoot = '',
  String bestTime = '',
  String relatedCategory = '',
  int createdAt = 1,
}) {
  return SceneRecord(
    id: id, name: name, icon: '', category: category, style: style,
    filter: const {}, vibe: vibe, description: description,
    exampleImages: const [], tips: tips, whereToShoot: whereToShoot,
    bestTime: bestTime, sceneGuide: const {}, relatedCategory: relatedCategory,
    recommendedTagIds: const [], tagIds: const [], creator: 'system',
    isFavorite: false, createdAt: createdAt, updatedAt: 1,
  );
}

void main() {
  test('多字段命中：name/分类/风格/氛围/描述/提示/地点/时间/关联分类', () {
    final list = <SceneRecord>[
      _scene(id: 'a', name: '窗光人像', vibe: '温暖'),
      _scene(id: 'b', name: '街头', style: '复古', whereToShoot: '老城区'),
      _scene(id: 'c', name: '咖啡馆', tips: const ['靠窗座位'], bestTime: '下午'),
      _scene(id: 'd', name: '海边', relatedCategory: 'landscape'),
    ];
    expect(SceneSearchService.matchesKeyword(list[0], '温暖'), isTrue);
    expect(SceneSearchService.matchesKeyword(list[1], '老城区'), isTrue);
    expect(SceneSearchService.matchesKeyword(list[2], '靠窗'), isTrue);
    expect(SceneSearchService.matchesKeyword(list[3], 'landscape'), isTrue);
    expect(SceneSearchService.matchesKeyword(list[0], '夜景'), isFalse);
  });

  test('category / style 筛选', () {
    final list = <SceneRecord>[
      _scene(id: 'a', name: '室内窗光', category: 'indoor', style: '清新'),
      _scene(id: 'b', name: '街头', category: 'street', style: '复古'),
    ];
    final byCategory = SceneSearchService.search(
      all: list, keyword: '', filters: SearchFilters(category: 'indoor'),
    );
    expect(byCategory.map((e) => e.id), ['a']);

    final byStyle = SceneSearchService.search(
      all: list, keyword: '', filters: SearchFilters(sceneStyle: '复古'),
    );
    expect(byStyle.map((e) => e.id), ['b']);
  });

  test('hot 按 popularity 降序，latest 按 createdAt 降序', () {
    final list = <SceneRecord>[
      _scene(id: 'a', name: 'A', createdAt: 1),
      _scene(id: 'b', name: 'B', createdAt: 2),
    ];
    final hot = SceneSearchService.search(
      all: list, keyword: '', filters: SearchFilters(sort: SearchSort.hot),
      popularity: {'b': 100, 'a': 10},
    );
    expect(hot.first.id, 'b');

    final latest = SceneSearchService.search(
      all: list, keyword: '', filters: SearchFilters(sort: SearchSort.latest),
    );
    expect(latest.first.id, 'b');
  });
}
