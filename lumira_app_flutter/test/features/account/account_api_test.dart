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