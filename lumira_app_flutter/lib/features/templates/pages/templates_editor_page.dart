import 'dart:async';
import 'dart:convert' show base64Encode, base64Decode;
import 'dart:typed_data' show Uint8List;
import 'dart:io' as io;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/file_picker_service.dart';

import '../../../core/db/dao/templates_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/lumira/lumira.dart' as lumira;
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../capture/data/capture_state.dart';
import '../../profile/pages/profile_my_templates_page.dart'
    show customTemplatesProvider;
import '../data/preview_form_provider.dart';
import '../data/builtin_silhouettes.dart';
import '../data/custom_tag_options_provider.dart';
import '../data/remote_template_dto.dart';
import '../data/remote_templates_providers.dart';
import '../data/templates_editor_mock_data.dart';
import '../services/template_exporter.dart';
import '../services/template_mapper.dart';
import '../widgets/composition_overlay.dart';
import '../widgets/editor_tab_bar.dart';
import '../widgets/pose_silhouette.dart';
import '../widgets/silhouette_editor.dart';

/// 编辑器顶部 6 个 tab 标题（与后台 STEPS 一致）。
const List<String> _editorTabs = [
  '基本信息', '封面与剪影', '构图', '相机参数', '场景引导', '后期处理',
];

/// 计算有效宽高比（处理 fullscreen 和方向自适应）
double _effectiveAspectRatio(String ratio, BuildContext context) {
  final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
  final raw = parseAspectRatio(ratio, isPortrait: isPortrait);
  if (raw < 0) {
    return MediaQuery.of(context).size.width /
        MediaQuery.of(context).size.height;
  }
  return raw;
}

/// 选项对（label/value）
class EditorOption {
  const EditorOption(this.value, this.label);
  final String value;
  final String label;
}

// ===== 选项数组（editor.vue lines 819-888 verbatim） =====
// v17: categoryOptions 改为从 DAO 动态加载（见 _Step1TemplateInfoState._loadTypeOptions），
// 不再硬编码，以支持后端动态分类管理。

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

