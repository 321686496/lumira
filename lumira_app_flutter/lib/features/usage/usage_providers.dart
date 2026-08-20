// lumira_app_flutter/lib/features/usage/usage_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/network/api_client.dart';
import 'builtin_scene_sync_service.dart';
import 'builtin_template_sync_service.dart';
import 'usage_event_recorder.dart';
import 'usage_sync_service.dart';

/// 模板/场景使用事件记录器（埋点）。
final usageEventRecorderProvider = FutureProvider<UsageEventRecorder>((ref) async {
  final dao = await ref.watch(usageDaoProvider.future);
  return UsageEventRecorder(dao);
});

/// 使用次数同步服务（上报未同步事件 + 拉取全站次数）。
final usageSyncServiceProvider = FutureProvider<UsageSyncService>((ref) async {
  final dao = await ref.watch(usageDaoProvider.future);
  final api = await ref.watch(apiClientProvider.future);
  return UsageSyncService(dao, DioUsageNetwork(api));
});

/// 内置模板名称同步服务。
final builtinTemplateSyncServiceProvider =
    FutureProvider<BuiltinTemplateSyncService>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  return BuiltinTemplateSyncService(DioBuiltinTemplateNetwork(api));
});

/// 内置场景名称同步服务。
final builtinSceneSyncServiceProvider =
    FutureProvider<BuiltinSceneSyncService>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  return BuiltinSceneSyncService(DioBuiltinSceneNetwork(api));
});