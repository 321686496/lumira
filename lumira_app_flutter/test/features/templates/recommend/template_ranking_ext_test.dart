import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/templates/recommend/template_ranking.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';

TemplateRecord _tpl(String id) => TemplateRecord(
      id: id,
      name: id,
      author: '',
      version: '1',
      category: 'portrait',
      classification: const {},
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
      isBuiltin: true,
      isRecommended: true,
    );

void main() {
  test('mixExplore 保留探索在最前且去重', () {
    final scores = <TemplateScore>[
      TemplateScore(template: _tpl('a'), interest: 0.9, exploration: 0.1, hot: 0.2, total: 0.62),
      TemplateScore(template: _tpl('b'), interest: 0.8, exploration: 0.2, hot: 0.1, total: 0.55),
      TemplateScore(template: _tpl('c'), interest: 0.1, exploration: 0.9, hot: 0.3, total: 0.37),
      TemplateScore(template: _tpl('d'), interest: 0.0, exploration: 1.0, hot: 0.2, total: 0.36),
    ];
    final out = TemplateRanking().mixExplore(scores);
    final first = out.first.id;
    expect(first == 'c' || first == 'd', isTrue,
        reason: '探索信号应排最前');
    expect(out.map((t) => t.id).toSet().length, out.length, reason: '完全去重');
  });
}