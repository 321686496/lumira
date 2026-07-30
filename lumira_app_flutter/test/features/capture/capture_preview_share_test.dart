import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/features/capture/pages/capture_preview_page.dart';

void main() {
  testWidgets('CapturePreviewPage nav has share button that opens sheet',
      (tester) async {
    final router = GoRouter(
      initialLocation:
          '${RouteNames.capturePreview}?photoUrl=https://example.com/test.jpg',
      routes: [
        GoRoute(
          path: RouteNames.capturePreview,
          name: 'capturePreview',
          builder: (context, state) => CapturePreviewPage(
            photoUrl: state.queryParams['photoUrl'],
            photoId: state.queryParams['photoId'],
          ),
        ),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    // 验证分享按钮存在
    final shareIcon = find.byIcon(Icons.ios_share_outlined);
    expect(shareIcon, findsOneWidget);

    // 点击分享按钮
    await tester.tap(shareIcon);
    await tester.pumpAndSettle();

    // 验证底部 Sheet 出现三个选项
    // 用 ListTile 精确匹配分享 sheet 中的 _ShareOption，
    // 避免与折叠操作栏的"保存到相册"（_CollapsedActionButton）冲突
    expect(find.widgetWithText(ListTile, '保存到相册'), findsOneWidget);
    expect(find.widgetWithText(ListTile, '分享到系统'), findsOneWidget);
    expect(find.widgetWithText(ListTile, '生成 EXIF 海报'), findsOneWidget);
  });
}
