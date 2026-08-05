import '../../../core/network/api_error.dart';
import '../data/profile_dao.dart';
import '../data/profile_models.dart';
import '../data/profile_repository.dart';

/// 资料保存结果
class ProfileSaveResult {
  final bool success;
  final bool synced;
  final String? error;
  const ProfileSaveResult({required this.success, required this.synced, this.error});
}

/// 个人资料同步服务
///
/// 离线优先：本地 sqflite 立即生效，再上报后端；网络失败不阻塞，标记待同步。
class ProfileSyncService {
  ProfileSyncService({
    required UserProfileDao dao,
    required ProfileRepository repository,
  })  : _dao = dao,
        _repo = repository;

  final UserProfileDao _dao;
  final ProfileRepository _repo;

  /// 保存资料：本地落库 → 上报后端
  Future<ProfileSaveResult> save(ProfileData profile) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _dao.upsert(profile, now);
    try {
      await _repo.update(username: profile.username, avatarSeed: profile.avatarSeed);
      await _dao.markSynced(now);
      return const ProfileSaveResult(success: true, synced: true);
    } on ApiException catch (e) {
      return ProfileSaveResult(success: true, synced: false, error: e.message);
    } catch (e) {
      return ProfileSaveResult(success: true, synced: false, error: e.toString());
    }
  }

  /// 首次拉取：本地无资料时从后端获取并落库（兼容已注册老设备）
  Future<void> ensureLoadedIfMissing() async {
    final local = await _dao.get();
    if (local != null) return;
    try {
      final remote = await _repo.fetch();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _dao.upsert(remote, now);
      await _dao.markSynced(now);
    } catch (_) {
      // 静默失败（如未注册无 token），下次启动再试
    }
  }

  /// 补传未同步的资料（App 启动时调用）
  Future<void> syncPendingIfNeeded() async {
    final hasUnsynced = await _dao.hasUnsynced();
    if (!hasUnsynced) return;
    final local = await _dao.get();
    if (local == null) return;
    try {
      await _repo.update(username: local.username, avatarSeed: local.avatarSeed);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _dao.markSynced(now);
    } catch (_) {
      // 静默失败，下次启动再试
    }
  }
}
