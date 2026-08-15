# 拍摄参数重复调整优化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 消除拍摄页 → 预览页 → 后期修图页三处后处理参数调整的"重复调"感知，并统一后处理编辑组件，避免同一套 `PostProcess` 参数在三个页面重复实现。

**Architecture:** 复用已存在的「基线+增量」（baked + delta）无损编辑模型，让 `PreviewEditPanel` 的滑块显示**全量值**（baked 基线 + 用户增量），而非当前从 0 起的增量。为此新增一对纯函数 `fullOf(baked, local)` / `deltaOf(baked, full)` 负责全量↔增量的双向换算，并让 `PreviewEditPanel` 接收可选 `bakedPostProcess` 参数。最后抽取共享的后处理编辑 Tab，统一拍摄页与预览/后期页的滑块实现。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6（不支持 Dart 3 records），flutter_riverpod 2.3.6，lumira_app_flutter。

## Global Constraints

- Dart 2.19.6，**禁止 Dart 3 records 语法**（`(a, b)` 元组、`switch` 表达式、`...` spread 等需谨慎）。
- 所有改动仅在 `lumira_app_flutter/` 内，不触碰 `lumira-app/`（废弃 uni-app）。
- 不引入新依赖，复用现有 `PostProcess` / `PostProcessColor` / `TransformParams` 模型（`lib/features/capture/domain/photo_template.dart`）。
- 保持 `PostProcess.merge` 现有语义不动（保存时从原图全量重处理依赖它）。
- 每个任务结束必须运行 `flutter analyze` 与对应测试，全部通过后再 commit。
- 中文代码注释。

---

### Task 1: 新增全量↔增量换算纯函数

**Files:**
- Create: `lumira_app_flutter/lib/features/capture/domain/post_process_delta.dart`
- Test: `lumira_app_flutter/test/features/capture/domain/post_process_delta_test.dart`

**Interfaces:**
- Produces:
  - `PostProcess fullOf(PostProcess baked, PostProcess local)` — 返回用户在编辑面板上应看到/操作的全量参数（`baked.merge(local)`）。
  - `PostProcess deltaOf(PostProcess baked, PostProcess full)` — 给定基线 `baked` 与目标全量 `full`，反推出应写入的增量 `local`（保存时 `baked.merge(local)` 应还原出 `full`）。供后序 Task 的编辑面板在"滑块绑定全量、onChanged 写增量"时使用。

**说明（写给实现者）：**
- `fullOf` 直接委托 `baked.merge(local)`（`photo_template.dart` 已有）。
- `deltaOf` 需逐字段反向换算：
  - 加法字段（`color` 的全部数值字段、`smoothStrength`、`sharpen`、`vignette`、`grain`）：`local = full - baked`（`color` 的 nullable 字段按 `?? 0` 处理）。
  - `lut`：`full.lut == baked.lut ? 'none' : full.lut`（与 `merge` 的"`delta.lut != 'none' ? delta.lut : lut`"语义互逆）。
  - `systemFilter`：`full.systemFilter == baked.systemFilter ? null : full.systemFilter`。
  - `cropRatio`：取 `full.cropRatio`（非加法，绝对值）。
  - `customCropRect`：取 `full.customCropRect`。
- 注意反转后 `baked.merge(deltaOf(baked, full))` 对加法字段会多算一次（`baked + (full - baked) = full`，正确）；对 lut/systemFilter 需保证互逆成立（见上面的映射）。

- [ ] **Step 1: 写失败测试**

```dart
// test/features/capture/domain/post_process_delta_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/capture/domain/post_process_delta.dart';

PostProcess _pp({
  double brightness = 0,
  double saturation = 0,
  int smooth = 0,
  String lut = 'none',
  String? sf,
}) =>
    PostProcess(
      color: PostProcessColor(brightness: brightness, saturation: saturation),
      smoothStrength: smooth,
      lut: lut,
      systemFilter: sf,
    );

void main() {
  group('fullOf', () {
    test('合并加法字段', () {
      final baked = _pp(brightness: 20, smooth: 10);
      final local = _pp(brightness: 5, smooth: 3);
      final full = fullOf(baked, local);
      expect(full.color.brightness, 25);
      expect(full.smoothStrength, 13);
    });

    test('lut 未改动保留 baked', () {
      final baked = _pp(lut: 'fuji');
      final local = _pp(lut: 'none');
      expect(fullOf(baked, local).lut, 'fuji');
    });
  });

  group('deltaOf', () {
    test('加法字段反推增量', () {
      final baked = _pp(brightness: 20, smooth: 10);
      final full = _pp(brightness: 25, smooth: 13);
      final delta = deltaOf(baked, full);
      expect(delta.color.brightness, 5);
      expect(delta.smoothStrength, 3);
    });

    test('lut 与 baked 相同则 local 为 none，还原后仍为 baked', () {
      final baked = _pp(lut: 'fuji');
      final full = _pp(lut: 'fuji');
      final delta = deltaOf(baked, full);
      expect(delta.lut, 'none');
      expect(fullOf(baked, delta).lut, 'fuji');
    });

    test('lut 与 baked 不同则 eq full', () {
      final baked = _pp(lut: 'fuji');
      final full = _pp(lut: 'vintage');
      final delta = deltaOf(baked, full);
      expect(delta.lut, 'vintage');
      expect(fullOf(baked, delta).lut, 'vintage');
    });

    test('systemFilter 与 baked 相同则 local 为 null', () {
      final baked = _pp(sf: 'vivid');
      final full = _pp(sf: 'vivid');
      final delta = deltaOf(baked, full);
      expect(delta.systemFilter, isNull);
      expect(fullOf(baked, delta).systemFilter, 'vivid');
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/features/capture/domain/post_process_delta_test.dart`
Expected: FAIL（`post_process_delta.dart` 不存在 / 函数未定义）。