const List<EditorOption> aspectRatioOptions = [
  EditorOption('fullscreen', '全屏'),
  EditorOption('4:3', '4:3'),
  EditorOption('1:1', '1:1'),
  EditorOption('3:4', '3:4'),
  EditorOption('16:9', '16:9'),
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
  EditorOption('warm_film', '暖色胶片'),
  EditorOption('cool_film', '冷色胶片'),
  EditorOption('pastel', '柔色'),
  EditorOption('fuji', '富士'),
  EditorOption('portrait', '人像'),
  EditorOption('japanese', '日系'),
  EditorOption('japanese_fresh', '日系清新'),
  EditorOption('cream', '奶油感'),
  EditorOption('cyberpunk', '赛博朋克'),
  EditorOption('night_cyber', '夜景赛博'),
  EditorOption('hk_neon', '港风霓虹'),
  EditorOption('sepia_classic', '褐调'),
  EditorOption('mist', '薄雾'),
  EditorOption('rouge', '胭脂'),
  EditorOption('twilight', '暮光'),
  EditorOption('cyan', '青调'),
  EditorOption('noir', '黑白'),
  EditorOption('fine_art_bw', '黑白艺术'),
  EditorOption('silver', '银盐感'),
  EditorOption('morandi', '莫兰迪'),
  EditorOption('muted_gray', '低饱和高级灰'),
  EditorOption('heavy_film', '浓厚胶片'),
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

  // 用版本计数器通知剪影预览区域重建，避免滑块/拖动时 setState 导致整个页面 rebuild
  int _poseVersion = 0;
  late final ValueNotifier<int> _poseVersionNotifier;

  /// 是否正在从 DAO 异步加载模板（编辑模式且 mock 中不存在时为 true）。
  /// 加载期间显示 loading 覆盖层，避免用户看到空白表单误以为模板未加载。
  bool _isLoadingFromDao = false;

  /// 当前选中的顶部 Tab 下标（0-5）。
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    // 同步加载 mock 数据（内置模板/草稿/测试种子）— 立即显示，避免空白闪烁
    _form = _loadInitialFormSync();
    final mockHasTemplate = widget.templateId != null &&
        TemplatesEditorMockData.loadTemplateById(widget.templateId) != null;
    _isEditMode = widget.templateId != null && mockHasTemplate;
    // 编辑模式但 mock 中不存在（用户自建模板）→ 需要从 DAO 异步加载
    _isLoadingFromDao = widget.templateId != null && !mockHasTemplate;
    _tagsController = TextEditingController(text: _form.meta.tags.join(', '));
    _propsController =
        TextEditingController(text: _form.sceneGuide.props.join(', '));
    _tipsController =
        TextEditingController(text: _form.sceneGuide.tips.join('\n'));
    _poseVersionNotifier = ValueNotifier(0);
    // 异步从 DAO 加载（若 DAO 命中则覆盖 mock 数据，用于用户自建模板编辑）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFromDaoIfNeeded();
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _scrollController.dispose();
    _tagsController.dispose();
    _propsController.dispose();
    _tipsController.dispose();
    _poseVersionNotifier.dispose();
    super.dispose();
  }

  /// 通知剪影预览区域重建（不触发父级 setState，避免页面滚动跳跃）
  void _notifyPoseChanged() {
    _poseVersion++;
    _poseVersionNotifier.value = _poseVersion;
  }

  /// 同步加载初始表单（mock 数据源）：
  /// 1. 编辑模式（templateId 非空）：从 mock 加载已有模板
  /// 2. 草稿恢复（draftId 非空）：从 mock 加载草稿
  /// 3. 兜底：空白模板
  EditorForm _loadInitialFormSync() {
    if (widget.templateId != null && widget.templateId!.isNotEmpty) {
      final tpl = TemplatesEditorMockData.loadTemplateById(widget.templateId);
      if (tpl != null) return tpl;
    }
    if (widget.draftId != null && widget.draftId!.isNotEmpty) {
      final draft = TemplatesEditorMockData.loadDraftById(widget.draftId);
      if (draft != null) {
        _currentDraftId = widget.draftId!;
        return draft;
      }
    }
    return createBlankEditorForm();
  }

  /// 异步从 DAO 加载已有模板（若命中则覆盖 mock 数据）。
  /// 仅在编辑模式（templateId 非空）且 DAO 命中时覆盖。
  /// 用于用户自建模板编辑（mock 数据不包含用户自建模板）。
  Future<void> _loadFromDaoIfNeeded() async {
    if (widget.templateId == null || widget.templateId!.isEmpty) {
      if (mounted) setState(() => _isLoadingFromDao = false);
      return;
    }
    try {
      final dao = await ref.read(templatesDaoProvider.future);
      var record = await dao.getById(widget.templateId!);
      if (record == null) {
        if (!mounted) return;
        setState(() => _isLoadingFromDao = false);
        return;
      }
      // 远程模板：meta 同步时 pose/composition 为空，编辑前按需拉取完整详情
      // （与详情页 templateDetailProvider 慢路径一致，保证剪影/构图等 5 段内容完整）
      if (record.source == 'remote' && record.composition.isEmpty) {
        final remoteTemplate = await ref
            .read(remoteTemplateDetailProvider(widget.templateId!).future);
        if (remoteTemplate != null) {
          final refreshed = await dao.getById(widget.templateId!);
          if (refreshed != null) record = refreshed;
        }
      }
      final loaded = TemplateMapper.toEditorForm(record);
      // 调试日志：追踪封面图和剪影数据加载
      debugPrint(
          '[Editor] Load from DAO: id=${record.id}, source=${record.source}');
      debugPrint(
          '[Editor]   coverData: ${record.coverData != null ? '${record.coverData!.length} chars' : 'null'}');
      debugPrint(
          '[Editor]   coverImage in form: ${loaded.meta.coverImage != null ? '${loaded.meta.coverImage!.length} chars' : 'null'}');
      final sil = loaded.pose.silhouette;
      debugPrint(
          '[Editor]   silhouette: type=${sil.type}, data=${sil.data.isNotEmpty ? '${sil.data.length} chars' : 'empty'}');
      if (!mounted) return;
      setState(() {
        _form = loaded;
        _isEditMode = true;
        _tagsController.text = _form.meta.tags.join(', ');
        _propsController.text = _form.sceneGuide.props.join(', ');
        _tipsController.text = _form.sceneGuide.tips.join('\n');
        _notifyPoseChanged();
        _isLoadingFromDao = false;
      });
    } catch (e) {
      debugPrint('Failed to load template from DAO: $e');
      if (mounted) setState(() => _isLoadingFromDao = false);
    }
  }

  // ===== 表单变更处理 =====

  void _onChange(void Function() mutator) {
    setState(mutator);
    _scheduleAutoSave();
  }

  void _onTagsChanged(String text) {
    _form.meta.tags = text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    _scheduleAutoSave();
  }

  void _onPropsChanged(String text) {
    _form.sceneGuide.props = text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
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

  // ===== 封面图选择 =====

  /// 根据文件扩展名推断 MIME 类型，覆盖常见图片格式。
  /// 未知扩展名回退到 image/png（大多数图片解码器可兼容处理）。
  static String _imageMimeFromExtension(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      case 'svg':
      case 'svgz':
        return 'image/svg+xml';
      default:
        return 'image/png';
    }
  }

  Future<void> _pickCoverImage() async {
    try {
      final file = await FilePickerService.pickSingleImage();
      if (file == null) return;
      // OHOS 端 file_picker 的 withData 返回的 bytes 会被截断为 4096 字节，
      // 无法解码图片；ensureFullBytes 会从磁盘/原生通道读取完整内容。
      final fullFile = await FilePickerService.ensureFullBytes(file);
      final bytes = fullFile.bytes;
      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        lumira.LumiraToast.show(context, '读取图片失败，请重试');
        return;
      }
      final mime = _imageMimeFromExtension(fullFile.extension);
      final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
      _onChange(() => _form.meta.coverImage = dataUrl);
      if (!mounted) return;
      lumira.LumiraToast.show(context, '封面图已设置');
    } catch (e) {
      if (!mounted) return;
      lumira.LumiraToast.show(context, '设置封面图失败：$e');
    }
  }

  /// 调用系统能力拍照获取封面图。
  ///
  /// 使用 image_picker 的 ImageSource.camera 调起系统相机（而非 app 内拍摄页），
  /// 拍照完成后读取图片 bytes 转 base64 data URL。
  /// OHOS 平台 image_picker 无原生实现，回退到相册选择提示。
  Future<void> _pickCoverImageFromCamera() async {
    try {
      // OHOS: image_picker 无 OHOS 实现，提示用户从相册选择
      if (io.Platform.operatingSystem == 'ohos') {
        if (!mounted) return;
        lumira.LumiraToast.show(context, '当前系统暂不支持系统拍照，请从相册选择');
        return;
      }
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: ImageSource.camera);
      if (xfile == null) return; // 用户取消拍照
      final bytes = await xfile.readAsBytes();
      // 拍摄结果统一为 jpeg
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      _onChange(() => _form.meta.coverImage = dataUrl);
      if (!mounted) return;
      lumira.LumiraToast.show(context, '封面图已设置');
    } on PlatformException catch (e) {
      // 用户取消拍照时某些平台抛 PlatformException，静默处理
      final code = e.code.toLowerCase();
      if (code.contains('cancel') ||
          code.contains('abort') ||
          code.contains('activity') ||
          code.contains('unknown')) {
        return;
      }
      if (!mounted) return;
      lumira.LumiraToast.show(context, '设置封面图失败：$e');
    } catch (e) {
      if (!mounted) return;
      lumira.LumiraToast.show(context, '设置封面图失败：$e');
    }
  }

  Future<void> _showCoverImagePicker() async {
    final tokens = ref.read(themeTokensProvider);
    await lumira.showLumiraBottomSheet<void>(
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
          lumira.LumiraListTile(
            leading: Icon(Icons.photo_outlined, color: tokens.brand),
            title: const Text('从相册选择'),
            onTap: () {
              Navigator.pop(ctx);
              _pickCoverImage();
            },
          ),
          lumira.LumiraListTile(
            leading: Icon(Icons.camera_alt_outlined, color: tokens.brand),
            title: const Text('拍照'),
            onTap: () {
              Navigator.pop(ctx);
              _pickCoverImageFromCamera();
            },
          ),
          lumira.LumiraListTile(
            title: Center(
              child: Text('取消', style: TextStyle(color: tokens.textSecondary)),
            ),
            onTap: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
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

  Future<void> _importSilhouetteImage() async {
    try {
      final file = await FilePickerService.pickSingleImage();
      if (file == null) return;
      // OHOS 端 file_picker 的 withData 返回的 bytes 会被截断为 4096 字节，
      // 无法解码图片；ensureFullBytes 会从磁盘/原生通道读取完整内容。
      final fullFile = await FilePickerService.ensureFullBytes(file);
      final bytes = fullFile.bytes;
      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        lumira.LumiraToast.show(context, '读取图片失败，请重试');
        return;
      }
      final mime = _imageMimeFromExtension(fullFile.extension);
      final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
      final sizeKB = (bytes.length / 1024).round();
      setState(() {
        _form.pose.silhouette = SilhouetteResource(
          type: 'image',
          data: dataUrl,
          filename: fullFile.name,
          sizeKB: sizeKB,
        );
      });
      if (!mounted) return;
      lumira.LumiraToast.show(context, '图片已导入（${sizeKB}KB）');
      _scheduleAutoSave();
    } catch (e) {
      if (!mounted) return;
      lumira.LumiraToast.show(context, '导入图片失败：$e');
    }
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

  void _onPoseDragUpdate(
      DragUpdateDetails details, BoxConstraints constraints) {
    if (!_isDraggingPose) return;
    // 拖动时不调用 setState（避免整个 page rebuild 和滚动跳跃），
    // 只更新 _form 和 _poseVersionNotifier，让 ValueListenableBuilder 局部重建
    final dx = details.delta.dx / constraints.maxWidth;
    final dy = details.delta.dy / constraints.maxHeight;
    _form.pose.position.x = (_form.pose.position.x + dx).clamp(0.0, 1.0);
    _form.pose.position.y = (_form.pose.position.y + dy).clamp(0.0, 1.0);
    _notifyPoseChanged();
  }

  void _onPoseDragEnd(DragEndDetails details) {
    setState(() => _isDraggingPose = false);
    _scheduleAutoSave();
  }

  /// 位置 X/Y 滑块变化（不调用 setState，避免页面滚动跳跃）
  void _onPosePositionSliderChanged(bool isX, double v) {
    if (isX) {
      _form.pose.position.x = v;
    } else {
      _form.pose.position.y = v;
    }
    _notifyPoseChanged();
    _scheduleAutoSave();
  }

  /// 缩放滑块变化（不调用 setState）
  void _onScaleSliderChanged(double v) {
    _form.pose.scale = v;
    _notifyPoseChanged();
    _scheduleAutoSave();
  }

  /// 旋转滑块变化（不调用 setState）
  void _onRotationSliderChanged(double v) {
    _form.pose.rotation = v;
    _notifyPoseChanged();
    _scheduleAutoSave();
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

    // 编辑模式下保留原 createdAt（避免更新时刷新创建时间）
    int createdAt = now;
    if (_isEditMode && widget.templateId != null) {
      try {
        final dao = await ref.read(templatesDaoProvider.future);
        final existing = await dao.getById(widget.templateId!);
        if (existing != null) {
          createdAt = existing.createdAt;
        }
      } catch (e) {
        debugPrint('Failed to query existing record for createdAt: $e');
      }
    }

    final record = TemplateMapper.fromEditorForm(
      _form,
      id: id,
      createdAt: createdAt,
    ).copyWith(updatedAt: now);

    // 调试日志：追踪封面图和剪影数据保存
    debugPrint('[Editor] Save: id=$id');
    debugPrint(
        '[Editor]   coverImage in form: ${_form.meta.coverImage != null ? '${_form.meta.coverImage!.length} chars' : 'null'}');
    debugPrint(
        '[Editor]   coverData in record: ${record.coverData != null ? '${record.coverData!.length} chars' : 'null'}');
    debugPrint(
        '[Editor]   silhouette: type=${_form.pose.silhouette.type}, data=${_form.pose.silhouette.data.isNotEmpty ? '${_form.pose.silhouette.data.length} chars' : 'empty'}');

    try {
      final dao = await ref.read(templatesDaoProvider.future);
      await dao.upsert(record);
      // 刷新 My Templates 页数据源，使新保存的模板立即出现
      ref.invalidate(customTemplatesProvider);
      // 刷新 Capture 页模板缓存（系统 + 自定义），使新保存的模板立即出现
      ref.invalidate(CaptureState.allTemplatesProvider);
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
      _currentDraftId = 'draft-editor-${DateTime.now().millisecondsSinceEpoch}';
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
              child: Text('取消', style: TextStyle(color: tokens.textSecondary)),
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
      final filePath =
          await TemplateExporter.exportToTempFile(record, usePptpl: usePptpl);
      if (!mounted) return;

      context.push(
        RouteNames.templatesExportDetail,
        extra: {
          'filePath': filePath,
          'templateName': record.name,
          'usePptpl': usePptpl,
        },
      );
    } catch (e) {
      if (!mounted) return;
      lumira.LumiraToast.show(context, '导出失败：$e');
    }
  }

  Future<void> _onPreview() async {
    // Bug 12 修复：将当前 _form 的副本写入 previewEditorFormProvider，
    // 让预览页能直接读取真实编辑器表单（而非 mock 数据）
    if (_currentDraftId.isEmpty) {
      _currentDraftId = 'draft-editor-${DateTime.now().millisecondsSinceEpoch}';
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
      _notifyPoseChanged();
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
                EditorTabBar(
                  tabs: _editorTabs,
                  index: _tabIndex,
                  onSelect: (i) => setState(() => _tabIndex = i),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: SingleChildScrollView(
                          key: ValueKey(_tabIndex),
                          padding: const EdgeInsets.fromLTRB(24, 4, 24, 120),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: _buildTabContent(_tabIndex),
                          ),
                        ),
                      ),
                      _EditorFooter(
                        tokens: tokens,
                        isExportVisible:
                            _isEditMode && _form.meta.id.isNotEmpty,
                        onSaveDraft: _onSaveDraft,
                        onPreview: _onPreview,
                        onSave: _onSave,
                        onExport: _onExport,
                      ),
                      if (_isLoadingFromDao)
                        Positioned.fill(
                          child: Container(
                            color: tokens.canvas.withOpacity(0.85),
                            child: Center(
                              child: lumira.LumiraProgress.circular(),
                            ),
                          ),
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

  /// 按当前 Tab 下标分发要渲染的 step 内容（封面图被抽到「封面与剪影」Tab）。
  List<Widget> _buildTabContent(int i) {
    final tokens = ref.read(themeTokensProvider);
    final children = <Widget>[];
    switch (i) {
      case 0: // 基本信息
        children.add(_Step1TemplateInfo(
          tokens: tokens,
          form: _form,
          tagsController: _tagsController,
          onTagsChanged: _onTagsChanged,
          onChange: _onChange,
        ));
        break;
      case 1: // 封面与剪影（封面图 + 姿势剪影）
        children.add(_StepCard(
          tokens: tokens,
          title: '封面',
          child: _buildCoverField(tokens),
        ));
        children.add(const SizedBox(height: 12));
        children.add(_Step3Pose(
          tokens: tokens,
          form: _form,
          compositionAspectRatio: _form.composition.aspectRatio,
          isDragging: _isDraggingPose,
          poseVersionNotifier: _poseVersionNotifier,
          onSourceChange: _onSilhouetteSourceChange,
          onSelectBuiltin: _selectBuiltinSilhouette,
          onImportImage: _importSilhouetteImage,
          onOpenEditor: _openSilhouetteEditor,
          onChange: _onChange,
          onPoseDragStart: _onPoseDragStart,
          onPoseDragUpdate: _onPoseDragUpdate,
          onPoseDragEnd: _onPoseDragEnd,
          onPosePositionSliderChanged: _onPosePositionSliderChanged,
          onScaleSliderChanged: _onScaleSliderChanged,
          onRotationSliderChanged: _onRotationSliderChanged,
        ));
        break;
      case 2: // 构图
        children.add(_Step2Composition(
          tokens: tokens,
          form: _form,
          onChange: _onChange,
        ));
        break;
      case 3: // 相机参数
        children.add(_Step4Camera(
          tokens: tokens,
          form: _form,
          onChange: _onChange,
          onIsoInput: _onIsoInput,
          onWbKInput: _onWbKInput,
        ));
        break;
      case 4: // 场景引导
        children.add(_Step5SceneGuide(
          tokens: tokens,
          form: _form,
          propsController: _propsController,
          tipsController: _tipsController,
          onPropsChanged: _onPropsChanged,
          onTipsChanged: _onTipsChanged,
          onChange: _onChange,
        ));
        break;
      case 5: // 后期处理
        children.add(_Step6PostProcess(
          tokens: tokens,
          form: _form,
          onChange: _onChange,
        ));
        break;
    }
    return children;
  }

  /// 「封面与剪影」Tab 中的封面图字段（从 Step1 抽离出来的「效果图（封面图）」区块）。
  Widget _buildCoverField(ThemeTokens tokens) {
    final cover = _form.meta.coverImage;
    final onPickCoverImage = _showCoverImagePicker;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(tokens: tokens, text: '效果图（封面图）'),
        if (cover != null && cover.isNotEmpty)
          GestureDetector(
            onTap: () => _showCoverPreviewDialog(
                context, cover, tokens, onPickCoverImage),
            behavior: HitTestBehavior.opaque,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: FutureBuilder<ui.Image>(
                future: _getCachedCoverImage(cover),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final img = snapshot.data!;
                    return AspectRatio(
                      aspectRatio: img.width / img.height,
                      child: Image.memory(
                        _cachedCoverDecode(cover),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, _) {
                          debugPrint(
                              '[Editor] Cover image decode error: $error');
                          return _CoverPlaceholder(tokens: tokens);
                        },
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    debugPrint(
                        '[Editor] Cover image decode error: ${snapshot.error}');
                    return _CoverPlaceholder(tokens: tokens);
                  }
                  return Container(
                    height: 200,
                    width: double.infinity,
                    color: tokens.canvasDeep,
                    child: const Center(
                        child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator())),
                  );
                },
              ),
            ),
          )
        else
          GestureDetector(
            onTap: onPickCoverImage,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: tokens.canvasDeep,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: tokens.divider,
                  width: 0.5,
                ),
              ),
              clipBehavior: Clip.hardEdge,
              child: _CoverPlaceholder(tokens: tokens),
            ),
          ),
      ],
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
    required this.title,
    required this.child,
    this.delay = Duration.zero,
  });

  final ThemeTokens tokens;
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
    this.onSubmitted,
    this.maxLength,
  });

  final ThemeTokens tokens;
  final TextEditingController? controller;
  final String? initialValue;
  final String? placeholder;
  final bool multiline;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// 可选：限制输入最大长度，超长部分在 onChanged 中截断（controller 同步截断）。
  final int? maxLength;

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
  void didUpdateWidget(covariant _FieldInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当父级表单从 DAO 异步加载后，initialValue 会变化（如编辑已有模板时）。
    // 需同步更新内部 controller 的 text，否则输入框仍显示初始空白值。
    // 仅当 own controller 且 initialValue 实际变化时才更新，避免覆盖用户正在输入的内容。
    if (_ownsController && widget.initialValue != oldWidget.initialValue) {
      final newValue = widget.initialValue ?? '';
      if (_internalController.text != newValue) {
        _internalController.text = newValue;
      }
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
      onChanged: _onChanged,
      onSubmitted: widget.onSubmitted,
      maxLines: widget.multiline ? 8 : 1,
    );
  }

  void _onChanged(String value) {
    if (widget.maxLength != null && value.length > widget.maxLength!) {
      final truncated = value.substring(0, widget.maxLength!);
      // 同步截断 controller，保证输入框显示不超过上限
      _internalController.value = TextEditingValue(
        text: truncated,
        selection:
            TextSelection.collapsed(offset: truncated.length),
      );
      widget.onChanged?.call(truncated);
    } else {
      widget.onChanged?.call(value);
    }
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
                  ? (active ? tokens.shadowConvex : tokens.shadowConvexSubtle)
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

class _Step1TemplateInfo extends ConsumerStatefulWidget {
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
  ConsumerState<_Step1TemplateInfo> createState() => _Step1TemplateInfoState();
}

/// base64 data URL 解码缓存（避免每次 rebuild 重复解码）
final Map<String, Uint8List> _coverImageDecodeCache = {};

Uint8List _cachedCoverDecode(String dataUrl) {
  return _coverImageDecodeCache.putIfAbsent(dataUrl, () {
    return base64Decode(dataUrl.substring(dataUrl.indexOf(',') + 1));
  });
}

/// 封面图尺寸缓存（宽高比用于 AspectRatio 约束）
final Map<String, Future<ui.Image>> _coverImageSizeCache = {};

Future<ui.Image> _getCachedCoverImage(String dataUrl) {
  return _coverImageSizeCache.putIfAbsent(
      dataUrl, () => _decodeCoverImage(dataUrl));
}

Future<ui.Image> _decodeCoverImage(String dataUrl) async {
  try {
    final bytes = _cachedCoverDecode(dataUrl);
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  } catch (e) {
    // 解码失败：移出缓存，避免坏 Future 被永久缓存导致后续重建永远失败
    _coverImageSizeCache.remove(dataUrl);
    rethrow;
  }
}

/// 封面图放大预览弹窗
void _showCoverPreviewDialog(
  BuildContext context,
  String cover,
  ThemeTokens tokens,
  VoidCallback onChangeCover,
) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FutureBuilder<ui.Image>(
              future: _getCachedCoverImage(cover),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final img = snapshot.data!;
                  return AspectRatio(
                    aspectRatio: img.width / img.height,
                    child: Image.memory(
                      _cachedCoverDecode(cover),
                      fit: BoxFit.contain,
                    ),
                  );
                }
                if (snapshot.hasError) {
                  debugPrint(
                      '[Editor] Cover preview decode error: ${snapshot.error}');
                  return Container(
                    height: 300,
                    width: double.infinity,
                    color: tokens.canvasDeep,
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: Colors.white38),
                    ),
                  );
                }
                return Container(
                  height: 300,
                  width: double.infinity,
                  color: tokens.canvasDeep,
                  child: const Center(
                      child: SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator())),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: tokens.textPrimary,
                foregroundColor: tokens.canvas,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                onChangeCover();
              },
              child: const Text('更换封面',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    ),
  );
}

