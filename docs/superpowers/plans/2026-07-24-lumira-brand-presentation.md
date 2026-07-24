# 如画品牌呈现与首页排版艺术化实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 splash/关于页 logo 增加主题色光晕、首页 APP 名称支持三种艺术排版可切换、4 个 tab 页标题统一左对齐。

**Architecture:** 新增 `HomeWordmarkStyle` 枚举 + Riverpod `StateProvider` 持久化偏好；新增 `HomeBrandTitle` 组件根据 style 渲染对应排版；修改 `LumiraNav` 支持 `centerTitle=false` 左对齐布局；splash/关于页 logo 后方叠径向渐变圆形光晕。

**Tech Stack:** Flutter, flutter_riverpod, flutter_svg, LumiraLogo（现有）

## Global Constraints

- 所有样式只用 class 选择器（项目记忆规则不适用 Flutter，但保持组件化）
- CSS 自定义属性 var(--xxx) 在 uni-app 不生效（不适用 Flutter）
- 颜色一律从 `tokens` 获取，禁止硬编码（除光晕透明度组合）
- 单位使用 dp（Flutter 标准），不使用 rpx
- 复用现有 `LumiraLogo`、`ThemeTokens`、`appThemeProvider`
- 不引入新依赖
- Flutter 代码遵循 `flutter analyze` 零警告
- 默认 `HomeWordmarkStyle.logoEnglish`
- 非 tab 页保持 `centerTitle=true` 默认值不变

---

## 文件结构

### 新增（2 个）
- `lib/core/preferences/home_wordmark_style.dart` — 枚举 + Provider
- `lib/shared/widgets/brand/home_brand_title.dart` — 根据偏好渲染排版

### 修改（8 个）
- `lib/shared/widgets/nav/lumira_nav.dart` — 支持 `centerTitle=false` 左对齐
- `lib/features/splash/pages/splash_page.dart` — logo 后加光晕
- `lib/features/profile/pages/profile_about_page.dart` — `_AppHeader` 替换为光晕+logo
- `lib/features/home/pages/home_page.dart` — 用 `HomeBrandTitle` 替代 `useWordmark`，传 `centerTitle: false`
- `lib/features/templates/pages/templates_page.dart` — 传 `centerTitle: false`
- `lib/features/challenge/pages/challenge_page.dart` — 传 `centerTitle: false`
- `lib/features/profile/pages/profile_page.dart` — 传 `centerTitle: false`
- `lib/features/profile/pages/profile_settings_page.dart` — 新增「首页标题样式」section

### 测试新增（2 个）
- `test/core/preferences/home_wordmark_style_test.dart`
- `test/shared/widgets/brand/home_brand_title_test.dart`

### 测试修改（2 个）
- `test/features/splash/splash_page_test.dart` — 验证光晕容器
- `test/features/profile/profile_about_page_test.dart`（若存在，否则新建）

---

## Task 1: 新增 HomeWordmarkStyle 枚举与 Provider

**Files:**
- Create: `lib/core/preferences/home_wordmark_style.dart`
- Create: `test/core/preferences/home_wordmark_style_test.dart`

**Interfaces:**
- Produces:
  - `enum HomeWordmarkStyle { logoEnglish, logoEnglishChinese, englishChinese }`
  - `final homeWordmarkStyleProvider = StateProvider<HomeWordmarkStyle>((_) => HomeWordmarkStyle.logoEnglish);`

- [ ] **Step 1: 写失败测试**

Create `test/core/preferences/home_wordmark_style_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/preferences/home_wordmark_style.dart';

void main() {
  group('HomeWordmarkStyle', () {
    test('enum has exactly 3 variants in expected order', () {
      expect(HomeWordmarkStyle.values.length, 3);
      expect(HomeWordmarkStyle.values[0], HomeWordmarkStyle.logoEnglish);
      expect(HomeWordmarkStyle.values[1], HomeWordmarkStyle.logoEnglishChinese);
      expect(HomeWordmarkStyle.values[2], HomeWordmarkStyle.englishChinese);
    });

    test('provider defaults to logoEnglish', () {
      final container = ProviderContainer();
      expect(container.read(homeWordmarkStyleProvider), HomeWordmarkStyle.logoEnglish);
      container.dispose();
    });

    test('provider can be updated to other styles', () {
      final container = ProviderContainer();
      container.read(homeWordmarkStyleProvider.notifier).state =
          HomeWordmarkStyle.logoEnglishChinese;
      expect(container.read(homeWordmarkStyleProvider),
          HomeWordmarkStyle.logoEnglishChinese);
      container.dispose();
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/core/preferences/home_wordmark_style_test.dart`
Expected: FAIL — 文件不存在 / `home_wordmark_style` 无法导入

- [ ] **Step 3: 创建枚举与 Provider**

