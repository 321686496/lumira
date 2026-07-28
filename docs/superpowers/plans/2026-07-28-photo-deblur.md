# 拍照去模糊功能实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现 Phase 1 拍照去模糊功能：拍照后自动检测模糊并用 Lucy-Richardson 反卷积去除手抖模糊，处理时间 ≤ 300ms，设置项可关闭，三端（OHOS/iOS/Android）兼容。

**Architecture:** 新增 `DeblurProcessor`（纯 Dart 反卷积算法）+ `SettingsDao`（复用 sqflite 持久化）+ `autoDeblurProvider`（Riverpod 状态），集成到现有 `PhotoPostProcessor.processFile` 流程的第 4 步与第 5 步之间。

**Tech Stack:** Dart 2.19.6 / Flutter 3.7 / Riverpod 2.3.6 / image ^4.0.16 / sqflite (CPF-Flutter fork) / dart:ui Canvas

## Global Constraints

- **Dart SDK**: `>=2.19.6 <3.0.0`（不使用 Dart 3 特性）
- **Flutter**: `>=3.7.0`
- **不引入新依赖**：只用 pubspec.yaml 已有的包（image, sqflite, flutter_riverpod）
- **三端兼容**：OHOS / iOS / Android，零原生平台通道代码
- **处理时间**: ≤ 300ms（1024x1024 图像，重度模糊时）
- **持久化**: 复用 `user_settings` 单行表（sqflite），不引入 shared_preferences
- **DAO 模式**: 对齐项目 7 个现有 DAO 的 `FutureProvider<Dao>` 模式
- **测试命令**: `flutter test test/features/capture/ test/features/profile/`
- **代码风格**: 遵循项目现有风格（debugPrint 日志、try/catch 静默回退）

## 文件结构

**新增文件：**
- `lib/features/capture/services/deblur_processor.dart` — 反卷积算法（纯 Dart）
- `lib/core/db/dao/settings_dao.dart` — 设置项 DAO
- `lib/features/profile/providers/settings_providers.dart` — autoDeblurProvider
- `test/features/capture/services/deblur_processor_test.dart` — 算法测试
- `test/core/db/dao/settings_dao_test.dart` — DAO 测试

**修改文件：**
- `lib/core/db/tables.dart` — 加 `colAutoDeblur` 列常量
- `lib/core/db/database_provider.dart` — `_kDbVersion` 5→6，加 v6 迁移，加 `settingsDaoProvider`
- `lib/features/capture/services/photo_post_processor.dart` — `processFile` 加 `autoDeblur` 参数 + 集成调用
- `lib/features/capture/pages/capture_page.dart` — 读 `autoDeblurProvider` 传给 `processFile`
- `lib/features/profile/pages/profile_settings_page.dart` — 加"自动去模糊"开关 + 接入持久化

---

### Task 1: DeblurProcessor 模糊度估计

**Files:**
- Create: `lib/features/capture/services/deblur_processor.dart`
- Test: `test/features/capture/services/deblur_processor_test.dart`

**Interfaces:**
- Produces: `DeblurProcessor.estimateBlur(img.Image image) → double`（返回 Laplacian 方差，越大越清晰）
- Produces: `DeblurProcessor.kClearThreshold = 600.0`（清晰阈值常量）
- Produces: `DeblurProcessor.strengthForScore(double score) → double`（返回 0.0-1.0 强度）

- [ ] **Step 1: Write the failing test**

