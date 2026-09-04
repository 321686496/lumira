import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/theme/theme_tokens.dart';
import '../lib/shared/widgets/effects/recessed_surface.dart';

void main() {
  testWidgets('recess debug probe', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 520));
    final tokens = ThemeTokens.of(ThemeKey.warmWhite);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: tokens.canvas,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1) pill（短宽）：同搜索类型 tab / 筛选 tab 的选中态
            Padding(
              padding: const EdgeInsets.all(16),
              child: RecessedSurface(
                tokens: tokens,
                borderRadius: 999,
                depth: 0.7,
                rimFraction: 0.34,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: const Text('全部', style: TextStyle(fontSize: 14)),
                ),
              ),
            ),
            // 2) 中尺寸 pill：同搜索记录词条按压态
            Padding(
              padding: const EdgeInsets.all(16),
              child: RecessedSurface(
                tokens: tokens,
                borderRadius: 24,
                depth: 0.68,
                rimFraction: 0.3,
                child: Padding(
                  padding:
                      const EdgeInsets.only(left: 14, right: 6, top: 7, bottom: 7),
                  child: const Text('落日人像'),
                ),
              ),
            ),
            // 3) 圆角 12 块：同热门搜索词条按压态
            Padding(
              padding: const EdgeInsets.all(16),
              child: RecessedSurface(
                tokens: tokens,
                borderRadius: 12,
                depth: 0.68,
                rimFraction: 0.3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('1', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      SizedBox(width: 8),
                      Text('晴天人像', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
            // 4) 关键词 pill：不透明 surfaceAlt 背景的按压态（复现是否被盖住）
            Padding(
              padding: const EdgeInsets.all(16),
              child: RecessedSurface(
                tokens: tokens,
                borderRadius: 999,
                depth: 0.68,
                rimFraction: 0.3,
                child: Container(
                  padding: const EdgeInsets.only(left: 14, right: 6, top: 7, bottom: 7),
                  decoration: BoxDecoration(
                    color: tokens.surfaceAlt,
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(color: tokens.divider, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('落日人像', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 6),
                      const Icon(Icons.close, size: 12),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/recess_debug.png'),
    );
  });
}