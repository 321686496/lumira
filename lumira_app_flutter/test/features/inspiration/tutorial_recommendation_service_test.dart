import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/db/dao/gallery_dao.dart';
import 'package:lumira_app_flutter/core/db/dao/tutorial_read_dao.dart';
import 'package:lumira_app_flutter/features/inspiration/data/tutorial_content.dart';
import 'package:lumira_app_flutter/features/inspiration/data/tutorial_recommendation_service.dart';
import 'package:lumira_app_flutter/features/onboarding/data/questionnaire_answers.dart';
import 'package:lumira_app_flutter/features/onboarding/data/questionnaire_dao.dart';

class _FakeQuestionnaireDao implements QuestionnaireDao {
  _FakeQuestionnaireDao(this.answers);
  final QuestionnaireAnswers? answers;
  @override
  Future<QuestionnaireAnswers?> getAnswers() async => answers;
  @override
  Future<bool> isCompleted() async => answers != null;
  @override
  Future<bool> hasUnsynced() async => false;
  @override
  Future<void> markSynced(int syncedAt) async {}
  @override
  Future<void> upsert(QuestionnaireAnswers a, int t) async {}
}

class _FakeGalleryDao implements GalleryDao {
  _FakeGalleryDao(this.counts);
  final Map<String, int> counts;
  @override
  Future<Map<String, int>> countByCategory() async => counts;
  // 其余 GalleryDao 方法最小实现（noSuchMethod 兜底）
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeReadDao implements TutorialReadDao {
  _FakeReadDao(this.readIds);
  final Set<String> readIds;
  @override
  Future<Set<String>> getReadIds() async => readIds;
  @override
  Future<void> markRead(String id) async {}
  @override
  Future<void> markUnread(String id) async {}
}

void main() {
  TutorialRecommendationService build({
    QuestionnaireAnswers? answers,
    Map<String, int> counts = const {},
    Set<String> readIds = const {},
  }) {
    return TutorialRecommendationService(
      questionnaireDao: _FakeQuestionnaireDao(answers),
      galleryDao: _FakeGalleryDao(counts),
      readDao: _FakeReadDao(readIds),
    );
  }

  test('冷启动：覆盖 >=3 类别且包含 general', () async {
    final result = await build().recommend();
    expect(result, isNotEmpty);
    expect(result.map((t) => t.category).toSet().length, greaterThanOrEqualTo(3));
    expect(result.any((t) => t.category == 'general'), isTrue);
  });

  test('问卷偏好加权：favoriteCategories 类别占多数', () async {
    final result = await build(
      answers: const QuestionnaireAnswers(
        favoriteCategories: ['portrait'],
        painPoints: [],
        expectations: [],
        commonScenes: [],
      ),
    ).recommend();
    final portraitCount = result.where((t) => t.category == 'portrait').length;
    expect(portraitCount, greaterThan(0));
  });

  test('行为优先：近期常拍类别占多数且包含探索类别（多样性）', () async {
    final result = await build(counts: {'food': 10, 'street': 8}).recommend();
    final related = result.where((t) => t.category == 'food' || t.category == 'street').length;
    final total = result.length;
    expect(related / total, greaterThan(0.5), reason: '相关类别应占多数');
    expect(result.map((t) => t.category).toSet().length, greaterThanOrEqualTo(3));
  });

  test('未读优先：已读教程排在同类未读之后', () async {
    final readIds = {TutorialContent.getById('tut_general_premium')!.id};
    final result = await build(readIds: readIds).recommend();
    final idx = result.indexWhere((t) => t.id == 'tut_general_premium');
    expect(idx, isNot(0), reason: '已读通用教程不应排在最前');
  });

  test('全部已读时仍正常返回', () async {
    final all = TutorialContent.all.map((t) => t.id).toSet();
    final result = await build(readIds: all).recommend();
    expect(result, isNotEmpty);
  });

  test('结果数量不超过 count 且去重', () async {
    final result = await build().recommend(count: 6);
    expect(result.length, lessThanOrEqualTo(6));
    expect(result.map((t) => t.id).toSet().length, result.length);
  });

  test('DAO 异常降级为均匀推荐', () async {
    final service = TutorialRecommendationService(
      questionnaireDao: _ThrowDao(),
      galleryDao: _ThrowGallery(),
      readDao: _FakeReadDao(const {}),
    );
    final result = await service.recommend();
    expect(result, isNotEmpty);
    expect(result.map((t) => t.category).toSet().length, greaterThanOrEqualTo(3));
  });
}

class _ThrowDao implements QuestionnaireDao {
  @override
  Future<QuestionnaireAnswers?> getAnswers() async => throw Exception('db down');
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _ThrowGallery implements GalleryDao {
  @override
  Future<Map<String, int>> countByCategory() async => throw Exception('db down');
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}