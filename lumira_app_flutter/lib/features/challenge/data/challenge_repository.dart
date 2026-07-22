import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/db/dao/gallery_dao.dart';
import 'challenge_pool.dart';
import 'challenge_models.dart';
import 'challenge_dao.dart';

abstract class ChallengeRepository {
  Future<List<ChallengePoolItem>> getDailyCandidates();
  Future<void> recordDailySelection(ChallengePoolItem selected);
  Future<ChallengePoolItem?> getTodayChallenge();
  Future<List<ChallengeHistoryRecord>> getWeeklyHistory();
  Future<List<ChallengeAchievement>> getAchievements();
  ChallengeTip getTipForCategory(String category);
  List<SubChallenge> getSubChallenges(String dailyCategory);
}

class LocalChallengeRepository implements ChallengeRepository {
  final ChallengeDao _challengeDao;
  final GalleryDao _galleryDao;
  final DateTime Function() _now;

  LocalChallengeRepository({
    required ChallengeDao challengeDao,
    required GalleryDao galleryDao,
    DateTime Function()? now,
  })  : _challengeDao = challengeDao,
        _galleryDao = galleryDao,
        _now = now ?? DateTime.now;

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int _dailySeed(DateTime date) => date.year * 10000 + date.month * 100 + date.day;

  @override
  Future<List<ChallengePoolItem>> getDailyCandidates() async {
    final now = _now();
    final seed = _dailySeed(now);
    final random = Random(seed);
    final profile = await _buildProfile();
    final categories = _selectCategories(profile, random);
    return categories.map((cat) {
      final pool = ChallengePool.byCategory(cat);
      final idx = random.nextInt(pool.length);
      return pool[idx];
    }).toList();
  }

  Future<UserShootingProfile> _buildProfile() async {
    final categoryCounts = await _galleryDao.countByCategory();
    final totalPhotos = categoryCounts.values.fold(0, (a, b) => a + b);
    final tried = categoryCounts.keys.where((c) => (categoryCounts[c] ?? 0) > 0).toSet();
    final untried = ChallengeCategory.all.where((c) => !tried.contains(c)).toSet();
    String? topCat;
    int maxCount = 0;
    categoryCounts.forEach((cat, cnt) {
      if (cnt > maxCount) { maxCount = cnt; topCat = cat; }
    });
    return UserShootingProfile(
      totalPhotos: totalPhotos, categoryCounts: categoryCounts,
      triedCategories: tried, untriedCategories: untried, topCategory: topCat,
    );
  }

  List<String> _selectCategories(UserShootingProfile profile, Random random) {
    final all = List<String>.from(ChallengeCategory.all)..shuffle(random);
    final result = <String>[];
    if (profile.totalPhotos < 5) { result.addAll(all.take(3)); return result; }
    final untried = profile.untriedCategories.toList()..shuffle(random);
    final tried = profile.triedCategories.toList()..shuffle(random);
    while (result.length < 3) {
      if (untried.isNotEmpty && (result.length < 2 || random.nextDouble() < 0.6)) {
        result.add(untried.removeAt(0));
      } else if (tried.isNotEmpty) {
        result.add(tried.removeAt(0));
      } else if (untried.isNotEmpty) {
        result.add(untried.removeAt(0));
      } else { break; }
    }
    if (result.length < 3) {
      for (final cat in all) {
        if (result.length >= 3) break;
        if (!result.contains(cat)) result.add(cat);
      }
    }
    return result.take(3).toList();
  }

  @override
  Future<void> recordDailySelection(ChallengePoolItem selected) async {
    final now = _now();
    await _challengeDao.insert(ChallengeHistoryRecord(
      id: '${_formatDate(now)}_${selected.id}', date: _formatDate(now),
      challengeId: selected.id, category: selected.category, title: selected.title,
      rewardXP: selected.rewardXP, status: ChallengeStatus.pending,
      selectedAt: now.millisecondsSinceEpoch, isDaily: true,
    ));
  }

  @override
  Future<ChallengePoolItem?> getTodayChallenge() async {
    final today = _formatDate(_now());
    final record = await _challengeDao.getDailyByDate(today);
    if (record == null) return null;
    return ChallengePool.byId(record.challengeId);
  }

  @override
  Future<List<ChallengeHistoryRecord>> getWeeklyHistory() async {
    final now = _now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return _challengeDao.getWeeklyHistory(_formatDate(weekStart), _formatDate(now));
  }

