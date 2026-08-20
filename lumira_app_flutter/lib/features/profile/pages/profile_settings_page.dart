import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/preferences/home_wordmark_style.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/brand/home_brand_title.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../capture/watermark/data/watermark_providers.dart';
import '../data/profile_mock_data.dart';

/// 设置页
///
/// 视觉规格来源：lumira-app/src/pages/profile/settings.vue（323 行）
/// 分组：通用 / 首页标题样式 / 显示 / 拍摄 / 关于 / 合规与法律
///
/// 关键交互：
/// - 主题选择 / 风格选择点击 → 跳 profileSettingsTheme
/// - 4 个 toggle 开关（网格 / 水平仪 / 快门声 / 水印）
/// - 版本号 7 连击 → 跳转兑换码页面
/// - 合规条目（用户协议 / 隐私政策 / 个人信息清单与SDK目录）→ 跳转对应详情页
class ProfileSettingsPage extends ConsumerStatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  ConsumerState<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends ConsumerState<ProfileSettingsPage> {
  late bool _gridOn = ProfileMockData.defaultGridOn;
  late bool _levelOn = ProfileMockData.defaultLevelOn;
  late bool _shutterOn = ProfileMockData.defaultShutterOn;

  int _tapCount = 0;
  Timer? _tapTimer;

  @override
  void initState() {
    super.initState();
    // 从 DB 异步加载水印设置到 provider。
    // 使用 microtask 避免在 build 阶段同步触发 provider 写入引发重建断言。
    Future.microtask(() =>
        loadWatermarkSettings(ProviderScope.containerOf(context, listen: false)));
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    super.dispose();
  }

