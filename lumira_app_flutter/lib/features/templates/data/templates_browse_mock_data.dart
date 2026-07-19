import 'package:flutter/material.dart';

/// 模板浏览页（detail / all / recommend）共享 mock 数据
///
/// 视觉规格来源：lumira-app/src/pages/templates/detail.vue / all.vue / recommend.vue
/// 与 Task 2.2 的 templates_mock_data.dart 独立，避免修改已稳定文件（与 Task 2.7B 策略一致）。
///
/// 注意：brief 中 `_LabelValue` 为私有类，但出现在公开 `Map<String, List<_LabelValue>>` 类型签名中
/// （Dart 私有类不能出现在公开 API 中），故实现时改为公有 `LabelValue`。

/// 模板分类中文标签
/// 来源：lumira-app/src/pages/templates/detail.vue 的 categoryLabel computed
const Map<String, String> _categoryLabelMap = {
  'portrait': '人像',
  'landscape': '风光',
  'food': '美食',
  'street': '街拍',
  'night': '夜景',
  'macro': '微距',
  'still-life': '静物',
};

/// 白平衡标签
/// 来源：detail.vue wbLabel computed
const Map<String, String> _wbLabelMap = {
  'daylight': '日光',
  'cloudy': '阴天',
  'shade': '阴影',
  'tungsten': '白炽灯',
  'fluorescent': '荧光灯',
  'custom': '自定义',
};

/// 闪光灯标签
const Map<String, String> _flashLabelMap = {
  'off': '关闭',
  'on': '开启',
  'auto': '自动',
  'torch': '常亮',
};

/// 对焦模式标签
const Map<String, String> _focusLabelMap = {
  'auto': '自动',
  'manual': '手动',
  'continuous': '连续',
};

/// 镜头建议标签
const Map<String, String> _lensLabelMap = {
  'wide': '广角',
  'main': '主摄',
  'telephoto': '长焦',
  'ultra_wide': '超广角',
};

/// LUT 标签
const Map<String, String> _lutLabelMap = {
  'none': '无',
  'cinematic': '电影感',
  'vintage': '复古',
  'bw': '黑白',
  'warm_film': '暖色胶片',
  'cool_film': '冷色胶片',
  'pastel': '柔色',
  'fuji': '富士',
};

/// 场景 → 分类映射（mock 简化版，Task 2.9 替换为完整 scenePresets）
const Map<String, String> sceneToCategoryMap = {
  'cafe': 'still-life',
  'sunset': 'landscape',
  'street': 'street',
  'night': 'night',
};

/// 三层分类 STYLE_MAP（all.vue STYLE_MAP verbatim）
/// 注意：LabelValue 为公有类（brief 中 _LabelValue 改公有，见文件头注释）
const Map<String, List<LabelValue>> styleMap = {
  'portrait': [
    LabelValue('japanese', '日系'),
    LabelValue('emotional', '情绪'),
    LabelValue('film', '胶片'),
    LabelValue('western', '欧美'),
  ],
  'landscape': [
    LabelValue('fresh', '清新'),
    LabelValue('epic', '大气'),
  ],
  'food': [
    LabelValue('overhead', '俯拍'),
    LabelValue('closeup', '特写'),
  ],
  'street': [
    LabelValue('casual', '随性'),
    LabelValue('geometric', '几何'),
  ],
  'night': [
    LabelValue('neon', '霓虹'),
    LabelValue('starry', '星空'),
  ],
  'macro': [
    LabelValue('nature', '自然'),
    LabelValue('object', '物品'),
  ],
  'still-life': [
    LabelValue('minimal', '极简'),
    LabelValue('flat', '扁平'),
  ],
};

