import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/router/route_names.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/profile_mock_data.dart';

/// 主题与风格选择页（**关键页：接入 themeKeyProvider / uiStyleProvider**）
///
/// 视觉规格来源：lumira-app/src/pages/profile/settings/theme.vue（405 行）
/// - UI 风格区（2 列 × 4 项）：neumorphic / flat / glass / female
/// - 颜色主题区（2 列 × 8 项）：8 套主题
/// - 跟随系统 toggle
///
/// Forced fix: 切换风格后整页 chrome（背景/_StyleCard/_ThemeCard/_FollowSystemCard）
/// 都根据当前 appTheme.style 动态渲染，让用户能即时预览效果。
class ProfileThemePage extends ConsumerStatefulWidget {
  const ProfileThemePage({super.key});

  @override
  ConsumerState<ProfileThemePage> createState() => _ProfileThemePageState();
}

class _ProfileThemePageState extends ConsumerState<ProfileThemePage> {
  bool _followSystem = false;

  void _selectTheme(ThemeKey key) {
    final label = ProfileMockData.themes.firstWhere((t) => t.key == key).label;
    // 切换即生效 + 持久化到本地
    // ignore: unawaited_futures
    persistTheme(ref, key);
    LumiraToast.show(context, '已切换至$label', duration: const Duration(milliseconds: 1000));
  }

  void _selectStyle(UIStyle style) {
    final label = ProfileMockData.styles.firstWhere((s) => s.style == style).label;
    // 切换即生效 + 持久化到本地
    // ignore: unawaited_futures
    persistUiStyle(ref, style);
    LumiraToast.show(context, '已切换至$label风格', duration: const Duration(milliseconds: 1000));
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = ref.watch(themeKeyProvider);
    final currentStyle = ref.watch(uiStyleProvider);
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '主题与风格',
        transparent: true,
        leading: _BackButton(tokens: tokens),
      ),
      body: Stack(
        children: [
          // Forced fix: 玻璃拟态需彩色背景才能体现 blur。
          // 不同风格给不同强度装饰背景：
          // - neumorphic: 单色 canvas（保持拟态同色）
          // - flat: 轻微径向
          // - glass: 强径向 + 多色斑（让 blur 后能看出毛玻璃）
          // - female: 柔和品牌色径向
          Positioned.fill(
            child: _StyleBackground(style: currentStyle, tokens: tokens),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 20, 12, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionTitle(text: 'UI 风格', tokens: tokens),
                  const SizedBox(height: 8),
                  _StyleGrid(
                    currentStyle: currentStyle,
                    tokens: tokens,
                    onSelect: _selectStyle,
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle(text: '颜色主题', tokens: tokens),
                  const SizedBox(height: 8),
                  _ThemeGrid(
                    currentTheme: currentTheme,
                    appTheme: appTheme,
                    onSelect: _selectTheme,
                  ),
                  const SizedBox(height: 16),
                  _FollowSystemCard(
                    tokens: tokens,
                    value: _followSystem,
                    onChanged: (v) => setState(() => _followSystem = v),
                  ),
                  const SizedBox(height: 12),
                  _BottomNote(tokens: tokens),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 不同风格的页面背景装饰
class _StyleBackground extends StatelessWidget {
  const _StyleBackground({required this.style, required this.tokens});
  final UIStyle style;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case UIStyle.neumorphic:
        // 单色 canvas，保持拟态同色背景
        return ColoredBox(color: tokens.canvas);
      case UIStyle.flat:
        // 轻微径向点缀
        return DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.canvas,
            gradient: RadialGradient(
              center: const Alignment(-0.8, -0.6),
              radius: 1.2,
              colors: [
                tokens.brandSubtle.withOpacity(0.20),
                tokens.canvas,
              ],
              stops: const [0.0, 0.7],
            ),
          ),
        );
      case UIStyle.glass:
        // 强径向 + 多色斑，让 blur 后能看出毛玻璃
        return Stack(
          children: [
            ColoredBox(color: tokens.canvas),
            Positioned(
              top: -60,
              left: -40,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tokens.brand.withOpacity(0.35),
                ),
              ),
            ),
            Positioned(
              top: 120,
              right: -60,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tokens.brandLight.withOpacity(0.30),
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              left: 80,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tokens.brandSubtle.withOpacity(0.55),
                ),
              ),
            ),
          ],
        );
      case UIStyle.female:
        // 柔和品牌色径向 + 高光
        return Stack(
          children: [
            ColoredBox(color: tokens.canvas),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.7, -0.5),
                    radius: 1.4,
                    colors: [
                      tokens.brandSubtle.withOpacity(0.55),
                      tokens.brandLight.withOpacity(0.20),
                      tokens.canvas,
                    ],
                    stops: const [0.0, 0.4, 0.85],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 80,
              right: -30,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tokens.brand.withOpacity(0.18),
                ),
              ),
            ),
          ],
        );
    }
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Forced fix: canPop 保护
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          GoRouter.of(context).go(RouteNames.profileSettings);
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text, required this.tokens});
  final String text;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: tokens.textTertiary,
          letterSpacing: 0.04 * 14,
        ),
      ),
    );
  }
}

class _StyleGrid extends StatelessWidget {
  const _StyleGrid({
    required this.currentStyle,
    required this.tokens,
    required this.onSelect,
  });
  final UIStyle currentStyle;
  final ThemeTokens tokens;
  final void Function(UIStyle) onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.0,
      children: ProfileMockData.styles.map((s) {
        return _StyleCard(
          preview: s,
          selected: s.style == currentStyle,
          tokens: tokens,
          onTap: () => onSelect(s.style),
        );
      }).toList(),
    );
  }
}

