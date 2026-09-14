import 'dart:math' as math;

/// 每日推荐批次项。
class DailyRecommendation {
  const DailyRecommendation({required this.rank, required this.templateId});
  final int rank;
  final String templateId;
}

/// 纯函数：把已排序的推荐池按「日期种子」做稳定轮换并封顶到 cap。
///
/// - 同一天：相同输入给出完全相同批次（确定性，避免同一天反复抖动）；
/// - 跨天：种子变 → 轮换起点变 → 当天批次不同，体现「今日」；
/// - cap：控制该栏展示数量（防信息过载 / 后台灌太多模板导致滑不完）。
///
/// 说明：轮换只改变顺序，不增减命中；模板是否"今日出现在该栏"由上层已按
/// 画像/热度/问卷打分决定。此函数仅提供稳定轮换 + 封顶两个职责。
class DailyRecommendator {
  const DailyRecommendator();

  List<DailyRecommendation> build(
    List<String> templateIds,
    DateTime date, {
    int cap = 10,
  }) {
    if (templateIds.isEmpty) return const [];
    final capN = cap.clamp(1, templateIds.length);
    final seed = date.year * 10000 + date.month * 100 + date.day;
    final rnd = math.Random(seed);
    final idx = List.generate(templateIds.length, (i) => i);
    // Fisher–Yates，以日期为种子，保证确定性
    for (var i = idx.length - 1; i > 0; i--) {
      final j = rnd.nextInt(i + 1);
      final tmp = idx[i];
      idx[i] = idx[j];
      idx[j] = tmp;
    }
    final out = <DailyRecommendation>[];
    for (var r = 0; r < capN; r++) {
      out.add(DailyRecommendation(rank: r, templateId: templateIds[idx[r]]));
    }
    return out;
  }
}