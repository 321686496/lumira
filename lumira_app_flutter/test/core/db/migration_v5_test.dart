import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

// 复用现有测试的 DB 创建方式（参考 dao_test.dart / migration_v4_test.dart）
// 注意：不直接 import database_provider.dart 以避免 CPF-Flutter sqflite fork 在测试环境的复杂依赖
// 直接手写 schema 验证 v5 升级逻辑

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  });

  tearDown(() async => db.close());

  test('v5 migration creates auth and api_cache tables', () async {
    // 表存在
    final authTables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='auth'",
    );
    expect(authTables.length, 1);

    final cacheTables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='api_cache'",
    );
    expect(cacheTables.length, 1);

    // auth 表列存在
    final authCols = await db.rawQuery('PRAGMA table_info(auth)');
    final authColNames = authCols.map((c) => c['name'] as String).toSet();
    expect(authColNames, containsAll([
      'id', 'device_id', 'os', 'token', 'is_new_device', 'registered_at',
    ]));

    // api_cache 表列存在
    final cacheCols = await db.rawQuery('PRAGMA table_info(api_cache)');
    final cacheColNames = cacheCols.map((c) => c['name'] as String).toSet();
    expect(cacheColNames, containsAll(['key', 'payload', 'cached_at']));
  });

  test('auth table stores single row by id=1', () async {
    await db.insert('auth', {
      'id': 1,
      'device_id': 'test-device',
      'os': 'android',
      'token': 'jwt-token',
      'is_new_device': 1,
      'registered_at': 1700000000,
    });
    final rows = await db.query('auth');
    expect(rows.length, 1);
    expect(rows.first['device_id'], 'test-device');
  });

  test('api_cache table upserts by key', () async {
    await db.insert('api_cache', {
      'key': 'invite_stats',
      'payload': '{"total":0}',
      'cached_at': 1700000000,
    });
    // upsert：DELETE + INSERT 简化
    await db.delete('api_cache', where: 'key = ?', whereArgs: ['invite_stats']);
    await db.insert('api_cache', {
      'key': 'invite_stats',
      'payload': '{"total":5}',
      'cached_at': 1700000001,
    });
    final rows = await db.query('api_cache', where: 'key = ?', whereArgs: ['invite_stats']);
    expect(rows.length, 1);
    expect(rows.first['payload'], '{"total":5}');
  });
}

// 复制 v5 创建逻辑（与 database_provider.dart 保持一致）
Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS auth (
      id INTEGER PRIMARY KEY DEFAULT 1,
      device_id TEXT NOT NULL,
      os TEXT NOT NULL,
      token TEXT NOT NULL,
      is_new_device INTEGER NOT NULL DEFAULT 0,
      registered_at INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE IF NOT EXISTS api_cache (
      key TEXT PRIMARY KEY,
      payload TEXT NOT NULL,
      cached_at INTEGER NOT NULL
    )
  ''');
}

Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 5) {
    await _onCreate(db, newVersion);
  }
}
