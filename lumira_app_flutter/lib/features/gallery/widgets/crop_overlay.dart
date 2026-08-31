// lib/features/gallery/widgets/crop_overlay.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/theme_tokens.dart';
import '../../capture/domain/photo_template.dart';
import '../../capture/services/photo_post_processor.dart';

/// 可拖拽裁剪框 + 可缩放照片叠加层（iPhone 原生风格）
///
/// 混合交互模型：
/// - 单指按住裁剪框边缘/角手柄 → 缩放裁剪框（改变裁剪区域）
/// - 单指在裁剪框内部滑动 → 移动裁剪框位置
/// - 双指捏合 / 双指拖动 → 缩放 / 平移照片
///
/// 裁剪框与照片是两层独立变换：
/// - 裁剪框（[Rect]，相对坐标 0.0-1.0）决定"保留哪块区域"
/// - 照片变换（缩放 + 平移）决定"区域内的照片内容"
/// 最终保留区域 = 裁剪框经照片变换反算出的照片区域，通过 [onChanged] 回调。
///
/// 坐标系统：裁剪框与照片均用相对坐标 0.0-1.0，便于跨图片尺寸使用。
///
/// 手柄类型（8 个）：
/// - 4 角：topLeft, topRight, bottomLeft, bottomRight（可同时调整宽高）
/// - 4 边中点：topCenter, bottomCenter, leftCenter, rightCenter（仅调整一个方向）
/// - 内部拖拽：body（整体移动裁剪区域，不改变大小）
///
/// 约束：
/// - 手柄触摸区域 >= 32x32 像素（hitTest 半径 24px → 48x48 命中区）
/// - 裁剪框不超出 0.0-1.0 边界，最小尺寸 _minSize
/// - 可选 aspectRatio 锁定宽高比
/// - 照片最小缩放 1.0（铺满裁剪区），最大缩放 _maxPhotoScale；
///   平移被夹紧，保证照片始终覆盖裁剪框（不露出空白）
class CropOverlay extends StatefulWidget {
  /// 照片 widget（渲染在裁剪区，可被缩放/平移）。
  /// 需填满整个裁剪区（使用 BoxFit.fill），由本组件叠加变换。
  final Widget photo;

  /// 初始裁剪区域（相对坐标 0.0-1.0）。
  /// 为 null 时自动计算默认区域（自由=满幅；锁定比例=该比例下最大居中矩形），
  /// 并在首帧后通过 [onChanged] 回传，保证「默认选区」与保存结果一致。
  final Rect? initialRect;

  /// 锁定宽高比（width / height，框内相对坐标系下的 w/h）。
  /// 为 null 时可自由调整；> 0 时锁定比例。
  final double? aspectRatio;

  /// 裁剪区域变化回调，返回相对坐标 Rect（0.0-1.0）。
  /// 在拖拽过程中持续触发。
  final ValueChanged<Rect>? onChanged;

  /// 主题色板（用于手柄和边框配色）。
  /// 为 null 时使用默认白色。
  final ThemeTokens? tokens;

  /// 照片变换（旋转/翻转/拉直），叠加在照片上，使裁剪面板下方的操作所见即所得。
  /// 为 null 或恒等变换时不应用。
  final TransformParams? transform;

