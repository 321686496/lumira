# 参数调整、持久化与补光颜色优化 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现拍摄页参数面板的全功能（相机Tab精简、色彩矩阵修复、细节后处理实现、参数持久化、补光颜色合并删改），使所有UI参数真正生效并持久化。

**Architecture:** 分5个独立任务推进：(1)饱和度矩阵修复（独立可测）→ (2)数据模型序列化（纯数据层）→ (3)数据库扩展+DAO（依赖序列化）→ (4)持久化加载/防抖+重置按钮+相机Tab精简（依赖DAO）→ (5)拍照后处理增加色彩/细节（依赖矩阵修复）→ (6)补光颜色合并删改（独立UI改动）。每个任务独立可测，按顺序提交。

**Tech Stack:** Flutter 3.x, Riverpod 2.x, sqflite (CPF-Flutter OHOS适配版), image 4.0.16, path_provider 2.0.14

## Global Constraints

- 三端兼容（OHOS/iOS/Android）：所有改动仅在 Dart 层，不依赖原生平台 API
- 不使用 shared_preferences（项目规则禁止），提示标记用本地 JSON 文件
- 数据库 migration 使用 `_addColumnIfNotExists` 保证幂等
- 拍照后处理总时间 <500ms（2048px 图像）
- image 包版本 4.0.16，API 参考 `dart_photo_pipeline.dart` 既有用法
- 不引入新依赖，复用现有 image 包和 DAO 模式

---

## File Structure

**修改文件清单**（按任务依赖顺序）：
- `lib/features/capture/domain/filter_recipe.dart` — Task 1: 修复饱和度矩阵
- `lib/features/capture/domain/photo_template.dart` — Task 2: 添加 toJson/fromJson
- `lib/core/db/tables.dart` — Task 3: 新增列常量
- `lib/core/db/database_provider.dart` — Task 3: v9 migration
- `lib/core/db/dao/settings_dao.dart` — Task 3: 新增 get/set 方法
- `lib/features/capture/data/capture_state.dart` — Task 4: 持久化防抖逻辑
- `lib/features/capture/pages/capture_page.dart` — Task 4,5,6: 持久化加载、后处理、补光UI
- `lib/features/capture/widgets/param_panel.dart` — Task 4: 相机Tab精简、重置按钮
- `lib/features/capture/services/dart_photo_pipeline.dart` — Task 5: 提取公共函数
- `lib/features/capture/data/custom_fill_light_colors.dart` — Task 6: 新增 update 方法

---

### Task 1: 修复饱和度矩阵色偏

**Files:**
- Modify: `lib/features/capture/domain/filter_recipe.dart:62-77`
- Test: `test/features/capture/domain/saturation_matrix_test.dart`

**Interfaces:**
- Consumes: 无
- Produces: 修复后的 `_saturationMatrix` 函数（私有，通过 `composePostProcessMatrix` 间接测试）

- [ ] **Step 1: Write the failing test**

```dart
// test/features/capture/domain/saturation_matrix_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/domain/filter_recipe.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';

void main() {
  group('Saturation matrix color cast fix', () {
    test('pure gray image keeps gray after saturation change (no color cast)', () {
      // 纯灰图 R=G=B=128，饱和度调整后应仍为灰（R=G=B），无色偏
      final postProcess = PostProcess(
        color: PostProcessColor(saturation: 50),
      );
      final matrix = composePostProcessMatrix(postProcess);

      // 模拟纯灰像素 R=G=B=128, A=255
      final r = 128.0, g = 128.0, b = 128.0, a = 255.0;
      final newR = matrix[0] * r + matrix[1] * g + matrix[2] * b + matrix[3] * a + matrix[4];
      final newG = matrix[5] * r + matrix[6] * g + matrix[7] * b + matrix[8] * a + matrix[9];
      final newB = matrix[10] * r + matrix[11] * g + matrix[12] * b + matrix[13] * a + matrix[14];

      // 灰色像素饱和度调整后应仍为灰色（R=G=B，允许浮点误差）
      expect((newR - newG).abs(), lessThan(0.5), reason: 'R and G should match for gray pixel');
      expect((newG - newB).abs(), lessThan(0.5), reason: 'G and B should match for gray pixel');
      expect((newR - newB).abs(), lessThan(0.5), reason: 'R and B should match for gray pixel');
    });

    test('saturation -100 produces grayscale (luminance only)', () {
      final postProcess = PostProcess(
        color: PostProcessColor(saturation: -100),
      );
      final matrix = composePostProcessMatrix(postProcess);

      // 红色像素 (255,0,0) 饱和度-100 后应变为亮度值
      final r = 255.0, g = 0.0, b = 0.0, a = 255.0;
      final newR = matrix[0] * r + matrix[1] * g + matrix[2] * b + matrix[3] * a + matrix[4];
      final newG = matrix[5] * r + matrix[6] * g + matrix[7] * b + matrix[8] * a + matrix[9];
      final newB = matrix[10] * r + matrix[11] * g + matrix[12] * b + matrix[13] * a + matrix[14];

      // 红色像素变灰后 R=G=B
      expect((newR - newG).abs(), lessThan(1.0));
      expect((newG - newB).abs(), lessThan(1.0));
    });

    test('saturation 0 is identity for color channels', () {
      final postProcess = PostProcess(
        color: PostProcessColor(saturation: 0),
      );
      final matrix = composePostProcessMatrix(postProcess);

      final r = 100.0, g = 150.0, b = 200.0, a = 255.0;
      final newR = matrix[0] * r + matrix[1] * g + matrix[2] * b + matrix[3] * a + matrix[4];
      final newG = matrix[5] * r + matrix[6] * g + matrix[7] * b + matrix[8] * a + matrix[9];
      final newB = matrix[10] * r + matrix[11] * g + matrix[12] * b + matrix[13] * a + matrix[14];

      expect(newR, closeTo(100, 0.5));
      expect(newG, closeTo(150, 0.5));
      expect(newB, closeTo(200, 0.5));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/capture/domain/saturation_matrix_test.dart`
Expected: FAIL — 纯灰图饱和度+50后 R≠G≠B（因NTSC权重偏差导致色偏）

- [ ] **Step 3: Write minimal implementation**

修改 `lib/features/capture/domain/filter_recipe.dart` 第 62-77 行的 `_saturationMatrix` 函数：

```dart
/// Saturation matrix: saturate(1 + v/100) in CSS
/// v: -100 ~ 100 (0 = no change, -100 = grayscale, +100 = double saturation)
///
/// 使用 Rec.709 亮度权重（sRGB 标准），
/// 替代老式 NTSC 权重（0.3086/0.6094/0.0820）以避免饱和度调整时的色偏。
List<double> _saturationMatrix(double v) {
  final s = 1 + v / 100;
  // Rec.709 亮度权重（sRGB 标准）
  const lumR = 0.2126, lumG = 0.7152, lumB = 0.0722;
  final sr = (1 - s) * lumR;
  final sg = (1 - s) * lumG;
  final sb = (1 - s) * lumB;
  return [
    s + sr, sr, sr, 0, 0,
    sg, s + sg, sg, 0, 0,
    sb, sb, s + sb, 0, 0,
    0, 0, 0, 1, 0,
  ];
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/capture/domain/saturation_matrix_test.dart`
Expected: PASS — 3个测试全部通过

