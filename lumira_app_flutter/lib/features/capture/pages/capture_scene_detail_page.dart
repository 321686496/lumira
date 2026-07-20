import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/capture_scene_mock_data.dart';
import '../widgets/scene_achievement_card.dart';
import '../widgets/scene_filter_badge.dart';

/// 场景详情页（Task 2.10）
///
/// 视觉规格来源：lumira-app/src/pages/capture/scene-detail.vue (217 行)
/// - 顶部导航：返回 + 标题（场景名）+ 收藏按钮
/// - 示例图轮播
/// - 标题区（图标 + 场景名 + vibe）
/// - 氛围卡片（描述 + 出片地点 + 最佳时间）
/// - 标签列表（自定义场景可编辑）
/// - 推荐滤镜徽章
/// - 拍摄小贴士
/// - 我的成就（照片数 + 等级 + 进度条 + 周排行）
/// - 底部双按钮：用此场景拍照 / 加入组合
///
/// 简化决策（brief §8）：
/// - TagSelector（uni-app 组件未迁移）：自定义场景下用内嵌 chip + 弹出选择 sheet 代替
/// - 收藏 / 加入组合 / 用此场景拍照：mock SnackBar，不接入实际持久化
class CaptureSceneDetailPage extends ConsumerStatefulWidget {
  const CaptureSceneDetailPage({super.key, this.sceneId});

  /// 路由参数：sceneId（场景 ID）
  final String? sceneId;

  @override
  ConsumerState<CaptureSceneDetailPage> createState() =>
      _CaptureSceneDetailPageState();
}

class _CaptureSceneDetailPageState
    extends ConsumerState<CaptureSceneDetailPage> {
  ScenePreset? _scene;
  bool _isFav = false;
  List<String> _editableTagIds = [];
  bool _tagSheetVisible = false;

  @override
  void initState() {
    super.initState();
    _loadScene();
  }

  void _loadScene() {
    final s = CaptureSceneMockData.getSceneById(widget.sceneId);
    _scene = s;
    _isFav = s != null ? CaptureSceneMockData.isFavorite(s.id) : false;
    if (s != null && s.isCustom) {
      _editableTagIds = List<String>.from(
          (s as CustomScenePreset).tagIds);
    }
  }

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.of(context).go(RouteNames.capture);
    }
  }

  void _toggleFav() {
    if (_scene == null) return;
    setState(() {
      _isFav = !_isFav;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isFav ? '已收藏场景' : '已取消收藏')),
    );
  }

  void _goCapture() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('用此场景拍照：${_scene?.name ?? ''}')),
    );
  }

  void _goCreateKit() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('加入组合：${_scene?.name ?? ''}')),
    );
  }

  void _openTagSheet() {
    setState(() {
      _tagSheetVisible = !_tagSheetVisible;
    });
  }

  void _toggleTag(String tagId) {
    setState(() {
      if (_editableTagIds.contains(tagId)) {
        _editableTagIds.remove(tagId);
      } else {
        _editableTagIds.add(tagId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final scene = _scene;

    return Scaffold(
      // 硬编码颜色，与 uni-app 一致 (scene-detail-page bg #FAF7F2)
      backgroundColor: const Color(0xFFFAF7F2),
      body: SafeArea(
        child: Column(
          children: [
            _DetailNav(
              tokens: tokens,
              title: scene?.name ?? '场景详情',
              isFav: _isFav,
              onBack: _back,
              onToggleFav: _toggleFav,
            ),
            if (scene != null)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Swiper(scene: scene),
                      _Header(scene: scene),
                      _AtmosphereSection(scene: scene),
                      _TagsSection(
                        scene: scene,
                        editableTagIds: _editableTagIds,
                        tagSheetVisible: _tagSheetVisible,
                        onToggleTagSheet: _openTagSheet,
                        onToggleTag: _toggleTag,
                      ),
                      _FilterSection(scene: scene),
                      _TipsSection(scene: scene),
                      _AchievementSection(scene: scene),
                      const SizedBox(height: 80), // detail-bottom-space
                    ],
                  ),
                ),
              )
            else
              Expanded(child: _EmptyState(onBack: _back)),
          ],
        ),
      ),
      bottomNavigationBar:
          scene == null ? null : _BottomButtons(onCapture: _goCapture, onCreateKit: _goCreateKit),
    );
  }
}

/// 顶部导航（返回 + 标题 + 收藏）
class _DetailNav extends StatelessWidget {
  const _DetailNav({
    required this.tokens,
    required this.title,
    required this.isFav,
    required this.onBack,
    required this.onToggleFav,
  });

  final ThemeTokens tokens;
  final String title;
  final bool isFav;
  final VoidCallback onBack;
  final VoidCallback onToggleFav;

