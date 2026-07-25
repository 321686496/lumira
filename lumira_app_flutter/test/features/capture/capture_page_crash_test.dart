import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/pages/capture_page.dart';
import 'package:lumira_app_flutter/features/capture/widgets/camera_preview.dart';

import '../../../test/helpers/test_http_overrides.dart';

void main() {
  late GoRouter router;
  FlutterExceptionHandler? originalErrorHandler;

  setUp(() {
    HttpOverrides.global = TestHttpOverrides();
    originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('NetworkImageLoadException')) {
        return;
      }
      // Capture all other errors as failures
      fail('FlutterError during test: ${details.exception}\n${details.stack}');
    };
    router = GoRouter(
      initialLocation: '/capture',
      routes: [
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('home'))),
        ),
        GoRoute(
          path: '/capture',
          name: 'capture',
          builder: (_, state) {
            final templateId = state.queryParams['templateId'];
            return CapturePage(templateId: templateId);
          },
        ),
      ],
    );
  });

  tearDown(() {
    HttpOverrides.global = null;
    FlutterError.onError = originalErrorHandler;
  });

  testWidgets('dispose() does not throw deactivated-ancestor assertion',
      (tester) async {
    const cameraPlaceholder = ColoredBox(
      key: Key('camera_placeholder'),
      color: Color(0xFF333333),
      child: SizedBox.expand(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
          uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
          cameraPreviewOverrideProvider.overrideWith((ref) => cameraPlaceholder),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CapturePage), findsOneWidget);

    // Pop the page to trigger dispose()
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    // Force a frame to finalize tree (this is where the assertion fired)
    await tester.pumpAndSettle();

    // If we reach here without fail(), the crash is fixed
    expect(find.byType(CapturePage), findsNothing);
  });
}
