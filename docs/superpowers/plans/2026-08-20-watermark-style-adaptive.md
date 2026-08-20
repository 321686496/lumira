# 水印编辑页 & 管理页 风格自适应 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复水印编辑页的丑陋样式与黑边，让编辑页外壳/底部面板/所有小按钮/输入控件、以及管理页布局切换分段控件完全跟随项目 4 套 UI 风格 × 8+1 主题色自适应（该圆角圆角、该阴影阴影）。

**Architecture:** 以「浅色主题外壳 + 深色沉浸预览」为总体取向。外壳组件全部改走「当前 UI 风格自身视觉语言」，通过一个私有 `_chipDeco(tokens, style, …)` 装饰解析辅助 + 复用 `LumiraSlider / LumiraTextField / LumiraSwitch / NeuCard / LumiraNav / BreathingTap` 来消除死板的 `surfaceAlt + 直边框` 平板样式；预览区背景由死黑改为「主题深色」（`canvasDeep` 亮度校验 + 深色常量兜底）。管理页仅轻量修复 `_LayoutSegments` 使其风格自适应。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6，flutter_riverpod。注意不支持 `dart:ui` records / `Color.withValues` / `ScaleStartDetails.scale` 等新 API。

## Global Constraints

- **风格不混用**：所有新样式只使用"当前风格自己的元素"。以 `ref.watch(uiStyleProvider)` 得到 `UIStyle` 后 `switch` 分支；严禁玻璃借到新拟态、浮雕借到扁平、vector 渐变借到非 female。
- **不硬编码主题色**：除「深色沉浸底常量 `Color(0xFF1B1A18)`」（叠照片深底，合法例外）外，所有颜色/阴影/圆角来自 `appTheme.tokens` / `appTheme.cardRadius`。
- **保留测试 key**：`wm-tab-element / wm-tab-style / wm-tab-border / wm-panel-collapse / wm-panel-expand / wm-preview-area / watermark-layout-toggle` 必须保持存在，否则既有测试失败。
- **不回归手势/渲染**：预览区点选/拖拽/缩放、`_buildFrameOverlay`、`_buildElementOverlay` 逻辑不变，只改壳。
- Flutter 侧改动不需提交 git；仅后端/后台改动需 commit + push 双端（本计划不涉及后端/后台）。

---

### Task 1: 编辑器外壳骨架（消除黑边 + 深色沉浸预览底）

**Files:**
- Modify: `d:\app\projects\photo_post\lumira_app_flutter\lib\features\watermark\pages\watermark_editor_page.dart`（`build`、`_buildPreviewArea`、`import` 顶部）
- Test: `d:\app\projects\photo_post\lumira_app_flutter\test\features\watermark\watermark_editor_page_test.dart`（既有，保持绿）

**Interfaces:**
- 新增私有方法：`Color _previewBg(ThemeTokens tokens)` → 返回深色沉浸底（`canvasDeep` 或常量兜底）。
- 新增私有常量：`static const Color _immersiveDeep = Color(0xFF1B1A18);`

- [ ] **Step 1: 修改 import（扩展 lumira barrel 导出）**

把第 15-17 行的 `show LumiraToast, showLumiraSaveModeSheet` 扩展为包含后续任务需要的组件：

```dart
import '../../../shared/widgets/lumira/lumira.dart'
    show
        LumiraToast,
        LumiraSlider,
        LumiraSwitch,
        LumiraTextField,
        showLumiraSaveModeSheet;
```

- [ ] **Step 2: 新增深色沉浸底常量与解析方法**

在 `static const double _collapsedHeight = 40.0;` 之后加常量：

```dart
static const String _sampleAsset = 'assets/images/watermark_sample.jpg';
static const double _collapsedHeight = 40.0;
// 叠照片深色沉浸底兜底常量（跨风格叠加视觉的合法例外，非主题色硬编码）。
static const Color _immersiveDeep = Color(0xFF1B1A18);
```

在 `_cancel()` 之后新增方法：

