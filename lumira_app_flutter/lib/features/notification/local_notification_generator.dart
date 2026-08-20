// lib/features/notification/local_notification_generator.dart
//
// 本地应用事件通知生成器（Task 7）。
//
// 阅读真实本地状态，生成 5 类本地应用事件通知（source='local'）：
//   - streak    连续打卡：user_progress.streak_days（>1）
//   - challenge 今日挑战未完成：challenge_history 当日记录
//   - achievement 成就解锁：user_progress.achievements_json 最新解锁项
//   - template  模板上新：custom_templates 中最新 source='remote' 模板
//   - system    App 版本更新：App 版本常量 + 静态文案
//
// 每条用 getByLocalKey(id) 判重（id = 'kind:业务键'），已存在则跳过，
// 避免每次进入通知中心页被重复插入叠加。生成后立即 insertLocal（未读）。
//
// 与 Task 6 的 provider 保持一致：unreadLocalGeneratedProvider 为
// FutureProvider<void>，由 notificationsProvider 点火，只负责把新生成的
// 本地通知写入 DAO（未读），不做任何网络请求。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/db/dao/growth_dao.dart';
import '../../../core/db/dao/templates_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/db/tables.dart';
import '../challenge/data/challenge_dao.dart';
import '../challenge/data/challenge_models.dart';
import '../profile/providers/growth_providers.dart';
import 'data/notification_dao.dart';
import 'notification_models.dart';

/// App 版本号（与 pubspec.yaml version 对齐：1.0.0+1）。
/// 作为 system 类通知的业务键（升级到新版本时生成一次）。
const String kAppVersion = '1.0.0';

/// 本地应用事件通知生成器。
///
/// 依赖本地 DAO / 裸表读取，均在生成时通过 [unreadLocalGeneratedProvider] 注入。
class LocalNotificationGenerator {
  LocalNotificationGenerator({
    required Database db,
    required NotificationDao dao,
    required GrowthDao growthDao,
    required ChallengeDao challengeDao,
    required TemplatesDao templatesDao,
  })  : _db = db,
        _dao = dao,
        _growthDao = growthDao,
        _challengeDao = challengeDao,
        _templatesDao = templatesDao;

  final Database _db;
  final NotificationDao _dao;
  final GrowthDao _growthDao;
  final ChallengeDao _challengeDao;
  final TemplatesDao _templatesDao;

  /// 生成全部 5 类本地通知；新增（已存在跳过的判断在 [uniq] 内完成）并返回。
  Future<List<NotificationItem>> generate() async {
    final candidates = <NotificationRecord>[
      ...await _streakCandidate(),
      ...await _challengeCandidate(),
      ...await _achievementCandidate(),
      ...await _templateCandidate(),
      ...await _systemCandidate(),
    ];
    return uniq(candidates);
  }

  /// 按本地主键去重：仅插入本地表中尚不存在的记录，避免每次进页重复叠加。
  /// 已存在的记录跳过，不重复插入。
  Future<List<NotificationItem>> uniq(List<NotificationRecord> list) async {
    final result = <NotificationItem>[];
    for (final r in list) {
      if (await _dao.getByLocalKey(r.id) != null) continue;
      await _dao.insertLocal(r);
      result.add(NotificationItem.fromRecord(r));
    }
    return result;
  }

  // === 五类候选生成（各自独立判空：数据不存在或条件不满足时返回空） ===

