import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/templates/data/owned_templates_repository.dart';
import 'package:lumira_app_flutter/features/templates/pages/templates_detail_page.dart';
import 'package:lumira_app_flutter/features/templates/widgets/pose_silhouette.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

/// Task 2.8A — TemplatesDetailPage 测试
///
/// 覆盖 brief 第 6 节 "Page 1" 的 13 项断言 + cross-theme/cross-style smoke test。
/// 注意：测试名不要 overpromise（#59/#60/#61 教训）— 仅断言实际渲染的文本与组件。
void main() {
  FlutterExceptionHandler? originalErrorHandler;
  late ProviderContainer dbContainer;
  late Database db;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    // Forced fix: 详情页 build 会经 ownedTemplatesLoaderProvider 惰性打开 sqflite。
    // 在 setUp 的 real async zone 中预打开数据库（首个测试建库+seed），并在 wrap 的
    // ProviderScope 中 override 复用该已打开的 Database 实例 —— pumpAndSettle
    // （fake async）期间只发生 microtask 级查询，避免真实文件 IO 无法被 fake async
    // 推进导致的超时。NoIsolate：DB 操作在主 isolate 同步执行。
    databaseFactory = databaseFactoryFfiNoIsolate;
    dbContainer = ProviderContainer();
    db = await dbContainer.read(databaseProvider.future);
    HttpOverrides.global = TestHttpOverrides();
    originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('NetworkImageLoadException')) {
        return;
      }
      originalErrorHandler?.call(details);
    };
  });

  tearDown(() {
    // 关闭数据库（databaseProvider 注册了 onDispose(db.close)）
    dbContainer.dispose();
    HttpOverrides.global = null;
    FlutterError.onError = originalErrorHandler;
  });

  Widget wrap(
    ThemeKey themeKey,
    UIStyle uiStyle, {
    String? templateId,
  }) {
    final goRouter = GoRouter(
      initialLocation: '/templates/detail',
      routes: [
        GoRoute(
          path: '/templates/detail',
          name: 'templatesDetail',
          builder: (_, __) => TemplatesDetailPage(templateId: templateId),
        ),
        GoRoute(
          path: RouteNames.capture,
          name: 'capture',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('CAPTURE_PAGE'))),
        ),
        GoRoute(
          path: RouteNames.templates,
          name: 'templates',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('TEMPLATES_PAGE'))),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        // 复用 setUp 预打开的 Database 实例，避免各测试重复建库/seed 及 fake async 文件 IO
        databaseProvider.overrideWith((ref) async => db),
        themeKeyProvider.overrideWith((ref) => themeKey),
        uiStyleProvider.overrideWith((ref) => uiStyle),
      ],
      child: MaterialApp.router(routerConfig: goRouter),
    );
  }

  Future<void> settleOrPump(WidgetTester tester, UIStyle style) async {
    if (style == UIStyle.female) {
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
  }

  void setLargeViewport(WidgetTester tester) {
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
  }

  group('TemplatesDetailPage', () {
    test('poseReferenceAspectRatio maps template ratios literally', () {
      const screen = Size(390, 844);
      // 模板宽高比 4:3 → 姿势参考卡片内容也是 4:3
      expect(
          poseReferenceAspectRatio('4:3', screen), closeTo(4.0 / 3.0, 0.001));
      // 16:9 同样按字面比例，不做方向自适应
      expect(
          poseReferenceAspectRatio('16:9', screen), closeTo(16.0 / 9.0, 0.001));
      expect(
          poseReferenceAspectRatio('3:4', screen), closeTo(3.0 / 4.0, 0.001));
      expect(poseReferenceAspectRatio('1:1', screen), closeTo(1.0, 0.001));
      // fullscreen 回退设备屏幕宽高比
      expect(poseReferenceAspectRatio('fullscreen', screen),
          closeTo(390 / 844, 0.001));
    });

    testWidgets('renders empty state when templateId is null', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: null,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('模板未找到'), findsOneWidget);
      expect(find.text('该模板可能已被删除或链接错误'), findsOneWidget);
    });

    testWidgets('renders empty state when templateId is not found',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: 'nonexistent_xyz',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 模板在 mock 快路径与本地库中均不存在 → 详情 provider 返回 null → 空态
      expect(find.text('模板未找到'), findsOneWidget);
      expect(find.text('该模板可能已被删除或链接错误'), findsOneWidget);
    });

    testWidgets('renders template name for free template', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: 'cafe_portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('咖啡馆人像'), findsOneWidget);
    });

    testWidgets('renders local cover image for builtin template',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: 'cafe_portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 封面应从本地 asset 加载（修复详情页封面加载不出来）
      final covers = tester
          .widgetList<Image>(find.byType(Image))
          .map((i) => i.image)
          .whereType<AssetImage>()
          .where((a) =>
              a.assetName == 'assets/images/templates/cafe_portrait.jpg');
      expect(covers, isNotEmpty, reason: '详情页应渲染咖啡馆人像本地封面图');
    });

    testWidgets('renders category label on preview image', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: 'cafe_portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // '人像' 来自 categoryLabel('portrait')，出现在预览图左上角 badge
      expect(find.text('人像'), findsOneWidget);
    });

    testWidgets('renders scene guide section with all 5 field labels',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: 'cafe_portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('场景指南'), findsOneWidget);
      expect(find.text('光线'), findsOneWidget);
      expect(find.text('距离'), findsOneWidget);
      expect(find.text('背景'), findsOneWidget);
      expect(find.text('道具'), findsOneWidget);
      expect(find.text('最佳时间'), findsOneWidget);
    });

    testWidgets('renders camera params with formatted values', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: 'cafe_portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('相机参数'), findsOneWidget);
      expect(find.text('EV +1'), findsOneWidget);
      expect(find.text('ISO 400'), findsOneWidget);
      expect(find.text('1/125s'), findsOneWidget);
    });

    testWidgets('renders post process params with LUT label', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: 'cafe_portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('后期参数'), findsOneWidget);
      expect(find.text('裁剪: 3:4'), findsOneWidget);
      // LUT 'warm_film' → '暖色胶片'
      expect(find.text('LUT: 暖色胶片'), findsOneWidget);
    });

    testWidgets('renders free unlock text for free template', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: 'cafe_portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // cafe_portrait price=0 → '免费' 出现在 title badge + unlock status
      expect(find.text('免费'), findsNWidgets(2));
    });

    testWidgets('renders premium unlock text for paid template',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: 'custom_golden_landscape',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // custom_golden_landscape price=18 → '18 积分' 出现在 title badge + unlock status
      expect(find.text('18 积分'), findsNWidgets(2));
    });

    testWidgets('locks camera/post-process params for unowned paid template',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: 'custom_golden_landscape',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 未解锁付费模板：隐藏相机/后期参数，显示锁定提示卡
      expect(find.text('相机 / 后期 / 滤镜参数已锁定'), findsOneWidget);
      expect(find.text('相机参数'), findsNothing);
      expect(find.text('后期参数'), findsNothing);
      // CTA 变为"试用 + 购买"
      expect(find.text('试用'), findsOneWidget);
      expect(find.text('18 积分解锁'), findsOneWidget);
      expect(find.text('套用此模板拍摄'), findsNothing);
    });

    testWidgets('renders full params for paid template after unlock',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
          uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
          // 模拟已解锁该付费模板
          ownedTemplateIdsProvider
              .overrideWith((ref) => <String>{'custom_golden_landscape'}),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/templates/detail',
            routes: [
              GoRoute(
                path: '/templates/detail',
                name: 'templatesDetail',
                builder: (_, __) => TemplatesDetailPage(
                  templateId: 'custom_golden_landscape',
                ),
              ),
              GoRoute(
                path: RouteNames.capture,
                name: 'capture',
                builder: (_, __) =>
                    const Scaffold(body: Center(child: Text('CAPTURE_PAGE'))),
              ),
              GoRoute(
                path: RouteNames.templatesUnlock,
                name: 'templatesUnlock',
                builder: (_, __) =>
                    const Scaffold(body: Center(child: Text('UNLOCK_PAGE'))),
              ),
            ],
          ),
        ),
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 已解锁：参数卡片可见，CTA 为"套用此模板拍摄"
      expect(find.text('相机参数'), findsOneWidget);
      expect(find.text('后期参数'), findsOneWidget);
      expect(find.text('套用此模板拍摄'), findsOneWidget);
      expect(find.text('试用'), findsNothing);
      expect(find.text('购买 ¥18'), findsNothing);
    });

    testWidgets('tapping 试用 navigates to /capture with trial param',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: 'custom_golden_landscape',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('试用'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 试用模式跳转 /capture（测试用 GoRouter 占位）
      expect(find.text('CAPTURE_PAGE'), findsOneWidget);
    });

    testWidgets('renders pose section when silhouette is not none',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: 'cafe_portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // cafe_portrait pose.silhouetteData='standing_basic' → hasSilhouette=true
      expect(find.text('姿势参考'), findsOneWidget);
    });

    testWidgets('pose reference card uses the template aspect ratio',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: 'cafe_portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      final aspect = tester.widget<AspectRatio>(
        find.byKey(const Key('pose_reference_card_aspect')),
      );
      // cafe_portrait aspectRatio='3:4' → 卡片内容宽高比 3:4
      expect(aspect.aspectRatio, closeTo(3.0 / 4.0, 0.001));
    });

    testWidgets(
        'pose reference card applies template silhouette scale/rotation',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: 'cafe_portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      final silhouette = tester.widget<PoseSilhouette>(
        find.descendant(
          of: find.byKey(const Key('pose_reference_card_aspect')),
          matching: find.byType(PoseSilhouette),
        ),
      );
      // 与模板提供的一致（mock cafe_portrait pose: scale 1.2 / rotation 8）
      expect(silhouette.scale, 1.2);
      expect(silhouette.rotation, 8);
    });

    testWidgets('hides pose section when silhouette is none', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: 'custom_golden_landscape',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // custom_golden_landscape pose.silhouetteData='none' → hasSilhouette=false
      expect(find.text('姿势参考'), findsNothing);
    });

    testWidgets('renders reference source text', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: 'cafe_portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('参数参考来源：摄影美学院 L03'), findsOneWidget);
    });

    testWidgets('tapping 套用此模板拍摄 button navigates to /capture page',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: 'cafe_portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击底部固定 CTA
      final ctaButton = find.text('套用此模板拍摄');
      expect(ctaButton, findsOneWidget);
      await tester.tap(ctaButton);
      await settleOrPump(tester, UIStyle.neumorphic);

      // 验证跳转到 /capture（路由由测试用 GoRouter 提供占位）
      expect(find.text('CAPTURE_PAGE'), findsOneWidget);
    });

    testWidgets('renders LumiraNav with title 模板详情', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        ThemeKey.warmWhite,
        UIStyle.neumorphic,
        templateId: 'cafe_portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.widgetWithText(LumiraNav, '模板详情'), findsOneWidget);
    });

    testWidgets('renders correctly across all 8 themes', (tester) async {
      setLargeViewport(tester);
      for (final theme in ThemeKey.values) {
        await tester.pumpWidget(wrap(
          theme,
          UIStyle.neumorphic,
          templateId: 'cafe_portrait',
        ));
        await settleOrPump(tester, UIStyle.neumorphic);
        expect(find.text('咖啡馆人像'), findsOneWidget, reason: 'theme=$theme');
        expect(find.text('场景指南'), findsOneWidget, reason: 'theme=$theme');
      }
    });

    testWidgets('renders correctly across all 4 UI styles', (tester) async {
      setLargeViewport(tester);
      for (final style in UIStyle.values) {
        await tester.pumpWidget(wrap(
          ThemeKey.warmWhite,
          style,
          templateId: 'cafe_portrait',
        ));
        await settleOrPump(tester, style);
        expect(find.text('咖啡馆人像'), findsOneWidget, reason: 'style=$style');
        expect(find.text('场景指南'), findsOneWidget, reason: 'style=$style');
      }
    });
  });
}
