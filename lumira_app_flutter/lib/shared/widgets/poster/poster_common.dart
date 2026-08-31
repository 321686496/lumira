import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../brand/lumira_logo.dart';
import 'poster_ratio.dart';

/// 分享海报固定品牌色板。
///
/// 分享海报为导出类品牌资产，固定 LUMIRA 原生风格色板，**不随 App 主题/UI 风格切换**
/// （对「样式跟随主题」铁律的唯一例外，属用户明确要求）。
class PosterPalette {
  PosterPalette._();

  static const Color surface = Color(0xFFFDFBF7);
  static const Color surfaceAlt = Color(0xFFF6F1E8);
  static const Color gold = Color(0xFFC9A96E);
  static const Color goldDeep = Color(0xFFB08D4F);
  static const Color goldSoft = Color(0xFFE8CFA4);
  static const Color ink = Color(0xFF1A1A1A);
  static const Color text2 = Color(0xFF6B645C);
  static const Color text3 = Color(0xFF8E867B);
  static const Color line = Color(0x52C9A96E); // rgba(201,169,110,.32)
}

/// 海报画布：固定宽度 + 品牌底色 + 金色细边 + 圆角裁切。
class PosterCanvas extends StatelessWidget {
  const PosterCanvas({
    super.key,
    required this.width,
    this.height,
    this.color = PosterPalette.surface,
    this.padding,
    this.borderColor = PosterPalette.line,
    this.borderRadius = 20,
    this.child,
  });

  final double width;
  final double? height;
  final Color color;
  final EdgeInsetsGeometry? padding;
  final Color borderColor;
  final double borderRadius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

/// 海报画布宽度（按比例区分，横图更宽）。
double posterCanvasWidth(PosterRatio ratio) {
  switch (ratio) {
    case PosterRatio.fullScreen:
    case PosterRatio.ratio34:
    case PosterRatio.square:
      return 300;
    case PosterRatio.ratio43:
      return 360;
    case PosterRatio.ratio169:
      return 380;
  }
}

/// 相对选型稿（330 宽画布）的缩放系数，用于固定高度/固定尺寸元素等比缩放。
double posterScale(PosterRatio ratio) => posterCanvasWidth(ratio) / 330;

/// 固定高度型海报（选型稿 min-height:760）在当前画布宽度下的高度。
double posterFixedHeight(PosterRatio ratio) => 760 * posterScale(ratio);

/// 海报照片区目标宽高比（照片区按该比例撑高，照片以 cover 填充）。
double posterPhotoAspect(PosterRatio ratio) {
  switch (ratio) {
    case PosterRatio.fullScreen:
      return 9 / 16;
    case PosterRatio.ratio34:
      return 3 / 4;
    case PosterRatio.square:
      return 1;
    case PosterRatio.ratio43:
      return 4 / 3;
    case PosterRatio.ratio169:
      return 16 / 9;
  }
}

/// 中文衬线标题样式（思源宋体 / 系统宋体回退）。
TextStyle posterSerif(
  double size, {
  Color color = PosterPalette.ink,
  double? letterSpacing,
  FontWeight weight = FontWeight.w700,
  double? height,
}) {
  return TextStyle(
    fontFamily: 'Noto Serif SC',
    fontFamilyFallback: const ['Songti SC', 'SimSun', 'STSong'],
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}

/// 英文衬线样式（Georgia）。
TextStyle posterSerifEn(
  double size, {
  Color color = PosterPalette.ink,
  double? letterSpacing,
  FontWeight weight = FontWeight.w600,
}) {
  return TextStyle(
    fontFamily: 'Georgia',
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: 1.2,
  );
}

/// 正文/小字样式（无衬线）。
TextStyle posterPlain(
  double size, {
  Color color = PosterPalette.text3,
  double? letterSpacing,
  FontWeight weight = FontWeight.normal,
  double? height,
}) {
  return TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}

/// 品牌四角框符号标（复用 LumiraLogo.symbol，金色取景器符号）。
class PosterLogo extends StatelessWidget {
  const PosterLogo({super.key, this.size = 15});
  final double size;

  @override
  Widget build(BuildContext context) {
    return LumiraLogo.symbol(size: size);
  }
}

/// 顶部品牌行（浅色底）：符号 + LUMIRA + 如画（金色）。
class PosterBrandRow extends StatelessWidget {
  const PosterBrandRow({super.key, this.logoSize = 15, this.textColor});
  final double logoSize;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? PosterPalette.goldDeep;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PosterLogo(size: logoSize),
        const SizedBox(width: 8),
        Text('LUMIRA', style: posterSerifEn(11, color: color, letterSpacing: 4)),
        const SizedBox(width: 6),
        Text('如画', style: posterPlain(10, color: PosterPalette.text3, letterSpacing: 2)),
      ],
    );
  }
}

