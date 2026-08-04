import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/dao/scenes_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/lumira/lumira.dart' show LumiraIconButton, LumiraProgress, LumiraToast;
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../capture/data/capture_scene_mock_data.dart';

/// Scenes 独立场景库页（Task 2.11）
///
/// 视觉规格来源：lumira-app/src/pages/scenes/index.vue (159 行)
/// - 顶部导航：返回 + 标题「场景库」+ 右侧搜索按钮（toast 占位）
/// - 分类概览：大卡片 + 瀑布流排版展示一级分类，点击进入二级分类
/// - 场景 grid 2 列：封面图 + 名称 + vibe + 照片数 badge（>0 时显示）
/// - FAB：右下角圆形 + 按钮 → /capture/scene-manage?tab=custom
class ScenesPage extends ConsumerStatefulWidget {
  const ScenesPage({super.key, this.category});

  final String? category;

  @override
  ConsumerState<ScenesPage> createState() => _ScenesPageState();
}

class _ScenesPageState extends ConsumerState<ScenesPage> {
  /// null = 分类概览模式；非 null = 二级分类页面（显示该分类下的场景）
  String? _activeCategoryId;
  /// 已加载的场景列表
  List<SceneRecord> _scenes = [];
  /// 是否正在加载
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _activeCategoryId = widget.category;
      _loadScenes();
    }
  }

  bool get _isOverview => _activeCategoryId == null;

  Future<void> _loadScenes() async {
    setState(() => _isLoading = true);
    try {
      final dao = await ref.read(scenesDaoProvider.future);
      final List<SceneRecord> scenes;
      if (_activeCategoryId == null || _activeCategoryId == 'all') {
        scenes = await dao.getAll();
      } else {
        scenes = await dao.getAllByCategory(_activeCategoryId!);
      }
      if (mounted) {
        setState(() {
          _scenes = scenes;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _scenes = [];
          _isLoading = false;
        });
      }
    }
  }

  void _back() {
    if (_activeCategoryId != null) {
      // 从二级分类返回到分类概览
      setState(() {
        _activeCategoryId = null;
        _scenes = [];
        _isLoading = false;
      });
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.of(context).go(RouteNames.home);
    }
  }

  void _onSearch() {
    LumiraToast.show(context, '搜索功能开发中');
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
      _scenes = [];
      _isLoading = false;
    });
    _loadScenes();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);

    return Scaffold(
      // 硬编码颜色，与 uni-app scenes-container bg #FAF7F2 一致
      backgroundColor: const Color(0xFFFAF7F2),
      body: SafeArea(
        child: Column(
          children: [
            _ScenesNav(
              title: _isOverview ? '场景库' : '全部场景',
              onBack: _back,
              onSearch: _onSearch,
            ),
            Expanded(
              child: _isOverview
                  ? _SceneCategoryOverview(
                      tokens: tokens,
                      onSelectCategory: _onCategorySelect,
                    )
                  : _isLoading
                      ? Center(child: LumiraProgress.circular())
                      : _SceneGrid(scenes: _scenes, onTap: _goDetail),
            ),
          ],
        ),
      ),
      floatingActionButton: _Fab(onTap: _goCreate),
    );
  }
}

/// 顶部导航：返回 + 标题 + 搜索
class _ScenesNav extends StatelessWidget {
  const _ScenesNav({required this.title, required this.onBack, required this.onSearch});
  final String title;
  final VoidCallback onBack;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return LumiraNav(
      title: title,
      transparent: true,
      leading: LumiraIconButton(
        icon: Icons.arrow_back_ios_new,
        onPressed: onBack,
        size: 20,
      ),
      actions: [
        LumiraIconButton(
          icon: Icons.search,
          onPressed: onSearch,
          size: 20,
        ),
      ],
    );
  }
}

/// 分类概览：大卡片 + 瀑布流排版展示一级分类
class _SceneCategoryOverview extends StatelessWidget {
  const _SceneCategoryOverview({
    required this.tokens,
    required this.onSelectCategory,
  });

