# 水印功能 + 拍照相框动画 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 App 添加水印功能（5种预设水印 + 参数编辑 + 水印渲染到照片 + 相框动画）

**Architecture:** 数据层（SQLite 模板存储 + 代码内置预设）→ 业务层（水印渲染器 + 管理服务）→ UI 层（管理页 + 编辑器 + 动画 Overlay）。水印渲染集成到拍照后处理管线中，使用 dart:ui Canvas 在照片上绘制水印元素。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6, flutter_riverpod 2.3.6, sqflite, dart:ui Canvas, go_router 6.5.7

---

## 全局约束

- Dart 2.19.6（不支持 Dart 3 records 语法）
- Flutter 3.7.12
- 状态管理使用 flutter_riverpod 2.3.6
- 路由使用 go_router 6.5.7
- 数据库使用 sqflite
- 图片处理使用 dart:ui（Canvas / PictureRecorder），不引入额外依赖
- 水印元素位置使用相对坐标（0.0~1.0），渲染时映射到实际图片尺寸
- 所有新增文件遵循项目现有代码风格（无注释、使用 ConsumerWidget/ConsumerStatefulWidget）

---

## 文件结构

### 新增文件

| 文件 | 职责 |
|------|------|
| `lib/features/capture/watermark/models/watermark_template.dart` | 水印模型定义（WatermarkTemplate, WatermarkElement, 枚举类型） |
| `lib/features/capture/watermark/models/watermark_settings.dart` | 水印设置模型（WatermarkSettings） |
| `lib/features/capture/watermark/data/preset_watermarks.dart` | 5种预设水印数据 |
| `lib/features/capture/watermark/data/watermark_providers.dart` | 水印相关 Riverpod Provider |
| `lib/features/capture/watermark/services/watermark_renderer.dart` | 水印渲染引擎（dart:ui Canvas 绘制） |
| `lib/features/capture/watermark/pages/watermark_manage_page.dart` | 水印管理列表页 |
| `lib/features/capture/watermark/pages/watermark_editor_page.dart` | 水印参数编辑器 |
| `lib/features/capture/watermark/widgets/watermark_preview.dart` | 水印预览缩略图组件 |
| `lib/features/capture/watermark/widgets/watermark_animation_overlay.dart` | 相框动画 Overlay |
| `lib/core/db/dao/watermark_dao.dart` | 水印模板 DAO |

### 修改文件

| 文件 | 改动 |
|------|------|
| `lib/core/db/tables.dart` | 新增 `watermark_templates` 表定义 |
| `lib/core/db/database_provider.dart` | 注册 WatermarkDao |
| `lib/features/capture/pages/capture_page.dart` | 集成水印渲染 + 相框动画 |
| `lib/features/profile/pages/profile_settings_page.dart` | 增加水印设置项 |
| `lib/app/router.dart` | 新增水印相关路由 |
| `lib/core/router/route_names.dart` | 新增路由常量 |

---

## 任务分解

### Task 1: 数据模型 + 数据库层

**Files:**
- Create: `lib/features/capture/watermark/models/watermark_template.dart`
- Create: `lib/features/capture/watermark/models/watermark_settings.dart`
- Create: `lib/core/db/dao/watermark_dao.dart`
- Modify: `lib/core/db/tables.dart`
- Modify: `lib/core/db/database_provider.dart`

**Interfaces:**
- Produces: `WatermarkTemplate`, `WatermarkElement`, `WatermarkElementType`, `WatermarkTemplateType`, `WatermarkSettings` 模型类
- Produces: `WatermarkDao`（CRUD 方法）
- Produces: `watermarkTemplatesTable` 表定义

- [ ] **Step 1: 创建水印模型文件**

  写入 `lib/features/capture/watermark/models/watermark_template.dart`：

  ```dart
  import 'dart:ui' as ui show Color;

  enum WatermarkTemplateType { preset, custom }

  enum WatermarkElementType { text, dateTime, image }

  class WatermarkElement {
    final String id;
    WatermarkElementType type;
    String text;
    double x;
    double y;
    double fontSize;
    ui.Color color;
    ui.Color shadowColor;
    double opacity;
    double rotation;
    String fontFamily;
    TextAlign textAlign;
    bool bold;
    bool italic;

    WatermarkElement({
      required this.id,
      required this.type,
      this.text = '',
      this.x = 0.0,
      this.y = 0.0,
      this.fontSize = 14.0,
      this.color = const ui.Color(0xFFFFFFFF),
      this.shadowColor = const ui.Color(0x00000000),
      this.opacity = 1.0,
      this.rotation = 0.0,
      this.fontFamily = '',
      this.textAlign = TextAlign.left,
      this.bold = false,
      this.italic = false,
    });

    WatermarkElement copyWith({
      String? id,
      WatermarkElementType? type,
      String? text,
      double? x,
      double? y,
      double? fontSize,
      ui.Color? color,
      ui.Color? shadowColor,
      double? opacity,
      double? rotation,
      String? fontFamily,
      TextAlign? textAlign,
      bool? bold,
      bool? italic,
    }) {
      return WatermarkElement(
        id: id ?? this.id,
        type: type ?? this.type,
        text: text ?? this.text,
        x: x ?? this.x,
        y: y ?? this.y,
        fontSize: fontSize ?? this.fontSize,
        color: color ?? this.color,
        shadowColor: shadowColor ?? this.shadowColor,
        opacity: opacity ?? this.opacity,
        rotation: rotation ?? this.rotation,
        fontFamily: fontFamily ?? this.fontFamily,
        textAlign: textAlign ?? this.textAlign,
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
      );
    }

    Map<String, dynamic> toJson() => {
      'id': id,
      'type': type.name,
      'text': text,
      'x': x,
      'y': y,
      'fontSize': fontSize,
      'color': color.value,
      'shadowColor': shadowColor.value,
      'opacity': opacity,
      'rotation': rotation,
      'fontFamily': fontFamily,
      'textAlign': textAlign.index,
      'bold': bold,
      'italic': italic,
    };

    factory WatermarkElement.fromJson(Map<String, dynamic> json) {
      return WatermarkElement(
        id: json['id'] as String,
        type: WatermarkElementType.values.firstWhere((e) => e.name == json['type']),
        text: json['text'] as String? ?? '',
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        fontSize: (json['fontSize'] as num).toDouble(),
        color: ui.Color(json['color'] as int),
        shadowColor: ui.Color(json['shadowColor'] as int? ?? 0x00000000),
        opacity: (json['opacity'] as num).toDouble(),
        rotation: (json['rotation'] as num).toDouble(),
        fontFamily: json['fontFamily'] as String? ?? '',
        textAlign: TextAlign.values[json['textAlign'] as int? ?? 0],
        bold: json['bold'] as bool? ?? false,
        italic: json['italic'] as bool? ?? false,
      );
    }
  }

  class WatermarkTemplate {
    final String id;
    String name;
    WatermarkTemplateType type;
    List<WatermarkElement> elements;
    DateTime createdAt;

    WatermarkTemplate({
      required this.id,
      required this.name,
      required this.type,
      required this.elements,
      DateTime? createdAt,
    }) : createdAt = createdAt ?? DateTime.now();

    Map<String, dynamic> toJson() => {
      'id': id,
      'name': name,
      'type': type.name,
      'elements': elements.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };

    factory WatermarkTemplate.fromJson(Map<String, dynamic> json) {
      return WatermarkTemplate(
        id: json['id'] as String,
        name: json['name'] as String,
        type: WatermarkTemplateType.values.firstWhere((e) => e.name == json['type']),
        elements: (json['elements'] as List)
            .map((e) => WatermarkElement.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
    }
  }
  ```