/// 叠在照片/深色背景上的品牌行（白色 + 阴影，保证可读）。
class PosterBrandOnPhoto extends StatelessWidget {
  const PosterBrandOnPhoto({super.key, this.logoSize = 15});
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PosterLogo(size: logoSize),
        const SizedBox(width: 8),
        Text(
          'LUMIRA',
          style: posterSerifEn(
            11,
            color: Colors.white,
            letterSpacing: 4,
          ).copyWith(shadows: const [Shadow(color: Colors.black38, blurRadius: 6)]),
        ),
        const SizedBox(width: 6),
        Text(
          '如画',
          style: posterPlain(10, color: Colors.white70, letterSpacing: 2),
        ),
      ],
    );
  }
}

/// 底部品牌脚：符号 + LUMIRA · 如画 + 标语「如你所见，皆成画卷」。
class PosterBrandFoot extends StatelessWidget {
  const PosterBrandFoot({
    super.key,
    this.logoSize = 15,
    this.borderTop = false,
    this.paddingTop = 0,
    this.borderColor = PosterPalette.line,
  });
  final double logoSize;

  /// 上方金色细分隔线（部分样式需要，如 dA / dC / dD / dE）。
  final bool borderTop;
  final double paddingTop;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PosterLogo(size: logoSize),
        const SizedBox(width: 8),
        Text('LUMIRA', style: posterSerifEn(10, color: PosterPalette.goldDeep, letterSpacing: 3)),
        const SizedBox(width: 4),
        Text('· 如画', style: posterPlain(10, color: PosterPalette.text3)),
        const Spacer(),
        Text('如你所见，皆成画卷', style: posterPlain(9, color: PosterPalette.text3, letterSpacing: 1)),
      ],
    );
    if (!borderTop && paddingTop == 0) return row;
    return Container(
      padding: EdgeInsets.only(top: paddingTop),
      decoration: borderTop
          ? BoxDecoration(border: Border(top: BorderSide(color: borderColor)))
          : null,
      child: row,
    );
  }
}

/// 海报缩略图作用域：样式切换条的迷你卡等「小尺寸缩略」场景。
///
/// 在该作用域内 [PosterQr] 渲染品牌占位 QR 图形（而非真实二维码）。
/// 真实二维码被缩略到约 10~15px 时会糊成「中间一个小点」；
/// 占位图形在任意小尺寸下都保持清晰可辨，避免缩略图出现渲染缺陷。
class PosterThumbnailScope extends InheritedWidget {
  const PosterThumbnailScope({super.key, required super.child});

  /// 当前是否处于缩略图作用域。
  static bool isThumbnail(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PosterThumbnailScope>() != null;

  @override
  bool updateShouldNotify(PosterThumbnailScope oldWidget) => false;
}

/// 海报二维码（白底黑模块，外框品牌色）。
///
/// 在 [PosterThumbnailScope] 缩略图作用域内改渲染品牌占位 QR 图形。
class PosterQr extends StatelessWidget {
  const PosterQr({
    super.key,
    required this.data,
    this.size = 54,
    this.padding = 5,
    this.radius = 9,
    this.background,
    this.borderColor,
    this.paddingAll = 0,
  });

  final String data;
  final double size;
  final double padding;
  final double radius;
  final Color? background;
  final Color? borderColor;
  final double paddingAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + paddingAll * 2,
      height: size + paddingAll * 2,
      padding: EdgeInsets.all(padding + paddingAll),
      decoration: BoxDecoration(
        color: background ?? PosterPalette.surfaceAlt,
        borderRadius: BorderRadius.circular(radius),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
      ),
      child: PosterThumbnailScope.isThumbnail(context)
          // 缩略图模式：占位 QR 图形，避免真实二维码缩成一点
          ? _QrThumbnailGlyph(size: size)
          : QrImageView(
              data: data,
              version: QrVersions.auto,
              size: size,
              // 关闭 QrImageView 自带 10px 内边距（双重 padding 会把有效二维码缩小
              // size-30，小尺寸下糊成一点）；静区由外层 Container 的浅色 padding 承担。
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
              errorStateBuilder: (_, __) => Center(
                child: PosterLogo(size: size * 0.4),
              ),
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: PosterPalette.ink,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: PosterPalette.ink,
              ),
            ),
    );
  }
}

