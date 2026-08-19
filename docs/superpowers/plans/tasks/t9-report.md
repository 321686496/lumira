# Task 9 报告: AuthController.recoverAccount + 单测

## 状态
DONE

## 完成内容
在 `AuthController` 上新增 `recoverAccount(String deviceId) -> Future<bool>`：

- 空 deviceId 直接返回 `false`，不触发注册。
- 若已有注册进行中（`_registering`）直接返回 `true`，避免并发覆盖。
- 复用 `_doRegister(deviceId: deviceId, os: _resolveOs())` 走注册，强制以目标 deviceId 为身份（不检查 fresh 状态，与 registerIfNeeded 的语义区别）。
- 把 `AuthRecord` 写库（`_dao.save`），`_onRegistered?.call` 落资料（失败捕获不阻塞）。
- `state` 置为 `registered`，携带 token / deviceId / os / isNewDevice。

## 修改文件
- 修改: `lumira_app_flutter/lib/core/auth/auth_controller.dart`（+33 行）
- 新增: `lumira_app_flutter/test/core/auth/auth_controller_recover_test.dart`（+52 行）

## TDD 证据

### Step 2 — RED（实现前跑单测）
`flutter test test/core/auth/auth_controller_recover_test.dart`
```
test/core/auth/auth_controller_recover_test.dart:28:33: Error: The method 'recoverAccount' isn't defined for the class 'AuthController'.
    final ok = await controller.recoverAccount('old-device-123');
                                ^^^^^^^^^^^^^^
test/core/auth/auth_controller_recover_test.dart:48:33: Error: The method 'recoverAccount' isn't defined for the class 'AuthController'.
    final ok = await controller.recoverAccount('');
                                ^^^^^^^^^^^^^^
00:00 +0 -1: loading ... [E]
  Failed to load "...auth_controller_recover_test.dart": Compilation failed for testPath=...
00:00 +0 -1: Some tests failed.
```
确认为编译失败（方法不存在）。

### Step 4 — GREEN（实现后跑全套 auth 单测）
`flutter test test/core/auth`
```
00:00 +1: ... recoverAccount 用目标 deviceId 触发注册并落库
00:00 +2: ... recoverAccount 空 deviceId 直接返回 false 不注册
...（auth_controller_test + device_id_resolver_test 原有 19 条全部通过）
00:00 +21: All tests passed!
```
2 个新用例 + 19 个既有用例 = 21 全绿，无回归。

## 提交
只提交了 2 个目标文件，未 push，并行会话的未提交改动（main.dart / lumira_toast.dart / EntryAbility.ets / checkin & tags 相关等）均未被 add/commit。

```
3dcbb74 feat(account): add AuthController.recoverAccount to take over a deviceId
 .../lib/core/auth/auth_controller.dart          | 33 ++++++++++++++
 .../core/auth/auth_controller_recover_test.dart | 52 ++++++++++++++++++++++
 2 files changed, 85 insertions(+)
```

## 自审
- [x] 逐字匹配 brief 指定的接口签名与实现逻辑（含 `_registering` 语义保持一致，不额外 set）。
- [x] 空 deviceId 守卫 + 并发保护齐全。
- [x] 测试用例覆盖成功路径与空 deviceId 边界路径。
- [x] RED → GREEN 证据完整，全套 auth 测试通过。
- [x] 仅提交 2 个目标文件，工作区其他并行改动完好。
- [ ] 未 push（按 brief 要求，不推送）。
- 说明：实现与 `registerIfNeeded` 高度相似（复用同一流程），属 brief 明确指定的设计，无重复抽象问题。