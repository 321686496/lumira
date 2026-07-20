import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../capture/data/capture_scene_mock_data.dart';
import '../data/scenes_mock_data.dart';

/// Scenes 独立场景库页（Task 2.11）
///
/// 视觉规格来源：lumira-app/src/pages/scenes/index.vue (159 行)
/// - 顶部导航：返回 + 标题「场景库」+ 右侧搜索按钮（toast 占位）
/// - 分类 tab 横滑条：全部 / 光线 / 室外 / 室内 / 情绪（5 项 pill）
/// - 场景 grid 2 列：封面图 + 名称 + vibe + 照片数 badge（>0 时显示）
/// - FAB：右下角圆形 + 按钮 → /capture/scene-manage?tab=custom
///
/// 跳转：
/// - 点击场景卡 → /capture/scene-detail?sceneId=xxx
/// - 点击搜索按钮 → SnackBar「搜索功能开发中」（与 uni-app showToast 一致）
class ScenesPage extends ConsumerStatefulWidget {
  const ScenesPage({super.key});

  @override
  ConsumerState<ScenesPage> createState() => _ScenesPageState();
}

class _ScenesPageState extends ConsumerState<ScenesPage> {
  String _activeCategoryId = 'all';

  List<ScenePreset> get _filteredScenes {
    final allScenes = ref.read(scenesListProvider);
    if (_activeCategoryId == 'all') return allScenes;
    final pill =
        scenesCategoryPills.firstWhere((p) => p.id == _activeCategoryId);
    return allScenes.where((s) => s.category == pill.category).toList();
  }

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.of(context).go(RouteNames.home);
    }
  }

  void _onSearch() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('搜索功能开发中')),
    );
  }

  void _goDetail(String id) {
    GoRouter.of(context).push(
      RouteNames.withSceneId(RouteNames.captureSceneDetail, id),
    );
  }

  void _goCreate() {
    GoRouter.of(context).push(
      RouteNames.build(RouteNames.captureSceneManage, {
        RouteNames.paramTab: 'custom',
      }),
    );
  }

  void _onCategorySelect(String id) {
    setState(() {
      _activeCategoryId = id;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 硬编码颜色，与 uni-app scenes-container bg #FAF7F2 一致
      backgroundColor: const Color(0xFFFAF7F2),
      body: SafeArea(
        child: Column(
          children: [
            _ScenesNav(onBack: _back, onSearch: _onSearch),
            _CategoryBar(
              activeId: _activeCategoryId,
              onSelect: _onCategorySelect,
            ),
            Expanded(
              child: _SceneGrid(
                scenes: _filteredScenes,
                onTap: _goDetail,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _Fab(onTap: _goCreate),
    );
  }
}

/// 顶部导航：返回 + 标题「场景库」+ 搜索
class _ScenesNav extends StatelessWidget {
  const _ScenesNav({required this.onBack, required this.onSearch});
  final VoidCallback onBack;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return LumiraNav(
      title: '场景库',
      transparent: true,
      leading: _NavIconButton(
        icon: Icons.arrow_back_ios_new, // ph-arrow-left → Icons.arrow_back_ios_new
        onTap: onBack,
      ),
      actions: [
        _NavIconButton(
          icon: Icons.search, // ph-magnifying-glass → Icons.search
          onTap: onSearch,
        ),
      ],
    );
  }
}

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

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
          color: const Color(0xFF2A2520),
        ),
      ),
    );
  }
}

