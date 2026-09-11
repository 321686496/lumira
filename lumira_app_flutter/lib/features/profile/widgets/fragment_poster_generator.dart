import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/images/lumira_image.dart';
import '../../../shared/widgets/lumira/lumira.dart' show showLumiraBottomSheet;
import '../data/profile_mock_data.dart';

/// 碎片收集分享海报（暖白金线衬线风 · 3:4 竖版）
///
/// 核心视觉 = 一块「对角斜裂」的碎片拼板（5 片，已收集到用照片填实、金线描边；
/// 未收集到用虚线 + 「待拼」空位补齐），配合情绪化文案（金句标题 + 诗意正文）
/// 与收集进度模块。共三套版式：
/// - [FragmentPosterLayout.editorial]  上情绪标题 / 中拼板 / 下进度横条
/// - [FragmentPosterLayout.zen]        居中大留白 / 情绪金句 / 极简进度
/// - [FragmentPosterLayout.darkBloom]  暗底大牌 / 拼板铺满 / 光从暗里来
///
/// 分享文案由 [buildFragmentShareText] 生成。

/// 可选的海报版式。
enum FragmentPosterLayout {
  editorial,
  zen,
  darkBloom,
}

extension FragmentPosterLayoutMeta on FragmentPosterLayout {
  String get label {
    const map = {
      FragmentPosterLayout.editorial: '上情绪 · 中拼板 · 下进度',
      FragmentPosterLayout.zen: '居中留白 · 情绪金句',
      FragmentPosterLayout.darkBloom: '暗底大牌 · 光从暗里来',
    };
    return map[this]!;
  }

