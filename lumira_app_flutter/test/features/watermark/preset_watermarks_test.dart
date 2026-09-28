import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/watermark/data/preset_watermarks.dart';
import 'package:lumira_app_flutter/features/watermark/models/watermark_template.dart';

/// 写死的日期文本（如 '2026.08.20'）——预置一律不得出现。
final _hardCodedDate = RegExp(r'20\d\d[.\-/]\d{1,2}');

void main() {
  test('预设有 6 款且 id 唯一', () {
    final presets = getPresetWatermarks();
    expect(presets.length, 6);
    final ids = presets.map((e) => e.id).toSet();
    expect(ids.length, presets.length);
  });

  test('每款至少一个日期元素，且全部为 dateTime 类型（不写死文本）', () {
    for (final t in getPresetWatermarks()) {
      final dates = t.elements
          .where((e) => e.type == WatermarkElementType.dateTime)
          .toList();
      expect(dates, isNotEmpty, reason: t.id);
    }
  });

  test('任何元素都不含写死的日期文本', () {
    for (final t in getPresetWatermarks()) {
      for (final e in t.elements) {
        expect(
          _hardCodedDate.hasMatch(e.text),
          isFalse,
          reason: '${t.id}/${e.id} text=${e.text}',
        );
      }
    }
  });

  test('画框水印不再用 ┌┐└┘ 字符拼角，改用 innerBorder 内描边', () {
    final t = getPresetWatermarks().firstWhere((t) => t.id == 'preset_frame_border');
    expect(t.frame.type, WatermarkFrameType.innerBorder);
    expect(t.frame.borderRatio, greaterThan(0));
    for (final e in t.elements) {
      for (final ch in ['┌', '┐', '└', '┘']) {
        expect(e.text.contains(ch), isFalse, reason: '${e.id} 仍含角字符 $ch');
      }
    }
  });

  test('画框类型映射：拍立得 / 画框水印 / 其余无画框', () {
    for (final t in getPresetWatermarks()) {
      final expected = t.id == 'preset_polaroid'
          ? WatermarkFrameType.polaroid
          : t.id == 'preset_frame_border'
              ? WatermarkFrameType.innerBorder
              : WatermarkFrameType.none;
      expect(t.frame.type, expected, reason: t.id);
    }
  });

  test('拍立得预设：底部白板 + 日期在白板空间、无阴影（白板提供对比）', () {
    final pol = getPresetWatermarks().firstWhere((t) => t.id == 'preset_polaroid');
    expect(pol.frame.type, WatermarkFrameType.polaroid);
    expect(pol.frame.bottomPlate, isTrue);

    final dateEl = pol.elements
        .firstWhere((e) => e.type == WatermarkElementType.dateTime);
    expect(dateEl.space, WatermarkElementSpace.frame);
    expect(dateEl.shadowColor.alpha, 0);
  });

  test('叠在照片上的元素都挂深色柔光晕（亮底可读，且不带描边）', () {
    for (final t in getPresetWatermarks()) {
      if (t.id == 'preset_polaroid') continue; // 白板内元素不挂阴影
      for (final e in t.elements) {
        expect(e.shadowBlur, greaterThan(0), reason: '${t.id}/${e.id}');
        expect(e.shadowColor.alpha, greaterThan(0), reason: '${t.id}/${e.id}');
      }
    }
  });

  test('画框水印只保留居中日期一个元素', () {
    final t = getPresetWatermarks().firstWhere((t) => t.id == 'preset_frame_border');
    expect(t.elements, hasLength(1));
    expect(t.elements.single.type, WatermarkElementType.dateTime);
  });

  group('拍立得渐变预设', () {
    test('预设非空、id（标签）唯一，且起止色必须可辨', () {
      expect(watermarkGradientPresets, isNotEmpty);
      final labels = watermarkGradientPresets.map((p) => p.label).toSet();
      expect(labels.length, watermarkGradientPresets.length);
      for (final p in watermarkGradientPresets) {
        expect(p.start.value, isNot(p.end.value), reason: p.label);
      }
    });

    test('matches 仅在颜色与方向都一致时命中', () {
      final preset = watermarkGradientPresets.first;
      final frame = const WatermarkFrame(type: WatermarkFrameType.polaroid)
          .copyWith(
        borderFill: WatermarkBorderFill.gradient,
        color: preset.start,
        gradientEndColor: preset.end,
        gradientDirection: preset.direction,
      );
      expect(preset.matches(frame), isTrue);
      // 纯色状态不算命中
      expect(
        preset.matches(frame.copyWith(borderFill: WatermarkBorderFill.solid)),
        isFalse,
      );
      // 换方向后不算命中
      expect(
        preset.matches(frame.copyWith(
          gradientDirection: preset.direction ==
                  WatermarkGradientDirection.topToBottom
              ? WatermarkGradientDirection.leftToRight
              : WatermarkGradientDirection.topToBottom,
        )),
        isFalse,
      );
    });
  });
}