/// 分类 tab 横滑条（5 项 pill）
class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.activeId, required this.onSelect});

  final String activeId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8), // 16rpx → 8dp
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12), // 24rpx → 12dp
        child: Row(
          children: [
            for (final pill in scenesCategoryPills) ...[
              _CategoryPill(
                label: pill.name,
                active: activeId == pill.id,
                onTap: () => onSelect(pill.id),
              ),
              const SizedBox(width: 8), // 16rpx → 8dp
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14, // 28rpx → 14dp
          vertical: 6, // 12rpx → 6dp
        ),
        decoration: BoxDecoration(
          // 与 uni-app 一致：active 用 brand-primary，inactive 用 card bg
          color: active ? const Color(0xFFC9A876) : Colors.white,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13, // 26rpx → 13dp
            color: active ? Colors.white : const Color(0xFF6B635A),
          ),
        ),
      ),
    );
  }
}

/// 场景 grid 2 列
class _SceneGrid extends StatelessWidget {
  const _SceneGrid({required this.scenes, required this.onTap});

  final List<ScenePreset> scenes;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    if (scenes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40), // 80rpx → 40dp
          child: Text(
            '暂无场景',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B635A),
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 80), // 24rpx + FAB 底部空间
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12, // 24rpx → 12dp
        crossAxisSpacing: 12,
        // 图片 ≈ 3:4 + body ≈ 60dp → 0.58
        childAspectRatio: 0.58,
      ),
      itemCount: scenes.length,
      itemBuilder: (context, index) {
        final scene = scenes[index];
        return _SceneCard(
          scene: scene,
          onTap: () => onTap(scene.id),
        );
      },
    );
  }
}

/// 场景卡片（对应 uni-app ScenePresetView variant="card"）
class _SceneCard extends StatelessWidget {
  const _SceneCard({required this.scene, required this.onTap});

  final ScenePreset scene;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final photoCount = CaptureSceneMockData.getPhotoCountByScene(scene.id);
    final hasBadge = photoCount > 0;
    final firstImage =
        scene.exampleImages.isNotEmpty ? scene.exampleImages.first : null;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14), // 28rpx → 14dp
          border: Border.all(
            color: const Color(0xFFEAE5DC),
            width: 1, // 2rpx → 1dp
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 图片区（Expanded 自动填充剩余空间，保持近似 3:4 比例）
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  firstImage != null
                      ? Image.network(
                          firstImage,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const _ImgPlaceholder(),
                        )
                      : const _ImgPlaceholder(),
                  if (hasBadge)
                    Positioned(
                      top: 8, // 16rpx → 8dp
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8, // 16rpx → 8dp
                          vertical: 3, // 6rpx → 3dp
                        ),
                        decoration: BoxDecoration(
                          // rgba(26,26,26,0.6) → 0x99 = 153 ≈ 0.6*255
                          color: const Color(0x991A1A1A),
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          '$photoCount 张',
                          style: const TextStyle(
                            fontSize: 10, // 20rpx → 10dp
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            letterSpacing: 0.4, // 0.04em
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 文字区
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    scene.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14, // 28rpx → 14dp
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2A2520),
                    ),
                  ),
                  const SizedBox(height: 4), // 8rpx → 4dp
                  Text(
                    scene.vibe,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12, // 24rpx → 12dp
                      fontStyle: FontStyle.italic,
                      color: Color(0xFFC9A876),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 图片占位（网络图加载失败 / 无图时）
class _ImgPlaceholder extends StatelessWidget {
  const _ImgPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color.fromRGBO(201, 168, 118, 0.12),
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          size: 28, // 56rpx → 28dp
          color: Color(0xFFC9A876),
        ),
      ),
    );
  }
}

/// 右下角 FAB（+ 创建自定义场景）
class _Fab extends StatelessWidget {
  const _Fab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 48, // 96rpx → 48dp
        height: 48,
        decoration: const BoxDecoration(
          color: Color(0xFFC9A876), // $color-brand-primary
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              // 0 8rpx 24rpx rgba(0,0,0,0.15) → 0 4dp 12dp
              color: Color(0x26000000), // 0.15*255 ≈ 38 = 0x26
              offset: Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: const Icon(
          Icons.add,
          size: 24, // 48rpx → 24dp
          color: Colors.white,
        ),
      ),
    );
  }
}
