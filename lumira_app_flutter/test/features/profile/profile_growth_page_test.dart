import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/growth_dao.dart';
import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/academy/data/academy_dao.dart';
import 'package:lumira_app_flutter/features/profile/pages/profile_growth_page.dart';
import 'package:lumira_app_flutter/features/profile/providers/growth_providers.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

/// Task A6 — ProfileGrowthPage 接入 GrowthDao 后的 smoke 测试
///
/// 原 mock 数据测试（断言 '入门学徒' / '4 / 6' / '本月 42 张' / '初露锋芒' 等
/// mock 专属值）在切换到 DAO 后不再适用。本测试改为：
/// 1. 用 sqflite_ffi + :memory: DB override databaseProvider / growthDaoProvider
/// 2. 断言 AppBar 标题、4 个 section 标题、空 DB 下的占位文案（稳定不变量）
/// 3. 跨 8 主题 smoke
void main() {
  FlutterExceptionHandler? originalErrorHandler;
  late Database sharedDb;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    sharedDb = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
  });

  tearDownAll(() async {
    await sharedDb.close();
  });

  setUp(() {
    HttpOverrides.global = TestHttpOverrides();
    originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('NetworkImageLoadException')) return;
      originalErrorHandler?.call(details);
    };
  });

  tearDown(() {
    HttpOverrides.global = null;
    FlutterError.onError = originalErrorHandler;
  });

  Widget wrap({ThemeKey themeKey = ThemeKey.warmWhite, UIStyle uiStyle = UIStyle.neumorphic}) {
    final router = GoRouter(
      initialLocation: RouteNames.profileGrowth,
      routes: [
        GoRoute(
          path: RouteNames.profileGrowth,
          name: 'profileGrowth',
          builder: (_, __) => const ProfileGrowthPage(),
        ),
        GoRoute(
          path: RouteNames.capture,
          name: 'capture',
          builder: (_, __) => const _StubPage(text: 'CAPTURE_PAGE'),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => themeKey),
        uiStyleProvider.overrideWith((ref) => uiStyle),
        databaseProvider.overrideWith((ref) async => sharedDb),
        growthDaoProvider.overrideWith((ref) async => GrowthDao(sharedDb)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Future<void> settleOrPump(WidgetTester tester) async {
    // sqflite_common_ffi 的 DB 查询是真实 async 操作，FakeAsync 下
    // pump(Duration) 无法让真实 Future 完成，必须用 tester.runAsync。
    // 并行全量负载下 DB Provider 解析可能超过单次 50ms，轮询多次以稳定通过。
    for (var i = 0; i < 10; i++) {
      await tester.pump();
      await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)));
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  void setLargeViewport(WidgetTester tester) {
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
  }

  group('ProfileGrowthPage — DAO smoke', () {
    testWidgets('renders LumiraNav with title 成长中心', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap());
      await settleOrPump(tester);

      expect(find.byType(ProfileGrowthPage), findsOneWidget);
      expect(find.widgetWithText(LumiraNav, '成长中心'), findsOneWidget);
    });

    testWidgets('renders all 4 section headers with empty DB', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap());
      await settleOrPump(tester);

      expect(find.text('LEVEL'), findsOneWidget);
      expect(find.text('成就'), findsOneWidget);
      expect(find.text('成长轨迹'), findsOneWidget);
      expect(find.text('拍摄日历'), findsOneWidget);
    });

    testWidgets('renders placeholder level 1 / 新手 / 0-6 / 本月 0 张 with empty DB',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap());
      await settleOrPump(tester);

      // GrowthSummary.empty: level=1, levelName='新手'
      expect(find.text('1'), findsOneWidget);
      expect(find.text('新手'), findsOneWidget);
      // 成就：6 项占位全部 locked → '0 / 6'
      expect(find.text('0 / 6'), findsOneWidget);
      // 本月 0 张（空 DB 无活动）
      expect(find.text('本月 0 张'), findsOneWidget);
    });

    testWidgets('renders 6 placeholder achievement names', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap());
      await settleOrPump(tester);

      expect(find.text('初次拍摄'), findsOneWidget);
      expect(find.text('连续7天'), findsOneWidget);
      expect(find.text('坚持30天'), findsOneWidget);
      expect(find.text('模板收藏家'), findsOneWidget);
      expect(find.text('挑战达人'), findsOneWidget);
      expect(find.text('进阶玩家'), findsOneWidget);
    });

    testWidgets('renders 112 heatmap cells', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap());
      await settleOrPump(tester);

      var cellCount = 0;
      for (var i = 0; i < 120; i++) {
        final key = ValueKey<String>('heatmap_cell_$i');
        if (find.byKey(key).evaluate().isNotEmpty) {
          cellCount++;
        }
      }
      expect(cellCount, 112);
    });

    testWidgets('renders without FlutterError across 8 themes', (tester) async {
      for (final theme in ThemeKey.values) {
        setLargeViewport(tester);
        await tester.pumpWidget(wrap(themeKey: theme));
        await settleOrPump(tester);
        expect(find.byType(ProfileGrowthPage), findsOneWidget, reason: 'theme=$theme');
        expect(find.text('LEVEL'), findsOneWidget, reason: 'theme=$theme');
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });
}

class _StubPage extends StatelessWidget {
  const _StubPage({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(text)));
  }
}

Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE ${Tables.userProgress} (
      ${Tables.colId} INTEGER PRIMARY KEY DEFAULT 1,
      ${Tables.colLevel} INTEGER NOT NULL DEFAULT 1,
      ${Tables.colLevelName} TEXT NOT NULL DEFAULT '新手',
      ${Tables.colXp} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colXpToNextLevel} INTEGER NOT NULL DEFAULT 100,
      ${Tables.colTotalPhotos} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colUsedTemplates} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colFavorites} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colStreakDays} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colLastCheckInDate} TEXT,
      ${Tables.colFragmentsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colAchievementsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
  await db.insert(Tables.userProgress, {
    Tables.colId: 1,
    Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
  });
  await db.execute(ChallengeHistoryTable.createSql);
  await db.execute('''
    CREATE TABLE ${Tables.galleryItems} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colDataUrl} TEXT,
      ${Tables.colFilePath} TEXT,
      ${Tables.colSceneId} TEXT,
      ${Tables.colTemplateId} TEXT,
      ${Tables.colKitId} TEXT,
      ${Tables.colMood} TEXT,
      ${Tables.colLut} TEXT,
      ${Tables.colCreatedAt} INTEGER NOT NULL
    )
  ''');
  await db.execute(AcademyTables.cpCreateSql);
}
