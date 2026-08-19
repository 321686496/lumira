import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/auth/auth_controller.dart';

void main() {
  group('fnv1a64Hex', () {
    test('同输入在两次调用中得到相同结果（确定性）', () {
      final a = fnv1a64Hex(['HUAWEI', 'Mate 60 Pro']);
      final b = fnv1a64Hex(['HUAWEI', 'Mate 60 Pro']);
      expect(a, b);
    });

    test('不同输入得到不同结果', () {
      final a = fnv1a64Hex(['A', 'B']);
      final b = fnv1a64Hex(['A', 'C']);
      expect(a, isNot(b));
    });

    test('空输入也能返回非空十六进制串', () {
      expect(fnv1a64Hex([]).length, greaterThan(0));
    });
  });
}