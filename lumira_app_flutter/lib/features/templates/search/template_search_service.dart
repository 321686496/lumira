import '../../../core/db/dao/templates_dao.dart';
import '../../../shared/searchengine/search_filters.dart';
import '../../tags/tag_filter_logic.dart';
import '../data/templates_browse_mock_data.dart';

/// 模板检索/筛选/排序纯函数（多字段命中 + 分类子树 + 价格 + 来源 + 排序）。
class TemplateSearchService {
  TemplateSearchService._();

  /// 多字段命中：name / category 中文标签 / classification 三级 key 及其中文标签 /
  /// tags / description / referenceSource / composition.description / postProcess.lut 中文标签。
  static bool matchesKeyword(
    TemplateRecord t,
    String keyword, {
    Map<String, String> categoryLabelByKey = const {},
  }) {
    final q = keyword.trim();
    if (q.isEmpty) return true;
    final candidates = <String>[
      t.name,
      TemplatesBrowseMockData.categoryLabel(t.category),
      ...t.tags,
      t.description,
      t.referenceSource,
    ];
    final cls = t.classification;
    for (final key in const ['type', 'majorStyle', 'subStyle', 'method']) {
      final v = cls[key] as String?;
      if (v == null || v.isEmpty) continue;
      candidates.add(v);
      final label = categoryLabelByKey[v];
      if (label != null && label.isNotEmpty && label != v) {
        candidates.add(label);
      }
    }
    final compDesc = t.composition['description'] as String?;
    if (compDesc != null && compDesc.isNotEmpty) candidates.add(compDesc);
    final lut = t.postProcess['lut'] as String?;
    if (lut != null && lut.isNotEmpty) {
      candidates.add(TemplatesBrowseMockData.lutLabel(lut));
    }
    return candidates.any((c) => containsIgnoreCase(c, q));
  }

  /// 关键词 → 筛选（分类子树/价格/来源/用户标签 allowedIds）→ 排序。
  /// [categoryLabelByKey] 分类 key→中文标签（页面从 template_categories 加载）。
  /// [allowedIds] 用户标签 AND 交集（null=不过滤）。
  /// [popularity] id→热度（子项目 B 就绪前传 null，hot 退化为 recommended+createdAt）。
  static List<TemplateRecord> search({
    required List<TemplateRecord> all,
    required String keyword,
    required SearchFilters filters,
    Map<String, String> categoryLabelByKey = const {},
    Set<String>? allowedIds,
    Map<String, int>? popularity,
    Map<String, int>? usageCounts,
  }) {
    var list = all
        .where((t) =>
            matchesKeyword(t, keyword, categoryLabelByKey: categoryLabelByKey))
        .toList();

    final category = filters.category;
    if (category != null && category.isNotEmpty) {
      list = list.where((t) => _categoryHit(t, category)).toList();
    }

    if (filters.price == SearchPriceFilter.free) {
      list = list.where((t) => t.price == 0).toList();
    } else if (filters.price == SearchPriceFilter.paid) {
      list = list.where((t) => t.price > 0).toList();
    }

    if (filters.ownedOnly) {
      list = list.where((t) => t.source == 'custom').toList();
    }

    if (allowedIds != null) {
      list = list.where((t) => allowedIds.contains(t.id)).toList();
    }

    _sort(list, filters.sort, popularity, usageCounts);
    return list;
  }

  static bool _categoryHit(TemplateRecord t, String key) {
    if (t.category == key) return true;
    final cls = t.classification;
    for (final k in const ['type', 'majorStyle', 'subStyle', 'method']) {
      final v = cls[k] as String?;
      if (v == key) return true;
    }
    return false;
  }

  static void _sort(
    List<TemplateRecord> list,
    SearchSort sort,
    Map<String, int>? popularity,
    Map<String, int>? usageCounts,
  ) {
    switch (sort) {
      case SearchSort.comprehensive:
        break; // 保持原顺序（数据已按创建/导入顺序稳定）
      case SearchSort.hot:
        list.sort((a, b) {
          final pa = popularity?[a.id] ?? (a.isRecommended ? 1 : 0);
          final pb = popularity?[b.id] ?? (b.isRecommended ? 1 : 0);
          if (pa != pb) return pb.compareTo(pa);
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
      case SearchSort.latest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SearchSort.photos:
        list.sort((a, b) {
          final pa = usageCounts?[a.id] ?? 0;
          final pb = usageCounts?[b.id] ?? 0;
          if (pa != pb) return pb.compareTo(pa);
          return a.name.compareTo(b.name);
        });
        break;
      case SearchSort.name:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
    }
  }
}
