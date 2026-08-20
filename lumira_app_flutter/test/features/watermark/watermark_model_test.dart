import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/watermark/models/watermark_settings.dart';
import 'package:lumira_app_flutter/features/watermark/models/watermark_template.dart';

void main() {
  group('WatermarkElement space 序列化', () {
    test('toJson/fromJson 保留 space', () {
      final e = WatermarkElement(id: 'e1', type: WatermarkElementType.text, text: '2026.08.20')
          .copyWith(space: WatermarkElementSpace.frame);
      final back = WatermarkElement.fromJson(e.toJson());
      expect(back.space, WatermarkElementSpace.frame);
    });
    test('旧 JSON 缺省 space 回退 photo', () {
      final e = WatermarkElement.fromJson({'id': 'e1', 'type': 'text', 'text': 'x'});
      expect(e.space, WatermarkElementSpace.photo);
    });
  });

  group('WatermarkFrame 序列化', () {
    test('toJson/fromJson roundtrip', () {
      const f = WatermarkFrame(
        type: WatermarkFrameType.polaroid,
        color: ui.Color(0xFFFFFFFF),
        borderRatio: 0.05,
        borderRadius: 0.01,
        bottomPlate: true,
        bottomRatio: 0.18,
        shadowColor: ui.Color(0xFF000000),
        shadowOpacity: 0.25,
        shadowBlur: 0.02,
      );
      final back = WatermarkFrame.fromJson(f.toJson());
      expect(back.type, WatermarkFrameType.polaroid);
      expect(back.borderRatio, 0.05);
      expect(back.bottomPlate, isTrue);
      expect(back.bottomRatio, 0.18);
      expect(back.shadowOpacity, 0.25);
    });
    test('旧模板 JSON 缺省 frame 回退 none', () {
      final t = WatermarkTemplate.fromJson({
        'id': 'preset_x',
        'name': 'x',
        'type': 'preset',
        'elements': <dynamic>[],
        'createdAt': '2026-08-08T00:00:00.000',
      });
      expect(t.frame.type, WatermarkFrameType.none);
    });
    test('模板含 frame roundtrip', () {
      final t = WatermarkTemplate(
        id: 't1',
        name: '拍立得',
        type: WatermarkTemplateType.custom,
        createdAt: DateTime(2026, 8, 20),
        elements: <WatermarkElement>[],
        frame: const WatermarkFrame(type: WatermarkFrameType.polaroid),
      );
      final back = WatermarkTemplate.fromJson(t.toJson());
      expect(back.frame.type, WatermarkFrameType.polaroid);
    });
  });

  group('WatermarkSettings manageLayout', () {
    test('默认 list', () {
      expect(const WatermarkSettings().manageLayout, WatermarkManageLayout.list);
    });
    test('toJson/fromJson roundtrip', () {
      const s = WatermarkSettings(manageLayout: WatermarkManageLayout.grid);
      final back = WatermarkSettings.fromJson(s.toJson());
      expect(back.manageLayout, WatermarkManageLayout.grid);
      expect(back.enabled, isTrue);
    });
    test('copyWith 更新 manageLayout', () {
      const s = WatermarkSettings();
      expect(s.copyWith(manageLayout: WatermarkManageLayout.grid).manageLayout,
          WatermarkManageLayout.grid);
    });
  });
}
