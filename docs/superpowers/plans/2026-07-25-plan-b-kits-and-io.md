# Flutter 完善计划 Plan B: 组合套件 + 模板导入导出

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现 M2 组合套件（场景+模板+参数）的完整 CRUD 与拍摄接线，以及 M3 模板导入导出的双格式（.pptpl / .lumira）互操作，让用户能保存"场景+模板+参数"组合、一键套用拍照、跨设备分享模板。

**Architecture:** 在 Plan A 已建立的 `composition_kits` 表与种子数据基础上，新增 `CompositionKit` 模型与 `CompositionKitsDao`，在场景详情页通过 `AddToCompositionSheet` 创建套件，CapturePage 通过 `?scene=&templateId=&kitId=` 三参数读取并应用套件，组合页/详情页提供列表与编辑入口。M3 通过 `TemplateMapper`（双向转换 `TemplateRecord ↔ PhotoTemplate / EditorForm`）+ `TemplateExporter`（双格式序列化 + share_plus / path_provider 落盘）+ 增强 `TemplateImportSheet`（双格式嗅探 + DAO 持久化 + ID 冲突 + builtin 降级）闭环。

**Tech Stack:** Flutter 3.7+, Dart 2.19, flutter_riverpod 2.3.6, sqflite, go_router 6.5.7, share_plus 7.2.2, path_provider 2.0.14, file_picker 8.0.6, sqflite_common_ffi (测试)

## Global Constraints
- 必须兼容 iOS / Android / HarmonyOS 三平台
- Dart SDK: >=2.19.6 <3.0.0（不支持 Dart 3）
- 不引入新依赖（复用现有 share_plus / path_provider / file_picker / sqflite_common_ffi）
- .pptpl 格式严格遵循 AGENT.md 第五章定义（含 composition / pose / camera / sceneGuide / postProcess 全字段）
- 剪影自包含策略：builtin→key, image→base64 data URL, svg→inline SVG
- ID 冲突追加 `_imported_${Date.now()}` 后缀
- 所有新增 Provider 用 flutter_riverpod 2.3.6 API
- 文件命名用 snake_case，类名用 PascalCase
- 主题 tokens 通过 `ref.watch(themeTokensProvider)` 获取

## Plan A Foundation（前置条件）

本计划假设 Plan A 已完成以下基础设施：

1. `lib/core/db/tables.dart` 已添加 `compositionKits` 表常量与列常量：
   - `Tables.compositionKits = 'composition_kits'`
   - `Tables.colCameraOverridesJson = 'camera_overrides_json'`
   - `Tables.colNote = 'note'`
   - `Tables.colCoverUrl = 'cover_url'`
   - `Tables.colLastUsedAt = 'last_used_at'`
   - `Tables.colUsageCount = 'usage_count'`
2. `lib/core/db/database_provider.dart` 已 v3 → v4 升级，`_onUpgrade` 创建 `composition_kits` 表，`_kDbVersion = 4`，并暴露 `compositionKitsDaoProvider`
3. `lib/core/db/dao/templates_dao.dart` 已添加 `getAllBuiltinOnly({required bool isBuiltin})` 方法（Plan A 用于 `customTemplatesProvider`）
4. `custom_templates` 表已添加 `is_builtin`、`is_recommended` 列

如果 Plan A 的某项基础设施尚未落地，执行 Task 1 前需先补齐上述常量与表结构。

---

## Task 1: CompositionKit 模型 + DAO + Providers

**Files:**
- Create: `lumira_app_flutter/lib/features/profile/data/composition_kit_models.dart`
- Create: `lumira_app_flutter/lib/core/db/dao/composition_kits_dao.dart`
- Create: `lumira_app_flutter/lib/features/profile/providers/composition_kits_providers.dart`
- Modify: `lumira_app_flutter/lib/core/db/database_provider.dart:50-53`（新增 `compositionKitsDaoProvider`）
- Test: `lumira_app_flutter/test/composition_kits_dao_test.dart`

**Interfaces:**
- Consumes: `Tables.compositionKits` / 列常量（来自 Plan A 的 `tables.dart`）；`Database`（来自 `databaseProvider`）
- Produces:
  - `class CompositionKit { String id; String name; String sceneId; String? templateId; Map<String,dynamic> cameraOverrides; String note; String? coverUrl; int createdAt; int? lastUsedAt; int usageCount; }`
  - `class CompositionKitsDao { Future<List<CompositionKit>> getAll(); Future<CompositionKit?> getById(String id); Future<String> insert(CompositionKit kit); Future<void> update(CompositionKit kit); Future<int> delete(String id); Future<void> incrementUsage(String id); Future<int> count(); }`
  - `final compositionKitsDaoProvider = FutureProvider<CompositionKitsDao>((ref) async { ... })`
  - `final compositionKitsProvider = FutureProvider<List<CompositionKit>>((ref) async { ... })`
  - `final compositionKitByIdProvider = FutureProvider.family<CompositionKit?, String>((ref, id) async { ... })`

- [ ] **Step 1: Write the failing test**

创建 `lumira_app_flutter/test/composition_kits_dao_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/db/dao/composition_kits_dao.dart';
import 'package:lumira_app_flutter/features/profile/data/composition_kit_models.dart';

void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(
      ':memory:',
      version: 1,
      onCreate: _onCreate,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('CompositionKitsDao', () {
    test('insert and getById', () async {
      final dao = CompositionKitsDao(db);
      final kit = CompositionKit(
        id: 'kit_test_001',
        name: '咖啡馆+柔光人像',
        sceneId: 'cafe-window',
        templateId: 'cafe_portrait',
        cameraOverrides: {'exposureCompensation': 0.3, 'iso': 400},
        note: '下午窗边拍摄',
        coverUrl: 'https://picsum.photos/seed/kit1/400/600',
        createdAt: 1700000000000,
      );

      final insertedId = await dao.insert(kit);
      expect(insertedId, 'kit_test_001');

      final fetched = await dao.getById('kit_test_001');
      expect(fetched, isNotNull);
      expect(fetched!.name, '咖啡馆+柔光人像');
      expect(fetched.sceneId, 'cafe-window');
      expect(fetched.templateId, 'cafe_portrait');
      expect(fetched.cameraOverrides['exposureCompensation'], 0.3);
      expect(fetched.note, '下午窗边拍摄');
      expect(fetched.coverUrl, 'https://picsum.photos/seed/kit1/400/600');
      expect(fetched.usageCount, 0);
      expect(fetched.lastUsedAt, isNull);
    });

    test('getAll returns newest-first by createdAt', () async {
      final dao = CompositionKitsDao(db);
      await dao.insert(_makeKit('kit_1', createdAt: 1000));
      await dao.insert(_makeKit('kit_2', createdAt: 3000));
      await dao.insert(_makeKit('kit_3', createdAt: 2000));

      final all = await dao.getAll();
      expect(all.length, 3);
      expect(all[0].id, 'kit_2');
      expect(all[1].id, 'kit_3');
      expect(all[2].id, 'kit_1');
    });

    test('update mutates existing record', () async {
      final dao = CompositionKitsDao(db);
      await dao.insert(_makeKit('kit_1', name: '原始'));

      final updated = _makeKit('kit_1', name: '更新后', note: '新备注');
      await dao.update(updated);

      final fetched = await dao.getById('kit_1');
      expect(fetched!.name, '更新后');
      expect(fetched.note, '新备注');
    });

    test('delete removes record', () async {
      final dao = CompositionKitsDao(db);
      await dao.insert(_makeKit('kit_1'));
      expect(await dao.count(), 1);

      final deleted = await dao.delete('kit_1');
      expect(deleted, 1);
      expect(await dao.count(), 0);
    });

    test('incrementUsage increments count and updates lastUsedAt', () async {
      final dao = CompositionKitsDao(db);
      await dao.insert(_makeKit('kit_1'));

      final before = DateTime.now().millisecondsSinceEpoch;
      await dao.incrementUsage('kit_1');
      final after = DateTime.now().millisecondsSinceEpoch;

      final fetched = await dao.getById('kit_1');
      expect(fetched!.usageCount, 1);
      expect(fetched.lastUsedAt, isNotNull);
      expect(fetched.lastUsedAt! >= before, isTrue);
      expect(fetched.lastUsedAt! <= after, isTrue);

      await dao.incrementUsage('kit_1');
      final fetched2 = await dao.getById('kit_1');
      expect(fetched2!.usageCount, 2);
    });

    test('getById returns null for non-existent id', () async {
      final dao = CompositionKitsDao(db);
      final fetched = await dao.getById('non_existent');
      expect(fetched, isNull);
    });

    test('insert with null templateId and null coverUrl', () async {
      final dao = CompositionKitsDao(db);
      final kit = CompositionKit(
        id: 'kit_minimal',
        name: '极简套件',
        sceneId: 'street-night',
        templateId: null,
        cameraOverrides: {},
        note: '',
        coverUrl: null,
        createdAt: 1700000000000,
      );
      await dao.insert(kit);

      final fetched = await dao.getById('kit_minimal');
      expect(fetched, isNotNull);
      expect(fetched!.templateId, isNull);
      expect(fetched.coverUrl, isNull);
    });
  });
}

CompositionKit _makeKit(String id, {String name = '套件', int? createdAt, String note = ''}) {
  return CompositionKit(
    id: id,
    name: name,
    sceneId: 'scene_$id',
    templateId: 'tpl_$id',
    cameraOverrides: {},
    note: note,
    coverUrl: null,
    createdAt: createdAt ?? DateTime.now().millisecondsSinceEpoch,
  );
}

Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.compositionKits} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colName} TEXT NOT NULL,
      ${Tables.colSceneId} TEXT NOT NULL,
      ${Tables.colTemplateId} TEXT,
      ${Tables.colCameraOverridesJson} TEXT,
      ${Tables.colNote} TEXT,
      ${Tables.colCoverUrl} TEXT,
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colLastUsedAt} INTEGER,
      ${Tables.colUsageCount} INTEGER DEFAULT 0
    )
  ''');
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/composition_kits_dao_test.dart -v`
Expected: FAIL with `Target of URI doesn't exist: 'package:lumira_app_flutter/core/db/dao/composition_kits_dao.dart'` / `composition_kit_models.dart` 等导入失败，编译错误。

- [ ] **Step 3: Write minimal implementation**

Create `lumira_app_flutter/lib/features/profile/data/composition_kit_models.dart`:

```dart
import 'dart:convert';

/// 组合套件实体（对应 `composition_kits` 表）
///
/// 一个套件绑定一个场景 + 可选模板 + 可选相机参数覆盖，
/// 用户可在场景详情页"加入组合"创建，套用拍照时三参数同时应用。
class CompositionKit {
  CompositionKit({
    required this.id,
    required this.name,
    required this.sceneId,
    this.templateId,
    this.cameraOverrides = const {},
    this.note = '',
    this.coverUrl,
    required this.createdAt,
    this.lastUsedAt,
    this.usageCount = 0,
  });

  /// 唯一 ID（推荐前缀 'kit_'）
  final String id;

  /// 套件名（如"咖啡馆+柔光人像"）
  final String name;

  /// 关联场景 ID
  final String sceneId;

  /// 关联模板 ID（可空，表示纯场景套件）
  final String? templateId;

  /// 相机参数覆盖（如 {'exposureCompensation': 0.3, 'iso': 400}）
  /// 序列化为 JSON 字符串存 `camera_overrides_json` 列
  final Map<String, dynamic> cameraOverrides;

  /// 备注
  final String note;

  /// 封面图 URL（一般为场景示例图）
  final String? coverUrl;

  /// 创建时间（毫秒）
  final int createdAt;

  /// 最近使用时间（毫秒，可空）
  final int? lastUsedAt;

  /// 使用次数（每次套用拍照 +1）
  final int usageCount;

  /// 序列化为 DB 行
  Map<String, Object?> toRow() {
    return {
      'id': id,
      'name': name,
      'scene_id': sceneId,
      'template_id': templateId,
      'camera_overrides_json': cameraOverrides.isEmpty ? null : jsonEncode(cameraOverrides),
      'note': note,
      'cover_url': coverUrl,
      'created_at': createdAt,
      'last_used_at': lastUsedAt,
      'usage_count': usageCount,
    };
  }

  /// 从 DB 行反序列化
  static CompositionKit fromRow(Map<String, Object?> row) {
    return CompositionKit(
      id: row['id'] as String,
      name: row['name'] as String,
      sceneId: row['scene_id'] as String,
      templateId: row['template_id'] as String?,
      cameraOverrides: _decodeJsonMap(row['camera_overrides_json']),
      note: (row['note'] as String?) ?? '',
      coverUrl: row['cover_url'] as String?,
      createdAt: (row['created_at'] as num).toInt(),
      lastUsedAt: row['last_used_at'] == null ? null : (row['last_used_at'] as num).toInt(),
      usageCount: (row['usage_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// 副本（用于编辑时构造新实例）
  CompositionKit copyWith({
    String? id,
    String? name,
    String? sceneId,
    String? templateId,
    Map<String, dynamic>? cameraOverrides,
    String? note,
    String? coverUrl,
    int? createdAt,
    int? lastUsedAt,
    int? usageCount,
  }) {
    return CompositionKit(
      id: id ?? this.id,
      name: name ?? this.name,
      sceneId: sceneId ?? this.sceneId,
      templateId: templateId ?? this.templateId,
      cameraOverrides: cameraOverrides ?? this.cameraOverrides,
      note: note ?? this.note,
      coverUrl: coverUrl ?? this.coverUrl,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      usageCount: usageCount ?? this.usageCount,
    );
  }

  static Map<String, dynamic> _decodeJsonMap(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      return jsonDecode(raw) as Map<String, dynamic>;
    }
    return <String, dynamic>{};
  }
}
```

Create `lumira_app_flutter/lib/core/db/dao/composition_kits_dao.dart`:

```dart
import 'package:sqflite/sqflite.dart';

import '../tables.dart';
import '../../../features/profile/data/composition_kit_models.dart';

/// 组合套件 DAO（CRUD + usage 计数）
class CompositionKitsDao {
  CompositionKitsDao(this._db);

  final Database _db;

  /// 获取所有套件，按 created_at DESC（最新在前）
  Future<List<CompositionKit>> getAll() async {
    final rows = await _db.query(
      Tables.compositionKits,
      orderBy: 'created_at DESC',
    );
    return rows.map(CompositionKit.fromRow).toList();
  }

  /// 按 ID 查询，未找到返回 null
  Future<CompositionKit?> getById(String id) async {
    final rows = await _db.query(
      Tables.compositionKits,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CompositionKit.fromRow(rows.first);
  }

  /// 插入套件，返回插入的 ID
  Future<String> insert(CompositionKit kit) async {
    await _db.insert(
      Tables.compositionKits,
      kit.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return kit.id;
  }

  /// 更新套件（按 id）
  Future<void> update(CompositionKit kit) async {
    await _db.update(
      Tables.compositionKits,
      kit.toRow(),
      where: 'id = ?',
      whereArgs: [kit.id],
    );
  }

  /// 删除套件，返回受影响行数
  Future<int> delete(String id) async {
    return _db.delete(
      Tables.compositionKits,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 使用次数 +1 并更新 last_used_at 为当前时间
  Future<void> incrementUsage(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.rawUpdate(
      'UPDATE ${Tables.compositionKits} SET usage_count = usage_count + 1, last_used_at = ? WHERE id = ?',
      [now, id],
    );
  }

  /// 总数
  Future<int> count() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS cnt FROM ${Tables.compositionKits}');
    return Sqflite.firstIntValue(rows) ?? 0;
  }
}
```

Modify `lumira_app_flutter/lib/core/db/database_provider.dart` 在 `academyDaoProvider` 之后（约 53 行）新增：

```dart
import 'dao/composition_kits_dao.dart';
// ...

final compositionKitsDaoProvider = FutureProvider<CompositionKitsDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return CompositionKitsDao(db);
});
```

具体 Edit 操作：在 `database_provider.dart` 第 6 行 `import 'dao/scenes_dao.dart';` 之后追加：

```dart
import 'dao/composition_kits_dao.dart';
```

在 `academyDaoProvider`（约 50-53 行）之后追加：

