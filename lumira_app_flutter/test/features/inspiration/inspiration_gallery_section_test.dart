import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/inspiration/data/inspiration_content.dart';
import 'package:lumira_app_flutter/features/inspiration/data/inspiration_providers.dart';
import 'package:lumira_app_flutter/features/inspiration/widgets/inspiration_gallery_section.dart';

void main() {
  testWidgets('renders local gallery grid and triggers onItemTap',
      (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(800, 2800);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    final tapped = <String>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: InspirationGallerySection(
            onItemTap: (item) => tapped.add(item.templateId),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('灵感图集'), findsOneWidget);
    expect(find.text('咖啡馆人像 · 窗边柔光'), findsOneWidget);
    expect(find.text('柔光人像 · 奶油质感'), findsOneWidget);

    await tester.tap(find.text('咖啡馆人像 · 窗边柔光'));
    expect(tapped, ['cafe_portrait']);
  });
}
