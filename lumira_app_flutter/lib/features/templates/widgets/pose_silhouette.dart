import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// 姿势剪影渲染组件
///
/// 视觉规格来源：lumira-app/src/components/PoseSilhouette.vue
///
/// 尺寸机制（与 uni-app 原始设计一致）：
/// - 剪影基础宽度 = 父容器宽度的 40%（widthFactor: 0.4）
/// - 剪影宽高比 = 1 : 1.6（人像纵向，非正方形）
/// - 缩放/旋转通过 Transform 在基础尺寸上叠加
/// - 图片/SVG 填满剪影容器（width: 100%, height: 100%）
class PoseSilhouette extends StatelessWidget {
  const PoseSilhouette({
    super.key,
    required this.silhouetteType,
    required this.silhouetteData,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.color,
  });

  /// 'builtin' / 'image' / 'svg'
  final String silhouetteType;

  /// builtin: silhouette key; image: base64 data URL; svg: inline SVG string
  final String silhouetteData;

  /// 缩放系数（在 40% 基础宽度上叠加）
  final double scale;

  /// 旋转角度 -45 ~ 45
  final double rotation;

  /// 默认 Color.fromRGBO(255, 255, 255, 0.85)
  final Color? color;

  /// 剪影基础宽度占父容器宽度的比例（与 uni-app 设计一致：40%）
  static const double baseWidthFactor = 0.4;

  /// 剪影宽高比（宽:高 = 1:1.6，人像纵向）
  static const double baseAspectW = 1.0;
  static const double baseAspectH = 1.6;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? const Color.fromRGBO(255, 255, 255, 0.85);