  const CropOverlay({
    super.key,
    required this.photo,
    this.initialRect,
    this.aspectRatio,
    this.onChanged,
    this.tokens,
    this.transform,
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

  /// 当前激活的手柄类型（单指拖拽中）
  _HandleType _activeHandle = _HandleType.none;

  /// 照片缩放倍数（1.0 = 铺满裁剪区，最小；可放大）
  double _photoScale = 1.0;

  /// 照片平移（相对坐标，相对裁剪区中心）
  Offset _photoOffset = Offset.zero;

  /// 双指手势中上一次的 scale（用于计算增量）
  double _lastScale = 1.0;

  /// 当前是否处于照片变换手势（双指）
  bool _inPhotoGesture = false;

  /// 最近一次回调上层的区域（用于识别"自身回调的回显"，避免重复重置）
  Rect? _lastEmitted;

  /// 最小裁剪尺寸（相对值），防止裁剪区域过小
  static const double _minSize = 0.1;

  /// 手柄触摸半径（像素），>= 16 保证命中区 >= 32x32
  static const double _touchRadius = 24.0;

  /// 照片最小/最大缩放
  static const double _minPhotoScale = 1.0;
  static const double _maxPhotoScale = 5.0;

  @override
  void initState() {
    super.initState();
    _cropRect = widget.initialRect ?? _computeDefaultRect();
    // 默认选区也视为有效选区：首帧后回传，保证不拖拽直接保存时
    // 导出内容 == 屏幕上显示的选框内容（WYSIWYG）。
    if (widget.initialRect == null) {
      _emitPostFrame();
    }
  }

  @override
  void didUpdateWidget(CropOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ratioChanged = widget.aspectRatio != oldWidget.aspectRatio;
    // 忽略"自身回调被上层回显"导致 initialRect 变化的情况，
    // 仅在外部真正改变（切换比例 / 重置 / 加载保存的裁剪）时重置。
    // 用容差比较：上层通过 Rect.fromLTWH(x,y,w,h) 回显时，浮点 round 会让
    // left+width ≠ right（差一个 ULP），精确 == 会误判为外部变化，导致裁剪
    // 框与照片状态被重置，表现为双指缩放/拖拽时图片抖动、裁剪区域跳动。
    final externalRectChanged =
        !_rectNearEqual(widget.initialRect, oldWidget.initialRect) &&
            !_rectNearEqual(widget.initialRect, _lastEmitted);
    if (ratioChanged || externalRectChanged) {
      final usedDefault = widget.initialRect == null;
      _cropRect = widget.initialRect ?? _computeDefaultRect();
      _resetPhoto();
      // 切换比例等重置为默认选区后回传（比例切换后选框变化但用户未拖拽，
      // 若不回传，保存时会沿用旧选区/无选区，与屏幕选框不一致）。
      if (usedDefault) {
        _emitPostFrame();
      }
    }
  }

  /// 下一帧回传当前选区（build 期间不可回调上层，故 post-frame）。
  void _emitPostFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _emit();
    });
  }

  /// 容差比较两个裁剪矩形（相对坐标），忽略 ULP 级浮点误差。
  bool _rectNearEqual(Rect? a, Rect? b, {double eps = 1e-6}) {
    if (a == null || b == null) return a == b;
    return (a.left - b.left).abs() < eps &&
        (a.top - b.top).abs() < eps &&
        (a.right - b.right).abs() < eps &&
        (a.bottom - b.bottom).abs() < eps;
  }

  /// 重置照片变换为基准（铺满裁剪区，居中）
  void _resetPhoto() {
    _photoScale = 1.0;
    _photoOffset = Offset.zero;
    _lastScale = 1.0;
    _inPhotoGesture = false;
  }

  /// 计算默认裁剪区域
  ///
  /// 自由模式默认满幅（[0,0,1,1]）：进入裁剪模式不拖动时，
  /// 选框 == 整张展示照片 → 保存结果与烘焙照片一致（无操作 = 无变化）。
  /// 锁定比例时默认该比例下最大居中矩形（iPhone 原生行为）。
  Rect _computeDefaultRect() {
    if (widget.aspectRatio == null) {
      return const Rect.fromLTWH(0, 0, 1, 1);
    }
    return _centerMaxRect(widget.aspectRatio!);
  }

  /// 在 0-1 范围内计算给定宽高比的最大居中 Rect（不留边距）
  Rect _centerMaxRect(double aspect) {
    double w, h;
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
    final x = (1.0 - w) / 2.0;
    final y = (1.0 - h) / 2.0;
    return Rect.fromLTWH(x, y, w, h);
  }

  /// 命中测试：根据触摸位置（像素）确定手柄类型
  _HandleType _hitTest(Offset localPos, Size size) {
    final crop = Rect.fromLTRB(
      _cropRect.left * size.width,
      _cropRect.top * size.height,
      _cropRect.right * size.width,
      _cropRect.bottom * size.height,
    );

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

    if (crop.contains(localPos)) {
      return _HandleType.body;
    }

    return _HandleType.none;
  }

  // === 手势统一入口（onScale 同时处理单指与多指） ===

  void _onScaleStart(ScaleStartDetails details, Size size) {
    _lastScale = 1.0;
    if (details.pointerCount == 1) {
      _activeHandle = _hitTest(details.localFocalPoint, size);
      _inPhotoGesture = false;
    } else {
      _activeHandle = _HandleType.none;
      _inPhotoGesture = true;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size size) {
    final isMulti = details.pointerCount >= 2;
    if (isMulti != _inPhotoGesture) {
      // 手指数量变化，重置累计基数
      _lastScale = 1.0;
      _inPhotoGesture = isMulti;
      if (isMulti) {
        _activeHandle = _HandleType.none;
      } else {
        _activeHandle = _hitTest(details.localFocalPoint, size);
      }
    }

    if (isMulti) {
      // 双指：缩放 + 平移照片
      final scaleChange = details.scale / _lastScale;
      _lastScale = details.scale;
      _applyPhotoZoom(scaleChange, details.localFocalPoint, size);
      _applyPhotoPan(details.focalPointDelta, size);
    } else {
      // 单指：编辑裁剪框
      if (_activeHandle == _HandleType.body) {
        _moveFrame(details.focalPointDelta, size);
      } else if (_activeHandle != _HandleType.none) {
        _resizeFrame(_activeHandle, details.focalPointDelta, size);
      }
    }

    _emit();
    if (mounted) setState(() {});
  }

  void _onScaleEnd(ScaleEndDetails details) {
    setState(() {
      _activeHandle = _HandleType.none;
      _lastScale = 1.0;
      _inPhotoGesture = false;
    });
  }

  // === 照片变换 ===

  /// 以焦点为中心缩放照片。
  /// [focalPx] 为焦点像素坐标，缩放后保持焦点下的照片内容不动。
  void _applyPhotoZoom(double scaleChange, Offset focalPx, Size size) {
    final s0 = _photoScale;
    final s1 = (s0 * scaleChange).clamp(_minPhotoScale, _maxPhotoScale);
    _photoScale = s1;
    final actual = s1 / s0;
    if (actual == 1.0) return;
    final f = Offset(focalPx.dx / size.width, focalPx.dy / size.height);
    const c = Offset(0.5, 0.5);
    final o0 = _photoOffset;
    final o1 = f - c - (f - c - o0) * actual;
    _photoOffset = o1;
    _clampPhotoOffset();
  }

  /// 平移照片（像素增量 → 相对增量）
  void _applyPhotoPan(Offset deltaPx, Size size) {
    _photoOffset += Offset(deltaPx.dx / size.width, deltaPx.dy / size.height);
    _clampPhotoOffset();
  }

  /// 夹紧照片平移，保证照片始终覆盖裁剪框（不露出空白）。
  /// 照片屏幕覆盖范围 X ∈ [0.5 - 0.5s + ox, 0.5 + 0.5s + ox]，
  /// 需覆盖裁剪框 [F.left, F.right]。
  void _clampPhotoOffset() {
    final s = _photoScale;
    final f = _cropRect;
    final minX = f.right - 0.5 - 0.5 * s;
    final maxX = f.left - 0.5 + 0.5 * s;
    final minY = f.bottom - 0.5 - 0.5 * s;
    final maxY = f.top - 0.5 + 0.5 * s;
    _photoOffset = Offset(
      _photoOffset.dx.clamp(minX, maxX),
      _photoOffset.dy.clamp(minY, maxY),
    );
  }

  /// 照片变换矩阵（相对裁剪区中心缩放到铺满，再平移）
  Matrix4 _photoMatrix(Size size) {
    final s = _photoScale;
    final c = Offset(size.width / 2, size.height / 2);
    final oPx = Offset(_photoOffset.dx * size.width, _photoOffset.dy * size.height);
    return Matrix4.identity()
      ..translate(c.dx * (1 - s) + oPx.dx, c.dy * (1 - s) + oPx.dy, 0)
      ..scale(s);
  }

  /// 叠加旋转/翻转/拉直变换到照片上（与全屏预览一致，所见即所得）。
  /// 使用 Transform 而非 RotatedBox，避免改变布局盒导致照片被拉伸/留黑边。
  Widget _applyTransform(Widget child) {
    final t = widget.transform;
    if (t == null || t.isIdentity) return child;
    return Transform.rotate(
      angle: t.rotation * math.pi / 180.0,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..scale(t.flipH ? -1.0 : 1.0, t.flipV ? -1.0 : 1.0, 1.0),
        child: Transform.rotate(
          angle: t.straighten * math.pi / 180.0,
          child: child,
        ),
      ),
    );
  }

  /// 计算最终保留的照片区域（裁剪框经照片变换反算，相对 0-1）。
  ///
  /// 展示层把照片先缩放/平移（[_photoMatrix]）再叠加旋转/翻转/拉直
  /// （[_applyTransform]）。用户框选的是变换后的展示坐标，因此：
  /// 1. 先反算缩放/平移，得到照片经过旋转/翻转后所在盒内的轴对齐区域；
  /// 2. 再逆变换（撤销 rotation→flip→straighten），映射回【未变换照片】的
  ///    0-1 坐标——与 processFile「先按原图裁剪、后应用变换」的 customCropRect
  ///    语义一致，保证「框选内容 == 导出内容」（WYSIWYG）。
  Rect _photoRectInFrame() {
    final s = _photoScale;
    final ox = _photoOffset.dx;
    final oy = _photoOffset.dy;
    final f = _cropRect;
    final frame = Rect.fromLTRB(
      (f.left - 0.5 - ox) / s + 0.5,
      (f.top - 0.5 - oy) / s + 0.5,
      (f.right - 0.5 - ox) / s + 0.5,
      (f.bottom - 0.5 - oy) / s + 0.5,
    );
    return PhotoPostProcessor.invertCropTransform(frame, widget.transform);
  }

  /// 回调上层当前保留区域
  void _emit() {
    final rect = _photoRectInFrame();
    _lastEmitted = rect;
    widget.onChanged?.call(rect);
  }

  // === 裁剪框编辑 ===

  void _moveFrame(Offset deltaPx, Size size) {
    final dx = deltaPx.dx / size.width;
    final dy = deltaPx.dy / size.height;
    final newLeft = (_cropRect.left + dx)
        .clamp(0.0, math.max(0.0, 1.0 - _cropRect.width))
        .toDouble();
    final newTop = (_cropRect.top + dy)
        .clamp(0.0, math.max(0.0, 1.0 - _cropRect.height))
        .toDouble();
    _cropRect = Rect.fromLTWH(newLeft, newTop, _cropRect.width, _cropRect.height);
  }

  /// 通过手柄缩放裁剪框。[deltaPx] 为本次手势增量（像素）。
  void _resizeFrame(_HandleType handle, Offset deltaPx, Size size) {
    final dx = deltaPx.dx / size.width;
    final dy = deltaPx.dy / size.height;

    Rect newRect = _cropRect;

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
      case _HandleType.none:
        return;
    }

    if (widget.aspectRatio != null) {
      newRect = _enforceAspectRatio(newRect, widget.aspectRatio!, handle);
    }

    _cropRect = _clampToBounds(newRect);
  }

  /// 在拖拽手柄时保持宽高比
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
    final width = rect.width.clamp(0.0, 1.0).toDouble();
    final height = rect.height.clamp(0.0, 1.0).toDouble();
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
        return ClipRect(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (d) => _onScaleStart(d, size),
            onScaleUpdate: (d) => _onScaleUpdate(d, size),
            onScaleEnd: _onScaleEnd,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 照片层（可缩放/平移 + 叠加旋转/翻转/拉直）
                Positioned.fill(
                  child: Transform(
                    transform: _photoMatrix(size),
                    child: IgnorePointer(child: _applyTransform(widget.photo)),
                  ),
                ),
                // 裁剪框层（固定不随照片变换）
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _CropOverlayPainter(
                        cropRect: _cropRect,
                        activeHandle: _activeHandle,
                        tokens: widget.tokens,
                      ),
                    ),
                  ),
                ),
              ],
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
  final Rect cropRect;
  final _HandleType activeHandle;
  final ThemeTokens? tokens;

  _CropOverlayPainter({
    required this.cropRect,
    required this.activeHandle,
    this.tokens,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pixelRect = Rect.fromLTRB(
      cropRect.left * size.width,
      cropRect.top * size.height,
      cropRect.right * size.width,
      cropRect.bottom * size.height,
    );

    // === 1. 半透明遮罩 ===
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
    for (int i = 1; i < 3; i++) {
      final x = pixelRect.left + pixelRect.width * i / 3;
      canvas.drawLine(
          Offset(x, pixelRect.top), Offset(x, pixelRect.bottom), gridPaint);
    }
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