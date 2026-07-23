import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/theme_tokens.dart';
import '../data/profile_mock_data.dart';

/// 碎片海报生成器
///
/// 将碎片收集详情渲染为海报并分享。
/// 使用 RepaintBoundary + toImage 捕获组件为图片，保存临时文件后调用系统分享。
class FragmentPosterGenerator {
  FragmentPosterGenerator._();

  /// 弹出海报预览底部弹层
  static Future<void> showPoster(
    BuildContext context, {
    required ThemeTokens tokens,
    required FragmentItem fragment,
    required GlobalKey posterKey,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PosterSheet(
        tokens: tokens,
        fragment: fragment,
        posterKey: posterKey,
      ),
    );
  }
}

class _PosterSheet extends StatefulWidget {
  const _PosterSheet({
    required this.tokens,
    required this.fragment,
    required this.posterKey,
  });

  final ThemeTokens tokens;
  final FragmentItem fragment;
  final GlobalKey posterKey;

  @override
  State<_PosterSheet> createState() => _PosterSheetState();
}

class _PosterSheetState extends State<_PosterSheet> {
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = widget.posterKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        _toast('海报生成失败');
        return;
      }
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        _toast('海报生成失败');
        return;
      }
      final bytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final safeName = widget.fragment.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File('${tempDir.path}/lumira_fragment_$safeName.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '如画 · 碎片收集：${widget.fragment.name}',
        text: '我在如画收集了「${widget.fragment.name}」碎片 ${widget.fragment.current}/${widget.fragment.max}，快来一起收集吧！',
      );
    } catch (e) {
      _toast('分享失败：$e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final fragment = widget.fragment;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      decoration: BoxDecoration(
        color: t.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部拖把
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: t.surfaceAlt,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 标题行
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  '海报预览',
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: RepaintBoundary(
                key: widget.posterKey,
                child: _PosterContent(tokens: t, fragment: fragment),
              ),
            ),
          ),
          // 底部操作
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sharing ? null : _share,
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.brand,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _sharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.ios_share_outlined, size: 18),
                label: Text(_sharing ? '生成中...' : '分享海报'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 海报内容（会被捕获为图片）
class _PosterContent extends StatelessWidget {
  const _PosterContent({required this.tokens, required this.fragment});
  final ThemeTokens tokens;
  final FragmentItem fragment;

  @override
  Widget build(BuildContext context) {
    final done = fragment.current >= fragment.max;
    final percent = fragment.percent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tokens.brandSubtle,
            tokens.canvas,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部品牌
          Row(
            children: [
              Icon(Icons.camera_alt_outlined, size: 18, color: tokens.brand),
              const SizedBox(width: 6),
              Text(
                'LUMIRA · 如画',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: tokens.brand,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 碎片图标 + 名称
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [tokens.brand, tokens.brandDeep],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(fragment.icon, size: 28, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '碎片收集',
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textTertiary,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fragment.name,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Noto Serif SC',
                        color: tokens.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              // 进度环
              SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: percent / 100.0,
                      strokeWidth: 4,
                      backgroundColor: tokens.brandSubtle,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(tokens.brand),
                    ),
                    Text(
                      '$percent%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 图片九宫格
          if (fragment.photoUrls.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _PhotoGrid(
                tokens: tokens,
                urls: fragment.photoUrls,
              ),
            ),
          const SizedBox(height: 20),
          // 进度文字
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: done
                  ? tokens.successSubtle
                  : tokens.brand.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  done ? Icons.check_circle : Icons.local_fire_department_outlined,
                  size: 16,
                  color: done ? tokens.success : tokens.brand,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    done
                        ? '已集齐 ${fragment.max} 枚「${fragment.name}」碎片！'
                        : '已收集 ${fragment.current}/${fragment.max}，再收集 ${fragment.max - fragment.current} 枚即可集齐',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: done ? tokens.success : tokens.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 底部水印
          Align(
            alignment: Alignment.center,
            child: Text(
              '如画 LUMIRA · 记录每一帧光影',
              style: TextStyle(
                fontSize: 10,
                color: tokens.textTertiary,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 图片九宫格（自适应 2-9 张）
class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.tokens, required this.urls});
  final ThemeTokens tokens;
  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final count = urls.length;
    int crossCount;
    if (count <= 1) {
      crossCount = 1;
    } else if (count <= 4) {
      crossCount = 2;
    } else {
      crossCount = 3;
    }

    final rows = (count / crossCount).ceil();
    final cellHeight = crossCount == 1 ? 200.0 : 110.0;

    return Column(
      children: [
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < crossCount; c++)
                Expanded(
                  child: (r * crossCount + c) < count
                      ? Container(
                          height: cellHeight,
                          margin: EdgeInsets.only(
                            right: c < crossCount - 1 ? 3 : 0,
                            bottom: r < rows - 1 ? 3 : 0,
                          ),
                          child: Image.network(
                            urls[r * crossCount + c],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: tokens.brandSubtle,
                              child: Icon(Icons.image_outlined,
                                  size: 24, color: tokens.brand),
                            ),
                          ),
                        )
                      : SizedBox(height: cellHeight),
                ),
            ],
          ),
      ],
    );
  }
}
