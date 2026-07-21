import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// 姿势剪影渲染组件（简化版）
///
/// 视觉规格来源：lumira-app/src/components/PoseSilhouette.vue
///
/// 简化说明（brief §3.2 + §8.1 已知简化决策 #1）：
/// - builtin：用 `Icon(Icons.person_outline)` 占位（仅当 data != 'none'）
/// - image：用 `Image.memory(base64Decode(data))` 渲染（若 data 为空则不渲染）
/// - svg：解析 SilhouetteEditor 导出的 SVG 字符串（<path d="M.. L.." stroke=".."
///   stroke-width=".." .../>），用 CustomPainter 渲染
///   - 仅支持 SilhouetteEditor 导出的简单格式（path 元素 + M/L 命令）
///   - 外部复杂 SVG 仍 fallback 到占位图标
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

  /// 0.5 ~ 1.5
  final double scale;

  /// -45 ~ 45
  final double rotation;

  /// 默认 Color.fromRGBO(255, 255, 255, 0.85)（与项目记忆规则"剪影包装元素 color: rgba(255,255,255,0.85)"一致）
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? const Color.fromRGBO(255, 255, 255, 0.85);

    Widget content = _buildContent(effectiveColor);

    // 用 Transform 应用缩放和旋转
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..rotateZ(rotation * math.pi / 180.0)
        ..scale(scale),
      child: content,
    );
  }

  Widget _buildContent(Color effectiveColor) {
    switch (silhouetteType) {
      case 'builtin':
        if (silhouetteData.isEmpty || silhouetteData == 'none') {
          // builtin 'none'：渲染空 SizedBox（与 brief §3.2 一致）
          return const SizedBox(width: 80, height: 80);
        }
        // 简化：用 Icon 占位（Task 2.9 接入真实 SVG 库后替换）
        return Icon(
          Icons.person_outline,
          color: effectiveColor,
          size: 80,
        );

      case 'image':
        if (silhouetteData.isEmpty) {
          // mock 数据为空时不渲染（避免 base64Decode 异常）
          return const SizedBox(width: 80, height: 80);
        }
        // image 类型：解析 base64 数据 URL（如 `data:image/png;base64,xxxx`）
        return Image.memory(
          _decodeBase64DataUrl(silhouetteData),
          width: 80,
          height: 80,
          color: effectiveColor,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.broken_image_outlined,
            color: effectiveColor,
            size: 80,
          ),
        );

      case 'svg':
        // Bug 11 修复：解析 SilhouetteEditor 导出的 SVG 字符串并渲染
        // 仅支持简单格式（<path d="M.. L.." stroke-width=".." .../>），
        // 复杂外部 SVG fallback 到占位图标
        final parsed = _SilhouetteSvgParser.parse(silhouetteData);
        if (parsed == null) {
          return Icon(
            Icons.brush_outlined,
            color: effectiveColor,
            size: 80,
          );
        }
        return SizedBox(
          width: 80,
          height: 80,
          child: CustomPaint(
            painter: _SilhouetteSvgPainter(
              paths: parsed.paths,
              viewBox: parsed.viewBox,
              color: effectiveColor,
            ),
          ),
        );

      default:
        return const SizedBox(width: 80, height: 80);
    }
  }

  /// 解析 base64 data URL，strip `data:image/...;base64,` 前缀
  static Uint8List _decodeBase64DataUrl(String data) {
    String raw = data;
    final commaIdx = data.indexOf(',');
    if (commaIdx >= 0 && data.startsWith('data:')) {
      raw = data.substring(commaIdx + 1);
    }
    return base64Decode(raw);
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
