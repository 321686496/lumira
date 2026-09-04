import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/theme_tokens.dart';

/// 新拟态「凹陷表面」的可复用组件。
///
/// 复现 CSS `box-shadow: inset 4px 4px 9px var(--shadow-dk), inset -4px -4px 9px
/// var(--shadow-lt)` 的内凹观感：**上边 + 左边**内边缘压暗、**下边 + 右边**内边缘
/// 泛白高光、中心保持平底，四个圆角自然过渡。
///
/// 实现要点（这是「上下左右自然过渡」的关键，也是先前版本"四边都糊、互相脏在一起"
/// 的修复）：**绝不把一条闭合描边整体平移**——那种做法会让暗/亮影同时糊满四条边的
/// 内侧，导致每个角都叠加成花花一片。而是把圆角轮廓**按光源方向拆成两段半轮廓**：
/// - 暗影只在「上边 + 左上圆角 + 左边」这一半留下（用负数 sweep 让圆角朝内收）；
/// - 亮影只在「下边 + 右下圆角 + 右边」这一半留下。
/// 两段各自用 `MaskFilter.blur` 高斯模糊成柔边 + 裁进圆角矩形内部，暗/亮的模糊尾巴
/// 在对面两角（右上/左下）自然淡出，中心始终是平底 surface。这样既保留新拟态凹陷
/// 的「左上暗 / 右下亮」方向性光源，又不再有生硬拼接或任意一条边"抢戏"。
///
/// 之所以不用 `BoxShadow(blurStyle: BlurStyle.inner)`：本 SDK 实测把 inner 阴影当外
/// 阴影画（视觉仍是凸起），故手绘模糊内阴影。采用 [CustomPaint]（非
/// `LayoutBuilder`+`Stack`/`Positioned`）以直接沿用子组件的有限尺寸、规避无界约束下
/// `size.isFinite` 断言。所有颜色派生自当前主题、随 8 主题 × 4 风格自适应。
///
/// [depth] 控制明暗强度（0~1，越大越明显）；[rimFraction] 控制阴影内伸带占短边的
/// 比例（沟槽/轨道用较小值，芯片/按钮用较大值）。
class RecessedSurface extends StatelessWidget {
  const RecessedSurface({
    super.key,
    required this.tokens,
    required this.child,
    this.borderRadius = 16,
    this.depth = 0.7,
    this.rimFraction = 0.30,
    this.color,
    this.recessDark,
    this.recessLight,
  });

  final ThemeTokens tokens;

  /// 承载在凹陷表面之上的实际内容，同时也是尺寸来源。
  final Widget child;

  final double borderRadius;

  /// 明暗强度 0~1。
  final double depth;

  /// 内阴影沿短边的内伸量比例。
  final double rimFraction;

  /// 覆盖默认 surface 的底色（一般不用传，跟随主题）。
  final Color? color;

  /// 覆盖凹陷表面的**内影色调**（一般不用传）。
  ///
  /// 默认取自 `tokens.shadowConcave`（跟随主题的暗/亮中性影）。给品牌 CTA 传入
  /// 品牌色系（[ThemeTokens.brandRecessDark]/[brandRecessLight]）即可在金色表面
  /// 上呈现同色系的凹陷内影，而不至于用中性灰在金色上糊出脏边。
  final Color? recessDark;
  final Color? recessLight;

  @override
  Widget build(BuildContext context) {
    final surface = color ?? tokens.surface;
    final darkC = recessDark ?? tokens.shadowConcave.first.color;
    final lightC = recessLight ?? tokens.shadowConcave[1].color;
    // 半透明阴影色（而非不透明白）+ 模糊，才能得到「柔边且有结构」的 inset，
    // 且中心保持平底，不会像不透明渐变那样糊穿整块表面。
    final darkAlpha = (60 + 70 * depth).round().clamp(0, 255);
    final lightAlpha = (120 + 90 * depth).round().clamp(0, 255);
    final fill = _RecessedPainter(
      surface: surface,
      dark: Color.fromARGB(darkAlpha, darkC.red, darkC.green, darkC.blue),
      light: Color.fromARGB(lightAlpha, lightC.red, lightC.green, lightC.blue),
      borderRadius: borderRadius,
      rimFraction: rimFraction,
      drawShadows: false,
    );
    final rims = _RecessedPainter(
      surface: surface,
      dark: Color.fromARGB(darkAlpha, darkC.red, darkC.green, darkC.blue),
      light: Color.fromARGB(lightAlpha, lightC.red, lightC.green, lightC.blue),
      borderRadius: borderRadius,
      rimFraction: rimFraction,
      drawShadows: true,
    );
    // painter=背景填充面，foregroundPainter=明暗内沿描边。
    // 把描边放到前景层，是为了让凹陷在「不透明实底 child」上也清晰可见
    // （否则会被 child 的实底盖住，整块只剩一个平底、看不到内阴影）。
    return CustomPaint(
      painter: fill,
      foregroundPainter: rims,
      child: child,
    );
  }
}

