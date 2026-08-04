import 'package:flutter/material.dart';

import '../domain/scene_preset.dart';
import '../domain/photo_template.dart' show SceneGuide;

// Re-export 统一类型定义，使用方 import 本文件仍能访问这些类型
export '../domain/scene_preset.dart'
    show
        SceneCategory,
        Target,
        SceneStyle,
        SceneCategoryGroup,
        SceneFilter,
        ScenePreset,
        CustomScenePreset,
        SceneAchievement,
        SceneRankingEntry,
        SceneTag,
        ShootKit,
        LutOption,
        SystemFilterOption;
// SceneGuide 定义在 photo_template.dart，re-export 以维持使用方对 SceneGuide 的访问
export '../domain/photo_template.dart' show SceneGuide;

/// Capture 场景子页 mock 数据（Task 2.10）
///
/// 数据来源：lumira-app/src/data/scenePresets.ts 与 lumira-app/src/composables/useSceneManager.ts
/// - 6 个预设场景（与 SCENE_PRESETS 子集一致，覆盖 4 个大类）
/// - 4 个大类（与 SCENE_CATEGORIES 一致）
/// - 7 个标签
/// - 10 个 LUT 选项
/// - 5 个系统滤镜选项
///
/// 类型定义已统一至 lib/features/capture/domain/scene_preset.dart（版本 A：字符串常量）。
/// - SceneCategory / Target：字符串常量（非 enum）
/// - ScenePreset.icon：String（'ph-xxx' phosphor 图标名，非 IconData）
/// - ScenePreset.category / relatedCategory：String（字符串常量）
/// - SceneGuide：使用 photo_template.dart 中的版本（含扩展字段 lightDirectionAngle/shootingDistanceM/bestTimeFrom/bestTimeTo）
class CaptureSceneMockData {
  CaptureSceneMockData._();

  // ===== 场景大类 =====
  static const List<SceneCategoryGroup> categories = [
    SceneCategoryGroup(
      category: SceneCategory.light,
      name: '光线氛围',
      icon: 'ph-sun',
      styles: [
        SceneStyle(id: 'window-light', name: '窗光', category: SceneCategory.light),
        SceneStyle(id: 'sunset-backlight', name: '日落逆光', category: SceneCategory.light),
        SceneStyle(id: 'neon', name: '霓虹', category: SceneCategory.light),
        SceneStyle(id: 'candle', name: '烛光', category: SceneCategory.light),
      ],
    ),
    SceneCategoryGroup(
      category: SceneCategory.outdoor,
      name: '室外环境',
      icon: 'ph-mountains',
      styles: [
        SceneStyle(id: 'seaside', name: '海边', category: SceneCategory.outdoor),
        SceneStyle(id: 'forest', name: '森林', category: SceneCategory.outdoor),
        SceneStyle(id: 'urban', name: '城市', category: SceneCategory.outdoor),
      ],
    ),
    SceneCategoryGroup(
      category: SceneCategory.indoor,
      name: '室内空间',
      icon: 'ph-house',
      styles: [
        SceneStyle(id: 'home', name: '居家', category: SceneCategory.indoor),
        SceneStyle(id: 'cafe', name: '咖啡馆店铺', category: SceneCategory.indoor),
        SceneStyle(id: 'studio', name: '影棚', category: SceneCategory.indoor),
      ],
    ),
    SceneCategoryGroup(
      category: SceneCategory.mood,
      name: '情绪氛围',
      icon: 'ph-heart',
      styles: [
        SceneStyle(id: 'healing', name: '治愈', category: SceneCategory.mood),
        SceneStyle(id: 'lonely', name: '孤独', category: SceneCategory.mood),
      ],
    ),
  ];

