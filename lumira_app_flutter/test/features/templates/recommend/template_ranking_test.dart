import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/features/templates/recommend/template_ranking.dart';

TemplateRecord _tpl(String id, String category, {String major = '', String style = ''}) {
  return TemplateRecord(
    id: id,
    name: id,
    author: '',
    version: '1.0.0',
    category: category,
    classification: {'category': category, 'majorStyle': major, 'style': style},
    tags: const [],
    tagIds: const [],
    price: 0,
    cover: '',
    description: '',
    referenceSource: '',
    composition: const {},
    pose: null,
    camera: const {},
    sceneGuide: const {},
    postProcess: const {},
    createdAt: 0,
    updatedAt: 0,
    isBuiltin: false,
    isRecommended: false,
    source: 'builtin',
  );
}

void main() {
  final ctx = RankingContext(nowMs: 0, portrait: {'category:portrait': 10, 'style:fresh': 3});

  test('scoreAll: 高兴趣模板 interest 更高、探索更低', () {
    final result = TemplateRanking().scoreAll(
      [_tpl('p1', 'portrait', style: 'fresh'), _tpl('p2', 'landscape', style: 'fog')],
      ctx,
    );
    final p1 = result.firstWhere((s) => s.template.id == 'p1');
    final p2 = result.firstWhere((s) => s.template.id == 'p2');
    expect(p1.interest > p2.interest, isTrue);
    expect(p1.exploration < p2.exploration, isTrue);
  });

  test('mixExplore: 返回全部且不重复', () {
    final tpls = [
      _tpl('a', 'portrait', style: 'fresh'),
      _tpl('b', 'portrait', style: 'fog'),
      _tpl('c', 'landscape', style: 'fresh'),
      _tpl('d', 'object', style: 'fog'),
    ];
    final scores = TemplateRanking().scoreAll(tpls, ctx);
    final out = TemplateRanking().mixExplore(scores);
    expect(out.length, 4);
    expect(out.map((t) => t.id).toSet().length, 4);
  });

  test('favoriteCategories 给问卷首选分类加分', () {
    final ctx2 = RankingContext(nowMs: 0, favoriteCategories: {'portrait'}, portrait: {});
    final scores = TemplateRanking().scoreAll(
      [_tpl('a', 'portrait'), _tpl('b', 'landscape')],
      ctx2,
    );
    final a = scores.firstWhere((s) => s.template.id == 'a');
    final b = scores.firstWhere((s) => s.template.id == 'b');
    expect(a.total > b.total, isTrue);
  });
}