  String get subtitle {
    const map = {
      FragmentPosterLayout.editorial: '衬线标题 + 诗意正文清晰分层，进度用大字横条',
      FragmentPosterLayout.zen: '大留白，情绪金句点题，进度极简聚焦',
      FragmentPosterLayout.darkBloom: '深色画布，拼板铺展，白色衬线标题叠暗部',
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

/// 碎片海报内容 Widget（公开，供 PosterGenerator 包裹渲染）。
class FragmentPosterContent extends StatefulWidget {
  const FragmentPosterContent({
    super.key,
    required this.tokens,
    required this.fragment,
    this.layout = FragmentPosterLayout.editorial,
  });

  final ThemeTokens tokens;
  final FragmentItem fragment;
  final FragmentPosterLayout layout;

  @override
  State<FragmentPosterContent> createState() => _FragmentPosterContentState();
}

class _FragmentPosterContentState extends State<FragmentPosterContent> {
  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final fragment = widget.fragment;
    final filled = fragment.current.clamp(0, fragment.max).toInt();

    Widget body;
    switch (widget.layout) {
      case FragmentPosterLayout.editorial:
        body = _Editorial(tokens: t, fragment: fragment, filled: filled);
        break;
      case FragmentPosterLayout.zen:
        body = _Zen(tokens: t, fragment: fragment, filled: filled);
        break;
      case FragmentPosterLayout.darkBloom:
        body = _DarkBloom(tokens: t, fragment: fragment, filled: filled);
        break;
    }

    if (widget.layout == FragmentPosterLayout.darkBloom) {
      // 暗底铺满，无内发丝边框
      return SizedBox(width: 300, height: 400, child: body);
    }

    // 浅色海报：暖白→暖杏 渐变底 + 内发丝描边（复现 HTML .poster 背景 + .hairline）
    const hairline = Color(0x57C9A96E); // rgba(201,169,110,.34)
    return Container(
      width: 300,
      height: 400,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFDFBF7), Color(0xFFFBF5EA)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: body),
          const Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.fromBorderSide(BorderSide(color: hairline, width: 1)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 碎片拼板几何（与 visual v17 中对角斜裂 5 片完全一致）
// ============================================================================

class _V {
  const _V(this.x, this.y);
  final double x;
  final double y;
}

const int _kW = 272;
const int _kH = 209;

/// 生成带中点锯齿的折线点列（amp>0 时在每个线段中点沿法线偏移，左右交替）。
List<_V> _jag(List<_V> pts, {double amp = 0}) {
  if (amp <= 0) return List<_V>.of(pts);
  final out = <_V>[pts[0]];
  var s = 1.0;
  for (var i = 0; i < pts.length - 1; i++) {
    final a = pts[i], b = pts[i + 1];
    final dx = b.x - a.x, dy = b.y - a.y;
    final L = math.sqrt(dx * dx + dy * dy);
    final nx = L == 0 ? 0.0 : -dy / L;
    final ny = L == 0 ? 0.0 : dx / L;
    out.add(_V((a.x + b.x) / 2 + nx * amp * s, (a.y + b.y) / 2 + ny * amp * s));
    out.add(_V(b.x, b.y));
    s = -s;
  }
  return out;
}

/// 生成 5 块紧密拼接（无缝隙、无重叠）的对角斜裂面。
/// 相邻面共享同一条边（方向相反），严格对齐。
List<List<_V>> _fragFaces() {
  final lT = _jag(const [_V(0, 0), _V(0, 64)]);
  final lB = _jag(const [_V(0, 64), _V(0, 209)]);
  final tL = _jag(const [_V(0, 0), _V(88, 0), _V(176, 0)]);
  final tR = _jag(const [_V(176, 0), _V(224, 0), _V(272, 0)]);
  final rA = _jag(const [_V(272, 0), _V(272, 90), _V(272, 150)]);
  final rB = _jag(const [_V(272, 150), _V(272, 209)]);
  final bL = _jag(const [_V(0, 209), _V(38, 209), _V(76, 209)]);
  final bM = _jag(const [_V(76, 209), _V(142, 209), _V(208, 209)]);
  final bR = _jag(const [_V(208, 209), _V(272, 209)]);
  final d0 = _jag(const [_V(0, 64), _V(50, 76), _V(90, 94)], amp: 2.6);
  final d1 = _jag(const [_V(90, 94), _V(128, 108), _V(160, 120)], amp: 2.6);
  final d2 = _jag(const [_V(160, 120), _V(188, 127), _V(220, 133)], amp: 2.4);
  final d3 = _jag(const [_V(220, 133), _V(244, 141), _V(272, 150)], amp: 2.6);
  final bUp = _jag(const [_V(176, 0), _V(170, 58), _V(160, 120)], amp: 2.4);
  final bDn1 = _jag(const [_V(90, 94), _V(84, 150), _V(76, 209)], amp: 2.6);
  final bDn2 = _jag(const [_V(220, 133), _V(214, 170), _V(208, 209)], amp: 2.4);

  List<_V> rev(List<_V> a) => a.reversed.toList();
  List<_V> join(List<List<_V>> ss) {
    final o = <_V>[];
    for (final s in ss) {
      for (final p in s) {
        final l = o.isEmpty ? null : o.last;
        if (l == null || l.x != p.x || l.y != p.y) o.add(p);
      }
    }
    final l = o.last;
    if (l.x == o.first.x && l.y == o.first.y) o.removeLast();
    return o;
  }

  return [
    join([tL, bUp, rev(d1), rev(d0), rev(lT)]),
    join([tR, rA, rev(d3), rev(d2), rev(bUp)]),
    join([d0, bDn1, rev(bL), rev(lB)]),
    join([d1, d2, bDn2, rev(bM), rev(bDn1)]),
    join([d3, rB, rev(bR), rev(bDn2)]),
  ];
}

/// 单块碎片。
class _Face {
  _Face({required this.index, required this.points, required this.url});
  final int index;
  final List<_V> points;
  final String? url;

  Rect get bbox {
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final p in points) {
      if (p.x < minX) minX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.x > maxX) maxX = p.x;
      if (p.y > maxY) maxY = p.y;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  Offset get centroid {
    double sumX = 0, sumY = 0;
    for (final p in points) {
      sumX += p.x;
      sumY += p.y;
    }
    return Offset(sumX / points.length, sumY / points.length);
  }

  Path buildPath(double sx, double sy) {
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final ox = p.x * sx, oy = p.y * sy;
      if (i == 0) {
        path.moveTo(ox, oy);
      } else {
        path.lineTo(ox, oy);
      }
    }
    path.close();
    return path;
  }
}

/// 已收集前 `filled` 片填照片，其余为空位补齐。
List<_Face> _buildFaces(List<String> urls, int filled) {
  final raw = _fragFaces();
  return [
    for (var i = 0; i < raw.length; i++)
      _Face(index: i, points: raw[i], url: i < filled ? urls[i] : null),
  ];
}

// ============================================================================
// 碎片拼板组件：已收集 → ClipPath 裁照片；空位 → 虚线 + 待拼；金线描边
// ============================================================================

/// 把整个拼板按画布 contain / stretch 布局。
class _FragmentBoard extends StatelessWidget {
  const _FragmentBoard({
    required this.faces,
    required this.strokeColor,
    required this.surfaceAlt,
    required this.emptyTextColor,
    this.fill = false,
    this.decorate = false,
  });

  final List<_Face> faces;
  final Color strokeColor;
  final Color surfaceAlt;
  final Color emptyTextColor;

  /// true 时拉伸填满整个可用区域，否则等比 contain 居中。
  final bool fill;

  /// true 时为拼板加金色描边 + 柔和投影（复现 HTML .boardbox 的金线 outline 与阴影）。
  final bool decorate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxW = constraints.maxWidth;
        final boxH = constraints.maxHeight;
        double sx, sy, w, h;
        if (fill) {
          sx = boxW / _kW;
          sy = boxH / _kH;
          w = boxW;
          h = boxH;
        } else {
          final s = math.min(boxW / _kW, boxH / _kH);
          sx = s;
          sy = s;
          w = _kW * s;
          h = _kH * s;
        }
        final board = SizedBox(
          width: w,
          height: h,
          child: Stack(
            children: [
              // 已收集碎片：ClipPath 裁照片
              for (final face in faces)
                if (face.url != null)
                  Positioned(
                    left: face.bbox.left * sx,
                    top: face.bbox.top * sy,
                    width: face.bbox.width * sx,
                    height: face.bbox.height * sy,
                    child: ClipPath(
                      clipper: _FaceClipper(
                        points: face.points,
                        origin: Offset(face.bbox.left, face.bbox.top),
                        sx: sx,
                        sy: sy,
                      ),
                      child: LumiraImage(face.url!, fit: BoxFit.cover),
                    ),
                  ),
              // 描边 / 空位
              Positioned.fill(
                child: CustomPaint(
                  painter: _BoardOverlayPainter(
                    faces: faces,
                    sx: sx,
                    sy: sy,
                    strokeColor: strokeColor,
                    surfaceAlt: surfaceAlt,
                    emptyTextColor: emptyTextColor,
                  ),
                ),
              ),
            ],
          ),
        );
        if (!decorate) return Center(child: board);
        return Center(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0x57C9A96E)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66302414),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: board,
          ),
        );
      },
    );
  }
}

