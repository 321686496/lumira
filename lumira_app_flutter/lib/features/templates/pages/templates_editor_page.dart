import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/dao/templates_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/lumira/lumira.dart' as lumira;
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../profile/pages/profile_my_templates_page.dart' show customTemplatesProvider;
import '../data/preview_form_provider.dart';
import '../data/templates_browse_mock_data.dart' show LabelValue, styleMap, methodMap;
import '../data/builtin_silhouettes.dart';
import '../data/templates_editor_mock_data.dart';
import '../services/template_exporter.dart';
import '../services/template_mapper.dart';
import '../widgets/composition_overlay.dart';
import '../widgets/pose_silhouette.dart';
import '../widgets/silhouette_editor.dart';

/// 选项对（label/value）
class EditorOption {
  const EditorOption(this.value, this.label);
  final String value;
  final String label;
}

// ===== 选项数组（editor.vue lines 819-888 verbatim） =====

const List<EditorOption> categoryOptions = [
  EditorOption('portrait', '人像'),
  EditorOption('landscape', '风光'),
  EditorOption('food', '美食'),
  EditorOption('night', '夜景'),
  EditorOption('street', '街拍'),
  EditorOption('macro', '微距'),
  EditorOption('still-life', '静物'),
];

const List<EditorOption> overlayTypeOptions = [
  EditorOption('rule_of_thirds', '三分法'),
  EditorOption('golden_ratio', '黄金比例'),
  EditorOption('diagonal', '对角线'),
  EditorOption('grid', '网格'),
  EditorOption('leading_lines', '引导线'),
  EditorOption('center', '中心构图'),
  EditorOption('none', '无'),
];

const List<EditorOption> silhouetteSourceOptions = [
  EditorOption('builtin', '内置库'),
  EditorOption('image', '导入图片'),
  EditorOption('svg', '绘制剪影'),
];

const List<EditorOption> whiteBalanceOptions = [
  EditorOption('daylight', '日光'),
  EditorOption('cloudy', '阴天'),
  EditorOption('shade', '阴影'),
  EditorOption('tungsten', '白炽灯'),
  EditorOption('fluorescent', '荧光灯'),
  EditorOption('custom', '自定义'),
];

const List<EditorOption> flashModeOptions = [
  EditorOption('off', '关闭'),
  EditorOption('on', '开启'),
  EditorOption('auto', '自动'),
  EditorOption('torch', '常亮'),
];

const List<EditorOption> focusModeOptions = [
  EditorOption('auto', '自动'),
  EditorOption('manual', '手动'),
  EditorOption('continuous', '连续'),
];

const List<EditorOption> lensOptions = [
  EditorOption('wide', '广角'),
  EditorOption('main', '主摄'),
  EditorOption('telephoto', '长焦'),
  EditorOption('ultra_wide', '超广角'),
];

const List<EditorOption> isoModeOptions = [
  EditorOption('auto', '自动'),
  EditorOption('manual', '手动'),
];

const List<EditorOption> lutOptions = [
  EditorOption('none', '无'),
  EditorOption('cinematic', '电影感'),
  EditorOption('vintage', '复古'),
  EditorOption('bw', '黑白'),
  EditorOption('warm_film', '暖色胶片'),
  EditorOption('cool_film', '冷色胶片'),
  EditorOption('pastel', '柔色'),
  EditorOption('fuji', '富士'),
];

/// 模板编辑器页
///
/// 视觉规格来源：lumira-app/src/pages/templates/editor.vue (1534 行)
/// 6 个 step：模板信息 / 构图叠图 / 姿势剪影 / 相机参数 / 场景指南 / 后期参数
/// + footer（草稿/预览/保存/导出）+ auto-save（1000ms debounce）+ pose drag
class TemplatesEditorPage extends ConsumerStatefulWidget {
  const TemplatesEditorPage({
    super.key,
    this.templateId,
    this.draftId,
  });

  /// 路由参数：templateId（编辑已有模板）或 draftId（恢复草稿），二选一或都为 null（新建）
  final String? templateId;
  final String? draftId;

  @override
  ConsumerState<TemplatesEditorPage> createState() =>
      _TemplatesEditorPageState();
}

class _TemplatesEditorPageState extends ConsumerState<TemplatesEditorPage> {
  late EditorForm _form;
  bool _isEditMode = false;
  String _currentDraftId = '';
  Timer? _autoSaveTimer;
  final ScrollController _scrollController = ScrollController();

  // 文本缓冲（数组字段与输入框双向同步）
  late TextEditingController _tagsController;
  late TextEditingController _propsController;
  late TextEditingController _tipsController;

  // 姿势预览拖动状态
  bool _isDraggingPose = false;

  // Bug 11 修复：用 ValueNotifier 通知剪影位置变化，避免拖动时整个 page rebuild
  // 拖动时只更新此 notifier，剪影预览部分用 ValueListenableBuilder 监听并重建
  late final ValueNotifier<Offset> _posePositionNotifier;

  @override
  void initState() {
    super.initState();
    _form = _loadInitialForm();
    _isEditMode = widget.templateId != null &&
        TemplatesEditorMockData.loadTemplateById(widget.templateId) != null;
    _tagsController =
        TextEditingController(text: _form.meta.tags.join(', '));
    _propsController =
        TextEditingController(text: _form.sceneGuide.props.join(', '));
    _tipsController =
        TextEditingController(text: _form.sceneGuide.tips.join('\n'));
    _posePositionNotifier = ValueNotifier(
      Offset(_form.pose.position.x, _form.pose.position.y),
    );
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _scrollController.dispose();
    _tagsController.dispose();
    _propsController.dispose();
    _tipsController.dispose();
    _posePositionNotifier.dispose();
    super.dispose();
  }

  /// 同步 pose position 到 notifier（在所有修改 _form.pose.position 的地方调用）
  void _syncPosePosition() {
    _posePositionNotifier.value =
        Offset(_form.pose.position.x, _form.pose.position.y);
  }

  EditorForm _loadInitialForm() {
    if (widget.templateId != null) {
      final tpl = TemplatesEditorMockData.loadTemplateById(widget.templateId);
      if (tpl != null) return tpl;
    }
    if (widget.draftId != null) {
      final draft = TemplatesEditorMockData.loadDraftById(widget.draftId);
      if (draft != null) {
        _currentDraftId = widget.draftId!;
        return draft;
      }
    }
    return createBlankEditorForm();
  }

