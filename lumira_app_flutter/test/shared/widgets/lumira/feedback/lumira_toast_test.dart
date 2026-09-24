import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/shared/widgets/lumira/feedback/lumira_toast.dart';

void main() {
  final navigatorKey = GlobalKey<NavigatorState>();

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
          uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Center(child: Text('home'))),
        ),
      ),
    );
  }

  testWidgets('Overlay.of(Navigator context) 抛 No Overlay（复现鸿蒙分享降级根因）',
      (tester) async {
    await pumpApp(tester);
    final navigator = navigatorKey.currentState!;
    expect(navigator.overlay, isNotNull);
    // 根因回归：Navigator 自身 context 位于其创建的 Overlay 之上，
    // 向上查找 Overlay 必然抛 FlutterError（对应线上 "No Overlay widget found"）
    expect(() => Overlay.of(navigator.context), throwsFlutterError);
  });

  testWidgets('showWithOverlay 通过 NavigatorState.overlay 正常显示 Toast',
      (tester) async {
    await pumpApp(tester);
    final overlay = navigatorKey.currentState!.overlay!;
    LumiraToast.showWithOverlay(overlay, '系统分享不可用，已复制到剪贴板');
    await tester.pump();
    expect(find.text('系统分享不可用，已复制到剪贴板'), findsOneWidget);
    // 自动消失（2s + 退出动画），避免残留 pending timer
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('系统分享不可用，已复制到剪贴板'), findsNothing);
  });

  testWidgets('show 用页面 context（Overlay 后代）正常显示', (tester) async {
    await pumpApp(tester);
    final ctx = tester.element(find.text('home'));
    LumiraToast.show(ctx, '普通页面 Toast');
    await tester.pump();
    expect(find.text('普通页面 Toast'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('普通页面 Toast'), findsNothing);
  });

  testWidgets('ToastAction 行动按钮可点击（回归：IgnorePointer 曾吞掉全部点击）',
      (tester) async {
    await pumpApp(tester);
    final ctx = tester.element(find.text('home'));
    var actionTapped = false;
    LumiraToast.show(
      ctx,
      '对比图已生成',
      action: ToastAction(label: '查看', onTap: () => actionTapped = true),
    );
    await tester.pump();
    expect(find.text('查看'), findsOneWidget);
    await tester.tap(find.text('查看'));
    expect(actionTapped, isTrue);
  });

  testWidgets('Toast 卡片空白处点击穿透到下层 UI（移除 IgnorePointer 不拦手势）',
      (tester) async {
    var underTapped = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
          uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: ElevatedButton(
                onPressed: () => underTapped = true,
                child: const Text('under'),
              ),
            ),
          ),
        ),
      ),
    );
    final ctx = tester.element(find.text('under'));
    LumiraToast.show(ctx, '顶层 Toast');
    await tester.pump();
    // 点击 Toast 覆盖区内的下层按钮：应穿透命中
    await tester.tap(find.text('under'));
    expect(underTapped, isTrue);
  });
}