/// 让 [path] 相对裁剪框原点（框 = 所在 bbox）表达。
class _FaceClipper extends CustomClipper<Path> {
  _FaceClipper({required this.points, required this.origin, required this.sx, required this.sy});
  final List<_V> points;
  final Offset origin;
  final double sx;
  final double sy;

  @override
  Path getClip(Size size) {
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final ox = (points[i].x - origin.dx) * sx;
      final oy = (points[i].y - origin.dy) * sy;
      if (i == 0) {
        path.moveTo(ox, oy);
      } else {
        path.lineTo(ox, oy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _FaceClipper old) =>
      old.points != points || old.sx != sx || old.sy != sy;
}

/// 纯矢量描边 + 空位（不涉及位图，可同步绘制）。
class _BoardOverlayPainter extends CustomPainter {
  _BoardOverlayPainter({
    required this.faces,
    required this.sx,
    required this.sy,
    required this.strokeColor,
    required this.surfaceAlt,
    required this.emptyTextColor,
  });

  final List<_Face> faces;
  final double sx;
  final double sy;
  final Color strokeColor;
  final Color surfaceAlt;
  final Color emptyTextColor;

  static const double _fontSize = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final solid = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * (sx + sy) / 2
      ..strokeJoin = StrokeJoin.round;
    final dashed = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * (sx + sy) / 2
      ..strokeJoin = StrokeJoin.round;

    // 空位：先画浅表面对 + 虚线 + 「待拼」
    for (final face in faces) {
      if (face.url != null) continue;
      final path = face.buildPath(sx, sy);
      canvas.drawPath(path, Paint()..color = surfaceAlt);
      _dashPath(canvas, path, dashed);
      final c = Offset(face.centroid.dx * sx, face.centroid.dy * sy);
      _drawCenteredText(canvas, c, '待拼', emptyTextColor, _fontSize * (sx + sy) / 2);
    }

    // 已收集：实线金边（盖在照片上）
    for (final face in faces) {
      if (face.url == null) continue;
      canvas.drawPath(face.buildPath(sx, sy), solid);
    }
  }

  void _drawCenteredText(Canvas canvas, Offset center, String text, Color color, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          letterSpacing: 1,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _dashPath(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      final seg = 5 * (sx + sy) / 2;
      final gap = 8 * (sx + sy) / 2;
      while (dist < metric.length) {
        canvas.drawPath(metric.extractPath(dist, dist + seg), paint);
        dist += seg + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoardOverlayPainter old) =>
      old.faces != faces || old.sx != sx || old.sy != sy;
}

// ============================================================================
// 版式 A · 上情绪 / 中拼板 / 下进度
// ============================================================================

class _Editorial extends StatelessWidget {
  const _Editorial({required this.tokens, required this.fragment, required this.filled});
  final ThemeTokens tokens;
  final FragmentItem fragment;
  final int filled;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final faces = _buildFaces(fragment.photoUrls, filled);
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 20, 26, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _BrandText(enColor: t.brandDeep, zhColor: t.textTertiary),
              const Spacer(),
              _SealTag(tokens: t, done: fragment.current >= fragment.max),
            ],
          ),
          const SizedBox(height: 18),
          const _Kicker(text: 'FRAGMENTS · 光影碎片集', color: Color(0xFFA9884B)),
          const SizedBox(height: 8),
          const _EmotionalTitle(color: Color(0xFF2A241C), gold: Color(0xFFA9884B)),
          const SizedBox(height: 11),
          const _Poem(
            lines: ['天空被切开，光漏了下来。', '每一缕，都曾在某个黄昏被你留住。'],
            color: Color(0xFF6B6257),
            bar: Color(0xFFE4D3AF),
            barThick: 1.5,
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _FragmentBoard(
              faces: faces,
              strokeColor: t.brand,
              surfaceAlt: t.surfaceAlt,
              emptyTextColor: t.textTertiary,
              decorate: true,
            ),
          ),
          const SizedBox(height: 16),
          _ProgressEditorial(t: t, filled: filled, max: fragment.max),
        ],
      ),
    );
  }
}

