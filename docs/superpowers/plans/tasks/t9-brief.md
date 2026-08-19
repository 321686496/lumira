# Task 9: AuthController.recoverAccount + 单测

**Files:**
- Modify: `lumira_app_flutter/lib/core/auth/auth_controller.dart`
- Create: `lumira_app_flutter/test/core/auth/auth_controller_recover_test.dart`

**Interfaces:**
- Consumes: 现 `_doRegister` / `_resolveOs` / `_dao.save` / `_onRegistered`。
- Produces: `Future<bool> recoverAccount(String deviceId)`（Task 12 调）。

## Step 1: 写失败单测

创建 `test/core/auth/auth_controller_recover_test.dart`：
```dart
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
```

## Step 2: 跑单测确认失败

```bash
cd lumira_app_flutter
flutter test test/core/auth/auth_controller_recover_test.dart
```
Expected: FAIL（`recoverAccount` 不存在）。

## Step 3: 实现 recoverAccount

在 `auth_controller.dart` 的 `invalidateRegistration()`（或 registerIfNeeded 附近）之后加方法：
```dart
/// 账号恢复：以目标 [deviceId] 为身份直接注册（新机取回旧标识）。
///
/// 供「恢复账号」页在拿到旧 deviceId 后调用：复用 [_doRegister] 走注册，
/// 把 [AuthRecord] 写库、[AuthState] 置为 registered，旧数据随之恢复。
Future<bool> recoverAccount(String deviceId) async {
  if (deviceId.isEmpty) return false;
  if (_registering) return true; // 已有注册进行中，避免并发覆盖
  final os = _resolveOs();
  final resp = await _doRegister(deviceId: deviceId, os: os);
  final now = DateTime.now().millisecondsSinceEpoch;
  final record = AuthRecord(
    deviceId: deviceId,
    os: os,
    token: resp.token,
    isNewDevice: resp.isNewDevice,
    registeredAt: now,
  );
  await _dao.save(record);
  try {
    await _onRegistered?.call(resp);
  } catch (_) {
    // 资料落库失败不阻塞恢复
  }
  state = AuthState(
    status: AuthStatus.registered,
    token: resp.token,
    deviceId: deviceId,
    os: os,
    isNewDevice: resp.isNewDevice,
  );
  return true;
}
```
> 与 registerIfNeeded 不同：不检查 fresh 状态，强制用目标 deviceId 注册。保持现有 `_registering` 语义不变（不额外 set）。

## Step 4: 跑单测

```bash
cd lumira_app_flutter
flutter test test/core/auth/auth_controller_recover_test.dart
```
Expected: PASS。同时跑一下现有 auth 相关单测确认无回归：`flutter test test/core/auth`。

## Step 5: 提交

```bash
git add lumira_app_flutter/lib/core/auth/auth_controller.dart lumira_app_flutter/test/core/auth/auth_controller_recover_test.dart
git commit -m "feat(account): add AuthController.recoverAccount to take over a deviceId"
```
只提交这两个文件；工作区其他并行改动不要 add。不要 push。工作目录：`d:\app\projects\photo_post`。