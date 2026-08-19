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