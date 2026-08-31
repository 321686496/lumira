import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/features/templates/services/template_share_code.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_picker.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_registry.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_types.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_ratio.dart';

const _outDir = 'build/qr_card_diag';

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
        backgroundColor: const Color(0xFFE8E4DC),
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
  testWidgets('渲染各比例下的样式卡 + 完整海报', (tester) async {
    final record = _makeRecord();
    final qrData = TemplateShareCode.buildShareLink(record, usePptpl: false);

    for (final ratio in [
      PosterRatio.fullScreen,
      PosterRatio.ratio34,
      PosterRatio.square,
    ]) {
      final styles =
          PosterStyleRegistry.stylesFor(PosterKind.template, ratio);
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
      // ignore: avoid_print
      print('ratio=$ratio styles=${styles.map((s) => s.id).join(',')}');

      // 完整海报（主预览）
      for (final s in styles) {
        await _capture(tester, s.builder(posterData), '${ratio.name}_${s.id}_full');
      }

      // 卡片行（与 PosterStylePicker 一致：FittedBox contain 118x152 内）
      await _capture(
        tester,
        SizedBox(
          height: 176,
          child: PosterStylePicker(
            styles: styles,
            data: posterData,
            selectedId: styles.isNotEmpty ? styles.first.id : '',
            onSelect: (_) {},
          ),
        ),
        '${ratio.name}_cards',
        pixelRatio: 2.0,
      );
    }
  });
}
