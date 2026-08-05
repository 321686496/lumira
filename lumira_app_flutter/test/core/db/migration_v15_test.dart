import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 15,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  });

  tearDown(() async => db.close());

  test('v15 migration creates user_profile table', () async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='user_profile'",
    );
    expect(tables.length, 1);

    final cols = await db.rawQuery('PRAGMA table_info(user_profile)');
    final colNames = cols.map((c) => c['name'] as String).toSet();
    expect(colNames, containsAll(['id', 'username', 'avatar_seed', 'updated_at', 'synced_at']));
  });

  test('user_profile table stores single row by id=1', () async {
    await db.insert('user_profile', {
      'id': 1,
      'username': '默认昵称',
      'avatar_seed': 'lumira-avatar-01',
      'updated_at': 1700000000,
      'synced_at': null,
    });
    final rows = await db.query('user_profile');
    expect(rows.length, 1);
    expect(rows.first['username'], '默认昵称');
  });
}

Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS user_profile (
      id INTEGER PRIMARY KEY DEFAULT 1,
      username TEXT NOT NULL,
      avatar_seed TEXT NOT NULL,
      updated_at INTEGER NOT NULL,
      synced_at INTEGER
    )
  ''');
}

Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 15) {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profile (
        id INTEGER PRIMARY KEY DEFAULT 1,
        username TEXT NOT NULL,
        avatar_seed TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        synced_at INTEGER
      )
    ''');
  }
}