```dart
/// 深色沉浸预览底：优先取 [ThemeTokens.canvasDeep]（ink 主题即 0xFF151310）；
/// 对暖/浅主题（canvasDeep 过浅）用 [_immersiveDeep] 兜底，保证任何主题下都有沉浸感。
Color _previewBg(ThemeTokens tokens) {
  final deep = tokens.canvasDeep;
  if (deep.computeLuminance() > 0.3) return _immersiveDeep;
  return deep;
}
```

- [ ] **Step 3: 修改 `build`（去掉死黑 Scaffold + SafeArea 外壳）**

把当前 `build` 改为：

```dart
@override
Widget build(BuildContext context) {
  final tokens = ref.watch(themeTokensProvider);
  final style = ref.watch(uiStyleProvider);

  return Scaffold(
    backgroundColor: tokens.canvas,
    body: Column(
      children: [
        _buildNav(tokens),
        Expanded(child: _buildPreviewArea(tokens, style)),
        _buildBottomPanel(tokens, style),
      ],
    ),
  );
}
```

要点：删除 `Colors.black` 与字符串包裹的 `SafeArea`；顶部安全区由 `LumiraNav` 内部处理；底部 Home indicator 安全区在 Task 2 移到 `_buildBottomPanel` 内部（`SafeArea(top: false)`）。`_buildNav` 去掉外层 `Container(color: tokens.canvas)` 包裹（改法见 Step 4）。

- [ ] **Step 4: 简化 `_buildNav`（移除冗余底色包裹）**

把当前：

```dart
            Container(color: tokens.canvas, child: _buildNav(tokens)),
```

改成（在 `Column` 中直接调用，无外层 Container）：

```dart
        _buildNav(tokens),
```

`_buildNav` 内部不变（已是 `LumiraNav` 自适应），但需要把 `_buildNav` 上面第 398 行的调用一并同步（见 Step 3 已经重写 build）。确认 `_buildNav` 方法体本身无需改动。

- [ ] **Step 5: 修改 `_buildPreviewArea` 背景为深色沉浸底**

把 `_buildPreviewArea` 中的 `color: Colors.black` 改为 `color: _previewBg(tokens)`：

```dart
Widget _buildPreviewArea(ThemeTokens tokens, UIStyle style) {
  final aspect = (_sourceAspect != null && _sourceAspect! > 0)
      ? _sourceAspect!
      : 1.0;
  return Container(
    key: const ValueKey('wm-preview-area'),
    color: _previewBg(tokens),
    child: Center(
      child: AspectRatio(
        aspectRatio: aspect,
        child: ClipRect(
          child: LayoutBuilder(
            builder: (context, c) {
              final photoRect = Offset.zero & c.biggest;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  if (_photoBytes != null && _photoBytes!.isNotEmpty)
                    Image.memory(
                      _photoBytes!,
                      fit: BoxFit.fill,
                      gaplessPlayback: true,
                    ),
                  if (_template.frame.type == WatermarkFrameType.polaroid)
                    _buildFrameOverlay(photoRect, _template.frame),
                  ..._template.elements
                      .map((e) => _buildElementOverlay(e, photoRect)),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
```

（`style` 形参保留，后续任务可能使用；若未用到可将实参名留 `style`，或暂时忽略 lint——见 Step 7。）

- [ ] **Step 6: 运行既有测试确认不回归**

在 `lumira_app_flutter/` 目录运行：

```bash
flutter test test/features/watermark/watermark_editor_page_test.dart
```

**Expected:** `All tests passed!`（或至少此文件全绿）。若 `_buildPreviewArea` 的 `style` 形参未用导致 lint info，先忽略。

- [ ] **Step 7: Commit**

```bash
git add lumira_app_flutter/lib/features/watermark/pages/watermark_editor_page.dart
git commit -m "feat(watermark): 编辑器外壳去死黑改用主题底色与深色沉浸预览底"
```

---

### Task 2: 底部面板 + 全部小控件风格自适应

