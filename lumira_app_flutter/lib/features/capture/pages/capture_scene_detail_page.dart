import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/dao/scenes_dao.dart';
import '../../../core/db/dao/tags_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/image_cache.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../../shared/widgets/tags/tag_chip.dart' show TagChip, TagChipKind;
import '../../../shared/widgets/images/fullscreen_image_gallery.dart';
import '../data/capture_scene_mock_data.dart';
import '../data/scene_record_mapper.dart';
import '../data/scene_presets_data.dart';
import '../widgets/scene_achievement_card.dart';
import '../widgets/scene_filter_badge.dart';
import '../widgets/add_to_composition_sheet.dart';
import '../../../shared/widgets/tags/user_tags_section.dart';

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
  SceneRecord? _sceneRecord;
  bool _isFav = false;
  List<String> _editableTagIds = [];
  bool _tagSheetVisible = false;
  List<GalleryItemRecord> _scenePhotos = [];

  @override
  void initState() {
    super.initState();
    _loadScene().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadScene() async {
    final id = widget.sceneId ?? '';
    // 1. 优先真实 DB 数据
    try {
      final dao = await ref.read(scenesDaoProvider.future);
      final record = await dao.getById(id);
      if (record != null) {
        _sceneRecord = record;
        _isFav = record.isFavorite;
        // 按 creator 映射：user → 自定义场景；其它 → 内置/系统场景
        _scene = record.creator == 'user'
            ? sceneRecordToCustom(record)
            : sceneRecordToPreset(record);
        final custom = _scene as CustomScenePreset?;
        if (custom != null) {
          _editableTagIds = List<String>.from(custom.tagIds);
        }
        // 加载该场景下拍摄的真实照片
        final galleryDao = await ref.read(galleryDaoProvider.future);
        _scenePhotos = await galleryDao.getByScene(id);
        return;
      }
    } catch (_) {
      // DAO 异常 → 下方回退真实内置预设
    }
    // 2. DB 无该场景 → 真实内置预设
    final preset = ScenePresetsData.getScenePreset(id);
    _scene = preset;
    _isFav = false;
    if (preset is CustomScenePreset) {
      _editableTagIds = List<String>.from(preset.tagIds);
    }
    final galleryDao = await ref.read(galleryDaoProvider.future);
    _scenePhotos = await galleryDao.getByScene(id);
  }

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.of(context).go(RouteNames.capture);
    }
  }

  Future<void> _toggleFav() async {
    if (_scene == null && _sceneRecord == null) return;
    final id = _scene?.id ?? _sceneRecord!.id;
    final newFav = !_isFav;
    setState(() => _isFav = newFav);
    try {
      final dao = await ref.read(scenesDaoProvider.future);
      await dao.setFavorite(id, newFav);
    } catch (_) {
      // 静默失败
    }
    if (mounted) {
      LumiraToast.show(context, newFav ? '已收藏场景' : '已取消收藏');
    }
  }

  void _goCapture() {
    final scene = _scene;
    if (scene == null) return;
    GoRouter.of(context).push(
      RouteNames.build(RouteNames.capture, {
        RouteNames.paramScene: scene.id,
      }),
    );
  }

  void _openViewer(int index) {
    final urls = _scenePhotos
        .map(galleryItemSource)
        .where((u) => u != null && u.isNotEmpty)
        .cast<String>()
        .toList();
    if (urls.isEmpty) return;
    final i = index.clamp(0, urls.length - 1);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FullscreenImageGallery(urls: urls, initialIndex: i),
    ));
  }

  void _goCreateKit() {
    final scene = _scene;
    if (scene == null) return;
    final coverUrl =
        scene.exampleImages.isNotEmpty ? scene.exampleImages.first : null;
    AddToCompositionSheet.show(
      context,
      sceneId: scene.id,
      sceneName: scene.name,
      sceneCoverUrl: coverUrl,
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
    // 主题 token：页面底色随主题切换
    final ThemeTokens tokens = ref.watch(appThemeProvider).tokens;
    final scene = _scene;

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          SafeArea(
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
                          UserTagsSection(
                            itemType: TagItemType.scene,
                            itemId: scene.id,
                          ),
                          _FilterSection(scene: scene),
                          _TipsSection(scene: scene),
                          _ScenePhotosSection(
                            sceneName: scene.name,
                            photos: _scenePhotos,
                            onOpenViewer: _openViewer,
                            onCapture: _goCapture,
                          ),
                          _AchievementSection(
                            scene: scene,
                            photoCount: _scenePhotos.length,
                          ),
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
        ],
      ),
      bottomNavigationBar:
          scene == null ? null : _BottomButtons(onCapture: _goCapture, onCreateKit: _goCreateKit),
    );
  }
}

