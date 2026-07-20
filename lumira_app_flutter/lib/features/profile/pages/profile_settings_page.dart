import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/profile_mock_data.dart';

/// 设置页
///
/// 视觉规格来源：lumira-app/src/pages/profile/settings.vue（323 行）
/// 4 个分组：通用 / 显示 / 拍摄 / 关于
///
/// 关键交互：
/// - 主题选择 / 风格选择点击 → 跳 profileSettingsTheme
/// - 4 个 toggle 开关（网格 / 水平仪 / 快门声 / 水印）
/// - 版本号 7 连击 → 显示兑换码输入框（3 秒重置）
/// - 兑换码确认 → SnackBar 反馈
class ProfileSettingsPage extends ConsumerStatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  ConsumerState<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends ConsumerState<ProfileSettingsPage> {
  late bool _gridOn = ProfileMockData.defaultGridOn;
  late bool _levelOn = ProfileMockData.defaultLevelOn;
  late bool _shutterOn = ProfileMockData.defaultShutterOn;
  late bool _watermarkOn = ProfileMockData.defaultWatermarkOn;

  int _tapCount = 0;
  Timer? _tapTimer;
  bool _showRedemption = false;
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _tapTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _handleVersionTap() {
    _tapCount++;
    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(seconds: 3), () => _tapCount = 0);
    if (_tapCount >= 7) {
      setState(() {
        _showRedemption = true;
        _tapCount = 0;
      });
    }
  }

  void _confirmRedemption() {
    final code = _codeController.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (code.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('请输入兑换码'), duration: Duration(milliseconds: 1000)),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text('兑换码「$code」已提交'), duration: const Duration(milliseconds: 1000)),
    );
    _codeController.clear();
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
                        isLast: true,
                      ),
                    ],
                  ),
                ),
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
                        trailing: Switch(
                          value: _gridOn,
                          onChanged: (v) => setState(() => _gridOn = v),
                          activeColor: tokens.brand,
                        ),
                        tokens: tokens,
                      ),
                      _SettingItem(
                        icon: Icons.straighten_outlined,
                        label: '水平仪',
                        trailing: Switch(
                          value: _levelOn,
                          onChanged: (v) => setState(() => _levelOn = v),
                          activeColor: tokens.brand,
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
                        trailing: Switch(
                          value: _watermarkOn,
                          onChanged: (v) => setState(() => _watermarkOn = v),
                          activeColor: tokens.brand,
                        ),
                        tokens: tokens,
                      ),
                      _SettingItem(
                        icon: Icons.graphic_eq_outlined,
                        label: '快门声音',
                        trailing: Switch(
                          value: _shutterOn,
                          onChanged: (v) => setState(() => _shutterOn = v),
                          activeColor: tokens.brand,
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
                      if (_showRedemption) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _codeController,
                                  decoration: InputDecoration(
                                    hintText: '请输入兑换码',
                                    hintStyle: TextStyle(color: tokens.textTertiary, fontSize: 14),
                                    filled: true,
                                    fillColor: tokens.canvas,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: tokens.divider, width: 1),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: tokens.divider, width: 1),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: tokens.brand, width: 1.5),
                                    ),
                                  ),
                                  style: TextStyle(color: tokens.textPrimary, fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _confirmRedemption,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: tokens.brand,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '确认',
                                    style: TextStyle(
                                      color: tokens.textInverse,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      _SettingItem(
                        icon: Icons.cleaning_services_outlined,
                        label: '清除缓存',
                        value: '0.0 MB',
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('已清除缓存'),
                            duration: Duration(milliseconds: 1000),
                          ),
                        ),
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
