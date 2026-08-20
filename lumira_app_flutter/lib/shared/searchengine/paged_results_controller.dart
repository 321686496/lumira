/// 分页懒渲染控制器：维护已渲染条数 visible，触底追加、防重入、可重置。
class PagedResultsController {
  PagedResultsController({this.pageSize = 20});

  final int pageSize;

  int _visible = 0;
  bool _loading = false;

  int get visible => _visible;
  bool get isLoading => _loading;

  bool hasMore(int total) => _visible < total;

  /// 触底追加一页。loading 中或已到底返回 false（防重入）。
  /// 成功追加后返回 true，调用方应 setState 刷新，再调用 [finishLoading]。
  bool loadMore(int total) {
    if (_loading || !hasMore(total)) return false;
    _loading = true;
    _visible = (_visible + pageSize).clamp(0, total);
    return true;
  }

  /// 追加完成后结束 loading 状态。
  void finishLoading() => _loading = false;

  /// 关键词/范围/筛选/排序变化时重置为第一页。
  void reset() {
    _visible = 0;
    _loading = false;
  }
}
