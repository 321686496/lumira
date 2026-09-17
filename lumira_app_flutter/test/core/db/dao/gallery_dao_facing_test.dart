import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/core/db/dao/gallery_dao.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/capture/domain/post_process_delta.dart';

/// facing（镜头朝向）持久化回归测试（2026-09-16 修复：前置照片编辑保存后水平翻转）。
///
/// 链路：拍摄落库（postProcess.facing）→ 编辑页读取 baked → 全量参数 merge 保留
/// facing → processFile 据此在「从原图重新处理」时补做前置镜像。
void main() {
  late Database db;
  late GalleryDao dao;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('gallery_facing_test_');
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
          ${Tables.colGalleryItemIsFavorite} INTEGER NOT NULL DEFAULT 0,
          ${Tables.colGalleryItemHidden} INTEGER NOT NULL DEFAULT 0,
          ${Tables.colCreatedAt} INTEGER NOT NULL
        )
      ''');
    });
    dao = GalleryDao(db);
  });

  tearDown(() async => await db.close());

  test('PostProcess facing JSON round-trip', () {
    const front = PostProcess(color: PostProcessColor(), facing: 'front');
    final json = front.toJson();
    expect(json['facing'], 'front');
    final restored = PostProcess.fromJson(json);
    expect(restored.facing, 'front');

    // 旧记录无 facing 字段 → null（向后兼容，视为 back）
    final legacy =
        PostProcess.fromJson(<String, dynamic>{'cropRatio': '3:4', 'color': <String, dynamic>{}});
    expect(legacy.facing, isNull);
  });

  test('GalleryItemRecord toRow/fromRow keeps facing (+wbResidual/fillLight)',
      () async {
    final record = GalleryItemRecord(
      id: 'p_front',
      filePath: '/tmp/p.jpg',
      originalPath: '/tmp/p.original.jpg',
      postProcess: const PostProcess(
        color: PostProcessColor(brightness: 10),
        smoothStrength: 30,
        sharpen: 25,
        facing: 'front',
        wbResidual: WbResidual(r: 1.1, g: 1.0, b: 0.9),
      ),
      createdAt: 1000,
    );
    await dao.insert(record);
    final loaded = await dao.getById('p_front');
    expect(loaded, isNotNull);
    expect(loaded!.postProcess?.facing, 'front');
    // 此前扁平序列化丢失 wbResidual → 编辑重保存后 iOS 白平衡补足失效
    expect(loaded.postProcess?.wbResidual?.r, 1.1);

    // updateEdit 保留 facing（编辑保存不改变拍摄朝向）
    await dao.updateEdit(
      id: 'p_front',
      filePath: '/tmp/p2.jpg',
      originalPath: '/tmp/p.original.jpg',
      transform: const TransformParams(),
      postProcess: const PostProcess(
        color: PostProcessColor(),
        smoothStrength: 60,
        facing: 'front',
      ),
    );
    final updated = await dao.getById('p_front');
    expect(updated!.postProcess?.facing, 'front');
    expect(updated.postProcess?.smoothStrength, 60);
  });

  test('merge keeps baked facing: baked(front) + local delta', () {
    const baked = PostProcess(color: PostProcessColor(), facing: 'front');
    const delta = PostProcess(color: PostProcessColor(), smoothStrength: 30);
    final full = baked.merge(delta);
    expect(full.smoothStrength, 30);
    expect(full.facing, 'front');

    // deltaOf 反推增量不含 facing（拍摄元数据不可增量调节）
    final nextDelta =
        deltaOf(baked, baked.merge(const PostProcess(color: PostProcessColor(), sharpen: 10)));
    expect(nextDelta.facing, isNull);
    expect(nextDelta.sharpen, 10);
  });

  test('capture-era record JSON (as written by capture_page) round-trips',
      () async {
    // 模拟 capture_page 落库：postProcess.copyWith(cropRatio, facing)
    final captured = const PostProcess(color: PostProcessColor()).copyWith(
      cropRatio: 'fullscreen',
      facing: 'front',
    );
    final record = GalleryItemRecord(
      id: 'p_cap',
      filePath: '/tmp/c.jpg',
      originalPath: '/tmp/c.original.jpg',
      postProcess: captured,
      createdAt: 2000,
    );
    await dao.insert(record);
    final loaded = await dao.getById('p_cap');
    expect(loaded!.postProcess?.cropRatio, 'fullscreen');
    expect(loaded.postProcess?.facing, 'front');
    // jsonEncode 直接走 PostProcess.toJson 时 facing 也在（双通道序列化一致）
    expect(jsonEncode(captured.toJson()), contains('facing'));
  });
}
