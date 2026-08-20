import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/academy/data/academy_models.dart';
import 'package:lumira_app_flutter/features/academy/search/academy_search_service.dart';
import 'package:lumira_app_flutter/shared/searchengine/search_filters.dart';

void main() {
  test('课程多字段命中：标题/主题中文标签/等级中文标签/标签/meta', () {
    final courses = <AcademyCourse>[
      const AcademyCourse(id: 'c1', lessonNumber: 1, title: '人像构图入门',
        level: AcademyLevel.beginner, topic: AcademyTopic.portrait,
        coverImage: '', meta: '8分钟 · 入门', tags: ['构图', '人像']),
      const AcademyCourse(id: 'c2', lessonNumber: 2, title: '街头抓拍',
        level: AcademyLevel.advanced, topic: AcademyTopic.street,
        coverImage: '', meta: '12分钟 · 高级', tags: ['街拍']),
    ];
    expect(AcademySearchService.courseMatchesKeyword(courses[0], '构图'), isTrue);
    expect(AcademySearchService.courseMatchesKeyword(courses[0], '人像'), isTrue);
    expect(AcademySearchService.courseMatchesKeyword(courses[0], '入门基础'), isTrue); // level.label
    expect(AcademySearchService.courseMatchesKeyword(courses[0], '街头'), isFalse);
    expect(AcademySearchService.courseMatchesKeyword(courses[1], '街头'), isTrue);
  });

  test('知识卡片多字段命中：标题/副标题/主题标签/正文/要点', () {
    final cards = <KnowledgeCard>[
      const KnowledgeCard(id: 'k1', topic: AcademyTopic.portrait, title: '三分法构图',
        subtitle: '让画面更均衡', coverImage: '', body: '把主体放在交点附近', keyPoints: ['引导线']),
    ];
    expect(AcademySearchService.cardMatchesKeyword(cards[0], '三分法'), isTrue);
    expect(AcademySearchService.cardMatchesKeyword(cards[0], '均衡'), isTrue);
    expect(AcademySearchService.cardMatchesKeyword(cards[0], '人像'), isTrue); // topic.label
    expect(AcademySearchService.cardMatchesKeyword(cards[0], '引导线'), isTrue);
    expect(AcademySearchService.cardMatchesKeyword(cards[0], '夜景'), isFalse);
  });

  test('主题/等级筛选与 hot 排序', () {
    final courses = <AcademyCourse>[
      const AcademyCourse(id: 'c1', lessonNumber: 1, title: '人像入门',
        level: AcademyLevel.beginner, topic: AcademyTopic.portrait,
        coverImage: '', meta: '', tags: [], rewardXP: 50),
      const AcademyCourse(id: 'c2', lessonNumber: 2, title: '街头进阶',
        level: AcademyLevel.intermediate, topic: AcademyTopic.street,
        coverImage: '', meta: '', tags: [], rewardXP: 100),
    ];
    final byTopic = AcademySearchService.searchCourses(
      all: courses, keyword: '', filters: SearchFilters(academyTopic: 'portrait'),
    );
    expect(byTopic.map((e) => e.id), ['c1']);

    final byLevel = AcademySearchService.searchCourses(
      all: courses, keyword: '', filters: SearchFilters(academyLevel: 'intermediate'),
    );
    expect(byLevel.map((e) => e.id), ['c2']);

    final hot = AcademySearchService.searchCourses(
      all: courses, keyword: '', filters: SearchFilters(sort: SearchSort.hot),
    );
    expect(hot.first.id, 'c2');
  });
}
