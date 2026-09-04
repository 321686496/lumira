import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/features/templates/services/template_share_code.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_common.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:zxing2/qrcode.dart';

const _outDir = 'build/qr_upscale_diag';

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

/// 与 scan_qr_page.dart 的 _decodeQrFromBytes 完全一致。
String? decodeScanPage(List<int> bytes) {
  final image = img.decodeImage(Uint8List.fromList(bytes));
  if (image == null) return null;
  try {
    final pixels = image.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
    final source = RGBLuminanceSource(image.width, image.height, pixels.buffer.asInt32List());
    final bitmap = BinaryBitmap(HybridBinarizer(source));
    final result = QRCodeReader().decode(bitmap);
    return result.text.isEmpty ? null : result.text;
  } catch (_) {
    return null;
  }
}

/// 直接以目标像素尺寸栅格化 QrPainter（无任何 upscale）。
Future<Uint8List> renderDirect(String data, double px) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Rect.fromLTWH(0, 0, px, px), Paint()..color = Colors.white);
  QrPainter(
    data: data,
    version: QrVersions.auto,
    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1A1A1A)),
    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1A1A1A)),
  ).paint(canvas, Size.square(px));
  final picture = recorder.endRecording();
  final image = await picture.toImage(px.toInt(), px.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

/// 小逻辑尺寸渲染 → RepaintBoundary upscale（复现 PosterQr 路径）。
Future<Uint8List> renderUpscaled(
  WidgetTester tester,
  String data,
  double logicalSize,
  double ratio,
  String name,
) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF888888),
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: PosterQr(data: data, size: logicalSize, padding: 5, radius: 9),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  Uint8List? out;
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: ratio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    out = byteData!.buffer.asUint8List();
    final file = File('$_outDir/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(out!);
  });
  return out!;
}

/// 打印二维码模块边缘的灰度值分布，判断是否模糊。
void inspectEdges(Uint8List bytes, String label) {
  final image = img.decodeImage(bytes);
  if (image == null) return;
  // 取中心行，统计所有非纯黑/纯白像素比例（边缘模糊度）
  var w = image.width, h = image.height;
  var y = h ~/ 2;
  var nonBinary = 0, total = 0;
  var min = 255, max = 0;
  for (var x = 0; x < w; x++) {
    final p = image.getPixel(x, y);
    final v = (p.r + p.g + p.b) ~/ 3;
    if (v < min) min = v;
    if (v > max) max = v;
    if (v > 20 && v < 235) nonBinary++;
    total++;
  }
  // ignore: avoid_print
  print('  [$label] centerRow min=$min max=$max grayBetween20-235=$nonBinary/$total');
}

/// 预处理策略 1：硬阈值（灰度 > t → 255，否则 0）→ HybridBinarizer。
String? decodeThreshold(Uint8List bytes, int t) {
  final image = img.decodeImage(bytes);
  if (image == null) return null;
  try {
    final w = image.width, h = image.height;
    final lum = Int8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = image.getPixel(x, y);
        final v = (p.r.toInt() * 306 + p.g.toInt() * 601 + p.b.toInt() * 117) >> 10;
        lum[y * w + x] = v > t ? 255 : 0;
      }
    }
    final source = GrayLuminanceSource(w, h, lum);
    final bitmap = BinaryBitmap(HybridBinarizer(source));
    final result = QRCodeReader().decode(bitmap);
    return result.text.isEmpty ? null : result.text;
  } catch (_) {
    return null;
  }
}

/// 预处理策略 2：GlobalHistogramBinarizer（zxing 自带，另一阈值算法）。
String? decodeGlobal(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) return null;
  try {
    final w = image.width, h = image.height;
    final pixels = image.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
    final source = RGBLuminanceSource(w, h, pixels.buffer.asInt32List());
    final bitmap = BinaryBitmap(GlobalHistogramBinarizer(source));
    final result = QRCodeReader().decode(bitmap);
    return result.text.isEmpty ? null : result.text;
  } catch (_) {
    return null;
  }
}

/// 预处理策略 3：最近邻放大 2x（保持模块方块化）→ HybridBinarizer。
String? decodeNearest2x(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) return null;
  try {
    final big = img.copyResize(image, width: image.width * 2, height: image.height * 2,
        interpolation: img.Interpolation.nearest);
    final w = big.width, h = big.height;
    final pixels = big.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
    final source = RGBLuminanceSource(w, h, pixels.buffer.asInt32List());
    final bitmap = BinaryBitmap(HybridBinarizer(source));
    final result = QRCodeReader().decode(bitmap);
    return result.text.isEmpty ? null : result.text;
  } catch (_) {
    return null;
  }
}

void main() {
  testWidgets('直接栅格 vs upscale：同一输出像素下的解码 + 边缘模糊对比', (tester) async {
    final data = TemplateShareCode.buildPosterQrData(_makeRecord());

    await tester.runAsync(() async {
      // 1) 直接栅格：与 upscale 输出像素一致
      for (final px in [108.0, 216.0, 312.0]) {
        final bytes = await renderDirect(data, px);
        final ok = decodeScanPage(bytes);
        inspectEdges(bytes, 'direct ${px.toInt()}px');
        // ignore: avoid_print
        print('  direct ${px.toInt()}px decode=${ok == null ? 'FAIL' : 'OK'}');
      }
    });

    // 2) PosterQr upscale 路径 + 各预处理策略
    final cfgs = <List<double>>[
      [54.0, 2.0],
      [54.0, 4.0],
      [78.0, 4.0],
    ];
    for (final cfg in cfgs) {
      final logical = cfg[0], ratio = cfg[1];
      final bytes = await renderUpscaled(tester, data, logical, ratio,
          'up_${logical.toInt()}_r${ratio.toInt()}');
      await tester.runAsync(() {
        inspectEdges(bytes, 'upscale logical=$logical ratio=$ratio');
        return Future.value();
      });
      final ok = decodeScanPage(bytes);
      // ignore: avoid_print
      print('  upscale logical=$logical ratio=$ratio '
          '(${bytes.length}B) decode=${ok == null ? 'FAIL' : 'OK'}');
      // ignore: avoid_print
      print('    threshold128=${decodeThreshold(bytes, 128) == null ? 'FAIL' : 'OK'} '
          'threshold160=${decodeThreshold(bytes, 160) == null ? 'FAIL' : 'OK'} '
          'global=${decodeGlobal(bytes) == null ? 'FAIL' : 'OK'} '
          'nearest2x=${decodeNearest2x(bytes) == null ? 'FAIL' : 'OK'}');
    }
  });
}

/// zxing2 的 LuminanceSource 子类：直接喂亮度矩阵（等价 RGBLuminanceSource 但避开其构造）。
class GrayLuminanceSource extends LuminanceSource {
  final Int8List _lum;
  GrayLuminanceSource(int width, int height, this._lum) : super(width, height);
  @override
  Int8List getMatrix() => _lum;
  @override
  Int8List getRow(int y, Int8List? row) {
    if (row == null || row.length < width) row = Int8List(width);
    for (var x = 0; x < width; x++) {
      row[x] = _lum[y * width + x];
    }
    return row;
  }
}
