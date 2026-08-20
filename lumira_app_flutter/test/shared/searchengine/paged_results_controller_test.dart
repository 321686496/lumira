import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/shared/searchengine/paged_results_controller.dart';

void main() {
  test('初始 visible=0，hasMore 判定', () {
    final c = PagedResultsController(pageSize: 20);
    expect(c.visible, 0);
    expect(c.hasMore(0), isFalse);
    expect(c.hasMore(45), isTrue);
  });

  test('loadMore 追加一页并 clamp 到总数', () {
    final c = PagedResultsController(pageSize: 20);
    expect(c.loadMore(45), isTrue);
    expect(c.visible, 20);
    c.finishLoading();
    expect(c.loadMore(45), isTrue);
    expect(c.visible, 40);
    c.finishLoading();
    expect(c.loadMore(45), isTrue);
    expect(c.visible, 45); // clamp 到 total
    c.finishLoading();
    expect(c.loadMore(45), isFalse); // 已到底
  });

  test('loading 中防重入（第二次 loadMore 忽略）', () {
    final c = PagedResultsController(pageSize: 20);
    expect(c.loadMore(100), isTrue);
    expect(c.visible, 20);
    expect(c.loadMore(100), isFalse); // 防重入
    expect(c.visible, 20);
    c.finishLoading();
  });

  test('reset 回到第一页并清除 loading', () {
    final c = PagedResultsController(pageSize: 20);
    c.loadMore(100);
    c.reset();
    expect(c.visible, 0);
    expect(c.isLoading, isFalse);
    expect(c.hasMore(100), isTrue);
  });
}
