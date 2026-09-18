import 'dart:math' as math;
import 'dart:ui' as ui show MaskFilter, BlurStyle;

import 'package:flutter/material.dart';

import '../../../shared/widgets/poster/poster_common.dart';
import '../../../shared/widgets/poster/poster_ratio.dart';
import '../../../shared/widgets/poster/poster_style_types.dart';
import 'checkin_poster_widgets.dart';

/// 探店足迹海报画布逻辑宽度（预览区 FittedBox 等比缩放，导出按 1080 重采样）。
const double _kCkW = 320;

/// 4 款探店足迹海报样式，与选型设计稿严格一一对应：
/// - `ckF`  温柔手帐  → `poster_mockup_checkin_f.html`
/// - `ckF2` 奶油莫兰迪 → `poster_mockup_checkin_f2.html`
/// - `ckV2` 鎏金画框   → `poster_mockup_checkin_v2.html`
/// - `ckM4` 错落画廊   → `poster_mockup_checkin_m4.html`
List<PosterStyle> checkinPosterStyles() => [
      _style('ckF', '温柔手帐', _buildSoftJournal),
      _style('ckF2', '奶油莫兰迪', _buildMorandi),
      _style('ckV2', '鎏金画框', _buildGoldFrame),
      _style('ckM4', '错落画廊', _buildAsymmetric),
    ];

PosterStyle _style(
        String id, String name, Widget Function(PosterStyleData) b) =>
    PosterStyle(
      id: id,
      name: name,
      groupName: name,
      kind: PosterKind.checkin,
      ratios: {PosterRatio.ratio34},
      builder: b,
    );

// ---------- 度量工具：设计稿 px → 画布逻辑 px ----------

/// 设计稿基准宽：f / f2 / m4 为 520，v2 为 540。
double _px(double v, double dw) => v * _kCkW / dw;

/// 字号换算（设 7 下限：更小在预览与导出中均已不可读）。
double _fs(double v, double dw) => _px(v, dw).clamp(7.0, 64.0).toDouble();

/// 评分星文本：实心 ★ + 空心 ☆，共 5 颗。
String _starsText(double rating) {
  final n = rating.round();
  final filled = n < 0 ? 0 : (n > 5 ? 5 : n);
  return List<String>.filled(filled, '★').join() +
      List<String>.filled(5 - filled, '☆').join();
}

/// 小图带：等分排布，间距 [gap]。
Widget _thumbRow({required List<Widget> cells, required double gap}) {
  final children = <Widget>[];
  for (var i = 0; i < cells.length; i++) {
    if (i > 0) children.add(SizedBox(width: gap));
    children.add(cells[i]);
  }
  return Row(children: children);
}

/// 圆角裁切的照片块。
Widget _photo(Widget Function(double, double) b, double w, double h, double r) {
  final child = b(w, h);
  return r <= 0
      ? child
      : ClipRRect(borderRadius: BorderRadius.circular(r), child: child);
}

/// 顶部/底部的一对「L」直角括号（topLeft / bottomRight）。
Widget _bracket({
  required double size,
  required double stroke,
  required Color color,
  required bool lower,
}) {
  return SizedBox(
    width: size,
    height: size,
    child: Container(
      decoration: BoxDecoration(
        border: lower
            ? Border(
                right: BorderSide(color: color, width: stroke),
                bottom: BorderSide(color: color, width: stroke),
              )
            : Border(
                left: BorderSide(color: color, width: stroke),
                top: BorderSide(color: color, width: stroke),
              ),
      ),
    ),
  );
}

/// ckF 温柔手账：用 painter 在内容之下绘制「渐变之上的柔和圆点」。
/// 相比把 _BlurDot( Positioned ) 放进多层 Stack：painter 永远垫在 child 之下，
/// 既向画布圆角出血、又不盖住大图/文字、也不会让内容高度塌陷（此前全白根因）。
class _SoftJournalDotsPainter extends CustomPainter {
  const _SoftJournalDotsPainter({
    required this.dot1Radius,
    required this.dot2Radius,
    required this.dot1Dx,
    required this.dot1Cy,
    required this.dot2Cx,
    required this.dot2CyBtm,
    required this.color1,
    required this.color2,
    required this.sigma,
    required this.radius,
  });

