import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 照片网格滑动多选工具（仿 iPhone 原生相册 / 微信选图）。
///
/// 交互：
/// - **长按某一格** → 选中该格，并保持按住即可开始**滑动批量选**；
/// - 手指移动进入新格时，按直线插值把路径上每个格「翻转」一次选中状态：
///   向前滑连续加选，反向回扫即可取消；
/// - 松手结束本次滑动。
///
/// 手势的所有权：
/// - 每个格子自身的点按/长按由调用方通过 [itemBuilder] 的 `startSweep` 回调自定
///   —— 长按某格时调用 `startSweep()` 即可把该格作为滑动起点（顺带把页面切到多选）。
/// - 本组件用一个**裸 [Listener]** 包住整个网格，在长按之后的拖拽过程中接收
///   原始指针移动，据此命中后续格子并连续加/减选，不与格子的手势产生竞技冲突。
class SweepSelectGrid extends StatefulWidget {
  const SweepSelectGrid({
    super.key,
    required this.itemCount,
    required this.idOf,
    required this.itemBuilder,
    required this.selectedIds,
    required this.onSelectionChanged,
    this.crossAxisCount = 3,
    this.mainAxisSpacing = 6,
    this.crossAxisSpacing = 6,
    this.padding = EdgeInsets.zero,
    this.aspectRatio = 1,
    this.shrinkWrap = false,
    this.physics,
    this.maxSelectable,
    this.onMaxReached,
  });

  /// 照片数量。
  final int itemCount;

  /// 把格子索引映射为唯一 id（选中集按 id 计量）。
  final String Function(int index) idOf;

  /// 构建格子的可视内容。`startSweep` 应挂在格子自己的长按回调上，用于把该格作为滑动起点。
  ///
  /// ```dart
  /// itemBuilder: (_, i, isSelected, startSweep) => GestureDetector(
  ///   onTap: () => onTapCell(i),
  ///   onLongPress: () { enterMultiSelect(); startSweep(); },
  ///   child: myCell(isSelected: isSelected),
  /// )
  /// ```
  final Widget Function(BuildContext context, int index, bool isSelected,
      VoidCallback startSweep) itemBuilder;

  /// 外部持有的选中集合。
  final Set<String> selectedIds;

  /// 选中集合变化回调（返回新的完整集合）。
  final ValueChanged<Set<String>> onSelectionChanged;

  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final EdgeInsets padding;
  final double aspectRatio;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  /// 最大可选数量；null 表示不限。滑动加选超过上限时被忽略。
  final int? maxSelectable;

  /// 加选被 [maxSelectable] 拦截时触发（如提示“已达上限”），同一次滑动只触发一次。
  final VoidCallback? onMaxReached;

  @override
  State<SweepSelectGrid> createState() => _SweepSelectGridState();
}

