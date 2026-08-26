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
import 'package:lumira_app_flutter/features/templates/data/owned_templates_repository.dart';
import 'package:lumira_app_flutter/features/points/data/points_models.dart';
import 'package:lumira_app_flutter/features/points/data/points_repository.dart';
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
    int? price,
    String? templateId,
    int freeUnlockCount = 0,
  }) {
    final goRouter = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/templates/unlock',
          name: 'templatesUnlock',
          builder: (_, __) =>
              TemplatesUnlockPage(templateId: templateId, price: price),
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
        GoRoute(
          path: RouteNames.profileInvite,
          name: 'profileInvite',
          builder: (_, __) => const Scaffold(body: Center(child: Text('INVITE_PAGE'))),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => themeKey),
        uiStyleProvider.overrideWith((ref) => uiStyle),
        ownedTemplatesRepositoryProvider.overrideWith(
            (ref) async => _MockOwnedTemplatesRepository()),
        pointsRepositoryProvider.overrideWith(
            (ref) async => _MockPointsRepository(freeUnlockCount)),
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

    testWidgets('renders option 1 积分解锁', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('0 积分解锁'), findsOneWidget);
      expect(find.text('消耗积分，永久使用'), findsOneWidget);
      expect(find.text('解锁'), findsOneWidget);
    });

    testWidgets('renders option 2 输入兑换码', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('输入兑换码'), findsOneWidget);
      expect(find.text('使用兑换码直接解锁模板'), findsOneWidget);
      expect(find.text('输入'), findsOneWidget);
    });

    testWidgets('renders option 3 分享给好友', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('分享给好友'), findsOneWidget);
      expect(find.text('邀请好友赚积分 / 兑换模板'), findsOneWidget);
      expect(find.text('去邀请'), findsOneWidget);
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
    testWidgets('tapping 积分购买 shows pay popup', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(
              themeKey: ThemeKey.warmWhite,
              uiStyle: UIStyle.neumorphic,
              price: 18,
              templateId: 'cafe_portrait'));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('解锁'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 弹窗内容：标题 + 价格 + 描述 + 取消/确认
      expect(find.text('积分解锁'), findsOneWidget);
      expect(find.text('18 积分'), findsOneWidget);
      expect(find.text('消耗 18 积分，永久解锁该模板'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
    });

    testWidgets('tapping 去邀请 navigates to /profile/invite', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('去邀请'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('INVITE_PAGE'), findsOneWidget);
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

    testWidgets('tapping 取消 in pay popup closes popup without unlocking',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(
              themeKey: ThemeKey.warmWhite,
              uiStyle: UIStyle.neumorphic,
              price: 18,
              templateId: 'cafe_portrait'));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('解锁'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击 取消 关闭弹窗
      await tester.tap(find.text('取消'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 弹窗消失，仍为锁定态
      expect(find.text('18 积分'), findsNothing);
      expect(find.text('解锁方式任选其一'), findsOneWidget);
    });

    testWidgets('tapping 取消 in code dialog closes without unlocking',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('输入'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 取消兑换码对话框
      await tester.tap(find.text('取消'));
      await settleOrPump(tester, UIStyle.neumorphic);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('解锁方式任选其一'), findsOneWidget);
    });

  });

  group('TemplatesUnlockPage — unlocked state', () {
    testWidgets('renders success card when unlocked', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(
              themeKey: ThemeKey.warmWhite,
              uiStyle: UIStyle.neumorphic,
              price: 18,
              templateId: 'cafe_portrait'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 积分购买 → 确认弹窗 → mock exchange 成功
      await tester.tap(find.text('解锁'));
      await settleOrPump(tester, UIStyle.neumorphic);
      await tester.tap(find.text('确认解锁'));
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
        price: 18,
        templateId: 'cafe_portrait',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 从 home 推入 unlock 页
      final homeContext = tester.element(find.text('HOME_PAGE'));
      GoRouter.of(homeContext).push('/templates/unlock');
      await settleOrPump(tester, UIStyle.neumorphic);

      // 积分购买 → 确认 → mock exchange 成功
      await tester.tap(find.text('解锁'));
      await settleOrPump(tester, UIStyle.neumorphic);
      await tester.tap(find.text('确认解锁'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击 开始使用
      await tester.tap(find.text('开始使用'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 返回 home 页
      expect(find.text('HOME_PAGE'), findsOneWidget);
    });
  });

  group('TemplatesUnlockPage — free unlock', () {
    testWidgets('banner shows free count when N>0', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
          themeKey: ThemeKey.warmWhite,
          uiStyle: UIStyle.neumorphic,
          price: 18,
          templateId: 'cafe_portrait',
          freeUnlockCount: 2));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(
          find.text('免费解锁 ×2：可在解锁页任选付费模板，不消耗积分'),
          findsOneWidget);
      expect(find.textContaining('免费解锁 ×0'), findsNothing);
    });

    testWidgets('banner shows ×0 hint when N==0', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
          themeKey: ThemeKey.warmWhite,
          uiStyle: UIStyle.neumorphic,
          freeUnlockCount: 0));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(
          find.text('免费解锁 ×0：邀请好友可获取免费解锁次数'),
          findsOneWidget);
    });

    testWidgets('N>0: tapping 解锁 opens choice dialog', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
          themeKey: ThemeKey.warmWhite,
          uiStyle: UIStyle.neumorphic,
          price: 18,
          templateId: 'cafe_portrait',
          freeUnlockCount: 2));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('解锁'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('选择解锁方式'), findsOneWidget);
      expect(find.text('免费解锁（剩余 ×2）'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
    });

    testWidgets('N>0: choose free unlock unlocks via free_unlock',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
          themeKey: ThemeKey.warmWhite,
          uiStyle: UIStyle.neumorphic,
          price: 18,
          templateId: 'cafe_portrait',
          freeUnlockCount: 2));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('解锁'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 选择免费解锁 → 弹出免费解锁确认
      await tester.tap(find.text('免费解锁（剩余 ×2）'));
      await settleOrPump(tester, UIStyle.neumorphic);
      expect(find.text('免费解锁'), findsAtLeastNWidgets(1));
      expect(find.text('确认免费解锁'), findsOneWidget);

      await tester.tap(find.text('确认免费解锁'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('解锁成功'), findsAtLeastNWidgets(1));
    });

    testWidgets('N>0: choose points shows pay popup', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
          themeKey: ThemeKey.warmWhite,
          uiStyle: UIStyle.neumorphic,
          price: 18,
          templateId: 'cafe_portrait',
          freeUnlockCount: 2));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('解锁'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 选择积分项（弹窗中的项在树中靠后，用 .last）
      await tester.tap(find.text('18 积分解锁').last);
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('选择解锁方式'), findsNothing);
      expect(find.text('18 积分'), findsOneWidget); // pay popup
      expect(find.text('确认解锁'), findsOneWidget);
    });

    testWidgets('N==0: tapping 解锁 goes straight to pay popup',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
          themeKey: ThemeKey.warmWhite,
          uiStyle: UIStyle.neumorphic,
          price: 18,
          templateId: 'cafe_portrait',
          freeUnlockCount: 0));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('解锁'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('选择解锁方式'), findsNothing);
      expect(find.text('18 积分'), findsOneWidget); // pay popup
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
        expect(find.text('0 积分解锁'), findsOneWidget, reason: 'theme=$theme');
      }
    });

    testWidgets('renders without FlutterError under 4 styles', (tester) async {
      for (final style in UIStyle.values) {
        setLargeViewport(tester);
        await tester.pumpWidget(
            wrap(themeKey: ThemeKey.warmWhite, uiStyle: style));
        await settleOrPump(tester, style);
        expect(find.text('解锁模板'), findsOneWidget, reason: 'style=$style');
        expect(find.text('0 积分解锁'), findsOneWidget, reason: 'style=$style');
      }
    });
  });
}

