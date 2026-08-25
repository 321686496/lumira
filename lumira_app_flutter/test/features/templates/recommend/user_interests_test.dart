import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/templates/recommend/user_interests.dart';

void main() {
  test('computeNewScore: 无历史 = 仅 weight', () {
    final s = InterestService.computeNewScore(
      existing: null, lastAt: null, nowMs: 0, weight: 3.0, halfLifeDays: 14,
    );
    expect(s, 3.0);
  });

  test('computeNewScore: 半衰期衰减后再加权重', () {
    // existing=10，半个半衰期(7天)后 → 10*0.5^(7/14)=7.07，再加 1
    const day = 24 * 3600 * 1000;
    final s = InterestService.computeNewScore(
      existing: 10.0, lastAt: 0, nowMs: 7 * day, weight: 1.0, halfLifeDays: 14,
    );
    expect(s, closeTo(8.071, 0.001));
  });
}