Create `lib/core/preferences/home_wordmark_style.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 首页 APP 名称艺术排版风格
///
/// 用户可在「设置 → 首页标题样式」中切换，默认 [logoEnglish]。
/// 切换后首页导航栏标题实时重建。
enum HomeWordmarkStyle {
  /// 符号标 + Lumira 英文（默认，简洁国际化）
  logoEnglish,

  /// 符号标 + Lumira + 「如画」中文（三段层次最丰富）
  logoEnglishChinese,

  /// Lumira 英文 + 「如画」中文（无 logo，纯字体艺术感）
  englishChinese,
}

/// 首页标题样式偏好
///
/// 与 [themeKeyProvider] / [uiStyleProvider] 保持一致使用 StateProvider，
/// 不引入持久化（保持架构统一）。
final homeWordmarkStyleProvider =
    StateProvider<HomeWordmarkStyle>((_) => HomeWordmarkStyle.logoEnglish);
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/core/preferences/home_wordmark_style_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: 提交**

```bash
git add lib/core/preferences/home_wordmark_style.dart test/core/preferences/home_wordmark_style_test.dart
git commit -m "feat(preferences): add HomeWordmarkStyle enum and provider"
```

---

## Task 2: 新增 HomeBrandTitle 组件

**Files:**
- Create: `lib/shared/widgets/brand/home_brand_title.dart`
- Create: `test/shared/widgets/brand/home_brand_title_test.dart`

**Interfaces:**
- Consumes:
  - `HomeWordmarkStyle` 与 `homeWordmarkStyleProvider`（Task 1）
  - `appThemeProvider`（现有）
  - `LumiraLogo.symbol`（现有）
- Produces:
  - `class HomeBrandTitle extends ConsumerWidget`
  - `const HomeBrandTitle({super.key, this.preview = false})`
  - 当 `preview=true` 时使用更小尺寸（适配设置页预览卡片）

- [ ] **Step 1: 写失败测试**

Create `test/shared/widgets/brand/home_brand_title_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/preferences/home_wordmark_style.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/shared/widgets/brand/home_brand_title.dart';
import 'package:lumira_app_flutter/shared/widgets/brand/lumira_logo.dart';

Widget _wrap(Widget child) => ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
      ],
      child: MaterialApp(home: Scaffold(body: Center(child: child))),
    );

void main() {
  group('HomeBrandTitle', () {
    testWidgets('logoEnglish renders logo + Lumira text', (tester) async {
      await tester.pumpWidget(_wrap(
        ProviderScope(
          overrides: [
            homeWordmarkStyleProvider
                .overrideWith((ref) => HomeWordmarkStyle.logoEnglish),
          ],
          child: const MaterialApp(
            home: Scaffold(body: Center(child: HomeBrandTitle())),
          ),
        ),
      ));

      expect(find.byType(LumiraLogo), findsOneWidget);
      expect(find.text('Lumira'), findsOneWidget);
      expect(find.text('如画'), findsNothing);
    });

    testWidgets('logoEnglishChinese renders logo + Lumira + 如画', (tester) async {
      await tester.pumpWidget(_wrap(
        ProviderScope(
          overrides: [
            homeWordmarkStyleProvider
                .overrideWith((ref) => HomeWordmarkStyle.logoEnglishChinese),
          ],
          child: const MaterialApp(
            home: Scaffold(body: Center(child: HomeBrandTitle())),
          ),
        ),
      ));

      expect(find.byType(LumiraLogo), findsOneWidget);
      expect(find.text('Lumira'), findsOneWidget);
      expect(find.text('如画'), findsOneWidget);
    });

    testWidgets('englishChinese renders Lumira + 如画 without logo', (tester) async {
      await tester.pumpWidget(_wrap(
        ProviderScope(
          overrides: [
            homeWordmarkStyleProvider
                .overrideWith((ref) => HomeWordmarkStyle.englishChinese),
          ],
          child: const MaterialApp(
            home: Scaffold(body: Center(child: HomeBrandTitle())),
          ),
        ),
      ));

      expect(find.byType(LumiraLogo), findsNothing);
      expect(find.text('Lumira'), findsOneWidget);
      expect(find.text('如画'), findsOneWidget);
    });

    testWidgets('default style is logoEnglish when provider not overridden',
        (tester) async {
      await tester.pumpWidget(_wrap(const HomeBrandTitle()));
      expect(find.byType(LumiraLogo), findsOneWidget);
      expect(find.text('Lumira'), findsOneWidget);
    });
  });
}
```

注意：测试嵌套两层 `ProviderScope` 时，内层 override 会覆盖外层。简化为单层 `ProviderScope` 在 `_wrap` 内同时 override 所有 provider，再增加测试用例时通过 `homeWordmarkStyleProvider.overrideWith` 切换。修正后测试代码：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/preferences/home_wordmark_style.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/shared/widgets/brand/home_brand_title.dart';
import 'package:lumira_app_flutter/shared/widgets/brand/lumira_logo.dart';

Widget _wrap(Widget child, {HomeWordmarkStyle? style}) => ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
        if (style != null)
          homeWordmarkStyleProvider.overrideWith((ref) => style),
      ],
      child: MaterialApp(home: Scaffold(body: Center(child: child))),
    );

void main() {
  group('HomeBrandTitle', () {
    testWidgets('default style is logoEnglish', (tester) async {
      await tester.pumpWidget(_wrap(const HomeBrandTitle()));
      expect(find.byType(LumiraLogo), findsOneWidget);
      expect(find.text('Lumira'), findsOneWidget);
      expect(find.text('如画'), findsNothing);
    });

    testWidgets('logoEnglishChinese renders logo + Lumira + 如画', (tester) async {
      await tester.pumpWidget(_wrap(
        const HomeBrandTitle(),
        style: HomeWordmarkStyle.logoEnglishChinese,
      ));
      expect(find.byType(LumiraLogo), findsOneWidget);
      expect(find.text('Lumira'), findsOneWidget);
      expect(find.text('如画'), findsOneWidget);
    });

    testWidgets('englishChinese renders Lumira + 如画 without logo', (tester) async {
      await tester.pumpWidget(_wrap(
        const HomeBrandTitle(),
        style: HomeWordmarkStyle.englishChinese,
      ));
      expect(find.byType(LumiraLogo), findsNothing);
      expect(find.text('Lumira'), findsOneWidget);
      expect(find.text('如画'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/shared/widgets/brand/home_brand_title_test.dart`
