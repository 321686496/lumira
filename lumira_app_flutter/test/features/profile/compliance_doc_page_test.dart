import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/profile/data/compliance_content.dart';
import 'package:lumira_app_flutter/features/profile/pages/compliance_doc_page.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

Widget _wrap({required String title, required String updatedAt, required List<ComplianceSection> sections}) {
  final router = GoRouter(
    initialLocation: '/doc',
    routes: [
      GoRoute(
        path: '/doc',
        builder: (_, __) => ComplianceDocPage(
          title: title,
          updatedAt: updatedAt,
          sections: sections,
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      themeKeyProvider.overrideWith((r) => ThemeKey.warmWhite),
      uiStyleProvider.overrideWith((r) => UIStyle.neumorphic),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('renders nav title and updated time', (tester) async {
    await tester.pumpWidget(_wrap(
      title: '隐私政策',
      updatedAt: '2026-08-05',
      sections: ComplianceDocs.privacy,
    ));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(LumiraNav, '隐私政策'), findsOneWidget);
    expect(find.textContaining('2026-08-05'), findsWidgets);
  });

  testWidgets('renders section titles, paragraphs and key-value rows', (tester) async {
    await tester.pumpWidget(_wrap(
      title: '隐私政策',
      updatedAt: '2026-08-05',
      sections: ComplianceDocs.privacy,
    ));
    await tester.pumpAndSettle();

    expect(find.text('引言'), findsOneWidget);
    expect(find.text('我们收集的信息'), findsOneWidget);
    expect(find.text('信息的使用目的'), findsOneWidget);
  });

  testWidgets('renders list items with kv rows for sdk doc', (tester) async {
    await tester.pumpWidget(_wrap(
      title: '个人信息清单与第三方 SDK 目录',
      updatedAt: '2026-08-05',
      sections: ComplianceDocs.sdk,
    ));
    await tester.pumpAndSettle();

    expect(find.text('个人信息收集使用清单'), findsOneWidget);
    expect(find.text('基础功能运行'), findsOneWidget);
    expect(find.text('收集场景'), findsWidgets);
    expect(find.text('启动应用、浏览首页'), findsOneWidget);
  });
}
