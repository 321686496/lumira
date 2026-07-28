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
    final rows = await db.query('user_settings', where: 'id = 1');
    expect(rows.first['auto_deblur'], equals(0));
  });

  test('setAutoDeblur(true) after false works', () async {
    await dao.setAutoDeblur(false);
    await dao.setAutoDeblur(true);
    expect(await dao.getAutoDeblur(), isTrue);
  });
}
