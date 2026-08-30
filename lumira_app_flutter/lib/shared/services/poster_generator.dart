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
        stylePicker: _StylePickerConfig(kind: kind, ratio: ratio, data: data),
      ),
    );
  }
}

/// 样式选择配置（传此配置时 Sheet 启用样式切换条并持选中态）。
class _StylePickerConfig {
  const _StylePickerConfig({
    required this.kind,
    required this.ratio,
    required this.data,
  });

  final PosterKind kind;
  final PosterRatio ratio;
  final PosterStyleData data;
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
  });

  final ThemeTokens tokens;
  final String title;

  /// 普通海报正文（[showPoster] 模式）；样式选择模式传 [stylePicker] 即可。
  final Widget? content;
  final GlobalKey? posterKey;
  final String shareSubject;
  final String shareText;
  final String fileNamePrefix;

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
  late String _selectedStyleId;

  /// 主效果卡片翻页控制器（左右滑动切换版式）。
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _posterKey = widget.posterKey ?? GlobalKey();
    final cfg = widget.stylePicker;
    String selectedId = '';
    if (cfg != null) {
      selectedId =
          PosterStyleRegistry.defaultFor(cfg.kind, cfg.ratio)?.id ?? '';
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
    return PosterStyleRegistry.stylesFor(cfg.kind, cfg.ratio);
  }

  /// 海报导出目标宽度（物理 px）。
  ///
  /// 按「目标宽度 / 画布逻辑宽」计算导出倍率，5 种比例海报统一以 ≥1080px
  /// 宽度出图（9:16 竖图 1080×1920），比固定 3x（9:16 仅 900 宽）更清晰。
  static const double kPosterExportWidth = 1080;

  Future<ui.Image?> _captureImage() async {
    final boundary = _posterKey.currentContext?.findRenderObject()
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
                          '切换版式，预览后导出或分享 · 左右滑动卡片切换',
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
          // RepaintBoundary 捕获的是海报设计尺寸（300~380 逻辑宽），
          // PageView/FittedBox 的缩放只作用于显示层，不影响导出清晰度。
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
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: style == null
                              ? (widget.content ?? const SizedBox.shrink())
                              : style.builder(widget.stylePicker!.data),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          // 底部操作条：两个主操作（保存到相册 / 分享），简洁不冗余
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 4),
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
          // 样式切换条（下移到底部，尺寸收紧，视觉重心留给上方主卡片）
          if (widget.stylePicker != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: PosterStylePicker(
                styles: _styles,
                data: widget.stylePicker!.data,
                selectedId: _selectedStyleId,
                onSelect: _onSelectStyle,
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
