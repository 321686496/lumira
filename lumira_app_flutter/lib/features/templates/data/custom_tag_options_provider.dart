// lib/features/templates/data/custom_tag_options_provider.dart
//
// 候选标签数据源：聚合所有自定义模板（source='custom'）的 tags，
// 去重并按 count 降序，供"选择已有自定义标签或新增标签"的 UI 使用。
// Dart 2.19.6：用类而非 records。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';

/// 一个候选标签选项及其被使用的次数。
class CustomTagOption {
  const CustomTagOption({required this.name, required this.count});

  final String name;
  final int count;
}

/// 从 DB 中聚合自定义模板标签生成的候选选项列表。
final customTagCandidatesProvider =
    FutureProvider<List<CustomTagOption>>((ref) async {
  final dao = await ref.read(templatesDaoProvider.future);
  final custom = await dao.getCustomOnly();
  final freq = <String, int>{};
  for (final t in custom) {
    for (final tag in t.tags) {
      final s = tag.trim();
      if (s.isNotEmpty) freq[s] = (freq[s] ?? 0) + 1;
    }
  }
  final list = freq.entries
      .map((e) => CustomTagOption(name: e.key, count: e.value))
      .toList()
    // count 降序；平局用 name 升序兜底（Dart List.sort 不稳定，需确定性次键）
    ..sort((a, b) {
      final c = b.count.compareTo(a.count);
      return c != 0 ? c : a.name.compareTo(b.name);
    });
  return list;
});