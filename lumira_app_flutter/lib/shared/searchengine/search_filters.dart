/// 排序方式。
enum SearchSort { comprehensive, hot, latest }

/// 价格筛选（template 专用）。
enum SearchPriceFilter { all, free, paid }

/// 搜索筛选状态。
/// 字段刻意用 String（category/sceneStyle/academyTopic/academyLevel 都是 key/枚举名），
/// 使本文件不依赖任何业务模型，保持 shared 层解耦。
class SearchFilters {
  SearchSort sort;
  String? category; // template: 分类 key；scene: 分类（复用同一字段）
  String? sceneStyle; // scene: 风格
  String? academyTopic; // academy: 主题枚举名（portrait/landscape/stillLife/street）
  String? academyLevel; // academy: 等级枚举名（beginner/intermediate/advanced）
  SearchPriceFilter price; // template 专用
  bool ownedOnly; // template 专用：仅我拥有的
  Set<int> userTagIds; // 通用：用户标签 AND

  SearchFilters({
    this.sort = SearchSort.comprehensive,
    this.category,
    this.sceneStyle,
    this.academyTopic,
    this.academyLevel,
    this.price = SearchPriceFilter.all,
    this.ownedOnly = false,
    Set<int>? userTagIds,
  }) : userTagIds = userTagIds ?? <int>{};

  SearchFilters copyWith({
    SearchSort? sort,
    String? Function()? category,
    String? Function()? sceneStyle,
    String? Function()? academyTopic,
    String? Function()? academyLevel,
    SearchPriceFilter? price,
    bool? ownedOnly,
    Set<int>? userTagIds,
  }) {
    return SearchFilters(
      sort: sort ?? this.sort,
      category: category != null ? category() : this.category,
      sceneStyle: sceneStyle != null ? sceneStyle() : this.sceneStyle,
      academyTopic: academyTopic != null ? academyTopic() : this.academyTopic,
      academyLevel: academyLevel != null ? academyLevel() : this.academyLevel,
      price: price ?? this.price,
      ownedOnly: ownedOnly ?? this.ownedOnly,
      userTagIds: userTagIds ?? this.userTagIds,
    );
  }

  /// 重置为默认（不重置 sort，只重置条件）。
  SearchFilters reset() => SearchFilters(sort: sort);
}
