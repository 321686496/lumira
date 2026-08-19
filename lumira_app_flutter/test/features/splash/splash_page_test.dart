import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/auth/auth_controller.dart';
import 'package:lumira_app_flutter/core/auth/auth_dao.dart';
import 'package:lumira_app_flutter/core/auth/auth_state.dart';
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
}