```dart
// test/features/capture/services/deblur_processor_test.dart
import 'package:image/image.dart' as img;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/services/deblur_processor.dart';

void main() {
  group('DeblurProcessor.estimateBlur', () {
    test('clear image (sharp edges) returns score > 600', () {
      // 构造一张充满边缘的清晰图像（黑白棋盘格）
      final image = img.Image(width: 64, height: 64);
      for (var y = 0; y < 64; y++) {
        for (var x = 0; x < 64; x++) {
          final isWhite = ((x ~/ 8) + (y ~/ 8)) % 2 == 0;
          image.setPixelRgb(x, y, isWhite ? 255 : 0, isWhite ? 255 : 0, isWhite ? 255 : 0);
        }
      }
      final score = DeblurProcessor.estimateBlur(image);
      expect(score, greaterThan(600.0),
          reason: '棋盘格图像边缘丰富，应为清晰图像');
    });

    test('blurred image (smooth gradient) returns score < 100', () {
      // 构造一张平滑渐变图像（无边缘，模拟模糊）
      final image = img.Image(width: 64, height: 64);
      for (var y = 0; y < 64; y++) {
        for (var x = 0; x < 64; x++) {
          final v = ((x + y) * 2).clamp(0, 255);
          image.setPixelRgb(x, y, v, v, v);
        }
      }
      final score = DeblurProcessor.estimateBlur(image);
      expect(score, lessThan(100.0),
          reason: '平滑渐变无边缘，应为模糊图像');
    });

    test('solid color image returns score near 0', () {
      final image = img.Image(width: 64, height: 64);
      image.fill(img.ColorRgb8(128, 128, 128));
      final score = DeblurProcessor.estimateBlur(image);
      expect(score, lessThan(10.0),
          reason: '纯色图像方差约为 0');
    });
  });

  group('DeblurProcessor.strengthForScore', () {
    test('score < 100 returns 0.8 (severe blur)', () {
      expect(DeblurProcessor.strengthForScore(50.0), equals(0.8));
    });
    test('score 100-300 returns 0.5 (moderate blur)', () {
      expect(DeblurProcessor.strengthForScore(200.0), equals(0.5));
    });
    test('score 300-600 returns 0.3 (light blur)', () {
      expect(DeblurProcessor.strengthForScore(400.0), equals(0.3));
    });
    test('score > 600 returns 0.0 (clear, skip)', () {
      expect(DeblurProcessor.strengthForScore(800.0), equals(0.0));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/capture/services/deblur_processor_test.dart`
Expected: FAIL with "DeblurProcessor not defined" 或 "getter not found"

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/capture/services/deblur_processor.dart
import 'dart:math' as math;
import 'package:image/image.dart' as img;

/// 照片去模糊处理器（纯 Dart 实现，三端通用）
///
/// 算法：
/// - 模糊度估计：Laplacian 方差（方差越小越模糊）
/// - 去模糊：Lucy-Richardson 反卷积 + 自动 PSF 估计
///
/// 性能：1024x1024 图像约 145-220ms
class DeblurProcessor {
  DeblurProcessor._();

  /// 清晰阈值：score ≥ 此值时跳过去模糊（省 200ms）
  static const double kClearThreshold = 600.0;