/// v17: Step1 表单状态。
///
/// 分类选项（type/majorStyle/subStyle/method）从 sqflite DAO 动态加载，支持四级级联：
/// - type（一级）：initState 时加载 level=1 分类 → `form.meta.category`
/// - majorStyle（二级）：type 变化时按 parentKey 重新加载 → `form.meta.style`
/// - subStyle（三级）：majorStyle 变化时按 parentKey 重新加载 → `form.meta.subStyle`
/// - method（四级）：subStyle 变化时按 parentKey 重新加载 → `form.meta.method`
///
/// 级联一致性：切换 type 时清空 style/subStyle/method；切换 style 时清空 subStyle/method；
/// 切换 subStyle 时清空 method。
class _Step1TemplateInfoState extends ConsumerState<_Step1TemplateInfo> {
  List<EditorOption> _typeOptions = const [];
  List<EditorOption> _styleOptions = const [];
  List<EditorOption> _subStyleOptions = const [];
  List<EditorOption> _method4Options = const [];

  /// “+ 新增标签”输入框控制器（标签 chips 下方的输入框）。
  final TextEditingController _newTagController = TextEditingController();

  /// 记录已加载过的 category/style/subStyle，用于 didUpdateWidget 判断是否需要重新加载
  String? _lastLoadedCategory;
  String? _lastLoadedStyle;
  String? _lastLoadedSubStyle;