**Files:**
- Modify: `d:\app\projects\photo_post\lumira_app_flutter\lib\features\watermark\pages\watermark_editor_page.dart`（`_buildBottomPanel / _buildTabButton / _miniButton / _elementChip / _spaceOption / _frameOption / _toggleChip / _alignChip / _sliderRow / _toggleRow / 样式 Tab 文本输入 / 颜色选点`，及新增 `_chipDeco / _panelDecoration / _scaleFor` 辅助）
- Test: `d:\app\projects\photo_post\lumira_app_flutter\test\features\watermark\watermark_editor_page_test.dart`（既有，保持绿）
- Test: **新增** `d:\app\projects\photo_post\lumira_app_flutter\test\features\watermark\watermark_style_adaptive_test.dart`

**Interfaces:**
- 新增私有方法 `BoxDecoration _chipDeco(ThemeTokens tokens, UIStyle style, {required bool active, required double radius, bool danger = false, bool raised = false})` —— 全页面小按钮/芯片/选项的统一背景解析。
- 新增私有方法 `BoxDecoration _panelDecoration(ThemeTokens tokens, UIStyle style)` —— 底部面板表面。
- 新增私有方法 `double _scaleFor(UIStyle style)` → female 0.96 / 其余 0.98（给 `BreathingTap.pressedScale`）。

- [ ] **Step 1: 写失败测试（风格自适应不抛异常 + key 存在）**

创建 `test/features/watermark/watermark_style_adaptive_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/watermark/pages/watermark_editor_page.dart';

const _presetMinimal = 'preset_minimal_date';

void main() {
  Future<void> pumpFor(
    WidgetTester tester,
    UIStyle uiStyle,
  ) async {
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
          uiStyleProvider.overrideWith((ref) => uiStyle),
        ],
        child: const MaterialApp(
          home: WatermarkEditorPage(templateId: _presetMinimal),
        ),
      ),
    );
    await tester.pump();
    if (uiStyle == UIStyle.female) {
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
  }

  for (final style in UIStyle.values) {
    testWidgets('编辑页在 ${style.name} 风格下渲染不抛异常且关键 key 存在',
        (tester) async {
      await pumpFor(tester, style);

      // 不抛异常 = 通过（pump 过程中异常会使测试 fail）
      expect(find.byKey(const ValueKey('wm-preview-area')), findsOneWidget);
      expect(find.byKey(const ValueKey('wm-tab-element')), findsOneWidget);
      expect(find.byKey(const ValueKey('wm-tab-style')), findsOneWidget);
      expect(find.byKey(const ValueKey('wm-tab-border')), findsOneWidget);
    });

    testWidgets('编辑页 ${style.name} 下可切到样式 Tab 并渲染滑块文本输入',
        (tester) async {
      await pumpFor(tester, style);
      await tester.tap(find.byKey(const ValueKey('wm-tab-style')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // 样式 Tab 选中一个元素后应出现字号/透明度标签（Text 来自 _sliderRow）
      expect(find.text('字号'), findsWidgets);
      expect(find.text('透明度'), findsWidgets);
    });
  }
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
flutter test test/features/watermark/watermark_style_adaptive_test.dart
```

**Expected:** 在（可能）部分风格下失败——`wm-tab-*` key 仍在，但这不是核心失败点；核心诉求是让本文件**至少在实现后全绿**。若当前 key 存在导致 `findsOneWidget` 通过、仅逻辑未变，可先跳过，以实现后为准。

- [ ] **Step 3: 新增 3 个辅助方法（`_scaleFor / _chipDeco / _panelDecoration`）**

在 `_cancel()` 与 `_previewBg` 之间（或文件底部私有区）插入：