/// 三层分类 METHOD_MAP（all.vue METHOD_MAP verbatim）
const Map<String, List<LabelValue>> methodMap = {
  'japanese': [
    LabelValue('selfie', '自拍'),
    LabelValue('normal', '他拍'),
    LabelValue('overhead', '俯拍'),
  ],
  'emotional': [
    LabelValue('selfie', '自拍'),
    LabelValue('wide', '远景'),
  ],
  'film': [
    LabelValue('selfie', '自拍'),
    LabelValue('normal', '他拍'),
  ],
  'western': [
    LabelValue('normal', '他拍'),
    LabelValue('wide', '远景'),
  ],
  'fresh': [
    LabelValue('wide', '远景'),
    LabelValue('flat', '平拍'),
  ],
  'epic': [
    LabelValue('wide', '远景'),
    LabelValue('overhead', '俯拍'),
  ],
  'overhead': [
    LabelValue('flat', '平拍'),
    LabelValue('overhead', '俯拍'),
  ],
  'closeup': [
    LabelValue('macro', '微距'),
    LabelValue('detail', '细节'),
  ],
  'casual': [
    LabelValue('normal', '随拍'),
    LabelValue('wide', '远景'),
  ],
  'geometric': [
    LabelValue('wide', '远景'),
    LabelValue('overhead', '俯拍'),
  ],
  'neon': [
    LabelValue('normal', '他拍'),
    LabelValue('wide', '远景'),
  ],
  // starry / nature / object / minimal / flat STYLE 缺 METHOD_MAP（uni-app 原表也无），按 nil 处理
};

/// 标签值对（三层分类 STYLE_MAP/METHOD_MAP 用）
/// 公有类：brief 中 _LabelValue 改公有，因 Dart 私有类不能出现在公开 Map 类型签名中
class LabelValue {
  const LabelValue(this.value, this.label);
  final String value;
  final String label;
}

/// 模板详情完整数据（PhotoTemplate-like）
class TemplateDetail {
  const TemplateDetail({
    required this.id,
    required this.name,
    required this.category,
    required this.coverSeed,
    required this.tags,
    required this.tagIds,
    required this.price,
    required this.referenceSource,
    required this.aspectRatio,
    required this.composition,
    required this.camera,
    required this.postProcess,
    required this.sceneGuide,
    required this.pose,
  });

  final String id;
  final String name;
  final String category; // 'portrait' / 'landscape' / ...
  final String coverSeed; // picsum seed
  final List<String> tags;
  final List<String> tagIds;
  final int price; // 0 = 免费
  final String referenceSource;
  final String aspectRatio; // '4:3' / '1:1' / '3:4' / ...
  final CompositionData composition;
  final CameraData camera;
  final PostProcessData postProcess;
  final SceneGuideData sceneGuide;
  final PoseData pose;
}

class CompositionData {
  const CompositionData({required this.type, required this.description});
  final String type; // 'rule-of-thirds' / 'center' / 'golden' / 'diagonal'
  final String description;
}

class CameraData {
  const CameraData({
    required this.iso,
    required this.shutterSpeed,
    required this.whiteBalance,
    required this.whiteBalanceK,
    required this.exposureCompensation,
    required this.flashMode,
    required this.focusMode,
    required this.lensSuggestion,
  });
  final int iso;
  final String shutterSpeed; // '1/125' / '1/60' / ...
  final String whiteBalance; // 'daylight' / 'cloudy' / ...
  final int? whiteBalanceK;
  final int exposureCompensation; // -2..+2
  final String flashMode; // 'off' / 'on' / 'auto' / 'torch'
  final String focusMode; // 'auto' / 'manual' / 'continuous'
  final String lensSuggestion; // 'wide' / 'main' / 'telephoto' / 'ultra_wide'
}

class PostProcessData {
  const PostProcessData({
    required this.cropRatio,
    required this.lut,
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.temperature,
    required this.tint,
    required this.smoothStrength,
    required this.sharpen,
    required this.vignette,
    required this.grain,
  });
  final String cropRatio; // '4:3' / '1:1' / ...
  final String lut; // 'none' / 'cinematic' / ...
  final int brightness; // -100..+100
  final int contrast;
  final int saturation;
  final int temperature;
  final int tint;
  final int smoothStrength; // 0..100
  final int sharpen; // 0..100
  final int vignette; // 0..100
  final int grain; // 0..100
}

class SceneGuideData {
  const SceneGuideData({
    required this.lightDirection,
    required this.shootingDistance,
    required this.background,
    required this.props,
    required this.bestTime,
    required this.tips,
  });
  final String lightDirection;
  final String shootingDistance;
  final String background;
  final List<String> props;
  final String bestTime;
  final List<String> tips;
}