  // ===== 预设场景（mock：6 个覆盖 4 大类，源数据为 18 个） =====
  // sceneGuide 扩展字段（lightDirectionAngle/shootingDistanceM/bestTimeFrom/bestTimeTo）
  // 对齐 lib/features/capture/data/scene_presets_data.dart 中同 id 场景。
  static const List<ScenePreset> presetScenes = [
    ScenePreset(
      id: 'cafe-window',
      name: '咖啡馆',
      icon: 'ph-coffee',
      category: SceneCategory.indoor,
      style: 'cafe',
      filter: SceneFilter(
        lut: 'warm_film',
        systemFilter: 'vivid_warm',
        reason: '色温偏暖 +20，对比度 +10，像被午后的光晒软了',
      ),
      vibe: '慵懒午后，把光调成蜜糖色',
      description: '适合下午 2-5 点，当阳光斜照进落地窗，整个世界都慢了下来。咖啡馆的木质桌椅、暖色墙面和飘散的咖啡香，构成最治愈的拍摄空间。',
      exampleImages: [
        'https://picsum.photos/seed/scene-cafe-window-1/600/800',
        'https://picsum.photos/seed/scene-cafe-window-2/600/800',
        'https://picsum.photos/seed/scene-cafe-window-3/600/800',
      ],
      tips: [
        '让模特面朝窗户，利用柔光均匀照亮面部',
        '大光圈虚化背景，突出人物',
        '咖啡杯做前景更有氛围感',
      ],
      whereToShoot: '咖啡馆 / 图书馆 / 居家窗边',
      bestTime: '下午 14:00-17:00',
      sceneGuide: SceneGuide(
        lightDirection: '侧光 45°-90°（窗户自然光为主光源）',
        shootingDistance: '1.5-2.5m',
        background: '咖啡馆室内环境，虚化的吧台、书架或暖色墙面',
        props: ['咖啡杯', '书本', '绿植盆栽'],
        bestTime: '下午 14:00-17:00',
        tips: ['让模特面朝窗户', '大光圈虚化背景', '咖啡杯做前景'],
        lightDirectionAngle: 90,
        shootingDistanceM: 2,
        bestTimeFrom: '14:00',
        bestTimeTo: '17:00',
      ),
      relatedCategory: Target.portrait,
    ),
    ScenePreset(
      id: 'sunset-silhouette',
      name: '黄昏剪影',
      icon: 'ph-sunset',
      category: SceneCategory.light,
      style: 'sunset-backlight',
      filter: SceneFilter(
        lut: 'cinematic',
        reason: '宽容差 + 暖调，把天空压成电影感',
      ),
      vibe: '把人放进夕阳里，剪成一帧诗',
      description: '适合日落前后 30 分钟，逆光下的人物轮廓被金色光线勾勒。天空的晚霞和地平线，是这张照片最壮阔的舞台。',
      exampleImages: [
        'https://picsum.photos/seed/scene-sunset-silhouette-1/600/800',
        'https://picsum.photos/seed/scene-sunset-silhouette-2/600/800',
      ],
      tips: [
        '对天空测光锁定，拍摄人物剪影',
        '利用前景增加画面纵深感',
        '黄金时刻色温最暖，抓紧时间',
      ],
      whereToShoot: '海边 / 山顶 / 城市天台',
      bestTime: '黄昏 17:30-19:00（日落前后 30 分钟）',
      sceneGuide: SceneGuide(
        lightDirection: '逆光（太阳位于主体正后方）',
        shootingDistance: '3-8m 剪影或半身',
        background: '落日、晚霞、地平线、剪影前景',
        props: ['草帽', '气球', '雨伞'],
        bestTime: '黄昏 17:30-19:00',
        tips: ['对天空测光锁定', '利用前景增加纵深', '黄金时刻色温最暖'],
        lightDirectionAngle: 180,
        shootingDistanceM: 5,
        bestTimeFrom: '17:30',
        bestTimeTo: '19:00',
      ),
      relatedCategory: Target.portrait,
    ),
    ScenePreset(
      id: 'night-street',
      name: '霓虹街角',
      icon: 'ph-moon-stars',
      category: SceneCategory.light,
      style: 'neon',
      filter: SceneFilter(
        lut: 'cyberpunk',
        reason: '高饱和蓝紫对比 + 暗部品红，赛博味拉满',
      ),
      vibe: '赛博夜行，让霓虹流过脸颊',
      description: '适合夜晚 19:00 后，城市的霓虹招牌、车流光轨和橱窗灯箱，是天然的赛博朋克布景。潮湿的柏油路反光更是绝佳镜面。',
      exampleImages: [
        'https://picsum.photos/seed/scene-night-street-1/600/800',
      ],
      tips: [
        '寻找霓虹招牌做轮廓光或发丝光',
        '雨后路面反光增加色彩层次',
        '注意快门速度避免手抖',
      ],
      whereToShoot: '商业街 / 霓虹招牌密集街区 / 地下通道',
      bestTime: '夜晚 19:00-23:00',
      sceneGuide: SceneGuide(
        lightDirection: '利用环境光源（霓虹灯、路灯、橱窗灯）',
        shootingDistance: '2-4m 人像',
        background: '霓虹招牌、车流光轨、城市天际线',
        props: ['透明雨伞', '反光镜面', '发光道具'],
        bestTime: '夜晚 19:00-23:00',
        tips: ['霓虹招牌做轮廓光', '雨后路面反光增色', '注意快门速度避免手抖'],
        lightDirectionAngle: 180,
        shootingDistanceM: 3,
        bestTimeFrom: '19:00',
        bestTimeTo: '23:00',
      ),
      relatedCategory: Target.night,
    ),
    ScenePreset(
      id: 'seaside-beach',
      name: '海边沙滩',
      icon: 'ph-waves',
      category: SceneCategory.outdoor,
      style: 'seaside',
      filter: SceneFilter(
        lut: 'pastel',
        reason: '低饱和 + 提亮，像被海水冲淡的颜色',
      ),
      vibe: '海风咸甜，把云朵调成棉花糖',
      description: '适合日出或日落前后的黄金时刻，开阔的海平面和柔软的沙滩是最好的画布。海风吹动发丝和裙摆，是清新自然风的最佳拍摄场景。',
      exampleImages: [
        'https://picsum.photos/seed/scene-seaside-beach-1/600/800',
        'https://picsum.photos/seed/scene-seaside-beach-2/600/800',
      ],
      tips: [
        '利用海风让头发飘动增加动感',
        '低角度拍摄拉长身形，融入海平面',
        '注意镜头防沙防水',
      ],
      whereToShoot: '海边 / 沙滩 / 海岛',
      bestTime: '黄金时刻 06:00-08:00 或 17:00-19:00',
      sceneGuide: SceneGuide(
        lightDirection: '顺光或侧光（避免正午顶光）',
        shootingDistance: '2-5m 半身至全身',
        background: '海平面、沙滩、礁石、天空',
        props: ['草帽', '丝巾', '沙滩裙'],
        bestTime: '黄金时刻 06:00-08:00 或 17:00-19:00',
        tips: ['海风让头发飘动', '低角度拉长身形', '注意镜头防沙防水'],
        lightDirectionAngle: 45,
        shootingDistanceM: 3,
        bestTimeFrom: '17:00',
        bestTimeTo: '19:00',
      ),
      relatedCategory: Target.landscape,
    ),
    ScenePreset(
      id: 'forest-bamboo',
      name: '竹海禅意',
      icon: 'ph-tree',
      category: SceneCategory.outdoor,
      style: 'forest',
      filter: SceneFilter(
        lut: 'fuji',
        reason: '青绿调 + 微反差，像被竹林过滤过的光',
      ),
      vibe: '竹影斑驳，把光调成一片青玉',
      description: '适合上午 8-11 点，光线透过竹叶形成丁达尔效应。深绿的竹林与飘动的雾气，是禅意照片的最佳布景。',
      exampleImages: [
        'https://picsum.photos/seed/scene-forest-bamboo-1/600/800',
      ],
      tips: [
        '寻找光线穿透竹叶的光斑',
        '低角度仰拍突出竹林高度',
        '利用雾气增加层次感',
      ],
      whereToShoot: '竹林 / 植物园 / 山间小径',
      bestTime: '上午 08:00-11:00 光线通透',
      sceneGuide: SceneGuide(
        lightDirection: '侧光或顶光穿透竹叶（丁达尔效应）',
        shootingDistance: '2-5m 人像或环境',
        background: '竹林、竹叶、林间小径、雾气',
        props: ['油纸伞', '竹篮', '汉服'],
        bestTime: '上午 08:00-11:00',
        tips: ['寻找光斑穿透竹叶', '低角度仰拍竹林', '利用雾气增加层次'],
        lightDirectionAngle: 90,
        shootingDistanceM: 3,
        bestTimeFrom: '08:00',
        bestTimeTo: '11:00',
      ),
      relatedCategory: Target.landscape,
    ),
    ScenePreset(
      id: 'rainy-window',
      name: '雨窗静思',
      icon: 'ph-drop',
      category: SceneCategory.mood,
      style: 'healing',
      filter: SceneFilter(
        lut: 'mist',
        reason: '低对比 + 灰蓝调，像被雨水稀释过的世界',
      ),
      vibe: '听雨落窗，把心放慢半拍',
      description: '适合雨天，窗外的雨滴在玻璃上形成水珠，模糊的世界透着宁静。一杯热茶、一本旧书、模糊的窗外，是治愈系照片最经典的画面。',
      exampleImages: [
        'https://picsum.photos/seed/scene-rainy-window-1/600/800',
      ],
      tips: [
        '对焦在玻璃水珠上，让窗外虚化',
        '利用窗外的色彩透过滤镜',
        '加入热饮或书本，增加治愈感',
      ],
      whereToShoot: '家中窗边 / 咖啡馆 / 车内',
      bestTime: '雨天全天',
      sceneGuide: SceneGuide(
        lightDirection: '漫射光（雨天自然光）',
        shootingDistance: '20-80cm 玻璃水珠特写',
        background: '雨窗、模糊街景、室内暖光',
        props: ['热茶杯', '旧书', '绿植', '毛毯'],
        bestTime: '雨天全天',
        tips: ['对焦玻璃水珠虚化窗外', '利用窗外色彩透过滤镜', '加入热饮或书本'],
        lightDirectionAngle: 90,
        shootingDistanceM: 0.3,
        bestTimeFrom: '08:00',
        bestTimeTo: '18:00',
      ),
      relatedCategory: Target.stillLife,
    ),
  ];

