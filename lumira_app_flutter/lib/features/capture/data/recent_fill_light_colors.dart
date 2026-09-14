import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// 用户拍过照片的自定义补光色历史（按最近使用排序，最多保留三条）。
class RecentFillLightColors {
  const RecentFillLightColors._();

  static const int limit = 3;

  static List<Color> recordUse(
    List<Color> history,
    Color color, {
    int maxCount = limit,
  }) {
    return <Color>[
      color,
      ...history.where((item) => item.value != color.value),
    ].take(maxCount).toList();
  }
}

class RecentFillLightColorsNotifier extends StateNotifier<List<Color>> {
  RecentFillLightColorsNotifier() : super(const []) {
    _loadFuture = _load();
  }

  static const _fileName = 'lumira_recent_fill_light_colors.json';

  late final Future<void> _loadFuture;

  Future<void> _load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final list = jsonDecode(await file.readAsString()) as List;
      state = list
          .map((item) => Color((item as num).toInt()))
          .toList(growable: false);
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode(state.map((item) => item.value).toList()));
    } catch (_) {}
  }

  Future<File> _file() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<void> recordUse(Color color) async {
    await _loadFuture;
    state = RecentFillLightColors.recordUse(state, color);
    await _persist();
  }
}

final recentFillLightColorsProvider = StateNotifierProvider<
    RecentFillLightColorsNotifier, List<Color>>((ref) {
  return RecentFillLightColorsNotifier();
});