  @override
  void initState() {
    super.initState();
    _loadTypeOptions();
    _loadStyleOptions(widget.form.meta.category);
    _loadSubStyleOptions(widget.form.meta.style);
    _loadMethod4Options(widget.form.meta.subStyle);
  }

  @override
  void dispose() {
    _newTagController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _Step1TemplateInfo oldWidget) {
    super.didUpdateWidget(oldWidget);
    // v17: 分类变化时重新加载二级 style 选项
    if (widget.form.meta.category != _lastLoadedCategory) {
      _loadStyleOptions(widget.form.meta.category);
    }
    // style 变化时重新加载三级 subStyle 选项
    if (widget.form.meta.style != _lastLoadedStyle) {
      _loadSubStyleOptions(widget.form.meta.style);
    }
    // subStyle 变化时重新加载四级 method 选项
    if (widget.form.meta.subStyle != _lastLoadedSubStyle) {
      _loadMethod4Options(widget.form.meta.subStyle);
    }
  }

  Future<void> _loadTypeOptions() async {
    try {
      final dao = await ref.read(templatesDaoProvider.future);
      final cats = await dao.getCategories(activeOnly: true, level: 1);
      if (!mounted) return;
      setState(() {
        _typeOptions = cats.map((c) => EditorOption(c.key, c.name)).toList();
      });
    } catch (e) {
      debugPrint('Failed to load type categories: $e');
    }
  }

