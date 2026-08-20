# 水印功能 V2 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将水印功能独立为 `lib/features/watermark/` 模块，重做沉浸式编辑器（全屏照片 + 底部可收起操作栏）、管理页（单列/双列切换持久化）、新增拍立得白边画框、文字可打照片或白边，并支持相册二次添加水印。

**Architecture:** 模型层新增 `WatermarkFrame`（拍立得/内描边）与元素 `space`（照片/白边坐标系）；渲染器改为按整个模板（含画框）渲染并显式返回输出尺寸；编辑器采用"全屏照片 contain 预览 + 底部锚定可收起操作栏（元素/样式/边框三 Tab）+ 手势编辑"；管理页单列/双列布局切换持久化到 `WatermarkSettings.manageLayout`；相册详情"更多"菜单新增"添加水印"进入应用模式编辑器。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6（禁 Dart 3 records）、flutter_riverpod 2.3.6、sqflite（user_settings + watermark_templates）、dart:ui Canvas + `image` 包（纯 Dart JPEG 编码）、flutter_test。

## Global Constraints

- **Dart 版本**：Dart 2.19.6 / Flutter 3.7.12，**禁止 Dart 3 records 语法**（禁止 `(a, b)` 记录字面量与记录类型）。
- **UI 风格铁律（AGENTS.md）**：所有颜色/阴影/边框/圆角必须来自 `appThemeProvider`（`AppThemeData` 的 `.tokens`/`.style`/`.cardRadius`/`.cardShadow`/`.cardBorder`/`.surfaceAlpha`）+ `uiStyleProvider`，禁止硬编码 `Colors.xxx`/`Color(0xFF...)`/写死 BoxShadow/BorderRadius 表达主题观感。唯一例外是叠照片的黑/白半透明遮罩。
- **禁止风格混搭**：同一次视觉呈现只能使用当前设置的那套 UI 风格与主题色板。
- **叠在照片上的浮层**：新拟态下用实心 `tokens.surface` + 细边，**无外阴影、无模糊**；glass 风格允许其自身毛玻璃；不混搭。
- **复用共享组件**：优先 `NeuCard`、`LumiraButton`、`LumiraIconButton`、`LumiraTextField`、`LumiraNav` 等。
- **渲染器输出尺寸**：画框会使输出 ≠ 原图尺寸，调用方必须用返回的 `width/height` 重建图片（`capture_page.dart` 已核实需同步修改）。
- **序列化兼容**：V1 已存模板 JSON 缺省 `space`/`frame` 字段时必须回退（space=photo、frame=none）。
- **测试**：`flutter test test/features/watermark/<file>` 定向测试；提交前本任务相关测试全绿。CI 为 `flutter analyze` + `flutter test`。
- **提交**：每任务完成后单独 commit（Flutter 改动不强制 push；仅后端/admin 改动才需 push 双远程）。

---

### Task 1: 模块化迁移（目录迁移 + 引用更新）

**Files:**
- Move: `lumira_app_flutter/lib/features/capture/watermark/` → `lumira_app_flutter/lib/features/watermark/`（内部 10 个文件整体迁移，`models/`、`data/`、`services/`、`pages/`、`widgets/` 结构不变）
- Modify: `lumira_app_flutter/lib/app/router.dart:16-17`（import 路径）
- Modify: `lumira_app_flutter/lib/core/db/dao/watermark_dao.dart:6`（import 路径）
- Modify: `lumira_app_flutter/lib/core/db/dao/settings_dao.dart:8`（import 路径）
- Modify: `lumira_app_flutter/lib/features/capture/pages/capture_page.dart`（import 路径）
- Modify: `lumira_app_flutter/lib/features/profile/pages/profile_settings_page.dart`（import 路径）

**Interfaces:**
- Consumes: 无（纯迁移）。
- Produces: 新路径 `lib/features/watermark/...`，后续所有任务在该路径下工作。路由常量不变（`RouteNames.profileSettingsWatermark` / `...Edit`）。

- [ ] **Step 1: 迁移目录**
  - 用文件系统操作将 `lib/features/capture/watermark/` 整个目录移动到 `lib/features/watermark/`，删除原目录。
  - 确认迁移后文件清单：
    - `lib/features/watermark/models/watermark_template.dart`
    - `lib/features/watermark/models/watermark_settings.dart`
    - `lib/features/watermark/data/watermark_providers.dart`
    - `lib/features/watermark/data/preset_watermarks.dart`
    - `lib/features/watermark/services/watermark_renderer.dart`
    - `lib/features/watermark/pages/watermark_manage_page.dart`
    - `lib/features/watermark/pages/watermark_editor_page.dart`
    - `lib/features/watermark/widgets/watermark_preview.dart`
    - `lib/features/watermark/widgets/watermark_animation_overlay.dart`

- [ ] **Step 2: 更新引用文件的 import 路径**

  `router.dart` 两处：
  ```dart
  import '../features/watermark/pages/watermark_editor_page.dart';
  import '../features/watermark/pages/watermark_manage_page.dart';
  ```
  `watermark_dao.dart`：
  ```dart
  import '../../../features/watermark/models/watermark_template.dart';
  ```
  `settings_dao.dart`：
  ```dart
  import '../../../features/watermark/models/watermark_settings.dart';
  ```
  对 `capture_page.dart` 与 `profile_settings_page.dart` 中的 `import .../capture/watermark/...` 执行同样的路径替换（可用编辑器全局替换 `features/capture/watermark` → `features/watermark`）。

- [ ] **Step 3: 验证无残留引用**

  Run: `flutter analyze`
  Expected: 无 error（允许 0 条有关 watermark 的 `import` 解析失败）。用 Grep 全仓确认不再存在字符串 `features/capture/watermark`。

- [ ] **Step 4: 跑相关既有测试确保未破坏**

  Run: `flutter test test/features/profile/profile_settings_page_test.dart test/features/capture/capture_page_test.dart`
  Expected: 全部 PASS。

