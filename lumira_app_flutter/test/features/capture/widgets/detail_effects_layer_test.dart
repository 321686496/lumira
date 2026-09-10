import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumira_app_flutter/features/capture/widgets/detail_effects_layer.dart';

/// DetailEffectsLayer 回归测试。
///
/// 2026-09-10 修复：CustomPaint.painter 绘制在 child **之下**（SDK
/// RenderCustomPaint.paint 顺序：painter → super.paint(child) →
/// foregroundPainter）。旧实现给 CustomPaint 挂了 `child: fallback()`
/// （不透明原图）——原图恰好铺满同比例画布时 shader 输出被完全遮盖，
/// 表现为「细节栏调整锐化/磨皮/暗角/颗粒无实时变化」；拉腿时画布比例
/// 变化导致 child 上下留边，shader 从边缘露出，表现为「照片下还有一张
/// 有变化的照片」重影。修复后 CustomPaint 不携带 child。
///
/// 测试环境注意（FakeAsync 三条铁律）：
/// 1. testWidgets 运行于 FakeAsync 假异步区，引擎异步（图像解码 /
///    FragmentProgram / ImmutableBuffer）不会自行完成——必须用
///    tester.runAsync 驱动真实事件循环；
/// 2. 若 FutureBuilder 的 future（loadGrainNoiseTile）首次创建发生在
///    FakeAsync 的 build 内，其引擎回调永远不会派发（真实时钟已暂停）
///    → 永远 waiting → shader 画布永不出现。因此必须在 pumpWidget 之前
///    于 runAsync 中预热进程级噪声 tile 单例；
/// 3. 进程级单例（噪声 tile / shader 程序）的 future 一旦在某个测试的
///    FakeAsync 区完成，后续测试再 await 该 future 时，续体可能滞留在
///    已销毁的旧 zone 永不调度（实测第 2 个 testWidgets 拿不到画布，
///    单独运行却通过）。因此本文件只保留 **一个** testWidgets，
///    「无 child」与「参数更新」两断言合并在同一测试内完成。
void main() {
  late Directory tempDir;
  late String photoPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('detail_fx_layer_test');
    final image = img.Image(width: 64, height: 64);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        image.setPixelRgb(x, y, 200, 120, 90);
      }
    }
    photoPath = '${tempDir.path}${Platform.pathSeparator}photo.png';
    File(photoPath).writeAsBytesSync(img.encodePng(image));
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  /// 精确匹配本层的 CustomPaint（painter 为 DetailEffectsPainter）。
  /// 注意：MaterialApp 内部还有别的 CustomPaint（debug banner 等），
  /// find.byType(CustomPaint) 会命中非目标节点，必须按 painter 类型定位。
  final canvasFinder = find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter is DetailEffectsPainter,
  );

  testWidgets('shader 画布无 child 且 effects 变化时更新 painter 参数',
      (tester) async {
    // 1) 预热进程级噪声 tile 单例（真实事件循环）：必须发生在首次 build
    //    前，否则 FutureBuilder 拿到的是 FakeAsync 区创建、永不完成的
    //    future，shader 画布永远不会出现。
    await tester.runAsync(() async {
      await loadGrainNoiseTile();
    });

    await tester.pumpWidget(MaterialApp(
      home: DetailEffectsLayer(
        url: photoPath,
        effects: const DetailEffectsParams(vignette: 50),
        fallback: () => const SizedBox.expand(),
      ),
    ));

    // 2) 驱动真实事件循环：源图解码 + shader 程序加载（initState 发起）。
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(seconds: 1));
    });
    await tester.pump(); // img+prog 就绪 → FutureBuilder（已完成 future）
    await tester.pump(); // 微任务冲刷 → noise snapshot.hasData → 画布
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 30));

    // 3) 回归断言一：shader 画布已渲染，且 CustomPaint 不携带 child。
    expect(canvasFinder, findsOneWidget,
        reason: '解码 + shader 加载 + 噪声 tile 就绪后应渲染 shader 画布');
    final cp = tester.widget<CustomPaint>(canvasFinder);
    expect(
      cp.child,
      isNull,
      reason: 'CustomPaint 的 child 绘制在 painter 之上，会完全遮盖'
          '细节效果 shader 输出（原图 contain 铺满同比例画布时不可见，'
          '拉腿比例变化时以重影形式露出）',
    );

    // 4) 回归断言二：滑块拖动（仅 effects 变化）复用已解码图像与已加载
    //    shader，painter 参数随新值更新。
    await tester.pumpWidget(MaterialApp(
      home: DetailEffectsLayer(
        url: photoPath,
        effects: const DetailEffectsParams(vignette: 80),
        fallback: () => const SizedBox.expand(),
      ),
    ));
    await tester.pump();

    expect(canvasFinder, findsOneWidget);
    final painter =
        tester.widget<CustomPaint>(canvasFinder).painter as DetailEffectsPainter;
    expect(painter.effects.vignette, 80);
  });
}