  Future<void> _loadStyleOptions(String? categoryKey) async {
    _lastLoadedCategory = categoryKey;
    if (categoryKey == null || categoryKey.isEmpty) {
      if (mounted) setState(() => _styleOptions = const []);
      return;
    }
    try {
      final dao = await ref.read(templatesDaoProvider.future);
      final cats = await dao.getCategoriesByParent(categoryKey);
      if (!mounted) return;
      setState(() {
        _styleOptions = cats.map((c) => EditorOption(c.key, c.name)).toList();
      });
    } catch (e) {
      debugPrint('Failed to load style categories: $e');
    }
  }

  Future<void> _loadSubStyleOptions(String? styleKey) async {
    _lastLoadedStyle = styleKey;
    if (styleKey == null || styleKey.isEmpty) {
      if (mounted) setState(() => _subStyleOptions = const []);
      return;
    }
    try {
      final dao = await ref.read(templatesDaoProvider.future);
      final cats = await dao.getCategoriesByParent(styleKey);
      if (!mounted) return;
      setState(() {
        _subStyleOptions =
            cats.map((c) => EditorOption(c.key, c.name)).toList();
      });
    } catch (e) {
      debugPrint('Failed to load subStyle categories: $e');
    }
  }

  Future<void> _loadMethod4Options(String? subStyleKey) async {
    _lastLoadedSubStyle = subStyleKey;
    if (subStyleKey == null || subStyleKey.isEmpty) {
      if (mounted) setState(() => _method4Options = const []);
      return;
    }
    try {
      final dao = await ref.read(templatesDaoProvider.future);
      final cats = await dao.getCategoriesByParent(subStyleKey);
      if (!mounted) return;
      setState(() {
        _method4Options = cats.map((c) => EditorOption(c.key, c.name)).toList();
      });
    } catch (e) {
      debugPrint('Failed to load method4 categories: $e');
    }
  }

  // ===== 标签 chips 操作 =====

  void _toggleTag(String tag) {
    widget.onChange(() {
      final tags = List<String>.from(widget.form.meta.tags);
      if (tags.contains(tag)) {
        tags.remove(tag);
      } else {
        tags.add(tag);
      }
      widget.form.meta.tags = tags;
    });
  }

  void _addNewTag(String raw) {
    final tag = raw.trim();
    if (tag.isEmpty) return;
    widget.onChange(() {
      final tags = List<String>.from(widget.form.meta.tags);
      if (!tags.contains(tag)) tags.add(tag);
      widget.form.meta.tags = tags;
    });
    _newTagController.clear();
  }

  // ===== 适用季节/天气/时段（ambience）chips =====

