import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/watermark/models/watermark_template.dart';
import 'package:lumira_app_flutter/features/watermark/services/watermark_renderer.dart';

/// 构造一张纯色测试图（w×h）
Future<ui.Image> makeImage(int w, int h, int argb) async {
  final bytes = Int32List(w * h);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = argb; // 注意端序：此处用 ARGB，测试仅用于尺寸断言
  }
  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(bytes.buffer.asUint8List(), w, h, ui.PixelFormat.rgba8888, c.complete);
  return c.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  WatermarkTemplate tpl(WatermarkFrameType type, {List<WatermarkElement> elements = const []}) {
    return WatermarkTemplate(
      id: 't',
      name: 't',
      type: WatermarkTemplateType.custom,
      createdAt: DateTime(2026, 8, 20),
      elements: elements,
      frame: WatermarkFrame(
        type: type,
        borderRatio: 0.1,
        bottomPlate: true,
        bottomRatio: 0.2,
        shadowOpacity: 0.0,
      ),
    );
  }

  test('无画框输出尺寸 = 原图', () async {
    final src = await makeImage(40, 30, 0xFFFFFFFF);
    final r = await WatermarkRenderer().render(sourceImage: src, template: tpl(WatermarkFrameType.none));
    expect(r.width, 40);
    expect(r.height, 30);
    expect(r.rgbaBytes.length, 40 * 30 * 4);
  });

  test('拍立得输出 = 照片 + 左右白边 + 上下白边 + 底部白板', () async {
    final src = await makeImage(100, 80, 0xFFFFFFFF);
    final r = await WatermarkRenderer().render(sourceImage: src, template: tpl(WatermarkFrameType.polaroid));
    // borderRatio=0.1 → pad=10；bottomRatio=0.2 → plate=16
    expect(r.width, 100 + 10 * 2);
    expect(r.height, 80 + 10 + 10 + 16);
    expect(r.rgbaBytes.length, r.width * r.height * 4);
  });

  test('内描边输出尺寸 = 原图', () async {
    final src = await makeImage(60, 60, 0xFFFFFFFF);
    final r = await WatermarkRenderer().render(sourceImage: src, template: tpl(WatermarkFrameType.innerBorder));
    expect(r.width, 60);
    expect(r.height, 60);
  });

  test('拍立得底部白板关闭时不加高', () async {
    final src = await makeImage(100, 80, 0xFFFFFFFF);
    final t = WatermarkTemplate(
      id: 't', name: 't', type: WatermarkTemplateType.custom, createdAt: DateTime(2026, 8, 20),
      elements: const <WatermarkElement>[],
      frame: const WatermarkFrame(type: WatermarkFrameType.polaroid, borderRatio: 0.1, bottomPlate: false, shadowOpacity: 0.0),
    );
    final r = await WatermarkRenderer().render(sourceImage: src, template: t);
    expect(r.height, 80 + 10 + 10);
  });

  test('frame 空间元素可渲染（含白板日期）', () async {
    final src = await makeImage(100, 80, 0xFFFFFFFF);
    final t = WatermarkTemplate(
      id: 't', name: 't', type: WatermarkTemplateType.custom, createdAt: DateTime(2026, 8, 20),
      elements: [
        WatermarkElement(id: 'd', type: WatermarkElementType.text, text: '2026.08.20')
            .copyWith(space: WatermarkElementSpace.frame),
      ],
      frame: const WatermarkFrame(type: WatermarkFrameType.polaroid, borderRatio: 0.1, bottomPlate: true, bottomRatio: 0.2, shadowOpacity: 0.0),
    );
    final r = await WatermarkRenderer().render(sourceImage: src, template: t);
    expect(r.width, 120);
    expect(r.height, 116);
    expect(r.rgbaBytes.length, r.width * r.height * 4);
  });
}