  // ===== 自定义场景（mock：1 个，演示 custom_ 前缀） =====
  static const CustomScenePreset customSceneExample = CustomScenePreset(
    id: 'custom_demo_001',
    name: '我的咖啡馆',
    icon: 'ph-coffee',
    category: SceneCategory.indoor,
    style: 'cafe',
    filter: SceneFilter(
      lut: 'warm_film',
      reason: '自定义暖调',
    ),
    vibe: '自定义情绪',
    description: '用户自定义场景描述',
    exampleImages: [
      'https://picsum.photos/seed/scene-custom-demo-1/600/800',
    ],
    tips: ['自定义贴士 1', '自定义贴士 2'],
    whereToShoot: '自定义地点',
    bestTime: '自定义时间',
    sceneGuide: SceneGuide(
      lightDirection: '侧光',
      shootingDistance: '1-2m',
      background: '简洁背景',
      props: ['咖啡杯'],
      bestTime: '全天',
      tips: ['侧光', '虚化背景'],
    ),
    relatedCategory: Target.portrait,
    tagIds: ['tag_cafe', 'tag_warm'],
    createdAt: 1717000000000,
    updatedAt: 1717000000000,
  );

  /// 所有场景（自定义 + 预设） — 对应 uni-app allScenes
  static List<ScenePreset> get allScenes =>
      [customSceneExample, ...presetScenes];

