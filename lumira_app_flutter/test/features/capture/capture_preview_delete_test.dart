import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/core/db/dao/gallery_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_thumbnail_state.dart';
import 'package:lumira_app_flutter/features/capture/pages/capture_preview_page.dart';

void main() {
  late Database db;
  late Directory tempDir;
  late File firstPhoto;
  late File secondPhoto;
  late ProviderContainer container;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
    tempDir = await Directory.systemTemp.createTemp('capture_preview_delete');
    firstPhoto = File('${tempDir.path}/first.jpg');
    secondPhoto = File('${tempDir.path}/second.jpg');
    await firstPhoto.writeAsBytes([1, 2, 3]);
    await secondPhoto.writeAsBytes([4, 5, 6]);

    final dao = GalleryDao(db);
    final now = DateTime.now().millisecondsSinceEpoch;
    await dao.insert(
      GalleryItemRecord(
        id: 'photo_1',
        filePath: firstPhoto.path,
        createdAt: now,
      ),
    );
    await dao.insert(
      GalleryItemRecord(
        id: 'photo_2',
        filePath: secondPhoto.path,
        createdAt: now - 1000,
      ),
    );

    container = ProviderContainer(
      overrides: [
        galleryDaoProvider.overrideWith((ref) async => dao),
        CaptureState.aspectRatioProvider.overrideWith((ref) => '3:4'),
      ],
    );
  });

  tearDown(() async {
    await db.close();
    container.dispose();
  });

  testWidgets('delete switches to the next remaining photo', (tester) async {
    container
        .read(captureThumbnailProvider.notifier)
        .setFinalResult(firstPhoto.path, 'photo_1');
    container.read(CaptureState.lastPhotoPathProvider.notifier).state =
        firstPhoto.path;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: CapturePreviewPage(
            photoUrl: firstPhoto.path,
            photoId: 'photo_1',
            aspectRatio: '3:4',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(find.byType(CapturePreviewPage), findsOneWidget);
    final thumbnail = container.read(captureThumbnailProvider);
    expect(thumbnail.status, CaptureThumbnailStatus.final_);
    expect(thumbnail.photoId, 'photo_2');
    expect(thumbnail.finalPath, secondPhoto.path);
    expect(container.read(CaptureState.lastPhotoPathProvider), secondPhoto.path);

    final currentImage = tester.widget<Image>(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is FileImage,
      ),
    );
    final fileImage = currentImage.image as FileImage;
    expect(fileImage.file.path, secondPhoto.path);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

Future<void> _onCreate(Database db, int version) async {
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
}