/// 缩略图模式下的二维码占位：白底圆角方块 + 占满的迷你 QR 图形。
///
/// 图形占满几乎整个方块（非居中缩小），配合高密度模块，
/// 即便整张海报缩到很小也不会退化成「中间一个小点」。
class _QrThumbnailGlyph extends StatelessWidget {
  const _QrThumbnailGlyph({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
      ),
      child: CustomPaint(
        size: Size.square((size - 4) * 0.96),
        painter: const _ThumbnailQrPainter(),
      ),
    );
  }
}

/// 迷你 QR 图形：三个醒目的实心定位角 + 密布信息模块。
///
/// 采用 7×7 高密度网格 + 深墨色高对比，小尺寸下仍呈现标准「二维码」观感，
/// 避免稀疏网格缩成一个小点。
class _ThumbnailQrPainter extends CustomPainter {
  const _ThumbnailQrPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const n = 7;
    final c = size.shortestSide / n;
    final ink = Paint()..color = PosterPalette.ink;
    final white = Paint()..color = Colors.white;

    void rect(double x, double y, double w, double h, Paint p) {
      canvas.drawRect(Rect.fromLTWH(x * c, y * c, w * c, h * c), p);
    }

    // 三定位角（左上 / 右上 / 左下）：外方 3×3 + 白芯 1×1 → 实心方块，最醒目
    for (final o in const [Offset(0, 0), Offset(4, 0), Offset(0, 4)]) {
      rect(o.dx, o.dy, 3, 3, ink);
      rect(o.dx + 1, o.dy + 1, 1, 1, white);
    }

    // 密布信息模块（避开定位角及其白芯）
    const modules = [
      // 定位角之间的时序行列
      Offset(3, 0), Offset(3, 2), Offset(2, 3), Offset(3, 3), Offset(4, 3),
      Offset(3, 4), Offset(3, 6),
      // 中下部随机信息点
      Offset(6, 3), Offset(5, 4), Offset(6, 5), Offset(6, 6),
      Offset(4, 5), Offset(5, 6), Offset(4, 6),
      // 右上区
      Offset(6, 1), Offset(5, 3), Offset(4, 2),
    ];
    for (final m in modules) {
      rect(m.dx, m.dy, 1, 1, ink);
    }
  }

  @override
  bool shouldRepaint(_ThumbnailQrPainter oldDelegate) => false;
}

/// 二维码 + 提示文案块（用于 pA / s1 / d1 等面板的 meta 区）。
class PosterQrTip extends StatelessWidget {
  const PosterQrTip({
    super.key,
    required this.data,
    this.qrSize = 54,
    this.hint,
    this.sub,
    this.light = false,
  });

  final String data;
  final double qrSize;
  final String? hint;
  final String? sub;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final Color t = light ? Colors.white : PosterPalette.ink;
    final Color s = light ? Colors.white70 : PosterPalette.text3;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PosterQr(data: data, size: qrSize, padding: 5, radius: 9),
        const SizedBox(width: 14),
        Flexible(
          fit: FlexFit.loose,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hint != null)
                Text(hint!,
                    style: posterPlain(11, color: t, weight: FontWeight.w600, letterSpacing: 1)),
              if (sub != null) ...[
                const SizedBox(height: 3),
                Text(sub!, style: posterPlain(9, color: s, letterSpacing: 1)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 圆形首字头像（照片海报落款 @小满 用）。
class PosterAvatar extends StatelessWidget {
  const PosterAvatar({super.key, required this.char, this.size = 24});
  final String char;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PosterPalette.gold, Color(0xFF8E867B)],
        ),
      ),
      child: Text(
        char,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 照片海报作者行：头像 + @小满 + · 用「如画」拍摄。
class PosterAuthorRow extends StatelessWidget {
  const PosterAuthorRow({
    super.key,
    required this.name,
    this.suffix = '用「如画」拍摄',
    this.light = false,
    this.avatarSize = 24,
    this.justifyCenter = false,
  });

  final String name;
  final String suffix;
  final bool light;
  final double avatarSize;
  final bool justifyCenter;

  @override
  Widget build(BuildContext context) {
    final Color who = light ? Colors.white : PosterPalette.ink;
    final Color withC = light ? Colors.white70 : PosterPalette.text3;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PosterAvatar(char: name.isEmpty ? 'L' : name.characters.first, size: avatarSize),
        const SizedBox(width: 8),
        Text('@$name', style: posterPlain(11, color: who, weight: FontWeight.w600, letterSpacing: 1)),
        const SizedBox(width: 6),
        Text('· $suffix', style: posterPlain(9, color: withC, letterSpacing: 1)),
      ],
    );
    return justifyCenter ? Center(child: row) : row;
  }
}