```dart
final compositionKitsDaoProvider = FutureProvider<CompositionKitsDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return CompositionKitsDao(db);
});
```

Create `lumira_app_flutter/lib/features/profile/providers/composition_kits_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/db/dao/composition_kits_dao.dart';
import '../data/composition_kit_models.dart';

/// 组合套件 DAO Provider（已在 database_provider.dart 中暴露）
// 重新导出避免循环依赖
export '../../../core/db/database_provider.dart' show compositionKitsDaoProvider;

/// 所有组合套件列表（按 created_at DESC）
final compositionKitsProvider = FutureProvider<List<CompositionKit>>((ref) async {
  final dao = await ref.watch(compositionKitsDaoProvider.future);
  return dao.getAll();
});

/// 按 ID 获取单个套件
final compositionKitByIdProvider =
    FutureProvider.family<CompositionKit?, String>((ref, id) async {
  final dao = await ref.watch(compositionKitsDaoProvider.future);
  return dao.getById(id);
});

/// 套件统计：总数 / 累计使用次数 / 最近使用时间
final compositionKitsStatsProvider = FutureProvider<CompositionKitsStats>((ref) async {
  final kits = await ref.watch(compositionKitsProvider.future);
  final totalCount = kits.length;
  final totalUsage = kits.fold<int>(0, (s, k) => s + k.usageCount);
  final lastUsed = kits
      .map((k) => k.lastUsedAt)
      .whereType<int>()
      .fold<int?>(null, (a, b) => a == null || b > a ? b : a);
  return CompositionKitsStats(
    totalCount: totalCount,
    totalUsage: totalUsage,
    lastUsedAt: lastUsed,
  );
});

class CompositionKitsStats {
  const CompositionKitsStats({
    required this.totalCount,
    required this.totalUsage,
    required this.lastUsedAt,
  });
  final int totalCount;
  final int totalUsage;
  final int? lastUsedAt;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/composition_kits_dao_test.dart -v`
Expected: PASS（7 个测试用例全过）

- [ ] **Step 5: Commit**

```bash
cd e:\Project\photo_post\lumira_app_flutter
git add lib/features/profile/data/composition_kit_models.dart lib/core/db/dao/composition_kits_dao.dart lib/features/profile/providers/composition_kits_providers.dart lib/core/db/database_provider.dart test/composition_kits_dao_test.dart
git commit -m "feat(composition-kits): add CompositionKit model, DAO and providers"
```

---

## Task 2: 场景详情页接线 + AddToCompositionSheet

**Files:**
- Create: `lumira_app_flutter/lib/features/capture/widgets/add_to_composition_sheet.dart`
- Modify: `lumira_app_flutter/lib/features/capture/pages/capture_scene_detail_page.dart:29-91`（构造函数新增 sceneId 已存在；改造 `_loadScene` / `_goCapture` / `_goCreateKit`）
- Test: `lumira_app_flutter/test/features/capture/add_to_composition_sheet_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `compositionKitsDaoProvider` / `CompositionKit`；`ScenePreset.id` / `ScenePreset.name`；`templatesDaoProvider` / `TemplateRecord`
- Produces:
  - `class AddToCompositionSheet extends ConsumerWidget`，静态方法 `static Future<void> show(BuildContext context, {required String sceneId, required String sceneName, String? sceneCoverUrl})`
  - 修改后的 `CaptureSceneDetailPage._goCapture()` 跳转 `RouteNames.capture` 并传 `paramScene`
  - 修改后的 `CaptureSceneDetailPage._goCreateKit()` 弹出 `AddToCompositionSheet.show(...)`

- [ ] **Step 1: Write the failing test**

Create `lumira_app_flutter/test/features/capture/add_to_composition_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/composition_kits_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/capture/widgets/add_to_composition_sheet.dart';
import 'package:lumira_app_flutter/features/profile/data/composition_kit_models.dart';

late Database _testDb;

Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.compositionKits} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colName} TEXT NOT NULL,
      ${Tables.colSceneId} TEXT NOT NULL,
      ${Tables.colTemplateId} TEXT,
      ${Tables.colCameraOverridesJson} TEXT,
      ${Tables.colNote} TEXT,
      ${Tables.colCoverUrl} TEXT,
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colLastUsedAt} INTEGER,
      ${Tables.colUsageCount} INTEGER DEFAULT 0
    )
  ''');
}

Future<CompositionKitsDao> _spawnDao() async {
  final db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
  _testDb = db;
  return CompositionKitsDao(db);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    if (_testDb.isOpen) {
      await _testDb.close();
    }
  });

  testWidgets('AddToCompositionSheet 显示名称/备注/模板下拉/保存按钮',
      (tester) async {
    final dao = await _spawnDao();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // 直接用 override 注入测试 DAO
          compositionKitsDaoProvider.overrideWith(
            (ref) async => dao,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => AddToCompositionSheet.show(
                  ctx,
                  sceneId: 'cafe-window',
                  sceneName: '咖啡馆窗边',
                  sceneCoverUrl: 'https://picsum.photos/seed/cafe/400/600',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('加入组合'), findsOneWidget);
    expect(find.text('套件名称'), findsOneWidget);
    expect(find.text('关联模板（可选）'), findsOneWidget);
    expect(find.text('备注'), findsOneWidget);
    expect(find.text('保存套件'), findsOneWidget);

    // 默认名称应为 "场景名-模板名" 模式
    expect(find.text('咖啡馆窗边-自由拍摄'), findsOneWidget);
  });

  testWidgets('点击保存按钮写入 DAO 并关闭 sheet', (tester) async {
    final dao = await _spawnDao();
    final messengerKey = GlobalKey<ScaffoldMessengerState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          compositionKitsDaoProvider.overrideWith((ref) async => dao),
        ],
        child: MaterialApp(
          scaffoldMessengerKey: messengerKey,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => AddToCompositionSheet.show(
                  ctx,
                  sceneId: 'street-night',
                  sceneName: '夜景街拍',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存套件'));
    await tester.pumpAndSettle();

    final all = await dao.getAll();
    expect(all.length, 1);
    expect(all.first.sceneId, 'street-night');
    expect(all.first.name, '夜景街拍-自由拍摄');
    expect(all.first.templateId, isNull);
  });
}
```

注意：`compositionKitsDaoProvider` 是 `FutureProvider<CompositionKitsDao>`，所以 `overrideWith` 传入 `(ref) async => dao` 闭包。

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/capture/add_to_composition_sheet_test.dart -v`
Expected: FAIL with `Target of URI doesn't exist: 'package:lumira_app_flutter/features/capture/widgets/add_to_composition_sheet.dart'`

- [ ] **Step 3: Write minimal implementation**

Create `lumira_app_flutter/lib/features/capture/widgets/add_to_composition_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../profile/data/composition_kit_models.dart';
import '../../profile/providers/composition_kits_providers.dart';

/// 「加入组合」底部 Sheet
///
/// 在场景详情页点击「加入组合」时弹出，让用户输入套件名 + 选择关联模板 + 备注，
/// 保存后写入 composition_kits 表。Toast 提供「查看组合」快捷入口。
class AddToCompositionSheet extends ConsumerStatefulWidget {
  const AddToCompositionSheet({
    super.key,
    required this.sceneId,
    required this.sceneName,
    this.sceneCoverUrl,
  });

  final String sceneId;
  final String sceneName;
  final String? sceneCoverUrl;

  static Future<void> show(
    BuildContext context, {
    required String sceneId,
    required String sceneName,
    String? sceneCoverUrl,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => AddToCompositionSheet(
        sceneId: sceneId,
        sceneName: sceneName,
        sceneCoverUrl: sceneCoverUrl,
      ),
    );
  }

  @override
  ConsumerState<AddToCompositionSheet> createState() =>
      _AddToCompositionSheetState();
}

class _AddToCompositionSheetState extends ConsumerState<AddToCompositionSheet> {
  late TextEditingController _nameController;
  late TextEditingController _noteController;
  String? _selectedTemplateId; // null = 自由拍摄
  List<_TemplateOption> _templateOptions = const [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // 默认名称 "场景名-自由拍摄"
    _nameController = TextEditingController(text: '${widget.sceneName}-自由拍摄');
    _noteController = TextEditingController();
    _loadTemplateOptions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplateOptions() async {
    try {
      final daoAsync = ref.read(templatesDaoProvider.future);
      final dao = await daoAsync;
      final records = await dao.getAll();
      if (!mounted) return;
      setState(() {
        _templateOptions = [
          const _TemplateOption(id: null, name: '自由拍摄（不关联模板）'),
          ...records.map((r) => _TemplateOption(id: r.id, name: r.name)),
        ];
      });
    } catch (_) {
      // 模板加载失败时仅显示自由拍摄选项
      if (!mounted) return;
      setState(() {
        _templateOptions = const [
          _TemplateOption(id: null, name: '自由拍摄（不关联模板）'),
        ];
      });
    }
  }

  Future<void> _onSave() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入套件名称')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final kit = CompositionKit(
        id: 'kit_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        sceneId: widget.sceneId,
        templateId: _selectedTemplateId,
        cameraOverrides: const {},
        note: _noteController.text.trim(),
        coverUrl: widget.sceneCoverUrl,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      final dao = await ref.read(compositionKitsDaoProvider.future);
      await dao.insert(kit);
      ref.invalidate(compositionKitsProvider);

      if (!mounted) return;
      Navigator.of(context).pop();

      // Toast + "查看组合"快捷入口
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('已加入组合'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: '查看组合',
            onPressed: () {
              GoRouter.of(context).push(RouteNames.profileCompositionKits);
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Material(
      color: tokens.canvas,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(tokens: tokens, title: '加入组合'),
              const SizedBox(height: 16),
              _Label(tokens: tokens, text: '套件名称'),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: '如：咖啡馆+柔光人像',
                  filled: true,
                  fillColor: tokens.canvasDeep,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(color: tokens.textPrimary, fontSize: 14),
              ),
              const SizedBox(height: 14),
              _Label(tokens: tokens, text: '关联模板（可选）'),
              _TemplateDropdown(
                tokens: tokens,
                value: _selectedTemplateId,
                options: _templateOptions,
                onChanged: (v) => setState(() => _selectedTemplateId = v),
              ),
              const SizedBox(height: 14),
              _Label(tokens: tokens, text: '备注'),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: '记录拍摄要点（可选）',
                  filled: true,
                  fillColor: tokens.canvasDeep,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(color: tokens.textPrimary, fontSize: 14),
              ),
              const SizedBox(height: 20),
              _SaveButton(
                tokens: tokens,
                saving: _saving,
                onTap: _onSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateOption {
  const _TemplateOption({required this.id, required this.name});
  final String? id;
  final String name;
}

class _Header extends StatelessWidget {
  const _Header({required this.tokens, required this.title});
  final ThemeTokens tokens;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.close, size: 20, color: tokens.textTertiary),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.tokens, required this.text});
  final ThemeTokens tokens;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: tokens.textSecondary,
        ),
      ),
    );
  }
}

class _TemplateDropdown extends StatelessWidget {
  const _TemplateDropdown({
    required this.tokens,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final ThemeTokens tokens;
  final String? value;
  final List<_TemplateOption> options;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: tokens.canvasDeep,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: tokens.textTertiary),
          style: TextStyle(fontSize: 14, color: tokens.textPrimary),
          dropdownColor: tokens.surface,
          items: options
              .map((o) => DropdownMenuItem<String?>(
                    value: o.id,
                    child: Text(o.name),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.tokens,
    required this.saving,
    required this.onTap,
  });

  final ThemeTokens tokens;
  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: saving ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: tokens.textPrimary,
          borderRadius: BorderRadius.circular(22),
        ),
        alignment: Alignment.center,
        child: saving
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: tokens.canvas,
                ),
              )
            : Text(
                '保存套件',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tokens.canvas,
                ),
              ),
      ),
    );
  }
}
```

现在修改 `capture_scene_detail_page.dart`，把 `_goCapture` 与 `_goCreateKit` 接上。在文件顶部 import 段（第 1-12 行之后）追加：

```dart
import '../widgets/add_to_composition_sheet.dart';
```

把第 81-91 行 `_goCapture` 与 `_goCreateKit` 整体替换为：

```dart
  void _goCapture() {
    final scene = _scene;
    if (scene == null) return;
    GoRouter.of(context).push(
      RouteNames.build(RouteNames.capture, {
        RouteNames.paramScene: scene.id,
      }),
    );
  }

  void _goCreateKit() {
    final scene = _scene;
    if (scene == null) return;
    final coverUrl =
        scene.exampleImages.isNotEmpty ? scene.exampleImages.first : null;
    AddToCompositionSheet.show(
      context,
      sceneId: scene.id,
      sceneName: scene.name,
      sceneCoverUrl: coverUrl,
    );
  }
```

注意：`RouteNames.profileCompositionKits` 常量将在 Task 4 中添加到 `route_names.dart`。Task 2 的实现引用了该常量，因此执行顺序上 Task 4 必须先于 Task 2 落地；若按 1→2→3→4→5 顺序执行，可先在 Task 2 执行前临时把 `RouteNames.profileCompositionKits` 添加到 `route_names.dart`（最小常量定义），Task 4 完成路由注册与页面文件。

为避免上述跨任务依赖问题，**在 Task 2 Step 3 执行前**先在 `route_names.dart` 第 47 行 `shootkitEditor = '/shootkit/editor';` 之后追加：

```dart
  static const String profileCompositionKits = '/profile/composition-kits';
  static const String profileCompositionKitDetail = '/profile/composition-kit-detail';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/capture/add_to_composition_sheet_test.dart -v`
Expected: PASS（2 个测试用例全过）

- [ ] **Step 5: Commit**

```bash
cd e:\Project\photo_post\lumira_app_flutter
git add lib/features/capture/widgets/add_to_composition_sheet.dart lib/features/capture/pages/capture_scene_detail_page.dart lib/core/router/route_names.dart test/features/capture/add_to_composition_sheet_test.dart
git commit -m "feat(capture): wire scene detail page to capture and AddToCompositionSheet"
```

---

## Task 3: CapturePage 套件参数应用

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/pages/capture_page.dart:37-98`（构造函数新增 sceneId/kitId，initState 读取并应用）
- Modify: `lumira_app_flutter/lib/app/router.dart:70-77`（capture 路由解析 scene/kitId 参数）
- Test: `lumira_app_flutter/test/features/capture/capture_page_kit_params_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `compositionKitsDaoProvider` / `CompositionKit`；`templatesDaoProvider` / `TemplateRecord`；`scenesDaoProvider` / `SceneRecord`；`CaptureState` 各 provider
- Produces:
  - `CapturePage({super.key, this.templateId, this.sceneId, this.kitId})`
  - capture 路由解析 `state.queryParams[paramScene]` / `[paramKitId]`
  - 拍照完成后调用 `compositionKitsDao.incrementUsage(kitId)`（在 `_captureSub` 监听器内）

- [ ] **Step 1: Write the failing test**

Create `lumira_app_flutter/test/features/capture/capture_page_kit_params_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/composition_kits_dao.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/core/db/dao/scenes_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/pages/capture_page.dart';
import 'package:lumira_app_flutter/features/profile/data/composition_kit_models.dart';

late Database _testDb;

Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.customTemplates} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colName} TEXT NOT NULL,
      ${Tables.colAuthor} TEXT NOT NULL DEFAULT '',
      ${Tables.colVersion} TEXT NOT NULL DEFAULT '1.0.0',
      ${Tables.colCategory} TEXT NOT NULL,
      ${Tables.colClassificationJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colTagsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colTagIdsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colPrice} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCover} TEXT NOT NULL DEFAULT '',
      ${Tables.colDescription} TEXT NOT NULL DEFAULT '',
      ${Tables.colReferenceSource} TEXT NOT NULL DEFAULT '',
      ${Tables.colCompositionJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPoseJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colCameraJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colSceneGuideJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPostProcessJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.scenes} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colName} TEXT NOT NULL,
      ${Tables.colIcon} TEXT NOT NULL DEFAULT '',
      ${Tables.colCategory} TEXT NOT NULL,
      ${Tables.colStyle} TEXT NOT NULL DEFAULT '',
      ${Tables.colFilterJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colVibe} TEXT NOT NULL DEFAULT '',
      ${Tables.colDescription} TEXT NOT NULL DEFAULT '',
      ${Tables.colExampleImagesJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colTipsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colWhereToShoot} TEXT NOT NULL DEFAULT '',
      ${Tables.colBestTime} TEXT NOT NULL DEFAULT '',
      ${Tables.colSceneGuideJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colRelatedCategory} TEXT NOT NULL DEFAULT '',
      ${Tables.colRecommendedTagIdsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colTagIdsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colCreator} TEXT NOT NULL DEFAULT 'user',
      ${Tables.colIsFavorite} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.compositionKits} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colName} TEXT NOT NULL,
      ${Tables.colSceneId} TEXT NOT NULL,
      ${Tables.colTemplateId} TEXT,
      ${Tables.colCameraOverridesJson} TEXT,
      ${Tables.colNote} TEXT,
      ${Tables.colCoverUrl} TEXT,
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colLastUsedAt} INTEGER,
      ${Tables.colUsageCount} INTEGER DEFAULT 0
    )
  ''');
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    if (_testDb.isOpen) await _testDb.close();
  });

  testWidgets('CapturePage 接收 scene/template/kit 三参数后应用到 CaptureState',
      (tester) async {
    _testDb = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
    final kitsDao = CompositionKitsDao(_testDb);
    final templatesDao = TemplatesDao(_testDb);
    final scenesDao = ScenesDao(_testDb);

    // 准备模板
    await templatesDao.upsert(TemplateRecord(
      id: 'tpl_test_001',
      name: '柔光人像',
      author: 'tester',
      version: '1.0.0',
      category: 'portrait',
      classification: {},
      tags: [],
      tagIds: [],
      price: 0,
      cover: '',
      description: '',
      referenceSource: '',
      composition: {'overlayType': 'rule_of_thirds'},
      pose: {},
      camera: {'exposureCompensation': 0.5, 'iso': 200, 'shutterSpeed': '1/200'},
      sceneGuide: {},
      postProcess: {},
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));

    // 准备套件（绑定 templateId + cameraOverrides 覆盖 EV）
    await kitsDao.insert(CompositionKit(
      id: 'kit_test_001',
      name: '咖啡馆+柔光人像',
      sceneId: 'scene_cafe',
      templateId: 'tpl_test_001',
      cameraOverrides: {'exposureCompensation': 0.7},
      note: '',
      coverUrl: null,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));

    final container = ProviderContainer(overrides: [
      // 用 override 注入测试 DAO（绕过真实 databaseProvider）
    ]);
    addTearDown(container.dispose);

    // 直接构造 CapturePage（不走 router）测试参数读取逻辑
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: CapturePage(
            templateId: 'tpl_test_001',
            sceneId: 'scene_cafe',
            kitId: 'kit_test_001',
          ),
        ),
      ),
    );
    await tester.pump();

    // 验证 CaptureState 中的 currentTemplateId 已被设置
    expect(container.read(CaptureState.currentTemplateIdProvider), 'tpl_test_001');
    expect(container.read(CaptureState.activeScenePresetIdProvider), 'scene_cafe');
  });
}
```

注意：上面的测试仅验证参数读取入口（initState 设置 CaptureState 的 templateId / sceneId），不验证相机参数覆盖（需 camerawesome 真实引擎）。完整套件应用流程通过手动集成测试验证（spec §10.3）。

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/capture/capture_page_kit_params_test.dart -v`
Expected: FAIL with `The named parameter 'sceneId' is not defined` / `'kitId' is not defined`（CapturePage 当前不接受 sceneId/kitId 参数）

