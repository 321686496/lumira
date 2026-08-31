import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/images/lumira_image.dart';
import '../../../shared/widgets/lumira/lumira.dart' show showLumiraBottomSheet;
import '../data/profile_mock_data.dart';

/// 碎片收集分享海报（暖白金线衬线风 · 3:4 竖版）
///
/// 三套可选照片布局：
/// - [FragmentPosterLayout.galleryStrip]  等高画廊带：每行照片等高、宽度随比例自适应，零留白
/// - [FragmentPosterLayout.matGrid]       装裱衬纸：统一 3+2 网格，像博物馆装裱，照片完整露出
/// - [FragmentPosterLayout.numberedStrip] 收藏编号版：等高画廊带 + 金色序号签，收藏册仪式感
///
/// 海报内新增一段「成就 + 邀请」混合文案（[buildFragmentPosterNote]），
/// 系统分享文案由 [buildFragmentShareText] 生成，共同提升用户分享欲。

/// 可选的海报照片布局。
enum FragmentPosterLayout {
  galleryStrip,
  matGrid,
  numberedStrip,
}

extension FragmentPosterLayoutMeta on FragmentPosterLayout {
  String get label {
    const map = {
      FragmentPosterLayout.galleryStrip: '等高画廊带',
      FragmentPosterLayout.matGrid: '装裱衬纸',
      FragmentPosterLayout.numberedStrip: '收藏编号版',
    };
    return map[this]!;
  }

  String get subtitle {
    const map = {
      FragmentPosterLayout.galleryStrip: '每行照片等高、宽度随比例自适应，零留白',
      FragmentPosterLayout.matGrid: '统一 3+2 网格，照片完整露出，整体最规整',
      FragmentPosterLayout.numberedStrip: '画廊带 + 金色序号签，收藏册仪式感',
    };
    return map[this]!;
  }
}

/// 海报内展示的分享文案（成就 + 邀请混合）。
///
/// 集齐时突出「成就 + 邀请」，进行中突出「进度 + 邀请一起收集」。
String buildFragmentPosterNote(FragmentItem fragment) {
  final name = fragment.name;
  final done = fragment.current >= fragment.max;
  if (done) {
    return '集齐 ${fragment.max} 枚「$name」碎片 · 邀你共赴光影之约';
  }
  final remain = fragment.max - fragment.current;
  return '还差 $remain 枚即可集齐「$name」，一起来收集吧';
}

/// 系统分享文案（成就 + 邀请混合，用于系统分享面板的 text 字段）。
String buildFragmentShareText(FragmentItem fragment) {
  final name = fragment.name;
  final cur = fragment.current;
  final max = fragment.max;
  final done = cur >= max;
  if (done) {
    return '我已在如画 LUMIRA 集齐「$name」碎片 $cur/$max！'
        '每一枚都是亲手拍摄记录的光影，集齐的瞬间成就感拉满～'
        '你也来试试吧，一起收集属于你的碎片！';
  }
  final remain = max - cur;
  return '我在如画 LUMIRA 收集「$name」碎片 $cur/$max 啦，'
      '还差 $remain 枚就集齐了！每一枚都是亲手拍的，'
      '快来加入一起把它集齐吧！';
}

/// 弹出「选择分享卡片」面板，返回用户选择的 [FragmentPosterLayout]；
/// 用户取消时返回 null。
Future<FragmentPosterLayout?> showFragmentPosterStylePicker({
  required BuildContext context,
}) {
  return showLumiraBottomSheet<FragmentPosterLayout>(
    context: context,
    builder: (ctx) => const _FragmentPosterStyleSheet(),
  );
}

/// 碎片海报内容 Widget（公开，供 PosterGenerator 包裹渲染）
///
/// 渲染暖白金线衬线风 3:4 竖版海报：细线 + 印章、品牌、衬线标题、照片区
/// （按所选布局）、分享文案、底部进度 + 品牌语。
class FragmentPosterContent extends StatefulWidget {
  const FragmentPosterContent({
    super.key,
    required this.tokens,
    required this.fragment,
    this.layout = FragmentPosterLayout.galleryStrip,
  });

  final ThemeTokens tokens;
  final FragmentItem fragment;
  final FragmentPosterLayout layout;