class _RecessedPainter extends CustomPainter {
  _RecessedPainter({
    required this.surface,
    required this.dark,
    required this.light,
    required this.borderRadius,
    required this.rimFraction,
    required this.drawShadows,
  });

  final Color surface;
  final Color dark;
  final Color light;
  final double borderRadius;
  final double rimFraction;

  /// true=画明暗内沿描边（前景层）；false=画平底填充面（背景层）。
  final bool drawShadows;

  @override
  void paint(Canvas canvas, Size size) {
    if (!drawShadows) {
      final rect = Offset.zero & size;
      final rrect =
          RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
      canvas.drawRRect(rrect, Paint()..color = surface);
      return;
    }
    final w = size.width, h = size.height;
    // 有效圆角半径：与 RRect 的转角裁切保持一致（Flutter 会把圆角钳制到短边的一半）。
    // 关键：阴影弧线必须用「钳制后」的 rr，而不能用原始的 borderRadius——
    // 否则胶囊/大圆角（如 999、24）下弧心 (r,r) 远在裁剪区之外，整段弧被裁掉，
    // 导致「上边有暗影、左边/下边却没有」。用同一 rr 后填充面与阴影的圆角完全对齐。
    final short = math.min(w, h);
    final rr = math.max(0.0, math.min(borderRadius, short / 2));
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(rr));

    // 内伸带的期望深度：基于短边 * rimFraction，上限 ~20px（参考 CSS `inset ... 9px`，
    // 过大会把中心扯成斜坡、失去平底）。
    final reach = math.max(0.0, math.min(short * rimFraction, 20.0));

    // 方向性半轮廓只画在光源应有的边上，中心天然平底。
    final sigma = math.max(1.1, math.min(7.0, reach * 0.28)); // 模糊半径
    final stroke = math.max(2.0, reach);                       // 描边宽度 = 内伸带
    final k = math.max(1.0, math.min(5.0, reach * 0.16));      // 方向性位移
    // 中性角内收间隙：让半轮廓在「右上/左下」这两个中性角之前提前收住，配合圆头笔帽
    // 的柔化尾巴自然淡出——既保证圆角，也保证 radius=0 方角不会在四个顶点叠加脏影。
    final m = math.max(2.5, math.min(7.0, reach * 0.18));

    // 暗影：上边 + 左上圆角 + 左边。（负 sweep 让圆角从外向内部收，避免楔形扩散；
    // 右上端与左下端各自内收 m，淡出避开中性角。）
    final darkPath = Path()..moveTo(w - rr - m, 0);
    darkPath.lineTo(rr, 0);
    if (rr > 0.5) {
      darkPath.arcTo(
        Rect.fromCircle(center: Offset(rr, rr), radius: rr),
        math.pi * 1.5,
        -math.pi / 2,
        false,
      );
    } else {
      darkPath.lineTo(0, 0);
    }
    darkPath.lineTo(0, h - m);

    // 亮影：下边 + 右下圆角 + 右边。（左下端与右上端各自内收 m。）
    final lightPath = Path()..moveTo(rr + m, h);
    lightPath.lineTo(w - rr, h);
    if (rr > 0.5) {
      lightPath.arcTo(
        Rect.fromCircle(center: Offset(w - rr, h - rr), radius: rr),
        math.pi / 2,
        -math.pi / 2,
        false,
      );
    } else {
      lightPath.lineTo(w, h);
    }
    lightPath.lineTo(w, m);

    final cap = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);

    // 暗影：向内侧 (+k,+k) 位移，让它更好地「接到」上/左内边缘。
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.translate(k, k);
    canvas.drawPath(darkPath, Paint()..color = dark..strokeCap = StrokeCap.round..style = cap.style..strokeWidth = cap.strokeWidth..maskFilter = cap.maskFilter);
    canvas.restore();

    // 亮影：向内侧 (−k,−k) 位移，接到下/右内边缘。
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.translate(-k, -k);
    canvas.drawPath(lightPath, Paint()..color = light..strokeCap = StrokeCap.round..style = cap.style..strokeWidth = cap.strokeWidth..maskFilter = cap.maskFilter);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RecessedPainter oldDelegate) =>
      oldDelegate.surface != surface ||
      oldDelegate.dark != dark ||
      oldDelegate.light != light ||
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.rimFraction != rimFraction ||
      oldDelegate.drawShadows != drawShadows;
}