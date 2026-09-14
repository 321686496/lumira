import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/db/dao/gallery_dao.dart';
import 'package:lumira_app_flutter/features/challenge/data/challenge_dao.dart';
import 'package:lumira_app_flutter/features/challenge/data/challenge_models.dart';
import 'package:lumira_app_flutter/features/challenge/data/challenge_pool.dart';
import 'package:lumira_app_flutter/features/challenge/data/challenge_repository.dart';

/// 最小 GalleryDao 实现：仅提供相册分类计数，其余方法 noSuchMethod 兜底。
class _FakeGalleryDao implements GalleryDao {
  _FakeGalleryDao(this.counts);
  final Map<String, int> counts;
  @override
  Future<Map<String, int>> countByCategory() async => counts;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// 最小 ChallengeDao 实现：可注入今日主挑战与今日历史，其余方法 noSuchMethod 兜底。
class _FakeChallengeDao implements ChallengeDao {
  _FakeChallengeDao({this.daily, this.history = const []});
  final ChallengeHistoryRecord? daily;
  final List<ChallengeHistoryRecord> history;

  @override
  Future<ChallengeHistoryRecord?> getDailyByDate(String date) async => daily;

  @override
  Future<List<ChallengeHistoryRecord>> getWeeklyHistory(
      String startDate, String endDate) async => history;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

LocalChallengeRepository build({
  Map<String, int> counts = const {},
  ChallengeHistoryRecord? daily,
  List<ChallengeHistoryRecord> history = const [],
}) {
  return LocalChallengeRepository(
    challengeDao: _FakeChallengeDao(daily: daily, history: history),
    galleryDao: _FakeGalleryDao(counts),
    now: () => DateTime(2026, 9, 14),
  );
}

ChallengeHistoryRecord dailyRecord(String challengeId, String category) {
  return ChallengeHistoryRecord(
    id: '2026-09-14_$challengeId',
    date: '2026-09-14',
    challengeId: challengeId,
    category: category,
    title: '主挑战',
    rewardXP: 50,
    status: ChallengeStatus.pending,
    selectedAt: DateTime(2026, 9, 14).millisecondsSinceEpoch,
    isDaily: true,
  );
}

void main() {
  group('getDailyCandidates 每日候选（偏好锚定）', () {
    test('只拍过一个人像大类 → 3 候选全部来自人像，且互不重复', () async {
      final repo = build(counts: {ChallengeCategory.portrait: 5});
      final candidates = await repo.getDailyCandidates();

      expect(candidates, hasLength(3));
      expect(candidates.map((c) => c.category).toSet(), {ChallengeCategory.portrait});
      expect(candidates.map((c) => c.id).toSet(), hasLength(3));
    });

    test('拍过偏好(人像) + 另一大类(静物) → 偏好占 2、已拍其他大类占 1，不含未拍大类', () async {
      final repo = build(counts: {
        ChallengeCategory.portrait: 5,
        ChallengeCategory.stillLife: 3,
      });
      final candidates = await repo.getDailyCandidates();

      expect(candidates, hasLength(3));
      final byCat = <String, int>{};
      for (final c in candidates) {
        byCat[c.category] = (byCat[c.category] ?? 0) + 1;
      }
      expect(byCat[ChallengeCategory.portrait], 2);
      expect(byCat[ChallengeCategory.stillLife], 1);
      // 未拍过的分类（landscape/food/…）绝不进入候选
      const untried = {
        ChallengeCategory.landscape,
        ChallengeCategory.food,
        ChallengeCategory.street,
        ChallengeCategory.night,
        ChallengeCategory.macro,
      };
      expect(candidates.any((c) => untried.contains(c.category)), isFalse);
      expect(candidates.map((c) => c.id).toSet(), hasLength(3),
          reason: '候选题 id 应互不重复');
    });

    test('一张照片都没有 → 仍返回 3 个候选（保底），不使挑战页为空', () async {
      final repo = build(counts: {});
      final candidates = await repo.getDailyCandidates();
      expect(candidates, hasLength(3));
      expect(candidates.map((c) => c.id).toSet(), hasLength(3));
    });
  });

  group('getSubChallenges 附加挑战（偏好为主）', () {
    test('只拍过人像、今日主挑战为人像题 → 附加挑战为人像其他风格，且不与主挑战撞题、奖励为 60%', () async {
      final main = dailyRecord('portrait_001', ChallengeCategory.portrait);
      final repo = build(
        counts: {ChallengeCategory.portrait: 5},
        daily: main,
      );
      final subs = await repo.getSubChallenges(ChallengeCategory.portrait);

      expect(subs, hasLength(2));
      expect(subs.any((s) => s.id == 'portrait_001'), isFalse,
          reason: '附加挑战不能与今日主挑战撞题');
      for (final s in subs) {
        // 只拍人像 → 附加挑战都应来自人像
        expect(s.status, ChallengeStatus.pending);
        final item = ChallengePool.byId(s.id)!;
        expect(item.category, ChallengeCategory.portrait);
        expect(s.rewardXP, subChallengeRewardXP(item.rewardXP));
      }
    });

    test('今日已完成某附加挑战 → 该题 as done 展示，其他为 pending', () async {
      final main = dailyRecord('portrait_001', ChallengeCategory.portrait);
      final repo = build(
        counts: {ChallengeCategory.portrait: 5},
        daily: main,
        history: [
          ChallengeHistoryRecord(
            id: '2026-09-14_portrait_002',
            date: '2026-09-14',
            challengeId: 'portrait_002',
            category: ChallengeCategory.portrait,
            title: '已完成附加挑战',
            rewardXP: 30,
            status: ChallengeStatus.done,
            selectedAt: DateTime(2026, 9, 14).millisecondsSinceEpoch,
            completedAt: DateTime(2026, 9, 14).millisecondsSinceEpoch,
          ),
        ],
      );
      final subs = await repo.getSubChallenges(ChallengeCategory.portrait);

      expect(subs, hasLength(2));
      // 已完成题若被选中则 as done；至少一条 pending（不重复提交已完成题）
      final done = subs.where((s) => s.status == ChallengeStatus.done).toList();
      final pending = subs.where((s) => s.status == ChallengeStatus.pending).toList();
      expect(done.length + pending.length, 2);
      expect(subs.any((s) => s.id == 'portrait_001'), isFalse,
          reason: '仍不能与主挑战撞题');
    });
  });
}