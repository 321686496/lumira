/// 用户标签的搜索/筛选核心纯函数。
/// 不依赖 DB，便于独立单元测试。

/// 大小写不敏感的子串匹配（含全匹配）。
bool containsIgnoreCase(String source, String query) {
  if (query.isEmpty) return true;
  return source.toLowerCase().contains(query.toLowerCase());
}

/// 模板是否命中关键词（匹配名称/分类/系统标签；空关键词恒匹配）。
bool templateMatchesKeyword(
  String name,
  String category,
  List<String> systemTags,
  String keyword,
) {
  if (keyword.trim().isEmpty) return true;
  final candidates = <String>[name, category, ...systemTags];
  return candidates.any((c) => containsIgnoreCase(c, keyword.trim()));
}

/// 场景是否命中关键词（匹配名称/氛围/分类；空关键词恒匹配）。
bool sceneMatchesKeyword(
  String name,
  String vibe,
  String category,
  String keyword,
) {
  if (keyword.trim().isEmpty) return true;
  final candidates = <String>[name, vibe, category];
  return candidates.any((c) => containsIgnoreCase(c, keyword.trim()));
}

/// 从标签（name, count）列表中筛出名称命中关键词的项，保持原顺序。
List<MapEntry<String, int>> filterTagsByKeyword(
  List<MapEntry<String, int>> tags,
  String keyword,
) {
  final q = keyword.trim();
  if (q.isEmpty) return tags;
  return tags.where((e) => containsIgnoreCase(e.key, q)).toList();
}