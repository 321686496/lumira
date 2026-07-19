import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/templates/pages/templates_unlock_page.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

/// Task 2.8B — TemplatesUnlockPage 测试
///
/// 覆盖 brief 第 5.2 节 ≥12 项断言 + cross-theme/cross-style smoke test。
void main() {
  FlutterExceptionHandler? originalErrorHandler;

  setUp(() {
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

  Widget wrap({
    required ThemeKey themeKey,
    required UIStyle uiStyle,
    String initialLocation = '/templates/unlock',
  }) {
    final goRouter = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/templates/unlock',
          name: 'templatesUnlock',
          builder: (_, __) => const TemplatesUnlockPage(),
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
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (_, __) => const _HomeStubPage(),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
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

  group('TemplatesUnlockPage — locked state rendering', () {
    testWidgets('renders LumiraNav with title 解锁模板', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.widgetWithText(LumiraNav, '解锁模板'), findsOneWidget);
    });

    testWidgets('renders preview card with title 日系胶片 · 精选模板',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('日系胶片 · 精选模板'), findsOneWidget);
    });

    testWidgets('renders preview desc', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('包含 12 级胶片颗粒 · 暖调偏移 · 柔光晕影'), findsOneWidget);
    });

    testWidgets('renders 3 preview tags', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('胶片'), findsOneWidget);
      expect(find.text('日系'), findsOneWidget);
      expect(find.text('人像'), findsOneWidget);
    });

    testWidgets('renders lock badge in locked state', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 锁定态：预览卡 lock-badge 中的 Icons.lock 存在
      // 注意：_BottomNote 中也使用 Icons.lock_open，故不断言 lock_open 缺席
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });

    testWidgets('renders subtitle 解锁方式任选其一', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('解锁方式任选其一'), findsOneWidget);
      expect(find.text('完成任意一项即可永久解锁'), findsOneWidget);
    });

    testWidgets('renders option 1 看广告解锁（30秒）', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('看广告解锁（30秒）'), findsOneWidget);
      expect(find.text('观看一段短视频广告即可解锁'), findsOneWidget);
      expect(find.text('立即观看'), findsOneWidget);
    });

    testWidgets('renders option 2 分享给好友（2/3）', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('分享给好友（2/3）'), findsOneWidget);
      expect(find.text('累计分享 3 位好友即可解锁'), findsOneWidget);
      expect(find.text('继续分享'), findsOneWidget);
    });

    testWidgets('renders option 3 拍摄 5 张照片（3/5）', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('拍摄 5 张照片（3/5）'), findsOneWidget);
      expect(find.text('完成 5 张拍摄任务即可解锁'), findsOneWidget);
      expect(find.text('去拍摄'), findsOneWidget);
    });

    testWidgets('renders option 4 输入兑换码', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('输入兑换码'), findsOneWidget);
      expect(find.text('使用兑换码直接解锁模板'), findsOneWidget);
      expect(find.text('输入'), findsOneWidget);
    });

    testWidgets('renders option 5 ¥3.00 直接购买', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('¥3.00 直接购买'), findsOneWidget);
      expect(find.text('一次购买，永久使用'), findsOneWidget);
      expect(find.text('购买'), findsOneWidget);
    });

    testWidgets('renders bottom note 解锁后永久使用', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('解锁后永久使用'), findsOneWidget);
    });
  });

  group('TemplatesUnlockPage — interactions', () {
    testWidgets('tapping 立即观看 shows ad SnackBar then unlocks after 1200ms',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击 立即观看
      await tester.tap(find.text('立即观看'));
      await tester.pump(const Duration(milliseconds: 500));

      // 广告播放中 SnackBar 出现
      expect(find.text('广告播放中…'), findsOneWidget);

      // 推进时间至 1200ms 之后
      await tester.pump(const Duration(milliseconds: 1300));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 解锁后 success card 出现（desc 唯一）
      expect(find.text('日系胶片 · 精选模板已永久解锁'), findsOneWidget);
      // 选项列表消失
      expect(find.text('解锁方式任选其一'), findsNothing);
    });

    testWidgets('tapping 继续分享 shows SnackBar 分享成功 +1', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('继续分享'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('分享成功 +1'), findsOneWidget);
    });

    testWidgets('tapping 去拍摄 navigates to /capture', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('去拍摄'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('CAPTURE_PAGE'), findsOneWidget);
    });

    testWidgets('tapping 输入 shows code input dialog with TextField',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('输入'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('输入兑换码'), findsNWidgets(2)); // 选项 title + dialog title
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('确认'), findsOneWidget);
    });

    testWidgets('entering code and confirming unlocks', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('输入'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 输入兑换码
      await tester.enterText(find.byType(TextField), 'TESTCODE');
      // 点击对话框中的 确认（区别于选项列表中的 输入 按钮）
      await tester.tap(find.text('确认'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 解锁成功 SnackBar + success card 出现
      expect(find.text('日系胶片 · 精选模板已永久解锁'), findsOneWidget);
      expect(find.text('解锁方式任选其一'), findsNothing);
    });

    testWidgets('tapping 购买 shows pay popup', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('购买'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 弹窗内容：确认支付（title + button，2 个） + ¥3.00 + 取消 + 描述
      expect(find.text('确认支付'), findsNWidgets(2));
      expect(find.text('¥3.00'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('日系胶片 · 精选模板 · 永久使用'), findsOneWidget);
    });

    testWidgets('tapping 取消 in pay popup closes popup without unlocking',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('购买'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击 取消 关闭弹窗
      await tester.tap(find.text('取消'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 弹窗消失
      expect(find.text('¥3.00'), findsNothing);
      // 仍然锁定
      expect(find.text('解锁方式任选其一'), findsOneWidget);
    });

    testWidgets('tapping 确认支付 unlocks and shows SnackBar', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('购买'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击 确认支付（第二个匹配项是按钮，第一个是 title）
      await tester.tap(find.text('确认支付').at(1));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 解锁成功 SnackBar 出现（content 文本 '解锁成功'，与 success card title 同名，至少 1 个）
      expect(find.text('解锁成功'), findsAtLeastNWidgets(1));
      // success card 出现
      expect(find.text('日系胶片 · 精选模板已永久解锁'), findsOneWidget);
      // 选项列表消失
      expect(find.text('解锁方式任选其一'), findsNothing);
    });
  });

  group('TemplatesUnlockPage — unlocked state', () {
    testWidgets('renders success card when unlocked', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 通过 立即观看 触发解锁
      await tester.tap(find.text('立即观看'));
      await tester.pump(const Duration(milliseconds: 1300));
      await settleOrPump(tester, UIStyle.neumorphic);

      // success card 内容
      expect(find.text('解锁成功'), findsAtLeastNWidgets(1));
      expect(find.text('日系胶片 · 精选模板已永久解锁'), findsOneWidget);
      expect(find.text('开始使用'), findsOneWidget);
    });

    testWidgets('tapping 开始使用 pops the page', (tester) async {
      setLargeViewport(tester);
      // 使用 /home 为初始路由，再 push /templates/unlock
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: '/home',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 从 home 推入 unlock 页
      final homeContext = tester.element(find.text('HOME_PAGE'));
      GoRouter.of(homeContext).push('/templates/unlock');
      await settleOrPump(tester, UIStyle.neumorphic);

      // 通过 立即观看 触发解锁
      await tester.tap(find.text('立即观看'));
      await tester.pump(const Duration(milliseconds: 1300));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击 开始使用
      await tester.tap(find.text('开始使用'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 返回 home 页
      expect(find.text('HOME_PAGE'), findsOneWidget);
    });
  });

  group('TemplatesUnlockPage — smoke tests', () {
    testWidgets('renders without FlutterError under 8 themes', (tester) async {
      for (final theme in ThemeKey.values) {
        setLargeViewport(tester);
        await tester.pumpWidget(
            wrap(themeKey: theme, uiStyle: UIStyle.neumorphic));
        await settleOrPump(tester, UIStyle.neumorphic);
        expect(find.text('解锁模板'), findsOneWidget, reason: 'theme=$theme');
        expect(find.text('看广告解锁（30秒）'), findsOneWidget,
            reason: 'theme=$theme');
      }
    });

    testWidgets('renders without FlutterError under 4 styles', (tester) async {
      for (final style in UIStyle.values) {
        setLargeViewport(tester);
        await tester.pumpWidget(
            wrap(themeKey: ThemeKey.warmWhite, uiStyle: style));
        await settleOrPump(tester, style);
        expect(find.text('解锁模板'), findsOneWidget, reason: 'style=$style');
        expect(find.text('看广告解锁（30秒）'), findsOneWidget,
            reason: 'style=$style');
      }
    });
  });
}

/// 用于测试 pop 行为的 home 占位页（包含跳转 unlock 页的入口）
class _HomeStubPage extends StatelessWidget {
  const _HomeStubPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('HOME_PAGE')),
    );
  }
}