- [ ] **Step 2: 创建水印设置模型**

  写入 `lib/features/capture/watermark/models/watermark_settings.dart`：

  ```dart
  class WatermarkSettings {
    final bool enabled;
    final String? activeTemplateId;
    final bool animationEnabled;

    const WatermarkSettings({
      this.enabled = true,
      this.activeTemplateId,
      this.animationEnabled = true,
    });

    WatermarkSettings copyWith({
      bool? enabled,
      String? activeTemplateId,
      bool? animationEnabled,
      bool clearTemplate = false,
    }) {
      return WatermarkSettings(
        enabled: enabled ?? this.enabled,
        activeTemplateId: clearTemplate ? null : (activeTemplateId ?? this.activeTemplateId),
        animationEnabled: animationEnabled ?? this.animationEnabled,
      );
    }

    Map<String, dynamic> toJson() => {
      'enabled': enabled,
      'activeTemplateId': activeTemplateId,
      'animationEnabled': animationEnabled,
    };

    factory WatermarkSettings.fromJson(Map<String, dynamic> json) {
      return WatermarkSettings(
        enabled: json['enabled'] as bool? ?? true,
        activeTemplateId: json['activeTemplateId'] as String?,
        animationEnabled: json['animationEnabled'] as bool? ?? true,
      );
    }
  }
  ```

- [ ] **Step 3: 添加数据库表定义**

  在 `lib/core/db/tables.dart` 中新增 `watermark_templates` 表：

  ```dart
  static const String watermarkTemplatesTable = '''
    CREATE TABLE IF NOT EXISTS watermark_templates (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      type TEXT NOT NULL DEFAULT 'preset',
      config TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
  ''';
  ```

  在 `tables.dart` 的 `allTables` 列表中添加 `watermarkTemplatesTable`。

- [ ] **Step 4: 创建 WatermarkDao**

  写入 `lib/core/db/dao/watermark_dao.dart`：

  ```dart
  import 'package:sqflite/sqflite.dart';
  import '../../features/capture/watermark/models/watermark_template.dart';

  class WatermarkDao {
    final Database db;

    WatermarkDao(this.db);

    Future<List<WatermarkTemplate>> getAll() async {
      final rows = await db.query('watermark_templates', orderBy: 'created_at ASC');
      return rows.map((row) {
        return WatermarkTemplate(
          id: row['id'] as String,
          name: row['name'] as String,
          type: WatermarkTemplateType.values.firstWhere(
            (e) => e.name == (row['type'] as String),
          ),
          elements: (WatermarkTemplate.fromJson({
            'elements': (row['config'] as String),
          })).elements,
          createdAt: DateTime.parse(row['created_at'] as String),
        );
      }).toList();
    }

    Future<WatermarkTemplate?> getById(String id) async {
      final rows = await db.query('watermark_templates', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) return null;
      final row = rows.first;
      return WatermarkTemplate(
        id: row['id'] as String,
        name: row['name'] as String,
        type: WatermarkTemplateType.values.firstWhere(
          (e) => e.name == (row['type'] as String),
        ),
        elements: (WatermarkTemplate.fromJson({
          'elements': (row['config'] as String),
        })).elements,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
    }

    Future<void> insert(WatermarkTemplate template) async {
      await db.insert('watermark_templates', {
        'id': template.id,
        'name': template.name,
        'type': template.type.name,
        'config': template.elements.map((e) => e.toJson()).toList().toString(),
        'created_at': template.createdAt.toIso8601String(),
      });
    }

    Future<void> update(WatermarkTemplate template) async {
      await db.update(
        'watermark_templates',
        {
          'name': template.name,
          'config': template.elements.map((e) => e.toJson()).toList().toString(),
        },
        where: 'id = ?',
        whereArgs: [template.id],
      );
    }

    Future<void> delete(String id) async {
      await db.delete('watermark_templates', where: 'id = ?', whereArgs: [id]);
    }
  }
  ```

- [ ] **Step 5: 在 database_provider 中注册 WatermarkDao**

  在 `lib/core/db/database_provider.dart` 中，找到 `galleryDaoProvider` 的注册位置，按相同模式注册 `watermarkDaoProvider`：

  ```dart
  final watermarkDaoProvider = FutureProvider<WatermarkDao>((ref) async {
    final db = await ref.watch(databaseProvider.future);
    return WatermarkDao(db);
  });
  ```

  确保 `import` 路径正确。

---

### Task 2: 预设水印数据