  void _handleVersionTap() {
    _tapCount++;
    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(seconds: 3), () => _tapCount = 0);
    if (_tapCount >= 7) {
      _tapCount = 0;
      // 彩蛋：跳转正规兑换页
      GoRouter.of(context).push(RouteNames.profileRedeem);
    }
  }

  Widget _buildHomeWordmarkSection(ThemeTokens tokens) {
    final currentStyle = ref.watch(homeWordmarkStyleProvider);
    final options = <MapEntry<HomeWordmarkStyle, String>>[
      const MapEntry(HomeWordmarkStyle.logoEnglish, 'Logo + 英文'),
      const MapEntry(HomeWordmarkStyle.logoEnglishChinese, 'Logo + 英文 + 中文'),
      const MapEntry(HomeWordmarkStyle.englishChinese, '英文 + 中文'),
    ];

    return Column(
      children: options.map((option) {
        final style = option.key;
        final label = option.value;
        final selected = style == currentStyle;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () {
              ref.read(homeWordmarkStyleProvider.notifier).state = style;
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: selected ? tokens.brandSubtle.withOpacity(0.30) : tokens.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? tokens.brand : tokens.divider,
                  width: selected ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 180,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: HomeBrandTitle(preview: true, styleOverride: style),
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: selected ? tokens.brand : tokens.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    selected ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 18,
                    color: selected ? tokens.brand : tokens.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final currentThemeKey = ref.watch(themeKeyProvider);
    final currentUiStyle = ref.watch(uiStyleProvider);
    // Forced fix: 主题/风格 value 动态显示当前选择
    final themeLabel = ProfileMockData.themes
        .firstWhere((t) => t.key == currentThemeKey)
        .label;
    final styleLabel = ProfileMockData.styles
        .firstWhere((s) => s.style == currentUiStyle)
        .label;
    // 水印设置（总开关 / 动画开关）+ 当前选中模板名称
    final watermarkSettings = ref.watch(watermarkSettingsProvider);
    final watermarkTemplate = ref.watch(currentWatermarkTemplateProvider);
    final currentTemplateName = watermarkTemplate?.name ?? '未选择';

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '设置',
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
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 24), // 24rpx/40rpx/48rpx → 12/20/24dp
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _GroupTitle(text: '通用', tokens: tokens),
                const SizedBox(height: 8),
                NeuCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    children: [
                      _SettingItem(
                        icon: Icons.palette_outlined,
                        label: '主题选择',
                        value: themeLabel,
                        onTap: () => GoRouter.of(context).push(RouteNames.profileSettingsTheme),
                        tokens: tokens,
                      ),
                      _SettingItem(
                        icon: Icons.style_outlined,
                        label: '风格选择',
                        value: styleLabel,
                        onTap: () => GoRouter.of(context).push(RouteNames.profileSettingsTheme),
                        tokens: tokens,
                      ),
                      _SettingItem(
                        icon: Icons.language_outlined,
                        label: '语言',
                        value: '简体中文',
                        tokens: tokens,
                      ),
                      _SettingItem(
                        icon: Icons.security_outlined,
                        label: '账号保护',
                        value: '二维码/邮箱',
                        onTap: () => GoRouter.of(context).push(RouteNames.accountProtection),
                        tokens: tokens,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _GroupTitle(text: '首页标题样式', tokens: tokens),
                const SizedBox(height: 8),
                _buildHomeWordmarkSection(tokens),
                const SizedBox(height: 20),
                _GroupTitle(text: '显示', tokens: tokens),
                const SizedBox(height: 8),
                NeuCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    children: [
                      _SettingItem(
                        icon: Icons.grid_on_outlined,
                        label: '网格显示',
                        trailing: LumiraSwitch(
                          value: _gridOn,
                          onChanged: (v) => setState(() => _gridOn = v),
                        ),
                        tokens: tokens,
                      ),
                      _SettingItem(
                        icon: Icons.straighten_outlined,
                        label: '水平仪',
                        trailing: LumiraSwitch(
                          value: _levelOn,
                          onChanged: (v) => setState(() => _levelOn = v),
                        ),
                        tokens: tokens,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _GroupTitle(text: '拍摄', tokens: tokens),
                const SizedBox(height: 8),
                NeuCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    children: [
                      _SettingItem(
                        icon: Icons.aspect_ratio_outlined,
                        label: '默认分辨率',
                        value: '4:3',
                        tokens: tokens,
                      ),
                      _SettingItem(
                        icon: Icons.branding_watermark_outlined,
                        label: '水印',
                        trailing: LumiraSwitch(
                          value: watermarkSettings.enabled,
                          onChanged: (v) {
                            final current = ref.read(watermarkSettingsProvider);
                            ref.read(watermarkSettingsProvider.notifier).state =
                                current.copyWith(enabled: v);
                            scheduleWatermarkPersist(
                                ProviderScope.containerOf(context, listen: false));
                          },
                        ),
                        tokens: tokens,
                      ),
                      _SettingItem(
                        icon: Icons.palette_outlined,
                        label: '水印样式',
                        value: currentTemplateName,
                        tokens: tokens,
                        onTap: () =>
                            GoRouter.of(context).push(RouteNames.profileSettingsWatermark),
                      ),
                      _SettingItem(
                        icon: Icons.animation_outlined,
                        label: '水印动画',
                        trailing: LumiraSwitch(
                          value: watermarkSettings.animationEnabled,
                          onChanged: (v) {
                            final current = ref.read(watermarkSettingsProvider);
                            ref.read(watermarkSettingsProvider.notifier).state =
                                current.copyWith(animationEnabled: v);
                            scheduleWatermarkPersist(
                                ProviderScope.containerOf(context, listen: false));
                          },
                        ),
                        tokens: tokens,
                      ),
                      _SettingItem(
                        icon: Icons.graphic_eq_outlined,
                        label: '快门声音',
                        trailing: LumiraSwitch(
                          value: _shutterOn,
                          onChanged: (v) => setState(() => _shutterOn = v),
                        ),
                        tokens: tokens,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _GroupTitle(text: '关于', tokens: tokens),
                const SizedBox(height: 8),
                NeuCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SettingItem(
                        icon: Icons.info_outline,
                        label: '版本号',
                        value: ProfileMockData.appVersion,
                        onTap: _handleVersionTap,
                        tokens: tokens,
                      ),
                      _SettingItem(
                        icon: Icons.cleaning_services_outlined,
                        label: '清除缓存',
                        value: '0.0 MB',
                        onTap: () => LumiraToast.show(
                          context,
                          '已清除缓存',
                          duration: const Duration(milliseconds: 1000),
                        ),
                        tokens: tokens,
                      ),
                      _SettingItem(
                        icon: Icons.feedback_outlined,
                        label: '意见反馈',
                        onTap: () => GoRouter.of(context).push(RouteNames.feedback),
                        tokens: tokens,
                      ),
                      _SettingItem(
                        icon: Icons.info_outline,
                        label: '关于如画',
                        onTap: () => GoRouter.of(context).push(RouteNames.profileAbout),
                        tokens: tokens,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _GroupTitle(text: '合规与法律', tokens: tokens),
                const SizedBox(height: 8),
                NeuCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SettingItem(
                        icon: Icons.description_outlined,
                        label: '用户协议',
                        onTap: () => GoRouter.of(context).push(RouteNames.profileComplianceAgreement),
                        tokens: tokens,
                      ),
                      _SettingItem(
                        icon: Icons.privacy_tip_outlined,
                        label: '隐私政策',
                        onTap: () => GoRouter.of(context).push(RouteNames.profileCompliancePrivacy),
                        tokens: tokens,
                      ),
                      _SettingItem(
                        icon: Icons.list_alt_outlined,
                        label: '个人信息清单与第三方SDK目录',
                        onTap: () => GoRouter.of(context).push(RouteNames.profileComplianceSdk),
                        tokens: tokens,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _VersionFooter(tokens: tokens),
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

class _GroupTitle extends StatelessWidget {
  const _GroupTitle({required this.text, required this.tokens});
  final String text;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: tokens.textTertiary,
          letterSpacing: 0.04 * 13,
        ),
      ),
    );
  }
}

class _SettingItem extends StatelessWidget {
  const _SettingItem({
    required this.icon,
    required this.label,
    required this.tokens,
    this.value,
    this.trailing,
    this.onTap,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final ThemeTokens tokens;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: isLast
            ? null
            : BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: tokens.divider, width: 0.5),
                ),
              ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: tokens.brand),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: tokens.textPrimary,
                ),
              ),
            ),
            if (value != null) ...[
              Text(
                value!,
                style: TextStyle(
                  fontSize: 13,
                  color: tokens.textTertiary,
                ),
              ),
              const SizedBox(width: 4),
            ],
            if (trailing != null) trailing!,
            if (trailing == null && onTap != null)
              Icon(Icons.chevron_right, size: 18, color: tokens.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _VersionFooter extends StatelessWidget {
  const _VersionFooter({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text(
            ProfileMockData.appVersionSub,
            style: TextStyle(
              fontSize: 12,
              color: tokens.textTertiary,
              fontFamily: 'Courier New',
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ProfileMockData.appVersionDesc,
            style: TextStyle(
              fontSize: 11,
              color: tokens.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
