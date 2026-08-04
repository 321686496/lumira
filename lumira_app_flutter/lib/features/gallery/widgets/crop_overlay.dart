// lib/features/gallery/widgets/crop_overlay.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/theme_tokens.dart';

/// 可拖拽裁剪框叠加层
///
/// 在图片上方绘制半透明遮罩，中间留出裁剪区域（透明）。
/// 裁剪区域四角和四边有 8 个拖拽手柄，用户可以拖拽调整裁剪区域大小和位置。
///
/// 坐标系统：裁剪区域用 Rect（相对坐标 0.0-1.0）表示，
/// 便于跨不同图片尺寸使用，导出时转为像素坐标。
///
/// 手柄类型（8 个）：
/// - 4 角：topLeft, topRight, bottomLeft, bottomRight（可同时调整宽高）
/// - 4 边中点：topCenter, bottomCenter, leftCenter, rightCenter（仅调整一个方向）
/// - 内部拖拽：body（整体移动裁剪区域，不改变大小）
///
/// 约束：
/// - 手柄触摸区域 >= 32x32 像素（hitTest 半径 24px → 48x48 命中区）
/// - 裁剪框不超出 0.0-1.0 边界
/// - 最小尺寸 _minSize，防止裁剪区域过小
/// - 可选 aspectRatio 锁定宽高比
class CropOverlay extends StatefulWidget {
  /// 初始裁剪区域（相对坐标 0.0-1.0）。
  /// 为 null 时自动计算默认居中区域（按 aspectRatio 居中最大化）。
  final Rect? initialRect;

  /// 锁定宽高比（width / height）。
  /// 为 null 时可自由调整；> 0 时锁定比例。
  final double? aspectRatio;

  /// 裁剪区域变化回调，返回相对坐标 Rect（0.0-1.0）。
  /// 在拖拽过程中持续触发。
  final ValueChanged<Rect>? onChanged;

  /// 主题色板（用于手柄和边框配色）。
  /// 为 null 时使用默认白色。
  final ThemeTokens? tokens;

  const CropOverlay({
    super.key,
    this.initialRect,
    this.aspectRatio,
    this.onChanged,
    this.tokens,
  });

  @override
  State<CropOverlay> createState() => _CropOverlayState();
}

/// 拖拽手柄类型
enum _HandleType {
  topLeft,
  topCenter,
  topRight,
  rightCenter,
  bottomRight,
  bottomCenter,
  bottomLeft,
  leftCenter,
  body, // 拖拽整个裁剪区域
  none,
}

class _CropOverlayState extends State<CropOverlay> {
  /// 当前裁剪区域（相对坐标 0.0-1.0）
  late Rect _cropRect;

  /// 当前激活的手柄类型（拖拽中）
  _HandleType _activeHandle = _HandleType.none;

  /// 最小裁剪尺寸（相对值），防止裁剪区域过小
  static const double _minSize = 0.1;

  /// 手柄触摸半径（像素），>= 16 保证命中区 >= 32x32
  static const double _touchRadius = 24.0;

  @override
  void initState() {
    super.initState();
    _cropRect = widget.initialRect ?? _computeDefaultRect();
  }

  @override
  void didUpdateWidget(CropOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部变化时重新计算裁剪区域（如切换比例、重置、加载保存的裁剪）
    if (widget.initialRect != oldWidget.initialRect ||
        widget.aspectRatio != oldWidget.aspectRatio) {
      _cropRect = widget.initialRect ?? _computeDefaultRect();
    }
  }

  /// 计算默认居中裁剪区域
  Rect _computeDefaultRect() {
    if (widget.aspectRatio == null) {
      // 自由模式：默认占 90% 区域，居中
      return const Rect.fromLTWH(0.05, 0.05, 0.9, 0.9);
    }
    return _centerMaxRect(widget.aspectRatio!);
  }

