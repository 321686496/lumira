/// 排序方式。
enum SearchSort {
  comprehensive, // 综合（默认）
  hot, // 火爆程度
  latest, // 最新
  photos, // 拍摄照片数
  name, // 名称
}

/// 价格筛选（template 专用）。
enum SearchPriceFilter { all, free, paid }

/// 搜索筛选状态。
/// 字段刻意用 String（category/sceneStyle/academyTopic/academyLevel 都是 key/枚举名），
/// 使本文件不依赖任何业务模型，保持 shared 层解耦。
class SearchFilters {
  SearchSort sort;
  String? category; // template: 分类 key（模板分类）
  String? sceneCategory; // scene: 分类（与模板分类解耦，供「全部」并列使用）
  String? sceneStyle; // scene: 风格
  String? academyTopic; // academy: 主题枚举名（portrait/landscape/stillLife/street）
  String? academyLevel; // academy: 等级枚举名（beginner/intermediate/advanced）
  SearchPriceFilter price; // template 专用
  bool ownedOnly; // template 专用：仅我拥有的
  Set<int> userTagIds; // 通用：用户标签 AND

  SearchFilters({
    this.sort = SearchSort.comprehensive,
    this.category,
    this.sceneCategory,
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
    String? Function()? sceneCategory,
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
      sceneCategory:
          sceneCategory != null ? sceneCategory() : this.sceneCategory,
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

  /// 是否存在任一非默认筛选条件（用于工具栏筛选项激活高亮）。
  bool get hasActiveConditions =>
      category != null ||
      sceneCategory != null ||
      sceneStyle != null ||
      academyTopic != null ||
      academyLevel != null ||
      price != SearchPriceFilter.all ||
      ownedOnly ||
      userTagIds.isNotEmpty;
}
