import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/features/templates/services/template_share_code.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_registry.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_types.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_ratio.dart';
import 'package:qr/qr.dart';

TemplateRecord _makeRecord() {
  return TemplateRecord(
    id: 'r1',
    name: '测试模板',
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

int _qrModules(String data) {
  final code = QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.L);
  // ignore: invalid_use_of_internal_member
  code.dataCache;
  return code.moduleCount;
}

void main() {
  test('打印各 QR 数据的长度、版本、模块数', () {
    final record = _makeRecord();
    final pptpl = TemplateShareCode.buildShareLink(record, usePptpl: true);
    final lumira = TemplateShareCode.buildShareLink(record, usePptpl: false);
    final light = 'https://lumira.app/tpl?name=${Uri.encodeComponent(record.name)}&category=${Uri.encodeComponent(record.category)}';

    // ignore: avoid_print
    print('pptpl len=${pptpl.length} modules=${_qrModules(pptpl)}');
    // ignore: avoid_print
    print('lumira len=${lumira.length} modules=${_qrModules(lumira)}');
    // ignore: avoid_print
    print('light len=${light.length} modules=${_qrModules(light)}');
  });

  testWidgets('渲染每个模板样式，检查 QR 是否进入 error 状态（PosterLogo 占位）', (tester) async {
    final record = _makeRecord();
    final data = TemplateShareCode.buildPosterQrData(record);
    // ignore: avoid_print
    print('poster qrData len=${data.length} modules=${_qrModules(data)}');

    final photoBox = Container(
      width: 300,
      height: 400,
      color: const Color(0xFFCCCCCC),
    );
    final posterData = PosterStyleData(
      ratio: PosterRatio.ratio34,
      title: record.name,
      category: '人像写真 · 摄影模板',
      qrData: data,
      qrHint: '长按识别 · 查看完整模板',
      qrSub: '打开如画，拍出同款',
      shareText: 'share',
      authorName: '',
      photoBuilder: (w, h) => SizedBox(width: w, height: h, child: photoBox),
    );

    final styles = PosterStyleRegistry.stylesFor(PosterKind.template, PosterRatio.ratio34);
    // ignore: avoid_print
    print('ratio34 模板样式数=${styles.length}');

    for (final s in styles) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RepaintBoundary(child: s.builder(posterData)),
            ),
          ),
        ),
      );
      await tester.pump();
      final exc = tester.takeException();
      // ignore: avoid_print
      print('style=${s.id} name=${s.name} exception=${exc}');
      expect(exc, isNull, reason: '样式 ${s.id} 渲染不应抛异常');
    }
  });
}