class _MockPointsRepository implements PointsRepository {
  _MockPointsRepository(this.freeUnlockCount);
  final int freeUnlockCount;

  @override
  Future<PointsBalance> getBalance() async => PointsBalance(
        deviceId: 'test-device',
        balance: 100,
        totalEarned: 100,
        totalSpent: 0,
        freeUnlockCount: freeUnlockCount,
      );

  @override
  Future<PointsTransactions> listTransactions({
    int limit = 50,
    int offset = 0,
  }) async =>
      const PointsTransactions(transactions: [], total: 0);

  @override
  Future<PointEarnResult> earn({required String type, String? refId}) async =>
      const PointEarnResult(granted: false, delta: 0, balance: 0);
}

class _MockOwnedTemplatesRepository implements OwnedTemplatesRepository {
  @override
  Future<OwnedTemplates> listOwned() =>
      throw UnimplementedError('unlock page test does not call listOwned');

  @override
  Future<TemplatePrices> listPrices() =>
      throw UnimplementedError('unlock page test does not call listPrices');

  @override
  Future<TemplateExchangeResult> exchange(
    String templateId, {
    int? priceCredits,
    String payBy = 'points',
  }) async {
    return TemplateExchangeResult(
      success: true,
      templateId: templateId,
      spentCredits: payBy == 'free_unlock' ? 0 : (priceCredits ?? 0),
      balance: payBy == 'free_unlock' ? 0 : 100,
      payBy: payBy,
    );
  }
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