  @override
  Widget build(BuildContext context) {
    return LumiraNav(
      title: title,
      transparent: true,
      leading: _NavIconButton(
        icon: Icons.arrow_back_ios_new,
        onTap: onBack,
      ),
      actions: [
        _NavIconButton(
          icon: isFav ? Icons.favorite : Icons.favorite_border,
          onTap: onToggleFav,
          iconColor: const Color(0xFFC9A876),
        ),
      ],
    );
  }
}

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          size: 20, // 40rpx → 20dp
          color: iconColor ?? const Color(0xFF2A2520),
        ),
      ),
    );
  }
}

/// 示例图轮播（mock：水平滚动 + 多图）
class _Swiper extends StatelessWidget {
  const _Swiper({required this.scene});
  final ScenePreset scene;

  @override
  Widget build(BuildContext context) {
    final images = scene.exampleImages;
    if (images.isEmpty) {
      return Container(
        height: 240, // 480rpx → 240dp
        // 硬编码颜色，与 uni-app 一致 (placeholder)
        color: const Color.fromRGBO(201, 168, 118, 0.12),
        child: const Center(
          child: Icon(
            Icons.image_outlined,
            size: 40,
            color: Color(0xFFC9A876),
          ),
        ),
      );
    }
    return SizedBox(
      height: 240, // 480rpx → 240dp
      child: PageView.builder(
        itemCount: images.length,
        itemBuilder: (context, idx) => Image.network(
          images[idx],
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color.fromRGBO(201, 168, 118, 0.12),
            child: const Center(
              child: Icon(
                Icons.image_outlined,
                size: 40,
                color: Color(0xFFC9A876),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 标题区（图标 + 名称 + vibe）
class _Header extends StatelessWidget {
  const _Header({required this.scene});
  final ScenePreset scene;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8), // 24rpx×2/32rpx/16rpx
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                scene.icon,
                size: 24, // 48rpx → 24dp
                color: const Color(0xFF2A2520),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  scene.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20, // 40rpx → 20dp
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2A2520),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6), // 12rpx → 6dp
          Text(
            scene.vibe,
            style: const TextStyle(
              fontSize: 14, // 28rpx → 14dp
              fontStyle: FontStyle.italic,
              color: Color(0xFF6B635A),
            ),
          ),
        ],
      ),
    );
  }
}

/// 通用 section 容器
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // 24rpx/16rpx
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14, // 28rpx → 14dp
              fontWeight: FontWeight.w600,
              color: Color(0xFF2A2520),
            ),
          ),
          const SizedBox(height: 8), // 16rpx → 8dp
          child,
        ],
      ),
    );
  }
}

/// 氛围卡片
class _AtmosphereSection extends StatelessWidget {
  const _AtmosphereSection({required this.scene});
  final ScenePreset scene;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '氛围',
      child: Container(
        padding: const EdgeInsets.all(12), // 24rpx → 12dp
        decoration: BoxDecoration(
          // 硬编码颜色，与 uni-app 一致 (section-card bg rgba(0,0,0,0.04))
          color: const Color.fromRGBO(0, 0, 0, 0.04),
          borderRadius: BorderRadius.circular(10), // 20rpx → 10dp
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              scene.description,
              style: const TextStyle(
                fontSize: 13, // 26rpx → 13dp
                height: 1.6,
                color: Color(0xFF2A2520),
              ),
            ),
            const SizedBox(height: 8), // 16rpx → 8dp
            _MetaRow(icon: Icons.place_outlined, text: scene.whereToShoot),
            const SizedBox(height: 4), // 8rpx → 4dp
            _MetaRow(icon: Icons.access_time, text: scene.bestTime),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14, // 28rpx → 14dp
          color: const Color(0xFF6B635A),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12, // 24rpx → 12dp
              color: Color(0xFF6B635A),
            ),
          ),
        ),
      ],
    );
  }
}

/// 标签区
class _TagsSection extends StatelessWidget {
  const _TagsSection({
    required this.scene,
    required this.editableTagIds,
    required this.tagSheetVisible,
    required this.onToggleTagSheet,
    required this.onToggleTag,
  });

  final ScenePreset scene;
  final List<String> editableTagIds;
  final bool tagSheetVisible;
  final VoidCallback onToggleTagSheet;
  final ValueChanged<String> onToggleTag;