  final double dot1Radius;
  final double dot2Radius;
  final double dot1Dx;
  final double dot1Cy;
  final double dot2Cx;
  final double dot2CyBtm;
  final Color color1;
  final Color color2;
  final double sigma;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    // 按画布圆角裁切，圆点出血部分会被圆角弧自然切掉（对齐 f.html）。
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
    );
    final blur = ui.MaskFilter.blur(ui.BlurStyle.normal, sigma);
    // 右上出血圆点：圆心 (w - dot1Dx, dot1Cy)
    canvas.drawCircle(
      Offset(size.width - dot1Dx, dot1Cy),
      dot1Radius,
      Paint()
        ..color = color1
        ..maskFilter = blur,
    );
    // 左下出血圆点：圆心 (dot2Cx, h - dot2CyBtm)
    canvas.drawCircle(
      Offset(dot2Cx, size.height - dot2CyBtm),
      dot2Radius,
      Paint()
        ..color = color2
        ..maskFilter = blur,
    );
  }

  @override
  bool shouldRepaint(_SoftJournalDotsPainter o) =>
      o.dot1Radius != dot1Radius ||
      o.dot2Radius != dot2Radius ||
      o.color1 != color1 ||
      o.color2 != color2 ||
      o.sigma != sigma;
}

/// 虚线描边（f2 的「+ 更多」格）。
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.width,
    required this.dash,
    required this.gap,
  });

  final Color color;
  final double width;
  final double dash;
  final double gap;

  void _dashLine(Canvas canvas, Offset from, Offset to, Paint p) {
    final total = (to - from).distance;
    if (total <= 0) return;
    final dir = Offset((to.dx - from.dx) / total, (to.dy - from.dy) / total);
    var d = 0.0;
    while (d < total) {
      final len = (d + dash) > total ? total - d : dash;
      canvas.drawLine(
        Offset(from.dx + dir.dx * d, from.dy + dir.dy * d),
        Offset(from.dx + dir.dx * (d + len), from.dy + dir.dy * (d + len)),
        p,
      );
      d += dash + gap;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;
    final h = width / 2;
    final tl = Offset(h, h);
    final tr = Offset(size.width - h, h);
    final br = Offset(size.width - h, size.height - h);
    final bl = Offset(h, size.height - h);
    _dashLine(canvas, tl, tr, p);
    _dashLine(canvas, tr, br, p);
    _dashLine(canvas, br, bl, p);
    _dashLine(canvas, bl, tl, p);
  }

  @override
  bool shouldRepaint(_DashedBorderPainter o) =>
      o.color != color || o.width != width || o.dash != dash || o.gap != gap;
}