  // ===== 收藏（mock：1 个） =====
  static const List<String> favoritePresetIds = ['cafe-window'];

  /// 收藏场景列表 — 对应 uni-app favoriteScenes
  static List<ScenePreset> get favoriteScenes => presetScenes
      .where((p) => favoritePresetIds.contains(p.id))
      .toList();

  // ===== 标签 =====
  static const List<SceneTag> tags = [
    SceneTag(id: 'tag_warm', name: '暖调'),
    SceneTag(id: 'tag_cafe', name: '咖啡馆'),
    SceneTag(id: 'tag_portrait', name: '人像'),
    SceneTag(id: 'tag_night', name: '夜景'),
    SceneTag(id: 'tag_outdoor', name: '户外'),
    SceneTag(id: 'tag_soft', name: '柔光'),
    SceneTag(id: 'tag_film', name: '胶片'),
  ];

  /// 根据 id 列表查找标签
  static List<SceneTag> getTagsByIds(List<String> ids) =>
      tags.where((t) => ids.contains(t.id)).toList();

  // ===== LUT 选项 =====
  static const List<LutOption> lutOptions = [
    LutOption(value: 'none', label: '原图'),
    LutOption(value: 'cinematic', label: '电影感'),
    LutOption(value: 'vintage', label: '复古'),
    LutOption(value: 'bw', label: '黑白'),
    LutOption(value: 'warm_film', label: '暖色胶片'),
    LutOption(value: 'cool_film', label: '冷色胶片'),
    LutOption(value: 'pastel', label: '柔色'),
    LutOption(value: 'fuji', label: '富士'),
    LutOption(value: 'cyberpunk', label: '赛博朋克'),
    LutOption(value: 'mist', label: '薄雾'),
  ];

