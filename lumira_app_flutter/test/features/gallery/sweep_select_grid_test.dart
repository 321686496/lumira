import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/features/gallery/widgets/sweep_select_grid.dart';

void main() {
  group('GridGeometry.indicesOnSegment', () {
    test('同格返回自身', () {
      expect(GridGeometry.indicesOnSegment(4, 4, 3), [4]);
    });

    test('同行的水平路径填充中间格', () {
      // (0,0)->(0,2)：应包含 0,1,2
      expect(GridGeometry.indicesOnSegment(0, 2, 3), [0, 1, 2]);
    });

    test('同列垂直路径填充中间格', () {
      // (0,1)->(2,1)：应包含 1,4,7
      expect(GridGeometry.indicesOnSegment(1, 7, 3), [1, 4, 7]);
    });

    test('斜向路径做直线插值且去重', () {
      // (0,2)->(1,0)：steps=2，几何中点 (0.5,1.0) 取整为 (1,1)
      // => (0,2),(1,1),(1,0)
      expect(GridGeometry.indicesOnSegment(2, 3, 3), [2, 4, 3]);
    });
  });

  group('GridGeometry.indicesInRange', () {
    test('同索引返回自身', () {
      expect(GridGeometry.indicesInRange(3, 3), [3]);
    });

    test('正向区间包含中间的每一个索引', () {
      expect(GridGeometry.indicesInRange(2, 5), [2, 3, 4, 5]);
    });

    test('反向区间等价于正向（回扫用同一段）', () {
      expect(GridGeometry.indicesInRange(5, 2), [2, 3, 4, 5]);
    });

    test('起点大于终点且相邻时返回两个索引', () {
      expect(GridGeometry.indicesInRange(4, 3), [3, 4]);
    });
  });

  group('GridGeometry.cellAt', () {
    const cross = 3;
    const cellW = 96.0;
    const cellH = 96.0;
    const spacing = 6.0;
    const padding = EdgeInsets.zero;

    test('第一格（左上角内）返回 0', () {
      expect(
        GridGeometry.cellAt(
          local: const Offset(10, 10),
          scrollOffset: 0,
          crossAxisCount: cross,
          itemCount: 6,
          cellWidth: cellW,
          cellHeight: cellH,
          mainSpacing: spacing,
          crossSpacing: spacing,
          padding: padding,
        ),
        0,
      );
    });

    test('第二格中心返回 1', () {
      expect(
        GridGeometry.cellAt(
          local: const Offset(cellW + spacing, 10),
          scrollOffset: 0,
          crossAxisCount: cross,
          itemCount: 6,
          cellWidth: cellW,
          cellHeight: cellH,
          mainSpacing: spacing,
          crossSpacing: spacing,
          padding: padding,
        ),
        1,
      );
    });

    test('第二行第一格（带滚动偏移）返回 3', () {
      expect(
        GridGeometry.cellAt(
          local: const Offset(10, 10),
          scrollOffset: cellH + spacing, // 内容已往上滚一行
          crossAxisCount: cross,
          itemCount: 6,
          cellWidth: cellW,
          cellHeight: cellH,
          mainSpacing: spacing,
          crossSpacing: spacing,
          padding: padding,
        ),
        3,
      );
    });

    test('超出内容数量返回 null', () {
      expect(
        GridGeometry.cellAt(
          local: const Offset(9999, 9999),
          scrollOffset: 0,
          crossAxisCount: cross,
          itemCount: 6,
          cellWidth: cellW,
          cellHeight: cellH,
          mainSpacing: spacing,
          crossSpacing: spacing,
          padding: padding,
        ),
        isNull,
      );
    });
  });

  group('SweepAlbumGrid 滑动多选', () {
    Widget buildHarness({
      required List<SweepAlbumSection> sections,
      required bool multiSelect,
      required Set<String> selected,
      required ValueChanged<Set<String>> onChanged,
      ScrollController? controller,
      int? maxSelectable,
      VoidCallback? onMaxReached,
    }) {
      return MaterialApp(
        // Center 包裹可避免 home 被紧约束撑满全屏，使 300 宽度生效。
        home: Center(
          child: SizedBox(
            width: 300,
            height: 320,
            child: _HarnessHost(
              sections: sections,
              multiSelect: multiSelect,
              initialSelected: selected,
              onChanged: onChanged,
              controller: controller ?? ScrollController(),
              maxSelectable: maxSelectable,
              onMaxReached: onMaxReached,
            ),
          ),
        ),
      );
    }

    Offset center(WidgetTester tester, int index) =>
        tester.getCenter(find.byKey(ValueKey('cell_$index')));

    testWidgets('多选态下点按抬起才切换选中（点击两次取消）', (tester) async {
      var snap = <String>{};
      await tester.pumpWidget(
        buildHarness(
          sections: [const SweepAlbumSection(id: 'a', photoCount: 6)],
          multiSelect: true,
          selected: <String>{},
          onChanged: (next) => snap = next,
        ),
      );

      // 仅按下不选中：需要方向判定（横向拖动）或抬起（点按）才生效
      final g1 = await tester.startGesture(center(tester, 0));
      await tester.pump();
      expect(snap, isEmpty);

      await g1.up();
      await tester.pump();
      expect(snap, {'id0'});

      final g2 = await tester.startGesture(center(tester, 0));
      await g2.up();
      await tester.pump();
      expect(snap, isEmpty);
    });

    testWidgets('多选态下纵向拖动滚动列表且不选中', (tester) async {
      final controller = ScrollController();
      var snap = <String>{};
      await tester.pumpWidget(
        buildHarness(
          sections: [const SweepAlbumSection(id: 'a', photoCount: 24)],
          multiSelect: true,
          selected: <String>{},
          onChanged: (next) => snap = next,
          controller: controller,
        ),
      );
      addTearDown(controller.dispose);

      final g = await tester.startGesture(center(tester, 0));
      await tester.pump();
      // 纵向拖动：超出 touch slop 后由列表自身接管滚动，不产生任何选中。
      await g.moveBy(const Offset(0, -30));
      await tester.pump();
      await g.moveBy(const Offset(0, -60));
      await tester.pump();

      expect(controller.offset, greaterThan(0));
      expect(snap, isEmpty);

      await g.up();
      await tester.pump();
    });

    testWidgets('多选态下横向拖动进入滑动多选并连续加选', (tester) async {
      var snap = <String>{};
      await tester.pumpWidget(
        buildHarness(
          sections: [const SweepAlbumSection(id: 'a', photoCount: 12)],
          multiSelect: true,
          selected: <String>{},
          onChanged: (next) => snap = next,
        ),
      );

      final g = await tester.startGesture(center(tester, 0));
      await tester.pump();
      expect(snap, isEmpty);

      // 横向拖动锁定「滑动多选」：起点格立即入选中
      await g.moveBy(const Offset(30, 0));
      await tester.pump();
      expect(snap, {'id0'});

      await g.moveBy(const Offset(96, 0));
      await tester.pump();
      expect(snap, {'id0', 'id1'});

      await g.up();
      await tester.pump();
    });

    testWidgets('横向进入多选后下滑，中间照片按索引区间补选且列表不滚动', (tester) async {
      final controller = ScrollController();
      var snap = <String>{};
      await tester.pumpWidget(
        buildHarness(
          sections: [const SweepAlbumSection(id: 'a', photoCount: 12)],
          multiSelect: true,
          selected: <String>{},
          onChanged: (next) => snap = next,
          controller: controller,
        ),
      );
      addTearDown(controller.dispose);

      final g = await tester.startGesture(center(tester, 0));
      await g.moveBy(const Offset(30, 0));
      await tester.pump();
      await g.moveBy(const Offset(96, 0));
      await tester.pump();
      await g.moveBy(const Offset(96, 0)); // 滑到第一行最后一格 cell2
      await tester.pump();
      expect(snap, {'id0', 'id1', 'id2'});

      // 下移到第二行同列 cell5：2~5 之间的每一个索引都要被补选（3、4 不能漏）
      await g.moveBy(const Offset(0, 102));
      await tester.pump();
      expect(snap, {'id0', 'id1', 'id2', 'id3', 'id4', 'id5'});

      // 已锁定滑动多选 → 纵向移动只扩展选中，列表不滚动
      expect(controller.offset, 0);

      await g.up();
      await tester.pump();
    });

    testWidgets('未进入多选态按下/拖动不触发选择', (tester) async {
      var snap = <String>{};
      await tester.pumpWidget(
        buildHarness(
          sections: [const SweepAlbumSection(id: 'a', photoCount: 6)],
          multiSelect: false,
          selected: <String>{},
          onChanged: (next) => snap = next,
        ),
      );

      final g = await tester.startGesture(center(tester, 0));
      await tester.pump();
      expect(snap, isEmpty);

      await g.moveBy(const Offset(96, 0));
      await tester.pump();
      expect(snap, isEmpty);

      await g.up();
      await tester.pump();
      expect(snap, isEmpty);
    });

    testWidgets('跨分区滑动多选按相册顺序连续补选', (tester) async {
      var snap = <String>{};
      await tester.pumpWidget(
        buildHarness(
          sections: [
            const SweepAlbumSection(id: 'a', photoCount: 3),
            const SweepAlbumSection(id: 'b', photoCount: 3),
          ],
          multiSelect: true,
          selected: <String>{},
          onChanged: (next) => snap = next,
        ),
      );

      final g = await tester.startGesture(center(tester, 0));
      await g.moveBy(const Offset(96, 0));
      await tester.pump();
      await g.moveBy(const Offset(96, 0)); // 第一分区末列 cell2
      await tester.pump();
      expect(snap, {'id0', 'id1', 'id2'});

      // 从第一分区末列滑入第二分区同列（cell5）：跨分区按索引区间连续补选
      await g.moveBy(const Offset(0, 126));
      await tester.pump();
      expect(snap, {'id0', 'id1', 'id2', 'id3', 'id4', 'id5'});

      await g.up();
      await tester.pump();
    });

    testWidgets('滑动到靠底边缘时自动向下滚动', (tester) async {
      final controller = ScrollController();
      var snap = <String>{};
      await tester.pumpWidget(
        buildHarness(
          sections: [const SweepAlbumSection(id: 'a', photoCount: 24)],
          multiSelect: true,
          selected: <String>{},
          onChanged: (next) => snap = next,
          controller: controller,
        ),
      );
      addTearDown(controller.dispose);

      final g = await tester.startGesture(center(tester, 0));
      await g.moveBy(const Offset(30, 0)); // 先横向锁定滑动多选
      await tester.pump();
      expect(snap, {'id0'});
      expect(controller.offset, 0);

      // 把指针移到可视区底部（超过 bottom-edge 阈值 → 向下自动滚动）。
      final bottom = tester.getBottomLeft(find.byType(SweepAlbumGrid));
      await g.moveTo(bottom + const Offset(10, -6));
      await tester.pump();

      expect(controller.offset, greaterThan(0));

      await g.up();
      await tester.pump();
    });

    testWidgets('maxSelectable 拦截加分并只提示一次', (tester) async {
      var snap = <String>{};
      var warn = 0;
      await tester.pumpWidget(
        buildHarness(
          sections: [const SweepAlbumSection(id: 'a', photoCount: 6)],
          multiSelect: true,
          selected: <String>{},
          onChanged: (next) => snap = next,
          maxSelectable: 1,
          onMaxReached: () => warn++,
        ),
      );

      final g = await tester.startGesture(center(tester, 0));
      await g.moveBy(const Offset(30, 0));
      await tester.pump();
      expect(snap, {'id0'});

      // 尝试再加选 cell1：被 maxSelectable 拦截。
      await g.moveBy(const Offset(96, 0));
      await tester.pump();
      expect(snap, {'id0'}); // 未加成
      expect(warn, 1);

      // 继续滑到 cell2 也拦截，但只提示一次。
      await g.moveBy(const Offset(96, 0));
      await tester.pump();
      expect(snap, {'id0'});
      expect(warn, 1);

      await g.up();
      await tester.pump();
    });
  });
}

