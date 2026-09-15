import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/theme_tokens.dart';
import '../../core/utils/safe_share.dart';
import '../../core/utils/safe_temp_dir.dart';
import '../widgets/lumira/lumira.dart' show LumiraProgress, LumiraToast, showLumiraBottomSheet;
import '../widgets/poster/poster_ratio.dart';
import '../widgets/poster/poster_style_picker.dart';
import '../widgets/poster/poster_style_registry.dart';

/// 通用海报生成器
///
/// 提供统一的「生成海报 / 导出海报 / 分享海报」三件套底部 Sheet。
/// 调用方传入 [content] Widget 作为海报内容，内部用 [RepaintBoundary]
/// 包裹并在导出/分享时通过 [toImage] 捕获为 PNG。
///
/// 平台兼容：
/// - 导出（保存到相册）：iOS/Android 用 `SaverGallery.saveImage`；
///   HarmonyOS 降级到 `MethodChannel('lumira/photo_saver')` 调用原生 photoAccessHelper。
/// - 分享：`SafeShare.shareXFiles` 三平台均支持，鸿蒙降级到剪贴板。
class PosterGenerator {
  PosterGenerator._();

  /// 弹出海报预览底部 Sheet
  ///
  /// [content] 是海报正文 Widget，会被 [RepaintBoundary] 包裹。
  /// [posterKey] 必须由调用方创建并传入，用于捕获图片。
  /// [fileNamePrefix] 用于导出/分享时的文件名前缀。
  static Future<void> showPoster({
    required BuildContext context,
    required ThemeTokens tokens,
    required String title,
    required Widget content,
    required GlobalKey posterKey,
    required String shareSubject,
    required String shareText,
    required String fileNamePrefix,
    Widget? extraAction,
    GlobalKey? plainContentKey,
  }) async {
    await showLumiraBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PosterSheet(
        tokens: tokens,
        title: title,
        content: content,
        posterKey: posterKey,
        shareSubject: shareSubject,
        shareText: shareText,
        fileNamePrefix: fileNamePrefix,
        extraAction: extraAction,
        plainContentKey: plainContentKey,
      ),
    );
  }

  /// 弹出「带样式选择」的海报预览底部 Sheet
  ///
  /// 顶部为样式切换条，按 [kind] + [ratio] 从 [PosterStyleRegistry] 取可选样式，
  /// 实时切换预览；导出/分享按当前选中样式出图。海报内容由样式构建器依据
  /// [data] 渲染，内部自持 [GlobalKey] 用于捕获。
  static Future<void> showPosterWithStylePicker({
    required BuildContext context,
    required ThemeTokens tokens,
    required String title,
    required PosterKind kind,
    required PosterRatio ratio,
    required PosterStyleData data,
    required String shareSubject,
    required String shareText,
    required String fileNamePrefix,
    List<PosterRatio>? ratioOptions,
    PosterReorderSpec? reorder,
  }) async {
    await showLumiraBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PosterSheet(
        tokens: tokens,
        title: title,
        shareSubject: shareSubject,
        shareText: shareText,
        fileNamePrefix: fileNamePrefix,
        stylePicker: _StylePickerConfig(
          kind: kind,
          ratio: ratio,
          data: data,
          ratioOptions: ratioOptions,
          reorder: reorder,
        ),
      ),
    );
  }
}

/// 照片排序 / 选择配置（精选集海报专用，可选）。
///
/// 传入后 Sheet 显示一个「照片顺序」面板：顶部为已按序选中的横排，可长按拖拽
/// 调整顺序、点右上角 × 移除；若可选照片多于已选，则下方显示可追加候选，点加号
/// 追加（最多 [maxCount] 张）。任意调整都会调用 [buildData] 重建海报数据，
/// 预览实时更新。调整仅本次 Sheet 存活期内有效，不写库。
class PosterReorderSpec {
  PosterReorderSpec({
    required this.allItems,
    required this.initialSelected,
    required this.itemThumb,
    required this.buildData,
    this.maxCount = 9,
  });

  /// 全部可选照片（含初始选中，元素实例需与 [initialSelected] 复用）。
  final List<Object> allItems;

