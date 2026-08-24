import 'package:flutter/gestures.dart';
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

  group('SweepSelectGrid 滑动多选', () {
    Widget buildHarness(Set<String> selected, ValueChanged<Set<String>> onChanged) {
      return MaterialApp(
        // Center 包裹可避免 home 被紧约束撑满全屏，使 300 宽度生效，
        // 从而让下方按 300 宽推导的 center() 坐标与网格几何一致。
        home: Center(
          child: SizedBox(
            width: 300,
            height: 320,
            child: SweepSelectGrid(
              itemCount: 6,
              idOf: (i) => 'id$i',
              selectedIds: selected,
              onSelectionChanged: onChanged,
              crossAxisCount: 3,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              padding: EdgeInsets.zero,
              itemBuilder: (_, i, isSelected, startSweep) {
                return GestureDetector(
                  onTap: () {},
                  onLongPress: () => startSweep(),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    key: ValueKey('cell_$i'),
                    color: isSelected ? Colors.blue : Colors.grey,
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    // 直接用每个 cell（ValueKey）的实际全局中心坐标，避免手工推导布局偏移。
    Offset center(WidgetTester tester, int index) =>
        tester.getCenter(find.byKey(ValueKey('cell_$index')));

    testWidgets('长按选中起点，拖动经格子连续加选，回扫取消', (tester) async {
      final selected = <String>{};
      var selectedSnapshot = <String>{};
      await tester.pumpWidget(
        buildHarness(selected, (next) {
          selectedSnapshot = next;
        }),
      );

      // 长按 cell0
      final g = await tester.startGesture(center(tester, 0));
      await tester.pump(kLongPressTimeout + kPressTimeout);
      expect(selectedSnapshot, {'id0'});

      // 向右滑过 cell1、cell2
      await g.moveTo(center(tester, 1));
      await tester.pump();
      expect(selectedSnapshot, {'id0', 'id1'});

      await g.moveTo(center(tester, 2));
      await tester.pump();
      expect(selectedSnapshot, {'id0', 'id1', 'id2'});

      // 滑到第二行中间（cell4）：路径补一格后加入
      await g.moveTo(center(tester, 4));
      await tester.pump();
      expect(selectedSnapshot, {'id0', 'id1', 'id2', 'id4'});

      // 回扫回到 cell1：cell1 取消选中
      await g.moveTo(center(tester, 1));
      await tester.pump();
      expect(selectedSnapshot, {'id0', 'id2', 'id4'});

      await g.up();
      await tester.pump();
    });

    testWidgets('maxSelectable 拦截加分并只触发一次提示', (tester) async {
      final selected = <String>{};
      var selectedSnapshot = <String>{};
      var maxWarnCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 300,
              height: 320,
              child: SweepSelectGrid(
                itemCount: 4,
                idOf: (i) => 'id$i',
                selectedIds: selected,
                onSelectionChanged: (next) => selectedSnapshot = next,
                maxSelectable: 1,
                onMaxReached: () => maxWarnCount++,
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                padding: EdgeInsets.zero,
                itemBuilder: (_, i, isSelected, startSweep) {
                  return GestureDetector(
                    onLongPress: () => startSweep(),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      key: ValueKey('cell_$i'),
                      color: isSelected ? Colors.blue : Colors.grey,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      final g = await tester.startGesture(center(tester, 0));
      await tester.pump(kLongPressTimeout + kPressTimeout);
      expect(selectedSnapshot, {'id0'});

      // 尝试再加选 cell1：被 maxSelectable 拦截
      await g.moveTo(center(tester, 1));
      await tester.pump();
      expect(selectedSnapshot, {'id0'}); // 未加成
      expect(maxWarnCount, 1);

      // 继续滑到 cell2 也拦截，但只提示一次
      await g.moveTo(center(tester, 2));
      await tester.pump();
      expect(selectedSnapshot, {'id0'});
      expect(maxWarnCount, 1);

      // 回扫取消 cell0 后，可再加选 cell1
      await g.moveTo(center(tester, 0));
      await tester.pump();
      expect(selectedSnapshot, isEmpty);

      await g.up();
      await tester.pump();
    });
  });
}