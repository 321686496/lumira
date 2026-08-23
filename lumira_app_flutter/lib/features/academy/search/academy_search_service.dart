import '../../../shared/searchengine/search_filters.dart';
import '../../tags/tag_filter_logic.dart';
import '../data/academy_models.dart';

/// 美学院课程/知识卡片检索/筛选/排序纯函数。
class AcademySearchService {
  AcademySearchService._();

  /// 课程多字段命中：title / topic.label / level.label / tags / meta。
  static bool courseMatchesKeyword(AcademyCourse c, String keyword) {
    final q = keyword.trim();
    if (q.isEmpty) return true;
    final candidates = <String>[
      c.title,
      c.topic.label,
      c.level.label,
      ...c.tags,
      c.meta,
    ];
    return candidates.any((x) => containsIgnoreCase(x, q));
  }

  /// 知识卡片多字段命中：title / subtitle / topic.label / body / keyPoints。
  static bool cardMatchesKeyword(KnowledgeCard k, String keyword) {
    final q = keyword.trim();
    if (q.isEmpty) return true;
    final candidates = <String>[
      k.title,
      k.subtitle,
      k.topic.label,
      k.body,
      ...k.keyPoints,
    ];
    return candidates.any((x) => containsIgnoreCase(x, q));
  }

  static List<AcademyCourse> searchCourses({
    required List<AcademyCourse> all,
    required String keyword,
    required SearchFilters filters,
  }) {
    var list =
        all.where((c) => courseMatchesKeyword(c, keyword)).toList();

    final topic = filters.academyTopic;
    if (topic != null && topic.isNotEmpty) {
      final t = AcademyTopic.values.byName(topic);
      list = list.where((c) => c.topic == t).toList();
    }
    final level = filters.academyLevel;
    if (level != null && level.isNotEmpty) {
      final l = AcademyLevel.values.byName(level);
      list = list.where((c) => c.level == l).toList();
    }

    switch (filters.sort) {
      case SearchSort.comprehensive:
        break; // 保持 lessonNumber 顺序
      case SearchSort.hot:
        list.sort((a, b) => b.rewardXP.compareTo(a.rewardXP));
        break;
      case SearchSort.latest:
        list.sort((a, b) => b.lessonNumber.compareTo(a.lessonNumber));
        break;
      case SearchSort.photos:
        list.sort((a, b) => a.title.compareTo(b.title));
        break;
      case SearchSort.name:
        list.sort((a, b) => a.title.compareTo(b.title));
        break;
    }
    return list;
  }

  static List<KnowledgeCard> searchCards({
    required List<KnowledgeCard> all,
    required String keyword,
    required SearchFilters filters,
  }) {
    var list =
        all.where((k) => cardMatchesKeyword(k, keyword)).toList();

    final topic = filters.academyTopic;
    if (topic != null && topic.isNotEmpty) {
      final t = AcademyTopic.values.byName(topic);
      list = list.where((k) => k.topic == t).toList();
    }
    return list;
  }
}
