import 'package:flutter/material.dart';

import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/poster/poster_common.dart';
import 'checkin_common.dart';

/// 把某张探店照片按给定宽高以 cover 渲染；空 url 或加载失败显示占位。
Widget checkinPhoto({
  required String url,
  required ThemeTokens tokens,
  required double width,
  required double height,
  double radius = 0,
}) {
  return SizedBox(
    width: width,
    height: height,
    child: CheckinPhotoImage(
      url: url,
      tokens: tokens,
      width: width,
      height: height,
      fit: BoxFit.cover,
      borderRadius: radius > 0 ? radius : null,
    ),
  );
}

/// 金色评分星行（rating <= 0 不渲染）。
class PosterRatingRow extends StatelessWidget {
  const PosterRatingRow({super.key, required this.rating, this.size = 14});
  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (rating <= 0) return const SizedBox.shrink();
    final filled = rating.round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${rating.toStringAsFixed(1)}',
          style: posterSerifEn(size + 2, color: PosterPalette.goldDeep),
        ),
        const SizedBox(width: 6),
        ...List.generate(5, (i) {
          return Icon(
            i < filled ? Icons.star : Icons.star_border,
            size: size,
            color: i < filled ? PosterPalette.gold : PosterPalette.line,
          );
        }),
      ],
    );
  }
}

/// 图标 + 单行 meta 文本（地点 / 日期）。
class PosterMetaLine extends StatelessWidget {
  const PosterMetaLine({
    super.key,
    required this.icon,
    required this.text,
    this.color = PosterPalette.text2,
    this.size = 11,
  });
  final IconData icon;
  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: size + 1, color: PosterPalette.goldDeep),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: posterPlain(size, color: color),
          ),
        ),
      ],
    );
  }
}

/// 金色细分隔线。
class PosterHairline extends StatelessWidget {
  const PosterHairline({super.key, this.color = PosterPalette.line});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(height: 1, color: color);
}

/// 缺角相框：四角切角 + 左上/右下金色 L 角标，内嵌 [child]。
class GoldNotchedFrame extends StatelessWidget {
  const GoldNotchedFrame({super.key, required this.child, this.notch = 0.28});
  final Widget child;
  final double notch; // 切角相对短边比例

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _NotchedFramePainter(notch: notch),
      child: Stack(
        children: [
          child,
          const Positioned(top: 0, left: 0, child: _LCorner(false)),
          const Positioned(bottom: 0, right: 0, child: _LCorner(true)),
        ],
      ),
    );
  }
}

class _LCorner extends StatelessWidget {
  const _LCorner(this.lower, {Key? key}) : super(key: key);
  final bool lower;
  @override
  Widget build(BuildContext context) {
    const stroke = 2.5;
    const len = 18.0;
    final g = PosterPalette.goldDeep;
    return SizedBox(
      width: len,
      height: len,
      child: CustomPaint(
        painter: _LMarkerPainter(lower: lower, stroke: stroke, len: len, color: g),
      ),
    );
  }
}

class _LMarkerPainter extends CustomPainter {
  const _LMarkerPainter({
    required this.lower,
    required this.stroke,
    required this.len,
    required this.color,
  });
  final bool lower;
  final double stroke;
  final double len;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    if (!lower) {
      // 左上 L：横线延右，竖线延下
      canvas.drawLine(Offset(0, 0), Offset(len, 0), p);
      canvas.drawLine(Offset(0, 0), Offset(0, len), p);
    } else {
      // 右下 L
      canvas.drawLine(Offset(0, len), Offset(len, len), p);
      canvas.drawLine(Offset(len, len), Offset(len, 0), p);
    }
  }

  @override
  bool shouldRepaint(_LMarkerPainter o) =>
      o.lower != lower || o.stroke != stroke || o.len != len || o.color != color;
}

class _NotchedFramePainter extends CustomPainter {
  const _NotchedFramePainter({required this.notch});
  final double notch;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final n = (w < h ? w : h) * notch;
    final path = Path()
      ..moveTo(n, 0)
      ..lineTo(w, 0)
      ..lineTo(w, n)
      ..lineTo(w, h)
      ..lineTo(w - n, h)
      ..lineTo(0, h)
      ..lineTo(0, h - n)
      ..lineTo(0, 0)
      ..close();
    canvas.clipPath(path);
  }

  @override
  bool shouldRepaint(_NotchedFramePainter o) => o.notch != notch;
}

/// 印章（红色圆章，用于金字招牌样式）。
class PosterStamp extends StatelessWidget {
  const PosterStamp({super.key, this.label = '打卡', this.size = 46});
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    const c = Color(0xFFB04532);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c, width: 2),
      ),
      child: Transform.rotate(
        angle: -0.12,
        child: Text(
          label,
          style: TextStyle(
            color: c,
            fontSize: size * 0.26,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

/// 底部品牌水印。
class PosterWatermark extends StatelessWidget {
  const PosterWatermark({super.key});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const PosterLogo(size: 13),
        const SizedBox(width: 6),
        Text('如画 LUMIRA', style: posterSerifEn(10, color: PosterPalette.goldDeep, letterSpacing: 3)),
        const SizedBox(width: 5),
        Text('· 探店足迹', style: posterPlain(10, color: PosterPalette.text3)),
      ],
    );
  }
}

/// 顶部品牌小标（浅色底）。
class CheckinBrandTag extends StatelessWidget {
  const CheckinBrandTag({super.key});
  @override
  Widget build(BuildContext context) {
    return const PosterBrandRow(logoSize: 14);
  }
}