/// 照片显示源：filePath > dataUrl > originalPath，取首个非空
String? galleryItemSource(GalleryItemRecord p) {
  for (final c in [p.filePath, p.dataUrl, p.originalPath]) {
    if (c != null && c.isNotEmpty) return c;
  }
  return null;
}

/// 由真实照片数构造场景成就（等级阈值：0 → 未开始；1-2 → 初遇 Lv1；3-9 → 熟悉 Lv2；10+ → 精通 Lv3）
SceneAchievement buildSceneAchievement(String sceneId, int count) {
  if (count == 0) {
    return SceneAchievement(
        sceneId: sceneId, level: 0, levelName: '未开始', photoCount: 0, nextLevelCount: 1);
  }
  if (count < 3) {
    return SceneAchievement(
        sceneId: sceneId, level: 1, levelName: '初遇', photoCount: count, nextLevelCount: 3);
  }
  if (count < 10) {
    return SceneAchievement(
        sceneId: sceneId, level: 2, levelName: '熟悉', photoCount: count, nextLevelCount: 10);
  }
  return SceneAchievement(
      sceneId: sceneId, level: 3, levelName: '精通', photoCount: count, nextLevelCount: 30);
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
      leading: LumiraIconButton(
        icon: Icons.arrow_back_ios_new,
        onPressed: onBack,
        size: 20,
      ),
      actions: [
        LumiraIconButton(
          icon: isFav ? Icons.favorite : Icons.favorite_border,
          onPressed: onToggleFav,
          size: 20,
        ),
      ],
    );
  }
}

