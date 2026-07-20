import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/profile_mock_data.dart';

/// 关于如画页
///
/// Forced fix: 之前"关于如画"点击只弹 SnackBar，不符合用户预期。
/// 改为独立页面，展示 App 信息、版本号、设计理念、联系方式、开源许可等。
class ProfileAboutPage extends ConsumerWidget {
  const ProfileAboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '关于如画',
        transparent: true,
        leading: _BackButton(tokens: tokens),
      ),
      body: Stack(
        children: [
          // 背景装饰
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.8, -0.6),
                  radius: 1.3,
                  colors: [
                    tokens.brandSubtle.withOpacity(0.45),
                    tokens.brandLight.withOpacity(0.15),
                    tokens.canvas,
                  ],
                  stops: const [0.0, 0.4, 0.85],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. App Logo + 名称 + 版本
                  _AppHeader(tokens: tokens),
                  const SizedBox(height: 20),
                  // 2. 设计理念
                  _SectionCard(
                    tokens: tokens,
                    icon: Icons.auto_awesome_outlined,
                    title: '设计理念',
                    children: [
                      _BulletText(
                        text: '东方新拟态 — 用柔和阴影与细腻质感，让数字界面重新拥有手作的温度。',
                        tokens: tokens,
                      ),
                      _BulletText(
                        text: '场景先行 — 每一次按下快门前，先有故事、光线与构图。',
                        tokens: tokens,
                      ),
                      _BulletText(
                        text: '低门槛创作 — 模板与套件让普通人也能拍出有故事感的画面。',
                        tokens: tokens,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 3. 版本信息
                  _SectionCard(
                    tokens: tokens,
                    icon: Icons.history_outlined,
                    title: '版本信息',
                    children: [
                      _InfoRow(
                        label: '当前版本',
                        value: ProfileMockData.appVersion,
                        tokens: tokens,
                      ),
                      _InfoRow(
                        label: '发布日期',
                        value: '2026.07',
                        tokens: tokens,
                      ),
                      _InfoRow(
                        label: '构建编号',
                        value: 'flutter-harmony-001',
                        tokens: tokens,
                        isLast: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 4. 联系我们
                  _SectionCard(
                    tokens: tokens,
                    icon: Icons.mail_outlined,
                    title: '联系我们',
                    children: [
                      _InfoRow(
                        label: '官方邮箱',
                        value: 'hello@lumira.app',
                        tokens: tokens,
                      ),
                      _InfoRow(
                        label: '用户反馈',
                        value: 'feedback@lumira.app',
                        tokens: tokens,
                      ),
                      _InfoRow(
                        label: '官方社区',
                        value: '@如画Lumira',
                        tokens: tokens,
                        isLast: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 5. 开源许可
                  _SectionCard(
                    tokens: tokens,
                    icon: Icons.code_outlined,
                    title: '开源许可',
                    children: [
                      _InfoRow(
                        label: 'Flutter',
                        value: 'BSD-style License',
                        tokens: tokens,
                      ),
                      _InfoRow(
                        label: 'Riverpod',
                        value: 'MIT License',
                        tokens: tokens,
                      ),
                      _InfoRow(
                        label: 'go_router',
                        value: 'BSD-2-Clause',
                        tokens: tokens,
                        isLast: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // 6. 底部签名
                  Center(
                    child: Text(
                      '© 2026 如画 Lumira',
                      style: TextStyle(
                        fontSize: 11,
                        color: tokens.textTertiary,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'Made with ♥ for everyday poets',
                      style: TextStyle(
                        fontSize: 10,
                        color: tokens.textTertiary.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
        // Forced fix: canPop 保护
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
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

class _AppHeader extends StatelessWidget {
  const _AppHeader({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [tokens.brand, tokens.brandLight],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: tokens.brand.withOpacity(0.30),
                offset: const Offset(0, 10),
                blurRadius: 24,
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '如',
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontFamily: 'Noto Serif SC',
                height: 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '如画 Lumira',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            fontFamily: 'Noto Serif SC',
            color: tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          ProfileMockData.appVersion,
          style: TextStyle(
            fontSize: 13,
            color: tokens.textTertiary,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: tokens.brandSubtle.withOpacity(0.30),
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Text(
            ProfileMockData.appVersionDesc,
            style: TextStyle(
              fontSize: 12,
              color: tokens.brand,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.tokens,
    required this.icon,
    required this.title,
    required this.children,
  });
  final ThemeTokens tokens;
  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: tokens.brand),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _BulletText extends StatelessWidget {
  const _BulletText({required this.text, required this.tokens});
  final String text;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.brand,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: tokens.textSecondary,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.tokens,
    this.isLast = false,
  });
  final String label;
  final String value;
  final ThemeTokens tokens;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: tokens.textTertiary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: tokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
