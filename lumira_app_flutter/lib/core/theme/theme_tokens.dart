import 'package:flutter/material.dart';

enum ThemeKey {
  warmWhite,
  ink,
  retro,
  fresh,
  cozy,
  macaron,
  morandi,
  rosegold,
}

enum UIStyle {
  neumorphic,
  flat,
  glass,
  female,
}

class ThemeTokens {
  final Color canvas;
  final Color surface;
  final Color surfaceAlt;
  final Color canvasDeep;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textInverse;
  final Color divider;
  final Color brand;
  final Color brandDeep;
  final Color brandLight; // 注意：warmWhite/ink/retro/fresh 主题在 App.vue 中未显式定义 --color-brand-light，需用 brand 色稍亮派生
  final Color brandSubtle;
  final Color brandText;
  final Color danger;
  final Color dangerSubtle;
  final Color success;
  final Color successSubtle;

  final List<BoxShadow> shadowConvex;
  final List<BoxShadow> shadowConvexSubtle;
  final List<BoxShadow> shadowConvexBrand;
  final List<BoxShadow> shadowConcave;
  final List<BoxShadow> shadowConcaveSubtle;
  final List<BoxShadow> shadowPressed;
  final List<BoxShadow> shadowFloat;

  const ThemeTokens({
    required this.canvas,
    required this.surface,
    required this.surfaceAlt,
    required this.canvasDeep,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textInverse,
    required this.divider,
    required this.brand,
    required this.brandDeep,
    required this.brandLight,
    required this.brandSubtle,
    required this.brandText,
    required this.danger,
    required this.dangerSubtle,
    required this.success,
    required this.successSubtle,
    required this.shadowConvex,
    required this.shadowConvexSubtle,
    required this.shadowConvexBrand,
    required this.shadowConcave,
    required this.shadowConcaveSubtle,
    required this.shadowPressed,
    required this.shadowFloat,
  });

  static ThemeTokens of(ThemeKey theme) {
    switch (theme) {
      case ThemeKey.warmWhite:
        return _warmWhiteTokens;
      case ThemeKey.ink:
        return _inkTokens;
      case ThemeKey.retro:
        return _retroTokens;
      case ThemeKey.fresh:
        return _freshTokens;
      case ThemeKey.cozy:
        return _cozyTokens;
      case ThemeKey.macaron:
        return _macaronTokens;
      case ThemeKey.morandi:
        return _morandiTokens;
      case ThemeKey.rosegold:
        return _rosegoldTokens;
    }
  }