  // ===== 表单变更处理 =====

  void _onChange(void Function() mutator) {
    setState(mutator);
    _scheduleAutoSave();
  }

  void _onTagsChanged(String text) {
    _form.meta.tags =
        text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    _scheduleAutoSave();
  }

  void _onPropsChanged(String text) {
    _form.sceneGuide.props =
        text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    _scheduleAutoSave();
  }

  void _onTipsChanged(String text) {
    _form.sceneGuide.tips = text
        .split('\n')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    _scheduleAutoSave();
  }

  void _onIsoInput(String text) {
    final value = int.tryParse(text) ?? 0;
    _onChange(() => _form.camera.iso = value);
  }

  void _onWbKInput(String text) {
    final value = int.tryParse(text) ?? 0;
    _onChange(() => _form.camera.whiteBalanceK = value);
  }

  void _onSilhouetteSourceChange(String type) {
    setState(() {
      _form.pose.silhouette.type = type;
      if (type == 'builtin') {
        _form.pose.silhouette.data = 'none';
      } else {
        _form.pose.silhouette.data = '';
      }
      _form.pose.silhouette.filename = null;
      _form.pose.silhouette.sizeKB = null;
    });
    _scheduleAutoSave();
  }

  void _selectBuiltinSilhouette(String key) {
    _onChange(() => _form.pose.silhouette.data = key);
  }

  void _importSilhouetteImage() {
    // 简化：mock 上传成功，设置固定的 filename 和 sizeKB
    // 真实实现在 Task 2.9+ 接入 file_picker
    setState(() {
      _form.pose.silhouette = SilhouetteResource(
        type: 'image',
        data: '', // 真实场景为 base64 data URL
        filename: 'silhouette.png',
        sizeKB: 24,
      );
    });
    lumira.LumiraToast.show(context, '图片已导入（mock）');
    _scheduleAutoSave();
  }

