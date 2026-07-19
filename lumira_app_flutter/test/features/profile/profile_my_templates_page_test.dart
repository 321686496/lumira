import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/core/utils/number_format.dart';
import 'package:lumira_app_flutter/features/profile/data/profile_content_mock_data.dart';
import 'package:lumira_app_flutter/features/profile/pages/profile_my_templates_page.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

void main() {
  late GoRouter router;
  FlutterExceptionHandler? originalErrorHandler;

  setUp(() {
    router = GoRouter(
      initialLocation: RouteNames.profileMyTemplates,
      routes: [
        GoRoute(
          path: RouteNames.profileMyTemplates,
          name: 'profileMyTemplates',
          builder: (_, __) => const ProfileMyTemplatesPage(),
        ),
        GoRoute(
          path: RouteNames.templatesEditor,
          name: 'templatesEditor',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('TEMPLATES_EDITOR'))),
        ),
        GoRoute(
          path: RouteNames.capture,
          name: 'capture',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('CAPTURE_PAGE'))),
        ),
      ],
    );
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
    HttpOverrides.global = null;
    FlutterError.onError = originalErrorHandler;
  });

  Widget wrap(ThemeKey themeKey, UIStyle uiStyle) {
    return ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => themeKey),
        uiStyleProvider.overrideWith((ref) => uiStyle),
      ],
      child: MaterialApp.router(routerConfig: router),
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

  group('ProfileMyTemplatesPage', () {
    testWidgets('renders LumiraNav with title 我的模板 and StatsBar', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.byType(ProfileMyTemplatesPage), findsOneWidget);
      expect(find.widgetWithText(LumiraNav, '我的模板'), findsOneWidget);

      // StatsBar：5 个模板 / 2,871 次使用 / 2 个收藏
      // totalUsage = 1280 + 856 + 432 + 215 + 88 = 2871
      expect(find.text('5'), findsOneWidget);
      expect(find.text(formatThousands(ProfileContentMockData.totalUsage)), findsOneWidget);
      expect(find.text('2,871'), findsOneWidget);
      expect(find.text('${ProfileContentMockData.favoriteCount}'), findsOneWidget);
      expect(find.text('自定义模板'), findsOneWidget);
      expect(find.text('使用次数'), findsOneWidget);
      expect(find.text('收藏'), findsOneWidget);
    });

    testWidgets('renders all 5 custom templates in list', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 5 个自定义模板名
      expect(find.text('复古胶片人像'), findsOneWidget); // tpl_001
      expect(find.text('日落山景'), findsOneWidget); // tpl_002
      expect(find.text('咖啡馆俯拍'), findsOneWidget); // tpl_003
      expect(find.text('夜景街拍'), findsOneWidget); // tpl_004
      expect(find.text('微距花卉'), findsOneWidget); // tpl_005

      // 验证 mock 数据条目数与页面一致
      expect(ProfileContentMockData.customTemplates.length, 5);
    });

    testWidgets('renders action bar with 新建模板 and 导入模板 buttons', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('新建模板'), findsOneWidget);
      expect(find.text('导入模板'), findsOneWidget);
    });

    testWidgets('renders filter bar with 5 filter pills', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 5 个 filter pills
      // 注意：'人像' / '风光' / '美食' 同时出现在 FilterPill 和模板行的 tpl-cat-tag 中
      // 所以用 findsAtLeastNWidgets(1) 验证 FilterPill 存在
      expect(find.text('全部'), findsOneWidget);
      expect(find.text('人像'), findsAtLeastNWidgets(1));
      expect(find.text('风光'), findsAtLeastNWidgets(1));
      expect(find.text('美食'), findsAtLeastNWidgets(1));
      expect(find.text('其他'), findsOneWidget);
    });

    testWidgets('tapping filter 人像 shows only tpl_001 (portrait)', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 初始 5 个模板
      expect(find.text('复古胶片人像'), findsOneWidget);
      expect(find.text('日落山景'), findsOneWidget);
      expect(find.text('咖啡馆俯拍'), findsOneWidget);
      expect(find.text('夜景街拍'), findsOneWidget);
      expect(find.text('微距花卉'), findsOneWidget);

      // 点击 "人像" filter
      // 注意：'人像' 同时出现在 FilterPill 和 tpl_001 的 tpl-cat-tag 中
      // FilterPill 在前（widget 树顺序），用 .first 选择 FilterPill
      await tester.tap(find.text('人像').first);
      await settleOrPump(tester, UIStyle.neumorphic);

      // 仅显示 portrait 类别的 tpl_001
      expect(find.text('复古胶片人像'), findsOneWidget);
      expect(find.text('日落山景'), findsNothing);
      expect(find.text('咖啡馆俯拍'), findsNothing);
      expect(find.text('夜景街拍'), findsNothing);
      expect(find.text('微距花卉'), findsNothing);
    });

    testWidgets('tapping filter 风光 shows only tpl_002 (landscape)', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // '风光' 同时出现在 FilterPill 和 tpl_002 的 tpl-cat-tag 中
      await tester.tap(find.text('风光').first);
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('复古胶片人像'), findsNothing);
      expect(find.text('日落山景'), findsOneWidget);
      expect(find.text('咖啡馆俯拍'), findsNothing);
      expect(find.text('夜景街拍'), findsNothing);
      expect(find.text('微距花卉'), findsNothing);
    });

    testWidgets('tapping filter 美食 shows only tpl_003 (food)', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // '美食' 同时出现在 FilterPill 和 tpl_003 的 tpl-cat-tag 中
      await tester.tap(find.text('美食').first);
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('复古胶片人像'), findsNothing);
      expect(find.text('日落山景'), findsNothing);
      expect(find.text('咖啡馆俯拍'), findsOneWidget);
      expect(find.text('夜景街拍'), findsNothing);
      expect(find.text('微距花卉'), findsNothing);
    });

    testWidgets('tapping filter 其他 shows tpl_004 + tpl_005 (street + macro)', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // '其他' 只出现在 FilterPill（不是分类标签）
      await tester.tap(find.text('其他'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('复古胶片人像'), findsNothing); // portrait
      expect(find.text('日落山景'), findsNothing); // landscape
      expect(find.text('咖啡馆俯拍'), findsNothing); // food
      expect(find.text('夜景街拍'), findsOneWidget); // street
      expect(find.text('微距花卉'), findsOneWidget); // macro
    });

    testWidgets('tapping filter 全部 shows all 5 templates', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 先切换到 人像（用 .first 选择 FilterPill）
      await tester.tap(find.text('人像').first);
      await settleOrPump(tester, UIStyle.neumorphic);
      expect(find.text('日落山景'), findsNothing);

      // 再切回 全部
      await tester.tap(find.text('全部'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('复古胶片人像'), findsOneWidget);
      expect(find.text('日落山景'), findsOneWidget);
      expect(find.text('咖啡馆俯拍'), findsOneWidget);
      expect(find.text('夜景街拍'), findsOneWidget);
      expect(find.text('微距花卉'), findsOneWidget);
    });

    testWidgets('tapping 新建模板 button pushes /templates/editor', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 新建模板 是 LumiraButton 中的 label 文本
      await tester.tap(find.text('新建模板'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 跳转到 templatesEditor
      expect(find.text('TEMPLATES_EDITOR'), findsOneWidget);
    });

    testWidgets('long-pressing a template shows action sheet with 5 actions', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 初始无 ActionSheet
      expect(find.text('编辑模板'), findsNothing);
      expect(find.text('套用拍摄'), findsNothing);
      expect(find.text('复制模板'), findsNothing);
      expect(find.text('导出 .pptpl'), findsNothing);
      expect(find.text('删除模板'), findsNothing);
      expect(find.text('取消'), findsNothing);

      // 长按第一个模板 '复古胶片人像'
      await tester.longPress(find.text('复古胶片人像'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 应出现 ActionSheet 含 5 个动作 + 取消
      expect(find.text('编辑模板'), findsOneWidget);
      expect(find.text('套用拍摄'), findsOneWidget);
      expect(find.text('复制模板'), findsOneWidget);
      expect(find.text('导出 .pptpl'), findsOneWidget);
      expect(find.text('删除模板'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
    });

    testWidgets('tapping 复制模板 in action sheet closes sheet and shows SnackBar 已复制', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 长按模板打开 ActionSheet
      await tester.longPress(find.text('复古胶片人像'));
      await settleOrPump(tester, UIStyle.neumorphic);
      expect(find.text('复制模板'), findsOneWidget);

      // 点击 复制模板
      await tester.tap(find.text('复制模板'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // ActionSheet 关闭
      expect(find.text('编辑模板'), findsNothing);
      expect(find.text('套用拍摄'), findsNothing);
      expect(find.text('复制模板'), findsNothing);
      expect(find.text('导出 .pptpl'), findsNothing);
      expect(find.text('删除模板'), findsNothing);

      // SnackBar 显示
      expect(find.text('已复制'), findsOneWidget);
    });

    testWidgets('tapping 删除模板 in action sheet closes sheet and shows SnackBar 已删除', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.longPress(find.text('日落山景'));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('删除模板'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // ActionSheet 关闭
      expect(find.text('删除模板'), findsNothing);
      // SnackBar 显示
      expect(find.text('已删除'), findsOneWidget);
    });

    testWidgets('tapping 导出 .pptpl in action sheet closes sheet and shows SnackBar 导出中...', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.longPress(find.text('咖啡馆俯拍'));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('导出 .pptpl'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // ActionSheet 关闭
      expect(find.text('导出 .pptpl'), findsNothing);
      // SnackBar 显示
      expect(find.text('导出中...'), findsOneWidget);
    });

    testWidgets('tapping 取消 in action sheet closes sheet without SnackBar', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.longPress(find.text('复古胶片人像'));
      await settleOrPump(tester, UIStyle.neumorphic);
      expect(find.text('取消'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // ActionSheet 关闭
      expect(find.text('编辑模板'), findsNothing);
      expect(find.text('取消'), findsNothing);
    });

    testWidgets('tapping 拍摄 button on template row pushes /capture with templateId', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 模板行上的 '拍摄' 按钮
      final applyBtn = find.text('拍摄');
      expect(applyBtn, findsNWidgets(5)); // 5 个模板行各 1 个

      // 点击第 1 个（复古胶片人像）
      await tester.tap(applyBtn.first);
      await settleOrPump(tester, UIStyle.neumorphic);

      // 跳转到 capture
      expect(find.text('CAPTURE_PAGE'), findsOneWidget);
    });

    testWidgets('renders correctly across all 8 themes', (tester) async {
      setLargeViewport(tester);
      for (final theme in ThemeKey.values) {
        await tester.pumpWidget(wrap(theme, UIStyle.neumorphic));
        await settleOrPump(tester, UIStyle.neumorphic);
        expect(find.byType(ProfileMyTemplatesPage), findsOneWidget, reason: 'theme=$theme');
        expect(find.text('我的模板'), findsOneWidget, reason: 'theme=$theme');
        expect(find.text('复古胶片人像'), findsOneWidget, reason: 'theme=$theme');
      }
    });

    testWidgets('renders correctly across all 4 UI styles', (tester) async {
      setLargeViewport(tester);
      for (final style in UIStyle.values) {
        await tester.pumpWidget(wrap(ThemeKey.warmWhite, style));
        await settleOrPump(tester, style);
        expect(find.byType(ProfileMyTemplatesPage), findsOneWidget, reason: 'style=$style');
        expect(find.text('我的模板'), findsOneWidget, reason: 'style=$style');
        expect(find.text('复古胶片人像'), findsOneWidget, reason: 'style=$style');
      }
    });
  });
}
