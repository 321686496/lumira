import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/file_picker_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
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
    final base = _base;
    final username = _usernameController.text.trim();
    final seedChanged = _selectedSeed != null && _selectedSeed != base?.avatarSeed;
    final userChanged = username.isNotEmpty && username != (base?.username ?? '');
    final genderChanged = _selectedGender != base?.gender;
    final skillChanged = _selectedSkillLevel != base?.skillLevel;
    final freqChanged = _selectedShootFrequency != base?.shootFrequency;
    final favChanged = !_listEq(_favoriteCategories.toList(), base?.favoriteCategories ?? const []);
    final painChanged = !_listEq(_painPoints.toList(), base?.painPoints ?? const []);
    final expChanged = !_listEq(_expectations.toList(), base?.expectations ?? const []);
    final sceneChanged = !_listEq(_commonScenes.toList(), base?.commonScenes ?? const []);
    final avatarChanged = (_avatarUrl ?? '') != (base?.avatarUrl ?? '');
    return username.isNotEmpty &&
        _selectedSeed != null &&
        (seedChanged ||
            userChanged ||
            genderChanged ||
            skillChanged ||
            freqChanged ||
            favChanged ||
            painChanged ||
            expChanged ||
            sceneChanged ||
            avatarChanged);
  }

  /// 集合语义比较两个 List<String>（忽略顺序），供 _dirty 判断偏好是否变化。
  bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final sa = [...a]..sort();
    final sb = [...b]..sort();
    for (var i = 0; i < sa.length; i++) {
      if (sa[i] != sb[i]) return false;
    }
    return true;
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

  /// 选择 + 上传自定义头像；返回新 URL，失败/取消返回 null
  Future<String?> _pickAndUpload() async {
    final picked = await FilePickerService.pickSingleImage();
    if (picked == null) return null; // 用户取消
    final full = await FilePickerService.ensureFullBytes(picked);
    final bytes = full.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('图片读取失败')));
      }
      return null;
    }
    setState(() => _uploadingAvatar = true);
    try {
      final sync = await ref.read(profileSyncServiceProvider.future);
      return await sync.uploadAvatar(
        Uint8List.fromList(bytes),
        full.name.isNotEmpty ? full.name : 'avatar.txt.png',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('上传失败：$e')));
      }
      return null;
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  /// 弹出头像选择器（底部弹层）：本地选择，点「确认」才写回页面状态
  Future<void> _showAvatarSheet() async {
    var sheetSeed = _selectedSeed ?? BuiltinProfiles.avatarSeeds.first;
    var sheetAvatarUrl = _avatarUrl;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final tokens = ref.watch(themeTokensProvider);
        final isFemale = ref.watch(appThemeProvider).style == UIStyle.female;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final customActive = sheetAvatarUrl != null && sheetAvatarUrl!.isNotEmpty;
            // 自定义头像置顶展示，其后为内置头像
            final seeds = <String?>[
              if (customActive) '_custom',
              ...BuiltinProfiles.avatarSeeds,
            ];
            return SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(isFemale ? 28 : 20),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          '选择头像',
                          style: TextStyle(
                            fontFamily: 'Noto Serif SC',
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.close, color: tokens.textTertiary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final s in seeds)
                          _AvatarTile(
                            seed: s,
                            url: s == '_custom'
                                ? sheetAvatarUrl!
                                : BuiltinProfiles.avatarUrl(s!),
                            selected: s == '_custom'
                                ? customActive
                                : (!customActive && s == sheetSeed),
                            isFemale: isFemale,
                            tokens: tokens,
                            onTap: () {
                              if (s != '_custom') {
                                sheetSeed = s!;
                                sheetAvatarUrl = null;
                              }
                              setSheetState(() {});
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    LumiraButton(
                      variant: ButtonVariant.secondary,
                      onPressed: _uploadingAvatar
                          ? null
                          : () async {
                              setSheetState(() {});
                              final url = await _pickAndUpload();
                              if (url != null) {
                                sheetAvatarUrl = url;
                                sheetSeed = BuiltinProfiles.avatarSeeds.first;
                              }
                              if (ctx.mounted) setSheetState(() {});
                            },
                      child: Text(_uploadingAvatar ? '上传中…' : '上传自定义头像'),
                    ),
                    if (customActive) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            sheetAvatarUrl = null;
                            setSheetState(() {});
                          },
                          child: const Text('恢复内置头像'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    LumiraButton(
                      variant: ButtonVariant.primary,
                      onPressed: () {
                        setState(() {
                          _selectedSeed = sheetSeed;
                          _avatarUrl = sheetAvatarUrl;
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('确认'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
                    _SectionTitle(text: '基本信息', tokens: tokens),
                    const SizedBox(height: 12),
                    _BasicInfoHeader(
                      seed: _selectedSeed,
                      avatarUrl: _avatarUrl,
                      isFemale: isFemale,
                      tokens: tokens,
                      onAvatarTap: _showAvatarSheet,
                      controller: _usernameController,
                      random: _randomUsername,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 28),
                    _SectionTitle(text: '摄影偏好', tokens: tokens),
                    const SizedBox(height: 12),
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

/// 头像选择器里的单个头像：无套娃卡片，选中态 = 品牌色描边环 + 金色对勾角标
class _AvatarTile extends StatelessWidget {
  const _AvatarTile({
    required this.seed,
    required this.url,
    required this.selected,
    required this.isFemale,
    required this.tokens,
    required this.onTap,
  });

  final String? seed; // '_custom' 表示自定义头像，否则为内置 seed
  final String url;
  final bool selected;
  final bool isFemale;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCustom = seed == '_custom';
    final borderWidth = isFemale ? 1.2 : 2.0;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipOval(
              child: Image.network(url, width: 64, height: 64, fit: BoxFit.cover),
            ),
            if (selected)
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: tokens.brand, width: borderWidth),
                ),
              ),
            if (selected)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // 硬编码颜色：金色对勾角标
                    gradient: const LinearGradient(
                      colors: [Color(0xFFC9A96E), Color(0xFFA88550)],
                    ),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.check, size: 13, color: Colors.white),
                ),
              ),
            if (isCustom)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black54,
                  ),
                  child: const Icon(
                    Icons.photo_camera_outlined,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 编辑资料页顶部基本信息区：左侧头像（点击弹出选择器）+ 右侧用户名输入
class _BasicInfoHeader extends StatelessWidget {
  const _BasicInfoHeader({
    required this.seed,
    required this.avatarUrl,
    required this.isFemale,
    required this.tokens,
    required this.onAvatarTap,
    required this.controller,
    required this.random,
    required this.onChanged,
  });

  final String? seed;
  final String? avatarUrl;
  final bool isFemale;
  final ThemeTokens tokens;
  final VoidCallback onAvatarTap;
  final TextEditingController controller;
  final VoidCallback random;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final customActive = avatarUrl != null && avatarUrl!.isNotEmpty;
    final url = customActive
        ? BuiltinProfiles.avatarUrl('_custom', customUrl: avatarUrl)
        : BuiltinProfiles.avatarUrl(seed ?? BuiltinProfiles.avatarSeeds.first);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onAvatarTap,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipOval(
                child: Image.network(url, width: 72, height: 72, fit: BoxFit.cover),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // 硬编码颜色：金色编辑角标（与选择器内风格一致）
                    gradient: const LinearGradient(
                      colors: [Color(0xFFC9A96E), Color(0xFFA88550)],
                    ),
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: const Icon(Icons.edit, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '用户名',
                style: TextStyle(
                  fontSize: 13,
                  color: tokens.textTertiary,
                  letterSpacing: 0.04 * 13,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: LumiraTextField(
                      controller: controller,
                      maxLength: 20,
                      hintText: '请输入用户名',
                      onChanged: onChanged,
                    ),
                  ),
                  const SizedBox(width: 12),
                  LumiraButton(
                    variant: ButtonVariant.secondary,
                    onPressed: random,
                    child: const Text('随机换一个'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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
