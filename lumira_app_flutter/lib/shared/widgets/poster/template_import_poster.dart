import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:qr_flutter/qr_flutter.dart';

/// 自定义模板「扫码导入」分享海报（V3 · 画幅自适应排版）。
///
/// 海报画布固定竖版 [kImportPosterWidth]×[kImportPosterHeight]，
/// 封面图按原生宽高比决定整套排版构图（5 种比例 = 5 种完全不同布局）：
/// - 9:16 → 左图满高 + 右列竖文
/// - 3:4  → 上居中图 + 下居中文
/// - 1:1  → 左方图 + 右栏文
/// - 4:3  → 文在上 + 图在下
/// - 16:9 → 电影通栏 + 标题压图
///
/// 这是固定品牌海报（暖白纸感 + 金色细线 + 衬线大标题），颜色为品牌固定色，
/// 不随 App UI 风格 / 主题变化——属于品牌海报制品，而非应用皮肤。
const double kImportPosterWidth = 340;
const double kImportPosterHeight = 566;

/// 海报封面数据（解码字节或网络 URL + 原生宽高比）。
class ImportPosterCover {
  const ImportPosterCover({
    this.bytes,
    this.networkUrl,
    required this.aspectRatio,
  });

  final Uint8List? bytes;
  final String? networkUrl;

  /// 宽 / 高（>1 为横幅，<1 为竖幅）。
  final double aspectRatio;
}

/// 从 `.pptpl` payload 解析封面数据（字节 / 网络 URL + 原生宽高比）。
///
/// 优先 `meta.coverData`（base64 data URL），其次 `meta.cover` 的 `data:` /
/// `assets/` / `http(s)`。解析不到宽高比时回退默认 3:4（0.75）。
Future<ImportPosterCover?> resolveImportPosterCover(
  Map<String, dynamic> payload,
) async {
  final meta = payload['meta'];
  if (meta is! Map<String, dynamic>) return null;
  final coverData = (meta['coverData'] as String?)?.trim() ?? '';
  var cover = (meta['cover'] as String?)?.trim() ?? '';

  var data = coverData;
  if (data.isEmpty && cover.startsWith('data:')) data = cover;

  if (data.isNotEmpty) {
    try {
      final b64 =
          data.contains(',') ? data.substring(data.indexOf(',') + 1) : data;
      final bytes = base64Decode(b64);
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        return ImportPosterCover(
          bytes: bytes,
          aspectRatio: decoded.width / decoded.height,
        );
      }
      return ImportPosterCover(bytes: bytes, aspectRatio: 0.75);
    } catch (_) {}
  }

  if (cover.startsWith('http://') || cover.startsWith('https://')) {
    return ImportPosterCover(networkUrl: cover, aspectRatio: 4 / 3);
  }

  if (cover.startsWith('assets/')) {
    try {
      final bd = await rootBundle.load(cover);
      final bytes = bd.buffer.asUint8List();
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        return ImportPosterCover(
          bytes: bytes,
          aspectRatio: decoded.width / decoded.height,
        );
      }
    } catch (_) {}
  }

  return null;
}

/// 按宽高比选择海报排版。
enum ImportPosterLayout { tall, portrait, square, landscape, wide }

ImportPosterLayout importPosterLayoutForRatio(double ratio) {
  if (ratio <= 0.66) return ImportPosterLayout.tall; // 9:16
  if (ratio < 0.85) return ImportPosterLayout.portrait; // 3:4
  if (ratio < 1.15) return ImportPosterLayout.square; // 1:1
  if (ratio < 1.70) return ImportPosterLayout.landscape; // 4:3
  return ImportPosterLayout.wide; // 16:9
}

/// 品牌固定色（暖白纸感 + 金色）。
const _paper = Color(0xFFFDFBF7);
const _ink = Color(0xFF1A1A1A);
const _gold = Color(0xFFC9A96E);
const _goldDeep = Color(0xFFB08D4F);
const _text2 = Color(0xFF6B645C);
const _text3 = Color(0xFF979080);
const _line = Color(0x61C9A96E); // rgba(201,169,110,.38)