  /// LUT 标签查找
  static String getLutLabel(String lut) {
    for (final o in lutOptions) {
      if (o.value == lut) return o.label;
    }
    return lut;
  }

  // ===== 系统滤镜选项 =====
  static const List<SystemFilterOption> systemFilterOptions = [
    SystemFilterOption(value: 'none', label: '无'),
    SystemFilterOption(value: 'vivid_warm', label: '鲜艳暖色'),
    SystemFilterOption(value: 'vivid_cool', label: '鲜艳冷色'),
    SystemFilterOption(value: 'mono', label: '单色'),
    SystemFilterOption(value: 'vintage', label: '复古'),
  ];

  /// 系统滤镜标签查找
  static String getSystemFilterLabel(String? sf) {
    if (sf == null || sf == 'none') return '';
    for (final o in systemFilterOptions) {
      if (o.value == sf) return o.label;
    }
    return sf;
  }

  // ===== 照片统计（mock） =====
  /// 每场景已拍摄照片数 — 对应 uni-app getPhotoCountByScene
  static const Map<String, int> photoCountByScene = {
    'cafe-window': 8,
    'sunset-silhouette': 3,
    'night-street': 5,
    'seaside-beach': 0,
    'forest-bamboo': 2,
    'rainy-window': 12,
    'custom_demo_001': 1,
  };

  static int getPhotoCountByScene(String sceneId) =>
      photoCountByScene[sceneId] ?? 0;

  // ===== 成就（mock） =====
  /// 场景成就 — 对应 uni-app getSceneAchievement
  static SceneAchievement getSceneAchievement(String sceneId) {
    final count = getPhotoCountByScene(sceneId);
    if (count == 0) {
      return SceneAchievement(
        sceneId: sceneId,
        level: 0,
        levelName: '未开始',
        photoCount: 0,
        nextLevelCount: 1,
      );
    }
    if (count < 3) {
      return SceneAchievement(
        sceneId: sceneId,
        level: 1,
        levelName: '初遇',
        photoCount: count,
        nextLevelCount: 3,
      );
    }
    if (count < 10) {
      return SceneAchievement(
        sceneId: sceneId,
        level: 2,
        levelName: '熟悉',
        photoCount: count,
        nextLevelCount: 10,
      );
    }
    return SceneAchievement(
      sceneId: sceneId,
      level: 3,
      levelName: '精通',
      photoCount: count,
      nextLevelCount: 30,
    );
  }

