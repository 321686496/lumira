import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/capture_scene_mock_data.dart';

/// 场景管理页（Task 2.10）
///
/// 视觉规格来源：lumira-app/src/pages/capture/scene-manage.vue (1012 行)
/// - 顶部导航：返回 + 标题（场景管理）
/// - Tab 栏：我的收藏 / 自定义场景
/// - Tab 1（我的收藏）：收藏场景列表 + 取消收藏按钮 / 空状态
/// - Tab 2（自定义场景）：列表 + 新建场景按钮 / 新建-编辑表单
///
/// 简化决策（brief §8）：
/// - TagSelector：用内嵌 chip 多选列表代替
/// - ScenePresetView：直接渲染行内卡片，复用 mock 数据
/// - addCustomScene / updateCustomScene / deleteCustomScene：mock 内存修改，不持久化
/// - showActionSheet / showModal：用 LumiraAlertDialog + LumiraToast 代替
///
/// 注：组合套件功能已迁移至独立的 CompositionKitsPage（lib/features/profile/pages/composition_kits_page.dart），
/// 由 DB 持久化，本页不再承载 "我的组合" Tab。
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

  // 内存中的自定义场景与收藏（mock）
  late List<CustomScenePreset> _customScenes;
  late List<String> _favoriteIds;

  @override
  void initState() {
    super.initState();
    _tab = _parseTab(widget.initialTab);
    _formData = _SceneFormData.empty();
    _customScenes = [CaptureSceneMockData.customSceneExample];
    _favoriteIds = List<String>.from(CaptureSceneMockData.favoritePresetIds);
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
    GoRouter.of(context).push(RouteNames.captureSceneGuide);
  }

  /// 点击场景卡片跳转到场景详情页（带 sceneId）
  void _goSceneDetail(String sceneId) {
    GoRouter.of(context).push(
      RouteNames.withSceneId(RouteNames.captureSceneDetail, sceneId),
    );
  }

  // ===== 收藏 =====
  void _toggleFav(String id) {
    setState(() {
      if (_favoriteIds.contains(id)) {
        _favoriteIds.remove(id);
      } else {
        _favoriteIds.add(id);
      }
    });
    LumiraToast.show(
      context,
      _favoriteIds.contains(id) ? '已收藏场景' : '已取消收藏',
    );
  }

  // ===== 自定义场景 CRUD =====
  void _onNew() {
    setState(() {
      _editingId = null;
      _formData = _SceneFormData.empty();
      _formVisible = true;
      _formDirty = false;
    });
  }

  void _onEdit(CustomScenePreset scene) {
    setState(() {
      _editingId = scene.id;
      _formData = _SceneFormData.from(scene);
      _formVisible = true;
      _formDirty = false;
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
      });
    }
  }

  void _onSaveForm() {
    if (_formData.name.trim().isEmpty) {
      LumiraToast.show(context, '请输入场景名称');
      return;
    }
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

    if (_editingId != null) {
      // 编辑：找到现有并替换
      final idx = _customScenes.indexWhere((s) => s.id == _editingId);
      if (idx >= 0) {
        final old = _customScenes[idx];
        _customScenes[idx] = CustomScenePreset(
          id: old.id,
          name: _formData.name.trim(),
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
          bestTime: _formData.bestTime.trim(),
          sceneGuide: SceneGuide(
            lightDirection: _formData.lightDirection,
            shootingDistance: _formData.shootingDistance,
            background: _formData.background,
            props: const [],
            bestTime: _formData.bestTime.trim(),
            tips: tips,
          ),
          relatedCategory: _formData.relatedCategory,
          tagIds: List<String>.from(_formData.tagIds),
          createdAt: old.createdAt,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
      }
      LumiraToast.show(context, '已保存');
    } else {
      // 新建
      final newScene = CustomScenePreset(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: _formData.name.trim(),
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
        bestTime: _formData.bestTime.trim(),
        sceneGuide: SceneGuide(
          lightDirection: _formData.lightDirection,
          shootingDistance: _formData.shootingDistance,
          background: _formData.background,
          props: const [],
          bestTime: _formData.bestTime.trim(),
          tips: tips,
        ),
        relatedCategory: _formData.relatedCategory,
        tagIds: List<String>.from(_formData.tagIds),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      _customScenes.add(newScene);
      LumiraToast.show(context, '已创建');
    }
    setState(() {
      _formVisible = false;
      _editingId = null;
      _formDirty = false;
    });
  }

  void _onMore(CustomScenePreset scene) {
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
            leading: const Icon(Icons.delete_outline, color: Color(0xFFC9453D)),
            title: const Text('删除', style: TextStyle(color: Color(0xFFC9453D))),
            onTap: () {
              Navigator.of(ctx).pop();
              _confirmDelete(scene);
            },
          ),
        ],
      ),
    );
  }

  void _confirmDelete(CustomScenePreset scene) {
    LumiraAlertDialog.show<void>(
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
          onPressed: () {
            Navigator.of(context).pop();
            setState(() {
              _customScenes.removeWhere((s) => s.id == scene.id);
            });
            LumiraToast.show(context, '已删除');
          },
          child: const Text('删除'),
        ),
      ],
    );
  }

  void _onFormChange() {
    if (_formVisible && !_formDirty) {
      setState(() {
        _formDirty = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 硬编码颜色，与 uni-app 一致 (lumira-container bg #FAF7F2)
      backgroundColor: const Color(0xFFFAF7F2),
      body: SafeArea(
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
                      favoriteIds: _favoriteIds,
                      onToggleFav: _toggleFav,
                      onGoGuide: _goGuide,
                      onTapScene: (_) => _goGuide(),
                    )
                  : _formVisible
                      ? _CustomForm(
                          formData: _formData,
                          editingId: _editingId,
                          onChange: _onFormChange,
                          onCancel: _onCancelForm,
                          onSave: _onSaveForm,
                          onMutate: (fn) {
                            setState(fn);
                            _onFormChange();
                          },
                        )
                      : _CustomTab(
                          customScenes: _customScenes,
                          onNew: _onNew,
                          onMore: _onMore,
                          onTapScene: _goSceneDetail,
                        ),
            ),
            const SizedBox(height: 24), // bottom-spacer
          ],
        ),
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

class _TabPill extends StatelessWidget {
  const _TabPill({
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), // 40rpx/16rpx
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFC9A96E), Color(0xFFA88550)],
                )
              : null,
          color: active ? null : Colors.white,
          border: active
              ? Border.all(color: Colors.transparent, width: 1.5)
              : Border.all(color: const Color(0xFFEAE5DC), width: 1.5),
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14, // 28rpx → 14dp
            fontWeight: FontWeight.w500,
            color: active ? Colors.white : const Color(0xFF5C5852),
          ),
        ),
      ),
    );
  }
}

