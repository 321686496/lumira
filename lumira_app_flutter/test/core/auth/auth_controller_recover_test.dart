import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/auth/auth_controller.dart';
import 'package:lumira_app_flutter/core/auth/auth_dao.dart';
import 'package:lumira_app_flutter/core/auth/auth_state.dart';

class _FakeDao implements AuthDaoLike {
  AuthRecord? saved;
  @override Future<AuthRecord?> load() async => saved;
  @override Future<void> save(AuthRecord r) async => saved = r;
  @override Future<void> clear() async => saved = null;
  @override Future<void> clearToken() async {
    if (saved != null) saved = AuthRecord(
      deviceId: saved!.deviceId, os: saved!.os, token: '', isNewDevice: saved!.isNewDevice, registeredAt: saved!.registeredAt);
  }
}

void main() {
  test('recoverAccount 用目标 deviceId 触发注册并落库', () async {
    final dao = _FakeDao();
    final controller = AuthController(
      dao: dao,
      resolveDeviceId: () async => 'local-device',
      resolveOs: () => 'android',
      doRegister: ({required deviceId, required os}) async =>
          RegisterResult(token: 'tok-$deviceId', isNewDevice: true, profile: null),
    );
    await controller.bootstrap(); // fresh
    final ok = await controller.recoverAccount('old-device-123');
    expect(ok, isTrue);
    expect(controller.state.status, AuthStatus.registered);
    expect(controller.state.deviceId, 'old-device-123');
    expect(controller.state.token, 'tok-old-device-123');
    expect(dao.saved?.deviceId, 'old-device-123');
  });

  test('recoverAccount 空 deviceId 直接返回 false 不注册', () async {
    final dao = _FakeDao();
    var called = false;
    final controller = AuthController(
      dao: dao,
      resolveDeviceId: () async => '',
      resolveOs: () => 'android',
      doRegister: ({required deviceId, required os}) async {
        called = true;
        return RegisterResult(token: 't', isNewDevice: true, profile: null);
      },
    );
    final ok = await controller.recoverAccount('');
    expect(ok, isFalse);
    expect(called, isFalse);
  });
}