  // === 暖米白主题（默认） ===
  // 来源: App.vue :root (line 40-80)
  // Neumorphic fix: surface 从纯白 #FFFFFF 改为 canvas 的微亮变体 #FDFBF7，
  // 保留暖色调，让新拟态卡片与背景色调一致，靠双向阴影区分层次。
  static const _warmWhiteTokens = ThemeTokens(
    canvas: Color(0xFFFAF7F2),
    surface: Color(0xFFFDFBF7), // canvas 微亮变体（RGB +3），保留暖色调
    surfaceAlt: Color(0xFFF2EEE6),
    canvasDeep: Color(0xFFF5F1EB),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF5C5852),
    textTertiary: Color(0xFF9C9690),
    textInverse: Color(0xFFFAF7F2),
    divider: Color(0xFFEAE5DC),
    brand: Color(0xFFC9A96E),
    brandDeep: Color(0xFFA88550),
    brandLight: Color(0xFFD4B57A), // App.vue 显式定义
    brandSubtle: Color(0xFFF5EDDB),
    brandText: Color(0xFF8C7340),
    danger: Color(0xFFB85450),
    dangerSubtle: Color(0xFFF5E3E0),
    success: Color(0xFF7A8B5C),
    successSubtle: Color(0xFFEBEEE2),
    shadowConvex: [
      BoxShadow(color: Color(0xFFD8D4CC), offset: Offset(6, 6), blurRadius: 14),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-6, -6), blurRadius: 14),
    ],
    shadowConvexSubtle: [
      BoxShadow(color: Color(0xFFE0DCD4), offset: Offset(3, 3), blurRadius: 6),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 6),
    ],
    shadowConvexBrand: [
      BoxShadow(color: Color(0xFFB89A5E), offset: Offset(4, 4), blurRadius: 10),
      BoxShadow(color: Color(0xFFDABB82), offset: Offset(-4, -4), blurRadius: 10),
    ],
    shadowConcave: [
      BoxShadow(color: Color(0xFFE0DCD4), offset: Offset(4, 4), blurRadius: 10, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-4, -4), blurRadius: 10, blurStyle: BlurStyle.inner),
    ],
    shadowConcaveSubtle: [
      BoxShadow(color: Color(0xFFE5E0D8), offset: Offset(2, 2), blurRadius: 5, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-2, -2), blurRadius: 5, blurStyle: BlurStyle.inner),
    ],
    shadowPressed: [
      BoxShadow(color: Color(0xFFE0DCD4), offset: Offset(3, 3), blurRadius: 8, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 8, blurStyle: BlurStyle.inner),
    ],
    shadowFloat: [
      BoxShadow(color: Color(0x141A1A1A), offset: Offset(0, 8), blurRadius: 32),
    ],
  );

  // === 浓墨主题 ===
  // 来源: App.vue [data-theme="ink"] (line 83-110)
  static const _inkTokens = ThemeTokens(
    canvas: Color(0xFF1C1A17),
    surface: Color(0xFF262320),
    surfaceAlt: Color(0xFF2E2B27),
    canvasDeep: Color(0xFF151310),
    textPrimary: Color(0xFFF2EEE6),
    textSecondary: Color(0xFFA39D94),
    textTertiary: Color(0xFF6E695F),
    textInverse: Color(0xFF1C1A17),
    divider: Color(0xFF3A3630),
    brand: Color(0xFFD4B57A),
    brandDeep: Color(0xFFB8985A),
    brandLight: Color(0xFFE0C68A),
    brandSubtle: Color(0xFF2E2820),
    brandText: Color(0xFFD4B57A),
    danger: Color(0xFFD4706C),
    dangerSubtle: Color(0xFF2E201E),
    success: Color(0xFF8FA06A),
    successSubtle: Color(0xFF22251D),
    shadowConvex: [
      BoxShadow(color: Color(0xFF13110E), offset: Offset(6, 6), blurRadius: 14),
      BoxShadow(color: Color(0xFF29251F), offset: Offset(-6, -6), blurRadius: 14),
    ],
    shadowConvexSubtle: [
      BoxShadow(color: Color(0xFF1A1714), offset: Offset(3, 3), blurRadius: 6),
      BoxShadow(color: Color(0xFF2E2B24), offset: Offset(-3, -3), blurRadius: 6),
    ],
    shadowConvexBrand: [
      BoxShadow(color: Color(0xFF1A1610), offset: Offset(4, 4), blurRadius: 10),
      BoxShadow(color: Color(0xFF3E3624), offset: Offset(-4, -4), blurRadius: 10),
    ],
    shadowConcave: [
      BoxShadow(color: Color(0xFF141210), offset: Offset(4, 4), blurRadius: 10, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFF302C25), offset: Offset(-4, -4), blurRadius: 10, blurStyle: BlurStyle.inner),
    ],
    shadowConcaveSubtle: [
      BoxShadow(color: Color(0xFF1A1714), offset: Offset(2, 2), blurRadius: 5, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFF2E2B24), offset: Offset(-2, -2), blurRadius: 5, blurStyle: BlurStyle.inner),
    ],
    shadowPressed: [
      BoxShadow(color: Color(0xFF141210), offset: Offset(3, 3), blurRadius: 8, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFF302C25), offset: Offset(-3, -3), blurRadius: 8, blurStyle: BlurStyle.inner),
    ],
    shadowFloat: [
      BoxShadow(color: Color(0x4D000000), offset: Offset(0, 8), blurRadius: 32),
    ],
  );

  // === 胶片复古主题 ===
  // 来源: App.vue [data-theme="retro"] (line 112-140)
  // 注意: retro 主题 App.vue 未显式定义 --color-brand-light，用 brandLight=brand 稍亮派生 (0xFFD4A57A)
  // Neumorphic fix: surface 从偏白 #FFF8F0 改为 canvas 微亮变体 #F8EAD7，保留复古黄色调；
  // brand 调深为 #B8855A，brandDeep #9A6A42，提升胶片复古质感。
  static const _retroTokens = ThemeTokens(
    canvas: Color(0xFFF5E6D3),
    surface: Color(0xFFF8EAD7), // canvas 微亮变体（RGB +3），保留复古黄色调
    surfaceAlt: Color(0xFFEBDAC4),
    canvasDeep: Color(0xFFEBDAC4),
    textPrimary: Color(0xFF3D2817),
    textSecondary: Color(0xFF6B4C2F),
    textTertiary: Color(0xFF9C8060),
    textInverse: Color(0xFFF5E6D3),
    divider: Color(0xFFD9C9B3),
    brand: Color(0xFFB8855A), // 调深，质感更佳
    brandDeep: Color(0xFF9A6A42),
    brandLight: Color(0xFFD4A57A),
    brandSubtle: Color(0xFFF0E0C8),
    brandText: Color(0xFF8C5A30),
    danger: Color(0xFFA04030),
    dangerSubtle: Color(0xFFF0D8D0),
    success: Color(0xFF6B7B4C),
    successSubtle: Color(0xFFE8EDDF),
    shadowConvex: [
      BoxShadow(color: Color(0xFFCFC0AB), offset: Offset(5, 5), blurRadius: 12),
      BoxShadow(color: Color(0xFFFFFDF7), offset: Offset(-5, -5), blurRadius: 12),
    ],
    shadowConvexSubtle: [
      BoxShadow(color: Color(0xFFD5C6B0), offset: Offset(3, 3), blurRadius: 6),
      BoxShadow(color: Color(0xFFFFFDF7), offset: Offset(-3, -3), blurRadius: 6),
    ],
    shadowConvexBrand: [
      BoxShadow(color: Color(0xFFB08560), offset: Offset(4, 4), blurRadius: 10),
      BoxShadow(color: Color(0xFFDAA577), offset: Offset(-4, -4), blurRadius: 10),
    ],
    shadowConcave: [
      BoxShadow(color: Color(0xFFD0C1AC), offset: Offset(4, 4), blurRadius: 8, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFDF7), offset: Offset(-4, -4), blurRadius: 8, blurStyle: BlurStyle.inner),
    ],
    shadowConcaveSubtle: [
      BoxShadow(color: Color(0xFFD5C6B0), offset: Offset(2, 2), blurRadius: 5, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFDF7), offset: Offset(-2, -2), blurRadius: 5, blurStyle: BlurStyle.inner),
    ],
    shadowPressed: [
      BoxShadow(color: Color(0xFFD0C1AC), offset: Offset(3, 3), blurRadius: 6, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFDF7), offset: Offset(-3, -3), blurRadius: 6, blurStyle: BlurStyle.inner),
    ],
    shadowFloat: [
      BoxShadow(color: Color(0x1A3D2817), offset: Offset(0, 8), blurRadius: 32),
    ],
  );

  // === 日系清新主题 ===
  // 来源: App.vue [data-theme="fresh"] (line 142-170)
  // 注意: fresh 主题 App.vue 未显式定义 --color-brand-light，用 brandLight=brand 稍亮派生 (0xFFA8D8A0)
  // Neumorphic fix: canvas 从过浅 #F8FAF6 加深为 #F0F4ED，让阴影对比明显；
  // surface 从纯白 #FFFFFF 改为 canvas 微亮变体 #F3F7F0，保留绿色调；
  // brand 调深为 #7BA068，brandDeep #5E8348，提升清新质感。
  static const _freshTokens = ThemeTokens(
    canvas: Color(0xFFF0F4ED), // 加深 2-3%，让新拟态阴影对比明显
    surface: Color(0xFFF3F7F0), // canvas 微亮变体（RGB +3），保留绿色调
    surfaceAlt: Color(0xFFE8EDE2),
    canvasDeep: Color(0xFFE5E9DD),
    textPrimary: Color(0xFF3D352B),
    textSecondary: Color(0xFF7A6F60),
    textTertiary: Color(0xFFA89E90),
    textInverse: Color(0xFFF0F4ED),
    divider: Color(0xFFD5DBC8),
    brand: Color(0xFF7BA068), // 调深，绿色更有活力
    brandDeep: Color(0xFF5E8348),
    brandLight: Color(0xFFA8D8A0),
    brandSubtle: Color(0xFFE5EDDE),
    brandText: Color(0xFF4A7038),
    danger: Color(0xFFC87878),
    dangerSubtle: Color(0xFFF5E0E0),
    success: Color(0xFF7A9C5C),
    successSubtle: Color(0xFFE5EDDE),
    shadowConvex: [
      BoxShadow(color: Color(0xFFCCD3C5), offset: Offset(6, 6), blurRadius: 14),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-6, -6), blurRadius: 14),
    ],
    shadowConvexSubtle: [
      BoxShadow(color: Color(0xFFD2D9CB), offset: Offset(3, 3), blurRadius: 6),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 6),
    ],
    shadowConvexBrand: [
      BoxShadow(color: Color(0xFF6A9058), offset: Offset(4, 4), blurRadius: 10),
      BoxShadow(color: Color(0xFF92BA80), offset: Offset(-4, -4), blurRadius: 10),
    ],
    shadowConcave: [
      BoxShadow(color: Color(0xFFCED5C7), offset: Offset(4, 4), blurRadius: 10, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-4, -4), blurRadius: 10, blurStyle: BlurStyle.inner),
    ],
    shadowConcaveSubtle: [
      BoxShadow(color: Color(0xFFD2D9CB), offset: Offset(2, 2), blurRadius: 5, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-2, -2), blurRadius: 5, blurStyle: BlurStyle.inner),
    ],
    shadowPressed: [
      BoxShadow(color: Color(0xFFCED5C7), offset: Offset(3, 3), blurRadius: 8, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 8, blurStyle: BlurStyle.inner),
    ],
    shadowFloat: [
      BoxShadow(color: Color(0x143D352B), offset: Offset(0, 8), blurRadius: 32),
    ],
  );

  // === 温馨粉主题 ===
  // 来源: App.vue [data-theme="cozy"] (line 172-201)
  // Neumorphic fix: canvas 从过浅 #FFF5F5 加深为 #F8EBEB，让阴影对比明显；
  // surface 从纯白 #FFFFFF 改为 canvas 微亮变体 #FBF0F0，保留粉色调；
  // brand 调深为 #D89090，brandDeep #BC7070，提升温馨粉质感。
  static const _cozyTokens = ThemeTokens(
    canvas: Color(0xFFF8EBEB), // 加深 2-3%，让新拟态阴影对比明显
    surface: Color(0xFFFBF0F0), // canvas 微亮变体（RGB +3），保留粉色调
    surfaceAlt: Color(0xFFF2E0E0),
    canvasDeep: Color(0xFFF0DDDD),
    textPrimary: Color(0xFF3D2E2E),
    textSecondary: Color(0xFF7A6060),
    textTertiary: Color(0xFFA88989),
    textInverse: Color(0xFFF8EBEB),
    divider: Color(0xFFE8D5D5),
    brand: Color(0xFFD89090), // 调深，粉色更有质感
    brandDeep: Color(0xFFBC7070),
    brandLight: Color(0xFFEAB5B5),
    brandSubtle: Color(0xFFF5DDDD),
    brandText: Color(0xFFA85858),
    danger: Color(0xFFC46868),
    dangerSubtle: Color(0xFFF5DDDD),
    success: Color(0xFF8FAA82),
    successSubtle: Color(0xFFE8EDE2),
    shadowConvex: [
      BoxShadow(color: Color(0xFFE8D5D5), offset: Offset(6, 6), blurRadius: 14),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-6, -6), blurRadius: 14),
    ],
    shadowConvexSubtle: [
      BoxShadow(color: Color(0xFFEDDDDD), offset: Offset(3, 3), blurRadius: 6),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 6),
    ],
    shadowConvexBrand: [
      BoxShadow(color: Color(0xFFBC7070), offset: Offset(4, 4), blurRadius: 10),
      BoxShadow(color: Color(0xFFEAB5B5), offset: Offset(-4, -4), blurRadius: 10),
    ],
    shadowConcave: [
      BoxShadow(color: Color(0xFFEADADA), offset: Offset(4, 4), blurRadius: 10, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-4, -4), blurRadius: 10, blurStyle: BlurStyle.inner),
    ],
    shadowConcaveSubtle: [
      BoxShadow(color: Color(0xFFEDDDDD), offset: Offset(2, 2), blurRadius: 5, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-2, -2), blurRadius: 5, blurStyle: BlurStyle.inner),
    ],
    shadowPressed: [
      BoxShadow(color: Color(0xFFEADADA), offset: Offset(3, 3), blurRadius: 8, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 8, blurStyle: BlurStyle.inner),
    ],
    shadowFloat: [
      BoxShadow(color: Color(0x143D2E2E), offset: Offset(0, 8), blurRadius: 32),
    ],
  );

  // === 马卡龙主题 ===
  // 来源: App.vue [data-theme="macaron"] (line 203-232)
  // Neumorphic fix: canvas 从过浅 #FFF8F0 加深为 #F5EEE0，让阴影对比明显；
  // surface 从纯白 #FFFFFF 改为 canvas 微亮变体 #F8F1E3，保留米调；
  // brand 从灰暗 #A8D8C8 提升饱和度为 #7BC4AB，brandDeep #5AA890，让薄荷绿更鲜活有质感。
  static const _macaronTokens = ThemeTokens(
    canvas: Color(0xFFF5EEE0), // 加深 2-3%，让新拟态阴影对比明显
    surface: Color(0xFFF8F1E3), // canvas 微亮变体（RGB +3），保留米调
    surfaceAlt: Color(0xFFEEE5D3),
    canvasDeep: Color(0xFFEBE0CC),
    textPrimary: Color(0xFF4A3D3D),
    textSecondary: Color(0xFF7A6A6A),
    textTertiary: Color(0xFFA89595),
    textInverse: Color(0xFFF5EEE0),
    divider: Color(0xFFE0D5C0),
    brand: Color(0xFF7BC4AB), // 提升饱和度，薄荷绿更鲜活
    brandDeep: Color(0xFF5AA890),
    brandLight: Color(0xFFA0D8C5),
    brandSubtle: Color(0xFFDDEDE5),
    brandText: Color(0xFF3D8068),
    danger: Color(0xFFE09090),
    dangerSubtle: Color(0xFFF5DDDD),
    success: Color(0xFF7BC4AB),
    successSubtle: Color(0xFFDDEDE5),
    shadowConvex: [
      BoxShadow(color: Color(0xFFE0D5C0), offset: Offset(6, 6), blurRadius: 14),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-6, -6), blurRadius: 14),
    ],
    shadowConvexSubtle: [
      BoxShadow(color: Color(0xFFE5DAC5), offset: Offset(3, 3), blurRadius: 6),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 6),
    ],
    shadowConvexBrand: [
      BoxShadow(color: Color(0xFF5AA890), offset: Offset(4, 4), blurRadius: 10),
      BoxShadow(color: Color(0xFFA0D8C5), offset: Offset(-4, -4), blurRadius: 10),
    ],
    shadowConcave: [
      BoxShadow(color: Color(0xFFE2D7C2), offset: Offset(4, 4), blurRadius: 10, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-4, -4), blurRadius: 10, blurStyle: BlurStyle.inner),
    ],
    shadowConcaveSubtle: [
      BoxShadow(color: Color(0xFFE5DAC5), offset: Offset(2, 2), blurRadius: 5, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-2, -2), blurRadius: 5, blurStyle: BlurStyle.inner),
    ],
    shadowPressed: [
      BoxShadow(color: Color(0xFFE2D7C2), offset: Offset(3, 3), blurRadius: 8, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 8, blurStyle: BlurStyle.inner),
    ],
    shadowFloat: [
      BoxShadow(color: Color(0x144A3D3D), offset: Offset(0, 8), blurRadius: 32),
    ],
  );

  // === 莫兰迪主题 ===
  // 来源: App.vue [data-theme="morandi"] (line 234-263)
  static const _morandiTokens = ThemeTokens(
    canvas: Color(0xFFE8E4E0),
    surface: Color(0xFFF2EFEA),
    surfaceAlt: Color(0xFFE0DCD6),
    canvasDeep: Color(0xFFDDD9D3),
    textPrimary: Color(0xFF4A4540),
    textSecondary: Color(0xFF7A7570),
    textTertiary: Color(0xFFA8A29C),
    textInverse: Color(0xFFE8E4E0),
    divider: Color(0xFFD5D0CA),
    brand: Color(0xFF8B9DAF),
    brandDeep: Color(0xFF6B7D8F),
    brandLight: Color(0xFFA8B8C8),
    brandSubtle: Color(0xFFD5DDE5),
    brandText: Color(0xFF5B6D7F),
    danger: Color(0xFFA88080),
    dangerSubtle: Color(0xFFE8DDDD),
    success: Color(0xFF8FA590),
    successSubtle: Color(0xFFDDE5DD),
    shadowConvex: [
      BoxShadow(color: Color(0xFFD5D0CA), offset: Offset(6, 6), blurRadius: 14),
      BoxShadow(color: Color(0xFFF2EFEA), offset: Offset(-6, -6), blurRadius: 14),
    ],
    shadowConvexSubtle: [
      BoxShadow(color: Color(0xFFD8D3CD), offset: Offset(3, 3), blurRadius: 6),
      BoxShadow(color: Color(0xFFF2EFEA), offset: Offset(-3, -3), blurRadius: 6),
    ],
    shadowConvexBrand: [
      BoxShadow(color: Color(0xFF6B7D8F), offset: Offset(4, 4), blurRadius: 10),
      BoxShadow(color: Color(0xFFA8B8C8), offset: Offset(-4, -4), blurRadius: 10),
    ],
    shadowConcave: [
      BoxShadow(color: Color(0xFFD5D0CA), offset: Offset(4, 4), blurRadius: 10, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFF2EFEA), offset: Offset(-4, -4), blurRadius: 10, blurStyle: BlurStyle.inner),
    ],
    shadowConcaveSubtle: [
      BoxShadow(color: Color(0xFFD8D3CD), offset: Offset(2, 2), blurRadius: 5, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFF2EFEA), offset: Offset(-2, -2), blurRadius: 5, blurStyle: BlurStyle.inner),
    ],
    shadowPressed: [
      BoxShadow(color: Color(0xFFD5D0CA), offset: Offset(3, 3), blurRadius: 8, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFF2EFEA), offset: Offset(-3, -3), blurRadius: 8, blurStyle: BlurStyle.inner),
    ],
    shadowFloat: [
      BoxShadow(color: Color(0x144A4540), offset: Offset(0, 8), blurRadius: 32),
    ],
  );

  // === 玫瑰金主题 ===
  // 来源: App.vue [data-theme="rosegold"] (line 265-294)
  // Neumorphic fix: canvas 从 #FAF6F2 加深为 #F5EDE8（带粉调），与 warmWhite 区分；
  // surface 从纯白 #FFFFFF 改为 canvas 微亮变体 #F8F1EC，保留粉调；
  // brand 调深为 #BC8888，brandDeep #A07070，让玫瑰金特色更明显有质感。
  static const _rosegoldTokens = ThemeTokens(
    canvas: Color(0xFFF5EDE8), // 加深 2-3%，带粉调，与 warmWhite 区分
    surface: Color(0xFFF8F1EC), // canvas 微亮变体（RGB +3），保留粉调
    surfaceAlt: Color(0xFFEEE0D8),
    canvasDeep: Color(0xFFEBDBD2),
    textPrimary: Color(0xFF3D2825),
    textSecondary: Color(0xFF6B4C48),
    textTertiary: Color(0xFFA8857D),
    textInverse: Color(0xFFF5EDE8),
    divider: Color(0xFFE5D5CC),
    brand: Color(0xFFBC8888), // 调深，玫瑰金特色更明显
    brandDeep: Color(0xFFA07070),
    brandLight: Color(0xFFD8A8A8),
    brandSubtle: Color(0xFFEFD8D5),
    brandText: Color(0xFF8C5858),
    danger: Color(0xFFBC6868),
    dangerSubtle: Color(0xFFF0D8D5),
    success: Color(0xFF8FAA82),
    successSubtle: Color(0xFFE8EDE2),
    shadowConvex: [
      BoxShadow(color: Color(0xFFE5D5CC), offset: Offset(6, 6), blurRadius: 14),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-6, -6), blurRadius: 14),
    ],
    shadowConvexSubtle: [
      BoxShadow(color: Color(0xFFEADAD0), offset: Offset(3, 3), blurRadius: 6),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 6),
    ],
    shadowConvexBrand: [
      BoxShadow(color: Color(0xFFA07070), offset: Offset(4, 4), blurRadius: 10),
      BoxShadow(color: Color(0xFFD8A8A8), offset: Offset(-4, -4), blurRadius: 10),
    ],
    shadowConcave: [
      BoxShadow(color: Color(0xFFE8D8CE), offset: Offset(4, 4), blurRadius: 10, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-4, -4), blurRadius: 10, blurStyle: BlurStyle.inner),
    ],
    shadowConcaveSubtle: [
      BoxShadow(color: Color(0xFFEADAD0), offset: Offset(2, 2), blurRadius: 5, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-2, -2), blurRadius: 5, blurStyle: BlurStyle.inner),
    ],
    shadowPressed: [
      BoxShadow(color: Color(0xFFE8D8CE), offset: Offset(3, 3), blurRadius: 8, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 8, blurStyle: BlurStyle.inner),
    ],
    shadowFloat: [
      BoxShadow(color: Color(0x143D2825), offset: Offset(0, 8), blurRadius: 32),
    ],
  );
}