  /// 在 0-1 范围内计算给定宽高比的最大居中 Rect
  ///
  /// [aspect] = width / height
  /// 留 5% 边距，不完全贴边
  Rect _centerMaxRect(double aspect) {
    double w, h;
    // 尝试占满宽度（w=1），h = 1/aspect
    // 如果 h > 1，则占满高度（h=1），w = aspect
    if (aspect >= 1.0) {
      w = 1.0;
      h = 1.0 / aspect;
      if (h > 1.0) {
        h = 1.0;
        w = aspect;
      }
    } else {
      h = 1.0;
      w = aspect;
      if (w > 1.0) {
        w = 1.0;
        h = 1.0 / aspect;
      }
    }
    // 留 5% 边距
    w = math.min(w * 0.9, 1.0);
    h = math.min(h * 0.9, 1.0);
    final x = (1.0 - w) / 2.0;
    final y = (1.0 - h) / 2.0;
    return Rect.fromLTWH(x, y, w, h);
  }

  /// 命中测试：根据触摸位置（像素）确定手柄类型
  _HandleType _hitTest(Offset localPos, Size size) {
    // 转换为像素坐标的裁剪区域
    final crop = Rect.fromLTRB(
      _cropRect.left * size.width,
      _cropRect.top * size.height,
      _cropRect.right * size.width,
      _cropRect.bottom * size.height,
    );

    // 优先检查四角（触摸半径内）
    if ((localPos - crop.topLeft).distance <= _touchRadius) {
      return _HandleType.topLeft;
    }
    if ((localPos - crop.topRight).distance <= _touchRadius) {
      return _HandleType.topRight;
    }
    if ((localPos - crop.bottomLeft).distance <= _touchRadius) {
      return _HandleType.bottomLeft;
    }
    if ((localPos - crop.bottomRight).distance <= _touchRadius) {
      return _HandleType.bottomRight;
    }

    // 检查四边中点
    if ((localPos - Offset(crop.center.dx, crop.top)).distance <= _touchRadius) {
      return _HandleType.topCenter;
    }
    if ((localPos - Offset(crop.center.dx, crop.bottom)).distance <=
        _touchRadius) {
      return _HandleType.bottomCenter;
    }
    if ((localPos - Offset(crop.left, crop.center.dy)).distance <=
        _touchRadius) {
      return _HandleType.leftCenter;
    }
    if ((localPos - Offset(crop.right, crop.center.dy)).distance <=
        _touchRadius) {
      return _HandleType.rightCenter;
    }

    // 检查裁剪区域内部（拖拽整个区域）
    if (crop.contains(localPos)) {
      return _HandleType.body;
    }

    return _HandleType.none;
  }