- [ ] **Step 5: Commit**

  ```bash
  git add lumira_app_flutter/lib/features lumira_app_flutter/lib/app/router.dart lumira_app_flutter/lib/core/db/dao
  git commit -m "refactor(watermark): extract watermark into independent feature module"
  ```

---

### Task 2: 数据模型扩展（WatermarkFrame + space + manageLayout）

**Files:**
- Modify: `lumira_app_flutter/lib/features/watermark/models/watermark_template.dart`
- Modify: `lumira_app_flutter/lib/features/watermark/models/watermark_settings.dart`
- Test: `lumira_app_flutter/test/features/watermark/watermark_model_test.dart`（新建）

**Interfaces:**
- Consumes: 现有 `WatermarkElement`/`WatermarkTemplate`/`WatermarkSettings`。
- Produces:
  - `enum WatermarkFrameType { none, polaroid, innerBorder }`
  - `class WatermarkFrame`（`type`/`color`/`borderRatio`/`borderRadius`/`bottomPlate`/`bottomRatio`/`shadowColor`/`shadowOpacity`/`shadowBlur` + `copyWith`/`toJson`/`fromJson`）
  - `enum WatermarkElementSpace { photo, frame }`；`WatermarkElement.space` 默认 `photo`
  - `WatermarkTemplate.frame` 默认 `const WatermarkFrame()`
  - `enum WatermarkManageLayout { list, grid }`；`WatermarkSettings.manageLayout` 默认 `list`

- [ ] **Step 1: 写失败测试**

  新建 `test/features/watermark/watermark_model_test.dart`：
  ```dart
  import 'dart:ui' as ui;
  import 'package:flutter/painting.dart' show TextAlign;
  import 'package:flutter_test/flutter_test.dart';
  import 'package:lumira_app/features/watermark/models/watermark_settings.dart';
  import 'package:lumira_app/features/watermark/models/watermark_template.dart';

  void main() {
    group('WatermarkElement space 序列化', () {
      test('toJson/fromJson 保留 space', () {
        final e = WatermarkElement(id: 'e1', type: WatermarkElementType.text, text: '2026.08.20')
          ..space = WatermarkElementSpace.frame;
        final back = WatermarkElement.fromJson(e.toJson());
        expect(back.space, WatermarkElementSpace.frame);
      });
      test('旧 JSON 缺省 space 回退 photo', () {
        final e = WatermarkElement.fromJson({'id': 'e1', 'type': 'text', 'text': 'x'});
        expect(e.space, WatermarkElementSpace.photo);
      });
    });

    group('WatermarkFrame 序列化', () {
      test('toJson/fromJson roundtrip', () {
        const f = WatermarkFrame(
          type: WatermarkFrameType.polaroid,
          color: ui.Color(0xFFFFFFFF),
          borderRatio: 0.05,
          borderRadius: 0.01,
          bottomPlate: true,
          bottomRatio: 0.18,
          shadowColor: ui.Color(0xFF000000),
          shadowOpacity: 0.25,
          shadowBlur: 0.02,
        );
        final back = WatermarkFrame.fromJson(f.toJson());
        expect(back.type, WatermarkFrameType.polaroid);
        expect(back.borderRatio, 0.05);
        expect(back.bottomPlate, isTrue);
        expect(back.bottomRatio, 0.18);
        expect(back.shadowOpacity, 0.25);
      });
      test('旧模板 JSON 缺省 frame 回退 none', () {
        final t = WatermarkTemplate.fromJson({
          'id': 'preset_x',
          'name': 'x',
          'type': 'preset',
          'elements': <dynamic>[],
          'createdAt': '2026-08-08T00:00:00.000',
        });
        expect(t.frame.type, WatermarkFrameType.none);
      });
      test('模板含 frame roundtrip', () {
        final t = WatermarkTemplate(
          id: 't1',
          name: '拍立得',
          type: WatermarkTemplateType.custom,
          createdAt: DateTime(2026, 8, 20),
          elements: <WatermarkElement>[],
          frame: const WatermarkFrame(type: WatermarkFrameType.polaroid),
        );
        final back = WatermarkTemplate.fromJson(t.toJson());
        expect(back.frame.type, WatermarkFrameType.polaroid);
      });
    });

    group('WatermarkSettings manageLayout', () {
      test('默认 list', () {
        expect(const WatermarkSettings().manageLayout, WatermarkManageLayout.list);
      });
      test('toJson/fromJson roundtrip', () {
        const s = WatermarkSettings(manageLayout: WatermarkManageLayout.grid);
        final back = WatermarkSettings.fromJson(s.toJson());
        expect(back.manageLayout, WatermarkManageLayout.grid);
        expect(back.enabled, isTrue);
      });
      test('copyWith 更新 manageLayout', () {
        const s = WatermarkSettings();
        expect(s.copyWith(manageLayout: WatermarkManageLayout.grid).manageLayout,
            WatermarkManageLayout.grid);
      });
    });
  }
  ```
  注意：现有 `WatermarkElement` 为 `final` 字段 + `copyWith`（无 `..space =` 可变写法）。若实现采用 `copyWith(space: ...)`，测试应相应改为 `e.copyWith(space: WatermarkElementSpace.frame)`。实现时保持字段风格与现有 `copyWith` 一致（推荐 `copyWith`），测试据此微调。

- [ ] **Step 2: 运行测试确认失败**

  Run: `flutter test test/features/watermark/watermark_model_test.dart`
  Expected: FAIL（`space`/`WatermarkFrame`/`manageLayout` 不存在）。

