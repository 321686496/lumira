# 新拟态暗色浮雕 + ParamPanel 工具条化重构 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复拍摄预览页黑底上新拟态编辑卡片无浮雕的问题（暗色语境浮雕），并把拍摄页参数弹出栏从 520px 文字 Tab 抽屉重构为「图标工具条 + 点选滑出控件区」（总高 ≤220，视觉全主题化）。

**Architecture:** Part 1 在 `LumiraThemeResolver` 增加 `darkNeuPalette`（从主题 canvas lerp 派生近黑三色配色）+ `cardVisual(darkContext)` 分支，`LumiraSurface` 透传参数，预览页 dock 开启。Part 2 把 `param_panel.dart` 整体重写为 ConsumerStatefulWidget（工具条状态本地持有），控件复用 `AdjustPanel`/`AdjustSlider`（后者从 `_EditSlider` 公开化并加 `accentColor`/`format` 参数），容器视觉按 4 风格 × 8 主题派生，白平衡/参数写入逻辑从旧版原样迁移。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6 / flutter_riverpod 2.3.6 / flutter_test

**Spec:** `docs/specs/2026-09-08-neu-dock-relief-and-param-panel-redesign-design.md`

## Global Constraints

- Dart 2.19.6：**禁止 Dart 3 语法**（records `(a, b)`、switch 表达式 `switch =>`、sealed class）；switch 必须用语句形式
- UI 铁律：所有主题相关颜色必须从 `appThemeProvider`（`tokens`/`style`）派生，禁止 `Color(0xFF...)` 表达皮肤观感；唯一例外是黑/白半透明遮罩（暗色语境文字白色系合法，先例 = ParamPillBar）
- 新拟态叠在照片/取景器动态画面上：无外阴影、无模糊，用「半透明暗底 + 细边」
- 测试与构建命令在 `e:\Project\photo_post\lumira_app_flutter` 目录下执行（PowerShell，`;` 分隔，不支持 `&&`）
- commit 仅本地提交（AGENTS.md 仅要求 backend/admin 改动推送双远程；Flutter 改动不推送）
- 旧参数写入行为（`CaptureState.updateCamera` / `updatePostProcess` / `updateComposition` / `resetFreeModeParams` / 白平衡应用逻辑 + iOS 残差拉取 / OHOS 隐藏色温滑块）不得改变，只迁移位置

---

### Task 1: 暗色语境新拟态浮雕（resolver + LumiraSurface）

**Files:**
- Modify: `lumira_app_flutter/lib/shared/widgets/lumira/_internal/lumira_theme_resolver.dart`
- Modify: `lumira_app_flutter/lib/shared/widgets/common/lumira_surface.dart`
- Test: `lumira_app_flutter/test/shared/widgets/common/lumira_surface_test.dart`（新建）

**Interfaces:**
- Produces: `LumiraThemeResolver.darkNeuPalette(ThemeTokens tokens) → DarkNeuPalette`（类字段 `surface`/`shadow`/`highlight`，均 `Color`）；`LumiraThemeResolver.cardVisual({tokens, style, radiusDp, emphasize, darkContext})`（新增 `bool darkContext = false`）；`LumiraSurface({darkContext})`（新增 `bool darkContext = false`，默认 false）
- 后续任务消费：Task 2 传 `darkContext: true`；Task 4 用 `LumiraThemeResolver.darkNeuPalette(tokens)` 取暗色底

- [ ] **Step 1: 写失败测试**

新建 `lumira_app_flutter/test/shared/widgets/common/lumira_surface_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/shared/widgets/common/lumira_surface.dart';

void main() {
  Widget wrapWithTheme(
    Widget child, {
    ThemeKey theme = ThemeKey.warmWhite,
    UIStyle style = UIStyle.neumorphic,
  }) {
    return ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => theme),
        uiStyleProvider.overrideWith((ref) => style),
      ],
      child: MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: child),
        ),
      ),
    );
  }

  BoxDecoration decorationOf(WidgetTester tester) {
    final container = tester.widget<Container>(find.ancestor(
      of: find.text('hello'),
      matching: find.byType(Container),
    ).first);
    return container.decoration as BoxDecoration;
  }

  group('LumiraSurface.darkContext 新拟态暗色语境', () {
    testWidgets('darkContext=true 渲染近黑卡面 + 双向浮雕明暗梯度', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const LumiraSurface(darkContext: true, child: Text('hello')),
      ));
      await tester.pumpAndSettle();

      final deco = decorationOf(tester);
      final tokens = ThemeTokens.of(ThemeKey.warmWhite);
      final expectedBg = Color.lerp(Colors.black, tokens.canvas, 0.10)!;

      expect(deco.color, expectedBg);
      expect(deco.boxShadow, isNotNull);
      expect(deco.boxShadow!.length, 2);

      // 梯度：高光 > 卡面 > 暗影（黑底上的真浮雕方向感）
      final dark = deco.boxShadow![0];
      final light = deco.boxShadow![1];
      expect(light.color.computeLuminance(),
          greaterThan(dark.color.computeLuminance()));
      expect(light.color.computeLuminance(),
          greaterThan(expectedBg.computeLuminance()));
      expect(expectedBg.computeLuminance(),
          greaterThan(dark.color.computeLuminance()));
      // 暗影右下、高光左上（轻量档 offset）
      expect(dark.offset, const Offset(4, 4));
      expect(light.offset, const Offset(-4, -4));
    });

    testWidgets('darkContext=true + emphasize 用强浮雕偏移', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const LumiraSurface(
            darkContext: true, emphasize: true, child: Text('hello')),
      ));
      await tester.pumpAndSettle();

      final deco = decorationOf(tester);
      expect(deco.boxShadow![0].offset, const Offset(6, 6));
      expect(deco.boxShadow![1].offset, const Offset(-6, -6));
    });

    testWidgets('darkContext=false 保持原有浅色卡表现', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const LumiraSurface(child: Text('hello')),
      ));
      await tester.pumpAndSettle();

      final deco = decorationOf(tester);
      final tokens = ThemeTokens.of(ThemeKey.warmWhite);
      expect(deco.color, tokens.surface);
      expect(deco.boxShadow, tokens.shadowConvexSubtle);
    });

    testWidgets('ink 主题下 darkContext 同样成立明暗梯度', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const LumiraSurface(darkContext: true, child: Text('hello')),
        theme: ThemeKey.ink,
      ));
      await tester.pumpAndSettle();

      final deco = decorationOf(tester);
      final tokens = ThemeTokens.of(ThemeKey.ink);
      expect(deco.color, Color.lerp(Colors.black, tokens.canvas, 0.10)!);
      expect(deco.boxShadow![1].color.computeLuminance(),
          greaterThan(deco.boxShadow![0].color.computeLuminance()));
    });

    testWidgets('flat/glass/female 风格不受 darkContext 影响', (tester) async {
      for (final style in [UIStyle.flat, UIStyle.glass, UIStyle.female]) {
        await tester.pumpWidget(wrapWithTheme(
          const LumiraSurface(darkContext: true, child: Text('hello')),
          style: style,
        ));
        await tester.pumpAndSettle();

        final deco = decorationOf(tester);
        expect(deco.color, isNotNull);
        if (style == UIStyle.flat) {
          final tokens = ThemeTokens.of(ThemeKey.warmWhite);
          expect(deco.color, tokens.surfaceAlt);
        }
      }
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```powershell
flutter test test/shared/widgets/common/lumira_surface_test.dart
```

预期：FAIL（`darkContext` 参数不存在 → 编译错误 "No named parameter 'darkContext'"）

- [ ] **Step 3: 实现 resolver 与 LumiraSurface**

`lumira_theme_resolver.dart` — 修改 `cardVisual`（签名 + neumorphic 分支，其余分支原样保留）：

```dart
  /// 解析通用「卡片/内容块」表面的视觉规格（空态卡、信息卡、分隔块等）。
  ///
  /// - [radiusDp]：已转换为 dp 的圆角值
  /// - [emphasize]：true 用强浮雕 [shadowConvex]，false 用轻量 [shadowConvexSubtle]
  /// - [darkContext]：true = 渲染在黑画布上（如预览页沉浸式看图）。
  ///   仅对 neumorphic 生效：卡面近黑带主题色调 + 深暗影 + 微亮高光
  ///   （见 [darkNeuPalette]）；其余风格不受影响。
  static ContainerVisual cardVisual({
    required ThemeTokens tokens,
    required UIStyle style,
    required double radiusDp,
    bool emphasize = false,
    bool darkContext = false,
  }) {
    final convex = emphasize ? tokens.shadowConvex : tokens.shadowConvexSubtle;
    switch (style) {
      case UIStyle.neumorphic:
        if (darkContext) {
          // 黑画布浮雕：近黑卡面 + 更深暗影 + 微亮高光（明暗梯度见 darkNeuPalette）
          final p = darkNeuPalette(tokens);
          final offset = emphasize ? const Offset(6, 6) : const Offset(4, 4);
          final blur = emphasize ? 14.0 : 8.0;
          return ContainerVisual(
            background: p.surface,
            border: null,
            shadows: [
              BoxShadow(color: p.shadow, offset: offset, blurRadius: blur),
              BoxShadow(color: p.highlight, offset: -offset, blurRadius: blur),
            ],
            backdropBlurSigma: 0,
            glassOverlay: null,
          );
        }
        return ContainerVisual(
          background: tokens.surface,
          border: null,
          shadows: convex,
          backdropBlurSigma: 0,
          glassOverlay: null,
        );
      case UIStyle.flat:
      // flat / glass / female 分支体原样保留（darkContext 仅对 neumorphic 生效）
      case UIStyle.glass:
      case UIStyle.female:
        // …（保持现有代码不变，此处仅为标注）
        break;
    }
    // 兜底：非 neumorphic 的旧逻辑维持原 switch 结构
  }
