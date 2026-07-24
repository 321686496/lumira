import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 如画品牌 Logo 资源路径常量
///
/// 所有 SVG 来源：assets/logos/（从 d:\app\projects\photo_post\assets\logos\lumira\ 拷贝）
/// 设计语言：Single Viewfinder + Diagonal Light Beam + Focus Dot
/// 主色 #C9A96E（brand 金），画布 #FAF7F2（canvas 暖白）
class LumiraLogoAsset {
  LumiraLogoAsset._();

  /// 符号标（仅取景器符号，200x200，无文字）
  static const String symbol = 'assets/logos/logo-lumira-symbol.svg';

  /// 主标（符号 + Lumira 文字标 + 中文标语，400x160）
  static const String primary = 'assets/logos/logo-lumira-primary.svg';

  /// 文字标（仅 Lumira 英文，300x60）
  static const String wordmark = 'assets/logos/logo-lumira-wordmark.svg';

  /// 反白版（深色背景用主标，400x160，背景 #1A1A1A）
  static const String reverse = 'assets/logos/logo-lumira-reverse.svg';

  /// 单色版（单色主标，400x160）
  static const String monochrome = 'assets/logos/logo-lumira-monochrome.svg';

  /// App 图标（1024x1024 squircle，白底金符号）
  static const String appIcon = 'assets/logos/app-icon-lumira.svg';
}

/// 如画品牌 Logo 组件
///
/// 使用 flutter_svg 渲染矢量 logo，保证任意缩放清晰度无损。
/// 支持五种形式：symbol / primary / wordmark / reverse / monochrome
///
/// 用法：
/// ```dart
/// // 启动页主标
/// LumiraLogo.primary(width: 220)
///
/// // 导航栏 wordmark
/// LumiraLogo.wordmark(height: 20)
///
/// // 关于页符号标
/// LumiraLogo.symbol(size: 72)
/// ```
class LumiraLogo extends StatelessWidget {
  const LumiraLogo({
    super.key,
    required this.asset,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.color,
    this.semanticsLabel,
  });

  /// 符号标：仅取景器符号（无文字），适合图标位
  const LumiraLogo.symbol({
    super.key,
    double size = 48,
    this.color,
    this.semanticsLabel = '如画符号标',
  })  : asset = LumiraLogoAsset.symbol,
        width = size,
        height = size,
        fit = BoxFit.contain;

  /// 主标：符号 + Lumira + 中文标语「如你所见，皆成画卷」
  const LumiraLogo.primary({
    super.key,
    this.width = 220,
    this.color,
    this.semanticsLabel = '如画主标',
  })  : asset = LumiraLogoAsset.primary,
        height = null,
        fit = BoxFit.contain;

  /// 文字标：仅 Lumira 英文
  const LumiraLogo.wordmark({
    super.key,
    this.height = 20,
    this.color,
    this.semanticsLabel = '如画文字标',
  })  : asset = LumiraLogoAsset.wordmark,
        width = null,
        fit = BoxFit.contain;

  /// 反白版：深色背景用主标（自带深色底）
  const LumiraLogo.reverse({
    super.key,
    this.width = 220,
    this.color,
    this.semanticsLabel = '如画反白主标',
  })  : asset = LumiraLogoAsset.reverse,
        height = null,
        fit = BoxFit.contain;

  /// 单色版：单色主标（可用 colorFilter 染色）
  const LumiraLogo.monochrome({
    super.key,
    this.width = 220,
    this.color,
    this.semanticsLabel = '如画单色主标',
  })  : asset = LumiraLogoAsset.monochrome,
        height = null,
        fit = BoxFit.contain;

  final String asset;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? color;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      color: color,
      semanticsLabel: semanticsLabel,
    );
  }
}