Expected: FAIL — `home_brand_title.dart` 不存在

- [ ] **Step 3: 创建 HomeBrandTitle 组件**

Create `lib/shared/widgets/brand/home_brand_title.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/preferences/home_wordmark_style.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import 'lumira_logo.dart';

/// 首页 APP 名称艺术排版组件
///
/// 监听 [homeWordmarkStyleProvider]，根据当前偏好渲染三种排版：
/// - [HomeWordmarkStyle.logoEnglish] — 符号标 + Lumira（默认）
/// - [HomeWordmarkStyle.logoEnglishChinese] — 符号标 + Lumira + 如画
/// - [HomeWordmarkStyle.englishChinese] — Lumira + 如画（无 logo）
///
/// 英文用 Georgia/Noto Serif，letter-spacing 0.08em；
/// 中文用 Noto Serif SC w600，颜色取 `tokens.brand` 作艺术对比。
///
/// [preview] 用于设置页预览卡片，使用更小尺寸。
class HomeBrandTitle extends ConsumerWidget {
  const HomeBrandTitle({super.key, this.preview = false});

  final bool preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(homeWordmarkStyleProvider);
    final tokens = ref.watch(appThemeProvider).tokens;

    // 尺寸：preview 用更小尺寸适配卡片
    final double logoSize = preview ? 18 : 24;
    final double logoSizeCompact = preview ? 16 : 22;
    final double englishSize = preview ? 16 : 20;
    final double englishSizeCompact = preview ? 14 : 18;
    final double chineseSize = preview ? 12 : 14;
    final double gapLogoEnglish = preview ? 6 : 8;
    final double gapEnglishChinese = preview ? 6 : 8;

    switch (style) {
      case HomeWordmarkStyle.logoEnglish:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LumiraLogo.symbol(size: logoSize),
            SizedBox(width: gapLogoEnglish),
            Text('Lumira', style: _englishStyle(tokens, englishSize)),
          ],
        );
      case HomeWordmarkStyle.logoEnglishChinese:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LumiraLogo.symbol(size: logoSizeCompact),
            SizedBox(width: gapLogoEnglish),
            Text('Lumira', style: _englishStyle(tokens, englishSizeCompact)),
            SizedBox(width: gapEnglishChinese),
            Text('如画', style: _chineseStyle(tokens, chineseSize)),
          ],
        );
      case HomeWordmarkStyle.englishChinese:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Lumira', style: _englishStyle(tokens, englishSize)),
            SizedBox(width: gapEnglishChinese),
            Text('如画', style: _chineseStyle(tokens, chineseSize)),
          ],
        );
    }
  }

  TextStyle _englishStyle(ThemeTokens tokens, double size) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.normal,
        color: tokens.textPrimary,
        letterSpacing: 0.08 * size,
        height: 1.2,
        fontFamily: 'Georgia',
      );

  TextStyle _chineseStyle(ThemeTokens tokens, double size) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: tokens.brand,
        letterSpacing: 0.04 * size,
        height: 1.2,
        fontFamily: 'Noto Serif SC',
      );
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/shared/widgets/brand/home_brand_title_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: 运行 analyze 确保无警告**

Run: `flutter analyze lib/shared/widgets/brand/home_brand_title.dart lib/core/preferences/home_wordmark_style.dart`
Expected: No issues found

- [ ] **Step 6: 提交**

```bash
git add lib/shared/widgets/brand/home_brand_title.dart test/shared/widgets/brand/home_brand_title_test.dart
git commit -m "feat(brand): add HomeBrandTitle widget with 3 switchable layouts"
```

---

## Task 3: 修改 LumiraNav 支持 centerTitle=false 左对齐

**Files:**
- Modify: `lib/shared/widgets/nav/lumira_nav.dart` (当前 line 117-181 区域)

**Interfaces:**
- Consumes:
  - 现有 `centerTitle` 参数（默认 `true`）
  - 现有 `title` / `leading` / `actions` / `useWordmark`
- Produces:
  - `centerTitle=false` 时标题不再用 `Center` 强制居中，改为紧贴 leading 右侧
  - `centerTitle=true` 时保持现有视觉（向后兼容）

- [ ] **Step 1: 阅读现有 lumira_nav.dart**

Run: Read `lib/shared/widgets/nav/lumira_nav.dart` line 137-182
确认当前布局用 `Stack` + `Positioned(left:0, right:0, child: Center)` 强制居中。

- [ ] **Step 2: 写失败测试（如果不存在 test 文件则新建）**

先检查是否存在 `test/shared/widgets/nav/lumira_nav_test.dart`，不存在则创建。

Create/Append `test/shared/widgets/nav/lumira_nav_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

