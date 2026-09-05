import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final boundaryKey = GlobalKey();

  testWidgets('capture 尺寸与坐标诊断', (tester) async {
    debugPrint('[diag] dpr=${tester.binding.window.devicePixelRatio} size=${tester.binding.window.physicalSize}');
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Center(
              child: Container(
                width: 90,
                height: 38,
                color: const Color(0xff00ff00),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final rect = tester.getRect(find.byType(Container));
    debugPrint('[diag] rect(logical)=$rect');

    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
    final image = await tester.binding.runAsync(() => boundary.toImage());
    debugPrint('[diag] image size=${image!.width}x${image.height}');

    final data = await tester.binding.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba));
    Color at(num px, num py) {
      final x = px.floor().clamp(0, image.width - 1);
      final y = py.floor().clamp(0, image.height - 1);
      final i = (y * image.width + x) * 4;
      return Color.fromARGB(data!.getUint8(i + 3), data!.getUint8(i),
          data!.getUint8(i + 1), data!.getUint8(i + 2));
    }

    final cLogical = at(rect.left + 45, rect.top + 19);
    debugPrint('[diag] logical-center=$cLogical');
    debugPrint('[diag] origin(0,0)=${at(0, 0)}');
    debugPrint('[diag] logical (400,300)=${at(400, 300)}');
  });
}