  void _openSilhouetteEditor() {
    showDialog<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Center(
          child: SilhouetteEditorDialog(
            onComplete: (svg) {
              setState(() {
                _form.pose.silhouette =
                    SilhouetteResource(type: 'svg', data: svg);
              });
              if (!mounted) return;
              Navigator.pop(ctx);
              lumira.LumiraToast.show(context, '剪影已保存');
              _scheduleAutoSave();
            },
          ),
        ),
      ),
    );
  }

  // ===== 姿势预览拖动 =====

  void _onPoseDragStart(DragStartDetails details) {
    setState(() => _isDraggingPose = true);
  }

  void _onPoseDragUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (!_isDraggingPose) return;
    // Bug 11 修复：拖动时不调用 setState（避免整个 page rebuild），
    // 只更新 _form 和 _posePositionNotifier，让 ValueListenableBuilder 局部重建
    final dx = details.delta.dx / constraints.maxWidth;
    final dy = details.delta.dy / constraints.maxHeight;
    _form.pose.position.x =
        (_form.pose.position.x + dx).clamp(0.0, 1.0);
    _form.pose.position.y =
        (_form.pose.position.y + dy).clamp(0.0, 1.0);
    _syncPosePosition();
  }

  void _onPoseDragEnd(DragEndDetails details) {
    setState(() => _isDraggingPose = false);
    _scheduleAutoSave();
  }

  /// 位置 X/Y 滑块变化时同步到 notifier（避免拖动滑块时预览不更新）
  void _onPosePositionSliderChanged(bool isX, double v) {
    _onChange(() {
      if (isX) {
        _form.pose.position.x = v;
      } else {
        _form.pose.position.y = v;
      }
    });
    _syncPosePosition();
  }

  // ===== 自动保存草稿（debounce 1000ms） =====

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 1000), () {
      // mock 自动保存（Task 2.9+ 接入真实 DAO）
      if (_currentDraftId.isEmpty) {
        _currentDraftId =
            'draft-editor-${DateTime.now().millisecondsSinceEpoch}';
      }
    });
  }

  // ===== Footer 操作 =====

  Future<void> _onSave() async {
    if (_form.meta.name.trim().isEmpty) {
      lumira.LumiraToast.show(context, '请输入模板名称');
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    // 编辑模式复用 templateId；新建模式生成 user_<timestamp> 作为持久化主键
    final id = widget.templateId ?? 'user_$now';
    final record = TemplateRecord(
      id: id,
      name: _form.meta.name.trim(),
      author: 'user',
      version: '1.0.0',
      category: _form.meta.category,
      classification: {
        'type': _form.meta.category,
      },
      tags: _form.meta.tags,
      tagIds: const [],
      price: 0,
      cover: '',
      description: _form.meta.description,
      referenceSource: _form.meta.referenceSource,
      composition: {
        'overlayType': _form.composition.overlayType,
        'aspectRatio': _form.composition.aspectRatio,
        'opacity': _form.composition.opacity,
        'description': _form.composition.description,
      },
      pose: {
        'silhouette': {
          'type': _form.pose.silhouette.type,
          'data': _form.pose.silhouette.data,
          'filename': _form.pose.silhouette.filename,
          'sizeKB': _form.pose.silhouette.sizeKB,
        },
        'position': {
          'x': _form.pose.position.x,
          'y': _form.pose.position.y,
        },
        'scale': _form.pose.scale,
        'rotation': _form.pose.rotation,
        'description': _form.pose.description,
      },
      camera: {
        'exposureCompensation': _form.camera.exposureCompensation,
        'isoMode': _form.camera.isoMode,
        'iso': _form.camera.iso,
        'shutterSpeed': _form.camera.shutterSpeed,
        'whiteBalance': _form.camera.whiteBalance,
        'whiteBalanceK': _form.camera.whiteBalanceK,
        'flashMode': _form.camera.flashMode,
        'focusMode': _form.camera.focusMode,
        'lens': _form.camera.lensSuggestion,
      },
      sceneGuide: {
        'lightDirection': _form.sceneGuide.lightDirection,
        'shootingDistance': _form.sceneGuide.shootingDistance,
        'background': _form.sceneGuide.background,
        'props': _form.sceneGuide.props,
        'bestTime': _form.sceneGuide.bestTime,
        'tips': _form.sceneGuide.tips,
      },
      postProcess: {
        'cropRatio': _form.postProcess.cropRatio,
        'lut': _form.postProcess.lut,
        'color': {
          'brightness': _form.postProcess.color.brightness,
          'contrast': _form.postProcess.color.contrast,
          'saturation': _form.postProcess.color.saturation,
          'temperature': _form.postProcess.color.temperature,
          'tint': _form.postProcess.color.tint,
        },
        'smoothStrength': _form.postProcess.smoothStrength,
        'sharpen': _form.postProcess.sharpen,
        'vignette': _form.postProcess.vignette,
        'grain': _form.postProcess.grain,
      },
      createdAt: now,
      updatedAt: now,
      isBuiltin: false,
      isRecommended: false,
    );

    try {
      final dao = await ref.read(templatesDaoProvider.future);
      await dao.upsert(record);
      // 刷新 My Templates 页数据源，使新保存的模板立即出现
      ref.invalidate(customTemplatesProvider);
      _currentDraftId = '';
      if (!mounted) return;
      lumira.LumiraToast.show(context, '保存成功');
      // 800ms 后返回上一页（与 uni-app setTimeout 一致）
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        GoRouter.of(context).go(RouteNames.templates);
      }
    } catch (e) {
      if (!mounted) return;
      lumira.LumiraToast.show(context, '保存失败：$e');
    }
  }

  void _onSaveDraft() {
    // 简化：mock 草稿保存
    if (_currentDraftId.isEmpty) {
      _currentDraftId =
          'draft-editor-${DateTime.now().millisecondsSinceEpoch}';
    }
    lumira.LumiraToast.show(context, '草稿已保存');
  }

  Future<void> _onExport() async {
    if (_form.meta.name.trim().isEmpty) {
      lumira.LumiraToast.show(context, '请先填写模板名称');
      return;
    }

    // 将 EditorForm 转为 TemplateRecord
    final now = DateTime.now().millisecondsSinceEpoch;
    final record = TemplateMapper.fromEditorForm(
      _form,
      id: _form.meta.id.isEmpty ? null : _form.meta.id,
      createdAt: now,
    );

    if (!mounted) return;
    await _showExportFormatSheet(context, record);
  }

  Future<void> _showExportFormatSheet(
      BuildContext context, TemplateRecord record) async {
    final tokens = ref.watch(themeTokensProvider);

    final result = await lumira.showLumiraBottomSheet<String>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '选择导出格式',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
          ),
          lumira.LumiraListTile(
            leading: Icon(Icons.description_outlined, color: tokens.brand),
            title: const Text('完整 .pptpl（推荐）'),
            subtitle: const Text('含构图/姿势/相机/场景/后期全参数'),
            onTap: () => Navigator.pop(ctx, 'pptpl'),
          ),
          lumira.LumiraListTile(
            leading: Icon(Icons.code_outlined, color: tokens.brand),
            title: const Text('简化 .lumira'),
            subtitle: const Text('仅元信息+相机核心参数'),
            onTap: () => Navigator.pop(ctx, 'lumira'),
          ),
          lumira.LumiraListTile(
            title: Center(
              child: Text('取消',
                  style: TextStyle(color: tokens.textSecondary)),
            ),
            onTap: () => Navigator.pop(ctx, null),
          ),
        ],
      ),
    );

    if (result == null) return;
    if (!mounted) return;

    final usePptpl = result == 'pptpl';
    lumira.LumiraToast.show(context, '正在导出 ${record.name}...');

    try {
      await TemplateExporter.shareTemplate(record, usePptpl: usePptpl);
      if (!mounted) return;
      lumira.LumiraToast.show(context, '已分享 ${record.name}');
    } catch (e) {
      if (!mounted) return;
      lumira.LumiraToast.show(context, '导出失败：$e');
    }
  }

  Future<void> _onPreview() async {
    // Bug 12 修复：将当前 _form 的副本写入 previewEditorFormProvider，
    // 让预览页能直接读取真实编辑器表单（而非 mock 数据）
    if (_currentDraftId.isEmpty) {
      _currentDraftId =
          'draft-editor-${DateTime.now().millisecondsSinceEpoch}';
    }
    ref.read(previewEditorFormProvider.notifier).state = _form.copy();

    // 跳转预览页（capture/preview-template?draftId=xxx）
    // await push 返回后，从 provider 读取用户在预览页修改后的 form
    await GoRouter.of(context)
        .push('/capture/preview-template?draftId=$_currentDraftId');

    if (!mounted) return;

    // 读取预览页同步回来的 EditorForm
    final syncedForm = ref.read(previewEditorFormProvider);
    if (syncedForm != null) {
      // 将修改后的 form 复制回 _form（深拷贝避免后续 mutation 污染）
      _form = syncedForm.copy();
      // 同步 notifier（让剪影预览的位置滑块立即反映新值）
      _syncPosePosition();
      // 同步文本控制器
      _tagsController.text = _form.meta.tags.join(', ');
      _propsController.text = _form.sceneGuide.props.join(', ');
      _tipsController.text = _form.sceneGuide.tips.join('\n');
      // 触发重建 + 自动保存
      setState(() {});
      _scheduleAutoSave();
      // 清空 provider，避免下次预览复用旧数据
      ref.read(previewEditorFormProvider.notifier).state = null;

      if (mounted) {
        lumira.LumiraToast.show(context, '已从预览页同步参数');
      }
    }
  }

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.of(context).go(RouteNames.templates);
    }
  }

  void _goDrafts() {
    GoRouter.of(context).push(RouteNames.templatesDrafts);
  }

  String get _pageTitle => _isEditMode ? '编辑模板' : '新建模板';

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          _BackgroundDecoration(tokens: tokens),
          SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: [
                LumiraNav(
                  title: _pageTitle,
                  transparent: true,
                  leading: _BackButton(tokens: tokens, onTap: _back),
                  actions: [
                    _DraftsNavButton(tokens: tokens, onTap: _goDrafts),
                  ],
                ),
                Expanded(
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Step1TemplateInfo(
                              tokens: tokens,
                              form: _form,
                              tagsController: _tagsController,
                              onTagsChanged: _onTagsChanged,
                              onChange: _onChange,
                            ),
                            const SizedBox(height: 12),
                            _Step2Composition(
                              tokens: tokens,
                              form: _form,
                              onChange: _onChange,
                            ),
                            const SizedBox(height: 12),
                            _Step3Pose(
                              tokens: tokens,
                              form: _form,
                              isDragging: _isDraggingPose,
                              posePositionNotifier: _posePositionNotifier,
                              onSourceChange: _onSilhouetteSourceChange,
                              onSelectBuiltin: _selectBuiltinSilhouette,
                              onImportImage: _importSilhouetteImage,
                              onOpenEditor: _openSilhouetteEditor,
                              onChange: _onChange,
                              onPoseDragStart: _onPoseDragStart,
                              onPoseDragUpdate: _onPoseDragUpdate,
                              onPoseDragEnd: _onPoseDragEnd,
                              onPosePositionSliderChanged:
                                  _onPosePositionSliderChanged,
                            ),
                            const SizedBox(height: 12),
                            _Step4Camera(
                              tokens: tokens,
                              form: _form,
                              onChange: _onChange,
                              onIsoInput: _onIsoInput,
                              onWbKInput: _onWbKInput,
                            ),
                            const SizedBox(height: 12),
                            _Step5SceneGuide(
                              tokens: tokens,
                              form: _form,
                              propsController: _propsController,
                              tipsController: _tipsController,
                              onPropsChanged: _onPropsChanged,
                              onTipsChanged: _onTipsChanged,
                              onChange: _onChange,
                            ),
                            const SizedBox(height: 12),
                            _Step6PostProcess(
                              tokens: tokens,
                              form: _form,
                              onChange: _onChange,
                            ),
                          ],
                        ),
                      ),
                      _EditorFooter(
                        tokens: tokens,
                        isExportVisible: _isEditMode && _form.meta.id.isNotEmpty,
                        onSaveDraft: _onSaveDraft,
                        onPreview: _onPreview,
                        onSave: _onSave,
                        onExport: _onExport,
                      ),
                    ],
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
                tokens.canvas.withOpacity(0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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

class _DraftsNavButton extends StatelessWidget {
  const _DraftsNavButton({required this.tokens, required this.onTap});
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
          Icons.edit_note,
          size: 22,
          color: tokens.textSecondary,
        ),
      ),
    );
  }
}