/// 衬线字体族回退链（不捆绑字体，尽量用系统衬线）。
const List<String> _serifFallback = [
  'Songti SC',
  'Noto Serif SC',
  'STSong',
  'Georgia',
];

TextStyle _titleStyle({
  double size = 32,
  Color color = _ink,
  double ls = 4,
}) {
  return TextStyle(
    fontFamily: 'serif',
    fontFamilyFallback: _serifFallback,
    fontSize: size,
    fontWeight: FontWeight.w700,
    color: color,
    letterSpacing: ls,
    height: 1.2,
  );
}

TextStyle _labelStyle({
  double size = 8,
  Color color = _text3,
  double ls = 2,
  FontWeight weight = FontWeight.normal,
}) {
  return TextStyle(
    fontSize: size,
    color: color,
    letterSpacing: ls,
    fontWeight: weight,
    height: 1.6,
  );
}

/// 海报主组件。
class TemplateImportPoster extends StatelessWidget {
  const TemplateImportPoster({
    super.key,
    required this.cover,
    required this.templateName,
    required this.category,
    required this.qrData,
    this.expiryText,
  });

  final ImportPosterCover? cover;
  final String templateName;
  final String category;
  final String qrData;
  final String? expiryText;

  String get _serial => '№ ${(templateName.hashCode.abs() % 900 + 100)}';

  @override
  Widget build(BuildContext context) {
    final data = _PosterData(
      cover: cover,
      name: templateName.trim().isEmpty ? '未命名模板' : templateName.trim(),
      category: category,
      qrData: qrData,
      expiryText: expiryText,
      serial: _serial,
    );

    final layout =
        importPosterLayoutForRatio(cover?.aspectRatio ?? 0.75);

    late final Widget body;
    switch (layout) {
      case ImportPosterLayout.tall:
        body = _TallLayout(data: data);
        break;
      case ImportPosterLayout.portrait:
        body = _PortraitLayout(data: data);
        break;
      case ImportPosterLayout.square:
        body = _SquareLayout(data: data);
        break;
      case ImportPosterLayout.landscape:
        body = _LandscapeLayout(data: data);
        break;
      case ImportPosterLayout.wide:
        body = _WideLayout(data: data);
        break;
    }

    return Container(
      width: kImportPosterWidth,
      height: kImportPosterHeight,
      decoration: const BoxDecoration(
        color: _paper,
        // 柔和暖棕投影 + 内侧白色发丝线（对应 CSS `0 30px 70px -30px … , inset 0 0 0 1px #fff`）
        boxShadow: [
          BoxShadow(
            color: Color(0x80563826),
            blurRadius: 70,
            offset: Offset(0, 30),
            spreadRadius: -30,
          ),
          BoxShadow(
            color: Color(0x66FFFFFF),
            blurRadius: 0,
            offset: Offset(0, 0),
            spreadRadius: -1,
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: body,
    );
  }
}

/// 五套排版共用的数据。
class _PosterData {
  const _PosterData({
    required this.cover,
    required this.name,
    required this.category,
    required this.qrData,
    required this.expiryText,
    required this.serial,
  });

  final ImportPosterCover? cover;
  final String name;
  final String category;
  final String qrData;
  final String? expiryText;
  final String serial;
}

/// 品牌 wordmark（画布上金色 / 压图上白色）。
class _Wordmark extends StatelessWidget {
  const _Wordmark({this.onImage = false});

  final bool onImage;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'LUMIRA',
          style: TextStyle(
            fontFamily: 'serif',
            fontFamilyFallback: _serifFallback,
            fontSize: 9,
            letterSpacing: 3,
            fontWeight: FontWeight.w700,
            color: onImage ? Colors.white : _goldDeep,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '· 如画',
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 2,
            color: onImage ? Colors.white70 : _text3,
          ),
        ),
      ],
    );
  }
}