/// Forced fix: _StyleCard 自身按 preview.style 渲染，
/// 让用户在卡片本身就能预览到该风格的效果（不只是 60dp 的小预览）。
class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.preview,
    required this.selected,
    required this.tokens,
    required this.onTap,
  });
  final StylePreview preview;
  final bool selected;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isGlass = preview.style == UIStyle.glass;
    final isFemale = preview.style == UIStyle.female;
    final isNeu = preview.style == UIStyle.neumorphic;

    // 选中边框颜色
    final selectedBorder = Border.all(color: tokens.brand, width: 1.5);
    final normalBorder = Border.all(color: tokens.divider, width: 0.5);

    // 卡片内容
    final content = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 预览区
          SizedBox(
            height: 60,
            child: _StylePreview(style: preview.style, tokens: tokens),
          ),
          const SizedBox(height: 8),
          Text(
            preview.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            preview.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: tokens.textTertiary,
            ),
          ),
        ],
      ),
    );

    Widget card;
    if (isGlass) {
      // Forced fix: glass 预览卡片与 NeuCard.glass 保持一致（5 层视觉）
      // 1. blur 25
      // 2. 3 段渐变白 0.85→0.50→0.30
      // 3. 顶部高光反射
      // 4. 双层边框
      // 5. 深阴影
      card = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.85),
                        Colors.white.withOpacity(0.50),
                        Colors.white.withOpacity(0.30),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.6),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            // 顶部高光
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 30,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.45),
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // 选中边框（叠加在 glass 边框上）
            if (selected)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: tokens.brand, width: 1.5),
                    ),
                  ),
                ),
              ),
            content,
          ],
        ),
      );
    } else if (isFemale) {
      // 女性美学：多渐变
      card = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tokens.brandSubtle.withOpacity(0.85),
              tokens.surface.withOpacity(0.65),
              tokens.brandLight.withOpacity(0.45),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          border: selected
              ? selectedBorder
              : Border.all(color: Colors.white.withOpacity(0.6), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: tokens.brand.withOpacity(0.20),
              offset: const Offset(0, 8),
              blurRadius: 24,
            ),
          ],
        ),
        child: content,
      );
    } else if (isNeu) {
      // 新拟态：同色 + 双向阴影
      card = Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected ? tokens.shadowConcaveSubtle : tokens.shadowConvexSubtle,
        ),
        child: content,
      );
    } else {
      // 扁平化：纯色 + 边框
      card = Container(
        decoration: BoxDecoration(
          color: tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: selected ? selectedBorder : normalBorder,
        ),
        child: content,
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          card,
          if (selected)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: tokens.brand,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 14, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _StylePreview extends StatelessWidget {
  const _StylePreview({required this.style, required this.tokens});
  final UIStyle style;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case UIStyle.neumorphic:
        return Center(
          child: Container(
            width: 50,
            height: 40,
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(8),
              boxShadow: tokens.shadowConvexSubtle,
            ),
          ),
        );
      case UIStyle.flat:
        return Center(
          child: Container(
            width: 50,
            height: 40,
            decoration: BoxDecoration(
              color: tokens.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.divider, width: 1),
            ),
          ),
        );
      case UIStyle.glass:
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [tokens.brand.withOpacity(0.25), tokens.brandSubtle.withOpacity(0.35)],
                ),
              ),
              child: Center(
                child: Container(
                  width: 40,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withOpacity(0.4), width: 0.5),
                  ),
                ),
              ),
            ),
          ),
        );
      case UIStyle.female:
        return Stack(
          alignment: Alignment.center,
          children: [
            // brand 色光晕
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: tokens.brand.withOpacity(0.30),
                    blurRadius: 18,
                    spreadRadius: 3,
                  ),
                ],
              ),
              width: 50,
              height: 40,
            ),
            Container(
              width: 50,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.70),
                    tokens.brandSubtle.withOpacity(0.60),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.6), width: 0.5),
              ),
            ),
          ],
        );
    }
  }
}

class _ThemeGrid extends StatelessWidget {
  const _ThemeGrid({
    required this.currentTheme,
    required this.appTheme,
    required this.onSelect,
  });
  final ThemeKey currentTheme;
  final AppThemeData appTheme;
  final void Function(ThemeKey) onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.05,
      children: ProfileMockData.themes.map((t) {
        return _ThemeCard(
          preview: t,
          selected: t.key == currentTheme,
          appTheme: appTheme,
          onTap: () => onSelect(t.key),
        );
      }).toList(),
    );
  }
}

/// Forced fix: _ThemeCard 使用 NeuCard 让卡片本身按当前风格渲染。
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.preview,
    required this.selected,
    required this.appTheme,
    required this.onTap,
  });
  final ThemePreview preview;
  final bool selected;
  final AppThemeData appTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = appTheme.tokens;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: NeuCard(
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 色块
                SizedBox(
                  height: 48,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: preview.canvasColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: preview.brandColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  preview.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                // 4 个 color dots
                Row(
                  children: preview.previewColors.map((c) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(color: tokens.divider, width: 0.5),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            if (selected)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: tokens.brand,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FollowSystemCard extends StatelessWidget {
  const _FollowSystemCard({
    required this.tokens,
    required this.value,
    required this.onChanged,
  });
  final ThemeTokens tokens;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.brightness_6_outlined, size: 18, color: tokens.brand),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '跟随系统',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '自动跟随系统深浅色模式',
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          LumiraSwitch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _BottomNote extends StatelessWidget {
  const _BottomNote({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '风格与主题可任意组合，切换即时生效',
        style: TextStyle(
          fontSize: 11,
          color: tokens.textTertiary,
        ),
      ),
    );
  }
}