class PoseData {
  const PoseData({
    required this.silhouetteType,
    required this.silhouetteData,
    required this.positionX,
    required this.positionY,
    required this.description,
  });
  final String silhouetteType; // 'builtin' / 'inline' / 'none'
  final String silhouetteData; // 'none' / 'standing_basic' / ... SVG id
  final double positionX; // 0..1
  final double positionY; // 0..1
  final String description;
}

/// 全部模板列表项（all 页用，分类筛选后渲染）
class AllTemplateItem {
  const AllTemplateItem({
    required this.id,
    required this.name,
    required this.category,
    required this.style, // STYLE_MAP value: 'japanese' / 'emotional' / ...
    required this.method, // METHOD_MAP value: 'selfie' / 'wide' / ...
    required this.coverSeed,
    required this.price,
    required this.isCustom,
  });
  final String id;
  final String name;
  final String category;
  final String? style;
  final String? method;
  final String coverSeed;
  final int price; // 0 = 免费
  final bool isCustom;
}

/// 推荐页 mock 数据（recommend.vue verbatim）
class StyleAnalysis {
  const StyleAnalysis({required this.icon, required this.label, required this.percent});
  final IconData icon; // Flutter 替代 Phosphor icon
  final String label;
  final int percent;
}

class GuessLikeItem {
  const GuessLikeItem({
    required this.imgSeed,
    required this.name,
    required this.match,
    required this.reason,
    required this.count,
    required this.level,
    required this.isGold,
  });
  final String imgSeed;
  final String name;
  final String match; // '匹配 96%'
  final String reason;
  final String count; // '12 张'
  final String level; // '易 新手' / '中 进阶' / '难 大师'
  final bool isGold; // true → lumira-tag-gold, false → lumira-tag-green
}

class SimilarUserItem {
  const SimilarUserItem({required this.imgSeed, required this.name, required this.usageCount});
  final String imgSeed;
  final String name;
  final int usageCount; // 1200 / 980 / 850 / 720 — 用于 formatThousands
}

class RecentShotInfo {
  const RecentShotInfo({required this.imgSeed, required this.text, required this.sub});
  final String imgSeed;
  final String text;
  final String sub;
}

class RecentTemplateItem {
  const RecentTemplateItem({
    required this.imgSeed,
    required this.name,
    required this.theme,
    required this.match,
    required this.count,
  });
  final String imgSeed;
  final String name;
  final String theme;
  final String match;
  final String count;
}

class TemplatesBrowseMockData {
  TemplatesBrowseMockData._();

  /// 模板详情 mock（2 个：1 免费 + 1 付费）
  /// 来源：uni-app loadTemplate 返回 PhotoTemplate，本任务 mock 简化
  static const List<TemplateDetail> details = [
    TemplateDetail(
      id: 'cafe_portrait',
      name: '咖啡馆人像',
      category: 'portrait',
      coverSeed: 'tpl-cafe-portrait',
      tags: ['日系', '柔光'],
      tagIds: [],
      price: 0,
      referenceSource: '摄影美学院 L03',
      aspectRatio: '3:4',
      composition: CompositionData(
        type: 'rule-of-thirds',
        description: '主体位于左侧三分线，留白右侧',
      ),
      camera: CameraData(
        iso: 400,
        shutterSpeed: '1/125',
        whiteBalance: 'daylight',
        whiteBalanceK: 5500,
        exposureCompensation: 1,
        flashMode: 'off',
        focusMode: 'auto',
        lensSuggestion: 'main',
      ),
      postProcess: PostProcessData(
        cropRatio: '3:4',
        lut: 'warm_film',
        brightness: 5,
        contrast: -3,
        saturation: 8,
        temperature: 6,
        tint: 2,
        smoothStrength: 30,
        sharpen: 15,
        vignette: 10,
        grain: 12,
      ),
      sceneGuide: SceneGuideData(
        lightDirection: '侧逆光（窗户方向）',
        shootingDistance: '1.2-1.8 米',
        background: '虚化的店内环境',
        props: ['咖啡杯', '书本'],
        bestTime: '下午 14:00-16:00',
        tips: ['让模特自然互动', '利用窗光制造柔光'],
      ),
      pose: PoseData(
        silhouetteType: 'builtin',
        silhouetteData: 'standing_basic',
        positionX: 0.4,
        positionY: 0.5,
        description: '站立微侧，双手自然交叠于腰前',
      ),
    ),
    TemplateDetail(
      id: 'custom_golden_landscape',
      name: '金色风光精选',
      category: 'landscape',
      coverSeed: 'tpl-golden-landscape',
      tags: ['金色', '日落'],
      tagIds: ['tag_sunset', 'tag_golden'],
      price: 18,
      referenceSource: '用户原创',
      aspectRatio: '16:9',
      composition: CompositionData(
        type: 'golden',
        description: '地平线位于下三分线，突出天空',
      ),
      camera: CameraData(
        iso: 100,
        shutterSpeed: '1/60',
        whiteBalance: 'cloudy',
        whiteBalanceK: 6500,
        exposureCompensation: -1,
        flashMode: 'off',
        focusMode: 'manual',
        lensSuggestion: 'wide',
      ),
      postProcess: PostProcessData(
        cropRatio: '16:9',
        lut: 'cinematic',
        brightness: -2,
        contrast: 12,
        saturation: 18,
        temperature: 10,
        tint: -3,
        smoothStrength: 0,
        sharpen: 25,
        vignette: 20,
        grain: 8,
      ),
      sceneGuide: SceneGuideData(
        lightDirection: '顺光（朝太阳方向）',
        shootingDistance: '远景',
        background: '开阔天空',
        props: [],
        bestTime: '日落前 30 分钟',
        tips: ['使用三脚架', '手动对焦无限远'],
      ),
      pose: PoseData(
        silhouetteType: 'builtin',
        silhouetteData: 'none',
        positionX: 0.5,
        positionY: 0.5,
        description: '',
      ),
    ),
  ];

