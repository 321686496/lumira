import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/auth/auth_controller.dart';
import 'package:lumira_app_flutter/core/auth/auth_dao.dart';
import 'package:lumira_app_flutter/core/auth/auth_state.dart';

void main() {
  group('AuthController', () {
    test('initial state is loading', () {
      final ctrl = AuthController(
        dao: _FakeDao(),
        resolveDeviceId: () async => 'test-id',
        resolveOs: () => 'android',
        doRegister: ({required deviceId, required os}) async =>
            RegisterResult(token: 'jwt', isNewDevice: true),
      );
      expect(ctrl.state.status, AuthStatus.loading);
    });

    test('bootstrap with no saved record sets status to fresh', () async {
      final ctrl = AuthController(
        dao: _FakeDao(initialRecord: null),
        resolveDeviceId: () async => 'test-id',
        resolveOs: () => 'android',
        doRegister: ({required deviceId, required os}) async =>
            RegisterResult(token: 'jwt', isNewDevice: true),
      );
      await ctrl.bootstrap();
      expect(ctrl.state.status, AuthStatus.fresh);
      expect(ctrl.state.needsRegistration, true);
    });

    test('bootstrap with saved record sets status to registered', () async {
      final saved = AuthRecord(
        deviceId: 'saved-id',
        os: 'ios',
        token: 'saved-jwt',
        isNewDevice: false,
        registeredAt: 1700000000,
      );
      final ctrl = AuthController(
        dao: _FakeDao(initialRecord: saved),
        resolveDeviceId: () async => 'test-id',
        resolveOs: () => 'android',
        doRegister: ({required deviceId, required os}) async =>
            RegisterResult(token: 'jwt', isNewDevice: true),
      );
      await ctrl.bootstrap();
      expect(ctrl.state.status, AuthStatus.registered);
      expect(ctrl.state.isReady, true);
      expect(ctrl.state.token, 'saved-jwt');
      expect(ctrl.state.deviceId, 'saved-id');
      expect(ctrl.currentToken, 'saved-jwt');
    });

    test('registerIfNeeded from fresh state succeeds', () async {
      final ctrl = AuthController(
        dao: _FakeDao(initialRecord: null),
        resolveDeviceId: () async => 'new-id',
        resolveOs: () => 'android',
        doRegister: ({required deviceId, required os}) async =>
            RegisterResult(token: 'new-jwt', isNewDevice: true),
      );
      await ctrl.bootstrap();
      await ctrl.registerIfNeeded();
      expect(ctrl.state.status, AuthStatus.registered);
      expect(ctrl.state.token, 'new-jwt');
      expect(ctrl.state.isNewDevice, true);
    });

    test('registerIfNeeded on failure sets status to failed', () async {
      final ctrl = AuthController(
        dao: _FakeDao(initialRecord: null),
        resolveDeviceId: () async => 'new-id',
        resolveOs: () => 'android',
        doRegister: ({required deviceId, required os}) async {
          throw Exception('network down');
        },
      );
      await ctrl.bootstrap();
      await ctrl.registerIfNeeded();
      expect(ctrl.state.status, AuthStatus.failed);
      expect(ctrl.state.lastError, contains('network down'));
    });

    test('invalidateRegistration clears state and dao', () async {
      final saved = AuthRecord(
        deviceId: 'saved-id',
        os: 'ios',
        token: 'saved-jwt',
        isNewDevice: false,
        registeredAt: 1700000000,
      );
      final dao = _FakeDao(initialRecord: saved);
      final ctrl = AuthController(
        dao: dao,
        resolveDeviceId: () async => 'new-id',
        resolveOs: () => 'android',
        doRegister: ({required deviceId, required os}) async =>
            RegisterResult(token: 'jwt', isNewDevice: true),
      );
      await ctrl.bootstrap();
      ctrl.invalidateRegistration();
      expect(ctrl.state.status, AuthStatus.fresh);
      expect(ctrl.state.token, isNull);
      expect(dao.cleared, true);
    });

    test('registerIfNeeded skips when already registered', () async {
      var registerCallCount = 0;
      final saved = AuthRecord(
        deviceId: 'saved-id',
        os: 'ios',
        token: 'saved-jwt',
        isNewDevice: false,
        registeredAt: 1700000000,
      );
      final ctrl = AuthController(
        dao: _FakeDao(initialRecord: saved),
        resolveDeviceId: () async => 'new-id',
        resolveOs: () => 'android',
        doRegister: ({required deviceId, required os}) async {
          registerCallCount++;
          return RegisterResult(token: 'new-jwt', isNewDevice: false);
        },
      );
      await ctrl.bootstrap();
      await ctrl.registerIfNeeded();
      expect(registerCallCount, 0); // 未触发注册
      expect(ctrl.state.status, AuthStatus.registered);
      expect(ctrl.state.token, 'saved-jwt'); // 仍是旧 token
    });
  });
}

class _FakeDao implements AuthDaoLike {
  AuthRecord? _record;
  bool cleared = false;

  _FakeDao({AuthRecord? initialRecord}) : _record = initialRecord;

  @override
  Future<AuthRecord?> load() async => _record;

  @override
  Future<void> save(AuthRecord r) async {
    _record = r;
    cleared = false;
  }

  @override
  Future<void> clear() async {
    _record = null;
    cleared = true;
  }
}
