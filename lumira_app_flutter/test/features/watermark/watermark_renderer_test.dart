import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show TextAlign;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/watermark/models/watermark_template.dart';
import 'package:lumira_app_flutter/features/watermark/services/watermark_layout.dart';
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
        borderTop: 0.1,
        borderRight: 0.1,
        borderBottom: 0.1,
        borderLeft: 0.1,
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
      frame: const WatermarkFrame(type: WatermarkFrameType.polaroid, borderTop: 0.1, borderRight: 0.1, borderBottom: 0.1, borderLeft: 0.1, bottomPlate: false, shadowOpacity: 0.0),
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
      frame: const WatermarkFrame(type: WatermarkFrameType.polaroid, borderRatio: 0.1, borderTop: 0.1, borderRight: 0.1, borderBottom: 0.1, borderLeft: 0.1, bottomPlate: true, bottomRatio: 0.2, shadowOpacity: 0.0),
    );
    final r = await WatermarkRenderer().render(sourceImage: src, template: t);
    expect(r.width, 120);
    expect(r.height, 116);
    expect(r.rgbaBytes.length, r.width * r.height * 4);
  });

  test('拍立得四边白边可独立设置，输出尺寸按各边向外扩展', () async {
    final src = await makeImage(100, 80, 0xFFFFFFFF);
    final t = WatermarkTemplate(
      id: 't', name: 't', type: WatermarkTemplateType.custom, createdAt: DateTime(2026, 8, 20),
      elements: const <WatermarkElement>[],
      frame: const WatermarkFrame(
        type: WatermarkFrameType.polaroid,
        borderLeft: 0.1,   // 10
        borderRight: 0.2,  // 20
        borderTop: 0.05,   // 5
        borderBottom: 0.1, // 10
        bottomPlate: false,
        shadowOpacity: 0.0,
      ),
    );
    final r = await WatermarkRenderer().render(sourceImage: src, template: t);
    expect(r.width, 100 + 10 + 20);
    expect(r.height, 80 + 5 + 10);
    expect(r.rgbaBytes.length, r.width * r.height * 4);
  });

  test('拍立得渐变白边可正常渲染（含渐变方向）', () async {
    final src = await makeImage(60, 50, 0xFFFFFFFF);
    final t = WatermarkTemplate(
      id: 't', name: 't', type: WatermarkTemplateType.custom, createdAt: DateTime(2026, 8, 20),
      elements: const <WatermarkElement>[],
      frame: const WatermarkFrame(
        type: WatermarkFrameType.polaroid,
        borderFill: WatermarkBorderFill.gradient,
        color: ui.Color(0xFFFFF3E0),
        gradientEndColor: ui.Color(0xFFE1BEE7),
        gradientDirection: WatermarkGradientDirection.leftToRight,
        borderTop: 0.05,
        borderRight: 0.05,
        borderBottom: 0.05,
        borderLeft: 0.05,
        bottomPlate: true,
        bottomRatio: 0.2,
        shadowOpacity: 0.0,
      ),
    );
    final r = await WatermarkRenderer().render(sourceImage: src, template: t);
    expect(r.rgbaBytes.length, r.width * r.height * 4);
  });

  test('space=frame 的元素以白板为基准绘制（y=0.5 落入白板区间）', () async {
    final src = await makeImage(100, 80, 0xFFFFFFFF);
    const frame = WatermarkFrame(
      type: WatermarkFrameType.polaroid,
      borderLeft: 0.1, // 10
      borderRight: 0.3, // 30
      borderTop: 0.05, // 4
      borderBottom: 0.05, // 4
      bottomPlate: true,
      bottomRatio: 0.2, // 16
      shadowOpacity: 0.0,
    );
    // 画布 140×(80+4+4+16=104)；photoRect 垂直 [4,84) → 中线 44；白板垂直 [84,104) → 中线 94
    final layout =
        WatermarkLayout.compute(photoW: 100, photoH: 80, frame: frame);

    WatermarkElement el(WatermarkElementSpace space) => WatermarkElement(
          id: 'd',
          type: WatermarkElementType.text,
          text: '2026.08.20',
          x: 0.5,
          y: 0.5,
          fontSize: 0.06,
          color: const ui.Color(0xFFFF0000),
          shadowColor: const ui.Color(0x00000000),
          textAlign: TextAlign.center,
          space: space,
        );

    Future<double> centerY(WatermarkElementSpace space) async {
      final r = await WatermarkRenderer().render(
        sourceImage: src,
        template: WatermarkTemplate(
          id: 't',
          name: 't',
          type: WatermarkTemplateType.custom,
          createdAt: DateTime(2026, 8, 20),
          elements: [el(space)],
          frame: frame,
        ),
      );
      return _redCenterY(r);
    }

    final photoY = await centerY(WatermarkElementSpace.photo);
    final frameY = await centerY(WatermarkElementSpace.frame);
    expect(photoY, greaterThan(layout.photoRect.top));
    expect(photoY, lessThan(layout.photoRect.bottom));
    // 白板基准 → 绘制落在照片区域之下（回归：白板元素不再按照片区域定位）。
    expect(frameY, greaterThan(layout.plateRect.top));
    expect(frameY, lessThan(layout.plateRect.bottom));
  });

  test('dateTime 元素按 captureDate 格式化（渲染结果等同等价文本元素）', () async {
    final src = await makeImage(60, 50, 0xFFFFFFFF);

    WatermarkElement el(WatermarkElementType type, String text) => WatermarkElement(
          id: 'd',
          type: type,
          text: text,
          x: 0.5,
          y: 0.5,
          fontSize: 0.08,
          color: const ui.Color(0xFF000000),
          shadowColor: const ui.Color(0x00000000),
          textAlign: TextAlign.center,
        );

    Future<WatermarkRenderResult> render(
      WatermarkElement el, {
      DateTime? captureDate,
    }) {
      return WatermarkRenderer().render(
        sourceImage: src,
        template: WatermarkTemplate(
          id: 't',
          name: 't',
          type: WatermarkTemplateType.custom,
          createdAt: DateTime(2026, 8, 20),
          elements: [el],
        ),
        captureDate: captureDate,
      );
    }

    final withDate = await render(
      el(WatermarkElementType.dateTime, ''),
      captureDate: DateTime(1999, 1, 1),
    );
    final equivalent =
        await render(el(WatermarkElementType.text, '1999.01.01'));
    final blank = await render(el(WatermarkElementType.text, ''));

    // 若 dateTime 未按 captureDate 格式化（例如回退元素自带的空文本），
    // withDate 会退化成全白，与 equivalent 不再相等。
    expect(withDate.rgbaBytes, equals(equivalent.rgbaBytes));
    expect(withDate.rgbaBytes, isNot(equals(blank.rgbaBytes)));
  });
}

/// 输出图中「纯红核心像素」的垂直重心（用于断言元素绘制落点）。
double _redCenterY(WatermarkRenderResult r) {
  var sum = 0;
  var count = 0;
  for (var y = 0; y < r.height; y++) {
    for (var x = 0; x < r.width; x++) {
      final i = (y * r.width + x) * 4;
      final red = r.rgbaBytes[i];
      final green = r.rgbaBytes[i + 1];
      final blue = r.rgbaBytes[i + 2];
      if (red > 200 && green < 160 && blue < 160) {
        sum += y;
        count++;
      }
    }
  }
  expect(count, greaterThan(0), reason: '输出图中未找到红色文字像素');
  return sum / count;
}