```dart
/// 按压缩放系数：女性美学 0.96，其余 0.98。
double _scaleFor(UIStyle style) => style == UIStyle.female ? 0.96 : 0.98;

/// 全页面小按钮/芯片/选项的统一风格自适应背景解析。
/// [active] 选中态；[raised] 指示"常驻凸起钮"（新拟态下即使未选中也带轻微浮雕）；
/// [danger] 让激活边框/底对应 danger 语义。
BoxDecoration _chipDeco(ThemeTokens tokens, UIStyle style,
    {required bool active,
    required double radius,
    bool danger = false,
    bool raised = false}) {
  final Color activeBg = danger ? tokens.dangerSubtle : tokens.brandSubtle;
  final Color accent = danger ? tokens.danger : tokens.brand;
  final BorderRadius r = BorderRadius.circular(radius);
  switch (style) {
    case UIStyle.neumorphic:
      return BoxDecoration(
        color: active ? activeBg : (raised ? tokens.surface : tokens.surfaceAlt),
        borderRadius: r,
        boxShadow: (raised || active) ? tokens.shadowConvexSubtle : const [],
      );
    case UIStyle.flat:
      return BoxDecoration(
        color: active ? activeBg : (raised ? tokens.surface : tokens.surfaceAlt),
        borderRadius: r,
        border: Border.all(
          color: active ? accent : tokens.divider,
          width: 1,
        ),
      );
    case UIStyle.glass:
      return BoxDecoration(
        color: active
            ? Colors.white.withOpacity(0.4)
            : Colors.white.withOpacity(raised ? 0.2 : 0.0),
        borderRadius: r,
        border: Border.all(
          color: active
              ? Colors.white.withOpacity(0.6)
              : Colors.white.withOpacity(raised ? 0.3 : 0.0),
          width: 1,
        ),
      );
    case UIStyle.female:
      if (active) {
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              activeBg.withOpacity(0.8),
              tokens.surface.withOpacity(0.55),
            ],
          ),
          borderRadius: r,
          border: Border.all(
            color: accent.withOpacity(0.35),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: tokens.brand.withOpacity(0.18),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        );
      }
      return BoxDecoration(
        color: Colors.transparent,
        borderRadius: r,
        border: Border.all(
          color: raised
              ? tokens.brand.withOpacity(0.2)
              : tokens.brand.withOpacity(0.12),
          width: 0.8,
        ),
      );
  }
}

/// 底部操作栏面板表面（按 4 风格）。外壳在纯色画布上 → 新拟态可用实心凸起/细边；
/// 玻璃用本风格半透明白；女性用 brandSubtle→surface 渐变。
BoxDecoration _panelDecoration(ThemeTokens tokens, UIStyle style) {
  switch (style) {
    case UIStyle.neumorphic:
      return BoxDecoration(
        color: tokens.surface,
        border: Border(
          top: BorderSide(color: tokens.divider, width: 0.5),
        ),
      );
    case UIStyle.flat:
      return BoxDecoration(
        color: tokens.surface,
        border: Border(top: BorderSide(color: tokens.divider, width: 1)),
      );
    case UIStyle.glass:
      return BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.4), width: 1),
        ),
      );
    case UIStyle.female:
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tokens.brandSubtle, tokens.surface],
        ),
        border: Border(
          top: BorderSide(color: tokens.brand.withOpacity(0.25), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: tokens.brand.withOpacity(0.12),
            offset: const Offset(0, -2),
            blurRadius: 12,
          ),
        ],
      );
  }
}
```

- [ ] **Step 4: 改造 `_buildBottomPanel`（加 SafeArea + 风格面板表面）**

把当前 `_buildBottomPanel` 改为：

```dart
Widget _buildBottomPanel(ThemeTokens tokens, UIStyle style) {
  return SafeArea(
    top: false, // Home indicator 区域由面板 surface 承接，消除黑边
    child: Container(
      decoration: _panelDecoration(tokens, style),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: _expanded
            ? _buildExpandedPanel(tokens, style)
            : _buildCollapsedBar(tokens),
      ),
    ),
  );
}
```

同步把 `_buildExpandedPanel(ThemeTokens tokens)` 形参改为 `(ThemeTokens tokens, UIStyle style)`，并把其中调用 `_buildTabButton(...)` 的位置传入 `style`。`_buildExpandedPanel` 内部的 `Divider(height: 1, color: tokens.divider)` 保留（风格共用的弱分隔线）。

- [ ] **Step 5: 改造 `_buildTabButton`（风格自适应 + 呼吸按压）**

把当前 `_buildTabButton` 改为：

