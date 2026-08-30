import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/widgets/images/lumira_image.dart';
import '../data/builtin_silhouettes.dart';

/// 姿势剪影渲染组件
///
/// 视觉规格来源：lumira-app/src/components/PoseSilhouette.vue
///
/// 尺寸机制（与 uni-app 原始设计一致）：
/// - 本组件**填满父容器**，父容器（[SilhouetteLayer]）负责把剪影框设为
///   成像区宽度的 40% × 1:1.6 宽高比
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
        // 填满父容器：父容器（SilhouetteLayer）已把尺寸算好
        final baseWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : (constraints.maxHeight.isFinite
                ? constraints.maxHeight * baseAspectW / baseAspectH
                : 100.0);
        final baseHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : baseWidth * baseAspectH / baseAspectW;

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
        // 渲染 asset 路径的黑色线条剪影 PNG（透明背景）
        final assetPath = BuiltinSilhouettes.assetMap[silhouetteData];
        if (assetPath != null && assetPath.isNotEmpty) {
          // 黑色线条 → 通过 ColorFiltered 反转为白色（适配暗色照片背景）
          return ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              -1,  0,  0, 0, 255,
               0, -1,  0, 0, 255,
               0,  0, -1, 0, 255,
               0,  0,  0, 1,   0,
            ]),
            child: Image.asset(
              assetPath,
              key: ValueKey('silhouette_png_$silhouetteData'),
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => Icon(
                Icons.person_outline,
                color: effectiveColor,
                size: baseWidth * 0.8,
              ),
            ),
          );
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
        // image 类型：非 `data:` 的源一律按路径透传给 LumiraImage，由其在内部
        // 分流（assets 路径 → Image.asset、http(s) URL → 网络缓存、其它 → 本地
        // 文件路径 Image.file）；`data:`/纯 base64 补前缀后走 Image.memory
        // （字节级缓存 + 降采样）。
        final isPath = !silhouetteData.startsWith('data:');
        return LumiraImage(
          isPath ? silhouetteData : _asDataUrl(silhouetteData),
          key: ValueKey(silhouetteData),
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.contain,
          errorWidget: Icon(
            Icons.broken_image_outlined,
            color: effectiveColor,
            size: baseWidth * 0.8,
          ),
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

  /// 纯 base64（无 `data:` 前缀）时补上 data URL 前缀，交给 [LumiraImage] 识别。
  static String _asDataUrl(String data) =>
      data.startsWith('data:') ? data : 'data:image/jpeg;base64,$data';
}

/// 剪影叠加层（统一渲染规则）
///
/// 三端（模板详情姿势参考 / 拍摄页取景 / 编辑页预览）共用的剪影定位组件，
/// 视觉规格来源：lumira-app 的 `.silhouette-layer` / `.pose-layer`：
/// - 剪影框宽 = 成像区（取景比例框）宽度的 40%（[PoseSilhouette.baseWidthFactor]）
/// - 剪影框宽高比 = 1 : 1.6（[PoseSilhouette.baseAspectW] / [PoseSilhouette.baseAspectH]）
/// - 剪影框中心锚定在 (positionX × 成像区宽, positionY × 成像区高)，
///   position 为 0..1 百分比，切换比例后位置随比例框自动变化
/// - scale / rotation 在基础尺寸上叠加
///
/// 使用方式：在成像区 Stack 中以 `Positioned.fill(child: SilhouetteLayer(...))`
/// 放入（本组件内部自带 LayoutBuilder，按成像区实际尺寸计算）。
class SilhouetteLayer extends StatelessWidget {
  const SilhouetteLayer({
    super.key,
    required this.silhouetteType,
    required this.silhouetteData,
    required this.positionX,
    required this.positionY,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.color,
  });

  /// 'builtin' / 'image' / 'svg'
  final String silhouetteType;

  /// builtin: silhouette key；image: base64 data URL / asset / http URL；
  /// svg: 内联 SVG 字符串
  final String silhouetteData;

  /// 剪影中心相对成像区的水平位置（0..1，百分比）
  final double positionX;

  /// 剪影中心相对成像区的垂直位置（0..1，百分比）
  final double positionY;

  /// 缩放系数（叠加在 40% 基础宽度上）
  final double scale;

  /// 旋转角度 -45 ~ 45
  final double rotation;

  /// 默认 Color.fromRGBO(255, 255, 255, 0.85)
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final areaW = constraints.maxWidth;
        final areaH = constraints.maxHeight;
        if (!areaW.isFinite || !areaH.isFinite) {
          return const SizedBox.shrink();
        }
        final baseW = areaW * PoseSilhouette.baseWidthFactor;
        final baseH =
            baseW * PoseSilhouette.baseAspectH / PoseSilhouette.baseAspectW;

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: areaW * positionX,
              top: areaH * positionY,
              child: FractionalTranslation(
                // 以剪影框中心点为锚点（left/top 指向中心）
                translation: const Offset(-0.5, -0.5),
                child: SizedBox(
                  key: const ValueKey('silhouette_box'),
                  width: baseW,
                  height: baseH,
                  child: PoseSilhouette(
                    silhouetteType: silhouetteType,
                    silhouetteData: silhouetteData,
                    scale: scale,
                    rotation: rotation,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
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
      final strokeWidth =
          double.tryParse(_attr(pathXml, 'stroke-width') ?? '') ?? 8.0;
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
