import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/pages/capture_scene_manage_page.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

/// Task 2.10 — CaptureSceneManagePage 测试
///
/// 覆盖 brief §5：≥8 项断言，含 UI 渲染 / 路由参数 / 用户交互 / 空状态 / 业务逻辑（CRUD）。
void main() {
  FlutterExceptionHandler? originalErrorHandler;

  setUp(() {
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

  Widget wrap({
    required ThemeKey themeKey,
    required UIStyle uiStyle,
    String initialLocation = '/capture/scene-manage',
  }) {
    final goRouter = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: RouteNames.captureSceneManage,
          name: 'captureSceneManage',
          builder: (context, state) {
            final tab = state.queryParams[RouteNames.paramTab];
            return CaptureSceneManagePage(initialTab: tab);
          },
        ),
        GoRoute(
          path: RouteNames.captureSceneGuide,
          name: 'captureSceneGuide',
          builder: (_, __) => const _StubPage(text: 'GUIDE_PAGE'),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
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

  // ============================================================
  // 分类 1: 基本渲染
  // ============================================================
  group('CaptureSceneManagePage — basic rendering', () {
    testWidgets('renders LumiraNav with title 场景管理', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.widgetWithText(LumiraNav, '场景管理'), findsOneWidget);
    });

    testWidgets('renders 2 tab pills', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('我的收藏'), findsOneWidget);
      expect(find.text('自定义场景'), findsOneWidget);
      // 组合套件已迁移至 CompositionKitsPage
      expect(find.text('我的组合'), findsNothing);
    });

    testWidgets('default tab is fav (我的收藏)', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // fav tab 默认显示 1 个收藏场景（cafe-window）
      // 收藏场景名「咖啡馆」会出现在列表中
      expect(find.text('咖啡馆'), findsOneWidget);
      // 自定义 tab 内容不可见（新建场景按钮）
      expect(find.text('新建场景'), findsNothing);
    });

    testWidgets('renders nav back button', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
    });

    testWidgets('fav tab shows star icon for each favorite scene',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 默认 1 个收藏场景，对应 1 个 star 图标
      expect(find.byIcon(Icons.star), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 2: 路由参数
  // ============================================================
  group('CaptureSceneManagePage — route parameters', () {
    testWidgets('initialTab=custom shows custom tab content', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: '/capture/scene-manage?tab=custom',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // custom tab 显示「新建场景」按钮
      expect(find.text('新建场景'), findsOneWidget);
      // 自定义场景列表中显示 mock 的 custom_demo_001
      expect(find.text('我的咖啡馆'), findsOneWidget);
    });

    testWidgets('initialTab=kit falls back to fav', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: '/capture/scene-manage?tab=kit',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // kit tab 已迁移至 CompositionKitsPage，tab=kit 回退到 fav
      expect(find.text('咖啡馆'), findsOneWidget);
      expect(find.text('新建场景'), findsNothing);
    });

    testWidgets('initialTab=fav shows fav tab content', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: '/capture/scene-manage?tab=fav',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // fav tab 显示收藏场景列表
      expect(find.text('咖啡馆'), findsOneWidget);
    });

    testWidgets('invalid initialTab falls back to fav', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: '/capture/scene-manage?tab=invalid',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 应回退到 fav tab
      expect(find.text('咖啡馆'), findsOneWidget);
      expect(find.text('新建场景'), findsNothing);
    });
  });

  // ============================================================
  // 分类 3: 交互
  // ============================================================
  group('CaptureSceneManagePage — interactions', () {
    testWidgets('tapping 自定义场景 tab switches to custom tab',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 默认 fav tab，「新建场景」不可见
      expect(find.text('新建场景'), findsNothing);

      // 点击「自定义场景」tab
      await tester.tap(find.text('自定义场景'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('新建场景'), findsOneWidget);
      expect(find.text('我的咖啡馆'), findsOneWidget);
    });

    testWidgets('tapping star icon on fav removes it and shows SnackBar',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 默认 1 个 star 图标
      expect(find.byIcon(Icons.star), findsOneWidget);

      // 点击 star 取消收藏
      await tester.tap(find.byIcon(Icons.star));
      await settleOrPump(tester, UIStyle.neumorphic);

      // SnackBar 提示
      expect(find.text('已取消收藏'), findsOneWidget);
    });

    testWidgets('tapping 新建场景 button shows form with title 新建场景',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: '/capture/scene-manage?tab=custom',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击「新建场景」
      await tester.tap(find.text('新建场景'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 表单出现，标题为「新建场景」
      // 注意：表单打开后，列表（含「新建场景」按钮）被替换为表单，因此只剩表单标题 1 处
      expect(find.text('新建场景'), findsOneWidget);
      // 表单字段
      expect(find.text('场景名称'), findsOneWidget);
      expect(find.text('情绪主标题'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
    });

    testWidgets('tapping more_horiz icon on custom scene shows action sheet',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: '/capture/scene-manage?tab=custom',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击 more_horiz 图标
      await tester.tap(find.byIcon(Icons.more_horiz));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 底部弹出菜单：编辑 / 删除
      expect(find.text('编辑'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);
    });

    testWidgets('tapping 新建场景 opens form', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: '/capture/scene-manage?tab=custom',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('新建场景'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 表单显示：场景名称字段
      expect(find.text('场景名称'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 4: 业务逻辑（表单 CRUD）
  // ============================================================
  group('CaptureSceneManagePage — form CRUD', () {
    testWidgets('saving form with empty name shows error SnackBar',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: '/capture/scene-manage?tab=custom',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 进入新建表单
      await tester.tap(find.text('新建场景'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 直接点保存（名称为空）
      await tester.tap(find.text('保存'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('请输入场景名称'), findsOneWidget);
    });

    testWidgets('saving form with valid name creates scene and closes form',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: '/capture/scene-manage?tab=custom',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 初始 1 个自定义场景
      expect(find.text('我的咖啡馆'), findsOneWidget);

      // 进入新建表单
      await tester.tap(find.text('新建场景'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 在场景名称字段输入文本（第一个 TextField）
      await tester.enterText(
        find.byType(TextField).first,
        '测试新场景',
      );
      await tester.pump();

      // 点击保存
      await tester.tap(find.text('保存'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // SnackBar 提示「已创建」
      expect(find.text('已创建'), findsOneWidget);
      // 表单关闭后，列表中应有 2 个场景：原场景 + 新场景
      // 注意：SnackBar 可能遮挡，需 pump 一下
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('我的咖啡馆'), findsOneWidget);
      expect(find.text('测试新场景'), findsOneWidget);
    });

    testWidgets('cancelling form without changes closes form immediately',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: '/capture/scene-manage?tab=custom',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 进入新建表单
      await tester.tap(find.text('新建场景'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 表单出现
      expect(find.text('场景名称'), findsOneWidget);

      // 点击取消
      await tester.tap(find.text('取消'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 表单关闭
      expect(find.text('场景名称'), findsNothing);
      // 返回列表
      expect(find.text('新建场景'), findsOneWidget);
    });

    testWidgets('editing existing scene shows form with title 编辑场景',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: '/capture/scene-manage?tab=custom',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击 more_horiz → 编辑
      await tester.tap(find.byIcon(Icons.more_horiz));
      await settleOrPump(tester, UIStyle.neumorphic);
      await tester.tap(find.text('编辑'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 表单标题为「编辑场景」
      expect(find.text('编辑场景'), findsOneWidget);
      expect(find.text('场景名称'), findsOneWidget);
    });

    testWidgets(
        'cancelling form with changes shows confirmation dialog',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: '/capture/scene-manage?tab=custom',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 进入新建表单
      await tester.tap(find.text('新建场景'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 输入文本（触发 _formDirty = true）
      await tester.enterText(
        find.byType(TextField).first,
        '测试场景',
      );
      await tester.pump();

      // 点击取消
      await tester.tap(find.text('取消'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 应弹出确认对话框
      expect(find.text('确认离开'), findsOneWidget);
      expect(find.textContaining('未保存的变更'), findsOneWidget);
      expect(find.text('确定'), findsOneWidget);
    });

    testWidgets('deleting custom scene shows confirmation then removes',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: '/capture/scene-manage?tab=custom',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 初始 1 个场景
      expect(find.text('我的咖啡馆'), findsOneWidget);

      // 点击 more_horiz → 删除
      await tester.tap(find.byIcon(Icons.more_horiz));
      await settleOrPump(tester, UIStyle.neumorphic);
      await tester.tap(find.text('删除'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 弹出确认对话框
      // 注意：列表中场景名「我的咖啡馆」与对话框文本「确定删除「我的咖啡馆」吗？」都会匹配 textContaining，
      // 改用精确匹配对话框文本来避免歧义
      expect(find.text('删除场景'), findsOneWidget);
      expect(find.text('确定删除「我的咖啡馆」吗？'), findsOneWidget);

      // 确认删除（对话框中的「删除」按钮）
      // 注意：action sheet 中的「删除」已通过 Navigator.pop 关闭，
      // 此处对话框中的「删除」按钮是第二个
      await tester.tap(find.text('删除').last);
      await settleOrPump(tester, UIStyle.neumorphic);

      // SnackBar 提示
      expect(find.text('已删除'), findsOneWidget);
      // 列表中场景消失
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('我的咖啡馆'), findsNothing);
    });
  });

  // ============================================================
  // 分类 5: 空状态
  // ============================================================
  group('CaptureSceneManagePage — empty states', () {
    testWidgets('fav tab empty state shows after removing all favorites',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(
          wrap(themeKey: ThemeKey.warmWhite, uiStyle: UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 点击 star 取消唯一的收藏
      await tester.tap(find.byIcon(Icons.star));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 等待 SnackBar 消失
      await tester.pump(const Duration(milliseconds: 400));

      // 显示空状态
      expect(find.text('还没有收藏的场景'), findsOneWidget);
      expect(find.text('去场景指南发现更多'), findsOneWidget);
    });

    testWidgets('custom tab empty state shows after deleting all scenes',
        (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: '/capture/scene-manage?tab=custom',
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      // more 菜单 → 删除 → 确认对话框 → 确认
      await tester.tap(find.byIcon(Icons.more_horiz));
      await settleOrPump(tester, UIStyle.neumorphic);
      await tester.tap(find.text('删除').last);
      await settleOrPump(tester, UIStyle.neumorphic);
      await tester.tap(find.text('删除').last);
      await settleOrPump(tester, UIStyle.neumorphic);

      // 等待 SnackBar 消失
      await tester.pump(const Duration(milliseconds: 400));

      // 显示空状态
      expect(find.text('还没有自定义场景'), findsOneWidget);
    });
  });

  // ============================================================
  // 分类 6: Cross-theme/cross-style smoke
  // ============================================================
  group('CaptureSceneManagePage — smoke tests', () {
    testWidgets('renders without FlutterError under 8 themes + 4 styles',
        (tester) async {
      final combinations = <_ThemeStyleCombo>[
        for (final t in ThemeKey.values)
          _ThemeStyleCombo(theme: t, style: UIStyle.neumorphic),
        for (final s in UIStyle.values)
          if (s != UIStyle.neumorphic)
            _ThemeStyleCombo(theme: ThemeKey.warmWhite, style: s),
      ];

      for (final combo in combinations) {
        setLargeViewport(tester);
        await tester.pumpWidget(
            wrap(themeKey: combo.theme, uiStyle: combo.style));
        await settleOrPump(tester, combo.style);

        expect(find.widgetWithText(LumiraNav, '场景管理'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
        expect(find.text('我的收藏'), findsOneWidget,
            reason: 'theme=${combo.theme}, style=${combo.style}');
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });
}

class _ThemeStyleCombo {
  const _ThemeStyleCombo({required this.theme, required this.style});
  final ThemeKey theme;
  final UIStyle style;
}

class _StubPage extends StatelessWidget {
  const _StubPage({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(text)));
  }
}
