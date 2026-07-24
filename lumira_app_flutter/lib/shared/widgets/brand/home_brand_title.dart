import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/preferences/home_wordmark_style.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import 'lumira_logo.dart';

/// 首页 APP 名称艺术排版组件
///
/// 监听 [homeWordmarkStyleProvider]，根据当前偏好渲染三种排版：
/// - [HomeWordmarkStyle.logoEnglish] — 符号标 + Lumira（默认）
/// - [HomeWordmarkStyle.logoEnglishChinese] — 符号标 + Lumira + 如画
/// - [HomeWordmarkStyle.englishChinese] — Lumira + 如画（无 logo）
///
/// 英文用 Georgia/Noto Serif，letter-spacing 0.08em；
/// 中文用 Noto Serif SC w600，颜色取 `tokens.brand` 作艺术对比。
///
/// [preview] 用于设置页预览卡片，使用更小尺寸。
class HomeBrandTitle extends ConsumerWidget {
  const HomeBrandTitle({super.key, this.preview = false});

  final bool preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(homeWordmarkStyleProvider);
    final tokens = ref.watch(appThemeProvider).tokens;

    // 尺寸：preview 用更小尺寸适配卡片
    final double logoSize = preview ? 18 : 24;
    final double logoSizeCompact = preview ? 16 : 22;
    final double englishSize = preview ? 16 : 20;
    final double englishSizeCompact = preview ? 14 : 18;
    final double chineseSize = preview ? 12 : 14;
    final double gapLogoEnglish = preview ? 6 : 8;
    final double gapEnglishChinese = preview ? 6 : 8;

    switch (style) {
      case HomeWordmarkStyle.logoEnglish:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LumiraLogo.symbol(size: logoSize),
            SizedBox(width: gapLogoEnglish),
            Text('Lumira', style: _englishStyle(tokens, englishSize)),
          ],
        );
      case HomeWordmarkStyle.logoEnglishChinese:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LumiraLogo.symbol(size: logoSizeCompact),
            SizedBox(width: gapLogoEnglish),
            Text('Lumira', style: _englishStyle(tokens, englishSizeCompact)),
            SizedBox(width: gapEnglishChinese),
            Text('如画', style: _chineseStyle(tokens, chineseSize)),
          ],
        );
      case HomeWordmarkStyle.englishChinese:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Lumira', style: _englishStyle(tokens, englishSize)),
            SizedBox(width: gapEnglishChinese),
            Text('如画', style: _chineseStyle(tokens, chineseSize)),
          ],
        );
    }
  }

  TextStyle _englishStyle(ThemeTokens tokens, double size) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.normal,
        color: tokens.textPrimary,
        letterSpacing: 0.08 * size,
        height: 1.2,
        fontFamily: 'Georgia',
      );

  TextStyle _chineseStyle(ThemeTokens tokens, double size) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: tokens.brand,
        letterSpacing: 0.04 * size,
        height: 1.2,
        fontFamily: 'Noto Serif SC',
      );
}
