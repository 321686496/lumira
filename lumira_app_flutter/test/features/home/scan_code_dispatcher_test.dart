import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/features/home/services/scan_code_dispatcher.dart';

void main() {
  group('ScanCodeDispatcher.classify', () {
    test('模板分享码 LUMIRA- 前缀', () {
      final r = ScanCodeDispatcher.classify('LUMIRA-food-红烧肉');
      expect(r.type, ScanCodeType.templateShareCode);
      expect(r.payload, 'LUMIRA-food-红烧肉');
    });

    test('模板离线链接 lumira://tpl 与 https://lumira.app/tpl', () {
      expect(
        ScanCodeDispatcher.classify('lumira://tpl/aGVsbG8').type,
        ScanCodeType.templateOfflineLink,
      );
      expect(
        ScanCodeDispatcher.classify('https://lumira.app/tpl?name=x&category=food').type,
        ScanCodeType.templateOfflineLink,
      );
    });

    test('模板在线 token lumira://imp 与 https://lumira.app/imp', () {
      final r = ScanCodeDispatcher.classify('lumira://imp/abc123');
      expect(r.type, ScanCodeType.templateOnlineToken);
      expect(r.payload, 'abc123');
      expect(
        ScanCodeDispatcher.classify('https://lumira.app/imp/xyz').type,
        ScanCodeType.templateOnlineToken,
      );
    });

    test('恢复码 account-recover / secret=', () {
      final r1 = ScanCodeDispatcher.classify('lumira://account-recover?v=1&secret=mySecret');
      expect(r1.type, ScanCodeType.recoveryCode);
      expect(r1.payload, 'mySecret');
      expect(
        ScanCodeDispatcher.classify('https://x.app/account-recover?secret=abc').type,
        ScanCodeType.recoveryCode,
      );
      expect(
        ScanCodeDispatcher.classify('some?secret=zzz').type,
        ScanCodeType.recoveryCode,
      );
    });

    test('邀请码 6 位安全字母表（含小写归一化）', () {
      final r = ScanCodeDispatcher.classify('a3b9ck');
      expect(r.type, ScanCodeType.inviteCode);
      expect(r.payload, 'A3B9CK');
      expect(
        ScanCodeDispatcher.classify('A3B9CK').type,
        ScanCodeType.inviteCode,
      );
    });

    test('未知：普通文本 / 过短 / 空串', () {
      expect(ScanCodeDispatcher.classify('hello world').type, ScanCodeType.unknown);
      expect(ScanCodeDispatcher.classify('12').type, ScanCodeType.unknown);
      expect(ScanCodeDispatcher.classify('').type, ScanCodeType.unknown);
      expect(ScanCodeDispatcher.classify('   ').type, ScanCodeType.unknown);
    });

    test('规则顺序：LUMIRA- 优先于邀请码；tpl 优先于 imp', () {
      expect(
        ScanCodeDispatcher.classify('LUMIRA-ABC123').type,
        ScanCodeType.templateShareCode,
      );
      expect(
        ScanCodeDispatcher.classify('https://lumira.app/tpl?u=https://lumira.app/imp/y').type,
        ScanCodeType.templateOfflineLink,
      );
    });
  });
}