- [ ] **Step 3: 实现最小代码**

```dart
// lib/features/capture/domain/post_process_delta.dart
import 'photo_template.dart';

/// 用户在编辑面板上看到的全量参数 = 基线 baked + 增量 local。
PostProcess fullOf(PostProcess baked, PostProcess local) => baked.merge(local);

/// 由基线 baked 与目标全量 full 反推增量 local。
/// 与 [PostProcess.merge] 语义互逆，保证 baked.merge(deltaOf(baked, full)) 还原 full。
PostProcess deltaOf(PostProcess baked, PostProcess full) {
  final bc = baked.color;
  final fc = full.color;
  return PostProcess(
    color: PostProcessColor(
      brightness: fc.brightness - bc.brightness,
      contrast: fc.contrast - bc.contrast,
      saturation: fc.saturation - bc.saturation,
      temperature: fc.temperature - bc.temperature,
      tint: fc.tint - bc.tint,
      highlights: (fc.highlights ?? 0) - (bc.highlights ?? 0),
      shadows: (fc.shadows ?? 0) - (bc.shadows ?? 0),
      blackPoint: (fc.blackPoint ?? 0) - (bc.blackPoint ?? 0),
      clarity: (fc.clarity ?? 0) - (bc.clarity ?? 0),
      vibrance: (fc.vibrance ?? 0) - (bc.vibrance ?? 0),
      brilliance: (fc.brilliance ?? 0) - (bc.brilliance ?? 0),
    ),
    smoothStrength: full.smoothStrength - baked.smoothStrength,
    sharpen: full.sharpen - baked.sharpen,
    vignette: full.vignette - baked.vignette,
    grain: full.grain - baked.grain,
    cropRatio: full.cropRatio,
    lut: full.lut == baked.lut ? 'none' : full.lut,
    systemFilter:
        full.systemFilter == baked.systemFilter ? null : full.systemFilter,
    customCropRect: full.customCropRect,
  );
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/features/capture/domain/post_process_delta_test.dart`
Expected: PASS。

- [ ] **Step 5: 运行 analyze 并提交**

```bash
cd lumira_app_flutter
flutter analyze lib/features/capture/domain/post_process_delta.dart
git add lib/features/capture/domain/post_process_delta.dart test/features/capture/domain/post_process_delta_test.dart
git commit -m "feat(capture): add PostProcess full/delta conversion helpers"
```

---