  /// 连续打卡：user_progress.streak_days > 1 → kind='streak'。
  Future<List<NotificationRecord>> _streakCandidate() async {
    final rows = await _db.query(
      Tables.userProgress,
      columns: [Tables.colStreakDays],
      where: '${Tables.colId} = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (rows.isEmpty) return const [];
    final streakDays =
        ((rows.first[Tables.colStreakDays] as num?)?.toInt() ?? 0);
    if (streakDays <= 1) return const [];
    final now = DateTime.now();
    return [
      NotificationRecord(
        id: 'streak:${_formatDate(now)}',
        source: 'local',
        kind: 'streak',
        title: '连续拍摄提醒',
        body: '你已经连续拍摄 $streakDays 天，继续保持创作节奏！',
        timeMs: now.millisecondsSinceEpoch,
      ),
    ];
  }

  /// 今日挑战未完成 → kind='challenge'。
  /// 复用 challenge DAO 的"今日是否完成"逻辑：可无今日记录（尚未翻牌）时跳过，
  /// 有记录但状态非 done（pending/skipped）时生成提醒。
  Future<List<NotificationRecord>> _challengeCandidate() async {
    final now = DateTime.now();
    final today = _formatDate(now);
    final record = await _challengeDao.getDailyByDate(today);
    if (record == null || record.status == ChallengeStatus.done) {
      return const [];
    }
    return [
      NotificationRecord(
        id: 'challenge:$today',
        source: 'local',
        kind: 'challenge',
        title: '今日挑战待完成',
        body: '「${record.title}」还没完成，打开挑战页去拿下它吧！',
        timeMs: now.millisecondsSinceEpoch,
      ),
    ];
  }

  /// 成就解锁：user_progress.achievements_json 最新解锁项 → kind='achievement'。
  Future<List<NotificationRecord>> _achievementCandidate() async {
    final achievements = await _growthDao.getAchievements();
    final unlocked = achievements
        .where((a) => a.unlocked && a.unlockedAt != null)
        .toList()
      ..sort((a, b) => b.unlockedAt!.compareTo(a.unlockedAt!));
    if (unlocked.isEmpty) return const [];
    final newest = unlocked.first;
    return [
      NotificationRecord(
        id: 'achievement:${newest.id}',
        source: 'local',
        kind: 'achievement',
        title: '成就解锁',
        body: '恭喜解锁成就「${newest.name}」：${newest.description}',
        timeMs: newest.unlockedAt!,
      ),
    ];
  }

  /// 模板上新：source='remote' 的最新建模板 updatedAt → kind='template'。
  Future<List<NotificationRecord>> _templateCandidate() async {
    final remote = await _templatesDao.getRemote();
    if (remote.isEmpty) return const [];
    // getRemote 已按 updated_at DESC 排序，取第一个即最近更新的模板
    final newest = remote.first;
    return [
      NotificationRecord(
        id: 'template:${newest.id}',
        source: 'local',
        kind: 'template',
        title: '新模板上线',
        body: '新模板《${newest.name}》已更新，快去「模板库」试试！',
        timeMs: newest.updatedAt,
      ),
    ];
  }

  /// 系统通知：App 版本常量 + 静态文案 → kind='system'（每版本一次）。
  Future<List<NotificationRecord>> _systemCandidate() async {
    return [
      NotificationRecord(
        id: 'system:v$kAppVersion',
        source: 'local',
        kind: 'system',
        title: '版本更新',
        body: '如画 Lumira v$kAppVersion 已就绪，享受更流畅的创作体验。',
        timeMs: DateTime.now().millisecondsSinceEpoch,
      ),
    ];
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// 本地应用事件通知生成 Provider（未读）。
///
/// 触发时机：进入通知中心页（notificationsProvider 点火）。
/// 职责：注入各本地 DAO → 调用 [LocalNotificationGenerator.generate] 把新生成的
/// 本地通知（未读）写入 sqflite notifications 表。失败静默，不影响本地列表。
final unreadLocalGeneratedProvider = FutureProvider<void>((ref) async {
  try {
    final db = await ref.watch(databaseProvider.future);
    final dao = await ref.watch(notificationDaoProvider.future);
    final growthDao = await ref.watch(growthDaoProvider.future);
    final challengeDao = await ref.watch(challengeDaoProvider.future);
    final templatesDao = await ref.watch(templatesDaoProvider.future);
    final generator = LocalNotificationGenerator(
      db: db,
      dao: dao,
      growthDao: growthDao,
      challengeDao: challengeDao,
      templatesDao: templatesDao,
    );
    await generator.generate();
  } catch (_) {
    // 本地事件生成失败静默：UI 只用已存在的通知（不影响进入通知中心页）
  }
});