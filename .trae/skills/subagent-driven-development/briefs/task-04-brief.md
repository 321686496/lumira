# Task 4: 预设更新（新增「拍立得」）

**Files:**
- Modify: `lumira_app_flutter/lib/features/watermark/data/preset_watermarks.dart`
- Test: `lumira_app_flutter/test/features/watermark/preset_watermarks_test.dart`（新建）

**Interfaces:**
- Consumes: `WatermarkFrame`/`WatermarkElementSpace`（Task 2 已完成）。
- Produces: `getPresetWatermarks()` 返回 6 款，新增 id=`preset_polaroid`（拍立得，frame=polaroid，日期元素 space=frame）。

## 现有代码结构

`preset_watermarks.dart` 当前：`getPresetWatermarks()` 返回 5 款（`_minimalDate`/`_filmStamp`/`_artSignature`/`_magazineLayout`/`_frameBorder`）。文件头已有 `import 'package:flutter/painting.dart' show TextAlign;`，但**没有 Color 导入**——新增 `_polaroid()` 用到 `Color(0xFFFFFFFF)` 等，需确认 `Color` 可用（可加 `import 'package:flutter/painting.dart' show Color, TextAlign;` 或 `import 'dart:ui' show Color;`，视现有模型 `WatermarkFrame.color` 用 `ui.Color` 而定——模型里 `WatermarkFrame` 用 `const ui.Color(0xFFFFFFFF)` 即 `dart:ui` Color，这里的话用 `Color(0x...)` 需引入 `dart:ui` 或 `painting`）。**以实际编译为准，选择与文件一致的导入方式。**

## Global Constraints

- **Dart 版本**：Dart 2.19.6 / Flutter 3.7.12，禁止 Dart 3 records。
- 测试：`flutter test test/features/watermark/preset_watermarks_test.dart` 定向测试；提交前本任务相关测试全绿。

---

- [ ] **Step 1: 写失败测试**

  新建 `test/features/watermark/preset_watermarks_test.dart`：
  ```dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:lumira_app_flutter/features/watermark/data/preset_watermarks.dart';
  import 'package:lumira_app_flutter/features/watermark/models/watermark_template.dart';

  void main() {
    test('预设有 6 款且 id 唯一', () {
      final presets = getPresetWatermarks();
      expect(presets.length, 6);
      final ids = presets.map((e) => e.id).toSet();
      expect(ids.length, presets.length);
    });
    test('拍立得预设：frame=polaroid、日期元素在 frame 空间', () {
      final pol = getPresetWatermarks().firstWhere((t) => t.id == 'preset_polaroid');
      expect(pol.frame.type, WatermarkFrameType.polaroid);
      expect(pol.frame.bottomPlate, isTrue);
      final dateEl = pol.elements.firstWhere(
        (e) => e.type == WatermarkElementType.dateTime ||
            (e.type == WatermarkElementType.text && e.text.contains('20')),
      );
      expect(dateEl.space, WatermarkElementSpace.frame);
    });
    test('其余预设 frame 为 none', () {
      for (final t in getPresetWatermarks()) {
        if (t.id == 'preset_polaroid') continue;
        expect(t.frame.type, WatermarkFrameType.none, reason: t.id);
      }
    });
  }
  ```
  **注意**：包名为 `package:lumira_app_flutter/...`（Task 2/3 已验证）。

- [ ] **Step 2: 运行测试确认失败**

  Run: `flutter test test/features/watermark/preset_watermarks_test.dart`
  Expected: FAIL（`preset_polaroid` 不存在 / length 不是 6）。

- [ ] **Step 3: 实现拍立得预设**

  在 `preset_watermarks.dart` 的 `getPresetWatermarks()` 列表末尾追加 `_polaroid()`（现在返回 6 款），并新增函数：
  ```dart
  WatermarkTemplate _polaroid() {
    return WatermarkTemplate(
      id: 'preset_polaroid',
      name: '拍立得',
      type: WatermarkTemplateType.preset,
      createdAt: DateTime(2026, 8, 20),
      frame: const WatermarkFrame(
        type: WatermarkFrameType.polaroid,
        color: Color(0xFFFFFFFF),
        borderRatio: 0.05,
        borderRadius: 0.0,
        bottomPlate: true,
        bottomRatio: 0.18,
        shadowColor: Color(0xFF000000),
        shadowOpacity: 0.22,
        shadowBlur: 0.02,
      ),
      elements: [
        WatermarkElement(
          id: 'preset_polaroid_date',
          type: WatermarkElementType.dateTime,
          text: '2026.08.20',
          x: 0.5,
          y: 0.5,
          fontSize: 0.045,
          color: const Color(0xFF444444),
          shadowColor: const Color(0x00000000),
          space: WatermarkElementSpace.frame,
          textAlign: TextAlign.center,
          fontFamily: 'serif',
          italic: true,
        ),
      ],
    );
  }
  ```
  需确认 `Color` 可用（见"现有代码结构"）。现有 5 款预设的 elements 均用默认 space（photo），无需改动。`frame` 参数在 `WatermarkTemplate` 构造函数里已由 Task 2 提供（默认 `const WatermarkFrame()`），`space` 参数在 `WatermarkElement` 构造函数里已由 Task 2 提供。

- [ ] **Step 4: 运行测试确认通过**

  Run: `flutter test test/features/watermark/preset_watermarks_test.dart`
  Expected: PASS。

- [ ] **Step 5: Commit**

  ```bash
  git add lumira_app_flutter/lib/features/watermark/data/preset_watermarks.dart lumira_app_flutter/test/features/watermark
  git commit -m "feat(watermark): add polaroid preset with frame-space date"
  ```

  **重要**：本仓库有另一会话（usage/scenes 任务）在并行提交，工作区可能有其未暂存改动以及历史中与本任务无关的提交。提交前务必 `git status`，**只精确暂存上述 2 个文件**，绝不 `git add -A`、绝不混入并行会话的改动。提交后判定：仅当 `git log` 与你改动相关的仓库干净即可，不需要处理并行会话的历史。