import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/data/template_registry.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/capture/widgets/template_strip.dart';

void main() {
  group('TemplateStrip', () {
    testWidgets('compact mode renders 6 template cards', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: TemplateStrip(compact: true)),
          ),
        ),
      );
      // Resolve sortedTemplatesProvider so the data branch is tested
      // (not the loading fallback).
      await tester.pumpAndSettle();

      expect(find.byType(GestureDetector), findsNWidgets(6));
    });

    testWidgets('expanded mode renders all template cards', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Expand the test viewport so the lazy ListView.builder builds all cards
      // (each card is 72px + 8px margin = 80px, need enough width for all)
      final templateCount = TemplateRegistry.allTemplates.length;
      tester.binding.window.physicalSizeTestValue =
          Size(templateCount * 80 + 100, 600);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
      addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: TemplateStrip(compact: false)),
          ),
        ),
      );
      // Resolve sortedTemplatesProvider so the data branch is tested
      // (not the loading fallback).
      await tester.pumpAndSettle();

      // In test environment, sortedTemplatesProvider falls back to system templates
      expect(find.byType(GestureDetector), findsNWidgets(templateCount));
    });

    testWidgets('tapping a template card updates currentTemplateIdProvider',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: TemplateStrip(compact: true)),
          ),
        ),
      );

      expect(container.read(CaptureState.currentTemplateIdProvider), isNull);

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      expect(container.read(CaptureState.currentTemplateIdProvider), isNotNull);
    });

    testWidgets('active template card has amber border', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: TemplateStrip(compact: true)),
          ),
        ),
      );

      // Tap first card to make it active.
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      // The first Container should now have a non-null border.
      final containers = find.byType(Container);
      final firstContainerWidget = tester.widget<Container>(containers.first);
      final decoration = firstContainerWidget.decoration;
      expect(decoration, isA<BoxDecoration>());
      final boxDecoration = decoration as BoxDecoration;
      expect(boxDecoration.border, isNotNull);
    });

    testWidgets('custom template (not in TemplateRegistry) shows 我的 badge',
        (tester) async {
      // Use an id that does NOT exist in TemplateRegistry so isCustom == true.
      final customTemplate = PhotoTemplate(
        meta: TemplateMeta(
          id: 'custom_test_001',
          name: 'My Custom',
          category: 'portrait',
          classification: const TemplateClassification(type: 'portrait'),
        ),
        composition: const Composition(),
        pose: const Pose(),
        camera: const CameraParams(),
        sceneGuide: const SceneGuide(),
        postProcess: const PostProcess(color: PostProcessColor()),
      );

      final container = ProviderContainer(
        overrides: [
          CaptureState.sortedTemplatesProvider.overrideWith(
            (ref) async => <PhotoTemplate>[customTemplate],
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: TemplateStrip(compact: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('我的'), findsOneWidget);
    });

    testWidgets('empty template list shows 暂无模板 placeholder',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          CaptureState.sortedTemplatesProvider.overrideWith(
            (ref) async => <PhotoTemplate>[],
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: TemplateStrip(compact: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('暂无模板'), findsOneWidget);
    });

    testWidgets('error branch falls back to system templates',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          CaptureState.sortedTemplatesProvider.overrideWith(
            (ref) async => throw Exception('test error'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: TemplateStrip(compact: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Error branch falls back to system templates; compact mode shows 6.
      expect(find.byType(GestureDetector), findsNWidgets(6));
    });
  });
}