// =====================================================================
// 温柔手帐 ckF —— poster_mockup_checkin_f.html
// 微渐变底 + 光晕圆点 + 大圆角 + 玻璃拟态胶囊
// =====================================================================
Widget _buildSoftJournal(PosterStyleData d) {
  const dw = 520.0;
  double px(double v) => _px(v, dw);
  double fs(double v) => _fs(v, dw);

  const bg1 = Color(0xFFFFF9F2); // 燕麦奶油
  const bg2 = Color(0xFFFFF3F1); // 晨曦粉
  const glass = Color(0xC7FFFFFF); // rgba(255,255,255,.78)
  const roseDeep = Color(0xFFD9958D);
  const ink = Color(0xFF5B4A44);
  const ink2 = Color(0xFF9A867E);
  const star = Color(0xFFF5B85A);

  final padH = px(30);
  final inner = _kCkW - padH * 2;
  final mainH = px(330);
  final thumbs = d.thumbBuilders ?? const <Widget Function(double, double)>[];
  final gap = px(10);
  final tw = thumbs.isEmpty
      ? 0.0
      : (inner - gap * (thumbs.length - 1)) / thumbs.length;

  return SizedBox(
    width: _kCkW,
    child: Container(
      // 内边距已下移到 CustomPaint 内的 Padding（圆点 painter 相对整幅画布定位）
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        // 设计稿 linear-gradient(160deg, ...)
        gradient: const LinearGradient(
          begin: Alignment(-0.342, -0.94),
          end: Alignment(0.342, 0.94),
          colors: [bg1, bg2],
        ),
        borderRadius: BorderRadius.circular(px(34)),
      ),
      child: CustomPaint(
        // 圆点用 painter 垫在内容之下绘制：既能向画布圆角出血，又绝不盖住大图/
        // 文字，也不会让内容高度塌陷。此前用多层「背景 Stack」反而导致整页全白。
        painter: _SoftJournalDotsPainter(
          dot1Radius: px(110),
          dot2Radius: px(90),
          dot1Dx: px(60),
          dot1Cy: px(50),
          dot2Cx: px(30),
          dot2CyBtm: px(20),
          color1: const Color(0xFFFBE3DF),
          color2: const Color(0xFFF4EEE0),
          sigma: px(6),
          radius: px(34),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(padH, px(32), padH, px(26)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 品牌行：如画 · LUMIRA / 探店足迹胶囊
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '如画 · LUMIRA',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: posterPlain(
                        fs(12),
                        color: roseDeep,
                        weight: FontWeight.w600,
                        letterSpacing: px(1),
                      ),
                    ),
                  ),
                  SizedBox(width: px(10)),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: px(14), vertical: px(6)),
                    decoration: BoxDecoration(
                      color: glass,
                      borderRadius: BorderRadius.circular(1000),
                    ),
                    child: Text('探店足迹', style: posterPlain(fs(12), color: ink)),
                  ),
                ],
              ),
              SizedBox(height: px(20)),
              // 主图 + 左下玻璃评分胶囊
              Stack(
                children: [
                  _photo(d.photoBuilder, inner, mainH, px(26)),
                  if (d.rating > 0)
                    Positioned(
                      left: px(16),
                      bottom: px(16),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: px(14), vertical: px(6)),
                        decoration: BoxDecoration(
                          color: const Color(0xD9FFFFFF),
                          borderRadius: BorderRadius.circular(1000),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('★', style: posterPlain(fs(16), color: star)),
                            SizedBox(width: px(6)),
                            Text(
                              d.rating.toStringAsFixed(1),
                              style: posterPlain(
                                fs(16),
                                color: ink,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: px(18)),
              // 店名 + 地址小字
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: d.title,
                      style: posterPlain(
                        fs(26),
                        color: ink,
                        weight: FontWeight.w700,
                        letterSpacing: px(0.5),
                      ),
                    ),
                    if (d.place.isNotEmpty)
                      TextSpan(
                        text: '  ${d.place}',
                        style: posterPlain(
                          fs(13),
                          color: ink2,
                          weight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: px(12)),
              // 玻璃胶囊信息行：日期 / 分类 / 星级
              Wrap(
                spacing: px(10),
                runSpacing: px(6),
                children: [
                  if (d.dateText.isNotEmpty)
                    _glassPill(
                        px: px, size: fs(12), text: d.dateText, color: ink),
                  if (d.category.isNotEmpty)
                    _glassPill(
                        px: px,
                        size: fs(12),
                        text: d.category,
                        color: roseDeep),
                  if (d.rating > 0)
                    _glassPill(
                        px: px,
                        size: fs(12),
                        text: _starsText(d.rating),
                        color: star),
                ],
              ),
              if (d.note.isNotEmpty) ...[
                SizedBox(height: px(16)),
                // 心得玻璃卡
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                      horizontal: px(18), vertical: px(14)),
                  decoration: BoxDecoration(
                    color: glass,
                    borderRadius: BorderRadius.circular(px(20)),
                    border: Border.all(
                        color: const Color(0xE6FFFFFF), width: px(1)),
                  ),
                  child: Text(
                    d.note,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: posterPlain(fs(14), color: ink2, height: 1.9),
                  ),
                ),
              ],
              if (thumbs.isNotEmpty) ...[
                SizedBox(height: px(16)),
                _thumbRow(
                  gap: gap,
                  cells: [
                    for (final t in thumbs) _photo(t, tw, px(96), px(16)),
                  ],
                ),
              ],
              SizedBox(height: px(18)),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '如画 LUMIRA · 探店足迹',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: posterPlain(fs(11),
                          color: ink2, letterSpacing: px(1)),
                    ),
                  ),
                  Text(
                    '每一帧都是心动',
                    style: posterPlain(
                      fs(11),
                      color: roseDeep,
                      weight: FontWeight.w600,
                      letterSpacing: px(1),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _glassPill({
  required double Function(double) px,
  required double size,
  required String text,
  required Color color,
  Color bg = const Color(0xC7FFFFFF),
}) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: px(12), vertical: px(5)),
    decoration:
        BoxDecoration(color: bg, borderRadius: BorderRadius.circular(1000)),
    child: Text(text, style: posterPlain(size, color: color)),
  );
}

