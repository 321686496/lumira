# Task 10: AccountApi（客户端请求 + 错误映射）

**Files:**
- Create: `lumira_app_flutter/lib/features/account/data/account_api.dart`
- Create: `lumira_app_flutter/test/features/account/account_api_test.dart`

**Interfaces:**
- Consumes: `ApiClient`（`lib/core/network/api_client.dart`，`post<T>(path, {body, required fromJson})` 已核验签名一致）、`apiClientProvider`。
- Produces: `AccountApi`（`rotateRecoverySecret()` / `recoverByQr(secret)` / `sendCode(email,purpose)` / `bindEmail(email,code)` / `recoverByEmail(email,code)`）。

> `ApiClient.post` 签名：`Future<T> post<T>(String path, {Object? body, required T Function(Object? json) fromJson})`。错误已由 ApiClient 内部 `classifyDioError` 映射。

## Step 1: 写单测

创建 `test/features/account/account_api_test.dart`（轻量，聚焦模型 json 解析）：
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/account/data/account_api.dart';

void main() {
  test('RecoveryQr model 解析', () {
    final r = RecoveryQrData.fromJson({
      'secret': 'abc', 'qrPayload': 'lumira://account-recover?v=1&secret=abc', 'expiresAt': 123,
    });
    expect(r.secret, 'abc');
    expect(r.qrPayload, contains('lumira://account-recover'));
  });
}
```

## Step 2: 实现 AccountApi 与模型

创建 `lib/features/account/data/account_api.dart`：
```dart
import '../../../core/network/api_client.dart';

class RecoveryQrData {
  final String secret;
  final String qrPayload;
  final int expiresAt;
  const RecoveryQrData({required this.secret, required this.qrPayload, required this.expiresAt});
  factory RecoveryQrData.fromJson(Map<String, dynamic> j) => RecoveryQrData(
        secret: j['secret'] as String,
        qrPayload: j['qrPayload'] as String,
        expiresAt: (j['expiresAt'] as num).toInt(),
      );
}

class RecoverResult {
  final String deviceId;
  const RecoverResult(this.deviceId);
}

/// 账号保护 / 恢复的客户端 API。
class AccountApi {
  final ApiClient client;
  const AccountApi(this.client);

  Future<RecoveryQrData> rotateRecoverySecret() async {
    final r = await client.post('/account/recovery-qr',
        fromJson: (json) => RecoveryQrData.fromJson(json as Map<String, dynamic>));
    return r;
  }

  Future<RecoverResult> recoverByQr(String secret) async {
    final r = await client.post('/account/recover-by-qr', body: {'secret': secret},
        fromJson: (json) => RecoverResult((json as Map<String, dynamic>)['deviceId'] as String));
    return r;
  }

  Future<void> sendCode({required String email, required String purpose}) async {
    await client.post('/account/email/send-code', body: {'email': email, 'purpose': purpose},
        fromJson: (_) => null);
  }

  Future<void> bindEmail({required String email, required String code}) async {
    await client.post('/account/email/bind', body: {'email': email, 'code': code},
        fromJson: (_) => null);
  }

  Future<RecoverResult> recoverByEmail({required String email, required String code}) async {
    final r = await client.post('/account/email/recover', body: {'email': email, 'code': code},
        fromJson: (json) => RecoverResult((json as Map<String, dynamic>)['deviceId'] as String));
    return r;
  }
}
```

> 页面用法：`AccountApi(await ref.read(apiClientProvider.future))`。

## Step 3: 跑测试

```bash
cd lumira_app_flutter
flutter test test/features/account/account_api_test.dart
```
Expected: PASS。

## Step 4: 提交

```bash
git add lumira_app_flutter/lib/features/account/data/account_api.dart lumira_app_flutter/test/features/account/account_api_test.dart
git commit -m "feat(account): add AccountApi client and models"
```
只提交这两个文件；工作区其他并行改动不要 add。不要 push。工作目录：`d:\app\projects\photo_post`。