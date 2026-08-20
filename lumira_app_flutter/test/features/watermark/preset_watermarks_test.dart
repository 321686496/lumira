import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/watermark/data/preset_watermarks.dart';
import 'package:lumira_app_flutter/features/watermark/models/watermark_template.dart';

void main() {
  test('预设有 6 款且 id 唯一', () {
    final presets = getPresetWatermarks();
    expect(presets.length, 6);
    final ids = presets.map((e) => e.id).toSet();
    expect(ids.length, presets.length);
  });
  test('拍立得预设：frame=polaroid、日期元素在 frame 空间', () {
    final pol = getPresetWatermarks().firstWhere((t) => t.id == 'preset_polaroid');
    expect(pol.frame.type, WatermarkFrameType.polaroid);
    expect(pol.frame.bottomPlate, isTrue);
    final dateEl = pol.elements.firstWhere(
      (e) => e.type == WatermarkElementType.dateTime ||
          (e.type == WatermarkElementType.text && e.text.contains('20')),
    );
    expect(dateEl.space, WatermarkElementSpace.frame);
  });
  test('其余预设 frame 为 none', () {
    for (final t in getPresetWatermarks()) {
      if (t.id == 'preset_polaroid') continue;
      expect(t.frame.type, WatermarkFrameType.none, reason: t.id);
    }
  });
}