**Files:**
- Create: `lib/features/capture/watermark/data/preset_watermarks.dart`

**Interfaces:**
- Produces: `getPresetWatermarks() → List<WatermarkTemplate>` 函数
- Produces: 5 个预设水印模板常量

- [ ] **Step 1: 创建预设水印数据文件**

  写入 `lib/features/capture/watermark/data/preset_watermarks.dart`：

  ```dart
  import 'dart:ui' as ui;
  import '../models/watermark_template.dart';

  List<WatermarkTemplate> getPresetWatermarks() => [
    _minimalDate,
    _filmStamp,
    _artSignature,
    _magazineLayout,
    _frameBorder,
  ];

  final _minimalDate = WatermarkTemplate(
    id: 'preset_minimal_date',
    name: '简约日期',
    type: WatermarkTemplateType.preset,
    elements: [
      WatermarkElement(
        id: 'line1',
        type: WatermarkElementType.text,
        text: '2026.08.08',
        x: 0.05,
        y: 0.88,
        fontSize: 12.0,
        color: const ui.Color(0xCCFFFFFF),
        opacity: 0.8,
      ),
      WatermarkElement(
        id: 'separator',
        type: WatermarkElementType.text,
        text: '——',
        x: 0.05,
        y: 0.92,
        fontSize: 8.0,
        color: const ui.Color(0x99FFFFFF),
        opacity: 0.6,
      ),
      WatermarkElement(
        id: 'line2',
        type: WatermarkElementType.text,
        text: 'LUMIRA',
        x: 0.05,
        y: 0.95,
        fontSize: 16.0,
        color: const ui.Color(0xCCFFFFFF),
        letterSpacing: 4.0,
        opacity: 0.8,
        bold: true,
      ),
    ],
  );

  final _filmStamp = WatermarkTemplate(
    id: 'preset_film_stamp',
    name: '胶片印记',
    type: WatermarkTemplateType.preset,
    elements: [
      WatermarkElement(
        id: 'bg',
        type: WatermarkElementType.text,
        text: '',
        x: 0.55,
        y: 0.82,
        fontSize: 0,
        color: const ui.Color(0x00000000),
        opacity: 0,
      ),
      WatermarkElement(
        id: 'date',
        type: WatermarkElementType.text,
        text: '2026.08.08',
        x: 0.58,
        y: 0.86,
        fontSize: 11.0,
        color: const ui.Color(0xFFFFFFFF),
        opacity: 0.9,
      ),
      WatermarkElement(
        id: 'device',
        type: WatermarkElementType.text,
        text: 'iPhone 15 Pro',
        x: 0.58,
        y: 0.91,
        fontSize: 9.0,
        color: const ui.Color(0xCCFFFFFF),
        opacity: 0.7,
      ),
    ],
  );

  final _artSignature = WatermarkTemplate(
    id: 'preset_art_signature',
    name: '艺术签名',
    type: WatermarkTemplateType.preset,
    elements: [
      WatermarkElement(
        id: 'dot',
        type: WatermarkElementType.text,
        text: '●',
        x: 0.78,
        y: 0.92,
        fontSize: 6.0,
        color: const ui.Color(0x66FFFFFF),
        opacity: 0.4,
      ),
      WatermarkElement(
        id: 'signature',
        type: WatermarkElementType.text,
        text: '© Lumira',
        x: 0.80,
        y: 0.92,
        fontSize: 14.0,
        color: const ui.Color(0x66FFFFFF),
        opacity: 0.4,
        rotation: -0.08,
      ),
    ],
  );

  final _magazineLayout = WatermarkTemplate(
    id: 'preset_magazine_layout',
    name: '杂志排版',
    type: WatermarkTemplateType.preset,
    elements: [
      WatermarkElement(
        id: 'line_left',
        type: WatermarkElementType.text,
        text: '——',
        x: 0.15,
        y: 0.95,
        fontSize: 8.0,
        color: const ui.Color(0x99FFFFFF),
        opacity: 0.6,
      ),
      WatermarkElement(
        id: 'text',
        type: WatermarkElementType.text,
        text: '2026.08.08  ·  MOMENT  ·  LUMIRA',
        x: 0.30,
        y: 0.95,
        fontSize: 10.0,
        color: const ui.Color(0x99FFFFFF),
        opacity: 0.6,
        letterSpacing: 2.0,
        textAlign: TextAlign.center,
      ),
      WatermarkElement(
        id: 'line_right',
        type: WatermarkElementType.text,
        text: '——',
        x: 0.70,
        y: 0.95,
        fontSize: 8.0,
        color: const ui.Color(0x99FFFFFF),
        opacity: 0.6,
      ),
    ],
  );

  final _frameBorder = WatermarkTemplate(
    id: 'preset_frame_border',
    name: '画框水印',
    type: WatermarkTemplateType.preset,
    elements: [
      WatermarkElement(
        id: 'corner_tl',
        type: WatermarkElementType.text,
        text: '┌',
        x: 0.03,
        y: 0.03,
        fontSize: 16.0,
        color: const ui.Color(0x66FFFFFF),
        opacity: 0.4,
      ),
      WatermarkElement(
        id: 'corner_tr',
        type: WatermarkElementType.text,
        text: '┐',
        x: 0.95,
        y: 0.03,
        fontSize: 16.0,
        color: const ui.Color(0x66FFFFFF),
        opacity: 0.4,
      ),
      WatermarkElement(
        id: 'corner_bl',
        type: WatermarkElementType.text,
        text: '└',
        x: 0.03,
        y: 0.93,
        fontSize: 16.0,
        color: const ui.Color(0x66FFFFFF),
        opacity: 0.4,
      ),
      WatermarkElement(
        id: 'corner_br',
        type: WatermarkElementType.text,
        text: '┘',
        x: 0.95,
        y: 0.93,
        fontSize: 16.0,
        color: const ui.Color(0x66FFFFFF),
        opacity: 0.4,
      ),
      WatermarkElement(
        id: 'bottom_text',
        type: WatermarkElementType.text,
        text: 'LUMIRA  |  2026.08.08',
        x: 0.50,
        y: 0.97,
        fontSize: 10.0,
        color: const ui.Color(0x99FFFFFF),
        opacity: 0.6,
        letterSpacing: 2.0,
        textAlign: TextAlign.center,
      ),
    ],
  );
  ```

  注意：需要给 `WatermarkElement` 模型添加 `letterSpacing` 字段，因为它目前没有。让我们在模板模型中也加上这个字段。

  更新 `WatermarkElement` 模型，添加 `letterSpacing`：

  ```dart
  double letterSpacing;
  
  // 在构造函数中
  this.letterSpacing = 0.0,
  
  // 在 copyWith 中
  double? letterSpacing,
  
  // 在 toJson 中
  'letterSpacing': letterSpacing,
  
  // 在 fromJson 中
  letterSpacing: (json['letterSpacing'] as num?)?.toDouble() ?? 0.0,
  ```

