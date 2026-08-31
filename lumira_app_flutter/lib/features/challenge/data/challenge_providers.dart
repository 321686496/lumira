import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/db/database_provider.dart';
import 'challenge_repository.dart';
import 'challenge_models.dart';

final challengeRepositoryProvider = FutureProvider<ChallengeRepository>((ref) async {
  final challengeDao = await ref.watch(challengeDaoProvider.future);
  final galleryDao = await ref.watch(galleryDaoProvider.future);
  return LocalChallengeRepository(challengeDao: challengeDao, galleryDao: galleryDao);
});

final dailyChallengeStateProvider = FutureProvider<DailyChallengeState>((ref) async {
  final repo = await ref.watch(challengeRepositoryProvider.future);
  final today = await repo.getTodayChallenge();
  if (today != null) {
    return DailyChallengeState.revealedState(today);
  }
  final candidates = await repo.getDailyCandidates();
  return DailyChallengeState.needsFlipState(candidates);
});

final weeklyHistoryProvider = FutureProvider<List<ChallengeHistoryRecord>>((ref) async {
  final repo = await ref.watch(challengeRepositoryProvider.future);
  return repo.getWeeklyHistory();
});

/// 全部挑战历史（不限日期范围）。
/// 用于挑战记录页"查看全部"，展示所有日期的挑战记录。
final allHistoryProvider = FutureProvider<List<ChallengeHistoryRecord>>((ref) async {
  final repo = await ref.watch(challengeRepositoryProvider.future);
  return repo.getAllHistory();
});

final challengeAchievementsProvider = FutureProvider<List<ChallengeAchievement>>((ref) async {
  final repo = await ref.watch(challengeRepositoryProvider.future);
  return repo.getAchievements();
});

final challengeTipProvider = FutureProvider<ChallengeTip>((ref) async {
  final state = await ref.watch(dailyChallengeStateProvider.future);
  final repo = await ref.watch(challengeRepositoryProvider.future);
  final category = state.selected?.category ?? ChallengeCategory.portrait;
  return repo.getTipForCategory(category);
});

/// 挑战打卡状态：以挑战完成记录（ChallengeHistory status=done）为准，
/// 计算连续完成天数、本周完成状态与今日是否已完成。
///
/// 与 [shootingCheckinProvider]（基于相册照片的"拍摄打卡"）语义不同：
/// 仅"拍过照片但未完成挑战"的日子不计入打卡，中间断签会被正确中断连续天数。
final challengeCheckinProvider = FutureProvider<ChallengeCheckin>((ref) async {
  final dao = await ref.watch(challengeDaoProvider.future);
  final doneDates = await dao.getDoneDates();

  String formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // 本周 7 天状态（周一到周日）
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final todayStr = formatDate(today);
  final monday = today.subtract(Duration(days: now.weekday - 1));
  const labels = ['一', '二', '三', '四', '五', '六', '日'];

  final weekDays = <ChallengeCheckinDay>[];
  for (var i = 0; i < 7; i++) {
    final d = monday.add(Duration(days: i));
    final ds = formatDate(d);
    weekDays.add(ChallengeCheckinDay(
      label: labels[i],
      done: doneDates.contains(ds),
      today: ds == todayStr,
    ));
  }

  // 连续完成挑战天数：今天已完成则从今天起算，否则从昨天往回数，遇断签即停
  int streak = 0;
  var cursor = doneDates.contains(todayStr)
      ? today
      : today.subtract(const Duration(days: 1));
  while (doneDates.contains(formatDate(cursor))) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  return ChallengeCheckin(
    streakDays: streak,
    weekDays: weekDays,
    completedToday: doneDates.contains(todayStr),
  );
});

final subChallengesProvider = FutureProvider<List<SubChallenge>>((ref) async {
  final state = await ref.watch(dailyChallengeStateProvider.future);
  final repo = await ref.watch(challengeRepositoryProvider.future);
  final category = state.selected?.category ?? ChallengeCategory.portrait;
  return await repo.getSubChallenges(category);
});
