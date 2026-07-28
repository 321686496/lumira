import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/db/dao/gallery_dao.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';

void main() {
  late Database db;
  late GalleryDao dao;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('gallery_edit_test_');
    final dbPath = p.join(tempDir.path, 'test_gallery.db');
    db = await openDatabase(dbPath, version: 1, onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE ${Tables.galleryItems} (
          ${Tables.colId} TEXT PRIMARY KEY,
          ${Tables.colDataUrl} TEXT,
          ${Tables.colFilePath} TEXT,
          ${Tables.colOriginalPath} TEXT,
          ${Tables.colTransform} TEXT,
          ${Tables.colPostProcess} TEXT,
          ${Tables.colSceneId} TEXT,
          ${Tables.colTemplateId} TEXT,
          ${Tables.colKitId} TEXT,
          ${Tables.colMood} TEXT,
          ${Tables.colLut} TEXT,
          ${Tables.colCreatedAt} INTEGER NOT NULL
        )
      ''');
    });
    dao = GalleryDao(db);
  });

  tearDown(() async => await db.close());

  test('insert and read with new fields', () async {
    final record = GalleryItemRecord(
      id: 'p1',
      filePath: '/tmp/p1.jpg',
      originalPath: '/tmp/p1.original.jpg',
      transform: const TransformParams(rotation: 90, flipH: true),
      postProcess: const PostProcess(
        cropRatio: '3:4',
        color: PostProcessColor(brightness: 10),
        smoothStrength: 20,
      ),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await dao.insert(record);

    final read = await dao.getById('p1');
    expect(read, isNotNull);
    expect(read!.originalPath, '/tmp/p1.original.jpg');
    expect(read.transform, const TransformParams(rotation: 90, flipH: true));
    expect(read.postProcess, isNotNull);
    expect(read.postProcess!.smoothStrength, 20);
    expect(read.postProcess!.color.brightness, 10);
  });

  test('insert with null new fields (backward compat)', () async {
    final record = GalleryItemRecord(
      id: 'old1',
      filePath: '/tmp/old.jpg',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await dao.insert(record);

    final read = await dao.getById('old1');
    expect(read, isNotNull);
    expect(read!.originalPath, isNull);
    expect(read.transform, isNull);
    expect(read.postProcess, isNull);
  });

  test('updateEdit updates file path, original, transform, postProcess', () async {
    final record = GalleryItemRecord(
      id: 'p2',
      filePath: '/tmp/p2.jpg',
      originalPath: '/tmp/p2.original.jpg',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await dao.insert(record);

    await dao.updateEdit(
      id: 'p2',
      filePath: '/tmp/p2_edited.jpg',
      originalPath: '/tmp/p2.original.jpg',
      transform: const TransformParams(rotation: 180),
      postProcess: const PostProcess(
        color: PostProcessColor(contrast: 20),
        sharpen: 30,
      ),
    );

    final read = await dao.getById('p2');
    expect(read!.filePath, '/tmp/p2_edited.jpg');
    expect(read.originalPath, '/tmp/p2.original.jpg');
    expect(read.transform, const TransformParams(rotation: 180));
    expect(read.postProcess!.sharpen, 30);
    expect(read.postProcess!.color.contrast, 20);
  });

  test('updateEdit can clear originalPath (set to null)', () async {
    final record = GalleryItemRecord(
      id: 'p3',
      filePath: '/tmp/p3.jpg',
      originalPath: '/tmp/p3.original.jpg',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await dao.insert(record);

    await dao.updateEdit(
      id: 'p3',
      filePath: '/tmp/p3.jpg',
      originalPath: null,
      transform: null,
      postProcess: null,
    );

    final read = await dao.getById('p3');
    expect(read!.originalPath, isNull);
  });
}
