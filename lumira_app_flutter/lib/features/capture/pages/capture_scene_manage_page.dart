import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/services/file_picker_service.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/image_cache.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/common/lumira_surface.dart';
import '../../../shared/widgets/effects/pressable_recess.dart';
import '../../../shared/widgets/effects/recessed_surface.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/capture_scene_mock_data.dart';
import '../data/scene_manage_providers.dart';
import '../data/scene_record_mapper.dart';

/// 场景管理页（Task 2.10）
///
/// 视觉规格来源：lumira-app/src/pages/capture/scene-manage.vue (1012 行)
/// - 顶部导航：返回 + 标题（场景管理）
/// - Tab 栏：我的收藏 / 自定义场景
/// - Tab 1（我的收藏）：收藏场景列表 + 取消收藏按钮 / 空状态
/// - Tab 2（自定义场景）：列表 + 新建场景按钮 / 新建-编辑表单
///
/// 数据来源：以本地 scenes 表为准（真实数据），自定义场景增删改实时落盘；
/// 收藏标记存 DB is_favorite，内置预设场景完整数据由代码常量提供。
/// 表单支持封面图上传（base64 data URL）、校验与字段分组。
class CaptureSceneManagePage extends ConsumerStatefulWidget {
  const CaptureSceneManagePage({super.key, this.initialTab});

  /// 路由参数：tab（fav / custom）
  final String? initialTab;

  @override
  ConsumerState<CaptureSceneManagePage> createState() =>
      _CaptureSceneManagePageState();
}

enum _ManageTab { fav, custom }

