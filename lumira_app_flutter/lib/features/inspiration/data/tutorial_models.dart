/// 拍摄小课堂数据模型（纯本地 const，无网络）
enum TutorialCtaType { scene, template }

/// 结尾动作：去拍场景 或 去模板
class TutorialCta {
  final TutorialCtaType type;
  final String targetId;

  const TutorialCta({required this.type, required this.targetId});
}

/// 教程步骤块（部分带 1 张对比图）
class TutorialStep {
  final String title;
  final String body;
  final String? imageAsset;

  const TutorialStep({required this.title, required this.body, this.imageAsset});
}

/// 单篇拍摄小教程
class ShootingTutorial {
  final String id;
  final String title;
  final String subtitle;
  final String coverImage;
  final String category; // general/portrait/landscape/food/street/night/macro/still-life
  final String readMinutes;
  final List<String> tags;
  final String intro;
  final List<TutorialStep> steps;
  final List<String> tips;
  final TutorialCta cta;
  final String? academyCourseId; // 关联美学院课程（导流）

  const ShootingTutorial({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.coverImage,
    required this.category,
    required this.readMinutes,
    this.tags = const [],
    required this.intro,
    this.steps = const [],
    this.tips = const [],
    required this.cta,
    this.academyCourseId,
  });
}