```dart
Widget _buildTabButton(_EditorTab tab, String label, String key,
    ThemeTokens tokens, UIStyle style) {
  final active = _tab == tab;
  final double radius = style == UIStyle.flat ? 8 : 12;
  return Expanded(
    child: BreathingTap(
      onTap: () => setState(() => _tab = tab),
      pressedScale: _scaleFor(style),
      child: Container(
        key: ValueKey(key),
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: _chipDeco(tokens, style,
            active: active, radius: radius, raised: true),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? tokens.brandText : tokens.textSecondary,
          ),
        ),
      ),
    ),
  );
}
```

并在文件顶部 import `breathing_tap`：`import '../../../shared/widgets/effects/breathing_tap.dart';`

- [ ] **Step 6: 改造 `_miniButton / _elementChip / _spaceOption / _frameOption / _toggleChip / _alignChip`**

把 `_miniButton` 改为（形参加 `UIStyle style`，调用处在 `_buildElementTab` 内部传入）：

```dart
Widget _miniButton(String label, VoidCallback onTap, ThemeTokens tokens,
    {bool danger = false, UIStyle style = UIStyle.neumorphic}) {
  return BreathingTap(
    onTap: onTap,
    pressedScale: _scaleFor(style),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: _chipDeco(tokens, style,
          active: false, radius: 10, danger: danger, raised: true),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: danger ? tokens.danger : tokens.brandText,
        ),
      ),
    ),
  );
}
```

在 `_buildElementTab(ThemeTokens tokens, UIStyle style)`（形参加 style）内，把 4 处 `_miniButton(...)` 调用补上 `style: style`。

把 `_elementChip(WatermarkElement e, ThemeTokens tokens, UIStyle style)` 的 `decoration` 改为：

```dart
        decoration: _chipDeco(tokens, style,
            active: selected, radius: 18, raised: true),
```

（删除原来的 `color/borderRadius/border` 三件套。）

在 `_buildElementTab` 内调用 `_elementChip(e, tokens, style)`。

把 `_spaceOption`、`_frameOption` 的 `decoration` 改为：

```dart
        decoration: _chipDeco(tokens, style,
            active: active, radius: 10, raised: true),
```

（两函数形参均加 `UIStyle style`，禁用态文字颜色仍用 `tokens.textTertiary` 表达。）

把 `_toggleChip` 的 `decoration` 改为：

```dart
        decoration: _chipDeco(tokens, style,
            active: active, radius: 8, raised: true),
```

把 `_alignChip` 的 `decoration` 改为：

```dart
        decoration: _chipDeco(tokens, style,
            active: active, radius: 6, raised: true),
```

调用链：`_buildStyleTab` / `_buildBorderTab` 均需把 `style` 从 `_buildTabContent` 一路透传。为此把 `_buildTabContent(ThemeTokens tokens)` 改为 `_buildTabContent(ThemeTokens tokens, UIStyle style)`；`_buildStyleTab(ThemeTokens tokens, UIStyle style)`；`_buildBorderTab(ThemeTokens tokens, UIStyle style)`。`_buildExpandedPanel` 调用 `_buildTabContent(tokens, style)`。

- [ ] **Step 7: 改造样式 Tab 文本输入（用 LumiraTextField）与开关（用 LumiraSwitch）**

`_buildStyleTab` 内的 `TextField` 替换为：

```dart
        if (el.type == WatermarkElementType.text)
          LumiraTextField(
            controller: _textEditController,
            hintText: '输入文本',
            onChanged: (v) {
              el.text = v;
              setState(() {});
            },
          ),
```

`_toggleRow` 内的原生 `Switch` 替换为：

```dart
        LumiraSwitch(
          value: value,
          onChanged: onChanged,
        ),
```

（`_toggleRow` 形参不需要 tokens 时移除其 `tokens` 参数；若其它位置仍引用 `tokens` 则保留。）

- [ ] **Step 8: 改造 `_sliderRow`（用 LumiraSlider）**

把 `Expanded(child: Slider(...))` 替换为：