/// 通用空状态
class _EmptyState extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20), // 40rpx/80rpx
      child: Column(
        children: [
          Icon(
            icon,
            size: 40, // 80rpx → 40dp
            color: const Color(0xFF9C9690),
          ),
          const SizedBox(height: 12), // 24rpx → 12dp
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 6), // 12rpx → 6dp
          Text(
            desc,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xFF9C9690),
            ),
          ),
          if (btnText != null && onBtnTap != null) ...[
            const SizedBox(height: 20), // 40rpx → 20dp
            GestureDetector(
              onTap: onBtnTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFC9A96E), Color(0xFFA88550)],
                  ),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  btnText!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
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

/// Tab 1：我的收藏
class _FavTab extends StatelessWidget {
  const _FavTab({
    required this.favoriteIds,
    required this.onToggleFav,
    required this.onGoGuide,
    required this.onTapScene,
  });

  final List<String> favoriteIds;
  final ValueChanged<String> onToggleFav;
  final VoidCallback onGoGuide;
  final ValueChanged<String> onTapScene;

  @override
  Widget build(BuildContext context) {
    final favScenes = CaptureSceneMockData.presetScenes
        .where((p) => favoriteIds.contains(p.id))
        .toList();

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
                child: const Padding(
                  padding: EdgeInsets.all(4), // 8rpx → 4dp
                  child: Icon(
                    Icons.star,
                    size: 18, // 36rpx → 18dp
                    color: Color(0xFFC9A96E),
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
class _ScenePresetRow extends StatelessWidget {
  const _ScenePresetRow({
    required this.scene,
    required this.onTap,
    this.action,
  });

  final ScenePreset scene;
  final VoidCallback onTap;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final firstImage =
        scene.exampleImages.isNotEmpty ? scene.exampleImages.first : null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromRGBO(0, 0, 0, 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 80, // 160rpx → 80dp（固定行高，避免在 ScrollView 中 stretch 导致无限高度）
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 80, // 160rpx → 80dp
                height: 80,
              child: firstImage != null
                  ? Image.network(
                      firstImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color.fromRGBO(201, 168, 118, 0.12),
                      ),
                    )
                  : Container(
                      color: const Color.fromRGBO(201, 168, 118, 0.12),
                    ),
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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      scene.vibe,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF6B635A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (action != null) Padding(padding: const EdgeInsets.all(8), child: action!),
          ],
          ),
        ),
      ),
    );
  }
}