```

实现说明：实际代码里 flat/glass/female 分支体**原样保留**在同一个 switch 里（上面伪标注仅为指示修改位置，不要写出 `break` 跳过——保持每个 case 各自 `return ContainerVisual(...)` 的现有写法）。关键改动只有两处：

(a) 签名加 `bool darkContext = false`；
(b) `case UIStyle.neumorphic:` 分支体开头插入 `if (darkContext) { ... return ...; }`（如上代码块所示），原有的 `return ContainerVisual(background: tokens.surface, ...)` 保留在 if 之后。

在 `overlayOnImageVisual` 方法之前新增：

```dart
  /// 暗色语境（黑画布，如拍摄预览页沉浸式看图）新拟态配色。
  ///
  /// 「组件与背景同色」铁律在黑画布上的推论：卡面近黑带主题色调
  /// （canvas 10%），右下暗影更深（3%）、左上高光比卡面微亮（22%），
  /// 形成黑底上的真浮雕明暗梯度。亮/暗主题均适用：全部从当前主题
  /// canvas lerp 派生，不复制 ink 色值。
  static DarkNeuPalette darkNeuPalette(ThemeTokens tokens) => DarkNeuPalette(
        surface: Color.lerp(Colors.black, tokens.canvas, 0.10)!,
        shadow: Color.lerp(Colors.black, tokens.canvas, 0.03)!,
        highlight: Color.lerp(Colors.black, tokens.canvas, 0.22)!,
      );
```

在文件末尾 `ContainerVisual` 类之后新增：

```dart
/// 暗色语境新拟态三色配色（卡面/暗影/高光），
/// 由 [LumiraThemeResolver.darkNeuPalette] 派生。
class DarkNeuPalette {
  final Color surface;
  final Color shadow;
  final Color highlight;
  const DarkNeuPalette({
    required this.surface,
    required this.shadow,
    required this.highlight,
  });
}
```

`lumira_surface.dart` — 构造函数新增参数、字段、透传：

```dart
  const LumiraSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius,
    this.emphasize = false,
    this.color,
    this.clip = false,
    this.darkContext = false,
  });
```

字段区新增（`clip` 字段之后）：

```dart
  /// true = 渲染在黑画布上（如预览页沉浸式看图）：新拟态走暗色浮雕
  /// （近黑卡面 + 深暗影 + 微亮高光）；其余风格不受影响
  final bool darkContext;
```

`build` 中调用改为：

```dart
    final visual = LumiraThemeResolver.cardVisual(
      tokens: tokens,
      style: appTheme.style,
      radiusDp: radius ?? 14,
      emphasize: emphasize,
      darkContext: darkContext,
    );
```

- [ ] **Step 4: 运行测试确认通过**

```powershell
flutter test test/shared/widgets/common/lumira_surface_test.dart
```

预期：PASS（5 个用例全绿）

- [ ] **Step 5: analyze 并提交**

```powershell
flutter analyze
```

预期：无新增 issue（重点关注 `lumira_theme_resolver.dart` / `lumira_surface.dart`）

```powershell
git add lumira_app_flutter/lib/shared/widgets/lumira/_internal/lumira_theme_resolver.dart lumira_app_flutter/lib/shared/widgets/common/lumira_surface.dart lumira_app_flutter/test/shared/widgets/common/lumira_surface_test.dart
git commit -m "feat(theme): 新拟态暗色语境浮雕（LumiraSurface.darkContext + darkNeuPalette）"
```

---

### Task 2: 预览页编辑 dock 开启暗色浮雕

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/pages/capture_preview_page.dart`（`_buildEditDock`，约 1489-1494 行）

**Interfaces:**
- Consumes: Task 1 的 `LumiraSurface({darkContext})`

- [ ] **Step 1: 修改 dock 传参**

`_buildEditDock` 中 `LumiraSurface` 增加 `darkContext: true`（其余内容与注释不动）：

```dart
    return SafeArea(
      top: false,
      child: LumiraSurface(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        radius: 20,
        clip: true,
        darkContext: true,
        child: Column(
```

- [ ] **Step 2: 回归预览页测试**

```powershell
flutter test test/features/capture/capture_preview_page_test.dart test/features/capture/capture_preview_edit_integration_test.dart test/features/capture/capture_preview_scene_test.dart test/features/capture/capture_preview_share_test.dart
```

