import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/network/api_client.dart';
import '../data/profile_models.dart';
import '../data/profile_repository.dart';
import '../services/profile_sync_service.dart';

final profileRepositoryProvider = FutureProvider<ProfileRepository>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  return RemoteProfileRepository(api);
});

final profileSyncServiceProvider = FutureProvider<ProfileSyncService>((ref) async {
  final dao = await ref.watch(userProfileDaoProvider.future);
  final repo = await ref.watch(profileRepositoryProvider.future);
  return ProfileSyncService(dao: dao, repository: repo);
});

/// 当前本地资料（null 表示尚未分配）
/// UI 通过 ref.watch 获取；保存/拉取后 ref.invalidate 刷新
final profileDataProvider = FutureProvider<ProfileData?>((ref) async {
  final dao = await ref.watch(userProfileDaoProvider.future);
  return dao.get();
});
