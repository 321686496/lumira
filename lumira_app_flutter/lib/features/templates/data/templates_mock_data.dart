/// 模板推荐来源类型
enum TemplateSource {
  /// 最近使用
  recentUsed,
  /// 场景匹配
  sceneMatch,
  /// 同分类
  categoryMatch,
  /// 系统精选
  systemPick,
}

/// 模板推荐项（Hero 推荐区）
class TemplateRecommendation {
  const TemplateRecommendation({
    required this.id,
    required this.name,
    required this.reason,
    required this.source,
    required this.imageSeed,
    required this.category,
    this.cover,
    this.coverData,
  });

  final String id;
  final String name;
  final String reason;
  final TemplateSource source;
  final String imageSeed; // picsum seed
  final String category; // 'portrait' / 'landscape' / ... 原始值
  /// 内置模板 assets 路径或远程模板 http URL
  final String? cover;
  /// 自定义模板 base64 data URL
  final String? coverData;
}

/// 模板卡片项（更多模板 section）
class TemplateItem {
  const TemplateItem({
    required this.id,
    required this.name,
    required this.category,
    required this.imageSeed,
    required this.price,
    this.cover,
    this.coverData,
  });

  final String id;
  final String name;
  final String category;
  final String imageSeed;
  final int price; // 0 = 免费
  /// 内置模板 assets 路径或远程模板 http URL
  final String? cover;
  /// 自定义模板 base64 data URL
  final String? coverData;
}

/// 用户拍摄偏好（仅有照片时显示）
class UserPreference {
  const UserPreference({
    required this.totalPhotos,
    required this.topCategory,
    required this.topCategoryPercentage,
  });

  final int totalPhotos;
  final String topCategory; // 'portrait' / ...
  final int topCategoryPercentage;
}

/// 模板页 mock 数据
/// 来源：lumira-app/src/pages/templates/index.vue 的 recommendations / otherTemplates / userPreference
/// 以及 lumira-app/src/composables/useRecommendation.ts 的 mock 示例
class TemplatesMockData {
  TemplatesMockData._();

  /// 今日推荐（4 项，不同来源）
  static const List<TemplateRecommendation> recommendations = [
    TemplateRecommendation(
      id: 'soft_portrait',
      name: '柔光人像',
      reason: '你最近经常使用此模板（5 次）',
      source: TemplateSource.recentUsed,
      imageSeed: 'tpl-soft-portrait',
      category: 'portrait',
    ),
    TemplateRecommendation(
      id: 'golden_landscape',
      name: '金色风光',
      reason: '匹配当前日落场景',
      source: TemplateSource.sceneMatch,
      imageSeed: 'tpl-golden-landscape',
      category: 'landscape',
    ),
    TemplateRecommendation(
      id: 'food_flat_lay',
      name: '美食俯拍',
      reason: '同分类热门模板',
      source: TemplateSource.categoryMatch,
      imageSeed: 'tpl-food-flat-lay',
      category: 'food',
    ),
    TemplateRecommendation(
      id: 'night_cityscape',
      name: '夜景城市',
      reason: '系统精选：适合当前时段',
      source: TemplateSource.systemPick,
      imageSeed: 'tpl-night-cityscape',
      category: 'night',
    ),
  ];

  /// 更多模板（6 项，部分免费）
  static const List<TemplateItem> otherTemplates = [
    TemplateItem(
      id: 'street_bw',
      name: '街拍黑白',
      category: 'street',
      imageSeed: 'tpl-street-bw',
      price: 0,
    ),
    TemplateItem(
      id: 'macro_flower',
      name: '微距花卉',
      category: 'macro',
      imageSeed: 'tpl-macro-flower',
      price: 0,
    ),
    TemplateItem(
      id: 'still_life_warm',
      name: '静物暖光',
      category: 'still-life',
      imageSeed: 'tpl-still-life-warm',
      price: 12,
    ),
    TemplateItem(
      id: 'portrait_bokeh',
      name: '人像散景',
      category: 'portrait',
      imageSeed: 'tpl-portrait-bokeh',
      price: 0,
    ),
    TemplateItem(
      id: 'landscape_panorama',
      name: '全景风光',
      category: 'landscape',
      imageSeed: 'tpl-landscape-panorama',
      price: 18,
    ),
    TemplateItem(
      id: 'night_neon',
      name: '霓虹夜景',
      category: 'night',
      imageSeed: 'tpl-night-neon',
      price: 24,
    ),
  ];

  /// 用户拍摄偏好（模拟数据，totalPhotos > 0 触发显示）
  static const UserPreference userPreference = UserPreference(
    totalPhotos: 24,
    topCategory: 'portrait',
    topCategoryPercentage: 42,
  );

  /// 分类中文标签
  /// 来源：lumira-app/src/pages/templates/index.vue 的 categoryLabelMap
  static String categoryLabel(String category) {
    const map = {
      'portrait': '人像',
      'landscape': '风光',
      'food': '美食',
      'night': '夜景',
      'street': '街拍',
      'macro': '微距',
      'still-life': '静物',
    };
    return map[category] ?? category;
  }

  /// 推荐来源中文标签
  /// 来源：lumira-app/src/pages/templates/index.vue 的 sourceLabel
  static String sourceLabel(TemplateSource source) {
    switch (source) {
      case TemplateSource.recentUsed:
        return '最近使用';
      case TemplateSource.sceneMatch:
        return '场景匹配';
      case TemplateSource.categoryMatch:
        return '同分类';
      case TemplateSource.systemPick:
        return '系统精选';
    }
  }
}
