import 'package:flutter/material.dart';

import '../../../core/theme/theme_tokens.dart';

/// 通用方形取色器：HSV 面板（饱和度 × 亮度）+ 横向色相条 + 当前色预览。
///
/// 面板内的「白→色相」「透明→黑」「彩虹色相条」属于取色盘自身的色彩内容，
/// 不随主题变化；只有外框描边这类「皮肤」部分跟随 [SquareColorPicker.tokens]。
class SquareColorPicker extends StatefulWidget {
  const SquareColorPicker({
    super.key,
    required this.onColorChanged,
    this.initialColor,
    this.tokens,
  });

  /// 每次拖动回调当前颜色（不透明，alpha 恒为 255）。
  ///
  /// 需要保留原色透明度时由调用方自行合成（取色器只负责色相/饱和度/亮度）。
  final ValueChanged<Color> onColorChanged;

  /// 打开时定位到的颜色；为 null 时沿用拍摄页默认的暖白附近。
  final Color? initialColor;

  /// 主题令牌：提供时外框描边取主题色；未提供则沿用拍摄页固定暗色皮肤。
  final ThemeTokens? tokens;

  @override
  State<SquareColorPicker> createState() => SquareColorPickerState();
}

class SquareColorPickerState extends State<SquareColorPicker> {
  static const _panelSize = 118.0;
  static const _hueBarWidth = 140.0;

  late double _hue;
  late double _saturation;
  late double _value;

  @override
  void initState() {
    super.initState();
    final seed = widget.initialColor;
    if (seed == null) {
      _hue = 40.0; // 默认暖白附近
      _saturation = 0.6;
      _value = 1.0;
    } else {
      final hsv = HSVColor.fromColor(seed);
      _hue = hsv.hue;
      _saturation = hsv.saturation;
      _value = hsv.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    const panelSize = _panelSize;
    const hueBarWidth = _hueBarWidth;
    const hueBarHeight = 10.0;
    final currentColor =
        HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();
    final tokens = widget.tokens;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _hueBarWidth,
          height: panelSize,
          child: GestureDetector(
            onPanDown: (d) => _handleSv(d.localPosition, panelSize),
            onPanUpdate: (d) => _handleSv(d.localPosition, panelSize),
            child: CustomPaint(
              painter: SvPanelPainter(
                hue: _hue,
                saturation: _saturation,
                value: _value,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: hueBarWidth,
          height: hueBarHeight,
          child: GestureDetector(
            onPanDown: (d) => _handleHue(d.localPosition),
            onPanUpdate: (d) => _handleHue(d.localPosition),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(hueBarHeight / 2),
              child: CustomPaint(painter: HueBarPainter(hue: _hue)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // 当前色预览
        Container(
          width: panelSize,
          height: 28,
          decoration: BoxDecoration(
            color: currentColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: tokens == null
                  ? Colors.white24
                  : tokens.textTertiary.withOpacity(0.35),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            _hex(currentColor),
            style: TextStyle(
              // 叠在任意色块上的固定黑白，保证 hex 始终可读（与色块自身亮度相关）。
              color: _value > 0.5 ? Colors.black54 : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  static String _hex(Color c) {
    final r = c.red.toRadixString(16).padLeft(2, '0').toUpperCase();
    final g = c.green.toRadixString(16).padLeft(2, '0').toUpperCase();
    final b = c.blue.toRadixString(16).padLeft(2, '0').toUpperCase();
    return '#$r$g$b';
  }

  void _handleSv(Offset localPos, double size) {
    final s = (localPos.dx / size).clamp(0.0, 1.0);
    // Y 轴反向：顶部=亮度1.0，底部=亮度0.0
    final v = (1.0 - localPos.dy / size).clamp(0.0, 1.0);
    setState(() {
      _saturation = s;
      _value = v;
    });
    widget.onColorChanged(
        HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor());
  }

  void _handleHue(Offset localPos) {
    final h = (localPos.dx / _hueBarWidth * 360.0).clamp(0.0, 360.0);
    setState(() => _hue = h);
    widget.onColorChanged(
        HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor());
  }
}

/// SV 面板绘制器：横向饱和度，纵向亮度
class SvPanelPainter extends CustomPainter {
  const SvPanelPainter({
    required this.hue,
    required this.saturation,
    required this.value,
  });
  final double hue;
  final double saturation;
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // 基色：当前色相的纯色
    final baseColor = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();

    // 横向：白→纯色（饱和度）
    final saturatePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Colors.white, baseColor],
      ).createShader(rect);
    canvas.drawRect(rect, saturatePaint);

    // 纵向：透明→黑（亮度）
    final valuePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black],
      ).createShader(rect);
    canvas.drawRect(rect, valuePaint);

    // 指示器圆圈
    final cx = saturation * size.width;
    final cy = (1.0 - value) * size.height;
    final indicator = Offset(cx, cy);
    canvas.drawCircle(indicator, 8, Paint()..color = Colors.white);
    canvas.drawCircle(
        indicator,
        8,
        Paint()
          ..color = Colors.black38
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant SvPanelPainter oldDelegate) =>
      oldDelegate.hue != hue ||
      oldDelegate.saturation != saturation ||
      oldDelegate.value != value;
}

/// 色相条绘制器
class HueBarPainter extends CustomPainter {
  const HueBarPainter({required this.hue});
  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          for (var h = 0; h <= 360; h += 30)
            HSVColor.fromAHSV(1.0, h.toDouble(), 1.0, 1.0).toColor(),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    // 指示器
    final x = (hue / 360.0) * size.width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(x, size.height / 2),
            width: 6,
            height: size.height + 4),
        const Radius.circular(3),
      ),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant HueBarPainter oldDelegate) =>
      oldDelegate.hue != hue;
}