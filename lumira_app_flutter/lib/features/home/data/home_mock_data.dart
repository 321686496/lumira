import 'package:flutter/material.dart';

/// 一周打卡日（连续打卡 section）
class WeekDay {
  const WeekDay({
    required this.label,
    required this.done,
    required this.today,
  });

  final String label; // '一' | '二' | ... | '日'
  final bool done;
  final bool today;
}

/// 场景推荐项（场景推荐 section）
class SceneReco {
  const SceneReco({
    required this.id,
    required this.name,
    required this.vibe,
    required this.imageSeed,
    required this.badgeText,
    required this.badgeBrand,
    required this.photoCount,
    this.coverUrl = '',
  });

  final String id;
  final String name;
  final String vibe;
  final String imageSeed; // 不再用于 picsum 兜底；仅保留字段兼容
  final String badgeText;
  final bool badgeBrand;
  final int photoCount;
  /// 真实封面：`data:image/` base64、http(s)、本地文件路径；空串表示无封面
  final String coverUrl;
}

/// 最近拍摄项（最近拍摄 section）
class RecentShot {
  const RecentShot({
    required this.name,
    required this.category,
    required this.icon,
    required this.imageSeed,
    required this.createdAt,
    this.isFavorite = false,
    this.templateId,
    this.sceneId,
    this.imageFilePath,
    this.imageDataUrl,
    this.imageOriginalPath,
  });

  final String name;
  final String category;
  final IconData icon;

  /// 拍摄时间（用于展示相对时间，如"今天"、"昨天"、"N 天前"）
  final DateTime createdAt;

  /// 是否已收藏（卡片右下角展示真实收藏状态）
  final bool isFavorite;

  /// 模板 / 场景 ID（用于"再拍一次"直达对应拍摄流程，可为空则不可复用）
  final String? templateId;
  final String? sceneId;

  /// 真实照片源（优先级：imageFilePath > imageDataUrl > imageOriginalPath > imageSeed fallback）
  /// 三者全空时回退到 imageSeed（picsum 占位）
  final String imageSeed;
  final String? imageFilePath;
  final String? imageDataUrl;
  final String? imageOriginalPath;

  /// 是否有真实照片源
  bool get hasRealImage =>
      (imageFilePath != null && imageFilePath!.isNotEmpty) ||
      (imageDataUrl != null && imageDataUrl!.isNotEmpty) ||
      (imageOriginalPath != null && imageOriginalPath!.isNotEmpty);
}

/// 拍摄小贴士（今日拍摄小贴士 section）
class ShootingTip {
  const ShootingTip({
    required this.text,
    required this.sub,
  });

  final String text;
  final String sub;
}

/// 首页 Banner 项
class HomeBannerItem {
  const HomeBannerItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageSeed,
    required this.tag,
    required this.route,
    this.cover,
    this.coverData,
  });
  final String id;
  final String title;
  final String subtitle;
  final String imageSeed;
  final String tag;
  /// 点击跳转路由（带查询参数）
  final String route;
  /// 模板封面（assets 路径或 http URL），用于模板类 banner 背景图。
  /// 非空时与 [coverData] 一起传给 TemplateCoverImage 渲染背景。
  final String? cover;
  /// 模板封面 base64 data URL（自定义模板场景）。
  final String? coverData;

  /// 是否有模板封面可用
  bool get hasCover =>
      (cover != null && cover!.isNotEmpty) ||
      (coverData != null && coverData!.isNotEmpty);
}

/// 首页 mock 数据
/// 来源：lumira-app/src/pages/home/index.vue 的 weekDays / scenes / recents
/// 以及 lumira-app/src/composables/useShootingTip.ts 的 FALLBACK_TIPS
class HomeMockData {
  HomeMockData._();

  /// 城市定位（顶部导航左侧）
  static const String location = '上海';

  /// 连续打卡天数
  static const int streakDays = 7;

  /// 一周打卡日（一/二/三/四/五/六/日，今天=周日且未完成）
  static const List<WeekDay> weekDays = [
    WeekDay(label: '一', done: true, today: false),
    WeekDay(label: '二', done: true, today: false),
    WeekDay(label: '三', done: true, today: false),
    WeekDay(label: '四', done: true, today: false),
    WeekDay(label: '五', done: true, today: false),
    WeekDay(label: '六', done: true, today: false),
    WeekDay(label: '日', done: false, today: true),
  ];

  /// 今日灵感卡片
  static const String heroDateText = '7月9日 星期二 · 光线极佳';
  static const String heroTitle = '今日灵感';
  static const String heroDesc = '捕捉每一束光，让日常成为习惯';
  static const String heroWeatherText = '17°C 晴 · 黄金时刻 16:30';