  /// 全部模板列表 mock（10 项：7 内置 + 3 自定义，覆盖 7 个分类）
  static const List<AllTemplateItem> allTemplates = [
    AllTemplateItem(
      id: 'cafe_portrait',
      name: '咖啡馆人像',
      category: 'portrait',
      style: 'japanese',
      method: 'normal',
      coverSeed: 'tpl-cafe-portrait',
      price: 0,
      isCustom: false,
    ),
    AllTemplateItem(
      id: 'street_bw',
      name: '街拍黑白',
      category: 'street',
      style: 'casual',
      method: 'wide',
      coverSeed: 'tpl-street-bw',
      price: 0,
      isCustom: false,
    ),
    AllTemplateItem(
      id: 'macro_flower',
      name: '微距花卉',
      category: 'macro',
      style: 'nature',
      method: null,
      coverSeed: 'tpl-macro-flower',
      price: 0,
      isCustom: false,
    ),
    AllTemplateItem(
      id: 'golden_landscape',
      name: '金色风光',
      category: 'landscape',
      style: 'epic',
      method: 'wide',
      coverSeed: 'tpl-golden-landscape',
      price: 18,
      isCustom: false,
    ),
    AllTemplateItem(
      id: 'food_overhead',
      name: '美食俯拍',
      category: 'food',
      style: 'overhead',
      method: 'flat',
      coverSeed: 'tpl-food-flat-lay',
      price: 0,
      isCustom: false,
    ),
    AllTemplateItem(
      id: 'night_neon',
      name: '霓虹夜景',
      category: 'night',
      style: 'neon',
      method: 'normal',
      coverSeed: 'tpl-night-neon',
      price: 24,
      isCustom: false,
    ),
    AllTemplateItem(
      id: 'still_life_warm',
      name: '静物暖光',
      category: 'still-life',
      style: 'minimal',
      method: null,
      coverSeed: 'tpl-still-life-warm',
      price: 12,
      isCustom: false,
    ),
    AllTemplateItem(
      id: 'custom_golden_landscape',
      name: '金色风光精选',
      category: 'landscape',
      style: 'epic',
      method: 'wide',
      coverSeed: 'tpl-golden-landscape',
      price: 18,
      isCustom: true,
    ),
    AllTemplateItem(
      id: 'custom_cafe_diary',
      name: '咖啡日记',
      category: 'still-life',
      style: 'flat',
      method: null,
      coverSeed: 'tpl-custom-cafe',
      price: 0,
      isCustom: true,
    ),
    AllTemplateItem(
      id: 'custom_portrait_soft',
      name: '柔光人像自创',
      category: 'portrait',
      style: 'japanese',
      method: 'selfie',
      coverSeed: 'tpl-custom-soft-portrait',
      price: 0,
      isCustom: true,
    ),
  ];

