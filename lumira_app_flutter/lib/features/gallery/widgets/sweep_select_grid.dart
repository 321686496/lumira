import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 相册时间分区的一个数据模型：分区 id + 照片数量（用于扁平化索引映射）。
class SweepAlbumSection {
  const SweepAlbumSection({required this.id, required this.photoCount});
  final String id;
  final int photoCount;
}

/// 相册级滑动多选驱动（仿 iPhone 原生相册 / 微信选图）。
///
/// 交互：
/// - **非多选态**：格子由调用方决定（点击看图 / 长按进入多选并把该格设为滑动起点）。
/// - **多选态**：手指**一按下任一图片即选中该格并进入滑动**，拖动时按网格路径
///   连续加选，反向回扫即可取消；无需再次长按。
/// - **跨分区连续**：内部把多个时间分区渲染进**同一个 CustomScrollView**，
///   照片按分区顺序扁平化成一个连续的网格索引空间（分区头不占索引），
///   因此从当前分区滑到下一分区无需打断即可连续选择。
/// - **到底自动滚动**：滑动时手指接近可视区上/下边缘，自动调用
///   [ScrollController.jumpTo] 让列表滚动，把下方更多图片带入视口继续选择。
///
/// 手势的所有权：
/// - 本组件用**裸 [Listener]** 包住整棵 CustomScrollView，接收原始 pointer 的
///   down / move / up，据此命中格子并驱动滑动选择 + 自动滚动（不进手势竞技场，
///   不与点击 / 长按 / 滚动竞技）。
/// - 格子定位不依赖手工几何：每个照片格挂 `GlobalObjectKey('album_cell_$i')`，
///   命中时遍历已挂载格的 RenderBox 全局矩形，得到精确的扁平索引
///   （懒加载 sliver 下只会挂载可视格，遍历成本低）。
class SweepAlbumGrid extends StatefulWidget {
  const SweepAlbumGrid({
    super.key,
    required this.sections,
    required this.idOf,
    required this.itemBuilder,
    required this.headerBuilder,
    required this.selectedIds,
    required this.onSelectionChanged,
    required this.isMultiSelectMode,
    required this.scrollController,
    this.crossAxisCount = 3,
    this.mainAxisSpacing = 6,
    this.crossAxisSpacing = 6,
    this.horizontalPadding = EdgeInsets.zero,
    this.bottomPadding = 0,
    this.maxSelectable,
    this.onMaxReached,
  });

  /// 各时间分区（顺序决定扁平化索引顺序）。
  final List<SweepAlbumSection> sections;

  /// 把扁平照片索引映射为唯一 id（选中集按 id 计量）。
  final String Function(int flatIndex) idOf;

  /// 构建某扁平索引对应的照片格。
  final Widget Function(BuildContext context, int flatIndex, bool isSelected)
      itemBuilder;

  /// 构建某分区头（不参与选择）。
  final Widget Function(BuildContext context, int sectionIndex) headerBuilder;

  /// 外部持有的选中集合。
  final Set<String> selectedIds;

  /// 选中集合变化回调（返回新的完整集合）。
  final ValueChanged<Set<String>> onSelectionChanged;

  /// 是否已进入多选态。为 true 时按下即选 + 禁用手势滚动（由本组件接管拖动）。
  final bool isMultiSelectMode;

  /// 供自动滚动使用的滚动控制器（本组件渲染的 CustomScrollView 使用它）。
  final ScrollController scrollController;

  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;

  /// 网格区域的水平内边距（分区网格整体缩进）。
  final EdgeInsets horizontalPadding;

  /// 列表底部预留高度（给多选操作栏 / 提示文字）。
  final double bottomPadding;

  /// 最大可选数量；null 表示不限。滑动加选超过上限时被忽略。
  final int? maxSelectable;

  /// 加选被 [maxSelectable] 拦截时触发（如提示“已达上限”），同一次滑动只触发一次。
  final VoidCallback? onMaxReached;