  @override
  State<FragmentPosterContent> createState() => _FragmentPosterContentState();
}

class _FragmentPosterContentState extends State<FragmentPosterContent> {
  /// 已收集照片的真实宽高比（宽/高），未解析到时默认 1:1。
  final Map<int, double> _ratios = {};
  bool _resolving = true;

  @override
  void initState() {
    super.initState();
    _resolveAll();
  }

  Future<void> _resolveAll() async {
    final urls = widget.fragment.photoUrls;
    final resolved = <int, double>{};
    for (var i = 0; i < urls.length; i++) {
      resolved[i] = await _resolveAspectRatio(urls[i]);
    }
    if (!mounted) return;
    setState(() {
      _ratios.addAll(resolved);
      _resolving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final fragment = widget.fragment;
    final done = fragment.current >= fragment.max;
    final slots = _buildSlots(fragment.photoUrls, fragment.max, _ratios);

    return Container(
      width: 300,
      height: 400,
      color: t.surface,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部细线 + 印章
          Row(
            children: [
              Expanded(
                child: Container(height: 1, color: t.brand.withOpacity(0.35)),
              ),
              const SizedBox(width: 8),
              _SealTag(tokens: t, done: done),
            ],
          ),
          const SizedBox(height: 14),
          // 品牌
          Text(
            'LUMIRA · 如画',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 3,
              fontWeight: FontWeight.w600,
              color: t.brand,
            ),
          ),
          const SizedBox(height: 8),
          // 衬线标题
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              fragment.name,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Noto Serif SC',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 标题短金线
          Center(child: Container(width: 44, height: 2, color: t.brand)),
          const SizedBox(height: 16),
          // 照片区（按所选布局）
          Expanded(
            child: _resolving
                ? Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: t.brand,
                      ),
                    ),
                  )
                : _PhotosArea(
                    layout: widget.layout,
                    slots: slots,
                    tokens: t,
                  ),
          ),
          const SizedBox(height: 12),
          // 分享文案（增强分享欲）
          Text(
            buildFragmentPosterNote(fragment),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Noto Serif SC',
              fontSize: 11,
              color: t.brandDeep,
              height: 1.5,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          // 底部进度 + 品牌语
          Column(
            children: [
              Text(
                done
                    ? '已集齐 ${fragment.max} / ${fragment.max}'
                    : '已收集 ${fragment.current} / ${fragment.max}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: t.textPrimary,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '如画 LUMIRA · 记录每一帧光影',
                style: TextStyle(
                  fontSize: 9,
                  color: t.textTertiary,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 依据已收集照片 + 目标数量构造槽位（不足 max 用虚线空位补齐）。
List<_PhotoSlot> _buildSlots(
  List<String> urls,
  int max,
  Map<int, double> ratios,
) {
  final slots = <_PhotoSlot>[];
  for (var i = 0; i < urls.length; i++) {
    slots.add(_PhotoSlot(url: urls[i], ratio: ratios[i] ?? 1.0));
  }
  while (slots.length < max) {
    slots.add(const _PhotoSlot(ratio: 1.0));
  }
  return slots;
}

/// 单个照片槽位。
class _PhotoSlot {
  const _PhotoSlot({this.url, required this.ratio});
  final String? url;
  final double ratio; // 宽/高
  bool get isEmpty => url == null || url!.isEmpty;
}

/// 照片区：按布局渲染。
class _PhotosArea extends StatelessWidget {
  const _PhotosArea({
    required this.layout,
    required this.slots,
    required this.tokens,
  });

  final FragmentPosterLayout layout;
  final List<_PhotoSlot> slots;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        switch (layout) {
          case FragmentPosterLayout.galleryStrip:
            return _GalleryStrip(
              tokens: tokens,
              slots: slots,
              numbered: false,
              width: width,
              height: height,
            );
          case FragmentPosterLayout.numberedStrip:
            return _GalleryStrip(
              tokens: tokens,
              slots: slots,
              numbered: true,
              width: width,
              height: height,
            );
          case FragmentPosterLayout.matGrid:
            return _MatGrid(tokens: tokens, slots: slots, width: width, height: height);
        }
      },
    );
  }
}

/// ①/③ 等高画廊带：每行照片等高，宽度随各自宽高比自适应，零留白。
class _GalleryStrip extends StatelessWidget {
  const _GalleryStrip({
    required this.tokens,
    required this.slots,
    required this.numbered,
    required this.width,
    required this.height,
  });

  final ThemeTokens tokens;
  final List<_PhotoSlot> slots;
  final bool numbered;
  final double width;
  final double height;

  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    final row1 = slots.take(3).toList();
    final row2 = slots.skip(3).take(2).toList();
    return Align(
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (row1.isNotEmpty) _stripRow(row1, 0, width, height),
          if (row2.isNotEmpty) ...[
            const SizedBox(height: _gap),
            _stripRow(row2, 3, width, height),
          ],
        ],
      ),
    );
  }