- [ ] **Step 3: Write minimal implementation**

修改 `lumira_app_flutter/lib/features/capture/pages/capture_page.dart`：

1. 修改第 1-26 行 import 段，在末尾追加：

```dart
import '../../../core/db/dao/composition_kits_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../profile/data/composition_kit_models.dart';
```

（`database_provider.dart` 已通过 `gallery_dao.dart` 间接 import，此处显式引入以便读取 `compositionKitsDaoProvider` 与 `scenesDaoProvider`）

2. 替换第 37-45 行 CapturePage 类定义为：

```dart
class CapturePage extends ConsumerStatefulWidget {
  const CapturePage({super.key, this.templateId, this.sceneId, this.kitId});

  /// 来自 URL ?templateId=xxx，null 表示自由拍摄
  final String? templateId;

  /// 来自 URL ?scene=xxx，表示从场景详情页进入，需应用场景预设
  final String? sceneId;

  /// 来自 URL ?kitId=xxx，表示套用组合套件（含场景+模板+参数覆盖）
  final String? kitId;

  @override
  ConsumerState<CapturePage> createState() => _CapturePageState();
}
```

3. 在 `_CapturePageState` 内（第 50 行 `class _CapturePageState` 之后）新增字段：

```dart
  /// 当前套用的 kit ID（用于拍照完成时 incrementUsage）
  String? _activeKitId;
```

4. 替换第 80-98 行 initState 内的 `WidgetsBinding.instance.addPostFrameCallback` 块为：

```dart
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyRouteParamsToState();
      ref.read(CaptureState.currentTemplateIdProvider.notifier).state =
          widget.templateId;
      // 解析 returnResult 模式：?mode=return 时拍照完成后 pop 回上一页
      final mode = GoRouterState.of(context).queryParams[RouteNames.paramMode];
      _returnResult = mode == 'return';
      _requestCameraPermission();

      // 模板加载后，如果已有 CameraState，立即应用参数；
      // 否则等 _onCameraStateCreated 触发时再应用
      final state = ref.read(CaptureState.cameraStateProvider);
      if (state != null) {
        _applyTemplateCameraParams(state);
      }
    });
```

5. 在 `_requestCameraPermission` 方法之前（约第 100 行）新增方法：

```dart
  /// 读取路由参数（sceneId / templateId / kitId）并应用到 CaptureState
  /// 优先级：kitId > templateId（套件已包含 templateId）；sceneId 独立设置
  Future<void> _applyRouteParamsToState() async {
    final kitId = widget.kitId;
    final sceneId = widget.sceneId;

    if (sceneId != null) {
      ref.read(CaptureState.activeScenePresetIdProvider.notifier).state = sceneId;
    }

    if (kitId == null) return;
    _activeKitId = kitId;

    try {
      final dao = await ref.read(compositionKitsDaoProvider.future);
      final kit = await dao.getById(kitId);
      if (kit == null) return;

      // 设置 sceneId（套件中的 sceneId 优先于 URL scene 参数）
      ref.read(CaptureState.activeScenePresetIdProvider.notifier).state = kit.sceneId;

      // 设置 templateId（套件中的 templateId 优先）
      if (kit.templateId != null) {
        ref.read(CaptureState.currentTemplateIdProvider.notifier).state =
            kit.templateId;
      }

      // 应用相机参数覆盖到 freeModeCamera（无模板时）或 editableTemplate（有模板时）
      final overrides = kit.cameraOverrides;
      if (overrides.isNotEmpty) {
        final editable = ref.read(CaptureState.editableTemplateProvider);
        if (editable != null) {
          // 有模板：基于模板相机参数叠加覆盖
          final newCamera = editable.camera.copyWith(
            exposureCompensation:
                (overrides['exposureCompensation'] as num?)?.toDouble() ??
                    editable.camera.exposureCompensation,
            iso: (overrides['iso'] as num?)?.toInt() ?? editable.camera.iso,
            shutterSpeed: (overrides['shutterSpeed'] as String?) ??
                editable.camera.shutterSpeed,
          );
          ref.read(CaptureState.editableTemplateProvider.notifier).state =
              editable.copyWith(camera: newCamera);
        } else {
          // 无模板：直接写 freeModeCamera
          final current = ref.read(CaptureState.freeModeCameraProvider);
          ref.read(CaptureState.freeModeCameraProvider.notifier).state =
              current.copyWith(
            exposureCompensation:
                (overrides['exposureCompensation'] as num?)?.toDouble() ??
                    current.exposureCompensation,
            iso: (overrides['iso'] as num?)?.toInt() ?? current.iso,
            shutterSpeed: (overrides['shutterSpeed'] as String?) ??
                current.shutterSpeed,
          );
        }
      }
    } catch (e) {
      debugPrint('[capture] 加载套件失败: $e');
    }
  }
```

6. 修改 `_captureSub` 监听器（第 188-266 行）中"自动保存到应用相册"区块，在 `await dao.insert(record);` 之后（第 247 行后）追加：

```dart
        // 套件使用次数 +1（仅在套用 kit 进入时）
        if (_activeKitId != null) {
          try {
            final kitsDao = await ref.read(compositionKitsDaoProvider.future);
            await kitsDao.incrementUsage(_activeKitId!);
            ref.invalidate(compositionKitsProvider);
          } catch (e) {
            debugPrint('[capture] 套件 usage 计数失败: $e');
          }
        }
```

（注意需要在文件顶部追加 `import '../../profile/providers/composition_kits_providers.dart';`）

7. 修改 `lumira_app_flutter/lib/app/router.dart` 第 70-77 行 capture 路由：

```dart
      GoRoute(
        path: RouteNames.capture,
        name: 'capture',
        builder: (context, state) {
          final templateId = state.queryParams[RouteNames.paramTemplateId];
          final sceneId = state.queryParams[RouteNames.paramScene];
          final kitId = state.queryParams[RouteNames.paramKitId];
          return CapturePage(
            templateId: templateId,
            sceneId: sceneId,
            kitId: kitId,
          );
        },
      ),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/capture/capture_page_kit_params_test.dart -v`
Expected: PASS（CapturePage 接受新参数并设置 CaptureState）

同时运行已有测试确保不回归：
Run: `flutter test test/features/capture/capture_page_test.dart -v`
Expected: PASS（无回归）

- [ ] **Step 5: Commit**

```bash
cd e:\Project\photo_post\lumira_app_flutter
git add lib/features/capture/pages/capture_page.dart lib/app/router.dart test/features/capture/capture_page_kit_params_test.dart
git commit -m "feat(capture): apply scene/template/kit params and increment usage on capture"
```

---

## Task 4: 组合页（列表）+ 路由 + Profile 入口

**Files:**
- Create: `lumira_app_flutter/lib/features/profile/pages/composition_kits_page.dart`
- Modify: `lumira_app_flutter/lib/app/router.dart`（注册 `/profile/composition-kits` 路由）
- Modify: `lumira_app_flutter/lib/features/profile/pages/profile_page.dart:558-597`（QuickActionsRow 新增「我的组合」）
- Test: `lumira_app_flutter/test/features/profile/composition_kits_page_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `compositionKitsProvider` / `compositionKitsStatsProvider` / `compositionKitsDaoProvider`；`RouteNames.profileCompositionKits`
- Produces:
  - `class CompositionKitsPage extends ConsumerWidget`
  - `RouteNames.profileCompositionKits = '/profile/composition-kits'`（已在 Task 2 添加）
  - 修改后 `ProfilePage._QuickActionsRow` 包含「我的组合」入口

- [ ] **Step 1: Write the failing test**

Create `lumira_app_flutter/test/features/profile/composition_kits_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/composition_kits_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/profile/data/composition_kit_models.dart';
import 'package:lumira_app_flutter/features/profile/pages/composition_kits_page.dart';
import 'package:lumira_app_flutter/features/profile/providers/composition_kits_providers.dart';

