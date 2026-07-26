import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/profile/pages/profile_notifications_page.dart';

void main() {
  testWidgets('ProfileNotificationsPage renders 5 mock notifications', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
      ],
      child: const MaterialApp(home: ProfileNotificationsPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('通知中心'), findsOneWidget);
    expect(find.text('你的连续打卡已 7 天'), findsOneWidget);
    expect(find.text('新模板已上线'), findsOneWidget);
  });
}
