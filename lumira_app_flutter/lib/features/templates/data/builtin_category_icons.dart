// lib/features/templates/data/builtin_category_icons.dart
//
// 内置 7 类的 Material Icon 映射。
//
// 当 [TemplateCategoryRecord.iconUrl] 为空字符串时，Flutter 端使用此映射回退渲染分类图标。
// spec §5.7 原始设计使用 PhosphorIcons，但项目未引入 phosphor_flutter 依赖，
// 统一使用 Material Icons（与 templates_all_page.dart 现有 _CategoryOverview 一致）。
//
// 后端可通过 iconUrl 字段下发自定义图标 URL（Image.network），
// 为空时回退到此映射，保证离线场景下分类瀑布流永远有图标可展示。

import 'package:flutter/material.dart';

/// 内置 7 类 Material Icon 回退映射。
///
/// key 与 [BuiltinDataSeeder.seedCategories] 中的 7 个系统分类 key 严格对齐：
/// portrait / landscape / food / street / night / macro / still-life。
/// 未命中映射的 key 回退到 [Icons.category_outlined]（调用方负责兜底）。
const Map<String, IconData> builtinCategoryIcons = {
  'portrait': Icons.person_outline,
  'landscape': Icons.landscape_outlined,
  'food': Icons.restaurant_outlined,
  'street': Icons.camera_alt_outlined,
  'night': Icons.nights_stay_outlined,
  'macro': Icons.zoom_in_outlined,
  'still-life': Icons.collections_outlined,
};

/// 默认回退图标（分类 key 不在 [builtinCategoryIcons] 中时使用）。
const IconData fallbackCategoryIcon = Icons.category_outlined;

/// 根据分类 key 获取对应的 Material Icon。
///
/// 优先查 [builtinCategoryIcons]，未命中返回 [fallbackCategoryIcon]。
IconData categoryIconForKey(String key) {
  return builtinCategoryIcons[key] ?? fallbackCategoryIcon;
}
