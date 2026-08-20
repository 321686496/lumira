# Task 3: 渲染器扩展（画框 + 坐标空间 + 返回尺寸）并修正拍照管线

**Files:**
- Modify: `lumira_app_flutter/lib/features/watermark/services/watermark_renderer.dart`
- Modify: `lumira_app_flutter/lib/features/capture/pages/capture_page.dart:670-688`
- Test: `lumira_app_flutter/test/features/watermark/watermark_renderer_test.dart`（新建）

**Interfaces:**
- Consumes: `WatermarkTemplate`（含 `frame`）、`WatermarkElement.space`（Task 2 已完成）。
- Produces:
  ```dart
  class WatermarkRenderResult {
    final Uint8List rgbaBytes;
    final int width;
    final int height;
  }
  Future<WatermarkRenderResult> render({required ui.Image sourceImage, required WatermarkTemplate template});
  ```
  渲染器不再暴露旧 `render({elements})` 签名。

## 现有代码结构

`watermark_renderer.dart` 当前：`render({required ui.Image sourceImage, required List<WatermarkElement> elements})` 返回 `Uint8List`；内部 `_drawTextElement(canvas, element, imageWidth, imageHeight, scale)`，`_withOpacity(color, opacity)` 辅助方法。

`capture_page.dart` 670-688 行：调用 `renderer.render(sourceImage: sourceImage, elements: watermarkTemplate.elements)`，返回 `rgbaBytes`（Uint8List），然后用 `img.Image.fromBytes(width: workerResult.width, height: workerResult.height, ...)` 编码。

## Global Constraints

- **Dart 版本**：Dart 2.19.6 / Flutter 3.7.12，禁止 Dart 3 records。
- **序列化兼容**：Task 2 已保证 `frame`/`space` 回退。
- 测试：`flutter test test/features/watermark/watermark_renderer_test.dart` 定向测试；提交前本任务相关测试全绿。

---

- [ ] **Step 1: 写失败测试**

  新建 `test/features/watermark/watermark_renderer_test.dart`：
  ```dart
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

    WatermarkTemplate _tpl(WatermarkFrameType type, {List<WatermarkElement> elements = const []}) {
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
      final r = await WatermarkRenderer().render(sourceImage: src, template: _tpl(WatermarkFrameType.none));
      expect(r.width, 40);
      expect(r.height, 30);
      expect(r.rgbaBytes.length, 40 * 30 * 4);
    });

    test('拍立得输出 = 照片 + 左右白边 + 上下白边 + 底部白板', () async {
      final src = await makeImage(100, 80, 0xFFFFFFFF);
      final r = await WatermarkRenderer().render(sourceImage: src, template: _tpl(WatermarkFrameType.polaroid));
      // borderRatio=0.1 → pad=10；bottomRatio=0.2 → plate=16
      expect(r.width, 100 + 10 * 2);
      expect(r.height, 80 + 10 + 10 + 16);
      expect(r.rgbaBytes.length, r.width * r.height * 4);
    });

    test('内描边输出尺寸 = 原图', () async {
      final src = await makeImage(60, 60, 0xFFFFFFFF);
      final r = await WatermarkRenderer().render(sourceImage: src, template: _tpl(WatermarkFrameType.innerBorder));
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
  ```
  **注意**：测试文件位于 `test/features/watermark/`，import 包名为 `package:lumira_app_flutter/...`（Task 2 已验证实际包名是 `lumira_app_flutter`）。`WatermarkElement` 是 immutable + copyWith 风格，用 `.copyWith(space: WatermarkElementSpace.frame)`（不要用 `..space =`）。

- [ ] **Step 2: 运行测试确认失败**

  Run: `flutter test test/features/watermark/watermark_renderer_test.dart`
  Expected: FAIL（`WatermarkRenderResult`/新 `render` 不存在）。