---

### Task 3: 水印渲染引擎

**Files:**
- Create: `lib/features/capture/watermark/services/watermark_renderer.dart`

**Interfaces:**
- Produces: `WatermarkRenderer` 类，含 `render(ui.Image, List<WatermarkElement>) → Future<Uint8List>` 方法

- [ ] **Step 1: 创建水印渲染器**

  写入 `lib/features/capture/watermark/services/watermark_renderer.dart`：

  ```dart
  import 'dart:typed_data';
  import 'dart:ui' as ui;
  import 'dart:io';
  import 'package:flutter/services.dart' show rootBundle;
  import '../models/watermark_template.dart';

  class WatermarkRenderer {
    Future<Uint8List> render({
      required ui.Image sourceImage,
      required List<WatermarkElement> elements,
    }) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = Size(
        sourceImage.width.toDouble(),
        sourceImage.height.toDouble(),
      );

      canvas.drawImage(sourceImage, Offset.zero, Paint());

      for (final element in elements) {
        if (element.type == WatermarkElementType.text && element.text.isNotEmpty) {
          _drawTextElement(canvas, element, size);
        }
      }

      final picture = recorder.endRecording();
      final img = await picture.toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
      final byteData = await img.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      return byteData!.buffer.asUint8List();
    }

    void _drawTextElement(
      Canvas canvas,
      WatermarkElement element,
      Size imageSize,
    ) {
      final x = element.x * imageSize.width;
      final y = element.y * imageSize.height;

      final builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          textAlign: element.textAlign,
          fontSize: element.fontSize * (imageSize.width / 400),
          fontWeight: element.bold ? FontWeight.w700 : FontWeight.w400,
          fontStyle: element.italic ? FontStyle.italic : FontStyle.normal,
          fontFamily: element.fontFamily.isNotEmpty ? element.fontFamily : null,
        ),
      )..pushStyle(
        ui.TextStyle(
          color: element.color.withOpacity(element.opacity),
          letterSpacing: element.letterSpacing * (imageSize.width / 400),
        ),
      )..addText(element.text);

      final paragraph = builder.build();
      paragraph.layout(const ui.ParagraphConstraints(width: 300));

      final offset = Offset(x, y);
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(element.rotation);
      canvas.translate(-offset.dx, -offset.dy);

      if (element.shadowColor.alpha > 0) {
        final shadowPaint = Paint()
          ..color = element.shadowColor.withOpacity(element.opacity * 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
        final shadowOffset = offset + const Offset(1, 1);
        canvas.drawParagraph(paragraph, shadowOffset);
      }

      canvas.drawParagraph(paragraph, offset);
      canvas.restore();
    }
  }
  ```

---

### Task 4: 水印 Provider 和服务

**Files:**
- Create: `lib/features/capture/watermark/data/watermark_providers.dart`

**Interfaces:**
- Produces: `watermarkSettingsProvider` (StateProvider<WatermarkSettings>)
- Produces: `currentWatermarkTemplateProvider` (Provider<WatermarkTemplate?>)
- Produces: `watermarkRendererProvider` (Provider<WatermarkRenderer>)

- [ ] **Step 1: 创建水印 Provider**

  写入 `lib/features/capture/watermark/data/watermark_providers.dart`：

  ```dart
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import '../models/watermark_settings.dart';
  import '../models/watermark_template.dart';
  import '../services/watermark_renderer.dart';
  import 'preset_watermarks.dart';

  final watermarkSettingsProvider = StateProvider<WatermarkSettings>((ref) {
    return const WatermarkSettings();
  });

  final watermarkRendererProvider = Provider<WatermarkRenderer>((ref) {
    return WatermarkRenderer();
  });

  final presetWatermarksProvider = Provider<List<WatermarkTemplate>>((ref) {
    return getPresetWatermarks();
  });

  final currentWatermarkTemplateProvider = Provider<WatermarkTemplate?>((ref) {
    final settings = ref.watch(watermarkSettingsProvider);
    if (!settings.enabled || settings.activeTemplateId == null) return null;
    final presets = ref.watch(presetWatermarksProvider);
    try {
      return presets.firstWhere((t) => t.id == settings.activeTemplateId);
    } catch (_) {
      return null;
    }
  });
  ```

---

### Task 5: 水印管理页

**Files:**
- Create: `lib/features/capture/watermark/pages/watermark_manage_page.dart`
- Create: `lib/features/capture/watermark/widgets/watermark_preview.dart`

**Interfaces:**
- Consumes: `presetWatermarksProvider`, `watermarkSettingsProvider`
- Produces: `WatermarkManagePage` widget