  Widget _stripRow(
    List<_PhotoSlot> row,
    int startIndex,
    double width,
    double height,
  ) {
    final count = row.length;
    final maxRowH = (height - _gap) / 2;
    final sumRatios = row.fold<double>(0, (s, slot) => s + slot.ratio);
    final rowGap = _gap * (count - 1);
    final fitH = sumRatios > 0 ? (width - rowGap) / sumRatios : 0.0;
    final rowH = (fitH > 0 && fitH < maxRowH) ? fitH : maxRowH;
    if (rowH <= 0) return const SizedBox.shrink();

    return SizedBox(
      width: width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: _gap),
            SizedBox(
              width: rowH * row[i].ratio,
              height: rowH,
              child: row[i].isEmpty
                  ? _EmptySlot(tokens: tokens, compact: true)
                  : _PhotoFrame(
                      tokens: tokens,
                      url: row[i].url!,
                      number: numbered ? (startIndex + i + 1) : null,
                      fit: BoxFit.fill,
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

/// ② 装裱衬纸：统一 3+2 网格，照片 contain 完整露出，衬纸留白规整。
class _MatGrid extends StatelessWidget {
  const _MatGrid({
    required this.tokens,
    required this.slots,
    required this.width,
    required this.height,
  });

  final ThemeTokens tokens;
  final List<_PhotoSlot> slots;
  final double width;
  final double height;

  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    final row1 = slots.take(3).toList();
    final row2 = slots.skip(3).take(2).toList();
    final rowH = (height - _gap) / 2;
    final row2SlotW = (width - _gap) / 2;

    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: _gap),
              Expanded(
                child: SizedBox(
                  height: rowH,
                  child: _MatSlot(tokens: tokens, slot: row1[i]),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: _gap),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 2; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                SizedBox(
                  width: row2SlotW,
                  height: rowH,
                  child: _MatSlot(tokens: tokens, slot: row2[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 衬纸格：衬纸底色 + 金线边框 + 金角标；照片 contain 完整露出，空位虚线。
class _MatSlot extends StatelessWidget {
  const _MatSlot({required this.tokens, required this.slot});

  final ThemeTokens tokens;
  final _PhotoSlot slot;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: tokens.surfaceAlt,
          child: slot.isEmpty
              ? _EmptySlot(tokens: tokens, compact: false)
              : Padding(
                  padding: const EdgeInsets.all(4),
                  child: LumiraImage(slot.url!, fit: BoxFit.contain),
                ),
        ),
        _GoldCorners(tokens: tokens, size: 12, strokeWidth: 2),
      ],
    );
  }
}

/// 画廊带照片框：金线描边 + 金角标 + 可选金色序号签，照片按比例填充不裁切。
class _PhotoFrame extends StatelessWidget {
  const _PhotoFrame({
    required this.tokens,
    required this.url,
    required this.fit,
    this.number,
  });

  final ThemeTokens tokens;
  final String url;
  final BoxFit fit;
  final int? number;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: tokens.brand.withOpacity(0.5), width: 1),
          ),
          child: LumiraImage(url, fit: fit),
        ),
        _GoldCorners(tokens: tokens, size: 11, strokeWidth: 2),
        if (number != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _NumberTag(tokens: tokens, number: number!),
            ),
          ),
      ],
    );
  }
}

/// 金色序号签（壹贰叁肆伍）。
class _NumberTag extends StatelessWidget {
  const _NumberTag({required this.tokens, required this.number});