  void _onPanStart(DragStartDetails details, Size size) {
    _activeHandle = _hitTest(details.localPosition, size);
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    if (_activeHandle == _HandleType.none) return;

    // 像素增量转相对增量
    final dx = details.delta.dx / size.width;
    final dy = details.delta.dy / size.height;

    Rect newRect = _cropRect;
    final handle = _activeHandle;

    switch (handle) {
      case _HandleType.topLeft:
        newRect = Rect.fromLTRB(
          (_cropRect.left + dx).clamp(0.0, _cropRect.right - _minSize),
          (_cropRect.top + dy).clamp(0.0, _cropRect.bottom - _minSize),
          _cropRect.right,
          _cropRect.bottom,
        );
        break;
      case _HandleType.topCenter:
        newRect = Rect.fromLTRB(
          _cropRect.left,
          (_cropRect.top + dy).clamp(0.0, _cropRect.bottom - _minSize),
          _cropRect.right,
          _cropRect.bottom,
        );
        break;
      case _HandleType.topRight:
        newRect = Rect.fromLTRB(
          _cropRect.left,
          (_cropRect.top + dy).clamp(0.0, _cropRect.bottom - _minSize),
          (_cropRect.right + dx).clamp(_cropRect.left + _minSize, 1.0),
          _cropRect.bottom,
        );
        break;
      case _HandleType.rightCenter:
        newRect = Rect.fromLTRB(
          _cropRect.left,
          _cropRect.top,
          (_cropRect.right + dx).clamp(_cropRect.left + _minSize, 1.0),
          _cropRect.bottom,
        );
        break;
      case _HandleType.bottomRight:
        newRect = Rect.fromLTRB(
          _cropRect.left,
          _cropRect.top,
          (_cropRect.right + dx).clamp(_cropRect.left + _minSize, 1.0),
          (_cropRect.bottom + dy).clamp(_cropRect.top + _minSize, 1.0),
        );
        break;
      case _HandleType.bottomCenter:
        newRect = Rect.fromLTRB(
          _cropRect.left,
          _cropRect.top,
          _cropRect.right,
          (_cropRect.bottom + dy).clamp(_cropRect.top + _minSize, 1.0),
        );
        break;
      case _HandleType.bottomLeft:
        newRect = Rect.fromLTRB(
          (_cropRect.left + dx).clamp(0.0, _cropRect.right - _minSize),
          _cropRect.top,
          _cropRect.right,
          (_cropRect.bottom + dy).clamp(_cropRect.top + _minSize, 1.0),
        );
        break;
      case _HandleType.leftCenter:
        newRect = Rect.fromLTRB(
          (_cropRect.left + dx).clamp(0.0, _cropRect.right - _minSize),
          _cropRect.top,
          _cropRect.right,
          _cropRect.bottom,
        );
        break;
      case _HandleType.body:
        // 拖拽整个区域（不改变大小）
        final newLeft = (_cropRect.left + dx)
            .clamp(0.0, math.max(0.0, 1.0 - _cropRect.width))
            .toDouble();
        final newTop = (_cropRect.top + dy)
            .clamp(0.0, math.max(0.0, 1.0 - _cropRect.height))
            .toDouble();
        newRect = Rect.fromLTWH(
            newLeft, newTop, _cropRect.width, _cropRect.height);
        break;
      case _HandleType.none:
        return;
    }

    // 如果锁定宽高比，调整 rect 以保持比例
    if (widget.aspectRatio != null && handle != _HandleType.body) {
      newRect = _enforceAspectRatio(newRect, widget.aspectRatio!, handle);
    }

    // 确保 rect 不超出 0-1 边界
    newRect = _clampToBounds(newRect);

    setState(() {
      _cropRect = newRect;
    });
    widget.onChanged?.call(newRect);
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _activeHandle = _HandleType.none;
    });
  }

  /// 在拖拽手柄时保持宽高比
  ///
  /// [aspect] = width / height
  /// 策略：
  /// - 角手柄：以宽度为主，高度 = width / aspect，保持对角不动
  /// - 上/下边手柄：以高度为主，宽度 = height * aspect，保持中心 x 不变
  /// - 左/右边手柄：以宽度为主，高度 = width / aspect，保持中心 y 不变
  Rect _enforceAspectRatio(Rect rect, double aspect, _HandleType handle) {
    switch (handle) {
      case _HandleType.topLeft:
        {
          final w = rect.width;
          final h = w / aspect;
          return Rect.fromLTRB(
              rect.right - w, rect.bottom - h, rect.right, rect.bottom);
        }
      case _HandleType.topRight:
        {
          final w = rect.width;
          final h = w / aspect;
          return Rect.fromLTRB(
              rect.left, rect.bottom - h, rect.right, rect.bottom);
        }
      case _HandleType.bottomRight:
        {
          final w = rect.width;
          final h = w / aspect;
          return Rect.fromLTRB(rect.left, rect.top, rect.left + w, rect.top + h);
        }
      case _HandleType.bottomLeft:
        {
          final w = rect.width;
          final h = w / aspect;
          return Rect.fromLTRB(
              rect.right - w, rect.top, rect.right, rect.top + h);
        }
      case _HandleType.topCenter:
      case _HandleType.bottomCenter:
        {
          final h = rect.height;
          final w = h * aspect;
          final cx = rect.center.dx;
          return Rect.fromCenter(
              center: Offset(cx, rect.center.dy), width: w, height: h);
        }
      case _HandleType.leftCenter:
      case _HandleType.rightCenter:
        {
          final w = rect.width;
          final h = w / aspect;
          final cy = rect.center.dy;
          return Rect.fromCenter(
              center: Offset(rect.center.dx, cy), width: w, height: h);
        }
      default:
        return rect;
    }
  }

  /// 确保 rect 不超出 0-1 边界
  Rect _clampToBounds(Rect rect) {
    // 如果宽高超出 1，截断
    final width = rect.width.clamp(0.0, 1.0).toDouble();
    final height = rect.height.clamp(0.0, 1.0).toDouble();
    // 位置约束
    final left =
        rect.left.clamp(0.0, math.max(0.0, 1.0 - width)).toDouble();
    final top =
        rect.top.clamp(0.0, math.max(0.0, 1.0 - height)).toDouble();
    return Rect.fromLTWH(left, top, width, height);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _onPanStart(d, size),
          onPanUpdate: (d) => _onPanUpdate(d, size),
          onPanEnd: _onPanEnd,
          child: CustomPaint(
            size: size,
            painter: _CropOverlayPainter(
              cropRect: _cropRect,
              activeHandle: _activeHandle,
              tokens: widget.tokens,
            ),
          ),
        );
      },
    );
  }
}