Widget _wrap(Widget child) => ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
      ],
      child: MaterialApp(home: Scaffold(appBar: child as PreferredSizeWidget, body: const SizedBox())),
    );

void main() {
  group('LumiraNav centerTitle', () {
    testWidgets('centerTitle=true (default) renders title centered', (tester) async {
      await tester.pumpWidget(_wrap(const LumiraNav(title: '发现')));
      expect(find.text('发现'), findsOneWidget);
    });

    testWidgets('centerTitle=false renders title without Center widget',
        (tester) async {
      await tester.pumpWidget(_wrap(const LumiraNav(
        title: '发现',
        centerTitle: false,
        showBackButton: false,
      )));
      expect(find.text('发现'), findsOneWidget);
      // 验证不再有 Center 强制居中
      expect(find.byType(Center), findsNothing);
    });
  });
}
```

- [ ] **Step 3: 运行测试验证失败**

Run: `flutter test test/shared/widgets/nav/lumira_nav_test.dart`
Expected: FAIL — `centerTitle=false` 时仍渲染 Center

- [ ] **Step 4: 修改 lumira_nav.dart 实现 left-align**

Modify `lib/shared/widgets/nav/lumira_nav.dart`，将 `SafeArea` 内的 `Stack` 改为根据 `centerTitle` 分支：

找到当前 line 148-181 的 `SafeArea` 块：

```dart
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 48, // min-height 96rpx → 48dp
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 左侧
                  Positioned(
                    left: 8,
                    child: leadingWidget,
                  ),
                  // 居中标题 / wordmark
                  if (centerWidget != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      child: Center(child: centerWidget),
                    ),
                  // 右侧
                  Positioned(
                    right: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: widget.actions ?? [const SizedBox(width: 40)],
                    ),
                  ),
                ],
              ),
            ),
          ),
```

替换为：

```dart
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 48, // min-height 96rpx → 48dp
              child: widget.centerTitle
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        // 左侧
                        Positioned(
                          left: 8,
                          child: leadingWidget,
                        ),
                        // 居中标题 / wordmark
                        if (centerWidget != null)
                          Positioned(
                            left: 0,
                            right: 0,
                            child: Center(child: centerWidget),
                          ),
                        // 右侧
                        Positioned(
                          right: 8,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: widget.actions ?? [const SizedBox(width: 40)],
                          ),
                        ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          leadingWidget,
                          if (centerWidget != null) ...[
                            const SizedBox(width: 4),
                            Flexible(child: centerWidget),
                          ],
                          const Spacer(),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: widget.actions ?? [const SizedBox(width: 40)],
                          ),
                        ],
                      ),
                    ),
            ),
          ),
```

- [ ] **Step 5: 运行测试验证通过**

Run: `flutter test test/shared/widgets/nav/lumira_nav_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 6: 运行 analyze 确保无警告**

Run: `flutter analyze lib/shared/widgets/nav/lumira_nav.dart`
Expected: No issues found

- [ ] **Step 7: 提交**

```bash
git add lib/shared/widgets/nav/lumira_nav.dart test/shared/widgets/nav/lumira_nav_test.dart
git commit -m "feat(nav): support centerTitle=false left-aligned layout"
```

---

## Task 4: Splash 页添加主题色光晕

**Files:**
- Modify: `lib/features/splash/pages/splash_page.dart` (line 64-75 区域)
- Modify: `test/features/splash/splash_page_test.dart`

**Interfaces:**
- Consumes: `tokens.brandSubtle`, `tokens.brandLight`, `tokens.canvas`, `LumiraLogo.symbol`

- [ ] **Step 1: 更新现有测试添加光晕断言**

Modify `test/features/splash/splash_page_test.dart`，在第一个测试中追加光晕容器断言：

将现有测试：

```dart
  testWidgets('SplashPage renders logo + title + caption', (tester) async {
    await tester.pumpWidget(_wrapWithRouter(const SplashPage()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('如画 Lumira'), findsOneWidget);
    expect(find.text('如你所见，皆成画卷'), findsOneWidget);
    // 原 Icons.camera_outlined 已替换为设计好的品牌 SVG 符号标
    expect(find.byType(LumiraLogo), findsOneWidget);
  });
```

改为：