// ============================================================================
// 版式 B · 居中留白 / 情绪金句 / 极简进度
// ============================================================================

class _Zen extends StatelessWidget {
  const _Zen({required this.tokens, required this.fragment, required this.filled});
  final ThemeTokens tokens;
  final FragmentItem fragment;
  final int filled;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final faces = _buildFaces(fragment.photoUrls, filled);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _BrandText(enColor: t.brandDeep, zhColor: t.textTertiary)),
          const SizedBox(height: 18),
          const Center(child: _Kicker(text: '光影碎片集', color: Color(0xFFA9884B))),
          const SizedBox(height: 9),
          const Center(child: _EmotionalTitle(color: Color(0xFF2A241C), gold: Color(0xFFA9884B))),
          const SizedBox(height: 12),
          Center(
            child: Container(width: 30, height: 1.5, color: const Color(0xFFC9A96E)),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: FractionallySizedBox(
              widthFactor: 0.86,
              child: _FragmentBoard(
                faces: faces,
                strokeColor: t.brand,
                surfaceAlt: t.surfaceAlt,
                emptyTextColor: t.textTertiary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Center(
            child: _Quote(
              text: '天空被切开，光漏了下来。每一缕，都是我和你抄下的黄昏。',
              color: Color(0xFF2A241C),
              gold: Color(0xFFA9884B),
            ),
          ),
          const SizedBox(height: 12),
          _ProgressZen(t: t, filled: filled, max: fragment.max),
          const Spacer(),
          const SizedBox(height: 6),
          Center(
            child: Text(
              '如 画 · 记 录 每 一 帧 光 影',
              style: TextStyle(fontSize: 8, letterSpacing: 2, color: t.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkBloom extends StatelessWidget {
  const _DarkBloom({required this.tokens, required this.fragment, required this.filled});
  final ThemeTokens tokens;
  final FragmentItem fragment;
  final int filled;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final faces = _buildFaces(fragment.photoUrls, filled);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1C1812), Color(0xFF12100C)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 拼板铺满
          _FragmentBoard(
            faces: faces,
            fill: true,
            strokeColor: const Color(0xFFCDB081),
            surfaceAlt: const Color(0x3025221B),
            emptyTextColor: const Color(0x99E4D3AF),
          ),
          // 光晕氛围：顶部径向泛光 + 底部线性压暗（复现 HTML .shade）
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -1),
                  radius: 1.25,
                  colors: [Color(0x33000000), Color(0x00000000), Color(0xBD0A0805)],
                  stops: [0.0, 0.42, 1.0],
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xB30A0805)],
                  stops: [0.42, 1.0],
                ),
              ),
            ),
          ),
          // 顶部品牌与印章
          Positioned(
            left: 24, right: 24, top: 22,
            child: Row(
              children: [
                const _BrandText(enColor: Color(0xFFE7CE9E), zhColor: Color(0x99FFFFFF)),
                const Spacer(),
                _SealTag(tokens: t, done: fragment.current >= fragment.max, light: true),
              ],
            ),
          ),
          // 底部文案区
          Positioned(
            left: 28, right: 28, bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Kicker(text: '光影碎片集 · FRAGMENTS', color: Color(0xFFE7CE9E)),
                const SizedBox(height: 9),
                const _EmotionalTitle(color: Color(0xFFFFF8EC), gold: Color(0xFFE7CE9E)),
                const SizedBox(height: 10),
                const _Poem(
                  lines: ['天空被切开，光漏了下来。每一缕，都曾在你掌心停过。'],
                  color: Color(0xBDDDFFFF),
                  bar: Color(0x80E7CE9E),
                  barThick: 1.5,
                  barHeight: 30,
                  barOpacity: 1,
                ),
                const SizedBox(height: 14),
                // 横向金色渐弱金线
                Container(
                  height: 1.5,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFFC9A96E), Color(0x00C9A96E)],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _ProgressDark(t: t, filled: filled, max: fragment.max),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 各版式进度模块
