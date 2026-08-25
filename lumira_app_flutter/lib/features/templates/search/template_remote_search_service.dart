import '../../../shared/searchengine/search_filters.dart';
import '../data/remote_template_dto.dart';
import '../data/remote_templates_repository.dart';

/// 模板「实时走后端搜索」服务。
///
/// 职责：把当前 UI 的排序/分类/关键词映射到后端搜索接口（GET /templates/search），
/// 返回最新线上模板（含全站热度 hotScore = 2×拍摄数 + 1×查看数）。
///
/// 后端仅负责「后台运营模板」（templates 表）的检索与排序，不包含 App 内置
/// 与用户自定义模板；搜索页需把本服务结果与本地内置/自定义结果合并展示。
///
/// 网络失败抛 [ApiException]，由调用方（搜索页）捕获后回退本地缓存搜索。
class TemplateRemoteSearchService {
  TemplateRemoteSearchService._();

  /// UI 排序 → 后端排序。
  static TemplateSearchSort sortOf(SearchSort sort) {
    switch (sort) {
      case SearchSort.hot:
        return TemplateSearchSort.hot;
      case SearchSort.latest:
        return TemplateSearchSort.latest;
      case SearchSort.photos:
        return TemplateSearchSort.photos;
      case SearchSort.name:
        return TemplateSearchSort.name;
      case SearchSort.comprehensive:
        return TemplateSearchSort.comprehensive;
    }
  }

  /// 后端搜索接口是否可承载当前筛选。
  ///
  /// 后端仅支持 q / sort / category / 分页，**不支持**价格筛选、仅我拥有、
  /// 用户标签 AND 交集。命中这些高级筛选时返回 false，页面应退用本地全量检索。
  static bool isBackendCapable(SearchFilters filters) {
    return filters.price == SearchPriceFilter.all &&
        !filters.ownedOnly &&
        filters.userTagIds.isEmpty;
  }

  /// 实时搜索线上模板。返回解析后的响应体（含 meta + hotScore/shootCount/openCount）。
  ///
  /// [page]/[pageSize] 默认取最大 50，交由解析缓存的 search base 在内存分页，
  /// 以便一次拉回足够数量供合并排序；失败抛异常由调用方回退。
  static Future<RemoteTemplateSearchResponseDto> search(
    RemoteTemplatesRepository repo, {
    required String keyword,
    required SearchFilters filters,
    int page = 1,
    int pageSize = 50,
  }) {
    return repo.search(
      q: keyword,
      sort: sortOf(filters.sort),
      category: filters.category,
      page: page,
      pageSize: pageSize,
    );
  }
}