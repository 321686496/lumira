// lib/features/capture/data/custom_fill_light_colors.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// 用户自定义补光色（可命名、可收藏）
class CustomFillLightColor {
  const CustomFillLightColor({
    required this.name,
    required this.color,
  });

  final String name;
  final Color color;

  Map<String, dynamic> toJson() => {
        'name': name,
        // color.value 在 Flutter 中是 32 位 int（0xAARRGGBB）
        'color': color.value,
      };

  factory CustomFillLightColor.fromJson(Map<String, dynamic> json) {
    return CustomFillLightColor(
      name: (json['name'] as String?) ?? '自定义',
      color: Color((json['color'] as num?)?.toInt() ?? 0xFFFFFFFF),
    );
  }
}

/// 自定义补光色列表 Provider（持久化到本地 JSON 文件）
class CustomFillLightColorsNotifier extends StateNotifier<List<CustomFillLightColor>> {
  CustomFillLightColorsNotifier() : super(const []) {
    _load();
  }

  static const _fileName = 'lumira_custom_fill_light_colors.json';

  Future<void> _load() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_fileName');
      if (!await file.exists()) return;
      final raw = await file.readAsString();
      final list = jsonDecode(raw) as List;
      state = list
          .map((e) => CustomFillLightColor.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_fileName');
      final raw = jsonEncode(state.map((e) => e.toJson()).toList());
      await file.writeAsString(raw);
    } catch (_) {}
  }

  /// 添加自定义颜色
  Future<void> add(String name, Color color) async {
    // 同名则覆盖
    final filtered = state.where((e) => e.name != name).toList();
    filtered.add(CustomFillLightColor(name: name, color: color));
    state = filtered;
    await _persist();
  }

  /// 删除自定义颜色
  Future<void> remove(String name) async {
    state = state.where((e) => e.name != name).toList();
    await _persist();
  }

  /// 修改已有颜色（按 name 匹配，可修改名称和/或颜色）
  Future<void> update(String name, {String? newName, Color? newColor}) async {
    final index = state.indexWhere((e) => e.name == name);
    if (index == -1) return;
    final old = state[index];
    final updated = CustomFillLightColor(
      name: newName ?? old.name,
      color: newColor ?? old.color,
    );
    final newList = List<CustomFillLightColor>.from(state);
    newList[index] = updated;
    state = newList;
    await _persist();
  }
}

final customFillLightColorsProvider = StateNotifierProvider<
    CustomFillLightColorsNotifier, List<CustomFillLightColor>>((ref) {
  return CustomFillLightColorsNotifier();
});