/// 右上角编号。
class _Serial extends StatelessWidget {
  const _Serial(this.text, {this.onImage = false});

  final String text;
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'serif',
        fontFamilyFallback: _serifFallback,
        fontSize: 9,
        letterSpacing: 1,
        color: onImage ? Colors.white60 : _text3,
      ),
    );
  }
}

/// kicker：两侧发丝线 + 金色小字。
class _Kicker extends StatelessWidget {
  const _Kicker();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 1, color: _line),
        const SizedBox(width: 8),
        Text(
          '模板分享',
          style: _labelStyle(size: 9, color: _goldDeep, ls: 3, weight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        Container(width: 14, height: 1, color: _line),
      ],
    );
  }
}

/// 分类 + 「摄影模板」（金色间隔点）。
class _Category extends StatelessWidget {
  const _Category(this.category);

  final String category;

  @override
  Widget build(BuildContext context) {
    final cat = category.trim().isEmpty ? '摄影模板' : category.trim();
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: cat,
            style: _labelStyle(size: 9, color: _text2, ls: 3),
          ),
          const TextSpan(
            text: ' · ',
            style: TextStyle(fontSize: 9, color: _goldDeep),
          ),
          TextSpan(
            text: '摄影模板',
            style: _labelStyle(size: 9, color: _text2, ls: 3),
          ),
        ],
      ),
    );
  }
}

/// 大号衬线标题（过长自动缩小 / 省略）。
class _Title extends StatelessWidget {
  const _Title(this.text, {this.size = 32, this.ls = 4, this.maxLines = 1});

  final String text;
  final double size;
  final double ls;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: _titleStyle(size: size, ls: ls),
      ),
    );
  }
}

/// 二维码块（白底 + 金色细边 + 柔和投影）。
class _QrBox extends StatelessWidget {
  const _QrBox({required this.size, required this.data});

  final double size;
  final String data;

  @override
  Widget build(BuildContext context) {
    final pad = size * 0.09;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line, width: 1),
        boxShadow: const [
          BoxShadow(color: Color(0x33564C3B), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      child: QrImageView(
        data: data,
        backgroundColor: Colors.white,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: _ink,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: _ink,
        ),
      ),
    );
  }
}

/// 封面相框：图片 + 细金描边 + 内侧白色发丝线。
class _PhotoFrame extends StatelessWidget {
  const _PhotoFrame(this.cover);

  final ImportPosterCover? cover;

  @override
  Widget build(BuildContext context) {
    final c = cover;
    Widget photo;
    if (c == null) {
      photo = Container(
        color: const Color(0xFFEFEAE0),
        child: const Center(
          child: Icon(Icons.photo_outlined, size: 36, color: _goldDeep),
        ),
      );
    } else if (c.bytes != null) {
      photo = Image.memory(
        c.bytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _photoPlaceholder(),
      );
    } else {
      photo = Image.network(
        c.networkUrl ?? '',
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _photoPlaceholder(),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _gold.withOpacity(0.4), width: 1),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: photo),
          Positioned(
            left: 6,
            top: 6,
            right: 6,
            bottom: 6,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withOpacity(0.55), width: 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      color: const Color(0xFFEFEAE0),
      child: const Center(
        child: Icon(Icons.broken_image_outlined, size: 32, color: _text3),
      ),
    );
  }
}

/// 构图 1 · 9:16 左图满高 + 右列竖文。
class _TallLayout extends StatelessWidget {
  const _TallLayout({required this.data});

