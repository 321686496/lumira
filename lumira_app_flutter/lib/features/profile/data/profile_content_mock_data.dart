/// 自定义模板分类（与 uni-app Target 类型对应）
enum TemplateCategory {
  portrait,    // 人像
  landscape,   // 风光
  food,        // 美食
  street,      // 街拍
  night,       // 夜景
  macro,       // 微距
  stillLife,   // 静物
}

/// 精选集项
class CollectionItem {
  final String id;
  final String coverUrl;
  final String name;
  final int count;
  final String updated;

  const CollectionItem({
    required this.id,
    required this.coverUrl,
    required this.name,
    required this.count,
    required this.updated,
  });
}

/// 精选集照片 URL（用于 collection-detail 3 列网格）
class PhotoItem {
  final String id;
  final String url;

  const PhotoItem({required this.id, required this.url});
}

/// 摄影学院课程章节
class LessonSection {
  final String title;
  final List<String> paragraphs;

  const LessonSection({required this.title, required this.paragraphs});
}

/// 对比卡片（academy-detail 用）
class CompareCell {
  final String iconName; // 'arrow_down' / 'arrows_left_right'
  final String name;
  final String desc;
  final String tagText;
  final String tagColor; // 'green' / 'gold'

  const CompareCell({
    required this.iconName,
    required this.name,
    required this.desc,
    required this.tagText,
    required this.tagColor,
  });
}

/// 实战练习标签
class PracticeTag {
  final String iconName;
  final String label;
  final String color; // 'gold' / 'green' / 'red'

  const PracticeTag({
    required this.iconName,
    required this.label,
    required this.color,
  });
}

/// 推荐模板
class RecommendTemplate {
  final String imageUrl;
  final String name;
  final String desc;
  final String badge; // '免费' / '付费'

  const RecommendTemplate({
    required this.imageUrl,
    required this.name,
    required this.desc,
    required this.badge,
  });
}

/// 自定义模板（my-templates 用）
class CustomTemplate {
  final String id;
  final String name;
  final String? coverUrl;
  final TemplateCategory category;
  final List<String> tags;
  final int exposureCompensation; // EV
  final int iso;
  final String shutterSpeed;
  final int usageCount;
  final bool isFavorite;

  const CustomTemplate({
    required this.id,
    required this.name,
    this.coverUrl,
    required this.category,
    required this.tags,
    required this.exposureCompensation,
    required this.iso,
    required this.shutterSpeed,
    required this.usageCount,
    required this.isFavorite,
  });
}

/// Profile 内容页共享 mock 数据
class ProfileContentMockData {
  ProfileContentMockData._();

  // === Collections 精选集（4 个）===
  static const collections = <CollectionItem>[
    CollectionItem(
      id: 'c1',
      coverUrl: 'https://picsum.photos/seed/326473/400/400',
      name: '我最爱的九张',
      count: 9,
      updated: '7月10日',
    ),
    CollectionItem(
      id: 'c2',
      coverUrl: 'https://picsum.photos/seed/457882/400/400',
      name: '旅行精选',
      count: 24,
      updated: '6月28日',
    ),
    CollectionItem(
      id: 'c3',
      coverUrl: 'https://picsum.photos/seed/1926769/400/400',
      name: '穿搭合集',
      count: 12,
      updated: '7月10日',
    ),
    CollectionItem(
      id: 'c4',
      coverUrl: 'https://picsum.photos/seed/312415/400/400',
      name: '咖啡馆时光',
      count: 8,
      updated: '6月15日',
    ),
  ];

  // === Collection Detail 照片（9 张，3x3 网格）===
  static const photos = <PhotoItem>[
    PhotoItem(id: 'p1', url: 'https://picsum.photos/seed/733872/400/600'),
    PhotoItem(id: 'p2', url: 'https://picsum.photos/seed/1926769/400/600'),
    PhotoItem(id: 'p3', url: 'https://picsum.photos/seed/2074130/400/600'),
    PhotoItem(id: 'p4', url: 'https://picsum.photos/seed/1038002/400/600'),
    PhotoItem(id: 'p5', url: 'https://picsum.photos/seed/172217/400/400'),
    PhotoItem(id: 'p6', url: 'https://picsum.photos/seed/326473/400/600'),
    PhotoItem(id: 'p7', url: 'https://picsum.photos/seed/1239291/400/600'),
    PhotoItem(id: 'p8', url: 'https://picsum.photos/seed/326473b/400/600'),
    PhotoItem(id: 'p9', url: 'https://picsum.photos/seed/1080696/400/600'),
  ];

  // === Academy Detail 课程 ===
  static const lessonTitle = '第1课 · 找到你的最佳角度';
  static const lessonMeta = '8分钟 · 进阶入门';
  static const lessonHeroImage = 'https://picsum.photos/seed/733872/400/600';

