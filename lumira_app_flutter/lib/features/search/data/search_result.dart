import '../../../core/db/dao/scenes_dao.dart';
import '../../../core/db/dao/templates_dao.dart';
import '../../../shared/searchengine/search_scope.dart';
import '../../academy/data/academy_models.dart';

/// 跨三类内容的统一搜索结果模型。
/// 每次只持有一种内容（template / scene / course / knowledgeCard 之一非空）。
class SearchResult {
  final SearchScope scope; // template | scene | academy
  final TemplateRecord? template;
  final SceneRecord? scene;
  final AcademyCourse? course;
  final KnowledgeCard? knowledgeCard;

  const SearchResult({
    required this.scope,
    this.template,
    this.scene,
    this.course,
    this.knowledgeCard,
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
      return _categoryLabel(template!.category);
    }
    if (scene != null) return scene!.vibe;
    if (course != null) {
      return '${course!.topic.label} · ${course!.level.label}';
    }
    if (knowledgeCard != null) return knowledgeCard!.subtitle;
    return '';
  }

  /// 网络/资源图片 URL（模板封面/场景示例图/课程封面）。
  String? get imageUrl {
    final t = template;
    if (t != null) return t.cover.isEmpty ? null : t.cover;
    final s = scene;
    if (s != null) {
      return s.exampleImages.isNotEmpty ? s.exampleImages.first : null;
    }
    final c = course;
    if (c != null) return c.coverImage;
    return null;
  }

  /// 模板 base64 封面数据。
  String? get coverData => template?.coverData;

  /// 美学院结果是否为课程（false=知识卡片）。
  bool get isCourse => course != null;

  static String _categoryLabel(String key) =>
      // 复用项目既有分类中文标签表（模板分类）。
      // 若 key 无映射则回退英文 key。
      const {
        'portrait': '人像',
        'landscape': '风光',
        'food': '美食',
        'street': '街拍',
        'night': '夜景',
        'macro': '微距',
        'still-life': '静物',
      }[key] ??
      key;
}
