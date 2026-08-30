import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';
import 'package:lumira_app_flutter/features/templates/data/templates_editor_mock_data.dart';
import 'package:lumira_app_flutter/features/templates/services/template_exporter.dart';
import 'package:lumira_app_flutter/features/templates/services/template_image_store.dart';
import 'package:lumira_app_flutter/features/templates/services/template_mapper.dart';

/// 复现「表单添加自定义模板 → 保存」的真实数据路径。
///
/// 覆盖用户真实操作时会携带的数据：封面/效果图、多姿势（含剪影）、
/// 四级分类、tags、后期参数。验证保存后：
/// - 记录确实写入 custom_templates 表（getCustomOnly / getCustomAndRemote 能查到）
/// - source 被标记为 'custom'（我的模板页 / 拍摄页依赖此过滤）
/// - 关键字段（封面、姿势、postProcess）round-trip 后不丢失
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

  group('自定义模板保存 → 读回（真实用户数据路径）', () {
    test('带封面+姿势+四级分类保存后，getCustomOnly/getCustomAndRemote 均能读到', () async {
      final dao = TemplatesDao(db);

      // 构造与用户表单一致的数据：名称 + 封面效果图 + 姿势（剪影）+ 四级分类 + 后期参数
      final form = EditorForm(
        meta: EditorFormMeta(
          name: '我的人像模板',
          category: 'portrait',
          style: 'soft',
          subStyle: 'natural_light',
          method: 'backlight',
          tags: ['人像', '柔光'],
          description: '自建模板',
          shortDesc: '自建',
          images: [
            EditorFormMetaImage(data: 'data:image/png;base64,COVER0'),
            EditorFormMetaImage(data: 'data:image/png;base64,EFFECT1'),
          ],
        ),
        composition: EditorFormComposition(
          overlayType: 'rule_of_thirds',
          aspectRatio: '3:4',
          opacity: 0.6,
        ),
        poses: [
          EditorFormPose(
            name: '自然站立',
            silhouette: SilhouetteResource(type: 'builtin', data: 'standing'),
            scale: 1.2,
            description: '侧身站立',
            cameraDirection: 'back',
          ),
        ],
        camera: EditorFormCamera(iso: 200, shutterSpeed: '1/200'),
        sceneGuide: EditorFormSceneGuide(lightDirection: 'front'),
        postProcess: EditorFormPostProcess(
          cropRatio: '3:4',
          smoothStrength: 30,
          sharpen: 40,
          vignette: 10,
          lut: 'warm_film',
        ),
      );

      final now = DateTime.now().millisecondsSinceEpoch;
      final record = TemplateMapper.fromEditorForm(form, id: 'user_$now', createdAt: now);

      // 保存（与 _onSave 一致）
      await dao.upsert(record);

      // 我的模板页数据源：source='custom' 必须能查到
      final customs = await dao.getCustomOnly();
      expect(customs.length, 1, reason: '保存后 getCustomOnly 应能读到 1 条');
      final saved = customs.first;
      expect(saved.id, record.id);
      expect(saved.source, 'custom', reason: '自定义模板必须标记 source=custom，否则我的模板页查不到');
      expect(saved.isBuiltin, isFalse);
      expect(saved.name, '我的人像模板');
      expect(saved.category, 'portrait');

      // 拍摄页数据源：custom+remote 必须能查到
      final pool = await dao.getCustomAndRemote();
      expect(pool.any((r) => r.id == record.id), isTrue,
          reason: '拍摄页 allTemplatesProvider 依赖 getCustomAndRemote，保存后必须能查到');

      // 关键字段 round-trip 不丢失
      expect(saved.coverData, 'data:image/png;base64,COVER0');
      expect(saved.cover, 'data:image/png;base64,COVER0');
      expect(saved.images?.length, 2);
      expect(saved.images![0].data, 'data:image/png;base64,COVER0');
      expect(saved.pose, isA<List<dynamic>>());
      final poses = saved.pose as List<dynamic>;
      expect(poses.length, 1);
      expect((poses.first as Map)['silhouette']['data'], 'standing');
      expect((poses.first as Map)['cameraDirection'], 'back');
      expect(saved.classification['type'], 'portrait');
      expect(saved.classification['majorStyle'], 'soft');
      expect(saved.classification['subStyle'], 'natural_light');
      expect(saved.classification['method'], 'backlight');
      expect(saved.postProcess['lut'], 'warm_film');
      expect(saved.postProcess['smoothStrength'], 30);
    });

    test('保存后可通过 toPhotoTemplate 转换供拍摄页套用', () async {
      final dao = TemplatesDao(db);
      final form = EditorForm(
        meta: EditorFormMeta(name: '转换测试', category: 'portrait'),
        composition: EditorFormComposition(),
        pose: EditorFormPose(silhouette: SilhouetteResource(type: 'builtin', data: 'standing')),
        camera: EditorFormCamera(),
        sceneGuide: EditorFormSceneGuide(),
        postProcess: EditorFormPostProcess(),
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      final record = TemplateMapper.fromEditorForm(form, id: 'user_$now', createdAt: now);
      await dao.upsert(record);

      final saved = (await dao.getCustomOnly()).first;
      // 不抛异常即视为可套用（TemplateMapper.toPhotoTemplate 内部无丢字段风险）
      expect(() => TemplateMapper.toPhotoTemplate(saved), returnsNormally);
    });

    test('编辑模式：同名 id upsert 覆盖更新而非新增', () async {
      final dao = TemplatesDao(db);
      final formA = EditorForm(
        meta: EditorFormMeta(name: '原始名称', category: 'portrait'),
        composition: EditorFormComposition(),
        pose: EditorFormPose(),
        camera: EditorFormCamera(),
        sceneGuide: EditorFormSceneGuide(),
        postProcess: EditorFormPostProcess(),
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      await dao.upsert(TemplateMapper.fromEditorForm(formA, id: 'user_$now', createdAt: now));

      final formB = EditorForm(
        meta: EditorFormMeta(name: '更新后名称', category: 'landscape'),
        composition: EditorFormComposition(),
        pose: EditorFormPose(),
        camera: EditorFormCamera(),
        sceneGuide: EditorFormSceneGuide(),
        postProcess: EditorFormPostProcess(),
      );
      await dao.upsert(TemplateMapper.fromEditorForm(formB, id: 'user_$now', createdAt: now));

      final customs = await dao.getCustomOnly();
      expect(customs.length, 1, reason: '编辑保存应覆盖原记录，不新增');
      expect(customs.first.name, '更新后名称');
      expect(customs.first.category, 'landscape');
    });

    test('保存后图片以绝对路径入 RDB（模拟 _persistFormImagesToFiles 落盘）', () async {
      // 模拟编辑器保存前落盘：data URL → 文件，路径写回表单
      final tmpDir = await Directory.systemTemp.createTemp('tpl_rt_');
      addTearDown(() async {
        if (tmpDir.existsSync()) await tmpDir.delete(recursive: true);
      });
      TemplateImageStore.overrideBaseDir = tmpDir.path;
      addTearDown(() => TemplateImageStore.overrideBaseDir = null);

      // 1x1 透明 PNG 的 data URL（可被真实解码）
      final pngB64 =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
      final dataUrl = 'data:image/png;base64,$pngB64';

      final form = EditorForm(
        meta: EditorFormMeta(
          name: '路径存储',
          category: 'portrait',
          images: [
            EditorFormMetaImage(data: dataUrl),
            EditorFormMetaImage(data: dataUrl),
          ],
        ),
        composition: EditorFormComposition(),
        poses: [
          EditorFormPose(
            name: '剪影姿势',
            silhouette: SilhouetteResource(type: 'image', data: dataUrl),
          ),
        ],
        camera: EditorFormCamera(),
        sceneGuide: EditorFormSceneGuide(),
        postProcess: EditorFormPostProcess(),
      );

      // 与编辑器 _persistFormImagesToFiles 相同的落盘逻辑
      for (var i = 0; i < form.meta.images.length; i++) {
        final e = form.meta.images[i];
        if (e.data.isEmpty) continue;
        e.data = await TemplateImageStore.saveDataUrl(
            'user_rt', i == 0 ? 'cover' : 'img', i, e.data);
      }
      for (var i = 0; i < form.poses.length; i++) {
        final p = form.poses[i];
        if (p.silhouette.type == 'image' && p.silhouette.data.isNotEmpty) {
          p.silhouette.data = await TemplateImageStore.saveDataUrl(
              'user_rt', 'silhouette', i, p.silhouette.data);
        }
      }

      final dao = TemplatesDao(db);
      final now = DateTime.now().millisecondsSinceEpoch;
      final record =
          TemplateMapper.fromEditorForm(form, id: 'user_rt', createdAt: now);
      await dao.upsert(record);

      final saved = (await dao.getCustomOnly()).first;
      // RDB 中存的是绝对路径，不再是 base64 data URL
      expect(TemplateImageStore.isLocalImageRef(saved.coverData ?? ''), isTrue,
          reason: 'coverData 应为本地路径（落盘后不再内嵌 base64）');
      expect(saved.coverData, startsWith(tmpDir.path));
      expect(saved.coverData!.contains('base64'), isFalse);
      expect(saved.images?.length, 2);
      for (final img in saved.images!) {
        expect(TemplateImageStore.isLocalImageRef(img.data ?? ''), isTrue);
        expect(img.data, startsWith(tmpDir.path));
        expect(img.data!.contains('base64'), isFalse);
      }
      final poses = saved.pose as List<dynamic>;
      final sil = (poses.first as Map)['silhouette']['data'] as String;
      expect(TemplateImageStore.isLocalImageRef(sil), isTrue,
          reason: 'image 剪影 data 应为本地路径');
      expect(sil, startsWith(tmpDir.path));
      expect(sil.contains('base64'), isFalse);

      // === 回环第 6 步：resolveLocalImages → exportToPptpl → .pptpl 内嵌 base64 ===
      final resolved = await TemplateExporter.resolveLocalImages(saved);

      // resolveLocalImages 把 coverData/cover/images[].data/剪影全部转回 base64 data URL
      expect(resolved.coverData, startsWith('data:image/png;base64,'));
      expect(
        base64Decode(
            resolved.coverData!.substring(resolved.coverData!.indexOf(',') + 1)),
        await File(saved.coverData!).readAsBytes(),
        reason: 'resolved.coverData 解码字节应与 cover 文件一致',
      );
      expect(resolved.cover, startsWith('data:image/png;base64,'));
      expect(
        base64Decode(resolved.cover.substring(resolved.cover.indexOf(',') + 1)),
        await File(saved.coverData!).readAsBytes(),
        reason: 'resolved.cover 解码字节应与 cover 文件一致',
      );
      expect(resolved.images?.length, 2);
      for (var i = 0; i < resolved.images!.length; i++) {
        final data = resolved.images![i].data!;
        expect(data, startsWith('data:image/png;base64,'));
        expect(
          base64Decode(data.substring(data.indexOf(',') + 1)),
          await File(saved.images![i].data!).readAsBytes(),
          reason: 'resolved.images[$i].data 解码字节应与对应效果图文件一致',
        );
      }
      final resolvedPoses = resolved.pose as List<dynamic>;
      final resolvedSil =
          (resolvedPoses.first as Map)['silhouette']['data'] as String;
      expect(resolvedSil, startsWith('data:image/png;base64,'));
      expect(
        base64Decode(resolvedSil.substring(resolvedSil.indexOf(',') + 1)),
        await File(sil).readAsBytes(),
        reason: 'resolved 剪影解码字节应与 silhouette 文件一致',
      );

      // exportToPptpl：解析 JSON，meta.coverData 与 pose 剪影均为可解码 base64 data URL
      // （.pptpl 六区段格式不含 images 数组；images[].data 已在 resolved record 层验证）
      final exportJson = TemplateExporter.exportToPptpl(resolved);
      final data = jsonDecode(exportJson) as Map<String, dynamic>;
      expect(data['format'], 'pptpl');
      final jsonCoverData = (data['meta'] as Map)['coverData'] as String;
      expect(jsonCoverData, startsWith('data:image/png;base64,'));
      expect(
        base64Decode(
            jsonCoverData.substring(jsonCoverData.indexOf(',') + 1)),
        await File(saved.coverData!).readAsBytes(),
        reason: '.pptpl meta.coverData 解码字节应与 cover 文件一致',
      );
      final jsonSil = (((data['pose'] as List).first as Map)['silhouette']
          as Map)['data'] as String;
      expect(jsonSil, startsWith('data:image/png;base64,'));
      expect(
        base64Decode(jsonSil.substring(jsonSil.indexOf(',') + 1)),
        await File(sil).readAsBytes(),
        reason: '.pptpl pose 剪影解码字节应与 silhouette 文件一致',
      );
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
