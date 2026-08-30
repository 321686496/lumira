import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';

/// 邀请卡片分享海报
///
/// 固定 300×400（3:4），完全跟随「设置里的 UI 风格 + 主题」（`appThemeProvider`）。
/// 覆盖 4 套 UI 风格（neumorphic / flat / glass / female），无手动风格切换器，
/// 无硬编码颜色（仅二维码白底 `Colors.white` 为「白底可扫」合法例外）。
///
/// Task 3（底部弹出分享面板）将以 `InvitePosterCard(code: code)` 复用此组件。
class InvitePosterCard extends ConsumerWidget {
  const InvitePosterCard({super.key, required this.code});

  /// 邀请码原始串（如 'LUMIRA-7K2A'），直接作为二维码数据与大字显示。
  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    return SizedBox(
      width: 300,
      height: 400,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _SceneBackground(appTheme: appTheme),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: _InviteCard(appTheme: appTheme, code: code),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 4 场景底：风格化背景（金色细边 / 品牌光斑 / 品牌氛围光）
class _SceneBackground extends StatelessWidget {
  const _SceneBackground({required this.appTheme});
  final AppThemeData appTheme;

  @override
  Widget build(BuildContext context) {
    final t = appTheme.tokens;
    switch (appTheme.style) {
      case UIStyle.neumorphic:
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [t.canvas, t.canvasDeep],
            ),
            border: Border.all(color: t.brand.withOpacity(0.35), width: 1),
          ),
        );
      case UIStyle.flat:
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [t.canvasDeep, t.surfaceAlt],
            ),
            border: Border.all(color: t.divider, width: 1),
          ),
        );
      case UIStyle.glass:
        return _GlassScene(tokens: t);
      case UIStyle.female:
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.7, -0.8),
              radius: 1.1,
              colors: [
                t.brandLight.withOpacity(0.28),
                t.brandLight.withOpacity(0.0),
              ],
            ),
          ),
        );
    }
  }
}

/// glass 场景底：纯色画布 + 3~4 个品牌光斑，让半透明玻璃透出色彩
class _GlassScene extends StatelessWidget {
  const _GlassScene({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: tokens.canvas)),
        Positioned(
          top: -60,
          left: -50,
          child: _SceneBlob(size: 180, color: tokens.brand, opacity: 0.7),
        ),
        Positioned(
          bottom: 120,
          right: -50,
          child: _SceneBlob(size: 170, color: tokens.brandLight, opacity: 0.6),
        ),
        Positioned(
          bottom: -50,
          left: 30,
          child: _SceneBlob(size: 190, color: tokens.brandSubtle, opacity: 0.7),
        ),
        Positioned(
          top: 160,
          left: -40,
          child: _SceneBlob(size: 120, color: tokens.brandLight, opacity: 0.5),
        ),
      ],
    );
  }
}

/// 柔和品牌光斑（径向渐变圆，边缘完全融入）
class _SceneBlob extends StatelessWidget {
  const _SceneBlob({
    required this.size,
    required this.color,
    required this.opacity,
  });
  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final base = color.withOpacity(opacity);
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(0, 0),
            radius: 0.85,
            colors: [base, base.withOpacity(0.5), base.withOpacity(0)],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}

