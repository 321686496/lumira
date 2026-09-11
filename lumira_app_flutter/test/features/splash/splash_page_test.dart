import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/auth/auth_controller.dart';
import 'package:lumira_app_flutter/core/auth/auth_dao.dart';
import 'package:lumira_app_flutter/core/auth/auth_state.dart';
import 'package:lumira_app_flutter/core/compliance/compliance_gate.dart';
import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/splash/pages/splash_page.dart';
import 'package:lumira_app_flutter/shared/widgets/lumira/feedback/lumira_progress.dart';
import 'package:lumira_app_flutter/shared/widgets/brand/lumira_logo.dart';

/// 测试用 AuthDao stub（避免依赖 sqflite）
class _NoopDao implements AuthDaoLike {
  @override
  Future<AuthRecord?> load() async => null;
  @override
  Future<void> save(AuthRecord r) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<void> clearToken() async {}
}

/// 测试用 AuthController stub
///
/// 注意：原 plan 使用 Dart 3.0+ record 语法 `(token: '', isNewDevice: false)`，
/// 但项目环境为 Dart 2.19.6 不支持 records，改用 RegisterResult 类
class _FakeAuthController extends AuthController {
  _FakeAuthController(AuthState initial)
      : super(
          dao: _NoopDao(),
          resolveDeviceId: () async => '',
          resolveOs: () => 'android',
          doRegister: ({required deviceId, required os}) async {
            return const RegisterResult(token: '', isNewDevice: false);
          },
        ) {
    state = initial;
  }
}