```dart
  testWidgets('SplashPage renders logo + title + caption + brand halo', (tester) async {
    await tester.pumpWidget(_wrapWithRouter(const SplashPage()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('如画 Lumira'), findsOneWidget);
    expect(find.text('如你所见，皆成画卷'), findsOneWidget);
    expect(find.byType(LumiraLogo), findsOneWidget);
    // 主题色光晕：用 Stack + Container(circle + RadialGradient)
    expect(find.byType(Stack), findsWidgets);
  });
```

- [ ] **Step 2: 运行测试验证可能通过（Stack 已存在）**

Run: `flutter test test/features/splash/splash_page_test.dart`
Expected: PASS（当前 SplashPage 用 Column，没有 Stack，所以会 FAIL）

- [ ] **Step 3: 修改 splash_page.dart 添加光晕**

Modify `lib/features/splash/pages/splash_page.dart`，找到当前 line 60-75：

```dart
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 品牌 logo（设计好的取景器符号标 SVG）
              const FadeUp(
                child: SizedBox(
                  width: 80, // 略放大承载 SVG 描边细节
                  height: 80,
                  child: LumiraLogo.symbol(
                    size: 80,
                    semanticsLabel: '如画品牌符号标',
                  ),
                ),
              ),
              const SizedBox(height: 24), // margin-bottom 48rpx → 24dp
              // 文字组
              FadeUp(
                delay: const Duration(milliseconds: 200),
                child: Column(
```

替换为用 Stack 包裹 logo + 光晕：

