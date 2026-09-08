import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/capture/widgets/post_process_adjust_panel.dart';

void main() {
  group('AdjustSlider', () {
    testWidgets('自定义 format 与 accentColor 生效', (tester) async {
      const accent = Color(0xFF123456);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: AdjustSlider(
              label: 'EV',
              value: 1.2,
              min: -3,
              max: 3,
              accentColor: accent,
              format: (v) =>
                  v >= 0 ? '+${v.toStringAsFixed(1)}' : v.toStringAsFixed(1),
              onChanged: (_) {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // 自定义格式：'+1.2'
      expect(find.text('+1.2'), findsOneWidget);

      // 填充轨道 / 把手描边使用传入 accent
      final decos = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .toList();
      expect(decos.any((d) => d.color == accent), isTrue);
      expect(
        decos.any(
            (d) => d.border is Border && (d.border as Border).top.color == accent),
        isTrue,
      );
    });

    testWidgets('默认整型格式（负数带负号）', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: AdjustSlider(
              label: '亮度',
              value: -5,
              min: -100,
              max: 100,
              onChanged: (_) {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('-5'), findsOneWidget);
    });

    testWidgets('拖动回调新值（向右拖 → 值增大）', (tester) async {
      double? changed;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: AdjustSlider(
              label: 'EV',
              value: 0,
              min: -3,
              max: 3,
              onChanged: (v) => changed = v,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(AdjustSlider), const Offset(200, 0));
      await tester.pumpAndSettle();

      final v = changed;
      expect(v, isNotNull);
      if (v != null) {
        expect(v, greaterThan(0));
      }
    });

    testWidgets('AdjustPanel accentColor 传递到选中 chip', (tester) async {
      const accent = Color(0xFF00AA00);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 160,
              child: AdjustPanel(
                defs: colorAdjustDefs(),
                full: const PostProcess(color: PostProcessColor()),
                onChanged: (_) {},
                accentColor: accent,
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // 默认选中第 0 项（亮度）：圆形图标底 = accent
      final decos = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .toList();
      expect(decos.any((d) => d.color == accent), isTrue);
    });
  });
}
