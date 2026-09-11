import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:image/image.dart' as img;

import '../lib/core/theme/theme_tokens.dart';
import '../lib/features/profile/data/profile_mock_data.dart';
import '../lib/features/profile/widgets/fragment_poster_generator.dart'
    show FragmentPosterContent, FragmentPosterLayout;

ThemeTokens _tokens() => const ThemeTokens(
      canvas: Color(0xFFFDFBF7),
      surface: Color(0xFFFDFBF7),
      surfaceAlt: Color(0xFFF3EDE2),
      canvasDeep: Color(0xFFF3EDE2),
      textPrimary: Color(0xFF2A241C),
      textSecondary: Color(0xFF6B6257),
      textTertiary: Color(0xFF9C9180),
      textInverse: Color(0xFFFFFFFF),
      divider: Color(0xFFE8DECC),
      brand: Color(0xFFC9A96E),
      brandDeep: Color(0xFFA9884B),
      brandLight: Color(0xFFE4D3AF),
      brandSubtle: Color(0xFFF3EDE2),
      brandText: Color(0xFFC9A96E),
      danger: Color(0xFFC05555),
      dangerSubtle: Color(0xFFF6E3E3),
      success: Color(0xFF5E9A6E),
      successSubtle: Color(0xFFE3F0E6),
      shadowConvex: [],
      shadowConvexSubtle: [],
      shadowConvexBrand: [],
      shadowConcave: [],
      shadowConcaveSubtle: [],
      shadowPressed: [],
      shadowFloat: [],
    );

String _pngUri(Color c) {
  final im = img.Image(width: 96, height: 96);
  img.fill(im,
      color: img.ColorRgb8(c.red, c.green, c.blue));
  return 'data:image/png;base64,${base64Encode(img.encodePng(im))}';
}

void main() {
  final urls = [_pngUri(Color(0xFFD98D6A)), _pngUri(Color(0xFF6FA8B8)), _pngUri(Color(0xFF9C8F6B))];

  final fragment = FragmentItem(
    name: '人像',
    icon: Icons.person_outline,
    current: 3,
    max: 5,
    photoUrls: urls,
  );

  Future<void> pumpPoster(WidgetTester tester, FragmentPosterLayout layout) async {
    tester.binding.window.physicalSizeTestValue = const Size(300, 400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SizedBox(
          width: 300,
          height: 400,
          child: RepaintBoundary(
            key: const Key('poster'),
            child: FragmentPosterContent(
              tokens: _tokens(),
              fragment: fragment,
              layout: layout,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));
  }

  testWidgets('fragment phase: capture editorials', (tester) async {
    await pumpPoster(tester, FragmentPosterLayout.editorial);
    await expectLater(find.byKey(const Key('poster')), matchesGoldenFile('goldens/probe_editorial.png'));
    await pumpPoster(tester, FragmentPosterLayout.zen);
    await expectLater(find.byKey(const Key('poster')), matchesGoldenFile('goldens/probe_zen.png'));
    await pumpPoster(tester, FragmentPosterLayout.darkBloom);
    await expectLater(find.byKey(const Key('poster')), matchesGoldenFile('goldens/probe_dark.png'));
  });
}