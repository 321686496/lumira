import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/profile/data/profile_content_mock_data.dart';
import 'templates_browse_mock_data.dart';

/// 导入的模板数据（运行时状态，可与 mock 数据合并显示）
///
/// 同时维护两种视图：
/// - [AllTemplateItem]：用于 templates_all_page（"我的"开关切换时显示）
/// - [CustomTemplate]：用于 profile_my_templates_page
class ImportedTemplate {
  const ImportedTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.tags,
    required this.coverSeed,
    required this.source,
    required this.importedAt,
  });

  /// 唯一 id（导入时生成，前缀 'imp_'）
  final String id;

  /// 模板名称
  final String name;

  /// 分类：'portrait' / 'landscape' / 'food' / 'street' / 'night' / 'macro' / 'still-life'
  final String category;

  /// 标签列表
  final List<String> tags;

  /// picsum.photos 的 seed（用于封面图）
  final String coverSeed;

  /// 来源：'file' / 'link' / 'qr'
  final String source;

  /// 导入时间（毫秒）
  final int importedAt;

  /// 转换为 AllTemplateItem（用于 templates_all_page）
  AllTemplateItem toAllTemplateItem() => AllTemplateItem(
        id: id,
        name: name,
        category: category,
        style: null,
        method: null,
        coverSeed: coverSeed,
        price: 0,
        isCustom: true,
      );

  /// 转换为 CustomTemplate（用于 profile_my_templates_page）
  /// 注意：TemplateCategory 是枚举，需要从 String 映射
  CustomTemplate toCustomTemplate() {
    final cat = _categoryFromString(category);
    return CustomTemplate(
      id: id,
      name: name,
      coverUrl: 'https://picsum.photos/seed/$coverSeed/400/600',
      category: cat,
      tags: tags,
      exposureCompensation: 0,
      iso: 100,
      shutterSpeed: '1/125',
      usageCount: 0,
      isFavorite: false,
    );
  }

  static TemplateCategory _categoryFromString(String s) {
    switch (s) {
      case 'portrait':
        return TemplateCategory.portrait;
      case 'landscape':
        return TemplateCategory.landscape;
      case 'food':
        return TemplateCategory.food;
      case 'street':
        return TemplateCategory.street;
      case 'night':
        return TemplateCategory.night;
      case 'macro':
        return TemplateCategory.macro;
      case 'still-life':
      default:
        return TemplateCategory.stillLife;
    }
  }
}

/// 导入模板的运行时状态管理
class ImportedTemplatesNotifier extends StateNotifier<List<ImportedTemplate>> {
  ImportedTemplatesNotifier() : super(const []);

  /// 添加一个导入的模板
  /// 返回新增的模板 id
  String addTemplate({
    required String name,
    required String category,
    required List<String> tags,
    required String source,
    String? coverSeed,
  }) {
    final id = 'imp_${DateTime.now().millisecondsSinceEpoch}';
    final seed = coverSeed ?? 'imported-$id';
    final tpl = ImportedTemplate(
      id: id,
      name: name,
      category: category,
      tags: tags,
      coverSeed: seed,
      source: source,
      importedAt: DateTime.now().millisecondsSinceEpoch,
    );
    state = [...state, tpl];
    return id;
  }

  /// 删除指定 id 的导入模板
  void removeTemplate(String id) {
    state = state.where((t) => t.id != id).toList();
  }

  /// 清空所有导入模板
  void clear() {
    state = const [];
  }
}

/// Provider：导入模板列表
final importedTemplatesProvider =
    StateNotifierProvider<ImportedTemplatesNotifier, List<ImportedTemplate>>(
  (ref) => ImportedTemplatesNotifier(),
);

/// Provider：导入模板作为 AllTemplateItem 列表（供 templates_all_page 使用）
final importedAllTemplatesProvider = Provider<List<AllTemplateItem>>((ref) {
  final imported = ref.watch(importedTemplatesProvider);
  return imported.map((t) => t.toAllTemplateItem()).toList();
});

/// Provider：导入模板作为 CustomTemplate 列表（供 profile_my_templates_page 使用）
final importedCustomTemplatesProvider = Provider<List<CustomTemplate>>((ref) {
  final imported = ref.watch(importedTemplatesProvider);
  return imported.map((t) => t.toCustomTemplate()).toList();
});