  /// 初始按序选中（[allItems] 的子序列），用于首批海报。
  final List<Object> initialSelected;

  /// 渲染单张照片缩略图（拖拽条 / 候选条共用）。
  final Widget Function(Object item, double size) itemThumb;

  /// 依据当前比例与有序选中照片重建海报数据。
  final PosterStyleData Function(PosterRatio ratio, List<Object> ordered) buildData;

  /// 允许选中的最大照片数（默认 9）。
  final int maxCount;
}

/// 样式选择配置（传此配置时 Sheet 启用样式切换条并持选中态）。
class _StylePickerConfig {
  const _StylePickerConfig({
    required this.kind,
    required this.ratio,
    required this.data,
    this.ratioOptions,
    this.reorder,
  });

  final PosterKind kind;
  final PosterRatio ratio;
  final PosterStyleData data;

  /// 可选：比例档位（如精选集海报的 3:4 / 1:1），非空时显示比例胶囊。
  final List<PosterRatio>? ratioOptions;

  /// 可选：照片排序 / 选择配置，非空时显示「照片顺序」面板。
  final PosterReorderSpec? reorder;
}

class _PosterSheet extends StatefulWidget {
  const _PosterSheet({
    required this.tokens,
    required this.title,
    required this.shareSubject,
    required this.shareText,
    required this.fileNamePrefix,
    this.extraAction,
    this.content,
    this.posterKey,
    this.stylePicker,
    this.plainContentKey,
  });

  final ThemeTokens tokens;
  final String title;

  /// 普通海报正文（[showPoster] 模式）；样式选择模式传 [stylePicker] 即可。
  final Widget? content;
  final GlobalKey? posterKey;
  final String shareSubject;
  final String shareText;
  final String fileNamePrefix;

  /// 可选：普通海报「严格卡片级」导出的捕获键。
  /// 当此键非空（且未启用样式选择）时，[widget.content] 会被紧包在一个
  /// [RepaintBoundary] 中，导出/分享改为捕获该边界（保持内容自身 3:4 等
  /// 固定尺寸、无外层容器背景填充）。缺省为 null 时行为与旧版完全一致。
  final GlobalKey? plainContentKey;

  /// 可选的扩展操作按钮，渲染在底部操作条第一位（保存/分享之前）。
  final Widget? extraAction;

  /// 样式选择配置，非空时启用样式切换条。
  final _StylePickerConfig? stylePicker;

  @override
  State<_PosterSheet> createState() => _PosterSheetState();
}

class _PosterSheetState extends State<_PosterSheet> {
  bool _exporting = false;
  bool _sharing = false;

  late final GlobalKey _posterKey;

  /// 样式选择模式：各页海报本体（设计尺寸 300~380 逻辑宽）的捕获键。
  ///
  /// 按页独立持有（而非单键）：PageView 翻页动画期间相邻两页同时挂在树上，
  /// 共用 GlobalKey 会触发 Duplicate GlobalKey 截断子树。key 挂在 FittedBox
  /// 内部海报 widget 上，boundary 尺寸恒为设计尺寸，与显示缩放无关。
  final Map<int, GlobalKey> _styleContentKeys = {};

  /// 普通海报（调用方未传 [_PosterSheet.plainContentKey]）的内容级捕获键。
  final GlobalKey _plainFallbackKey = GlobalKey();

  late String _selectedStyleId;

  /// 当前海报比例（比例胶囊可切换；精选集海报支持 3:4 / 1:1）。
  late PosterRatio _ratio;

  /// 当前海报数据（比例切换 / 照片排序后重建，预览实时更新）。
  late PosterStyleData _data;

  /// 已按序选中的照片（照片排序面板状态，仅本次 Sheet 有效）。
  late List<Object> _selected;