  final ThemeTokens tokens;
  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: tokens.brandDeep,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _cnNumber(number),
        style: TextStyle(
          fontSize: 8,
          color: tokens.textInverse,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// 虚线空位（待收集）。
class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.tokens, required this.compact});

  final ThemeTokens tokens;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashRectPainter(
        color: tokens.brand.withOpacity(0.55),
        radius: 3,
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: compact ? 12 : 16, color: tokens.brand),
                if (!compact) ...[
                  const SizedBox(height: 2),
                  Text(
                    '待收集',
                    style: TextStyle(
                      fontSize: 8,
                      color: tokens.brand,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 印章：集齐（金色实心）/ 收集中（金色描边）。
class _SealTag extends StatelessWidget {
  const _SealTag({required this.tokens, required this.done});

  final ThemeTokens tokens;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: done ? tokens.brand : Colors.transparent,
        border: Border.all(color: tokens.brand, width: 1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        done ? '集齐' : '收集中',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
          color: done ? tokens.textInverse : tokens.brand,
        ),
      ),
    );
  }
}

/// 金角标：左上 + 右下 L 形金色描边。
class _GoldCorners extends StatelessWidget {
  const _GoldCorners({
    required this.tokens,
    required this.size,
    required this.strokeWidth,
  });

  final ThemeTokens tokens;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _GoldCornerPainter(
          color: tokens.brand,
          size: size,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _GoldCornerPainter extends CustomPainter {
  const _GoldCornerPainter({
    required this.color,
    required this.size,
    required this.strokeWidth,
  });

  final Color color;
  final double size;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final s = this.size;
    final tl = Path()
      ..moveTo(0, s)
      ..lineTo(0, 0)
      ..lineTo(s, 0);
    final br = Path()
      ..moveTo(size.width - s, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, size.height - s);
    canvas.drawPath(tl, paint);
    canvas.drawPath(br, paint);
  }

  @override
  bool shouldRepaint(covariant _GoldCornerPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.size != size ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// 虚线矩形（空位边框）。
class _DashRectPainter extends CustomPainter {
  const _DashRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + 4),
          paint,
        );
        distance += 7;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

/// 1x1 透明 PNG（图片解析失败时的兜底 provider，保证流有可监听对象）。
final Uint8List _k1x1TransparentPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// 中文序号（壹贰叁肆伍…），超出则回退阿拉伯数字。
const List<String> _kCnNumbers = ['壹', '贰', '叁', '肆', '伍', '陆', '柒', '捌', '玖', '拾'];

String _cnNumber(int n) {
  if (n >= 1 && n <= _kCnNumbers.length) return _kCnNumbers[n - 1];
  return '$n';
}

/// 为 URL 构造 ImageProvider（data / http / assets / 本地文件）。
ImageProvider? _providerFor(String url) {
  if (url.startsWith('data:')) {
    try {
      final commaIdx = url.indexOf(',');
      final raw = commaIdx >= 0 ? url.substring(commaIdx + 1) : url;
      return MemoryImage(base64Decode(raw));
    } catch (_) {
      return null;
    }
  }
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return NetworkImage(url);
  }
  if (url.startsWith('assets/')) {
    return AssetImage(url);
  }
  try {
    return FileImage(File(url));
  } catch (_) {
    return null;
  }
}

/// 限制解码尺寸的 provider（仅用于读取宽高比，比例不受缩放影响）。
ImageProvider _limitedProviderFor(String url) {
  final base = _providerFor(url);
  if (base == null) return MemoryImage(_k1x1TransparentPng);
  if (base is MemoryImage) {
    return ResizeImage(MemoryImage(base.bytes), width: 512);
  }
  if (base is NetworkImage) {
    return ResizeImage(NetworkImage(base.url), width: 512);
  }
  return base;
}

/// 异步解析图片真实宽高比（宽/高），失败或超时回退 1:1。
Future<double> _resolveAspectRatio(String url) async {
  final provider = _limitedProviderFor(url);
  try {
    final stream = provider.resolve(const ImageConfiguration());
    final completer = Completer<double>();
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          final w = info.image.width.toDouble();
          final h = info.image.height.toDouble();
          completer.complete(h > 0 ? w / h : 1.0);
        }
        info.dispose();
      },
      onError: (Object error, StackTrace? stackTrace) {
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete(1.0);
      },
    );
    stream.addListener(listener);
    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        stream.removeListener(listener);
        return 1.0;
      },
    );
  } catch (_) {
    return 1.0;
  }
}