  @override
  State<SweepAlbumGrid> createState() => SweepAlbumGridState();
}

class SweepAlbumGridState extends State<SweepAlbumGrid> {
  bool _sweeping = false;
  int _lastFlat = -1;
  Set<String> _dragSelected = <String>{};
  bool _maxWarned = false;

  /// 扁平照片索引 → GlobalObjectKey（命中测试用；懒加载下仅挂载格有 currentContext）。
  List<GlobalKey> _cellKeys = const [];

  int get _totalPhotos =>
      widget.sections.fold(0, (s, e) => s + e.photoCount);

  @override
  void dispose() {
    _cellKeys = const [];
    super.dispose();
  }

  /// 把某扁平索引设为滑动起点并选中它（长按进入多选 / 多选态按下共用）。
  void beginSweep(int flatIndex) {
    if (flatIndex < 0 || flatIndex >= _totalPhotos) return;
    _sweeping = true;
    _lastFlat = flatIndex;
    _maxWarned = false;
    _dragSelected = Set<String>.of(widget.selectedIds);
    _toggleIndex(flatIndex);
  }

  void _toggleIndex(int flatIndex) {
    if (flatIndex < 0 || flatIndex >= _totalPhotos) return;
    final next = _toggleReturn(_dragSelected, flatIndex);
    if (next == _dragSelected) return;
    _dragSelected = next;
    widget.onSelectionChanged(Set<String>.of(next));
  }

  /// 翻转一个格子的选中态，并在达到 [maxSelectable] 时拦截加分。
  Set<String> _toggleReturn(Set<String> src, int flatIndex) {
    final id = widget.idOf(flatIndex);
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
    if (cur == _lastFlat || cur < 0 || cur >= _totalPhotos) return;
    final seg = GridGeometry.indicesOnSegment(
        _lastFlat, cur, widget.crossAxisCount);
    var accum = _dragSelected;
    for (final i in seg) {
      if (i == _lastFlat) continue; // 起点上一步已翻转，避免重复
      accum = _toggleReturn(accum, i);
    }
    _lastFlat = cur;
    if (!setEquals(accum, _dragSelected)) {
      _dragSelected = accum;
      HapticFeedback.selectionClick();
      widget.onSelectionChanged(Set<String>.of(accum));
    }
  }

  void _endSweep() {
    if (!_sweeping) return;
    _sweeping = false;
    _lastFlat = -1;
  }

  /// 命中指针位置的照片格扁平索引；命中空白/未挂载区域返回 null。
  int? _hitTestFlatIndex(Offset position) {
    for (var i = 0; i < _cellKeys.length; i++) {
      final ctx = _cellKeys[i].currentContext;
      if (ctx == null) continue; // 懒加载下未挂载
      final ro = ctx.findRenderObject();
      if (ro is! RenderBox || !ro.attached) continue;
      final rect = ro.localToGlobal(Offset.zero) & ro.size;
      if (rect.contains(position)) return i;
    }
    return null;
  }

  void _handleDown(PointerDownEvent event) {
    if (!widget.isMultiSelectMode) return; // 未进入多选态不触发滑动
    final flat = _hitTestFlatIndex(event.position);
    if (flat != null) beginSweep(flat);
  }

  void _handleMove(PointerMoveEvent event) {
    if (!_sweeping) return;
    final flat = _hitTestFlatIndex(event.position);
    if (flat != null) _stepTo(flat);
    _autoScroll(event.position);
  }

