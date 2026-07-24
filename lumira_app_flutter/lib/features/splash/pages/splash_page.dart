import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/brand/lumira_logo.dart';
import '../../../shared/widgets/common/fade_up.dart';

/// Splash 启动页
///
/// 视觉规格来源：lumira-app/src/pages/splash/index.vue
/// - 居中布局：logo + 标题 + 副标题
/// - logo 120rpx→60dp aperture 图标，brand 色
/// - 标题 48rpx→24dp Noto Serif SC，600 字重
/// - 副标题 26rpx→13dp，textTertiary 色，letter-spacing 0.04em
/// - 1.8s 后 uni.reLaunch → home（Flutter 用 context.go 替换栈顶）
///
/// Logo 升级：原 Icons.camera_outlined 替换为设计好的品牌 SVG 符号标
/// （Single Viewfinder + Diagonal Light Beam + Focus Dot），主色 #C9A96E
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  static const Duration _redirectDelay = Duration(milliseconds: 1800);

  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();
    // 1.8s 后跳转 home（用 context.go 替换路由栈，对齐 uni-app 的 reLaunch 语义）
    _redirectTimer = Timer(_redirectDelay, () {
      if (mounted) {
        context.go(RouteNames.home);
      }
    });
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(appThemeProvider).tokens;

    return Scaffold(
      // #FAF7F2 默认主题 canvas；用 tokens.canvas 让所有主题都对齐
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 品牌 logo + 主题色光晕（logo 后方叠径向渐变圆形）
              FadeUp(
                child: SizedBox(
                  width: 160,
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 主题色光晕
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              tokens.brandSubtle.withOpacity(0.45),
                              tokens.brandLight.withOpacity(0.18),
                              tokens.canvas.withOpacity(0),
                            ],
                            stops: const [0.0, 0.55, 1.0],
                          ),
                        ),
                      ),
                      // 品牌 logo（设计好的取景器符号标 SVG）
                      const SizedBox(
                        width: 80, // 略放大承载 SVG 描边细节
                        height: 80,
                        child: LumiraLogo.symbol(
                          size: 80,
                          semanticsLabel: '如画品牌符号标',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24), // margin-bottom 48rpx → 24dp
              // 文字组
              FadeUp(
                delay: const Duration(milliseconds: 200),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '如画 Lumira',
                      style: TextStyle(
                        fontSize: 24, // 48rpx → 24dp
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                        letterSpacing: -0.01 * 24,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6), // gap 12rpx → 6dp
                    Text(
                      '如你所见，皆成画卷',
                      style: TextStyle(
                        fontSize: 13, // 26rpx → 13dp
                        color: tokens.textTertiary,
                        letterSpacing: 0.04 * 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
