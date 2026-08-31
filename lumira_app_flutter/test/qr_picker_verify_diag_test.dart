import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/templates/services/template_share_code.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_ratio.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_picker.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_registry.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_types.dart';

const _outDir = 'build/qr_picker_verify';

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

Future<void> _snapshot(WidgetTester tester, GlobalKey key, String name,
    {double pixelRatio = 2.0}) async {
  await tester.pump();
  final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await tester.runAsync(
    () async => boundary.toImage(pixelRatio: pixelRatio),
  );
  if (image == null) return;
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('$_outDir/$name.png');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(byteData!.buffer.asUint8List());
  // ignore: avoid_print
  print('saved $_outDir/$name.png ${image.width}x${image.height}');
}

PosterStyleData _makePosterData(PosterRatio ratio) {
  final record = _makeRecord();
  final data = TemplateShareCode.buildPosterQrData(record);
  return PosterStyleData(
    ratio: ratio,
    title: record.name,
    category: '人像写真 · 摄影模板',
    qrData: data,
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
}

void main() {
  testWidgets('样式切换条缩略图（选中 pC 相纸卡片，QR 占位清晰）', (tester) async {
    await tester.binding.setSurfaceSize(const Size(820, 240));
    final ratio = PosterRatio.fullScreen;
    final styles = PosterStyleRegistry.stylesFor(PosterKind.template, ratio);
    final posterData = _makePosterData(ratio);

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: const Color(0xFFE8E4DC),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: PosterStylePicker(
                  styles: styles,
                  data: posterData,
                  selectedId: 'pC',
                  onSelect: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await _snapshot(tester, key, 'picker_selected_pC');
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('相纸卡片 pC 主预览（真实二维码渲染）', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final ratio = PosterRatio.fullScreen;
    final posterData = _makePosterData(ratio);

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF444444),
          body: RepaintBoundary(
            key: key,
            child: Center(
              child: PosterStyleRegistry
                  .stylesFor(PosterKind.template, ratio)
                  .firstWhere((s) => s.id == 'pC')
                  .builder(posterData),
            ),
          ),
        ),
      ),
    );
    await _snapshot(tester, key, 'pC_main_preview');
    await tester.binding.setSurfaceSize(null);
  });
}
