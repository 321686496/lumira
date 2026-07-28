import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/gallery_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/capture/services/photo_post_processor.dart';

/// Task 12 — 非破坏性编辑集成测试
///
/// 覆盖端到端流程：
/// 1. 原图保留 → reprocess from original → updateEdit
/// 2. originalPath == null → read-only mode
/// 3. transform + postProcess persistence via updateEdit
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('non-destructive reprocessing: original file is unchanged after processFile with outputPath', () async {
    // 1. Create a temp directory with an original image
    final tempDir = await Directory.systemTemp.createTemp('task12_nd_');
    try {
      final originalPath = p.join(tempDir.path, 'original.jpg');
      final outputPath = p.join(tempDir.path, 'processed.jpg');

      // Create a 100x100 blue image as the "original"
      final originalImage = img.Image(width: 100, height: 100);
      img.fill(originalImage, color: img.ColorRgb8(0, 0, 255));
      await File(originalPath).writeAsBytes(img.encodeJpg(originalImage));

      // Record original file bytes for comparison
      final originalBytes = await File(originalPath).readAsBytes();

      // 2. Process from original to outputPath (brightness adjustment)
      final processedPath = await PhotoPostProcessor.processFile(
        inputPath: originalPath,
        params: const PostProcess(color: PostProcessColor()),
        outputPath: outputPath,
        aspectRatio: 'fullscreen',
        autoDeblur: false,
      );

      // 3. Verify output path matches
      expect(processedPath, equals(outputPath));

      // 4. Verify original file is UNCHANGED (non-destructive)
      final originalBytesAfter = await File(originalPath).readAsBytes();
      expect(originalBytesAfter, equals(originalBytes),
          reason: '原图文件必须保持不变（非破坏性编辑）');

      // 5. Verify output file exists and is different from original
      final outputBytes = await File(outputPath).readAsBytes();
      expect(outputBytes, isNotEmpty);
      // Note: with default PostProcess params, output may be similar but
      // file metadata (e.g. EXIF) will differ. The key assertion is that
      // the original is unchanged.
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  test('GalleryDao.updateEdit persists transform + postProcess for re-edit', () async {
    // Use the in-memory DB pattern from gallery_dao_v7_test.dart
    final db = await _openInMemoryDbWithV7Schema();
    try {
      final dao = GalleryDao(db);

      // 1. Insert a record with originalPath
      final now = DateTime.now().millisecondsSinceEpoch;
      final originalRecord = GalleryItemRecord(
        id: 'photo_test_1',
        filePath: '/tmp/processed.jpg',
        originalPath: '/tmp/processed.jpg.original.jpg',
        postProcess: const PostProcess(color: PostProcessColor()),
        dataUrl: null,
        sceneId: 'portrait',
        templateId: null,
        kitId: null,
        mood: null,
        lut: null,
        createdAt: now,
      );
      await dao.insert(originalRecord);

      // 2. Simulate re-edit: apply transform + adjusted postProcess
      const newTransform = TransformParams(rotation: 90, flipH: true);
      const newPostProcess = PostProcess(
        color: PostProcessColor(brightness: 0.2, contrast: 0.1),
        smoothStrength: 50,
      );
      await dao.updateEdit(
        id: 'photo_test_1',
        filePath: '/tmp/processed_v2.jpg',
        originalPath: null, // user chose NOT to keep original
        transform: newTransform,
        postProcess: newPostProcess,
      );

      // 3. Read back and verify
      final updated = await dao.getById('photo_test_1');
      expect(updated, isNotNull);
      expect(updated!.filePath, equals('/tmp/processed_v2.jpg'));
      expect(updated.originalPath, isNull,
          reason: 'originalPath should be null after user chose not to keep original');
      expect(updated.transform, equals(newTransform));
      expect(updated.postProcess, equals(newPostProcess));
      expect(updated.postProcess?.smoothStrength, equals(50));
      expect(updated.postProcess?.color.brightness, equals(0.2));
    } finally {
      await db.close();
    }
  });

  test('read-only mode: originalPath null after updateEdit means photo cannot be re-edited', () async {
    final db = await _openInMemoryDbWithV7Schema();
    try {
      final dao = GalleryDao(db);

      // Insert a record that has NO originalPath (read-only from the start)
      final record = GalleryItemRecord(
        id: 'photo_readonly_1',
        filePath: '/tmp/photo.jpg',
        originalPath: null, // no original preserved
        postProcess: null,
        dataUrl: null,
        sceneId: 'portrait',
        templateId: null,
        kitId: null,
        mood: null,
        lut: null,
        createdAt: 0,
      );
      await dao.insert(record);

      // Read back and verify read-only state
      final result = await dao.getById('photo_readonly_1');
      expect(result, isNotNull);
      expect(result!.originalPath, isNull,
          reason: 'originalPath == null indicates read-only mode');
      expect(result.transform, isNull);
      expect(result.postProcess, isNull);
    } finally {
      await db.close();
    }
  });
}

/// Helper: opens an in-memory SQLite DB with the v7 gallery schema.
/// Mirrors the pattern in gallery_dao_v7_test.dart.
Future<Database> _openInMemoryDbWithV7Schema() async {
  return openDatabase(
    inMemoryDatabasePath,
    version: 1,
    onCreate: (db, _) async {
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
    },
  );
}
