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

  /// 内凹表面渐变（选中/按压/嵌入态，复现 CSS `inset` 内阴影）。
  ///
  /// 对应规范 `box-shadow: inset 4px 4px 9px var(--shadow-dk), inset -4px -4px 9px var(--shadow-lt)`：
  /// 左上内边缘压暗、右下内边缘泛白高光、中间保持平表面（内凹的"地板"）。
  /// 鉴于此 SDK 中 `BoxShadow` 的 `BlurStyle.inner` 不按内阴影渲染（实测被当外阴影画，
  /// 视觉仍是「凸」），故用多段对角渐变模拟 inset 的"边缘明/暗描边 + 中部平底"，
  /// 颜色均派生自当前主题色、随 8 主题 × 4 风格自适应。
  /// 用法：置于选中/按压态的 `BoxDecoration.gradient`。
  static LinearGradient recessedGradient(ThemeTokens t, {double depth = 0.65}) {
    // 左上：内边缘阴影描边；右下：内边缘高光描边；二者随 depth 同步缩放，
    // 胶囊/选中(深)用大 depth、宽沟槽(浅)用小 depth，明暗始终对称不至于失衡。
    final sd = Color.lerp(t.surface, t.shadowConcave.first.color, depth)!;
    final hl = Color.lerp(t.surface, t.shadowConcave[1].color, depth)!;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [sd, t.surface, t.surface, hl],
      stops: const [0.0, 0.22, 0.78, 1.0],
    );
  }

  /// 品牌色「凸起浮雕」外阴影（用于金色 CTA 按钮常态）。
  ///
  /// 复现 neumorphic `shadowConvex` 的双向浮雕，右下暗影取「品牌色加深(压暗)」，
  /// 保证在品牌金色顶面边缘有清晰明暗落差。左上亮影必须**比画布更亮**才能读出
  /// 「左上受光」的方向性浮雕——因此直接取各主题自己的高光色
  /// （`shadowConvex[1]`：亮色主题=纯白、暗色主题=比画布微亮的暖灰），
  /// 与全站新拟态卡片同一套光源语言。此前用 `lerp(brandLight, white, .5)`
  /// ≈ #EADABC，比暖白画布 #FAF7F2 更暗，左上实际是「压暗」而非高光，
  /// 方向性光源消失导致主色按钮常态看不出浮雕。
  static List<BoxShadow> brandEmbossShadows(ThemeTokens t) => [
        BoxShadow(
          color: Color.lerp(t.brand, Colors.black, 0.30)!,
          offset: const Offset(5, 5),
          blurRadius: 12,
        ),
        BoxShadow(
          color: t.shadowConvex[1].color,
          offset: const Offset(-5, -5),
          blurRadius: 12,
        ),
      ];

  /// 品牌色「凸起浮雕」顶面渐变（用于金色 CTA 按钮常态，配合 [brandEmbossShadows]）。
  ///
  /// 新拟态浮雕的本质是「受光曲面被光雕出凸起」：均匀色块 + 投影只能读作
  /// 「悬浮在页面上方的实体按钮」（Material 阴影语义），读不出浮雕感。
  /// 顶面自身必须带方向性明暗——145°（左上受光 → 右下背光）三段微渐变：
  /// 品牌浅色微提亮 → 品牌色 → 品牌色微压暗，模拟鼓起曲面的受光过渡。
  /// 明度跨度刻意克制（~10%），保持金色纯度、不显塑料光泽。
  static LinearGradient brandEmbossGradient(ThemeTokens t) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(t.brandLight, Colors.white, 0.22)!,
          t.brand,
          Color.lerp(t.brand, t.brandDeep, 0.42)!,
        ],
        stops: const [0.0, 0.45, 1.0],
      );

  /// 品牌色凹陷表面用的内影色调：左上暗、右下亮，均取品牌色系。
  static Color brandRecessDark(ThemeTokens t) =>
      Color.lerp(t.brand, Colors.black, 0.34)!;

  static Color brandRecessLight(ThemeTokens t) =>
      Color.lerp(t.brandLight, Colors.white, 0.55)!;

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

  // === glass 风格主题色工具（组件复用，跟随品牌色，亮/暗各一套） ===

  /// glass 磨砂填充色（半透明，让背后彩色背景透出）。亮色主题白底品牌微染，
  /// 暗色主题（ink）暗底品牌微染。
  static Color glassFill(ThemeTokens t) {
    final isDark = t.canvas.computeLuminance() < 0.5;
    final tint = isDark
        ? Color.lerp(const Color(0xFF26231E), t.brand, 0.12)!
        : Color.lerp(Colors.white, t.brandLight, 0.10)!;
    return tint.withOpacity(isDark ? 0.5 : 0.58);
  }

  /// glass 外描边色（灯下白色细边：亮更白，暗微光）
  static Color glassBorder(ThemeTokens t) =>
      Colors.white.withOpacity(t.canvas.computeLuminance() < 0.5 ? 0.20 : 0.55);

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
      BoxShadow(color: Color(0xFFC6C0B5), offset: Offset(6, 6), blurRadius: 14),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-6, -6), blurRadius: 14),
    ],
    shadowConvexSubtle: [
      BoxShadow(color: Color(0xFFC6C0B5), offset: Offset(4, 4), blurRadius: 8),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-4, -4), blurRadius: 8),
    ],
    shadowConvexBrand: [
      BoxShadow(color: Color(0xFFB7BFB0), offset: Offset(6, 6), blurRadius: 14),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-6, -6), blurRadius: 14),
    ],
    shadowConcave: [
      BoxShadow(color: Color(0xFF8A7F70), offset: Offset(5, 5), blurRadius: 5, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-5, -5), blurRadius: 5, blurStyle: BlurStyle.inner),
    ],
    shadowConcaveSubtle: [
      BoxShadow(color: Color(0xFFADA497), offset: Offset(3, 3), blurRadius: 4, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 4, blurStyle: BlurStyle.inner),
    ],
    shadowPressed: [
      BoxShadow(color: Color(0xFF7E7466), offset: Offset(5, 5), blurRadius: 4, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-5, -5), blurRadius: 4, blurStyle: BlurStyle.inner),
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
      BoxShadow(color: Color(0xFF0B0A08), offset: Offset(6, 6), blurRadius: 14),
      BoxShadow(color: Color(0xFF2D2821), offset: Offset(-6, -6), blurRadius: 14),
    ],
    shadowConvexSubtle: [
      BoxShadow(color: Color(0xFF121010), offset: Offset(3, 3), blurRadius: 6),
      BoxShadow(color: Color(0xFF36322C), offset: Offset(-3, -3), blurRadius: 6),
    ],
    shadowConvexBrand: [
      BoxShadow(color: Color(0xFF0B0A08), offset: Offset(6, 6), blurRadius: 14),
      BoxShadow(color: Color(0xFF36322C), offset: Offset(-6, -6), blurRadius: 14),
    ],
    shadowConcave: [
      BoxShadow(color: Color(0xFF000000), offset: Offset(5, 5), blurRadius: 5, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFF4F4940), offset: Offset(-5, -5), blurRadius: 5, blurStyle: BlurStyle.inner),
    ],
    shadowConcaveSubtle: [
      BoxShadow(color: Color(0xFF0A0908), offset: Offset(3, 3), blurRadius: 4, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFF3E3932), offset: Offset(-3, -3), blurRadius: 4, blurStyle: BlurStyle.inner),
    ],
    shadowPressed: [
      BoxShadow(color: Color(0xFF000000), offset: Offset(5, 5), blurRadius: 4, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFF565047), offset: Offset(-5, -5), blurRadius: 4, blurStyle: BlurStyle.inner),
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
      BoxShadow(color: Color(0xFFBDAE96), offset: Offset(5, 5), blurRadius: 12),
      BoxShadow(color: Color(0xFFFFFDF7), offset: Offset(-5, -5), blurRadius: 12),
    ],
    shadowConvexSubtle: [
      BoxShadow(color: Color(0xFFC3B298), offset: Offset(3, 3), blurRadius: 6),
      BoxShadow(color: Color(0xFFFFFDF7), offset: Offset(-3, -3), blurRadius: 6),
    ],
    shadowConvexBrand: [
      BoxShadow(color: Color(0xFF9A7D40), offset: Offset(6, 6), blurRadius: 14),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-6, -6), blurRadius: 14),
    ],
    shadowConcave: [
      BoxShadow(color: Color(0xFF8D7E61), offset: Offset(5, 5), blurRadius: 5, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFDF7), offset: Offset(-5, -5), blurRadius: 5, blurStyle: BlurStyle.inner),
    ],
    shadowConcaveSubtle: [
      BoxShadow(color: Color(0xFFAD9C7F), offset: Offset(3, 3), blurRadius: 4, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFDF7), offset: Offset(-3, -3), blurRadius: 4, blurStyle: BlurStyle.inner),
    ],
    shadowPressed: [
      BoxShadow(color: Color(0xFF7C6D52), offset: Offset(5, 5), blurRadius: 4, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFDF7), offset: Offset(-5, -5), blurRadius: 4, blurStyle: BlurStyle.inner),
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
      BoxShadow(color: Color(0xFFB7BFB0), offset: Offset(6, 6), blurRadius: 14),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-6, -6), blurRadius: 14),
    ],
    shadowConvexSubtle: [
      BoxShadow(color: Color(0xFFBDC6B4), offset: Offset(3, 3), blurRadius: 6),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 6),
    ],
    shadowConvexBrand: [
      BoxShadow(color: Color(0xFFB7BFB0), offset: Offset(6, 6), blurRadius: 14),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-6, -6), blurRadius: 14),
    ],
    shadowConcave: [
      BoxShadow(color: Color(0xFF879275), offset: Offset(5, 5), blurRadius: 5, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-5, -5), blurRadius: 5, blurStyle: BlurStyle.inner),
    ],
    shadowConcaveSubtle: [
      BoxShadow(color: Color(0xFF9CA88E), offset: Offset(3, 3), blurRadius: 4, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 4, blurStyle: BlurStyle.inner),
    ],
    shadowPressed: [
      BoxShadow(color: Color(0xFF7B8767), offset: Offset(5, 5), blurRadius: 4, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-5, -5), blurRadius: 4, blurStyle: BlurStyle.inner),
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
      BoxShadow(color: Color(0xFFD6BEBE), offset: Offset(6, 6), blurRadius: 14),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-6, -6), blurRadius: 14),
    ],
    shadowConvexSubtle: [
      BoxShadow(color: Color(0xFFDBC9C9), offset: Offset(3, 3), blurRadius: 6),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 6),
    ],
    shadowConvexBrand: [
      BoxShadow(color: Color(0xFFD6BEBE), offset: Offset(6, 6), blurRadius: 14),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-6, -6), blurRadius: 14),
    ],
    shadowConcave: [
      BoxShadow(color: Color(0xFF9C7F7F), offset: Offset(5, 5), blurRadius: 5, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-5, -5), blurRadius: 5, blurStyle: BlurStyle.inner),
    ],
    shadowConcaveSubtle: [
      BoxShadow(color: Color(0xFFB9A0A0), offset: Offset(3, 3), blurRadius: 4, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 4, blurStyle: BlurStyle.inner),
    ],
    shadowPressed: [
      BoxShadow(color: Color(0xFF8C7070), offset: Offset(5, 5), blurRadius: 4, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-5, -5), blurRadius: 4, blurStyle: BlurStyle.inner),
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
      BoxShadow(color: Color(0xFFCFC1A6), offset: Offset(6, 6), blurRadius: 14),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-6, -6), blurRadius: 14),
    ],
    shadowConvexSubtle: [
      BoxShadow(color: Color(0xFFD3C6AC), offset: Offset(3, 3), blurRadius: 6),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 6),
    ],
    shadowConvexBrand: [
      BoxShadow(color: Color(0xFFCFC1A6), offset: Offset(6, 6), blurRadius: 14),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-6, -6), blurRadius: 14),
    ],
    shadowConcave: [
      BoxShadow(color: Color(0xFF91805F), offset: Offset(5, 5), blurRadius: 5, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-5, -5), blurRadius: 5, blurStyle: BlurStyle.inner),
    ],
    shadowConcaveSubtle: [
      BoxShadow(color: Color(0xFFAF9F83), offset: Offset(3, 3), blurRadius: 4, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 4, blurStyle: BlurStyle.inner),
    ],
    shadowPressed: [
      BoxShadow(color: Color(0xFF80705A), offset: Offset(5, 5), blurRadius: 4, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-5, -5), blurRadius: 4, blurStyle: BlurStyle.inner),
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
      BoxShadow(color: Color(0xFFC2BCB3), offset: Offset(6, 6), blurRadius: 14),
      BoxShadow(color: Color(0xFFF6F3EE), offset: Offset(-6, -6), blurRadius: 14),
    ],
    shadowConvexSubtle: [
      BoxShadow(color: Color(0xFFC6C0B7), offset: Offset(3, 3), blurRadius: 6),
      BoxShadow(color: Color(0xFFF6F3EE), offset: Offset(-3, -3), blurRadius: 6),
    ],
    shadowConvexBrand: [
      BoxShadow(color: Color(0xFFC2BCB3), offset: Offset(6, 6), blurRadius: 14),
      BoxShadow(color: Color(0xFFF6F3EE), offset: Offset(-6, -6), blurRadius: 14),
    ],
    shadowConcave: [
      BoxShadow(color: Color(0xFF877F74), offset: Offset(5, 5), blurRadius: 5, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFBF8F3), offset: Offset(-5, -5), blurRadius: 5, blurStyle: BlurStyle.inner),
    ],
    shadowConcaveSubtle: [
      BoxShadow(color: Color(0xFFABA298), offset: Offset(3, 3), blurRadius: 4, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFBF8F3), offset: Offset(-3, -3), blurRadius: 4, blurStyle: BlurStyle.inner),
    ],
    shadowPressed: [
      BoxShadow(color: Color(0xFF787067), offset: Offset(5, 5), blurRadius: 4, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFBF8F3), offset: Offset(-5, -5), blurRadius: 4, blurStyle: BlurStyle.inner),
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
      BoxShadow(color: Color(0xFFD3C0B5), offset: Offset(6, 6), blurRadius: 14),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-6, -6), blurRadius: 14),
    ],
    shadowConvexSubtle: [
      BoxShadow(color: Color(0xFFD8C5B8), offset: Offset(3, 3), blurRadius: 6),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 6),
    ],
    shadowConvexBrand: [
      BoxShadow(color: Color(0xFFBDAE96), offset: Offset(6, 6), blurRadius: 14),
      BoxShadow(color: Color(0xFFFFFDF7), offset: Offset(-6, -6), blurRadius: 14),
    ],
    shadowConcave: [
      BoxShadow(color: Color(0xFF9C8470), offset: Offset(5, 5), blurRadius: 5, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-5, -5), blurRadius: 5, blurStyle: BlurStyle.inner),
    ],
    shadowConcaveSubtle: [
      BoxShadow(color: Color(0xFFBEA896), offset: Offset(3, 3), blurRadius: 4, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 4, blurStyle: BlurStyle.inner),
    ],
    shadowPressed: [
      BoxShadow(color: Color(0xFF8A7565), offset: Offset(5, 5), blurRadius: 4, blurStyle: BlurStyle.inner),
      BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-5, -5), blurRadius: 4, blurStyle: BlurStyle.inner),
    ],
    shadowFloat: [
      BoxShadow(color: Color(0x143D2825), offset: Offset(0, 8), blurRadius: 32),
    ],
  );
}
