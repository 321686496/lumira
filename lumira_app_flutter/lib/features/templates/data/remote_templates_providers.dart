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
//
// 错误处理：网络失败抛异常，FutureProvider 自动进入 error 状态，
// UI 层（templates_page / templates_all_page / templates_detail_page）使用本地缓存降级，
// 不主动展示错误（spec §7.2）。

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/dao/templates_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/network/api_client.dart';
import '../../capture/domain/photo_template.dart';
import '../services/template_mapper.dart';
import 'remote_template_dto.dart';
import 'remote_templates_repository.dart';

/// 远程模板 Repository Provider。
///
/// 复用全局 [apiClientProvider]（与 [ownedTemplatesRepositoryProvider] 同源），
/// baseUrl 来自 [AppConfig.baseUrl]（含 /api/v1 前缀）。
final remoteTemplatesRepositoryProvider =
    FutureProvider<RemoteTemplatesRepository>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  return RemoteTemplatesRepositoryImpl(api);
});

/// 拉取后端分类列表 → upsert 到 sqflite template_categories 表。
///
/// 触发时机：
/// - 进入模板页（templates_page.dart initState）
/// - App 启动初始化（可选）
///
/// 失败处理：网络失败静默忽略，UI 用本地缓存（含 7 个系统分类兜底）。
/// 静默忽略通过 FutureProvider 的 error 状态实现，调用方不 await 此 future 即不抛错。
final remoteCategoriesSyncProvider = FutureProvider<void>((ref) async {
  final repo = await ref.watch(remoteTemplatesRepositoryProvider.future);
  final dao = await ref.watch(templatesDaoProvider.future);
  final cats = await repo.fetchCategories();
  for (final c in cats) {
    await dao.upsertCategory(TemplateCategoryRecord(
      key: c.key,
      name: c.name,
      iconUrl: c.iconUrl,
      sortOrder: c.sortOrder,
      isSystem: c.isSystem,
      isActive: c.isActive,
      updatedAt: c.updatedAt,
    ));
  }
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
/// 触发时机：详情页打开 source='remote' 且 sqflite 中 composition_json='{}' 的模板时。
///
/// 返回值：成功返回填充完整的 [PhotoTemplate]；失败抛异常（UI 显示"网络错误"并禁用"套用拍摄"）。
/// 注意：拉取成功后再次进入同一模板详情页时，sqflite 已缓存完整内容，无需再次拉取。
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
