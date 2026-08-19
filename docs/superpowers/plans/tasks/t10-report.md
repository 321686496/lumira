# Task 10 Report: AccountApi（客户端请求 + 错误映射）

## Status: DONE

## TDD 证据

### RED（先写测试，确认失败）
创建 `test/features/account/account_api_test.dart` 后运行：

```
test/features/account/account_api_test.dart:2:8: Error: Error when reading 'lib/features/account/data/account_api.dart': 系统找不到指定的路径。
test/features/account/account_api_test.dart:6:15: Error: Undefined name 'RecoveryQrData'.
00:00 +0 -1: Some tests failed.
```
→ 编译失败，验证了 `RecoveryQrData` / `account_api.dart` 尚不存在，符合预期 RED。

### GREEN（实现后运行通过）
创建 `lib/features/account/data/account_api.dart` 后运行：

```
00:00 +0: RecoveryQr model 解析
00:00 +1: All tests passed!
```
退出码 0，测试通过。

## 变更文件
- 新增 `lumira_app_flutter/lib/features/account/data/account_api.dart`
- 新增 `lumira_app_flutter/test/features/account/account_api_test.dart`

## 提交
- `a4f542c` `feat(account): add AccountApi client and models`（仅含上述 2 个文件，未包含工作区并行改动，未 push）

## 自审（Self-review）
- `ApiClient.post` 实际签名（`Future<T> post<T>(String path, {Object? body, required T Function(Object? json) fromJson})`）与 brief 一致，`AccountApi` 五个方法（`rotateRecoverySecret` / `recoverByQr` / `sendCode` / `bindEmail` / `recoverByEmail`）全部复用该签名。
- `RecoveryQrData.fromJson` 对 `expiresAt` 使用 `(j['expiresAt'] as num).toInt()` 兼容 int/double；测试传入 int 123 通过。
- 错误映射由 `ApiClient` 内部 `classifyDioError` 处理，AccountApi 层不重复包装，符合"错误映射已由底层完成"的设计。
- 空返回方法（`sendCode` / `bindEmail`）用 `fromJson: (_) => null` 落在 `post<void>` 上，无返回值包装，合理。
- 依赖 `apiClientProvider`（FutureProvider<ApiClient>），页面用法 `AccountApi(await ref.read(apiClientProvider.future))` 与 brief 一致。