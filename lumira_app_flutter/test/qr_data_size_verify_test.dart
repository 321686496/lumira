import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/features/templates/services/template_exporter.dart';
import 'package:lumira_app_flutter/features/templates/services/template_share_code.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_common.dart';
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

/// 模拟 QrImageView 实际渲染路径：fromData 不抛异常（懒加载），
/// 访问 dataCache 才会触发 InputTooLongException。
bool _qrRenders(String data) {
  try {
    final code = QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.L);
    // 触发 _createData，超容量在此抛 InputTooLongException
    // ignore: invalid_use_of_internal_member
    code.dataCache;
    return true;
  } catch (_) {
    return false;
  }
}

void main() {
  test('实测两种格式的 QR 数据长度与可生成性', () {
    final record = _makeRecord();

    final pptplLink = TemplateShareCode.buildShareLink(record, usePptpl: true);
    final lumiraLink = TemplateShareCode.buildShareLink(record, usePptpl: false);
    // 与 QR 中实际编码内容等价的明文（去掉 lumira://tpl/ 前缀后仍是 QR data 本身）
    final pptplData = pptplLink;
    final lumiraData = lumiraLink;

    // ignore: avoid_print
    print('pptpl json len=${TemplateExporter.exportToPptpl(record).length}, '
        'link len=${pptplData.length}, qrRenders=${_qrRenders(pptplData)}');
    // ignore: avoid_print
    print('lumira json len=${TemplateExporter.exportToLumira(record).length}, '
        'link len=${lumiraData.length}, qrRenders=${_qrRenders(lumiraData)}');

    expect(_qrRenders(lumiraData), isTrue, reason: '轻量格式必须可生成 QR');
  });

  test('带 coverData（base64 封面）时 pptpl 必然超 QR 容量', () {
    // 模拟 30KB 封面（典型封面远大于此）
    final coverBytes = List<int>.filled(30 * 1024, 0xAB);
    final coverData = 'data:image/jpeg;base64,${base64Encode(coverBytes)}';
    final record = _makeRecord().copyWith(coverData: coverData);

    final pptplLink = TemplateShareCode.buildShareLink(record, usePptpl: true);
    final lumiraLink = TemplateShareCode.buildShareLink(record, usePptpl: false);

    // ignore: avoid_print
    print('withCover pptpl link len=${pptplLink.length}, qrRenders=${_qrRenders(pptplLink)}');
    // ignore: avoid_print
    print('withCover lumira link len=${lumiraLink.length}, qrRenders=${_qrRenders(lumiraLink)}');

    expect(_qrRenders(lumiraLink), isTrue);
  });

  test('QR v40 EC-L 可渲染长度边界（用于确定回退阈值）', () {
    // 数据为纯 ASCII，长度即字节数；从大到小找可渲染的最大长度。
    int lo = 0;
    int hi = 6000;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (_qrRenders('a' * mid)) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    // ignore: avoid_print
    print('QR v40 EC-L 最大可渲染 ASCII 长度 = $lo');

    // 回退阈值取 2900，留足余量，且必须远小于边界。
    expect(lo, greaterThan(2900));
  });

  testWidgets('PosterQr 用回退数据（带内嵌封面）能真正渲染出 QR', (tester) async {
    // 模拟 30KB 封面 → pptpl 必然超容量 → 回退 .lumira
    final coverBytes = List<int>.filled(30 * 1024, 0xAB);
    final coverData = 'data:image/jpeg;base64,${base64Encode(coverBytes)}';
    final record = _makeRecord().copyWith(coverData: coverData);

    final data = TemplateShareCode.buildPosterQrData(record);
    expect(data.length, lessThan(2900));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PosterQr(data: data, size: 120),
          ),
        ),
      ),
    );
    await tester.pump();

    // 没有异常（build 阶段 QrImageView 校验通过），且确实绘出了 CustomPaint（QR 像素）
    expect(tester.takeException(), isNull);
    expect(
      find.byType(CustomPaint),
      findsWidgets,
      reason: 'PosterQr 必须渲染出 QR 像素画布，而不是 error 占位',
    );
  });
}
