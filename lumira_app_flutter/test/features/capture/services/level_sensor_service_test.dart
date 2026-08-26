import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/services/level_sensor_service.dart';

void main() {
  group('LevelSensorService.angleFromAccel', () {
    test('水平持机（重力沿 -y）时角度为 0', () {
      expect(LevelSensorService.angleFromAccel(0, -9.8), closeTo(0, 0.001));
    });

    test('右倾（x 为正）时角度为正', () {
      // 45° roll：x=+g, y=-g
      expect(LevelSensorService.angleFromAccel(9.8, -9.8), closeTo(45, 0.001));
      // 小倾角
      final small = LevelSensorService.angleFromAccel(1.7, -9.6);
      expect(small, greaterThan(0));
      expect(small, closeTo(10.04, 0.1));
    });

    test('左倾（x 为负）时角度为负', () {
      expect(LevelSensorService.angleFromAccel(-9.8, -9.8), closeTo(-45, 0.001));
    });
  });

  group('LevelSensorService.emaSmooth', () {
    test('一阶低通滤波：新数据权重为 alpha', () {
      // 0.25 * 0 + 0.75 * 10 = 7.5
      expect(LevelSensorService.emaSmooth(0, 10), closeTo(7.5, 0.001));
      // 0.25 * 8 + 0.75 * 4 = 5
      expect(LevelSensorService.emaSmooth(8, 4), closeTo(5, 0.001));
    });

    test('alpha 可自定义', () {
      expect(LevelSensorService.emaSmooth(10, 0, 0.5), closeTo(5, 0.001));
    });
  });

  group('LevelSensorService.clampAngle', () {
    test('限制在 ±maxDeg 内', () {
      expect(LevelSensorService.clampAngle(30), closeTo(10, 0.001));
      expect(LevelSensorService.clampAngle(-30), closeTo(-10, 0.001));
      expect(LevelSensorService.clampAngle(5), closeTo(5, 0.001));
    });

    test('支持自定义最大角度', () {
      expect(LevelSensorService.clampAngle(20, 15), closeTo(15, 0.001));
    });
  });

  group('LevelReading', () {
    test('fromAccel 构造可用读数并计算角度', () {
      final r = LevelReading.fromAccel(9.8, -9.8);
      expect(r.available, isTrue);
      expect(r.angleDeg, closeTo(45, 0.001));
    });

    test('fromAccel 手机平放（重力沿 z 轴）时返回不可用，气泡回中', () {
      final r = LevelReading.fromAccel(0, 0);
      expect(r.available, isFalse);
      expect(r.angleDeg, 0);
    });

    test('unavailable 为不可用且角度 0', () {
      const r = LevelReading.unavailable;
      expect(r.available, isFalse);
      expect(r.angleDeg, 0);
    });

    test('值相等时 == 成立', () {
      const a = LevelReading(angleDeg: 1.5, available: true);
      const b = LevelReading(angleDeg: 1.5, available: true);
      const c = LevelReading(angleDeg: 2.0, available: true);
      expect(a, equals(b));
      expect(a == c, isFalse);
    });
  });
}
