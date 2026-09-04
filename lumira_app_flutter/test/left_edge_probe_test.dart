import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/shared/widgets/effects/recessed_surface.dart';

/// 客观验证「胶囊大圆角」pill 的左侧是否真的有内凹暗影。
/// 方法：渲染一个 radius=999 的 RecessedSurface 到图片，逐像素采样左边缘与中心，
/// 断言左边缘亮度显著低于中心（说明左侧存在暗影），避免依赖不可靠的图像模型。
void main() {
  testWidgets('capsule pill has left dark inner shadow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(220, 90));
    final tokens = ThemeTokens.of(ThemeKey.warmWhite);
    final key = GlobalKey();

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: tokens.canvas,
        body: Column(
          children: [
            RepaintBoundary(
              key: key,
              child: RecessedSurface(
                tokens: tokens,
                borderRadius: 999, // 胶囊
                depth: 0.9,
                rimFraction: 0.6,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text('全部', style: TextStyle(fontSize: 14)),
                ),
              ),
            ),
          ],
        ),
      ),
    ));

    await tester.pumpAndSettle();

    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = (await image.toByteData())!;
    final data = bytes.buffer.asUint8List();
    final w = image.width, h = image.height;

    double lum(int x, int y, double dpr) {
      var sum = 0.0;
      var n = 0;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final px = (x + dx).clamp(0, w - 1);
          final py = (y + dy).clamp(0, h - 1);
          final i = (py * w + px) * 4;
          final r = data[i], g = data[i + 1], b = data[i + 2];
          sum += 0.2126 * r + 0.7152 * g + 0.0722 * b;
          n++;
        }
      }
      return sum / n;
    }

    final cx = w ~/ 2, cy = h ~/ 2;
    final leftEdge = lum((w * 0.06).round(), cy, 1); // 靠近左内边缘
    final center = lum(cx, cy, 1);                    // 中心平底

    // 左边缘应明显暗于中心（凹陷暗影）。
    final gap = center - leftEdge;
    // ignore: avoid_print
    print('size=${w}x$h  center=$center  leftEdge=$leftEdge  gap=$gap');
    expect(leftEdge, lessThan(center),
        reason: '左内边缘亮度($leftEdge) 应低于中心($center)，即左侧存在凹下暗影');
  });
}