### Task 2: PreviewEditPanel 增加 baked 基线，滑块显示全量值

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/widgets/preview_edit_panel.dart`
- Test: `lumira_app_flutter/test/features/capture/widgets/preview_edit_panel_test.dart`

**Interfaces:**
- Consumes: `fullOf(baked, local)` / `deltaOf(baked, full)`（Task 1）。
- Produces: `PreviewEditPanel` 新增可选参数 `PostProcess? bakedPostProcess`（默认 null，视为全零基线）。当不为 null 时，`_ColorTab` / `_DetailTab` / `_FilterTab` 绑定的滑块值改为 `fullOf(baked, postProcess)` 对应字段，`onPostProcessChanged` 回调时传出 `deltaOf(baked, newFull)`；为 null 时保持现状（postProcess 即全量，直接绑定）。

**设计决策：**
- 为最小侵入，`_SliderRow` 仍接收"当前显示值 + onChanged 回调"。改造点集中在 `_ColorTab` / `_DetailTab` / `_FilterTab`：把"从 `postProcess` 读值 / 写回 `postProcess`"改为"从 `full` 读值 / 写回 `delta`"。
- 做法：在 `_PreviewEditPanelState` 内计算 `final baked = widget.bakedPostProcess ?? const PostProcess(color: PostProcessColor()); final full = fullOf(baked, widget.postProcess);`，并新增 `_updatePostFromFull(PostProcess newFull) => widget.onPostProcessChanged(deltaOf(baked, newFull));`。各 Tab 接收 `full` 与 `_updatePostFromFull`。
- 注意：`_bakedPostProcess == null` 时 `full == postProcess` 且 `deltaOf(全零, full) == full`，因此默认行为完全不变，现有测试不受影响。

- [ ] **Step 1: 写失败测试**

在 `preview_edit_panel_test.dart` 追加：

```dart
testWidgets('with bakedPostProcess: slider shows full value, emits delta', (tester) async {
  PostProcess? captured;
  await tester.pumpWidget(wrapWidget(
    PreviewEditPanel(
      postProcess: const PostProcess(color: PostProcessColor()), // 增量 0
      bakedPostProcess: const PostProcess(
        color: PostProcessColor(brightness: 20),
      ),
      transform: const TransformParams(),
      onPostProcessChanged: (p) => captured = p,
      onTransformChanged: (_) {},
    ),
  ));

  // 亮度行显示全量 20（而非增量 0）
  expect(find.text('20'), findsWidgets);
});
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/features/capture/widgets/preview_edit_panel_test.dart --plain-name "with bakedPostProcess"`
Expected: FAIL（`bakedPostProcess` 参数尚不存在，编译错误）。

- [ ] **Step 3: 改造 PreviewEditPanel**

按"设计决策"实现：给 `PreviewEditPanel` 增加 `this.bakedPostProcess` 字段；在 State 中计算 `baked` / `full` / `_updatePostFromFull`；将 `_buildCurrentTab` 传给 Tab 的 `postProcess` 改为 `full`，`onChanged` 改为 `_updatePostFromFull`。保留 `_ColorTab`/`_DetailTab`/`_FilterTab` 内部结构不变（它们只读 `postProcess` 字段并回调 `onChanged`）。

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/features/capture/widgets/preview_edit_panel_test.dart`
Expected: 全部 PASS（含原有 5 个用例）。

- [ ] **Step 5: 运行 analyze 并提交**

```bash
cd lumira_app_flutter
flutter analyze lib/features/capture/widgets/preview_edit_panel.dart
git add lib/features/capture/widgets/preview_edit_panel.dart test/features/capture/widgets/preview_edit_panel_test.dart
git commit -m "feat(capture): PreviewEditPanel shows full value with baked baseline"
```

---

