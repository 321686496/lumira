import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/templates/data/templates_management_mock_data.dart';
import 'package:lumira_app_flutter/features/templates/pages/templates_drafts_page.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

/// Task 2.8B — TemplatesDraftsPage 测试
///
/// 覆盖 brief 第 5.1 节 ≥10 项断言 + cross-theme/cross-style smoke test。
/// 草稿列表读取真实 template_drafts 表（v51），测试用 ffi 内存库种子 3 条草稿。
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

  late Database _db;

  /// 构造一条 template_drafts 行载荷（TemplateRecord.toRow 期望的列结构）。
  Map<String, Object?> draftRow(
    String id,
    String name,
    String category,
    double ev,
    int iso,
    String shutter,
    int updatedAt,
  ) {
    return {
      Tables.colId: id,
      Tables.colName: name,
      Tables.colAuthor: '',
      Tables.colVersion: '1.0.0',
      Tables.colCategory: category,
      Tables.colClassificationJson: jsonEncode({'type': category}),
      Tables.colTagsJson: '[]',
      Tables.colTagIdsJson: '[]',
      Tables.colPrice: 0,
      Tables.colCover: '',
      Tables.colCoverData: null,
      Tables.colImagesJson: '[]',
      Tables.colDescription: '',
      Tables.colReferenceSource: '',
      Tables.colShortDesc: '',
      Tables.colAmbienceJson: '{}',
      Tables.colCompositionJson: '{}',
      Tables.colPoseJson: '[]',
      Tables.colCameraJson: jsonEncode({
        'exposureCompensation': ev,
        'isoMode': 'auto',
        'iso': iso,
        'shutterSpeed': shutter,
        'whiteBalance': 'daylight',
        'whiteBalanceK': 5500,
        'flashMode': 'off',
        'focusMode': 'auto',
        'lensSuggestion': 'main',
      }),
      Tables.colSceneGuideJson: '{}',
      Tables.colPostProcessJson: '{}',
      Tables.colIsBuiltin: 0,
      Tables.colIsRecommended: 0,
      Tables.colSource: 'custom',
      Tables.colCreatedAt: updatedAt,
      Tables.colUpdatedAt: updatedAt,
    };
  }

  Future<void> seedDraft(
    String id,
    String name,
    String category,
    double ev,
    int iso,
    String shutter,
    int updatedAt,
  ) async {
    final payload = jsonEncode(
      draftRow(id, name, category, ev, iso, shutter, updatedAt),
    );
    await _db.insert(Tables.templateDrafts, {
      Tables.colId: id,
      Tables.colPayload: payload,
      Tables.colUpdatedAt: updatedAt,
    });
  }

  setUpAll(() async {
    _db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, v) async {
        await db.execute(TemplatesDraftsTable.createSql);
      },
    );
  });

  setUp(() async {
    await _db.delete(Tables.templateDrafts);
    final now = DateTime.now().millisecondsSinceEpoch;
    await seedDraft('draft-1', '咖啡馆人像草稿', 'portrait', 0.7, 400, '1/125s',
        now - 2 * 60 * 60 * 1000);
    await seedDraft('draft-2', '日落风光草稿', 'landscape', -0.3, 200, '1/60s',
        now - 3 * 24 * 60 * 60 * 1000);
    await seedDraft('draft-3', '街拍黑白草稿', 'street', 1.0, 800, '1/250s',
        now - 15 * 24 * 60 * 60 * 1000);
  });

  Widget wrap({required ThemeKey themeKey, required UIStyle uiStyle}) {
    final goRouter = GoRouter(
      initialLocation: '/templates/drafts',
      routes: [
        GoRoute(
          path: '/templates/drafts',
          name: 'templatesDrafts',
          builder: (_, __) => const TemplatesDraftsPage(),
        ),
        GoRoute(
          path: RouteNames.templatesEditor,
          name: 'templatesEditor',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('EDITOR_PAGE'))),
        ),
        GoRoute(
          path: RouteNames.profileMyTemplates,
          name: 'profileMyTemplates',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('MY_TEMPLATES_PAGE'))),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWith((ref) async => _db),
        themeKeyProvider.overrideWith((ref) => themeKey),
        uiStyleProvider.overrideWith((ref) => uiStyle),
      ],
      child: MaterialApp.router(routerConfig: goRouter),
    );
  }

  Future<void> settleOrPump(WidgetTester tester, UIStyle style) async {
    if (style == UIStyle.female) {
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
  }

  void setLargeViewport(WidgetTester tester) {
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
  }

  group('TemplatesDraftsPage', () {
    testWidgets('renders empty state when drafts list is empty', (tester) async {
      setLargeViewport(tester);
      await _db.delete(Tables.templateDrafts);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('还没有草稿'), findsOneWidget);
      expect(find.text('在模板编辑器中填写内容时会自动保存草稿'), findsOneWidget);
      expect(find.text('新建模板'), findsOneWidget);
    });

    testWidgets('renders stats bar with draft count', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('3'), findsOneWidget);
      expect(find.text('个草稿'), findsOneWidget);
    });

    testWidgets('renders 3 draft rows with names', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('咖啡馆人像草稿'), findsOneWidget);
      expect(find.text('日落风光草稿'), findsOneWidget);
      expect(find.text('街拍黑白草稿'), findsOneWidget);
    });

    testWidgets('renders category tag from categoryLabel', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 3 个分类标签：人像 / 风光 / 街拍（来自 TemplatesBrowseMockData.categoryLabel）
      expect(find.text('人像'), findsOneWidget);
      expect(find.text('风光'), findsOneWidget);
      expect(find.text('街拍'), findsOneWidget);
    });

    testWidgets('renders camera params for draft-1', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('EV +0.7'), findsOneWidget);
      expect(find.text('ISO 400'), findsOneWidget);
      expect(find.text('1/125s'), findsOneWidget);
    });

    testWidgets('formats 2 hours ago as "2小时前"', (tester) async {
      final now = DateTime(2026, 7, 19, 12, 0, 0).millisecondsSinceEpoch;
      final ts = now - 2 * 60 * 60 * 1000;
      expect(formatDraftTime(ts, now: now), '2小时前');
    });

    testWidgets('formats 3 days ago as "3天前"', (tester) async {
      final now = DateTime(2026, 7, 19, 12, 0, 0).millisecondsSinceEpoch;
      final ts = now - 3 * 24 * 60 * 60 * 1000;
      expect(formatDraftTime(ts, now: now), '3天前');
    });

    testWidgets('formats 15 days ago as "M月D日" (date format)', (tester) async {
      // 7-day threshold (matching uni-app drafts.vue): 15 days ago falls into 'M月D日' branch
      final now = DateTime(2026, 7, 19, 12, 0, 0).millisecondsSinceEpoch;
      final ts = now - 15 * 24 * 60 * 60 * 1000;
      final d = DateTime.fromMillisecondsSinceEpoch(ts);
      final expected = '${d.month}月${d.day}日';
      expect(formatDraftTime(ts, now: now), expected);
    });

    testWidgets('tapping delete button shows confirmation dialog',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 4 个 delete_outline icon：1 个 nav trash (index 0) + 3 个 draft row del-btn (index 1-3)
      // 点击第一个 draft row 的 delete 按钮（index 1）
      await tester.tap(find.byIcon(Icons.delete_outline).at(1));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('删除草稿'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('确认'), findsOneWidget);
    });

    testWidgets('confirming delete removes draft and shows toast',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 初始 3 个草稿
      expect(find.text('咖啡馆人像草稿'), findsOneWidget);

      // 点击第一个 draft row 的 delete 按钮（index 1，跳过 nav trash）
      await tester.tap(find.byIcon(Icons.delete_outline).at(1));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击确认
      await tester.tap(find.text('确认'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // Toast '已删除' 出现，'咖啡馆人像草稿' 消失
      expect(find.text('已删除'), findsOneWidget);
      expect(find.text('咖啡馆人像草稿'), findsNothing);
    });

    testWidgets('tapping trash icon in nav shows clear all confirmation dialog',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击 LumiraNav 中的 trash 按钮（通过 find.descendant 精确定位）
      final navTrash = find.descendant(
        of: find.byType(LumiraNav),
        matching: find.byIcon(Icons.delete_outline),
      );
      expect(navTrash, findsOneWidget);
      await tester.tap(navTrash);
      await settleOrPump(tester, UIStyle.neumorphic);

      // 验证清空草稿箱对话框
      expect(find.text('清空草稿箱'), findsOneWidget);
      expect(find.text('确定删除所有草稿吗？此操作不可恢复。'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('确认'), findsOneWidget);
    });

    testWidgets('confirming clear all empties drafts and shows toast',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击 LumiraNav 中的 trash 按钮（LumiraNav 的 actions 区域）
      final navTrash = find.descendant(
        of: find.byType(LumiraNav),
        matching: find.byIcon(Icons.delete_outline),
      );
      await tester.tap(navTrash);
      await settleOrPump(tester, UIStyle.neumorphic);

      // 验证清空草稿箱对话框
      expect(find.text('清空草稿箱'), findsOneWidget);
      expect(find.text('确定删除所有草稿吗？此操作不可恢复。'), findsOneWidget);

      // 点击确认
      await tester.tap(find.text('确认'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // Toast '已清空' + 空状态出现
      expect(find.text('已清空'), findsOneWidget);
      expect(find.text('还没有草稿'), findsOneWidget);
    });

    testWidgets('renders LumiraNav with title 草稿箱', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.widgetWithText(LumiraNav, '草稿箱'), findsOneWidget);
    });

    testWidgets('renders correctly across all 8 themes', (tester) async {
      for (final theme in ThemeKey.values) {
        setLargeViewport(tester);
        await tester.pumpWidget(wrap(
          themeKey: theme,
          uiStyle: UIStyle.neumorphic,
        ));
        await settleOrPump(tester, UIStyle.neumorphic);
        expect(find.text('草稿箱'), findsOneWidget, reason: 'theme=$theme');
        expect(find.text('咖啡馆人像草稿'), findsOneWidget,
            reason: 'theme=$theme');
      }
    });

    testWidgets('renders correctly across all 4 UI styles', (tester) async {
      for (final style in UIStyle.values) {
        setLargeViewport(tester);
        await tester.pumpWidget(wrap(
          themeKey: ThemeKey.warmWhite,
          uiStyle: style,
        ));
        await settleOrPump(tester, style);
        expect(find.text('草稿箱'), findsOneWidget, reason: 'style=$style');
        expect(find.text('咖啡馆人像草稿'), findsOneWidget,
            reason: 'style=$style');
      }
    });
  });
}