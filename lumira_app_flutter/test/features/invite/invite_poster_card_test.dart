import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/invite/widgets/invite_poster_card.dart';
import 'package:qr_flutter/qr_flutter.dart';

Widget wrap(Widget child) {
  return ProviderScope(
    overrides: [
      themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
      uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
    ],
    child: MaterialApp(home: Scaffold(body: Center(child: child))),
  );
}

void main() {
  testWidgets('InvitePosterCard 渲染标题、邀请码与二维码（默认暖白/新拟态）', (tester) async {
    await tester.pumpWidget(wrap(const InvitePosterCard(code: 'LUMIRA-7K2A')));
    await tester.pump();
    expect(find.text('邀请好友 · 一起来拍照'), findsOneWidget);
    expect(find.text('LUMIRA-7K2A'), findsOneWidget);
    expect(find.text('我的邀请码'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
  });
}