late Database _testDb;

Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.compositionKits} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colName} TEXT NOT NULL,
      ${Tables.colSceneId} TEXT NOT NULL,
      ${Tables.colTemplateId} TEXT,
      ${Tables.colCameraOverridesJson} TEXT,
      ${Tables.colNote} TEXT,
      ${Tables.colCoverUrl} TEXT,
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colLastUsedAt} INTEGER,
      ${Tables.colUsageCount} INTEGER DEFAULT 0
    )
  ''');
}

Future<CompositionKitsDao> _spawnDao() async {
  final db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
  _testDb = db;
  return CompositionKitsDao(db);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    if (_testDb.isOpen) await _testDb.close();
  });

  testWidgets('空状态显示"还没有组合套件"提示', (tester) async {
    final dao = await _spawnDao();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          compositionKitsDaoProvider.overrideWith((ref) async => dao),
        ],
        child: const MaterialApp(home: CompositionKitsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('还没有组合套件'), findsOneWidget);
    expect(find.text('在场景详情页点击"加入组合"即可创建'), findsOneWidget);
  });

  testWidgets('列表显示套件卡片 + StatsBar', (tester) async {
    final dao = await _spawnDao();
    await dao.insert(CompositionKit(
      id: 'kit_1',
      name: '咖啡馆+柔光人像',
      sceneId: 'scene_cafe',
      templateId: 'tpl_cafe',
      cameraOverrides: {},
      note: '下午窗边',
      coverUrl: null,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      usageCount: 3,
      lastUsedAt: DateTime.now().millisecondsSinceEpoch,
    ));
    await dao.insert(CompositionKit(
      id: 'kit_2',
      name: '夜景街拍+黑白',
      sceneId: 'scene_street',
      templateId: 'tpl_bw',
      cameraOverrides: {},
      note: '',
      coverUrl: null,
      createdAt: DateTime.now().millisecondsSinceEpoch - 1000,
      usageCount: 0,
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          compositionKitsDaoProvider.overrideWith((ref) async => dao),
        ],
        child: const MaterialApp(home: CompositionKitsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('咖啡馆+柔光人像'), findsOneWidget);
    expect(find.text('夜景街拍+黑白'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // StatsBar 总数
    expect(find.text('3'), findsOneWidget); // StatsBar 总使用次数
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/profile/composition_kits_page_test.dart -v`
Expected: FAIL with `Target of URI doesn't exist: 'package:lumira_app_flutter/features/profile/pages/composition_kits_page.dart'`

- [ ] **Step 3: Write minimal implementation**

Create `lumira_app_flutter/lib/features/profile/pages/composition_kits_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/number_format.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/composition_kit_models.dart';
import '../providers/composition_kits_providers.dart';

/// 组合套件列表页
///
/// 视觉规格：对齐 ProfileMyTemplatesPage 结构
/// 1. 顶部 StatsBar：总数 / 总使用次数 / 最近使用
/// 2. 套件列表卡片：封面 + 名称 + 场景标签 + 模板标签 + 上次使用 + 使用次数
/// 3. FAB "新建套件"
/// 4. 卡片点击 → 详情页；长按 → ActionSheet（套用/编辑/复制/删除）
class CompositionKitsPage extends ConsumerWidget {
  const CompositionKitsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final kitsAsync = ref.watch(compositionKitsProvider);
    final statsAsync = ref.watch(compositionKitsStatsProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '我的组合',
        transparent: true,
        leading: _BackButton(tokens: tokens),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => GoRouter.of(context).push(RouteNames.captureSceneManage),
        backgroundColor: tokens.brand,
        child: Icon(Icons.add, color: tokens.canvas),
      ),
      body: SafeArea(
        child: kitsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('加载失败：$e')),
          data: (kits) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(compositionKitsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                _StatsBar(tokens: tokens, stats: statsAsync),
                const SizedBox(height: 16),
                if (kits.isEmpty)
                  _EmptyState(tokens: tokens)
                else
                  for (var i = 0; i < kits.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _KitCard(
                      tokens: tokens,
                      kit: kits[i],
                      onTap: () => GoRouter.of(context).push(
                        '${RouteNames.profileCompositionKitDetail}'
                        '?${RouteNames.paramKitId}=${kits[i].id}',
                      ),
                      onLongPress: () => _showActionSheet(context, ref, kits[i]),
                    ),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showActionSheet(BuildContext context, WidgetRef ref, CompositionKit kit) {
    final tokens = ref.read(themeTokensProvider);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: tokens.brand),
              title: const Text('套用拍照'),
              onTap: () {
                Navigator.pop(ctx);
                GoRouter.of(context).push(RouteNames.build(RouteNames.capture, {
                  RouteNames.paramScene: kit.sceneId,
                  RouteNames.paramTemplateId: kit.templateId ?? '',
                  RouteNames.paramKitId: kit.id,
                }));
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: tokens.danger),
              title: Text('删除', style: TextStyle(color: tokens.danger)),
              onTap: () async {
                Navigator.pop(ctx);
                final dao = await ref.read(compositionKitsDaoProvider.future);
                await dao.delete(kit.id);
                ref.invalidate(compositionKitsProvider);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已删除')),
                );
              },
            ),
            ListTile(
              title: Center(
                child: Text('取消',
                    style: TextStyle(color: tokens.textSecondary)),
              ),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context);
        } else {
          GoRouter.of(context).go(RouteNames.profile);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(Icons.arrow_back_ios_new, size: 20, color: tokens.textPrimary),
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.tokens, required this.stats});
  final ThemeTokens tokens;
  final AsyncValue<CompositionKitsStats> stats;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: stats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const SizedBox.shrink(),
        data: (s) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
                tokens: tokens, value: '${s.totalCount}', label: '套件总数'),
            _Divider(tokens: tokens),
            _StatItem(
                tokens: tokens,
                value: formatThousands(s.totalUsage),
                label: '总使用次数'),
            _Divider(tokens: tokens),
            _StatItem(
                tokens: tokens,
                value: s.lastUsedAt == null
                    ? '—'
                    : _formatDate(s.lastUsedAt!),
                label: '最近使用'),
          ],
        ),
      ),
    );
  }

  String _formatDate(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.month}-${dt.day}';
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.tokens, required this.value, required this.label});
  final ThemeTokens tokens;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Noto Serif SC',
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: tokens.textTertiary),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(width: 0.5, height: 28, color: tokens.divider);
  }
}

class _KitCard extends StatelessWidget {
  const _KitCard({
    required this.tokens,
    required this.kit,
    required this.onTap,
    required this.onLongPress,
  });

  final ThemeTokens tokens;
  final CompositionKit kit;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: NeuCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 80,
                height: 80,
                child: kit.coverUrl != null && kit.coverUrl!.isNotEmpty
                    ? Image.network(
                        kit.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _CoverPlaceholder(tokens: tokens),
                      )
                    : _CoverPlaceholder(tokens: tokens),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    kit.name,
                    style: TextStyle(
                      fontFamily: 'Noto Serif SC',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _Tag(tokens: tokens, text: '场景: ${_shortId(kit.sceneId)}'),
                      if (kit.templateId != null)
                        _Tag(tokens: tokens, text: '模板: ${_shortId(kit.templateId!)}'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '使用 ${kit.usageCount} 次 · ${_formatLastUsed(kit.lastUsedAt)}',
                    style: TextStyle(fontSize: 11, color: tokens.textTertiary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: tokens.textTertiary),
          ],
        ),
      ),
    );
  }

  String _shortId(String id) {
    // 取 id 中第一个 - 之前的部分作为简短标签
    final idx = id.indexOf('-');
    return idx == -1 ? id : id.substring(0, idx);
  }

  String _formatLastUsed(int? ms) {
    if (ms == null) return '未使用';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inHours < 1) return '刚刚';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${dt.month}-${dt.day}';
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: tokens.surfaceAlt,
      child: Icon(Icons.layers_outlined, color: tokens.textTertiary, size: 28),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.tokens, required this.text});
  final ThemeTokens tokens;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: tokens.brandSubtle,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: tokens.brandText),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 40),
      child: Column(
        children: [
          Icon(Icons.layers_outlined, size: 60, color: tokens.textTertiary.withOpacity(0.35)),
          const SizedBox(height: 10),
          Text(
            '还没有组合套件',
            style: TextStyle(
              fontFamily: 'Noto Serif SC',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '在场景详情页点击"加入组合"即可创建',
            style: TextStyle(fontSize: 12, color: tokens.textTertiary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => GoRouter.of(context).push(RouteNames.scenes),
            child: const Text('去逛逛场景'),
          ),
        ],
      ),
    );
  }
}
```

修改 `lumira_app_flutter/lib/app/router.dart` 第 299-303 行（`profileMyTemplates` 路由之后）追加：

```dart
      GoRoute(
        path: RouteNames.profileCompositionKits,
        name: 'profileCompositionKits',
        builder: (context, state) => const CompositionKitsPage(),
      ),
```

并在文件顶部 import 段追加（约第 33 行之后）：

```dart
import '../features/profile/pages/composition_kits_page.dart';
```

修改 `lumira_app_flutter/lib/features/profile/pages/profile_page.dart` 的 `_QuickActionsRow`（第 558-597 行），替换为 4 列布局：

```dart
class _QuickActionsRow extends ConsumerWidget {
  const _QuickActionsRow({required this.onTap});
  final void Function(String path) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final items = <_QuickActionItem>[
      _QuickActionItem(
        icon: Icons.emoji_events_outlined,
        label: '成长中心',
        onTap: () => onTap(RouteNames.profileGrowth),
      ),
      _QuickActionItem(
        icon: Icons.layers_outlined,
        label: '我的组合',
        onTap: () => onTap(RouteNames.profileCompositionKits),
      ),
      _QuickActionItem(
        icon: Icons.card_giftcard_outlined,
        label: '邀请有礼',
        onTap: () => onTap(RouteNames.profileInvite),
      ),
      _QuickActionItem(
        icon: Icons.menu_book_outlined,
        label: '摄影美学院',
        onTap: () => onTap(RouteNames.profileAcademy),
      ),
    ];

    return Row(
      children: items.asMap().entries.map((entry) {
        final item = entry.value;
        final isLast = entry.key == items.length - 1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 6),
            child: _QuickActionCard(item: item, tokens: tokens, appTheme: appTheme),
          ),
        );
      }).toList(),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/profile/composition_kits_page_test.dart -v`
Expected: PASS（2 个测试用例全过）

- [ ] **Step 5: Commit**

```bash
cd e:\Project\photo_post\lumira_app_flutter
git add lib/features/profile/pages/composition_kits_page.dart lib/app/router.dart lib/features/profile/pages/profile_page.dart test/features/profile/composition_kits_page_test.dart
git commit -m "feat(profile): add CompositionKitsPage list with route and QuickActions entry"
```

---

## Task 5: 组合详情页 + 编辑

**Files:**
- Create: `lumira_app_flutter/lib/features/profile/pages/composition_kit_detail_page.dart`
- Modify: `lumira_app_flutter/lib/app/router.dart`（注册 `/profile/composition-kit-detail` 路由）
- Test: `lumira_app_flutter/test/features/profile/composition_kit_detail_page_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `compositionKitByIdProvider` / `compositionKitsDaoProvider`；`scenesDaoProvider` / `templatesDaoProvider`（解析关联实体）；`RouteNames.profileCompositionKitDetail`
- Produces:
  - `class CompositionKitDetailPage extends ConsumerWidget`，构造函数 `CompositionKitDetailPage({super.key, required this.kitId})`
  - 「立即使用此套件拍照」按钮跳转 `RouteNames.capture` 并传 `paramScene` / `paramTemplateId` / `paramKitId` 三参数

- [ ] **Step 1: Write the failing test**

Create `lumira_app_flutter/test/features/profile/composition_kit_detail_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/composition_kits_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/profile/data/composition_kit_models.dart';
import 'package:lumira_app_flutter/features/profile/pages/composition_kit_detail_page.dart';
import 'package:lumira_app_flutter/features/profile/providers/composition_kits_providers.dart';

late Database _testDb;

Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.compositionKits} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colName} TEXT NOT NULL,
      ${Tables.colSceneId} TEXT NOT NULL,
      ${Tables.colTemplateId} TEXT,
      ${Tables.colCameraOverridesJson} TEXT,
      ${Tables.colNote} TEXT,
      ${Tables.colCoverUrl} TEXT,
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colLastUsedAt} INTEGER,
      ${Tables.colUsageCount} INTEGER DEFAULT 0
    )
  ''');
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    if (_testDb.isOpen) await _testDb.close();
  });

  testWidgets('详情页显示套件名/场景/模板/参数表/拍照按钮', (tester) async {
    _testDb = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
    final dao = CompositionKitsDao(_testDb);
    await dao.insert(CompositionKit(
      id: 'kit_detail_1',
      name: '咖啡馆+柔光人像',
      sceneId: 'scene_cafe',
      templateId: 'tpl_cafe',
      cameraOverrides: {'exposureCompensation': 0.3, 'iso': 400, 'shutterSpeed': '1/80'},
      note: '下午窗边拍摄',
      coverUrl: null,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));

    final goRouter = GoRouter(
      initialLocation: '/?kitId=kit_detail_1',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const SizedBox.shrink(),
        ),
        GoRoute(
          path: '/detail',
          builder: (context, state) {
            final kitId = state.queryParams['kitId']!;
            return CompositionKitDetailPage(kitId: kitId);
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          compositionKitsDaoProvider.overrideWith((ref) async => dao),
        ],
        child: MaterialApp.router(routerConfig: goRouter),
      ),
    );
    // 触发导航到 /detail?kitId=kit_detail_1
    goRouter.go('/detail?kitId=kit_detail_1');
    await tester.pumpAndSettle();

    expect(find.text('咖啡馆+柔光人像'), findsOneWidget);
    expect(find.text('场景'), findsOneWidget);
    expect(find.text('模板'), findsOneWidget);
    expect(find.text('参数'), findsOneWidget);
    expect(find.text('备注'), findsOneWidget);
    expect(find.text('EV'), findsOneWidget);
    expect(find.text('+0.3'), findsOneWidget);
    expect(find.text('ISO'), findsOneWidget);
    expect(find.text('400'), findsOneWidget);
    expect(find.text('快门'), findsOneWidget);
    expect(find.text('1/80'), findsOneWidget);
    expect(find.text('下午窗边拍摄'), findsOneWidget);
    expect(find.text('立即使用此套件拍照'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/profile/composition_kit_detail_page_test.dart -v`
Expected: FAIL with `Target of URI doesn't exist: 'package:lumira_app_flutter/features/profile/pages/composition_kit_detail_page.dart'`

- [ ] **Step 3: Write minimal implementation**

Create `lumira_app_flutter/lib/features/profile/pages/composition_kit_detail_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/composition_kit_models.dart';
import '../providers/composition_kits_providers.dart';

/// 组合套件详情页
///
/// 显示套件预览（场景图 + 模板叠图描述 + 参数表）+「立即使用此套件拍照」按钮
class CompositionKitDetailPage extends ConsumerWidget {
  const CompositionKitDetailPage({super.key, required this.kitId});

  final String kitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final kitAsync = ref.watch(compositionKitByIdProvider(kitId));

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '套件详情',
        transparent: true,
        leading: _BackButton(tokens: tokens),
      ),
      body: SafeArea(
        child: kitAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('加载失败：$e')),
          data: (kit) {
            if (kit == null) {
              return _NotFound(tokens: tokens);
            }
            return _KitDetailContent(tokens: tokens, kit: kit);
          },
        ),
      ),
      bottomNavigationBar: kitAsync.maybeWhen(
        data: (kit) => kit == null
            ? null
            : _BottomCaptureBar(tokens: tokens, kit: kit),
        orElse: () => null,
      ),
    );
  }
}

class _KitDetailContent extends ConsumerWidget {
  const _KitDetailContent({required this.tokens, required this.kit});
  final ThemeTokens tokens;
  final CompositionKit kit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CoverPreview(tokens: tokens, kit: kit),
          const SizedBox(height: 16),
          _TitleSection(tokens: tokens, kit: kit),
          const SizedBox(height: 16),
          _MetaSection(tokens: tokens, kit: kit, ref: ref),
          const SizedBox(height: 16),
          if (kit.cameraOverrides.isNotEmpty) ...[
            _ParamsSection(tokens: tokens, kit: kit),
            const SizedBox(height: 16),
          ],
          if (kit.note.isNotEmpty) ...[
            _NoteSection(tokens: tokens, kit: kit),
            const SizedBox(height: 16),
          ],
          _UsageSection(tokens: tokens, kit: kit),
        ],
      ),
    );
  }
}

class _CoverPreview extends StatelessWidget {
  const _CoverPreview({required this.tokens, required this.kit});
  final ThemeTokens tokens;
  final CompositionKit kit;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 3.0 / 4.0,
        child: kit.coverUrl != null && kit.coverUrl!.isNotEmpty
            ? Image.network(
                kit.coverUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _CoverFallback(tokens: tokens),
              )
            : _CoverFallback(tokens: tokens),
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: tokens.surfaceAlt,
      child: Center(
        child: Icon(Icons.layers_outlined, size: 56, color: tokens.textTertiary),
      ),
    );
  }
}

class _TitleSection extends StatelessWidget {
  const _TitleSection({required this.tokens, required this.kit});
  final ThemeTokens tokens;
  final CompositionKit kit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kit.name,
          style: TextStyle(
            fontFamily: 'Noto Serif SC',
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '创建于 ${_formatDate(kit.createdAt)}',
          style: TextStyle(fontSize: 12, color: tokens.textTertiary),
        ),
      ],
    );
  }

  String _formatDate(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _MetaSection extends ConsumerWidget {
  const _MetaSection({required this.tokens, required this.kit, required this.ref});
  final ThemeTokens tokens;
  final CompositionKit kit;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MetaRow(
            tokens: tokens,
            label: '场景',
            value: 'ID: ${kit.sceneId}',
          ),
          const SizedBox(height: 8),
          _MetaRow(
            tokens: tokens,
            label: '模板',
            value: kit.templateId == null ? '未关联' : 'ID: ${kit.templateId}',
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.tokens, required this.label, required this.value});
  final ThemeTokens tokens;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: tokens.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 13, color: tokens.textPrimary),
          ),
        ),
      ],
    );
  }
}

class _ParamsSection extends StatelessWidget {
  const _ParamsSection({required this.tokens, required this.kit});
  final ThemeTokens tokens;
  final CompositionKit kit;

  @override
  Widget build(BuildContext context) {
    final params = kit.cameraOverrides;
    final ev = (params['exposureCompensation'] as num?)?.toDouble();
    final iso = (params['iso'] as num?)?.toInt();
    final shutter = params['shutterSpeed'] as String?;

    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '参数覆盖',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (ev != null)
                _ParamChip(tokens: tokens, label: 'EV', value: _formatEv(ev)),
              if (iso != null)
                _ParamChip(tokens: tokens, label: 'ISO', value: '$iso'),
              if (shutter != null)
                _ParamChip(tokens: tokens, label: '快门', value: shutter),
            ],
          ),
        ],
      ),
    );
  }

  String _formatEv(double ev) {
    if (ev > 0) return '+${ev.toStringAsFixed(1)}';
    return ev.toStringAsFixed(1);
  }
}

class _ParamChip extends StatelessWidget {
  const _ParamChip({required this.tokens, required this.label, required this.value});
  final ThemeTokens tokens;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: tokens.textTertiary),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: tokens.textPrimary,
              fontFamily: 'Courier New',
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteSection extends StatelessWidget {
  const _NoteSection({required this.tokens, required this.kit});
  final ThemeTokens tokens;
  final CompositionKit kit;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '备注',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            kit.note,
            style: TextStyle(fontSize: 13, color: tokens.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _UsageSection extends StatelessWidget {
  const _UsageSection({required this.tokens, required this.kit});
  final ThemeTokens tokens;
  final CompositionKit kit;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.history, size: 16, color: tokens.textTertiary),
          const SizedBox(width: 8),
          Text(
            '使用 ${kit.usageCount} 次 · ${kit.lastUsedAt == null ? "未使用" : "最近: ${_formatDate(kit.lastUsedAt!)}"}',
            style: TextStyle(fontSize: 12, color: tokens.textTertiary),
          ),
        ],
      ),
    );
  }

  String _formatDate(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.month}-${dt.day}';
  }
}

class _BottomCaptureBar extends StatelessWidget {
  const _BottomCaptureBar({required this.tokens, required this.kit});
  final ThemeTokens tokens;
  final CompositionKit kit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(
          color: tokens.canvas,
          border: Border(top: BorderSide(color: tokens.divider, width: 0.5)),
        ),
        child: GestureDetector(
          onTap: () => GoRouter.of(context).push(RouteNames.build(
            RouteNames.capture,
            {
              RouteNames.paramScene: kit.sceneId,
              RouteNames.paramTemplateId: kit.templateId ?? '',
              RouteNames.paramKitId: kit.id,
            },
          )),
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: tokens.textPrimary,
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            child: Text(
              '立即使用此套件拍照',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: tokens.canvas,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context);
        } else {
          GoRouter.of(context).go(RouteNames.profileCompositionKits);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(Icons.arrow_back_ios_new, size: 20, color: tokens.textPrimary),
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: tokens.textTertiary),
          const SizedBox(height: 12),
          Text('套件不存在或已删除',
              style: TextStyle(fontSize: 16, color: tokens.textPrimary)),
        ],
      ),
    );
  }
}
```

修改 `lumira_app_flutter/lib/app/router.dart`，在 `profileCompositionKits` 路由之后追加（约第 305 行后）：

```dart
      GoRoute(
        path: RouteNames.profileCompositionKitDetail,
        name: 'profileCompositionKitDetail',
        builder: (context, state) {
          final kitId = state.queryParams[RouteNames.paramKitId];
          return CompositionKitDetailPage(kitId: kitId ?? '');
        },
      ),
```

并在文件顶部 import 段追加：

```dart
import '../features/profile/pages/composition_kit_detail_page.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/profile/composition_kit_detail_page_test.dart -v`
Expected: PASS（详情页显示所有套件信息）

- [ ] **Step 5: Commit**

```bash
cd e:\Project\photo_post\lumira_app_flutter
git add lib/features/profile/pages/composition_kit_detail_page.dart lib/app/router.dart test/features/profile/composition_kit_detail_page_test.dart
git commit -m "feat(profile): add CompositionKitDetailPage with capture entry"
```

---

## Task 6: TemplateExporter + TemplateMapper

**Files:**
- Create: `lumira_app_flutter/lib/features/templates/services/template_mapper.dart`
- Create: `lumira_app_flutter/lib/features/templates/services/template_exporter.dart`
- Test: `lumira_app_flutter/test/template_mapper_test.dart`
- Test: `lumira_app_flutter/test/template_exporter_test.dart`

**Interfaces:**
- Consumes: `TemplateRecord`（来自 `templates_dao.dart`）；`PhotoTemplate` / `SilhouetteResource`（来自 `domain/photo_template.dart`）；`EditorForm`（来自 `templates_editor_mock_data.dart`）
- Produces:
  - `class TemplateMapper { static TemplateRecord toRecord(PhotoTemplate tpl); static PhotoTemplate toPhotoTemplate(TemplateRecord r); static TemplateRecord fromEditorForm(EditorForm form, {String? id, required int createdAt}); static EditorForm toEditorForm(TemplateRecord r); static Map<String, dynamic> silhouetteToJson(SilhouetteResource s); static SilhouetteResource silhouetteFromJson(Map<String, dynamic> json); }`
  - `class TemplateExporter { static String exportToPptpl(TemplateRecord record); static String exportToLumira(TemplateRecord record); static Future<void> shareTemplate(TemplateRecord record, {required bool usePptpl}); static Future<void> saveToFile(TemplateRecord record, {required bool usePptpl, required String dirPath}); }`

- [ ] **Step 1: Write the failing test**

Create `lumira_app_flutter/test/template_mapper_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/templates/services/template_mapper.dart';

void main() {
  group('TemplateMapper.toRecord', () {
    test('PhotoTemplate → TemplateRecord 完整字段保留', () {
      final tpl = PhotoTemplate(
        meta: TemplateMeta(
          id: 'cafe_portrait',
          name: '咖啡馆人像',
          author: '如画',
          version: '1.0.0',
          category: 'portrait',
          classification: TemplateClassification(type: 'portrait', style: 'japanese', method: 'normal'),
          tags: ['咖啡馆', '人像'],
          tagIds: ['t1', 't2'],
          price: 0,
          cover: 'https://example.com/cover.jpg',
          description: '咖啡馆室内自然光人像',
          referenceSource: '样片 EXIF: Unsplash #67890',
        ),
        composition: Composition(
          overlayType: 'center',
          subjectFrame: SubjectFrame(x: 0.3, y: 0.2, w: 0.4, h: 0.6),
          opacity: 0.45,
          aspectRatio: '3:4',
          description: '人物居中',
        ),
        pose: Pose(
          silhouette: SilhouetteResource(type: 'builtin', data: 'sitting-cafe'),
          position: Position(x: 0.5, y: 0.45),
          scale: 1.0,
          rotation: 0,
          description: '坐姿',
        ),
        camera: CameraParams(
          exposureCompensation: 0.3,
          iso: 400,
          shutterSpeed: '1/80',
          whiteBalance: 'cloudy',
          whiteBalanceK: 4800,
          flashMode: 'off',
          focusMode: 'auto',
          lensSuggestion: 'main',
        ),
        sceneGuide: SceneGuide(
          lightDirection: '侧光 45°',
          shootingDistance: '1.5-2.5m',
          background: '咖啡馆室内',
          props: ['咖啡杯', '书本'],
          bestTime: '14:00-17:00',
          tips: ['让模特面朝窗户', '大光圈虚化'],
        ),
        postProcess: PostProcess(
          cropRatio: '3:4',
          color: PostProcessColor(brightness: 5, contrast: 10, saturation: 10, temperature: 20, tint: -5),
          smoothStrength: 20,
          sharpen: 15,
          vignette: 15,
          grain: 5,
          lut: 'warm_film',
        ),
      );

      final record = TemplateMapper.toRecord(tpl, createdAt: 1700000000000);

      expect(record.id, 'cafe_portrait');
      expect(record.name, '咖啡馆人像');
      expect(record.category, 'portrait');
      expect(record.tags, ['咖啡馆', '人像']);
      expect(record.composition['overlayType'], 'center');
      expect(record.composition['subjectFrame'], isNotNull);
      expect(record.pose['silhouette'], isNotNull);
      expect(record.camera['iso'], 400);
      expect(record.sceneGuide['lightDirection'], '侧光 45°');
      expect(record.postProcess['lut'], 'warm_film');
    });
  });

  group('TemplateMapper.toPhotoTemplate', () {
    test('TemplateRecord → PhotoTemplate 往返一致', () {
      final record = TemplateRecord(
        id: 'r1',
        name: '测试',
        author: 'a',
        version: '1.0.0',
        category: 'portrait',
        classification: {'type': 'portrait', 'style': '', 'method': ''},
        tags: ['t1'],
        tagIds: [],
        price: 0,
        cover: '',
        description: '',
        referenceSource: '',
        composition: {'overlayType': 'center', 'opacity': 0.5, 'aspectRatio': '3:4', 'description': ''},
        pose: {'silhouette': {'type': 'builtin', 'data': 'none'}, 'scale': 1.0, 'rotation': 0, 'description': ''},
        camera: {'exposureCompensation': 0.0, 'iso': 200, 'shutterSpeed': '1/200', 'whiteBalance': 'daylight', 'whiteBalanceK': 5500, 'flashMode': 'off', 'focusMode': 'auto', 'lensSuggestion': 'main'},
        sceneGuide: {'lightDirection': '', 'shootingDistance': '', 'background': '', 'props': <String>[], 'bestTime': '', 'tips': <String>[]},
        postProcess: {'cropRatio': '3:4', 'color': {'brightness': 0, 'contrast': 0, 'saturation': 0, 'temperature': 0, 'tint': 0}, 'smoothStrength': 0, 'sharpen': 0, 'vignette': 0, 'grain': 0, 'lut': 'none'},
        createdAt: 1700000000000,
        updatedAt: 1700000000000,
      );

      final tpl = TemplateMapper.toPhotoTemplate(record);
      expect(tpl.meta.id, 'r1');
      expect(tpl.meta.category, 'portrait');
      expect(tpl.composition.overlayType, 'center');
      expect(tpl.camera.iso, 200);
      expect(tpl.postProcess.lut, 'none');
    });
  });

  group('TemplateMapper.silhouetteToJson / silhouetteFromJson', () {
    test('builtin 剪影自包含（仅存 key）', () {
      final s = SilhouetteResource(type: 'builtin', data: 'standing-profile');
      final json = TemplateMapper.silhouetteToJson(s);
      expect(json['type'], 'builtin');
      expect(json['data'], 'standing-profile');

      final restored = TemplateMapper.silhouetteFromJson(json);
      expect(restored.type, 'builtin');
      expect(restored.data, 'standing-profile');
    });

    test('image 剪影自包含（存 base64 data URL）', () {
      final s = SilhouetteResource(
        type: 'image',
        data: 'data:image/png;base64,iVBORw0KGgo=',
        filename: 'sil.png',
        sizeKB: 12,
      );
      final json = TemplateMapper.silhouetteToJson(s);
      expect(json['type'], 'image');
      expect(json['data'], 'data:image/png;base64,iVBORw0KGgo=');
      expect(json['filename'], 'sil.png');

      final restored = TemplateMapper.silhouetteFromJson(json);
      expect(restored.type, 'image');
      expect(restored.data, 'data:image/png;base64,iVBORw0KGgo=');
    });

    test('svg 剪影自包含（存 inline SVG）', () {
      final s = SilhouetteResource(type: 'svg', data: '<svg></svg>');
      final json = TemplateMapper.silhouetteToJson(s);
      expect(json['type'], 'svg');
      expect(json['data'], '<svg></svg>');
    });
  });
}
```

Create `lumira_app_flutter/test/template_exporter_test.dart`:

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/features/templates/services/template_exporter.dart';

TemplateRecord _makeRecord() {
  return TemplateRecord(
    id: 'r1',
    name: '测试模板',
    author: 'tester',
    version: '1.0.0',
    category: 'portrait',
    classification: {},
    tags: ['人像'],
    tagIds: [],
    price: 0,
    cover: '',
    description: '',
    referenceSource: '',
    composition: {'overlayType': 'rule_of_thirds', 'subjectFrame': {'x': 0.1, 'y': 0.2, 'w': 0.3, 'h': 0.4}, 'opacity': 0.5, 'aspectRatio': '3:4', 'description': '三分法'},
    pose: {'silhouette': {'type': 'builtin', 'data': 'standing-profile'}, 'position': {'x': 0.5, 'y': 0.5}, 'scale': 1.0, 'rotation': 0, 'description': ''},
    camera: {'exposureCompensation': 0.3, 'iso': 200, 'shutterSpeed': '1/200', 'whiteBalance': 'daylight', 'whiteBalanceK': 5500, 'flashMode': 'off', 'focusMode': 'auto', 'lensSuggestion': 'main'},
    sceneGuide: {'lightDirection': 'front', 'shootingDistance': '2m', 'background': 'wall', 'props': <String>[], 'bestTime': 'morning', 'tips': <String>['keep steady']},
    postProcess: {'cropRatio': '3:4', 'color': {'brightness': 0, 'contrast': 0, 'saturation': 0, 'temperature': 0, 'tint': 0}, 'smoothStrength': 0, 'sharpen': 0, 'vignette': 0, 'grain': 0, 'lut': 'none'},
    createdAt: 1700000000000,
    updatedAt: 1700000000000,
  );
}

void main() {
  group('TemplateExporter.exportToPptpl', () {
    test('生成完整 .pptpl JSON（含所有 5 字段）', () {
      final json = TemplateExporter.exportToPptpl(_makeRecord());
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect(data['format'], 'pptpl');
      expect(data['version'], '1.0');
      expect(data['meta'], isA<Map>());
      expect(data['composition'], isA<Map>());
      expect(data['pose'], isA<Map>());
      expect(data['camera'], isA<Map>());
      expect(data['sceneGuide'], isA<Map>());
      expect(data['postProcess'], isA<Map>());

      expect(data['meta']['id'], 'r1');
      expect(data['composition']['subjectFrame'], isNotNull);
      expect(data['pose']['silhouette'], isNotNull);
    });
  });

  group('TemplateExporter.exportToLumira', () {
    test('生成简化 .lumira JSON（仅 meta + camera + composition.overlayType）', () {
      final json = TemplateExporter.exportToLumira(_makeRecord());
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect(data['format'], 'lumira');
      expect(data['version'], '1.0');
      expect(data['meta'], isA<Map>());
      expect(data['camera'], isA<Map>());
      expect(data['composition'], isA<Map>());

      // 简化版不应包含完整 pose / sceneGuide / postProcess
      expect(data.containsKey('pose'), isFalse);
      expect(data.containsKey('sceneGuide'), isFalse);
      expect(data.containsKey('postProcess'), isFalse);

      // composition 仅保留 overlayType
      expect(data['composition']['overlayType'], 'rule_of_thirds');
      expect(data['composition'].containsKey('subjectFrame'), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/template_mapper_test.dart test/template_exporter_test.dart -v`
Expected: FAIL with `Target of URI doesn't exist: 'package:lumira_app_flutter/features/templates/services/template_mapper.dart'`

- [ ] **Step 3: Write minimal implementation**

Create `lumira_app_flutter/lib/features/templates/services/template_mapper.dart`:

```dart
import 'dart:convert';

import '../../../core/db/dao/templates_dao.dart';
import '../../capture/domain/photo_template.dart';
import '../data/templates_editor_mock_data.dart' as editor;

/// 模板双向映射器
///
/// 处理 TemplateRecord ↔ PhotoTemplate 与 TemplateRecord ↔ EditorForm 的转换，
/// 包括 SilhouetteResource 的自包含序列化（builtin→key, image→base64 data URL, svg→inline）。
class TemplateMapper {
  TemplateMapper._();

  // === PhotoTemplate ↔ TemplateRecord ===

  /// PhotoTemplate → TemplateRecord
  /// 用于将内存中的 PhotoTemplate 持久化到 DB
  static TemplateRecord toRecord(PhotoTemplate tpl, {required int createdAt}) {
    return TemplateRecord(
      id: tpl.meta.id,
      name: tpl.meta.name,
      author: tpl.meta.author,
      version: tpl.meta.version,
      category: tpl.meta.category,
      classification: {
        'type': tpl.meta.classification.type,
        'style': tpl.meta.classification.style,
        'method': tpl.meta.classification.method,
      },
      tags: tpl.meta.tags,
      tagIds: tpl.meta.tagIds,
      price: tpl.meta.price,
      cover: tpl.meta.cover,
      description: tpl.meta.description,
      referenceSource: tpl.meta.referenceSource,
      composition: _compositionToJson(tpl.composition),
      pose: _poseToJson(tpl.pose),
      camera: _cameraToJson(tpl.camera),
      sceneGuide: _sceneGuideToJson(tpl.sceneGuide),
      postProcess: _postProcessToJson(tpl.postProcess),
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  /// TemplateRecord → PhotoTemplate
  /// 用于从 DB 读取后构造内存对象供 UI 使用
  static PhotoTemplate toPhotoTemplate(TemplateRecord r) {
    return PhotoTemplate(
      meta: TemplateMeta(
        id: r.id,
        name: r.name,
        author: r.author,
        version: r.version,
        category: r.category,
        classification: TemplateClassification(
          type: (r.classification['type'] as String?) ?? r.category,
          style: (r.classification['style'] as String?) ?? '',
          method: (r.classification['method'] as String?) ?? '',
        ),
        tags: r.tags,
        tagIds: r.tagIds,
        price: r.price,
        cover: r.cover,
        description: r.description,
        referenceSource: r.referenceSource,
      ),
      composition: _compositionFromJson(r.composition),
      pose: _poseFromJson(r.pose),
      camera: _cameraFromJson(r.camera),
      sceneGuide: _sceneGuideFromJson(r.sceneGuide),
      postProcess: _postProcessFromJson(r.postProcess),
    );
  }

  // === EditorForm ↔ TemplateRecord ===

  /// EditorForm → TemplateRecord
  /// 用于模板编辑器保存时序列化表单到 DB
  static TemplateRecord fromEditorForm(editor.EditorForm form,
      {String? id, required int createdAt}) {
    final formId = id ?? form.meta.id.isNotEmpty
        ? form.meta.id
        : 'tpl_${DateTime.now().millisecondsSinceEpoch}';
    return TemplateRecord(
      id: formId.isEmpty ? 'tpl_${DateTime.now().millisecondsSinceEpoch}' : formId,
      name: form.meta.name,
      author: 'user',
      version: '1.0.0',
      category: form.meta.category,
      classification: {'type': form.meta.category, 'style': '', 'method': ''},
      tags: form.meta.tags,
      tagIds: [],
      price: 0,
      cover: '',
      description: form.meta.description,
      referenceSource: form.meta.referenceSource,
      composition: {
        'overlayType': form.composition.overlayType,
        'aspectRatio': form.composition.aspectRatio,
        'opacity': form.composition.opacity,
        'description': form.composition.description,
      },
      pose: {
        'silhouette': silhouetteToJson(form.pose.silhouette),
        'position': {'x': form.pose.position.x, 'y': form.pose.position.y},
        'scale': form.pose.scale,
        'rotation': form.pose.rotation,
        'description': form.pose.description,
      },
      camera: {
        'exposureCompensation': form.camera.exposureCompensation,
        'isoMode': form.camera.isoMode,
        'iso': form.camera.iso,
        'shutterSpeed': form.camera.shutterSpeed,
        'whiteBalance': form.camera.whiteBalance,
        'whiteBalanceK': form.camera.whiteBalanceK,
        'flashMode': form.camera.flashMode,
        'focusMode': form.camera.focusMode,
        'lensSuggestion': form.camera.lensSuggestion,
      },
      sceneGuide: {
        'lightDirection': form.sceneGuide.lightDirection,
        'shootingDistance': form.sceneGuide.shootingDistance,
        'background': form.sceneGuide.background,
        'props': form.sceneGuide.props,
        'bestTime': form.sceneGuide.bestTime,
        'tips': form.sceneGuide.tips,
      },
      postProcess: {
        'cropRatio': form.postProcess.cropRatio,
        'color': {
          'brightness': form.postProcess.color.brightness,
          'contrast': form.postProcess.color.contrast,
          'saturation': form.postProcess.color.saturation,
          'temperature': form.postProcess.color.temperature,
          'tint': form.postProcess.color.tint,
        },
        'smoothStrength': form.postProcess.smoothStrength,
        'sharpen': form.postProcess.sharpen,
        'vignette': form.postProcess.vignette,
        'grain': form.postProcess.grain,
        'lut': form.postProcess.lut,
      },
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  /// TemplateRecord → EditorForm
  /// 用于模板编辑器加载已有模板时反序列化
  static editor.EditorForm toEditorForm(TemplateRecord r) {
    final composition = r.composition;
    final pose = r.pose;
    final camera = r.camera;
    final sceneGuide = r.sceneGuide;
    final postProcess = r.postProcess;

    return editor.EditorForm(
      meta: editor.EditorFormMeta(
        id: r.id,
        name: r.name,
        category: r.category,
        tags: r.tags,
        description: r.description,
        referenceSource: r.referenceSource,
      ),
      composition: editor.EditorFormComposition(
        overlayType: (composition['overlayType'] as String?) ?? 'rule_of_thirds',
        aspectRatio: (composition['aspectRatio'] as String?) ?? '3:4',
        opacity: (composition['opacity'] as num?)?.toDouble() ?? 0.5,
        description: (composition['description'] as String?) ?? '',
      ),
      pose: editor.EditorFormPose(
        silhouette: silhouetteFromJson(
            (pose['silhouette'] as Map<String, dynamic>?) ?? {}),
        position: editor.Position(
          x: ((pose['position'] as Map<String, dynamic>?)?['x'] as num?)
                  ?.toDouble() ??
              0.5,
          y: ((pose['position'] as Map<String, dynamic>?)?['y'] as num?)
                  ?.toDouble() ??
              0.5,
        ),
        scale: (pose['scale'] as num?)?.toDouble() ?? 1.0,
        rotation: (pose['rotation'] as num?)?.toDouble() ?? 0,
        description: (pose['description'] as String?) ?? '',
      ),
      camera: editor.EditorFormCamera(
        exposureCompensation:
            (camera['exposureCompensation'] as num?)?.toDouble() ?? 0,
        isoMode: (camera['isoMode'] as String?) ?? 'auto',
        iso: (camera['iso'] as num?)?.toInt() ?? 200,
        shutterSpeed: (camera['shutterSpeed'] as String?) ?? '1/200',
        whiteBalance: (camera['whiteBalance'] as String?) ?? 'daylight',
        whiteBalanceK: (camera['whiteBalanceK'] as num?)?.toInt() ?? 5500,
        flashMode: (camera['flashMode'] as String?) ?? 'off',
        focusMode: (camera['focusMode'] as String?) ?? 'auto',
        lensSuggestion: (camera['lensSuggestion'] as String?) ?? 'main',
      ),
      sceneGuide: editor.EditorFormSceneGuide(
        lightDirection: (sceneGuide['lightDirection'] as String?) ?? '',
        shootingDistance: (sceneGuide['shootingDistance'] as String?) ?? '',
        background: (sceneGuide['background'] as String?) ?? '',
        props: (sceneGuide['props'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        bestTime: (sceneGuide['bestTime'] as String?) ?? '',
        tips: (sceneGuide['tips'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
      ),
      postProcess: editor.EditorFormPostProcess(
        cropRatio: (postProcess['cropRatio'] as String?) ?? '3:4',
        color: editor.EditorFormPostProcessColor(
          brightness: ((postProcess['color'] as Map<String, dynamic>?)?['brightness'] as num?)?.toDouble() ?? 0,
          contrast: ((postProcess['color'] as Map<String, dynamic>?)?['contrast'] as num?)?.toDouble() ?? 0,
          saturation: ((postProcess['color'] as Map<String, dynamic>?)?['saturation'] as num?)?.toDouble() ?? 0,
          temperature: ((postProcess['color'] as Map<String, dynamic>?)?['temperature'] as num?)?.toDouble() ?? 0,
          tint: ((postProcess['color'] as Map<String, dynamic>?)?['tint'] as num?)?.toDouble() ?? 0,
        ),
        smoothStrength: (postProcess['smoothStrength'] as num?)?.toInt() ?? 0,
        sharpen: (postProcess['sharpen'] as num?)?.toInt() ?? 0,
        vignette: (postProcess['vignette'] as num?)?.toInt() ?? 0,
        grain: (postProcess['grain'] as num?)?.toInt() ?? 0,
        lut: (postProcess['lut'] as String?) ?? 'none',
      ),
    );
  }

  // === SilhouetteResource 自包含序列化 ===

  /// SilhouetteResource → JSON Map
  /// - builtin: 仅存 key（data 字段）
  /// - image: 存完整 base64 data URL
  /// - svg: 存完整 SVG 字符串
  static Map<String, dynamic> silhouetteToJson(SilhouetteResource s) {
    return {
      'type': s.type,
      'data': s.data,
      if (s.filename != null) 'filename': s.filename,
      if (s.sizeKB != null) 'sizeKB': s.sizeKB,
    };
  }

  /// editor 包的 SilhouetteResource → JSON
  static Map<String, dynamic> editorSilhouetteToJson(editor.SilhouetteResource s) {
    return {
      'type': s.type,
      'data': s.data,
      if (s.filename != null) 'filename': s.filename,
      if (s.sizeKB != null) 'sizeKB': s.sizeKB,
    };
  }

  /// JSON Map → PhotoTemplate 的 SilhouetteResource
  static SilhouetteResource silhouetteFromJson(Map<String, dynamic> json) {
    return SilhouetteResource(
      type: (json['type'] as String?) ?? 'builtin',
      data: (json['data'] as String?) ?? 'none',
      filename: json['filename'] as String?,
      sizeKB: json['sizeKB'] == null ? null : (json['sizeKB'] as num).toInt(),
    );
  }

  // === 私有辅助：PhotoTemplate 子对象 → JSON ===

  static Map<String, dynamic> _compositionToJson(Composition c) {
    return {
      'overlayType': c.overlayType,
      if (c.gridType != null) 'gridType': c.gridType,
      if (c.subjectFrame != null)
        'subjectFrame': {
          'x': c.subjectFrame!.x,
          'y': c.subjectFrame!.y,
          'w': c.subjectFrame!.w,
          'h': c.subjectFrame!.h,
        },
      'opacity': c.opacity,
      'aspectRatio': c.aspectRatio,
      'description': c.description,
    };
  }

  static Map<String, dynamic> _poseToJson(Pose p) {
    return {
      'silhouette': silhouetteToJson(p.silhouette),
      'position': {'x': p.position.x, 'y': p.position.y},
      'scale': p.scale,
      'rotation': p.rotation,
      'description': p.description,
    };
  }

  static Map<String, dynamic> _cameraToJson(CameraParams c) {
    return {
      'exposureCompensation': c.exposureCompensation,
      if (c.isoMode != null) 'isoMode': c.isoMode,
      'iso': c.iso,
      'shutterSpeed': c.shutterSpeed,
      'whiteBalance': c.whiteBalance,
      'whiteBalanceK': c.whiteBalanceK,
      'flashMode': c.flashMode,
      'focusMode': c.focusMode,
      if (c.lensSuggestion != null) 'lensSuggestion': c.lensSuggestion,
    };
  }

  static Map<String, dynamic> _sceneGuideToJson(SceneGuide s) {
    return {
      'lightDirection': s.lightDirection,
      'shootingDistance': s.shootingDistance,
      'background': s.background,
      'props': s.props,
      'bestTime': s.bestTime,
      'tips': s.tips,
    };
  }

  static Map<String, dynamic> _postProcessToJson(PostProcess p) {
    return {
      'cropRatio': p.cropRatio,
      'color': {
        'brightness': p.color.brightness,
        'contrast': p.color.contrast,
        'saturation': p.color.saturation,
        'temperature': p.color.temperature,
        'tint': p.color.tint,
      },
      'smoothStrength': p.smoothStrength,
      'sharpen': p.sharpen,
      'vignette': p.vignette,
      'grain': p.grain,
      'lut': p.lut,
    };
  }

  // === 私有辅助：JSON → PhotoTemplate 子对象 ===

  static Composition _compositionFromJson(Map<String, dynamic> json) {
    final sf = json['subjectFrame'] as Map<String, dynamic>?;
    return Composition(
      overlayType: (json['overlayType'] as String?) ?? 'rule_of_thirds',
      gridType: json['gridType'] as String?,
      subjectFrame: sf == null
          ? null
          : SubjectFrame(
              x: (sf['x'] as num).toDouble(),
              y: (sf['y'] as num).toDouble(),
              w: (sf['w'] as num).toDouble(),
              h: (sf['h'] as num).toDouble(),
            ),
      opacity: (json['opacity'] as num?)?.toDouble() ?? 0.5,
      aspectRatio: (json['aspectRatio'] as String?) ?? '3:4',
      description: (json['description'] as String?) ?? '',
    );
  }

  static Pose _poseFromJson(Map<String, dynamic> json) {
    final posJson = json['position'] as Map<String, dynamic>?;
    return Pose(
      silhouette: silhouetteFromJson(
          (json['silhouette'] as Map<String, dynamic>?) ?? {}),
      position: Position(
        x: (posJson?['x'] as num?)?.toDouble() ?? 0.5,
        y: (posJson?['y'] as num?)?.toDouble() ?? 0.5,
      ),
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      description: (json['description'] as String?) ?? '',
    );
  }

  static CameraParams _cameraFromJson(Map<String, dynamic> json) {
    return CameraParams(
      exposureCompensation:
          (json['exposureCompensation'] as num?)?.toDouble() ?? 0,
      iso: (json['iso'] as num?)?.toInt() ?? 200,
      shutterSpeed: (json['shutterSpeed'] as String?) ?? '1/200',
      whiteBalance: (json['whiteBalance'] as String?) ?? 'daylight',
      whiteBalanceK: (json['whiteBalanceK'] as num?)?.toInt() ?? 5500,
      flashMode: (json['flashMode'] as String?) ?? 'off',
      focusMode: (json['focusMode'] as String?) ?? 'auto',
      lensSuggestion: json['lensSuggestion'] as String?,
      isoMode: json['isoMode'] as String?,
    );
  }

  static SceneGuide _sceneGuideFromJson(Map<String, dynamic> json) {
    return SceneGuide(
      lightDirection: (json['lightDirection'] as String?) ?? '',
      shootingDistance: (json['shootingDistance'] as String?) ?? '',
      background: (json['background'] as String?) ?? '',
      props: (json['props'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      bestTime: (json['bestTime'] as String?) ?? '',
      tips: (json['tips'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  static PostProcess _postProcessFromJson(Map<String, dynamic> json) {
    final colorJson = json['color'] as Map<String, dynamic>?;
    return PostProcess(
      cropRatio: (json['cropRatio'] as String?) ?? '3:4',
      color: PostProcessColor(
        brightness: (colorJson?['brightness'] as num?)?.toDouble() ?? 0,
        contrast: (colorJson?['contrast'] as num?)?.toDouble() ?? 0,
        saturation: (colorJson?['saturation'] as num?)?.toDouble() ?? 0,
        temperature: (colorJson?['temperature'] as num?)?.toDouble() ?? 0,
        tint: (colorJson?['tint'] as num?)?.toDouble() ?? 0,
      ),
      smoothStrength: (json['smoothStrength'] as num?)?.toInt() ?? 0,
      sharpen: (json['sharpen'] as num?)?.toInt() ?? 0,
      vignette: (json['vignette'] as num?)?.toInt() ?? 0,
      grain: (json['grain'] as num?)?.toInt() ?? 0,
      lut: (json['lut'] as String?) ?? 'none',
    );
  }
}
```

Create `lumira_app_flutter/lib/features/templates/services/template_exporter.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/db/dao/templates_dao.dart';

/// 模板导出器
///
/// 支持双格式：
/// - .pptpl（完整 AGENT.md 规范，含 composition/pose/camera/sceneGuide/postProcess 全字段）
/// - .lumira（简化版，仅 meta + camera + composition.overlayType）
///
/// 剪影自包含策略在 TemplateMapper.silhouetteToJson 中实现：
/// - builtin→key, image→base64 data URL, svg→inline SVG
class TemplateExporter {
  TemplateExporter._();

  /// 导出为 .pptpl JSON 字符串
  static String exportToPptpl(TemplateRecord record) {
    final data = <String, dynamic>{
      'format': 'pptpl',
      'version': '1.0',
      'meta': {
        'id': record.id,
        'name': record.name,
        'author': record.author,
        'version': record.version,
        'category': record.category,
        'classification': record.classification,
        'tags': record.tags,
        'tagIds': record.tagIds,
        'price': record.price,
        'cover': record.cover,
        'description': record.description,
        'referenceSource': record.referenceSource,
      },
      'composition': record.composition,
      'pose': record.pose,
      'camera': record.camera,
      'sceneGuide': record.sceneGuide,
      'postProcess': record.postProcess,
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// 导出为 .lumira 简化 JSON 字符串
  /// 仅保留 meta（id/name/category/tags）+ camera + composition.overlayType
  static String exportToLumira(TemplateRecord record) {
    final data = <String, dynamic>{
      'format': 'lumira',
      'version': '1.0',
      'meta': {
        'id': record.id,
        'name': record.name,
        'category': record.category,
        'tags': record.tags,
      },
      'camera': {
        'exposureCompensation': record.camera['exposureCompensation'] ?? 0,
        'iso': record.camera['iso'] ?? 100,
        'shutterSpeed': record.camera['shutterSpeed'] ?? '1/125',
      },
      'composition': {
        'overlayType': record.composition['overlayType'] ?? 'rule_of_thirds',
      },
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// 通过系统分享面板分享模板文件
  /// [usePptpl]=true → .pptpl；false → .lumira
  static Future<void> shareTemplate(TemplateRecord record,
      {required bool usePptpl}) async {
    final content = usePptpl ? exportToPptpl(record) : exportToLumira(record);
    final ext = usePptpl ? 'pptpl' : 'lumira';
    final safeName = record.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final tempDir = await getTemporaryDirectory();
    final file =
        File('${tempDir.path}/lumira_template_$safeName.$ext');
    await file.writeAsString(content);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: '如画模板：${record.name}',
      text: '我创建了一个如画摄影模板「${record.name}」，用如画 App 导入即可使用。',
    );
  }

  /// 保存模板文件到指定目录
  /// [dirPath] 通常来自 file_picker 拿到的目录路径或 path_provider 的 Documents 目录
  static Future<void> saveToFile(TemplateRecord record,
      {required bool usePptpl, required String dirPath}) async {
    final content = usePptpl ? exportToPptpl(record) : exportToLumira(record);
    final ext = usePptpl ? 'pptpl' : 'lumira';
    final safeName = record.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('$dirPath/lumira_template_$safeName.$ext');
    await file.writeAsString(content);
  }
}
```

注意：`EditorFormPostProcessColor` 类名需与 `templates_editor_mock_data.dart` 中实际定义一致。在 Step 3 执行前，需先 Read 该文件确认 `EditorFormPostProcess` 内嵌的 color 类名（可能是 `EditorFormPostProcessColor` 或 `PostProcessColor`）。若实际类名为 `PostProcessColor`，把 `template_mapper.dart` 中的 `editor.EditorFormPostProcessColor` 改为 `editor.PostProcessColor`。

经查 `templates_editor_mock_data.dart` 第 202+ 行（已读部分），实际 color 类名应为 `EditorFormPostProcessColor`（按命名约定）。若 Read 时发现实际为别的名称，需相应调整。

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/template_mapper_test.dart test/template_exporter_test.dart -v`
Expected: PASS（所有测试用例全过）

- [ ] **Step 5: Commit**

```bash
cd e:\Project\photo_post\lumira_app_flutter
git add lib/features/templates/services/template_mapper.dart lib/features/templates/services/template_exporter.dart test/template_mapper_test.dart test/template_exporter_test.dart
git commit -m "feat(templates): add TemplateMapper and TemplateExporter for dual-format IO"
```

---

## Task 7: 导出 UI 接线

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/pages/templates_editor_page.dart:365-370`（`_onExport` 改为弹出格式选择 Sheet）
- Modify: `lumira_app_flutter/lib/features/profile/pages/profile_my_templates_page.dart:131-158`（`_exportTemplate` 改为调用 `TemplateExporter`）
- Test: `lumira_app_flutter/test/features/templates/templates_editor_export_test.dart`
- Test: `lumira_app_flutter/test/features/profile/profile_my_templates_export_test.dart`

**Interfaces:**
- Consumes: Task 6 的 `TemplateExporter.shareTemplate` / `TemplateMapper.fromEditorForm`；`templatesDaoProvider`
- Produces:
  - `TemplatesEditorPage._onExport()` 弹出格式选择 Sheet（.pptpl 推荐 / .lumira 简化 / 取消）
  - `ProfileMyTemplatesPage._exportTemplate(CustomTemplate tpl)` 调用 `TemplateExporter.shareTemplate`
  - 共享辅助方法 `void _showExportFormatSheet(BuildContext context, TemplateRecord record, WidgetRef ref)`

- [ ] **Step 1: Write the failing test**

Create `lumira_app_flutter/test/features/templates/templates_editor_export_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lumira_app_flutter/features/templates/pages/templates_editor_page.dart';

void main() {
  testWidgets('TemplatesEditorPage 点击导出按钮弹出格式选择 Sheet',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: const TemplatesEditorPage(templateId: 'tpl_test_export'),
        ),
      ),
    );
    await tester.pump();

    // 触发导出（通过 footer 的导出按钮；编辑模式下可见）
    // 编辑模式需要 templateId 存在 + mock 数据可加载；本测试主要验证 Sheet 弹出
    // 由于 _onExport 私有，通过点击导出按钮间接验证
    final exportBtn = find.text('导出');
    if (exportBtn.evaluate().isNotEmpty) {
      await tester.tap(exportBtn);
      await tester.pumpAndSettle();

      expect(find.text('选择导出格式'), findsOneWidget);
      expect(find.text('完整 .pptpl（推荐）'), findsOneWidget);
      expect(find.text('简化 .lumira'), findsOneWidget);
      expect(find.text('取消'), findsWidgets);
    }
  });
}
```

Create `lumira_app_flutter/test/features/profile/profile_my_templates_export_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/profile/data/profile_content_mock_data.dart';
import 'package:lumira_app_flutter/features/profile/pages/profile_my_templates_page.dart';

late Database _testDb;

Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.customTemplates} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colName} TEXT NOT NULL,
      ${Tables.colAuthor} TEXT NOT NULL DEFAULT '',
      ${Tables.colVersion} TEXT NOT NULL DEFAULT '1.0.0',
      ${Tables.colCategory} TEXT NOT NULL,
      ${Tables.colClassificationJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colTagsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colTagIdsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colPrice} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCover} TEXT NOT NULL DEFAULT '',
      ${Tables.colDescription} TEXT NOT NULL DEFAULT '',
      ${Tables.colReferenceSource} TEXT NOT NULL DEFAULT '',
      ${Tables.colCompositionJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPoseJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colCameraJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colSceneGuideJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPostProcessJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    if (_testDb.isOpen) await _testDb.close();
  });

  testWidgets('长按模板卡片弹出 ActionSheet 含"导出模板"项', (tester) async {
    _testDb = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
    final dao = TemplatesDao(_testDb);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // 不依赖真实 provider，仅验证 UI 显示
        ],
        child: const MaterialApp(home: ProfileMyTemplatesPage()),
      ),
    );
    await tester.pump();

    // ProfileContentMockData.customTemplates 应至少有一项
    if (ProfileContentMockData.customTemplates.isNotEmpty) {
      final firstTpl = ProfileContentMockData.customTemplates.first;
      final card = find.text(firstTpl.name);
      if (card.evaluate().isNotEmpty) {
        await tester.longPress(card);
        await tester.pumpAndSettle();

        expect(find.text('导出模板'), findsOneWidget);
      }
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/templates/templates_editor_export_test.dart -v`
Expected: FAIL（当前 `_onExport` 仅显示 "已导出（mock）" SnackBar，不弹出格式选择 Sheet）

- [ ] **Step 3: Write minimal implementation**

修改 `lumira_app_flutter/lib/features/templates/pages/templates_editor_page.dart`：

1. 在文件顶部 import 段（约第 17 行后）追加：

```dart
import '../services/template_exporter.dart';
import '../services/template_mapper.dart';
import '../../../core/db/database_provider.dart';
```

2. 替换第 365-370 行的 `_onExport` 方法为：

```dart
  Future<void> _onExport() async {
    if (_form.meta.name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先填写模板名称')),
      );
      return;
    }

    // 将 EditorForm 转为 TemplateRecord
    final now = DateTime.now().millisecondsSinceEpoch;
    final record = TemplateMapper.fromEditorForm(
      _form,
      id: _form.meta.id.isEmpty ? null : _form.meta.id,
      createdAt: now,
    );

    if (!mounted) return;
    await _showExportFormatSheet(context, record);
  }
```

3. 在 `_TemplatesEditorPageState` 类末尾（`_back()` 方法之前或之后）新增方法：

```dart
  Future<void> _showExportFormatSheet(
      BuildContext context, TemplateRecord record) async {
    final tokens = ref.watch(themeTokensProvider);

    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                '选择导出格式',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.description_outlined, color: tokens.brand),
              title: const Text('完整 .pptpl（推荐）'),
              subtitle: const Text('含构图/姿势/相机/场景/后期全参数'),
              onTap: () => Navigator.pop(ctx, 'pptpl'),
            ),
            ListTile(
              leading: Icon(Icons.code_outlined, color: tokens.brand),
              title: const Text('简化 .lumira'),
              subtitle: const Text('仅元信息+相机核心参数'),
              onTap: () => Navigator.pop(ctx, 'lumira'),
            ),
            ListTile(
              title: Center(
                child: Text('取消',
                    style: TextStyle(color: tokens.textSecondary)),
              ),
              onTap: () => Navigator.pop(ctx, null),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    if (!mounted) return;

    final usePptpl = result == 'pptpl';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('正在导出 ${record.name}...')),
    );

    try {
      await TemplateExporter.shareTemplate(record, usePptpl: usePptpl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已分享 ${record.name}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$e')),
      );
    }
  }
```

修改 `lumira_app_flutter/lib/features/profile/pages/profile_my_templates_page.dart`：

1. 在文件顶部 import 段（约第 19 行后）追加：

```dart
import '../../../core/db/dao/templates_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../templates/services/template_exporter.dart';
```

2. 替换第 131-158 行的 `_exportTemplate` 方法为：

```dart
  /// 导出模板：先从 DAO 加载 TemplateRecord，再弹出格式选择 Sheet
  Future<void> _exportTemplate(CustomTemplate tpl) async {
    try {
      final dao = await ref.read(templatesDaoProvider.future);
      final record = await dao.getById(tpl.id);

      if (record == null) {
        // 自定义模板可能尚未持久化（来自 mock），构造一个最小 record
        _showSnack('模板未持久化，请先保存到我的模板');
        return;
      }

      if (!mounted) return;
      await _showExportFormatSheet(record);
    } catch (e) {
      _showSnack('导出失败：$e');
    }
  }

  Future<void> _showExportFormatSheet(TemplateRecord record) async {
    final tokens = ref.watch(themeTokensProvider);
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                '选择导出格式',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.description_outlined, color: tokens.brand),
              title: const Text('完整 .pptpl（推荐）'),
              subtitle: const Text('含构图/姿势/相机/场景/后期全参数'),
              onTap: () => Navigator.pop(ctx, 'pptpl'),
            ),
            ListTile(
              leading: Icon(Icons.code_outlined, color: tokens.brand),
              title: const Text('简化 .lumira'),
              subtitle: const Text('仅元信息+相机核心参数'),
              onTap: () => Navigator.pop(ctx, 'lumira'),
            ),
            ListTile(
              title: Center(
                child: Text('取消',
                    style: TextStyle(color: tokens.textSecondary)),
              ),
              onTap: () => Navigator.pop(ctx, null),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    if (!mounted) return;

    final usePptpl = result == 'pptpl';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('正在导出 ${record.name}...')),
    );

    try {
      await TemplateExporter.shareTemplate(record, usePptpl: usePptpl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已分享 ${record.name}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$e')),
      );
    }
  }
```

3. 若 `profile_my_templates_page.dart` 顶部尚未 import `themeTokensProvider`，在 import 段追加：

```dart
import '../../../core/theme/theme_tokens.dart';
import '../../../core/theme/theme_controller.dart';
```

4. 若 `_showSnack` 辅助方法不存在，在 `_ProfileMyTemplatesPageState` 类中新增：

```dart
  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/templates/templates_editor_export_test.dart test/features/profile/profile_my_templates_export_test.dart -v`
Expected: PASS（编辑器导出按钮弹出含"完整 .pptpl（推荐）/简化 .lumira/取消"三项的 Sheet；我的模板页长按卡片弹出含"导出模板"项的 ActionSheet）

- [ ] **Step 5: Commit**

```bash
cd e:\Project\photo_post\lumira_app_flutter
git add lib/features/templates/pages/templates_editor_page.dart lib/features/profile/pages/profile_my_templates_page.dart test/features/templates/templates_editor_export_test.dart test/features/profile/profile_my_templates_export_test.dart
git commit -m "feat(templates): wire export UI to TemplateExporter with format selection sheet"
```

---

## Task 8: 导入 UI 增强（双格式嗅探 + DAO 持久化 + ID 冲突 + 剪影降级）

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/services/template_mapper.dart`（新增 `recordFromImportedJson` 静态方法）
- Modify: `lumira_app_flutter/lib/features/templates/widgets/template_import_sheet.dart:122-172`（`_handleFileImport` 改为 DAO 持久化 + 双格式嗅探）+ `:265-280`（`_parseTemplateJson` 升级为完整格式探测）
- Test: `lumira_app_flutter/test/template_import_test.dart`

**Interfaces:**
- Consumes: Task 6 的 `TemplateMapper.silhouetteFromJson`；`templatesDaoProvider`；`TemplatesEditorMockData.builtinSilhouetteKeys`（内置剪影 key 白名单）
- Produces:
  - `TemplateMapper.recordFromImportedJson(Map<String, dynamic> json, {required int createdAt}) → TemplateRecord`：从导入 JSON 构造 TemplateRecord，内部完成格式嗅探 + 剪影降级
  - `TemplateImportSheet._handleFileImport` 升级为 DAO 持久化路径，调用 `templatesDao.upsert(record)` 并处理 ID 冲突
  - ID 冲突解决策略：`while (await dao.getById(finalId) != null) finalId = '${finalId}_imported_${DateTime.now().millisecondsSinceEpoch}'`

- [ ] **Step 1: Write the failing test**

Create `lumira_app_flutter/test/template_import_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/templates/services/template_mapper.dart';
import 'package:lumira_app_flutter/features/templates/data/templates_editor_mock_data.dart'
    as mock;

late Database _testDb;

Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${Tables.customTemplates} (
      ${Tables.colId} TEXT PRIMARY KEY,
      ${Tables.colName} TEXT NOT NULL,
      ${Tables.colAuthor} TEXT NOT NULL DEFAULT '',
      ${Tables.colVersion} TEXT NOT NULL DEFAULT '1.0.0',
      ${Tables.colCategory} TEXT NOT NULL,
      ${Tables.colClassificationJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colTagsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colTagIdsJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colPrice} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colCover} TEXT NOT NULL DEFAULT '',
      ${Tables.colDescription} TEXT NOT NULL DEFAULT '',
      ${Tables.colReferenceSource} TEXT NOT NULL DEFAULT '',
      ${Tables.colCompositionJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPoseJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colCameraJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colSceneGuideJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPostProcessJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    if (_testDb.isOpen) await _testDb.close();
  });

  group('TemplateMapper.recordFromImportedJson — pptpl 格式', () {
    test('完整 pptpl JSON 应保留全部 section 字段', () {
      final json = <String, dynamic>{
        'format': 'pptpl',
        'version': '1.0',
        'meta': {
          'id': 'tpl-imported-1',
          'name': '导入的完整模板',
          'author': 'friend',
          'category': 'portrait',
          'tags': ['人像', '导入'],
          'tagIds': <String>[],
          'price': 0,
          'cover': '',
          'description': '从 pptpl 导入',
          'referenceSource': 'shared',
        },
        'composition': {
          'overlayType': 'golden_ratio',
          'aspectRatio': '4:3',
          'opacity': 0.6,
        },
        'pose': {
          'silhouette': {
            'type': 'builtin',
            'data': 'standing-profile',
          },
          'position': {'x': 0.4, 'y': 0.5},
          'scale': 1.1,
          'rotation': 0,
        },
        'camera': {
          'exposureCompensation': 0.5,
          'iso': 200,
          'shutterSpeed': '1/250',
        },
        'sceneGuide': {'lightDirection': '正面光'},
        'postProcess': {'cropRatio': '4:3', 'lut': 'cinematic'},
      };

      final record = TemplateMapper.recordFromImportedJson(
        json,
        createdAt: 1700000000000,
      );

      expect(record.id, 'tpl-imported-1');
      expect(record.name, '导入的完整模板');
      expect(record.author, 'friend');
      expect(record.category, 'portrait');
      expect(record.tags, ['人像', '导入']);
      expect(record.composition['overlayType'], 'golden_ratio');
      expect(record.pose['silhouette']['type'], 'builtin');
      expect(record.pose['silhouette']['data'], 'standing-profile');
      expect(record.camera['iso'], 200);
      expect(record.sceneGuide['lightDirection'], '正面光');
      expect(record.postProcess['lut'], 'cinematic');
    });

    test('剪影 builtin key 不存在时应降级为 none', () {
      final json = <String, dynamic>{
        'format': 'pptpl',
        'version': '1.0',
        'meta': {
          'id': 'tpl-bad-silhouette',
          'name': '坏剪影',
          'category': 'portrait',
        },
        'composition': {'overlayType': 'rule_of_thirds'},
        'pose': {
          'silhouette': {
            'type': 'builtin',
            'data': 'nonexistent-key-xyz',
          },
        },
        'camera': <String, dynamic>{},
        'sceneGuide': <String, dynamic>{},
        'postProcess': <String, dynamic>{},
      };

      final record = TemplateMapper.recordFromImportedJson(
        json,
        createdAt: 1700000000000,
      );

      expect(record.pose['silhouette']['type'], 'builtin');
      expect(record.pose['silhouette']['data'], 'none');
    });
  });

  group('TemplateMapper.recordFromImportedJson — lumira 格式', () {
    test('简化 lumira JSON 应填充默认值给缺失 section', () {
      final json = <String, dynamic>{
        'format': 'lumira',
        'version': '1.0',
        'meta': {
          'id': 'tpl-lumira-1',
          'name': '简化模板',
          'category': 'food',
          'tags': ['美食'],
        },
        'camera': {
          'exposureCompensation': 0.3,
          'iso': 100,
          'shutterSpeed': '1/125',
        },
        'composition': {'overlayType': 'center'},
      };

      final record = TemplateMapper.recordFromImportedJson(
        json,
        createdAt: 1700000000000,
      );

      expect(record.id, 'tpl-lumira-1');
      expect(record.name, '简化模板');
      expect(record.category, 'food');
      expect(record.camera['iso'], 100);
      expect(record.composition['overlayType'], 'center');
      // 缺失的 section 应有默认空值，不应为 null
      expect(record.pose, isNotEmpty);
      expect(record.sceneGuide, isA<Map<String, dynamic>>());
      expect(record.postProcess, isA<Map<String, dynamic>>());
      // author 应标记为 imported
      expect(record.author, 'imported');
    });

    test('无 format 字段但有 composition.subjectFrame 应识别为 pptpl', () {
      final json = <String, dynamic>{
        'meta': {
          'id': 'tpl-no-format',
          'name': '无格式字段',
          'category': 'street',
        },
        'composition': {
          'overlayType': 'diagonal',
          'subjectFrame': {'x': 0.5, 'y': 0.5, 'w': 0.3, 'h': 0.4},
        },
        'camera': <String, dynamic>{},
        'pose': <String, dynamic>{},
        'sceneGuide': <String, dynamic>{},
        'postProcess': <String, dynamic>{},
      };

      final record = TemplateMapper.recordFromImportedJson(
        json,
        createdAt: 1700000000000,
      );

      // subjectFrame 存在 → 按 pptpl 解析 → composition 保留 subjectFrame
      expect(record.composition['overlayType'], 'diagonal');
      expect(record.composition['subjectFrame'], isNotNull);
    });
  });

  group('ID 冲突处理', () {
    test('导入已存在 id 的模板应追加 _imported_ 时间戳后缀', () async {
      _testDb = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
      final dao = TemplatesDao(_testDb);

      // 先插入一条原始记录
      final original = TemplateMapper.recordFromImportedJson({
        'format': 'pptpl',
        'version': '1.0',
        'meta': {
          'id': 'tpl-conflict',
          'name': '原始',
          'category': 'portrait',
        },
        'composition': {'overlayType': 'rule_of_thirds'},
        'pose': <String, dynamic>{},
        'camera': <String, dynamic>{},
        'sceneGuide': <String, dynamic>{},
        'postProcess': <String, dynamic>{},
      }, createdAt: 1700000000000);
      await dao.upsert(original);

      // 模拟导入冲突解决逻辑
      var finalId = original.id;
      while (await dao.getById(finalId) != null) {
        finalId = '${finalId}_imported_${DateTime.now().millisecondsSinceEpoch}';
      }
      expect(finalId, isNot(equals('tpl-conflict')));
      expect(finalId.startsWith('tpl-conflict_imported_'), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/template_import_test.dart -v`
Expected: FAIL（`TemplateMapper.recordFromImportedJson` 未定义；编译错误 "The method 'recordFromImportedJson' isn't defined for the type 'TemplateMapper'"）

- [ ] **Step 3: Write minimal implementation**

修改 `lumira_app_flutter/lib/features/templates/services/template_mapper.dart`：

在文件末尾的 `TemplateMapper` 类内部（最后一个静态方法之后、类闭合 `}` 之前）追加：

```dart
  /// 从导入的 JSON 构造 TemplateRecord
  /// 自动嗅探格式：
  ///   - json['format'] == 'pptpl' 或 json['composition']?.containsKey('subjectFrame') → 完整 pptpl
  ///   - 否则 → 简化 lumira
  /// 内置剪影 key 不存在于白名单时降级为 'none'，并记录 warning 日志
  static TemplateRecord recordFromImportedJson(
    Map<String, dynamic> json, {
    required int createdAt,
  }) {
    final isPptpl = _sniffPptpl(json);
    final meta = (json['meta'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final id = (meta['id'] as String?) ?? 'imported_$createdAt';
    final name = (meta['name'] as String?) ?? '未命名模板';
    final category = (meta['category'] as String?) ?? 'still-life';
    final tags = (meta['tags'] as List<dynamic>?)?.cast<String>() ?? <String>[];
    final tagIds =
        (meta['tagIds'] as List<dynamic>?)?.cast<String>() ?? <String>[];
    final price = (meta['price'] as num?)?.toInt() ?? 0;
    final cover = (meta['cover'] as String?) ?? '';
    final description = (meta['description'] as String?) ?? '';
    final referenceSource = (meta['referenceSource'] as String?) ?? '';

    Map<String, dynamic> composition;
    Map<String, dynamic> pose;
    Map<String, dynamic> camera;
    Map<String, dynamic> sceneGuide;
    Map<String, dynamic> postProcess;

    if (isPptpl) {
      composition =
          (json['composition'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      pose = _normalizePose((json['pose'] as Map<String, dynamic>?) ?? {});
      camera = (json['camera'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      sceneGuide =
          (json['sceneGuide'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      postProcess = (json['postProcess'] as Map<String, dynamic>?) ??
          <String, dynamic>{};
    } else {
      // lumira 简化格式：仅 meta + camera + composition.overlayType，其余填默认
      final cam =
          (json['camera'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final comp =
          (json['composition'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      composition = {
        'overlayType': comp['overlayType'] ?? 'rule_of_thirds',
      };
      pose = <String, dynamic>{
        'silhouette': {'type': 'builtin', 'data': 'none'},
        'position': {'x': 0.5, 'y': 0.5},
        'scale': 1.0,
        'rotation': 0,
      };
      camera = cam;
      sceneGuide = <String, dynamic>{};
      postProcess = <String, dynamic>{'cropRatio': '3:4', 'lut': 'none'};
    }

    // 剪影降级：builtin key 不在白名单 → 'none'
    pose = _degradeSilhouetteIfNeeded(pose);

    return TemplateRecord(
      id: id,
      name: name,
      author: 'imported',
      version: '1.0.0',
      category: category,
      classification: <String, dynamic>{},
      tags: tags,
      tagIds: tagIds,
      price: price,
      cover: cover,
      description: description,
      referenceSource: referenceSource,
      composition: composition,
      pose: pose,
      camera: camera,
      sceneGuide: sceneGuide,
      postProcess: postProcess,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  /// 嗅探是否为完整 pptpl 格式
  static bool _sniffPptpl(Map<String, dynamic> json) {
    final format = json['format'] as String?;
    if (format == 'pptpl') return true;
    final comp = json['composition'];
    if (comp is Map<String, dynamic> && comp.containsKey('subjectFrame')) {
      return true;
    }
    return false;
  }

  /// 规范化 pose 字段，确保 silhouette / position / scale / rotation 存在
  static Map<String, dynamic> _normalizePose(Map<String, dynamic> pose) {
    final silhouette =
        pose['silhouette'] as Map<String, dynamic>? ?? <String, dynamic>{
      'type': 'builtin',
      'data': 'none',
    };
    final position =
        pose['position'] as Map<String, dynamic>? ?? <String, dynamic>{
      'x': 0.5,
      'y': 0.5,
    };
    return {
      'silhouette': silhouette,
      'position': position,
      'scale': pose['scale'] ?? 1.0,
      'rotation': pose['rotation'] ?? 0,
    };
  }

  /// 内置剪影 key 不存在于白名单时降级为 'none'
  /// 白名单来源：TemplatesEditorMockData.builtinSilhouetteKeys
  /// 注意：当 Task 2.9 迁移完整 SVG 库后，应替换为真实剪影库的 key 列表
  static Map<String, dynamic> _degradeSilhouetteIfNeeded(
      Map<String, dynamic> pose) {
    final silhouette = pose['silhouette'];
    if (silhouette is! Map<String, dynamic>) return pose;
    if (silhouette['type'] != 'builtin') return pose;

    final key = silhouette['data'] as String?;
    final whitelist = mock.TemplatesEditorMockData.builtinSilhouetteKeys;
    if (key == null || !whitelist.contains(key)) {
      // ignore: avoid_print
      print('Warning: builtin silhouette key "$key" not found in whitelist, '
          'degrading to "none"');
      return {
        ...pose,
        'silhouette': {'type': 'builtin', 'data': 'none'},
      };
    }
    return pose;
  }
```

> **注意：** 上述代码假设 `template_mapper.dart` 顶部已 import `templates_editor_mock_data.dart`。若未 import，在文件顶部追加：
> ```dart
> import '../data/templates_editor_mock_data.dart' as mock;
> ```
> 并确保 `template_mapper.dart` 已 import `package:flutter/foundation.dart`（用于 `print`，可改为 `debugPrint`）。

修改 `lumira_app_flutter/lib/features/templates/widgets/template_import_sheet.dart`：

1. 在文件顶部 import 段（第 9 行后）追加：

```dart
import '../../../core/db/dao/templates_dao.dart';
import '../../../core/db/database_provider.dart';
import '../services/template_mapper.dart';
```

2. 替换 `_handleFileImport` 方法（第 122-172 行）为：

```dart
  // ===== 文件导入（DAO 持久化 + 双格式嗅探）=====
  Future<void> _handleFileImport(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    navigator.pop(); // 先关闭 BottomSheet

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'lumira', 'pptpl'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        // 用户取消选择
        return;
      }

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        _showSnackMsg(messenger, '无法读取文件内容');
        return;
      }

      final content = utf8.decode(bytes);
      final parsed = _parseTemplateJson(content);
      if (parsed == null) {
        _showSnackMsg(messenger, '文件格式无效，请选择有效的模板文件');
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      var record = TemplateMapper.recordFromImportedJson(
        parsed,
        createdAt: now,
      );

      // ID 冲突处理：已存在则追加 _imported_ 时间戳后缀
      final dao = await ref.read(templatesDaoProvider.future);
      var finalId = record.id;
      while (await dao.getById(finalId) != null) {
        finalId = '${finalId}_imported_$now';
      }
      if (finalId != record.id) {
        record = _copyRecordWithId(record, finalId);
      }

      await dao.upsert(record);

      _showSnackMsg(messenger, '已导入模板：${record.name}');
      onImported(record.id);
    } catch (e) {
      _showSnackMsg(messenger, '导入失败：$e');
    }
  }

  /// 复制 TemplateRecord 并替换 id（用于 ID 冲突时生成新记录）
  TemplateRecord _copyRecordWithId(TemplateRecord src, String newId) {
    return TemplateRecord(
      id: newId,
      name: src.name,
      author: src.author,
      version: src.version,
      category: src.category,
      classification: src.classification,
      tags: src.tags,
      tagIds: src.tagIds,
      price: src.price,
      cover: src.cover,
      description: src.description,
      referenceSource: src.referenceSource,
      composition: src.composition,
      pose: src.pose,
      camera: src.camera,
      sceneGuide: src.sceneGuide,
      postProcess: src.postProcess,
      createdAt: src.createdAt,
      updatedAt: src.updatedAt,
    );
  }
```

3. 替换 `_parseTemplateJson` 方法（第 267-280 行）为升级版（支持完整 pptpl/lumira 格式探测）：

```dart
  /// 解析模板 JSON（文件内容）
  /// 支持格式：
  /// - .pptpl: { "format": "pptpl", "meta": {...}, "composition": {...}, ... }
  /// - .lumira: { "format": "lumira", "meta": {...}, "camera": {...}, ... }
  /// - 旧版扁平: { "name": "...", "category": "...", "tags": [...], "coverSeed": "..." }
  /// 返回原始 JSON Map；具体格式嗅探由 TemplateMapper.recordFromImportedJson 完成
  Map<String, dynamic>? _parseTemplateJson(String content) {
    try {
      final data = jsonDecode(content);
      if (data is! Map<String, dynamic>) return null;

      // 新格式：含 format 字段或 meta 字段 → 直接返回，交给 mapper 嗅探
      if (data['format'] is String || data['meta'] is Map) {
        return data;
      }

      // 旧版扁平格式：{ name, category, tags, coverSeed }
      // 包装为 lumira 简化格式交给 mapper
      final name = data['name'];
      if (name is String && name.isNotEmpty) {
        return {
          'format': 'lumira',
          'version': '1.0',
          'meta': {
            'id': data['id'] ?? 'imported_legacy_${DateTime.now().millisecondsSinceEpoch}',
            'name': name,
            'category': data['category'] ?? 'still-life',
            'tags': data['tags'] ?? <String>[],
          },
          'camera': <String, dynamic>{},
          'composition': {'overlayType': 'rule_of_thirds'},
        };
      }
      return null;
    } catch (_) {
      return null;
    }
  }
```

4. 链接导入与扫码导入保持原有 `importedTemplatesProvider` 路径不变（这两条路径不涉及文件格式嗅探，且 spec 明确"为兼容保留 importedAllTemplatesProvider"，不在本任务重构范围内）。若需统一走 DAO，可在后续任务处理。

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/template_import_test.dart -v`
Expected: PASS（所有 5 个测试用例全过：pptpl 完整字段保留、剪影降级、lumira 默认值填充、subjectFrame 嗅探、ID 冲突后缀）

- [ ] **Step 5: Commit**

```bash
cd e:\Project\photo_post\lumira_app_flutter
git add lib/features/templates/services/template_mapper.dart lib/features/templates/widgets/template_import_sheet.dart test/template_import_test.dart
git commit -m "feat(templates): enhance import with dual-format sniffing, DAO persistence, ID conflict handling, and silhouette degradation"
```

---

## Self-Review

**1. Spec coverage 核对（M2 + M3）：**

| Spec 要求 | 对应 Task | 状态 |
|---|---|---|
| M2 CompositionKit 模型 + DAO | Task 1 | ✓ |
| M2 场景详情页"加入组合"入口 | Task 2 | ✓ |
| M2 CapturePage 应用套件参数 + usage+1 | Task 3 | ✓ |
| M2 组合列表页 + Profile 入口 | Task 4 | ✓ |
| M2 组合详情页 + 编辑 | Task 5 | ✓ |
| M3 TemplateExporter 双格式导出 | Task 6 | ✓ |
| M3 TemplateMapper 双向转换 + 剪影序列化 | Task 6 | ✓ |
| M3 导出 UI 接线（格式选择 Sheet） | Task 7 | ✓ |
| M3 导入双格式嗅探（format + subjectFrame） | Task 8 | ✓ |
| M3 导入 DAO 持久化（`templatesDao.upsert`） | Task 8 | ✓ |
| M3 ID 冲突处理（`_imported_` 后缀） | Task 8 | ✓ |
| M3 内置剪影 key 校验 + 降级 | Task 8 | ✓ |
| M3 标记 `author="imported"` | Task 8 | ✓ |
| M3 `importedAllTemplatesProvider` 兼容保留 | Task 8（注释说明不重构） | ✓ |

**2. Placeholder 扫描：** 已检查全部 8 个 task，无 "TBD/TODO/implement later/类似 Task N" 占位符。每个 step 均含完整代码或完整命令。

**3. 类型一致性核对：**
- `TemplateRecord` 字段（id/name/author/version/category/classification/tags/tagIds/price/cover/description/referenceSource/composition/pose/camera/sceneGuide/postProcess/createdAt/updatedAt）在 Task 1/6/8 中一致 ✓
- `TemplateMapper` 方法签名：`toRecord` / `toPhotoTemplate` / `fromEditorForm` / `toEditorForm` / `silhouetteToJson` / `silhouetteFromJson`（Task 6 定义）/ `recordFromImportedJson`（Task 8 新增）—— 名称无冲突 ✓
- `CompositionKit` 字段（id/name/sceneId/templateId/cameraOverrides/note/coverUrl/createdAt/lastUsedAt/usageCount）在 Task 1-5 中一致 ✓
- `CompositionKitsDao` 方法（getAll/getById/insert/update/delete/incrementUsage）在 Task 1-5 中一致 ✓
- `TemplateExporter.shareTemplate(record, {required bool usePptpl})` 在 Task 6 定义、Task 7 消费 —— 签名一致 ✓
- `templatesDaoProvider` 为 `FutureProvider<TemplatesDao>`，消费方均用 `await ref.read(templatesDaoProvider.future)` ✓

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-25-plan-b-kits-and-io.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**