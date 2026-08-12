// lumira_app_flutter/lib/features/templates/recommend/recommendation_models.dart
//
// 推荐引擎输入/输出模型（纯数据，无 Flutter 依赖）。
// 由 recommendation_providers.dart 负责把 DAO 数据转换为信号对象。

import '../../onboarding/data/questionnaire_answers.dart';

/// 后期参数向量（引擎内部使用的轻量表示）
class PostProcessVector {
  const PostProcessVector({
    this.saturation = 0,
    this.temperature = 0,
    this.contrast = 0,
    this.brightness = 0,
  });

  final double saturation;
  final double temperature;
  final double contrast;
  final double brightness;
}

/// 单张照片的行为信号（由 provider 从 GalleryItemRecord 转换）
class PhotoSignal {
  const PhotoSignal({
    required this.createdAt,
    this.templateId,
    this.sceneId,
    this.postProcess,
    this.isFavorite = false,
  });

  /// 毫秒时间戳
  final int createdAt;
  /// 套用的模板 id（可能为 null）
  final String? templateId;
  /// 关联的拍摄场景 id（可能为 null）
  final String? sceneId;
  /// 后期参数（可能为 null）
  final PostProcessVector? postProcess;
  final bool isFavorite;
}

/// 场景元数据信号（由 provider 从 SceneRecord 转换）
class SceneSignal {
  const SceneSignal({
    required this.id,
    this.style = '',
    this.relatedCategory = '',
  });

  final String id;
  final String style;
  final String relatedCategory;
}

/// 候选模板信号（由 provider 从 TemplateRecord 转换）
class TemplateSignal {
  const TemplateSignal({
    required this.id,
    required this.name,
    required this.category,
    this.tags = const [],
    this.tagIds = const [],
    this.classification = const {},
    this.postProcess = const {},
    this.cover = '',
    this.coverData,
    this.price = 0,
    this.updatedAt = 0,
  });

  final String id;
  final String name;
  final String category;
  final List<String> tags;
  final List<String> tagIds;
  final Map<String, dynamic> classification;
  final Map<String, dynamic> postProcess;
  final String cover;
  final String? coverData;
  final int price;
  final int updatedAt;
}

/// 推荐引擎输入汇总
class RecommendationEngineInput {
  const RecommendationEngineInput({
    required this.photos,
    required this.scenes,
    required this.templates,
    required this.ownedTemplateIds,
    this.questionnaire,
    required this.nowMs,
  });

  final List<PhotoSignal> photos;
  final Map<String, SceneSignal> scenes;
  final List<TemplateSignal> templates;
  final Set<String> ownedTemplateIds;
  final QuestionnaireAnswers? questionnaire;
  final int nowMs;
}

/// 推荐结果：单个模板项（页面卡片数据）
class RecommendItem {
  const RecommendItem({
    required this.templateId,
    required this.name,
    required this.category,
    this.cover = '',
    this.coverData,
    this.price = 0,
    this.matchScore = 0,
    this.reason = '',
    this.usedCount = 0,
  });

  final String templateId;
  final String name;
  final String category;
  final String cover;
  final String? coverData;
  final int price;
  /// 匹配度 0..1（展示为百分比）
  final double matchScore;
  /// 卡片副文案
  final String reason;
  /// 历史使用张数（旧爱回归用）
  final int usedCount;
}

/// 风格分析项
class StyleScore {
  const StyleScore({required this.label, required this.percent});

  final String label;
  /// 0..100
  final double percent;
}

/// 最近拍摄信息卡数据
class RecentInfo {
  const RecentInfo({required this.text, required this.sub});

  final String text;
  final String sub;
}

/// 推荐引擎输出：页面 4 个 section 的数据
class RecommendationResult {
  const RecommendationResult({
    required this.coldStart,
    this.styleScores = const [],
    this.guessLikes = const [],
    this.recall = const [],
    this.recentInfo,
    this.recentRelated = const [],
  });

  /// true = 无照片行为数据（冷启动）
  final bool coldStart;
  /// Section 1 风格分析 Top 3
  final List<StyleScore> styleScores;
  /// Section 2 猜你喜欢（已排除 owned+used，按分数降序的完整候选）
  final List<RecommendItem> guessLikes;
  /// Section 3 旧爱回归 Top 4
  final List<RecommendItem> recall;
  /// Section 4 最近拍摄信息（无最近照片或无法推断时为 null）
  final RecentInfo? recentInfo;
  /// Section 4 最近拍摄相关模板 Top 4
  final List<RecommendItem> recentRelated;
}
