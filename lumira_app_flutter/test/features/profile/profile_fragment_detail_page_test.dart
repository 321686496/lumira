import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/profile/pages/profile_fragment_detail_page.dart';

void main() {
  testWidgets(
      'tapping share button on fragment card opens PosterGenerator sheet',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: const MaterialApp(home: ProfileFragmentDetailPage()),
      ),
    );
    await tester.pumpAndSettle();

    // 找到第一个「生成海报」按钮并点击
    final shareButtons = find.text('生成海报');
    expect(shareButtons, findsWidgets);

    // 滚动到按钮可见位置后再点击（默认 800x600 视口下按钮可能位于屏幕外）
    await tester.ensureVisible(shareButtons.first);
    await tester.pumpAndSettle();

    await tester.tap(shareButtons.first);
    await tester.pumpAndSettle();

    // 验证 PosterGenerator 底部 Sheet 出现（包含「导出海报」和「分享海报」按钮）
    expect(find.text('导出海报'), findsOneWidget);
    expect(find.text('分享海报'), findsOneWidget);
  });
}
