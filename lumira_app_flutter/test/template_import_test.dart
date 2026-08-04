import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/templates/services/template_mapper.dart';
import 'package:lumira_app_flutter/features/templates/data/templates_editor_mock_data.dart'
    as mock;

Database? _testDb;

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
      ${Tables.colCoverData} TEXT,
      ${Tables.colDescription} TEXT NOT NULL DEFAULT '',
      ${Tables.colReferenceSource} TEXT NOT NULL DEFAULT '',
      ${Tables.colCompositionJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPoseJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colCameraJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colSceneGuideJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPostProcessJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colIsBuiltin} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colIsRecommended} INTEGER NOT NULL DEFAULT 0,
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
    final db = _testDb;
    if (db != null && db.isOpen) await db.close();
    _testDb = null;
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

    test('剪影 builtin key 存在于完整库时应保留（不降级）', () {
      final json = <String, dynamic>{
        'format': 'pptpl',
        'version': '1.0',
        'meta': {
          'id': 'tpl-neon-pose',
          'name': '霓虹剪影',
          'category': 'portrait',
        },
        'composition': {'overlayType': 'rule_of_thirds'},
        'pose': {
          'silhouette': {
            'type': 'builtin',
            'data': 'neon-pose',
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
      expect(record.pose['silhouette']['data'], 'neon-pose');
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

    test('无 format 字段但有 composition.subjectFrames 应识别为 pptpl', () {
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
      final dao = TemplatesDao(_testDb!);

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

  group('TemplateRecord coverData', () {
    test('toRow/fromRow round-trips coverData', () async {
      final db = await openDatabase(inMemoryDatabasePath, version: 1,
          onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE ${Tables.customTemplates} (
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
            ${Tables.colCoverData} TEXT,
            ${Tables.colDescription} TEXT NOT NULL DEFAULT '',
            ${Tables.colReferenceSource} TEXT NOT NULL DEFAULT '',
            ${Tables.colCompositionJson} TEXT NOT NULL DEFAULT '{}',
            ${Tables.colPoseJson} TEXT NOT NULL DEFAULT '{}',
            ${Tables.colCameraJson} TEXT NOT NULL DEFAULT '{}',
            ${Tables.colSceneGuideJson} TEXT NOT NULL DEFAULT '{}',
            ${Tables.colPostProcessJson} TEXT NOT NULL DEFAULT '{}',
            ${Tables.colIsBuiltin} INTEGER NOT NULL DEFAULT 0,
            ${Tables.colIsRecommended} INTEGER NOT NULL DEFAULT 0,
            ${Tables.colCreatedAt} INTEGER NOT NULL,
            ${Tables.colUpdatedAt} INTEGER NOT NULL
          )
        ''');
      });

      final record = TemplateRecord(
        id: 'test-cover',
        name: '测试',
        author: '',
        version: '1.0.0',
        category: 'portrait',
        classification: {},
        tags: [],
        tagIds: [],
        price: 0,
        cover: 'assets/images/templates/test.jpg',
        coverData: 'data:image/jpeg;base64,abc123',
        description: '',
        referenceSource: '',
        composition: {},
        pose: {},
        camera: {},
        sceneGuide: {},
        postProcess: {},
        createdAt: 1700000000000,
        updatedAt: 1700000000000,
        isBuiltin: false,
        isRecommended: false,
      );

      await db.insert(Tables.customTemplates, record.toRow());
      final rows = await db.query(Tables.customTemplates);
      final restored = TemplateRecord.fromRow(rows.first);

      expect(restored.coverData, 'data:image/jpeg;base64,abc123');
      await db.close();
    });
  });
}