class _CaptureSceneManagePageState
    extends ConsumerState<CaptureSceneManagePage> {
  late _ManageTab _tab;
  bool _formVisible = false;
  String? _editingId;
  late _SceneFormData _formData;
  bool _formDirty = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _tab = _parseTab(widget.initialTab);
    _formData = _SceneFormData.empty();
  }

  _ManageTab _parseTab(String? tab) {
    switch (tab) {
      case 'custom':
        return _ManageTab.custom;
      default:
        return _ManageTab.fav;
    }
  }

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.of(context).go(RouteNames.capture);
    }
  }

  void _goGuide() {
    // 管理页"查看场景"统一进入场景库大全（场景灵感页已并入）
    GoRouter.of(context).push(RouteNames.scenes);
  }

  /// 点击场景卡片跳转到场景详情页（带 sceneId）
  void _goSceneDetail(String sceneId) {
    GoRouter.of(context).push(
      RouteNames.withSceneId(RouteNames.captureSceneDetail, sceneId),
    );
  }

  // ===== 收藏（真实数据：写 scenes 表 is_favorite） =====
  Future<void> _toggleFav(String id) async {
    final dao = await ref.read(scenesDaoProvider.future);
    final favs = await dao.getFavorites();
    final isFav = favs.any((r) => r.id == id);
    await dao.setFavorite(id, !isFav);
    _invalidateScenes();
    if (!mounted) return;
    LumiraToast.show(context, isFav ? '已取消收藏' : '已收藏场景');
  }

  // ===== 自定义场景 CRUD（真实数据：读/写 scenes 表） =====
  void _onNew() {
    setState(() {
      _editingId = null;
      _formData = _SceneFormData.empty();
      _formVisible = true;
      _formDirty = false;
      _formError = null;
    });
  }

  void _onEdit(CustomScenePreset scene) {
    setState(() {
      _editingId = scene.id;
      _formData = _SceneFormData.from(scene);
      _formVisible = true;
      _formDirty = false;
      _formError = null;
    });
  }

  void _onCancelForm() {
    if (_formDirty) {
      LumiraAlertDialog.show<void>(
        context: context,
        title: const Text('确认离开'),
        content: const Text('当前表单有未保存的变更，确定要离开吗？'),
        actions: [
          LumiraButton(
            variant: ButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          LumiraButton(
            variant: ButtonVariant.primary,
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _formVisible = false;
                _editingId = null;
                _formDirty = false;
                _formError = null;
              });
            },
            child: const Text('确定'),
          ),
        ],
      );
    } else {
      setState(() {
        _formVisible = false;
        _editingId = null;
        _formError = null;
      });
    }
  }

  Future<void> _onSaveForm() async {
    final name = _formData.name.trim();
    if (name.isEmpty) {
      setState(() => _formError = '请填写场景名称');
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final isEdit = _editingId != null;

    final dao = await ref.read(scenesDaoProvider.future);
    final existing = isEdit ? await dao.getById(_editingId!) : null;
    final isFav = existing?.isFavorite ?? false;

    final exampleImages = _formData.exampleImageSeeds
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((s) => 'https://picsum.photos/seed/$s/600/800')
        .toList();
    final tips = _formData.tipsText
        .split('\n')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final bestTime = _formData.bestTime.trim();

    final preset = CustomScenePreset(
      id: _editingId ?? 'custom_$now',
      name: name,
      icon: _formData.icon,
      category: _formData.category,
      style: _formData.style,
      filter: SceneFilter(
        lut: _formData.filterLut,
        systemFilter: _formData.filterSystemFilter,
        reason: _formData.filterReason.trim(),
      ),
      vibe: _formData.vibe.trim(),
      description: _formData.description.trim(),
      exampleImages: exampleImages,
      tips: tips,
      whereToShoot: _formData.whereToShoot.trim(),
      bestTime: bestTime,
      sceneGuide: SceneGuide(
        lightDirection: _formData.lightDirection,
        shootingDistance: _formData.shootingDistance,
        background: _formData.background,
        props: const [],
        bestTime: bestTime,
        tips: tips,
      ),
      relatedCategory: _formData.relatedCategory,
      tagIds: List<String>.from(_formData.tagIds),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      cover: _formData.cover,
    );
    await dao.upsert(customToRecord(preset, isFavorite: isFav));
    _invalidateScenes();
    if (!mounted) return;
    setState(() {
      _formVisible = false;
      _editingId = null;
      _formDirty = false;
      _formError = null;
    });
    LumiraToast.show(context, isEdit ? '已保存' : '已创建');
  }

  void _onMore(CustomScenePreset scene) {
    final tokens = ref.read(appThemeProvider).tokens;
    showLumiraBottomSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LumiraListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('编辑'),
            onTap: () {
              Navigator.of(ctx).pop();
              _onEdit(scene);
            },
          ),
          LumiraListTile(
            leading: Icon(Icons.delete_outline, color: tokens.danger),
            title: Text('删除', style: TextStyle(color: tokens.danger)),
            onTap: () {
              Navigator.of(ctx).pop();
              _confirmDelete(scene);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(CustomScenePreset scene) async {
    await LumiraAlertDialog.show<void>(
      context: context,
      title: const Text('删除场景'),
      content: Text('确定删除「${scene.name}」吗？'),
      actions: [
        LumiraButton(
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        LumiraButton(
          variant: ButtonVariant.danger,
          onPressed: () async {
            Navigator.of(context).pop();
            final dao = await ref.read(scenesDaoProvider.future);
            await dao.delete(scene.id);
            _invalidateScenes();
            if (mounted) LumiraToast.show(context, '已删除');
          },
          child: const Text('删除'),
        ),
      ],
    );
  }

  void _onFormChange() {
    if (_formError != null) {
      setState(() => _formError = null);
    } else if (_formVisible && !_formDirty) {
      setState(() => _formDirty = true);
    }
  }

  void _invalidateScenes() {
    ref.invalidate(customScenesProvider);
    ref.invalidate(favoriteScenesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final customScenes = ref.watch(customScenesProvider).valueOrNull ?? const [];
    final favoriteScenes =
        ref.watch(favoriteScenesProvider).valueOrNull ?? const [];
    return Scaffold(
      backgroundColor: tokens.canvas,
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          SafeArea(
            child: Column(
              children: [
                _Nav(onBack: _back),
                _TabsRow(
                  current: _tab,
                  onSelect: (t) => setState(() => _tab = t),
                ),
                Expanded(
                  child: _tab == _ManageTab.fav
                      ? _FavTab(
                          favoriteScenes: favoriteScenes,
                          onToggleFav: _toggleFav,
                          onGoGuide: _goGuide,
                          onTapScene: _goSceneDetail,
                        )
                      : _formVisible
                          ? _CustomForm(
                              formData: _formData,
                              editingId: _editingId,
                              errorText: _formError,
                              onChange: _onFormChange,
                              onCancel: _onCancelForm,
                              onSave: _onSaveForm,
                              onMutate: (fn) {
                                setState(fn);
                                _onFormChange();
                              },
                            )
                          : _CustomTab(
                              customScenes: customScenes,
                              onNew: _onNew,
                              onMore: _onMore,
                              onTapScene: _goSceneDetail,
                            ),
                ),
                const SizedBox(height: 24), // bottom-spacer
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 表单数据
class _SceneFormData {
  String name;
  String icon;
  String description;
  String vibe;
  String relatedCategory;
  String category;
  String style;
  String lightDirection;
  String shootingDistance;
  String background;
  String whereToShoot;
  String bestTime;
  String filterLut;
  String? filterSystemFilter;
  String filterReason;
  List<String> exampleImageSeeds;
  String tipsText;
  List<String> tagIds;
  String cover;

  _SceneFormData({
    required this.name,
    required this.icon,
    required this.description,
    required this.vibe,
    required this.relatedCategory,
    required this.category,
    required this.style,
    required this.lightDirection,
    required this.shootingDistance,
    required this.background,
    required this.whereToShoot,
    required this.bestTime,
    required this.filterLut,
    required this.filterSystemFilter,
    required this.filterReason,
    required this.exampleImageSeeds,
    required this.tipsText,
    required this.tagIds,
    this.cover = '',
  });

  factory _SceneFormData.empty() => _SceneFormData(
        name: '',
        icon: 'ph-camera',
        description: '',
        vibe: '',
        relatedCategory: Target.portrait,
        category: SceneCategory.indoor,
        style: 'cafe',
        lightDirection: '自然光',
        shootingDistance: '1-2米',
        background: '简洁背景',
        whereToShoot: '',
        bestTime: '',
        filterLut: 'none',
        filterSystemFilter: null,
        filterReason: '',
        exampleImageSeeds: ['', '', ''],
        tipsText: '',
        tagIds: [],
      );

  factory _SceneFormData.from(CustomScenePreset s) {
    String seedFromUrl(String url) {
      final m = RegExp(r'/seed/([^/]+)/').firstMatch(url);
      return m != null ? m.group(1)! : '';
    }

    return _SceneFormData(
      name: s.name,
      icon: s.icon,
      description: s.description,
      vibe: s.vibe,
      relatedCategory: s.relatedCategory,
      category: s.category,
      style: s.style,
      lightDirection: s.sceneGuide.lightDirection,
      shootingDistance: s.sceneGuide.shootingDistance,
      background: s.sceneGuide.background,
      whereToShoot: s.whereToShoot,
      bestTime: s.bestTime,
      filterLut: s.filter.lut,
      filterSystemFilter: s.filter.systemFilter,
      filterReason: s.filter.reason,
      exampleImageSeeds: [
        for (var i = 0; i < 3; i++)
          i < s.exampleImages.length ? seedFromUrl(s.exampleImages[i]) : '',
      ],
      tipsText: s.tips.join('\n'),
      tagIds: List<String>.from(s.tagIds),
      cover: s.cover,
    );
  }
}

/// 顶部导航
class _Nav extends StatelessWidget {
  const _Nav({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return LumiraNav(
      title: '场景管理',
      transparent: true,
      leading: LumiraIconButton(
        icon: Icons.arrow_back_ios_new,
        onPressed: onBack,
        size: 20,
      ),
    );
  }
}

/// Tab 栏
class _TabsRow extends StatelessWidget {
  const _TabsRow({required this.current, required this.onSelect});
  final _ManageTab current;
  final ValueChanged<_ManageTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0), // 48rpx/32rpx
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _TabPill(
              label: '我的收藏',
              active: current == _ManageTab.fav,
              onTap: () => onSelect(_ManageTab.fav),
            ),
            const SizedBox(width: 8), // 16rpx → 8dp
            _TabPill(
              label: '自定义场景',
              active: current == _ManageTab.custom,
              onTap: () => onSelect(_ManageTab.custom),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabPill extends ConsumerWidget {
  const _TabPill({
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
      child: isNeu && active
          ? RecessedSurface(
              tokens: tokens,
              borderRadius: 9999,
              depth: 0.7,
              rimFraction: 0.32,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: active
                        ? (isNeu ? tokens.brandText : tokens.textInverse)
                        : tokens.textSecondary,
                  ),
                ),
              ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                // neumorphic：方案 B 选中/未选中同为 surface，仅凸起↔凹陷翻转，品牌色只在文字
                color: active ? tokens.brand : tokens.surface,
                borderRadius: BorderRadius.circular(9999),
                boxShadow: isNeu ? tokens.shadowConvexSubtle : null,
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: active
                      ? (isNeu ? tokens.brandText : tokens.textInverse)
                      : tokens.textSecondary,
                ),
              ),
            ),
    );
  }
}

/// 品牌色 CTA 按钮：按压保持主色背景（仅加深 + 缩放），不切换为凹陷表面。
/// 用于「去场景指南发现更多」「新建场景」等主操作，满足「主色 CTA 保持主色」。
class _BrandCtaButton extends ConsumerStatefulWidget {
  const _BrandCtaButton({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  ConsumerState<_BrandCtaButton> createState() => _BrandCtaButtonState();
}

class _BrandCtaButtonState extends ConsumerState<_BrandCtaButton> {
  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(appThemeProvider).tokens;
    // 主色 CTA 新拟态内斜边：纯品牌色顶面 + 内斜边（亮上左/暗下右），
    // 按压时反转斜边（暗上左/亮下右），1.5px 实线不发散，无外阴影避免悬浮感。
    return PressableRecess(
      onTap: widget.onTap,
      borderRadius: 9999,
      raisedFill: tokens.brand,
      bevelLight: ThemeTokens.brandBevelLight(tokens),
      bevelDark: ThemeTokens.brandBevelDark(tokens),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: widget.child,
      ),
    );
  }
}

/// 通用空状态
class _EmptyState extends ConsumerWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.desc,
    this.btnText,
    this.onBtnTap,
  });

  final IconData icon;
  final String title;
  final String desc;
  final String? btnText;
  final VoidCallback? onBtnTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20), // 40rpx/80rpx
      child: Column(
        children: [
          Icon(
            icon,
            size: 40, // 80rpx → 40dp
            color: tokens.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: tokens.textTertiary,
            ),
          ),
          if (btnText != null && onBtnTap != null) ...[
            const SizedBox(height: 20),
            _BrandCtaButton(
              onTap: onBtnTap!,
              child: Text(
                btnText!,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: tokens.textInverse,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tab 1：我的收藏
class _FavTab extends ConsumerWidget {
  const _FavTab({
    required this.favoriteScenes,
    required this.onToggleFav,
    required this.onGoGuide,
    required this.onTapScene,
  });

  final List<ScenePreset> favoriteScenes;
  final ValueChanged<String> onToggleFav;
  final VoidCallback onGoGuide;
  final ValueChanged<String> onTapScene;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final favScenes = favoriteScenes;

    if (favScenes.isEmpty) {
      return SingleChildScrollView(
        child: _EmptyState(
          icon: Icons.star_outline,
          title: '还没有收藏的场景',
          desc: '收藏的场景会出现在首页和场景指南中',
          btnText: '去场景指南发现更多',
          onBtnTap: onGoGuide,
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        children: [
          for (var i = 0; i < favScenes.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _ScenePresetRow(
              scene: favScenes[i],
              onTap: () => onTapScene(favScenes[i].id),
              action: GestureDetector(
                onTap: () => onToggleFav(favScenes[i].id),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.star,
                    size: 18,
                    color: tokens.brand,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 场景预设行（简化版 ScenePresetView）
/// 封面优先使用自定义场景的 cover；否则回退到示例图第一张。
class _ScenePresetRow extends ConsumerWidget {
  const _ScenePresetRow({
    required this.scene,
    required this.onTap,
    this.action,
  });

  final ScenePreset scene;
  final VoidCallback onTap;
  final Widget? action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    // 封面优先使用自定义场景的 cover；否则回退到示例图第一张。
    // 注：scene 是 Widget 字段（非局部变量），Dart 不做字段类型提升，需显式类型判断。
    String? cover;
    if (scene is CustomScenePreset && (scene as CustomScenePreset).cover.isNotEmpty) {
      cover = (scene as CustomScenePreset).cover;
    } else if (scene.exampleImages.isNotEmpty) {
      cover = scene.exampleImages.first;
    }
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 80,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: cover != null ? _CoverImage(url: cover) : null,
              ),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
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
                    ],
                  ),
                ),
              ),
              if (action != null)
                Padding(padding: const EdgeInsets.all(8), child: action!),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tab 2：自定义场景列表
class _CustomTab extends ConsumerWidget {
  const _CustomTab({
    required this.customScenes,
    required this.onNew,
    required this.onMore,
    required this.onTapScene,
  });

  final List<CustomScenePreset> customScenes;
  final VoidCallback onNew;
  final ValueChanged<CustomScenePreset> onMore;
  final ValueChanged<String> onTapScene;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    if (customScenes.isEmpty) {
      return SingleChildScrollView(
        child: _EmptyState(
          icon: Icons.camera_alt_outlined,
          title: '还没有自定义场景',
          desc: '创建你的专属拍摄场景，快速应用参数',
          btnText: '+ 新建场景',
          onBtnTap: onNew,
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        children: [
          for (var i = 0; i < customScenes.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _ScenePresetRow(
              scene: customScenes[i],
              onTap: () => onTapScene(customScenes[i].id),
              action: GestureDetector(
                onTap: () => onMore(customScenes[i]),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.more_horiz,
                    size: 18,
                    color: tokens.textTertiary,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          // 新建场景按钮（主色 CTA：纯品牌色 + 品牌浮雕，按下同色内影凹陷）
          _BrandCtaButton(
            onTap: onNew,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 18, color: tokens.textInverse),
                const SizedBox(width: 6),
                Text(
                  '新建场景',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: tokens.textInverse,
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

/// Tab 2 表单：新建/编辑场景
class _CustomForm extends ConsumerWidget {
  const _CustomForm({
    required this.formData,
    required this.editingId,
    required this.errorText,
    required this.onChange,
    required this.onCancel,
    required this.onSave,
    required this.onMutate,
  });

  final _SceneFormData formData;
  final String? editingId;
  final String? errorText;
  final VoidCallback onChange;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final void Function(void Function() fn) onMutate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: LumiraSurface(
        padding: const EdgeInsets.all(20),
        radius: 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              editingId != null ? '编辑场景' : '新建场景',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
            if (errorText != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.error_outline, size: 16, color: tokens.danger),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      errorText!,
                      style: TextStyle(fontSize: 13, color: tokens.danger),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            // === 封面图 ===
            _CoverPicker(
              cover: formData.cover,
              onChanged: (v) => onMutate(() => formData.cover = v),
            ),
            const SizedBox(height: 4),
            const _SectionTitle('基本信息'),
            _FormTextField(
              label: '场景名称',
              value: formData.name,
              placeholder: '如：夕阳人像',
              maxLength: 20,
              errorText: errorText != null && formData.name.trim().isEmpty
                  ? '请填写场景名称'
                  : null,
              onChanged: (v) => onMutate(() => formData.name = v),
            ),
            _FormTextField(
              label: '情绪主标题',
              value: formData.vibe,
              placeholder: '如：慵懒午后，把光调成蜜糖色',
              maxLength: 40,
              onChanged: (v) => onMutate(() => formData.vibe = v),
            ),
            _IconPicker(
              selected: formData.icon,
              onSelect: (ic) => onMutate(() => formData.icon = ic),
            ),
            _PillPicker(
              label: '关联分类',
              options: Target.all
                  .map((t) => _PillOption(value: t, label: Target.label(t)))
                  .toList(),
              selected: formData.relatedCategory,
              onSelect: (v) =>
                  onMutate(() => formData.relatedCategory = v),
            ),
            const _SectionTitle('拍摄参考'),
            _FormTextField(
              label: '光线方向',
              value: formData.lightDirection,
              placeholder: '如：侧光 45°',
              onChanged: (v) => onMutate(() => formData.lightDirection = v),
            ),
            _FormTextField(
              label: '拍摄距离',
              value: formData.shootingDistance,
              placeholder: '如：1.5-2.5m',
              onChanged: (v) => onMutate(() => formData.shootingDistance = v),
            ),
            _FormTextField(
              label: '背景建议',
              value: formData.background,
              placeholder: '如：简洁背景',
              onChanged: (v) => onMutate(() => formData.background = v),
            ),
            _FormTextField(
              label: '出片地点',
              value: formData.whereToShoot,
              placeholder: '如：咖啡馆 / 图书馆',
              onChanged: (v) => onMutate(() => formData.whereToShoot = v),
            ),
            _FormTextField(
              label: '最佳拍摄时间',
              value: formData.bestTime,
              placeholder: '如：下午 14:00-17:00',
              onChanged: (v) => onMutate(() => formData.bestTime = v),
            ),
            const _SectionTitle('滤镜'),
            _PillPicker(
              label: 'LUT 滤镜',
              options: CaptureSceneMockData.lutOptions
                  .map((o) => _PillOption(value: o.value, label: o.label))
                  .toList(),
              selected: formData.filterLut,
              onSelect: (v) => onMutate(() => formData.filterLut = v),
            ),
            _PillPicker(
              label: '系统滤镜（可选）',
              options: CaptureSceneMockData.systemFilterOptions
                  .map((o) => _PillOption(value: o.value, label: o.label))
                  .toList(),
              selected: formData.filterSystemFilter ?? 'none',
              allowToggle: true,
              onSelect: (v) => onMutate(() {
                formData.filterSystemFilter =
                    formData.filterSystemFilter == v ? null : v;
              }),
            ),
            _FormTextField(
              label: '滤镜理由',
              value: formData.filterReason,
              placeholder: '如：让画面像被夕阳包住一样温柔',
              onChanged: (v) => onMutate(() => formData.filterReason = v),
            ),
            const _SectionTitle('参考与分享'),
            _ExampleImagesEditor(
              seeds: formData.exampleImageSeeds,
              onChange: (idx, val) =>
                  onMutate(() => formData.exampleImageSeeds[idx] = val),
            ),
            _TipsEditor(
              tipsText: formData.tipsText,
              onChanged: (v) => onMutate(() => formData.tipsText = v),
            ),
            _TagPicker(
              selectedIds: formData.tagIds,
              onToggle: (id) => onMutate(() {
                if (formData.tagIds.contains(id)) {
                  formData.tagIds.remove(id);
                } else {
                  formData.tagIds.add(id);
                }
              }),
            ),
            const SizedBox(height: 20),
            // 表单按钮
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onCancel,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: tokens.surfaceAlt,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '取消',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: onSave,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [tokens.brand, tokens.brandDeep],
                        ),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '保存',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: tokens.textInverse,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 表单分组标题
class _SectionTitle extends ConsumerWidget {
  const _SectionTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: tokens.brand,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 封面图选择控件（支持 base64 data URL / http URL 预览）
class _CoverPicker extends ConsumerWidget {
  const _CoverPicker({required this.cover, required this.onChanged});
  final String cover;
  final ValueChanged<String> onChanged;

  Future<void> _pickCover(BuildContext context, WidgetRef ref) async {
    final tokens = ref.read(appThemeProvider).tokens;
    await showLumiraBottomSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '选择封面图',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
          ),
          LumiraListTile(
            leading: Icon(Icons.photo_outlined, color: tokens.brand),
            title: const Text('从相册选择'),
            onTap: () {
              Navigator.pop(ctx);
              _pickCoverFromGallery(context, ref);
            },
          ),
          LumiraListTile(
            leading: Icon(Icons.camera_alt_outlined, color: tokens.brand),
            title: const Text('拍照'),
            onTap: () {
              Navigator.pop(ctx);
              _pickCoverFromCamera(context, ref);
            },
          ),
          if (cover.isNotEmpty)
            LumiraListTile(
              leading: Icon(Icons.delete_outline, color: tokens.danger),
              title: Text('移除封面', style: TextStyle(color: tokens.danger)),
              onTap: () {
                Navigator.pop(ctx);
                onChanged('');
              },
            ),
          LumiraListTile(
            title: Center(
              child: Text('取消', style: TextStyle(color: tokens.textSecondary)),
            ),
            onTap: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCoverFromGallery(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final file = await FilePickerService.pickSingleImage();
      if (file == null) return;
      final fullFile = await FilePickerService.ensureFullBytes(file);
      final bytes = fullFile.bytes;
      if (bytes == null || bytes.isEmpty) {
        if (context.mounted) {
          LumiraToast.show(context, '读取图片失败，请重试');
        }
        return;
      }
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      onChanged(dataUrl);
      if (context.mounted) LumiraToast.show(context, '封面图已设置');
    } catch (e) {
      if (context.mounted) {
        LumiraToast.show(context, '设置封面图失败：$e');
      }
    }
  }

  Future<void> _pickCoverFromCamera(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // OHOS: image_picker 无 OHOS 实现，提示从相册选择
    if (Platform.operatingSystem == 'ohos') {
      if (context.mounted) {
        LumiraToast.show(context, '当前系统暂不支持系统拍照，请从相册选择');
      }
      return;
    }
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: ImageSource.camera);
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      onChanged(dataUrl);
      if (context.mounted) LumiraToast.show(context, '封面图已设置');
    } catch (e) {
      if (context.mounted) {
        LumiraToast.show(context, '设置封面图失败：$e');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '封面图',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _pickCover(context, ref),
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 140,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: tokens.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: tokens.divider,
                  width: 1,
                ),
              ),
              child: cover.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        _CoverImage(url: cover, fit: BoxFit.cover),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '点击更换封面',
                              style: TextStyle(fontSize: 11, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 32,
                          color: tokens.textTertiary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '点击添加封面图',
                          style: TextStyle(
                            fontSize: 13,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 渲染封面图：优先 base64 data URL，其次网络/路径地址。
/// 黑色半透明遮罩属于跨风格通用「叠加视觉」，符合设计规范。
class _CoverImage extends ConsumerWidget {
  const _CoverImage({required this.url, this.fit = BoxFit.cover});
  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    if (url.startsWith('data:image/')) {
      final bytes = _dataUrlBytes(url);
      if (bytes != null) {
        return Image.memory(
          bytes,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => Container(color: tokens.brand),
        );
      }
    }
    return CachedNetworkImage(
      url: url,
      fit: fit,
      errorWidget: Container(color: tokens.brand),
    );
  }

  static Uint8List? _dataUrlBytes(String url) {
    final comma = url.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(url.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }
}

class _PillOption {
  const _PillOption({required this.value, required this.label});
  final String value;
  final String label;
}

class _FormTextField extends StatefulWidget {
  const _FormTextField({
    required this.value,
    required this.placeholder,
    required this.onChanged,
    this.label,
    this.maxLength,
    this.maxLines = 1,
    this.padding,
    this.errorText,
  });

  final String? label;
  final String value;
  final String placeholder;
  final ValueChanged<String> onChanged;
  final int? maxLength;
  final int maxLines;
  final EdgeInsetsGeometry? padding;
  final String? errorText;

  @override
  State<_FormTextField> createState() => _FormTextFieldState();
}

class _FormTextFieldState extends State<_FormTextField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_FormTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.value) {
      _controller.text = widget.value;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding ?? const EdgeInsets.only(bottom: 16),
      child: LumiraTextField(
        controller: _controller,
        labelText: widget.label,
        hintText: widget.placeholder,
        maxLength: widget.maxLength,
        maxLines: widget.maxLines,
        errorText: widget.errorText,
        onChanged: widget.onChanged,
      ),
    );
  }
}

class _IconPicker extends ConsumerWidget {
  const _IconPicker({required this.selected, required this.onSelect});
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    const icons = CaptureSceneMockData.iconOptions;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '图标',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < icons.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => onSelect(icons[i]),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected == icons[i]
                            ? tokens.brand.withOpacity(0.12)
                            : tokens.surfaceAlt,
                        border: Border.all(
                          color: selected == icons[i]
                              ? tokens.brand
                              : Colors.transparent,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        CaptureSceneMockData.iconFromString(icons[i]),
                        size: 18,
                        color: selected == icons[i]
                            ? tokens.brand
                            : tokens.textPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PillPicker extends ConsumerWidget {
  const _PillPicker({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.allowToggle = false,
  });

  final String label;
  final List<_PillOption> options;
  final String selected;
  final ValueChanged<String> onSelect;
  final bool allowToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final isNeu = appTheme.style == UIStyle.neumorphic;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: options.map((o) {
              final active = o.value == selected;
              final labelStyle = TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w500 : FontWeight.normal,
                color: active
                    ? (isNeu ? tokens.brandText : tokens.brand)
                    : tokens.textSecondary,
              );

              return GestureDetector(
                onTap: () => onSelect(o.value),
                behavior: HitTestBehavior.opaque,
                child: isNeu && active
                    ? RecessedSurface(
                        tokens: tokens,
                        borderRadius: 9999,
                        depth: 0.7,
                        rimFraction: 0.32,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: Text(o.label, style: labelStyle),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          // neumorphic：方案 B 选中/未选中同为 surface，仅凸起↔凹陷翻转；品牌色只在文字
                          color: isNeu
                              ? tokens.surface
                              : (active
                                  ? tokens.brand.withOpacity(0.12)
                                  : tokens.surfaceAlt),
                          border: isNeu
                              ? null
                              : Border.all(
                                  color: active
                                      ? tokens.brand
                                      : Colors.transparent,
                                  width: 1,
                                ),
                          borderRadius: BorderRadius.circular(9999),
                          boxShadow: isNeu ? tokens.shadowConvexSubtle : null,
                        ),
                        child: Text(o.label, style: labelStyle),
                      ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ExampleImagesEditor extends ConsumerWidget {
  const _ExampleImagesEditor({required this.seeds, required this.onChange});
  final List<String> seeds;
  final void Function(int idx, String val) onChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '示例图（输入关键词，最多 3 张）',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          for (var idx = 0; idx < seeds.length; idx++)
            _FormTextField(
              value: seeds[idx],
              placeholder: '图 ${idx + 1} 关键词（如：cat）',
              onChanged: (v) => onChange(idx, v),
              padding: const EdgeInsets.only(bottom: 8),
            ),
        ],
      ),
    );
  }
}

class _TipsEditor extends ConsumerWidget {
  const _TipsEditor({required this.tipsText, required this.onChanged});
  final String tipsText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '拍摄贴士（每行一条）',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _FormTextField(
            value: tipsText,
            placeholder: '如：\n让模特侧对窗户\n白平衡偏暖一档',
            maxLines: 4,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _TagPicker extends ConsumerWidget {
  const _TagPicker({required this.selectedIds, required this.onToggle});
  final List<String> selectedIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    const tags = CaptureSceneMockData.tags;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '标签',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tags.map((t) {
              final selected = selectedIds.contains(t.id);
              return GestureDetector(
                onTap: () => onToggle(t.id),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? tokens.brand : tokens.surfaceAlt,
                    border: Border.all(
                      color: selected ? tokens.brand : Colors.transparent,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    t.name,
                    style: TextStyle(
                      fontSize: 13,
                      color: selected
                          ? tokens.textInverse
                          : tokens.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}