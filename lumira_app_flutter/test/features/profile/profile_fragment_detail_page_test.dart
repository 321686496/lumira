import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/profile/pages/profile_fragment_detail_page.dart';
import 'package:lumira_app_flutter/features/profile/data/profile_mock_data.dart';
import 'package:lumira_app_flutter/features/profile/providers/fragments_providers.dart';

void main() {
  testWidgets(
      'tapping share button opens style picker, then poster sheet',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fragmentsProvider.overrideWith(
              (ref) async => ProfileMockData.fragments),
        ],
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

    // 验证「选择分享卡片」面板出现，含三套布局
    expect(find.text('选择分享卡片'), findsOneWidget);
    expect(find.text('等高画廊带'), findsOneWidget);
    expect(find.text('装裱衬纸'), findsOneWidget);
    expect(find.text('收藏编号版'), findsOneWidget);

    // 选择「等高画廊带」，进入海报预览
    await tester.tap(find.text('等高画廊带'));
    await tester.pumpAndSettle();

    // 验证 PosterGenerator 底部 Sheet 出现（包含「保存到相册」和「分享海报」按钮）
    expect(find.text('保存到相册'), findsOneWidget);
    expect(find.text('分享海报'), findsOneWidget);
  });
}
