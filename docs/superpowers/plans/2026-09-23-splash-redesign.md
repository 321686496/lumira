# Splash 启动页视觉优化 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重排 Splash 排版：去掉 logo 光晕、增强品牌层次、状态区融入整体、底部加排版版权。

**Architecture:** 仅改动 `splash_page.dart` 的 `build()`（尺寸/排版/间距），不影响认证、合规、路由、定时跳转逻辑。同步更新 `splash_page_test.dart` 中与新视觉相冲突的断言并新增元素用例。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6（不支持 records），flutter_riverpod，go_router。

## Global Constraints

- 视觉一律来自 `ref.watch(appThemeProvider).tokens` + `uiStyleProvider`，随设置切换，禁止硬编码 `Colors.xxx` / `Color(0xFF...)`。
- 背景保持纯 `tokens.canvas`，不叠任何风格渐变。
- 唯一合法新增硬编码仅有：发丝线透明度 `tokens.brand.withOpacity(0.25)` 这一「叠加视觉」用法。
- Dart 2.19.6，禁止 Dart 3 records 语法。

---

### Task 1: 重排 Splash build() 排版并更新测试

**Files:**
- Modify: `lumira_app_flutter/lib/features/splash/pages/splash_page.dart:196-301`（build 方法）
- Test: `lumira_app_flutter/test/features/splash/splash_page_test.dart:96-105`（品牌光晕用例）

**Interfaces:**
- Consumes: `tokens`（`canvas`/`brand`/`textPrimary`/`textTertiary`）、`LumiraLogo.symbol`、`FadeUp`、`LumiraProgress.circular`、`LumiraButton`、`auth.status`。
- Produces: 无外部依赖的新接口（纯视觉改动）。

- [ ] **Step 1: 更新既有「品牌光晕」测试为「无光晕 + 关键元素」判定**

在 `test/features/splash/splash_page_test.dart` 中，将第 96-105 行的用例标题与断言替换为：

```dart
testWidgets('SplashPage 无光晕，渲染 符号标 + 发丝线 + 标题 + 副标题 + 版权', (tester) async {
  await tester.pumpWidget(_wrapWithRouter(const SplashPage()));
  await tester.pump(const Duration(milliseconds: 100));

  expect(find.text('如画 Lumira'), findsOneWidget);
  expect(find.text('如你所见，皆成画卷'), findsOneWidget);
  expect(find.byType(LumiraLogo), findsOneWidget);
  expect(find.text('Design · 如画'), findsOneWidget);
  // 发丝线通过 Key 定位
  expect(find.byKey(const Key('splash-brand-line')), findsOneWidget);
  // 明确不再渲染任何圆形 RadialGradient 光晕
  expect(
    find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).shape == BoxShape.circle &&
          (w.decoration as BoxDecoration).gradient is RadialGradient,
    ),
    findsNothing,
  );
});
```

- [ ] **Step 2: 运行测试确认新断言失败（当前仍有光晕）**

Run: `cd lumira_app_flutter; flutter test test/features/splash/splash_page_test.dart`
Expected: Step 1 的新用例 FAIL（存在光晕/缺发丝线 Key/缺版权文案）。

- [ ] **Step 3: 重排 `splash_page.dart` 的 `build()`**

将 `import 'dart:async';` 后的若干 import 无需改动（`FadeUp`/`LumiraLogo` 均已引入）。替换 `build()` 方法体（第 196-301 行）为：

```dart
  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final auth = ref.watch(authControllerProvider);

    // 状态区内容：loading / failed / 无（空白占位）
    final Widget statusArea = switch (auth.status) {
      AuthStatus.loading => LumiraProgress.circular(),
      AuthStatus.failed => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '网络连接失败',
              style: TextStyle(fontSize: 13, color: tokens.textTertiary),
            ),
            const SizedBox(height: 12),
            LumiraButton(
              variant: ButtonVariant.primary,
              onPressed: _retryRegistration,
              child: const Text('重试'),
            ),
          ],
        ),
      _ => const SizedBox.shrink(),
    };

    return Scaffold(
      // #FAF7F2 默认主题 canvas；用 tokens.canvas 让所有主题都对齐
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: [
              const Spacer(),
              // 品牌区：符号标（无光晕）→ 细金发丝线 → 标题 → 副标题
              FadeUp(
                child: SizedBox(
                  width: 128,
                  height: 128,
                  child: Center(
                    child: LumiraLogo.symbol(
                      size: 72,
                      semanticsLabel: '如画品牌符号标',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FadeUp(
                delay: const Duration(milliseconds: 200),
                child: Container(
                  key: const Key('splash-brand-line'),
                  width: 36,
                  height: 0.8,
                  decoration: BoxDecoration(
                    color: tokens.brand.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FadeUp(
                delay: const Duration(milliseconds: 200),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '如画 Lumira',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                        letterSpacing: -0.06,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '如你所见，皆成画卷',
                      style: TextStyle(
                        fontSize: 14,
                        color: tokens.textTertiary,
                        letterSpacing: 1.2,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              // 状态区：固定高度槽位，三态切换不跳动
              const SizedBox(height: 32),
              SizedBox(
                height: 44,
                child: Center(child: statusArea),
              ),
              const Spacer(),
              // 底部排版版权
              Text(
                'Design · 如画',
                style: TextStyle(
                  fontSize: 12,
                  color: tokens.textTertiary,
                  letterSpacing: 0.7,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
```

> 说明：原代码在 `build()` 前使用了 `switch`/集合中缀等，Dart 2.19 已支持 `switch` 表达式，安全。若项目启用 `dart format` 风格（combine），保持之路由/认证逻辑全部不变。

- [ ] **Step 4: 运行全部 splash 测试确认真整体通过**

Run: `cd lumira_app_flutter; flutter analyze lib/features/splash/pages/splash_page.dart; flutter test test/features/splash/splash_page_test.dart`
Expected: 全部 PASS（含保留的合规/重试/loading 用例）。

- [ ] **Step 5: Commit**

```bash
git add lumira_app_flutter/lib/features/splash/pages/splash_page.dart lumira_app_flutter/test/features/splash/splash_page_test.dart
git commit -m "feat: 优化 splash 排版——去光晕、强化品牌层次、状态区与底部版权"
```

---

## Self-Review

- **Spec 覆盖**：去光晕（Task1 Step3 删除 RadialGradient）✓；增强品牌层次（发丝线+字号对比）✓；状态区融入（固定 44dp 槽位 + Center）✓；底部版权（Design · 如画）✓；跨风格/主题无硬编码（仅 canvas + tokens）✓。
- **占位符扫描**：无 TBD/TODO；代码均完整给出。
- **类型一致**：`AuthStatus`、`tokens.*`、`LumiraButton`/`LumiraProgress` 均与既有用法一致；`_` 用作 switch 兜底分支匹配 `registered/fresh` 等值，合法。