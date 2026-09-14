import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/data/custom_fill_light_colors.dart';
import 'package:lumira_app_flutter/features/capture/data/recent_fill_light_colors.dart';
import 'package:lumira_app_flutter/features/capture/widgets/capture_bottom_controls.dart';

void main() {
  group('fill light color picker', () {
    testWidgets('keeps the compact picker inside a small overlay area', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SquareColorPicker(onColorChanged: (Color _) {}),
          ),
        ),
      );

      final size = tester.getSize(find.byType(SquareColorPicker));
      expect(size, const Size(140, 172));
    });
  });

  group('fill light toolbar ordering', () {
    test('places recent colors before saved colors and system presets', () {
      final rows = CaptureFillLightPanel.buildRowPresets(
        systemPresets: const [
          FillLightPreset('暖白', Color(0xFFFFE5B4), 0.6),
          FillLightPreset('冷白', Color(0xFFE0F0FF), 0.6),
        ],
        recentColors: const [
          Color(0xFF123456),
          Color(0xFF654321),
        ],
        savedColors: const [
          CustomFillLightColor(name: '日落金', color: Color(0xFFFFB347)),
        ],
        activeColor: null,
      );

      expect(
        rows.map((preset) => preset.label),
        ['#123456', '#654321', '日落金', '暖白', '冷白'],
      );
    });

    test('puts the active color first when it is not already listed', () {
      final rows = CaptureFillLightPanel.buildRowPresets(
        systemPresets: const [
          FillLightPreset('暖白', Color(0xFFFFE5B4), 0.6),
        ],
        recentColors: const [Color(0xFF123456)],
        savedColors: const [],
        activeColor: const Color(0xFFABCDEF),
      );

      expect(rows.first.label, '当前');
      expect(rows.first.color, const Color(0xFFABCDEF));
      expect(rows.map((preset) => preset.label), ['当前', '#123456', '暖白']);
    });

    test('promotes an existing active color to the first position', () {
      final rows = CaptureFillLightPanel.buildRowPresets(
        systemPresets: const [
          FillLightPreset('暖白', Color(0xFFFFE5B4), 0.6),
        ],
        recentColors: const [Color(0xFF123456)],
        savedColors: const [],
        activeColor: const Color(0xFFFFE5B4),
      );

      expect(rows.first.label, '暖白');
      expect(rows.map((preset) => preset.label), ['暖白', '#123456']);
    });

    test('names recent custom colors by RGB hex value', () {
      expect(
        CaptureFillLightPanel.fillLightColorLabel(const Color(0xFFFF8C42)),
        '#FF8C42',
      );
    });
  });

  group('recent fill light history', () {
    test('keeps only the three most recent unique colors', () {
      var history = const <Color>[];
      history = RecentFillLightColors.recordUse(history, const Color(0xFF111111));
      history = RecentFillLightColors.recordUse(history, const Color(0xFF222222));
      history = RecentFillLightColors.recordUse(history, const Color(0xFF333333));
      history = RecentFillLightColors.recordUse(history, const Color(0xFF111111));
      history = RecentFillLightColors.recordUse(history, const Color(0xFF444444));

      expect(
        history,
        const [Color(0xFF444444), Color(0xFF111111), Color(0xFF333333)],
      );
    });
  });
}
