import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/auth/auth_controller.dart';
import 'package:lumira_app_flutter/core/auth/auth_dao.dart';

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

  group('defaultResolveDeviceId', () {
    test('无本地记录时，用注入采集到的 ODID 作为 deviceId', () async {
      final id = await defaultResolveDeviceId(
        _ResolverFakeDao(initial: null),
        collect: (platform) async {
          expect(platform, defaultResolveOs());
          return const DeviceAttributes(
            osId: 'ODID-open-123',
            stableParts: ['HUAWEI', 'Mate 60 Pro'],
          );
        },
      );
      expect(id, 'ODID-open-123');
    });

    test('有本地记录时优先复用本地 deviceId，不触发采集', () async {
      var collected = false;
      final id = await defaultResolveDeviceId(
        _ResolverFakeDao(initial: 'saved-device'),
        collect: (platform) async {
          collected = true;
          return const DeviceAttributes(osId: 'ODID-other');
        },
      );
      expect(id, 'saved-device');
      expect(collected, false);
    });

    test('osId 与稳定属性全空时落到 fallback（非确定值）', () async {
      final a = await defaultResolveDeviceId(
        _ResolverFakeDao(initial: null),
        collect: (platform) async => const DeviceAttributes(),
      );
      final b = await defaultResolveDeviceId(
        _ResolverFakeDao(initial: null),
        collect: (platform) async => const DeviceAttributes(),
      );
      expect(a, startsWith('fallback-'));
      expect(a, isNot(b)); // 时间戳不同 → 两次不同（记录为已知局限）
    });

    test('无法采集时（collect 抛异常）仍回退到聚合哈希或 fallback', () async {
      final id = await defaultResolveDeviceId(
        _ResolverFakeDao(initial: null),
        collect: (platform) async => throw Exception('plugin down'),
      );
      expect(id, isNotEmpty);
    });
  });
}

class _ResolverFakeDao implements AuthDaoLike {
  final String? savedDeviceId;
  _ResolverFakeDao({String? initial}) : savedDeviceId = initial;

  @override
  Future<AuthRecord?> load() async {
    if (savedDeviceId == null) return null;
    return AuthRecord(
      deviceId: savedDeviceId!,
      os: 'harmonyos',
      token: 'jwt',
      isNewDevice: false,
      registeredAt: 1700000000,
    );
  }

  @override
  Future<void> save(AuthRecord r) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<void> clearToken() async {}
}