/// Tab 2：自定义场景列表
class _CustomTab extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.more_horiz,
                    size: 18,
                    color: Color(0xFF9C9690),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          // 新建场景按钮
          GestureDetector(
            onTap: onNew,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(16), // 32rpx → 16dp
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFFEAE5DC),
                  width: 1.5,
                ),
                color: Colors.white,
                borderRadius: BorderRadius.circular(12), // 24rpx → 12dp
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.add,
                    size: 18, // 36rpx → 18dp
                    color: Color(0xFFC9A96E),
                  ),
                  SizedBox(width: 6), // 12rpx → 6dp
                  Text(
                    '新建场景',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFC9A96E),
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

/// Tab 2 表单：新建/编辑场景
class _CustomForm extends StatelessWidget {
  const _CustomForm({
    required this.formData,
    required this.editingId,
    required this.onChange,
    required this.onCancel,
    required this.onSave,
    required this.onMutate,
  });

  final _SceneFormData formData;
  final String? editingId;
  final VoidCallback onChange;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final void Function(void Function() fn) onMutate;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Container(
        padding: const EdgeInsets.all(20), // 40rpx → 20dp
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14), // 28rpx → 14dp
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              offset: Offset(0, 4),
              blurRadius: 16,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              editingId != null ? '编辑场景' : '新建场景',
              style: const TextStyle(
                fontSize: 17, // 34rpx → 17dp
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 16), // 32rpx → 16dp
            _FormTextField(
              label: '场景名称',
              value: formData.name,
              placeholder: '如：夕阳人像',
              maxLength: 20,
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
              onSelect: (v) => onMutate(() {
                formData.relatedCategory = v;
              }),
            ),
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
                        color: const Color(0xFFF2EEE6),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '取消',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1A1A1A),
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
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFC9A96E), Color(0xFFA88550)],
                        ),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '保存',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
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
  });

  final String? label;
  final String value;
  final String placeholder;
  final ValueChanged<String> onChanged;
  final int? maxLength;
  final int maxLines;
  final EdgeInsetsGeometry? padding;

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
        onChanged: widget.onChanged,
      ),
    );
  }
}

class _IconPicker extends StatelessWidget {
  const _IconPicker({required this.selected, required this.onSelect});
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    const icons = CaptureSceneMockData.iconOptions;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '图标',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF5C5852),
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
                      width: 40, // 80rpx → 40dp
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected == icons[i]
                            ? const Color.fromRGBO(201, 169, 110, 0.12)
                            : const Color(0xFFF2EEE6),
                        border: Border.all(
                          color: selected == icons[i]
                              ? const Color(0xFFC9A96E)
                              : Colors.transparent,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        CaptureSceneMockData.iconFromString(icons[i]),
                        size: 18,
                        color: selected == icons[i]
                            ? const Color(0xFFC9A96E)
                            : const Color(0xFF1A1A1A),
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

class _PillPicker extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF5C5852),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: options.map((o) {
              final active = o.value == selected;
              return GestureDetector(
                onTap: () => onSelect(o.value),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color.fromRGBO(201, 169, 110, 0.12)
                        : const Color(0xFFF2EEE6),
                    border: Border.all(
                      color: active
                          ? const Color(0xFFC9A96E)
                          : Colors.transparent,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    o.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w500 : FontWeight.normal,
                      color: active
                          ? const Color(0xFFC9A96E)
                          : const Color(0xFF5C5852),
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

class _ExampleImagesEditor extends StatelessWidget {
  const _ExampleImagesEditor({required this.seeds, required this.onChange});
  final List<String> seeds;
  final void Function(int idx, String val) onChange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '示例图（输入关键词，最多 3 张）',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF5C5852),
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

class _TipsEditor extends StatelessWidget {
  const _TipsEditor({required this.tipsText, required this.onChanged});
  final String tipsText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '拍摄贴士（每行一条）',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF5C5852),
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

class _TagPicker extends StatelessWidget {
  const _TagPicker({required this.selectedIds, required this.onToggle});
  final List<String> selectedIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    const tags = CaptureSceneMockData.tags;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '标签',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF5C5852),
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
                    color: selected
                        ? const Color(0xFFC9A96E)
                        : const Color(0xFFF2EEE6),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFC9A96E)
                          : Colors.transparent,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    t.name,
                    style: TextStyle(
                      fontSize: 13,
                      color: selected ? Colors.white : const Color(0xFF5C5852),
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