### Task 3: 预览页 / 后期修图页传入 baked 基线

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/pages/capture_preview_page.dart`
- Modify: `lumira_app_flutter/lib/features/gallery/pages/gallery_edit_page.dart`
- Test: `lumira_app_flutter/test/features/capture/capture_preview_page_test.dart`（若存在该文件相关用例则补充/回归）

**Interfaces:**
- Consumes: `PreviewEditPanel.bakedPostProcess`（Task 2）。
- Behavior: 两处调用 `PreviewEditPanel` 时，把当前 `_bakedPostProcess` 作为 `bakedPostProcess:` 传入。这样滑块显示全量（拍摄时烘焙值 + 预览增量），用户一眼看到"已调过的值"，无需重复调。

**注意：**
- 两处 `PreviewEditPanel` 调用点（capture_preview_page.dart L1578/L1598，gallery_edit_page.dart L226）均需改。
- 传入后，`onPostProcessChanged` 回调收到的将是"增量 delta"（由 Task 2 的 `deltaOf` 算出），而现有回调把收到的值直接赋给 `_localPostProcess`（增量语义），语义一致，无需改回调逻辑。
- 保存逻辑（`_bakedPostProcess.merge(_localPostProcess)`）保持不变，因此最终出图结果与滑块显示的全量一致。

- [ ] **Step 1: 修改 capture_preview_page.dart 两处调用**

将 L1578 与 L1598 的 `PreviewEditPanel(...)` 增加 `bakedPostProcess: _bakedPostProcess,`。

- [ ] **Step 2: 修改 gallery_edit_page.dart**

将 L226 的 `PreviewEditPanel(...)` 增加 `bakedPostProcess: _bakedPostProcess,`。

- [ ] **Step 3: 运行相关测试回归**

Run: `flutter test test/features/capture/capture_preview_page_test.dart test/features/gallery/gallery_detail_page_test.dart`
Expected: 全部 PASS（若文件不存在则跳过，以 `flutter test` 实际结果为准）。

- [ ] **Step 4: 运行 analyze 并提交**

```bash
cd lumira_app_flutter
flutter analyze lib/features/capture/pages/capture_preview_page.dart lib/features/gallery/pages/gallery_edit_page.dart
git add lib/features/capture/pages/capture_preview_page.dart lib/features/gallery/pages/gallery_edit_page.dart
git commit -m "feat(capture): pass baked baseline to edit panel to show full values"
```

---

### Task 4: 抽取共享后处理编辑 Tab，统一拍摄页与编辑页滑块

**Files:**
- Create: `lumira_app_flutter/lib/features/capture/widgets/post_process_color_tab.dart`（共享色彩 Tab）
- Create: `lumira_app_flutter/lib/features/capture/widgets/post_process_detail_tab.dart`（共享细节 Tab）
- Create: `lumira_app_flutter/lib/features/capture/widgets/post_process_slider_row.dart`（共享滑块行）
- Modify: `lumira_app_flutter/lib/features/capture/widgets/preview_edit_panel.dart`（改用共享 Tab）
- Modify: `lumira_app_flutter/lib/features/capture/widgets/param_panel.dart`（色彩/细节 Tab 改用共享 Tab）
- Test: `lumira_app_flutter/test/features/capture/widgets/preview_edit_panel_test.dart`（回归）
- Test: `lumira_app_flutter/test/features/capture/widgets/param_panel_test.dart`（回归）

**设计决策：**
- 共享组件为**受控纯展示**：接收 `PostProcess full` 与 `ValueChanged<PostProcess> onChanged`，UI 只读字段并回调全量值。具体"全量↔增量"换算由上层（`PreviewEditPanel` 用 `deltaOf`，`ParamPanel` 用 `CaptureState.updatePostProcess`）负责，共享 Tab 不感知 baked。
- `PostProcessSliderRow` 采用与现有 `PreviewEditPanel._SliderRow` 一致的视觉（细线轨道 + 圆形把手 + 品牌色 #E5C07B），统一两处观感。
- `ParamPanel` 的 `_ColorTab`/`_DetailTab` 替换为共享 Tab 后，回调改为 `CaptureState.updatePostProcess(ref, (p) => p.copyWith(color: newFull.color))` 等（保持写入全局 state、实时预览取景器不变）。
- 此任务为纯 UI 重构，不改任何参数语义与行为。

- [ ] **Step 1: 创建共享 `PostProcessSliderRow`**

从 `preview_edit_panel.dart` 的 `_SliderRow` 复制为公共组件，保留 `label/value/min/max/onChanged/hint` 接口，视觉不变。

- [ ] **Step 2: 创建共享 `PostProcessColorTab` 与 `PostProcessDetailTab`**

从 `PreviewEditPanel` 的 `_ColorTab` / `_DetailTab` 复制为公共组件，接口改为 `PostProcess full` + `ValueChanged<PostProcess> onChanged`，内部使用 `PostProcessSliderRow`。

- [ ] **Step 3: 让 `PreviewEditPanel` 复用共享 Tab**

将 `_ColorTab` / `_DetailTab` / `_SliderRow` 删除，改为引用共享组件；`FilterTab` / `_FilterThumbnail` / `CropTab` 保留在 `preview_edit_panel.dart`。

- [ ] **Step 4: 让 `ParamPanel` 的 `_ColorTab` / `_DetailTab` 复用共享 Tab**

删除 `ParamPanel` 内重复的 `_ColorTab` / `_DetailTab` / `_SliderRow` / `_SectionCard` / `_PopupRow` 中与共享组件重复的部分，改用共享 `PostProcessColorTab`/`PostProcessDetailTab`，回调桥接到 `CaptureState.updatePostProcess`。

- [ ] **Step 5: 运行回归测试**

Run: `flutter test test/features/capture/widgets/preview_edit_panel_test.dart test/features/capture/widgets/param_panel_test.dart`
Expected: 全部 PASS。

- [ ] **Step 6: 全量 analyze + 提交**

```bash
cd lumira_app_flutter
flutter analyze lib/features/capture/widgets/
git add lib/features/capture/widgets/
git commit -m "refactor(capture): unify post-process edit tabs across capture & edit pages"
```

---

## Self-Review

- **Spec coverage:** 方案A（Task 1-3：滑块显示全量、输入连续性）与方案B（Task 4：统一组件）均已覆盖。Task 1 提供换算基石，Task 2 改造面板，Task 3 接入基线，Task 4 消除组件级重复。
- **Placeholder scan:** 各步骤均含完整代码/命令/预期输出，无 TBD/TODO 占位。
- **Type consistency:** `fullOf`/`deltaOf`/`bakedPostProcess`/`PostProcessSliderRow`/`PostProcessColorTab`/`PostProcessDetailTab` 命名在各任务间一致；`deltaOf` 返回的增量语义与现有 `_localPostProcess` 一致，保存链路 `baked.merge(local)` 不变。