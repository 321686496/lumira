import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/capture_preview_mock_data.dart';

/// 照片预览页（Task 2.9A）
///
/// 视觉规格来源：lumira-app/src/pages/capture/preview.vue (399 行)
/// - 深色背景 + LumiraNav transparent
/// - 照片预览（3:4）
/// - 底部白色 Sheet：心情标签 + 场景标签 + 操作按钮 + 保存按钮
///
/// 已知简化决策（brief §8）：
/// - photoUrl 路由参数：mock 阶段为 picsum URL，真实接入 Task 2.3 CaptureState
/// - 保存到相册：mock SnackBar + pop，不接入 saver_gallery
/// - 生成对比图 / EXIF 卡片：mock SnackBar，不接入图像生成
class CapturePreviewPage extends ConsumerStatefulWidget {
  const CapturePreviewPage({super.key, this.photoUrl});

  /// 路由参数：photoUrl（拍摄后的照片 URL）
  final String? photoUrl;

  @override
  ConsumerState<CapturePreviewPage> createState() =>
      _CapturePreviewPageState();
}

class _CapturePreviewPageState extends ConsumerState<CapturePreviewPage> {
  late String _photoUrl;
  late List<MoodOption> _moods;
  String? _selectedSceneId;

  @override
  void initState() {
    super.initState();
    _photoUrl =
        widget.photoUrl ?? CapturePreviewMockData.lastCapturedPhotoUrl;
    _moods = CapturePreviewMockData.moods
        .map((m) => m.copyWith(active: m.active))
        .toList();
  }

