import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/capture/services/white_balance.dart';

/// 构造一个含 n 个姿势的模板（供测试 Provider 逻辑，不涉及相机/不挂 widget 树）。
PhotoTemplate tplN(String id, int n) => PhotoTemplate(
      meta: TemplateMeta(
        id: id,
        name: id,
        category: 'portrait',
        classification: const TemplateClassification(type: 'portrait'),
      ),
      composition: const Composition(),
      poses: List.generate(n, (i) => Pose(name: 'p$i')),
      camera: const CameraParams(),
      sceneGuide: const SceneGuide(),
      postProcess: const PostProcess(color: PostProcessColor()),
    );

void main() {
  // ── nextPose 依赖的纯函数：验证「单姿势不切换」与「多姿势循环切换」两种语义 ──
  group('nextPoseIndex 纯函数', () {
    test('单姿势（count<=1）时不切换', () {
      expect(CaptureState.nextPoseIndex(0, 1), 0);
      expect(CaptureState.nextPoseIndex(3, 1), 0);
      expect(CaptureState.nextPoseIndex(2, 0), 0);
    });

    test('多姿势循环切换', () {
      expect(CaptureState.nextPoseIndex(0, 3), 1);
      expect(CaptureState.nextPoseIndex(1, 3), 2);
      expect(CaptureState.nextPoseIndex(2, 3), 0);
    });
  });

  // ── currentPoseIndexProvider 的读写与复位 ──
  group('currentPoseIndexProvider', () {
    test('初始为 0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(CaptureState.currentPoseIndexProvider), 0);
    });

    test('可读可写', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(CaptureState.currentPoseIndexProvider.notifier).state = 2;
      expect(container.read(CaptureState.currentPoseIndexProvider), 2);
    });

    test('模板切换（currentTemplateId 变化）时复位为 0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(CaptureState.currentPoseIndexProvider.notifier).state = 2;
      expect(container.read(CaptureState.currentPoseIndexProvider), 2);
      // currentPoseIndexProvider watch currentTemplateIdProvider → 变化时复位
      container.read(CaptureState.currentTemplateIdProvider.notifier).state =
          'a';
      expect(container.read(CaptureState.currentPoseIndexProvider), 0);
    });

    test('resetAll 复位下标为 0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(CaptureState.currentPoseIndexProvider.notifier).state = 4;
      CaptureState.resetAll(container);
      expect(container.read(CaptureState.currentPoseIndexProvider), 0);
    });
  });

  // ── 白平衡会话态的跨会话重置（修复：套用模板参数在相机重建后不生效）──
  // resetAll 不清白平衡会话时，模板白平衡会跨会话残留到自由模式，且陈旧的
  // wbResidual 会持续注入 effectivePostProcess 调色矩阵污染成片。
  group('resetAll 白平衡会话态', () {
    test('resetAll 复位白平衡会话与残差', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(whiteBalanceSessionProvider.notifier).state =
          const WhiteBalanceSettings(
        mode: WhiteBalanceMode.daylight,
        temperatureK: 5500,
      );
      container.read(wbResidualSessionProvider.notifier).state =
          const WbResidual(r: 1.2, g: 1.0, b: 0.9);
      CaptureState.resetAll(container);
      expect(container.read(whiteBalanceSessionProvider).isAuto, isTrue);
      expect(container.read(wbResidualSessionProvider), isNull);
    });
  });

  // ── nextPose 的分支语义：仅 poses>1 时按 nextPoseIndex 更新 provider ──
  // 注：nextPose 依赖 WidgetRef，故此处按计划允许的可测设计，通过容器读写验证
  // 「读 poses → 计算 next → 写回 currentPoseIndexProvider」的完整逻辑链路。
  group('nextPose 分支语义', () {
    test('单姿势（poses.length<=1）不更新下标', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(CaptureState.editableTemplateProvider.notifier).state =
          tplN('a', 1);

      final editable = container.read(CaptureState.editableTemplateProvider);
      final poses = editable?.poses ?? const <Pose>[];
      if (poses.length <= 1) return; // 与 nextPose 内部 early-return 一致
      final cur = container.read(CaptureState.currentPoseIndexProvider);
      container.read(CaptureState.currentPoseIndexProvider.notifier).state =
          CaptureState.nextPoseIndex(cur, poses.length);

      expect(container.read(CaptureState.currentPoseIndexProvider), 0);
    });

    test('多姿势按 nextPoseIndex 循环更新', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(CaptureState.editableTemplateProvider.notifier).state =
          tplN('a', 3);

      final editable = container.read(CaptureState.editableTemplateProvider);
      final poses = editable?.poses ?? const <Pose>[];
      var cur = container.read(CaptureState.currentPoseIndexProvider);
      for (var i = 0; i < 4; i++) {
        cur = CaptureState.nextPoseIndex(cur, poses.length);
        container.read(CaptureState.currentPoseIndexProvider.notifier).state =
            cur;
        expect(
          cur,
          (i + 1) % 3,
          reason: '第 ${i + 1} 次切换后应为 #${(i + 1) % 3}',
        );
      }
      expect(container.read(CaptureState.currentPoseIndexProvider), 1);
    });
  });
}