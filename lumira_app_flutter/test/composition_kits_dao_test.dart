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