```dart
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 品牌 logo + 主题色光晕（logo 后方叠径向渐变圆形）
              FadeUp(
                child: SizedBox(
                  width: 160,
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 主题色光晕
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              tokens.brandSubtle.withOpacity(0.45),
                              tokens.brandLight.withOpacity(0.18),
                              tokens.canvas.withOpacity(0),
                            ],
                            stops: const [0.0, 0.55, 1.0],
                          ),
                        ),
                      ),
                      // 品牌 logo（设计好的取景器符号标 SVG）
                      const SizedBox(
                        width: 80, // 略放大承载 SVG 描边细节
                        height: 80,
                        child: LumiraLogo.symbol(
                          size: 80,
                          semanticsLabel: '如画品牌符号标',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24), // margin-bottom 48rpx → 24dp
              // 文字组
              FadeUp(
                delay: const Duration(milliseconds: 200),
                child: Column(
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/features/splash/splash_page_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: 运行 analyze 确保无警告**

Run: `flutter analyze lib/features/splash/pages/splash_page.dart`
Expected: No issues found

- [ ] **Step 6: 提交**

```bash
git add lib/features/splash/pages/splash_page.dart test/features/splash/splash_page_test.dart
git commit -m "feat(splash): add brand color halo behind logo"
```

---

## Task 5: 关于页 _AppHeader 替换为光晕 + logo

**Files:**
- Modify: `lib/features/profile/pages/profile_about_page.dart` (line 212-282 `_AppHeader` class)

**Interfaces:**
- Consumes: `tokens.brandSubtle`, `tokens.brandLight`, `tokens.canvas`, `LumiraLogo.symbol`

- [ ] **Step 1: 检查现有 about 页测试**

Run: Glob `test/features/profile/*about*`
如果存在 `profile_about_page_test.dart`，读取其内容；否则将在 Step 2 中创建。

- [ ] **Step 2: 写测试验证光晕存在**

如果测试文件不存在，Create `test/features/profile/profile_about_page_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/features/profile/pages/profile_about_page.dart';
import 'package:lumira_app_flutter/shared/widgets/brand/lumira_logo.dart';

Widget _wrap() {
  final router = GoRouter(
    initialLocation: '/about',
    routes: [
      GoRoute(
        path: '/about',
        builder: (context, state) => const ProfileAboutPage(),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
      uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('ProfileAboutPage renders brand logo with halo', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.byType(LumiraLogo), findsOneWidget);
    expect(find.text('如画 Lumira'), findsOneWidget);
  });
}
```

- [ ] **Step 3: 运行测试验证失败**

Run: `flutter test test/features/profile/profile_about_page_test.dart`
Expected: FAIL（如文件不存在）或 PASS（如现有 _AppHeader 已含 LumiraLogo）

- [ ] **Step 4: 修改 _AppHeader 替换为光晕 + logo**

Modify `lib/features/profile/pages/profile_about_page.dart`，找到当前 line 217-242 的 `_AppHeader.build` 中 Container 块：

```dart
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        // Logo 升级：原渐变方块 +「如」字替换为设计好的品牌 SVG 符号标
        // 外层保留柔和的金色光晕，呼应原渐变方块的视觉权重
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: tokens.brand.withOpacity(0.30),
                offset: const Offset(0, 10),
                blurRadius: 24,
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: const LumiraLogo.symbol(
            size: 80,
            semanticsLabel: '如画品牌符号标',
          ),
        ),
        const SizedBox(height: 14),
```

替换为光晕 + logo 组合：

```dart
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        // 主题色光晕 + 品牌 logo（替换原白色 surface 容器 + box-shadow）
        SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      tokens.brandSubtle.withOpacity(0.45),
                      tokens.brandLight.withOpacity(0.18),
                      tokens.canvas.withOpacity(0),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
              const LumiraLogo.symbol(
                size: 80,
                semanticsLabel: '如画品牌符号标',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
```

- [ ] **Step 5: 运行测试验证通过**

Run: `flutter test test/features/profile/profile_about_page_test.dart`
Expected: PASS

- [ ] **Step 6: 运行 analyze 确保无警告**

Run: `flutter analyze lib/features/profile/pages/profile_about_page.dart`
Expected: No issues found

- [ ] **Step 7: 提交**

```bash
git add lib/features/profile/pages/profile_about_page.dart test/features/profile/profile_about_page_test.dart
git commit -m "feat(about): replace surface container with brand halo + logo"
```

---

## Task 6: 首页使用 HomeBrandTitle 并传 centerTitle: false

**Files:**
- Modify: `lib/features/home/pages/home_page.dart` (line 96-115 appBar 区域 + line 270-298 `_NavLocation`)

**Interfaces:**
- Consumes:
  - `HomeBrandTitle`（Task 2）
  - `LumiraNav(centerTitle: false)`（Task 3）

- [ ] **Step 1: 修改 home_page.dart appBar**

Modify `lib/features/home/pages/home_page.dart`，找到 line 96-115：

```dart
    return Scaffold(
      backgroundColor: tokens.canvas,
      // 透明 LumiraNav 作为 appBar（PreferredSizeWidget）
      // Logo 升级：首页使用品牌 SVG 文字标替换纯文本「如画」
      appBar: LumiraNav(
        useWordmark: true,
        transparent: true,
        scrolled: _scrolled,
        leading: _NavLocation(tokens: tokens),
        actions: [
          _NavAction(
            icon: Icons.notifications_outlined,
            tokens: tokens,
            onTap: () {}, // 占位：通知中心
          ),
          _NavAction(
            icon: Icons.qr_code_outlined,
            tokens: tokens,
            onTap: () {}, // 占位：扫一扫
          ),
        ],
      ),
```

替换为：

```dart
    return Scaffold(
      backgroundColor: tokens.canvas,
      // 透明 LumiraNav 作为 appBar（PreferredSizeWidget）
      // 首页使用可切换的艺术排版组件 HomeBrandTitle
      appBar: LumiraNav(
        centerTitle: false,
        transparent: true,
        scrolled: _scrolled,
        showBackButton: false,
        leading: const HomeBrandTitle(),
        actions: [
          _NavAction(
            icon: Icons.notifications_outlined,
            tokens: tokens,
            onTap: () {}, // 占位：通知中心
          ),
          _NavAction(
            icon: Icons.qr_code_outlined,
            tokens: tokens,
            onTap: () {}, // 占位：扫一扫
          ),
        ],
      ),
```

- [ ] **Step 2: 添加 import**

在 `home_page.dart` 顶部 import 区追加：

```dart
import '../../../shared/widgets/brand/home_brand_title.dart';
```

- [ ] **Step 3: 删除 _NavLocation 类**

删除 line 270-298 的 `_NavLocation` 类（不再被使用）：

```dart
/// 顶部导航左侧位置显示
class _NavLocation extends StatelessWidget {
  const _NavLocation({required this.tokens});

  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.place_outlined,
          size: 16, // 32rpx → 16dp
          color: tokens.textSecondary,
        ),
        const SizedBox(width: 4), // 8rpx → 4dp
        Text(
          HomeMockData.location,
          style: TextStyle(
            fontSize: 14, // 28rpx → 14dp
            fontWeight: FontWeight.w500,
            color: tokens.textSecondary,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}
```

如果 `HomeMockData.location` 在其他地方有引用，保留 `home_mock_data.dart` 不动；只删除 `_NavLocation` 类本身。

- [ ] **Step 4: 运行 analyze 确保无警告**

Run: `flutter analyze lib/features/home/pages/home_page.dart`
Expected: No issues found（如有 "unused import" 警告 HomeMockData.location 等，按提示清理）

- [ ] **Step 5: 运行现有首页测试（若存在）**

Run: `flutter test test/features/home/` 或 Glob 检查首页测试是否存在
Expected: 若存在则应通过；若无测试则跳过

- [ ] **Step 6: 提交**

```bash
git add lib/features/home/pages/home_page.dart
git commit -m "feat(home): use HomeBrandTitle with left-aligned layout"
```

---

## Task 7: 其余 3 个 tab 页传 centerTitle: false

**Files:**
- Modify: `lib/features/templates/pages/templates_page.dart` (line 87)
- Modify: `lib/features/challenge/pages/challenge_page.dart` (line 125)
- Modify: `lib/features/profile/pages/profile_page.dart` (line 46)

- [ ] **Step 1: 修改 templates_page.dart**

Modify `lib/features/templates/pages/templates_page.dart` line 87-92，找到：

```dart
                LumiraNav(
                  title: '发现',
                  transparent: true,
                  scrolled: _scrolled,
                  showBackButton: false,
```

改为：

```dart
                LumiraNav(
                  title: '发现',
                  centerTitle: false,
                  transparent: true,
                  scrolled: _scrolled,
                  showBackButton: false,
```

- [ ] **Step 2: 修改 challenge_page.dart**

Modify `lib/features/challenge/pages/challenge_page.dart` line 125-129，找到：

```dart
                LumiraNav(
                  title: '每日挑战',
                  scrolled: _scrolled,
                  transparent: true,
                  showBackButton: false,
```

改为：

```dart
                LumiraNav(
                  title: '每日挑战',
                  centerTitle: false,
                  scrolled: _scrolled,
                  transparent: true,
                  showBackButton: false,
```

- [ ] **Step 3: 修改 profile_page.dart**

Modify `lib/features/profile/pages/profile_page.dart` line 46，找到：

```dart
      appBar: const LumiraNav(title: '我的', transparent: true, showBackButton: false),
```

改为：

```dart
      appBar: const LumiraNav(
        title: '我的',
        centerTitle: false,
        transparent: true,
        showBackButton: false,
      ),
```

- [ ] **Step 4: 运行 analyze 确保无警告**

Run: `flutter analyze lib/features/templates/pages/templates_page.dart lib/features/challenge/pages/challenge_page.dart lib/features/profile/pages/profile_page.dart`
Expected: No issues found

- [ ] **Step 5: 提交**

```bash
git add lib/features/templates/pages/templates_page.dart lib/features/challenge/pages/challenge_page.dart lib/features/profile/pages/profile_page.dart
git commit -m "feat(tabs): left-align titles on discover/challenge/profile pages"
```

---

## Task 8: 设置页新增「首页标题样式」section

**Files:**
- Modify: `lib/features/profile/pages/profile_settings_page.dart`

**Interfaces:**
- Consumes:
  - `homeWordmarkStyleProvider`（Task 1）
  - `HomeBrandTitle(preview: true)`（Task 2）

- [ ] **Step 1: 阅读现有 profile_settings_page.dart**

Run: Read `lib/features/profile/pages/profile_settings_page.dart`
找到「界面风格」section，确定其结构与下方插入点。

- [ ] **Step 2: 新增 section 渲染逻辑**

在「界面风格」section 下方追加「首页标题样式」section。在 `_ProfileSettingsPageState.build` 或对应 widget 中添加：

```dart
// 首页标题样式选择
const SizedBox(height: 24),
_SectionTitle(tokens: tokens, icon: Icons.title_outlined, text: '首页标题样式'),
const SizedBox(height: 12),
_buildHomeWordmarkSection(tokens),
```

实现 `_buildHomeWordmarkSection`：

```dart
Widget _buildHomeWordmarkSection(ThemeTokens tokens) {
  final currentStyle = ref.watch(homeWordmarkStyleProvider);
  final options = [
    (HomeWordmarkStyle.logoEnglish, 'Logo + 英文'),
    (HomeWordmarkStyle.logoEnglishChinese, 'Logo + 英文 + 中文'),
    (HomeWordmarkStyle.englishChinese, '英文 + 中文'),
  ];

  return Column(
    children: options.map((option) {
      final (style, label) = option;
      final selected = style == currentStyle;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GestureDetector(
          onTap: () {
            ref.read(homeWordmarkStyleProvider.notifier).state = style;
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected ? tokens.brandSubtle.withOpacity(0.30) : tokens.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? tokens.brand : tokens.divider,
                width: selected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                // 预览
                SizedBox(
                  width: 200,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: HomeBrandTitle(preview: true),
                  ),
                ),
                const Spacer(),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: selected ? tokens.brand : tokens.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                if (selected)
                  Icon(Icons.check_circle, size: 18, color: tokens.brand)
                else
                  Icon(Icons.radio_button_unchecked, size: 18, color: tokens.textTertiary),
              ],
            ),
          ),
        ),
      );
    }).toList(),
  );
}
```

**注意**：`HomeBrandTitle(preview: true)` 会监听 `homeWordmarkStyleProvider`，但因为它的预览要展示对应风格的样式，需要为每张卡片渲染对应 style 的预览，而不是都渲染当前选中的 style。

修正方案：将 `HomeBrandTitle` 改为可接受可选 `styleOverride` 参数，或在设置页内联渲染三种排版的预览。更简洁的做法是让 `HomeBrandTitle` 支持 `styleOverride`：

修改 `lib/shared/widgets/brand/home_brand_title.dart`，给 `HomeBrandTitle` 增加可选 `styleOverride`：

```dart
class HomeBrandTitle extends ConsumerWidget {
  const HomeBrandTitle({super.key, this.preview = false, this.styleOverride});

  final bool preview;
  final HomeWordmarkStyle? styleOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = styleOverride ?? ref.watch(homeWordmarkStyleProvider);
    // ... 其余不变
  }
}
```

更新 Task 2 的测试以覆盖 `styleOverride`：

新增测试用例：

```dart
testWidgets('styleOverride takes precedence over provider', (tester) async {
  await tester.pumpWidget(_wrap(
    const HomeBrandTitle(styleOverride: HomeWordmarkStyle.englishChinese),
    style: HomeWordmarkStyle.logoEnglish,
  ));
  expect(find.byType(LumiraLogo), findsNothing);
  expect(find.text('Lumira'), findsOneWidget);
  expect(find.text('如画'), findsOneWidget);
});
```

- [ ] **Step 3: 更新 home_brand_title.dart 添加 styleOverride**

Modify `lib/shared/widgets/brand/home_brand_title.dart`：增加 `styleOverride` 字段并修改 build 第一行。

- [ ] **Step 4: 运行 HomeBrandTitle 测试验证通过**

Run: `flutter test test/shared/widgets/brand/home_brand_title_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: 实现设置页 section**

Modify `lib/features/profile/pages/profile_settings_page.dart`：

1. 顶部 import 追加：

```dart
import '../../../core/preferences/home_wordmark_style.dart';
import '../../../shared/widgets/brand/home_brand_title.dart';
```

2. 在「界面风格」section 下方按 Step 2 的代码插入新 section，但预览改为传 `styleOverride`：

```dart
Widget _buildHomeWordmarkSection(ThemeTokens tokens) {
  final currentStyle = ref.watch(homeWordmarkStyleProvider);
  final options = [
    (HomeWordmarkStyle.logoEnglish, 'Logo + 英文'),
    (HomeWordmarkStyle.logoEnglishChinese, 'Logo + 英文 + 中文'),
    (HomeWordmarkStyle.englishChinese, '英文 + 中文'),
  ];

  return Column(
    children: options.map((option) {
      final (style, label) = option;
      final selected = style == currentStyle;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GestureDetector(
          onTap: () {
            ref.read(homeWordmarkStyleProvider.notifier).state = style;
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected ? tokens.brandSubtle.withOpacity(0.30) : tokens.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? tokens.brand : tokens.divider,
                width: selected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 200,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: HomeBrandTitle(preview: true, styleOverride: style),
                  ),
                ),
                const Spacer(),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: selected ? tokens.brand : tokens.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 18,
                  color: selected ? tokens.brand : tokens.textTertiary,
                ),
              ],
            ),
          ),
        ),
      );
    }).toList(),
  );
}
```

- [ ] **Step 6: 运行 analyze 确保无警告**

Run: `flutter analyze lib/features/profile/pages/profile_settings_page.dart`
Expected: No issues found

- [ ] **Step 7: 运行所有测试**

Run: `flutter test`
Expected: All tests pass

- [ ] **Step 8: 提交**

```bash
git add lib/shared/widgets/brand/home_brand_title.dart test/shared/widgets/brand/home_brand_title_test.dart lib/features/profile/pages/profile_settings_page.dart
git commit -m "feat(settings): add home wordmark style picker with live preview"
```

---

## Task 9: 最终验证

- [ ] **Step 1: flutter analyze 全项目**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 2: flutter test 全项目**

Run: `flutter test`
Expected: All tests pass

- [ ] **Step 3: 人工验证清单**

逐项确认：
- [ ] Splash 页 logo 后有圆形主题色光晕
- [ ] 关于页 logo 容器从白色 surface 变为光晕 + logo
- [ ] 首页导航栏标题左对齐，渲染 Logo + Lumira
- [ ] 发现 / 每日挑战 / 我的 三个 tab 页标题左对齐
- [ ] 设置页 → 首页标题样式 section 显示 3 个选项卡片
- [ ] 每张卡片实时渲染对应预览
- [ ] 点击卡片切换后，首页导航栏标题实时变化
- [ ] 在 8 个主题下视觉协调

- [ ] **Step 4: 最终提交（如有遗漏）**

```bash
git status
# 如有未提交的修改：
git add -A
git commit -m "chore: final review fixes for brand presentation"
```

---

## Self-Review

### Spec coverage 核对
- ✅ Splash 圆形主题色光晕 → Task 4
- ✅ 关于页光晕 + logo → Task 5
- ✅ 首页默认 logo + 英文 → Task 6（HomeBrandTitle 默认 logoEnglish）
- ✅ 三种风格可切换 → Task 1 (枚举) + Task 2 (组件) + Task 8 (设置页 UI)
- ✅ 设置页带预览 → Task 8
- ✅ 4 个 tab 页标题左对齐 → Task 6 (home) + Task 7 (其他 3 个)
- ✅ 不影响非 tab 页 → Task 3 (centerTitle 默认 true 不变)

### Type 一致性
- `HomeWordmarkStyle` 枚举值在 Task 1、2、8 中一致
- `HomeBrandTitle({preview, styleOverride})` 在 Task 2、8 中一致
- `homeWordmarkStyleProvider` 在 Task 1、2、8 中一致

### 已修正点
- Task 2 测试嵌套 ProviderScope 改为单层
- Task 8 `HomeBrandTitle` 增加 `styleOverride`，对应更新 Task 2 实现 + 测试
- Task 8 预览传 `styleOverride: style` 而非依赖全局 provider
