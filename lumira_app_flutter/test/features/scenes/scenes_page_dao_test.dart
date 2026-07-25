import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/scenes/pages/scenes_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Task A3 — ScenesPage DAO 接入测试
///
/// brief §3.4：验证 ScenesPage 在接入 scenesDaoProvider 后仍能正常 build 并显示标题。
/// 此测试为 intentionally weak（brief 说明更详尽的测试在 Task 6 集成）。
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('ScenesPage builds and displays 场景库 title', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ScenesPage()),
    ));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 验证 "场景库" 标题出现（nav 标题 + 摘要卡片中都有此文本，故用 findsAtLeastNWidgets）
    expect(find.text('场景库'), findsAtLeastNWidgets(1));
  });
}
