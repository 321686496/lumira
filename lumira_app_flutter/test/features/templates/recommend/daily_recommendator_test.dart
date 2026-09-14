import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/templates/recommend/daily_recommendator.dart';

void main() {
  test('同一天两次调用结果一致（确定性）', () {
    final ids = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l'];
    final d1 = DailyRecommendator().build(ids, DateTime(2026, 9, 14), cap: 10);
    final d2 = DailyRecommendator().build(ids, DateTime(2026, 9, 14), cap: 10);
    expect(d1.map((x) => x.templateId).toList(),
        d2.map((x) => x.templateId).toList());
  });

  test('不同日期轮换不同且封顶', () {
    final ids = List.generate(20, (i) => 't$i');
    final a = DailyRecommendator().build(ids, DateTime(2026, 9, 14), cap: 10);
    final b = DailyRecommendator().build(ids, DateTime(2026, 9, 15), cap: 10);
    expect(a.length, 10);
    expect(b.length, 10);
    expect(a.map((x) => x.templateId).toList(),
        isNot(b.map((x) => x.templateId).toList()));
  });
}