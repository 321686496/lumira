// lumira_app_flutter/lib/features/templates/recommend/recommendation_engine.dart
//
// 纯本地模板推荐引擎（无 Flutter / 数据库依赖，可单元测试）。
//
// 算法（spec 2026-08-12 第 4 节）：
// - 画像聚合：照片按时间衰减加权（半衰期 30 天）
// - 打分：category 0.35 / tag 0.30 / style 0.20 / postProcess 0.15
// - 排除：已拥有 + 已用过
// - 旧召回：>30 天前用过 + 匹配分 >= 0.3
// - 冷启动：问卷偏好 / 分类多样性

import 'dart:math' as math;

import 'recommendation_models.dart';

/// 用户偏好画像
class UserProfile {
  const UserProfile({
    required this.photoCount,
    required this.categoryWeights,
    required this.styleWeights,
    required this.tagWeights,
    required this.avgPost,
    required this.usedTemplateCounts,
    required this.lastUsedTemplateAt,
  });

  final int photoCount;
  final Map<String, double> categoryWeights;
  final Map<String, double> styleWeights;
  final Map<String, double> tagWeights;
  final PostProcessVector avgPost;
  /// templateId -> 照片张数
  final Map<String, int> usedTemplateCounts;
  /// templateId -> 最近一次使用时间（ms）
  final Map<String, int> lastUsedTemplateAt;

  bool get isEmpty => photoCount == 0;
}

class RecommendationEngine {
  /// 时间衰减半衰期（天）
  static const double kHalfLifeDays = 30;
  /// 旧召回匹配分阈值
  static const double kRecallThreshold = 0.3;
  /// 旧召回：最近使用距今超过该天数判定为"很久之前"
  static const int kRecallGapDays = 30;
  /// 打分权重
  static const double wCategory = 0.35;
  static const double wTag = 0.30;
  static const double wStyle = 0.20;
  static const double wPost = 0.15;

  /// 构建用户偏好画像
  UserProfile buildProfile(RecommendationEngineInput input) {
    final now = input.nowMs;
    final halfLifeMs = kHalfLifeDays * 24 * 3600 * 1000.0;
    final templateById = <String, TemplateSignal>{
      for (final t in input.templates) t.id: t,
    };

    final category = <String, double>{};
    final style = <String, double>{};
    final tag = <String, double>{};
    var sumSat = 0.0, sumTemp = 0.0, sumContrast = 0.0, sumBright = 0.0;
    var postCount = 0;
    final usedCounts = <String, int>{};
    final lastUsed = <String, int>{};

    for (final p in input.photos) {
      final ageMs = (now - p.createdAt).abs();
      final w = math.exp(-ageMs / halfLifeMs);

      // 场景 -> 分类 / 风格
      final scene = p.sceneId != null ? input.scenes[p.sceneId] : null;
      if (scene != null) {
        if (scene.relatedCategory.isNotEmpty) {
          category[scene.relatedCategory] =
              (category[scene.relatedCategory] ?? 0) + w;
        }
        if (scene.style.isNotEmpty) {
          style[scene.style] = (style[scene.style] ?? 0) + w;
        }
      }

      // 套用模板 -> 分类 / 标签 / 使用计数
      final tpl = p.templateId != null ? templateById[p.templateId] : null;
      if (tpl != null) {
        if (tpl.category.isNotEmpty) {
          category[tpl.category] = (category[tpl.category] ?? 0) + w;
        }
        for (final tagId in tpl.tagIds) {
          tag[tagId] = (tag[tagId] ?? 0) + w;
        }
        usedCounts[p.templateId!] = (usedCounts[p.templateId!] ?? 0) + 1;
        final last = lastUsed[p.templateId!];
        if (last == null || p.createdAt > last) {
          lastUsed[p.templateId!] = p.createdAt;
        }
      }

      // 后期参数均值
      final post = p.postProcess;
      if (post != null) {
        sumSat += post.saturation;
        sumTemp += post.temperature;
        sumContrast += post.contrast;
        sumBright += post.brightness;
        postCount++;
      }
    }

    return UserProfile(
      photoCount: input.photos.length,
      categoryWeights: category,
      styleWeights: style,
      tagWeights: tag,
      avgPost: postCount == 0
          ? const PostProcessVector()
          : PostProcessVector(
              saturation: sumSat / postCount,
              temperature: sumTemp / postCount,
              contrast: sumContrast / postCount,
              brightness: sumBright / postCount,
            ),
      usedTemplateCounts: usedCounts,
      lastUsedTemplateAt: lastUsed,
    );
  }

