import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/utils/image_cache.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../features/capture/data/capture_scene_mock_data.dart';
import '../../../features/templates/data/templates_mock_data.dart';
import '../../../shared/widgets/lumira/lumira.dart' show LumiraListTile, LumiraSlider, LumiraTextField, LumiraToast, showLumiraBottomSheet;
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/shootkit_mock_data.dart';

/// ShootKit 组合编辑器页（Task 2.12）
///
/// 视觉规格来源：lumira-app/src/pages/shootkit/editor.vue (273 行)
/// - 顶部导航：返回 + 标题（新建组合 / 编辑组合）+ 保存按钮
/// - 表单区：
///   1. 组合名称输入框
///   2. 绑定场景（卡片展示当前场景，点击切换）
///   3. 选择模板（3 列网格，点击选中）
///   4. 参数覆盖（EV/WB/ISO 三个 slider，可选）
///   5. 预览（选中模板时展示模板封面）
/// - 保存逻辑：名称/场景/模板均必填，否则 SnackBar 提示
///
/// 简化决策（mock 阶段）：
/// - 不接入 localStorage 持久化，使用 ShootKitMockData 内存 List
/// - 场景选择：uni-app 源页仅展示绑定场景（无切换 UI），此处增加底部弹窗选择
///   （task brief §"关键功能还原" 要求场景选择区支持点击切换）
/// - 模板列表：复用 TemplatesMockData.otherTemplates（6 项）
/// - 场景列表：复用 CaptureSceneMockData.allScenes（7 项 = 1 custom + 6 preset）
class ShootkitEditorPage extends ConsumerStatefulWidget {
  const ShootkitEditorPage({
    super.key,
    this.kitId,
    this.sceneId,
  });

  /// 路由参数：kitId（编辑模式，加载已有组合）
  final String? kitId;

  /// 路由参数：sceneId（新建模式预绑定场景，对应 uni-app onLoad options.sceneId）
  final String? sceneId;

  @override
  ConsumerState<ShootkitEditorPage> createState() =>
      _ShootkitEditorPageState();
}

class _ShootkitEditorPageState extends ConsumerState<ShootkitEditorPage> {
  late String _kitId;
  late String _sceneId;
  late String _kitName;
  late String _selectedTemplateId;
  late CameraOverrides _overrides;

  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _kitId = widget.kitId ?? '';
    _sceneId = widget.sceneId ?? '';
    _kitName = '';
    _selectedTemplateId = '';
    _overrides = const CameraOverrides();

    // 编辑模式：加载已有组合
    // 若 kitId 无效（getKitById 返回 null），回退到新建模式（清空 _kitId 使 _isEdit 为 false）
    if (_kitId.isNotEmpty) {
      final kit = ShootKitMockData.getKitById(_kitId);
      if (kit != null) {
        _kitName = kit.name;
        _selectedTemplateId = kit.templateId;
        _sceneId = kit.sceneId;
        _overrides = kit.overrides;
      } else {
        _kitId = '';
      }
    }