/// 「选择分享卡片」面板。
class _FragmentPosterStyleSheet extends ConsumerWidget {
  const _FragmentPosterStyleSheet();

  void _pick(BuildContext context, FragmentPosterLayout layout) {
    Navigator.of(context).pop(layout);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    return SingleChildScrollView(
      child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '选择分享卡片',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
        ),
        Text(
          '3:4 竖版 · 暖白金线衬线风 · 照片完整露出',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: tokens.textTertiary),
        ),
        const SizedBox(height: 14),
        for (final layout in FragmentPosterLayout.values) ...[
          _StyleOption(
            layout: layout,
            tokens: tokens,
            onTap: () => _pick(context, layout),
          ),
          const SizedBox(height: 8),
        ],
      ],
    ),
  );
  }
}
class _StyleOption extends StatelessWidget {
  const _StyleOption({
    required this.layout,
    required this.tokens,
    required this.onTap,
  });

  final FragmentPosterLayout layout;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            _LayoutSchematic(layout: layout, tokens: tokens),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    layout.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    layout.subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: tokens.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: tokens.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// 布局示意缩略图（迷你 3:4 卡片）。
class _LayoutSchematic extends StatelessWidget {
  const _LayoutSchematic({required this.layout, required this.tokens});

  final FragmentPosterLayout layout;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final gold = tokens.brand;
    final goldSoft = tokens.brand.withOpacity(0.55);
    final goldDeep = tokens.brandDeep;
    return Container(
      width: 46,
      height: 60,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: goldSoft, width: 1),
      ),
      child: Column(
        children: [
          // 标题短线
          Container(height: 3, width: 18, color: gold),
          const SizedBox(height: 4),
          Expanded(
            child: _schematicFor(
              layout,
              gold: gold,
              goldSoft: goldSoft,
              goldDeep: goldDeep,
            ),
          ),
        ],
      ),
    );
  }

  Widget _schematicFor(
    FragmentPosterLayout layout, {
    required Color gold,
    required Color goldSoft,
    required Color goldDeep,
  }) {
    switch (layout) {
      case FragmentPosterLayout.galleryStrip:
        return _schematicStrip(gold, goldSoft);
      case FragmentPosterLayout.numberedStrip:
        return _schematicStrip(gold, goldSoft,
            numbered: true, goldDeep: goldDeep);
      case FragmentPosterLayout.matGrid:
        return _schematicGrid(goldSoft);
    }
  }

  Widget _schematicStrip(Color gold, Color goldSoft,
      {bool numbered = false, Color? goldDeep}) {
    Widget bar(double flex, bool filled) => Container(
          height: 7,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: filled ? goldSoft : Colors.transparent,
            border: Border.all(color: goldSoft, width: 0.8),
          ),
          child: numbered && filled
              ? Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: 4,
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 1),
                    color: goldDeep,
                  ),
                )
              : null,
        );

    Widget row(List<double> flexes, List<bool> filled) => Row(
          children: [
            for (var i = 0; i < flexes.length; i++)
              Expanded(flex: (flexes[i] * 10).round(), child: bar(flexes[i], filled[i])),
          ],
        );

    return Column(
      children: [
        row([1.0, 0.7, 0.5], [true, true, true]),
        const SizedBox(height: 3),
        row([0.85, 0.6], [true, true]),
      ],
    );
  }

  Widget _schematicGrid(Color goldSoft) {
    Widget cell({bool filled = false}) => Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: filled ? goldSoft : Colors.transparent,
            border: Border.all(color: goldSoft, width: 0.8),
          ),
        );
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [cell(filled: true), cell(), cell(filled: true)],
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 16, child: cell(filled: true)),
              const SizedBox(width: 2),
              SizedBox(width: 16, child: cell()),
            ],
          ),
        ),
      ],
    );
  }
}