预期：PASS（darkContext 只改 neumorphic 分支的卡面/阴影颜色，测试断言行为不受影响）

- [ ] **Step 3: 提交**

```powershell
git add lumira_app_flutter/lib/features/capture/pages/capture_preview_page.dart
git commit -m "fix(capture): 预览页黑底编辑 dock 新拟态浮雕修复（darkContext）"
```

---

### Task 3: AdjustSlider 公开化 + accentColor/format 参数

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/widgets/post_process_adjust_panel.dart`
- Test: `lumira_app_flutter/test/features/capture/widgets/adjust_slider_test.dart`（新建）

**Interfaces:**
- Produces: 公开类 `AdjustSlider({label, value, min, max, onChanged, tokens?, hint?, accentColor?, format?})`（自 `_EditSlider` 改名公开）；`AdjustPanel({defs, full, onChanged, tokens?, accentColor?})`（新增可选 `accentColor`）；`_AdjustStripChip({def, selected, tokens?, accentColor?, onTap})`
- 现有调用方 `PostProcessColorTab` / `PostProcessDetailTab` 签名兼容，不改动
- 后续任务消费：Task 4 的 ParamPanel 用 `AdjustSlider`（EV/色温/透明度）与 `AdjustPanel`（色彩/细节）传 `accentColor: tokens.brand`

- [ ] **Step 1: 写失败测试**

新建 `lumira_app_flutter/test/features/capture/widgets/adjust_slider_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/capture/widgets/post_process_adjust_panel.dart';