  /// 推荐页：风格分析（3 项，recommend.vue verbatim）
  /// Phosphor 图标映射：ph-flower → Icons.local_florist, ph-leaf → Icons.eco, ph-camera → Icons.camera_alt
  static const List<StyleAnalysis> styleAnalysis = [
    StyleAnalysis(icon: Icons.local_florist, label: '温柔', percent: 68),
    StyleAnalysis(icon: Icons.eco, label: '清新', percent: 45),
    StyleAnalysis(icon: Icons.camera_alt, label: '复古', percent: 32),
  ];

  /// 推荐页：猜你喜欢（6 项，recommend.vue verbatim）
  static const List<GuessLikeItem> guessLikes = [
    GuessLikeItem(imgSeed: '1038002', name: '牡丹花下', match: '匹配 96%', reason: '因为你喜欢温柔风格', count: '12 张', level: '易 新手', isGold: false),
    GuessLikeItem(imgSeed: '326473', name: '茶园春色', match: '匹配 92%', reason: '因为你喜欢清新品味', count: '9 张', level: '易 新手', isGold: false),
    GuessLikeItem(imgSeed: '1926769', name: '民国风情', match: '匹配 89%', reason: '因为你喜欢复古调性', count: '14 张', level: '中 进阶', isGold: true),
    GuessLikeItem(imgSeed: '1239291', name: '白纱轻舞', match: '匹配 94%', reason: '因为你喜欢温柔风格', count: '11 张', level: '易 新手', isGold: false),
    GuessLikeItem(imgSeed: '326473', name: '植物园记', match: '匹配 87%', reason: '因为你喜欢清新品味', count: '13 张', level: '中 构图', isGold: true),
    GuessLikeItem(imgSeed: '1926769', name: '旧上海', match: '匹配 85%', reason: '因为你喜欢复古调性', count: '16 张', level: '难 大师', isGold: true),
  ];

  /// 推荐页：相似用户也在拍（4 项，recommend.vue verbatim — usageCount 用 int 类型便于 formatThousands）
  static const List<SimilarUserItem> similarUsers = [
    SimilarUserItem(imgSeed: '326473', name: '晨雾森林', usageCount: 1200),
    SimilarUserItem(imgSeed: '1038002', name: '向日葵田', usageCount: 980),
    SimilarUserItem(imgSeed: '172217', name: '书香午后', usageCount: 850),
    SimilarUserItem(imgSeed: '457882', name: '海边栈道', usageCount: 720),
  ];

  /// 推荐页：根据最近拍摄（1 项）
  static const RecentShotInfo recentShot = RecentShotInfo(
    imgSeed: '2074130',
    text: '你昨天在咖啡馆拍了 3 张照片',
    sub: '试试这些咖啡馆模板吧',
  );

  /// 推荐页：最近模板（4 项）
  static const List<RecentTemplateItem> recentTemplates = [
    RecentTemplateItem(imgSeed: '2074130', name: '咖啡角落', theme: '咖啡馆主题', match: '匹配 91%', count: '10 张'),
    RecentTemplateItem(imgSeed: '2074130', name: '拉花艺术', theme: '咖啡馆主题', match: '匹配 86%', count: '8 张'),
    RecentTemplateItem(imgSeed: '2074130', name: '窗边阅读', theme: '咖啡馆主题', match: '匹配 88%', count: '12 张'),
    RecentTemplateItem(imgSeed: '2074130', name: '咖啡物语', theme: '咖啡馆主题', match: '匹配 82%', count: '6 张'),
  ];

  /// 标签查询：通过 id 查询 TemplateDetail（detail 页用）
  static TemplateDetail? findDetailById(String id) {
    for (final t in details) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// 6 个 enum label 静态方法（detail 页用）
  static String categoryLabel(String category) =>
      _categoryLabelMap[category] ?? category;
  static String wbLabel(String wb) => _wbLabelMap[wb] ?? wb;
  static String flashLabel(String f) => _flashLabelMap[f] ?? f;
  static String focusLabel(String f) => _focusLabelMap[f] ?? f;
  static String lensLabel(String l) => _lensLabelMap[l] ?? l;
  static String lutLabel(String l) => _lutLabelMap[l] ?? l;
}
