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
  static const _warmWhiteTokens = ThemeTokens(
    canvas: Color(0xFFFAF7F2),
    surface: Color(0xFFFFFFFF),
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
  static const _retroTokens = ThemeTokens(
    canvas: Color(0xFFF5E6D3),
    surface: Color(0xFFFFF8F0),
    surfaceAlt: Color(0xFFEBDAC4),
    canvasDeep: Color(0xFFEBDAC4),
    textPrimary: Color(0xFF3D2817),
    textSecondary: Color(0xFF6B4C2F),
    textTertiary: Color(0xFF9C8060),
    textInverse: Color(0xFFF5E6D3),
    divider: Color(0xFFD9C9B3),
    brand: Color(0xFFC4956A),
    brandDeep: Color(0xFFA67B52),
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
  static const _freshTokens = ThemeTokens(
    canvas: Color(0xFFF8FAF6),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEDF2EB),
    canvasDeep: Color(0xFFE8EDE5),
    textPrimary: Color(0xFF4A3F35),
    textSecondary: Color(0xFF8C7F70),
    textTertiary: Color(0xFFB8AEA0),
    textInverse: Color(0xFFF8FAF6),
    divider: Color(0xFFDDE5D8),
    brand: Color(0xFF8BAD72),
    brandDeep: Color(0xFF6E9458),
    brandLight: Color(0xFFA8D8A0),
    brandSubtle: Color(0xFFE8F0E2),
    brandText: Color(0xFF5E8348),
    danger: Color(0xFFC87878),
    dangerSubtle: Color(0xFFF5E0E0),
    success: Color(0xFF9AAB7C),
    successSubtle: Color(0xFFEDF2E8),
    shadowConvex: [
      BoxShadow(color: Color(0xFFD4DBD0), offset: Offset(6, 6), blurRadius: 14),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-6, -6), blurRadius: 14),
    ],
    shadowConvexSubtle: [
      BoxShadow(color: Color(0xFFD8DFD4), offset: Offset(3, 3), blurRadius: 6),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 6),
    ],
    shadowConvexBrand: [
      BoxShadow(color: Color(0xFF7A9B62), offset: Offset(4, 4), blurRadius: 10),
      BoxShadow(color: Color(0xFF9CC084), offset: Offset(-4, -4), blurRadius: 10),
    ],
    shadowConcave: [
      BoxShadow(color: Color(0xFFD6DDD2), offset: Offset(4, 4), blurRadius: 10, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-4, -4), blurRadius: 10, blurStyle: BlurStyle.inner),
    ],
    shadowConcaveSubtle: [
      BoxShadow(color: Color(0xFFD8DFD4), offset: Offset(2, 2), blurRadius: 5, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-2, -2), blurRadius: 5, blurStyle: BlurStyle.inner),
    ],
    shadowPressed: [
      BoxShadow(color: Color(0xFFD6DDD2), offset: Offset(3, 3), blurRadius: 8, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 8, blurStyle: BlurStyle.inner),
    ],
    shadowFloat: [
      BoxShadow(color: Color(0x144A3F35), offset: Offset(0, 8), blurRadius: 32),
    ],
  );

  // === 温馨粉主题 ===
  // 来源: App.vue [data-theme="cozy"] (line 172-201)
  static const _cozyTokens = ThemeTokens(
    canvas: Color(0xFFFFF5F5),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFFAEDED),
    canvasDeep: Color(0xFFF5EAEA),
    textPrimary: Color(0xFF4A3A3A),
    textSecondary: Color(0xFF8C7070),
    textTertiary: Color(0xFFB89A9A),
    textInverse: Color(0xFFFFF5F5),
    divider: Color(0xFFF0E0E0),
    brand: Color(0xFFE8A0A0),
    brandDeep: Color(0xFFD4858A),
    brandLight: Color(0xFFF0B5B5),
    brandSubtle: Color(0xFFFCE8E8),
    brandText: Color(0xFFC47070),
    danger: Color(0xFFD47070),
    dangerSubtle: Color(0xFFFCE8E8),
    success: Color(0xFF8FB088),
    successSubtle: Color(0xFFEDF2E8),
    shadowConvex: [
      BoxShadow(color: Color(0xFFF0E0E0), offset: Offset(6, 6), blurRadius: 14),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-6, -6), blurRadius: 14),
    ],
    shadowConvexSubtle: [
      BoxShadow(color: Color(0xFFF2E2E2), offset: Offset(3, 3), blurRadius: 6),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 6),
    ],
    shadowConvexBrand: [
      BoxShadow(color: Color(0xFFD4858A), offset: Offset(4, 4), blurRadius: 10),
      BoxShadow(color: Color(0xFFF0B5B5), offset: Offset(-4, -4), blurRadius: 10),
    ],
    shadowConcave: [
      BoxShadow(color: Color(0xFFF0E0E0), offset: Offset(4, 4), blurRadius: 10, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-4, -4), blurRadius: 10, blurStyle: BlurStyle.inner),
    ],
    shadowConcaveSubtle: [
      BoxShadow(color: Color(0xFFF2E2E2), offset: Offset(2, 2), blurRadius: 5, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-2, -2), blurRadius: 5, blurStyle: BlurStyle.inner),
    ],
    shadowPressed: [
      BoxShadow(color: Color(0xFFF0E0E0), offset: Offset(3, 3), blurRadius: 8, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 8, blurStyle: BlurStyle.inner),
    ],
    shadowFloat: [
      BoxShadow(color: Color(0x144A3A3A), offset: Offset(0, 8), blurRadius: 32),
    ],
  );

  // === 马卡龙主题 ===
  // 来源: App.vue [data-theme="macaron"] (line 203-232)
  static const _macaronTokens = ThemeTokens(
    canvas: Color(0xFFFFF8F0),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF5F0E8),
    canvasDeep: Color(0xFFF0EAE0),
    textPrimary: Color(0xFF5A4A4A),
    textSecondary: Color(0xFF8C7A7A),
    textTertiary: Color(0xFFB8A8A0),
    textInverse: Color(0xFFFFF8F0),
    divider: Color(0xFFE8E0D5),
    brand: Color(0xFFA8D8C8),
    brandDeep: Color(0xFF8CC5B5),
    brandLight: Color(0xFFC5E8DD),
    brandSubtle: Color(0xFFE0F0EA),
    brandText: Color(0xFF5E9882),
    danger: Color(0xFFE8A0A0),
    dangerSubtle: Color(0xFFFCE8E8),
    success: Color(0xFFA8D8C8),
    successSubtle: Color(0xFFE0F0EA),
    shadowConvex: [
      BoxShadow(color: Color(0xFFE8E0D5), offset: Offset(6, 6), blurRadius: 14),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-6, -6), blurRadius: 14),
    ],
    shadowConvexSubtle: [
      BoxShadow(color: Color(0xFFEDE5D8), offset: Offset(3, 3), blurRadius: 6),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 6),
    ],
    shadowConvexBrand: [
      BoxShadow(color: Color(0xFF8CC5B5), offset: Offset(4, 4), blurRadius: 10),
      BoxShadow(color: Color(0xFFC5E8DD), offset: Offset(-4, -4), blurRadius: 10),
    ],
    shadowConcave: [
      BoxShadow(color: Color(0xFFE8E0D5), offset: Offset(4, 4), blurRadius: 10, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-4, -4), blurRadius: 10, blurStyle: BlurStyle.inner),
    ],
    shadowConcaveSubtle: [
      BoxShadow(color: Color(0xFFEDE5D8), offset: Offset(2, 2), blurRadius: 5, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-2, -2), blurRadius: 5, blurStyle: BlurStyle.inner),
    ],
    shadowPressed: [
      BoxShadow(color: Color(0xFFE8E0D5), offset: Offset(3, 3), blurRadius: 8, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 8, blurStyle: BlurStyle.inner),
    ],
    shadowFloat: [
      BoxShadow(color: Color(0x145A4A4A), offset: Offset(0, 8), blurRadius: 32),
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
  static const _rosegoldTokens = ThemeTokens(
    canvas: Color(0xFFFAF6F2),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF5EDE8),
    canvasDeep: Color(0xFFF0E8E2),
    textPrimary: Color(0xFF3D2E2A),
    textSecondary: Color(0xFF6B5450),
    textTertiary: Color(0xFFA89088),
    textInverse: Color(0xFFFAF6F2),
    divider: Color(0xFFE8DDD5),
    brand: Color(0xFFC9A0A0),
    brandDeep: Color(0xFFB08585),
    brandLight: Color(0xFFDDB8B8),
    brandSubtle: Color(0xFFF0E0E0),
    brandText: Color(0xFFA06868),
    danger: Color(0xFFC47878),
    dangerSubtle: Color(0xFFF0E0E0),
    success: Color(0xFF9AB088),
    successSubtle: Color(0xFFE8F0E0),
    shadowConvex: [
      BoxShadow(color: Color(0xFFE8DDD5), offset: Offset(6, 6), blurRadius: 14),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-6, -6), blurRadius: 14),
    ],
    shadowConvexSubtle: [
      BoxShadow(color: Color(0xFFEDE2DA), offset: Offset(3, 3), blurRadius: 6),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 6),
    ],
    shadowConvexBrand: [
      BoxShadow(color: Color(0xFFB08585), offset: Offset(4, 4), blurRadius: 10),
      BoxShadow(color: Color(0xFFDDB8B8), offset: Offset(-4, -4), blurRadius: 10),
    ],
    shadowConcave: [
      BoxShadow(color: Color(0xFFE8DDD5), offset: Offset(4, 4), blurRadius: 10, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-4, -4), blurRadius: 10, blurStyle: BlurStyle.inner),
    ],
    shadowConcaveSubtle: [
      BoxShadow(color: Color(0xFFEDE2DA), offset: Offset(2, 2), blurRadius: 5, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-2, -2), blurRadius: 5, blurStyle: BlurStyle.inner),
    ],
    shadowPressed: [
      BoxShadow(color: Color(0xFFE8DDD5), offset: Offset(3, 3), blurRadius: 8, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 8, blurStyle: BlurStyle.inner),
    ],
    shadowFloat: [
      BoxShadow(color: Color(0x143D2E2A), offset: Offset(0, 8), blurRadius: 32),
    ],
  );
}