/// 示例图轮播（mock：水平滚动 + 多图）
class _Swiper extends ConsumerWidget {
  const _Swiper({required this.scene});
  final ScenePreset scene;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 主题 token：占位底色 / 占位图标色跟随主题 brand
    final ThemeTokens tokens = ref.watch(appThemeProvider).tokens;
    // 自定义场景封面优先展示；内置场景走 exampleImages。
    // 将封面放入 images 首项（cover 可能为空，需过滤）。
    final images = <String>[
      if (scene is CustomScenePreset && (scene as CustomScenePreset).cover.isNotEmpty)
        (scene as CustomScenePreset).cover,
      ...scene.exampleImages,
    ];
    if (images.isEmpty) {
      return Container(
        height: 240, // 480rpx → 240dp
        // 占位底色跟随主题 brand 半透明
        color: tokens.brand.withOpacity(0.12),
        child: Center(
          child: Icon(
            Icons.image_outlined,
            size: 40,
            color: tokens.brand,
          ),
        ),
      );
    }
    return SizedBox(
      height: 240, // 480rpx → 240dp
      child: PageView.builder(
        itemCount: images.length,
        itemBuilder: (context, idx) => CachedNetworkImage(
          url: images[idx],
          fit: BoxFit.cover,
          errorWidget: Container(
            color: tokens.brand.withOpacity(0.12),
            child: Center(
              child: Icon(
                Icons.image_outlined,
                size: 40,
                color: tokens.brand,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 标题区（图标 + 名称 + vibe）
class _Header extends ConsumerWidget {
  const _Header({required this.scene});
  final ScenePreset scene;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 主题 token：图标 / 主次文字色跟随主题
    final ThemeTokens tokens = ref.watch(appThemeProvider).tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8), // 24rpx×2/32rpx/16rpx
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CaptureSceneMockData.iconFromString(scene.icon),
                size: 24, // 48rpx → 24dp
                color: tokens.textPrimary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  scene.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20, // 40rpx → 20dp
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6), // 12rpx → 6dp
          Text(
            scene.vibe,
            style: TextStyle(
              fontSize: 14, // 28rpx → 14dp
              fontStyle: FontStyle.italic,
              color: tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 通用 section 容器
class _Section extends ConsumerWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 主题 token：标题色跟随主题
    final ThemeTokens tokens = ref.watch(appThemeProvider).tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // 24rpx/16rpx
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14, // 28rpx → 14dp
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
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
class _AtmosphereSection extends ConsumerWidget {
  const _AtmosphereSection({required this.scene});
  final ScenePreset scene;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 主题 token：卡片底色 / 描述文字色跟随主题
    final ThemeTokens tokens = ref.watch(appThemeProvider).tokens;
    return _Section(
      title: '氛围',
      child: Container(
        padding: const EdgeInsets.all(12), // 24rpx → 12dp
        decoration: BoxDecoration(
          // 卡片底色跟随主题 surfaceAlt
          color: tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(10), // 20rpx → 10dp
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              scene.description,
              style: TextStyle(
                fontSize: 13, // 26rpx → 13dp
                height: 1.6,
                color: tokens.textPrimary,
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

class _MetaRow extends ConsumerWidget {
  const _MetaRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 主题 token：图标 / 文字色跟随主题
    final ThemeTokens tokens = ref.watch(appThemeProvider).tokens;
    return Row(
      children: [
        Icon(
          icon,
          size: 14, // 28rpx → 14dp
          color: tokens.textSecondary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12, // 24rpx → 12dp
              color: tokens.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// 标签区
class _TagsSection extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    // 主题 token：空态 / 添加标签 chip 色跟随主题
    final ThemeTokens tokens = ref.watch(appThemeProvider).tokens;
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
                TagChip(label: t.name, kind: TagChipKind.golden),
              if (tags.isEmpty && !isCustom)
                Text(
                  '暂无标签',
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.textTertiary,
                  ),
                ),
              if (isCustom)
                TagChip(
                  label: '添加标签',
                  kind: TagChipKind.system,
                  onTap: onToggleTagSheet,
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

/// TagSelector 简化版（内嵌 chip 列表，brief §8）
class _TagSelectorSheet extends ConsumerWidget {
  const _TagSelectorSheet({
    required this.selectedIds,
    required this.onToggle,
  });

  final List<String> selectedIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const allTags = CaptureSceneMockData.tags;
    return NeuCard(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: allTags.map((t) {
          final selected = selectedIds.contains(t.id);
          return TagChip(
            label: t.name,
            kind: TagChipKind.plain,
            selected: selected,
            onTap: () => onToggle(t.id),
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

class _TipsSection extends ConsumerWidget {
  const _TipsSection({required this.scene});
  final ScenePreset scene;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 主题 token：贴士卡片底色跟随主题
    final ThemeTokens tokens = ref.watch(appThemeProvider).tokens;
    return _Section(
      title: '拍摄小贴士',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tokens.surfaceAlt,
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

class _TipRow extends ConsumerWidget {
  const _TipRow({required this.text});
  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 主题 token：圆点 / 文字色跟随主题
    final ThemeTokens tokens = ref.watch(appThemeProvider).tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '•',
          style: TextStyle(
            fontSize: 13,
            color: tokens.brand,
            height: 1.5,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: tokens.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// 该场景下拍摄的照片（真实数据，横向缩略 + 全屏查看；无照片引导拍摄）
class _ScenePhotosSection extends ConsumerWidget {
  const _ScenePhotosSection({
    required this.sceneName,
    required this.photos,
    required this.onOpenViewer,
    required this.onCapture,
  });

  final String sceneName;
  final List<GalleryItemRecord> photos;
  final void Function(int index) onOpenViewer;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;

    if (photos.isEmpty) {
      // 空态：引导「用此场景拍照」
      return _Section(
        title: '此场景拍摄',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
          decoration: BoxDecoration(
            color: tokens.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(Icons.photo_library_outlined,
                  size: 36, color: tokens.textTertiary),
              const SizedBox(height: 8),
              Text(
                '还没有用「$sceneName」拍过照片',
                style: TextStyle(fontSize: 13, color: tokens.textSecondary),
              ),
              const SizedBox(height: 12),
              LumiraButton(
                variant: ButtonVariant.primary,
                onPressed: onCapture,
                child: const Text('用此场景拍照'),
              ),
            ],
          ),
        ),
      );
    }

    return _Section(
      title: '此场景拍摄',
      child: SizedBox(
        height: 140,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: photos.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final url = galleryItemSource(photos[i]) ?? '';
            return GestureDetector(
              onTap: () => onOpenViewer(i),
              behavior: HitTestBehavior.opaque,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 100,
                  height: 140,
                  child: _ScenePhotoThumb(url: url, tokens: tokens),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 单张场景照片缩略：http / data / 本地文件 → 统一占位
class _ScenePhotoThumb extends StatelessWidget {
  const _ScenePhotoThumb({required this.url, required this.tokens});
  final String url;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: tokens.surfaceAlt,
      child: Icon(Icons.image_outlined, size: 28, color: tokens.textTertiary),
    );
    if (url.isEmpty) return placeholder;
    if (url.startsWith('data:image/')) {
      Widget decode() {
        final comma = url.indexOf(',');
        final b64 = comma >= 0 ? url.substring(comma + 1) : url;
        return Image.memory(base64Decode(b64), fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder);
      }
      try {
        return decode();
      } catch (_) {
        return placeholder;
      }
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return CachedNetworkImage(
        url: url,
        fit: BoxFit.cover,
        placeholder: placeholder,
        errorWidget: placeholder,
      );
    }
    return Image.file(File(url),
        fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder);
  }
}

class _AchievementSection extends StatelessWidget {
  const _AchievementSection({required this.scene, required this.photoCount});
  final ScenePreset scene;
  final int photoCount;

  @override
  Widget build(BuildContext context) {
    final achievement = buildSceneAchievement(scene.id, photoCount);
    return _Section(
      title: '我的成就',
      child: SceneAchievementCard(
        achievement: achievement,
        sceneName: scene.name,
        // rank 为空 → 不渲染排行榜
      ),
    );
  }
}

/// 空状态（场景未找到）
class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 主题 token：空状态图标 / 文字色跟随主题
    final ThemeTokens tokens = ref.watch(appThemeProvider).tokens;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: tokens.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            '场景未找到',
            style: TextStyle(
              fontSize: 16,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          LumiraButton(
            variant: ButtonVariant.ghost,
            onPressed: onBack,
            child: const Text('返回'),
          ),
        ],
      ),
    );
  }
}

/// 底部双按钮
class _BottomButtons extends ConsumerWidget {
  const _BottomButtons({required this.onCapture, required this.onCreateKit});
  final VoidCallback onCapture;
  final VoidCallback onCreateKit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 主题 token：底部面板底 / 主副按钮色跟随主题
    final ThemeTokens tokens = ref.watch(appThemeProvider).tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16), // 24rpx + safe-area
      decoration: BoxDecoration(
        color: tokens.canvas, // 与页面背景一致
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
                  // 主按钮底色跟随主题 textPrimary
                  color: tokens.textPrimary,
                  borderRadius: BorderRadius.circular(22), // 44rpx → 22dp
                ),
                alignment: Alignment.center,
                child: Text(
                  '用此场景拍照',
                  style: TextStyle(
                    fontSize: 14, // 28rpx → 14dp
                    fontWeight: FontWeight.w600,
                    color: tokens.textInverse,
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
                  // 副按钮底色跟随主题 brand 半透明
                  color: tokens.brand.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(22),
                ),
                alignment: Alignment.center,
                child: Text(
                  '加入组合',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tokens.brand,
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
