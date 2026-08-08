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

final subChallengesProvider = FutureProvider<List<SubChallenge>>((ref) async {
  final state = await ref.watch(dailyChallengeStateProvider.future);
  final repo = await ref.watch(challengeRepositoryProvider.future);
  final category = state.selected?.category ?? ChallengeCategory.portrait;
  return await repo.getSubChallenges(category);
});
