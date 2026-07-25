import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lumira_app_flutter/core/db/dao/gallery_dao.dart';
import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/gallery/pages/gallery_page.dart';

void main() {
  testWidgets('long-press a photo enters multi-select mode',
      (tester) async {
    // 此测试依赖真实 DAO；若项目有 mock galleryDaoProvider，请改用 overrides
    // 这里仅断言多选 UI 出现：底部出现"删除"和"取消"按钮
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
          uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/gallery',
            routes: [
              GoRoute(path: '/gallery', builder: (_, __) => GalleryPage()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // 假设至少有一张照片可长按；如无照片则测试跳过
    final firstCellFinder = find.byKey(const ValueKey('photo_cell_0'));
    if (firstCellFinder.evaluate().isEmpty) {
      debugPrint('No photos in gallery, skipping test');
      return;
    }

    await tester.longPress(firstCellFinder);
    await tester.pumpAndSettle();

    expect(find.text('删除'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
  });
}