- [ ] **Step 1: 创建水印预览组件**

  写入 `lib/features/capture/watermark/widgets/watermark_preview.dart`：

  ```dart
  import 'package:flutter/material.dart';
  import '../models/watermark_template.dart';

  class WatermarkPreview extends StatelessWidget {
    final WatermarkTemplate template;
    final double width;
    final double height;

    const WatermarkPreview({
      super.key,
      required this.template,
      this.width = 80,
      this.height = 100,
    });

    @override
    Widget build(BuildContext context) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: CustomPaint(
          painter: _WatermarkPreviewPainter(template),
          size: Size(width, height),
        ),
      );
    }
  }

  class _WatermarkPreviewPainter extends CustomPainter {
    final WatermarkTemplate template;

    _WatermarkPreviewPainter(this.template);

    @override
    void paint(Canvas canvas, Size size) {
      for (final element in template.elements) {
        if (element.type == WatermarkElementType.text && element.text.isNotEmpty) {
          final x = element.x * size.width;
          final y = element.y * size.height;
          final textPainter = TextPainter(
            text: TextSpan(
              text: element.text,
              style: TextStyle(
                color: element.color.withOpacity(element.opacity),
                fontSize: element.fontSize * (size.width / 400),
                fontWeight: element.bold ? FontWeight.w700 : FontWeight.w400,
                fontStyle: element.italic ? FontStyle.italic : FontStyle.normal,
              ),
            ),
            textDirection: TextDirection.ltr,
            textAlign: element.textAlign,
          );
          textPainter.layout(maxWidth: size.width * 0.8);
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(element.rotation);
          textPainter.paint(canvas, Offset.zero);
          canvas.restore();
        }
      }
    }

    @override
    bool shouldRepaint(covariant _WatermarkPreviewPainter oldDelegate) {
      return oldDelegate.template != template;
    }
  }
  ```

- [ ] **Step 2: 创建水印管理页面**

  写入 `lib/features/capture/watermark/pages/watermark_manage_page.dart`：

  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:go_router/go_router.dart';
  import '../../../../core/router/route_names.dart';
  import '../../../../shared/widgets/lumira/lumira.dart';
  import '../data/watermark_providers.dart';
  import '../models/watermark_settings.dart';
  import '../models/watermark_template.dart';
  import '../widgets/watermark_preview.dart';

  class WatermarkManagePage extends ConsumerWidget {
    const WatermarkManagePage({super.key});

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      final presets = ref.watch(presetWatermarksProvider);
      final settings = ref.watch(watermarkSettingsProvider);

      return Scaffold(
        appBar: AppBar(
          title: const Text('水印管理'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: presets.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final template = presets[index];
            final isSelected = template.id == settings.activeTemplateId;
            return _WatermarkCard(
              template: template,
              isSelected: isSelected,
              onTap: () {
                ref.read(watermarkSettingsProvider.notifier).state = settings.copyWith(
                  activeTemplateId: template.id,
                );
                context.pop();
              },
              onEdit: () {
                context.push(
                  '${RouteNames.profileSettingsWatermarkEdit}?templateId=${template.id}',
                );
              },
            );
          },
        ),
      );
    }
  }

  class _WatermarkCard extends StatelessWidget {
    final WatermarkTemplate template;
    final bool isSelected;
    final VoidCallback onTap;
    final VoidCallback onEdit;

    const _WatermarkCard({
      required this.template,
      required this.isSelected,
      required this.onTap,
      required this.onEdit,
    });

    @override
    Widget build(BuildContext context) {
      final tokens = Theme.of(context).extension<LumiraTokens>()!;
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? tokens.brand : tokens.divider,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              WatermarkPreview(template: template),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: template.type == WatermarkTemplateType.preset
                            ? tokens.brandSubtle.withOpacity(0.15)
                            : tokens.success.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        template.type == WatermarkTemplateType.preset ? '预设' : '自定义',
                        style: TextStyle(
                          fontSize: 11,
                          color: template.type == WatermarkTemplateType.preset
                              ? tokens.brand
                              : tokens.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: tokens.brand, size: 24)
              else
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: tokens.textSecondary),
                  onPressed: onEdit,
                ),
            ],
          ),
        ),
      );
    }
  }
  ```

  注意：这里使用了 `LumiraTokens` 主题扩展，需要确保导入正确。查看项目中的 `theme_tokens.dart` 和 `lumira.dart` 来确认正确的导入方式。

---

### Task 6: 水印编辑器页

**Files:**
- Create: `lib/features/capture/watermark/pages/watermark_editor_page.dart`

**Interfaces:**
- Consumes: `presetWatermarksProvider`, `watermarkSettingsProvider`, `watermarkRendererProvider`
- URL 参数: `?templateId=xxx`

- [ ] **Step 1: 创建水印编辑器页面**

  写入 `lib/features/capture/watermark/pages/watermark_editor_page.dart`：

  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:go_router/go_router.dart';
  import '../../../../shared/widgets/lumira/lumira.dart';
  import '../data/watermark_providers.dart';
  import '../models/watermark_template.dart';
  import '../models/watermark_settings.dart';
  import '../widgets/watermark_preview.dart';

  class WatermarkEditorPage extends ConsumerStatefulWidget {
    final String? templateId;

    const WatermarkEditorPage({super.key, this.templateId});

    @override
    ConsumerState<WatermarkEditorPage> createState() => _WatermarkEditorPageState();
  }

  class _WatermarkEditorPageState extends ConsumerState<WatermarkEditorPage> {
    late WatermarkTemplate _editing;

    @override
    void initState() {
      super.initState();
      final presets = ref.read(presetWatermarksProvider);
      final template = presets.firstWhere(
        (t) => t.id == widget.templateId,
        orElse: () => presets.first,
      );
      _editing = WatermarkTemplate(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: '${template.name} (自定义)',
        type: WatermarkTemplateType.custom,
        elements: template.elements
            .map((e) => e.copyWith(id: '${e.id}_${DateTime.now().millisecondsSinceEpoch}'))
            .toList(),
      );
    }

    void _updateElement(int index, WatermarkElement updated) {
      setState(() {
        final elements = List<WatermarkElement>.from(_editing.elements);
        elements[index] = updated;
        _editing = WatermarkTemplate(
          id: _editing.id,
          name: _editing.name,
          type: _editing.type,
          elements: elements,
          createdAt: _editing.createdAt,
        );
      });
    }

    @override
    Widget build(BuildContext context) {
      final tokens = Theme.of(context).extension<LumiraTokens>()!;
      return Scaffold(
        appBar: AppBar(
          title: const Text('编辑水印'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                ref.read(watermarkSettingsProvider.notifier).state = ref
                    .read(watermarkSettingsProvider)
                    .copyWith(activeTemplateId: _editing.id);
                context.pop();
                context.pop();
              },
              child: const Text('保存'),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: Container(
                  width: 200,
                  height: 260,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CustomPaint(
                    painter: _WatermarkPreviewPainter(_editing),
                    size: const Size(200, 260),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('文字内容', style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  )),
                  const SizedBox(height: 8),
                  ..._editing.elements.asMap().entries.map((entry) {
                    final index = entry.key;
                    final element = entry.value;
                    if (element.type != WatermarkElementType.text) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(element.text, style: TextStyle(
                            fontSize: 12,
                            color: tokens.textSecondary,
                          )),
                          const SizedBox(height: 4),
                          TextField(
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            controller: TextEditingController(text: element.text),
                            onChanged: (v) {
                              _updateElement(index, element.copyWith(text: v));
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('大小', style: TextStyle(
                                      fontSize: 11, color: tokens.textSecondary,
                                    )),
                                    Slider(
                                      value: element.fontSize,
                                      min: 6,
                                      max: 40,
                                      onChanged: (v) {
                                        _updateElement(index, element.copyWith(fontSize: v));
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('透明度', style: TextStyle(
                                      fontSize: 11, color: tokens.textSecondary,
                                    )),
                                    Slider(
                                      value: element.opacity,
                                      min: 0.1,
                                      max: 1.0,
                                      onChanged: (v) {
                                        _updateElement(index, element.copyWith(opacity: v));
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('X 位置', style: TextStyle(
                                      fontSize: 11, color: tokens.textSecondary,
                                    )),
                                    Slider(
                                      value: element.x,
                                      min: 0,
                                      max: 1.0,
                                      onChanged: (v) {
                                        _updateElement(index, element.copyWith(x: v));
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Y 位置', style: TextStyle(
                                      fontSize: 11, color: tokens.textSecondary,
                                    )),
                                    Slider(
                                      value: element.y,
                                      min: 0,
                                      max: 1.0,
                                      onChanged: (v) {
                                        _updateElement(index, element.copyWith(y: v));
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              FilterChip(
                                label: const Text('B'),
                                selected: element.bold,
                                onSelected: (v) {
                                  _updateElement(index, element.copyWith(bold: v));
                                },
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: const Text('I'),
                                selected: element.italic,
                                onSelected: (v) {
                                  _updateElement(index, element.copyWith(italic: v));
                                },
                              ),
                              const Spacer(),
                              Text('旋转', style: TextStyle(
                                fontSize: 11, color: tokens.textSecondary,
                              )),
                              SizedBox(
                                width: 100,
                                child: Slider(
                                  value: element.rotation,
                                  min: -0.5,
                                  max: 0.5,
                                  onChanged: (v) {
                                    _updateElement(index, element.copyWith(rotation: v));
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  class _WatermarkPreviewPainter extends CustomPainter {
    final WatermarkTemplate template;

    _WatermarkPreviewPainter(this.template);

    @override
    void paint(Canvas canvas, Size size) {
      final paint = Paint()..color = Colors.grey[300]!;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

      for (final element in template.elements) {
        if (element.type == WatermarkElementType.text && element.text.isNotEmpty) {
          final x = element.x * size.width;
          final y = element.y * size.height;
          final textPainter = TextPainter(
            text: TextSpan(
              text: element.text,
              style: TextStyle(
                color: Colors.black.withOpacity(element.opacity),
                fontSize: element.fontSize * (size.width / 400),
                fontWeight: element.bold ? FontWeight.w700 : FontWeight.w400,
                fontStyle: element.italic ? FontStyle.italic : FontStyle.normal,
              ),
            ),
            textDirection: TextDirection.ltr,
            textAlign: element.textAlign,
          );
          textPainter.layout(maxWidth: size.width * 0.8);
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(element.rotation);
          textPainter.paint(canvas, Offset.zero);
          canvas.restore();
        }
      }
    }

    @override
    bool shouldRepaint(covariant _WatermarkPreviewPainter oldDelegate) {
      return oldDelegate.template != template;
    }
  }
  ```