    _nameController = TextEditingController(text: _kitName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _isEdit => _kitId.isNotEmpty;

  /// 当前绑定的场景对象（null 表示未选择）
  ScenePreset? get _boundScene =>
      CaptureSceneMockData.getSceneById(_sceneId);

  /// 当前选中的模板对象（null 表示未选择）
  TemplateItem? get _selectedTemplate {
    for (final t in TemplatesMockData.otherTemplates) {
      if (t.id == _selectedTemplateId) return t;
    }
    return null;
  }

  /// EV 显示文本（对应 uni-app evDisplay computed）
  /// null 或 0 显示 '0.00'；正数加 '+' 前缀
  String get _evDisplay {
    final ev = _overrides.exposureCompensation;
    if (ev == null || ev == 0) return '0.00';
    return (ev > 0 ? '+' : '') + ev.toStringAsFixed(2);
  }

  /// WB(K) 显示文本（null 显示默认 5500）
  String get _wbDisplay => _overrides.whiteBalanceK?.toString() ?? '5500';

  /// ISO 显示文本（null 显示 'AUTO'）
  String get _isoDisplay => _overrides.iso?.toString() ?? 'AUTO';

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.of(context).go(RouteNames.home);
    }
  }

  void _onSave() {
    if (_kitName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写组合名称')),
      );
      return;
    }
    if (_sceneId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未绑定场景')),
      );
      return;
    }
    if (_selectedTemplateId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择模板')),
      );
      return;
    }

    final hasOverrides = _overrides.isNotEmpty;
    final overrides = hasOverrides ? _overrides : CameraOverrides.empty;

    if (_isEdit) {
      ShootKitMockData.updateKit(
        _kitId,
        name: _kitName.trim(),
        sceneId: _sceneId,
        templateId: _selectedTemplateId,
        overrides: overrides,
      );
    } else {
      ShootKitMockData.createKit(
        name: _kitName.trim(),
        sceneId: _sceneId,
        templateId: _selectedTemplateId,
        overrides: overrides,
      );
    }

    LumiraToast.show(context, '保存成功');

    // 对应 uni-app setTimeout(() => uni.navigateBack(), 600)
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        GoRouter.of(context).go(RouteNames.home);
      }
    });
  }

  void _onResetOverrides() {
    setState(() {
      _overrides = const CameraOverrides();
    });
    LumiraToast.show(context, '参数已重置');
  }

  void _openScenePicker() {
    final tokens = ref.read(themeTokensProvider);
    showLumiraBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final scenes = CaptureSceneMockData.allScenes;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '选择场景',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              for (final scene in scenes)
                LumiraListTile(
                  leading: Icon(
                    CaptureSceneMockData.iconFromString(scene.icon),
                    color: tokens.brand,
                  ),
                  title: Text(scene.name),
                  trailing: _sceneId == scene.id
                      ? Icon(Icons.check, color: tokens.brand)
                      : null,
                  onTap: () {
                    setState(() {
                      _sceneId = scene.id;
                    });
                    Navigator.of(ctx).pop();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: Column(
          children: [
            LumiraNav(
              title: _isEdit ? '编辑组合' : '新建组合',
              transparent: true,
              leading: _BackButton(tokens: tokens, onTap: _back),
              actions: [
                _SaveNavButton(tokens: tokens, onTap: _onSave),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _NameSection(
                      tokens: tokens,
                      controller: _nameController,
                      onChanged: (v) => setState(() => _kitName = v),
                    ),
                    _BoundSceneSection(
                      tokens: tokens,
                      scene: _boundScene,
                      onTap: _openScenePicker,
                    ),
                    _TemplateGridSection(
                      tokens: tokens,
                      selectedId: _selectedTemplateId,
                      onSelect: (id) =>
                          setState(() => _selectedTemplateId = id),
                    ),
                    _OverridesSection(
                      tokens: tokens,
                      overrides: _overrides,
                      evDisplay: _evDisplay,
                      wbDisplay: _wbDisplay,
                      isoDisplay: _isoDisplay,
                      onEvChange: (v) => setState(() {
                        _overrides = _overrides.copyWith(
                          exposureCompensation: v,
                        );
                      }),
                      onWbChange: (v) => setState(() {
                        _overrides = _overrides.copyWith(
                          whiteBalanceK: v.round(),
                        );
                      }),
                      onIsoChange: (v) => setState(() {
                        _overrides = _overrides.copyWith(
                          iso: v.round(),
                        );
                      }),
                      onReset: _onResetOverrides,
                    ),
                    if (_selectedTemplate != null)
                      _PreviewSection(
                        tokens: tokens,
                        template: _selectedTemplate!,
                      ),
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

// ============================================================
// 导航按钮
// ============================================================

class _BackButton extends StatelessWidget {
  const _BackButton({required this.tokens, required this.onTap});
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Icons.arrow_back_ios_new,
          size: 20,
          color: tokens.textPrimary,
        ),
      ),
    );
  }
}

class _SaveNavButton extends StatelessWidget {
  const _SaveNavButton({required this.tokens, required this.onTap});
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Center(
          child: Text(
            '保存',
            style: TextStyle(
              fontSize: 14, // 28rpx → 14dp
              fontWeight: FontWeight.w600,
              color: tokens.brand,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 表单分区
// ============================================================

/// 通用分区容器（对应 uni-app .form-section）
class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.tokens,
    required this.label,
    required this.child,
  });

  final ThemeTokens tokens;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16), // 48rpx/24rpx/32rpx
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: tokens.divider, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13, // 26rpx → 13dp
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 8), // 16rpx → 8dp
          child,
        ],
      ),
    );
  }
}

/// 1. 组合名称
class _NameSection extends StatelessWidget {
  const _NameSection({
    required this.tokens,
    required this.controller,
    required this.onChanged,
  });

  final ThemeTokens tokens;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return _FormSection(
      tokens: tokens,
      label: '组合名称',
      child: LumiraTextField(
        controller: controller,
        hintText: '给这个组合起个名字',
        onChanged: onChanged,
      ),
    );
  }
}

/// 2. 绑定场景
class _BoundSceneSection extends StatelessWidget {
  const _BoundSceneSection({
    required this.tokens,
    required this.scene,
    required this.onTap,
  });