    return LayoutBuilder(
      builder: (context, constraints) {
        // 剪影基础宽度 = 父容器宽度 × 40%
        final baseWidth = constraints.maxWidth * baseWidthFactor;
        // 高度 = 宽度 × 1.6
        final baseHeight = baseWidth * baseAspectH / baseAspectW;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..rotateZ(rotation * math.pi / 180.0)
            ..scale(scale),
          child: SizedBox(
            width: baseWidth,
            height: baseHeight,
            child: _buildContent(effectiveColor, baseWidth),
          ),
        );
      },
    );
  }

  Widget _buildContent(Color effectiveColor, double baseWidth) {
    switch (silhouetteType) {
      case 'builtin':
        if (silhouetteData.isEmpty || silhouetteData == 'none') {
          return const SizedBox.shrink();
        }
        return Icon(
          Icons.person_outline,
          color: effectiveColor,
          size: baseWidth * 0.8,
        );

      case 'image':
        if (silhouetteData.isEmpty) {
          return const SizedBox.shrink();
        }
        // image 类型支持三种数据源：
        // 1. asset 路径 → Image.asset
        // 2. http(s) URL → Image.network
        // 3. base64 data URL → Image.memory
        if (silhouetteData.startsWith('assets/')) {
          return Image.asset(
            silhouetteData,
            key: ValueKey(silhouetteData),
            gaplessPlayback: true,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.broken_image_outlined,
              color: effectiveColor,
              size: baseWidth * 0.8,
            ),
          );
        }
        if (silhouetteData.startsWith('http://') ||
            silhouetteData.startsWith('https://')) {
          return Image.network(
            silhouetteData,
            key: ValueKey(silhouetteData),
            gaplessPlayback: true,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.contain,
            errorBuilder: (_, error, ___) {
              debugPrint('[PoseSilhouette] Network image error: $error');
              return Icon(
                Icons.broken_image_outlined,
                color: effectiveColor,
                size: baseWidth * 0.8,
              );
            },
          );
        }
        return Image.memory(
          _decodeBase64DataUrl(silhouetteData),
          key: ValueKey(silhouetteData),
          gaplessPlayback: true,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.contain,
          errorBuilder: (_, error, ___) {
            debugPrint('[PoseSilhouette] Memory image decode error: $error');
            return Icon(
              Icons.broken_image_outlined,
              color: effectiveColor,
              size: baseWidth * 0.8,
            );
          },
        );

      case 'svg':
        final parsed = _SilhouetteSvgParser.parse(silhouetteData);
        if (parsed == null) {
          return Icon(
            Icons.brush_outlined,
            color: effectiveColor,
            size: baseWidth * 0.8,
          );
        }
        return SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: CustomPaint(
            painter: _SilhouetteSvgPainter(
              paths: parsed.paths,
              viewBox: parsed.viewBox,
              color: effectiveColor,
            ),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  /// 解析 base64 data URL，strip `data:image/...;base64,` 前缀
  static final Map<String, Uint8List> _cachedBase64 = {};

  static Uint8List _decodeBase64DataUrl(String data) {
    return _cachedBase64.putIfAbsent(data, () {
      String raw = data;
      final commaIdx = data.indexOf(',');
      if (commaIdx >= 0 && data.startsWith('data:')) {
        raw = data.substring(commaIdx + 1);
      }
      return base64Decode(raw);
    });
  }
}

/// 解析 SilhouetteEditor 导出的简单 SVG 字符串
///
/// 支持格式：
/// ```xml
/// <svg viewBox="0 0 300 480" xmlns="...">
///   <path d="M 10 20 L 30 40 L 50 60" stroke="#fff" stroke-width="8"
///         stroke-linecap="round" stroke-linejoin="round" fill="none"/>
/// </svg>
/// ```
class _SilhouetteSvgParser {
  static _ParsedSvg? parse(String svg) {
    if (svg.isEmpty || !svg.contains('<svg')) return null;

    final viewBox = _parseViewBox(svg) ?? const _Rect(0, 0, 300, 480);
    final paths = <_ParsedPath>[];

    // 简单正则提取所有 <path .../> 元素
    final pathRegex = RegExp(r'<path\b[^>]*?/>', caseSensitive: false);
    for (final match in pathRegex.allMatches(svg)) {
      final pathXml = match.group(0)!;
      final d = _attr(pathXml, 'd');
      if (d == null) continue;
      final strokeWidth = double.tryParse(_attr(pathXml, 'stroke-width') ?? '') ??
          8.0;
      paths.add(_ParsedPath(
        d: d,
        strokeWidth: strokeWidth,
      ));
    }

    if (paths.isEmpty) return null;
    return _ParsedSvg(viewBox: viewBox, paths: paths);
  }

  static _Rect? _parseViewBox(String svg) {
    final match = RegExp(r'viewBox="([^"]+)"').firstMatch(svg);
    if (match == null) return null;
    final parts = match.group(1)!.split(RegExp(r'[\s,]+'));
    if (parts.length != 4) return null;
    final x = double.tryParse(parts[0]) ?? 0;
    final y = double.tryParse(parts[1]) ?? 0;
    final w = double.tryParse(parts[2]) ?? 300;
    final h = double.tryParse(parts[3]) ?? 480;
    return _Rect(x, y, w, h);
  }

  static String? _attr(String xml, String name) {
    final match = RegExp('$name="([^"]*)"').firstMatch(xml);
    return match?.group(1);
  }
}

class _Rect {
  final double x;
  final double y;
  final double width;
  final double height;
  const _Rect(this.x, this.y, this.width, this.height);
}

class _ParsedPath {
  final String d;
  final double strokeWidth;
  const _ParsedPath({required this.d, required this.strokeWidth});
}

class _ParsedSvg {
  final _Rect viewBox;
  final List<_ParsedPath> paths;
  const _ParsedSvg({required this.viewBox, required this.paths});
}

/// 将 SVG path 数据转换为 flutter Path 对象
/// 仅支持 SilhouetteEditor 导出的 "M x y L x y L x y ..." 格式
Path _buildPathFromD(String d) {
  final path = Path();
  final tokens = d.split(RegExp(r'[\s,]+'));
  int i = 0;
  while (i < tokens.length) {
    final cmd = tokens[i];
    i++;
    if (cmd == 'M' || cmd == 'L') {
      if (i + 1 >= tokens.length) break;
      final x = double.tryParse(tokens[i]) ?? 0;
      final y = double.tryParse(tokens[i + 1]) ?? 0;
      i += 2;
      if (cmd == 'M') {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    } else {
      // 跳过未知命令
      break;
    }
  }
  return path;
}

class _SilhouetteSvgPainter extends CustomPainter {
  _SilhouetteSvgPainter({
    required this.paths,
    required this.viewBox,
    required this.color,
  });

  final List<_ParsedPath> paths;
  final _Rect viewBox;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // 计算 viewBox 到 size 的缩放比，保持宽高比（contain）
    final sx = size.width / viewBox.width;
    final sy = size.height / viewBox.height;
    final scale = math.min(sx, sy);
    final dx = (size.width - viewBox.width * scale) / 2 - viewBox.x * scale;
    final dy = (size.height - viewBox.height * scale) / 2 - viewBox.y * scale;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale, scale);

    for (final p in paths) {
      final path = _buildPathFromD(p.d);
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = p.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SilhouetteSvgPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.viewBox.width != viewBox.width ||
        oldDelegate.viewBox.height != viewBox.height ||
        oldDelegate.paths.length != paths.length;
  }
}
