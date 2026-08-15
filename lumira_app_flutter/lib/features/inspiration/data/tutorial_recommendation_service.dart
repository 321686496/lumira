import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/dao/tutorial_read_dao.dart';
import '../../onboarding/data/questionnaire_answers.dart';
import '../../onboarding/data/questionnaire_dao.dart';
import 'tutorial_content.dart';
import 'tutorial_models.dart';

/// 类别权重（与 countByCategory 返回 key 一致 + general）
const List<String> _kAllCategories = [
  'general', 'portrait', 'landscape', 'food', 'street', 'night', 'macro', 'still-life',
];

/// 拍摄小课堂推荐服务
///
/// 信号：问卷偏好（静态）+ 近 30 天拍摄统计（动态）+ 已读状态。
/// 规则：类别权重（问卷 3 / 行为 top2 3、问卷 2、其余 1、general 冷启动 1.2）
///       → 未读 +1 → 60% 高分池 + 40% 低分池 → 保证 >=3 类别。
class TutorialRecommendationService {
  TutorialRecommendationService({
    required QuestionnaireDao questionnaireDao,
    required GalleryDao galleryDao,
    required TutorialReadDao readDao,
  })  : _questionnaireDao = questionnaireDao,
        _galleryDao = galleryDao,
        _readDao = readDao;

  final QuestionnaireDao _questionnaireDao;
  final GalleryDao _galleryDao;
  final TutorialReadDao _readDao;

  Future<List<ShootingTutorial>> recommend({int count = 6}) async {
    try {
      final answers = await _questionnaireDao.getAnswers();
      final counts = await _galleryDao.countByCategory();
      final readIds = await _readDao.getReadIds();
      return _recommendWith(
        favCategories: answers?.favoriteCategories ?? const [],
        counts: counts,
        readIds: readIds,
        count: count,
      );
    } catch (_) {
      return _fallbackEven(count);
    }
  }

  List<ShootingTutorial> _recommendWith({
    required List<String> favCategories,
    required Map<String, int> counts,
    required Set<String> readIds,
    required int count,
  }) {
    final weights = _buildWeights(favCategories, counts);
    final scores = <String, double>{};
    final high = <ShootingTutorial>[];
    final low = <ShootingTutorial>[];
    for (final t in TutorialContent.all) {
      final w = weights[t.category] ?? 1.0;
      final readBonus = readIds.contains(t.id) ? 0.0 : 1.0;
      scores[t.id] = w + readBonus;
      (w >= 2 ? high : low).add(t);
    }
    int byScoreDesc(ShootingTutorial a, ShootingTutorial b) =>
        scores[b.id]!.compareTo(scores[a.id]!);
    high.sort(byScoreDesc);
    low.sort(byScoreDesc);

    final result = <ShootingTutorial>[];
    final usedIds = <String>{};
    void addFrom(List<ShootingTutorial> pool) {
      for (final t in pool) {
        if (result.length >= count) return;
        if (usedIds.add(t.id)) result.add(t);
      }
    }

    final highTake = (count * 0.6).ceil();
    var taken = 0;
    for (final t in high) {
      if (taken >= highTake) break;
      if (usedIds.add(t.id)) {
        result.add(t);
        taken++;
      }
    }
    for (final t in low) {
      if (result.length >= count) break;
      if (usedIds.add(t.id)) result.add(t);
    }
    if (result.length < count) addFrom(high);

    _ensureCategoryDiversity(result, usedIds, weights);
    return result;
  }

  /// 保证结果覆盖 >=3 个类别。
  ///
  /// 当结果已满（已达 count）但类别不足时，用缺失类别的未选篇目替换
  /// 出现次数最多的类别条目，逐轮替换直到类别满足或无可替换。
  void _ensureCategoryDiversity(
    List<ShootingTutorial> result,
    Set<String> usedIds,
    Map<String, double> weights,
  ) {
    for (var round = 0; round < 4; round++) {
      final present = result.map((t) => t.category).toSet();
      if (present.length >= 3) return;
      final missing = _kAllCategories.where((c) => !present.contains(c)).toList();
      ShootingTutorial? candidate;
      for (final t in TutorialContent.all) {
        if (missing.contains(t.category) && !usedIds.contains(t.id)) {
          candidate = t;
          break;
        }
      }
      if (candidate == null) return;
      final countPerCat = <String, int>{};
      for (final t in result) {
        countPerCat[t.category] = (countPerCat[t.category] ?? 0) + 1;
      }
      String? mostFreq;
      var maxC = 0;
      for (final e in countPerCat.entries) {
        if (e.value > maxC) {
          maxC = e.value;
          mostFreq = e.key;
        }
      }
      var replaced = false;
      for (var i = 0; i < result.length; i++) {
        if (result[i].category == mostFreq) {
          usedIds.remove(result[i].id);
          usedIds.add(candidate.id);
          result[i] = candidate;
          replaced = true;
          break;
        }
      }
      if (!replaced) return;
    }
  }

  Map<String, double> _buildWeights(
    List<String> favCategories,
    Map<String, int> counts,
  ) {
    final weights = <String, double>{for (final c in _kAllCategories) c: 1.0};
    final top2 = _topCategories(counts, 2);
    final hasSignal = favCategories.isNotEmpty || top2.isNotEmpty;
    if (!hasSignal) {
      weights['general'] = 1.2; // 冷启动人人可读
      return weights;
    }
    for (final c in favCategories) {
      weights[c] = 2.0; // 问卷偏好：有行为时 2，无行为时提升到 3
    }
    for (final c in top2) {
      weights[c] = 3.0; // 行为优先
    }
    if (top2.isEmpty) {
      for (final c in favCategories) {
        weights[c] = 3.0; // 有问卷无拍摄
      }
    }
    return weights;
  }

  List<String> _topCategories(Map<String, int> counts, int n) {
    final entries = counts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(n).map((e) => e.key).toList();
  }

  List<ShootingTutorial> _fallbackEven(int count) {
    final result = <ShootingTutorial>[];
    final used = <String>{};
    var i = 0;
    while (result.length < count && i < TutorialContent.all.length) {
      final t = TutorialContent.all[i];
      if (used.add(t.id)) result.add(t);
      i++;
    }
    _ensureCategoryDiversity(result, used, const {});
    return result;
  }
}