import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:lumira_app_flutter/core/db/dao/settings_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';

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
            compliance_agreed INTEGER NOT NULL DEFAULT 0,
            compliance_version TEXT,
            compliance_agreed_at INTEGER,
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

  test('getComplianceVersion returns null before agreement', () async {
    expect(await dao.getComplianceVersion(), isNull);
  });

  test('setComplianceAgreed persists version and agreed flag', () async {
    await dao.setComplianceAgreed('2026-08-24');
    expect(await dao.getComplianceVersion(), '2026-08-24');
    final rows = await db.query('user_settings', where: 'id = 1');
    expect(rows.first['compliance_agreed'], equals(1));
    expect(rows.first['compliance_version'], equals('2026-08-24'));
  });

  test('setComplianceAgreed overwrites previous version', () async {
    await dao.setComplianceAgreed('2026-08-24');
    await dao.setComplianceAgreed('2026-09-01');
    expect(await dao.getComplianceVersion(), '2026-09-01');
  });

  test('getComplianceVersion returns null when row missing', () async {
    await db.delete('user_settings', where: 'id = 1');
    expect(await dao.getComplianceVersion(), isNull);
  });
}