  /// 手指接近可视区上/下边缘时自动滚动，让更多图片进入视口继续选择。
  void _autoScroll(Offset position) {
    if (!_sweeping) return;
    if (!widget.scrollController.hasClients) return;
    try {
      final position2 = widget.scrollController.position;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.attached) return;
      final top = box.localToGlobal(Offset.zero).dy;
      final bottom = top + box.size.height;
      const edge = 72.0;
      const step = 26.0;
      if (position.dy > bottom - edge &&
          position2.pixels < position2.maxScrollExtent) {
        position2
            .jumpTo(math.min(position2.pixels + step, position2.maxScrollExtent));
      } else if (position.dy < top + edge && position2.pixels > 0) {
        position2.jumpTo(math.max(position2.pixels - step, 0.0));
      }
    } catch (_) {
      // 滚动位置尚未就绪时忽略本次自动滚动
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalPhotos;
    _cellKeys = List<GlobalKey>.generate(
      total,
      (i) => GlobalObjectKey<State<StatefulWidget>>('album_cell_$i'),
    );

    // 预计算每个分区的扁平起始下标。
    final starts = <int>[];
    var acc = 0;
    for (final s in widget.sections) {
      starts.add(acc);
      acc += s.photoCount;
    }

    final physics = widget.isMultiSelectMode
        ? const NeverScrollableScrollPhysics()
        : const AlwaysScrollableScrollPhysics();

    final slivers = <Widget>[];
    for (var s = 0; s < widget.sections.length; s++) {
      final sec = widget.sections[s];
      slivers.add(SliverToBoxAdapter(child: widget.headerBuilder(context, s)));
      slivers.add(
        SliverPadding(
          padding: widget.horizontalPadding,
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: widget.crossAxisCount,
              mainAxisSpacing: widget.mainAxisSpacing,
              crossAxisSpacing: widget.crossAxisSpacing,
              childAspectRatio: 1,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, localIndex) {
                final flat = starts[s] + localIndex;
                final id = widget.idOf(flat);
                return KeyedSubtree(
                  key: _cellKeys[flat],
                  child: widget.itemBuilder(
                    context,
                    flat,
                    widget.selectedIds.contains(id),
                  ),
                );
              },
              childCount: sec.photoCount,
            ),
          ),
        ),
      );
    }
    slivers.add(
      SliverToBoxAdapter(child: SizedBox(height: widget.bottomPadding)),
    );

    return Listener(
      onPointerDown: _handleDown,
      onPointerMove: _handleMove,
      onPointerUp: (_) => _endSweep(),
      onPointerCancel: (_) => _endSweep(),
      child: CustomScrollView(
        controller: widget.scrollController,
        physics: physics,
        slivers: slivers,
      ),
    );
  }
}

/// 通用「扁平网格」滑动多选（照片选择器的单区网格场景）。
///
/// 与 [SweepAlbumGrid] 的区别：没有「时间分区 / 自动滚动 / 多选态开关」，
/// 选择入口由调用方的 [itemBuilder] 里的 `startSweep()` 回调触发（通常是
/// 长按某格进入），随后拖动按 [GridGeometry] 路径连续加选 / 回扫取消。
/// 点击查看与滑动选择互不干扰（点击不进滑动）。
class SweepSelectGrid extends StatefulWidget {
  const SweepSelectGrid({
    super.key,
    required this.itemCount,
    required this.idOf,
    required this.itemBuilder,
    required this.selectedIds,
    required this.onSelectionChanged,
    this.maxSelectable,
    this.onMaxReached,
    this.crossAxisCount = 3,
    this.mainAxisSpacing = 10,
    this.crossAxisSpacing = 10,
    this.padding = EdgeInsets.zero,
    this.aspectRatio = 1,
  });

  final int itemCount;

  /// 把格子索引映射为唯一 id（选中集按 id 计量）。
  final String Function(int index) idOf;

  /// 构建某格子；[startSweep] 回调用于把该格设为滑动起点（长按住触发）。
  final Widget Function(BuildContext context, int index, bool isSelected,
      VoidCallback startSweep) itemBuilder;

  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onSelectionChanged;
  final int? maxSelectable;
  final VoidCallback? onMaxReached;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final EdgeInsets padding;
  final double aspectRatio;

  @override
  State<SweepSelectGrid> createState() => SweepSelectGridState();
}

