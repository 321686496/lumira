import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 相册时间分区的一个数据模型：分区 id + 照片数量（用于扁平化索引映射）。
class SweepAlbumSection {
  const SweepAlbumSection({required this.id, required this.photoCount});
  final String id;
  final int photoCount;
}

/// 相册级滑动多选驱动（仿 iPhone 原生相册多选手势）。
///
/// 交互（多选态）：
/// - **上下滑动 = 滚动视图**：多选态下网格保持可滚动，纵向拖动由
///   [CustomScrollView] 自身接管（原生惯性 / 回弹），不产生任何选中。
/// - **左右滑动 = 滑动多选**：横向拖动超过 touch slop 后锁定为滑动多选，
///   以按下的那一格为起点立即选中，继续拖动按**索引区间**连续补选。
/// - **方向锁定**：一次手势只会成为「滚动」或「滑动多选」其中之一，锁定后不再切换
///   （纵向拖动不会被选照片打断，横向拖动期间也不会滚动列表）。
/// - **点按 = 切换选中**：未超过点击容差即抬起时，翻转该格选中态。
/// - **区间补选**：从「上一张」移动到「当前这张」时，按相册顺序把这个索引区间内的
///   照片全部补上（[GridGeometry.indicesInRange]），因此横向滑过一行后向下滑到下方
///   照片，中间被掠过的照片也会一并选中。
/// - **跨分区连续**：内部把多个时间分区渲染进**同一个 CustomScrollView**，
///   照片按分区顺序扁平化成一个连续的网格索引空间（分区头不占索引），
///   因此从当前分区滑到下一分区无需打断即可连续选择。
/// - **到底自动滚动**：滑动多选期间手指接近可视区上/下边缘时，自动调用
///   [ScrollController.jumpTo] 让列表滚动，把下方更多图片带入视口继续选择。
/// - **非多选态**：格子由调用方决定（点击看图 / 长按进入多选并把该格设为滑动起点）；
///   长按进入后手指不抬起即可继续拖动连续选。
///
/// 手势的所有权与方向仲裁：
/// - 多选态下本组件在整棵 [CustomScrollView] 外层挂一个只注册
///   [HorizontalDragGestureRecognizer] 的 `RawGestureDetector`。它与滚动视图自身的
///   纵向拖动识别器同处一个手势竞技场：谁先在各自方向上超过 touch slop 谁获胜，
///   另一方被 rejected —— 这就是方向锁定，无需手工判断位移。
/// - 本组件另用**裸 [Listener]** 接收原始 pointer 事件（不进竞技场，不参与仲裁）：
///   负责命中格子、驱动区间补选、边缘自动滚动，以及在「点按抬起」时翻转选中态。
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

  /// 是否已进入多选态。为 true 时启用「横向拖动 = 滑动多选、纵向拖动 = 滚动、
  /// 点按 = 切换选中」的方向仲裁；为 false 时全部手势交给格子自身（点击看图 /
  /// 长按进入多选）。
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

  /// 本次手势按下的位置（用于判断是否属于「点按」）。
  Offset? _downPosition;
  bool _pointerDown = false;

  /// 扁平照片索引 → GlobalObjectKey（命中测试用；懒加载下仅挂载格有 currentContext）。
  List<GlobalKey> _cellKeys = const [];

  int get _totalPhotos =>
      widget.sections.fold(0, (s, e) => s + e.photoCount);

  @override
  void dispose() {
    _cellKeys = const [];
    super.dispose();
  }

  /// 把某扁平索引设为滑动起点并选中它（横向拖动锁定滑动多选 / 长按进入多选共用）。
  ///
  /// 长按进入多选时调用方先 `setState(isMultiSelectMode = true)` 再调用本方法，
  /// 此刻本组件尚未重建，因此这里不做多选态判断。
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
    // 索引区间补选：把「上一张 → 当前这张」之间被掠过的照片全部翻转，
    // 快速拖动跨行 / 跨分区时也不会漏选中间的格。
    final seg = GridGeometry.indicesInRange(_lastFlat, cur);
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
    if (!widget.isMultiSelectMode) return;
    _pointerDown = true;
    _downPosition = event.position;
  }

  void _handleMove(PointerMoveEvent event) {
    if (!_sweeping) return; // 未锁定滑动多选（滚动方向）时不选中任何格
    final flat = _hitTestFlatIndex(event.position);
    if (flat != null) _stepTo(flat);
    _autoScroll(event.position);
  }

  /// 点按抬起：未超过点击容差且未进入滑动多选时，翻转该格选中态。
  void _handleUp(PointerUpEvent event) {
    final wasSweeping = _sweeping;
    final down = _downPosition;
    final tracked = _pointerDown && widget.isMultiSelectMode;
    _pointerDown = false;
    _downPosition = null;
    _endSweep();
    if (!tracked || wasSweeping || down == null) return;
    if ((event.position - down).distance > kTouchSlop) return; // 属于拖动，不当作点按
    final flat = _hitTestFlatIndex(event.position);
    if (flat == null) return;
    _dragSelected = Set<String>.of(widget.selectedIds); // 以外部最新选中集为准
    _toggleIndex(flat);
  }

  void _handleCancel() {
    _pointerDown = false;
    _downPosition = null;
    _endSweep();
  }

  /// 横向拖动获胜（方向锁定为滑动多选）：以按下那一格为起点开始连续选择。
  ///
  /// 该识别器与滚动视图自身的纵向拖动识别器同处一个竞技场，横向获胜即意味着
  /// 纵向识别器被 rejected —— 本手势后续的纵向移动只会扩展选中，不会滚动列表。
  void _handleHorizontalDragStart(DragStartDetails details) {
    beginSweep(_hitTestFlatIndex(details.globalPosition) ?? -1);
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

    // 多选态下额外注册横向拖动识别器：靠竞技场与滚动视图的纵向拖动识别器做方向锁定。
    final gestures = <Type, GestureRecognizerFactory>{};
    if (widget.isMultiSelectMode) {
      gestures[HorizontalDragGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<HorizontalDragGestureRecognizer>(
        () => HorizontalDragGestureRecognizer(),
        (instance) {
          // 以「按下那一格」为滑动起点，而不是识别发生的位置
          instance.dragStartBehavior = DragStartBehavior.down;
          instance.onStart = _handleHorizontalDragStart;
        },
      );
    }

    return Listener(
      onPointerDown: _handleDown,
      onPointerMove: _handleMove,
      onPointerUp: _handleUp,
      onPointerCancel: (_) => _handleCancel(),
      child: RawGestureDetector(
        gestures: gestures,
        child: CustomScrollView(
          controller: widget.scrollController,
          // 多选态同样保持可滚动：上下滑动永远是「滑动视图」。
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: slivers,
        ),
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

  /// 返回从索引 [a] 到索引 [b]（含两端）的**整个索引区间**（升序、去重）。
  ///
  /// 相册网格按「行优先」把照片展平成连续索引，因此这一段索引就是照片在相册中的
  /// 自然先后顺序。滑动多选时用它补选「上一张 → 当前这张」之间被手指掠过的照片，
  /// 避免快速拖动时中间格被漏选（[indicesOnSegment] 只取直线路径，会留空洞）。
  static List<int> indicesInRange(int a, int b) {
    final hi = math.max(a, b);
    final lo = math.max(0, math.min(a, b));
    if (hi < lo) return const [];
    return [for (var i = lo; i <= hi; i++) i];
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