// ============================================================================

class _ProgressEditorial extends StatelessWidget {
  const _ProgressEditorial({required this.t, required this.filled, required this.max});
  final ThemeTokens t;
  final int filled;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: const Color(0x57C9A96E)),
        const SizedBox(height: 12),
        Row(
          children: [
            Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '$filled',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: t.brandDeep,
                    height: 1,
                  ),
                ),
                TextSpan(
                  text: ' / $max',
                  style: TextStyle(fontSize: 12, color: t.textTertiary),
                ),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Bar(t: t, filled: filled, max: max),
                  const SizedBox(height: 6),
                  Text(
                    '还差 ${max - filled} 缕 · 一起凑齐一束光',
                    style: TextStyle(fontSize: 8.5, letterSpacing: 1, color: t.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProgressZen extends StatelessWidget {
  const _ProgressZen({required this.t, required this.filled, required this.max});
  final ThemeTokens t;
  final int filled;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '已 $filled / $max · 还差 ${(max - filled).toString().padLeft(2, '0')} 缕点亮完整',
          style: TextStyle(fontSize: 10, letterSpacing: 2, color: t.textSecondary),
        ),
        const SizedBox(height: 9),
        Center(child: SizedBox(width: 200, child: _Bar(t: t, filled: filled, max: max))),
      ],
    );
  }
}