class SweepSelectGridState extends State<SweepSelectGrid> {
  bool _sweeping = false;
  int _lastFlat = -1;
  Set<String> _dragSelected = <String>{};
  bool _maxWarned = false;

  List<GlobalKey> _cellKeys = const [];

  @override
  void dispose() {
    _cellKeys = const [];
    super.dispose();
  }

  void beginSweep(int flatIndex) {
    if (flatIndex < 0 || flatIndex >= widget.itemCount) return;
    _sweeping = true;
    _lastFlat = flatIndex;
    _maxWarned = false;
    _dragSelected = Set<String>.of(widget.selectedIds);
    _toggleIndex(flatIndex);
  }

  void _toggleIndex(int flatIndex) {
    if (flatIndex < 0 || flatIndex >= widget.itemCount) return;
    final next = _toggleReturn(_dragSelected, flatIndex);
    if (next == _dragSelected) return;
    _dragSelected = next;
    widget.onSelectionChanged(Set<String>.of(next));
  }

  Set<String> _toggleReturn(Set<String> src, int flatIndex) {
    final id = widget.idOf(flatIndex);
    final s = Set<String>.of(src);
    if (s.contains(id)) {
      s.remove(id);
      return s;
    }
    if (widget.maxSelectable != null && s.length >= widget.maxSelectable!) {
      _warnMax();
      return src;
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
    if (cur == _lastFlat || cur < 0 || cur >= widget.itemCount) return;
    final seg =
        GridGeometry.indicesOnSegment(_lastFlat, cur, widget.crossAxisCount);
    var accum = _dragSelected;
    for (final i in seg) {
      if (i == _lastFlat) continue;
      accum = _toggleReturn(accum, i);
    }
    _lastFlat = cur;
    if (!setEquals(accum, _dragSelected)) {
      _dragSelected = accum;
      HapticFeedback.selectionClick();
      widget.onSelectionChanged(Set<String>.of(accum));
    }
  }

  void _endSweep() {
    if (!_sweeping) return;
    _sweeping = false;
    _lastFlat = -1;
  }

  int? _hitTestFlatIndex(Offset position) {
    for (var i = 0; i < _cellKeys.length; i++) {
      final ctx = _cellKeys[i].currentContext;
      if (ctx == null) continue;
      final ro = ctx.findRenderObject();
      if (ro is! RenderBox || !ro.attached) continue;
      final rect = ro.localToGlobal(Offset.zero) & ro.size;
      if (rect.contains(position)) return i;
    }
    return null;
  }

  void _handleDown(PointerDownEvent event) {
    // 选择入口完全由 itemBuilder 的 startSweep() 决定（通常长按），按下不直接选择。
  }

  void _handleMove(PointerMoveEvent event) {
    if (!_sweeping) return;
    final flat = _hitTestFlatIndex(event.position);
    if (flat != null) _stepTo(flat);
  }

  @override
  Widget build(BuildContext context) {
    _cellKeys = List<GlobalKey>.generate(
      widget.itemCount,
      (i) => GlobalObjectKey<State<StatefulWidget>>('grid_cell_$i'),
    );

    return Listener(
      onPointerDown: _handleDown,
      onPointerMove: _handleMove,
      onPointerUp: (_) => _endSweep(),
      onPointerCancel: (_) => _endSweep(),
      child: GridView.builder(
        padding: widget.padding,
        physics: const BouncingScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.crossAxisCount,
          mainAxisSpacing: widget.mainAxisSpacing,
          crossAxisSpacing: widget.crossAxisSpacing,
          childAspectRatio: widget.aspectRatio,
        ),
        itemCount: widget.itemCount,
        itemBuilder: (context, i) {
          final id = widget.idOf(i);
          return KeyedSubtree(
            key: _cellKeys[i],
            child: widget.itemBuilder(
              context,
              i,
              widget.selectedIds.contains(id),
              () => beginSweep(i),
            ),
          );
        },
      ),
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