  final _PosterData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Stack(
      children: [
        const Positioned(top: 16, left: 22, child: _Wordmark()),
        Positioned(top: 18, right: 22, child: _Serial(d.serial)),
        Positioned(
          left: 24,
          top: 78,
          width: 196,
          height: 348,
          child: _PhotoFrame(d.cover),
        ),
        Positioned(
          left: 240,
          top: 78,
          bottom: 40,
          right: 20,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: 80,
              height: 448,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '模板分享',
                    style: _labelStyle(
                      size: 8,
                      color: _goldDeep,
                      ls: 3,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 22),
                  RotatedBox(
                    quarterTurns: 1,
                    child: Text(
                      d.name,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: _titleStyle(size: 28, ls: 8),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Container(width: 26, height: 1, color: _gold.withOpacity(0.7)),
                  const SizedBox(height: 20),
                  RotatedBox(
                    quarterTurns: 1,
                    child: Text(
                      d.category.trim().isEmpty ? '摄影模板' : d.category.trim(),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: _labelStyle(size: 8, color: _text2, ls: 4),
                    ),
                  ),
                  const Spacer(),
                  _QrBox(size: 74, data: d.qrData),
                  const SizedBox(height: 9),
                  Text(
                    '扫码导入模板\n打开如画 App',
                    textAlign: TextAlign.center,
                    style: _labelStyle(size: 8),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (d.expiryText != null)
          Positioned(
            left: 24,
            bottom: 26,
            child: Text(
              d.expiryText!,
              style: _labelStyle(size: 8, ls: 2),
            ),
          ),
      ],
    );
  }
}

/// 构图 2 · 3:4 上居中图 + 下居中文。
class _PortraitLayout extends StatelessWidget {
  const _PortraitLayout({required this.data});

  final _PosterData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Stack(
      children: [
        const Positioned(top: 16, left: 22, child: _Wordmark()),
        Positioned(top: 18, right: 22, child: _Serial(d.serial)),
        Positioned(
          left: 78,
          top: 64,
          width: 184,
          height: 246,
          child: _PhotoFrame(d.cover),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 336,
          bottom: 22,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const _Kicker(),
                  const SizedBox(height: 10),
                  _Title(d.name, size: 30, ls: 4),
                  const SizedBox(height: 8),
                  _Category(d.category),
                  const SizedBox(height: 12),
                  Container(width: 46, height: 1, color: _gold.withOpacity(0.7)),
                  const SizedBox(height: 14),
                  _QrBox(size: 78, data: d.qrData),
                  const SizedBox(height: 9),
                  Text(
                    '扫码导入模板 · 打开如画 App',
                    style: _labelStyle(size: 8),
                  ),
                  if (d.expiryText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      d.expiryText!,
                      style: _labelStyle(
                        size: 8,
                        color: _goldDeep,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 构图 3 · 1:1 左方图 + 右栏文。
class _SquareLayout extends StatelessWidget {
  const _SquareLayout({required this.data});

  final _PosterData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Stack(
      children: [
        const Positioned(top: 16, left: 22, child: _Wordmark()),
        Positioned(top: 18, right: 22, child: _Serial(d.serial)),
        Positioned(
          left: 28,
          top: 118,
          width: 196,
          height: 196,
          child: _PhotoFrame(d.cover),
        ),
        Positioned(
          left: 240,
          right: 22,
          top: 118,
          bottom: 44,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '模板分享',
                style: _labelStyle(
                  size: 8,
                  color: _goldDeep,
                  ls: 3,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              _Title(d.name, size: 26, ls: 3, maxLines: 2),
              const SizedBox(height: 8),
              Text(
                d.category.trim().isEmpty ? '摄影模板' : d.category.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _labelStyle(size: 8, color: _text2, ls: 2),
              ),
              const SizedBox(height: 14),
              Container(width: 26, height: 1, color: _gold.withOpacity(0.7)),
              const Spacer(),
              _QrBox(size: 76, data: d.qrData),
              const SizedBox(height: 9),
              Text(
                '扫码导入模板\n打开如画 App',
                style: _labelStyle(size: 8),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 构图 4 · 4:3 文在上 + 图在下。
class _LandscapeLayout extends StatelessWidget {
  const _LandscapeLayout({required this.data});

  final _PosterData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Stack(
      children: [
        const Positioned(top: 16, left: 22, child: _Wordmark()),
        Positioned(top: 18, right: 22, child: _Serial(d.serial)),
        Positioned(
          left: 0,
          right: 0,
          top: 58,
          child: Column(
            children: [
              const _Kicker(),
              const SizedBox(height: 10),
              _Title(d.name, size: 30, ls: 4),
              const SizedBox(height: 8),
              _Category(d.category),
            ],
          ),
        ),
        Positioned(
          left: 26,
          top: 176,
          width: 288,
          height: 216,
          child: _PhotoFrame(d.cover),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 26,
          child: Column(
            children: [
              _QrBox(size: 76, data: d.qrData),
              const SizedBox(height: 8),
              Text(
                '扫码导入模板 · 打开如画 App',
                style: _labelStyle(size: 8),
              ),
              if (d.expiryText != null) ...[
                const SizedBox(height: 7),
                Text(
                  d.expiryText!,
                  style: _labelStyle(
                    size: 8,
                    color: _goldDeep,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 构图 5 · 16:9 电影通栏 + 标题压图。
class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.data});

  final _PosterData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Stack(
      children: [
        // 通栏图片
        Positioned(
          left: 0,
          right: 0,
          top: 58,
          height: 186,
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (d.cover != null)
                  d.cover!.bytes != null
                      ? Image.memory(
                          d.cover!.bytes!,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, __, ___) =>
                              const _WideImagePlaceholder(),
                        )
                      : Image.network(
                          d.cover!.networkUrl ?? '',
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, __, ___) =>
                              const _WideImagePlaceholder(),
                        )
                else
                  const _WideImagePlaceholder(),
                // 压暗渐变
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x47140F0A),
                        Colors.transparent,
                        Color(0x0D140F0A),
                      ],
                      stops: [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
                // 底部金色发丝线
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(height: 1, color: _gold.withOpacity(0.8)),
                ),
                // 顶部裁切刻度
                Positioned(
                  left: 14,
                  right: 14,
                  top: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(width: 14, height: 1, color: _gold.withOpacity(0.7)),
                      Container(width: 14, height: 1, color: _gold.withOpacity(0.7)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // 压图 wordmark / 编号
        const Positioned(top: 16, left: 22, child: _Wordmark(onImage: true)),
        Positioned(top: 18, right: 22, child: _Serial(d.serial, onImage: true)),
        // 大标题
        Positioned(
          left: 24,
          top: 220,
          right: 24,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _Title(d.name, size: 40, ls: 6),
          ),
        ),
        // 信息行：分类 —— 有效期
        Positioned(
          left: 26,
          right: 26,
          top: 292,
          child: Row(
            children: [
              Expanded(
                child: _Category(d.category),
              ),
              const SizedBox(width: 12),
              if (d.expiryText != null)
                Text(
                  d.expiryText!,
                  style: _labelStyle(
                    size: 8,
                    color: _goldDeep,
                    weight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        // 底部：二维码 + 提示 + 品牌标语
        Positioned(
          left: 26,
          right: 26,
          bottom: 26,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _QrBox(size: 76, data: d.qrData),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '扫码导入模板',
                        style: _labelStyle(
                          size: 9,
                          color: _ink,
                          ls: 2,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '打开如画 App 扫码即可导入',
                        style: _labelStyle(size: 8),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'LUMIRA',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontFamilyFallback: _serifFallback,
                        fontSize: 9,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                        color: _goldDeep,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '如你所见 · 皆成画卷',
                      style: _labelStyle(size: 8),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 16:9 通栏图占位。
class _WideImagePlaceholder extends StatelessWidget {
  const _WideImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEFEAE0),
      child: const Center(
        child: Icon(Icons.photo_outlined, size: 34, color: _goldDeep),
      ),
    );
  }
}