- [ ] **Step 5: Commit**

```bash
cd e:/Project/photo_post/lumira_app_flutter
git add test/features/capture/domain/saturation_matrix_test.dart lib/features/capture/domain/filter_recipe.dart
git commit -m "fix: 修复饱和度矩阵色偏，使用Rec.709亮度权重替代NTSC权重"
```

---

### Task 2: 数据模型序列化（toJson/fromJson）

**Files:**
- Modify: `lib/features/capture/domain/photo_template.dart`
- Test: `test/features/capture/domain/photo_template_serialization_test.dart`

**Interfaces:**
- Consumes: 无
- Produces: `CameraParams.toJson()`/`CameraParams.fromJson()`, `PostProcess.toJson()`/`PostProcess.fromJson()`, `PostProcessColor.toJson()`/`PostProcessColor.fromJson()`, `Composition.toJson()`/`Composition.fromJson()`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/capture/domain/photo_template_serialization_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';

void main() {
  group('CameraParams serialization', () {
    test('roundtrip preserves all fields', () {
      const original = CameraParams(
        exposureCompensation: 1.5,
        iso: 400,
        shutterSpeed: '1/125',
        whiteBalance: 'cloudy',
        whiteBalanceK: 6000,
        flashMode: 'auto',
        focusMode: 'continuous',
        lensType: 'wide',
        isoMode: 'manual',
        lensSuggestion: '使用广角',
      );
      final json = original.toJson();
      final restored = CameraParams.fromJson(json);
      expect(restored, equals(original));
    });

    test('default values roundtrip', () {
      const original = CameraParams();
      final json = original.toJson();
      final restored = CameraParams.fromJson(json);
      expect(restored, equals(original));
    });
  });

  group('PostProcessColor serialization', () {
    test('roundtrip preserves all fields including nullables', () {
      const original = PostProcessColor(
        brightness: 10,
        contrast: -5,
        saturation: 30,
        temperature: 15,
        tint: -8,
        highlights: 20,
        shadows: -15,
        blackPoint: 5,
        clarity: 12,
        vibrance: 8,
        brilliance: 3,
      );
      final json = original.toJson();
      final restored = PostProcessColor.fromJson(json);
      expect(restored, equals(original));
    });

    test('null nullable fields preserved as null', () {
      const original = PostProcessColor();
      final json = original.toJson();
      final restored = PostProcessColor.fromJson(json);
      expect(restored.highlights, isNull);
      expect(restored.shadows, isNull);
      expect(restored.blackPoint, isNull);
      expect(restored.clarity, isNull);
      expect(restored.vibrance, isNull);
      expect(restored.brilliance, isNull);
    });
  });

  group('PostProcess serialization', () {
    test('roundtrip preserves all fields', () {
      const original = PostProcess(
        cropRatio: '1:1',
        color: PostProcessColor(brightness: 10, saturation: 20),
        smoothStrength: 15,
        sharpen: 30,
        vignette: 25,
        grain: 10,
        lut: 'cinematic',
        systemFilter: 'vivid',
      );
      final json = original.toJson();
      final restored = PostProcess.fromJson(json);
      expect(restored, equals(original));
    });

    test('systemFilter null preserved', () {
      const original = PostProcess(
        color: PostProcessColor(),
        systemFilter: null,
      );
      final json = original.toJson();
      final restored = PostProcess.fromJson(json);
      expect(restored.systemFilter, isNull);
    });
  });

  group('Composition serialization', () {
    test('roundtrip preserves all fields', () {
      const original = Composition(
        overlayType: 'golden_ratio',
        opacity: 0.7,
        aspectRatio: '4:3',
        description: '黄金比例构图',
      );
      final json = original.toJson();
      final restored = Composition.fromJson(json);
      expect(restored, equals(original));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/capture/domain/photo_template_serialization_test.dart`
Expected: FAIL — `toJson`/`fromJson` 方法不存在

- [ ] **Step 3: Write minimal implementation**

在 `lib/features/capture/domain/photo_template.dart` 中为以下类添加 `toJson()` 和 `fromJson()` 工厂构造。

**CameraParams**（在第 380 行 `}` 前插入）：
```dart
  Map<String, dynamic> toJson() => {
        'exposureCompensation': exposureCompensation,
        'iso': iso,
        'shutterSpeed': shutterSpeed,
        'whiteBalance': whiteBalance,
        'whiteBalanceK': whiteBalanceK,
        'flashMode': flashMode,
        'focusMode': focusMode,
        if (lensType != null) 'lensType': lensType,
        if (isoMode != null) 'isoMode': isoMode,
        if (lensSuggestion != null) 'lensSuggestion': lensSuggestion,
      };

  factory CameraParams.fromJson(Map<String, dynamic> json) => CameraParams(
        exposureCompensation: (json['exposureCompensation'] as num?)?.toDouble() ?? 0.0,
        iso: (json['iso'] as num?)?.toInt() ?? 200,
        shutterSpeed: json['shutterSpeed'] as String? ?? '1/200',
        whiteBalance: json['whiteBalance'] as String? ?? 'daylight',
        whiteBalanceK: (json['whiteBalanceK'] as num?)?.toInt() ?? 5500,
        flashMode: json['flashMode'] as String? ?? 'off',
        focusMode: json['focusMode'] as String? ?? 'auto',
        lensType: json['lensType'] as String?,
        isoMode: json['isoMode'] as String?,
        lensSuggestion: json['lensSuggestion'] as String?,
      );
```

**PostProcessColor**（在文件末尾 `}` 前插入）：
```dart
  Map<String, dynamic> toJson() => {
        'brightness': brightness,
        'contrast': contrast,
        'saturation': saturation,
        'temperature': temperature,
        'tint': tint,
        if (highlights != null) 'highlights': highlights,
        if (shadows != null) 'shadows': shadows,
        if (blackPoint != null) 'blackPoint': blackPoint,
        if (clarity != null) 'clarity': clarity,
        if (vibrance != null) 'vibrance': vibrance,
        if (brilliance != null) 'brilliance': brilliance,
      };

  factory PostProcessColor.fromJson(Map<String, dynamic> json) => PostProcessColor(
        brightness: (json['brightness'] as num?)?.toDouble() ?? 0,
        contrast: (json['contrast'] as num?)?.toDouble() ?? 0,
        saturation: (json['saturation'] as num?)?.toDouble() ?? 0,
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0,
        tint: (json['tint'] as num?)?.toDouble() ?? 0,
        highlights: (json['highlights'] as num?)?.toDouble(),
        shadows: (json['shadows'] as num?)?.toDouble(),
        blackPoint: (json['blackPoint'] as num?)?.toDouble(),
        clarity: (json['clarity'] as num?)?.toDouble(),
        vibrance: (json['vibrance'] as num?)?.toDouble(),
        brilliance: (json['brilliance'] as num?)?.toDouble(),
      );
```

**PostProcess**（在 `hashCode` getter 后插入）：
```dart
  Map<String, dynamic> toJson() => {
        'cropRatio': cropRatio,
        'color': color.toJson(),
        'smoothStrength': smoothStrength,
        'sharpen': sharpen,
        'vignette': vignette,
        'grain': grain,
        'lut': lut,
        if (systemFilter != null) 'systemFilter': systemFilter,
      };

  factory PostProcess.fromJson(Map<String, dynamic> json) => PostProcess(
        cropRatio: json['cropRatio'] as String? ?? '3:4',
        color: PostProcessColor.fromJson(json['color'] as Map<String, dynamic>? ?? {}),
        smoothStrength: (json['smoothStrength'] as num?)?.toInt() ?? 0,
        sharpen: (json['sharpen'] as num?)?.toInt() ?? 0,
        vignette: (json['vignette'] as num?)?.toInt() ?? 0,
        grain: (json['grain'] as num?)?.toInt() ?? 0,
        lut: json['lut'] as String? ?? 'none',
        systemFilter: json['systemFilter'] as String?,
      );
```

**Composition**（在 `hashCode` getter 后插入）：
```dart
  Map<String, dynamic> toJson() => {
        'overlayType': overlayType,
        if (gridType != null) 'gridType': gridType,
        if (subjectFrame != null)
          'subjectFrame': {
            'x': subjectFrame!.x,
            'y': subjectFrame!.y,
            'w': subjectFrame!.w,
            'h': subjectFrame!.h,
          },
        'opacity': opacity,
        'aspectRatio': aspectRatio,
        'description': description,
      };

  factory Composition.fromJson(Map<String, dynamic> json) => Composition(
        overlayType: json['overlayType'] as String? ?? 'rule_of_thirds',
        gridType: json['gridType'] as String?,
        subjectFrame: (json['subjectFrame'] as Map<String, dynamic>?) != null
            ? SubjectFrame(
                x: (json['subjectFrame']['x'] as num).toDouble(),
                y: (json['subjectFrame']['y'] as num).toDouble(),
                w: (json['subjectFrame']['w'] as num).toDouble(),
                h: (json['subjectFrame']['h'] as num).toDouble(),
              )
            : null,
        opacity: (json['opacity'] as num?)?.toDouble() ?? 0.5,
        aspectRatio: json['aspectRatio'] as String? ?? '3:4',
        description: json['description'] as String? ?? '',
      );
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/capture/domain/photo_template_serialization_test.dart`
Expected: PASS — 8个测试全部通过

- [ ] **Step 5: Commit**

```bash
cd e:/Project/photo_post/lumira_app_flutter
git add test/features/capture/domain/photo_template_serialization_test.dart lib/features/capture/domain/photo_template.dart
git commit -m "feat: 为CameraParams/PostProcess/Composition添加toJson/fromJson序列化"
```

---

### Task 3: 数据库扩展 + SettingsDao 方法

**Files:**
- Modify: `lib/core/db/tables.dart:52-53` (新增列常量)
- Modify: `lib/core/db/database_provider.dart:19,206-209,388-433` (版本号+建表+migration)
- Modify: `lib/core/db/dao/settings_dao.dart` (新增 get/set 方法)
- Test: `test/core/db/dao/settings_dao_test.dart` (扩展)

**Interfaces:**
- Consumes: Task 2 的 `CameraParams.toJson/fromJson`, `PostProcess.toJson/fromJson`, `Composition.toJson/fromJson`
- Produces: `SettingsDao.getFreeModeCamera()`, `SettingsDao.setFreeModeCamera(CameraParams)`, `SettingsDao.getFreeModePostProcess()`, `SettingsDao.setFreeModePostProcess(PostProcess)`, `SettingsDao.getFreeModeComposition()`, `SettingsDao.setFreeModeComposition(Composition)`

- [ ] **Step 1: Write the failing test**

在 `test/core/db/dao/settings_dao_test.dart` 末尾的 `main()` 内追加测试（先更新 setUp 中的建表 SQL 包含新列）：

```dart
  // 在 setUp 的 onCreate 中，建表 SQL 需新增三列：
  // free_mode_camera TEXT, free_mode_post_process TEXT, free_mode_composition TEXT

  group('free mode params persistence', () {
    test('setFreeModeCamera persists and getFreeModeCamera returns same value', () async {
      const params = CameraParams(
        exposureCompensation: 1.5,
        iso: 400,
        shutterSpeed: '1/125',
        whiteBalance: 'cloudy',
        flashMode: 'auto',
        focusMode: 'continuous',
      );
      await dao.setFreeModeCamera(params);
      final restored = await dao.getFreeModeCamera();
      expect(restored, isNotNull);
      expect(restored!.exposureCompensation, equals(1.5));
      expect(restored.iso, equals(400));
      expect(restored.shutterSpeed, equals('1/125'));
      expect(restored.whiteBalance, equals('cloudy'));
      expect(restored.flashMode, equals('auto'));
      expect(restored.focusMode, equals('continuous'));
    });

    test('getFreeModeCamera returns null when not set', () async {
      final restored = await dao.getFreeModeCamera();
      expect(restored, isNull);
    });

    test('setFreeModePostProcess persists and getFreeModePostProcess returns same value', () async {
      const params = PostProcess(
        cropRatio: '1:1',
        color: PostProcessColor(brightness: 10, saturation: 20, clarity: 15),
        smoothStrength: 12,
        sharpen: 25,
        vignette: 30,
        grain: 8,
        lut: 'cinematic',
        systemFilter: 'vivid',
      );
      await dao.setFreeModePostProcess(params);
      final restored = await dao.getFreeModePostProcess();
      expect(restored, isNotNull);
      expect(restored!.cropRatio, equals('1:1'));
      expect(restored.color.brightness, equals(10));
      expect(restored.color.saturation, equals(20));
      expect(restored.color.clarity, equals(15));
      expect(restored.smoothStrength, equals(12));
      expect(restored.sharpen, equals(25));
      expect(restored.vignette, equals(30));
      expect(restored.grain, equals(8));
      expect(restored.lut, equals('cinematic'));
      expect(restored.systemFilter, equals('vivid'));
    });

    test('setFreeModeComposition persists and getFreeModeComposition returns same value', () async {
      const params = Composition(
        overlayType: 'golden_ratio',
        opacity: 0.7,
        aspectRatio: '4:3',
        description: '测试构图',
      );
      await dao.setFreeModeComposition(params);
      final restored = await dao.getFreeModeComposition();
      expect(restored, isNotNull);
      expect(restored!.overlayType, equals('golden_ratio'));
      expect(restored.opacity, equals(0.7));
      expect(restored.aspectRatio, equals('4:3'));
      expect(restored.description, equals('测试构图'));
    });
  });
```

同时需要更新文件顶部 import：
```dart
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
```

并更新 setUp 中的建表 SQL，在 `auto_deblur INTEGER NOT NULL DEFAULT 1,` 后追加：
```sql
free_mode_camera TEXT,
free_mode_post_process TEXT,
free_mode_composition TEXT,
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/db/dao/settings_dao_test.dart`
Expected: FAIL — `setFreeModeCamera`/`getFreeModeCamera` 等方法不存在

- [ ] **Step 3: Write minimal implementation**

**3a. 修改 `lib/core/db/tables.dart`**，在第 53 行 `colAutoDeblur` 后追加：
```dart
  // === user_settings 扩展列（v9 迁移新增，自由模式参数持久化） ===
  static const String colFreeModeCamera = 'free_mode_camera';
  static const String colFreeModePostProcess = 'free_mode_post_process';
  static const String colFreeModeComposition = 'free_mode_composition';
```

**3b. 修改 `lib/core/db/database_provider.dart`**：

第 19 行版本号改为：
```dart
const int _kDbVersion = 9;
```

在 `_onCreate` 的 user_settings 建表 SQL 中（第 206 行 `colAutoDeblur` 后）追加三列：
```dart
      ${Tables.colAutoDeblur} INTEGER NOT NULL DEFAULT 1,
      ${Tables.colFreeModeCamera} TEXT,
      ${Tables.colFreeModePostProcess} TEXT,
      ${Tables.colFreeModeComposition} TEXT,
      ${Tables.colUpdatedAt} INTEGER NOT NULL
```

在 `_onUpgrade` 末尾（第 433 行 `}` 前，v8 块之后）追加 v9 migration：
```dart
  if (oldVersion < 9) {
    try {
      // v9: 自由模式参数持久化（相机/后期/构图 JSON）
      await _addColumnIfNotExists(
        db,
        Tables.userSettings,
        Tables.colFreeModeCamera,
        'TEXT',
      );
      await _addColumnIfNotExists(
        db,
        Tables.userSettings,
        Tables.colFreeModePostProcess,
        'TEXT',
      );
      await _addColumnIfNotExists(
        db,
        Tables.userSettings,
        Tables.colFreeModeComposition,
        'TEXT',
      );
    } catch (e) {
      debugPrint('v9 migration failed (silent fallback): $e');
    }
  }
```

**3c. 修改 `lib/core/db/dao/settings_dao.dart`**，在文件顶部添加 import：
```dart
import 'dart:convert';
import '../../features/capture/domain/photo_template.dart';
```

在 `SettingsDao` 类末尾 `}` 前追加方法：
```dart
  /// 读取自由模式相机参数（未设置时返回 null）
  Future<CameraParams?> getFreeModeCamera() async {
    final rows = await _db.query(
      Tables.userSettings,
      columns: [Tables.colFreeModeCamera],
      where: 'id = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return null;
    final raw = rows.first[Tables.colFreeModeCamera] as String?;
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return CameraParams.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// 保存自由模式相机参数
  Future<void> setFreeModeCamera(CameraParams value) async {
    await _db.update(
      Tables.userSettings,
      {
        Tables.colFreeModeCamera: jsonEncode(value.toJson()),
        Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  /// 读取自由模式后期参数（未设置时返回 null）
  Future<PostProcess?> getFreeModePostProcess() async {
    final rows = await _db.query(
      Tables.userSettings,
      columns: [Tables.colFreeModePostProcess],
      where: 'id = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return null;
    final raw = rows.first[Tables.colFreeModePostProcess] as String?;
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return PostProcess.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// 保存自由模式后期参数
  Future<void> setFreeModePostProcess(PostProcess value) async {
    await _db.update(
      Tables.userSettings,
      {
        Tables.colFreeModePostProcess: jsonEncode(value.toJson()),
        Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  /// 读取自由模式构图参数（未设置时返回 null）
  Future<Composition?> getFreeModeComposition() async {
    final rows = await _db.query(
      Tables.userSettings,
      columns: [Tables.colFreeModeComposition],
      where: 'id = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return null;
    final raw = rows.first[Tables.colFreeModeComposition] as String?;
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return Composition.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// 保存自由模式构图参数
  Future<void> setFreeModeComposition(Composition value) async {
    await _db.update(
      Tables.userSettings,
      {
        Tables.colFreeModeComposition: jsonEncode(value.toJson()),
        Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/db/dao/settings_dao_test.dart`
Expected: PASS — 所有测试通过

- [ ] **Step 5: Commit**

```bash
cd e:/Project/photo_post/lumira_app_flutter
git add lib/core/db/tables.dart lib/core/db/database_provider.dart lib/core/db/dao/settings_dao.dart test/core/db/dao/settings_dao_test.dart
git commit -m "feat: 扩展SettingsDao支持自由模式参数持久化(v9迁移)"
```

---

### Task 4: 持久化加载/防抖 + 重置按钮 + 相机Tab精简

**Files:**
- Modify: `lib/features/capture/data/capture_state.dart` (防抖 Timer)
- Modify: `lib/features/capture/pages/capture_page.dart` (initState 加载)
- Modify: `lib/features/capture/widgets/param_panel.dart` (相机Tab精简、重置按钮)

**Interfaces:**
- Consumes: Task 3 的 SettingsDao 方法
- Produces: 自由模式参数的自动持久化与加载

- [ ] **Step 1: 修改 capture_state.dart 添加防抖持久化**

在 `lib/features/capture/data/capture_state.dart` 中，找到 `freeModeCameraProvider` 定义（约第 186 行），在其后添加防抖 Timer 和持久化方法。

在文件顶部添加 import：
```dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/dao/settings_dao.dart';
import '../../core/db/database_provider.dart';
```

在 `freeModeCompositionProvider`（约第 196 行）之后添加：
```dart
  // ── 自由模式参数持久化（防抖写入 DAO）──

  /// 防抖 Timer：参数变更后 500ms 无新变更才写入 DAO
  static Timer? _cameraPersistTimer;
  static Timer? _postProcessPersistTimer;
  static Timer? _compositionPersistTimer;

  /// 从 DAO 加载自由模式参数到对应 provider（拍摄页 initState 调用）
  static Future<void> loadFreeModeParams(ProviderContainer container) async {
    try {
      final dao = await container.read(settingsDaoProvider.future);
      final camera = await dao.getFreeModeCamera();
      final postProcess = await dao.getFreeModePostProcess();
      final composition = await dao.getFreeModeComposition();
      if (camera != null) {
        container.read(freeModeCameraProvider.notifier).state = camera;
      }
      if (postProcess != null) {
        container.read(freeModePostProcessProvider.notifier).state = postProcess;
      }
      if (composition != null) {
        container.read(freeModeCompositionProvider.notifier).state = composition;
      }
    } catch (e) {
      // 加载失败静默降级，使用默认值
      debugPrint('[capture] loadFreeModeParams failed: $e');
    }
  }

  /// 防抖持久化相机参数（500ms 内多次变更只写一次）
  static void _scheduleCameraPersist(ProviderContainer container) {
    _cameraPersistTimer?.cancel();
    _cameraPersistTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final dao = await container.read(settingsDaoProvider.future);
        final value = container.read(freeModeCameraProvider);
        await dao.setFreeModeCamera(value);
      } catch (e) {
        debugPrint('[capture] persist camera failed: $e');
      }
    });
  }

  /// 防抖持久化后期参数
  static void _schedulePostProcessPersist(ProviderContainer container) {
    _postProcessPersistTimer?.cancel();
    _postProcessPersistTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final dao = await container.read(settingsDaoProvider.future);
        final value = container.read(freeModePostProcessProvider);
        await dao.setFreeModePostProcess(value);
      } catch (e) {
        debugPrint('[capture] persist postProcess failed: $e');
      }
    });
  }

  /// 防抖持久化构图参数
  static void _scheduleCompositionPersist(ProviderContainer container) {
    _compositionPersistTimer?.cancel();
    _compositionPersistTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final dao = await container.read(settingsDaoProvider.future);
        final value = container.read(freeModeCompositionProvider);
        await dao.setFreeModeComposition(value);
      } catch (e) {
        debugPrint('[capture] persist composition failed: $e');
      }
    });
  }
```

修改 `updateCamera` 方法（约第 228 行），在自由模式分支添加持久化调用：
```dart
  static void updateCamera(WidgetRef ref, CameraParams Function(CameraParams) updater) {
    final editable = ref.read(editableTemplateProvider);
    if (editable != null) {
      ref.read(editableTemplateProvider.notifier).state =
          editable.copyWith(camera: updater(editable.camera));
    } else {
      final current = ref.read(freeModeCameraProvider);
      ref.read(freeModeCameraProvider.notifier).state = updater(current);
      _scheduleCameraPersist(ref.container);
    }
  }
```

修改 `updatePostProcess` 方法（约第 240 行），同理添加：
```dart
  static void updatePostProcess(WidgetRef ref, PostProcess Function(PostProcess) updater) {
    final editable = ref.read(editableTemplateProvider);
    if (editable != null) {
      ref.read(editableTemplateProvider.notifier).state =
          editable.copyWith(postProcess: updater(editable.postProcess));
    } else {
      final current = ref.read(freeModePostProcessProvider);
      ref.read(freeModePostProcessProvider.notifier).state = updater(current);
      _schedulePostProcessPersist(ref.container);
    }
  }
```

修改 `updateComposition` 方法（约第 252 行），同理添加：
```dart
  static void updateComposition(WidgetRef ref, Composition Function(Composition) updater) {
    final editable = ref.read(editableTemplateProvider);
    if (editable != null) {
      ref.read(editableTemplateProvider.notifier).state =
          editable.copyWith(composition: updater(editable.composition));
    } else {
      final current = ref.read(freeModeCompositionProvider);
      ref.read(freeModeCompositionProvider.notifier).state = updater(current);
      _scheduleCompositionPersist(ref.container);
    }
  }
```

新增重置方法（在 updateComposition 之后）：
```dart
  /// 重置自由模式所有参数为默认值并立即持久化
  static void resetFreeModeParams(WidgetRef ref) {
    ref.read(freeModeCameraProvider.notifier).state = const CameraParams();
    ref.read(freeModePostProcessProvider.notifier).state =
        const PostProcess(color: PostProcessColor());
    ref.read(freeModeCompositionProvider.notifier).state = const Composition();
    _cameraPersistTimer?.cancel();
    _postProcessPersistTimer?.cancel();
    _compositionPersistTimer?.cancel();
    _scheduleCameraPersist(ref.container);
    _schedulePostProcessPersist(ref.container);
    _scheduleCompositionPersist(ref.container);
  }
```

- [ ] **Step 2: 修改 capture_page.dart initState 加载持久化参数**

在 `lib/features/capture/pages/capture_page.dart` 的 `_CapturePageState` 的 `initState` 中（搜索 `void initState`），添加加载调用：

找到 initState 方法，在现有逻辑末尾（`super.initState()` 之后的位置）添加：
```dart
    // 异步加载持久化的自由模式参数
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CaptureState.loadFreeModeParams(ref.container);
    });
```

- [ ] **Step 3: 修改 param_panel.dart 重置按钮始终显示 + 相机Tab精简**

在 `lib/features/capture/widgets/param_panel.dart` 中：

**3a. 修改 `_PanelFooter`（约第 258 行）**，移除 `hasTemplate && isModified` 条件，始终显示重置按钮。

修改 `ParamPanel` 的 build 方法中 `_PanelFooter` 的调用（约第 86-99 行）：
```dart
                    _PanelFooter(
                      hasTemplate: editable != null && original != null,
                      isModified: editable != null &&
                          original != null &&
                          editable != original,
                      onReset: () {
                        if (editable != null && original != null) {
                          // 模板模式：重置为模板原始值
                          ref
                              .read(CaptureState.editableTemplateProvider.notifier)
                              .state = original.copyWith();
                        } else {
                          // 自由模式：重置为默认值并持久化
                          CaptureState.resetFreeModeParams(ref);
                        }
                      },
                      onDone: () => _close(ref),
                    ),
```

修改 `_PanelFooter` 的 build 方法（约第 285 行），将 `if (hasTemplate && isModified)` 改为始终显示：
```dart
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.06),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // 始终显示重置按钮
          GestureDetector(
            onTap: onReset,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.refresh, size: 14, color: Colors.white70),
                  SizedBox(width: 4),
                  Text('重置', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onDone,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 100,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFC9A96E), Color(0xFFB8954E)],
                ),
                borderRadius: BorderRadius.circular(19),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC9A96E).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  '完成',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
```

**3b. 修改 `_CameraTab`（约第 350 行）**，精简为 EV + 闪光：

```dart
class _CameraTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cam = ref.watch(CaptureState.effectiveCameraProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      children: [
        _SectionCard(
          title: '曝光',
          children: [
            _SliderRow(
              label: 'EV',
              value: cam.exposureCompensation,
              min: -3.0,
              max: 3.0,
              divisions: 60,
              display:
                  '${cam.exposureCompensation >= 0 ? '+' : ''}${cam.exposureCompensation.toStringAsFixed(1)}',
              onChanged: (v) => CaptureState.updateCamera(
                  ref, (c) => c.copyWith(exposureCompensation: v)),
            ),
          ],
        ),
        _SectionCard(
          title: '其他',
          children: [
            _PopupRow(
              label: '闪光',
              value: cam.flashMode,
              items: const ['off', 'on', 'auto', 'torch'],
              displayLabels: const {
                'off': '关闭',
                'on': '常亮',
                'auto': '自动',
                'torch': '手电筒',
              },
              onChanged: (v) => CaptureState.updateCamera(
                  ref, (c) => c.copyWith(flashMode: v)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white24, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'EV 可实时影响取景器亮度',
                  style: TextStyle(color: Colors.white24, fontSize: 10, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
```

- [ ] **Step 4: Run flutter analyze to verify no errors**

Run: `flutter analyze lib/features/capture/data/capture_state.dart lib/features/capture/pages/capture_page.dart lib/features/capture/widgets/param_panel.dart`
Expected: 0 errors

- [ ] **Step 5: Commit**

```bash
cd e:/Project/photo_post/lumira_app_flutter
git add lib/features/capture/data/capture_state.dart lib/features/capture/pages/capture_page.dart lib/features/capture/widgets/param_panel.dart
git commit -m "feat: 自由模式参数持久化加载/防抖写入，重置按钮始终显示，相机Tab精简为EV+闪光"
```

---

### Task 5: 拍照后处理增加色彩矩阵与细节效果

**Files:**
- Modify: `lib/features/capture/services/dart_photo_pipeline.dart` (提取公共函数)
- Modify: `lib/features/capture/pages/capture_page.dart` (`_processCaptureInIsolate` 增加后处理)

**Interfaces:**
- Consumes: Task 1 的 `composePostProcessMatrix`
- Produces: 拍照后图像应用色彩/锐化/磨皮/暗角/颗粒

- [ ] **Step 1: 提取 dart_photo_pipeline.dart 中的公共函数**

在 `lib/features/capture/services/dart_photo_pipeline.dart` 中，将 `_applyColorMatrixImg`（约第 555 行）和 `_applyPerPixelEffectsImg`（约第 572 行）从私有改为公共，并添加磨皮和暗角函数。

将 `_applyColorMatrixImg` 改为 `applyColorMatrixImg`（移除下划线）：
```dart
/// 逐像素应用 4×5 ColorMatrix（公共方法，供 isolate 后处理复用）。
img.Image applyColorMatrixImg(img.Image image, List<double> m) {
  for (final p in image) {
    final r = p.r;
    final g = p.g;
    final b = p.b;
    final a = p.a;
    p
      ..r = (m[0] * r + m[1] * g + m[2] * b + m[3] * a + m[4]).clamp(0, 255)
      ..g = (m[5] * r + m[6] * g + m[7] * b + m[8] * a + m[9]).clamp(0, 255)
      ..b = (m[10] * r + m[11] * g + m[12] * b + m[13] * a + m[14]).clamp(0, 255)
      ..a = (m[15] * r + m[16] * g + m[17] * b + m[18] * a + m[19]).clamp(0, 255);
  }
  return image;
}
```

将 `_applyPerPixelEffectsImg` 改为 `applyPerPixelEffectsImg`（移除下划线），并在其后添加磨皮和暗角函数：

```dart
/// Sharpen + Clarity + Grain 逐像素效果（公共方法，供 isolate 后处理复用）。
void applyPerPixelEffectsImg(
  img.Image image, {
  required int sharpen,
  required double? clarity,
  required int grain,
}) {
  // Sharpen（卷积核）
  if (sharpen > 0) {
    final a = (sharpen / 100.0).clamp(0.0, 1.0);
    img.convolution(
      image,
      filter: [0, -a, 0, -a, 1 + 4 * a, -a, 0, -a, 0],
      div: 1.0,
      amount: 1.0,
    );
  }

  // Clarity（中频对比度：原图 - 高斯模糊，再按 amount 混合）
  if (clarity != null && clarity != 0) {
    final amount = (clarity.abs() / 100.0).clamp(0.0, 1.0) * 0.6;
    final sign = clarity > 0 ? 1.0 : -1.0;
    final blurred = img.gaussianBlur(img.Image.from(image), radius: 3);
    for (final p in image) {
      final bp = blurred.getPixel(p.x, p.y);
      p
        ..r = (p.r + (p.r - bp.r) * sign * amount).clamp(0, 255)
        ..g = (p.g + (p.g - bp.g) * sign * amount).clamp(0, 255)
        ..b = (p.b + (p.b - bp.b) * sign * amount).clamp(0, 255);
    }
  }

  // Grain（胶片颗粒噪声）
  if (grain > 0) {
    final intensity = (grain / 100.0).clamp(0.0, 1.0) * 0.25;
    const maxOffset = 64.0;
    final random = math.Random(42);
    for (final p in image) {
      final noise = (random.nextDouble() * 2 - 1) * intensity * maxOffset;
      p
        ..r = (p.r + noise).clamp(0, 255)
        ..g = (p.g + noise).clamp(0, 255)
        ..b = (p.b + noise).clamp(0, 255);
    }
  }
}

/// 磨皮：降采样模糊 + 原图混合（仅 smoothStrength > 0 时调用）
/// 通过降采样到 1/4 尺寸后高斯模糊，再与原图按比例混合，实现快速磨皮。
void applySmoothSkinImg(img.Image image, {required int smoothStrength}) {
  if (smoothStrength <= 0) return;
  final mix = (smoothStrength / 100.0).clamp(0.0, 0.8);

  // 降采样到 1/4 尺寸
  final smallW = (image.width / 4).clamp(1, image.width).toInt();
  final smallH = (image.height / 4).clamp(1, image.height).toInt();
  final small = img.copyResize(image, width: smallW, height: smallH);

  // 高斯模糊（radius 根据 smoothStrength 映射 2-6）
  final radius = 2 + (smoothStrength / 100 * 4).round();
  final blurred = img.gaussianBlur(small, radius: radius);

  // 放大回原尺寸
  final upscaled = img.copyResize(blurred, width: image.width, height: image.height);

  // 与原图混合
  for (final p in image) {
    final bp = upscaled.getPixel(p.x, p.y);
    p
      ..r = (p.r * (1 - mix) + bp.r * mix).clamp(0, 255)
      ..g = (p.g * (1 - mix) + bp.g * mix).clamp(0, 255)
      ..b = (p.b * (1 - mix) + bp.b * mix).clamp(0, 255);
  }
}

/// 暗角：径向渐变暗化四角（仅 vignette > 0 时调用）
void applyVignetteImg(img.Image image, {required int vignette}) {
  if (vignette <= 0) return;
  final strength = (vignette / 100.0).clamp(0.0, 1.0) * 0.6;
  final centerX = image.width / 2;
  final centerY = image.height / 2;
  // 对角线距离的平方
  final maxDistSq = centerX * centerX + centerY * centerY;

  for (final p in image) {
    final dx = p.x - centerX;
    final dy = p.y - centerY;
    final distSq = dx * dx + dy * dy;
    // 距离比例 0-1（中心=0，四角=1）
    final ratio = distSq / maxDistSq;
    // 仅在 ratio > 0.3 时开始暗化（中心 30% 区域不受影响）
    if (ratio > 0.3) {
      final darken = ((ratio - 0.3) / 0.7) * strength;
      p
        ..r = (p.r * (1 - darken)).clamp(0, 255)
        ..g = (p.g * (1 - darken)).clamp(0, 255)
        ..b = (p.b * (1 - darken)).clamp(0, 255);
    }
  }
}
```

同时更新文件内所有调用 `_applyColorMatrixImg` 和 `_applyPerPixelEffectsImg` 的地方，改为不带下划线的公共方法名（搜索替换）。

- [ ] **Step 2: 修改 _processCaptureInIsolate 增加后处理**

在 `lib/features/capture/pages/capture_page.dart` 中，修改 `_CaptureProcessParams` 类和 `_processCaptureInIsolate` 函数。

首先找到 `_CaptureProcessParams` 类定义，添加 `postProcess` 字段：

```dart
class _CaptureProcessParams {
  const _CaptureProcessParams({
    required this.inputPath,
    required this.targetRatio,
    required this.isPortrait,
    required this.isFront,
    required this.postProcess,
  });
  final String inputPath;
  final double targetRatio;
  final bool isPortrait;
  final bool isFront;
  final PostProcess postProcess;
}
```

修改 `_processCaptureInIsolate` 函数，在镜像后、限制尺寸前插入色彩和细节处理：

```dart
Future<String> _processCaptureInIsolate(_CaptureProcessParams params) async {
  try {
    final bytes = await File(params.inputPath).readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) return params.inputPath;

    // 1. 方向对齐
    final jpegIsLandscape = image.width > image.height;
    final needRotate = (params.isPortrait && jpegIsLandscape) ||
        (!params.isPortrait && !jpegIsLandscape);
    if (needRotate) {
      final angle = params.isPortrait ? 90 : 270;
      image = img.copyRotate(image, angle: angle);
    }

    // 2. cover 裁切到目标比例
    final imgRatio = image.width / image.height;
    int cropW, cropH, cropX, cropY;
    if (imgRatio > params.targetRatio) {
      cropH = image.height;
      cropW = (cropH * params.targetRatio).round();
      cropX = ((image.width - cropW) / 2).round();
      cropY = 0;
    } else {
      cropW = image.width;
      cropH = (cropW / params.targetRatio).round();
      cropX = 0;
      cropY = ((image.height - cropH) / 2).round();
    }
    var result = img.copyCrop(image,
        x: cropX, y: cropY, width: cropW, height: cropH);

    // 3. 前置镜像
    if (params.isFront) {
      result = img.flip(result, direction: img.FlipDirection.horizontal);
    }

    // 4. 应用色彩矩阵（亮度/对比度/饱和度/色温/色调等）
    final matrix = composePostProcessMatrix(params.postProcess);
    result = applyColorMatrixImg(result, matrix);

    // 5. 细节效果：锐化 + 清晰度 + 颗粒
    applyPerPixelEffectsImg(
      result,
      sharpen: params.postProcess.sharpen,
      clarity: params.postProcess.color.clarity,
      grain: params.postProcess.grain,
    );

    // 6. 磨皮
    applySmoothSkinImg(result, smoothStrength: params.postProcess.smoothStrength);

    // 7. 暗角
    applyVignetteImg(result, vignette: params.postProcess.vignette);

    // 8. 限制最大边长到 2048px
    const maxDim = 2048;
    if (result.width > maxDim || result.height > maxDim) {
      final scale = maxDim / (result.width > result.height ? result.width : result.height);
      result = img.copyResize(
        result,
        width: (result.width * scale).round(),
        height: (result.height * scale).round(),
      );
    }

    // 9. 编码保存
    final encoded = img.encodeJpg(result, quality: 90);
    await File(params.inputPath).writeAsBytes(encoded);
    return params.inputPath;
  } catch (_) {
    return params.inputPath;
  }
}
```

在文件顶部添加 import：
```dart
import '../services/dart_photo_pipeline.dart' show applyColorMatrixImg, applyPerPixelEffectsImg, applySmoothSkinImg, applyVignetteImg;
import '../domain/filter_recipe.dart' show composePostProcessMatrix;
```

修改 `_onCapture` 方法中调用 `_processCaptureQueue.add` 的地方，传入 `postProcess`：

找到 `_processCaptureQueue.add(_CaptureProcessParams(` 调用，添加 `postProcess` 参数：
```dart
      _processCaptureQueue.add(_CaptureProcessParams(
        inputPath: result.filePath,
        targetRatio: targetRatio,
        isPortrait: isPortrait,
        isFront: facing == 'front',
        postProcess: ref.read(CaptureState.effectivePostProcessProvider),
      ));
```

- [ ] **Step 3: Run flutter analyze to verify no errors**

Run: `flutter analyze lib/features/capture/services/dart_photo_pipeline.dart lib/features/capture/pages/capture_page.dart`
Expected: 0 errors

- [ ] **Step 4: Commit**

```bash
cd e:/Project/photo_post/lumira_app_flutter
git add lib/features/capture/services/dart_photo_pipeline.dart lib/features/capture/pages/capture_page.dart
git commit -m "feat: 拍照后处理增加色彩矩阵、锐化、磨皮、暗角、颗粒效果"
```

---

### Task 6: 补光颜色合并显示 + 长按删改 + 操作提示

**Files:**
- Modify: `lib/features/capture/data/custom_fill_light_colors.dart` (新增 update 方法)
- Modify: `lib/features/capture/pages/capture_page.dart` (`_CustomColorsRow` 重构、`_FillLightPanel` 合并列表)

**Interfaces:**
- Consumes: 无
- Produces: 合并的补光颜色列表、长按删改交互

- [ ] **Step 1: 修改 custom_fill_light_colors.dart 新增 update 方法**

在 `lib/features/capture/data/custom_fill_light_colors.dart` 的 `CustomFillLightColorsNotifier` 类中，`remove` 方法后添加：

```dart
  /// 修改已有颜色（按 name 匹配，可修改名称和/或颜色）
  Future<void> update(String name, {String? newName, Color? newColor}) async {
    final index = state.indexWhere((e) => e.name == name);
    if (index == -1) return;
    final old = state[index];
    final updated = CustomFillLightColor(
      name: newName ?? old.name,
      color: newColor ?? old.color,
    );
    final newList = List<CustomFillLightColor>.from(state);
    newList[index] = updated;
    state = newList;
    await _persist();
  }
```

- [ ] **Step 2: 修改 _FillLightPanel 合并预设与自定义颜色列表**

在 `lib/features/capture/pages/capture_page.dart` 中，修改 `_FillLightPanel` 的 build 方法。

找到「预设色行」部分（约第 1080 行），将系统预设和自定义颜色合并为一个 ListView。替换 `_CustomColorsRow` 的调用位置，将其合并到预设色行之后但作为同一列表的延续。

修改 `_FillLightPanel` 的 build 方法中 `ringExpanded` 块（约第 1173 行），替换为：

```dart
          if (ringExpanded) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Center(
                child: _SquareColorPicker(
                  onColorChanged: (c) {
                    ref.read(CaptureState.fillLightColorProvider.notifier).state = c;
                  },
                ),
              ),
            ),
            // 保存颜色行（合并系统预设与用户保存颜色）
            _SaveColorsRow(
              onPick: (c) {
                ref.read(CaptureState.fillLightEnabledProvider.notifier).state = true;
                ref.read(CaptureState.fillLightColorProvider.notifier).state = c;
              },
              onAdd: (name, c) {
                ref.read(customFillLightColorsProvider.notifier).add(name, c);
              },
            ),
          ],
```

- [ ] **Step 3: 新增 _SaveColorsRow 替代 _CustomColorsRow**

在 `lib/features/capture/pages/capture_page.dart` 中，找到 `_CustomColorsRow` 类定义（约第 1501 行），将其替换为 `_SaveColorsRow`：

```dart
/// 保存颜色行：合并系统预设与用户保存颜色为一个列表，
/// 用户保存的颜色可长按修改或删除。
class _SaveColorsRow extends ConsumerStatefulWidget {
  const _SaveColorsRow({
    required this.onPick,
    required this.onAdd,
  });
  final ValueChanged<Color> onPick;
  final void Function(String name, Color color) onAdd;

  @override
  ConsumerState<_SaveColorsRow> createState() => _SaveColorsRowState();
}

class _SaveColorsRowState extends ConsumerState<_SaveColorsRow> {
  bool _showNameInput = false;
  final _nameController = TextEditingController();
  bool _hintShown = false;

  @override
  void initState() {
    super.initState();
    _loadHintState();
  }

  Future<void> _loadHintState() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/lumira_fill_light_hint.json');
      if (await file.exists()) {
        if (mounted) setState(() => _hintShown = true);
      }
    } catch (_) {}
  }

  Future<void> _markHintShown() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/lumira_fill_light_hint.json');
      await file.writeAsString('{"shown":true}');
      if (mounted) setState(() => _hintShown = true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // 系统预设颜色（与 _FillLightPanel._presets 一致）
  static const _presets = [
    _FillLightPreset('暖白', Color(0xFFFFE5B4), 0.6),
    _FillLightPreset('冷白', Color(0xFFE0F0FF), 0.6),
    _FillLightPreset('黄金', Color(0xFFFFB347), 0.7),
    _FillLightPreset('柔粉', Color(0xFFFFC0CB), 0.6),
    _FillLightPreset('青蓝', Color(0xFF8FD3F4), 0.5),
    _FillLightPreset('紫', Color(0xFFD8BFD8), 0.5),
  ];

  void _showEditSheet(String name, Color color) {
    _markHintShown();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFFC9A96E), size: 20),
              title: const Text('修改名称', style: TextStyle(color: Colors.white70, fontSize: 14)),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(name);
              },
            ),
            ListTile(
              leading: const Icon(Icons.color_lens, color: Color(0xFFC9A96E), size: 20),
              title: const Text('修改颜色', style: TextStyle(color: Colors.white70, fontSize: 14)),
              onTap: () {
                Navigator.pop(ctx);
                // 用当前颜色打开色环
                ref.read(CaptureState.fillLightColorProvider.notifier).state = color;
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              title: const Text('删除', style: TextStyle(color: Colors.redAccent, fontSize: 14)),
              onTap: () {
                ref.read(customFillLightColorsProvider.notifier).remove(name);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(String oldName) {
    final controller = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2C),
        title: const Text('修改名称', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: '输入新名称',
            hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFC9A96E))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != oldName) {
                ref.read(customFillLightColorsProvider.notifier).update(oldName, newName: newName);
              }
              Navigator.pop(ctx);
            },
            child: const Text('确定', style: TextStyle(color: Color(0xFFC9A96E))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customColors = ref.watch(customFillLightColorsProvider);
    final currentColor = ref.watch(CaptureState.fillLightColorProvider);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行 + 保存按钮
          Row(
            children: [
              const Text(
                '保存颜色',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _showNameInput = !_showNameInput),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bookmark_add_outlined, size: 12, color: const Color(0xFFC9A96E)),
                      const SizedBox(width: 3),
                      Text(
                        '保存当前',
                        style: TextStyle(color: const Color(0xFFC9A96E), fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // 命名输入框
          if (_showNameInput) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: currentColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: '为该颜色命名（如：日落金）',
                      hintStyle: TextStyle(color: Colors.white30, fontSize: 11),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Colors.white24, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: const Color(0xFFC9A96E), width: 1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    final name = _nameController.text.trim();
                    if (name.isEmpty) return;
                    widget.onAdd(name, currentColor);
                    _nameController.clear();
                    setState(() => _showNameInput = false);
                    _markHintShown();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC9A96E),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '保存',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
          // 合并的颜色列表：系统预设 + 用户保存
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // 系统预设颜色（不可删改）
                ..._presets.map((p) {
                  final isSelected = _colorMatch(currentColor, p.color);
                  return _PresetColorDot(
                    preset: p,
                    selected: isSelected,
                    onTap: () => widget.onPick(p.color),
                  );
                }),
                // 分隔符
                if (customColors.isNotEmpty)
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    color: Colors.white12,
                  ),
                // 用户保存颜色（可长按删改）
                ...customColors.map((c) {
                  final isSelected = _colorMatch(currentColor, c.color);
                  return _SavedColorDot(
                    name: c.name,
                    color: c.color,
                    selected: isSelected,
                    onTap: () => widget.onPick(c.color),
                    onLongPress: () => _showEditSheet(c.name, c.color),
                  );
                }),
              ],
            ),
          ),
          // 操作提示（首次显示，用户长按或保存后消失）
          if (!_hintShown)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white30, size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '长按保存的颜色可修改或删除',
                      style: TextStyle(color: Colors.white30, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool _colorMatch(Color a, Color b) => a.value == b.value;
}

/// 用户保存的颜色圆点（支持长按）
class _SavedColorDot extends StatelessWidget {
  const _SavedColorDot({
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });
  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 44,
        margin: const EdgeInsets.only(right: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? const Color(0xFFC9A96E) : Colors.white24,
                  width: selected ? 2 : 1,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? const Color(0xFFC9A96E) : Colors.white54,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

注意：原 `_CustomColorsRow` 和 `_CustomColorDot` 类可以删除（被 `_SaveColorsRow` 和 `_SavedColorDot` 替代）。搜索文件中所有 `_CustomColorsRow` 的引用并替换为 `_SaveColorsRow`。

在文件顶部添加 import（如尚未有 path_provider）：
```dart
import 'package:path_provider/path_provider.dart';
import 'dart:io';
```

- [ ] **Step 4: Run flutter analyze to verify no errors**

Run: `flutter analyze lib/features/capture/data/custom_fill_light_colors.dart lib/features/capture/pages/capture_page.dart`
Expected: 0 errors

- [ ] **Step 5: Commit**

```bash
cd e:/Project/photo_post/lumira_app_flutter
git add lib/features/capture/data/custom_fill_light_colors.dart lib/features/capture/pages/capture_page.dart
git commit -m "feat: 补光颜色合并为单列表，支持长按删改，首次显示操作提示"
```

---

## Self-Review

**1. Spec coverage:**
- 相机Tab精简为EV+闪光 → Task 4 Step 3b ✓
- 修复饱和度色偏 → Task 1 ✓
- 色彩矩阵优化（高光/阴影等） → Task 1 修复饱和度，Task 5 应用矩阵到拍照后处理。spec 提到"优化高光/阴影矩阵"但ColorFilter.matrix是线性变换无法做非线性色调映射，预览端保持现有近似，拍照端通过image包实现更精确。Task 5 已覆盖拍照端 ✓
- 细节Tab锐化/磨皮/暗角/颗粒实现 → Task 5 ✓
- 参数持久化（自由模式） → Task 2(序列化) + Task 3(DAO) + Task 4(加载/防抖) ✓
- 重置按钮始终显示 → Task 4 Step 3a ✓
- 补光颜色合并为单列表 → Task 6 ✓
- 长按删改 → Task 6 ✓
- 操作提示 → Task 6 ✓

**2. Placeholder scan:** 无 TBD/TODO，所有步骤含完整代码 ✓

**3. Type consistency:**
- `applyColorMatrixImg` / `applyPerPixelEffectsImg` / `applySmoothSkinImg` / `applyVignetteImg` 在 Task 5 定义，Task 5 内使用 ✓
- `CameraParams.toJson/fromJson` 在 Task 2 定义，Task 3 DAO 使用 ✓
- `setFreeModeCamera` 等在 Task 3 定义，Task 4 capture_state 使用 ✓
- `resetFreeModeParams` 在 Task 4 定义，Task 4 param_panel 使用 ✓
- `_SaveColorsRow` 在 Task 6 定义，Task 6 内使用 ✓
- `_CaptureProcessParams.postProcess` 在 Task 5 定义，Task 5 内使用 ✓
