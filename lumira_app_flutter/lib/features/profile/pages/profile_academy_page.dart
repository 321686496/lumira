import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';

/// 摄影美学院页（空状态）
///
/// 视觉规格来源：lumira-app/src/pages/profile/academy.vue（26 行，仅空状态）
/// uni-app 原版只渲染 graduation-cap 图标 + "摄影美学院即将上线" 文本，
/// 无任何业务逻辑。Flutter 迁移保留此空状态（YAGNI）。
class ProfileAcademyPage extends ConsumerWidget {
  const ProfileAcademyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '摄影美学院',
        transparent: true,
        leading: _BackButton(tokens: tokens),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.6),
            radius: 1.2,
            colors: [
              tokens.brandSubtle.withOpacity(0.35),
              tokens.canvas.withOpacity(0.0),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.school_outlined,
                  size: 48, // 96rpx → 48dp
                  color: tokens.divider,
                ),
                const SizedBox(height: 12), // 24rpx → 12dp
                Text(
                  '摄影美学院即将上线',
                  style: TextStyle(
                    fontFamily: 'Noto Serif SC',
                    fontSize: 14, // 28rpx → 14dp
                    color: tokens.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // uni-app: navigateBack({ fail: () => reLaunch('/pages/profile/index') })
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context);
        } else {
          GoRouter.of(context).go(RouteNames.profile);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(Icons.arrow_back_ios_new, size: 20, color: tokens.textPrimary),
      ),
    );
  }
}
