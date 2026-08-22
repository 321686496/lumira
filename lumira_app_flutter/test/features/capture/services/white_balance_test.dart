import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/services/white_balance.dart';

void main() {
  group('WhiteBalanceSettings', () {
    test('默认是 auto、temperatureK == null、isAuto == true', () {
      const settings = WhiteBalanceSettings();
      expect(settings.mode, WhiteBalanceMode.auto);
      expect(settings.temperatureK, isNull);
      expect(settings.isAuto, isTrue);
    });

    test('copyWith(mode: daylight, temperatureK: 6000) 后 isAuto == false', () {
      const settings = WhiteBalanceSettings();
      final updated = settings.copyWith(
        mode: WhiteBalanceMode.daylight,
        temperatureK: 6000,
      );
      expect(updated.mode, WhiteBalanceMode.daylight);
      expect(updated.temperatureK, 6000);
      expect(updated.isAuto, isFalse);
    });

    test('相等性与 hashCode 一致', () {
      const a = WhiteBalanceSettings(
        mode: WhiteBalanceMode.cloudy,
        temperatureK: 6500,
      );
      const b = WhiteBalanceSettings(
        mode: WhiteBalanceMode.cloudy,
        temperatureK: 6500,
      );
      const c = WhiteBalanceSettings(
        mode: WhiteBalanceMode.cloudy,
        temperatureK: 5000,
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
      expect(a.hashCode, isNot(c.hashCode));
    });
  });
}