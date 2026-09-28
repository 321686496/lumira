import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/services/level_sensor_service.dart';

/// 让流事件（经两级 controller 异步投递）走完。
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.value();
  }
}

/// 下发 App 生命周期状态（与引擎通知同路径：会广播给 WidgetsBindingObserver）。
void _setLifecycle(AppLifecycleState state) {
  // ignore: invalid_use_of_protected_member
  WidgetsBinding.instance.handleAppLifecycleStateChanged(state);
}

/// 可观测「订阅 / 取消」的上游：用于验证门控是否真正释放了上游订阅。
/// 用 broadcast controller，使门控可在回前台后重新订阅。
class _UpstreamProbe {
  _UpstreamProbe() {
    _controller = StreamController<int>.broadcast(
      onListen: () => listenCount++,
      onCancel: () => cancelCount++,
    );
  }

  /// 首次订阅次数（全部取消后再订阅会再次计数）。
  int listenCount = 0;

  /// 全部取消次数（最后一个订阅者取消时计数）。
  int cancelCount = 0;

  late final StreamController<int> _controller;

  Stream<int> get stream => _controller.stream;

  void add(int value) => _controller.add(value);

  void addError(Object error) => _controller.addError(error);

  Future<void> close() => _controller.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('LevelSensorService.sharedGatedSource（共享单订阅 + 前后台门控）', () {
    tearDown(() => _setLifecycle(AppLifecycleState.resumed));

    test('前台：订阅上游并透传事件；唯一消费者取消时释放上游', () async {
      _setLifecycle(AppLifecycleState.resumed);
      final probe = _UpstreamProbe();
      final seen = <int>[];
      final sub = LevelSensorService.sharedGatedSource(() => probe.stream)
          .listen(seen.add);
      await _settle();
      expect(probe.listenCount, 1);

      probe.add(1);
      probe.add(2);
      await _settle();
      expect(seen, <int>[1, 2]);

      await sub.cancel();
      await _settle();
      expect(probe.cancelCount, 1, reason: '唯一消费者退出应释放上游');

      await probe.close();
    });

    test('多消费者共享同一条上游订阅，且都能收到数据（修复同名通道互相覆盖）', () async {
      _setLifecycle(AppLifecycleState.resumed);
      final probe = _UpstreamProbe();
      final shared = LevelSensorService.sharedGatedSource(() => probe.stream);
      final seenA = <int>[];
      final seenB = <int>[];
      final subA = shared.listen(seenA.add);
      final subB = shared.listen(seenB.add);
      await _settle();
      expect(probe.listenCount, 1, reason: '两个消费者只应开一条底层订阅');

      probe.add(5);
      await _settle();
      expect(seenA, <int>[5]);
      expect(seenB, <int>[5], reason: '后订阅者不应顶掉先订阅者的数据');

      // 先退出的消费者不应误释放传感器
      await subA.cancel();
      await _settle();
      expect(probe.cancelCount, 0, reason: '仍有消费者在用时不得释放传感器');
      probe.add(6);
      await _settle();
      expect(seenB, <int>[5, 6]);

      // 全部退出才释放
      await subB.cancel();
      await _settle();
      expect(probe.cancelCount, 1);

      await probe.close();
    });

    test('退到后台：取消上游订阅（释放传感器），下游保持打开；回前台恢复', () async {
      _setLifecycle(AppLifecycleState.resumed);
      final probe = _UpstreamProbe();
      final seen = <int>[];
      var done = false;
      final sub = LevelSensorService.sharedGatedSource(() => probe.stream)
          .listen(seen.add, onDone: () => done = true);
      await _settle();
      expect(probe.listenCount, 1);

      _setLifecycle(AppLifecycleState.paused);
      await _settle();
      expect(probe.cancelCount, 1, reason: '退到后台必须释放传感器订阅');
      expect(done, isFalse, reason: '下游不应被关闭');

      _setLifecycle(AppLifecycleState.inactive);
      await _settle();
      expect(probe.cancelCount, 1, reason: '已释放，不应重复取消');

      _setLifecycle(AppLifecycleState.resumed);
      await _settle();
      expect(probe.listenCount, 2, reason: '回前台应重新订阅');

      probe.add(7);
      await _settle();
      expect(seen, <int>[7]);

      await sub.cancel();
      await _settle();
      await probe.close();
    });

    test('后台发起订阅：不启动上游，回前台才启动', () async {
      _setLifecycle(AppLifecycleState.paused);
      final probe = _UpstreamProbe();
      final sub = LevelSensorService.sharedGatedSource(() => probe.stream)
          .listen((_) {});
      await _settle();
      expect(probe.listenCount, 0, reason: '后台不应占用传感器');

      _setLifecycle(AppLifecycleState.resumed);
      await _settle();
      expect(probe.listenCount, 1);

      await sub.cancel();
      await _settle();
      await probe.close();
    });

    test('上游自然结束：不关闭下游（共享单例不得被一次性事件关闭）', () async {
      _setLifecycle(AppLifecycleState.resumed);
      final probe = _UpstreamProbe();
      var done = false;
      final sub = LevelSensorService.sharedGatedSource(() => probe.stream)
          .listen((_) {}, onDone: () => done = true);
      await _settle();

      await probe.close();
      await _settle();
      expect(done, isFalse, reason: '共享单例不能被上游结束关闭');

      await sub.cancel();
    });

    test('上游出错：错误转发给下游，由其各自降级', () async {
      _setLifecycle(AppLifecycleState.resumed);
      final probe = _UpstreamProbe();
      Object? error;
      final sub = LevelSensorService.sharedGatedSource(() => probe.stream)
          .listen((_) {}, onError: (Object e) => error = e);
      await _settle();

      probe.addError(StateError('sensor failed'));
      await _settle();
      expect(error, isA<StateError>());

      await sub.cancel();
      await probe.close();
    });
  });
}
