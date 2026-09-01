import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/templates/data/templates_editor_mock_data.dart';
import 'package:lumira_app_flutter/features/templates/services/template_image_store.dart';
import 'package:lumira_app_flutter/features/templates/services/template_mapper.dart';

/// 复现「自定义模板保存后，剪影/封面图在编辑/详情页看不到」的根因：
/// `silhouetteFromJson` 调用 `normalizeAssetUrl(data)`，把以 `/` 开头的
/// 本地文件路径（如 `/data/user/0/.../silhouette_0.png`）误判为「服务端相对路径」，
/// 拼接后端 origin 后变成无法访问的 `https://lumira.iwtle.top/data/user/0/...`，
/// 导致剪影图加载失败。
///
/// 同样影响 `_imagesFromRecord` 中的 `r.cover`（自定义模板存的是本地路径），
/// 但 `toEditorForm` 路径上对 coverData/images 直接透传未调用 normalizeAssetUrl，
/// 所以编辑表单的封面图未受波及；剪影走 `silhouetteFromJson` 受波及。
void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(
      ':memory:',
      version: 1,
      onCreate: _onCreate,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('normalizeAssetUrl 对本地文件路径的影响', () {
    test('本地文件路径不应被 normalizeAssetUrl 拼接成服务端 URL', () {
      // 模拟 iOS/Android/OHOS 上的本地绝对路径
      const filePath = '/data/user/0/com.lumira.app/files/lumira/templates/user_123/silhouette_0.png';

      // normalizeAssetUrl 当前实现：以 `/` 开头 → 拼接服务端 origin
      // 期望：本地路径应原样返回（不拼接 origin）
      final result = TemplateMapper.normalizeAssetUrl(filePath);

      // 当前 bug：result 变成 https://lumira.iwtle.top/data/user/0/...
      // 修复后：result 应等于 filePath
      expect(result, filePath,
          reason: '本地文件路径不应被拼接服务端 origin，否则图片无法加载');
    });

    test('剪影 data 落盘后 round-trip 应保留本地路径（非服务端 URL）', () async {
      final tmpDir = await Directory.systemTemp.createTemp('sil_rt_');
      addTearDown(() async {
        if (tmpDir.existsSync()) await tmpDir.delete(recursive: true);
      });
      TemplateImageStore.overrideBaseDir = tmpDir.path;
      addTearDown(() => TemplateImageStore.overrideBaseDir = null);

      // 1x1 透明 PNG
      const pngB64 =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
      const dataUrl = 'data:image/png;base64,$pngB64';

      final form = EditorForm(
        meta: EditorFormMeta(
          name: '剪影路径测试',
          category: 'portrait',
          images: [EditorFormMetaImage(data: dataUrl)],
        ),
        composition: EditorFormComposition(),
        poses: [
          EditorFormPose(
            name: '姿势',
            silhouette: SilhouetteResource(type: 'image', data: dataUrl),
          ),
        ],
        camera: EditorFormCamera(),
        sceneGuide: EditorFormSceneGuide(),
        postProcess: EditorFormPostProcess(),
      );

      // 落盘：data URL → 文件，data 字段变成本地路径
      for (var i = 0; i < form.meta.images.length; i++) {
        final e = form.meta.images[i];
        if (e.data.isEmpty) continue;
        e.data = await TemplateImageStore.saveDataUrl(
            'user_sil', i == 0 ? 'cover' : 'img', i, e.data);
      }
      for (var i = 0; i < form.poses.length; i++) {
        final p = form.poses[i];
        if (p.silhouette.type == 'image' && p.silhouette.data.isNotEmpty) {
          p.silhouette.data = await TemplateImageStore.saveDataUrl(
              'user_sil', 'silhouette', i, p.silhouette.data);
        }
      }

      // 验证落盘后是本地路径
      expect(TemplateImageStore.isLocalImageRef(form.poses.first.silhouette.data),
          isTrue);

      final dao = TemplatesDao(db);
      final now = DateTime.now().millisecondsSinceEpoch;
      final record =
          TemplateMapper.fromEditorForm(form, id: 'user_sil', createdAt: now);
      await dao.upsert(record);

      final saved = (await dao.getCustomOnly()).first;

      // toEditorForm round-trip：剪影 data 应仍为本地路径
      final reloaded = TemplateMapper.toEditorForm(saved);
      final silData = reloaded.poses.first.silhouette.data;

      // 当前 bug：silData 被 normalizeAssetUrl 拼成 https://lumira.iwtle.top/...
      // 修复后：silData 应仍是本地路径
      expect(TemplateImageStore.isLocalImageRef(silData), isTrue,
          reason: '剪影 round-trip 后应保留本地路径，不应被拼接服务端 origin');
      expect(silData, startsWith(tmpDir.path),
          reason: '剪影路径应指向落盘的临时目录');
    });
  });
}

Future<void> _onCreate(Database db, int version) async {
  final batch = db.batch();
  batch.execute('''
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
      ${Tables.colShortDesc} TEXT NOT NULL DEFAULT '',
      ${Tables.colAmbienceJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colCompositionJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPoseJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colImagesJson} TEXT NOT NULL DEFAULT '[]',
      ${Tables.colCameraJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colSceneGuideJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colPostProcessJson} TEXT NOT NULL DEFAULT '{}',
      ${Tables.colIsBuiltin} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colIsRecommended} INTEGER NOT NULL DEFAULT 0,
      ${Tables.colSource} TEXT NOT NULL DEFAULT 'builtin',
      ${Tables.colCreatedAt} INTEGER NOT NULL,
      ${Tables.colUpdatedAt} INTEGER NOT NULL
    )
  ''');
  await batch.commit(noResult: true);
}
