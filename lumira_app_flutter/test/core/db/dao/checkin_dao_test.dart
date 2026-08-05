import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/checkin/data/checkin_dao.dart';
import 'package:lumira_app_flutter/features/checkin/data/checkin_models.dart';

void main() {
  late Database db;
  late CheckinDao dao;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: (d, v) async {
      await d.execute(CheckinTable.createSql);
      await d.execute(CheckinTable.indexVisitedAtSql);
      await d.execute(CheckinPhotoTable.createSql);
      await d.execute(CheckinPhotoTable.indexCheckinSql);
    });
    dao = CheckinDao(db);
  });

  tearDown(() async => db.close());

  CheckinRecord make(String id, {int visitedAt = 1000, String name = '测试店铺'}) {
    return CheckinRecord(
      id: id, name: name, place: '上海', category: 'coffee', rating: 4,
      note: '很好', visitedAt: visitedAt, createdAt: 1, updatedAt: 2,
    );
  }

  group('checkins CRUD', () {
    test('insert + getById', () async {
      expect(await dao.insert(make('c1')), 'c1');
      final rec = await dao.getById('c1');
      expect(rec, isNotNull);
      expect(rec!.name, '测试店铺');
      expect(rec.place, '上海');
      expect(rec.category, 'coffee');
      expect(rec.rating, 4);
      expect(rec.note, '很好');
      expect(rec.visitedAt, 1000);
    });

    test('getById 不存在返回 null', () async {
      expect(await dao.getById('none'), isNull);
    });

    test('getAll 按 visited_at 倒序', () async {
      await dao.insert(make('a', visitedAt: 1000));
      await dao.insert(make('b', visitedAt: 3000));
      await dao.insert(make('c', visitedAt: 2000));
      expect((await dao.getAll()).map((r) => r.id).toList(), ['b', 'c', 'a']);
    });

    test('update 修改全部字段', () async {
      await dao.insert(make('c1'));
      await dao.update(CheckinRecord(
        id: 'c1', name: '改名', place: '北京', category: 'art', rating: 5,
        note: '新心得', visitedAt: 9000, createdAt: 1, updatedAt: 999,
      ));
      final rec = await dao.getById('c1');
      expect(rec!.name, '改名');
      expect(rec.place, '北京');
      expect(rec.category, 'art');
      expect(rec.rating, 5);
      expect(rec.note, '新心得');
      expect(rec.visitedAt, 9000);
      expect(rec.updatedAt, 999);
    });

    test('countAll', () async {
      expect(await dao.countAll(), 0);
      await dao.insert(make('a'));
      await dao.insert(make('b'));
      expect(await dao.countAll(), 2);
    });

    test('delete 级联删除照片关联', () async {
      await dao.insert(make('c1'));
      await dao.replacePhotos('c1', ['p1', 'p2']);
      expect(await dao.getPhotoIds('c1'), ['p1', 'p2']);
      await dao.delete('c1');
      expect(await dao.getById('c1'), isNull);
      expect(await dao.getPhotoIds('c1'), isEmpty);
    });
  });

  group('checkin_photos', () {
    test('replacePhotos 整体替换并保序', () async {
      await dao.insert(make('c1'));
      await dao.replacePhotos('c1', ['a', 'b', 'c']);
      expect(await dao.getPhotoIds('c1'), ['a', 'b', 'c']);
      await dao.replacePhotos('c1', ['x', 'y']);
      expect(await dao.getPhotoIds('c1'), ['x', 'y']);
    });

    test('replacePhotos 空列表清空', () async {
      await dao.insert(make('c1'));
      await dao.replacePhotos('c1', ['a']);
      await dao.replacePhotos('c1', []);
      expect(await dao.getPhotoIds('c1'), isEmpty);
    });
  });
}
