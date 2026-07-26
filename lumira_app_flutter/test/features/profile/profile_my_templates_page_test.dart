import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/profile/data/profile_content_mock_data.dart';
import 'package:lumira_app_flutter/features/profile/pages/profile_my_templates_page.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

/// Task 2.10 + Task A5 — ProfileMyTemplatesPage 测试
///
/// Task A5 适配：页面从 `importedCustomTemplatesProvider`（mock 列表）
/// 切换到 `customTemplatesProvider`（DAO），测试通过 sqflite_ffi + 共享
/// 内存 DB 覆盖 `templatesDaoProvider`，并用 `ProfileContentMockData.customTemplates`
/// （deprecated）作为种子数据保持既有断言稳定。
void main() {
  late GoRouter router;
  FlutterExceptionHandler? originalErrorHandler;
  // 共享 DB 实例：在 setUpAll 中创建并种入 mock 数据，所有测试通过 override 复用。
  late Database sharedDb;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    sharedDb = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
  });

  tearDownAll(() async {
    await sharedDb.close();
  });

  setUp(() async {
    // 每个测试前清空 + 重新种入 5 个 mock 模板，保证测试间状态隔离
    // （`_handleActionDelete` 测试会从 sharedDb 删除记录）
    await sharedDb.delete(Tables.customTemplates, where: '1=1');
    await _seedMockCustomTemplates(sharedDb);

    router = GoRouter(
      initialLocation: RouteNames.profileMyTemplates,
      routes: [
        GoRoute(
          path: RouteNames.profileMyTemplates,
          name: 'profileMyTemplates',
          builder: (_, __) => const ProfileMyTemplatesPage(),
        ),
        GoRoute(
          path: RouteNames.templatesEditor,
          name: 'templatesEditor',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('TEMPLATES_EDITOR'))),
        ),
        GoRoute(
          path: RouteNames.capture,
          name: 'capture',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('CAPTURE_PAGE'))),
        ),
      ],
    );
    HttpOverrides.global = TestHttpOverrides();
    originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('NetworkImageLoadException')) {
        return;
      }
      originalErrorHandler?.call(details);
    };
  });

  tearDown(() {
    HttpOverrides.global = null;
    FlutterError.onError = originalErrorHandler;
  });

  Widget wrap(ThemeKey themeKey, UIStyle uiStyle) {
    return ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => themeKey),
        uiStyleProvider.overrideWith((ref) => uiStyle),
        // 复用 sharedDb，避免每个测试重新打开 DB 文件
        databaseProvider.overrideWith((ref) async => sharedDb),
        // 直接覆盖 templatesDaoProvider，避免 FutureProvider 异步解析时序问题
        templatesDaoProvider.overrideWith((ref) async => TemplatesDao(sharedDb)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Future<void> settleOrPump(WidgetTester tester, UIStyle style) async {
    // 使用 pump + runAsync：sqflite_common_ffi 的 DB 查询是真实 async 操作，
    // 在 FakeAsync 环境下 pump(Duration) 无法让真实 Future 完成。
    // 必须用 tester.runAsync 让真实 async 操作（DAO 查询 / 写入）完成。
    await tester.pump();
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  void setLargeViewport(WidgetTester tester) {
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
  }

  group('ProfileMyTemplatesPage', () {
    testWidgets('renders LumiraNav with title 我的模板 and StatsBar', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.byType(ProfileMyTemplatesPage), findsOneWidget);
      expect(find.widgetWithText(LumiraNav, '我的模板'), findsOneWidget);

      // StatsBar：5 个模板 / 0 次使用 / 0 个收藏
      // Task A5：usageCount/isFavorite 暂未持久化到 DAO，按 brief 简化为 0
      expect(find.text('5'), findsOneWidget);
      // usage + favorites 均为 0，StatsBar 中 '0' 出现 2 次
      expect(find.text('0'), findsNWidgets(2));
      expect(find.text('自定义模板'), findsOneWidget);
      expect(find.text('使用次数'), findsOneWidget);
      expect(find.text('收藏'), findsOneWidget);
    });

    testWidgets('renders all 5 custom templates in list', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 5 个自定义模板名
      expect(find.text('复古胶片人像'), findsOneWidget); // tpl_001
      expect(find.text('日落山景'), findsOneWidget); // tpl_002
      expect(find.text('咖啡馆俯拍'), findsOneWidget); // tpl_003
      expect(find.text('夜景街拍'), findsOneWidget); // tpl_004
      expect(find.text('微距花卉'), findsOneWidget); // tpl_005

      // 验证 mock 数据条目数与页面一致
      // ignore: deprecated_member_use_from_same_package
      expect(ProfileContentMockData.customTemplates.length, 5);
    });

    testWidgets('renders action bar with 新建模板 and 导入模板 buttons', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('新建模板'), findsOneWidget);
      expect(find.text('导入模板'), findsOneWidget);
    });

    testWidgets('renders filter bar with 5 filter pills', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 5 个 filter pills
      // 注意：'人像' / '风光' / '美食' 同时出现在 FilterPill 和模板行的 tpl-cat-tag 中
      // 所以用 findsAtLeastNWidgets(1) 验证 FilterPill 存在
      expect(find.text('全部'), findsOneWidget);
      expect(find.text('人像'), findsAtLeastNWidgets(1));
      expect(find.text('风光'), findsAtLeastNWidgets(1));
      expect(find.text('美食'), findsAtLeastNWidgets(1));
      expect(find.text('其他'), findsOneWidget);
    });

    testWidgets('tapping filter 人像 shows only tpl_001 (portrait)', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 初始 5 个模板
      expect(find.text('复古胶片人像'), findsOneWidget);
      expect(find.text('日落山景'), findsOneWidget);
      expect(find.text('咖啡馆俯拍'), findsOneWidget);
      expect(find.text('夜景街拍'), findsOneWidget);
      expect(find.text('微距花卉'), findsOneWidget);

      // 点击 "人像" filter
      // 注意：'人像' 同时出现在 FilterPill 和 tpl_001 的 tpl-cat-tag 中
      // FilterPill 在前（widget 树顺序），用 .first 选择 FilterPill
      await tester.tap(find.text('人像').first);
      await settleOrPump(tester, UIStyle.neumorphic);

      // 仅显示 portrait 类别的 tpl_001
      expect(find.text('复古胶片人像'), findsOneWidget);
      expect(find.text('日落山景'), findsNothing);
      expect(find.text('咖啡馆俯拍'), findsNothing);
      expect(find.text('夜景街拍'), findsNothing);
      expect(find.text('微距花卉'), findsNothing);
    });

    testWidgets('tapping filter 风光 shows only tpl_002 (landscape)', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // '风光' 同时出现在 FilterPill 和 tpl_002 的 tpl-cat-tag 中
      await tester.tap(find.text('风光').first);
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('复古胶片人像'), findsNothing);
      expect(find.text('日落山景'), findsOneWidget);
      expect(find.text('咖啡馆俯拍'), findsNothing);
      expect(find.text('夜景街拍'), findsNothing);
      expect(find.text('微距花卉'), findsNothing);
    });

    testWidgets('tapping filter 美食 shows only tpl_003 (food)', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // '美食' 同时出现在 FilterPill 和 tpl_003 的 tpl-cat-tag 中
      await tester.tap(find.text('美食').first);
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('复古胶片人像'), findsNothing);
      expect(find.text('日落山景'), findsNothing);
      expect(find.text('咖啡馆俯拍'), findsOneWidget);
      expect(find.text('夜景街拍'), findsNothing);
      expect(find.text('微距花卉'), findsNothing);
    });

    testWidgets('tapping filter 其他 shows tpl_004 + tpl_005 (street + macro)', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // '其他' 只出现在 FilterPill（不是分类标签）
      await tester.tap(find.text('其他'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('复古胶片人像'), findsNothing); // portrait
      expect(find.text('日落山景'), findsNothing); // landscape
      expect(find.text('咖啡馆俯拍'), findsNothing); // food
      expect(find.text('夜景街拍'), findsOneWidget); // street
      expect(find.text('微距花卉'), findsOneWidget); // macro
    });

    testWidgets('tapping filter 全部 shows all 5 templates', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 先切换到 人像（用 .first 选择 FilterPill）
      await tester.tap(find.text('人像').first);
      await settleOrPump(tester, UIStyle.neumorphic);
      expect(find.text('日落山景'), findsNothing);

      // 再切回 全部
      await tester.tap(find.text('全部'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('复古胶片人像'), findsOneWidget);
      expect(find.text('日落山景'), findsOneWidget);
      expect(find.text('咖啡馆俯拍'), findsOneWidget);
      expect(find.text('夜景街拍'), findsOneWidget);
      expect(find.text('微距花卉'), findsOneWidget);
    });

    testWidgets('tapping 新建模板 button pushes /templates/editor', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 新建模板 是 LumiraButton 中的 label 文本
      await tester.tap(find.text('新建模板'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 跳转到 templatesEditor
      expect(find.text('TEMPLATES_EDITOR'), findsOneWidget);
    });

    testWidgets('long-pressing a template shows action sheet with 5 actions', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 初始无 ActionSheet
      expect(find.text('编辑模板'), findsNothing);
      expect(find.text('套用拍摄'), findsNothing);
      expect(find.text('复制模板'), findsNothing);
      expect(find.text('导出模板'), findsNothing);
      expect(find.text('删除模板'), findsNothing);
      expect(find.text('取消'), findsNothing);

      // 长按第一个模板 '复古胶片人像'
      await tester.longPress(find.text('复古胶片人像'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 应出现 ActionSheet 含 5 个动作 + 取消
      expect(find.text('编辑模板'), findsOneWidget);
      expect(find.text('套用拍摄'), findsOneWidget);
      expect(find.text('复制模板'), findsOneWidget);
      expect(find.text('导出模板'), findsOneWidget);
      expect(find.text('删除模板'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
    });

    testWidgets('tapping 复制模板 in action sheet closes sheet and shows SnackBar 已复制', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 长按模板打开 ActionSheet
      await tester.longPress(find.text('复古胶片人像'));
      await settleOrPump(tester, UIStyle.neumorphic);
      expect(find.text('复制模板'), findsOneWidget);

      // 点击 复制模板
      await tester.tap(find.text('复制模板'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // ActionSheet 关闭
      expect(find.text('编辑模板'), findsNothing);
      expect(find.text('套用拍摄'), findsNothing);
      expect(find.text('复制模板'), findsNothing);
      expect(find.text('导出模板'), findsNothing);
      expect(find.text('删除模板'), findsNothing);

      // SnackBar 显示
      expect(find.text('已复制'), findsOneWidget);
    });

    testWidgets('tapping 删除模板 in action sheet closes sheet and shows SnackBar 已删除', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.longPress(find.text('日落山景'));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('删除模板'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // ActionSheet 关闭
      expect(find.text('删除模板'), findsNothing);
      // SnackBar 显示
      expect(find.text('已删除'), findsOneWidget);
    });

    testWidgets('tapping 导出模板 in action sheet closes sheet', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.longPress(find.text('咖啡馆俯拍'));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('导出模板'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // ActionSheet 关闭
      expect(find.text('导出模板'), findsNothing);
      // SnackBar：测试环境下 Share.shareXFiles / getTemporaryDirectory 缺失，
      // 实现 `_exportTemplate` 在 catch 中显示 '导出失败：...'。
      // 仅验证 SnackBar 区域出现错误提示（不绑定具体平台依赖文案）。
      expect(find.textContaining('导出'), findsOneWidget);
    });

    testWidgets('tapping 取消 in action sheet closes sheet without SnackBar', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.longPress(find.text('复古胶片人像'));
      await settleOrPump(tester, UIStyle.neumorphic);
      expect(find.text('取消'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // ActionSheet 关闭
      expect(find.text('编辑模板'), findsNothing);
      expect(find.text('取消'), findsNothing);
    });

    testWidgets('tapping 拍摄 button on template row pushes /capture with templateId', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 模板行上的 '拍摄' 按钮
      final applyBtn = find.text('拍摄');
      expect(applyBtn, findsNWidgets(5)); // 5 个模板行各 1 个

      // 点击第 1 个（复古胶片人像）
      await tester.tap(applyBtn.first);
      await settleOrPump(tester, UIStyle.neumorphic);

      // 跳转到 capture
      expect(find.text('CAPTURE_PAGE'), findsOneWidget);
    });

    testWidgets('renders correctly across all 8 themes', (tester) async {
      setLargeViewport(tester);
      for (final theme in ThemeKey.values) {
        await tester.pumpWidget(wrap(theme, UIStyle.neumorphic));
        await settleOrPump(tester, UIStyle.neumorphic);
        expect(find.byType(ProfileMyTemplatesPage), findsOneWidget, reason: 'theme=$theme');
        expect(find.text('我的模板'), findsOneWidget, reason: 'theme=$theme');
        expect(find.text('复古胶片人像'), findsOneWidget, reason: 'theme=$theme');
      }
    });

    testWidgets('renders correctly across all 4 UI styles', (tester) async {
      setLargeViewport(tester);
      for (final style in UIStyle.values) {
        await tester.pumpWidget(wrap(ThemeKey.warmWhite, style));
        await settleOrPump(tester, style);
        expect(find.byType(ProfileMyTemplatesPage), findsOneWidget, reason: 'style=$style');
        expect(find.text('我的模板'), findsOneWidget, reason: 'style=$style');
        expect(find.text('复古胶片人像'), findsOneWidget, reason: 'style=$style');
      }
    });
  });
}

/// 创建 custom_templates 表（与 database_provider._onCreate 中对应部分一致）
Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE ${Tables.customTemplates} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colName} TEXT NOT NULL,
      ${Tables.colAuthor} TEXT NOT NULL DEFAULT '',
      ${Tables.colVersion} TEXT NOT NULL DEFAULT '1.0.0',
      ${Tables.colCategory} TEXT NOT NULL,
      ${Tables.colClassificationJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colTagsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colTagIdsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colPrice} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCover} TEXT NOT NULL DEFAULT '',
      ${Tables.colDescription} TEXT NOT NULL DEFAULT '',
      ${Tables.colReferenceSource} TEXT NOT NULL DEFAULT '',
      ${Tables.colCompositionJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPoseJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colCameraJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colSceneGuideJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPostProcessJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colIsBuiltin} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colIsRecommended} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
}

