import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/lumira/buttons/lumira_button.dart';
import '../../../shared/widgets/lumira/form/lumira_text_field.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/builtin_profiles.dart';
import '../data/profile_models.dart';
import '../providers/profile_providers.dart';

/// 编辑资料页（头像选择 + 用户名）
///
/// 视觉规格来源：Task 6 brief，页面骨架沿用 profile 页的
/// GlassBackground(profile) + 径向渐变 + SafeArea + SingleChildScrollView。
/// 数据来源：profileDataProvider（本地资料），保存走 ProfileSyncService（离线优先）。
class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key});

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  final _usernameController = TextEditingController();
  String? _selectedSeed;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final profile = await ref.read(profileDataProvider.future);
    if (!mounted) return;
    setState(() {
      _usernameController.text = profile?.username ?? '';
      _selectedSeed = profile?.avatarSeed ?? BuiltinProfiles.avatarSeeds.first;
    });
  }

  void _randomUsername() {
    final current = _usernameController.text.trim();
    final pool = BuiltinProfiles.usernames.where((n) => n != current).toList();
    if (pool.isEmpty) return;
    setState(() => _usernameController.text = pool[Random().nextInt(pool.length)]);
  }

  bool get _dirty {
    final username = _usernameController.text.trim();
    return _selectedSeed != null && username.isNotEmpty;
  }

  Future<void> _save() async {
    if (!_dirty || _saving) return;
    setState(() => _saving = true);
    final username = _usernameController.text.trim();
    final profile = ProfileData(username: username, avatarSeed: _selectedSeed!);
    final sync = await ref.read(profileSyncServiceProvider.future);
    final result = await sync.save(profile);
    if (!mounted) return;
    ref.invalidate(profileDataProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.synced ? '已保存' : '已保存到本地，稍后自动同步')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final isFemale = appTheme.style == UIStyle.female;

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: const LumiraNav(title: '编辑资料'),
      body: Stack(
        children: [
          // glass 风格彩色斑点背景（沿用 profile 页变体）
          const Positioned.fill(
            child: GlassBackground(variant: GlassBackgroundVariant.profile),
          ),
          // 主内容层
          Container(
            // 径向渐变背景装饰（glass 风格可见性）
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
              top: false,
              bottom: false,
              child: SingleChildScrollView(
                // extendBodyBehindAppBar=true 时 body 从 y=0 开始，
                // 用 viewPadding.top + nav 内容高度 48dp 精确占位（与 profile 页一致）
                padding: EdgeInsets.fromLTRB(
                  24,
                  MediaQuery.of(context).viewPadding.top + 48,
                  24,
                  40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionTitle(text: '选择头像', tokens: tokens),
                    const SizedBox(height: 12),
                    // 头像 2 列 × 4 行网格
                    GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        mainAxisExtent: 104,
                      ),
                      children: [
                        for (final seed in BuiltinProfiles.avatarSeeds)
                          _AvatarCell(
                            seed: seed,
                            selected: seed == _selectedSeed,
                            isFemale: isFemale,
                            tokens: tokens,
                            onTap: () => setState(() => _selectedSeed = seed),
                          ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _SectionTitle(text: '用户名', tokens: tokens),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: LumiraTextField(
                            controller: _usernameController,
                            maxLength: 20,
                            hintText: '请输入用户名',
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        LumiraButton(
                          variant: ButtonVariant.secondary,
                          onPressed: _randomUsername,
                          child: const Text('随机换一个'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    LumiraButton(
                      variant: ButtonVariant.primary,
                      onPressed: (_dirty && !_saving) ? _save : null,
                      child: const Text('保存'),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 单个头像选择项：NeuCard 包裹圆形头像，
/// 选中态 = 品牌色圆形描边（female 1.2 / 其余 2）+ 右下角金色对勾角标
class _AvatarCell extends StatelessWidget {
  const _AvatarCell({
    required this.seed,
    required this.selected,
    required this.isFemale,
    required this.tokens,
    required this.onTap,
  });

  final String seed;
  final bool selected;
  final bool isFemale;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderWidth = isFemale ? 1.2 : 2.0;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: NeuCard(
        padding: const EdgeInsets.all(8),
        child: Center(
          child: Stack(
            children: [
              ClipOval(
                child: Image.network(
                  BuiltinProfiles.avatarUrl(seed),
                  width: 88, // 176rpx → 88dp
                  height: 88,
                  fit: BoxFit.cover,
                ),
              ),
              if (selected)
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: tokens.brand,
                      width: borderWidth,
                    ),
                  ),
                ),
              if (selected)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      // 硬编码颜色：与 HeroCard 角标一致 linear-gradient(135deg, #C9A96E, #A88550)
                      gradient: const LinearGradient(
                        colors: [Color(0xFFC9A96E), Color(0xFFA88550)],
                      ),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 小节标题（沿用设置页 _GroupTitle 的视觉风格）
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text, required this.tokens});

  final String text;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: tokens.textTertiary,
        letterSpacing: 0.04 * 13,
      ),
    );
  }
}
