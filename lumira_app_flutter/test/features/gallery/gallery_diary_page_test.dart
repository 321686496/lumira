import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/features/gallery/pages/gallery_diary_page.dart';
import '../../../test/helpers/test_http_overrides.dart';
import 'dart:io';

void main() {
  setUpAll(() {
    HttpOverrides.global = TestHttpOverrides();
  });

  testWidgets('renders diary entries timeline', (tester) async {
    // Forced fix: brief 用 `await tester.binding.window.setPhysicalSizeTestValue(...)`
    // 但 setPhysicalSizeTestValue 返回 void，await void 会触发 use_of_void_result lint 错误。
    // 改用 setter 赋值形式（与 challenge_page_test.dart / home_page_test.dart 同模式）。
    // Forced fix: brief 用 800x1800 视口，但 5 个 entries 每 entry ~552dp
    // （cellWidth=332 × 3/2 ratio + tags + padding）= ~2760dp + 顶部 256dp = ~3016dp，
    // 1800 视口不足，'07/05' / '07/04' 为 offstage，find.text 找不到。
    // 增大视口到 800x3400 让所有 entries 进入可视区。
    tester.binding.window.physicalSizeTestValue = const Size(800, 3400);
    // Forced fix: 不设 devicePixelRatio=1.0 时默认 ~3.0，逻辑视口仅 ~266×1133，
    // 内容溢出 / offstage 导致 findsOneWidget 失败。与 challenge_page_test.dart 同模式。
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: GalleryDiaryPage()),
    ));
    await tester.pumpAndSettle();

    // Forced fix: brief 期望 `find.text('穿搭日记'), findsOneWidget`，但 brief File 9
    // 实现同时包含 AppBar title（动态：outfit 时为 '穿搭日记'）+ toggle outfit item
    // （'穿搭日记'），共 2 处 Text。改为 findsWidgets（≥1）。
    expect(find.text('穿搭日记'), findsWidgets);
    expect(find.text('时间轴'), findsOneWidget);
    expect(find.text('5篇'), findsOneWidget);
    // 5 个 entries 的日期
    expect(find.text('07/08'), findsOneWidget);
    expect(find.text('07/07'), findsOneWidget);
    expect(find.text('07/06'), findsOneWidget);
    expect(find.text('07/05'), findsOneWidget);
    expect(find.text('07/04'), findsOneWidget);
  });

  testWidgets('renders streak banner with text', (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(800, 3400);
    // Forced fix: 不设 devicePixelRatio=1.0 时默认 ~3.0，逻辑视口仅 ~266×1133，
    // 内容溢出 / offstage 导致 findsOneWidget 失败。与 challenge_page_test.dart 同模式。
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: GalleryDiaryPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('连续打卡 7'), findsOneWidget);
    expect(find.text('继续保持，解锁「周更达人」徽章'), findsOneWidget);
  });

  testWidgets('toggles between outfit and shoot tabs', (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(800, 3400);
    // Forced fix: 不设 devicePixelRatio=1.0 时默认 ~3.0，逻辑视口仅 ~266×1133，
    // 内容溢出 / offstage 导致 findsOneWidget 失败。与 challenge_page_test.dart 同模式。
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: GalleryDiaryPage()),
    ));
    await tester.pumpAndSettle();

    // 默认 outfit tab 激活：title='穿搭日记' + toggle '穿搭日记' = 2 处
    expect(find.text('穿搭日记'), findsWidgets);

    await tester.tap(find.text('拍摄日记').first);
    await tester.pumpAndSettle();

    // shoot tab 激活后：title 动态切换为 '拍摄日记'，仅 toggle 中 '穿搭日记' 文字保留
    expect(find.text('穿搭日记'), findsOneWidget);
  });
}