  // ===== 周排行（mock） =====
  static List<SceneRankingEntry> get weeklyRanking {
    final entries = <SceneRankingEntry>[];
    final ranked = presetScenes
        .map((s) => MapEntry(s, getPhotoCountByScene(s.id)))
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (var i = 0; i < ranked.length; i++) {
      entries.add(SceneRankingEntry(
        scene: ranked[i].key,
        photoCount: ranked[i].value,
        rank: i + 1,
      ));
    }
    return entries;
  }

  // ===== 拍摄套件 mock（用于 scene-manage Tab 3） =====
  static const List<ShootKit> shootKits = [
    ShootKit(
      id: 'kit_001',
      sceneId: 'cafe-window',
      templateId: 'tpl_001',
      name: '咖啡馆人像套件',
    ),
  ];

  // ===== 图标选项（scene-manage 表单） =====
  // 'ph-xxx' phosphor 图标名字符串（与 uni-app 表单一致）。
  // 顺序与 _iconDataOptions 一一对应，用于 iconFromString 索引映射。
  static const List<String> iconOptions = [
    'ph-camera',
    'ph-coffee',
    'ph-sun',
    'ph-flower',
    'ph-building',
    'ph-car',
    'ph-paw-print',
    'ph-fork-knife',
    'ph-mountains',
    'ph-snowflake',
    'ph-lightning',
    'ph-leaf',
    'ph-moon',
    'ph-house',
    'ph-tree',
    'ph-waves',
    'ph-sunset',
    'ph-building-office',
  ];

  // 与 iconOptions 平行的 IconData 列表，用于在 Flutter 中渲染图标
  static const List<IconData> _iconDataOptions = [
    Icons.camera_alt_outlined,
    Icons.coffee_outlined,
    Icons.wb_sunny_outlined,
    Icons.local_florist_outlined,
    Icons.apartment_outlined,
    Icons.directions_car_outlined,
    Icons.pets_outlined,
    Icons.restaurant_outlined,
    Icons.landscape_outlined,
    Icons.ac_unit_outlined,
    Icons.bolt_outlined,
    Icons.eco_outlined,
    Icons.nightlight_outlined,
    Icons.home_outlined,
    Icons.park_outlined,
    Icons.waves_outlined,
    Icons.wb_twilight_outlined,
    Icons.business_outlined,
  ];

  /// 字符串 → 图标（编辑场景回填、Icon 渲染用）
  ///
  /// 支持：
  /// - 'ph-xxx' phosphor 名（优先匹配 iconOptions）
  /// - 旧格式 'icon_x'（按索引兼容历史 DB 数据）
  /// - 其它未知值：回退 Icons.camera_alt_outlined
  static IconData iconFromString(String? s) {
    if (s == null || s.isEmpty) return Icons.camera_alt_outlined;
    final idx = iconOptions.indexOf(s);
    if (idx >= 0) return _iconDataOptions[idx];
    // 兼容旧格式 'icon_x'（按索引映射到 _iconDataOptions）
    if (s.startsWith('icon_')) {
      final legacyIdx = int.tryParse(s.substring(5));
      if (legacyIdx != null &&
          legacyIdx >= 0 &&
          legacyIdx < _iconDataOptions.length) {
        return _iconDataOptions[legacyIdx];
      }
    }
    return Icons.camera_alt_outlined;
  }

  // ===== 场景查找 =====
  /// 按 id 查找场景 — 对应 uni-app getSceneById
  static ScenePreset? getSceneById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final s in allScenes) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// 是否为收藏场景
  static bool isFavorite(String id) => favoritePresetIds.contains(id);
}