/// 将 `ProfileContentMockData.customTemplates`（deprecated）作为种子数据
/// 插入到 sharedDb，使页面通过 `customTemplatesProvider`（DAO）读取时
/// 能渲染出与原 mock 列表一致的 5 个模板。
///
/// Task A5 适配：保留既有断言稳定（如 '复古胶片人像' / '日落山景' 等）。
Future<void> _seedMockCustomTemplates(Database db) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  // ignore: deprecated_member_use_from_same_package
  for (final t in ProfileContentMockData.customTemplates) {
    await db.insert(
      Tables.customTemplates,
      {
        Tables.colId: t.id,
        Tables.colName: t.name,
        Tables.colAuthor: 'user',
        Tables.colVersion: '1.0.0',
        Tables.colCategory: t.category.name,
        Tables.colClassificationJson: '{}',
        Tables.colTagsJson: jsonEncode(t.tags),
        Tables.colTagIdsJson: '[]',
        Tables.colPrice: 0,
        Tables.colCover: t.coverUrl ?? '',
        Tables.colDescription: '',
        Tables.colReferenceSource: '',
        Tables.colCompositionJson: '{}',
        Tables.colPoseJson: '{}',
        Tables.colCameraJson: jsonEncode({
          'exposureCompensation': t.exposureCompensation,
          'iso': t.iso,
          'shutterSpeed': t.shutterSpeed,
        }),
        Tables.colSceneGuideJson: '{}',
        Tables.colPostProcessJson: '{}',
        Tables.colIsBuiltin: 0,
        Tables.colIsRecommended: 0,
        Tables.colCreatedAt: now,
        Tables.colUpdatedAt: now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