class _ProgressDark extends StatelessWidget {
  const _ProgressDark({required this.t, required this.filled, required this.max});
  final ThemeTokens t;
  final int filled;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text.rich(
          TextSpan(
            style: const TextStyle(height: 1),
            children: [
              TextSpan(
                text: '$filled',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE7CE9E),
                ),
              ),
              TextSpan(
                text: ' / $max',
                style: const TextStyle(fontSize: 12, color: Color(0x88FFFFFF)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Bar(t: t, filled: filled, max: max, dark: true),
              const SizedBox(height: 7),
              Text(
                '还差 ${max - filled} 缕 · 一起凑齐一束光',
                style: const TextStyle(fontSize: 8.5, letterSpacing: 1, color: Color(0x99FFFFFF)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 进度横条（max 等分，filled 或填充金色）。
class _Bar extends StatelessWidget {
  const _Bar({required this.t, required this.filled, required this.max, this.dark = false});
  final ThemeTokens t;
  final int filled;
  final int max;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final base = dark ? const Color(0x33FFFFFF) : t.brand.withOpacity(0.3);
    return Row(
      children: [
        for (var i = 0; i < max; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: i < filled ? t.brand : base,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================================
// 共享小组件
// ============================================================================

class _BrandText extends StatelessWidget {
  const _BrandText({required this.enColor, required this.zhColor});
  final Color enColor;
  final Color zhColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('LUMIRA',
            style: TextStyle(
                fontSize: 10, letterSpacing: 4, fontWeight: FontWeight.w700, color: enColor)),
        const SizedBox(width: 7),
        Text('如画', style: TextStyle(fontSize: 9, letterSpacing: 3, color: zhColor)),
      ],
    );
  }
}

class _Kicker extends StatelessWidget {
  const _Kicker({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 9, letterSpacing: 2.5, color: color, fontWeight: FontWeight.w600),
    );
  }
}

/// 情绪标题「光，正一片片归位」，「一片片」金色强调。
class _EmotionalTitle extends StatelessWidget {
  const _EmotionalTitle({required this.color, required this.gold});
  final Color color;
  final Color gold;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            fontFamily: 'Noto Serif SC',
            fontSize: 27,
            fontWeight: FontWeight.w700,
            color: color,
            height: 1.2,
          ),
          children: [
            const TextSpan(text: '光，正'),
            TextSpan(text: '一片片', style: TextStyle(color: gold)),
            const TextSpan(text: '归位'),
          ],
        ),
      ),
    );
  }
}

/// 诗意正文（左侧金线引导）。
class _Poem extends StatelessWidget {
  const _Poem({
    required this.lines,
    required this.color,
    required this.bar,
    this.barThick = 2.5,
    this.barHeight = 34,
    this.barOpacity = 0.55,
  });
  final List<String> lines;
  final Color color;
  final Color bar;
  final double barThick;
  final double barHeight;
  final double barOpacity;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: barThick, height: barHeight, color: bar.withOpacity(barOpacity)),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final l in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(l,
                      style: TextStyle(fontSize: 10.5, color: color, height: 1.7, letterSpacing: .3)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 情绪金句（双引号 + 居中，无左侧金线；用于版式 B）。
class _Quote extends StatelessWidget {
  const _Quote({
    required this.text,
    required this.color,
    required this.gold,
  });
  final String text;
  final Color color;
  final Color gold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 10, color: Color(0xFF2A241C), height: 1.9, letterSpacing: .5),
          children: [
            TextSpan(text: '“', style: TextStyle(color: gold)),
            TextSpan(text: text, style: TextStyle(color: color)),
            TextSpan(text: '”', style: TextStyle(color: gold)),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// 印章：集齐（金色实心）/ 收集中（金色描边）。
class _SealTag extends StatelessWidget {
  const _SealTag({required this.tokens, required this.done, this.light = false});
  final ThemeTokens tokens;
  final bool done;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final brand = light ? const Color(0xFFE7CE9E) : tokens.brand;
    final fg = light ? const Color(0xE63C3227) : tokens.textInverse;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: done ? brand : Colors.transparent,
        border: Border.all(color: brand, width: 1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        done ? '集齐' : '拼碎片',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
          color: done ? fg : brand,
        ),
      ),
    );
  }
}

// ============================================================================
// 选择面板
// ============================================================================

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
              '选择分享海报',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: tokens.textPrimary),
            ),
          ),
          Text(
            '3:4 竖版 · 碎片拼板 · 情绪文案 + 进度',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: tokens.textTertiary),
          ),
          const SizedBox(height: 14),
          for (final layout in FragmentPosterLayout.values) ...[
            _StyleOption(layout: layout, tokens: tokens, onTap: () => _pick(context, layout)),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _StyleOption extends StatelessWidget {
  const _StyleOption({required this.layout, required this.tokens, required this.onTap});
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
                  Text(layout.label,
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                  const SizedBox(height: 3),
                  Text(layout.subtitle,
                      style: TextStyle(fontSize: 11, color: tokens.textSecondary, height: 1.4)),
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

/// 版式示意缩略图。
class _LayoutSchematic extends StatelessWidget {
  const _LayoutSchematic({required this.layout, required this.tokens});
  final FragmentPosterLayout layout;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final gold = tokens.brand;
    final goldSoft = tokens.brand.withOpacity(0.55);
    return Container(
      width: 46,
      height: 60,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: layout == FragmentPosterLayout.darkBloom ? const Color(0xFF1D1A14) : tokens.surface,
        border: Border.all(color: goldSoft, width: 1),
      ),
      child: _schematic(layout, gold: gold, goldSoft: goldSoft),
    );
  }

  Widget _schematic(FragmentPosterLayout layout,
      {required Color gold, required Color goldSoft}) {
    Widget bar(double h, {bool on = false}) => Container(
          height: h,
          decoration: BoxDecoration(
            color: on ? gold : goldSoft.withOpacity(.45),
            borderRadius: BorderRadius.circular(1),
          ),
        );
    final board = Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: goldSoft.withOpacity(.3),
        border: Border.all(color: goldSoft, width: .8),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(child: bar(3)),
          const SizedBox(width: 4),
          SizedBox(width: 8, child: bar(3)),
        ]),
        Expanded(child: board),
        bar(2, on: true),
        const SizedBox(height: 3),
        bar(1.5),
      ],
    );
  }
}