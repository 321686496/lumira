import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/profile_mock_data.dart';

/// 主题与风格选择页（**关键页：接入 themeKeyProvider / uiStyleProvider**）
///
/// 视觉规格来源：lumira-app/src/pages/profile/settings/theme.vue（405 行）
/// - UI 风格区（2 列 × 4 项）：neumorphic / flat / glass / female
/// - 颜色主题区（2 列 × 8 项）：8 套主题
/// - 跟随系统 toggle
///
/// 切换后即时生效：因 themeKeyProvider / uiStyleProvider 是 StateProvider，
/// 修改 state 后所有 ref.watch 的 widget 自动 rebuild。
class ProfileThemePage extends ConsumerStatefulWidget {
  const ProfileThemePage({super.key});

  @override
  ConsumerState<ProfileThemePage> createState() => _ProfileThemePageState();
}

class _ProfileThemePageState extends ConsumerState<ProfileThemePage> {
  bool _followSystem = false;

  void _selectTheme(ThemeKey key) {
    ref.read(themeKeyProvider.notifier).state = key;
    final label = ProfileMockData.themes.firstWhere((t) => t.key == key).label;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已切换至$label'),
        duration: const Duration(milliseconds: 1000),
      ),
    );
  }

  void _selectStyle(UIStyle style) {
    ref.read(uiStyleProvider.notifier).state = style;
    final label = ProfileMockData.styles.firstWhere((s) => s.style == style).label;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已切换至$label风格'),
        duration: const Duration(milliseconds: 1000),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = ref.watch(themeKeyProvider);
    final currentStyle = ref.watch(uiStyleProvider);
    final tokens = ref.watch(themeTokensProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '主题与风格',
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
                  tokens: tokens,
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
      onTap: () => GoRouter.of(context).pop(),
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.canvas,
          borderRadius: BorderRadius.circular(14),
          border: selected
              ? Border.all(color: tokens.brand, width: 1)
              : Border.all(color: tokens.divider, width: 0.5),
          boxShadow: selected ? tokens.shadowConcaveSubtle : null,
        ),
        child: Stack(
          children: [
            Padding(
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
            ),
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
              color: tokens.canvas,
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
              color: tokens.canvas,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.divider, width: 1),
            ),
          ),
        );
      case UIStyle.glass:
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [tokens.brand.withOpacity(0.2), tokens.brandSubtle.withOpacity(0.3)],
                ),
              ),
              child: Center(
                child: Container(
                  width: 40,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.5),
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
                    color: tokens.brand.withOpacity(0.25),
                    blurRadius: 16,
                    spreadRadius: 2,
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
                color: Colors.white.withOpacity(0.55),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.5), width: 0.5),
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
    required this.tokens,
    required this.onSelect,
  });
  final ThemeKey currentTheme;
  final ThemeTokens tokens;
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
          tokens: tokens,
          onTap: () => onSelect(t.key),
        );
      }).toList(),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.preview,
    required this.selected,
    required this.tokens,
    required this.onTap,
  });
  final ThemePreview preview;
  final bool selected;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tokens.canvas,
          borderRadius: BorderRadius.circular(14),
          border: selected
              ? Border.all(color: tokens.brand, width: 1)
              : Border.all(color: tokens.divider, width: 0.5),
          boxShadow: selected ? tokens.shadowConcaveSubtle : null,
        ),
        child: Column(
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
                  if (selected)
                    Positioned(
                      top: 6,
                      right: 6,
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
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: tokens.brand,
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