  /// 场景推荐（4 个，对齐 home/index.vue 的 scenes computed.slice(0,4)）
  static const List<SceneReco> scenes = [
    SceneReco(
      id: 'preset_cafe',
      name: '咖啡馆',
      vibe: '温暖的午后光线，木质与金属的对比',
      imageSeed: 'scene-home-preset_cafe',
      badgeText: '你最常去',
      badgeBrand: false,
      photoCount: 12,
    ),
    SceneReco(
      id: 'preset_street',
      name: '街头',
      vibe: '都市节奏，光影与人物的瞬间交错',
      imageSeed: 'scene-home-preset_street',
      badgeText: '街头拍摄',
      badgeBrand: false,
      photoCount: 8,
    ),
    SceneReco(
      id: 'preset_park',
      name: '公园',
      vibe: '自然光与树影斑驳，四季变换的色彩',
      imageSeed: 'scene-home-preset_park',
      badgeText: '新场景推荐',
      badgeBrand: true,
      photoCount: 5,
    ),
    SceneReco(
      id: 'preset_studio',
      name: '工作室',
      vibe: '可控光线下的人像与静物创作',
      imageSeed: 'scene-home-preset_studio',
      badgeText: '工作室拍摄',
      badgeBrand: false,
      photoCount: 3,
    ),
  ];

  /// 最近拍摄（5 个，对齐 home/index.vue 的 recents）
  /// 补充真实字段：createdAt 拍摄时间、isFavorite 收藏状态、templateId/sceneId 复用来源
  static final List<RecentShot> recents = [
    RecentShot(
      name: '自然光人像',
      category: '人像',
      icon: Icons.person_outline,
      imageSeed: 'recent-portrait',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      isFavorite: true,
      templateId: 'tpl_natural_portrait',
    ),
    RecentShot(
      name: '复古胶片感',
      category: '胶片',
      icon: Icons.movie_outlined,
      imageSeed: 'recent-film',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      templateId: 'tpl_film_vintage',
    ),
    RecentShot(
      name: '窗边咖啡时光',
      category: '咖啡馆半身',
      icon: Icons.local_cafe_outlined,
      imageSeed: 'recent-cafe',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      sceneId: 'preset_cafe',
    ),
    RecentShot(
      name: '氛围感人像',
      category: '人像氛围',
      icon: Icons.auto_awesome_outlined,
      imageSeed: 'recent-mood',
      createdAt: DateTime.now().subtract(const Duration(days: 6)),
      templateId: 'tpl_mood_portrait',
    ),
    RecentShot(
      name: '黄金时刻风光',
      category: '风光',
      icon: Icons.landscape_outlined,
      imageSeed: 'recent-landscape',
      createdAt: DateTime.now().subtract(const Duration(days: 12)),
      sceneId: 'preset_sunset',
    ),
  ];

  /// 拍摄小贴士候选（对齐 useShootingTip.ts FALLBACK_TIPS）
  static const List<ShootingTip> tips = [
    ShootingTip(
      text: '侧逆光人像：让模特侧向镜头，让自然光从侧面打在脸上，显瘦又自然。',
      sub: '— 适合午后窗边或户外树下',
    ),
    ShootingTip(
      text: '黄金时刻：日出后或日落前 1 小时，光线柔和暖黄，适合拍摄人像与风光。',
      sub: '— 注意提前踩点',
    ),
    ShootingTip(
      text: '三分构图：将主体放在画面九宫格交叉点上，让画面更平衡有张力。',
      sub: '— 适合所有场景',
    ),
    ShootingTip(
      text: '前景遮挡：用花草、树叶、玻璃等作为前景，增加画面层次感。',
      sub: '— 适合静物与人像',
    ),
  ];

  /// 统计数据
  static const int statsFavorites = 12;
  static const String statsLikes = '8.5k';
  static const int statsWorks = 47;

  /// 首页 Banner 列表
  static const List<HomeBannerItem> banners = [
    HomeBannerItem(
      id: 'banner_tpl_scene',
      title: '咖啡馆 × 复古胶片',
      subtitle: '模板与场景搭配，一键出片',
      imageSeed: 'banner-cafe-film',
      tag: '模板+场景',
      route: '/templates/detail?templateId=tpl_film_vintage',
    ),
    HomeBannerItem(
      id: 'banner_inspire',
      title: '黄金时刻拍摄灵感',
      subtitle: '日落前 1 小时，光线柔和暖黄',
      imageSeed: 'banner-golden-hour',
      tag: '拍摄灵感',
      route: '/capture/scene-detail?sceneId=preset_sunset',
    ),
    HomeBannerItem(
      id: 'banner_new_tpl',
      title: '霓虹夜景人像',
      subtitle: '全新模板上架，赛博朋克氛围',
      imageSeed: 'banner-neon-portrait',
      tag: '新模板',
      route: '/templates/detail?templateId=tpl_neon_portrait',
    ),
  ];
}