// ===== 通用 Step 卡片 + 字段组件 =====

class _StepCard extends ConsumerWidget {
  const _StepCard({
    required this.tokens,
    required this.stepNumber,
    required this.title,
    required this.child,
    this.delay = Duration.zero,
  });

  final ThemeTokens tokens;
  final int stepNumber;
  final String title;
  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNeumorphic = ref.watch(uiStyleProvider) == UIStyle.neumorphic;
    return FadeUp(
      delay: delay,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          // neumorphic 风格下：tokens.canvas 改为 tokens.surface，移除 border
          color: isNeumorphic ? tokens.surface : tokens.canvas,
          borderRadius: BorderRadius.circular(14),
          border: isNeumorphic
              ? null
              : Border.all(color: tokens.divider, width: 0.5),
          boxShadow: tokens.shadowConvex,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: tokens.brand,
                    shape: BoxShape.circle,
                    boxShadow: tokens.shadowConvexBrand,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$stepNumber',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Noto Serif SC',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.tokens, required this.text});
  final ThemeTokens tokens;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: tokens.textSecondary,
        ),
      ),
    );
  }
}

class _FieldInput extends StatefulWidget {
  const _FieldInput({
    required this.tokens,
    this.controller,
    this.initialValue,
    this.placeholder,
    this.multiline = false,
    this.keyboardType,
    this.onChanged,
  });

  final ThemeTokens tokens;
  final TextEditingController? controller;
  final String? initialValue;
  final String? placeholder;
  final bool multiline;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  State<_FieldInput> createState() => _FieldInputState();
}

class _FieldInputState extends State<_FieldInput> {
  late TextEditingController _internalController;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _internalController = widget.controller!;
      _ownsController = false;
    } else {
      _internalController = TextEditingController(text: widget.initialValue);
      _ownsController = true;
    }
  }

  @override
  void dispose() {
    if (_ownsController) _internalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return lumira.LumiraTextField(
      controller: _internalController,
      hintText: widget.placeholder,
      keyboardType: widget.keyboardType,
      onChanged: widget.onChanged,
      maxLines: widget.multiline ? 8 : 1,
    );
  }
}

class _FieldDropdown extends StatelessWidget {
  const _FieldDropdown({
    required this.tokens,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final ThemeTokens tokens;
  final String value;
  final List<EditorOption> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return lumira.LumiraDropdown<String>(
      value: value,
      items: options
          .map((o) => DropdownMenuItem<String>(
                value: o.value,
                child: Text(o.label),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _PillGroup extends ConsumerWidget {
  const _PillGroup({
    required this.tokens,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final ThemeTokens tokens;
  final List<EditorOption> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNeumorphic = ref.watch(uiStyleProvider) == UIStyle.neumorphic;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: options.map((o) {
        final active = o.value == value;
        return GestureDetector(
          onTap: () => onChanged(o.value),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              // neumorphic 风格下：激活用 brand + shadowConvex，非激活用 surface + shadowConvexSubtle
              color: active
                  ? tokens.brand
                  : (isNeumorphic ? tokens.surface : tokens.canvasDeep),
              borderRadius: BorderRadius.circular(9999),
              border: isNeumorphic
                  ? null
                  : Border.all(
                      color: active ? tokens.brand : Colors.transparent,
                      width: 1,
                    ),
              boxShadow: isNeumorphic
                  ? (active
                      ? tokens.shadowConvex
                      : tokens.shadowConvexSubtle)
                  : null,
            ),
            child: Text(
              o.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: active ? tokens.textInverse : tokens.textSecondary,
                height: 1,
              ),
            ),
          ),
        );
      }).toList(),
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
    required this.onChanged,
    required this.valueText,
  });

  final ThemeTokens tokens;
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final String valueText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: tokens.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: lumira.LumiraSlider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              valueText,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'SF Mono',
                color: tokens.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Step 1: 模板信息 =====

class _Step1TemplateInfo extends StatelessWidget {
  const _Step1TemplateInfo({
    required this.tokens,
    required this.form,
    required this.tagsController,
    required this.onTagsChanged,
    required this.onChange,
  });

  final ThemeTokens tokens;
  final EditorForm form;
  final TextEditingController tagsController;
  final ValueChanged<String> onTagsChanged;
  final void Function(void Function() mutator) onChange;

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      tokens: tokens,
      stepNumber: 1,
      title: '模板信息',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(tokens: tokens, text: '名称'),
          _FieldInput(
            tokens: tokens,
            initialValue: form.meta.name,
            placeholder: '输入模板名称',
            onChanged: (v) => onChange(() => form.meta.name = v),
          ),
          const SizedBox(height: 14),
          _FieldLabel(tokens: tokens, text: '分类'),
          _FieldDropdown(
            tokens: tokens,
            value: form.meta.category,
            options: categoryOptions,
            onChanged: (v) => onChange(() {
              form.meta.category = v;
            }),
          ),
          const SizedBox(height: 14),
          _FieldLabel(tokens: tokens, text: '标签'),
          _FieldInput(
            tokens: tokens,
            controller: tagsController,
            placeholder: '标签1, 标签2',
            onChanged: onTagsChanged,
          ),
          const SizedBox(height: 14),
          _FieldLabel(tokens: tokens, text: '简介'),
          _FieldInput(
            tokens: tokens,
            initialValue: form.meta.description,
            placeholder: '模板简介',
            multiline: true,
            onChanged: (v) => onChange(() => form.meta.description = v),
          ),
          const SizedBox(height: 14),
          _FieldLabel(tokens: tokens, text: '参数参考来源'),
          _FieldInput(
            tokens: tokens,
            initialValue: form.meta.referenceSource,
            placeholder: '如：样片 EXIF',
            onChanged: (v) => onChange(() => form.meta.referenceSource = v),
          ),
        ],
      ),
    );
  }
}

