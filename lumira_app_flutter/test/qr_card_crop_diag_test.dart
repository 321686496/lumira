import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/features/templates/services/template_share_code.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_ratio.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_registry.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_types.dart';

const _outDir = 'build/qr_card_crop';

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

void main() {
  testWidgets('裁剪放大各样式卡的二维码区域', (tester) async {
    final record = _makeRecord();
    final qrData = TemplateShareCode.buildShareLink(record, usePptpl: false);
    // ignore: avoid_print
    print('qrData len=${qrData.length} modules=${qrData.length ~/ 10}');

    final ratio = PosterRatio.fullScreen;
    final styles = PosterStyleRegistry.stylesFor(PosterKind.template, ratio);
    final posterData = PosterStyleData(
      ratio: ratio,
      title: record.name,
      category: '人像写真 · 摄影模板',
      qrData: qrData,
      qrHint: '长按识别 · 查看完整模板',
      qrSub: '打开如画，拍出同款',
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

    // 每个样式：渲染整卡海报（与卡片一致 FittedBox contain 106x140 内），再放大截图
    // 分别按 pixelRatio 2/3/4 输出，模拟不同 DPR 设备上的观感
    for (final ratio in [2.0, 3.0, 4.0]) {
      for (final s in styles) {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: const Color(0xFFE8E4DC),
              body: Center(
                child: RepaintBoundary(
                  key: key,
                  child: SizedBox(
                    width: 106,
                    height: 140,
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
          final image = await boundary.toImage(pixelRatio: ratio);
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory(_outDir)..createSync(recursive: true);
          File('$_outDir/${s.id}_card_${ratio.toInt()}x.png')
              .writeAsBytesSync(byteData!.buffer.asUint8List());
          // ignore: avoid_print
          print('${s.id} @${ratio}x ${image.width}x${image.height}');
        });
      }
    }
  });
}
