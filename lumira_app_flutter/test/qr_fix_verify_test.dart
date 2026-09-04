import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/features/templates/services/template_share_code.dart';
import 'package:lumira_app_flutter/shared/services/qr_decoder.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_common.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_ratio.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_registry.dart';

const _outDir = 'build/qr_fix_verify';

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

/// 与相册扫码管线完全一致的解码：decodeQrFromBytes（共享服务）。
/// 保留独立别名便于断言语义清晰。
String? decodeScanPage(List<int> bytes) => decodeQrFromBytes(bytes);

Future<Uint8List> captureBoundary(GlobalKey key, double ratio) async {
  final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: ratio);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

void main() {
  Directory(_outDir).createSync(recursive: true);

  testWidgets('修复验证：PosterQr 与整卡海报 pC 导出后均可被相册管线识别', (tester) async {
    // 竖屏大窗口，容纳 fullScreen（约 300x630）海报渲染，避免 overflow
    tester.binding.window.physicalSizeTestValue = const Size(800, 1400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    final record = _makeRecord();
    final data = TemplateShareCode.buildPosterQrData(record);

    // 1) PosterQr 独立渲染（真实导出倍率 3.6）
    final qrKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF888888),
          body: Center(
            child: RepaintBoundary(
              key: qrKey,
              child: PosterQr(data: data, size: 54, padding: 5, radius: 9),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final qrBytes = await tester.runAsync(() => captureBoundary(qrKey, 3.6));
    File('$_outDir/poster_qr_54_r36.png').writeAsBytesSync(qrBytes!);
    final qrDecoded = decodeScanPage(qrBytes);
    // ignore: avoid_print
    print('PosterQr(54) @3.6 decode=${qrDecoded == null ? 'FAIL' : 'OK'}');
    expect(qrDecoded, data, reason: 'PosterQr 独立渲染必须能被相册管线识别');

    // 2) 整卡海报 pC（真实导出流程：1080 宽）
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
    final posterKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF888888),
          body: Center(
            child: UnconstrainedBox(
              child: RepaintBoundary(key: posterKey, child: pC.builder(posterData)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final bytes = await tester.runAsync(() async {
      final boundary =
          posterKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final size = boundary.size;
      final ratio = (1080.0 / size.width).clamp(2.0, 4.0);
      final image = await boundary.toImage(pixelRatio: ratio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    });
    File('$_outDir/pC_full_1080.png').writeAsBytesSync(bytes!);
    final pCDecoded = decodeScanPage(bytes);
    // ignore: avoid_print
    print('pC full (1080w) decode=${pCDecoded == null ? 'FAIL' : 'OK'}');
    expect(pCDecoded, data, reason: '整卡海报 pC 导出（1080 宽）必须能被相册管线识别');
  });
}