  static const lessonSections = <LessonSection>[
    LessonSection(
      title: '为什么角度很重要',
      paragraphs: [
        '同样的场景、同样的光线，仅仅因为拍摄角度的不同，照片效果可能天差地别。找到你身上最自信的角度，是出片的第一步。',
        '每个人的脸型、身材比例不同，适合的角度也不同。但有一些通用法则可以让你快速找到自己的「最佳出片位」。',
      ],
    ),
    LessonSection(
      title: '俯拍 vs 平拍',
      paragraphs: [
        '两种最常见角度的效果对比：',
      ],
    ),
    LessonSection(
      title: '小贴士',
      paragraphs: [],
    ),
  ];

  // 技巧卡片
  static const tipCardTitle = '45度角拍摄';
  static const tipCardParagraph =
      '微微侧身45度，下巴略微前伸，可以让脸部轮廓更立体。这个角度适合绝大多数脸型，尤其对圆脸非常友好。';
  static const tipCardImage = 'https://picsum.photos/seed/733872/400/600';

  // 对比卡片
  static const compareCells = <CompareCell>[
    CompareCell(
      iconName: 'arrow_down',
      name: '俯拍',
      desc: '相机在眼睛上方，从上往下拍。显脸小、显头身比好。',
      tagText: '推荐',
      tagColor: 'green',
    ),
    CompareCell(
      iconName: 'arrows_left_right',
      name: '平拍',
      desc: '相机与眼睛平齐。真实还原，适合证件照、正面照。',
      tagText: '中性',
      tagColor: 'gold',
    ),
  ];

  // 实战练习
  static const practiceTitle = '试试这个练习';
  static const practiceParagraph =
      '打开如画，选择「街拍回眸」模板，在自然光下尝试俯拍角度，拍摄3张不同角度的照片。';
  static const practiceTags = <PracticeTag>[
    PracticeTag(iconName: 'camera', label: '街拍', color: 'gold'),
    PracticeTag(iconName: 'sun', label: '自然光', color: 'green'),
    PracticeTag(iconName: 'arrow_down', label: '俯拍', color: 'red'),
  ];

  // 小贴士列表
  static const tips = <String>[
    '手机举高15-30cm，微微俯拍效果最好',
    '避免完全正面，微微转头更自然',
    '利用窗光，侧光拍出脸部立体感',
  ];

  // 推荐模板
  static const recommendTemplate = RecommendTemplate(
    imageUrl: 'https://picsum.photos/seed/1926769/400/600',
    name: '街拍回眸',
    desc: '试试用「街拍回眸」拍摄',
    badge: '免费',
  );

  // === My Templates 自定义模板（5 个，覆盖 4 个分类）===
  static const customTemplates = <CustomTemplate>[
    CustomTemplate(
      id: 'tpl_001',
      name: '复古胶片人像',
      coverUrl: 'https://picsum.photos/seed/tpl001/400/600',
      category: TemplateCategory.portrait,
      tags: ['复古', '胶片', '暖调'],
      exposureCompensation: 0,
      iso: 400,
      shutterSpeed: '1/125',
      usageCount: 1280,
      isFavorite: true,
    ),
    CustomTemplate(
      id: 'tpl_002',
      name: '日落山景',
      coverUrl: 'https://picsum.photos/seed/tpl002/400/600',
      category: TemplateCategory.landscape,
      tags: ['日落', '广角', '高动态'],
      exposureCompensation: -1,
      iso: 100,
      shutterSpeed: '1/250',
      usageCount: 856,
      isFavorite: false,
    ),
    CustomTemplate(
      id: 'tpl_003',
      name: '咖啡馆俯拍',
      coverUrl: 'https://picsum.photos/seed/tpl003/400/600',
      category: TemplateCategory.food,
      tags: ['俯拍', '暖光', '静物'],
      exposureCompensation: 1,
      iso: 800,
      shutterSpeed: '1/60',
      usageCount: 432,
      isFavorite: true,
    ),
    CustomTemplate(
      id: 'tpl_004',
      name: '夜景街拍',
      coverUrl: 'https://picsum.photos/seed/tpl004/400/600',
      category: TemplateCategory.street,
      tags: ['夜景', '霓虹', '长焦'],
      exposureCompensation: 0,
      iso: 1600,
      shutterSpeed: '1/30',
      usageCount: 215,
      isFavorite: false,
    ),
    CustomTemplate(
      id: 'tpl_005',
      name: '微距花卉',
      coverUrl: 'https://picsum.photos/seed/tpl005/400/600',
      category: TemplateCategory.macro,
      tags: ['微距', '柔光', '浅景深'],
      exposureCompensation: 0,
      iso: 200,
      shutterSpeed: '1/200',
      usageCount: 88,
      isFavorite: false,
    ),
  ];

  // === My Templates 统计 ===
  static int get totalUsage =>
      customTemplates.fold(0, (sum, t) => sum + t.usageCount);
  static int get favoriteCount =>
      customTemplates.where((t) => t.isFavorite).length;
}