Widget _wrapWithRouter(
  Widget child, {
  ThemeKey theme = ThemeKey.warmWhite,
  AuthState? authState,
  _FakeAuthController? authController,
  bool awaitingCompliance = false,
  bool failCompliancePersist = false,
}) {
  final router = GoRouter(
    initialLocation: RouteNames.splash,
    routes: [
      GoRoute(
        path: RouteNames.splash,
        name: 'splash',
        builder: (context, state) => child,
      ),
      GoRoute(
        path: RouteNames.home,
        name: 'home',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('HOME'))),
      ),
    ],
  );

  // 默认提供 registered 状态，避免触发 UnimplementedError
  final controller = authController ??
      _FakeAuthController(
        authState ?? const AuthState(status: AuthStatus.registered),
      );

  return ProviderScope(
    overrides: [
      themeKeyProvider.overrideWith((ref) => theme),
      uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
      authControllerProvider.overrideWith((ref) => controller),
      complianceAwaitingProvider.overrideWith((ref) => awaitingCompliance),
      // 如果要求模拟合规落库失败，则 settingsDaoProvider 直接抛出异常
      if (failCompliancePersist)
        settingsDaoProvider.overrideWith((ref) async {
          throw StateError('simulated persist failure');
        }),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('SplashPage renders logo + title + caption + brand halo', (tester) async {
    await tester.pumpWidget(_wrapWithRouter(const SplashPage()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('如画 Lumira'), findsOneWidget);
    expect(find.text('如你所见，皆成画卷'), findsOneWidget);
    expect(find.byType(LumiraLogo), findsOneWidget);
    // 主题色光晕：用 Stack + Container(circle + RadialGradient)
    expect(find.byType(Stack), findsWidgets);
  });

  testWidgets('SplashPage uses tokens.canvas as background', (tester) async {
    await tester.pumpWidget(_wrapWithRouter(const SplashPage()));
    await tester.pump(const Duration(milliseconds: 100));

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final tokens = ThemeTokens.of(ThemeKey.warmWhite);
    expect(scaffold.backgroundColor, tokens.canvas);
  });

  testWidgets('SplashPage renders across 8 themes without error',
      (tester) async {
    for (final theme in ThemeKey.values) {
      await tester.pumpWidget(_wrapWithRouter(const SplashPage(), theme: theme));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('如画 Lumira'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
    }
  });

  testWidgets('shows retry button when auth failed', (tester) async {
    await tester.pumpWidget(_wrapWithRouter(
      const SplashPage(),
      authState: const AuthState(
        status: AuthStatus.failed,
        lastError: 'network down',
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('网络连接失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    // 保留原 UI 不破坏
    expect(find.byType(LumiraLogo), findsOneWidget);
    expect(find.text('如画 Lumira'), findsOneWidget);
  });

  testWidgets('shows spinner when auth loading', (tester) async {
    await tester.pumpWidget(_wrapWithRouter(
      const SplashPage(),
      authState: const AuthState(status: AuthStatus.loading),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(LumiraProgress), findsOneWidget);
    // 保留原 UI 不破坏
    expect(find.byType(LumiraLogo), findsOneWidget);
  });

  testWidgets('clicking retry triggers registerIfNeeded', (tester) async {
    final fakeController = _FakeAuthController(
      const AuthState(
        status: AuthStatus.failed,
        lastError: 'network down',
      ),
    );

    await tester.pumpWidget(_wrapWithRouter(
      const SplashPage(),
      authController: fakeController,
    ));
    await tester.pump(const Duration(milliseconds: 100));

    // 初始状态：failed
    expect(fakeController.state.status, AuthStatus.failed);

    // 点击重试按钮
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    // 验证 registerIfNeeded 被触发：状态从 failed 转为 registered
    // （doRegister stub 立即返回成功，所以状态应为 registered）
    expect(fakeController.state.status, AuthStatus.registered);
  });

  testWidgets('未待同意时不弹合规窗', (tester) async {
    await tester.pumpWidget(_wrapWithRouter(const SplashPage()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('用户协议与隐私政策'), findsNothing);
  });

  testWidgets('待同意时弹出合规窗', (tester) async {
    await tester.pumpWidget(_wrapWithRouter(
      const SplashPage(),
      awaitingCompliance: true,
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('用户协议与隐私政策'), findsOneWidget);
    expect(find.text('同意并开始使用'), findsOneWidget);
    expect(find.text('不同意并退出'), findsOneWidget);
  });

  testWidgets('awaitingCompliance 且 auth 已注册：1.8s 后仍在弹窗不跳转', (tester) async {
    await tester.pumpWidget(_wrapWithRouter(
      const SplashPage(),
      authState: const AuthState(
        status: AuthStatus.registered,
        isNewDevice: false,
      ),
      awaitingCompliance: true,
    ));
    await tester.pump(const Duration(milliseconds: 1800)); // 越过原 1.8s redirectTimer
    // 关键回归断言：即使已注册，待同意时也绝不跳走、弹窗仍在
    expect(find.text('用户协议与隐私政策'), findsOneWidget);
  });

  testWidgets('同意落库失败：不清除 awaiting、不导航、重新弹窗可重试', (tester) async {
    await tester.pumpWidget(_wrapWithRouter(
      const SplashPage(),
      authState: const AuthState(
        status: AuthStatus.registered,
        isNewDevice: false,
      ),
      awaitingCompliance: true,
      failCompliancePersist: true, // settingsDaoProvider 抛错
    ));
    await tester.pump(const Duration(milliseconds: 100));

    // 容器引用，用于读取 awaiting 状态
    final ctx = tester.element(find.byType(SplashPage));
    final container = ProviderScope.containerOf(ctx, listen: false);

    // 待同意状态下点击“同意并开始使用”
    await tester.tap(find.text('同意并开始使用'));
    await tester.pumpAndSettle();

    // 落库失败：awaiting 必须仍为 true（不可视为已同意）
    expect(container.read(complianceAwaitingProvider), isTrue,
        reason: '落库失败时不得清除 awaiting 标志');
    // 不得导航离开 Splash（未跳转 home）
    expect(find.text('HOME'), findsNothing,
        reason: '落库失败时不得绕开合规门控跳转首页');
    // 重新弹出合规窗以便用户重试
    expect(find.text('用户协议与隐私政策'), findsOneWidget,
        reason: '落库失败应重新弹出合规窗以便重试');
  });
}