// ===== Step 2: 构图叠图 =====

class _Step2Composition extends StatelessWidget {
  const _Step2Composition({
    required this.tokens,
    required this.form,
    required this.onChange,
  });

  final ThemeTokens tokens;
  final EditorForm form;
  final void Function(void Function() mutator) onChange;

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      tokens: tokens,
      stepNumber: 2,
      title: '构图叠图',
      delay: const Duration(milliseconds: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(tokens: tokens, text: '构图类型'),
          _FieldDropdown(
            tokens: tokens,
            value: form.composition.overlayType,
            options: overlayTypeOptions,
            onChanged: (v) =>
                onChange(() => form.composition.overlayType = v),
          ),
          const SizedBox(height: 14),
          _FieldLabel(tokens: tokens, text: '宽高比'),
          _FieldInput(
            tokens: tokens,
            initialValue: form.composition.aspectRatio,
            placeholder: '如 3:4',
            onChanged: (v) =>
                onChange(() => form.composition.aspectRatio = v),
          ),
          const SizedBox(height: 14),
          _SliderRow(
            tokens: tokens,
            label: '透明度',
            value: form.composition.opacity,
            min: 0,
            max: 1,
            divisions: 10,
            onChanged: (v) =>
                onChange(() => form.composition.opacity = v),
            valueText: form.composition.opacity.toStringAsFixed(1),
          ),
          _FieldLabel(tokens: tokens, text: '构图说明'),
          _FieldInput(
            tokens: tokens,
            initialValue: form.composition.description,
            placeholder: '构图说明',
            multiline: true,
            onChanged: (v) =>
                onChange(() => form.composition.description = v),
          ),
          const SizedBox(height: 14),
          _PreviewBox(
            tokens: tokens,
            aspectRatio: parseAspectRatio(form.composition.aspectRatio),
            child: CompositionOverlay(
              overlayType: form.composition.overlayType,
              opacity: form.composition.opacity,
            ),
          ),
        ],
      ),
    );
  }
}

/// 预览框（preview-box: 渐变背景 + 叠加层）
class _PreviewBox extends StatelessWidget {
  const _PreviewBox({
    required this.tokens,
    required this.aspectRatio,
    required this.child,
  });

  final ThemeTokens tokens;
  final double aspectRatio;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 硬编码颜色，与 uni-app 一致 (preview-bg: linear-gradient(135deg, #3A3631 0%, #2A2622 100%))
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3A3631), Color(0xFF2A2622)],
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

// ===== Step 3: 姿势剪影 =====

class _Step3Pose extends StatelessWidget {
  const _Step3Pose({
    required this.tokens,
    required this.form,
    required this.isDragging,
    required this.posePositionNotifier,
    required this.onSourceChange,
    required this.onSelectBuiltin,
    required this.onImportImage,
    required this.onOpenEditor,
    required this.onChange,
    required this.onPoseDragStart,
    required this.onPoseDragUpdate,
    required this.onPoseDragEnd,
    required this.onPosePositionSliderChanged,
  });

