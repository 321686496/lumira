import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/features/templates/services/template_share_code.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_common.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_ratio.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_types.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_styles_shared.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_registry.dart';

const _outDir = 'build/qr_padding_diag';

TemplateRecord _makeRecord() {
  return TemplateRecord(
    id: 'r1',
    name: '晨光人像',
    author: 'tester',
    version: '1.0.0',
    category: 'portrait',
    classification: {'type': '人像', 'style': '清新', 'method': '平拍'},
    tags: ['人像'],
    tagIds: [],
    price: 0,
    cover: '',
    description: '',
    referenceSource: '',
    composition: {'overlayType': 'rule_of_thirds', 'subjectFrame': {'x': 0.1, 'y': 0.2, 'w': 0.3, 'h': 0.4}, 'opacity': 0.5, 'aspectRatio': '3:4', 'description': '三分法'},
    pose: {'silhouette': {'type': 'builtin', 'data': 'standing-profile'}, 'position': {'x': 0.5, 'y': 0.5}, 'scale': 1.0, 'rotation': 0, 'description': ''},
    camera: {'exposureCompensation': 0.3, 'iso': 200, 'shutterSpeed': '1/200', 'whiteBalance': 'daylight', 'whiteBalanceK': 5500, 'flashMode': 'off', 'focusMode': 'auto', 'lensSuggestion': 'main'},
    sceneGuide: {'lightDirection': 'front', 'shootingDistance': '2m', 'background': 'wall', 'props': <String>[], 'bestTime': 'morning', 'tips': <String>['keep steady']},
    postProcess: {'cropRatio': '3:4', 'color': {'brightness': 0, 'contrast': 0, 'saturation': 0, 'temperature': 0, 'tint': 0}, 'smoothStrength': 0, 'sharpen': 0, 'vignette': 0, 'grain': 0, 'lut': 'none'},
    createdAt: 1700000000000,
    updatedAt: 1700000000000,
    isBuiltin: false,
    isRecommended: false,
  );
}

Future<void> _capture(WidgetTester tester, Widget widget, String name,
    {double pixelRatio = 1.0}) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF888888),
        body: Center(child: RepaintBoundary(key: key, child: widget)),
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
}

void main() {
  testWidgets('对比 PosterQr 在 40/50/54px 下默认 padding vs 零 padding 的渲染差异', (tester) async {
    final record = _makeRecord();
    final data = TemplateShareCode.buildPosterQrData(record);
    // ignore: avoid_print
    print('qrData len=${data.length}');

    final sizes = [40.0, 50.0, 54.0, 60.0, 78.0];
    for (final s in sizes) {
      await _capture(
        tester,
        PosterQr(data: data, size: s, padding: 5, radius: 6),
        'qr_defaultPad_${s.toInt()}',
        pixelRatio: 3.0,
      );
    }

    // 构造无双重 padding 的对比：直接 QrImageView padding 0
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
      ),
    );

    // 第二款海报（相纸卡片 pC）整卡高分辨率渲染
    final pC = PosterStyleRegistry.stylesFor(PosterKind.template, PosterRatio.fullScreen)
        .firstWhere((s) => s.id == 'pC');
    await _capture(tester, pC.builder(posterData), 'pC_full', pixelRatio: 3.0);
    // 第一款海报（经典面板 pA）
    final pA = PosterStyleRegistry.stylesFor(PosterKind.template, PosterRatio.fullScreen)
        .firstWhere((s) => s.id == 'pA');
    await _capture(tester, pA.builder(posterData), 'pA_full', pixelRatio: 3.0);
  });
}