/// 邀请卡片主卡：风格自适应表面 + 固定内容列
class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.appTheme, required this.code});
  final AppThemeData appTheme;
  final String code;

  @override
  Widget build(BuildContext context) {
    final mg = appTheme.multiGradient;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      decoration: _cardSurface(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 女性美学专属：径向高光氛围（叠加于卡片底，置于内容之下）
          if (mg != null)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration:
                      BoxDecoration(gradient: mg.radialHighlight),
                ),
              ),
            ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildBrandRow(),
                const SizedBox(height: 5),
                _buildTitle(),
                const SizedBox(height: 1),
                _buildSubtitle(),
                const SizedBox(height: 6),
                _buildGainPill(),
                const SizedBox(height: 4),
                _buildQrBox(),
                const SizedBox(height: 4),
                _buildCodeBlock(),
                const SizedBox(height: 5),
                _buildFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardSurface() {
    final t = appTheme.tokens;
    switch (appTheme.style) {
      case UIStyle.neumorphic:
        return BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: t.shadowConvex,
        );
      case UIStyle.flat:
        return BoxDecoration(
          color: t.surfaceAlt,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.divider, width: 1),
        );
      case UIStyle.glass:
        return BoxDecoration(
          color: ThemeTokens.glassFill(t),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ThemeTokens.glassBorder(t), width: 1),
        );
      case UIStyle.female:
        final mg = appTheme.multiGradient!;
        return BoxDecoration(
          gradient: mg.linear,
          borderRadius: BorderRadius.circular(24),
          border: mg.hairlineBorder,
          boxShadow: appTheme.cardShadow,
        );
    }
  }

  Widget _buildBrandRow() {
    final t = appTheme.tokens;
    return Row(
      children: [
        Text(
          'LUMIRA',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
            color: t.brandDeep,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [t.brand.withOpacity(0.9), t.brandLight.withOpacity(0.3)],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '如画',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.brandText),
        ),
      ],
    );
  }

  Widget _buildTitle() {
    return Text(
      '邀请好友 · 一起来拍照',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.1,
        color: appTheme.tokens.textPrimary,
      ),
    );
  }

  Widget _buildSubtitle() {
    return Text(
      '和你一起，把生活拍成想要的样子',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 10,
        color: appTheme.tokens.textSecondary,
      ),
    );
  }

  Widget _buildGainPill() {
    final t = appTheme.tokens;
    Color bg;
    Border? border;
    switch (appTheme.style) {
      case UIStyle.neumorphic:
      case UIStyle.female:
        bg = t.brandSubtle;
        border = null;
        break;
      case UIStyle.flat:
        bg = t.surfaceAlt;
        border = Border.all(color: t.divider, width: 1);
        break;
      case UIStyle.glass:
        bg = Colors.white.withOpacity(0.55);
        border = Border.all(color: Colors.white, width: 0.8);
        break;
    }
    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: border,
        ),
        child: Text(
          '好友首次激活，双方各得 +30 积分',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: t.brandText),
        ),
      ),
    );
  }

  Widget _buildQrBox() {
    final t = appTheme.tokens;
    Border? border;
    List<BoxShadow> shadow;
    switch (appTheme.style) {
      case UIStyle.neumorphic:
        border = null;
        shadow = t.shadowFloat;
        break;
      case UIStyle.flat:
        border = Border.all(color: t.divider, width: 1);
        shadow = const [];
        break;
      case UIStyle.glass:
        border = Border.all(color: Colors.white, width: 0.8);
        shadow = [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ];
        break;
      case UIStyle.female:
        border = Border.all(color: t.brand.withOpacity(0.4), width: 0.8);
        shadow = [
          BoxShadow(
            color: t.brand.withOpacity(0.12),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ];
        break;
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white, // 白底可扫（合法例外）
        borderRadius: BorderRadius.circular(12),
        border: border,
        boxShadow: shadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 二维码模块用黑色（非主题色）而非 textPrimary：保证任意主题下白底均可扫描
          QrImageView(
            data: code,
            size: 132,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Colors.black,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '长按识别二维码 · 立即加入',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              color: t.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeBlock() {
    final t = appTheme.tokens;
    Color bg;
    Border? border;
    List<BoxShadow> shadow;
    switch (appTheme.style) {
      case UIStyle.neumorphic:
        bg = t.surfaceAlt;
        border = null;
        shadow = t.shadowConcaveSubtle;
        break;
      case UIStyle.flat:
        bg = Colors.white;
        border = Border.all(color: t.divider, width: 1);
        shadow = const [];
        break;
      case UIStyle.glass:
        bg = Colors.white.withOpacity(0.45);
        border = Border.all(color: Colors.white, width: 0.8);
        shadow = const [];
        break;
      case UIStyle.female:
        bg = Colors.white.withOpacity(0.7);
        border = Border.all(color: t.brand.withOpacity(0.25), width: 0.8);
        shadow = const [
          BoxShadow(color: Color(0x14000000), offset: Offset(0, 3), blurRadius: 8),
        ];
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: border,
        boxShadow: shadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '我的邀请码',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: t.brandText),
          ),
          const SizedBox(height: 1),
          Text(
            code,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              fontFamily: 'Courier New',
              letterSpacing: 5,
              color: t.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Text(
      'LUMIRA · 如画 · 记录每一帧美好',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 9,
        letterSpacing: 1,
        color: appTheme.tokens.textTertiary,
      ),
    );
  }
}