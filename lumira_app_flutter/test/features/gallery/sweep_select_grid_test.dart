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
            child: SweepAlbumGrid(
              sections: sections,
              scrollController: controller ?? ScrollController(),
              idOf: (i) => 'id$i',
              selectedIds: selected,
              onSelectionChanged: onChanged,
              isMultiSelectMode: multiSelect,
              crossAxisCount: 3,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              horizontalPadding: EdgeInsets.zero,
              bottomPadding: 0,
              maxSelectable: maxSelectable,
              onMaxReached: onMaxReached,
              itemBuilder: (_, flat, isSelected) => Container(
                key: ValueKey('cell_$flat'),
                color: isSelected ? Colors.blue : Colors.grey,
              ),
              headerBuilder: (_, s) => SizedBox(
                height: 30,
                child: Text('header_${sections[s].id}'),
              ),
            ),
          ),
        ),
      );
    }

    Offset center(WidgetTester tester, int index) =>
        tester.getCenter(find.byKey(ValueKey('cell_$index')));

    testWidgets('多选态下按下即选，拖动连续加选，回扫取消', (tester) async {
      var snap = <String>{};
      await tester.pumpWidget(
        buildHarness(
          sections: [const SweepAlbumSection(id: 'a', photoCount: 6)],
          multiSelect: true,
          selected: <String>{},
          onChanged: (next) => snap = next,
        ),
      );

      // 多选态下无需长按，按下即选中起点。
      final g = await tester.startGesture(center(tester, 0));
      await tester.pump();
      expect(snap, {'id0'});

      await g.moveTo(center(tester, 1));
      await tester.pump();
      expect(snap, {'id0', 'id1'});

      // 滑到第二行中间（cell4）：路径补齐加入。
      await g.moveTo(center(tester, 4));
      await tester.pump();
      expect(snap, {'id0', 'id1', 'id4'});

      // 回扫回到 cell1：cell1 取消选中。
      await g.moveTo(center(tester, 1));
      await tester.pump();
      expect(snap, {'id0', 'id4'});

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

      await g.moveTo(center(tester, 1));
      await tester.pump();
      expect(snap, isEmpty);

      await g.up();
      await tester.pump();
    });

    testWidgets('跨分区路径连续选择', (tester) async {
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

      final g = await tester.startGesture(center(tester, 2));
      await tester.pump();
      expect(snap, {'id2'});

      // 从第一分区末列滑入第二分区同列：跨分区边界连续选择，无需打断
      // （2=(0,2) -> 5=(1,2) 同列垂直，不产生斜向内插格）。
      await g.moveTo(center(tester, 5));
      await tester.pump();
      expect(snap, {'id2', 'id5'});

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
      await tester.pump();
      expect(snap, {'id0'});

      // 尝试再加选 cell1：被 maxSelectable 拦截。
      await g.moveTo(center(tester, 1));
      await tester.pump();
      expect(snap, {'id0'}); // 未加成
      expect(warn, 1);

      // 继续滑到 cell2 也拦截，但只提示一次。
      await g.moveTo(center(tester, 2));
      await tester.pump();
      expect(snap, {'id0'});
      expect(warn, 1);

      // 回扫取消 cell0 后，可再加选。
      await g.moveTo(center(tester, 0));
      await tester.pump();
      expect(snap, isEmpty);

      await g.up();
      await tester.pump();
    });
  });
}