  // ===== 事件处理 =====

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.of(context).go(RouteNames.capture);
    }
  }

  void _onCompare() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('查看对比')),
    );
  }

  void _onSkip() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已跳过')),
    );
  }

  void _onCompareCard() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('生成对比图中')),
    );
  }

  void _onExifCard() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('生成 EXIF 卡片中')),
    );
  }

  void _selectMood(MoodOption selected) {
    setState(() {
      for (var i = 0; i < _moods.length; i++) {
        _moods[i] = _moods[i].copyWith(active: _moods[i].name == selected.name);
      }
    });
  }

  void _selectScene(String? id) {
    setState(() {
      _selectedSceneId = id;
    });
  }

  void _onSave() {
    if (_photoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无照片数据')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已保存')),
    );
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        GoRouter.of(context).go(RouteNames.gallery);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);

    return Scaffold(
      // 硬编码颜色，与 uni-app 一致 (preview-container bg #1C1A17)
      backgroundColor: const Color(0xFF1C1A17),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          _BackgroundDecoration(tokens: tokens),
          SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: [
                _PreviewNav(
                  tokens: tokens,
                  onBack: _back,
                  onCompare: _onCompare,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PhotoFrame(
                          tokens: tokens,
                          photoUrl: _photoUrl,
                        ),
                        _BottomSheet(
                          tokens: tokens,
                          moods: _moods,
                          selectedSceneId: _selectedSceneId,
                          onSelectMood: _selectMood,
                          onSelectScene: _selectScene,
                          onSkip: _onSkip,
                          onCompareCard: _onCompareCard,
                          onExifCard: _onExifCard,
                          onSave: _onSave,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 背景径向渐变装饰（glass 风格 backdrop-filter 可见性）
/// 与 templates_unlock_page._BackgroundDecoration 一致
class _BackgroundDecoration extends StatelessWidget {
  const _BackgroundDecoration({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.6, -0.8),
              radius: 1.4,
              colors: [
                tokens.brandSubtle.withOpacity(0.45),
                // 硬编码颜色，与 uni-app 一致 (preview-container bg #1C1A17)
                const Color(0xFF1C1A17).withOpacity(0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 顶部导航（LumiraNav transparent: true + 自定义返回按钮 + 对比链接）
class _PreviewNav extends StatelessWidget {
  const _PreviewNav({
    required this.tokens,
    required this.onBack,
    required this.onCompare,
  });

  final ThemeTokens tokens;
  final VoidCallback onBack;
  final VoidCallback onCompare;

  @override
  Widget build(BuildContext context) {
    return Container(
      // 硬编码颜色，与 uni-app 一致 (preview-nav bg rgba(28,26,23,0.9))
      color: const Color.fromRGBO(28, 26, 23, 0.9),
      child: LumiraNav(
        title: '照片预览',
        transparent: true,
        leading: _NavBackButton(onTap: onBack),
        actions: [
          _CompareLink(onTap: onCompare),
        ],
      ),
    );
  }
}

class _NavBackButton extends StatelessWidget {
  const _NavBackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(
          Icons.arrow_back_ios_new,
          size: 20,
          // 硬编码颜色，与 uni-app 一致 (nav-back-icon color #ffffff)
          color: Colors.white,
        ),
      ),
    );
  }
}

class _CompareLink extends StatelessWidget {
  const _CompareLink({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              '对比 ›',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                // 硬编码颜色，与 uni-app 一致 (nav-compare color #C9A96E)
                color: Color(0xFFC9A96E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 照片预览框（3:4 AspectRatio + Image.network + 空态 placeholder）
class _PhotoFrame extends StatelessWidget {
  const _PhotoFrame({
    required this.tokens,
    required this.photoUrl,
  });

  final ThemeTokens tokens;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (photoUrl.isNotEmpty)
                Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _PhotoEmptyState(tokens: tokens),
                )
              else
                _PhotoEmptyState(tokens: tokens),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoEmptyState extends StatelessWidget {
  const _PhotoEmptyState({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      // 硬编码颜色，与 uni-app 一致 (photo-empty bg rgba(255,255,255,0.04))
      color: const Color.fromRGBO(255, 255, 255, 0.04),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.image_outlined,
            size: 40,
            // 硬编码颜色，与 uni-app 一致 (photo-empty-icon color rgba(255,255,255,0.3))
            color: Color.fromRGBO(255, 255, 255, 0.3),
          ),
          SizedBox(height: 8),
          Text(
            '无照片数据',
            style: TextStyle(
              fontSize: 13,
              // 硬编码颜色，与 uni-app 一致 (photo-empty-text color rgba(255,255,255,0.4))
              color: Color.fromRGBO(255, 255, 255, 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// 底部白色 Sheet
class _BottomSheet extends StatelessWidget {
  const _BottomSheet({
    required this.tokens,
    required this.moods,
    required this.selectedSceneId,
    required this.onSelectMood,
    required this.onSelectScene,
    required this.onSkip,
    required this.onCompareCard,
    required this.onExifCard,
    required this.onSave,
  });

  final ThemeTokens tokens;
  final List<MoodOption> moods;
  final String? selectedSceneId;
  final ValueChanged<MoodOption> onSelectMood;
  final ValueChanged<String?> onSelectScene;
  final VoidCallback onSkip;
  final VoidCallback onCompareCard;
  final VoidCallback onExifCard;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      // 硬编码颜色，与 uni-app 一致 (bottom-sheet bg #FFFFFF)
      // 注：brief §3.1 列出的硬编码颜色不包含 bottom-sheet bg，但 uni-app 源码硬编码为 #FFFFFF。
      // 此处遵循 uni-app 视觉规格，使用 Colors.white。
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetHandle(tokens: tokens),
          const SizedBox(height: 16),
          _MoodSection(
            tokens: tokens,
            moods: moods,
            onSelectMood: onSelectMood,
            onSkip: onSkip,
          ),
          const SizedBox(height: 24),
          _SceneSection(
            tokens: tokens,
            selectedSceneId: selectedSceneId,
            onSelectScene: onSelectScene,
          ),
          const SizedBox(height: 24),
          _ActionRow(
            tokens: tokens,
            onCompareCard: onCompareCard,
            onExifCard: onExifCard,
          ),
          const SizedBox(height: 16),
          _SaveButton(onTap: onSave),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          // 硬编码颜色，与 uni-app 一致 (sheet-handle bg #E5E0D8)
          color: const Color(0xFFE5E0D8),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _MoodSection extends StatelessWidget {
  const _MoodSection({
    required this.tokens,
    required this.moods,
    required this.onSelectMood,
    required this.onSkip,
  });

  final ThemeTokens tokens;
  final List<MoodOption> moods;
  final ValueChanged<MoodOption> onSelectMood;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitleRow(
          title: '今天的心情是？',
          linkText: '跳过',
          onLinkTap: onSkip,
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < moods.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _Pill(
                  icon: moods[i].icon,
                  text: moods[i].name,
                  active: moods[i].active,
                  onTap: () => onSelectMood(moods[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SceneSection extends StatelessWidget {
  const _SceneSection({
    required this.tokens,
    required this.selectedSceneId,
    required this.onSelectScene,
  });

  final ThemeTokens tokens;
  final String? selectedSceneId;
  final ValueChanged<String?> onSelectScene;

  @override
  Widget build(BuildContext context) {
    const scenes = CapturePreviewMockData.sceneOptions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle(title: '拍摄场景'),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < scenes.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _Pill(
                  icon: scenes[i].icon,
                  text: scenes[i].name,
                  active: selectedSceneId == scenes[i].id,
                  onTap: () => onSelectScene(scenes[i].id),
                ),
              ],
              const SizedBox(width: 8),
              _Pill(
                text: '不标记',
                active: selectedSceneId == null,
                onTap: () => onSelectScene(null),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitleRow extends StatelessWidget {
  const _SectionTitleRow({
    required this.title,
    required this.linkText,
    required this.onLinkTap,
  });

  final String title;
  final String linkText;
  final VoidCallback onLinkTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: _SectionTitle(title: title),
        ),
        GestureDetector(
          onTap: onLinkTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              linkText,
              style: const TextStyle(
                fontSize: 13,
                // 硬编码颜色，与 uni-app 一致 (section-link color $color-text-tertiary — 白色 sheet 上用深灰)
                color: Color(0xFF999999),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: 'Noto Serif SC',
        fontSize: 15,
        fontWeight: FontWeight.w600,
        // 硬编码颜色，与 uni-app 一致 (section-title color $color-text-primary — 白色 sheet 上用深色)
        color: Color(0xFF1A1A1A),
      ),
    );
  }
}

/// 心情/场景 pill
class _Pill extends StatelessWidget {
  const _Pill({
    this.icon,
    required this.text,
    required this.active,
    required this.onTap,
  });

  final IconData? icon;
  final String text;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          // 硬编码颜色，与 uni-app 一致 (pill.active linear-gradient(135deg, #C9A96E 0%, #A88550 100%))
          gradient: active
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFC9A96E), Color(0xFFA88550)],
                )
              : null,
          // 硬编码颜色，与 uni-app 一致 (pill border $color-border — 白色 sheet 上用浅灰)
          border: active
              ? Border.all(color: Colors.transparent, width: 1.5)
              : Border.all(color: const Color(0xFFE5E0D8), width: 1.5),
          // 硬编码颜色，与 uni-app 一致 (pill bg $color-bg-card — 白色 sheet 上用浅米色)
          color: active ? null : const Color(0xFFFAF7F2),
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                // 硬编码颜色，与 uni-app 一致 (pill active icon #ffffff / inactive $color-text-secondary)
                color: active ? Colors.white : const Color(0xFF666666),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                // 硬编码颜色，与 uni-app 一致 (pill.active color #ffffff / inactive $color-text-secondary)
                color: active ? Colors.white : const Color(0xFF666666),
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 操作按钮行（生成对比图 / 生成 EXIF 卡片）
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.tokens,
    required this.onCompareCard,
    required this.onExifCard,
  });

  final ThemeTokens tokens;
  final VoidCallback onCompareCard;
  final VoidCallback onExifCard;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.bar_chart_outlined,
            text: '生成对比图',
            onTap: onCompareCard,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            icon: Icons.content_paste_outlined,
            text: '生成 EXIF 卡片',
            onTap: onExifCard,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          // 硬编码颜色，与 uni-app 一致 (action-btn border $color-border)
          border: Border.all(color: const Color(0xFFE5E0D8), width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              // 硬编码颜色，与 uni-app 一致 (action-icon color $color-text-secondary)
              color: const Color(0xFF666666),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  // 硬编码颜色，与 uni-app 一致 (action-text color $color-text-primary)
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 保存到相册主按钮
class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          // 硬编码颜色，与 uni-app 一致 (save-btn bg #1A1A1A)
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.save_outlined,
              size: 16,
              // 硬编码颜色，与 uni-app 一致 (save-icon color #FAF7F2)
              color: Color(0xFFFAF7F2),
            ),
            SizedBox(width: 8),
            Text(
              '保存到相册',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                // 硬编码颜色，与 uni-app 一致 (save-text color #FAF7F2)
                color: Color(0xFFFAF7F2),
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