/// 承载选中集状态的测试宿主：像真实相册页那样在 `onSelectionChanged` 后
/// `setState` 回写选中集，使 [SweepAlbumGrid] 每次重建都能拿到最新选中集
/// （否则「点按切换」等以外部选中集为基准的行为无法被正确验证）。
class _HarnessHost extends StatefulWidget {
  const _HarnessHost({
    required this.sections,
    required this.multiSelect,
    required this.initialSelected,
    required this.onChanged,
    required this.controller,
    this.maxSelectable,
    this.onMaxReached,
  });

  final List<SweepAlbumSection> sections;
  final bool multiSelect;
  final Set<String> initialSelected;
  final ValueChanged<Set<String>> onChanged;
  final ScrollController controller;
  final int? maxSelectable;
  final VoidCallback? onMaxReached;

  @override
  State<_HarnessHost> createState() => _HarnessHostState();
}

class _HarnessHostState extends State<_HarnessHost> {
  late Set<String> _selected = Set<String>.of(widget.initialSelected);

  @override
  Widget build(BuildContext context) {
    return SweepAlbumGrid(
      sections: widget.sections,
      scrollController: widget.controller,
      idOf: (i) => 'id$i',
      selectedIds: _selected,
      onSelectionChanged: (next) {
        setState(() => _selected = Set<String>.of(next));
        widget.onChanged(next);
      },
      isMultiSelectMode: widget.multiSelect,
      crossAxisCount: 3,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      horizontalPadding: EdgeInsets.zero,
      bottomPadding: 0,
      maxSelectable: widget.maxSelectable,
      onMaxReached: widget.onMaxReached,
      itemBuilder: (_, flat, isSelected) => Container(
        key: ValueKey('cell_$flat'),
        color: isSelected ? Colors.blue : Colors.grey,
      ),
      headerBuilder: (_, s) => SizedBox(
        height: 30,
        child: Text('header_${widget.sections[s].id}'),
      ),
    );
  }
}