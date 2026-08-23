import '../../../core/db/dao/scenes_dao.dart';
import '../../../core/db/dao/templates_dao.dart';
import '../../../shared/searchengine/search_scope.dart';
import '../../academy/data/academy_models.dart';
import '../../templates/data/remote_template_dto.dart';
import '../../templates/data/templates_browse_mock_data.dart';
import '../../templates/services/template_mapper.dart';

/// 跨三类内容的统一搜索结果模型。
/// 每次只持有一种内容（template / scene / course / knowledgeCard 之一非空）。
class SearchResult {
  final SearchScope scope; // template | scene | academy
  final TemplateRecord? template;
  final SceneRecord? scene;
  final AcademyCourse? course;
  final KnowledgeCard? knowledgeCard;

  /// 模板在本机已拍摄的照片数（模板卡片「已拍 N 张」角标；非模板时为 0）。
  final int usageCount;

  /// 分类 key → 中文标签映射（含二级大风格），来自 sqflite template_categories 表。
  /// 用于卡片展示「大类 · 二级大风格」两级分类。
  final Map<String, String> categoryLabels;

  const SearchResult({
    required this.scope,
    this.template,
    this.scene,
    this.course,
    this.knowledgeCard,
    this.usageCount = 0,
    this.categoryLabels = const {},
  });

  String get id {
    final t = template?.id;
    if (t != null) return t;
    final s = scene?.id;
    if (s != null) return s;
    final c = course?.id;
    if (c != null) return c;
    return knowledgeCard?.id ?? '';
  }

  String get title =>
      template?.name ?? scene?.name ?? course?.title ?? knowledgeCard?.title ?? '';

  String get subtitle {
    if (template != null) {
      return categoryLabel;
    }
    if (scene != null) return scene!.vibe;
    if (course != null) {
      return '${course!.topic.label} · ${course!.level.label} · ${course!.meta}';
    }
    if (knowledgeCard != null) return knowledgeCard!.subtitle;
    return '';
  }

  /// 网络/资源图片 URL（模板封面/场景示例图/课程封面/知识卡封面）。
  String? get imageUrl {
    final t = template;
    if (t != null) return t.cover.isEmpty ? null : t.cover;
    final s = scene;
    if (s != null) {
      return s.exampleImages.isNotEmpty ? s.exampleImages.first : null;
    }
    final c = course;
    if (c != null) return c.coverImage;
    final k = knowledgeCard;
    if (k != null) return k.coverImage;
    return null;
  }

  /// 模板 base64 封面数据。
  String? get coverData => template?.coverData;

  // === 模板卡片富内容（对齐「全部模板页」卡片） ===

  /// 模板分类中文标签。
  String get categoryLabel =>
      template != null
          ? TemplatesBrowseMockData.categoryLabel(template!.category)
          : '';

  /// 模板二级大风格中文标签（L2，如「情绪」「日系」）。
  /// 优先从 sqflite 分类表映射取，缺失时回退到 mock metadata。
  String get categoryMajorLabel {
    final t = template;
    if (t == null) return '';
    final majorStyle = t.classification['majorStyle'] as String?;
    if (majorStyle == null || majorStyle.isEmpty) return '';
    final fromMap = categoryLabels[majorStyle];
    if (fromMap != null && fromMap.isNotEmpty) return fromMap;
    // ignore: deprecated_member_use, deprecated_member_use_from_same_package
    final style = styleMap[majorStyle];
    if (style != null && style.isNotEmpty) return style.first.label;
    return '';
  }

  /// 模板两级分类展示文本：「大类 · 二级大风格」。无二级时仅大类。
  String get categoryTwoLevel {
    final l1 = categoryLabel;
    if (l1.isEmpty) return '';
    final l2 = categoryMajorLabel;
    if (l2.isEmpty) return l1;
    return '$l1 · $l2';
  }

  /// 模板短简介（短描述为空时兜底截取完整描述）。
  String get shortDesc {
    final t = template;
    if (t == null) return '';
    if (t.shortDesc.isNotEmpty) return t.shortDesc;
    if (t.description.isNotEmpty) {
      return t.description;
    }
    return '';
  }

  /// 是否为自定义模板。
  bool get isCustom => template?.source == 'custom';

  /// 模板价格（0 = 免费）。
  int get price => template?.price ?? 0;

  /// 季节/天气/时段氛围元数据（模板卡片 tag 展示用）。
  RemoteTemplateAmbienceDto? get ambience {
    final t = template;
    if (t == null) return null;
    return TemplateMapper.ambienceFromJson(t.ambienceJson);
  }

  /// 美学院结果是否为课程（false=知识卡片）。
  bool get isCourse => course != null;
}