- [ ] **Step 3: 实现模型扩展**

  `watermark_template.dart` 新增（放在 `WatermarkElement` 定义之前）：
  ```dart
  /// 画框类型：none（无画框）/ polaroid（拍立得白边）/ innerBorder（内描边）
  enum WatermarkFrameType { none, polaroid, innerBorder }

  /// 元素定位坐标系：photo（相对照片区域，默认）/ frame（相对画框/白板区域）
  enum WatermarkElementSpace { photo, frame }

  /// 水印画框：描述照片四周的边框/白边。
  ///
  /// polaroid：画布向外扩展（照片分辨率不变，四周加白边，底部可加宽白板），
  ///   底部带投影；innerBorder：画布与照片同尺寸，沿边缘画内描边。
  class WatermarkFrame {
    final WatermarkFrameType type;
    final ui.Color color;
    final double borderRatio; // 边框厚度 = borderRatio × 照片宽（0~0.2）
    final double borderRadius; // 圆角（相对照片宽的比例，0~0.08）
    final bool bottomPlate; // 拍立得底部白板开关
    final double bottomRatio; // 白板高 = bottomRatio × 照片高
    final ui.Color shadowColor;
    final double shadowOpacity; // 0~1
    final double shadowBlur; // 投影模糊（相对照片宽的比例）

    const WatermarkFrame({
      this.type = WatermarkFrameType.none,
      this.color = const ui.Color(0xFFFFFFFF),
      this.borderRatio = 0.05,
      this.borderRadius = 0.0,
      this.bottomPlate = true,
      this.bottomRatio = 0.18,
      this.shadowColor = const ui.Color(0xFF000000),
      this.shadowOpacity = 0.25,
      this.shadowBlur = 0.02,
    });

    WatermarkFrame copyWith({
      WatermarkFrameType? type,
      ui.Color? color,
      double? borderRatio,
      double? borderRadius,
      bool? bottomPlate,
      double? bottomRatio,
      ui.Color? shadowColor,
      double? shadowOpacity,
      double? shadowBlur,
    }) {
      return WatermarkFrame(
        type: type ?? this.type,
        color: color ?? this.color,
        borderRatio: borderRatio ?? this.borderRatio,
        borderRadius: borderRadius ?? this.borderRadius,
        bottomPlate: bottomPlate ?? this.bottomPlate,
        bottomRatio: bottomRatio ?? this.bottomRatio,
        shadowColor: shadowColor ?? this.shadowColor,
        shadowOpacity: shadowOpacity ?? this.shadowOpacity,
        shadowBlur: shadowBlur ?? this.shadowBlur,
      );
    }

    Map<String, dynamic> toJson() => {
          'type': type.name,
          'color': color.value,
          'borderRatio': borderRatio,
          'borderRadius': borderRadius,
          'bottomPlate': bottomPlate,
          'bottomRatio': bottomRatio,
          'shadowColor': shadowColor.value,
          'shadowOpacity': shadowOpacity,
          'shadowBlur': shadowBlur,
        };

    factory WatermarkFrame.fromJson(Map<String, dynamic> json) {
      return WatermarkFrame(
        type: _parseFrameType(json['type'] as String?),
        color: ui.Color((json['color'] as num?)?.toInt() ?? 0xFFFFFFFF),
        borderRatio: (json['borderRatio'] as num?)?.toDouble() ?? 0.05,
        borderRadius: (json['borderRadius'] as num?)?.toDouble() ?? 0.0,
        bottomPlate: (json['bottomPlate'] as bool?) ?? true,
        bottomRatio: (json['bottomRatio'] as num?)?.toDouble() ?? 0.18,
        shadowColor: ui.Color((json['shadowColor'] as num?)?.toInt() ?? 0xFF000000),
        shadowOpacity: (json['shadowOpacity'] as num?)?.toDouble() ?? 0.25,
        shadowBlur: (json['shadowBlur'] as num?)?.toDouble() ?? 0.02,
      );
    }

    static WatermarkFrameType _parseFrameType(String? value) {
      switch (value) {
        case 'polaroid':
          return WatermarkFrameType.polaroid;
        case 'innerBorder':
          return WatermarkFrameType.innerBorder;
        case 'none':
        default:
          return WatermarkFrameType.none;
      }
    }
  }
  ```
  `WatermarkElement` 增加 `space` 字段：
  ```dart
  WatermarkElementSpace space; // 默认 WatermarkElementSpace.photo

  // 构造参数新增：this.space = WatermarkElementSpace.photo,
  // copyWith 新增 WatermarkElementSpace? space,
  // toJson 新增 'space': space.name,
  // fromJson 新增：space: _parseSpace(json['space']),
  ```
  ```dart
  static WatermarkElementSpace _parseSpace(String? value) {
    switch (value) {
      case 'frame':
        return WatermarkElementSpace.frame;
      case 'photo':
      default:
        return WatermarkElementSpace.photo;
    }
  }
  ```
  `WatermarkTemplate` 增加 `frame` 字段：
  ```dart
  WatermarkFrame frame; // 构造参数默认 const WatermarkFrame()
  // toJson 新增 'frame': frame.toJson(),
  // fromJson：frame: json['frame'] != null
  //     ? WatermarkFrame.fromJson(json['frame'] as Map<String, dynamic>)
  //     : const WatermarkFrame(),
  ```

  `watermark_settings.dart` 新增：
  ```dart
  /// 水印管理页布局：list（单列）/ grid（双列）
  enum WatermarkManageLayout { list, grid }

  class WatermarkSettings {
    ...
    final WatermarkManageLayout manageLayout; // 默认 WatermarkManageLayout.list
    // copyWith 新增 WatermarkManageLayout? manageLayout,
    // toJson 新增 'manageLayout': manageLayout.name,
    // fromJson：
    //   manageLayout: _parseLayout(json['manageLayout']),
    // 新增：
    //   static WatermarkManageLayout _parseLayout(String? value) {
    //     switch (value) {
    //       case 'grid': return WatermarkManageLayout.grid;
    //       case 'list': default: return WatermarkManageLayout.list;
    //     }
    //   }
  }
  ```

- [ ] **Step 4: 运行测试确认通过**

  Run: `flutter test test/features/watermark/watermark_model_test.dart`
  Expected: PASS。

- [ ] **Step 5: Commit**

  ```bash
  git add lumira_app_flutter/lib/features/watermark/models lumira_app_flutter/test/features/watermark
  git commit -m "feat(watermark): add frame model, element space, manage layout setting"
  ```

---

