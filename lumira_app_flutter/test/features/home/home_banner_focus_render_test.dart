import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/home/data/home_mock_data.dart';
import 'package:lumira_app_flutter/features/home/providers/banner_recommendation_provider.dart';
import 'package:lumira_app_flutter/features/home/widgets/home_banner.dart';
import 'package:lumira_app_flutter/features/usage/usage_providers.dart';

const String _onePixelPng =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/x8AAwMB/6X0mQAAAABJRU5ErkJggg==';

void main() {
  testWidgets('operation banner image renders as full-bleed background',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
          uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
          bannerRecommendationProvider.overrideWith((ref) async => const [
                HomeBannerItem(
                  id: 'op_focus',
                  title: 'Focused banner',
                  subtitle: 'Full bleed',
                  imageSeed: 'op_focus',
                  tag: 'Focus',
                  route: '/invite',
                  coverData: _onePixelPng,
                  type: BannerType.operation,
                  bannerId: 'op_focus',
                  focusX: 0.25,
                  focusY: 0.75,
                  focusZoom: 1.5,
                ),
              ]),
          usageEventRecorderProvider
              .overrideWith((ref) async => throw Exception('unused')),
        ],
        child: const MaterialApp(home: Scaffold(body: HomeBanner())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Focused banner'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(HomeBanner),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Row &&
              widget.crossAxisAlignment == CrossAxisAlignment.stretch,
        ),
      ),
      findsNothing,
    );
  });
}