class _SweepSelectGridState extends State<SweepSelectGrid> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _gridKey = GlobalKey();

  double _cellWidth = 0;
  double _cellHeight = 0;

  bool _sweeping = false;
  int _lastIndex = -1;
  Set<String> _dragSelected = <String>{};
  bool _maxWarned = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 格子长按时调用：把该格设为滑动起点并选中它，随后随手指移动连续加/减选。
  void _beginSweep(int index) {
    if (index < 0 || index >= widget.itemCount) return;
    _sweeping = true;
    _lastIndex = index;
    _maxWarned = false;
    _dragSelected = Set<String>.of(widget.selectedIds);
    _toggleIndex(index);
  }

  void _toggleIndex(int index) {
    if (index < 0 || index >= widget.itemCount) return;
    final next = _toggleReturn(_dragSelected, index);
    if (next == _dragSelected) return;
    _dragSelected = next;
    widget.onSelectionChanged(Set<String>.of(next));
  }

  /// 翻转一个格子的选中态，并在达到 [maxSelectable] 时拦截加分。
  Set<String> _toggleReturn(Set<String> src, int index) {
    final id = widget.idOf(index);
    final s = Set<String>.of(src);
    if (s.contains(id)) {
      s.remove(id); // 回扫取消永远允许
      return s;
    }
    if (widget.maxSelectable != null && s.length >= widget.maxSelectable!) {
      _warnMax();
      return src; // 已达上限，忽略加分
    }
    s.add(id);
    return s;
  }

  void _warnMax() {
    if (_maxWarned) return;
    _maxWarned = true;
    widget.onMaxReached?.call();
  }

  void _stepTo(int cur) {
    if (!_sweeping) return;
    if (cur == _lastIndex || cur < 0 || cur >= widget.itemCount) return;
    final seg = GridGeometry.indicesOnSegment(
        _lastIndex, cur, widget.crossAxisCount);
    var accum = _dragSelected;
    for (final i in seg) {
      if (i == _lastIndex) continue; // 起点上一步已翻转，避免重复
      accum = _toggleReturn(accum, i);
    }
    _lastIndex = cur;
    if (!setEquals(accum, _dragSelected)) {
      _dragSelected = accum;
      HapticFeedback.selectionClick();
      widget.onSelectionChanged(Set<String>.of(accum));
    }
  }

  void _endSweep() {
    if (!_sweeping) return;
    _sweeping = false;
    _lastIndex = -1;
  }

  void _handleMove(PointerMoveEvent event) {
    if (!_sweeping) return;
    final box = _gridKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final local = box.globalToLocal(event.position);
    final index = GridGeometry.cellAt(
      local: local,
      scrollOffset:
          _scrollController.hasClients ? _scrollController.offset : 0,
      crossAxisCount: widget.crossAxisCount,
      itemCount: widget.itemCount,
      cellWidth: _cellWidth,
      cellHeight: _cellHeight,
      mainSpacing: widget.mainAxisSpacing,
      crossSpacing: widget.crossAxisSpacing,
      padding: widget.padding,
    );
    if (index != null) _stepTo(index);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final innerWidth = constraints.maxWidth -
            widget.padding.horizontal -
            (widget.crossAxisCount - 1) * widget.crossAxisSpacing;
        if (innerWidth <= 0) return const SizedBox.shrink();
        final cross = widget.crossAxisCount > 0 ? widget.crossAxisCount : 1;
        _cellWidth = innerWidth / cross;
        _cellHeight = _cellWidth / widget.aspectRatio;
        return Listener(
          onPointerMove: _handleMove,
          onPointerUp: (_) => _endSweep(),
          onPointerCancel: (_) => _endSweep(),
          child: GridView.builder(
            key: _gridKey,
            controller: _scrollController,
            shrinkWrap: widget.shrinkWrap,
            physics: widget.physics ??
                const ClampingScrollPhysics(
                    parent: BouncingScrollPhysics()),
            padding: widget.padding,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cross,
              mainAxisSpacing: widget.mainAxisSpacing,
              crossAxisSpacing: widget.crossAxisSpacing,
              childAspectRatio: widget.aspectRatio,
            ),
            itemCount: widget.itemCount,
            itemBuilder: (_, i) {
              final isSelected =
                  widget.selectedIds.contains(widget.idOf(i));
              return widget.itemBuilder(
                  context, i, isSelected, () => _beginSweep(i));
            },
          ),
        );
      },
    );
  }
}

/// 照片网格的几何计算（纯函数，便于单元测试）。
class GridGeometry {
  const GridGeometry._();

  static int rowOf(int index, int crossAxisCount) =>
      crossAxisCount <= 0 ? 0 : index ~/ crossAxisCount;

  static int colOf(int index, int crossAxisCount) =>
      crossAxisCount <= 0 ? 0 : index % crossAxisCount;

  /// 把网格内的一个偏移量映射为格子索引；超出内容区域返回 null。
  ///
  /// [scrollOffset]：滚动式网格的滚动偏移（内容第 0 行对应的偏移）。
  static int? cellAt({
    required Offset local,
    required double scrollOffset,
    required int crossAxisCount,
    required int itemCount,
    required double cellWidth,
    required double cellHeight,
    required double mainSpacing,
    required double crossSpacing,
    required EdgeInsets padding,
  }) {
    if (cellWidth <= 0 || cellHeight <= 0 || crossAxisCount <= 0) return null;
    final x = local.dx - padding.left;
    final y = local.dy + scrollOffset - padding.top;
    if (x < 0 || y < 0) return null;
    final col = (x ~/ (cellWidth + crossSpacing)).clamp(0, crossAxisCount - 1);
    final row = y ~/ (cellHeight + mainSpacing);
    final index = row * crossAxisCount + col;
    if (index < 0 || index >= itemCount) return null;
    return index;
  }

  /// 返回从索引 [a] 到 [b]（含两端）的直线路径索引列表（去重）。
  static List<int> indicesOnSegment(int a, int b, int crossAxisCount) {
    if (crossAxisCount <= 0) return [math.max(0, a)];
    if (a == b) return [a];
    final ra = rowOf(a, crossAxisCount);
    final ca = colOf(a, crossAxisCount);
    final rb = rowOf(b, crossAxisCount);
    final cb = colOf(b, crossAxisCount);
    final dr = rb - ra;
    final dc = cb - ca;
    final steps = math.max(dr.abs(), dc.abs());
    final result = <int>[];
    var last = -1;
    for (var t = 0; t <= steps; t++) {
      final r = ra + (dr * t / steps).round();
      final c = ca + (dc * t / steps).round();
      final idx = r * crossAxisCount + c;
      if (idx != last) {
        result.add(idx);
        last = idx;
      }
    }
    return result;
  }
}