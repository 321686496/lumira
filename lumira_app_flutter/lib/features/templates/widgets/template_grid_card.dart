import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../data/templates_mock_data.dart';

/// 模板网格卡片（更多模板 section 2 列网格项）
///
/// 视觉规格来源：lumira-app/src/pages/templates/index.vue line 62-83
/// - 图片宽高比: 100% (1:1)
/// - 圆角: 24rpx → 12dp
/// - 免费 badge: 左上角，绿色背景
/// - name: 26rpx → 13dp，单行 ellipsis
/// - category: 22rpx → 11dp，brand 色
class TemplateGridCard extends ConsumerWidget {
  const TemplateGridCard({
    super.key,
    required this.template,
    required this.onTap,
  });

  final TemplateItem template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final tpl = template;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12), // 24rpx → 12dp
          // 保留新拟态凸起阴影，仅移除 surface 背景填充（让卡片透明融入页面）
          boxShadow:
              appTheme.style == UIStyle.neumorphic ? tokens.shadowConvex : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GridImage(tpl: tpl, tokens: tokens),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10), // 20rpx 16rpx 20rpx 20rpx → 10 8 10 10
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tpl.name,
                    style: TextStyle(
                      fontSize: 13, // 26rpx → 13dp
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3), // margin-top: 6rpx → 3dp
                  Text(
                    TemplatesMockData.categoryLabel(tpl.category),
                    style: TextStyle(
                      fontSize: 11, // 22rpx → 11dp
                      color: tokens.brand,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridImage extends StatelessWidget {
  const _GridImage({required this.tpl, required this.tokens});

  final TemplateItem tpl;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0, // padding-bottom: 100% → 1:1
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tokens.brandSubtle,
                  tokens.brand.withOpacity(0.4),
                ],
              ),
            ),
            child: Center(
              child: Icon(
                Icons.photo_camera_outlined,
                size: 28,
                color: tokens.brandDeep.withOpacity(0.6),
              ),
            ),
          ),
          if (tpl.price == 0)
            Positioned(
              top: 6, // 12rpx → 6dp
              left: 6,
              child: _FreeBadge(),
            ),
        ],
      ),
    );
  }
}

class _FreeBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), // 14rpx 4rpx → 7 2
      decoration: BoxDecoration(
        // rgba(90, 122, 72, 0.85)
        color: const Color(0xFF5A7A48).withOpacity(0.85),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: const Text(
        '免费',
        style: TextStyle(
          fontSize: 10, // 20rpx → 10dp
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.2,
        ),
      ),
    );
  }
}
