import 'dart:math' as math;

import '../../../core/db/dao/templates_dao.dart';

/// 个性化排序上下文（由各入口从画像/热度/问卷/近期展示组装）
class RankingContext {
  /// 画像：'{scope}:{key}' -> score（来自 user_interests）
  final Map<String, double> portrait;
  /// templateId -> 全站热度（use_shoot*2 + open_detail）
  final Map<String, int> popularity;
  /// 用户问卷首选分类
  final Set<String> favoriteCategories;
  /// 近期已在列表展示过的 templateId（降权防重复）
  final Set<String> recentlyShown;
  final int nowMs;

  const RankingContext({
    this.portrait = const {},
    this.popularity = const {},
    this.favoriteCategories = const {},
    this.recentlyShown = const {},
    required this.nowMs,
  });

  double scoreFor(String scope, String key) => portrait['$scope:$key'] ?? 0;
}

/// 单条模板的排序指标
class TemplateScore {
  final TemplateRecord template;
  final double interest;
  final double exploration;
  final double hot;
  final double total;
  const TemplateScore({
    required this.template,
    required this.interest,
    required this.exploration,
    required this.hot,
    required this.total,
  });
}

/// 个性化模板排序器（纯 Dart，可单元测试）。
/// 四级画像权重 + 50/50 熟/新混合；独立新引擎，不与现有 recommendation_engine.dart 混用。
class TemplateRanking {
  // 四级画像内部权重（category/style/subStyle/method，总和 1.0）
  static const double wCategory = 0.40;
  static const double wStyle = 0.20;     // L2：effective（人像 majorStyle，非人像 style）
  static const double wSubStyle = 0.20;  // L3：子风格
  static const double wMethod = 0.20;    // L4：拍摄方式
  // 总分权重
  static const double wInterest = 0.50;
  static const double wExplore = 0.30;
  static const double wHot = 0.15;
  static const double wQuestionnaire = 0.10;
  static const double penaltyRecent = 0.25;

  /// 取 L2 key：majorStyle 优先，为空回退 style（兼容旧数据）。
  static String effectiveL2(TemplateRecord t) {
    final cls = t.classification;
    final maj = cls['majorStyle'];
    if (maj is String && maj.isNotEmpty) return maj;
    final sty = cls['style'];
    return sty is String ? sty : '';
  }

  /// 对每个模板计算 interest（四级画像加权和）
  double interestFor(TemplateRecord t, RankingContext ctx) {
    final cls = t.classification;
    final c = ctx.scoreFor(InterestScope.category, t.category);
    final l2 = effectiveL2(t);
    var relevant = 0.0;
    if (l2.isNotEmpty) {
      var m = ctx.scoreFor(InterestScope.style, l2);
      if (m == 0) m = ctx.scoreFor(InterestScope.majorStyle, l2); // 旧键回退
      relevant += wStyle * m;
    }
    final sub = cls['subStyle'];
    if (sub is String && sub.isNotEmpty) {
      relevant += wSubStyle * ctx.scoreFor(InterestScope.subStyle, sub);
    }
    final method = cls['method'];
    if (method is String && method.isNotEmpty) {
      relevant += wMethod * ctx.scoreFor(InterestScope.method, method);
    }
    return wCategory * c + relevant;
  }

  /// 画像命中阈值：interest 得分超过该值即视为「画像推荐」（用于展示来源/理由）。
  static const double kMatchThreshold = 0.35;

  /// 判断模板是否为画像命中（仅展示用，不影响排序）。
  bool isProfileMatch(TemplateRecord t, RankingContext ctx) {
    return interestFor(t, ctx) >= kMatchThreshold;
  }

  /// 打分全量候选（含归一化与问卷/近期展示加减分）
  List<TemplateScore> scoreAll(List<TemplateRecord> templates, RankingContext ctx) {
    if (templates.isEmpty) return const [];
    var maxInterest = 0.0;
    for (final t in templates) {
      final v = interestFor(t, ctx);
      if (v > maxInterest) maxInterest = v;
    }
    var maxPop = 0;
    for (final t in templates) {
      final p = ctx.popularity[t.id] ?? 0;
      if (p > maxPop) maxPop = p;
    }

    final scores = <TemplateScore>[];
    for (final t in templates) {
      final interest = maxInterest > 0 ? interestFor(t, ctx) / maxInterest : 0.0;
      final exploration = (1.0 - interest).clamp(0.0, 1.0).toDouble();
      final p = ctx.popularity[t.id] ?? 0;
      final hot = maxPop > 0 ? (p / maxPop).clamp(0.0, 1.0).toDouble() : 0.0;
      final q = ctx.favoriteCategories.contains(t.category) ? 1.0 : 0.0;
      final recentPenalty = ctx.recentlyShown.contains(t.id) ? penaltyRecent : 0.0;
      final total =
          (wInterest * interest + wExplore * exploration + wHot * hot + wQuestionnaire * q) -
              recentPenalty;
      scores.add(TemplateScore(
        template: t,
        interest: interest,
        exploration: exploration,
        hot: hot,
        total: total,
      ));
    }
    return scores;
  }

  /// 熟/新 50/50 混合：新鲜 half 与兴趣 half 交替合并（去重后回填）。
  /// 保留探索/兴趣交错顺序，不加总分数全局重排（避免把探索信号挤到末尾）。
  List<TemplateRecord> mixExplore(List<TemplateScore> scores) {
    if (scores.isEmpty) return const [];
    final explore = [...scores]
      ..sort((a, b) => b.exploration.compareTo(a.exploration));
    final exploit = [...scores]
      ..sort((a, b) => b.interest.compareTo(a.interest));
    final half = (scores.length / 2).ceil();
    final a = explore.take(half).toList();
    final b = exploit.take(half).toList();
    final out = <TemplateRecord>[];
    final used = <String>{};
    final len = math.max(a.length, b.length);
    for (var i = 0; i < len; i++) {
      if (i < a.length) {
        final t = a[i].template;
        if (used.add(t.id)) out.add(t);
      }
      if (i < b.length) {
        final t = b[i].template;
        if (used.add(t.id)) out.add(t);
      }
    }
    if (out.length < scores.length) {
      final rest = <TemplateScore>[
        ...explore.skip(half),
        ...exploit.skip(half),
      ];
      for (final s in rest) {
        if (out.length >= scores.length) break;
        if (used.add(s.template.id)) out.add(s.template);
      }
    }
    return out; // 保留探索/兴趣交错顺序，不加总分数全局重排
  }
}

/// 画像维度名（与 InterestService 常量对齐，避免散落魔法字符串）
class InterestScope {
  static const category = 'category';
  static const majorStyle = 'major_style';
  static const style = 'style';
  static const subStyle = 'sub_style';
  static const method = 'method';
}