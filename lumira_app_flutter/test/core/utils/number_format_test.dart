// 单元测试：formatThousands 千分位格式化工具
//
// 函数位置：lib/core/utils/number_format.dart
// 用途：Profile HeroCard 总作品数、Growth LevelCard 经验值等场景的数字格式化
//
// 历史背景：原 `_formatNum`（已废弃）在 4+ 位数字上逗号位置错误，
// 例如 1280 错误返回 "128,0"，2000 错误返回 "200,0"。
// 新的 `formatThousands` 修正了该 bug，正确返回 "1,280" / "2,000"。
// 本测试覆盖该 bug 修复路径以提供回归保护。
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/utils/number_format.dart';

void main() {
  group('formatThousands', () {
    test('0 → "0"', () {
      expect(formatThousands(0), '0');
    });

    test('720 → "720" (3-digit, no comma)', () {
      expect(formatThousands(720), '720');
    });

    test('999 → "999" (boundary, no comma)', () {
      expect(formatThousands(999), '999');
    });

    test('1000 → "1,000" (boundary, single comma)', () {
      expect(formatThousands(1000), '1,000');
    });

    test('1280 → "1,280" (regression: original _formatNum returned "128,0")', () {
      expect(formatThousands(1280), '1,280');
    });

    test('2000 → "2,000" (regression: original _formatNum returned "200,0")', () {
      expect(formatThousands(2000), '2,000');
    });

    test('9999 → "9,999" (4-digit max with one comma)', () {
      expect(formatThousands(9999), '9,999');
    });

    test('10000 → "10,000" (5-digit, one comma)', () {
      expect(formatThousands(10000), '10,000');
    });

    test('1000000 → "1,000,000" (7-digit, two commas)', () {
      expect(formatThousands(1000000), '1,000,000');
    });

    test('1234567 → "1,234,567" (realistic large number)', () {
      expect(formatThousands(1234567), '1,234,567');
    });
  });
}