  final ThemeTokens tokens;
  final void Function(String category) onSelectCategory;

  /// 4 个一级分类的展示元数据（id 与 SceneCategory 字符串常量对应）
  static const List<_SceneCategoryMeta> _categories = [
    _SceneCategoryMeta(
      id: 'light',
      name: '光线氛围',
      icon: Icons.wb_sunny_outlined,
      desc: '窗光、日落逆光、霓虹与烛光',
      gradient: [Color(0xFFE8B97A), Color(0xFFB8743D)],
      height: 190,
    ),
    _SceneCategoryMeta(
      id: 'outdoor',
      name: '室外环境',
      icon: Icons.landscape_outlined,
      desc: '海边、森林、城市街景',
      gradient: [Color(0xFF8FA06A), Color(0xFF5A7A48)],
      height: 165,
    ),
    _SceneCategoryMeta(
      id: 'indoor',
      name: '室内空间',
      icon: Icons.home_outlined,
      desc: '居家、咖啡馆、影棚',
      gradient: [Color(0xFFC9A96E), Color(0xFF8B7355)],
      height: 175,
    ),
    _SceneCategoryMeta(
      id: 'mood',
      name: '情绪氛围',
      icon: Icons.favorite_outline,
      desc: '治愈、孤独、内心风景',
      gradient: [Color(0xFFC9A0A8), Color(0xFF8C5A66)],
      height: 200,
    ),
  ];

  int _countForCategory(String categoryId) {
    final group = CaptureSceneMockData.categories.firstWhere(
      (g) => g.category == categoryId,
      orElse: () => CaptureSceneMockData.categories.first,
    );
    return CaptureSceneMockData.allScenes
        .where((s) => s.category == group.category)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final totalScenes = CaptureSceneMockData.allScenes.length;

    // 瀑布流：两列交替分布
    final left = <Widget>[];
    final right = <Widget>[];
    for (var i = 0; i < _categories.length; i++) {
      final cat = _categories[i];
      final card = _SceneCategoryCard(
        meta: cat,
        count: _countForCategory(cat.id),
        tokens: tokens,
        onTap: () => onSelectCategory(cat.id),
      );
      if (i % 2 == 0) {
        left.add(card);
      } else {
        right.add(card);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部摘要
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tokens.brandSubtle,
                  tokens.brand.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.filter_drama_outlined, size: 28, color: tokens.brand),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '场景库',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$totalScenes 个场景 · 4 个大类等你探索',
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '浏览分类',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          // 瀑布流双列
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Column(children: left)),
              const SizedBox(width: 12),
              Expanded(child: Column(children: right)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SceneCategoryMeta {
  const _SceneCategoryMeta({
    required this.id,
    required this.name,
    required this.icon,
    required this.desc,
    required this.gradient,
    required this.height,
  });
  final String id;
  final String name;
  final IconData icon;
  final String desc;
  final List<Color> gradient;
  final double height;
}

/// 分类大卡片：渐变背景 + 装饰圆 + 图标 + 名称 + 描述 + 数量
class _SceneCategoryCard extends StatelessWidget {
  const _SceneCategoryCard({
    required this.meta,
    required this.count,
    required this.tokens,
    required this.onTap,
  });

  final _SceneCategoryMeta meta;
  final int count;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: meta.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: meta.gradient.last.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 渐变背景
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: meta.gradient,
                ),
              ),
            ),
            // 装饰圆（右上角）
            Positioned(
              top: -24,
              right: -24,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.18),
                ),
              ),
            ),
            // 装饰圆（左下角小）
            Positioned(
              bottom: -16,
              left: -16,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.12),
                ),
              ),
            ),
            // 内容
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(meta.icon, size: 22, color: Colors.white),
                  ),
                  const Spacer(),
                  Text(
                    meta.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    meta.desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.92),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text(
                      '$count 个场景',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
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

/// 场景 grid 2 列
class _SceneGrid extends StatelessWidget {
  const _SceneGrid({required this.scenes, required this.onTap});

  final List<SceneRecord> scenes;
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

  final SceneRecord scene;
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
