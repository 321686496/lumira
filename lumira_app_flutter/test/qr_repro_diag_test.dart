import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/features/templates/services/template_share_code.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_common.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_ratio.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_registry.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_types.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_styles_shared.dart';

const _outDir = 'build/qr_repro_diag';

TemplateRecord _makeRecord() {
  return TemplateRecord(
    id: 'r1',
    name: '晨光人像',
    author: 'tester',
    version: '1.0.0',
    category: 'portrait',
    classification: const {'type': '人像', 'style': '清新', 'method': '平拍'},
    tags: const ['人像'],
    tagIds: const [],
    price: 0,
    cover: '',
    description: '',
    referenceSource: '',
    composition: const {'overlayType': 'rule_of_thirds', 'subjectFrame': {'x': 0.1, 'y': 0.2, 'w': 0.3, 'h': 0.4}, 'opacity': 0.5, 'aspectRatio': '3:4', 'description': '三分法'},
    pose: const {'silhouette': {'type': 'builtin', 'data': 'standing-profile'}, 'position': {'x': 0.5, 'y': 0.5}, 'scale': 1.0, 'rotation': 0, 'description': ''},
    camera: const {'exposureCompensation': 0.3, 'iso': 200, 'shutterSpeed': '1/200', 'whiteBalance': 'daylight', 'whiteBalanceK': 5500, 'flashMode': 'off', 'focusMode': 'auto', 'lensSuggestion': 'main'},
    sceneGuide: const {'lightDirection': 'front', 'shootingDistance': '2m', 'background': 'wall', 'props': <String>[], 'bestTime': 'morning', 'tips': <String>['keep steady']},
    postProcess: const {'cropRatio': '3:4', 'color': {'brightness': 0, 'contrast': 0, 'saturation': 0, 'temperature': 0, 'tint': 0}, 'smoothStrength': 0, 'sharpen': 0, 'vignette': 0, 'grain': 0, 'lut': 'none'},
    createdAt: 1700000000000,
    updatedAt: 1700000000000,
    isBuiltin: false,
    isRecommended: false,
  );
}

/// 在给定 surface 尺寸下渲染 widget，返回按 pixelRatio 截取的图片并落盘。
Future<void> _capture(
  WidgetTester tester,
  Widget widget,
  String name, {
  double pixelRatio = 1.0,
  double surfaceW = 400,
  double surfaceH = 1000,
}) async {
  final key = GlobalKey();
  await tester.binding.setSurfaceSize(Size(surfaceW, surfaceH));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF888888),
        body: SingleChildScrollView(
          child: Center(child: RepaintBoundary(key: key, child: widget)),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_outDir/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(byteData!.buffer.asUint8List());
    // ignore: avoid_print
    print('saved $_outDir/$name.png ${image.width}x${image.height}');
  });
  await tester.binding.setSurfaceSize(null);
}

void main() {
  testWidgets('复现真实弹窗场景：pC/pA 整卡自然尺寸渲染 + 样式卡缩略渲染', (tester) async {
    final record = _makeRecord();
    final data = TemplateShareCode.buildPosterQrData(record);
    // ignore: avoid_print
    print('qrData len=${data.length}');

    final posterData = PosterStyleData(
      ratio: PosterRatio.fullScreen,
      title: record.name,
      category: '人像写真 · 摄影模板',
      qrData: data,
      qrHint: 'hint',
      qrSub: 'sub',
      shareText: 'share',
      authorName: '',
      photoBuilder: (w, h) => Container(
        width: w,
        height: h,
        color: const Color(0xFFCCCCCC),
        child: const Center(
          child: Text('PHOTO', style: TextStyle(color: Colors.black38, fontSize: 20)),
        ),
      ),
    );

    final pC = PosterStyleRegistry.stylesFor(PosterKind.template, PosterRatio.fullScreen)
        .firstWhere((s) => s.id == 'pC');
    final pA = PosterStyleRegistry.stylesFor(PosterKind.template, PosterRatio.fullScreen)
        .firstWhere((s) => s.id == 'pA');

    // 整卡自然尺寸（真实主预览，无 FittedBox），DPR 3.0
    await _capture(tester, pC.builder(posterData), 'pC_natural_3x', pixelRatio: 3.0);
    await _capture(tester, pA.builder(posterData), 'pA_natural_3x', pixelRatio: 3.0);

    // 样式卡缩略（FittedBox contain 106x140，DPR 3.0），复现选择 popup 卡片
    for (final s in [pA, pC]) {
      final key = GlobalKey();
      await tester.binding.setSurfaceSize(const Size(400, 400));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF888888),
            body: Center(
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 118,
                  height: 152,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: s.builder(posterData),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$_outDir/${s.id}_card_3x.png');
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync(byteData!.buffer.asUint8List());
        // ignore: avoid_print
        print('saved $_outDir/${s.id}_card_3x.png ${image.width}x${image.height}');
      });
      await tester.binding.setSurfaceSize(null);
    }
  });
}
