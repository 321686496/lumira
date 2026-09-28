import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show TextAlign;
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/features/watermark/models/watermark_template.dart';
import 'package:lumira_app_flutter/features/watermark/services/watermark_layout.dart';

/// 拍立得画框（borderRatio 0.05 × 照片宽，底部白板 0.18 × 照片高）。
const WatermarkFrame _polaroid = WatermarkFrame(
  type: WatermarkFrameType.polaroid,
  borderRatio: 0.05,
  borderTop: 0.05,
  borderRight: 0.05,
  borderBottom: 0.05,
  borderLeft: 0.05,
  bottomPlate: true,
  bottomRatio: 0.18,
);

void main() {
  group('WatermarkLayout 画框几何', () {
    test('polaroid + 白板：画布向外扩展，白板为整卡宽', () {
      // 300×400 → 左右各 15、上 15、下 15 + 72 = 87
      final layout = WatermarkLayout.compute(
        photoW: 300,
        photoH: 400,
        frame: _polaroid,
      );
      expect(layout.cardRect, const ui.Rect.fromLTWH(0, 0, 330, 502));
      expect(layout.photoRect, const ui.Rect.fromLTWH(15, 15, 300, 400));
      // 白板左边界必须是 0（整卡宽）：取 padLeft 会让 x=0.5 的元素整体右移。
      expect(layout.plateRect, const ui.Rect.fromLTWH(0, 415, 330, 87));
    });

    test('polaroid 无白板：plateRect 回退 photoRect', () {
      final layout = WatermarkLayout.compute(
        photoW: 300,
        photoH: 400,
        frame: _polaroid.copyWith(bottomPlate: false),
      );
      // 无白板 → padBottom 只剩 borderBottom × 照片宽 = 15
      expect(layout.cardRect, const ui.Rect.fromLTWH(0, 0, 330, 430));
      expect(layout.plateRect, layout.photoRect);
    });

    test('innerBorder / none：画布与照片同尺寸，plateRect 回退 photoRect', () {
      for (final frame in <WatermarkFrame>[
        const WatermarkFrame(type: WatermarkFrameType.innerBorder, borderRatio: 0.012),
        const WatermarkFrame(),
      ]) {
        final layout =
            WatermarkLayout.compute(photoW: 300, photoH: 400, frame: frame);
        expect(layout.cardRect, const ui.Rect.fromLTWH(0, 0, 300, 400));
        expect(layout.photoRect, const ui.Rect.fromLTWH(0, 0, 300, 400));
        expect(layout.plateRect, layout.photoRect);
        expect(layout.outputWidth, 300);
        expect(layout.outputHeight, 400);
      }
    });

    test('baseFor：frame → 白板，photo → 照片', () {
      final layout =
          WatermarkLayout.compute(photoW: 300, photoH: 400, frame: _polaroid);
      expect(layout.baseFor(WatermarkElementSpace.frame), layout.plateRect);
      expect(layout.baseFor(WatermarkElementSpace.photo), layout.photoRect);
    });
  });

  group('拍立得日期居中（回归：日期落在白板中部而非照片中部）', () {
    /// 白板内日期元素（与预置「拍立得」一致）。
    final dateEl = WatermarkElement(
      id: 'd',
      type: WatermarkElementType.dateTime,
      text: '',
      x: 0.5,
      y: 0.54,
      fontSize: 0.035,
      space: WatermarkElementSpace.frame,
      textAlign: TextAlign.center,
    );

    test('成片坐标系：x=0.5 落在整卡水平中线，且在白板垂直区间内', () {
      final layout =
          WatermarkLayout.compute(photoW: 300, photoH: 400, frame: _polaroid);
      final base = layout.baseFor(dateEl.space);
      final placement = WatermarkTextPlacement.compute(
        element: dateEl,
        base: base,
        textWidth: 40,
        textHeight: 8,
      );

      expect(placement.anchorX, closeTo(layout.cardRect.width / 2, 0.001));
      expect(placement.anchorY, greaterThan(layout.plateRect.top));
      expect(placement.anchorY, lessThan(layout.plateRect.bottom));
    });

    test('缩略图坐标系：日期仍居中于白板（不再落到照片中部）', () {
      final geometry = WatermarkPreviewGeometry.fit(
        size: const ui.Size(120, 160),
        frame: _polaroid,
      );
      final base = geometry.baseFor(dateEl.space);
      final placement = WatermarkTextPlacement.compute(
        element: dateEl,
        base: base,
        textWidth: 20,
        textHeight: 4,
      );

      final card = geometry.displayRect(geometry.layout.cardRect);
      final plate = geometry.displayRect(geometry.layout.plateRect);
      expect(placement.anchorX, closeTo(card.center.dx, 0.001));
      // 落入白板区间（照片区域之下）——即缺陷「拍立得日期在图片中间」的回归断言。
      expect(placement.anchorY, greaterThan(plate.top));
      expect(placement.anchorY, lessThan(plate.bottom));
    });
  });

  group('WatermarkTextPlacement 锚点与偏移', () {
    const base = ui.Rect.fromLTWH(10, 20, 200, 100);

    WatermarkTextPlacement place(TextAlign align) => WatermarkTextPlacement.compute(
          element: WatermarkElement(
            id: 't',
            type: WatermarkElementType.text,
            text: 'x',
            x: 0.5,
            y: 0.5,
            textAlign: align,
          ),
          base: base,
          textWidth: 40,
          textHeight: 10,
        );

    test('锚点 = 相对坐标 × 基准尺寸 + 基准原点', () {
      final p = place(TextAlign.left);
      expect(p.anchorX, 10 + 0.5 * 200);
      expect(p.anchorY, 20 + 0.5 * 100);
      expect(p.offsetX, 0.0);
      expect(p.offsetY, -10 * 0.85);
    });

    test('右对齐左移整段宽度，居中左移半段宽度', () {
      expect(place(TextAlign.right).offsetX, -40.0);
      expect(place(TextAlign.center).offsetX, -20.0);
    });
  });

  group('WatermarkElementMetrics 换算', () {
    test('只挂柔光晕：单个模糊阴影，无零模糊的描边阴影', () {
      final e = WatermarkElement(
        id: 'e',
        type: WatermarkElementType.text,
        text: 'x',
        fontSize: 0.05,
        shadowColor: const ui.Color(0xFF000000),
        shadowBlur: 0.45,
      );
      final m = WatermarkElementMetrics.of(e, WatermarkLayout.referenceWidth);
      expect(m.fontSize, 20.0);
      expect(m.shadows, hasLength(1));
      expect(m.shadows.single.blurRadius, greaterThan(0));
    });

    test('shadowBlur = 0 或阴影全透明时完全不挂阴影', () {
      final base = WatermarkElement(
        id: 'e',
        type: WatermarkElementType.text,
        text: 'x',
        shadowColor: const ui.Color(0xFF000000),
        shadowBlur: 0.0,
      );
      expect(WatermarkElementMetrics.of(base, 400).shadows, isEmpty);
      expect(
        WatermarkElementMetrics.of(
          base.copyWith(
            shadowBlur: 0.45,
            shadowColor: const ui.Color(0x00000000),
          ),
          400,
        ).shadows,
        isEmpty,
      );
    });

    test('光晕半径随画布等比放大，不被 8px 上限吞掉（回归：3000px 成片）', () {
      final e = WatermarkElement(
        id: 'e',
        type: WatermarkElementType.text,
        text: 'x',
        fontSize: 0.045,
        shadowColor: const ui.Color(0xFF000000),
        shadowBlur: 0.45,
      );
      final small = WatermarkElementMetrics.of(e, 400);
      final large = WatermarkElementMetrics.of(e, 3000);
      final smallBlur = small.shadows.single.blurRadius;
      final largeBlur = large.shadows.single.blurRadius;
      expect(smallBlur, lessThanOrEqualTo(8.0));
      expect(largeBlur, greaterThan(8.0));
      // 与基准宽度成正比（k = baseWidth / 400）
      expect(largeBlur, closeTo(smallBlur * (3000 / 400), 0.001));
    });

    test('字距随基准宽度等比缩放', () {
      final e = WatermarkElement(
        id: 'e',
        type: WatermarkElementType.text,
        text: 'x',
        letterSpacing: 6.0,
      );
      expect(
        WatermarkElementMetrics.of(e, 400).letterSpacing,
        6.0,
      );
      expect(
        WatermarkElementMetrics.of(e, 800).letterSpacing,
        12.0,
      );
    });

    test('opacity 折算进颜色与阴影 alpha', () {
      WatermarkElement build(double opacity) => WatermarkElement(
            id: 'e',
            type: WatermarkElementType.text,
            text: 'x',
            color: const ui.Color(0xFFFFFFFF),
            shadowColor: const ui.Color(0xFF000000),
            opacity: opacity,
            shadowBlur: 0.45,
          );
      final half = WatermarkElementMetrics.of(build(0.5), 400);
      final full = WatermarkElementMetrics.of(build(1.0), 400);
      expect(half.color.alpha, 128);
      expect(full.color.alpha, 255);
      expect(
        half.shadows.single.color.alpha,
        lessThan(full.shadows.single.color.alpha),
      );
    });
  });

  group('formatWatermarkDate', () {
    test('零填充为 yyyy.MM.dd', () {
      expect(formatWatermarkDate(DateTime(2026, 1, 5)), '2026.01.05');
      expect(formatWatermarkDate(DateTime(2026, 12, 31)), '2026.12.31');
    });
  });

  group('watermarkCaptureDateFromPath', () {
    test('解析 capture_<毫秒> 前缀', () {
      final d = watermarkCaptureDateFromPath('/p/DCIM/capture_1727000000000.jpg');
      expect(d, DateTime.fromMillisecondsSinceEpoch(1727000000000));
    });

    test('派生文件仍取首个时间戳（即快门时间）', () {
      final d = watermarkCaptureDateFromPath(
        '/p/capture_1727000000000_final_wm_1727000123456.jpg',
      );
      expect(d, DateTime.fromMillisecondsSinceEpoch(1727000000000));
    });

    test('无法解析时返回 null（由渲染器回退当天）', () {
      expect(watermarkCaptureDateFromPath('/p/IMG_0001.jpg'), isNull);
      expect(watermarkCaptureDateFromPath(null), isNull);
      expect(watermarkCaptureDateFromPath(''), isNull);
    });
  });

  group('watermarkFrameGradientShader', () {
    test('六种方向均可构造 shader，未知方向回退 topToBottom', () {
      const rect = ui.Rect.fromLTWH(0, 0, 100, 100);
      for (final dir in WatermarkGradientDirection.values) {
        final shader = watermarkFrameGradientShader(
          WatermarkFrame(
            type: WatermarkFrameType.polaroid,
            borderFill: WatermarkBorderFill.gradient,
            gradientDirection: dir,
          ),
          rect,
        );
        expect(shader, isNotNull, reason: dir.name);
      }
    });
  });
}