  final ThemeTokens tokens;
  final ScenePreset? scene;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _FormSection(
      tokens: tokens,
      label: '绑定场景',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: tokens.canvasDeep,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                scene == null
                    ? Icons.help_outline
                    : CaptureSceneMockData.iconFromString(scene!.icon),
                size: 18, // 32rpx → 16dp（实际 18 视觉更平衡）
                color: tokens.brand,
              ),
              const SizedBox(width: 8), // 16rpx → 8dp
              Expanded(
                child: Text(
                  scene?.name ?? '未选择',
                  style: TextStyle(
                    fontSize: 14,
                    color: scene != null
                        ? tokens.textPrimary
                        : tokens.textTertiary,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: tokens.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 3. 模板网格
class _TemplateGridSection extends StatelessWidget {
  const _TemplateGridSection({
    required this.tokens,
    required this.selectedId,
    required this.onSelect,
  });

  final ThemeTokens tokens;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    const templates = TemplatesMockData.otherTemplates;

    return _FormSection(
      tokens: tokens,
      label: '选择模板',
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 8, // 16rpx → 8dp
        crossAxisSpacing: 8,
        childAspectRatio: 0.72, // 卡片宽高比（图片 160rpx + 文字）
        children: [
          for (final tpl in templates)
            _TemplateCard(
              tokens: tokens,
              template: tpl,
              selected: tpl.id == selectedId,
              onTap: () => onSelect(tpl.id),
            ),
        ],
      ),
    );
  }
}

class _TemplateCard extends ConsumerWidget {
  const _TemplateCard({
    required this.tokens,
    required this.template,
    required this.selected,
    required this.onTap,
  });

  final ThemeTokens tokens;
  final TemplateItem template;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNeu = ref.watch(uiStyleProvider) == UIStyle.neumorphic;
    final coverUrl =
        'https://picsum.photos/seed/${template.imageSeed}/200/200';
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(6), // 12rpx → 6dp
          border: selected
              ? Border.all(color: tokens.brand, width: 1.5)
              : (isNeu ? null : Border.all(color: Colors.transparent, width: 1.5)),
          boxShadow: isNeu && !selected ? tokens.shadowConvexSubtle : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: CachedNetworkImage(
                url: coverUrl,
                fit: BoxFit.cover,
                errorWidget: Container(
                  color: tokens.brandSubtle,
                  child: Icon(
                    Icons.image_outlined,
                    size: 28,
                    color: tokens.textTertiary,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4), // 8rpx → 4dp
              child: Text(
                template.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11, // 22rpx → 11dp
                  color: tokens.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 4. 参数覆盖
class _OverridesSection extends StatelessWidget {
  const _OverridesSection({
    required this.tokens,
    required this.overrides,
    required this.evDisplay,
    required this.wbDisplay,
    required this.isoDisplay,
    required this.onEvChange,
    required this.onWbChange,
    required this.onIsoChange,
    required this.onReset,
  });

  final ThemeTokens tokens;
  final CameraOverrides overrides;
  final String evDisplay;
  final String wbDisplay;
  final String isoDisplay;
  final ValueChanged<double> onEvChange;
  final ValueChanged<double> onWbChange;
  final ValueChanged<double> onIsoChange;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return _FormSection(
      tokens: tokens,
      label: '参数覆盖（可选）',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SliderRow(
            tokens: tokens,
            label: 'EV',
            value: overrides.exposureCompensation ?? 0.0,
            min: -3,
            max: 3,
            divisions: 120, // step 0.05
            valueText: evDisplay,
            onChanged: onEvChange,
          ),
          _SliderRow(
            tokens: tokens,
            label: 'WB(K)',
            value: (overrides.whiteBalanceK ?? 5500).toDouble(),
            min: 2000,
            max: 10000,
            divisions: 160, // step 50
            valueText: wbDisplay,
            onChanged: onWbChange,
          ),
          _SliderRow(
            tokens: tokens,
            label: 'ISO',
            value: (overrides.iso ?? 100).toDouble(),
            min: 100,
            max: 6400,
            divisions: 126, // step 50
            valueText: isoDisplay,
            onChanged: onIsoChange,
          ),
          const SizedBox(height: 8),
          // 重置按钮（对应 uni-app 任务说明 "保存/重置按钮"）
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onReset,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(9999),
                  boxShadow: tokens.shadowConvexSubtle,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh,
                      size: 14,
                      color: tokens.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '重置',
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textSecondary,
                      ),
                    ),
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

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.tokens,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueText,
    required this.onChanged,
  });

  final ThemeTokens tokens;
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueText;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(
            width: 48, // 80rpx → 40dp（视觉平衡用 48）
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: tokens.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: LumiraSlider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 56, // 100rpx → 50dp（视觉平衡用 56）
            child: Text(
              valueText,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                color: tokens.textPrimary,
                fontFamily: 'SF Mono',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 5. 预览区（选中模板时展示模板封面）
class _PreviewSection extends StatelessWidget {
  const _PreviewSection({
    required this.tokens,
    required this.template,
  });

  final ThemeTokens tokens;
  final TemplateItem template;

  @override
  Widget build(BuildContext context) {
    final coverUrl =
        'https://picsum.photos/seed/${template.imageSeed}/600/400';
    return _FormSection(
      tokens: tokens,
      label: '预览',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8), // 16rpx → 8dp
        child: AspectRatio(
          aspectRatio: 3 / 2,
          child: CachedNetworkImage(
            url: coverUrl,
            fit: BoxFit.cover,
            errorWidget: Container(
              color: tokens.brandSubtle,
              child: Icon(
                Icons.image_outlined,
                size: 40,
                color: tokens.textTertiary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