### Task 3: 渲染器扩展（画框 + 坐标空间 + 返回尺寸）并修正拍照管线

**Files:**
- Modify: `lumira_app_flutter/lib/features/watermark/services/watermark_renderer.dart`
- Modify: `lumira_app_flutter/lib/features/capture/pages/capture_page.dart:670-688`
- Test: `lumira_app_flutter/test/features/watermark/watermark_renderer_test.dart`（新建）

**Interfaces:**
- Consumes: `WatermarkTemplate`（含 `frame`）、`WatermarkElement.space`（Task 2）。
- Produces:
  ```dart
  class WatermarkRenderResult {
    final Uint8List rgbaBytes;
    final int width;
    final int height;
  }
  Future<WatermarkRenderResult> render({required ui.Image sourceImage, required WatermarkTemplate template});
  ```
  渲染器不再暴露旧 `render({elements})` 签名。

- [ ] **Step 1: 写失败测试**

  新建 `test/features/watermark/watermark_renderer_test.dart`：
  ```dart
  import 'dart:ui' as ui;
  import 'package:flutter_test/flutter_test.dart';
  import 'package:lumira_app/features/watermark/models/watermark_template.dart';
  import 'package:lumira_app/features/watermark/services/watermark_renderer.dart';

  /// 构造一张纯色测试图（w×h）
  Future<ui.Image> makeImage(int w, int h, int argb) async {
    final bytes = Int32List(w * h);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = argb; // 注意端序：此处用 ARGB，测试仅用于尺寸断言
    }
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(bytes.buffer.asUint8List(), w, h, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }
  ```
  > 若 `Int32List`/`Completer` 需 import，在测试顶部补 `dart:typed_data` 与 `dart:async`。像素内容仅用于存在性，不做逐像素比对。

  ```dart
  void main() {
    TestWidgetsFlutterBinding.ensureInitialized();

    WatermarkTemplate _tpl(WatermarkFrameType type, {List<WatermarkElement> elements = const []}) {
      return WatermarkTemplate(
        id: 't',
        name: 't',
        type: WatermarkTemplateType.custom,
        createdAt: DateTime(2026, 8, 20),
        elements: elements,
        frame: WatermarkFrame(
          type: type,
          borderRatio: 0.1,
          bottomPlate: true,
          bottomRatio: 0.2,
          shadowOpacity: 0.0,
        ),
      );
    }

    test('无画框输出尺寸 = 原图', () async {
      final src = await makeImage(40, 30, 0xFFFFFFFF);
      final r = await WatermarkRenderer().render(sourceImage: src, template: _tpl(WatermarkFrameType.none));
      expect(r.width, 40);
      expect(r.height, 30);
      expect(r.rgbaBytes.length, 40 * 30 * 4);
    });

    test('拍立得输出 = 照片 + 左右白边 + 上下白边 + 底部白板', () async {
      final src = await makeImage(100, 80, 0xFFFFFFFF);
      final r = await WatermarkRenderer().render(sourceImage: src, template: _tpl(WatermarkFrameType.polaroid));
      // borderRatio=0.1 → pad=10；bottomRatio=0.2 → plate=16
      expect(r.width, 100 + 10 * 2);
      expect(r.height, 80 + 10 + 10 + 16);
      expect(r.rgbaBytes.length, r.width * r.height * 4);
    });

    test('内描边输出尺寸 = 原图', () async {
      final src = await makeImage(60, 60, 0xFFFFFFFF);
      final r = await WatermarkRenderer().render(sourceImage: src, template: _tpl(WatermarkFrameType.innerBorder));
      expect(r.width, 60);
      expect(r.height, 60);
    });

    test('拍立得底部白板关闭时不加高', () async {
      final src = await makeImage(100, 80, 0xFFFFFFFF);
      final t = WatermarkTemplate(
        id: 't', name: 't', type: WatermarkTemplateType.custom, createdAt: DateTime(2026, 8, 20),
        elements: const <WatermarkElement>[],
        frame: const WatermarkFrame(type: WatermarkFrameType.polaroid, borderRatio: 0.1, bottomPlate: false, shadowOpacity: 0.0),
      );
      final r = await WatermarkRenderer().render(sourceImage: src, template: t);
      expect(r.height, 80 + 10 + 10);
    });

    test('frame 空间元素可渲染（含白板日期）', () async {
      final src = await makeImage(100, 80, 0xFFFFFFFF);
      final t = WatermarkTemplate(
        id: 't', name: 't', type: WatermarkTemplateType.custom, createdAt: DateTime(2026, 8, 20),
        elements: [
          WatermarkElement(id: 'd', type: WatermarkElementType.text, text: '2026.08.20')
            ..space = WatermarkElementSpace.frame,
        ],
        frame: const WatermarkFrame(type: WatermarkFrameType.polaroid, borderRatio: 0.1, bottomPlate: true, bottomRatio: 0.2, shadowOpacity: 0.0),
      );
      final r = await WatermarkRenderer().render(sourceImage: src, template: t);
      expect(r.width, 120);
      expect(r.height, 116);
      expect(r.rgbaBytes.length, r.width * r.height * 4);
    });
  }
  ```
  > 若模型采用 `copyWith` 风格，`..space =` 改为 `copyWith(space: WatermarkElementSpace.frame)`（与 Task 2 一致）。

- [ ] **Step 2: 运行测试确认失败**

  Run: `flutter test test/features/watermark/watermark_renderer_test.dart`
  Expected: FAIL（`WatermarkRenderResult`/新 `render` 不存在）。