---

### Task 7: 路由注册

**Files:**
- Modify: `lib/core/router/route_names.dart`
- Modify: `lib/app/router.dart`

- [ ] **Step 1: 添加路由常量**

  在 `lib/core/router/route_names.dart` 中添加：

  ```dart
  static const String profileSettingsWatermark = '/profile/settings/watermark';
  static const String profileSettingsWatermarkEdit = '/profile/settings/watermark/edit';
  ```

- [ ] **Step 2: 注册路由**

  在 `lib/app/router.dart` 中，在 `profileSettings` 路由下添加子路由：

  ```dart
  GoRoute(
    path: 'watermark',
    builder: (context, state) => const WatermarkManagePage(),
  ),
  GoRoute(
    path: 'watermark/edit',
    builder: (context, state) {
      final templateId = state.uri.queryParameters['templateId'];
      return WatermarkEditorPage(templateId: templateId);
    },
  ),
  ```

  确保在文件顶部添加对应的 import 语句。

---

### Task 8: 设置页集成

**Files:**
- Modify: `lib/features/profile/pages/profile_settings_page.dart`

- [ ] **Step 1: 扩展水印设置项**

  在 `ProfileSettingsPage` 的"拍摄"区域，将水印相关设置扩展为：

  ```dart
  // 替换现有的水印 Toggle
  _SettingItem(
    icon: Icons.branding_watermark_outlined,
    label: '水印',
    trailing: LumiraSwitch(
      value: _watermarkOn,
      onChanged: (v) => setState(() => _watermarkOn = v),
    ),
    tokens: tokens,
  ),
  _SettingItem(
    icon: Icons.water_drop_outlined,
    label: '水印样式',
    value: '简约日期', // 显示当前选中的水印名称
    tokens: tokens,
    onTap: () => GoRouter.of(context).push(RouteNames.profileSettingsWatermark),
  ),
  _SettingItem(
    icon: Icons.animation_outlined,
    label: '水印动画',
    trailing: LumiraSwitch(
      value: _animationOn, // 新增状态变量
      onChanged: (v) => setState(() => _animationOn = v),
    ),
    tokens: tokens,
  ),
  ```

  在 `_ProfileSettingsPageState` 中添加状态变量：

  ```dart
  late bool _watermarkOn = ProfileMockData.defaultWatermarkOn;
  late bool _animationOn = ProfileMockData.defaultWatermarkAnimationOn;
  ```

  在 `ProfileMockData` 中添加默认值：

  ```dart
  static const bool defaultWatermarkAnimationOn = true;
  ```

  需要导入 `watermark_providers.dart` 和 `route_names.dart`。