  /// 对候选模板打分排序（排除已拥有与已用过）
  List<RecommendItem> rankCandidates(
    UserProfile profile,
    List<TemplateSignal> candidates,
    RecommendationEngineInput input,
  ) {
    final used = profile.usedTemplateCounts.keys.toSet();
    final owned = input.ownedTemplateIds;

    final maxCategory = _maxOr1(profile.categoryWeights);
    final maxStyle = _maxOr1(profile.styleWeights);
    final tagTotal = profile.tagWeights.values.fold(0.0, (a, b) => a + b);

    final scored = <RecommendItem>[];
    for (final t in candidates) {
      if (owned.contains(t.id) || used.contains(t.id)) continue;

      final categorySim = maxCategory > 0
          ? ((profile.categoryWeights[t.category] ?? 0) / maxCategory)
              .clamp(0.0, 1.0)
          : 0.0;

      double tagSim = 0.0;
      if (tagTotal > 0) {
        for (final tagId in t.tagIds) {
          tagSim += profile.tagWeights[tagId] ?? 0;
        }
        tagSim = (tagSim / tagTotal).clamp(0.0, 1.0);
      }

      final tplStyle = t.classification['style'];
      double styleSim = 0.0;
      if (maxStyle > 0 && tplStyle is String && tplStyle.isNotEmpty) {
        styleSim =
            ((profile.styleWeights[tplStyle] ?? 0) / maxStyle).clamp(0.0, 1.0);
      }

      final postSim = _cosinePost(profile.avgPost, _templatePost(t.postProcess));

      final score = (wCategory * categorySim +
              wTag * tagSim +
              wStyle * styleSim +
              wPost * postSim)
          .clamp(0.0, 1.0);

      scored.add(RecommendItem(
        templateId: t.id,
        name: t.name,
        category: t.category,
        cover: t.cover,
        coverData: t.coverData,
        price: t.price,
        matchScore: score,
        reason: _guessReason(categorySim, tagSim, styleSim, postSim),
      ));
    }

    scored.sort((a, b) => b.matchScore.compareTo(a.matchScore));
    return scored;
  }

  /// 主入口：画像 -> 过滤 -> 打分 -> 旧召回 -> 最近拍摄 / 冷启动
  RecommendationResult build(RecommendationEngineInput input) {
    final profile = buildProfile(input);
    if (profile.isEmpty) {
      return _buildColdStart(input);
    }
    final used = profile.usedTemplateCounts.keys.toSet();
    final candidates = input.templates
        .where((t) =>
            !input.ownedTemplateIds.contains(t.id) && !used.contains(t.id))
        .toList();
    final ranked = rankCandidates(profile, candidates, input);
    return RecommendationResult(
      coldStart: false,
      styleScores: _topStyles(profile),
      guessLikes: ranked,
      recall: _buildRecall(profile, input),
      recentInfo: _buildRecentInfo(profile, input),
      recentRelated: _buildRecentRelated(profile, input, ranked),
    );
  }

  // ===== 私有辅助 =====

  /// 冷启动（Task 2 完善：问卷偏好 / 分类多样性）
  RecommendationResult _buildColdStart(RecommendationEngineInput input) {
    final owned = input.ownedTemplateIds;
    final pool = input.templates
        .where((t) => !owned.contains(t.id))
        .toList();
    final picked = pool.take(8).toList();
    return RecommendationResult(
      coldStart: true,
      guessLikes: picked
          .map((t) => RecommendItem(
                templateId: t.id,
                name: t.name,
                category: t.category,
                cover: t.cover,
                coverData: t.coverData,
                price: t.price,
              ))
          .toList(),
    );
  }

  /// 风格分析 Top 3（按权重占比）
  List<StyleScore> _topStyles(UserProfile profile) {
    final entries = profile.styleWeights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = profile.styleWeights.values.fold(0.0, (a, b) => a + b);
    if (total <= 0) return const [];
    return entries.take(3).map((e) {
      final pct = (e.value / total * 100).clamp(0.0, 100.0);
      return StyleScore(label: e.key, percent: pct);
    }).toList();
  }

  /// 旧爱回归（Task 2 实现）
  List<RecommendItem> _buildRecall(
      UserProfile profile, RecommendationEngineInput input) {
    return const [];
  }

  /// 最近拍摄信息（Task 2 实现）
  RecentInfo? _buildRecentInfo(
      UserProfile profile, RecommendationEngineInput input) {
    return null;
  }

  /// 最近拍摄相关模板（Task 2 实现）
  List<RecommendItem> _buildRecentRelated(UserProfile profile,
      RecommendationEngineInput input, List<RecommendItem> ranked) {
    return const [];
  }

  static double _maxOr1(Map<String, double> m) {
    var max = 0.0;
    for (final v in m.values) {
      if (v > max) max = v;
    }
    return max <= 0 ? 1 : max;
  }

  static PostProcessVector _templatePost(Map<String, dynamic> pp) {
    // 注：局部函数名不能用 `num`，会遮蔽核心类型 num 导致编译错误，故命名为 toNum
    double toNum(String k) => (pp[k] as num?)?.toDouble() ?? 0;
    return PostProcessVector(
      saturation: toNum('saturation'),
      temperature: toNum('temperature'),
      contrast: toNum('contrast'),
      brightness: toNum('brightness'),
    );
  }

  /// 余弦相似度（映射到 0..1）
  static double _cosinePost(PostProcessVector a, PostProcessVector b) {
    final dot = a.saturation * b.saturation +
        a.temperature * b.temperature +
        a.contrast * b.contrast +
        a.brightness * b.brightness;
    final na = math.sqrt(a.saturation * a.saturation +
        a.temperature * a.temperature +
        a.contrast * a.contrast +
        a.brightness * a.brightness);
    final nb = math.sqrt(b.saturation * b.saturation +
        b.temperature * b.temperature +
        b.contrast * b.contrast +
        b.brightness * b.brightness);
    if (na == 0 || nb == 0) return 0;
    return ((dot / (na * nb)) + 1) / 2;
  }

  static String _guessReason(
      double categorySim, double tagSim, double styleSim, double postSim) {
    if (categorySim > 0.4) return '匹配你常拍的分类';
    if (tagSim > 0.4) return '与你常用模板风格相近';
    if (styleSim > 0.4) return '匹配你喜欢的拍摄风格';
    return '为你精选的模板';
  }
}