```dart
        Expanded(
          child: LumiraSlider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
```

（保留左侧 `SizedBox(width:56, child: Text(label))` 与右侧 `SizedBox(width:40, child: Text(value))`。`LumiraSlider` 为 Consumer 组件，内部自行 watch 主题。）

- [ ] **Step 9: 颜色选点样式微调（白色圆点浅色底可见）**

`_buildElementPalette` 与 `_buildFramePalette` 中，把非选中描边颜色从 `tokens.divider` 改为带对比的 `tokens.textTertiary.withOpacity(0.35)`，选中仍用 `tokens.brand`：

```dart
                  border: Border.all(
                    color: el.color == c ? tokens.brand : tokens.textTertiary.withOpacity(0.35),
                    width: 2,
                  ),
```

（框架选点同理：`frame.color == c ? tokens.brand : tokens.textTertiary.withOpacity(0.35)`。）

- [ ] **Step 10: flutter analyze + 运行测试**

```bash
flutter analyze lib/features/watermark/pages/watermark_editor_page.dart
flutter test test/features/watermark/watermark_editor_page_test.dart
flutter test test/features/watermark/watermark_style_adaptive_test.dart
```

**Expected:** `flutter analyze` 无 error；两个测试文件均 `All tests passed!`。若 `_previewBg` / 未使用的 `style` 形参产生 lint **info**（非 error）可忽略，但不要留 `unused` error。

- [ ] **Step 11: Commit**

```bash
git add lumira_app_flutter/lib/features/watermark/pages/watermark_editor_page.dart
git add lumira_app_flutter/test/features/watermark/watermark_style_adaptive_test.dart
git commit -m "feat(watermark): 编辑器底部面板与全部小控件风格自适应"
```

---

### Task 3: 管理页 `_LayoutSegments` 风格自适应

**Files:**
- Modify: `d:\app\projects\photo_post\lumira_app_flutter\lib\features\watermark\pages\watermark_manage_page.dart`
- Test: `d:\app\projects\photo_post\lumira_app_flutter\test\features\watermark\watermark_manage_page_test.dart`（既有，保持绿）

**Interfaces:**
- `_LayoutSegments` 增加 `UIStyle style` 字段；父级 watch `uiStyleProvider` 传入。

- [ ] **Step 1: 父级 watch style 并透传**

在 `build` 中 `final tokens = ref.watch(themeTokensProvider);` 之后加：

```dart
    final style = ref.watch(uiStyleProvider);
```

`_layoutHeader(tokens, layout)` 改为 `_layoutHeader(tokens, layout, style)`；`_LayoutSegments` 构造传 `style: style`。

- [ ] **Step 2: 重写 `_LayoutSegments` 为风格自适应**

把 `_LayoutSegments` 整体替换为：

```dart
/// 布局切换分段控件：单列 / 双列（风格自适应）
class _LayoutSegments extends StatelessWidget {
  const _LayoutSegments({
    required this.value,
    required this.onChanged,
    required this.tokens,
    required this.style,
  });

  final WatermarkManageLayout value;
  final ValueChanged<WatermarkManageLayout> onChanged;
  final ThemeTokens tokens;
  final UIStyle style;

  @override
  Widget build(BuildContext context) {
    final double radius = style == UIStyle.flat ? 8 : (style == UIStyle.female ? 16 : 12);
    // 容器底：female 用 brandSubtle 淡底；其余 surfaceAlt 淡底
    final Color track =
        style == UIStyle.female ? tokens.brandSubtle : tokens.surfaceAlt;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seg(Icons.view_agenda, WatermarkManageLayout.list, radius),
          const SizedBox(width: 3),
          _seg(Icons.grid_view, WatermarkManageLayout.grid, radius),
        ],
      ),
    );
  }

  Widget _seg(
    IconData icon,
    WatermarkManageLayout layout,
    double radius,
  ) {
    final active = value == layout;
    final List<BoxShadow> shadow = active
        ? (style == UIStyle.female
            ? [
                BoxShadow(
                  color: tokens.brand.withOpacity(0.15),
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                ),
              ]
            : style == UIStyle.neumorphic
                ? tokens.shadowConvexSubtle
                : const [])
        : const [];
    return GestureDetector(
      onTap: () => onChanged(layout),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          // female 激活用 gradient；其余激活用 surface 凸起 + 品牌描边；glass 激活用白 0.4
          gradient: active && style == UIStyle.female
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    tokens.brandSubtle.withOpacity(0.9),
                    tokens.surface,
                  ],
                )
              : null,
          color: active
              ? (style == UIStyle.glass
                  ? Colors.white.withOpacity(0.4)
                  : style == UIStyle.female
                      ? tokens.surface
                      : tokens.surface)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(radius - 3),
          border: active
              ? (style == UIStyle.neumorphic
                  ? null
                  : Border.all(color: tokens.brand, width: 1))
              : null,
          boxShadow: shadow,
        ),
        child: Icon(
          icon,
          size: 20,
          color: active ? tokens.brandText : tokens.textSecondary,
        ),
      ),
    );
  }
}
```

