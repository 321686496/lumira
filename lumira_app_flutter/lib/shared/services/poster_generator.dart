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
      ),
    );
  }
}

class _PosterSheet extends StatefulWidget {
  const _PosterSheet({
    required this.tokens,
    required this.title,
    required this.content,
    required this.posterKey,
    required this.shareSubject,
    required this.shareText,
    required this.fileNamePrefix,
  });

  final ThemeTokens tokens;
  final String title;
  final Widget content;
  final GlobalKey posterKey;
  final String shareSubject;
  final String shareText;
  final String fileNamePrefix;

  @override
  State<_PosterSheet> createState() => _PosterSheetState();
}

class _PosterSheetState extends State<_PosterSheet> {
  bool _exporting = false;
  bool _sharing = false;

  Future<ui.Image?> _captureImage() async {
    final boundary = widget.posterKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    return boundary.toImage(pixelRatio: 2.0);
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
      constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题行
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Icon(Icons.close, size: 20, color: t.textTertiary),
                ),
              ],
            ),
          ),
          // 海报内容
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: RepaintBoundary(
                key: widget.posterKey,
                child: widget.content,
              ),
            ),
          ),
          // 底部三按钮
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            child: Row(
              children: [
                Expanded(
                  child: _PosterButton(
                    tokens: t,
                    icon: Icons.visibility_outlined,
                    label: '生成海报',
                    color: t.surfaceAlt,
                    textColor: t.textPrimary,
                    onTap: () => _toast('海报已生成'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PosterButton(
                    tokens: t,
                    icon: _exporting
                        ? null
                        : Icons.save_alt_outlined,
                    label: _exporting ? '导出中...' : '导出海报',
                    color: t.brandSubtle,
                    textColor: t.brandText,
                    loading: _exporting,
                    onTap: _exporting ? null : _onExport,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PosterButton(
                    tokens: t,
                    icon: _sharing ? null : Icons.ios_share_outlined,
                    label: _sharing ? '分享中...' : '分享海报',
                    color: t.brand,
                    textColor: Colors.white,
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

class _PosterButton extends StatelessWidget {
  const _PosterButton({
    required this.tokens,
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    this.loading = false,
    this.onTap,
  });

  final ThemeTokens tokens;
  final IconData? icon;
  final String label;
  final Color color;
  final Color textColor;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              LumiraProgress.circular(strokeWidth: 2, size: 18)
            else if (icon != null)
              Icon(icon, size: 18, color: textColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
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
