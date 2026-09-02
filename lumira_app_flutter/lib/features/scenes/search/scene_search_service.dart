import '../../../core/db/dao/scenes_dao.dart';
import '../../../shared/searchengine/search_filters.dart';
import '../../tags/tag_filter_logic.dart';

/// 场景检索/筛选/排序纯函数。
class SceneSearchService {
  SceneSearchService._();

  /// 多字段命中：name / category / style / vibe / description / tips /
  /// whereToShoot / bestTime / relatedCategory。
  static bool matchesKeyword(SceneRecord s, String keyword) {
    final q = keyword.trim();
    if (q.isEmpty) return true;
    final candidates = <String>[
      s.name,
      s.category,
      s.style,
      s.vibe,
      s.description,
      ...s.tips,
      s.whereToShoot,
      s.bestTime,
      s.relatedCategory,
    ];
    return candidates.any((c) => containsIgnoreCase(c, q));
  }

  /// 关键词 → 筛选（分类/风格/用户标签 allowedIds）→ 排序。
  static List<SceneRecord> search({
    required List<SceneRecord> all,
    required String keyword,
    required SearchFilters filters,
    Set<String>? allowedIds,
    Map<String, int>? popularity,
  }) {
    var list =
        all.where((s) => matchesKeyword(s, keyword)).toList();

    final category = filters.sceneCategory ?? filters.category;
    if (category != null && category.isNotEmpty) {
      list = list.where((s) => s.category == category).toList();
    }
    final style = filters.sceneStyle;
    if (style != null && style.isNotEmpty) {
      list = list.where((s) => s.style == style).toList();
    }
    if (allowedIds != null) {
      list = list.where((s) => allowedIds.contains(s.id)).toList();
    }

    _sort(list, filters.sort, popularity);
    return list;
  }

  static void _sort(
    List<SceneRecord> list,
    SearchSort sort,
    Map<String, int>? popularity,
  ) {
    switch (sort) {
      case SearchSort.comprehensive:
        break; // 保持原顺序
      case SearchSort.hot:
        list.sort((a, b) =>
            (popularity?[b.id] ?? 0).compareTo(popularity?[a.id] ?? 0));
        break;
      case SearchSort.latest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SearchSort.photos:
        list.sort((a, b) =>
            (popularity?[b.id] ?? 0).compareTo(popularity?[a.id] ?? 0));
        break;
      case SearchSort.name:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
    }
  }
}