  @override
  Future<List<ChallengeAchievement>> getAchievements() async {
    final completedCount = await _challengeDao.countCompleted();
    final distinctCategories = await _challengeDao.countDistinctCompletedCategories();
    final portraitCount = await _challengeDao.countByCategory(ChallengeCategory.portrait);
    final landscapeCount = await _challengeDao.countByCategory(ChallengeCategory.landscape);
    return [
      ChallengeAchievement(id: 'first_challenge', title: '初出茅庐', description: '完成第 1 个挑战', icon: Icons.flag_outlined, unlocked: completedCount >= 1, progress: (completedCount / 1).clamp(0.0, 1.0)),
      ChallengeAchievement(id: 'streak_7', title: '七日坚持', description: '连续打卡 7 天', icon: Icons.local_fire_department_outlined, unlocked: false, progress: 0),
      ChallengeAchievement(id: 'streak_15', title: '半月之星', description: '连续打卡 15 天', icon: Icons.star_outline, unlocked: false, progress: 0),
      ChallengeAchievement(id: 'explorer_3', title: '探索者', description: '尝试 3 个不同分类', icon: Icons.explore_outlined, unlocked: distinctCategories >= 3, progress: (distinctCategories / 3).clamp(0.0, 1.0)),
      ChallengeAchievement(id: 'explorer_all', title: '全领域', description: '尝试全部 7 个分类', icon: Icons.category_outlined, unlocked: distinctCategories >= 7, progress: (distinctCategories / 7).clamp(0.0, 1.0)),
      ChallengeAchievement(id: 'portrait_master', title: '人像大师', description: '完成 10 个人像挑战', icon: Icons.face_outlined, unlocked: portraitCount >= 10, progress: (portraitCount / 10).clamp(0.0, 1.0)),
      ChallengeAchievement(id: 'landscape_master', title: '风光达人', description: '完成 10 个风光挑战', icon: Icons.landscape_outlined, unlocked: landscapeCount >= 10, progress: (landscapeCount / 10).clamp(0.0, 1.0)),
      ChallengeAchievement(id: 'completed_50', title: '百折不挠', description: '累计完成 50 个挑战', icon: Icons.emoji_events_outlined, unlocked: completedCount >= 50, progress: (completedCount / 50).clamp(0.0, 1.0)),
    ];
  }

  @override
  ChallengeTip getTipForCategory(String category) {
    switch (category) {
      case ChallengeCategory.portrait:
        return ChallengeTip(title: '人像光影秘籍', description: '利用 45 度侧光打造伦勃朗光效果，让面部更有立体感', icon: Icons.face_retouching_natural_outlined, category: category);
      case ChallengeCategory.landscape:
        return ChallengeTip(title: '风光构图法则', description: '三分法 + 前景引导线，让风景照片层次分明', icon: Icons.landscape_outlined, category: category);
      case ChallengeCategory.food:
        return ChallengeTip(title: '美食拍摄技巧', description: '自然侧光 + 浅景深，突出食物质感和色彩', icon: Icons.restaurant_outlined, category: category);
      case ChallengeCategory.street:
        return ChallengeTip(title: '街拍心法', description: '预判场景，提前对焦，捕捉决定性瞬间', icon: Icons.directions_walk_outlined, category: category);
      case ChallengeCategory.night:
        return ChallengeTip(title: '夜景曝光指南', description: '三脚架 + 长曝光，或高 ISO + 大光圈手持', icon: Icons.nightlight_outlined, category: category);
      case ChallengeCategory.macro:
        return ChallengeTip(title: '微距对焦技巧', description: '手动对焦更精准，连拍多张选最清晰的', icon: Icons.center_focus_strong_outlined, category: category);
      case ChallengeCategory.stillLife:
        return ChallengeTip(title: '静物布光法', description: '单侧光 + 反光板补暗部，营造立体感', icon: Icons.collections_outlined, category: category);
      default:
        return ChallengeTip(title: '通用拍摄技巧', description: '注意光线方向和构图，多拍多练', icon: Icons.camera_alt_outlined, category: category);
    }
  }

  @override
  List<SubChallenge> getSubChallenges(String dailyCategory) {
    final otherCategories = ChallengeCategory.all.where((c) => c != dailyCategory).toList();
    final random = Random(_dailySeed(_now()) + 1);
    otherCategories.shuffle(random);
    final subChallenges = <SubChallenge>[];
    for (final cat in otherCategories.take(2)) {
      final pool = ChallengePool.byCategory(cat);
      final item = pool[random.nextInt(pool.length)];
      subChallenges.add(SubChallenge(
        id: item.id, title: item.title, icon: _categoryIcon(cat),
        status: ChallengeStatus.pending, progressCurrent: 0, progressTotal: 1,
        rewardXP: (item.rewardXP * 0.6).round(),
        tags: [ChallengeTag(label: ChallengeCategory.label(cat), color: _tagColor(cat))],
      ));
    }
    return subChallenges;
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case ChallengeCategory.portrait:
        return Icons.face_outlined;
      case ChallengeCategory.landscape:
        return Icons.landscape_outlined;
      case ChallengeCategory.food:
        return Icons.restaurant_outlined;
      case ChallengeCategory.street:
        return Icons.directions_walk_outlined;
      case ChallengeCategory.night:
        return Icons.nightlight_outlined;
      case ChallengeCategory.macro:
        return Icons.center_focus_strong_outlined;
      case ChallengeCategory.stillLife:
        return Icons.collections_outlined;
      default:
        return Icons.help_outline;
    }
  }

  ChallengeTagColor _tagColor(String category) {
    switch (category) {
      case ChallengeCategory.portrait:
        return ChallengeTagColor.gold;
      case ChallengeCategory.landscape:
        return ChallengeTagColor.green;
      case ChallengeCategory.food:
        return ChallengeTagColor.red;
      default:
        return ChallengeTagColor.gold;
    }
  }
}
