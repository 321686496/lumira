// lib/features/templates/data/remote_templates_repository.dart
//
// 后端动态模板 Repository。
// 参考 owned_templates_repository.dart 的模式：包装 ApiClient（dio）调用后端 REST 接口。
//
// 接口对应 spec §3.2（DeviceAuthGuard）：
//   GET /templates/list        - meta 列表（仅 isActive=1）
//   GET /templates/:id         - 单个模板完整内容
//   GET /templates/categories  - 分类列表（仅 isActive=1，按 sortOrder 排序）
//
// 静态资源 URL（封面/剪影/图标）不含 /api/v1 前缀，使用 backendHost 拼接：
//   ${backendHost}/uploads/templates/{id}/cover.{ext}
//   ${backendHost}/uploads/categories/{key}/icon.{ext}

import '../../../core/network/api_client.dart';
import 'remote_template_dto.dart';

/// 后端动态模板 Repository。
///
/// 由 [remoteTemplatesRepositoryProvider] 注入 [ApiClient]，所有方法返回 Future<T>，
/// 网络失败抛 [ApiException]（由 ApiClient 统一 classifyDioError 转换），
/// 调用方（FutureProvider）捕获后静默降级到本地 sqflite 缓存。
abstract class RemoteTemplatesRepository {
  Future<RemoteTemplateListResponseDto> list({
    int? since,
    String? category,
  });

  Future<RemoteTemplateDetailDto> fetchDetail(String id);

  Future<List<TemplateCategoryDto>> fetchCategories();

  /// 实时搜索线上模板。Network 失败抛 [ApiException]，由调用方决定是否回退本地。
  Future<RemoteTemplateSearchResponseDto> search({
    required String q,
    required TemplateSearchSort sort,
    String? category,
    int page = 1,
    int pageSize = 20,
  });
}

class RemoteTemplatesRepositoryImpl implements RemoteTemplatesRepository {
  RemoteTemplatesRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<RemoteTemplateListResponseDto> list({
    int? since,
    String? category,
  }) async {
    final query = <String, dynamic>{};
    if (since != null) query['since'] = since;
    if (category != null && category.isNotEmpty) query['category'] = category;
    return _api.get(
      '/templates/list',
      query: query.isEmpty ? null : query,
      fromJson: (j) =>
          RemoteTemplateListResponseDto.fromJson(j as Map<String, dynamic>),
    );
  }

  @override
  Future<RemoteTemplateDetailDto> fetchDetail(String id) async {
    return _api.get(
      '/templates/$id',
      fromJson: (j) =>
          RemoteTemplateDetailDto.fromJson(j as Map<String, dynamic>),
    );
  }

  @override
  Future<List<TemplateCategoryDto>> fetchCategories() async {
    final resp = await _api.get(
      '/templates/categories',
      fromJson: (j) => TemplateCategoryListResponseDto.fromJson(
        j as Map<String, dynamic>,
      ),
    );
    return resp.categories;
  }

  @override
  Future<RemoteTemplateSearchResponseDto> search({
    required String q,
    required TemplateSearchSort sort,
    String? category,
    int page = 1,
    int pageSize = 20,
  }) async {
    return _api.get(
      '/templates/search',
      query: <String, dynamic>{
        'q': q,
        'sort': sort.name,
        if (category != null && category.isNotEmpty) 'category': category,
        'page': page,
        'pageSize': pageSize,
      },
      fromJson: (j) =>
          RemoteTemplateSearchResponseDto.fromJson(j as Map<String, dynamic>),
    );
  }
}
