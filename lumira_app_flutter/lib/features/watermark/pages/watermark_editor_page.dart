import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../../core/db/dao/gallery_dao.dart' show GalleryItemRecord;
import '../../../core/db/database_provider.dart'
    show galleryDaoProvider, watermarkDaoProvider;
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/images/lumira_image.dart';
import '../../../shared/widgets/effects/breathing_tap.dart';
import '../../../shared/widgets/lumira/lumira.dart'
    show
        LumiraSlider,
        LumiraSwitch,
        LumiraTextField,
        LumiraToast,
        showLumiraSaveModeSheet;
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/watermark_providers.dart';
import '../models/watermark_template.dart';

/// 底部操作栏的 Tab。
enum _EditorTab { element, style, border }

/// 全屏沉浸式水印编辑器。
///
/// 双模式：
/// - 模板模式（[templateId] 非空，或两者皆空 → 新建空白模板）：编辑并保存水印模板。
/// - 应用模式（[photoPath] 非空）：读取真实照片，把水印渲染到照片上并另存为新照片。
///
/// 布局：
/// - 顶部 [LumiraNav]（取消 / 标题 / 保存）
/// - 全屏照片预览（`BoxFit.contain` 等比适配，周围黑色留白）
/// - 底部可收起操作栏（展开含「元素 / 样式 / 边框」三个 Tab）
///
/// 预览/手势：点选元素、单指拖拽移动、双指捏合缩放。
class WatermarkEditorPage extends ConsumerStatefulWidget {
  const WatermarkEditorPage({super.key, this.templateId, this.photoPath});

  /// 模板模式：要编辑的模板 id（预置或自定义）。为空则新建空白模板。
  final String? templateId;

  /// 应用模式：真实照片的本地文件路径。非空时进入"保存并应用"。
  final String? photoPath;

  @override
  ConsumerState<WatermarkEditorPage> createState() =>
      WatermarkEditorPageState();
}

class WatermarkEditorPageState extends ConsumerState<WatermarkEditorPage> {
  /// 模板模式下用于预览的示例照片资源。
  static const String _sampleAsset = 'assets/images/watermark_sample.jpg';
  static const double _collapsedHeight = 40.0;
  // 叠照片深色沉浸底兜底常量（跨风格叠加视觉的合法例外，非主题色硬编码）。
  static const Color _immersiveDeep = Color(0xFF1B1A18);

  /// 深拷贝时保证元素 id 唯一（同一编辑会话内多次拷贝不冲突）。
  static int _copyCounter = 0;

  late WatermarkTemplate _template;
  String? _selectedElementId;
  bool _expanded = true;
  _EditorTab _tab = _EditorTab.element;

  /// 背景照片字节（模板模式为示例照片，应用模式为真实照片）。
  Uint8List? _photoBytes;
  String? _photoDataUrl;
  double? _sourceAspect;

  late final TextEditingController _textEditController;
  bool _isSaving = false;

  // 拖拽 / 缩放起始快照。
  double? _scaleStartFontSize;

  /// 测试钩子：当前正在编辑的模板（含最新元素/画框状态）。
  @visibleForTesting
  WatermarkTemplate get template => _template;

  /// 测试钩子：当前选中的元素 id。
  @visibleForTesting
  String? get selectedElementId => _selectedElementId;

  WatermarkElement? get _selectedElement {
    final id = _selectedElementId;
    if (id == null) return null;
    for (final e in _template.elements) {
      if (e.id == id) return e;
    }
    return null;
  }

  bool get _isApplyMode => widget.photoPath != null;

  @override
  void initState() {
    super.initState();
    _textEditController = TextEditingController();
    _initTemplate();
    _loadBaseImage();
  }

  @override
  void dispose() {
    _textEditController.dispose();
    super.dispose();
  }

  // === 模板初始化 ===

  void _initTemplate() {
    final presets = ref.read(presetWatermarksProvider);
    final customs = ref.read(customWatermarksProvider);

    WatermarkTemplate? source;

    if (widget.templateId != null) {
      for (final t in presets) {
        if (t.id == widget.templateId) {
          source = t;
          break;
        }
      }
      if (source == null) {
        for (final t in customs) {
          if (t.id == widget.templateId) {
            source = t;
            break;
          }
        }
      }
    } else if (_isApplyMode) {
      // 应用模式：取当前选中模板，否则用首个预置。
      source = ref.read(currentWatermarkTemplateProvider);
      source ??= presets.isNotEmpty ? presets.first : null;
    }

    if (source == null) {
      // 新建空白模板（模板模式 + templateId == null）。
      _template = _newBlankTemplate();
    } else {
      _template = _deepCopyTemplate(source);
    }
  }

  WatermarkTemplate _newBlankTemplate() {
    final now = DateTime.now();
    final id = _nextId();
    return WatermarkTemplate(
      id: 'custom_${now.millisecondsSinceEpoch}',
      name: '新水印',
      type: WatermarkTemplateType.custom,
      createdAt: now,
      elements: [
        WatermarkElement(
          id: id,
          type: WatermarkElementType.text,
          text: 'LUMIRA',
          x: 0.5,
          y: 0.9,
          fontSize: 0.04,
          textAlign: TextAlign.center,
        ),
      ],
      frame: const WatermarkFrame(),
    );
  }