  void _toggleSeason(String key) {
    widget.onChange(() {
      final a =
          widget.form.meta.ambience ?? const RemoteTemplateAmbienceDto();
      final list = List<String>.from(a.seasons);
      if (list.contains(key)) {
        list.remove(key);
      } else {
        list.add(key);
      }
      widget.form.meta.ambience = RemoteTemplateAmbienceDto(
        seasons: list,
        weathers: a.weathers,
        timeTones: a.timeTones,
      );
    });
  }

  void _toggleWeather(String key) {
    widget.onChange(() {
      final a =
          widget.form.meta.ambience ?? const RemoteTemplateAmbienceDto();
      final list = List<String>.from(a.weathers);
      if (list.contains(key)) {
        list.remove(key);
      } else {
        list.add(key);
      }
      widget.form.meta.ambience = RemoteTemplateAmbienceDto(
        seasons: a.seasons,
        weathers: list,
        timeTones: a.timeTones,
      );
    });
  }

  void _toggleTimeTone(String key) {
    widget.onChange(() {
      final a =
          widget.form.meta.ambience ?? const RemoteTemplateAmbienceDto();
      final list = List<String>.from(a.timeTones);
      if (list.contains(key)) {
        list.remove(key);
      } else {
        list.add(key);
      }
      widget.form.meta.ambience = RemoteTemplateAmbienceDto(
        seasons: a.seasons,
        weathers: a.weathers,
        timeTones: list,
      );
    });
  }

  // ===== 标签候选 chips 渲染（customTagCandidatesProvider） =====