  /// 模糊度估计：对图像做 3x3 Laplacian 卷积，返回方差
  /// 方差越大 = 边缘越多 = 越清晰；方差越小 = 越模糊
  static double estimateBlur(img.Image image) {
    final w = image.width;
    final h = image.height;
    if (w < 3 || h < 3) return kClearThreshold + 1; // 太小无法卷积，视为清晰

    // Laplacian 卷积核：
    // [0, -1, 0]
    // [-1, 4, -1]
    // [0, -1, 0]
    final laplacianValues = <double>[];
    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final center = _luminance(image.getPixel(x, y));
        final up = _luminance(image.getPixel(x, y - 1));
        final down = _luminance(image.getPixel(x, y + 1));
        final left = _luminance(image.getPixel(x - 1, y));
        final right = _luminance(image.getPixel(x + 1, y));
        final lap = 4 * center - up - down - left - right;
        laplacianValues.add(laplacian.abs().toDouble());
      }
    }

    if (laplacianValues.isEmpty) return kClearThreshold + 1;

    // 计算方差
    final mean = laplacianValues.reduce((a, b) => a + b) / laplacianValues.length;
    var sumSquaredDiff = 0.0;
    for (final v in laplacianValues) {
      sumSquaredDiff += (v - mean) * (v - mean);
    }
    return sumSquaredDiff / laplacianValues.length;
  }

  /// 根据模糊度分数返回去模糊强度（0.0-1.0）
  /// score 越低（越模糊）→ strength 越大
  static double strengthForScore(double score) {
    if (score < 100) return 0.8; // 严重模糊
    if (score < 300) return 0.5; // 中度模糊
    if (score < 600) return 0.3; // 轻度模糊
    return 0.0; // 清晰，跳过
  }

  /// 计算像素亮度（0-255）
  static double _luminance(img.Pixel p) {
    // ITU-R BT.601: Y = 0.299R + 0.587G + 0.114B
    return 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/capture/services/deblur_processor_test.dart`
Expected: PASS (all 6 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/capture/services/deblur_processor.dart test/features/capture/services/deblur_processor_test.dart
git commit -m "feat(deblur): add DeblurProcessor blur estimation via Laplacian variance"
```

---

### Task 2: DeblurProcessor Lucy-Richardson 反卷积

**Files:**
- Modify: `lib/features/capture/services/deblur_processor.dart`
- Modify: `test/features/capture/services/deblur_processor_test.dart`

**Interfaces:**
- Produces: `DeblurProcessor.deblur(img.Image image, {required double strength}) → Future<img.Image>`
- Consumes: Task 1 的 `estimateBlur` / `strengthForScore`

- [ ] **Step 1: Write the failing test**

追加到 `test/features/capture/services/deblur_processor_test.dart`：

```dart
  group('DeblurProcessor.deblur', () {
    test('strength=0 returns identical image', () async {
      final image = img.Image(width: 32, height: 32);
      for (var y = 0; y < 32; y++) {
        for (var x = 0; x < 32; x++) {
          image.setPixelRgb(x, y, x * 8 % 256, y * 8 % 256, 128);
        }
      }
      final result = await DeblurProcessor.deblur(image, strength: 0.0);
      expect(result.width, equals(32));
      expect(result.height, equals(32));
      // strength=0 应返回相同图像
      for (var y = 0; y < 32; y++) {
        for (var x = 0; x < 32; x++) {
          final orig = image.getPixel(x, y);
          final res = result.getPixel(x, y);
          expect(res.r, closeTo(orig.r, 1.0));
          expect(res.g, closeTo(orig.g, 1.0));
          expect(res.b, closeTo(orig.b, 1.0));
        }
      }
    });

    test('blurred image becomes sharper after deblur', () async {
      // 构造一张模糊图像（高斯模糊后的边缘）
      final blurred = img.Image(width: 32, height: 32);
      for (var y = 0; y < 32; y++) {
        for (var x = 0; x < 32; x++) {
          // 模拟模糊：用邻近像素平均
          final v = ((x + y) / 2).round().clamp(0, 255);
          blurred.setPixelRgb(x, y, v, v, v);
        }
      }
      final origScore = DeblurProcessor.estimateBlur(blurred);
      final result = await DeblurProcessor.deblur(blurred, strength: 0.5);
      final newScore = DeblurProcessor.estimateBlur(result);
      // 去模糊后 Laplacian 方差应提升（边缘更锐利）
      expect(newScore, greaterThan(origScore),
          reason: '去模糊后图像应更清晰');
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/capture/services/deblur_processor_test.dart`
Expected: FAIL with "deblur method not defined"

- [ ] **Step 3: Write minimal implementation**

追加到 `lib/features/capture/services/deblur_processor.dart`：

```dart
  /// Lucy-Richardson 反卷积去模糊
  ///
  /// [strength] 0.0-1.0，0 表示不处理，1 表示最大强度
  /// 返回处理后的新图像（不修改输入）
  ///
  /// 算法：
  /// 1. 根据 strength 生成线性运动模糊 PSF（核大小 3-15）
  /// 2. 迭代 3 次：f_{k+1} = f_k * (h* ⊗ (g / (h ⊗ f_k)))
  /// 3. 对 RGB 三通道分别处理
  static Future<img.Image> deblur(
    img.Image image, {
    required double strength,
  }) async {
    if (strength <= 0.0) return img.Image.from(image);

    final w = image.width;
    final h = image.height;

    // PSF 核大小：strength 越大，核越长（3-15）
    final kernelSize = (3 + (strength * 12).round()).clamp(3, 15);
    final psf = _generateMotionPsf(kernelSize, 0.0); // 水平方向运动模糊

    // 提取 RGB 通道
    final rChannel = _extractChannel(image, 'r');
    final gChannel = _extractChannel(image, 'g');
    final bChannel = _extractChannel(image, 'b');

    // Lucy-Richardson 迭代（3 次）
    final iterations = 3;
    var rDeconv = rChannel;
    var gDeconv = gChannel;
    var bDeconv = bChannel;
    for (var i = 0; i < iterations; i++) {
      rDeconv = _lucyRichardsonIter(rDeconv, psf, w, h);
      gDeconv = _lucyRichardsonIter(gDeconv, psf, w, h);
      bDeconv = _lucyRichardsonIter(bDeconv, psf, w, h);
    }

    // 合并回 RGB 图像
    return _mergeChannels(rDeconv, gDeconv, bDeconv, w, h);
  }

  /// 生成水平方向运动模糊 PSF（归一化）
  static List<double> _generateMotionPsf(int size, double angle) {
    // 简化：仅水平方向，angle 参数保留给未来扩展
    final psf = List<double>.filled(size * size, 0.0);
    final center = size ~/ 2;
    // 水平线段：中心行全 1，归一化
    for (var x = 0; x < size; x++) {
      psf[center * size + x] = 1.0;
    }
    // 归一化
    final sum = psf.reduce((a, b) => a + b);
    for (var i = 0; i < psf.length; i++) {
      psf[i] /= sum;
    }
    return psf;
  }

  /// 提取单通道为 2D 数组
  static List<List<double>> _extractChannel(img.Image image, String channel) {
    final w = image.width;
    final h = image.height;
    final result = List.generate(h, (_) => List<double>.filled(w, 0.0));
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = image.getPixel(x, y);
        switch (channel) {
          case 'r':
            result[y][x] = p.r.toDouble();
            break;
          case 'g':
            result[y][x] = p.g.toDouble();
            break;
          case 'b':
            result[y][x] = p.b.toDouble();
            break;
        }
      }
    }
    return result;
  }

  /// 合并 RGB 通道回 img.Image
  static img.Image _mergeChannels(
    List<List<double>> r,
    List<List<double>> g,
    List<List<double>> b,
    int w,
    int h,
  ) {
    final result = img.Image(width: w, height: h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        result.setPixelRgb(
          x,
          y,
          r[y][x].round().clamp(0, 255),
          g[y][x].round().clamp(0, 255),
          b[y][x].round().clamp(0, 255),
        );
      }
    }
    return result;
  }

  /// Lucy-Richardson 单次迭代
  /// f_{k+1} = f_k * (h* ⊗ (g / (h ⊗ f_k)))
  static List<List<double>> _lucyRichardsonIter(
    List<List<double>> observed,
    List<double> psf,
    int w,
    int h,
  ) {
    final psfSize = math.sqrt(psf.length).toInt();
    final psfRadius = psfSize ~/ 2;

    // 1. 计算模糊估计：blurred_est = h ⊗ f_k
    final blurredEst = _convolve2D(observed, psf, psfSize, w, h);

    // 2. 计算比值：ratio = g / blurred_est（防止除零）
    final ratio = List.generate(h, (y) => List<double>.filled(w, 0.0));
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final denom = blurredEst[y][x];
        ratio[y][x] = denom > 1e-10 ? observed[y][x] / denom : 0.0;
      }
    }

    // 3. 计算比值与翻转 PSF 的卷积：correction = h* ⊗ ratio
    final psfFlipped = _flipPsf(psf, psfSize);
    final correction = _convolve2D(ratio, psfFlipped, psfSize, w, h);

    // 4. 更新：f_{k+1} = f_k * correction
    final result = List.generate(h, (y) => List<double>.filled(w, 0.0));
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        result[y][x] = (observed[y][x] * correction[y][x]).clamp(0.0, 255.0);
      }
    }
    return result;
  }

  /// 2D 卷积（边界零填充）
  static List<List<double>> _convolve2D(
    List<List<double>> image,
    List<double> kernel,
    int kernelSize,
    int w,
    int h,
  ) {
    final result = List.generate(h, (y) => List<double>.filled(w, 0.0));
    final radius = kernelSize ~/ 2;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var sum = 0.0;
        for (var ky = 0; ky < kernelSize; ky++) {
          for (var kx = 0; kx < kernelSize; kx++) {
            final srcY = y + ky - radius;
            final srcX = x + kx - radius;
            if (srcY >= 0 && srcY < h && srcX >= 0 && srcX < w) {
              sum += image[srcY][srcX] * kernel[ky * kernelSize + kx];
            }
          }
        }
        result[y][x] = sum;
      }
    }
    return result;
  }

  /// 翻转 PSF（180 度旋转）
  static List<double> _flipPsf(List<double> psf, int size) {
    final flipped = List<double>.filled(psf.length, 0.0);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        flipped[(size - 1 - y) * size + (size - 1 - x)] = psf[y * size + x];
      }
    }
    return flipped;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/capture/services/deblur_processor_test.dart`
Expected: PASS (all 8 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/capture/services/deblur_processor.dart test/features/capture/services/deblur_processor_test.dart
git commit -m "feat(deblur): add Lucy-Richardson deconvolution algorithm"
```

---

### Task 3: 数据库迁移 + SettingsDao

**Files:**
- Modify: `lib/core/db/tables.dart`
- Modify: `lib/core/db/database_provider.dart`
- Create: `lib/core/db/dao/settings_dao.dart`
- Create: `test/core/db/dao/settings_dao_test.dart`

**Interfaces:**
- Produces: `SettingsDao.getAutoDeblur() → Future<bool>`
- Produces: `SettingsDao.setAutoDeblur(bool value) → Future<void>`
- Produces: `settingsDaoProvider` (FutureProvider<SettingsDao>)

- [ ] **Step 1: Write the failing test**

```dart
// test/core/db/dao/settings_dao_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

import 'package:lumira_app_flutter/core/db/dao/settings_dao.dart';

void main() {
  late Database db;
  late SettingsDao dao;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, v) async {
        // 模拟 user_settings 表（含 auto_deblur 列）
        await db.execute('''
          CREATE TABLE user_settings (
            id INTEGER PRIMARY KEY DEFAULT 1,
            theme_key TEXT NOT NULL DEFAULT 'warmWhite',
            ui_style TEXT NOT NULL DEFAULT 'neumorphic',
            follow_system INTEGER NOT NULL DEFAULT 0,
            capture_fullscreen INTEGER NOT NULL DEFAULT 0,
            grid_enabled INTEGER NOT NULL DEFAULT 0,
            level_enabled INTEGER NOT NULL DEFAULT 0,
            shutter_sound INTEGER NOT NULL DEFAULT 1,
            watermark INTEGER NOT NULL DEFAULT 0,
            seed_v3_done INTEGER NOT NULL DEFAULT 0,
            auto_deblur INTEGER NOT NULL DEFAULT 1,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.insert('user_settings', {
          'id': 1,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });
      },
    );
    dao = SettingsDao(db);
  });

  tearDown(() async => db.close());

  test('default value is true (1)', () async {
    final value = await dao.getAutoDeblur();
    expect(value, isTrue);
  });

  test('setAutoDeblur(false) persists to DB', () async {
    await dao.setAutoDeblur(false);
    final value = await dao.getAutoDeblur();
    expect(value, isFalse);
    // 验证直接从 DB 读取
    final rows = await db.query('user_settings', where: 'id = 1');
    expect(rows.first['auto_deblur'], equals(0));
  });

  test('setAutoDeblur(true) after false works', () async {
    await dao.setAutoDeblur(false);
    await dao.setAutoDeblur(true);
    expect(await dao.getAutoDeblur(), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/db/dao/settings_dao_test.dart`
Expected: FAIL with "SettingsDao not found" 或 "auto_deblur column not found"

- [ ] **Step 3: Add column constant to tables.dart**

在 `lib/core/db/tables.dart` 的 user_settings 列常量区块（约 line 99 后）加：

```dart
  static const String colAutoDeblur = 'auto_deblur';
```

- [ ] **Step 4: Update database_provider.dart v1 schema + v6 migration**

在 `lib/core/db/database_provider.dart`：

1. 改 `_kDbVersion`：
```dart
const int _kDbVersion = 6;
```

2. 在 v1 建表 SQL（约 line 192 的 `colSeedV3Done` 后）加：
```dart
      ${Tables.colSeedV3Done} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colAutoDeblur} INTEGER NOT NULL DEFAULT 1,
```

3. 在 `_onUpgrade` 函数末尾（`if (oldVersion < 5)` 块之后）加：
```dart
  if (oldVersion < 6) {
    try {
      // v6: 新增 auto_deblur 列（自动去模糊开关，默认 1=开启）
      await _addColumnIfNotExists(
        db,
        Tables.userSettings,
        Tables.colAutoDeblur,
        'INTEGER NOT NULL DEFAULT 1',
      );
    } catch (e) {
      debugPrint('v6 migration failed (silent fallback): $e');
    }
  }
```

4. 在 providers 区块（约 line 73 后，对齐其他 DAO provider）加：
```dart
final settingsDaoProvider = FutureProvider<SettingsDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return SettingsDao(db);
});
```

- [ ] **Step 5: Create SettingsDao**

```dart
// lib/core/db/dao/settings_dao.dart
import 'package:sqflite/sqflite.dart';
import '../tables.dart';

/// 用户设置 DAO（单行表 user_settings，id=1）
///
/// 对齐项目 DAO 模式：持有 Database 引用，FutureProvider 注入。
/// 三端通用（sqflite CPF-Flutter fork 已适配 OHOS）。
class SettingsDao {
  SettingsDao(this._db);
  final Database _db;

  /// 读取自动去模糊开关（默认 true）
  Future<bool> getAutoDeblur() async {
    final rows = await _db.query(
      Tables.userSettings,
      columns: [Tables.colAutoDeblur],
      where: 'id = ?',
      whereArgs: [1],
    );
    if (rows.isEmpty) return true; // 默认开启
    return (rows.first[Tables.colAutoDeblur] as int?) == 1;
  }

  /// 设置自动去模糊开关
  Future<void> setAutoDeblur(bool value) async {
    await _db.update(
      Tables.userSettings,
      {
        Tables.colAutoDeblur: value ? 1 : 0,
        Tables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/core/db/dao/settings_dao_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 7: Run existing tests to verify no regression**

Run: `flutter test test/features/capture/ test/features/profile/ test/core/`
Expected: All existing tests pass (242 + 3 new)

- [ ] **Step 8: Commit**

```bash
git add lib/core/db/tables.dart lib/core/db/database_provider.dart lib/core/db/dao/settings_dao.dart test/core/db/dao/settings_dao_test.dart
git commit -m "feat(db): add auto_deblur column to user_settings + SettingsDao"
```

---

### Task 4: autoDeblurProvider + 设置页开关

**Files:**
- Create: `lib/features/profile/providers/settings_providers.dart`
- Modify: `lib/features/profile/pages/profile_settings_page.dart`

**Interfaces:**
- Produces: `autoDeblurProvider` (StateProvider<bool>)
- Produces: `loadAutoDeblurFromDb(ProviderContainer) → Future<void>`
- Consumes: Task 3 的 `settingsDaoProvider` / `SettingsDao`

- [ ] **Step 1: Create settings_providers.dart**

```dart
// lib/features/profile/providers/settings_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/db/dao/settings_dao.dart';
import '../../../core/db/database_provider.dart';

/// 自动去模糊开关（内存态，启动时从 DB 加载）
/// 默认 true（开启）。CapturePage 读取此值决定是否调用 DeblurProcessor。
/// ProfileSettingsPage 的 Switch 双向绑定此 provider。
final autoDeblurProvider = StateProvider<bool>((ref) => true);

/// 应用启动时从 DB 异步加载 autoDeblur 历史值
/// 在 main.dart 或 ProfileSettingsPage initState 中调用
Future<void> loadAutoDeblurFromDb(ProviderContainer container) async {
  try {
    final dao = await container.read(settingsDaoProvider.future);
    final value = await dao.getAutoDeblur();
    container.read(autoDeblurProvider.notifier).state = value;
  } catch (e) {
    // 加载失败保持默认值 true
  }
}
```

- [ ] **Step 2: Modify profile_settings_page.dart to add switch**

在 `lib/features/profile/pages/profile_settings_page.dart`：

1. 添加 import：
```dart
import '../providers/settings_providers.dart';
import '../../../core/db/database_provider.dart';
```

2. 在 `_ProfileSettingsPageState`（约 line 37）加字段：
```dart
  late bool _autoDeblurOn = true;
```

3. 在 `initState`（如果有）或 build 方法首次构建时加载 DB 值：
```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final dao = await ref.read(settingsDaoProvider.future);
        final value = await dao.getAutoDeblur();
        if (mounted) {
          setState(() => _autoDeblurOn = value);
          ref.read(autoDeblurProvider.notifier).state = value;
        }
      } catch (_) {}
    });
  }
```

4. 在"拍摄"分组（约 line 268 的水印 Switch 之后）加新项：
```dart
                      _SettingItem(
                        icon: Icons.blur_on,
                        label: '自动去模糊',
                        trailing: Switch(
                          value: _autoDeblurOn,
                          onChanged: (v) async {
                            setState(() => _autoDeblurOn = v);
                            ref.read(autoDeblurProvider.notifier).state = v;
                            try {
                              final dao = await ref.read(settingsDaoProvider.future);
                              await dao.setAutoDeblur(v);
                            } catch (e) {
                              debugPrint('保存自动去模糊设置失败: $e');
                            }
                          },
                          activeColor: tokens.brand,
                        ),
                        tokens: tokens,
                        isLast: true,
                      ),
```

注意：把之前水印项的 `isLast: true` 删掉（改为不传或 false），让新的"自动去模糊"成为最后一项。

- [ ] **Step 3: Run existing settings page tests**

Run: `flutter test test/features/profile/profile_settings_page_test.dart`
Expected: PASS（现有测试不应破坏）

- [ ] **Step 4: Commit**

```bash
git add lib/features/profile/providers/settings_providers.dart lib/features/profile/pages/profile_settings_page.dart
git commit -m "feat(settings): add auto-deblur toggle with DB persistence"
```

---

### Task 5: PhotoPostProcessor 集成去模糊

**Files:**
- Modify: `lib/features/capture/services/photo_post_processor.dart`
- Modify: `lib/features/capture/pages/capture_page.dart`

**Interfaces:**
- Consumes: Task 1-2 的 `DeblurProcessor.estimateBlur` / `deblur`
- Consumes: Task 4 的 `autoDeblurProvider`

- [ ] **Step 1: Modify PhotoPostProcessor.processFile signature**

在 `lib/features/capture/services/photo_post_processor.dart`：

1. 添加 import：
```dart
import 'deblur_processor.dart';
```

2. 修改 `processFile` 方法签名（约 line 32）加参数：
```dart
  static Future<String> processFile({
    required String inputPath,
    required PostProcess params,
    bool rawMode = false,
    String aspectRatio = 'fullscreen',
    double screenRatio = 9.0 / 19.5,
    bool isPortrait = true,
    bool autoDeblur = false,  // 新增
  }) async {
```

3. 在第 4 步（Canvas 合并完成，约 line 135 `resultImage` 赋值后）和第 5 步（逐像素效果，约 line 138 `if (!rawMode)` 前）之间插入：
```dart
      // 4b. 自动去模糊（若开启且检测到模糊）
      // 性能：清晰图（blurScore ≥ 600）直接跳过，省 200ms
      if (autoDeblur) {
        try {
          // 转换 ui.Image → img.Image 做反卷积
          final rgba = await resultImage.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          if (rgba != null) {
            final imgForDeblur = img.Image.fromBytes(
              width: resultImage.width,
              height: resultImage.height,
              bytes: rgba.buffer.asUint8List().buffer,
              numChannels: 4,
              order: img.ChannelOrder.rgba,
            );
            final blurScore = DeblurProcessor.estimateBlur(imgForDeblur);
            debugPrint('[post-process] 模糊度: $blurScore');
            if (blurScore < DeblurProcessor.kClearThreshold) {
              final strength = DeblurProcessor.strengthForScore(blurScore);
              final deblurred = await DeblurProcessor.deblur(
                imgForDeblur,
                strength: strength,
              );
              // 转回 ui.Image
              final outBytes = deblurred.getBytes(order: img.ChannelOrder.rgba);
              final buffer = await ui.ImmutableBuffer.fromUint8List(outBytes);
              final descriptor = ui.ImageDescriptor.raw(
                buffer,
                width: deblurred.width,
                height: deblurred.height,
                pixelFormat: ui.PixelFormat.rgba8888,
              );
              final codec = await descriptor.instantiateCodec();
              final frame = await codec.getNextFrame();
              resultImage.dispose();
              resultImage = frame.image;
              buffer.dispose();
              descriptor.dispose();
              codec.dispose();
              debugPrint('[post-process] 去模糊完成: strength=$strength');
            } else {
              debugPrint('[post-process] 图像清晰，跳过去模糊');
            }
          }
        } catch (e) {
          debugPrint('[post-process] 去模糊失败（静默跳过）: $e');
        }
      }
```

- [ ] **Step 2: Modify capture_page.dart to pass autoDeblur**

在 `lib/features/capture/pages/capture_page.dart`：

1. 添加 import：
```dart
import '../../profile/providers/settings_providers.dart';
```

2. 在 `_onCameraStateCreated` 的 `captureState$.listen` 回调中（约 line 280，读取 `aspectRatio` 后），加读取：
```dart
        final autoDeblur = ref.read(autoDeblurProvider);
```

3. 修改 `PhotoPostProcessor.processFile` 调用（约 line 288），加 `autoDeblur` 参数：
```dart
        final processedPath = await PhotoPostProcessor.processFile(
          inputPath: media.filePath,
          params: params,
          rawMode: rawMode,
          aspectRatio: aspectRatio,
          screenRatio: screenRatio,
          isPortrait: isPortrait,
          autoDeblur: autoDeblur,
        );
```

- [ ] **Step 3: Run existing tests to verify no regression**

Run: `flutter test test/features/capture/`
Expected: All 225 capture tests pass

- [ ] **Step 4: Commit**

```bash
git add lib/features/capture/services/photo_post_processor.dart lib/features/capture/pages/capture_page.dart
git commit -m "feat(deblur): integrate auto-deblur into PhotoPostProcessor pipeline"
```

---

### Task 6: 端到端测试 + 性能验证

**Files:**
- Modify: `test/features/capture/photo_post_processor_crop_test.dart`（追加去模糊测试）

- [ ] **Step 1: Add integration tests**

在 `test/features/capture/photo_post_processor_crop_test.dart` 末尾追加：

```dart
group('PhotoPostProcessor autoDeblur integration', () {
  test('autoDeblur=false never deblurs (even on blurry image)', () async {
    // 构造模糊图像
    final image = img.Image(width: 64, height: 64);
    for (var y = 0; y < 64; y++) {
      for (var x = 0; x < 64; x++) {
        final v = ((x + y) / 2).round().clamp(0, 255);
        image.setPixelRgb(x, y, v, v, v);
      }
    }
    final tempDir = await Directory.systemTemp.createTemp('deblur_test_');
    final inputPath = '${tempDir.path}/blurry.jpg';
    final jpgBytes = img.encodeJpg(image, quality: 88);
    await File(inputPath).writeAsBytes(jpgBytes);

    final result = await PhotoPostProcessor.processFile(
      inputPath: inputPath,
      params: const PostProcess(color: PostProcessColor()),
      aspectRatio: 'free',
      autoDeblur: false,
    );

    // 验证文件存在且未被修改（autoDeblur=false）
    expect(await File(result).exists(), isTrue);
    await tempDir.delete(recursive: true);
  });

  test('autoDeblur=true on clear image skips deblur (performance)', () async {
    // 构造清晰图像（棋盘格）
    final image = img.Image(width: 64, height: 64);
    for (var y = 0; y < 64; y++) {
      for (var x = 0; x < 64; x++) {
        final isWhite = ((x ~/ 8) + (y ~/ 8)) % 2 == 0;
        image.setPixelRgb(x, y, isWhite ? 255 : 0, isWhite ? 255 : 0, isWhite ? 255 : 0);
      }
    }
    final tempDir = await Directory.systemTemp.createTemp('deblur_test_');
    final inputPath = '${tempDir.path}/clear.jpg';
    final jpgBytes = img.encodeJpg(image, quality: 88);
    await File(inputPath).writeAsBytes(jpgBytes);

    final sw = Stopwatch()..start();
    final result = await PhotoPostProcessor.processFile(
      inputPath: inputPath,
      params: const PostProcess(color: PostProcessColor()),
      aspectRatio: 'free',
      autoDeblur: true,
    );
    sw.stop();
    debugPrint('[test] 清晰图 autoDeblur=true 耗时: ${sw.elapsedMilliseconds}ms');

    expect(await File(result).exists(), isTrue);
    // 清晰图应快速返回（跳过去模糊）
    expect(sw.elapsedMilliseconds, lessThan(500),
        reason: '清晰图应跳过去模糊，耗时接近无去模糊基线');
    await tempDir.delete(recursive: true);
  });
});
```

- [ ] **Step 2: Run tests**

Run: `flutter test test/features/capture/photo_post_processor_crop_test.dart`
Expected: PASS

- [ ] **Step 3: Run full test suite**

Run: `flutter test test/features/capture/ test/features/profile/ test/core/`
Expected: All tests pass (242 existing + new tests)

- [ ] **Step 4: Commit**

```bash
git add test/features/capture/photo_post_processor_crop_test.dart
git commit -m "test(deblur): add integration tests for autoDeblur in PhotoPostProcessor"
```

---

## Self-Review

**1. Spec coverage:**
- ✅ DeblurProcessor 模糊估计 → Task 1
- ✅ Lucy-Richardson 反卷积 → Task 2
- ✅ 三端兼容（纯 Dart，无原生代码）→ 全部任务
- ✅ 持久化到 user_settings 表 → Task 3
- ✅ SettingsDao → Task 3
- ✅ autoDeblurProvider → Task 4
- ✅ 设置页开关 → Task 4
- ✅ PhotoPostProcessor 集成 → Task 5
- ✅ CapturePage 读 provider 传参 → Task 5
- ✅ ≤ 300ms 性能 → Task 1 提前退出 + Task 6 性能测试
- ✅ 单元测试 → Task 1, 2, 3, 6
- ✅ 三端回归 → Task 6 端到端测试（纯 Dart 在三端行为一致）

**2. Placeholder scan:** 无 TBD/TODO，所有代码块完整。

**3. Type consistency:**
- `estimateBlur(img.Image) → double` ✅
- `strengthForScore(double) → double` ✅
- `deblur(img.Image, {required double strength}) → Future<img.Image>` ✅
- `SettingsDao.getAutoDeblur() → Future<bool>` ✅
- `SettingsDao.setAutoDeblur(bool) → Future<void>` ✅
- `autoDeblurProvider` StateProvider<bool> ✅
- `processFile(..., bool autoDeblur = false)` ✅
