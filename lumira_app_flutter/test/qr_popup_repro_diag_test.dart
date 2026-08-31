import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/templates/services/template_share_code.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_common.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_ratio.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_picker.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_registry.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_types.dart';

const _outDir = 'build/qr_popup_repro';

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
    {double pixelRatio = 3.0}) async {
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

void main() {
  testWidgets('渲染真实海报选择弹窗布局（样式条 + 主预览），默认与选中 pC 对比', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final tokens = ThemeTokens.of(ThemeKey.warmWhite);
    final record = _makeRecord();
    final data = TemplateShareCode.buildPosterQrData(record);

    final ratio = PosterRatio.fullScreen;
    final styles = PosterStyleRegistry.stylesFor(PosterKind.template, ratio);
    final posterData = PosterStyleData(
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

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF444444),
          body: RepaintBoundary(
            key: key,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                color: tokens.surface,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 标题行
                    Row(
                      children: [
                        Text('分享模板', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
                        const Spacer(),
                        Icon(Icons.close_rounded, color: tokens.textSecondary),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // 样式切换条
                    PosterStylePicker(
                      styles: styles,
                      data: posterData,
                      selectedId: 'pA',
                      onSelect: (_) {},
                    ),
                    // 主预览区
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: tokens.surfaceAlt,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: RepaintBoundary(
                              child: styles.firstWhere((s) => s.id == 'pA').builder(posterData),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await _snapshot(tester, key, 'sheet_default_pA');

    // 切换主预览为 pC
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF444444),
          body: RepaintBoundary(
            key: key,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                color: tokens.surface,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text('分享模板', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: tokens.textPrimary)),
                        const Spacer(),
                        Icon(Icons.close_rounded, color: tokens.textSecondary),
                      ],
                    ),
                    const SizedBox(height: 6),
                    PosterStylePicker(
                      styles: styles,
                      data: posterData,
                      selectedId: 'pC',
                      onSelect: (_) {},
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: tokens.surfaceAlt,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: RepaintBoundary(
                              child: styles.firstWhere((s) => s.id == 'pC').builder(posterData),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await _snapshot(tester, key, 'sheet_selected_pC');

    await tester.binding.setSurfaceSize(null);
  });
}