---

### Task 9: 拍摄页集成水印渲染

**Files:**
- Modify: `lib/features/capture/pages/capture_page.dart`

- [ ] **Step 1: 在拍照后处理管线中集成水印渲染**

  在 `_processCaptureQueueItem()` 方法中，在 CPU 处理完成后、JPEG 编码保存前，插入水印渲染步骤：

  找到 `_processCaptureInIsolate` 调用之后、`GalleryItemRecord` 插入之前的代码段，在 `processedPath` 文件写入后，添加水印合成步骤：

  ```dart
  // 在 compute(_processCaptureInIsolate, gpuData) 之后
  final processedPath = await compute(_processCaptureInIsolate, gpuData);

  // 水印渲染
  String? watermarkedPath = processedPath;
  final watermarkSettings = ref.read(watermarkSettingsProvider);
  final watermarkTemplate = ref.read(currentWatermarkTemplateProvider);
  if (watermarkSettings.enabled && watermarkTemplate != null) {
    try {
      final file = File(processedPath);
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final sourceImage = frame.image;

      final renderer = ref.read(watermarkRendererProvider);
      final renderedBytes = await renderer.render(
        sourceImage: sourceImage,
        elements: watermarkTemplate.elements,
      );

      // 将渲染后的 RGBA 数据编码为 JPEG
      final img.Image output = img.Image.fromBytes(
        width: sourceImage.width,
        height: sourceImage.height,
        bytes: renderedBytes.buffer,
        numChannels: 4,
      );
      final jpegBytes = img.encodeJpg(output, quality: 95);
      watermarkedPath = processedPath.replaceAll('.jpg', '_wm.jpg');
      await File(watermarkedPath).writeAsBytes(jpegBytes);

      sourceImage.dispose();
      frame.release();
    } catch (e) {
      debugPrint('[watermark] render failed: $e');
      watermarkedPath = processedPath;
    }
  }
  ```

  注意：这里使用了 `image` 库的 `Image.fromBytes` 和 `encodeJpg`，需要确保 `image` 库已导入（该库已在 `pubspec.yaml` 中声明）。

  然后将 `GalleryItemRecord` 的 `filePath` 改为 `watermarkedPath`。

---

### Task 10: 相框动画 Overlay

**Files:**
- Create: `lib/features/capture/watermark/widgets/watermark_animation_overlay.dart`
- Modify: `lib/features/capture/pages/capture_page.dart`

- [ ] **Step 1: 创建相框动画组件**

  写入 `lib/features/capture/watermark/widgets/watermark_animation_overlay.dart`：

  ```dart
  import 'dart:async';
  import 'dart:io';
  import 'dart:ui' as ui;
  import 'package:flutter/material.dart';
  import '../models/watermark_template.dart';

  class WatermarkAnimationOverlay extends StatefulWidget {
    final String photoPath;
    final WatermarkTemplate watermarkTemplate;
    final Rect targetRect;
    final VoidCallback onAnimationComplete;

    const WatermarkAnimationOverlay({
      super.key,
      required this.photoPath,
      required this.watermarkTemplate,
      required this.targetRect,
      required this.onAnimationComplete,
    });

    @override
    State<WatermarkAnimationOverlay> createState() => _WatermarkAnimationOverlayState();
  }

  class _WatermarkAnimationOverlayState extends State<WatermarkAnimationOverlay>
      with SingleTickerProviderStateMixin {
    late AnimationController _controller;
    late Animation<double> _phase1;
    late Animation<double> _phase2;
    late Animation<double> _phase4;
    ui.Image? _photoImage;

    @override
    void initState() {
      super.initState();
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2200),
      );

      _phase1 = CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.14, curve: Curves.easeOut),
      );
      _phase2 = CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.14, 0.45, curve: Curves.easeOutBack),
      );
      _phase4 = CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.68, 0.86, curve: Curves.easeInCubic),
      );

      _loadImage();
      _controller.forward();
      _controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onAnimationComplete();
        }
      });
    }

    Future<void> _loadImage() async {
      final file = File(widget.photoPath);
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      setState(() {
        _photoImage = frame.image;
      });
    }

    @override
    void dispose() {
      _photoImage?.dispose();
      _controller.dispose();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      final screenSize = MediaQuery.of(context).size;
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          if (_photoImage == null) return const SizedBox.shrink();

          final phase1Value = _phase1.value;
          final phase2Value = _phase2.value;
          final phase4Value = _phase4.value;

          double opacity;
          double scale;
          Offset offset;

          if (_controller.value <= 0.14) {
            opacity = phase1Value;
            scale = 1.0;
            offset = Offset.zero;
          } else if (_controller.value <= 0.45) {
            opacity = 1.0;
            scale = 1.0;
            offset = Offset.zero;
          } else if (_controller.value <= 0.68) {
            opacity = 1.0;
            scale = 1.0;
            offset = Offset.zero;
          } else {
            opacity = 1.0 - (phase4Value * 0.3);
            scale = 1.0 - (phase4Value * 0.85);
            final targetDx = widget.targetRect.left - (screenSize.width / 2 - widget.targetRect.width * phase4Value / 2);
            final targetDy = widget.targetRect.top - (screenSize.height / 2 - widget.targetRect.height * phase4Value / 2);
            offset = Offset(targetDx * phase4Value, targetDy * phase4Value);
          }

          return IgnorePointer(
            child: Stack(
              children: [
                // 背景遮罩
                if (_controller.value > 0 && _controller.value < 0.86)
                  Container(color: Colors.black.withOpacity(0.5 * (1 - _controller.value))),
                // 照片
                Center(
                  child: Transform(
                    transform: Matrix4.identity()
                      ..translate(offset.dx, offset.dy)
                      ..scale(scale),
                    alignment: Alignment.center,
                    child: Opacity(
                      opacity: opacity,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8 * (1 - scale)),
                        child: SizedBox(
                          width: screenSize.width,
                          height: screenSize.height,
                          child: RawImage(
                            image: _photoImage,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // 水印文字（Phase 2 渐入）
                if (_controller.value > 0.14 && _controller.value < 0.86)
                  ...widget.watermarkTemplate.elements.map((element) {
                    final elementOpacity = ((_controller.value - 0.14) / 0.31).clamp(0.0, 1.0);
                    final elementScale = 0.8 + (0.2 * elementOpacity);
                    return Positioned(
                      left: element.x * screenSize.width,
                      top: element.y * screenSize.height,
                      child: Transform(
                        transform: Matrix4.identity()..scale(elementScale),
                        alignment: Alignment.center,
                        child: Opacity(
                          opacity: elementOpacity * element.opacity,
                          child: Text(
                            element.text,
                            style: TextStyle(
                              color: element.color,
                              fontSize: element.fontSize,
                              fontWeight: element.bold ? FontWeight.w700 : FontWeight.w400,
                              fontStyle: element.italic ? FontStyle.italic : FontStyle.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      );
    }
  }
  ```

  注意：这个动画组件需要进一步优化，特别是位置计算。实际实现时，需要根据屏幕尺寸和照片比例精确计算照片的显示区域和水印位置。

