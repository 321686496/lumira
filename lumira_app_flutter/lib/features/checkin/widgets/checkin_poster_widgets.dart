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

/// 缺角相框：左上/右下切角 + 金色 L 角标，内嵌 [child]。
class GoldNotchedFrame extends StatelessWidget {
  const GoldNotchedFrame({
    super.key,
    required this.child,
    this.notch = 0.28,
    this.notchPx,
    this.cornerLen,
    this.cornerStroke = 2.5,
    this.cornerColor,
    this.showCorners = true,
  });

  final Widget child;

  /// 切角相对短边比例（[notchPx] 为空时生效）。
  final double notch;

  /// 切角绝对边长（逻辑 px），优先于 [notch]。
  final double? notchPx;

  /// L 角标边长（缺省 18）。
  final double? cornerLen;

  /// L 角标线宽（缺省 2.5）。
  final double cornerStroke;

  /// L 角标颜色（缺省 [PosterPalette.goldDeep]）。
  final Color? cornerColor;

  /// 是否绘制角标（部分版式只需切角）。
  final bool showCorners;

  @override
  Widget build(BuildContext context) {
    final len = cornerLen ?? 18.0;
    final color = cornerColor ?? PosterPalette.goldDeep;
    return ClipPath(
      // 用 ClipPath 裁掉左上/右下缺角，才能真正切开 child（照片）。
      // 旧实现用 CustomPaint 的 canvas.clipPath 只裁剪 painter 自身图层，无法裁剪 child。
      clipper: _NotchedClipper(notch: notch, notchPx: notchPx),
      child: Stack(
        children: [
          child,
          if (showCorners) ...[
            Positioned(
              top: 0,
              left: 0,
              child: _LCorner(false, len: len, stroke: cornerStroke, color: color),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: _LCorner(true, len: len, stroke: cornerStroke, color: color),
            ),
          ],
        ],
      ),
    );
  }
}

class _LCorner extends StatelessWidget {
  const _LCorner(
    this.lower, {
    required this.len,
    required this.stroke,
    required this.color,
  });
  final bool lower;
  final double len;
  final double stroke;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: len,
      height: len,
      child: CustomPaint(
        painter: _LMarkerPainter(lower: lower, stroke: stroke, len: len, color: color),
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

/// 缺角裁剪器：仅裁左上角与右下角（对齐 v2.html/m4.html 的
/// `clip-path: polygon(...)`，右上/左下为直角）。
class _NotchedClipper extends CustomClipper<Path> {
  const _NotchedClipper({required this.notch, this.notchPx});
  final double notch;
  final double? notchPx;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final n = notchPx ?? (w < h ? w : h) * notch;
    return Path()
      ..moveTo(n, 0) // 左上：顶边从此 x 开始，左角被切
      ..lineTo(w, 0) // 顶边 → 右上直角
      ..lineTo(w, h - n) // 右边下行，到右下缺角上点
      ..lineTo(w - n, h) // 右下缺角斜切
      ..lineTo(0, h) // 底边 → 左下直角
      ..lineTo(0, n) // 左边上行，到左上缺角下点
      ..close();
  }

  @override
  bool shouldReclip(_NotchedClipper o) =>
      o.notch != notch || o.notchPx != notchPx;
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