  final ThemeTokens tokens;
  final EditorForm form;
  final bool isDragging;
  final ValueNotifier<Offset> posePositionNotifier;
  final ValueChanged<String> onSourceChange;
  final ValueChanged<String> onSelectBuiltin;
  final VoidCallback onImportImage;
  final VoidCallback onOpenEditor;
  final void Function(void Function() mutator) onChange;
  final void Function(DragStartDetails) onPoseDragStart;
  final void Function(DragUpdateDetails, BoxConstraints) onPoseDragUpdate;
  final void Function(DragEndDetails) onPoseDragEnd;
  final void Function(bool isX, double v) onPosePositionSliderChanged;

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      tokens: tokens,
      stepNumber: 3,
      title: '姿势剪影',
      delay: const Duration(milliseconds: 160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(tokens: tokens, text: '来源'),
          _PillGroup(
            tokens: tokens,
            options: silhouetteSourceOptions,
            value: form.pose.silhouette.type,
            onChanged: onSourceChange,
          ),
          const SizedBox(height: 14),
          if (form.pose.silhouette.type == 'builtin') ...[
            _FieldLabel(tokens: tokens, text: '选择剪影'),
            _BuiltinSilhouetteThumbnails(
              tokens: tokens,
              selectedKey: form.pose.silhouette.data,
              onSelect: onSelectBuiltin,
            ),
          ],
          if (form.pose.silhouette.type == 'image') ...[
            _FieldLabel(tokens: tokens, text: '导入图片'),
            _GhostActionButton(
              tokens: tokens,
              icon: Icons.upload_outlined,
              label: '选择图片',
              onTap: onImportImage,
            ),
            if (form.pose.silhouette.filename != null) ...[
              const SizedBox(height: 8),
              Text(
                form.pose.silhouette.sizeKB != null
                    ? '${form.pose.silhouette.filename} (${form.pose.silhouette.sizeKB}KB)'
                    : '${form.pose.silhouette.filename}',
                style: TextStyle(
                  fontSize: 12,
                  color: tokens.textTertiary,
                ),
              ),
            ],
          ],
          if (form.pose.silhouette.type == 'svg') ...[
            _FieldLabel(tokens: tokens, text: '绘制剪影'),
            _GhostActionButton(
              tokens: tokens,
              icon: Icons.brush_outlined,
              label: '打开画布',
              onTap: onOpenEditor,
            ),
          ],
          const SizedBox(height: 14),
          _SliderRow(
            tokens: tokens,
            label: '位置 X',
            value: form.pose.position.x,
            min: 0,
            max: 1,
            divisions: 100,
            onChanged: (v) => onPosePositionSliderChanged(true, v),
            valueText: form.pose.position.x.toStringAsFixed(2),
          ),
          _SliderRow(
            tokens: tokens,
            label: '位置 Y',
            value: form.pose.position.y,
            min: 0,
            max: 1,
            divisions: 100,
            onChanged: (v) => onPosePositionSliderChanged(false, v),
            valueText: form.pose.position.y.toStringAsFixed(2),
          ),
          _SliderRow(
            tokens: tokens,
            label: '缩放',
            value: form.pose.scale,
            min: 0.5,
            max: 1.5,
            divisions: 100,
            onChanged: (v) => onChange(() => form.pose.scale = v),
            valueText: form.pose.scale.toStringAsFixed(2),
          ),
          _SliderRow(
            tokens: tokens,
            label: '旋转',
            value: form.pose.rotation,
            min: -45,
            max: 45,
            divisions: 90,
            onChanged: (v) => onChange(() => form.pose.rotation = v),
            valueText: '${form.pose.rotation.round()}°',
          ),
          _FieldLabel(tokens: tokens, text: '姿势描述'),
          _FieldInput(
            tokens: tokens,
            initialValue: form.pose.description,
            placeholder: '姿势描述',
            multiline: true,
            onChanged: (v) => onChange(() => form.pose.description = v),
          ),
          const SizedBox(height: 14),
          // 预览框（可拖动）—— Bug 11 修复：用 RepaintBoundary 隔离重绘，
          // ValueListenableBuilder 监听位置变化，拖动时只重建此部分而非整个 page
          AspectRatio(
            aspectRatio: parseAspectRatio(form.composition.aspectRatio),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: RepaintBoundary(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      onPanStart: onPoseDragStart,
                      onPanUpdate: (details) =>
                          onPoseDragUpdate(details, constraints),
                      onPanEnd: onPoseDragEnd,
                      child: Stack(
                        fit: StackFit.expand,
                        clipBehavior: Clip.hardEdge,
                        children: [
                          // 硬编码颜色，与 uni-app 一致 (preview-bg: linear-gradient(135deg, #3A3631 0%, #2A2622 100%))
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF3A3631),
                                  Color(0xFF2A2622),
                                ],
                              ),
                            ),
                          ),
                          // 剪影 —— ValueListenableBuilder 局部重建
                          ValueListenableBuilder<Offset>(
                            valueListenable: posePositionNotifier,
                            builder: (context, pos, _) {
                              return Positioned(
                                left: constraints.maxWidth * pos.dx,
                                top: constraints.maxHeight * pos.dy,
                                child: FractionalTranslation(
                                  translation: const Offset(-0.5, -0.5),
                                  child: PoseSilhouette(
                                    silhouetteType:
                                        form.pose.silhouette.type,
                                    silhouetteData:
                                        form.pose.silhouette.data,
                                    scale: form.pose.scale,
                                    rotation: form.pose.rotation,
                                  ),
                                ),
                              );
                            },
                          ),
                          // 拖动提示
                          if (!isDragging)
                            Positioned(
                              bottom: 8,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    // 硬编码颜色，与 uni-app 一致 (rgba(0,0,0,0.5))
                                    color: const Color.fromRGBO(0, 0, 0, 0.5),
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.open_with,
                                        size: 12,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '拖动调整位置',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white.withOpacity(0.8),
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
                  },
                ),
              ),
            ),
          ),
          // 位置数值显示 —— 也用 ValueListenableBuilder 局部重建
          if (form.pose.silhouette.data != 'none') ...[
            const SizedBox(height: 8),
            ValueListenableBuilder<Offset>(
              valueListenable: posePositionNotifier,
              builder: (context, pos, _) {
                return Text(
                  '位置 X: ${(pos.dx * 100).round()}%  Y: ${(pos.dy * 100).round()}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'SF Mono',
                    color: tokens.textTertiary,
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _BuiltinSilhouetteThumbnails extends ConsumerWidget {
  const _BuiltinSilhouetteThumbnails({
    required this.tokens,
    required this.selectedKey,
    required this.onSelect,
  });

  final ThemeTokens tokens;
  final String selectedKey;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNeumorphic = ref.watch(uiStyleProvider) == UIStyle.neumorphic;
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kBuiltinSilhouetteKeys.length + 1, // +1 for 'none' at front
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final key = index == 0 ? 'none' : kBuiltinSilhouetteKeys[index - 1];
          final active = selectedKey == key;
          return GestureDetector(
            onTap: () => onSelect(key),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 64,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                // neumorphic 风格下：激活用 brandSubtle + shadowConvex，非激活用 surface + shadowConvexSubtle
                color: active
                    ? tokens.brandSubtle
                    : (isNeumorphic ? tokens.surface : tokens.canvasDeep),
                borderRadius: BorderRadius.circular(8),
                border: isNeumorphic
                    ? null
                    : Border.all(
                        color: active ? tokens.brand : Colors.transparent,
                        width: 1,
                      ),
                boxShadow: isNeumorphic
                    ? (active
                        ? tokens.shadowConvex
                        : tokens.shadowConvexSubtle)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    key == 'none'
                        ? Icons.close
                        : Icons.person_outline,
                    size: 32,
                    color: active ? tokens.brandDeep : tokens.textSecondary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    key,
                    style: TextStyle(
                      fontSize: 9,
                      color: tokens.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GhostActionButton extends ConsumerWidget {
  const _GhostActionButton({
    required this.tokens,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final ThemeTokens tokens;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNeu = ref.watch(uiStyleProvider) == UIStyle.neumorphic;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isNeu ? tokens.surface : tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isNeu ? tokens.shadowConvexSubtle : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: tokens.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: tokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== Step 4: 相机参数 =====

class _Step4Camera extends StatelessWidget {
  const _Step4Camera({
    required this.tokens,
    required this.form,
    required this.onChange,
    required this.onIsoInput,
    required this.onWbKInput,
  });

  final ThemeTokens tokens;
  final EditorForm form;
  final void Function(void Function() mutator) onChange;
  final ValueChanged<String> onIsoInput;
  final ValueChanged<String> onWbKInput;

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      tokens: tokens,
      stepNumber: 4,
      title: '相机参数',
      delay: const Duration(milliseconds: 240),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SliderRow(
            tokens: tokens,
            label: 'EV',
            value: form.camera.exposureCompensation,
            min: -3,
            max: 3,
            divisions: 20,
            onChanged: (v) => onChange(
                () => form.camera.exposureCompensation = v.toDouble()),
            valueText: formatEvSlider(form.camera.exposureCompensation),
          ),
          _FieldLabel(tokens: tokens, text: 'ISO 模式'),
          _PillGroup(
            tokens: tokens,
            options: isoModeOptions,
            value: form.camera.isoMode,
            onChanged: (v) => onChange(() => form.camera.isoMode = v),
          ),
          const SizedBox(height: 14),
          _FieldLabel(tokens: tokens, text: 'ISO 值'),
          _FieldInput(
            tokens: tokens,
            initialValue: form.camera.iso.toString(),
            placeholder: '200',
            keyboardType: TextInputType.number,
            onChanged: onIsoInput,
          ),
          const SizedBox(height: 14),
          _FieldLabel(tokens: tokens, text: '快门'),
          _FieldInput(
            tokens: tokens,
            initialValue: form.camera.shutterSpeed,
            placeholder: '如 1/200',
            onChanged: (v) => onChange(() => form.camera.shutterSpeed = v),
          ),
          const SizedBox(height: 14),
          _FieldLabel(tokens: tokens, text: '白平衡'),
          _FieldDropdown(
            tokens: tokens,
            value: form.camera.whiteBalance,
            options: whiteBalanceOptions,
            onChanged: (v) => onChange(() => form.camera.whiteBalance = v),
          ),
          const SizedBox(height: 14),
          _FieldLabel(tokens: tokens, text: '色温 K'),
          _FieldInput(
            tokens: tokens,
            initialValue: form.camera.whiteBalanceK.toString(),
            placeholder: '5500',
            keyboardType: TextInputType.number,
            onChanged: onWbKInput,
          ),
          const SizedBox(height: 14),
          _FieldLabel(tokens: tokens, text: '闪光'),
          _FieldDropdown(
            tokens: tokens,
            value: form.camera.flashMode,
            options: flashModeOptions,
            onChanged: (v) => onChange(() => form.camera.flashMode = v),
          ),
          const SizedBox(height: 14),
          _FieldLabel(tokens: tokens, text: '对焦'),
          _FieldDropdown(
            tokens: tokens,
            value: form.camera.focusMode,
            options: focusModeOptions,
            onChanged: (v) => onChange(() => form.camera.focusMode = v),
          ),
          const SizedBox(height: 14),
          _FieldLabel(tokens: tokens, text: '镜头'),
          _FieldDropdown(
            tokens: tokens,
            value: form.camera.lensSuggestion,
            options: lensOptions,
            onChanged: (v) => onChange(() => form.camera.lensSuggestion = v),
          ),
        ],
      ),
    );
  }
}

// ===== Step 5: 场景指南 =====

class _Step5SceneGuide extends StatelessWidget {
  const _Step5SceneGuide({
    required this.tokens,
    required this.form,
    required this.propsController,
    required this.tipsController,
    required this.onPropsChanged,
    required this.onTipsChanged,
    required this.onChange,
  });

  final ThemeTokens tokens;
  final EditorForm form;
  final TextEditingController propsController;
  final TextEditingController tipsController;
  final ValueChanged<String> onPropsChanged;
  final ValueChanged<String> onTipsChanged;
  final void Function(void Function() mutator) onChange;

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      tokens: tokens,
      stepNumber: 5,
      title: '场景指南',
      delay: const Duration(milliseconds: 320),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(tokens: tokens, text: '光线方向'),
          _FieldInput(
            tokens: tokens,
            initialValue: form.sceneGuide.lightDirection,
            placeholder: '如 逆光 45°',
            onChanged: (v) =>
                onChange(() => form.sceneGuide.lightDirection = v),
          ),
          const SizedBox(height: 14),
          _FieldLabel(tokens: tokens, text: '拍摄距离'),
          _FieldInput(
            tokens: tokens,
            initialValue: form.sceneGuide.shootingDistance,
            placeholder: '如 2-3m',
            onChanged: (v) =>
                onChange(() => form.sceneGuide.shootingDistance = v),
          ),
          const SizedBox(height: 14),
          _FieldLabel(tokens: tokens, text: '背景'),
          _FieldInput(
            tokens: tokens,
            initialValue: form.sceneGuide.background,
            placeholder: '背景建议',
            onChanged: (v) => onChange(() => form.sceneGuide.background = v),
          ),
          const SizedBox(height: 14),
          _FieldLabel(tokens: tokens, text: '最佳时间'),
          _FieldInput(
            tokens: tokens,
            initialValue: form.sceneGuide.bestTime,
            placeholder: '如 黄金时刻',
            onChanged: (v) => onChange(() => form.sceneGuide.bestTime = v),
          ),
          const SizedBox(height: 14),
          _FieldLabel(tokens: tokens, text: '道具'),
          _FieldInput(
            tokens: tokens,
            controller: propsController,
            placeholder: '道具1, 道具2',
            onChanged: onPropsChanged,
          ),
          const SizedBox(height: 14),
          _FieldLabel(tokens: tokens, text: '贴士'),
          _FieldInput(
            tokens: tokens,
            controller: tipsController,
            placeholder: '每行一条',
            multiline: true,
            onChanged: onTipsChanged,
          ),
        ],
      ),
    );
  }
}

// ===== Step 6: 后期参数 =====

class _Step6PostProcess extends StatelessWidget {
  const _Step6PostProcess({
    required this.tokens,
    required this.form,
    required this.onChange,
  });

  final ThemeTokens tokens;
  final EditorForm form;
  final void Function(void Function() mutator) onChange;

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      tokens: tokens,
      stepNumber: 6,
      title: '后期参数',
      delay: const Duration(milliseconds: 400),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(tokens: tokens, text: '裁剪比'),
          _FieldInput(
            tokens: tokens,
            initialValue: form.postProcess.cropRatio,
            placeholder: '如 3:4',
            onChanged: (v) => onChange(() => form.postProcess.cropRatio = v),
          ),
          const SizedBox(height: 14),
          _FieldLabel(tokens: tokens, text: 'LUT'),
          _FieldDropdown(
            tokens: tokens,
            value: form.postProcess.lut,
            options: lutOptions,
            onChanged: (v) => onChange(() => form.postProcess.lut = v),
          ),
          const SizedBox(height: 14),
          _SliderRow(
            tokens: tokens,
            label: '亮度',
            value: form.postProcess.color.brightness.toDouble(),
            min: -100,
            max: 100,
            divisions: 200,
            onChanged: (v) => onChange(
                () => form.postProcess.color.brightness = v.round()),
            valueText: formatSigned(form.postProcess.color.brightness),
          ),
          _SliderRow(
            tokens: tokens,
            label: '对比',
            value: form.postProcess.color.contrast.toDouble(),
            min: -100,
            max: 100,
            divisions: 200,
            onChanged: (v) => onChange(
                () => form.postProcess.color.contrast = v.round()),
            valueText: formatSigned(form.postProcess.color.contrast),
          ),
          _SliderRow(
            tokens: tokens,
            label: '饱和',
            value: form.postProcess.color.saturation.toDouble(),
            min: -100,
            max: 100,
            divisions: 200,
            onChanged: (v) => onChange(
                () => form.postProcess.color.saturation = v.round()),
            valueText: formatSigned(form.postProcess.color.saturation),
          ),
          _SliderRow(
            tokens: tokens,
            label: '色温',
            value: form.postProcess.color.temperature.toDouble(),
            min: -100,
            max: 100,
            divisions: 200,
            onChanged: (v) => onChange(
                () => form.postProcess.color.temperature = v.round()),
            valueText: formatSigned(form.postProcess.color.temperature),
          ),
          _SliderRow(
            tokens: tokens,
            label: '色调',
            value: form.postProcess.color.tint.toDouble(),
            min: -100,
            max: 100,
            divisions: 200,
            onChanged: (v) =>
                onChange(() => form.postProcess.color.tint = v.round()),
            valueText: formatSigned(form.postProcess.color.tint),
          ),
          _SliderRow(
            tokens: tokens,
            label: '磨皮',
            value: form.postProcess.smoothStrength.toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            onChanged: (v) => onChange(
                () => form.postProcess.smoothStrength = v.round()),
            valueText: '${form.postProcess.smoothStrength}',
          ),
          _SliderRow(
            tokens: tokens,
            label: '锐化',
            value: form.postProcess.sharpen.toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            onChanged: (v) =>
                onChange(() => form.postProcess.sharpen = v.round()),
            valueText: '${form.postProcess.sharpen}',
          ),
          _SliderRow(
            tokens: tokens,
            label: '暗角',
            value: form.postProcess.vignette.toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            onChanged: (v) =>
                onChange(() => form.postProcess.vignette = v.round()),
            valueText: '${form.postProcess.vignette}',
          ),
          _SliderRow(
            tokens: tokens,
            label: '颗粒',
            value: form.postProcess.grain.toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            onChanged: (v) =>
                onChange(() => form.postProcess.grain = v.round()),
            valueText: '${form.postProcess.grain}',
          ),
        ],
      ),
    );
  }
}