void main() {
  group('AdjustSlider', () {
    testWidgets('自定义 format 与 accentColor 生效', (tester) async {
      const accent = Color(0xFF123456);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: AdjustSlider(
              label: 'EV',
              value: 1.2,
              min: -3,
              max: 3,
              accentColor: accent,
              format: (v) =>
                  v >= 0 ? '+${v.toStringAsFixed(1)}' : v.toStringAsFixed(1),
              onChanged: (_) {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // 自定义格式：'+1.2'
      expect(find.text('+1.2'), findsOneWidget);

      // 填充轨道 / 把手描边使用传入 accent
      final decos = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .toList();
      expect(decos.any((d) => d.color == accent), isTrue);
      expect(
        decos.any(
            (d) => d.border is Border && (d.border as Border).top.color == accent),
        isTrue,
      );
    });

    testWidgets('默认整型格式（负数带负号）', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: AdjustSlider(
              label: '亮度',
              value: -5,
              min: -100,
              max: 100,
              onChanged: (_) {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('-5'), findsOneWidget);
    });

    testWidgets('拖动回调新值（向右拖 → 值增大）', (tester) async {
      double? changed;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: AdjustSlider(
              label: 'EV',
              value: 0,
              min: -3,
              max: 3,
              onChanged: (v) => changed = v,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(AdjustSlider), const Offset(200, 0));
      await tester.pumpAndSettle();

      final v = changed;
      expect(v, isNotNull);
      if (v != null) {
        expect(v, greaterThan(0));
      }
    });

    testWidgets('AdjustPanel accentColor 传递到选中 chip', (tester) async {
      const accent = Color(0xFF00AA00);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 160,
              child: AdjustPanel(
                defs: colorAdjustDefs(),
                full: const PostProcess(),
                onChanged: (_) {},
                accentColor: accent,
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // 默认选中第 0 项（亮度）：圆形图标底 = accent
      final decos = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .toList();
      expect(decos.any((d) => d.color == accent), isTrue);
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```powershell
flutter test test/features/capture/widgets/adjust_slider_test.dart
```

预期：FAIL（`AdjustSlider` / `accentColor` 未公开 → 编译错误）

- [ ] **Step 3: 实现公开化**

`post_process_adjust_panel.dart` 修改三处：

1. `_EditSlider` 改名为 `AdjustSlider`（公开），新增字段（构造函数相应增加，其余逻辑不变）：

```dart
/// 单滑块（名称 + 数值 + 轨道 + 可选提示文字）。
///
/// 公开复用：拍摄页 ParamPanel（EV/色温/透明度）与编辑面板共用同一质感。
/// [accentColor]：暗色语境强调色（null 时走 tokens / 默认 fallback）；
/// [format]：数值格式化（null 时默认整型 +/-）。
class AdjustSlider extends StatefulWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ThemeTokens? tokens;
  final ValueChanged<double> onChanged;
  final String? hint;
  final Color? accentColor;
  final String Function(double)? format;

  const AdjustSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.tokens,
    this.hint,
    this.accentColor,
    this.format,
  });

  @override
  State<AdjustSlider> createState() => _AdjustSliderState();
}

class _AdjustSliderState extends State<AdjustSlider> {
  double _dragValue = double.nan;

  double get _effectiveValue =>
      _dragValue.isNaN ? widget.value : _dragValue;

  @override
  void didUpdateWidget(AdjustSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _dragValue = double.nan;
    }
  }

  String _format(double v) {
    if (widget.format != null) {
      return widget.format!(v);
    }
    final rounded = v.round();
    return rounded > 0 ? '+$rounded' : '$rounded';
  }
```

`build` 内颜色派生改为（accent 优先；`labelColor`/`trackColor`/`thumbFillColor`/`hintColor` 不变）：

```dart
    final labelColor = t?.textSecondary ?? Colors.white70;
    final valueColor = t?.textSecondary ?? Colors.white54;
    final accent = widget.accentColor ?? (t?.brand ?? const Color(0xFFE5C07B));
    final valueActiveColor = accent;
    final trackColor = t?.divider ?? Colors.white24;
    final fillColor = accent;
    final thumbBorderColor = accent;
    final thumbFillColor = t?.surface ?? Colors.white;
    final hintColor = t?.textTertiary ?? Colors.white38;
```

（手势、布局、Stack 结构原样；文件内所有 `_EditSlider` 引用随改名更新为 `AdjustSlider`）

2. `_AdjustStripChip` 增加 `accentColor`，选中色 accent 优先：

```dart
class _AdjustStripChip extends StatelessWidget {
  final AdjustDef def;
  final bool selected;
  final ThemeTokens? tokens;
  final Color? accentColor;
  final VoidCallback onTap;

  const _AdjustStripChip({
    required this.def,
    required this.selected,
    required this.tokens,
    required this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final accent = accentColor ?? (t?.brand ?? const Color(0xFFE5C07B));
    final bgColor = selected ? accent : (t?.surfaceAlt ?? Colors.white12);
    final iconColor = selected
        ? (t?.textInverse ?? Colors.black)
        : (t?.textSecondary ?? Colors.white70);
    final labelColor =
        selected ? accent : (t?.textSecondary ?? Colors.white70);
```

（GestureDetector / SizedBox / Column 主体不变）

3. `AdjustPanel` 增加 `accentColor` 并透传给 chip 与 slider：

```dart
  /// 暗色语境强调色（拍摄页 ParamPanel 传 tokens.brand）；null 走 tokens/fallback
  final Color? accentColor;

  const AdjustPanel({
    super.key,
    required this.defs,
    required this.full,
    required this.onChanged,
    this.tokens,
    this.accentColor,
  });
```

`build` 内 `_AdjustStripChip(...)` 增加 `accentColor: widget.accentColor`；`AdjustSlider(...)`（原 `_EditSlider(...)`）增加 `accentColor: widget.accentColor`。

- [ ] **Step 4: 运行测试确认通过**

```powershell
flutter test test/features/capture/widgets/adjust_slider_test.dart
```

预期：PASS（4 个用例全绿）

- [ ] **Step 5: 回归既有 AdjustPanel 使用方**

```powershell
flutter test test/features/capture
```

预期：PASS（签名只增可选参数，`PostProcessColorTab`/`PostProcessDetailTab` 及预览页/修图页测试不受影响）

- [ ] **Step 6: analyze 并提交**

```powershell
flutter analyze
```

预期：无新增 issue

```powershell
git add lumira_app_flutter/lib/features/capture/widgets/post_process_adjust_panel.dart lumira_app_flutter/test/features/capture/widgets/adjust_slider_test.dart
git commit -m "refactor(capture): AdjustSlider 公开复用，新增 accentColor/format 参数"
```

---

### Task 4: ParamPanel 重构（图标工具条 + 点选滑出）

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/widgets/param_panel.dart`（整体重写）
- Modify: `lumira_app_flutter/test/features/capture/widgets/param_panel_test.dart`（整体重写）
- Modify: `lumira_app_flutter/test/features/capture/capture_preview_template_page_test.dart`（约 264-284 行「5 tabs」用例）

**Interfaces:**
- Consumes: Task 1 的 `LumiraThemeResolver.darkNeuPalette(tokens)`；Task 3 的 `AdjustPanel({defs, full, onChanged, accentColor})` / `AdjustSlider({label, value, min, max, onChanged, accentColor, format})`；既有 `CaptureState.panelExpandedProvider` / `editableTemplateProvider` / `originalTemplateProvider` / `effectiveCameraProvider` / `effectivePostProcessProvider` / `effectiveCompositionProvider` / `effectiveSceneGuideProvider` / `freeModeCameraProvider` / `appliedProvider` / `updateCamera` / `updatePostProcess` / `updateComposition` / `resetFreeModeParams`；`whiteBalanceSessionProvider` / `refreshWbResidual` / `cameraServiceProvider`；`LumiraIconButton`（lumira.dart barrel）
- Produces: `ParamPanel`（类名与挂载点不变：`capture_page.dart` Stack 内 `const ParamPanel()`，无参构造）

**结构总览（实现对照）：**

```
Stack
├─ (expanded) Positioned.fill → GestureDetector(onTap: 关闭整栏)
└─ Positioned(left:0, right:0, bottom:0) → AnimatedSlide(关闭时 offset(0, 1.2))
   └─ _panelShell（按风格：neu 半透明暗底+细边 / glass 暗玻璃 / flat 暗底细边 / female 暗渐变）
      └─ Column(min)
         ├─ _HandleRow（拖动条 + 模板/自由徽标 + 重置 pill + 关闭图标）
         ├─ _ToolbarRow（7 个 _ToolItem：曝光/白平衡/闪光/色彩/细节/构图/场景）
         └─ AnimatedSize（0 ↔ 132）→ AnimatedSwitcher → 控件区
```

- [ ] **Step 1: 重写测试（先失败）**

用以下内容**整体替换** `lumira_app_flutter/test/features/capture/widgets/param_panel_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/widgets/param_panel.dart';
import 'package:lumira_app_flutter/features/capture/widgets/post_process_adjust_panel.dart';

void main() {
  /// 构建带主题 override 的测试宿主（ParamPanel 依赖 appThemeProvider）
  Future<void> host(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Stack(children: const [ParamPanel()]),
          ),
        ),
      ),
    );
  }

  ProviderContainer makeContainer({String? templateId}) {
    final container = ProviderContainer(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
      ],
    );
    addTearDown(container.dispose);
    if (templateId != null) {
      container
          .read(CaptureState.currentTemplateIdProvider.notifier)
          .state = templateId;
    }
    return container;
  }

  void expand(ProviderContainer container) {
    container.read(CaptureState.panelExpandedProvider.notifier).state = true;
  }

  group('ParamPanel 工具条结构', () {
    testWidgets('展开后显示 7 个工具 + 徽标 + 重置，无旧版“完成”按钮', (tester) async {
      final container = makeContainer(templateId: 'soft_portrait');
      await host(tester, container);
      expand(container);
      await tester.pumpAndSettle();

      expect(find.text('模板'), findsOneWidget);
      expect(find.text('重置'), findsOneWidget);
      for (final label in ['曝光', '白平衡', '闪光', '色彩', '细节', '构图', '场景']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('完成'), findsNothing);
      expect(find.text('相机'), findsNothing); // 旧文字 Tab 不再存在
    });

    testWidgets('自由模式显示“自由”徽标', (tester) async {
      final container = makeContainer();
      await host(tester, container);
      expand(container);
      await tester.pumpAndSettle();
      expect(find.text('自由'), findsOneWidget);
    });
  });

  group('ParamPanel 工具交互', () {
    testWidgets('点“曝光”滑出 EV 滑块，拖动更新曝光值', (tester) async {
      final container = makeContainer(templateId: 'soft_portrait');
      await host(tester, container);
      expand(container);
      await tester.pumpAndSettle();

      await tester.tap(find.text('曝光'));
      await tester.pumpAndSettle();

      final slider = find.byType(AdjustSlider);
      expect(slider, findsOneWidget);
      expect(find.text('EV'), findsOneWidget);

      final initialEv = container
          .read(CaptureState.editableTemplateProvider)!
          .camera
          .exposureCompensation;
      await tester.drag(slider, const Offset(200, 0));
      await tester.pumpAndSettle();
      final newEv = container
          .read(CaptureState.editableTemplateProvider)!
          .camera
          .exposureCompensation;
      expect(newEv, isNot(equals(initialEv)));
    });

    testWidgets('再点同一工具收起控件区', (tester) async {
      final container = makeContainer(templateId: 'soft_portrait');
      await host(tester, container);
      expand(container);
      await tester.pumpAndSettle();

      await tester.tap(find.text('曝光'));
      await tester.pumpAndSettle();
      expect(find.byType(AdjustSlider), findsOneWidget);

      await tester.tap(find.text('曝光'));
      await tester.pumpAndSettle();
      expect(find.byType(AdjustSlider), findsNothing);
    });

    testWidgets('自由模式 EV 拖动写入 freeModeCamera（防抖持久化推进）', (tester) async {
      final container = makeContainer();
      await host(tester, container);
      expand(container);
      await tester.pumpAndSettle();

      await tester.tap(find.text('曝光'));
      await tester.pumpAndSettle();

      final initialEv = container
          .read(CaptureState.freeModeCameraProvider)
          .exposureCompensation;
      await tester.drag(find.byType(AdjustSlider), const Offset(200, 0));
      await tester.pumpAndSettle();
      final newEv = container
          .read(CaptureState.freeModeCameraProvider)
          .exposureCompensation;
      expect(newEv, isNot(equals(initialEv)));

      // 推进 500ms 防抖持久化 Timer，避免测试结束时 Timer pending
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
    });

    testWidgets('点“色彩”展开 AdjustPanel 并可调亮度', (tester) async {
      final container = makeContainer(templateId: 'soft_portrait');
      await host(tester, container);
      expand(container);
      await tester.pumpAndSettle();

      await tester.tap(find.text('色彩'));
      await tester.pumpAndSettle();

      // AdjustPanel 默认选中第 0 项「亮度」
      expect(find.text('亮度'), findsOneWidget);

      final initial = container
          .read(CaptureState.editableTemplateProvider)!
          .postProcess
          .color
          .brightness;
      await tester.drag(find.byType(AdjustSlider), const Offset(200, 0));
      await tester.pumpAndSettle();
      final updated = container
          .read(CaptureState.editableTemplateProvider)!
          .postProcess
          .color
          .brightness;
      expect(updated, isNot(equals(initial)));
    });

    testWidgets('点“闪光”展开选项 pill 并切换闪光模式', (tester) async {
      final container = makeContainer(templateId: 'soft_portrait');
      await host(tester, container);
      expand(container);
      await tester.pumpAndSettle();

      await tester.tap(find.text('闪光'));
      await tester.pumpAndSettle();

      expect(find.text('常亮'), findsOneWidget);
      await tester.tap(find.text('常亮'));
      await tester.pumpAndSettle();

      expect(
        container.read(CaptureState.effectiveCameraProvider).flashMode,
        'on',
      );
    });

    testWidgets('点“构图”展开辅助线类型 pill 与透明度滑块', (tester) async {
      final container = makeContainer(templateId: 'soft_portrait');
      await host(tester, container);
      expand(container);
      await tester.pumpAndSettle();

      await tester.tap(find.text('构图'));
      await tester.pumpAndSettle();

      expect(find.text('三分法'), findsOneWidget);
      expect(find.text('透明度'), findsOneWidget);
    });

    testWidgets('点“场景”展开场景指南（模板模式）', (tester) async {
      final container = makeContainer(templateId: 'soft_portrait');
      await host(tester, container);
      expand(container);
      await tester.pumpAndSettle();

      await tester.tap(find.text('场景'));
      await tester.pumpAndSettle();

      expect(find.text('光线方向'), findsOneWidget);
    });

    testWidgets('自由模式场景空态文案', (tester) async {
      final container = makeContainer();
      await host(tester, container);
      expand(container);
      await tester.pumpAndSettle();

      await tester.tap(find.text('场景'));
      await tester.pumpAndSettle();

      expect(find.text('当前为自由模式，无场景指南'), findsOneWidget);
    });
  });

  group('ParamPanel 面板级交互', () {
    testWidgets('重置按钮恢复模板原始值', (tester) async {
      final container = makeContainer(templateId: 'soft_portrait');
      await host(tester, container);
      expand(container);
      await tester.pumpAndSettle();

      // 修改 EV 使 editable 偏离 original
      await tester.tap(find.text('曝光'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(AdjustSlider), const Offset(200, 0));
      await tester.pumpAndSettle();
      expect(container.read(CaptureState.appliedProvider), false);

      await tester.tap(find.text('重置'));
      await tester.pumpAndSettle();
      expect(container.read(CaptureState.appliedProvider), true);
    });

    testWidgets('把手行收起图标关闭面板', (tester) async {
      final container = makeContainer(templateId: 'soft_portrait');
      await host(tester, container);
      expand(container);
      await tester.pumpAndSettle();
      expect(container.read(CaptureState.panelExpandedProvider), true);

      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();
      expect(container.read(CaptureState.panelExpandedProvider), false);
    });

    testWidgets('点面板外区域（取景器）关闭整栏', (tester) async {
      final container = makeContainer(templateId: 'soft_portrait');
      await host(tester, container);
      expand(container);
      await tester.pumpAndSettle();

      // 面板贴底；点击屏幕上半部（面板外）
      await tester.tapAt(const Offset(400, 100));
      await tester.pumpAndSettle();
      expect(container.read(CaptureState.panelExpandedProvider), false);
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```powershell
flutter test test/features/capture/widgets/param_panel_test.dart
```

预期：FAIL（新断言找不到 `曝光` 等工具条标签）

- [ ] **Step 3: 重写 ParamPanel**

用以下内容**整体替换** `lumira_app_flutter/lib/features/capture/widgets/param_panel.dart`：

```dart
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/lumira/_internal/lumira_theme_resolver.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../data/capture_state.dart';
import '../services/camera_service_provider.dart';
import '../services/white_balance.dart';
import 'post_process_adjust_panel.dart';

/// 参数面板工具条条目
enum _ParamTool { ev, wb, flash, color, detail, composition, scene }

/// 拍摄页底部参数面板：图标工具条 + 点选滑出控件区（总高 ≤220）。
///
/// 交互与预览页编辑工具条 / iPhone 原生相机一致：
/// - 点工具图标 → 控件区滑出该组控件；再点同图标 → 收起控件区
/// - 点把手行关闭图标 / 面板外取景器区域 → 关闭整栏（panelExpandedProvider）
///
/// 视觉：容器与强调色全部从当前 UI 风格 + 主题 tokens 派生；叠在取景器
/// 动态画面上，新拟态走「半透明暗底 + 细边」取向（无阴影无模糊铁律，
/// 色值由 [LumiraThemeResolver.darkNeuPalette] 从主题 canvas lerp 派生），
/// 暗色语境文字用白色系（与 ParamPillBar 拍摄页先例一致）。
///
/// 白平衡应用逻辑（预设→色温联动、OHOS 隐藏色温滑块、iOS 残差拉取）
/// 与旧版一致，仅迁移位置。
class ParamPanel extends ConsumerStatefulWidget {
  const ParamPanel({super.key});

  @override
  ConsumerState<ParamPanel> createState() => _ParamPanelState();
}

class _ParamPanelState extends ConsumerState<ParamPanel> {
  /// 控件区固定高度：pill 行 + 滑块 / AdjustPanel 均按此设计
  static const _controlH = 132.0;

  _ParamTool? _activeTool;

  void _close() {
    ref.read(CaptureState.panelExpandedProvider.notifier).state = false;
  }

  void _toggleTool(_ParamTool tool) {
    setState(() => _activeTool = _activeTool == tool ? null : tool);
    HapticFeedback.lightImpact();
  }

  void _reset() {
    final editable = ref.read(CaptureState.editableTemplateProvider);
    final original = ref.read(CaptureState.originalTemplateProvider);
    if (editable != null && original != null) {
      // 模板模式：重置为模板原始值
      ref.read(CaptureState.editableTemplateProvider.notifier).state =
          original.copyWith();
    } else {
      // 自由模式：重置为默认值并持久化
      CaptureState.resetFreeModeParams(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expanded = ref.watch(CaptureState.panelExpandedProvider);
    final theme = ref.watch(appThemeProvider);
    final tokens = theme.tokens;
    final style = theme.style;
    final accent = tokens.brand;
    final hasTemplate =
        ref.watch(CaptureState.editableTemplateProvider) != null;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Stack(
      children: [
        // 点击面板外取景器区域关闭整栏（面板本体在其上层，不受影响）
        if (expanded)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _close,
              child: const SizedBox.expand(),
            ),
          ),
        // 面板本体：底部贴边 + AnimatedSlide 进出（高度由内容自然撑开，
        // 控件区用 AnimatedSize 滑出，避免固定高容器在动画期溢出）
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            offset: expanded ? Offset.zero : const Offset(0, 1.2),
            child: _panelShell(
              style: style,
              tokens: tokens,
              bottomInset: bottomInset,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HandleRow(
                    hasTemplate: hasTemplate,
                    accent: accent,
                    onReset: _reset,
                    onClose: _close,
                  ),
                  _ToolbarRow(
                    activeTool: _activeTool,
                    accent: accent,
                    onToolTap: _toggleTool,
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: _activeTool == null
                        ? const SizedBox.shrink()
                        : SizedBox(
                            height: _controlH,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: KeyedSubtree(
                                key: ValueKey(_activeTool),
                                child: _buildControl(accent),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── 面板外壳：按当前 UI 风格派生暗色语境视觉 ──

  Widget _panelShell({
    required UIStyle style,
    required ThemeTokens tokens,
    required double bottomInset,
    required Widget child,
  }) {
    const radius = BorderRadius.vertical(top: Radius.circular(24));
    final palette = LumiraThemeResolver.darkNeuPalette(tokens);
    Widget body;
    switch (style) {
      case UIStyle.glass:
        // 暗玻璃：毛玻璃 + 近黑半透明底（ParamPillBar 玻璃胶囊同取向）
        body = ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: EdgeInsets.only(bottom: bottomInset),
              decoration: BoxDecoration(
                color: palette.surface.withOpacity(0.80),
                borderRadius: radius,
                border: Border.all(
                    color: Colors.white.withOpacity(0.10), width: 0.5),
              ),
              child: child,
            ),
          ),
        );
        break;
      case UIStyle.female:
        // 暗渐变：黑 → 品牌微染，柔和细边
        body = Container(
          padding: EdgeInsets.only(bottom: bottomInset),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.82),
                Color.lerp(Colors.black, tokens.brand, 0.16)!
                    .withOpacity(0.84),
              ],
            ),
            borderRadius: radius,
            border: Border.all(
                color: Colors.white.withOpacity(0.08), width: 0.6),
          ),
          child: child,
        );
        break;
      case UIStyle.neumorphic:
        // 新拟态叠动态画面：半透明暗底 + 细边（无阴影无模糊铁律）
        body = Container(
          padding: EdgeInsets.only(bottom: bottomInset),
          decoration: BoxDecoration(
            color: palette.surface.withOpacity(0.94),
            borderRadius: radius,
            border: Border.all(
                color: Colors.white.withOpacity(0.14), width: 0.6),
          ),
          child: child,
        );
        break;
      case UIStyle.flat:
        // 扁平：半透明暗底 + 细边
        body = Container(
          padding: EdgeInsets.only(bottom: bottomInset),
          decoration: BoxDecoration(
            color: palette.surface.withOpacity(0.92),
            borderRadius: radius,
            border: Border.all(
                color: Colors.white.withOpacity(0.08), width: 0.5),
          ),
          child: child,
        );
        break;
    }
    return body;
  }

  // ── 控件区内容分发 ──

  Widget _buildControl(Color accent) {
    switch (_activeTool!) {
      case _ParamTool.ev:
        return _EvControl(accent: accent);
      case _ParamTool.wb:
        return _WbControl(accent: accent);
      case _ParamTool.flash:
        return _FlashControl(accent: accent);
      case _ParamTool.color:
        return AdjustPanel(
          defs: colorAdjustDefs(),
          full: ref.watch(CaptureState.effectivePostProcessProvider),
          onChanged: (p) => CaptureState.updatePostProcess(ref, (_) => p),
          accentColor: accent,
        );
      case _ParamTool.detail:
        return AdjustPanel(
          defs: detailAdjustDefs(),
          full: ref.watch(CaptureState.effectivePostProcessProvider),
          onChanged: (p) => CaptureState.updatePostProcess(ref, (_) => p),
          accentColor: accent,
        );
      case _ParamTool.composition:
        return const _CompositionControl();
      case _ParamTool.scene:
        return const _SceneControl();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// 把手行
// ─────────────────────────────────────────────────────────────────────

/// 把手行：拖动条 + 模板/自由徽标 + 重置 pill + 关闭图标
class _HandleRow extends StatelessWidget {
  const _HandleRow({
    required this.hasTemplate,
    required this.accent,
    required this.onReset,
    required this.onClose,
  });

  final bool hasTemplate;
  final Color accent;
  final VoidCallback onReset;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 6),
      child: Row(
        children: [
          // 拖动条（装饰）
          Container(
            width: 24,
            height: 3,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: hasTemplate
                  ? accent.withOpacity(0.15)
                  : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              hasTemplate ? '模板' : '自由',
              style: TextStyle(
                color: hasTemplate ? accent : Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onReset,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, size: 12, color: Colors.white70),
                  SizedBox(width: 4),
                  Text('重置',
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          LumiraIconButton(
            icon: Icons.close,
            onPressed: onClose,
            color: Colors.white70,
            size: 16,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 图标工具条
// ─────────────────────────────────────────────────────────────────────

/// 图标工具条：7 项单行（曝光/白平衡/闪光/色彩/细节/构图/场景）
class _ToolbarRow extends StatelessWidget {
  const _ToolbarRow({
    required this.activeTool,
    required this.accent,
    required this.onToolTap,
  });

  final _ParamTool? activeTool;
  final Color accent;
  final ValueChanged<_ParamTool> onToolTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToolItem(
            icon: Icons.exposure,
            label: '曝光',
            selected: activeTool == _ParamTool.ev,
            accent: accent,
            onTap: () => onToolTap(_ParamTool.ev),
          ),
          _ToolItem(
            icon: Icons.wb_sunny_outlined,
            label: '白平衡',
            selected: activeTool == _ParamTool.wb,
            accent: accent,
            onTap: () => onToolTap(_ParamTool.wb),
          ),
          _ToolItem(
            icon: Icons.flash_on_outlined,
            label: '闪光',
            selected: activeTool == _ParamTool.flash,
            accent: accent,
            onTap: () => onToolTap(_ParamTool.flash),
          ),
          _ToolItem(
            icon: Icons.tune,
            label: '色彩',
            selected: activeTool == _ParamTool.color,
            accent: accent,
            onTap: () => onToolTap(_ParamTool.color),
          ),
          _ToolItem(
            icon: Icons.auto_fix_high_outlined,
            label: '细节',
            selected: activeTool == _ParamTool.detail,
            accent: accent,
            onTap: () => onToolTap(_ParamTool.detail),
          ),
          _ToolItem(
            icon: Icons.grid_4x4_outlined,
            label: '构图',
            selected: activeTool == _ParamTool.composition,
            accent: accent,
            onTap: () => onToolTap(_ParamTool.composition),
          ),
          _ToolItem(
            icon: Icons.tips_and_updates_outlined,
            label: '场景',
            selected: activeTool == _ParamTool.scene,
            accent: accent,
            onTap: () => onToolTap(_ParamTool.scene),
          ),
        ],
      ),
    );
  }
}

/// 单个工具项：图标 + 文字，选中态 accent 高亮 + 胶囊底
class _ToolItem extends StatelessWidget {
  const _ToolItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? accent : Colors.white70;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? accent.withOpacity(0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(1000),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 控件区：曝光 / 白平衡 / 闪光 / 构图 / 场景
// ─────────────────────────────────────────────────────────────────────

/// 曝光 EV 单滑块
class _EvControl extends ConsumerWidget {
  const _EvControl({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cam = ref.watch(CaptureState.effectiveCameraProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: AdjustSlider(
        label: 'EV',
        value: cam.exposureCompensation,
        min: -3,
        max: 3,
        accentColor: accent,
        format: (v) =>
            v >= 0 ? '+${v.toStringAsFixed(1)}' : v.toStringAsFixed(1),
        onChanged: (v) => CaptureState.updateCamera(
            ref, (c) => c.copyWith(exposureCompensation: v)),
      ),
    );
  }
}

/// 白平衡：预设 pill + 色温滑块（自旧 _CameraTab 原样迁移）
class _WbControl extends ConsumerWidget {
  const _WbControl({required this.accent});

  final Color accent;

  /// 白平衡预设 pill（mode → 显示名）。
  static const _wbPresets = <WhiteBalanceMode, String>{
    WhiteBalanceMode.auto: '自动',
    WhiteBalanceMode.daylight: '日光',
    WhiteBalanceMode.cloudy: '阴天',
    WhiteBalanceMode.fluorescent: '荧光',
    WhiteBalanceMode.incandescent: '白炽',
  };

  /// 预设 → 色温(K)。与 iOS 原生映射保持一致，用于 iOS/Android 预设点击
  /// 时把滑块联动到对应档位（两者底层同为锁定色温）。OHOS 不使用。
  static const _wbPresetK = <WhiteBalanceMode, int>{
    WhiteBalanceMode.daylight: 5500,
    WhiteBalanceMode.cloudy: 6500,
    WhiteBalanceMode.fluorescent: 4200,
    WhiteBalanceMode.incandescent: 3000,
  };

  /// 应用白平衡设置：写入会话 provider + 实时下发取景器。
  /// 仅实时会话调节，**不写入 CameraParams**。
  /// 随后拉取 iOS 硬件「残差」（软封顶削减比），供软件矩阵补足
  ///（极值色温下取景器局部冷/暖色丢失的修复，见 white_balance.dart）。
  void _apply(WidgetRef ref, WhiteBalanceSettings s) {
    ref.read(whiteBalanceSessionProvider.notifier).state = s;
    ref.read(cameraServiceProvider).setWhiteBalance(s);
    refreshWbResidual(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wb = ref.watch(whiteBalanceSessionProvider);
    // OHOS 连续色温（setWhiteBalance/getWhiteBalanceRange）真机不可用，
    // 传感器级手动值无法落地，仅保留预设 pill，隐藏色温滑块。
    final showWbSlider = Platform.isAndroid || Platform.isIOS;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      children: [
        _WbPresetRow(
          presets: _wbPresets,
          selected: wb.mode,
          accent: accent,
          onSelected: (mode) {
            if (mode == WhiteBalanceMode.auto) {
              // 切回 Auto：temperatureK 置 null，插件端 auto 复位
              _apply(ref, const WhiteBalanceSettings());
            } else {
              // 非 Auto 预设。iOS/Android：预设与色温滑块底层同为“锁定色温”，
              // 预设点击时把 temperatureK 联动到对应档位，使滑块跟随；
              // OHOS：预设走原生 mode 分支，temperatureK 保持 null。
              _apply(
                ref,
                showWbSlider
                    ? WhiteBalanceSettings(
                        mode: mode, temperatureK: _wbPresetK[mode])
                    : WhiteBalanceSettings(mode: mode),
              );
            }
          },
        ),
        if (showWbSlider && !wb.isAuto)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: AdjustSlider(
              label: '色温',
              value: (wb.temperatureK ?? 5500).toDouble(),
              min: 3000,
              max: 8000,
              accentColor: accent,
              format: (v) => '${(v / 100).round() * 100} K',
              onChanged: (v) => _apply(
                ref,
                WhiteBalanceSettings(
                  mode: wb.mode,
                  temperatureK: (v / 100).round() * 100,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 闪光：4 选项 pill 单选
class _FlashControl extends ConsumerWidget {
  const _FlashControl({required this.accent});

  final Color accent;

  static const _flashChoices = [
    _ChoiceItem('off', '关闭'),
    _ChoiceItem('on', '常亮'),
    _ChoiceItem('auto', '自动'),
    _ChoiceItem('torch', '手电筒'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cam = ref.watch(CaptureState.effectiveCameraProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: _ChoicePillRow(
        items: _flashChoices,
        selected: cam.flashMode,
        accent: accent,
        onSelected: (v) =>
            CaptureState.updateCamera(ref, (c) => c.copyWith(flashMode: v)),
      ),
    );
  }
}

/// 构图：辅助线类型 pill + 透明度滑块
class _CompositionControl extends ConsumerWidget {
  const _CompositionControl();

  static const _overlayTypes = [
    _ChoiceItem('rule_of_thirds', '三分法'),
    _ChoiceItem('golden_ratio', '黄金比例'),
    _ChoiceItem('center', '居中'),
    _ChoiceItem('diagonal', '对角线'),
    _ChoiceItem('symmetry', '对称'),
    _ChoiceItem('none', '无'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comp = ref.watch(CaptureState.effectiveCompositionProvider);
    final accent = ref.watch(appThemeProvider).tokens.brand;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      children: [
        _ChoicePillRow(
          items: _overlayTypes,
          selected: comp.overlayType,
          accent: accent,
          onSelected: (v) => CaptureState.updateComposition(
              ref, (c) => c.copyWith(overlayType: v)),
        ),
        const SizedBox(height: 8),
        AdjustSlider(
          label: '透明度',
          value: comp.opacity,
          min: 0,
          max: 1,
          accentColor: accent,
          format: (v) => '${(v * 100).round()}%',
          onChanged: (v) => CaptureState.updateComposition(
              ref, (c) => c.copyWith(opacity: v)),
        ),
      ],
    );
  }
}

/// 场景指南：紧凑 label:value 只读列表（自旧 _SceneTab 迁移）
class _SceneControl extends ConsumerWidget {
  const _SceneControl();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = ref.watch(CaptureState.effectiveSceneGuideProvider);

    final rows = <MapEntry<String, String>>[
      MapEntry('光线方向', sg.lightDirection),
      MapEntry('拍摄距离', sg.shootingDistance),
      MapEntry('背景建议', sg.background),
      MapEntry('最佳时段', sg.bestTime),
      if (sg.bestTimeFrom != null && sg.bestTimeTo != null)
        MapEntry('时段范围', '${sg.bestTimeFrom} - ${sg.bestTimeTo}'),
      if (sg.presetId != null) MapEntry('场景预设', sg.presetId!),
      if (sg.props.isNotEmpty) MapEntry('推荐道具', sg.props.join('、')),
      if (sg.tips.isNotEmpty) MapEntry('拍摄贴士', sg.tips.join('\n• ')),
    ];

    if (rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('当前为自由模式，无场景指南',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
            SizedBox(height: 4),
            Text('选择场景预设或套用模板后可查看',
                style: TextStyle(color: Colors.white24, fontSize: 10)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 64,
                  child: Text(row.key,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 10)),
                ),
                Expanded(
                  child: Text(
                    row.value.isEmpty ? '—' : row.value,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 通用 pill 组件
// ─────────────────────────────────────────────────────────────────────

/// 选项键值对（泛型 pill 行的条目）
class _ChoiceItem {
  final String value;
  final String label;
  const _ChoiceItem(this.value, this.label);
}

/// 通用选项 pill 行（暗色语境）：胶囊单选，选中态 accent
class _ChoicePillRow extends StatelessWidget {
  const _ChoicePillRow({
    required this.items,
    required this.selected,
    required this.accent,
    required this.onSelected,
  });

  final List<_ChoiceItem> items;
  final String selected;
  final Color accent;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          GestureDetector(
            onTap: () => onSelected(item.value),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: item.value == selected
                    ? accent.withOpacity(0.18)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: item.value == selected
                      ? accent.withOpacity(0.6)
                      : Colors.white.withOpacity(0.08),
                  width: item.value == selected ? 1 : 0.5,
                ),
              ),
              child: Text(
                item.label,
                style: TextStyle(
                  color: item.value == selected ? accent : Colors.white70,
                  fontSize: 12,
                  fontWeight: item.value == selected
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 白平衡预设 pill 行 — 胶囊式单选（自旧版迁移，强调色主题化）
class _WbPresetRow extends StatelessWidget {
  const _WbPresetRow({
    required this.presets,
    required this.selected,
    required this.accent,
    required this.onSelected,
  });

  final Map<WhiteBalanceMode, String> presets;
  final WhiteBalanceMode selected;
  final Color accent;
  final ValueChanged<WhiteBalanceMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: presets.entries.map((e) {
        final active = e.key == selected;
        return GestureDetector(
          onTap: () => onSelected(e.key),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: active
                  ? accent.withOpacity(0.18)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: active
                    ? accent.withOpacity(0.6)
                    : Colors.white.withOpacity(0.08),
                width: active ? 1 : 0.5,
              ),
            ),
            child: Text(
              e.value,
              style: TextStyle(
                color: active ? accent : Colors.white70,
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
```

实现注意：
- 图标 `Icons.grid_4x4_outlined` / `Icons.tips_and_updates_outlined` 若 analyze 报未定义（Flutter 3.7 图标集差异），分别降级为 `Icons.grid_on` / `Icons.lightbulb_outline`
- `_panelShell` 的 switch 每个分支都赋值 `body` 并 `break`，四个枚举值全覆盖 → 无 "missing return" 
- `dart:ui` 的 `ImageFilter` 仅 glass 分支使用，import 置顶

- [ ] **Step 4: 运行 param_panel 测试确认通过**

```powershell
flutter test test/features/capture/widgets/param_panel_test.dart
```

预期：PASS（13 个用例全绿）

- [ ] **Step 5: 更新 capture_preview_template_page_test 的 5 Tab 用例**

`lumira_app_flutter/test/features/capture/capture_preview_template_page_test.dart` 约 264-284 行，把旧用例：

```dart
    testWidgets('tapping 参数 tool opens ParamPanel with 5 tabs', (tester) async {
      ...
      // ParamPanel Tab 栏展开：相机 / 色彩 / 细节 / 构图 / 场景
      //（"场景" 也出现在底部工具栏按钮，故限定在 ParamPanel 内查找）
      final inPanel = (String t) =>
          find.descendant(of: find.byType(ParamPanel), matching: find.text(t));
      expect(inPanel('相机'), findsOneWidget);
      expect(inPanel('色彩'), findsOneWidget);
      expect(inPanel('构图'), findsOneWidget);
      expect(inPanel('场景'), findsOneWidget);
    });
```

替换为（结构对齐新工具条）：

```dart
    testWidgets('tapping 参数 tool opens ParamPanel toolbar', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(
        themeKey: ThemeKey.warmWhite,
        uiStyle: UIStyle.neumorphic,
        initialLocation: tplQuery,
      ));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('参数'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // ParamPanel 工具条展开：曝光/白平衡/闪光/色彩/细节/构图/场景
      //（"场景" 也出现在底部工具栏按钮，故限定在 ParamPanel 内查找）
      final inPanel = (String t) =>
          find.descendant(of: find.byType(ParamPanel), matching: find.text(t));
      expect(inPanel('曝光'), findsOneWidget);
      expect(inPanel('色彩'), findsOneWidget);
      expect(inPanel('构图'), findsOneWidget);
      expect(inPanel('场景'), findsOneWidget);
    });
```

（该文件约 392 行处 `expect(find.byType(ParamPanel), findsOneWidget, ...)` 仅存在性断言，无需改动）

- [ ] **Step 6: 全量回归 + analyze**

```powershell
flutter test test/features/capture test/shared/widgets/common/lumira_surface_test.dart test/features/capture/widgets/adjust_slider_test.dart
flutter analyze
```

预期：全绿；analyze 无新增 issue。若有旧 ParamPanel 结构残留引用的测试失败（如 `find.text('相机')` / `'完成'`），按新工具条结构修正该断言（工具条 7 项 + 把手行 重置/关闭）

- [ ] **Step 7: 提交**

```powershell
git add lumira_app_flutter/lib/features/capture/widgets/param_panel.dart lumira_app_flutter/test/features/capture/widgets/param_panel_test.dart lumira_app_flutter/test/features/capture/capture_preview_template_page_test.dart
git commit -m "feat(capture): 参数面板重构为图标工具条+点选滑出（主题化暗色语境）"
```

---

## 验收清单（对照 spec）

- [ ] 新拟态 + 黑底：预览页编辑 dock 呈现真浮雕（高光 0.22 > 卡面 0.10 > 暗影 0.03 梯度），flat/glass/female 不变
- [ ] ParamPanel：520 抽屉 + 5 文字 Tab → 工具条 + 滑出控件区，收起 ≈96dp、展开 ≤220
- [ ] 7 工具一步直达（EV/白平衡/闪光/色彩/细节/构图/场景），色彩/细节与预览页同款 AdjustPanel
- [ ] 强调色全部 `tokens.brand`（旧 `0xFFC9A96E` 硬编码清零），容器按 4 风格派生
- [ ] 白平衡/参数写入行为与旧版一致（含 OHOS 隐藏色温滑块、iOS 残差拉取）
- [ ] 重置逻辑保持（模板=原始值 / 自由=默认值持久化）；「完成」按钮移除
- [ ] `flutter analyze` 无新增 issue；capture 测试目录全绿
