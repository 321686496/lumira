import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/capture_scene_mock_data.dart';

/// 场景灵感页（Task 2.10）
///
/// 视觉规格来源：lumira-app/src/pages/capture/scene-guide.vue (306 行)
/// - 顶部导航：返回 + 标题（场景灵感）+ 设置按钮
/// - 分类导航：两层 pill（大类 + 风格）
/// - 标签筛选：水平 chip 列表（TagSelector 简化版）
/// - 场景卡片列表：图 + 名称 + vibe + 照片数 + 等级
/// - 空状态：暂无匹配场景
///
/// 简化决策（brief §8）：
/// - TagSelector（uni-app 组件未迁移）：用水平 chip 列表代替，支持多选
/// - 跳转场景详情 / 场景管理：mock SnackBar
class CaptureSceneGuidePage extends ConsumerStatefulWidget {
  const CaptureSceneGuidePage({super.key, this.scene});

  /// 路由参数：scene（高亮指定场景 ID，mock 阶段仅接收不强制滚动到该场景）
  final String? scene;

  @override
  ConsumerState<CaptureSceneGuidePage> createState() =>
      _CaptureSceneGuidePageState();
}

class _CaptureSceneGuidePageState
    extends ConsumerState<CaptureSceneGuidePage> {
  String? _selectedCategory;
  String? _selectedStyle;
  final List<String> _selectedTagIds = [];

  @override
  void initState() {
    super.initState();
    // 若路由参数 scene 提供且匹配某场景 ID，进入页面后无需特殊高亮
    // （uni-app 行为相同，scene 仅作为页面标识传递）
  }

  /// 筛选后的场景列表（与 uni-app 同样保留 category + style + tag 组合筛选）
  List<ScenePreset> get _filteredScenes {
    var list = CaptureSceneMockData.allScenes;
    if (_selectedCategory != null) {
      list = list.where((s) => s.category == _selectedCategory).toList();
    }
    if (_selectedStyle != null) {
      list = list.where((s) => s.style == _selectedStyle).toList();
    }
    if (_selectedTagIds.isNotEmpty) {
      list = list.where((s) {
        final ids = s.isCustom
            ? (s as CustomScenePreset).tagIds
            : s.recommendedTagIds;
        return _selectedTagIds.any((id) => ids.contains(id));
      }).toList();
    }
    return list;
  }

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.of(context).go(RouteNames.capture);
    }
  }

  void _goSceneDetail(String id) {
    GoRouter.of(context).push(RouteNames.withSceneId(
      RouteNames.captureSceneDetail,
      id,
    ));
  }

  void _goSceneManage() {
    GoRouter.of(context).push(RouteNames.captureSceneManage);
  }

  void _onCategorySelect(String? cat) {
    setState(() {
      _selectedCategory = cat;
      _selectedStyle = null;
    });
  }

  void _onStyleSelect(String? style) {
    setState(() {
      _selectedStyle = style;
    });
  }

  void _toggleTag(String tagId) {
    setState(() {
      if (_selectedTagIds.contains(tagId)) {
        _selectedTagIds.remove(tagId);
      } else {
        _selectedTagIds.add(tagId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _GuideNav(onBack: _back, onManage: _goSceneManage),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CategoryNav(
                      tokens: tokens,
                      selectedCategory: _selectedCategory,
                      selectedStyle: _selectedStyle,
                      onCategorySelect: _onCategorySelect,
                      onStyleSelect: _onStyleSelect,
                    ),
                    _TagFilter(
                      selectedTagIds: _selectedTagIds,
                      onToggleTag: _toggleTag,
                    ),
                    _SceneList(
                      scenes: _filteredScenes,
                      onTap: _goSceneDetail,
                    ),
                    const SizedBox(height: 24), // guide-bottom-space
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 顶部导航
class _GuideNav extends StatelessWidget {
  const _GuideNav({required this.onBack, required this.onManage});
  final VoidCallback onBack;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return LumiraNav(
      title: '场景灵感',
      transparent: true,
      leading: LumiraIconButton(
        icon: Icons.arrow_back_ios_new,
        onPressed: onBack,
        size: 20,
      ),
      actions: [
        LumiraIconButton(
          icon: Icons.settings_outlined, // ph-gear-six → Icons.settings_outlined
          onPressed: onManage,
          size: 20,
        ),
      ],
    );
  }
}

/// 分类导航（两层 pill）
class _CategoryNav extends StatelessWidget {
  const _CategoryNav({
    required this.tokens,
    required this.selectedCategory,
    required this.selectedStyle,
    required this.onCategorySelect,
    required this.onStyleSelect,
  });

  final ThemeTokens tokens;
  final String? selectedCategory;
  final String? selectedStyle;
  final ValueChanged<String?> onCategorySelect;
  final ValueChanged<String?> onStyleSelect;

  @override
  Widget build(BuildContext context) {
    const categories = CaptureSceneMockData.categories;
    final selectedGroup = selectedCategory == null
        ? null
        : categories.firstWhere((g) => g.category == selectedCategory);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4), // 8rpx → 4dp
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一层：大类
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12), // 24rpx → 12dp
            child: Row(
              children: [
                _Pill(
                  label: '全部',
                  active: selectedCategory == null,
                  onTap: () => onCategorySelect(null),
                ),
                const SizedBox(width: 8),
                for (final g in categories) ...[
                  _Pill(
                    label: g.name,
                    active: selectedCategory == g.category,
                    onTap: () => onCategorySelect(g.category),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          if (selectedGroup != null) ...[
            const SizedBox(height: 6), // 12rpx → 6dp
            // 第二层：风格
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _Pill(
                    label: '全部风格',
                    active: selectedStyle == null,
                    onTap: () => onStyleSelect(null),
                    subtle: true,
                  ),
                  const SizedBox(width: 8),
                  for (final s in selectedGroup.styles) ...[
                    _Pill(
                      label: s.name,
                      active: selectedStyle == s.id,
                      onTap: () => onStyleSelect(s.id),
                      subtle: true,
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends ConsumerWidget {
  const _Pill({
    required this.label,
    required this.active,
    required this.onTap,
    this.subtle = false,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool subtle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final isNeu = appTheme.style == UIStyle.neumorphic;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? tokens.brand
              : (subtle ? tokens.surfaceAlt : tokens.surface),
          borderRadius: BorderRadius.circular(9999),
          boxShadow: isNeu && !active ? tokens.shadowConvexSubtle : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: active ? tokens.textInverse : tokens.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// 标签筛选（水平 chip 列表，多选）
class _TagFilter extends StatelessWidget {
  const _TagFilter({
    required this.selectedTagIds,
    required this.onToggleTag,
  });

  final List<String> selectedTagIds;
  final ValueChanged<String> onToggleTag;

  @override
  Widget build(BuildContext context) {
    const tags = CaptureSceneMockData.tags;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final t in tags) ...[
              _TagChip(
                label: t.name,
                active: selectedTagIds.contains(t.id),
                onTap: () => onToggleTag(t.id),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _TagChip extends ConsumerWidget {
  const _TagChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final isNeu = appTheme.style == UIStyle.neumorphic;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? tokens.brand : tokens.surface,
          borderRadius: BorderRadius.circular(9999),
          boxShadow: isNeu && !active ? tokens.shadowConvexSubtle : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: active ? tokens.textInverse : tokens.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// 场景卡片列表
class _SceneList extends StatelessWidget {
  const _SceneList({required this.scenes, required this.onTap});

  final List<ScenePreset> scenes;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    if (scenes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40), // 80rpx → 40dp
        child: Center(
          child: Text(
            '暂无匹配场景',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B635A),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12), // 24rpx → 12dp
      child: Column(
        children: [
          for (var i = 0; i < scenes.length; i++) ...[
            if (i > 0) const SizedBox(height: 10), // 20rpx → 10dp
            _SceneCard(scene: scenes[i], onTap: () => onTap(scenes[i].id)),
          ],
        ],
      ),
    );
  }
}

class _SceneCard extends ConsumerWidget {
  const _SceneCard({required this.scene, required this.onTap});
  final ScenePreset scene;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;

    final photoCount = CaptureSceneMockData.getPhotoCountByScene(scene.id);
    final achievement = CaptureSceneMockData.getSceneAchievement(scene.id);
    final firstImage = scene.exampleImages.isNotEmpty
        ? scene.exampleImages.first
        : null;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: tokens.shadowConvex,
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 100,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 缩略图
              SizedBox(
                width: 100,
                height: 100,
              child: firstImage != null
                  ? Image.network(
                      firstImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _ImgPlaceholder(),
                    )
                  : const _ImgPlaceholder(),
            ),
            // 信息区
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      scene.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scene.vibe,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: tokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 12,
                          color: tokens.textTertiary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$photoCount',
                          style: TextStyle(
                            fontSize: 11,
                            color: tokens.textTertiary,
                          ),
                        ),
                        if (achievement.level > 0) ...[
                          const SizedBox(width: 10),
                          Icon(
                            Icons.emoji_events_outlined,
                            size: 12,
                            color: tokens.brand,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Lv.${achievement.level}',
                            style: TextStyle(
                              fontSize: 11,
                              color: tokens.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
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
