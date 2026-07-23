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
