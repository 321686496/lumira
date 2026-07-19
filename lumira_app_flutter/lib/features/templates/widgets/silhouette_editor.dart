import 'package:flutter/material.dart';

/// 剪影编辑器对话框（简化版）
///
/// 视觉规格来源：lumira-app/src/components/SilhouetteEditor.vue（~500 行）
///
/// 调用方式（brief §3.3）：通过 `showDialog<void>` 调用，对话框自关闭通过 `Navigator.pop(ctx)`
///
/// 简化范围（brief §3.3 + §8.2 已知简化决策 #2）：
/// - ✅ 画笔/橡皮/撤销/重做/清空/画笔粗细滑块
/// - ❌ 参考线配置（Task 2.9+ 补全）
/// - ❌ 参考图上传（Task 2.9+ 补全）
class SilhouetteEditorDialog extends StatefulWidget {
  const SilhouetteEditorDialog({super.key, this.onComplete});

  /// 完成回调，参数为生成的 SVG 字符串
  final void Function(String svg)? onComplete;

  @override
  State<SilhouetteEditorDialog> createState() => _SilhouetteEditorDialogState();
}

class _SilhouetteEditorDialogState extends State<SilhouetteEditorDialog> {
  String _tool = 'brush'; // 'brush' / 'eraser'
  double _brushSize = 8.0; // 2.0 ~ 30.0
  final List<_DrawPath> _paths = [];
  final List<_DrawPath> _redoStack = [];
  bool _isDrawing = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            _buildToolbar(),
            const SizedBox(height: 8),
            _buildBrushSizeSlider(),
            const SizedBox(height: 12),
            _buildCanvas(),
            const SizedBox(height: 12),
            _buildHint(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.close, size: 22),
          ),
        ),
        const Expanded(
          child: Text(
            '绘制剪影',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        GestureDetector(
          onTap: _onComplete,
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Text(
              '完成',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        _ToolButton(
          label: '画笔',
          icon: Icons.brush,
          active: _tool == 'brush',
          onTap: () => setState(() => _tool = 'brush'),
        ),
        _ToolButton(
          label: '橡皮',
          icon: Icons.auto_fix_high_outlined,
          active: _tool == 'eraser',
          onTap: () => setState(() => _tool = 'eraser'),
        ),
        _ToolButton(
          label: '撤销',
          icon: Icons.undo,
          active: false,
          onTap: _undo,
        ),
        _ToolButton(
          label: '重做',
          icon: Icons.redo,
          active: false,
          onTap: _redo,
        ),
        _ToolButton(
          label: '清空',
          icon: Icons.delete_outline,
          active: false,
          onTap: _clear,
        ),
      ],
    );
  }

  Widget _buildBrushSizeSlider() {
    return Row(
      children: [
        const Text(
          '画笔粗细',
          style: TextStyle(fontSize: 12),
        ),
        Expanded(
          child: Slider(
            value: _brushSize,
            min: 2.0,
            max: 30.0,
            divisions: 28,
            label: _brushSize.toStringAsFixed(0),
            onChanged: (v) => setState(() => _brushSize = v),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            _brushSize.toStringAsFixed(0),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildCanvas() {
    return AspectRatio(
      aspectRatio: 300 / 480,
      child: Container(
        // 硬编码颜色，与 uni-app 一致（preview-bg: linear-gradient(135deg, #3A3631 0%, #2A2622 100%)）
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3A3631), Color(0xFF2A2622)],
          ),
        ),
        child: GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: CustomPaint(
            painter: _DrawPainter(
              paths: _paths,
              // 硬编码颜色，与 uni-app 一致（canvas-bg: #2A2622）
              canvasBgColor: const Color(0xFF2A2622),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }

  Widget _buildHint() {
    return const Text(
      '在画布上绘制轮廓，完成后将自动保存为 SVG 矢量剪影',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, color: Colors.black54),
    );
  }

  // === 绘制事件 ===

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDrawing = true;
      _paths.add(_DrawPath(
        points: [details.localPosition],
        width: _brushSize,
        eraser: _tool == 'eraser',
      ));
      _redoStack.clear();
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDrawing) return;
    setState(() {
      if (_paths.isNotEmpty) {
        _paths.last.points.add(details.localPosition);
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDrawing = false;
    });
  }

  // === 工具操作 ===

  void _undo() {
    if (_paths.isEmpty) return;
    setState(() {
      _redoStack.add(_paths.removeLast());
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _paths.add(_redoStack.removeLast());
    });
  }

  void _clear() {
    setState(() {
      _paths.clear();
      _redoStack.clear();
    });
  }

  void _onComplete() {
    final svg = _exportSvg();
    widget.onComplete?.call(svg);
  }

  String _exportSvg() {
    final visiblePaths = _paths.where((p) => !p.eraser).toList();
    final pathsXml = visiblePaths.map((p) {
      final d = p.points.asMap().entries.map((e) {
        final cmd = e.key == 0 ? 'M' : 'L';
        return '$cmd ${e.value.dx.round()} ${e.value.dy.round()}';
      }).join(' ');
      return '<path d="$d" stroke="#fff" stroke-width="${p.width}" stroke-linecap="round" stroke-linejoin="round" fill="none"/>';
    }).join('');
    return '<svg viewBox="0 0 300 480" xmlns="http://www.w3.org/2000/svg">$pathsXml</svg>';
  }
}

/// 一条绘制路径（用于 SilhouetteEditor）
class _DrawPath {
  _DrawPath({
    required this.points,
    required this.width,
    required this.eraser,
  });

  final List<Offset> points;
  final double width;
  final bool eraser;
}

/// 绘制画笔 CustomPainter
class _DrawPainter extends CustomPainter {
  _DrawPainter({
    required this.paths,
    required this.canvasBgColor,
  });

  final List<_DrawPath> paths;
  final Color canvasBgColor;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in paths) {
      final color = p.eraser ? canvasBgColor : Colors.white;
      if (p.points.length < 2) {
        // 单点：用圆点表示
        final paint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(p.points.first, p.width / 2, paint);
        continue;
      }
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = p.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()..moveTo(p.points.first.dx, p.points.first.dy);
      for (int i = 1; i < p.points.length; i++) {
        path.lineTo(p.points[i].dx, p.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DrawPainter oldDelegate) {
    // 始终重绘：paths 是可变列表，引用相同但内容可能已变更
    return true;
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Theme.of(context).primaryColor : Colors.black12,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? Colors.white : Colors.black87),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: active ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