  WatermarkTemplate _deepCopyTemplate(WatermarkTemplate source) {
    final now = DateTime.now();
    return WatermarkTemplate(
      id: 'custom_${now.millisecondsSinceEpoch}',
      name: source.name.isEmpty ? '自定义水印' : '${source.name}（副本）',
      type: WatermarkTemplateType.custom,
      createdAt: now,
      elements:
          source.elements.map((e) => e.copyWith(id: _nextId())).toList(),
      // WatermarkFrame 为不可变对象，可直接共享引用。
      frame: source.frame,
    );
  }

  static String _nextId() {
    _copyCounter += 1;
    return 'el_${DateTime.now().microsecondsSinceEpoch}_$_copyCounter';
  }

  Future<void> _loadBaseImage() async {
    try {
      final Uint8List bytes;
      if (_isApplyMode) {
        bytes = await File(widget.photoPath!).readAsBytes();
      } else {
        final data = await rootBundle.load(_sampleAsset);
        bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      }
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final w = image.width;
      final h = image.height;
      image.dispose();
      codec.dispose();
      if (!mounted) return;
      setState(() {
        _photoBytes = bytes;
        _photoDataUrl =
            bytes.isEmpty ? null : 'data:image/jpeg;base64,${base64Encode(bytes)}';
        _sourceAspect = (w > 0 && h > 0) ? w / h : 1.0;
      });
    } catch (e) {
      debugPrint('[watermark-editor] load base image failed: $e');
      if (!mounted) return;
      setState(() {});
    }
  }

  // === 元素操作 ===

  void _selectElement(WatermarkElement el) {
    setState(() {
      _selectedElementId = el.id;
      _textEditController.text = el.text;
    });
  }

  void _addElement(WatermarkElementType type) {
    final isDate = type == WatermarkElementType.dateTime;
    final el = WatermarkElement(
      id: _nextId(),
      type: type,
      text: isDate ? '2026.08.20' : '',
      x: 0.5,
      y: 0.9,
      fontSize: 0.04,
      textAlign: TextAlign.center,
    );
    setState(() {
      _template.elements.add(el);
      _selectedElementId = el.id;
      _textEditController.text = el.text;
    });
  }

  void _copyElement(WatermarkElement el) {
    final copy = el.copyWith(id: _nextId());
    final index = _template.elements.indexOf(el);
    setState(() {
      _template.elements.insert(index + 1, copy);
      _selectedElementId = copy.id;
      _textEditController.text = copy.text;
    });
  }

  void _removeElement(WatermarkElement el) {
    setState(() {
      _template.elements.removeWhere((e) => e.id == el.id);
      if (_selectedElementId == el.id) {
        _selectedElementId = null;
      }
    });
  }

  void _updateFrame(WatermarkFrame Function(WatermarkFrame) mutate) {
    setState(() {
      _template = WatermarkTemplate(
        id: _template.id,
        name: _template.name,
        type: _template.type,
        createdAt: _template.createdAt,
        elements: _template.elements,
        frame: mutate(_template.frame),
      );
    });
  }

  void _setFrameType(WatermarkFrameType t) {
    _updateFrame((f) {
      switch (t) {
        case WatermarkFrameType.none:
          return f.copyWith(type: WatermarkFrameType.none);
        case WatermarkFrameType.polaroid:
          return f.copyWith(
            type: WatermarkFrameType.polaroid,
            color: const Color(0xFFFFFFFF),
            borderTop: 0.05,
            borderRight: 0.05,
            borderBottom: 0.05,
            borderLeft: 0.05,
            borderRadius: 0.0,
            bottomPlate: true,
            bottomRatio: 0.18,
            borderFill: WatermarkBorderFill.solid,
            gradientEndColor: const Color(0xFFFFFFFF),
            gradientDirection: WatermarkGradientDirection.topToBottom,
            shadowOpacity: 0.22,
          );
        case WatermarkFrameType.innerBorder:
          return f.copyWith(
            type: WatermarkFrameType.innerBorder,
            color: const Color(0xFFFFFFFF),
            borderRatio: 0.02,
            borderRadius: 0.0,
          );
      }
    });
  }

  // === 保存 ===