// ===== Footer =====

class _EditorFooter extends StatelessWidget {
  const _EditorFooter({
    required this.tokens,
    required this.isExportVisible,
    required this.onSaveDraft,
    required this.onPreview,
    required this.onSave,
    required this.onExport,
  });

  final ThemeTokens tokens;
  final bool isExportVisible;
  final VoidCallback onSaveDraft;
  final VoidCallback onPreview;
  final VoidCallback onSave;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    // Forced fix: 4 个 LumiraButton 在 Row 中（每个 padding horizontal:16-24）
    // 在窄屏（360dp）下，每按钮宽度仅 60dp，icon 18 + gap 8 + 文字 + padding 32 = 84dp 溢出。
    // 改为垂直 Column 按钮（icon 上 + text 下），宽度只需 ~50dp。
    final buttons = <_FooterBtn>[
      _FooterBtn(
        icon: Icons.edit_note,
        label: '草稿',
        onTap: onSaveDraft,
        type: _FooterBtnType.secondary,
      ),
      _FooterBtn(
        icon: Icons.visibility_outlined,
        label: '预览',
        onTap: onPreview,
        type: _FooterBtnType.secondary,
      ),
      _FooterBtn(
        icon: Icons.save_outlined,
        label: '保存',
        onTap: onSave,
        type: _FooterBtnType.primary,
        flex: 2,
      ),
      if (isExportVisible)
        _FooterBtn(
          icon: Icons.ios_share,
          label: '导出',
          onTap: onExport,
          type: _FooterBtnType.secondary,
        ),
    ];

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              tokens.canvas.withOpacity(0),
              tokens.canvas,
            ],
            stops: const [0, 0.4],
          ),
        ),
        child: Row(
          children: buttons.asMap().entries.map((entry) {
            final btn = entry.value;
            final isLast = entry.key == buttons.length - 1;
            return Expanded(
              flex: btn.flex,
              child: Padding(
                padding: EdgeInsets.only(right: isLast ? 0 : 8),
                child: _VerticalFooterButton(btn: btn, tokens: tokens),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

enum _FooterBtnType { primary, secondary }

class _FooterBtn {
  const _FooterBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.type,
    this.flex = 1,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final _FooterBtnType type;
  final int flex;
}

class _VerticalFooterButton extends ConsumerWidget {
  const _VerticalFooterButton({required this.btn, required this.tokens});
  final _FooterBtn btn;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNeumorphic = ref.watch(uiStyleProvider) == UIStyle.neumorphic;
    final isPrimary = btn.type == _FooterBtnType.primary;
    final bg = isPrimary ? tokens.textPrimary : tokens.surfaceAlt;
    final fg = isPrimary ? tokens.canvas : tokens.textSecondary;
    // neumorphic 风格下：次按钮移除 border，用 shadowConvexSubtle
    final borderColor = (isPrimary || isNeumorphic) ? null : tokens.divider;

    return GestureDetector(
      onTap: btn.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: borderColor != null
              ? Border.all(color: borderColor, width: 1)
              : null,
          boxShadow: isNeumorphic && !isPrimary
              ? tokens.shadowConvexSubtle
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(btn.icon, size: 18, color: fg),
            const SizedBox(height: 4),
            Text(
              btn.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: fg,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
