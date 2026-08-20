import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/file_picker_service.dart';
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
import '../services/profile_sync_service.dart';
import '../widgets/pref_selector.dart';

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

  // Task6 新增：原始资料（copyWith 基础）+ 各偏好选择值
  ProfileData? _base;
  String? _selectedGender;
  final Set<String> _favoriteCategories = {};
  final Set<String> _painPoints = {};
  String? _selectedSkillLevel;
  final Set<String> _expectations = {};
  final Set<String> _commonScenes = {};
  String? _selectedShootFrequency;
  String? _avatarUrl; // 自定义头像 URL（null/空 表示用内置 seed）
  bool _uploadingAvatar = false;

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
      _base = profile;
      _usernameController.text = profile?.username ?? '';
      _selectedSeed = profile?.avatarSeed ?? BuiltinProfiles.avatarSeeds.first;
      _selectedGender = profile?.gender;
      _favoriteCategories
        ..clear()
        ..addAll(profile?.favoriteCategories ?? const []);
      _painPoints
        ..clear()
        ..addAll(profile?.painPoints ?? const []);
      _selectedSkillLevel = profile?.skillLevel;
      _expectations
        ..clear()
        ..addAll(profile?.expectations ?? const []);
      _commonScenes
        ..clear()
        ..addAll(profile?.commonScenes ?? const []);
      _selectedShootFrequency = profile?.shootFrequency;
      _avatarUrl = profile?.avatarUrl;
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
    try {
      final result = await _persist();
      if (!mounted) return;
      ref.invalidate(profileDataProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.synced ? '已保存' : '已保存到本地，稍后自动同步')),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 组装 ProfileData 并调用 sync.save（离线优先，不抛异常）
  Future<ProfileSaveResult> _persist() async {
    final base = _base;
    final username = _usernameController.text.trim();
    final updated = (base ?? ProfileData(username: username, avatarSeed: 'lumira-avatar-01')).copyWith(
      username: username,
      avatarSeed: _selectedSeed,
      gender: _selectedGender,
      favoriteCategories: _favoriteCategories.toList(),
      painPoints: _painPoints.toList(),
      skillLevel: _selectedSkillLevel,
      expectations: _expectations.toList(),
      commonScenes: _commonScenes.toList(),
      shootFrequency: _selectedShootFrequency,
      avatarUrl: _avatarUrl == null || _avatarUrl!.isEmpty ? null : _avatarUrl,
    );
    final sync = await ref.read(profileSyncServiceProvider.future);
    return sync.save(updated);
  }

  /// 选图 + 上传自定义头像；成功后立即持久化，便于用户直接离开页面
  Future<void> _pickAndUploadAvatar() async {
    if (_uploadingAvatar) return;
    final picked = await FilePickerService.pickSingleImage();
    if (picked == null) return; // 用户取消
    final full = await FilePickerService.ensureFullBytes(picked);
    final bytes = full.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('图片读取失败')));
      }
      return;
    }
    setState(() => _uploadingAvatar = true);
    try {
      final sync = await ref.read(profileSyncServiceProvider.future);
      final url = await sync.uploadAvatar(
        Uint8List.fromList(bytes),
        full.name.isNotEmpty ? full.name : 'avatar.txt.png',
      );
      if (!mounted) return;
      setState(() => _avatarUrl = url);
      await _persist();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('上传失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  void _restoreBuiltinAvatar() {
    setState(() => _avatarUrl = null);
  }

  /// 自定义头像上传/恢复区：左侧当前头像预览，右侧上传与恢复按钮
  Widget _buildAvatarUpload(ThemeTokens tokens) {
    final customActive = _avatarUrl != null && _avatarUrl!.isNotEmpty;
    final imgUrl = customActive
        ? BuiltinProfiles.avatarUrl('_custom', customUrl: _avatarUrl)
        : BuiltinProfiles.avatarUrl(
            _selectedSeed ?? BuiltinProfiles.avatarSeeds.first);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipOval(
          child: Image.network(
            imgUrl,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LumiraButton(
                variant: ButtonVariant.secondary,
                onPressed: _uploadingAvatar ? null : _pickAndUploadAvatar,
                child: Text(_uploadingAvatar ? '上传中…' : '上传自定义头像'),
              ),
              if (customActive) ...[
                const SizedBox(height: 8),
                LumiraButton(
                  variant: ButtonVariant.ghost,
                  onPressed: _uploadingAvatar ? null : _restoreBuiltinAvatar,
                  child: const Text('恢复内置头像'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
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
                    const SizedBox(height: 20),
                    _buildAvatarUpload(tokens),
                    const SizedBox(height: 28),
                    PrefSingleSelector(
                      title: '性别',
                      options: PrefOptions.gender,
                      value: _selectedGender,
                      onChanged: (v) => setState(() => _selectedGender = v),
                      tokens: tokens,
                    ),
                    const SizedBox(height: 28),
                    PrefMultiSelector(
                      title: '喜欢拍什么',
                      options: PrefOptions.favoriteCategories,
                      selected: _favoriteCategories,
                      onToggle: (v) => setState(() {
                            _favoriteCategories.contains(v)
                                ? _favoriteCategories.remove(v)
                                : _favoriteCategories.add(v);
                          }),
                      tokens: tokens,
                    ),
                    const SizedBox(height: 28),
                    PrefMultiSelector(
                      title: '拍摄烦恼',
                      options: PrefOptions.painPoints,
                      selected: _painPoints,
                      onToggle: (v) => setState(() {
                            _painPoints.contains(v)
                                ? _painPoints.remove(v)
                                : _painPoints.add(v);
                          }),
                      tokens: tokens,
                    ),
                    const SizedBox(height: 28),
                    PrefMultiSelector(
                      title: '拍摄期望',
                      options: PrefOptions.expectations,
                      selected: _expectations,
                      onToggle: (v) => setState(() {
                            _expectations.contains(v)
                                ? _expectations.remove(v)
                                : _expectations.add(v);
                          }),
                      tokens: tokens,
                    ),
                    const SizedBox(height: 28),
                    PrefMultiSelector(
                      title: '常用场景',
                      options: PrefOptions.commonScenes,
                      selected: _commonScenes,
                      onToggle: (v) => setState(() {
                            _commonScenes.contains(v)
                                ? _commonScenes.remove(v)
                                : _commonScenes.add(v);
                          }),
                      tokens: tokens,
                    ),
                    const SizedBox(height: 28),
                    PrefSingleSelector(
                      title: '摄影水平',
                      options: PrefOptions.skillLevel,
                      value: _selectedSkillLevel,
                      onChanged: (v) => setState(() => _selectedSkillLevel = v),
                      tokens: tokens,
                    ),
                    const SizedBox(height: 28),
                    PrefSingleSelector(
                      title: '拍摄频率',
                      options: PrefOptions.shootFrequency,
                      value: _selectedShootFrequency,
                      onChanged: (v) => setState(() => _selectedShootFrequency = v),
                      tokens: tokens,
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