  @override
  Widget build(BuildContext context) {
    final isCustom = scene.isCustom;
    final tagIds = isCustom ? editableTagIds : scene.recommendedTagIds;
    final tags = CaptureSceneMockData.getTagsByIds(tagIds);

    return _Section(
      title: '标签',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6, // 12rpx → 6dp
            runSpacing: 6,
            children: [
              for (final t in tags)
                _TagChip(name: t.name, golden: true),
              if (tags.isEmpty && !isCustom)
                const Text(
                  '暂无标签',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9C9690),
                  ),
                ),
              if (isCustom)
                GestureDetector(
                  onTap: onToggleTagSheet,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // 20rpx×8rpx
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(
                        color: const Color(0xFFC9A876),
                        width: 1, // 2rpx → 1dp
                      ),
                      color: const Color.fromRGBO(201, 168, 118, 0.08),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.add,
                          size: 12, // 24rpx → 12dp
                          color: Color(0xFFC9A876),
                        ),
                        SizedBox(width: 3), // 6rpx → 3dp
                        Text(
                          '添加标签',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFC9A876),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (isCustom && tagSheetVisible) ...[
            const SizedBox(height: 8),
            _TagSelectorSheet(
              selectedIds: editableTagIds,
              onToggle: onToggleTag,
            ),
          ],
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.name, this.golden = false});
  final String name;
  final bool golden;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // 20rpx×8rpx
      decoration: BoxDecoration(
        // 硬编码颜色，与 uni-app 一致 (lumira-tag-gold bg rgba(201,168,118,0.15))
        color: golden
            ? const Color.fromRGBO(201, 168, 118, 0.15)
            : const Color.fromRGBO(0, 0, 0, 0.04),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: golden ? const Color(0xFF8C7340) : const Color(0xFF2A2520),
        ),
      ),
    );
  }
}

/// TagSelector 简化版（内嵌 chip 列表，brief §8）
class _TagSelectorSheet extends StatelessWidget {
  const _TagSelectorSheet({
    required this.selectedIds,
    required this.onToggle,
  });

  final List<String> selectedIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    const allTags = CaptureSceneMockData.tags;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(0, 0, 0, 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: allTags.map((t) {
          final selected = selectedIds.contains(t.id);
          return GestureDetector(
            onTap: () => onToggle(t.id),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFC9A876)
                    : Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(
                  color: selected
                      ? const Color(0xFFC9A876)
                      : const Color(0xFFEAE5DC),
                  width: 1,
                ),
              ),
              child: Text(
                t.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : const Color(0xFF2A2520),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.scene});
  final ScenePreset scene;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '推荐滤镜',
      child: SceneFilterBadge(filter: scene.filter),
    );
  }
}

class _TipsSection extends StatelessWidget {
  const _TipsSection({required this.scene});
  final ScenePreset scene;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '拍摄小贴士',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(0, 0, 0, 0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final tip in scene.tips) ...[
              _TipRow(text: tip),
              if (tip != scene.tips.last) const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '•',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFFC9A876),
            height: 1.5,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xFF2A2520),
            ),
          ),
        ),
      ],
    );
  }
}

class _AchievementSection extends StatelessWidget {
  const _AchievementSection({required this.scene});
  final ScenePreset scene;

  @override
  Widget build(BuildContext context) {
    final achievement = CaptureSceneMockData.getSceneAchievement(scene.id);
    final rankEntry = CaptureSceneMockData.weeklyRanking
        .where((e) => e.scene.id == scene.id)
        .toList();
    final rank = rankEntry.isEmpty ? null : rankEntry.first.rank;

    return _Section(
      title: '我的成就',
      child: SceneAchievementCard(
        achievement: achievement,
        sceneName: scene.name,
        rank: rank,
        rankLabel: '本周',
      ),
    );
  }
}

/// 空状态（场景未找到）
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: Color(0xFF9C9690),
          ),
          const SizedBox(height: 12),
          const Text(
            '场景未找到',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF2A2520),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onBack,
            child: const Text('返回'),
          ),
        ],
      ),
    );
  }
}

/// 底部双按钮
class _BottomButtons extends StatelessWidget {
  const _BottomButtons({required this.onCapture, required this.onCreateKit});
  final VoidCallback onCapture;
  final VoidCallback onCreateKit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16), // 24rpx + safe-area
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F2), // 硬编码：与页面背景一致
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onCapture,
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 44, // 88rpx → 44dp
                decoration: BoxDecoration(
                  // 硬编码颜色，与 uni-app 一致 (btn-primary bg #2A2520)
                  color: const Color(0xFF2A2520),
                  borderRadius: BorderRadius.circular(22), // 44rpx → 22dp
                ),
                alignment: Alignment.center,
                child: const Text(
                  '用此场景拍照',
                  style: TextStyle(
                    fontSize: 14, // 28rpx → 14dp
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8), // 16rpx → 8dp
          Expanded(
            child: GestureDetector(
              onTap: onCreateKit,
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  // 硬编码颜色，与 uni-app 一致 (btn-secondary bg rgba(201,168,118,0.15))
                  color: const Color.fromRGBO(201, 168, 118, 0.15),
                  borderRadius: BorderRadius.circular(22),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '加入组合',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFC9A876),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
