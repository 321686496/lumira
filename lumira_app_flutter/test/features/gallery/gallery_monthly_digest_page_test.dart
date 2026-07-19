import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/features/gallery/pages/gallery_monthly_digest_page.dart';
import '../../../test/helpers/test_http_overrides.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = TestHttpOverrides();
  });

  testWidgets('renders cover section with title', (tester) async {
    // Forced fix: brief 用 `await tester.binding.window.setPhysicalSizeTestValue(...)`
    // 但 setPhysicalSizeTestValue 返回 void，await void 会触发 use_of_void_result lint 错误。
    // 改用 setter 赋值形式（与 challenge_page_test.dart / home_page_test.dart 同模式）。
    // Forced fix: brief 用 800x2400 视口，但页面总高 ~2664dp（封面 + 4 行照片墙 1540 +
    // 本月精选 314 + 总结卡 150 + 场景足迹 80 + CTA 100 + Footer 30 + 间距），CTA / Footer
    // 在 2400 视口下为 offstage。增大视口到 800x3200 让所有 sections 进入可视区。
    tester.binding.window.physicalSizeTestValue = const Size(800, 3200);
    // Forced fix: 不设 devicePixelRatio=1.0 时默认 ~3.0，逻辑视口仅 ~266×1066，
    // 内容溢出 / offstage 导致 findsOneWidget 失败。与 challenge_page_test.dart 同模式。
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: GalleryMonthlyDigestPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('7月摄影手帐'), findsOneWidget);
    expect(find.text('我的 7 月摄影手帐'), findsOneWidget);
    expect(find.text('Lumira · Monthly Digest'), findsOneWidget);
    expect(find.text('张照片'), findsOneWidget);
    expect(find.text('个模板'), findsOneWidget);
    expect(find.text('个场景'), findsOneWidget);
  });

  testWidgets('renders photo grid and selected sections', (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(800, 3200);
    // Forced fix: 不设 devicePixelRatio=1.0 时默认 ~3.0，逻辑视口仅 ~266×1066，
    // 内容溢出 / offstage 导致 findsOneWidget 失败。与 challenge_page_test.dart 同模式。
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: GalleryMonthlyDigestPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('月份照片墙'), findsOneWidget);
    expect(find.text('共 32 张'), findsOneWidget);
    expect(find.text('本月精选'), findsOneWidget);
    expect(find.text('3 张'), findsOneWidget);
    // 本月精选标题
    expect(find.text('河畔金色的午后'), findsOneWidget);
    expect(find.text('城市夜雨'), findsOneWidget);
    expect(find.text('山间晨雾'), findsOneWidget);
  });

  testWidgets('renders summary section with quote', (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(800, 3200);
    // Forced fix: 不设 devicePixelRatio=1.0 时默认 ~3.0，逻辑视口仅 ~266×1066，
    // 内容溢出 / offstage 导致 findsOneWidget 失败。与 challenge_page_test.dart 同模式。
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: GalleryMonthlyDigestPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('7月拍摄总结'), findsOneWidget);
    expect(find.textContaining('天有拍摄'), findsOneWidget);
    expect(find.textContaining('这个月你记录了'), findsOneWidget);
  });

  testWidgets('renders scene tags section', (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(800, 3200);
    // Forced fix: 不设 devicePixelRatio=1.0 时默认 ~3.0，逻辑视口仅 ~266×1066，
    // 内容溢出 / offstage 导致 findsOneWidget 失败。与 challenge_page_test.dart 同模式。
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: GalleryMonthlyDigestPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('场景足迹'), findsOneWidget);
    expect(find.text('城市'), findsOneWidget);
    expect(find.text('自然'), findsOneWidget);
    expect(find.text('室内'), findsOneWidget);
    expect(find.text('美食'), findsOneWidget);
  });

  testWidgets('renders CTA buttons and footer branding', (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(800, 3200);
    // Forced fix: 不设 devicePixelRatio=1.0 时默认 ~3.0，逻辑视口仅 ~266×1066，
    // 内容溢出 / offstage 导致 findsOneWidget 失败。与 challenge_page_test.dart 同模式。
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: GalleryMonthlyDigestPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('生成手帐长图'), findsOneWidget);
    expect(find.text('分享手帐'), findsOneWidget);
    expect(find.textContaining('如你所见'), findsOneWidget);
  });
}