  /// 主效果卡片翻页控制器（左右滑动切换版式）。
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _posterKey = widget.posterKey ?? GlobalKey();
    final cfg = widget.stylePicker;
    _ratio = cfg?.ratio ?? PosterRatio.ratio34;
    final reorder = cfg?.reorder;
    _selected = List<Object>.of(reorder?.initialSelected ?? const []);
    _data = reorder != null
        ? reorder.buildData(_ratio, List<Object>.of(_selected))
        : (cfg?.data ?? _emptyPosterData());
    String selectedId = '';
    if (cfg != null) {
      selectedId = PosterStyleRegistry.defaultFor(cfg.kind, _ratio)?.id ?? '';
    }
    _selectedStyleId = selectedId;
    // showPoster 模式无样式选择（_styles 为空），创建兜底单页控制器。
    _pageController = PageController(
      initialPage: _styles.isEmpty
          ? 0
          : (_styles.indexWhere((s) => s.id == selectedId)).clamp(0, _styles.length - 1),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// 从底部缩略条选择样式：同步选中态并按需翻页到对应主卡片。
  void _onSelectStyle(String id) {
    final idx = _styles.indexWhere((s) => s.id == id);
    if (idx < 0) return;
    setState(() => _selectedStyleId = id);
    if (_pageController.hasClients && idx != _pageController.page?.round()) {
      _pageController.animateToPage(
        idx,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// 当前 kind + ratio 下的可选样式列表。
  List<PosterStyle> get _styles {
    final cfg = widget.stylePicker;
    if (cfg == null) return const [];
    return PosterStyleRegistry.stylesFor(cfg.kind, _ratio);
  }

  /// showPoster（无样式选择）模式下的兜底空数据，仅占位，不参与渲染。
  PosterStyleData _emptyPosterData() => PosterStyleData(
        ratio: _ratio,
        title: '',
        category: '',
        qrData: '',
        qrHint: '',
        qrSub: '',
        shareText: '',
        photoBuilder: (w, h) => SizedBox(width: w, height: h),
      );

  /// 切换比例档位：重建数据并按当前比例取默认样式。
  void _onSelectRatio(PosterRatio r) {
    if (r == _ratio) return;
    final cfg = widget.stylePicker;
    if (cfg == null) return;
    setState(() {
      _ratio = r;
      _rebuildData();
      _selectedStyleId = PosterStyleRegistry.defaultFor(cfg.kind, r)?.id ?? '';
    });
  }

  /// 依当前比例与选中照片重建海报数据（仅 reorder 模式生效）。
  void _rebuildData() {
    final cfg = widget.stylePicker;
    if (cfg?.reorder == null) return;
    _data = cfg!.reorder!.buildData(_ratio, List<Object>.of(_selected));
  }

  /// 可选候选照片（全部可选 - 已选）。元素以相同实例复用，靠 identity 判定。
  List<Object> get _reorderCandidates {
    final spec = widget.stylePicker?.reorder;
    if (spec == null) return const [];
    return spec.allItems.where((it) => !_selected.contains(it)).toList();
  }

  /// 把 [oldIndex] 处的照片移动到 [newIndex] 槽位（目标槽位语义，非插入点语义）。
  ///
  /// 注意：这里**不做** `newIndex > oldIndex` 时的 -1 补偿——那是
  /// ReorderableListView「先移除再插入」的回调约定；自绘拖拽直接给出
  /// 目标槽位下标，再补偿会差一位。
  void _onReorderPhoto(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    if (oldIndex < 0 || newIndex < 0) return;
    if (oldIndex >= _selected.length || newIndex >= _selected.length) return;
    setState(() {
      final it = _selected.removeAt(oldIndex);
      _selected.insert(newIndex, it);
      _rebuildData();
    });
  }

  void _onRemovePhoto(Object item) {
    setState(() {
      _selected.remove(item);
      _rebuildData();
    });
  }

  void _onAddPhoto(Object item) {
    final spec = widget.stylePicker?.reorder;
    if (spec == null || _selected.length >= spec.maxCount) return;
    setState(() {
      _selected.add(item);
      _rebuildData();
    });
  }

  /// 海报导出目标宽度（物理 px）。
  ///
  /// 按「目标宽度 / 画布逻辑宽」计算导出倍率，5 种比例海报统一以 ≥1080px
  /// 宽度出图（9:16 竖图 1080×1920），比固定 3x（9:16 仅 900 宽）更清晰。
  static const double kPosterExportWidth = 1080;

  /// 比例档位胶囊（非空时才渲染；精选集海报：3:4 / 1:1）。
  Widget _buildRatioPills(ThemeTokens t) {
    final opts = widget.stylePicker?.ratioOptions;
    if (opts == null || opts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          children: [
            for (final r in opts)
              _RatioPill(
                label: r == PosterRatio.square ? '1:1 方版' : '3:4 竖版',
                selected: r == _ratio,
                onTap: () => _onSelectRatio(r),
                seeds: t,
              ),
          ],
        ),
      ),
    );
  }

  Future<ui.Image?> _captureImage() async {
    // 一律「内容级」捕获：直接捕获海报本体（样式选择模式取设计尺寸的
    // 海报 widget；普通模式取 content 自身），而非外层预览容器。这样：
    // 1. FittedBox/预览区的显示缩放不影响导出分辨率；
    // 2. 导出图不含预览容器背景与边距。
    final GlobalKey? targetKey;
    if (widget.stylePicker != null) {
      // 当前选中样式对应页的 key（onPageChanged 已同步选中态）。
      final idx = _styles.indexWhere((s) => s.id == _selectedStyleId);
      targetKey = idx >= 0 ? _styleContentKeys[idx] : null;
    } else if (widget.plainContentKey != null) {
      targetKey = widget.plainContentKey;
    } else {
      targetKey = _plainFallbackKey;
    }
    if (targetKey == null) return null;
    final boundary = targetKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final size = boundary.size;
    if (size.isEmpty) return null;
    final pixelRatio = (kPosterExportWidth / size.width).clamp(2.0, 4.0);
    return boundary.toImage(pixelRatio: pixelRatio);
  }

  Future<List<int>?> _captureBytes() async {
    final image = await _captureImage();
    if (image == null) return null;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    return byteData.buffer.asUint8List().toList();
  }

  Future<File> _writeTempFile(List<int> bytes) async {
    final tempDir = await getSafeTemporaryDirectory();
    final fileName =
        '${widget.fileNamePrefix}_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  /// 导出海报到系统相册
  /// iOS/Android: SaverGallery.saveImage
  /// HarmonyOS: MethodChannel('lumira/photo_saver') saveToAlbum
  Future<void> _onExport() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final bytes = await _captureBytes();
      if (bytes == null) {
        _toast('海报生成失败');
        return;
      }
      final fileName =
          '${widget.fileNamePrefix}_${DateTime.now().millisecondsSinceEpoch}.png';
      try {
        // 尝试 saver_gallery（iOS/Android）
        // saver_gallery 3.0.6 实际 API：name + androidExistNotSave
        final result = await SaverGallery.saveImage(
          Uint8List.fromList(bytes),
          name: fileName,
          androidExistNotSave: false,
        );
        if (result.isSuccess) {
          _toast('已保存到相册');
        } else {
          _toast('保存失败：${result.errorMessage ?? "未知错误"}');
        }
      } on MissingPluginException {
        // HarmonyOS 降级：写入临时文件后调用原生通道
        final file = await _writeTempFile(bytes);
        const channel = MethodChannel('lumira/photo_saver');
        final result = await channel.invokeMethod('saveToAlbum', {
          'path': file.path,
        });
        final success = result != null && result['success'] == true;
        if (success) {
          _toast('已保存到相册');
        } else {
          _toast('保存失败：${result?['error'] ?? "未知错误"}');
        }
      }
    } catch (e) {
      _toast('导出失败：$e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// 分享海报到系统
  Future<void> _onShare() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final bytes = await _captureBytes();
      if (bytes == null) {
        _toast('海报生成失败');
        return;
      }
      final file = await _writeTempFile(bytes);
      await SafeShare.shareXFiles(
        [XFile(file.path)],
        subject: widget.shareSubject,
        text: widget.shareText,
      );
    } catch (e) {
      _toast('分享失败：$e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _toast(String msg) {
    LumiraToast.show(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final screenHeight = MediaQuery.of(context).size.height;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.70),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题行：标题 + 副文案 + 关闭
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      if (widget.stylePicker != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.stylePicker!.reorder != null
                              ? '长按拖动照片可调整顺序 · 预览后导出或分享'
                              : '切换版式，预览后导出或分享 · 左右滑动卡片切换',
                          style: TextStyle(
                            fontSize: 11,
                            color: t.textTertiary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // 圆形关闭按钮，扩大点击热区
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: t.surfaceAlt,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded, size: 18, color: t.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          // 主效果卡片：整页满视图展示当前版式，可左右滑动切换。
          // 导出捕获走内容级键（_styleContentKeys / plainContentKey /
          // _plainFallbackKey，见 _captureImage），此处 _posterKey 仅作预览
          // 容器边界，不参与导出。
          Expanded(
            child: Container(
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: t.surfaceAlt,
                borderRadius: BorderRadius.circular(18),
              ),
              child: RepaintBoundary(
                key: _posterKey,
                child: PageView.builder(
                  controller: _pageController,
                  // 样式选择模式打开翻页；普通海报（无样式）禁用滑动仅单页。
                  physics: widget.stylePicker == null
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  onPageChanged: (i) {
                    if (widget.stylePicker != null && i >= 0 && i < _styles.length) {
                      if (_styles[i].id != _selectedStyleId) {
                        setState(() => _selectedStyleId = _styles[i].id);
                      }
                    }
                  },
                  itemCount: _styles.isEmpty ? 1 : _styles.length,
                  itemBuilder: (ctx, i) {
                    final style = _styles.isEmpty ? null : _styles[i];
                    // 普通海报（无样式）：按预览区宽度渲染调用方 content 并允许纵向滚动，
                    // 保持旧版「有界宽度 + 可滚动」语义（部分 content 用 width: Infinity）。
                    // content 始终包一层内容级 RepaintBoundary 供导出捕获。
                    // 样式选择模式：用 FittedBox 适配 5 种设计画布，每页海报本体挂
                    // 独立捕获键，显示层缩放不影响导出清晰度。
                    return RepaintBoundary(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: style == null
                              ? SingleChildScrollView(
                                  child: RepaintBoundary(
                                    key: widget.plainContentKey ??
                                        _plainFallbackKey,
                                    child: widget.content ??
                                        const SizedBox.shrink(),
                                  ),
                                )
                              : FittedBox(
                                  fit: BoxFit.contain,
                                  child: UnconstrainedBox(
                                    child: RepaintBoundary(
                                      key: _styleContentKeys.putIfAbsent(
                                          i, () => GlobalKey()),
                                      child: style
                                          .builder(_data),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          // 比例档位胶囊（精选集海报：3:4 / 1:1）
          _buildRatioPills(t),
          // 样式切换条（操作按钮与效果卡片之间，视觉重心仍在主效果卡片）
          if (widget.stylePicker != null && _styles.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 2),
              child: PosterStylePicker(
                styles: _styles,
                data: _data,
                selectedId: _selectedStyleId,
                onSelect: _onSelectStyle,
              ),
            ),
          // 照片顺序编辑面板（精选集海报拖拽排序 / 选照片）
          if (widget.stylePicker?.reorder != null && _selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _PosterReorderPanel(
                tokens: t,
                selected: _selected,
                candidates: _reorderCandidates,
                maxCount: widget.stylePicker!.reorder!.maxCount,
                itemThumb: widget.stylePicker!.reorder!.itemThumb,
                onReorder: _onReorderPhoto,
                onRemove: _onRemovePhoto,
                onAdd: _onAddPhoto,
              ),
            ),

          // 底部操作条：两个主操作（保存到相册 / 分享），简洁不冗余
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Row(
              children: [
                if (widget.extraAction != null) ...[
                  Expanded(child: widget.extraAction!),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: _PosterAction(
                    tokens: t,
                    icon: _exporting ? null : Icons.save_alt_outlined,
                    label: _exporting ? '导出中...' : '保存到相册',
                    color: t.brandSubtle,
                    textColor: t.brandText,
                    loading: _exporting,
                    onTap: _exporting ? null : _onExport,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PosterAction(
                    tokens: t,
                    icon: _sharing ? null : Icons.ios_share_outlined,
                    label: _sharing ? '分享中...' : '分享海报',
                    color: t.brand,
                    textColor: Colors.white,
                    elevated: true,
                    loading: _sharing,
                    onTap: _sharing ? null : _onShare,
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

/// 底部操作按钮：紧凑横排（图标 + 文案），弱化高度、强化可读。
class _PosterAction extends StatelessWidget {
  const _PosterAction({
    required this.tokens,
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    this.elevated = false,
    this.loading = false,
    this.onTap,
  });

  final ThemeTokens tokens;
  final IconData? icon;
  final String label;
  final Color color;
  final Color textColor;

  /// 主按钮：叠加品牌色投影突出主操作。
  final bool elevated;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: elevated
              ? [
                  BoxShadow(
                    color: tokens.brand.withOpacity(.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              LumiraProgress.circular(strokeWidth: 2, size: 16)
            else if (icon != null) ...[
              Icon(icon, size: 16, color: textColor),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单个比例档位胶囊（当前态金描边高亮）。
class _RatioPill extends StatelessWidget {
  const _RatioPill({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.seeds,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ThemeTokens seeds;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? seeds.brandSubtle : seeds.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? seeds.brand : seeds.divider,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? seeds.brandText : seeds.textTertiary,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

/// 照片顺序编辑面板：已按序选中横排（长按拖拽调整、点 × 移除）+ 可选候选追加。
///
/// 拖拽排序为**自绘实现**（LongPressDraggable + DragTarget），不使用
/// 「ReorderableListView 外套 RotatedBox」的横排技巧：Flutter 3.7 的
/// ReorderableListView 用手指的 Y 坐标判定插入位置（`_dragUpdateItems` 取的是
/// `dragPosition.dy`，`scrollDirection` 恒为 vertical），横排后所有 item 的全局
/// Y 区间完全重合，拖到哪儿都算同一个槽位，`onReorder` 根本不会被调用。
/// 这里改为按 X 坐标计算目标槽位（内容坐标 = 视口 x + 横向滚动量），
/// 拖动过程中实时让位，松手即生效。
class _PosterReorderPanel extends StatefulWidget {
  const _PosterReorderPanel({
    required this.tokens,
    required this.selected,
    required this.candidates,
    required this.maxCount,
    required this.itemThumb,
    required this.onReorder,
    required this.onRemove,
    required this.onAdd,
  });

  final ThemeTokens tokens;
  final List<Object> selected;
  final List<Object> candidates;
  final int maxCount;
  final Widget Function(Object item, double size) itemThumb;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(Object item) onRemove;
  final void Function(Object item) onAdd;

  @override
  State<_PosterReorderPanel> createState() => _PosterReorderPanelState();
}

class _PosterReorderPanelState extends State<_PosterReorderPanel> {
  static const double _thumb = 54;
  static const double _gap = 6;
  /// 单个缩略图在横排中占据的步距（含右侧间距）。
  static const double _stride = _thumb + _gap;

  /// 长按触发拖拽的时长（与系统长按一致）。
  static const Duration _dragDelay = Duration(milliseconds: 500);

  final ScrollController _scrollCtl = ScrollController();
  Timer? _autoScrollTimer;

  /// 当前被拖项在 [widget.selected] 中的下标；实时让位后同步更新。
  int? _dragIndex;
  /// 是否处于拖拽中：拖拽期间禁用横排自身的滚动，避免与拖拽抢横向手势。
  bool _dragging = false;
  /// 指针在横排视口内的 x 坐标（滚动后重算落点用，< 0 表示未知）。
  double _pointerViewDx = -1;
  /// 指针的**屏幕** x 坐标（贴边自动滚动用，不依赖是否落在横排条内）。
  double _pointerGlobalDx = -1;
  /// 横排内容层的 RenderBox（把 DragTarget 回调里的全局坐标换算成内容坐标）。
  ///
  /// 注意：Flutter 3.7 的 [DragTargetDetails.offset] 是 **globalPosition**
  /// （源码注释 "The global position when the specific pointer event occurred"），
  /// 不是 DragTarget 的局部坐标。横排滚动后必须减去内容层的全局左边缘，
  /// 否则落点会按"未滚动"的坐标算，拖到最后一位实际只落到中间某个位置。
  RenderBox? _contentBox;
  /// 横排视口宽度（LayoutBuilder 取得）。
  double _viewWidth = 0;
  /// 屏幕宽度（贴边判定用）。
  double _screenWidth = 0;

  @override
  void dispose() {
    _stopAutoScroll();
    _scrollCtl.dispose();
    super.dispose();
  }

  void _startDrag(int index) {
    _dragIndex = index;
    // 长按成立、照片被"拎起"时给一次明确的震动反馈。
    HapticFeedback.mediumImpact();
    setState(() => _dragging = true);
    _stopAutoScroll();
    _autoScrollTimer =
        Timer.periodic(const Duration(milliseconds: 16), (_) => _tickAutoScroll());
  }

  void _endDrag() {
    _stopAutoScroll();
    _dragIndex = null;
    _pointerViewDx = -1;
    _pointerGlobalDx = -1;
    if (mounted) setState(() => _dragging = false);
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  /// 拖到屏幕左右边缘时自动横向滚动，便于把照片送到屏幕外的槽位。
  ///
  /// 判定用**屏幕坐标**而非横排条内的相对坐标：手指拖到条外（上方预览区、
  /// 屏幕最左/最右）时只要还没松手，滚动依然继续，不会中途停住。
  /// 越贴边滚得越快（3～20dp / 帧）。
  void _tickAutoScroll() {
    if (!_scrollCtl.hasClients || _pointerGlobalDx < 0) return;
    final double width = _screenWidth > 0 ? _screenWidth : _viewWidth;
    if (width <= 0) return;
    const double edge = 56;
    double delta;
    if (_pointerGlobalDx < edge) {
      delta = -((edge - _pointerGlobalDx) / 4).clamp(3.0, 20.0);
    } else if (_pointerGlobalDx > width - edge) {
      delta = ((_pointerGlobalDx - (width - edge)) / 4).clamp(3.0, 20.0);
    } else {
      return;
    }
    final double min = _scrollCtl.position.minScrollExtent;
    final double max = _scrollCtl.position.maxScrollExtent;
    final double cur = _scrollCtl.offset;
    final double target = (cur + delta).clamp(min, max).toDouble();
    // 已到尽头（或内容本就放得下）时不再跳，避免无谓重建。
    if (target == cur) return;
    _scrollCtl.jumpTo(target);
    // 内容滚过去后，指针下方的槽位也变了，按新的内容坐标重算落点。
    if (_pointerViewDx >= 0) _applyTarget(_pointerViewDx + target);
  }

  /// 拖拽中的位移：刷新指针的屏幕坐标（供贴边滚动判断）。
  void _onDragUpdate(DragUpdateDetails details) {
    _pointerGlobalDx = details.globalPosition.dx;
  }

  void _onDragMove(DragTargetDetails<int> details) {
    // details.offset 是全局坐标，先换算成横排内容坐标。
    final RenderBox? box = _contentBox;
    if (box == null || !box.attached) return;
    final double contentDx = details.offset.dx - box.localToGlobal(Offset.zero).dx;
    final double scroll = _scrollCtl.hasClients ? _scrollCtl.offset : 0.0;
    // 视口坐标（滚动后重算落点用）；指针全局坐标顺手同步，贴边滚动更跟手。
    _pointerViewDx = contentDx - scroll;
    _pointerGlobalDx = details.offset.dx;
    _applyTarget(contentDx);
  }

  /// 按内容坐标 x 算出目标槽位并实时让位（让位后被拖项就位于 [to]）。
  void _applyTarget(double contentDx) {
    final int? from = _dragIndex;
    final int len = widget.selected.length;
    if (from == null || len < 2) return;
    final int to = (contentDx / _stride).floor().clamp(0, len - 1).toInt();
    if (to == from) return;
    widget.onReorder(from, to);
    _dragIndex = to;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    _screenWidth = MediaQuery.of(context).size.width;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.drag_indicator_rounded, size: 15, color: t.textTertiary),
              const SizedBox(width: 4),
              Text(
                '照片顺序',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: t.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '已选 ${widget.selected.length}/${widget.maxCount}',
                style: TextStyle(fontSize: 10, color: t.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 已按序选中：单行横排，长按拖拽排序。
          //
          // 横排超出屏宽时需要滚动，而滚动手势会与拖拽抢横向位移：
          // 拖拽期间（_dragging）把 physics 换成 NeverScrollable，横向手势
          // 就全归拖拽，配合贴边自动滚动可以够到屏幕外的槽位；不拖拽时
          // 仍可正常左右滑动查看。
          SizedBox(
            height: _thumb + 6,
            child: LayoutBuilder(
              builder: (context, constraints) {
                _viewWidth = constraints.maxWidth;
                return SingleChildScrollView(
                  controller: _scrollCtl,
                  scrollDirection: Axis.horizontal,
                  physics: _dragging
                      ? const NeverScrollableScrollPhysics()
                      : const ClampingScrollPhysics(),
                  child: DragTarget<int>(
                    onMove: _onDragMove,
                    onLeave: (_) {
                      _pointerViewDx = -1;
                    },
                    builder: (context, _, __) {
                      // 缓存内容层 RenderBox：DragTarget 回调给的是全局坐标，
                      // 需要它换算成内容坐标（见 _onDragMove）。
                      final Object? ro = context.findRenderObject();
                      if (ro is RenderBox) _contentBox = ro;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < widget.selected.length; i++) ...[
                            if (i > 0) const SizedBox(width: _gap),
                            _orderedTile(widget.selected[i], i),
                          ],
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
          // 可选候选：追加
          if (widget.candidates.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '从全部中选择',
              style: TextStyle(fontSize: 10, color: t.textTertiary),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: _thumb + 6,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.candidates.length,
                separatorBuilder: (_, __) => const SizedBox(width: _gap),
                itemBuilder: (context, index) {
                  final item = widget.candidates[index];
                  final full = widget.selected.length >= widget.maxCount;
                  return GestureDetector(
                    onTap: full ? null : () => widget.onAdd(item),
                    behavior: HitTestBehavior.opaque,
                    child: Opacity(
                      opacity: full ? .45 : 1,
                      child: Container(
                        width: _thumb,
                        height: _thumb,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: t.divider, width: 1),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            widget.itemThumb(item, _thumb),
                            Center(
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(.45),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.add_rounded, size: 15, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _orderedTile(Object item, int index) {
    // 只剩一张时无需排序，也不显示删除按钮
    final bool draggable = widget.selected.length > 1;
    final Widget tile = _tileBody(item, showRemove: draggable);
    if (!draggable) return tile;
    return LongPressDraggable<int>(
      key: ValueKey<Object>(item),
      data: index,
      delay: _dragDelay,
      // 关掉内置的 selectionClick，改在 onDragStarted 里给一次更明确的
      // mediumImpact（内置那下太轻，长按拎起照片时几乎感觉不到）。
      hapticFeedbackOnStart: false,
      feedback: Material(
        color: Colors.transparent,
        elevation: 4,
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: _thumb,
          height: _thumb,
          child: _tileBody(item, showRemove: false),
        ),
      ),
      childWhenDragging: Opacity(opacity: .3, child: tile),
      onDragStarted: () => _startDrag(index),
      onDragUpdate: _onDragUpdate,
      onDragEnd: (_) => _endDrag(),
      child: tile,
    );
  }

  /// 单张缩略图（间距由外层 Wrap 的 spacing / runSpacing 提供，这里不带 margin）。
  Widget _tileBody(Object item, {required bool showRemove}) {
    final t = widget.tokens;
    return Container(
      width: _thumb,
      height: _thumb,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: t.divider, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.itemThumb(item, _thumb),
          if (showRemove)
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: () => widget.onRemove(item),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, size: 11, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
