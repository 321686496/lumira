import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/splash/widgets/compliance_dialog.dart';

/// 注册合规三个文档路由，供点链接 push 验证。
final _complianceRoutes = <RouteBase>[
  GoRoute(
    path: RouteNames.profileComplianceAgreement,
    builder: (_, __) => const Scaffold(body: Text('协议页')),
  ),
  GoRoute(
    path: RouteNames.profileCompliancePrivacy,
    builder: (_, __) => const Scaffold(body: Text('隐私页')),
  ),
  GoRoute(
    path: RouteNames.profileComplianceSdk,
    builder: (_, __) => const Scaffold(body: Text('SDK页')),
  ),
];

Widget wrap(Widget child) {
  final router = GoRouter(
    initialLocation: '/x',
    routes: [
      GoRoute(path: '/x', builder: (_, __) => child),
      ..._complianceRoutes,
    ],
  );
  return ProviderScope(
    overrides: [
      themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
      uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('渲染标题、三链接与两按钮文案', (tester) async {
    await tester.pumpWidget(wrap(ComplianceDialog(
      onAgree: () {},
      onDisagree: () {},
    )));
    await tester.pump();

    expect(find.text('用户协议与隐私政策'), findsOneWidget);
    expect(find.textContaining('《用户协议》'), findsOneWidget);
    expect(find.textContaining('《隐私政策》'), findsOneWidget);
    expect(find.textContaining('《个人信息清单与第三方SDK目录》'), findsOneWidget);
    expect(find.text('同意并开始使用'), findsOneWidget);
    expect(find.text('不同意并退出'), findsOneWidget);
  });

  testWidgets('点「同意并开始使用」触发 onAgree', (tester) async {
    var agreed = false;
    await tester.pumpWidget(wrap(ComplianceDialog(
      onAgree: () => agreed = true,
      onDisagree: () {},
    )));
    await tester.pump();

    await tester.tap(find.text('同意并开始使用'));
    await tester.pump();
    expect(agreed, isTrue);
  });

  testWidgets('点「不同意并退出」触发 onDisagree', (tester) async {
    var disagreed = false;
    await tester.pumpWidget(wrap(ComplianceDialog(
      onAgree: () {},
      onDisagree: () => disagreed = true,
    )));
    await tester.pump();

    await tester.tap(find.text('不同意并退出'));
    await tester.pump();
    expect(disagreed, isTrue);
  });
}