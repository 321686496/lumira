import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/searchengine/search_scope.dart';

/// 首页搜索胶囊：导航栏下方圆角胶囊，点击进入全局搜索页（all scope）。
class SearchCapsule extends ConsumerWidget {
  const SearchCapsule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    return GestureDetector(
      onTap: () => context.push(
        RouteNames.withScope(RouteNames.search, SearchScope.all.name),
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 40,
        margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tokens.divider, width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 18, color: tokens.textTertiary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '搜索模板 / 场景 / 拍摄教程',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: tokens.textTertiary,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