  Future<void> _saveTemplate() async {
    if (_template.name.isEmpty) {
      _template.name = '自定义水印';
    }
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      final dao = await ref.read(watermarkDaoProvider.future);
      await dao.insert(_template);
      ref.read(customWatermarksProvider.notifier).state = [
        ...ref.read(customWatermarksProvider),
        _template,
      ];
    } catch (e) {
      debugPrint('[watermark-editor] persist custom template failed: $e');
    }
    setWatermarkActive(container, _template.id);
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _saveApply() async {
    if (_isSaving || _photoBytes == null) return;
    final saveMode = await showLumiraSaveModeSheet(context: context);
    if (saveMode == null || !mounted) return;
    setState(() => _isSaving = true);

    ui.Image? sourceImage;
    try {
      final codec = await ui.instantiateImageCodec(_photoBytes!);
      final frame = await codec.getNextFrame();
      sourceImage = frame.image;
      codec.dispose();

      final renderer = ref.read(watermarkRendererProvider);
      final r =
          await renderer.render(sourceImage: sourceImage, template: _template);
      final output = img.Image.fromBytes(
        width: r.width,
        height: r.height,
        bytes: r.rgbaBytes.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );
      final jpegBytes = img.encodeJpg(output, quality: 90);

      // 应用模式以「另存新照片」为主：不管 replace/duplicate 均写入新文件。
      final sourcePath = widget.photoPath!;
      final outPath = _makeDuplicatePath(sourcePath);
      await File(outPath).writeAsBytes(jpegBytes);

      final dao = await ref.read(galleryDaoProvider.future);
      await dao.insert(GalleryItemRecord(
        id: 'photo_${DateTime.now().millisecondsSinceEpoch}',
        filePath: outPath,
        originalPath: sourcePath,
        templateId: _template.id,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));
      ref.invalidate(galleryDaoProvider);

      if (mounted) {
        LumiraToast.show(context, '已另存为新照片',
            duration: const Duration(seconds: 1));
        Navigator.of(context).maybePop();
      }
    } catch (e, st) {
      debugPrint('[watermark-editor] apply save failed: $e\n$st');
      if (mounted) {
        LumiraToast.show(context, '保存失败：$e');
      }
    } finally {
      sourceImage?.dispose();
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _makeDuplicatePath(String sourcePath) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final dot = sourcePath.lastIndexOf('.');
    if (dot <= 0) return '${sourcePath}_$now.jpg';
    return '${sourcePath.substring(0, dot)}_$now${sourcePath.substring(dot)}';
  }

  void _cancel() {
    Navigator.of(context).maybePop();
  }

  /// 深色沉浸预览底：优先取 [ThemeTokens.canvasDeep]（ink 主题即 0xFF151310）；
  /// 对暖/浅主题（canvasDeep 过浅）用 [_immersiveDeep] 兜底，保证任何主题下都有沉浸感。
  Color _previewBg(ThemeTokens tokens) {
    final deep = tokens.canvasDeep;
    if (deep.computeLuminance() > 0.3) return _immersiveDeep;
    return deep;
  }

  /// 按压缩放系数：女性美学 0.96，其余 0.98。
  double _scaleFor(UIStyle style) => style == UIStyle.female ? 0.96 : 0.98;

  /// 全页面小按钮/芯片/选项的统一风格自适应背景解析。
  /// [active] 选中态；[raised] 指示"常驻凸起钮"（新拟态下即使未选中也带轻微浮雕）；
  /// [danger] 让激活边框/底对应 danger 语义。
  BoxDecoration _chipDeco(ThemeTokens tokens, UIStyle style,
      {required bool active,
      required double radius,
      bool danger = false,
      bool raised = false}) {
    final Color activeBg = danger ? tokens.dangerSubtle : tokens.brandSubtle;
    final Color accent = danger ? tokens.danger : tokens.brand;
    final BorderRadius r = BorderRadius.circular(radius);
    switch (style) {
      case UIStyle.neumorphic:
        return BoxDecoration(
          color: active
              ? activeBg
              : (raised ? tokens.surface : tokens.surfaceAlt),
          borderRadius: r,
          boxShadow: (raised || active) ? tokens.shadowConvexSubtle : const [],
        );
      case UIStyle.flat:
        return BoxDecoration(
          color: active
              ? activeBg
              : (raised ? tokens.surface : tokens.surfaceAlt),
          borderRadius: r,
          border: Border.all(
            color: active ? accent : tokens.divider,
            width: 1,
          ),
        );
      case UIStyle.glass:
        return BoxDecoration(
          color: active
              ? Colors.white.withOpacity(0.4)
              : Colors.white.withOpacity(raised ? 0.2 : 0.0),
          borderRadius: r,
          border: Border.all(
            color: active
                ? Colors.white.withOpacity(0.6)
                : Colors.white.withOpacity(raised ? 0.3 : 0.0),
            width: 1,
          ),
        );
      case UIStyle.female:
        if (active) {
          return BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                activeBg.withOpacity(0.8),
                tokens.surface.withOpacity(0.55),
              ],
            ),
            borderRadius: r,
            border: Border.all(
              color: accent.withOpacity(0.35),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.brand.withOpacity(0.18),
                offset: const Offset(0, 4),
                blurRadius: 12,
              ),
            ],
          );
        }
        return BoxDecoration(
          color: Colors.transparent,
          borderRadius: r,
          border: Border.all(
            color: raised
                ? tokens.brand.withOpacity(0.2)
                : tokens.brand.withOpacity(0.12),
            width: 0.8,
          ),
        );
    }
  }

  /// 底部操作栏面板表面（按 4 风格）。外壳在纯色画布上 → 新拟态可用实心凸起/细边；
  /// 玻璃用本风格半透明白；女性用 brandSubtle→surface 渐变。
  BoxDecoration _panelDecoration(ThemeTokens tokens, UIStyle style) {
    switch (style) {
      case UIStyle.neumorphic:
        return BoxDecoration(
          color: tokens.surface,
          border: Border(
            top: BorderSide(color: tokens.divider, width: 0.5),
          ),
        );
      case UIStyle.flat:
        return BoxDecoration(
          color: tokens.surface,
          border: Border(top: BorderSide(color: tokens.divider, width: 1)),
        );
      case UIStyle.glass:
        return BoxDecoration(
          color: Colors.white.withOpacity(0.55),
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.4), width: 1),
          ),
        );
      case UIStyle.female:
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [tokens.brandSubtle, tokens.surface],
          ),
          border: Border(
            top: BorderSide(color: tokens.brand.withOpacity(0.25), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: tokens.brand.withOpacity(0.12),
              offset: const Offset(0, -2),
              blurRadius: 12,
            ),
          ],
        );
    }
  }

  // === build ===

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final style = ref.watch(uiStyleProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: Column(
        children: [
          _buildNav(tokens),
          Expanded(child: _buildPreviewArea(tokens, style)),
          _buildBottomPanel(tokens, style),
        ],
      ),
    );
  }

  Widget _buildNav(ThemeTokens tokens) {
    return LumiraNav(
      title: _isApplyMode ? '添加水印' : '编辑水印',
      leading: GestureDetector(
        onTap: _cancel,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            '取消',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: tokens.textSecondary,
            ),
          ),
        ),
      ),
      actions: [
        GestureDetector(
          onTap: _isApplyMode ? _saveApply : _saveTemplate,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              _isApplyMode ? '保存并应用' : '保存',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: tokens.brand,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewArea(ThemeTokens tokens, UIStyle style) {
    final frame = _template.frame;
    final aspect = (_sourceAspect != null && _sourceAspect! > 0)
        ? _sourceAspect!
        : 1.0;
    return Container(
      key: const ValueKey('wm-preview-area'),
      color: _previewBg(tokens),
      child: Center(
        child: frame.type == WatermarkFrameType.polaroid
            ? _buildPolaroidPreview(tokens, style)
            : AspectRatio(
                aspectRatio: aspect,
                child: ClipRect(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final photoRect = Offset.zero & c.biggest;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _photoImage(),
                          if (frame.type == WatermarkFrameType.innerBorder)
                            _buildInnerBorderOverlay(photoRect, frame),
                          ..._template.elements
                              .map((e) => _buildElementOverlay(e, photoRect)),
                        ],
                      );
                    },
                  ),
                ),
              ),
      ),
    );
  }

  Widget _photoImage() {
    final url = _photoDataUrl;
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    return LumiraImage(url, fit: BoxFit.fill);
  }

  /// 拍立得预览：白边向外扩展，照片区域缩小并被四周白边包围；
  /// 与真实渲染一致，因此配图围绕外扩的卡片底布局。
  Widget _buildPolaroidPreview(ThemeTokens tokens, UIStyle style) {
    final aspect = (_sourceAspect != null && _sourceAspect! > 0)
        ? _sourceAspect!
        : 1.0;
    final f = _template.frame;
    return LayoutBuilder(builder: (context, c) {
      final availW = c.maxWidth;
      final availH = c.maxHeight;
      if (availW <= 0 || availH <= 0) return const SizedBox.shrink();

      // 以照片高为 1 单位：photoW = aspect；边宽/白板均按 x 照片宽换算。
      final photoW = aspect;
      const photoH = 1.0;
      final pL = f.borderLeft * photoW;
      final pR = f.borderRight * photoW;
      final pT = f.borderTop * photoW;
      final pB = f.borderBottom * photoW +
          (f.bottomPlate ? f.bottomRatio * photoH : 0.0);
      final shadowOn = f.shadowOpacity > 0;
      final shadowH = shadowOn ? photoW * 0.1 : 0.0;
      final cardW = photoW + pL + pR;
      final cardH = photoH + pT + pB;
      final totalH = cardH + shadowH;

      final scale = math.min(availW / cardW, availH / totalH);
      if (scale <= 0) return const SizedBox.shrink();

      final w = cardW * scale;
      final h = totalH * scale;
      final radius = BorderRadius.circular(f.borderRadius * cardW * scale);
      final photoRect = Rect.fromLTWH(
          pL * scale, pT * scale, photoW * scale, photoH * scale);

      return SizedBox(
        width: w,
        height: h,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              width: cardW * scale,
              height: cardH * scale,
              child: DecoratedBox(
                decoration: _frameCardDecoration(f, radius),
              ),
            ),
            Positioned(
              left: photoRect.left,
              top: photoRect.top,
              width: photoRect.width,
              height: photoRect.height,
              child: ClipRRect(
                borderRadius: radius,
                child: _photoImage(),
              ),
            ),
            ..._template.elements.map((e) => _buildElementOverlay(e, photoRect)),
          ],
        ),
      );
    });
  }

  /// 卡片底（白边/白板）外观：纯色或渐变色 + 圆角 + 底部投影。
  BoxDecoration _frameCardDecoration(WatermarkFrame f, BorderRadius radius) {
    final gradient = f.borderFill == WatermarkBorderFill.gradient;
    return BoxDecoration(
      color: gradient ? null : f.color,
      gradient: gradient
          ? LinearGradient(
              begin: _gradientBegin(f.gradientDirection),
              end: _gradientEnd(f.gradientDirection),
              colors: [f.color, f.gradientEndColor],
            )
          : null,
      borderRadius: radius,
      boxShadow: f.shadowOpacity > 0
          ? [
              BoxShadow(
                color: f.shadowColor.withOpacity(f.shadowOpacity),
                offset: const Offset(0, 6),
                blurRadius: 12,
              ),
            ]
          : null,
    );
  }

  /// 渐变起点 Alignment。
  Alignment _gradientBegin(WatermarkGradientDirection dir) {
    switch (dir) {
      case WatermarkGradientDirection.bottomToTop:
        return Alignment.bottomCenter;
      case WatermarkGradientDirection.leftToRight:
        return Alignment.centerLeft;
      case WatermarkGradientDirection.rightToLeft:
        return Alignment.centerRight;
      case WatermarkGradientDirection.topLeftToBottomRight:
        return Alignment.topLeft;
      case WatermarkGradientDirection.bottomLeftToTopRight:
        return Alignment.bottomLeft;
      case WatermarkGradientDirection.topToBottom:
      default:
        return Alignment.topCenter;
    }
  }

  /// 渐变终点 Alignment。
  Alignment _gradientEnd(WatermarkGradientDirection dir) {
    switch (dir) {
      case WatermarkGradientDirection.bottomToTop:
        return Alignment.topCenter;
      case WatermarkGradientDirection.leftToRight:
        return Alignment.centerRight;
      case WatermarkGradientDirection.rightToLeft:
        return Alignment.centerLeft;
      case WatermarkGradientDirection.topLeftToBottomRight:
        return Alignment.bottomRight;
      case WatermarkGradientDirection.bottomLeftToTopRight:
        return Alignment.topRight;
      case WatermarkGradientDirection.topToBottom:
      default:
        return Alignment.bottomCenter;
    }
  }

  /// 内描边在预览中的呈现（沿边缘向内描边），使该功能可见。
  Widget _buildInnerBorderOverlay(Rect r, WatermarkFrame frame) {
    final stroke = (frame.borderRatio * r.width).clamp(0.0, 24.0);
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: frame.color, width: stroke),
            borderRadius:
                BorderRadius.circular(frame.borderRadius * r.width),
          ),
        ),
      ),
    );
  }

  /// 元素定位基准矩形：按 space 选择照片矩形或拍立得白板矩形（近似）。
  Rect _baseRectFor(WatermarkElementSpace space, Rect photoRect) {
    if (space == WatermarkElementSpace.frame) {
      final f = _template.frame;
      if (f.type == WatermarkFrameType.polaroid && f.bottomPlate) {
        final plateH = f.bottomRatio * photoRect.height;
        return Rect.fromLTRB(
          photoRect.left,
          photoRect.top,
          photoRect.right,
          photoRect.bottom + plateH,
        );
      }
      return photoRect;
    }
    return photoRect;
  }

  Widget _buildElementOverlay(WatermarkElement e, Rect photoRect) {
    final base = _baseRectFor(e.space, photoRect);
    final fontSize = (e.fontSize * base.width).clamp(4.0, 220.0);
    final left = base.left + e.x * base.width - fontSize * 0.5;
    final top = base.top + e.y * base.height - fontSize;
    final selected = e.id == _selectedElementId;

    return Positioned(
          left: left,
          top: top,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _selectElement(e),
            // 单指拖拽 = 焦点位移（focalPointDelta），双指捏合 = scale。
            // scale 手势是 pan 的超集，不能同时声明两者。
            onScaleStart: (_) {
              _scaleStartFontSize = e.fontSize;
            },
            onScaleUpdate: (d) {
              setState(() {
                final dx = d.focalPointDelta.dx / base.width;
                final dy = d.focalPointDelta.dy / base.height;
                e.x = (e.x + dx).clamp(-0.2, 1.2).toDouble();
                e.y = (e.y + dy).clamp(-0.2, 1.2).toDouble();
                final startF = _scaleStartFontSize ?? e.fontSize;
                e.fontSize =
                    (startF * d.scale).clamp(0.01, 0.6).toDouble();
              });
            },
            child: Container(
              foregroundDecoration: selected
                  ? BoxDecoration(
                      border:
                          Border.all(color: Colors.white, width: 1.5),
                    )
                  : null,
              child: Transform.rotate(
                angle: e.rotation,
                child: Text(
                  e.text,
                  maxLines: 1,
                  textAlign: e.textAlign,
                  style: TextStyle(
                    fontSize: fontSize,
                    color: e.color,
                    fontWeight: e.bold ? FontWeight.bold : FontWeight.normal,
                    fontStyle: e.italic ? FontStyle.italic : FontStyle.normal,
                    letterSpacing: e.letterSpacing,
                  ),
                ),
              ),
            ),
          ),
        );
  }

  // === 底部操作栏 ===

  Widget _buildBottomPanel(ThemeTokens tokens, UIStyle style) {
    return SafeArea(
      top: false, // Home indicator 区域由面板 surface 承接，消除黑边
      child: Container(
        decoration: _panelDecoration(tokens, style),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _expanded
              ? _buildExpandedPanel(tokens, style)
              : _buildCollapsedBar(tokens),
        ),
      ),
    );
  }

  Widget _buildCollapsedBar(ThemeTokens tokens) {
    return GestureDetector(
      key: const ValueKey('wm-panel-expand'),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _expanded = true),
      child: SizedBox(
        height: _collapsedHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.keyboard_arrow_up,
                size: 20, color: tokens.textSecondary),
            const SizedBox(width: 4),
            Text(
              '展开操作栏',
              style: TextStyle(fontSize: 12, color: tokens.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedPanel(ThemeTokens tokens, UIStyle style) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 收起
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(
            children: [
              const Spacer(),
              GestureDetector(
                key: const ValueKey('wm-panel-collapse'),
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _expanded = false),
                child: Row(
                  children: [
                    Text(
                      '收起',
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textSecondary,
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down,
                        size: 18, color: tokens.textSecondary),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Tab 行
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              _buildTabButton(_EditorTab.element, '元素',
                  'wm-tab-element', tokens, style),
              const SizedBox(width: 6),
              _buildTabButton(_EditorTab.style, '样式', 'wm-tab-style', tokens,
                  style),
              const SizedBox(width: 6),
              _buildTabButton(_EditorTab.border, '边框',
                  'wm-tab-border', tokens, style),
            ],
          ),
        ),
        Divider(height: 1, color: tokens.divider),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Center(
              child: _buildTabContent(tokens, style),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton(_EditorTab tab, String label, String key,
      ThemeTokens tokens, UIStyle style) {
    final active = _tab == tab;
    final double radius = style == UIStyle.flat ? 8 : 12;
    return Expanded(
      child: BreathingTap(
        onTap: () => setState(() => _tab = tab),
        pressedScale: _scaleFor(style),
        child: Container(
          key: ValueKey(key),
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: _chipDeco(tokens, style,
              active: active, radius: radius, raised: true),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: active ? tokens.brandText : tokens.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(ThemeTokens tokens, UIStyle style) {
    switch (_tab) {
      case _EditorTab.element:
        return _buildElementTab(tokens, style);
      case _EditorTab.style:
        return _buildStyleTab(tokens, style);
      case _EditorTab.border:
        return _buildBorderTab(tokens, style);
    }
  }

  // --- 元素 Tab ---

  Widget _buildElementTab(ThemeTokens tokens, UIStyle style) {
    final selected = _selectedElement;
    if (_template.elements.isEmpty) {
      return Text(
        '暂无元素，点「＋文本」新增',
        style: TextStyle(fontSize: 12, color: tokens.textTertiary),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final e in _template.elements)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _elementChip(e, tokens, style),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _miniButton('＋文本', () => _addElement(WatermarkElementType.text),
                tokens,
                style: style),
            const SizedBox(width: 8),
            _miniButton(
                '＋日期', () => _addElement(WatermarkElementType.dateTime),
                tokens,
                style: style),
            const Spacer(),
            if (selected != null) ...[
              _miniButton('复制', () => _copyElement(selected), tokens,
                  style: style),
              const SizedBox(width: 8),
              _miniButton('删除', () => _removeElement(selected), tokens,
                  danger: true, style: style),
            ],
          ],
        ),
      ],
    );
  }

  Widget _elementChip(WatermarkElement e, ThemeTokens tokens, UIStyle style) {
    final label = e.text.isNotEmpty
        ? e.text
        : (e.type == WatermarkElementType.dateTime ? '日期时间' : '文本');
    final selected = e.id == _selectedElementId;
    return GestureDetector(
      onTap: () => _selectElement(e),
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: _chipDeco(tokens, style,
            active: selected, radius: 18, raised: true),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? tokens.brandText : tokens.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _miniButton(String label, VoidCallback onTap, ThemeTokens tokens,
      {bool danger = false, UIStyle style = UIStyle.neumorphic}) {
    return BreathingTap(
      onTap: onTap,
      pressedScale: _scaleFor(style),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: _chipDeco(tokens, style,
            active: false, radius: 10, danger: danger, raised: true),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: danger ? tokens.danger : tokens.brandText,
          ),
        ),
      ),
    );
  }

  // --- 样式 Tab ---

  Widget _buildStyleTab(ThemeTokens tokens, UIStyle style) {
    final el = _selectedElement;
    if (el == null) {
      return Text(
        '先在上方选中一个元素，再编辑样式',
        style: TextStyle(fontSize: 12, color: tokens.textTertiary),
      );
    }
    final frame = _template.frame;
    final frameReady =
        frame.type == WatermarkFrameType.polaroid && frame.bottomPlate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (el.type == WatermarkElementType.text)
          LumiraTextField(
            controller: _textEditController,
            hintText: '输入文本',
            onChanged: (v) {
              el.text = v;
              setState(() {});
            },
          ),
        const SizedBox(height: 12),
        // 照片 / 白边
        Row(
          children: [
            _spaceOption('照片', WatermarkElementSpace.photo, el, tokens, style),
            const SizedBox(width: 8),
            _spaceOption('白边', WatermarkElementSpace.frame, el, tokens, style,
                enabled: frameReady),
          ],
        ),
        if (!frameReady)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '「白边」需在边框 Tab 使用拍立得白板',
              style: TextStyle(fontSize: 11, color: tokens.textTertiary),
            ),
          ),
        const SizedBox(height: 8),
        _sliderRow(
          label: '字号',
          value: el.fontSize * 400,
          min: 6,
          max: 200,
          divisions: 48,
          onChanged: (v) => setState(() => el.fontSize = v / 400),
          tokens: tokens,
        ),
        _sliderRow(
          label: '透明度',
          value: el.opacity,
          min: 0.1,
          max: 1.0,
          divisions: 18,
          onChanged: (v) => setState(() => el.opacity = v),
          tokens: tokens,
        ),
        _sliderRow(
          label: '旋转',
          value: el.rotation,
          min: -0.5,
          max: 0.5,
          divisions: 20,
          onChanged: (v) => setState(() => el.rotation = v),
          tokens: tokens,
        ),
        _sliderRow(
          label: '字间距',
          value: el.letterSpacing,
          min: 0,
          max: 8,
          divisions: 16,
          onChanged: (v) => setState(() => el.letterSpacing = v),
          tokens: tokens,
        ),
        const SizedBox(height: 6),
        _buildElementPalette(el, tokens),
        const SizedBox(height: 8),
        Row(
          children: [
            _toggleChip('粗体', el.bold, (v) => setState(() => el.bold = v),
                tokens, style),
            const SizedBox(width: 8),
            _toggleChip('斜体', el.italic, (v) => setState(() => el.italic = v),
                tokens, style),
            const SizedBox(width: 8),
            _alignChip(TextAlign.left, '左', el, tokens, style),
            const SizedBox(width: 4),
            _alignChip(TextAlign.center, '中', el, tokens, style),
            const SizedBox(width: 4),
            _alignChip(TextAlign.right, '右', el, tokens, style),
          ],
        ),
      ],
    );
  }

  Widget _spaceOption(String label, WatermarkElementSpace space,
      WatermarkElement el, ThemeTokens tokens, UIStyle style,
      {bool enabled = true}) {
    final active = el.space == space;
    return GestureDetector(
      key: ValueKey('wm-space-$label'),
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => setState(() => el.space = space) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 9),
        decoration: _chipDeco(tokens, style,
            active: active, radius: 10, raised: true),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: enabled
                ? (active ? tokens.brandText : tokens.textSecondary)
                : tokens.textTertiary,
          ),
        ),
      ),
    );
  }

  Widget _buildElementPalette(WatermarkElement el, ThemeTokens tokens) {
    final colors = <Color>[
      const Color(0xFFFFFFFF),
      const Color(0xFF000000),
      tokens.brand,
      tokens.brandText,
      tokens.textPrimary,
      tokens.textSecondary,
    ];
    return Row(
      children: [
        for (final c in colors)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => setState(() => el.color = c),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: el.color == c
                        ? tokens.brand
                        : tokens.textTertiary.withOpacity(0.35),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _toggleChip(String label, bool value, ValueChanged<bool> onChanged,
      ThemeTokens tokens, UIStyle style) {
    final active = value;
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: _chipDeco(tokens, style,
            active: active, radius: 8, raised: true),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: active ? tokens.brandText : tokens.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _alignChip(TextAlign align, String label, WatermarkElement el,
      ThemeTokens tokens, UIStyle style) {
    final active = el.textAlign == align;
    return GestureDetector(
      onTap: () => setState(() => el.textAlign = align),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: _chipDeco(tokens, style,
            active: active, radius: 6, raised: true),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: active ? tokens.brandText : tokens.textSecondary,
          ),
        ),
      ),
    );
  }

  // --- 边框 Tab ---

  Widget _buildBorderTab(ThemeTokens tokens, UIStyle style) {
    final frame = _template.frame;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _frameOption('无', WatermarkFrameType.none, tokens, style),
            const SizedBox(width: 8),
            _frameOption('拍立得', WatermarkFrameType.polaroid, tokens, style),
            const SizedBox(width: 8),
            _frameOption('内描边', WatermarkFrameType.innerBorder, tokens, style),
          ],
        ),
        const SizedBox(height: 12),
        if (frame.type == WatermarkFrameType.polaroid) ...[
          _sectionLabel('白边宽度（四边独立）'),
          _sliderRow(
            label: '上',
            value: frame.borderTop,
            min: 0,
            max: 0.2,
            divisions: 20,
            onChanged: (v) => _updateFrame((f) => f.copyWith(borderTop: v)),
            tokens: tokens,
          ),
          _sliderRow(
            label: '右',
            value: frame.borderRight,
            min: 0,
            max: 0.2,
            divisions: 20,
            onChanged: (v) => _updateFrame((f) => f.copyWith(borderRight: v)),
            tokens: tokens,
          ),
          _sliderRow(
            label: '下',
            value: frame.borderBottom,
            min: 0,
            max: 0.2,
            divisions: 20,
            onChanged: (v) => _updateFrame((f) => f.copyWith(borderBottom: v)),
            tokens: tokens,
          ),
          _sliderRow(
            label: '左',
            value: frame.borderLeft,
            min: 0,
            max: 0.2,
            divisions: 20,
            onChanged: (v) => _updateFrame((f) => f.copyWith(borderLeft: v)),
            tokens: tokens,
          ),
          _toggleRow('白板', frame.bottomPlate,
              (v) => _updateFrame((f) => f.copyWith(bottomPlate: v)), tokens),
          if (frame.bottomPlate)
            _sliderRow(
              label: '白板比例',
              value: frame.bottomRatio,
              min: 0.05,
              max: 0.4,
              divisions: 14,
              onChanged: (v) => _updateFrame((f) => f.copyWith(bottomRatio: v)),
              tokens: tokens,
            ),
          _sliderRow(
            label: '圆角',
            value: frame.borderRadius,
            min: 0,
            max: 0.08,
            divisions: 16,
            onChanged: (v) => _updateFrame((f) => f.copyWith(borderRadius: v)),
            tokens: tokens,
          ),
          _toggleRow('投影', frame.shadowOpacity > 0, (v) => _updateFrame((f) =>
              f.copyWith(shadowOpacity: v ? 0.22 : 0.0)), tokens),
          if (frame.shadowOpacity > 0)
            _sliderRow(
              label: '投影强度',
              value: frame.shadowOpacity,
              min: 0,
              max: 0.6,
              divisions: 12,
              onChanged: (v) =>
                  _updateFrame((f) => f.copyWith(shadowOpacity: v)),
              tokens: tokens,
            ),
          const SizedBox(height: 8),
          _buildPolaroidColorSettings(frame, tokens, style),
        ] else if (frame.type == WatermarkFrameType.innerBorder) ...[
          _colorSwatchRow('描边颜色', frame.color,
              (c) => _updateFrame((f) => f.copyWith(color: c)), tokens),
          const SizedBox(height: 8),
          _sliderRow(
            label: '描边厚度',
            value: frame.borderRatio,
            min: 0.005,
            max: 0.08,
            divisions: 15,
            onChanged: (v) => _updateFrame((f) => f.copyWith(borderRatio: v)),
            tokens: tokens,
          ),
          _sliderRow(
            label: '圆角',
            value: frame.borderRadius,
            min: 0,
            max: 0.08,
            divisions: 16,
            onChanged: (v) => _updateFrame((f) => f.copyWith(borderRadius: v)),
            tokens: tokens,
          ),
        ],
      ],
    );
  }

  Widget _frameOption(
    String label, WatermarkFrameType t, ThemeTokens tokens, UIStyle style) {
    final active = _template.frame.type == t;
    return GestureDetector(
      key: ValueKey('wm-frame-$label'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _setFrameType(t),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: _chipDeco(tokens, style,
            active: active, radius: 10, raised: true),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? tokens.brandText : tokens.textSecondary,
          ),
        ),
      ),
    );
  }

  /// 白边可选的预设色板。
  List<Color> _frameColors(ThemeTokens tokens) {
    return <Color>[
      const Color(0xFFFFFFFF),
      const Color(0xFF000000),
      tokens.brand,
      tokens.brandText,
      tokens.textPrimary,
      tokens.textSecondary,
    ];
  }

  /// 一行「标签 + 可点选的色板」。
  Widget _colorSwatchRow(String label, Color current, ValueChanged<Color> onSelect,
      ThemeTokens tokens) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: tokens.textSecondary),
          ),
        ),
        Flexible(
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final c in _frameColors(tokens))
                GestureDetector(
                  onTap: () => onSelect(c),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: current == c
                            ? tokens.brand
                            : tokens.textTertiary.withOpacity(0.35),
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 拍立得白边颜色设置：纯色 / 渐变切换 + 色板 + 渐变方向。
  Widget _buildPolaroidColorSettings(
      WatermarkFrame frame, ThemeTokens tokens, UIStyle style) {
    final isGradient = frame.borderFill == WatermarkBorderFill.gradient;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _toggleChip('纯色', !isGradient,
                (_) => _updateFrame(
                    (f) => f.copyWith(borderFill: WatermarkBorderFill.solid)),
                tokens,
                style),
            const SizedBox(width: 8),
            _toggleChip('渐变', isGradient,
                (_) => _updateFrame(
                    (f) => f.copyWith(borderFill: WatermarkBorderFill.gradient)),
                tokens,
                style),
          ],
        ),
        const SizedBox(height: 8),
        if (!isGradient) ...[
          _colorSwatchRow('颜色', frame.color,
              (c) => _updateFrame((f) => f.copyWith(color: c)), tokens),
        ] else ...[
          _colorSwatchRow('起始色', frame.color,
              (c) => _updateFrame((f) => f.copyWith(color: c)), tokens),
          const SizedBox(height: 6),
          _colorSwatchRow('结束色', frame.gradientEndColor,
              (c) => _updateFrame((f) => f.copyWith(gradientEndColor: c)),
              tokens),
          const SizedBox(height: 8),
          _sectionLabel('渐变方向', tokens: tokens),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final d in WatermarkGradientDirection.values)
                _dirChip(d, frame, tokens, style),
            ],
          ),
        ],
      ],
    );
  }

  Widget _dirChip(WatermarkGradientDirection dir, WatermarkFrame frame,
      ThemeTokens tokens, UIStyle style) {
    final active = frame.gradientDirection == dir;
    return GestureDetector(
      onTap: () => _updateFrame((f) => f.copyWith(gradientDirection: dir)),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration:
            _chipDeco(tokens, style, active: active, radius: 8, raised: true),
        child: Text(
          _dirLabel(dir),
          style: TextStyle(
            fontSize: 11,
            color: active ? tokens.brandText : tokens.textSecondary,
          ),
        ),
      ),
    );
  }

  String _dirLabel(WatermarkGradientDirection dir) {
    switch (dir) {
      case WatermarkGradientDirection.topToBottom:
        return '上→下';
      case WatermarkGradientDirection.bottomToTop:
        return '下→上';
      case WatermarkGradientDirection.leftToRight:
        return '左→右';
      case WatermarkGradientDirection.rightToLeft:
        return '右→左';
      case WatermarkGradientDirection.topLeftToBottomRight:
        return '左上→右下';
      case WatermarkGradientDirection.bottomLeftToTopRight:
        return '左下→右上';
    }
  }

  /// 分区小标题。
  Widget _sectionLabel(String text, {ThemeTokens? tokens}) {
    final ThemeTokens tk = tokens ?? ref.read(themeTokensProvider);
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: tk.textSecondary,
      ),
    );
  }

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged,
      ThemeTokens tokens) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: tokens.textSecondary),
        ),
        const Spacer(),
        LumiraSwitch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _sliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required ThemeTokens tokens,
    int? divisions,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: tokens.textSecondary),
          ),
        ),
        Expanded(
          child: LumiraSlider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            value.toStringAsFixed(2),
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 11, color: tokens.textTertiary),
          ),
        ),
      ],
    );
  }
}