/// 裁剪框叠加层画笔
///
/// 绘制内容：
/// 1. 半透明遮罩（裁剪区域外，使用 evenOdd 路径镂空中心）
/// 2. 裁剪区域边框
/// 3. 三分线辅助网格
/// 4. 8 个拖拽手柄（圆形 + 描边）
class _CropOverlayPainter extends CustomPainter {
  /// 裁剪区域（相对坐标 0.0-1.0）
  final Rect cropRect;

  /// 当前激活的手柄（用于高亮显示）
  final _HandleType activeHandle;

  /// 主题色板
  final ThemeTokens? tokens;

  _CropOverlayPainter({
    required this.cropRect,
    required this.activeHandle,
    this.tokens,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 相对坐标 → 像素坐标
    final pixelRect = Rect.fromLTRB(
      cropRect.left * size.width,
      cropRect.top * size.height,
      cropRect.right * size.width,
      cropRect.bottom * size.height,
    );

    // === 1. 半透明遮罩 ===
    // 使用 evenOdd 路径：全区域 + 裁剪区域 → 中心镂空
    final maskPaint = Paint()..color = Colors.black.withOpacity(0.5);
    final maskPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(pixelRect);
    maskPath.fillType = PathFillType.evenOdd;
    canvas.drawPath(maskPath, maskPaint);

    // === 2. 裁剪区域边框 ===
    final borderColor = tokens?.brand ?? Colors.white;
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(pixelRect, borderPaint);

    // === 3. 三分线辅助网格 ===
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    // 垂直线
    for (int i = 1; i < 3; i++) {
      final x = pixelRect.left + pixelRect.width * i / 3;
      canvas.drawLine(
          Offset(x, pixelRect.top), Offset(x, pixelRect.bottom), gridPaint);
    }
    // 水平线
    for (int i = 1; i < 3; i++) {
      final y = pixelRect.top + pixelRect.height * i / 3;
      canvas.drawLine(
          Offset(pixelRect.left, y), Offset(pixelRect.right, y), gridPaint);
    }

    // === 4. 8 个拖拽手柄 ===
    final handleColor = borderColor;
    final handlePaint = Paint()
      ..color = handleColor
      ..style = PaintingStyle.fill;
    final handleBorderPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // 手柄位置（像素坐标）
    final handlePositions = <Offset>[
      pixelRect.topLeft,
      Offset(pixelRect.center.dx, pixelRect.top),
      pixelRect.topRight,
      Offset(pixelRect.right, pixelRect.center.dy),
      pixelRect.bottomRight,
      Offset(pixelRect.center.dx, pixelRect.bottom),
      pixelRect.bottomLeft,
      Offset(pixelRect.left, pixelRect.center.dy),
    ];

    const handleRadius = 7.0;
    for (final pos in handlePositions) {
      canvas.drawCircle(pos, handleRadius, handlePaint);
      canvas.drawCircle(pos, handleRadius, handleBorderPaint);
    }
  }

  @override
  bool shouldRepaint(_CropOverlayPainter oldDelegate) {
    return cropRect != oldDelegate.cropRect ||
        activeHandle != oldDelegate.activeHandle ||
        tokens != oldDelegate.tokens;
  }
}
