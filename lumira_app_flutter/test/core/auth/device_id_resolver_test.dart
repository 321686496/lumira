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

  group('compositeDeviceId', () {
    test('同属性组合两次调用结果相同', () {
      final a = compositeDeviceId(parts: ['HUAWEI', 'Mate 60 Pro', null]);
      final b = compositeDeviceId(parts: ['HUAWEI', 'Mate 60 Pro', null]);
      expect(a, b);
      expect(b, startsWith('comp-'));
    });

    test('仅含一个稳定属性也能生成确定性 id', () {
      final a = compositeDeviceId(parts: ['HUAWEI', null, null]);
      final b = compositeDeviceId(parts: ['HUAWEI', null, null]);
      expect(a, b);
    });

    test('全部为空返回空串', () {
      expect(compositeDeviceId(parts: []), '');
      expect(compositeDeviceId(parts: [null, null]), '');
    });
  });

  group('resolveStableDeviceId', () {
    test('osId 非空时优先生效', () {
      expect(
        resolveStableDeviceId(osId: 'ODID-open-123', stableParts: ['HUAWEI', 'Mate']),
        'ODID-open-123',
      );
    });

    test('osId 为空时退回属性聚合哈希', () {
      final id = resolveStableDeviceId(osId: '', stableParts: ['HUAWEI', 'Mate']);
      expect(id, startsWith('comp-'));
    });
  });
}