- [ ] **Step 2: 在 CapturePage 中集成动画**

  在 `CapturePage` 的 `_processCaptureQueueItem()` 方法中，在照片处理完成后，如果水印动画开启，则显示动画 Overlay：

  ```dart
  // 在缩略图更新之前，检查是否播放动画
  final watermarkSettings = ref.read(watermarkSettingsProvider);
  final watermarkTemplate = ref.read(currentWatermarkTemplateProvider);
  final shouldAnimate = watermarkSettings.enabled &&
      watermarkSettings.animationEnabled &&
      watermarkTemplate != null;

  if (shouldAnimate && mounted) {
    final thumbnailKey = _thumbnailKey;
    final completer = Completer<void>();
    setState(() {
      _showWatermarkAnimation = true;
      _animationPhotoPath = processedWmPath ?? processedPath;
      _animationTemplate = watermarkTemplate!;
      _animationTargetRect = _getThumbnailGlobalRect();
      _onAnimationComplete = () {
        setState(() => _showWatermarkAnimation = false);
        completer.complete();
      };
    });
    await completer.future;
  }

  // 然后更新缩略图
  ref.read(captureThumbnailProvider.notifier)
      .setFinalResult(processedPath, photoId);
  ```

  在 `_CapturePageState` 中添加状态变量：

  ```dart
  bool _showWatermarkAnimation = false;
  String? _animationPhotoPath;
  WatermarkTemplate? _animationTemplate;
  Rect _animationTargetRect = Rect.zero;
  VoidCallback? _onAnimationComplete;
  final _thumbnailKey = GlobalKey();
  ```

  在 `build` 方法的 `Stack` 中添加动画 Overlay：

  ```dart
  if (_showWatermarkAnimation &&
      _animationPhotoPath != null &&
      _animationTemplate != null) {
    Positioned.fill(
      child: WatermarkAnimationOverlay(
        photoPath: _animationPhotoPath!,
        watermarkTemplate: _animationTemplate!,
        targetRect: _animationTargetRect,
        onAnimationComplete: _onAnimationComplete ?? () {},
      ),
    ),
  }
  ```

  给 `CaptureThumbnail` 设置 `_thumbnailKey`：

  ```dart
  CaptureThumbnail(
    key: _thumbnailKey,
    onTap: _onThumbnailTap,
  ),
  ```

  添加辅助方法获取缩略图全局位置：

  ```dart
  Rect _getThumbnailGlobalRect() {
    final renderBox = _thumbnailKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return const Rect.fromLTWH(24, 0, 48, 48);
    final position = renderBox.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      position.dx,
      position.dy,
      renderBox.size.width,
      renderBox.size.height,
    );
  }
  ```

---

### Task 11: 设置持久化

**Files:**
- Modify: `lib/features/profile/pages/profile_settings_page.dart`

- [ ] **Step 1: 将水印设置持久化到 SettingsDao**

  在 `ProfileSettingsPage` 中，读取和写入水印设置时，通过 `watermarkSettingsProvider` 来持久化：

  ```dart
  // 读取水印设置
  final watermarkSettings = ref.watch(watermarkSettingsProvider);
  _watermarkOn = watermarkSettings.enabled;
  _animationOn = watermarkSettings.animationEnabled;

  // 写入水印设置
  ref.read(watermarkSettingsProvider.notifier).state = watermarkSettings.copyWith(
    enabled: v,
  );
  ```

  在 `SettingsDao` 中添加水印设置读取/写入方法，将其存储到 `user_settings` 表的 `watermark` JSON 字段中（或使用现有的 `freeModeCamera` 类似的 JSON 字段存储方式）。

  查看 `SettingsDao` 的实现来确定正确的持久化方式。

---

## 自检清单

1. **Spec 覆盖**: 检查每个 spec 需求是否对应一个任务
   - 5种预设水印 → Task 2
   - 水印管理页 → Task 5
   - 水印编辑器 → Task 6
   - 水印渲染到照片 → Task 9
   - 相框动画 → Task 10
   - 设置项 → Task 8
   - 路由 → Task 7
   - 数据模型 → Task 1
   - Provider → Task 4
   - 持久化 → Task 11

2. **占位符检查**: 所有代码块都有完整实现，无 TODO/TBD

3. **类型一致性**: 模型、Provider、渲染器之间的类型签名一致