（`UIStyle` 已有 import：`theme_controller.dart` / `app_theme.dart` 均在文件内；确认 `UIStyle` 符号可见。`uiStyleProvider` 来自 `theme_controller.dart`，已 import。）

- [ ] **Step 3: 运行测试 + analyze**

```bash
flutter analyze lib/features/watermark/pages/watermark_manage_page.dart
flutter test test/features/watermark/watermark_manage_page_test.dart
```

**Expected:** analyze 无 error；管理页测试全绿（`watermark-layout-toggle` key 不受影响）。

- [ ] **Step 4: Commit**

```bash
git add lumira_app_flutter/lib/features/watermark/pages/watermark_manage_page.dart
git commit -m "feat(watermark): 管理页布局切换分段控件风格自适应"
```

---

### Task 4: 全量回归验证

**Files:**（无新改动，仅验证）

- [ ] **Step 1: 全量 Flutter analyze**

```bash
flutter analyze
```

**Expected:** 无 error（允许少量与本次无关的 info）。

- [ ] **Step 2: 全量测试**

```bash
flutter test
```

**Expected:** 全绿。特别关注 `test/features/watermark/**` 与可能被 `_LayoutSegments` / 编辑页影响的上游测试（`profile`、`gallery` 二次加工入口相关）。

- [ ] **Step 3: 人工核验 4 风格（真机/模拟器，可选但有价值）**

在「设置 → UI 风格」下分别切 neumorphic / flat / glass / female，进水印编辑页确认：
- 顶部无黑边、状态栏与导航同色；
- 预览区为深色沉浸底、四周无死黑；
- 底部面板展开/折叠、三 Tab、样式 Tab 的字号/透明度滑块、文本输入、颜色点均随风格与主题变化；
- 收起时 Home indicator 区域底色与面板一致（无黑条）。

- [ ] **Step 4: 收尾说明（不提交，除非用户要求）**

Flutter 侧改动不提交远端。如需 Git 提交，仅按上面各 Task 的 commit 记录为准；不 push 双端远程（本计划不涉及后端/后台）。

---

## 自检（Self-Review）

- **Spec 覆盖**：Spec 3.1 骨架/黑边 → Task1；3.2 面板 → Task2 Step4；3.3 Tab → Task2 Step5；3.4 小按钮/芯片 → Task2 Step6；3.5 输入控件 → Task2 Step7/8/9；3.6 顶栏去冗余底 → Task1 Step4；3.7 预览区深底 → Task1 Step5；4 管理页 `_LayoutSegments` → Task3。覆盖完整。
- **占位符扫描**：无 TBD/TODO，每处均给出实际代码。
- **类型一致性**：`_chipDeco(tokens, style, {active, radius, danger, raised})`、`_panelDecoration(tokens, style)`、`_scaleFor(style)`、`_previewBg(tokens)` 在各 Task 中名称/签名一致；`_buildTabContent/_buildStyleTab/_buildBorderTab/_buildElementTab/_expandedPanel` 统一为 `(tokens[, style])` 形态并透传。