// lib/features/templates/data/remote_templates_providers.dart
//
// 后端动态模板同步 Provider。
//
// 三种 Provider 职责：
// - remoteTemplatesRepositoryProvider: Repository 工厂（依赖 ApiClient）
// - remoteCategoriesSyncProvider / remoteTemplatesSyncProvider: 全量同步 FutureProvider
//   进入模板页时触发，拉取后端 list/categories → upsert 到 sqflite → prune 已下架的 remote 模板
// - remoteTemplateDetailProvider: 按需拉取单个模板完整内容的 FutureProvider.family
//   打开详情页且 sqflite 中只有 meta（composition_json='{}'）时触发
// - templateDetailProvider: 详情页统一入口，按 mock → DAO → remote 顺序查找
//
// 错误处理：网络失败抛异常，FutureProvider 自动进入 error 状态，
// UI 层（templates_page / templates_all_page / templates_detail_page）使用本地缓存降级，
// 不主动展示错误（spec §7.2）。

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/dao/templates_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/db/seeders/builtin_data_seeder.dart';
import '../../../core/network/api_client.dart';
import '../../capture/domain/photo_template.dart';
import '../services/template_mapper.dart';
import 'remote_templates_repository.dart';
import 'templates_browse_mock_data.dart';

/// 远程模板 Repository Provider。
///
/// 复用全局 [apiClientProvider]（与 [ownedTemplatesRepositoryProvider] 同源），
/// baseUrl 来自 [AppConfig.baseUrl]（含 /api/v1 前缀）。
final remoteTemplatesRepositoryProvider =
    FutureProvider<RemoteTemplatesRepository>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  return RemoteTemplatesRepositoryImpl(api);
});

/// 拉取后端分类列表 → upsert 到 sqflite template_categories 表
/// → prune 本地已不在后端列表的分类。
///
/// 触发时机：
/// - 进入模板页（templates_page.dart initState）
/// - 模板分类页下拉刷新（templates_category_page.dart _onRefresh）
///
/// 失败处理：网络失败静默忽略，UI 用本地缓存（含 7 个系统分类兜底）。
/// 静默忽略通过 FutureProvider 的 error 状态实现，调用方不 await 此 future 即不抛错。
/// 注意：prune 仅在拉取成功后执行；网络失败抛错进入 error 状态，不会误删本地缓存。
final remoteCategoriesSyncProvider = FutureProvider<void>((ref) async {
  final repo = await ref.watch(remoteTemplatesRepositoryProvider.future);
  final dao = await ref.watch(templatesDaoProvider.future);
  final cats = await repo.fetchCategories();
  for (final c in cats) {
    await dao.upsertCategory(TemplateCategoryRecord(
      key: c.key,
      name: c.name,
      parentKey: c.parentKey,
      level: c.level,
      iconUrl: c.iconUrl,
      description: c.description,
      sortOrder: c.sortOrder,
      isSystem: c.isSystem,
      isActive: c.isActive,
      updatedAt: c.updatedAt,
    ));
  }
  // 阶段 2: 删除本地已不在后端列表的分类（后台删除/停用后同步清理），
  // 避免分类页残留已删除分类（与 remoteTemplatesSyncProvider 的 prune 一致）。
  final validKeys = cats.map((c) => c.key).toSet();
  await dao.pruneStaleCategories(validKeys);
  // 兜底：重种 7 个系统内置分类及其 style/method 子树（INSERT OR REPLACE / OR IGNORE 幂等）。
  // 即使后端分类树未下发这些 key（如历史误删的 micro 微距），也能恢复一级分类概览，
  // 保证离线兜底题材始终可用（spec 2026-08-17-template-category-4level-design.md）。
  final db = await ref.watch(databaseProvider.future);
  await BuiltinDataSeeder.seedCategories(db);
  await BuiltinDataSeeder.seedStyleMethodCategories(db);
});

/// 拉取后端模板 meta 列表 → upsert 到 sqflite custom_templates（source='remote'）
/// → prune 本地已不在后端列表的 remote 模板。
///
/// 触发时机：同 [remoteCategoriesSyncProvider]。
///
/// 失败处理：网络失败静默忽略，UI 用本地缓存。
/// 注意：不删除用户自定义模板（source='custom'），仅清理 source='remote' 的缓存。
final remoteTemplatesSyncProvider = FutureProvider<void>((ref) async {
  final repo = await ref.watch(remoteTemplatesRepositoryProvider.future);
  final dao = await ref.watch(templatesDaoProvider.future);
  final resp = await repo.list();
  // 阶段 1: upsert 远端 meta 到 sqflite（5 段 JSON 设为 '{}'，详情按需拉取）
  for (final meta in resp.templates) {
    final record = TemplateMapper.metaToRecord(meta);
    await dao.upsert(record);
  }
  // 阶段 2: 删除本地 source='remote' 但已不在后端列表的模板（已下架/已删除）
  final validIds = resp.templates.map((t) => t.id).toSet();
  await dao.pruneRemoteTemplates(validIds);
});

