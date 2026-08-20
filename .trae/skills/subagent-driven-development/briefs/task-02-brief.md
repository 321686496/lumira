# Task 2: 数据模型扩展（WatermarkFrame + space + manageLayout）

**Files:**
- Modify: `lumira_app_flutter/lib/features/watermark/models/watermark_template.dart`
- Modify: `lumira_app_flutter/lib/features/watermark/models/watermark_settings.dart`
- Test: `lumira_app_flutter/test/features/watermark/watermark_model_test.dart`（新建）

**Interfaces:**
- Consumes: 现有 `WatermarkElement`/`WatermarkTemplate`/`WatermarkSettings`（见下方"现有代码结构"）。
- Produces:
  - `enum WatermarkFrameType { none, polaroid, innerBorder }`
  - `class WatermarkFrame`（`type`/`color`/`borderRatio`/`borderRadius`/`bottomPlate`/`bottomRatio`/`shadowColor`/`shadowOpacity`/`shadowBlur` + `copyWith`/`toJson`/`fromJson`）
  - `enum WatermarkElementSpace { photo, frame }`；`WatermarkElement.space` 默认 `photo`
  - `WatermarkTemplate.frame` 默认 `const WatermarkFrame()`
  - `enum WatermarkManageLayout { list, grid }`；`WatermarkSettings.manageLayout` 默认 `list`

## 现有代码结构（重要，决定实现风格）

`watermark_template.dart` 当前结构：
- `WatermarkElement`：**所有字段 final**，有 `copyWith({...})`、`toJson()`、`fromJson()`，内部用 `_parseElementType`/`_parseTextAlign` 静态方法解析枚举。**注意：没有 `..space =` 这种可变写法，新增 space 字段必须走 copyWith。**
- `WatermarkTemplate`：字段 `id`/`name`/`type`/`elements`/`createdAt`，**无 copyWith**，有 `toJson()`/`fromJson()`，`fromJson` 用 `_parseTemplateType`。

`watermark_settings.dart` 当前结构：
- `WatermarkSettings`：字段 `enabled`/`activeTemplateId`/`animationEnabled`（全 final，const 构造），有 `copyWith`、`toJson`、`fromJson`。

## 测试说明（重要）

计划中的测试草案使用了 `..space = WatermarkElementSpace.frame` 可变写法，但现有 `WatermarkElement` 是 final 字段 + copyWith 风格。**实现必须与现有 copyWith 风格保持一致**，测试相应改为 `e.copyWith(space: WatermarkElementSpace.frame)`。

## Global Constraints

- **Dart 版本**：Dart 2.19.6 / Flutter 3.7.12，禁止 Dart 3 records 语法。
- **序列化兼容**：V1 已存模板 JSON 缺省 `space`/`frame` 字段时必须回退（space=photo、frame=none）。
- 测试：`flutter test test/features/watermark/watermark_model_test.dart` 定向测试；提交前本任务相关测试全绿。

---

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
            .copyWith(space: WatermarkElementSpace.frame);
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
  - 字段：`WatermarkElementSpace space;` 默认 `WatermarkElementSpace.photo`
  - 构造参数新增：`this.space = WatermarkElementSpace.photo,`
  - `copyWith` 新增参数 `WatermarkElementSpace? space,` 与赋值 `space: space ?? this.space,`
  - `toJson` 新增 `'space': space.name,`
  - `fromJson` 新增：`space: _parseSpace(json['space'] as String?),`
  - 新增静态方法：
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
  - 字段：`WatermarkFrame frame;`
  - 构造参数：`this.frame = const WatermarkFrame(),`
  - `toJson` 新增 `'frame': frame.toJson(),`
  - `fromJson`：`frame: json['frame'] != null ? WatermarkFrame.fromJson(json['frame'] as Map<String, dynamic>) : const WatermarkFrame(),`

  `watermark_settings.dart` 新增：
  ```dart
  /// 水印管理页布局：list（单列）/ grid（双列）
  enum WatermarkManageLayout { list, grid }
  ```
  `WatermarkSettings`：
  - 字段：`final WatermarkManageLayout manageLayout;` 默认 `WatermarkManageLayout.list`（构造参数 `this.manageLayout = WatermarkManageLayout.list,`）
  - `copyWith` 新增 `WatermarkManageLayout? manageLayout,` 与赋值
  - `toJson` 新增 `'manageLayout': manageLayout.name,`
  - `fromJson`：`manageLayout: _parseLayout(json['manageLayout'] as String?),`
  - 新增：
  ```dart
  static WatermarkManageLayout _parseLayout(String? value) {
    switch (value) {
      case 'grid':
        return WatermarkManageLayout.grid;
      case 'list':
      default:
        return WatermarkManageLayout.list;
    }
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