/// 金色短分隔线（rule）。
class PosterRule extends StatelessWidget {
  const PosterRule({super.key, this.width = 46, this.thickness = 2, this.color});
  final double width;
  final double thickness;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: thickness,
      color: color ?? PosterPalette.gold,
    );
  }
}

/// 金色细分隔线（meta 区顶部）。
class PosterDivider extends StatelessWidget {
  const PosterDivider({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: PosterPalette.line);
  }
}

/// 小字号金色 kicker（如「LUMIRA TEMPLATE · 模板」）。
class PosterKicker extends StatelessWidget {
  const PosterKicker({
    super.key,
    required this.text,
    this.color = PosterPalette.goldDeep,
    this.size = 9,
    this.letterSpacing = 3,
    this.weight = FontWeight.w600,
  });
  final String text;
  final Color color;
  final double size;
  final double letterSpacing;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: posterPlain(size, color: color, weight: weight, letterSpacing: letterSpacing),
    );
  }
}

/// 衬线大标题。
class PosterTitle extends StatelessWidget {
  const PosterTitle({
    super.key,
    required this.text,
    this.color = PosterPalette.ink,
    this.size = 30,
    this.letterSpacing = 2,
    this.height = 1.25,
    this.align,
  });
  final String text;
  final Color color;
  final double size;
  final double letterSpacing;
  final double height;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      style: posterSerif(size, color: color, letterSpacing: letterSpacing, height: height),
    );
  }
}

/// 分类文案（「 · 」分隔符用品牌金渲染）。
class PosterCatText extends StatelessWidget {
  const PosterCatText({
    super.key,
    required this.category,
    this.size = 9,
    this.color = PosterPalette.text2,
    this.letterSpacing = 3,
    this.separatorColor = PosterPalette.goldDeep,
    this.align,
  });
  final String category;
  final double size;
  final Color color;
  final double letterSpacing;
  final Color separatorColor;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) {
    final segs = category.split('·').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final base = posterPlain(size, color: color, letterSpacing: letterSpacing);
    final spans = <TextSpan>[];
    for (var i = 0; i < segs.length; i++) {
      if (i > 0) {
        spans.add(TextSpan(text: ' · ', style: base.copyWith(color: separatorColor)));
      }
      spans.add(TextSpan(text: segs[i]));
    }
    return Text.rich(TextSpan(children: spans, style: base), textAlign: align);
  }
}

/// 叠在照片/深色底上的品牌脚：LUMIRA · 如画 + 标语。
class PosterFootOnPhoto extends StatelessWidget {
  const PosterFootOnPhoto({
    super.key,
    this.name = 'LUMIRA',
    this.zh = '· 如画',
    this.slogan = '如你所见，皆成画卷',
    this.nameColor = PosterPalette.goldSoft,
    this.zhColor = const Color(0xB3FFFFFF),
    this.sloganColor = const Color(0xA6FFFFFF),
    this.includeSlogan = true,
  });
  final String name;
  final String zh;
  final String slogan;
  final Color nameColor;
  final Color zhColor;
  final Color sloganColor;
  final bool includeSlogan;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(name, style: posterPlain(10, color: nameColor, weight: FontWeight.w600, letterSpacing: 3)),
        const SizedBox(width: 4),
        Text(zh, style: posterPlain(10, color: zhColor)),
        if (includeSlogan) ...[
          const Spacer(),
          Text(slogan, style: posterPlain(9, color: sloganColor, letterSpacing: 1)),
        ],
      ],
    );
  }
}