- [ ] **Step 3: 实现渲染器**

  用以下内容重写 `watermark_renderer.dart`（保持 `_withOpacity` 等既有辅助方法）：
  ```dart
  class WatermarkRenderResult {
    final Uint8List rgbaBytes;
    final int width;
    final int height;
    const WatermarkRenderResult({
      required this.rgbaBytes,
      required this.width,
      required this.height,
    });
  }

  class WatermarkRenderer {
    static const double _referenceWidth = 400.0;

    Future<WatermarkRenderResult> render({
      required ui.Image sourceImage,
      required WatermarkTemplate template,
    }) async {
      final photoW = sourceImage.width.toDouble();
      final photoH = sourceImage.height.toDouble();
      final frame = template.frame;
      final type = frame.type;
      final scale = photoW / _referenceWidth;

      // —— 画布尺寸 ——
      double padX = 0, padTop = 0, padBottom = 0;
      if (type == WatermarkFrameType.polaroid) {
        final pad = frame.borderRatio * photoW;
        padX = pad;
        padTop = pad;
        padBottom = pad + (frame.bottomPlate ? frame.bottomRatio * photoH : 0);
      }
      final shadow = (type == WatermarkFrameType.polaroid && frame.shadowOpacity > 0)
          ? (frame.shadowBlur * photoW).clamp(2.0, 60.0)
          : 0.0;
      final outputW = (photoW + padX * 2).round();
      final outputH = (photoH + padTop + padBottom + shadow).round();

      final cardRect = ui.Rect.fromLTWH(0, 0, photoW + padX * 2, photoH + padTop + padBottom);
      final photoOrigin = ui.Offset(padX, padTop);
      final photoRect = ui.Rect.fromLTWH(padX, padTop, photoW, photoH);
      final plateRect = (type == WatermarkFrameType.polaroid && frame.bottomPlate)
          ? ui.Rect.fromLTWH(padX, padTop + photoH, photoW, padBottom - padX)
          : photoRect;

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      // 投影（拍立得，仅底部）
      if (shadow > 0) {
        final paint = ui.Paint()
          ..color = frame.shadowColor.withValues(alpha: frame.shadowOpacity)
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, shadow);
        canvas.drawRect(
          ui.Rect.fromLTWH(0, cardRect.bottom, outputW.toDouble(), shadow * 1.4),
          paint,
        );
      }

      // 白卡（拍立得）/ 透明底（其余）
      if (type == WatermarkFrameType.polaroid) {
        final paint = ui.Paint()..color = frame.color;
        if (frame.borderRadius > 0) {
          canvas.drawRRect(
            ui.RRect.fromRectAndRadius(cardRect, ui.Radius.circular(frame.borderRadius * photoW)),
            paint,
          );
        } else {
          canvas.drawRect(cardRect, paint);
        }
      }

      // 照片
      canvas.drawImage(sourceImage, photoOrigin, ui.Paint());

      // 内描边
      if (type == WatermarkFrameType.innerBorder) {
        final stroke = frame.borderRatio * photoW;
        final paint = ui.Paint()
          ..color = frame.color
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = stroke;
        final inner = photoRect.deflate(stroke / 2);
        if (frame.borderRadius > 0) {
          canvas.drawRRect(
            ui.RRect.fromRectAndRadius(inner, ui.Radius.circular(frame.borderRadius * photoW)),
            paint,
          );
        } else {
          canvas.drawRect(inner, paint);
        }
      }

      // 元素
      for (final element in template.elements) {
        if (element.type == WatermarkElementType.image) continue;
        final base = element.space == WatermarkElementSpace.frame ? plateRect : photoRect;
        _drawTextElement(canvas, element, base, scale);
      }

      // 画布圆角裁剪（拍立得/内描边且 borderRadius>0）
      if (type != WatermarkFrameType.none && frame.borderRadius > 0) {
        final clipRect = ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(0, 0, outputW.toDouble(), outputH.toDouble()),
          ui.Radius.circular(frame.borderRadius * photoW),
        );
        canvas.clipRRect(clipRect);
      }

      final picture = recorder.endRecording();
      final outputImage = await picture.toImage(outputW, outputH);
      final byteData = await outputImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      outputImage.dispose();
      if (byteData == null) throw StateError('WatermarkRenderer: failed to encode output image');
      return WatermarkRenderResult(
        rgbaBytes: byteData.buffer.asUint8List(),
        width: outputW,
        height: outputH,
      );
    }

    void _drawTextElement(
      ui.Canvas canvas,
      WatermarkElement element,
      ui.Rect base, // 坐标空间基准矩形
      double scale,
    ) {
      final absoluteFontSize = element.fontSize * base.width;
      final blurRadius = (absoluteFontSize * 0.08).clamp(0.5, 8.0);
      // 段落构建（沿用原实现，见 Step 3 说明）
      // anchorX = element.x * base.width + base.left
      // anchorY = element.y * base.height + base.top
      // 其余（对齐偏移、旋转、drawParagraph）与现有实现一致
    }
  }
  ```
  `_drawTextElement` 从"图像尺寸"改为"基准矩形 `base`"：
  - 字号：`element.fontSize * base.width`
  - 锚点：`anchorX = element.x * base.width + base.left`、`anchorY = element.y * base.height + base.top`
  - 对齐偏移逻辑、`letterSpacing * scale`、旋转、阴影保持原样（原实现见文件 67-142 行）。

- [ ] **Step 4: 修正拍照管线调用点**

  `capture_page.dart` 670-688 行改为：
  ```dart
  final renderer = ref.read(watermarkRendererProvider);
  final wmResult = await renderer.render(
    sourceImage: sourceImage,
    template: watermarkTemplate,
  );

  final outputImage = img.Image.fromBytes(
    width: wmResult.width,
    height: wmResult.height,
    bytes: wmResult.rgbaBytes.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  final jpegBytes = img.encodeJpg(outputImage, quality: 90);
  ```

- [ ] **Step 5: 运行测试确认通过**

  Run: `flutter test test/features/watermark/watermark_renderer_test.dart`
  Expected: PASS。

- [ ] **Step 6: 全仓编译校验**

  Run: `flutter analyze`
  Expected: 无 error（确认渲染器新签名已被所有调用点适配）。

- [ ] **Step 7: Commit**

  ```bash
  git add lumira_app_flutter/lib/features/watermark/services lumira_app_flutter/lib/features/capture/pages/capture_page.dart lumira_app_flutter/test/features/watermark
  git commit -m "feat(watermark): renderer supports frames and coordinate spaces; fix capture pipeline size"
  ```

