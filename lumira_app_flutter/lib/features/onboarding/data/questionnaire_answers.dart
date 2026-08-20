import 'dart:convert';

/// 问卷答案不可变模型
///
/// 字段名与后端 JSON key 一致（snake_case），便于直接序列化。
/// 单选题跳过为 null，多选题跳过为空数组。
class QuestionnaireAnswers {
  final String? gender;
  final String? source;
  final List<String> favoriteCategories;
  final List<String> painPoints;
  final String? skillLevel;
  final List<String> expectations;
  final List<String> commonScenes;
  final String? shootFrequency;

  const QuestionnaireAnswers({
    this.gender,
    this.source,
    required this.favoriteCategories,
    required this.painPoints,
    this.skillLevel,
    required this.expectations,
    required this.commonScenes,
    this.shootFrequency,
  });

  /// 全空答案（整体跳过时使用）
  factory QuestionnaireAnswers.empty() => const QuestionnaireAnswers(
        gender: null,
        source: null,
        favoriteCategories: [],
        painPoints: [],
        skillLevel: null,
        expectations: [],
        commonScenes: [],
        shootFrequency: null,
      );

  factory QuestionnaireAnswers.fromJson(Map<String, dynamic> json) {
    return QuestionnaireAnswers(
      gender: json['gender'] as String?,
      source: json['source'] as String?,
      favoriteCategories:
          (json['favorite_categories'] as List<dynamic>?)?.cast<String>() ?? [],
      painPoints: (json['pain_points'] as List<dynamic>?)?.cast<String>() ?? [],
      skillLevel: json['skill_level'] as String?,
      expectations:
          (json['expectations'] as List<dynamic>?)?.cast<String>() ?? [],
      commonScenes:
          (json['common_scenes'] as List<dynamic>?)?.cast<String>() ?? [],
      shootFrequency: json['shoot_frequency'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'gender': gender,
        'source': source,
        'favorite_categories': favoriteCategories,
        'pain_points': painPoints,
        'skill_level': skillLevel,
        'expectations': expectations,
        'common_scenes': commonScenes,
        'shoot_frequency': shootFrequency,
      };

  String toJsonString() => jsonEncode(toJson());

  /// 是否完全未填写（所有题都跳过）
  bool get isAllSkipped =>
      gender == null &&
      source == null &&
      favoriteCategories.isEmpty &&
      painPoints.isEmpty &&
      skillLevel == null &&
      expectations.isEmpty &&
      commonScenes.isEmpty &&
      shootFrequency == null;
}