- [ ] **Step 3: 实现渲染器**

  用以下内容重写 `watermark_renderer.dart`（保持 `_withOpacity` 等既有辅助方法）：
  ```dart
  class WatermarkRenderResult {
    final Uint8List rgbaBytes;
    final int width;
    final int height;
    const WatermarkRenderResult({
      required this.rgbaBytes,
      required this.width,
      required this.height,
    });
  }

  class WatermarkRenderer {
    static const double _referenceWidth = 400.0;

    Future<WatermarkRenderResult> render({
      required ui.Image sourceImage,
      required WatermarkTemplate template,
    }) async {
      final photoW = sourceImage.width.toDouble();
      final photoH = sourceImage.height.toDouble();
      final frame = template.frame;
      final type = frame.type;
      final scale = photoW / _referenceWidth;

      // —— 画布尺寸 ——
      double padX = 0, padTop = 0, padBottom = 0;
      if (type == WatermarkFrameType.polaroid) {
        final pad = frame.borderRatio * photoW;
        padX = pad;
        padTop = pad;
        padBottom = pad + (frame.bottomPlate ? frame.bottomRatio * photoH : 0);
      }
      final shadow = (type == WatermarkFrameType.polaroid && frame.shadowOpacity > 0)
          ? (frame.shadowBlur * photoW).clamp(2.0, 60.0)
          : 0.0;
      final outputW = (photoW + padX * 2).round();
      final outputH = (photoH + padTop + padBottom + shadow).round();

      final cardRect = ui.Rect.fromLTWH(0, 0, photoW + padX * 2, photoH + padTop + padBottom);
      final photoOrigin = ui.Offset(padX, padTop);
      final photoRect = ui.Rect.fromLTWH(padX, padTop, photoW, photoH);
      final plateRect = (type == WatermarkFrameType.polaroid && frame.bottomPlate)
          ? ui.Rect.fromLTWH(padX, padTop + photoH, photoW, padBottom - padX)
          : photoRect;

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      // 投影（拍立得，仅底部）
      if (shadow > 0) {
        final paint = ui.Paint()
          ..color = frame.shadowColor.withValues(alpha: frame.shadowOpacity)
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, shadow);
        canvas.drawRect(
          ui.Rect.fromLTWH(0, cardRect.bottom, outputW.toDouble(), shadow * 1.4),
          paint,
        );
      }

      // 白卡（拍立得）/ 透明底（其余）
      if (type == WatermarkFrameType.polaroid) {
        final paint = ui.Paint()..color = frame.color;
        if (frame.borderRadius > 0) {
          canvas.drawRRect(
            ui.RRect.fromRectAndRadius(cardRect, ui.Radius.circular(frame.borderRadius * photoW)),
            paint,
          );
        } else {
          canvas.drawRect(cardRect, paint);
        }
      }

      // 照片
      canvas.drawImage(sourceImage, photoOrigin, ui.Paint());

      // 内描边
      if (type == WatermarkFrameType.innerBorder) {
        final stroke = frame.borderRatio * photoW;
        final paint = ui.Paint()
          ..color = frame.color
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = stroke;
        final inner = photoRect.deflate(stroke / 2);
        if (frame.borderRadius > 0) {
          canvas.drawRRect(
            ui.RRect.fromRectAndRadius(inner, ui.Radius.circular(frame.borderRadius * photoW)),
            paint,
          );
        } else {
          canvas.drawRect(inner, paint);
        }
      }

      // 元素
      for (final element in template.elements) {
        if (element.type == WatermarkElementType.image) continue;
        final base = element.space == WatermarkElementSpace.frame ? plateRect : photoRect;
        _drawTextElement(canvas, element, base, scale);
      }

      // 画布圆角裁剪（拍立得/内描边且 borderRadius>0）
      if (type != WatermarkFrameType.none && frame.borderRadius > 0) {
        final clipRect = ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(0, 0, outputW.toDouble(), outputH.toDouble()),
          ui.Radius.circular(frame.borderRadius * photoW),
        );
        canvas.clipRRect(clipRect);
      }

      final picture = recorder.endRecording();
      final outputImage = await picture.toImage(outputW, outputH);
      final byteData = await outputImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      outputImage.dispose();
      if (byteData == null) throw StateError('WatermarkRenderer: failed to encode output image');
      return WatermarkRenderResult(
        rgbaBytes: byteData.buffer.asUint8List(),
        width: outputW,
        height: outputH,
      );
    }

    void _drawTextElement(
      ui.Canvas canvas,
      WatermarkElement element,
      ui.Rect base, // 坐标空间基准矩形
      double scale,
    ) {
      final absoluteFontSize = element.fontSize * base.width;
      final blurRadius = (absoluteFontSize * 0.08).clamp(0.5, 8.0);

      // 构建段落
      final paragraphStyle = ui.ParagraphStyle(
        textAlign: element.textAlign,
        fontSize: absoluteFontSize,
        fontWeight: element.bold ? FontWeight.bold : FontWeight.normal,
        fontStyle: element.italic ? FontStyle.italic : FontStyle.normal,
        fontFamily: element.fontFamily.isEmpty ? null : element.fontFamily,
      );

      final builder = ui.ParagraphBuilder(paragraphStyle)
        ..pushStyle(
          ui.TextStyle(
            color: _withOpacity(element.color, element.opacity),
            fontSize: absoluteFontSize,
            fontWeight: element.bold ? FontWeight.bold : FontWeight.normal,
            fontStyle: element.italic ? FontStyle.italic : FontStyle.normal,
            fontFamily: element.fontFamily.isEmpty ? null : element.fontFamily,
            letterSpacing: element.letterSpacing * scale,
            shadows: [
              ui.Shadow(
                color: _withOpacity(element.shadowColor, element.opacity),
                blurRadius: blurRadius,
                offset: ui.Offset(blurRadius * 0.4, blurRadius * 0.4),
              ),
            ],
          ),
        )
        ..addText(element.text);

      // 约束宽度使用基准矩形宽度
      final paragraph = builder.build()
        ..layout(ui.ParagraphConstraints(width: base.width));

      final textWidth = paragraph.maxIntrinsicWidth;
      final textHeight = paragraph.height;

      // 锚点：相对基准矩形换算绝对像素
      final anchorX = element.x * base.width + base.left;
      final anchorY = element.y * base.height + base.top;

      double offsetX;
      switch (element.textAlign) {
        case TextAlign.right:
          offsetX = -textWidth;
          break;
        case TextAlign.center:
          offsetX = -textWidth / 2;
          break;
        case TextAlign.left:
        case TextAlign.justify:
        default:
          offsetX = 0.0;
      }
      final offsetY = -textHeight * 0.85;

      canvas.save();
      canvas.translate(anchorX, anchorY);
      if (element.rotation != 0.0) {
        canvas.rotate(element.rotation);
      }
      canvas.translate(offsetX, offsetY);
      canvas.drawParagraph(paragraph, ui.Offset.zero);
      canvas.restore();
    }

    ui.Color _withOpacity(ui.Color color, double opacity) {
      if (opacity >= 1.0) return color;
      final clamped = opacity.clamp(0.0, 1.0);
      final alpha = (color.alpha * clamped).round();
      return ui.Color.fromARGB(
        alpha,
        color.red,
        color.green,
        color.blue,
      );
    }
  }
  ```
  注意：`Color.withValues(alpha:)` 在 Flutter 3.7.12 / Dart 2.19.6 上是否存在需核实。若不存在，改用 `ui.Color.fromARGB((frame.shadowOpacity * 255).round(), color.red, color.green, color.blue)` 或复用 `_withOpacity(frame.shadowColor, frame.shadowOpacity)`。**请以实际可编译为准。**

- [ ] **Step 4: 修正拍照管线调用点**

  `capture_page.dart` 670-688 行改为：
  ```dart
  final renderer = ref.read(watermarkRendererProvider);
  final wmResult = await renderer.render(
    sourceImage: sourceImage,
    template: watermarkTemplate,
  );

  final outputImage = img.Image.fromBytes(
    width: wmResult.width,
    height: wmResult.height,
    bytes: wmResult.rgbaBytes.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  final jpegBytes = img.encodeJpg(outputImage, quality: 90);
  ```

- [ ] **Step 5: 运行测试确认通过**

  Run: `flutter test test/features/watermark/watermark_renderer_test.dart`
  Expected: PASS。

- [ ] **Step 6: 全仓编译校验**

  Run: `flutter analyze`
  Expected: 无 error（确认渲染器新签名已被所有调用点适配）。

- [ ] **Step 7: Commit**

  ```bash
  git add lumira_app_flutter/lib/features/watermark/services lumira_app_flutter/lib/features/capture/pages/capture_page.dart lumira_app_flutter/test/features/watermark
  git commit -m "feat(watermark): renderer supports frames and coordinate spaces; fix capture pipeline size"
  ```