---

### Task 4: 预设更新（新增「拍立得」）

**Files:**
- Modify: `lumira_app_flutter/lib/features/watermark/data/preset_watermarks.dart`
- Test: `lumira_app_flutter/test/features/watermark/preset_watermarks_test.dart`（新建）

**Interfaces:**
- Consumes: `WatermarkFrame`/`WatermarkElementSpace`（Task 2）。
- Produces: `getPresetWatermarks()` 返回 6 款，新增 id=`preset_polaroid`（拍立得，frame=polaroid，日期元素 space=frame）。

- [ ] **Step 1: 写失败测试**

  新建 `test/features/watermark/preset_watermarks_test.dart`：
  ```dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:lumira_app/features/watermark/data/preset_watermarks.dart';
  import 'package:lumira_app/features/watermark/models/watermark_template.dart';

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

- [ ] **Step 2: 运行测试确认失败**

  Run: `flutter test test/features/watermark/preset_watermarks_test.dart`
  Expected: FAIL（`preset_polaroid` 不存在 / length 不是 6）。

- [ ] **Step 3: 实现拍立得预设**

  在 `preset_watermarks.dart` 的 `getPresetWatermarks()` 列表末尾追加 `_polaroid()`，并新增函数：
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
  需在文件头确认已有 `Color` 导入（`package:flutter/painting.dart` 或 `dart:ui`）。现有预设的 `elements` 均用默认 `space`（photo），无需改动；若 5 款坐标/字号与可视化对照有偏差可在此步微调，但**必须保持测试断言成立**。

- [ ] **Step 4: 运行测试确认通过**

  Run: `flutter test test/features/watermark/preset_watermarks_test.dart`
  Expected: PASS。

- [ ] **Step 5: Commit**

  ```bash
  git add lumira_app_flutter/lib/features/watermark/data/preset_watermarks.dart lumira_app_flutter/test/features/watermark
  git commit -m "feat(watermark): add polaroid preset with frame-space date"
  ```

---

### Task 5: 管理页重做（单列/双列切换 + 持久化 + 真实预览）

**Files:**
- Create: `lumira_app_flutter/assets/images/watermark_sample.jpg`（真实示例照片，用于预览底图）
- Modify: `lumira_app_flutter/lib/features/watermark/widgets/watermark_preview.dart`
- Modify: `lumira_app_flutter/lib/features/watermark/pages/watermark_manage_page.dart`（重写）
- Modify: `lumira_app_flutter/lib/features/watermark/data/watermark_providers.dart`（管理页布局读写辅助）
- Test: `lumira_app_flutter/test/features/watermark/watermark_manage_page_test.dart`（新建）

**Interfaces:**
- Consumes: `WatermarkSettings.manageLayout`（Task 2）、`WatermarkTemplate`、`scheduleWatermarkPersist`/`watermarkSettingsProvider`/`customWatermarksProvider`（既有）。
- Produces:
  - `WatermarkManagePage` 顶部右上角「≡ / ▦」切换按钮 +「＋新建」；单列卡片 / 双列网格两种布局；点卡片选中；自定义模板可编辑/复制/删除；预设只读。
  - `WatermarkPreview(template: ...)` 基于真实照片（示例图或传入底图）渲染叠加预览。

- [ ] **Step 1: 生成示例照片资源**

  使用图像生成能力创建一张普通生活/风景照片，保存到 `lumira_app_flutter/assets/images/watermark_sample.jpg`（3:4 竖构图，色彩柔和不抢水印主体，供水印叠加展示）。

- [ ] **Step 2: 实现布局切换持久化辅助**

  在 `watermark_providers.dart` 增加：
  ```dart
  /// 切换管理页布局并持久化（list/grid）。
  void setWatermarkManageLayout(ProviderContainer container, WatermarkManageLayout layout) {
    container.read(watermarkSettingsProvider.notifier).update((s) => s.copyWith(manageLayout: layout));
    scheduleWatermarkPersist(container);
  }
  ```
  顶部补 import `../models/watermark_settings.dart`（`WatermarkManageLayout`）。

- [ ] **Step 3: 重写管理页**

  `watermark_manage_page.dart` 实现要点（遵循 Global Constraints 主题规范）：
  - 顶部导航：左侧返回 + 标题「水印管理」；右侧 `LumiraIconButton`（≡ 单列 / ▦ 双列，当前布局高亮）+「＋新建」。
  - 布局源：`ref.watch(watermarkSettingsProvider).manageLayout`；切换调用 `setWatermarkManageLayout`。
  - 数据源：`presetWatermarksProvider` + `customWatermarksProvider` 合并展示；选中态来自 `watermarkSettingsProvider.activeTemplateId`。
  - **单列卡片**：每张横向卡片 = 左侧 `WatermarkPreview` 缩略（套模板效果的真实照片预览）+ 名称 + 类型标签（预置/自定义）+ 右侧 选中✓/编辑✎。
  - **双列网格**：2 列卡片 = `WatermarkPreview` 缩略 + 名称 + 选中/编辑标记，选中态用主题色描边。
  - 交互：点卡片 → `setWatermarkActive(container, id)`（既有，更新 settings + 持久化 + 返回上一页）；编辑 → 编辑器（模板模式）；自定义模板左滑或按钮删除（经 watermarkDao）；复制 → 以 `_copy` 后缀生成新自定义模板；「＋新建」→ 空模板进编辑器。
  - 删除/复制/选中逻辑若既有 `WatermarkManagePage` 已有实现，优先沿用并套用新布局。
  - 所有卡片、按钮、描边颜色均来自 `appThemeProvider`/`uiStyleProvider`。

  `watermark_preview.dart` 改造为照片底预览：
  - 入参 `WatermarkTemplate template` + 可选 `ImageProvider? background`（默认 `AssetImage('assets/images/watermark_sample.jpg')`）。
  - 用 `CustomPaint` 在照片底上按模板叠加元素（复用渲染算法的小尺寸封装，或直接用 `Stack` + 定位近似呈现）；实现方式以"预览观感真实"为目标。

- [ ] **Step 4: 写管理页 widget 测试**

  `test/features/watermark/watermark_manage_page_test.dart`（沿用项目现有 page 测试模式：`ProviderScope` + 内存 DB override + 预置 provider override）：
  ```dart
  // 覆盖点：
  // - 默认显示单列卡片（find 到「简约日期」等预设卡片）
  // - 点击 ▦ 切换后显示双列网格卡片
  // - 切换后 WatermarkSettings.manageLayout == grid（且已写 settingsDao）
  // - 点击卡片后 activeTemplateId 更新
  ```
  参考既有页测（如 `test/features/gallery/gallery_detail_page_test.dart`、`test/core/db/dao/settings_dao_test.dart`）初始化内存 DB 与 provider。

- [ ] **Step 5: 运行测试确认通过**

  Run: `flutter test test/features/watermark/watermark_manage_page_test.dart`
  Expected: PASS。

- [ ] **Step 6: analyze + Commit**

  Run: `flutter analyze`
  Expected: 无 error。

  ```bash
  git add lumira_app_flutter/lib/features/watermark lumira_app_flutter/assets/images/watermark_sample.jpg lumira_app_flutter/test/features/watermark
  git commit -m "feat(watermark): redesign manage page with list/grid toggle and photo preview"
  ```

---

### Task 6: 编辑器重做（全屏沉浸 + 底部可收起操作栏 + 三 Tab + 手势 + 双模式）

**Files:**
- Modify: `lumira_app_flutter/lib/features/watermark/pages/watermark_editor_page.dart`（重写）
- Test: `lumira_app_flutter/test/features/watermark/watermark_editor_page_test.dart`（新建）

**Interfaces:**
- Consumes: `WatermarkTemplate`/`WatermarkFrame`（Task 2）、渲染器（Task 3）、`watermark_sample.jpg`（Task 5）、`WatermarkDao`、`scheduleWatermarkPersist`。
- Produces:
  - `WatermarkEditorPage({String? templateId, String? photoPath})`——`templateId` 为空且管理页进入时新建空白模板；`photoPath` 非空 = 应用模式（相册二次添加）。
  - 保存行为：模板模式 → 写 DAO + 刷新 provider；应用模式 → 渲染到真实照片 → 复用既有 `SaveMode` sheet（`lumira_save_mode_sheet.dart`）另存新照片。
  - 底部操作栏三段 Tab：元素 / 样式 / 边框；手势：点选、单指拖拽移动、双指捏合缩放。

- [ ] **Step 1: 写关键 widget 测试**

  `test/features/watermark/watermark_editor_page_test.dart`（沿用现有 page 测试模式）：
  ```dart
  // 覆盖点：
  // - 渲染编辑页（模板模式）不崩溃，预览区存在
  // - 底部操作栏默认展开态：存在「元素」「样式」「边框」三个 Tab
  // - 点击「收起」后操作栏折叠为细条（仍可点开）
  // - 元素 Tab：点「＋文本」新增一个元素；选中后可删除
  // - 边框 Tab：切到「拍立得」后模板 frame.type == polaroid
  // - 样式 Tab：切换「照片/白边」后选中元素 space 更新
  ```
- [ ] **Step 2: 运行测试确认失败**

  Run: `flutter test test/features/watermark/watermark_editor_page_test.dart`
  Expected: FAIL（页面重写后行为尚不存在）。

- [ ] **Step 3: 实现编辑器**

  `watermark_editor_page.dart` 实现要点：
  - **状态**：`_template`（副本）、`_selectedElementId`、`_expanded`（操作栏展开/折叠，默认展开）、`_tab`（元素/样式/边框）。
  - **顶部导航**：`‹ 取消`（丢弃返回）、标题、`保存`（模板模式）/`保存并应用`（应用模式）。
  - **预览区（铁律）**：
    - 背景 = `photoPath` 真实照片（应用模式）或 `watermark_sample.jpg`（模板模式）。
    - `LayoutBuilder` 计算可用高度 = 屏高 − 顶部导航 − 操作栏高度（展开/折叠动态）。
    - 照片 `Image.file`/`AssetImage` + `BoxFit.contain`（**等比适配，宽高比不变，全貌可见**）；周围 `Colors.black` 留白（合法例外：叠照遮罩）。
    - 元素叠加层：`Stack` + `Positioned`，按 `space`（photo→照片显示矩形；frame→白板矩形）换算像素坐标；元素用 `GestureDetector` 实现点选/拖拽，`onScaleStart/Update` 实现双指缩放（改 fontSize）。
  - **底部操作栏**（锚定，`AnimatedSize` 平滑展开折叠）：
    - 折叠态：34px 细条 +「展开操作栏 ⌃」。
    - 展开态：三段 Tab（元素/样式/边框）+ 参数区。
    - 作为叠在照片上的浮层：颜色/圆角/阴影按当前风格从 `appThemeProvider`/`uiStyleProvider` 取（新拟态下实心 surface + 细边、无外阴影）。
  - **元素 Tab**：元素 chip 列表（可点选）、「＋文本」「＋日期」、选中元素「复制」「删除」。
  - **样式 Tab**（选中元素）：文本输入（text 类型）、字号/透明度/旋转/字间距滑杆、颜色色板（主题色板+白/黑）、粗体/斜体/对齐、「照片/白边」segmented（白边仅 frame=polaroid 且 bottomPlate 时可选，默认照片）。
  - **边框 Tab**：画框类型 segmented（无/拍立得/内描边）；拍立得 → 厚度滑杆、白板开关+比例滑杆、圆角滑杆、投影开关/强度；内描边 → 颜色、厚度、圆角。
  - **保存（模板模式）**：写 `watermarkDao.upsert` + 刷新 `customWatermarksProvider` + 更新 `activeTemplateId`（沿用既有编辑页保存逻辑）。
  - **保存并应用（应用模式）**：`ui.decodeImageFromList(photoBytes)` → `renderer.render` → 编码 JPEG → 复用 `SaveMode` sheet 与画廊保存管线另存新照片；完成后返回相册并刷新画廊列表。

- [ ] **Step 4: 运行测试确认通过**

  Run: `flutter test test/features/watermark/watermark_editor_page_test.dart`
  Expected: PASS。

- [ ] **Step 5: analyze + Commit**

  Run: `flutter analyze`
  Expected: 无 error。

  ```bash
  git add lumira_app_flutter/lib/features/watermark/pages/watermark_editor_page.dart lumira_app_flutter/test/features/watermark
  git commit -m "feat(watermark): immersive editor with collapsible bottom panel and gestures"
  ```

---

### Task 7: 相册二次添加水印

**Files:**
- Modify: `lumira_app_flutter/lib/features/gallery/pages/gallery_detail_page.dart`（`_MoreAction` 菜单新增「添加水印」）
- Modify: `lumira_app_flutter/lib/app/router.dart`（新增路由或复用编辑路由带 photoPath 参数）
- Modify: `lumira_app_flutter/lib/core/router/route_names.dart`（新增路由常量，如 `galleryWatermarkApply`）
- Test: `lumira_app_flutter/test/features/gallery/gallery_detail_page_more_action_test.dart`（新建，或在既有 gallery_detail 测试中追加）

**Interfaces:**
- Consumes: `WatermarkEditorPage(photoPath: ...)`（Task 6）、`currentWatermarkTemplateProvider`。
- Produces: 相册详情「更多」弹层出现「添加水印」；点击进入应用模式编辑器；保存后另存新照片入相册。

- [ ] **Step 1: 写测试**

  在 `test/features/gallery/gallery_detail_page_more_action_test.dart`（或既有 gallery detail 测试中追加）：
  ```dart
  // 覆盖点：
  // - 打开「更多」菜单 → 出现「添加水印」项
  // - 点击「添加水印」→ 路由跳转至编辑器（可断言路由名/页面出现）
  ```
- [ ] **Step 2: 运行测试确认失败**

  Run: `flutter test test/features/gallery/gallery_detail_page_more_action_test.dart`
  Expected: FAIL（菜单项不存在）。

- [ ] **Step 3: 实现**

  - `route_names.dart`：新增 `static const String galleryWatermarkApply = '/gallery/watermark/apply';`（或复用编辑路由并追加 query `photoPath`，按路由现有风格实现，避免路径含文件路径导致的编码问题）。
  - `router.dart`：注册 `galleryWatermarkApply` → `WatermarkEditorPage(photoPath: state.uri.queryParameters['photo'], templateId: state.uri.queryParameters['templateId'])`。
  - `gallery_detail_page.dart` `_MoreAction`：在选项列表新增「添加水印」项（`LumiraIconButton`/菜单项，图标用 Phosphor 风格 `image-watermark` 或既有图标库），点击 → 取当前照片路径 + `currentWatermarkTemplateProvider` 的 templateId → `context.push(RouteNames.galleryWatermarkApply)`；应用模式保存后 `ref.refresh` 画廊列表 provider。

- [ ] **Step 4: 运行测试确认通过**

  Run: `flutter test test/features/gallery/gallery_detail_page_more_action_test.dart`
  Expected: PASS。

- [ ] **Step 5: analyze + Commit**

  Run: `flutter analyze`
  Expected: 无 error。

  ```bash
  git add lumira_app_flutter/lib/features/gallery lumira_app_flutter/lib/app/router.dart lumira_app_flutter/lib/core/router/route_names.dart lumira_app_flutter/test
  git commit -m "feat(watermark): add watermark to existing photos from gallery detail"
  ```

---

### Task 8: 全量回归与收尾

**Files:**
- 无新增/修改（仅在需要时修复回归）。

**Interfaces:**
- Consumes: 全部先前任务。

- [ ] **Step 1: 全量 analyze**

  Run: `flutter analyze`
  Expected: 0 error / 0 warning（本项目基线要求）。

- [ ] **Step 2: 全量测试**

  Run: `flutter test`
  Expected: 全部 PASS（含既有 269 个用例 + 新增 watermark 用例；基线中既有 1 个与本功能无关的失败用例除外，需在报告中说明）。

- [ ] **Step 3: 手工冒烟（若可运行）**

  若环境支持，`flutter run` 验证：管理页单列/双列切换与持久化、拍立得预览、编辑器展开/折叠与三 Tab、拍照加水印、相册详情「添加水印」→ 保存新照片。

- [ ] **Step 4: 修复回归（如有）并 Commit**

  ```bash
  git add -A
  git commit -m "chore(watermark): regression fixes after full test run"
  ```

---

## Self-Review（编写者自查）

- **Spec 覆盖**：
  - 模块化（设计第二章）→ Task 1 ✓
  - 数据模型扩展（设计第三章）→ Task 2 ✓
  - 渲染器扩展（设计第四章 + 尺寸返回）→ Task 3 ✓
  - 预设/拍立得（设计第八章）→ Task 4 ✓
  - 管理页单列/双列 + 持久化 + 真实预览（设计第六章）→ Task 5 ✓
  - 编辑器方案 H + 三 Tab + 手势 + 双模式（设计第五章）→ Task 6 ✓
  - 相册二次添加（设计第七章）→ Task 7 ✓
  - 拍照管线尺寸修正（设计 4.3 风险项）→ Task 3 Step 4 ✓
- **Placeholder 扫描**：核心逻辑（模型/渲染器/预设/设置）均给出完整代码；UI 重写任务给出明确结构、交互、测试与关键算法，未留 "TBD/TODO"。
- **类型一致性**：`WatermarkRenderResult` 在 Task 3 定义并在 Task 3 Step 4 与 Task 6 使用一致；`WatermarkElementSpace`/`WatermarkFrameType`/`WatermarkManageLayout` 在 Task 2 定义、Task 3/4/5/6 引用一致；`WatermarkEditorPage({templateId, photoPath})` 在 Task 6 定义、Task 7 按该签名调用一致。