// =====================================================================
// 奶油莫兰迪 ckF2 —— poster_mockup_checkin_f2.html
// 燕麦奶油底 + 衬线克制排版 + 细线卡纸框 + 陶土色 L 角标
// =====================================================================
Widget _buildMorandi(PosterStyleData d) {
  const dw = 520.0;
  double px(double v) => _px(v, dw);
  double fs(double v) => _fs(v, dw);

  const bg = Color(0xFFF6F1E9);
  const card = Color(0xFFFBF7EF);
  const taupe = Color(0xFFB8A69B);
  const clay = Color(0xFFC98F78);
  const ink = Color(0xFF4A4039);
  const ink2 = Color(0xFF8A7E73);
  const line = Color(0x59A8B5A0); // rgba(168,181,160,.35)

  final padH = px(44);
  final framePad = px(20);
  // 细线卡纸框带 1px 描边（左右各 1px 共 2px），须从可用宽度中扣减，
  // 否则下方缩略图 Row 会向右溢出约 2×px(1)（渲染成 debug 黄色条纹）。
  final inner = _kCkW - padH * 2 - framePad * 2 - px(2);
  final mainH = px(360);
  final thumbs = d.thumbBuilders ?? const <Widget Function(double, double)>[];
  final gap = px(12);
  // 设计稿为「3 张小图 + 一个 + 号格」，共 4 格。
  final imgCount =
      thumbs.isEmpty ? 0 : (thumbs.length >= 3 ? 3 : thumbs.length);
  final cellCount = thumbs.isEmpty ? 0 : imgCount + 1;
  final cw = cellCount == 0 ? 0.0 : (inner - gap * (cellCount - 1)) / cellCount;

  return SizedBox(
    width: _kCkW,
    child: Container(
      color: bg,
      padding: EdgeInsets.fromLTRB(padH, px(40), padH, px(30)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 细线卡纸框 + 陶土色 L 角标
          Container(
            decoration:
                BoxDecoration(border: Border.all(color: line, width: px(1))),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding:
                      EdgeInsets.fromLTRB(framePad, px(26), framePad, px(20)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 眉题
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(width: px(24), height: px(1), color: clay),
                          SizedBox(width: px(10)),
                          Flexible(
                            child: Text(
                              'STORE EXPLORATION · 探店足迹',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: posterSerif(
                                fs(11),
                                color: taupe,
                                letterSpacing: px(5),
                                weight: FontWeight.w500,
                              ),
                            ),
                          ),
                          SizedBox(width: px(10)),
                          Container(width: px(24), height: px(1), color: clay),
                        ],
                      ),
                      SizedBox(height: px(14)),
                      // 店名
                      Text(
                        d.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: posterSerif(
                          fs(34),
                          color: ink,
                          letterSpacing: px(4),
                          weight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: px(14)),
                      // meta：地点 · 日期 · 分类
                      _separatedMeta(d,
                          size: fs(12),
                          gapPx: px(2),
                          color: ink2,
                          sepColor: clay),
                      SizedBox(height: px(26)),
                      // 主图
                      _photo(d.photoBuilder, inner, mainH, px(2)),
                      SizedBox(height: px(22)),
                      // 评分：★★★★★ 5.0 / 5
                      if (d.rating > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _starsText(d.rating),
                              style: posterSerif(fs(15),
                                  color: clay, letterSpacing: px(2)),
                            ),
                            SizedBox(width: px(8)),
                            Text(
                              d.rating.toStringAsFixed(1),
                              style: posterSerif(
                                fs(30),
                                color: clay,
                                letterSpacing: px(2),
                                weight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '/ 5',
                              style: posterSerif(fs(12),
                                  color: clay, letterSpacing: px(2)),
                            ),
                          ],
                        ),
                      if (d.note.isNotEmpty) ...[
                        SizedBox(height: px(18)),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                              horizontal: px(10), vertical: px(14)),
                          child: Text(
                            d.note,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: posterSerif(fs(14), color: ink2, height: 2)
                                .copyWith(fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                      if (thumbs.isNotEmpty) ...[
                        SizedBox(height: px(24)),
                        _thumbRow(
                          gap: gap,
                          cells: [
                            for (var i = 0; i < imgCount; i++)
                              _photo(thumbs[i], cw, px(100), px(2)),
                            if (imgCount < cellCount)
                              Stack(
                                children: [
                                  Container(
                                    width: cw,
                                    height: px(100),
                                    color: card,
                                  ),
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _DashedBorderPainter(
                                        color: line,
                                        width: px(1),
                                        dash: px(4),
                                        gap: px(3),
                                      ),
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: Center(
                                      child: Text(
                                        '+',
                                        style:
                                            posterSerif(fs(26), color: taupe),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  top: -px(1),
                  left: -px(1),
                  child: _bracket(
                    size: px(16),
                    stroke: px(2),
                    color: clay,
                    lower: false,
                  ),
                ),
                Positioned(
                  bottom: -px(1),
                  right: -px(1),
                  child: _bracket(
                    size: px(16),
                    stroke: px(2),
                    color: clay,
                    lower: true,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: px(26)),
          // 页脚
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '如画',
                        style: posterPlain(
                          fs(11),
                          color: clay,
                          weight: FontWeight.w600,
                          letterSpacing: px(2),
                        ),
                      ),
                      TextSpan(
                        text: ' LUMIRA',
                        style: posterPlain(fs(11),
                            color: taupe, letterSpacing: px(2)),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: px(8)),
              Text(
                'LUMIRA · 探店足迹',
                style: posterPlain(fs(10), color: ink2, letterSpacing: px(1)),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// 「地点 · 日期 · 分类」串联 meta（分隔符用点缀色）。
///
/// [includeDate] 为 false 时只串地点与分类（v2 版式日期单独成行）。
Widget _separatedMeta(
  PosterStyleData d, {
  required double size,
  required double gapPx,
  required Color color,
  required Color sepColor,
  bool includeDate = true,
}) {
  final segs = <String>[
    if (d.place.isNotEmpty) d.place,
    if (includeDate && d.dateText.isNotEmpty) d.dateText,
    if (d.category.isNotEmpty) d.category,
  ];
  if (segs.isEmpty) return const SizedBox.shrink();
  final base = posterPlain(size, color: color, letterSpacing: gapPx);
  final spans = <TextSpan>[];
  for (var i = 0; i < segs.length; i++) {
    if (i > 0) {
      spans.add(TextSpan(text: '·', style: base.copyWith(color: sepColor)));
    }
    spans.add(TextSpan(text: segs[i]));
  }
  return Text.rich(
    TextSpan(children: spans, style: base),
    textAlign: TextAlign.center,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
  );
}

// =====================================================================
// 鎏金画框 ckV2 —— poster_mockup_checkin_v2.html
// 金色双线外框 + 印章 + 缺角大图 + 四图拼条 + 上下金线信息卡
// =====================================================================
Widget _buildGoldFrame(PosterStyleData d) {
  const dw = 540.0;
  double px(double v) => _px(v, dw);
  double fs(double v) => _fs(v, dw);

  const paper = Color(0xFFFDFBF7);
  const gold = Color(0xFFC9A96E);
  const goldDark = Color(0xFFB08D4F);
  const ink = Color(0xFF3A3A37);
  const ink2 = Color(0xFF6E6A60);
  const ink3 = Color(0xFF8C877B);
  const line = Color(0x73B99E6C); // rgba(185,158,108,.45)
  const lineSoft = Color(0x47B99E6C); // rgba(185,158,108,.28)

  final padH = px(36);
  final contentW = px(440);
  final mainH = px(300);
  final thumbs = d.thumbBuilders ?? const <Widget Function(double, double)>[];
  final bandGap = px(9);
  final bandW = thumbs.isEmpty
      ? 0.0
      : (contentW - bandGap * (thumbs.length - 1)) / thumbs.length;

  return SizedBox(
    width: _kCkW,
    child: Container(
      color: paper,
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(padH, px(30), padH, px(26)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: px(22)),
                // 印章
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: px(16), vertical: px(3)),
                  decoration: BoxDecoration(
                    border: Border.all(color: gold, width: px(1)),
                    borderRadius: BorderRadius.circular(1000),
                  ),
                  child: Text(
                    '探 店 足 迹',
                    style: posterSerif(fs(12),
                        color: goldDark, letterSpacing: px(4)),
                  ),
                ),
                SizedBox(height: px(14)),
                Text(
                  d.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: posterSerif(
                    fs(42),
                    color: ink,
                    letterSpacing: px(4),
                    height: 1.1,
                  ),
                ),
                SizedBox(height: px(10)),
                // v2.html：meta 行只放地点（衬线、金色中文字距），分类仅在下方信息卡 cat-tag。
                if (d.place.isNotEmpty)
                  Text(
                    d.place,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: posterSerif(
                      fs(14),
                      color: ink2,
                      letterSpacing: px(2),
                      weight: FontWeight.w500,
                    ),
                  ),
                if (d.dateText.isNotEmpty) ...[
                  SizedBox(height: px(6)),
                  Text(
                    d.dateText,
                    style:
                        posterSerif(fs(11), color: ink3, letterSpacing: px(3)),
                  ),
                ],
                SizedBox(height: px(22)),
                // 大图（缺角相框 + 金色 L 角标）
                GoldNotchedFrame(
                  notchPx: px(26),
                  cornerLen: px(18),
                  cornerStroke: px(3),
                  cornerColor: gold,
                  child: SizedBox(
                    width: contentW,
                    height: mainH,
                    child: d.photoBuilder(contentW, mainH),
                  ),
                ),
                if (thumbs.isNotEmpty) ...[
                  SizedBox(height: px(14)),
                  Center(
                    child: _thumbRow(
                      gap: bandGap,
                      cells: [
                        for (final t in thumbs)
                          GoldNotchedFrame(
                            notchPx: px(18),
                            cornerLen: px(13),
                            cornerStroke: px(1.6),
                            cornerColor: gold,
                            child: SizedBox(
                              width: bandW,
                              height: px(96),
                              child: t(bandW, px(96)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: px(22)),
                // 信息卡：上下金线
                Container(
                  width: contentW,
                  padding: EdgeInsets.symmetric(vertical: px(16)),
                  decoration: BoxDecoration(
                    // 只保留上方金线分隔，去掉底边——底边正好横在心得文字下方，
                    // 呈现为讨厌的「文字下方黄色横线」。
                    border: Border(
                      top: BorderSide(color: line, width: px(1)),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (d.rating > 0) ...[
                            Text(
                              _starsText(d.rating),
                              style: posterPlain(fs(17),
                                  color: gold, letterSpacing: px(2)),
                            ),
                            SizedBox(width: px(8)),
                            Text(
                              d.rating.toStringAsFixed(1),
                              style: posterSerif(
                                fs(18),
                                color: goldDark,
                                letterSpacing: px(1),
                              ),
                            ),
                          ],
                          if (d.category.isNotEmpty) ...[
                            SizedBox(width: px(12)),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: px(13),
                                vertical: px(2),
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: gold, width: px(1)),
                                borderRadius: BorderRadius.circular(1000),
                              ),
                              child: Text(
                                d.category,
                                style: posterSerif(
                                  fs(12),
                                  color: goldDark,
                                  letterSpacing: px(2),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (d.note.isNotEmpty) ...[
                        SizedBox(height: px(16)),
                        SizedBox(
                          width: px(400),
                          child: Text(
                            d.note,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: posterSerif(fs(14), color: ink2, height: 2)
                                .copyWith(fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: px(18)),
                // 页脚
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(top: px(18)),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: line, width: px(1))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '如 画 · LUMIRA',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: posterSerif(fs(12),
                              color: goldDark, letterSpacing: px(3)),
                        ),
                      ),
                      Flexible(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '探 店 足 迹 ',
                                style: posterSerif(
                                  fs(12),
                                  color: goldDark,
                                  letterSpacing: px(3),
                                ),
                              ),
                              TextSpan(
                                text: 'LUMIRA',
                                style: posterSerif(
                                  fs(10),
                                  color: ink3,
                                  letterSpacing: px(1),
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 金色双线外框
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(px(14)),
              child: Container(
                decoration: BoxDecoration(
                    border: Border.all(color: line, width: px(1))),
                child: Padding(
                  padding: EdgeInsets.all(px(3)),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: lineSoft, width: px(1)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 右上/左下金角标
          Positioned(
            top: px(6),
            left: px(6),
            child: _bracket(
                size: px(30), stroke: px(3), color: goldDark, lower: false),
          ),
          Positioned(
            bottom: px(6),
            right: px(6),
            child: _bracket(
                size: px(30), stroke: px(3), color: goldDark, lower: true),
          ),
        ],
      ),
    ),
  );
}

// =====================================================================
// 错落画廊 ckM4 —— poster_mockup_checkin_m4.html
// 左大图 + 右信息列 + 下方四格错落 + 细金内框
// =====================================================================
Widget _buildAsymmetric(PosterStyleData d) {
  const dw = 520.0;
  double px(double v) => _px(v, dw);
  double fs(double v) => _fs(v, dw);

  const surface = Color(0xFFFDFBF7);
  const brand = Color(0xFFC9A96E);
  const brandDeep = Color(0xFFA88550);
  const ink = Color(0xFF1A1A1A);
  const ink2 = Color(0xFF5C5852);
  const ink3 = Color(0xFFA29A8A);
  const hair = Color(0x61A88550); // rgba(168,133,80,.38)

  final padH = px(34);
  final inner = _kCkW - padH * 2;
  final heroGap = px(22);
  final leftW = (inner - heroGap) * 1.35 / 2.35;
  final rightW = inner - heroGap - leftW;
  final bigH = px(300);
  final thumbs = d.thumbBuilders ?? const <Widget Function(double, double)>[];
  final gGap = px(10);
  // 设计稿为「3 张小图 + 一个『＋更多』格」，共 4 格。
  final gImg = thumbs.isEmpty ? 0 : (thumbs.length >= 3 ? 3 : thumbs.length);
  final gCount = thumbs.isEmpty ? 0 : gImg + 1;
  final gOff = [px(26), 0.0, px(14), px(6)];
  final gW = gCount == 0 ? 0.0 : (inner - gGap * (gCount - 1)) / gCount;

  return SizedBox(
    width: _kCkW,
    child: Container(
      color: surface,
      child: Stack(
        children: [
          // 细金内框（对应 m4.html outline-offset:-12px）：距画布外缘 12px，
          // 位于内容留白之内、正文（从 34px 起排）之外，不与正文重叠。
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(px(12)),
              child: Container(
                decoration: BoxDecoration(
                    border: Border.all(color: hair, width: px(1))),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(padH, px(32), padH, px(28)),
            child: ConstrainedBox(
              // m4.html 画布 min-height:820（随 520 宽等比缩放），保证底部留白
              constraints: BoxConstraints(minHeight: px(820)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 上排：左大图 + 右信息列
                  SizedBox(
                    height: bigH,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: leftW,
                          child: Stack(
                            children: [
                              d.photoBuilder(leftW, bigH),
                              Positioned(
                                top: 0,
                                left: 0,
                                child: _bracket(
                                  size: px(16),
                                  stroke: px(1),
                                  color: brandDeep,
                                  lower: false,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: heroGap),
                        SizedBox(
                          width: rightW,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 顶部信息组：眉题 + 短线菱形 + 店名（对齐 m4.html 靠上排版）
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'STORE DIARY · NO.001',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: posterSerif(fs(9),
                                        color: ink3,
                                        letterSpacing: px(4),
                                        weight: FontWeight.w400),
                                  ),
                                  // 金色短线 + 菱形
                                  SizedBox(
                                    height: px(8),
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Positioned(
                                          left: px(3.5),
                                          top: px(3.5),
                                          child: Container(
                                              width: px(34),
                                              height: px(1),
                                              color: brand),
                                        ),
                                        Positioned(
                                          left: 0,
                                          top: 0,
                                          child: Transform.rotate(
                                            angle: math.pi / 4,
                                            child: Container(
                                              width: px(7),
                                              height: px(7),
                                              decoration: BoxDecoration(
                                                color: surface,
                                                border: Border.all(
                                                    color: brand, width: px(1)),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: px(16)),
                                  Text(
                                    d.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: posterSerif(
                                      fs(40),
                                      color: ink,
                                      letterSpacing: px(7),
                                      height: 1.15,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              // 底部信息组：评分 + 地址/日期 + 分类标签（spaceBetween 沉到底部）
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (d.rating > 0) ...[
                                    Text(
                                      _starsText(d.rating),
                                      style: posterSerif(
                                        fs(13),
                                        color: brand,
                                        letterSpacing: px(2),
                                        weight: FontWeight.w400,
                                      ),
                                    ),
                                    SizedBox(height: px(2)),
                                    Text(
                                      d.rating.toStringAsFixed(1),
                                      style: posterSerif(
                                        fs(24),
                                        color: brandDeep,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  if (d.place.isNotEmpty ||
                                      d.dateText.isNotEmpty) ...[
                                    SizedBox(height: px(14)),
                                    Text(
                                      [
                                        if (d.place.isNotEmpty) d.place,
                                        if (d.dateText.isNotEmpty) d.dateText,
                                      ].join('\n'),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: posterSerif(
                                        fs(11),
                                        color: ink2,
                                        letterSpacing: px(1),
                                        height: 1.9,
                                        weight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                  if (d.category.isNotEmpty) ...[
                                    SizedBox(height: px(6)),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: px(12),
                                        vertical: px(2),
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: brand, width: px(1)),
                                      ),
                                      child: Text(
                                        d.category,
                                        style: posterSerif(
                                          fs(10),
                                          color: brandDeep,
                                          letterSpacing: px(3),
                                          weight: FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (thumbs.isNotEmpty) ...[
                    SizedBox(height: px(22)),
                    // 下排：错落四格
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < gCount; i++) ...[
                          if (i > 0) SizedBox(width: gGap),
                          Padding(
                            padding: EdgeInsets.only(top: gOff[i % 4]),
                            child: i < gImg
                                ? Stack(
                                    children: [
                                      SizedBox(
                                        width: gW,
                                        height: px(120),
                                        child: thumbs[i](gW, px(120)),
                                      ),
                                      Positioned(
                                        top: 0,
                                        left: 0,
                                        child: _bracket(
                                          size: px(12),
                                          stroke: px(1),
                                          color: brandDeep,
                                          lower: false,
                                        ),
                                      ),
                                    ],
                                  )
                                : Container(
                                    width: gW,
                                    height: px(120),
                                    decoration: BoxDecoration(
                                      color: surface,
                                      border: Border.all(
                                          color: brand, width: px(1)),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '＋',
                                          style: posterSerif(
                                            fs(24),
                                            color: brandDeep,
                                            weight: FontWeight.w400,
                                          ),
                                        ),
                                        SizedBox(height: px(2)),
                                        Text(
                                          '更多',
                                          style: posterSerif(
                                            fs(11),
                                            color: brandDeep,
                                            letterSpacing: px(2),
                                            weight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  if (d.note.isNotEmpty) ...[
                    SizedBox(height: px(24)),
                    // 心得块：上下金色发丝线包裹斜体文案（对齐 m4.html .note）
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: px(2), vertical: px(14)),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: hair, width: px(1)),
                          bottom: BorderSide(color: hair, width: px(1)),
                        ),
                      ),
                      child: Text(
                        d.note,
                        textAlign: TextAlign.justify,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: posterSerif(fs(13),
                                color: ink2,
                                height: 2.1,
                                weight: FontWeight.w400)
                            .copyWith(fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                  SizedBox(height: px(22)),
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '如画 · 探店足迹 ',
                                style: posterSerif(
                                  fs(11),
                                  color: brandDeep,
                                  letterSpacing: px(4),
                                  weight: FontWeight.w400,
                                ),
                              ),
                              TextSpan(
                                text: 'LUMIRA',
                                style: posterSerif(
                                  fs(9),
                                  color: ink3,
                                  letterSpacing: px(2),
                                  weight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'LUMIRA · 如画',
                        style: posterSerif(fs(10),
                            color: ink3,
                            letterSpacing: px(3),
                            weight: FontWeight.w400),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