  List<Widget> _buildTagCandidates(
    ThemeTokens tokens,
    AsyncValue<List<CustomTagOption>> async,
  ) {
    return async.when(
      data: (options) {
        if (options.isEmpty) {
          return [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '暂无候选标签，可在下方新增',
                style: TextStyle(fontSize: 12, color: tokens.textTertiary),
              ),
            ),
          ];
        }
        return [
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options
                .map((o) => _ToggleChip(
                      tokens: tokens,
                      label: o.name,
                      active: widget.form.meta.tags.contains(o.name),
                      onTap: () => _toggleTag(o.name),
                    ))
                .toList(),
          ),
        ];
      },
      loading: () => [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '标签加载中…',
            style: TextStyle(fontSize: 12, color: tokens.textTertiary),
          ),
        ),
      ],
      error: (e, __) => [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '标签加载失败',
            style: TextStyle(fontSize: 12, color: tokens.textTertiary),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 局部别名，避免 body 中大量 widget.xxx 前缀
    final tokens = widget.tokens;
    final form = widget.form;
    final onChange = widget.onChange;
    // style/subStyle/method 为可选字段，首位加"不限"（空值 → null）
    final styleOptions = <EditorOption>[
      const EditorOption('', '不限'),
      ..._styleOptions,
    ];
    final subStyleOptions = <EditorOption>[
      const EditorOption('', '不限'),
      ..._subStyleOptions,
    ];
    final method4Options = <EditorOption>[
      const EditorOption('', '不限'),
      ..._method4Options,
    ];
    // 标签候选（异步聚合自定义模板 tags）
    final tagCandidates = ref.watch(customTagCandidatesProvider);

    // 适用季节/天气/时段 chips 选项（值对齐后端 ambience keys）
    const seasonOptions = <EditorOption>[
      EditorOption('spring', '春'),
      EditorOption('summer', '夏'),
      EditorOption('autumn', '秋'),
      EditorOption('winter', '冬'),
    ];
    const weatherOptions = <EditorOption>[
      EditorOption('sunny', '晴'),
      EditorOption('cloudy', '多云'),
      EditorOption('overcast', '阴'),
      EditorOption('rain', '雨'),
      EditorOption('snow', '雪'),
      EditorOption('fog', '雾'),
    ];
    const timeToneOptions = <EditorOption>[
      EditorOption('goldenHour', '黄金小时'),
      EditorOption('day', '白天'),
      EditorOption('night', '夜晚'),
      EditorOption('warm', '暖调'),
      EditorOption('cool', '冷调'),
    ];

    final ambience = form.meta.ambience;

    return _StepCard(
      tokens: tokens,
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
          // v17: 分类（type，必选）— 选项从 DAO level=1 加载
          _FieldLabel(tokens: tokens, text: '分类'),
          _FieldDropdown(
            tokens: tokens,
            value: form.meta.category,
            options: _typeOptions,
            onChanged: (v) => onChange(() {
              form.meta.category = v;
              // 切换分类时清空 style/subStyle/method（级联一致性）
              form.meta.style = null;
              form.meta.subStyle = null;
              form.meta.method = null;
            }),
          ),
          const SizedBox(height: 14),
          // Task6: 短简介（≤20 字）
          _FieldLabel(tokens: tokens, text: '短简介'),
          _FieldInput(
            tokens: tokens,
            initialValue: form.meta.shortDesc,
            placeholder: '一句话介绍（推荐 ≤20 字）',
            maxLength: 20,
            onChanged: (v) => onChange(() => form.meta.shortDesc = v),
          ),
          const SizedBox(height: 14),
          // v17: 风格（style=二级 majorStyle，可选，级联自分类）
          _FieldLabel(tokens: tokens, text: '风格'),
          _FieldDropdown(
            tokens: tokens,
            value: form.meta.style ?? '',
            options: styleOptions,
            onChanged: (v) => onChange(() {
              form.meta.style = v.isEmpty ? null : v;
              // 切换风格时清空 subStyle/method（级联一致性）
              form.meta.subStyle = null;
              form.meta.method = null;
            }),
          ),
          const SizedBox(height: 14),
          // Task6 四级级联第三级：子风格（subStyle，可选，级联自风格）
          _FieldLabel(tokens: tokens, text: '子风格'),
          _FieldDropdown(
            tokens: tokens,
            value: form.meta.subStyle ?? '',
            options: subStyleOptions,
            onChanged: (v) => onChange(() {
              form.meta.subStyle = v.isEmpty ? null : v;
              // 切换子风格时清空 method（级联一致性）
              form.meta.method = null;
            }),
          ),
          const SizedBox(height: 14),
          // Task6 四级级联第四级：方法（method，可选，级联自子风格）
          _FieldLabel(tokens: tokens, text: '方法'),
          _FieldDropdown(
            tokens: tokens,
            value: form.meta.method ?? '',
            options: method4Options,
            onChanged: (v) => onChange(() {
              form.meta.method = v.isEmpty ? null : v;
            }),
          ),
          const SizedBox(height: 14),
          // Task6: 适用季节/天气/时段（ambience chips 多选）
          _FieldLabel(tokens: tokens, text: '适用季节/天气/时段'),
          _AmbienceChipGroup(
            tokens: tokens,
            label: '季节',
            options: seasonOptions,
            selected: ambience?.seasons ?? const [],
            onToggle: _toggleSeason,
          ),
          _AmbienceChipGroup(
            tokens: tokens,
            label: '天气',
            options: weatherOptions,
            selected: ambience?.weathers ?? const [],
            onToggle: _toggleWeather,
          ),
          _AmbienceChipGroup(
            tokens: tokens,
            label: '时段',
            options: timeToneOptions,
            selected: ambience?.timeTones ?? const [],
            onToggle: _toggleTimeTone,
          ),
          const SizedBox(height: 2),
          // Task6: 标签（候选 chips + 新增输入，替代原逗号文本框）
          _FieldLabel(tokens: tokens, text: '标签'),
          ..._buildTagCandidates(tokens, tagCandidates),
          const SizedBox(height: 8),
          _FieldInput(
            tokens: tokens,
            controller: _newTagController,
            placeholder: '+ 新增标签（回车添加）',
            onSubmitted: _addNewTag,
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

/// Task6: 可切换 chip（用于标签/ambience 等多选），主题自适应。
class _ToggleChip extends ConsumerWidget {
  const _ToggleChip({
    required this.tokens,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final ThemeTokens tokens;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNeumorphic = ref.watch(uiStyleProvider) == UIStyle.neumorphic;
    return GestureDetector(
      onTap: onTap,
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
              ? (active ? tokens.shadowConvex : tokens.shadowConvexSubtle)
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: active ? tokens.textInverse : tokens.textSecondary,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// Task6: 单一 ambience 维度（季节/天气/时段）的 chips 分组，主题自适应。
class _AmbienceChipGroup extends ConsumerWidget {
  const _AmbienceChipGroup({
    required this.tokens,
    required this.label,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final ThemeTokens tokens;
  final String label;
  final List<EditorOption> options;
  final List<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(tokens: tokens, text: label),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options
                .map((o) => _ToggleChip(
                      tokens: tokens,
                      label: o.label,
                      active: selected.contains(o.value),
                      onTap: () => onToggle(o.value),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// 封面图占位（未设置封面图时显示）
class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 32,
            color: tokens.textTertiary,
          ),
          const SizedBox(height: 6),
          Text(
            '点击添加封面图',
            style: TextStyle(
              fontSize: 12,
              color: tokens.textTertiary,
            ),
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
            onChanged: (v) => onChange(() => form.composition.overlayType = v),
          ),
          const SizedBox(height: 14),
          _FieldLabel(tokens: tokens, text: '宽高比'),
          _PillGroup(
            tokens: tokens,
            options: aspectRatioOptions,
            value: form.composition.aspectRatio,
            onChanged: (v) => onChange(() => form.composition.aspectRatio = v),
          ),
          const SizedBox(height: 14),
          _SliderRow(
            tokens: tokens,
            label: '透明度',
            value: form.composition.opacity,
            min: 0,
            max: 1,
            divisions: 10,
            onChanged: (v) => onChange(() => form.composition.opacity = v),
            valueText: form.composition.opacity.toStringAsFixed(1),
          ),
          _FieldLabel(tokens: tokens, text: '构图说明'),
          _FieldInput(
            tokens: tokens,
            initialValue: form.composition.description,
            placeholder: '构图说明',
            multiline: true,
            onChanged: (v) => onChange(() => form.composition.description = v),
          ),
          const SizedBox(height: 14),
          _PreviewBox(
            tokens: tokens,
            aspectRatio:
                _effectiveAspectRatio(form.composition.aspectRatio, context),
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
    required this.compositionAspectRatio,
    required this.isDragging,
    required this.poseVersionNotifier,
    required this.onSourceChange,
    required this.onSelectBuiltin,
    required this.onImportImage,
    required this.onOpenEditor,
    required this.onChange,
    required this.onPoseDragStart,
    required this.onPoseDragUpdate,
    required this.onPoseDragEnd,
    required this.onPosePositionSliderChanged,
    required this.onScaleSliderChanged,
    required this.onRotationSliderChanged,
  });

  final ThemeTokens tokens;
  final EditorForm form;
  final String compositionAspectRatio;
  final bool isDragging;
  final ValueNotifier<int> poseVersionNotifier;
  final ValueChanged<String> onSourceChange;
  final ValueChanged<String> onSelectBuiltin;
  final VoidCallback onImportImage;
  final VoidCallback onOpenEditor;
  final void Function(void Function() mutator) onChange;
  final void Function(DragStartDetails) onPoseDragStart;
  final void Function(DragUpdateDetails, BoxConstraints) onPoseDragUpdate;
  final void Function(DragEndDetails) onPoseDragEnd;
  final void Function(bool isX, double v) onPosePositionSliderChanged;
  final ValueChanged<double> onScaleSliderChanged;
  final ValueChanged<double> onRotationSliderChanged;

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      tokens: tokens,
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
          ValueListenableBuilder<int>(
            valueListenable: poseVersionNotifier,
            builder: (context, _, __) {
              return _SliderRow(
                tokens: tokens,
                label: '位置 X',
                value: form.pose.position.x,
                min: 0,
                max: 1,
                divisions: 100,
                onChanged: (v) => onPosePositionSliderChanged(true, v),
                valueText: form.pose.position.x.toStringAsFixed(2),
              );
            },
          ),
          ValueListenableBuilder<int>(
            valueListenable: poseVersionNotifier,
            builder: (context, _, __) {
              return _SliderRow(
                tokens: tokens,
                label: '位置 Y',
                value: form.pose.position.y,
                min: 0,
                max: 1,
                divisions: 100,
                onChanged: (v) => onPosePositionSliderChanged(false, v),
                valueText: form.pose.position.y.toStringAsFixed(2),
              );
            },
          ),
          ValueListenableBuilder<int>(
            valueListenable: poseVersionNotifier,
            builder: (context, _, __) {
              return _SliderRow(
                tokens: tokens,
                label: '缩放',
                value: form.pose.scale,
                min: 0.3,
                max: 2.5,
                divisions: 110,
                onChanged: onScaleSliderChanged,
                valueText: form.pose.scale.toStringAsFixed(2),
              );
            },
          ),
          ValueListenableBuilder<int>(
            valueListenable: poseVersionNotifier,
            builder: (context, _, __) {
              return _SliderRow(
                tokens: tokens,
                label: '旋转',
                value: form.pose.rotation,
                min: -45,
                max: 45,
                divisions: 90,
                onChanged: onRotationSliderChanged,
                valueText: '${form.pose.rotation.round()}°',
              );
            },
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
          // 预览框（可拖动）—— 用 RepaintBoundary 隔离重绘，
          // ValueListenableBuilder 监听版本计数器，拖动时只重建此部分而非整个 page
          // 拖动区域比例使用构图宽高比 + 方向自适应
          AspectRatio(
            aspectRatio: _effectiveAspectRatio(compositionAspectRatio, context),
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
                          // 剪影 —— ValueListenableBuilder 局部重建（版本计数器触发）
                          ValueListenableBuilder<int>(
                            valueListenable: poseVersionNotifier,
                            builder: (context, _, __) {
                              return Positioned.fill(
                                child: SilhouetteLayer(
                                  silhouetteType: form.pose.silhouette.type,
                                  silhouetteData: form.pose.silhouette.data,
                                  positionX: form.pose.position.x,
                                  positionY: form.pose.position.y,
                                  scale: form.pose.scale,
                                  rotation: form.pose.rotation,
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
            ValueListenableBuilder<int>(
              valueListenable: poseVersionNotifier,
              builder: (context, _, __) {
                return Text(
                  '位置 X: ${(form.pose.position.x * 100).round()}%  Y: ${(form.pose.position.y * 100).round()}%',
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
                    ? (active ? tokens.shadowConvex : tokens.shadowConvexSubtle)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    key == 'none' ? Icons.close : Icons.person_outline,
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
            onChanged: (v) =>
                onChange(() => form.camera.exposureCompensation = v.toDouble()),
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
          const SizedBox(height: 14),
          _FieldLabel(tokens: tokens, text: '补光灯'),
          _SliderRow(
            tokens: tokens,
            label: '启用',
            value: form.fillLight?.enabled == true ? 1.0 : 0.0,
            min: 0,
            max: 1,
            divisions: 1,
            onChanged: (v) => onChange(() {
              form.fillLight ??= EditorFormFillLight();
              form.fillLight!.enabled = v > 0.5;
            }),
            valueText: form.fillLight?.enabled == true ? '开' : '关',
          ),
          if (form.fillLight?.enabled == true)
            _SliderRow(
              tokens: tokens,
              label: '强度',
              value: form.fillLight?.intensity ?? 0.8,
              min: 0.1,
              max: 1.5,
              divisions: 14,
              onChanged: (v) => onChange(() {
                form.fillLight ??= EditorFormFillLight();
                form.fillLight!.intensity = v;
              }),
              valueText: (form.fillLight?.intensity ?? 0.8).toStringAsFixed(1),
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
            value: form.postProcess.color.brightness,
            min: -100,
            max: 100,
            divisions: 200,
            onChanged: (v) =>
                onChange(() => form.postProcess.color.brightness = v),
            valueText: formatSigned(form.postProcess.color.brightness),
          ),
          _SliderRow(
            tokens: tokens,
            label: '对比',
            value: form.postProcess.color.contrast,
            min: -100,
            max: 100,
            divisions: 200,
            onChanged: (v) =>
                onChange(() => form.postProcess.color.contrast = v),
            valueText: formatSigned(form.postProcess.color.contrast),
          ),
          _SliderRow(
            tokens: tokens,
            label: '饱和',
            value: form.postProcess.color.saturation,
            min: -100,
            max: 100,
            divisions: 200,
            onChanged: (v) =>
                onChange(() => form.postProcess.color.saturation = v),
            valueText: formatSigned(form.postProcess.color.saturation),
          ),
          _SliderRow(
            tokens: tokens,
            label: '色温',
            value: form.postProcess.color.temperature,
            min: -100,
            max: 100,
            divisions: 200,
            onChanged: (v) =>
                onChange(() => form.postProcess.color.temperature = v),
            valueText: formatSigned(form.postProcess.color.temperature),
          ),
          _SliderRow(
            tokens: tokens,
            label: '色调',
            value: form.postProcess.color.tint,
            min: -100,
            max: 100,
            divisions: 200,
            onChanged: (v) => onChange(() => form.postProcess.color.tint = v),
            valueText: formatSigned(form.postProcess.color.tint),
          ),
          _SliderRow(
            tokens: tokens,
            label: '高光',
            value: form.postProcess.color.highlights ?? 0,
            min: -100,
            max: 100,
            divisions: 200,
            onChanged: (v) =>
                onChange(() => form.postProcess.color.highlights = v),
            valueText: formatSigned(form.postProcess.color.highlights ?? 0),
          ),
          _SliderRow(
            tokens: tokens,
            label: '阴影',
            value: form.postProcess.color.shadows ?? 0,
            min: -100,
            max: 100,
            divisions: 200,
            onChanged: (v) =>
                onChange(() => form.postProcess.color.shadows = v),
            valueText: formatSigned(form.postProcess.color.shadows ?? 0),
          ),
          _SliderRow(
            tokens: tokens,
            label: '黑点',
            value: form.postProcess.color.blackPoint ?? 0,
            min: -100,
            max: 100,
            divisions: 200,
            onChanged: (v) =>
                onChange(() => form.postProcess.color.blackPoint = v),
            valueText: formatSigned(form.postProcess.color.blackPoint ?? 0),
          ),
          _SliderRow(
            tokens: tokens,
            label: '自然饱和',
            value: form.postProcess.color.vibrance ?? 0,
            min: -100,
            max: 100,
            divisions: 200,
            onChanged: (v) =>
                onChange(() => form.postProcess.color.vibrance = v),
            valueText: formatSigned(form.postProcess.color.vibrance ?? 0),
          ),
          _SliderRow(
            tokens: tokens,
            label: '鲜明度',
            value: form.postProcess.color.brilliance ?? 0,
            min: -100,
            max: 100,
            divisions: 200,
            onChanged: (v) =>
                onChange(() => form.postProcess.color.brilliance = v),
            valueText: formatSigned(form.postProcess.color.brilliance ?? 0),
          ),
          _SliderRow(
            tokens: tokens,
            label: '清晰度',
            value: form.postProcess.color.clarity ?? 0,
            min: -100,
            max: 100,
            divisions: 200,
            onChanged: (v) =>
                onChange(() => form.postProcess.color.clarity = v),
            valueText: formatSigned(form.postProcess.color.clarity ?? 0),
          ),
          _SliderRow(
            tokens: tokens,
            label: '磨皮',
            value: form.postProcess.smoothStrength.toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            onChanged: (v) =>
                onChange(() => form.postProcess.smoothStrength = v.round()),
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
          boxShadow:
              isNeumorphic && !isPrimary ? tokens.shadowConvexSubtle : null,
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