/// 按需拉取单个远程模板完整内容 → upsert 到 sqflite → 返回 PhotoTemplate。
///
/// 触发时机：
/// - 拍摄页 / 编辑器（capture_state / templates_editor_page）需要完整模板内容时；
/// - 详情页历史版本曾依赖本 provider，现详情页（[templateDetailProvider]）改为
///   每次进入直接走 Repository 拉取最新内容，不经过本 provider（避免全局缓存旧数据）。
///
/// 返回值：成功返回填充完整的 [PhotoTemplate]；失败抛异常（UI 显示"网络错误"并禁用"套用拍摄"）。
final remoteTemplateDetailProvider =
    FutureProvider.family<PhotoTemplate?, String>((ref, id) async {
  final repo = await ref.watch(remoteTemplatesRepositoryProvider.future);
  final dao = await ref.watch(templatesDaoProvider.future);
  final detail = await repo.fetchDetail(id);
  final record = TemplateMapper.detailToRecord(detail);
  await dao.upsert(record);
  // 重新读取以获得规范化的 TemplateRecord（确保 source 等字段被默认值填充）
  final refreshed = await dao.getById(id);
  if (refreshed == null) {
    debugPrint('[remote] detail upsert vanished: $id');
    return null;
  }
  return TemplateMapper.toPhotoTemplate(refreshed);
});

/// 模板详情统一 Provider（v14 新增）。
///
/// 详情页（templates_detail_page.dart）通过此 provider 获取 [TemplateDetail]，
/// 查找顺序：
/// 1. [TemplatesBrowseMockData.findDetailById]（mock + TemplateRegistry，同步快路径）
///    - 覆盖内置 29 个模板 + mock 详情列表
/// 2. DAO [TemplatesDao.getById]（含 builtin 镜像 / custom / remote meta）
///    - 若记录存在且 source='remote' 且 composition_json 为空 → 触发 [remoteTemplateDetailProvider]
/// 3. 将 [PhotoTemplate] 通过 [TemplatesBrowseMockData.fromPhotoTemplate] 转为 [TemplateDetail]
///
/// 返回值：
/// - 非null：模板详情（来自 mock / DAO / 远程拉取）
/// - null：模板不存在（id 错误或已下架且本地无缓存）
///
/// 错误处理：
/// - 远程拉取失败 → 抛异常（FutureProvider 进入 error 状态，UI 显示"网络错误"）
/// - DAO 不可用 → 返回 mock 结果（可能为 null）
final templateDetailProvider =
    FutureProvider.autoDispose.family<TemplateDetail?, String>((ref, id) async {
  // 1. 快路径：mock + TemplateRegistry（同步）
  final mock = TemplatesBrowseMockData.findDetailById(id);
  if (mock != null) return mock;

  // 2. 慢路径：DAO 查找（含 custom / remote 缓存）
  final dao = await ref.watch(templatesDaoProvider.future);
  final record = await dao.getById(id);
  if (record == null) return null;

  // 3. remote 模板：每次进入详情页都尝试拉取后端最新完整内容，
  //    保证后台修改模板后 App 重新进入能看到更新；网络失败时降级本地缓存。
  //    注意：此处直接用 Repository 拉取（而非 watch remoteTemplateDetailProvider），
  //    避免命中其全局缓存导致数据仍是旧版本。
  if (record.source == 'remote') {
    try {
      final repo = await ref.watch(remoteTemplatesRepositoryProvider.future);
      final detail = await repo.fetchDetail(id);
      await dao.upsert(TemplateMapper.detailToRecord(detail));
      final refreshed = await dao.getById(id);
      if (refreshed != null) {
        return TemplatesBrowseMockData.fromPhotoTemplate(
          TemplateMapper.toPhotoTemplate(refreshed),
          fillLight: _fillLightFromRecord(refreshed),
        );
      }
    } catch (_) {
      // 网络失败：本地已有完整内容则降级展示；否则抛错让 UI 显示网络错误 + 重试
      if (record.composition.isEmpty) rethrow;
    }
    return TemplatesBrowseMockData.fromPhotoTemplate(
      TemplateMapper.toPhotoTemplate(record),
      fillLight: _fillLightFromRecord(record),
    );
  }

  // 4. 本地（builtin/custom）已有完整内容 → 直接转换
  return TemplatesBrowseMockData.fromPhotoTemplate(
    TemplateMapper.toPhotoTemplate(record),
    fillLight: _fillLightFromRecord(record),
  );
});

/// 从模板记录 postProcess JSON 解析补光灯配置；未启用或不存在时返回 null。
FillLightData? _fillLightFromRecord(TemplateRecord r) {
  final fl = r.postProcess['fillLight'] as Map<String, dynamic>?;
  if (fl == null) return null;
  return FillLightData(
    enabled: (fl['enabled'] as bool?) ?? false,
    color: (fl['color'] as num?)?.toInt() ?? 0xFFFFE5B4,
    intensity: (fl['intensity'] as num?)?.toDouble() ?? 0.8,
  );
}
