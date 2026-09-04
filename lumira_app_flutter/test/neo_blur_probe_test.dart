import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/theme/theme_tokens.dart';
import '../lib/shared/widgets/effects/recessed_surface.dart';

void main() {
  testWidgets('blurred inset surface probe', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 220));
    final tokens = ThemeTokens.of(ThemeKey.warmWhite);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: tokens.canvas,
        body: Column(
          children: [
            const SizedBox(height: 16),
            SizedBox(
              width: 240,
              height: 56,
              child: RecessedSurface(
                tokens: tokens,
                borderRadius: 28,
                depth: 0.7,
                rimFraction: 0.34,
                child: const Center(child: Text('自然凹陷')),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 160,
              height: 80,
              child: RecessedSurface(
                tokens: tokens,
                borderRadius: 0,
                depth: 0.7,
                rimFraction: 0.3,
                child: const Center(child: Text('方角')),
              ),
            ),
          ],
        ),
      ),
    ));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/neo_blur_surface.png'),
    );
  });
}