import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/templates/services/template_exporter.dart';
import 'package:lumira_app_flutter/features/templates/services/template_image_store.dart';

/// 生成一张 size×size 的随机噪点 PNG data URL（用于落盘真实文件）。
Future<String> _noisePngDataUrl(int size, {int channels = 3}) async {
  final image = img.Image(width: size, height: size, numChannels: channels);
  final rnd = math.Random(42);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      if (channels == 4) {
        image.setPixelRgba(x, y, rnd.nextInt(256), rnd.nextInt(256),
            rnd.nextInt(256), rnd.nextInt(256));
      } else {
        image.setPixelRgb(
            x, y, rnd.nextInt(256), rnd.nextInt(256), rnd.nextInt(256));
      }
    }
  }
  final bytes = img.encodePng(image);
  return 'data:image/png;base64,${base64Encode(bytes)}';
}

TemplateRecord _makeRecord() {
  return TemplateRecord(
    id: 'r1',
    name: '测试模板',
    author: 'tester',
    version: '1.0.0',
    category: 'portrait',
    classification: {},
    tags: ['人像'],
    tagIds: [],
    price: 0,
    cover: '',
    description: '',
    referenceSource: '',
    composition: {'overlayType': 'rule_of_thirds', 'subjectFrame': {'x': 0.1, 'y': 0.2, 'w': 0.3, 'h': 0.4}, 'opacity': 0.5, 'aspectRatio': '3:4', 'description': '三分法'},
    pose: {'silhouette': {'type': 'builtin', 'data': 'standing-profile'}, 'position': {'x': 0.5, 'y': 0.5}, 'scale': 1.0, 'rotation': 0, 'description': ''},
    camera: {'exposureCompensation': 0.3, 'iso': 200, 'shutterSpeed': '1/200', 'whiteBalance': 'daylight', 'whiteBalanceK': 5500, 'flashMode': 'off', 'focusMode': 'auto', 'lensSuggestion': 'main'},
    sceneGuide: {'lightDirection': 'front', 'shootingDistance': '2m', 'background': 'wall', 'props': <String>[], 'bestTime': 'morning', 'tips': <String>['keep steady']},
    postProcess: {'cropRatio': '3:4', 'color': {'brightness': 0, 'contrast': 0, 'saturation': 0, 'temperature': 0, 'tint': 0}, 'smoothStrength': 0, 'sharpen': 0, 'vignette': 0, 'grain': 0, 'lut': 'none'},
    createdAt: 1700000000000,
    updatedAt: 1700000000000,
    isBuiltin: false,
    isRecommended: false,
  );
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tpl_exp_');
    TemplateImageStore.overrideBaseDir = tempDir.path;
  });

  tearDown(() async {
    TemplateImageStore.overrideBaseDir = null;
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('TemplateExporter.exportToPptpl', () {
    test('生成完整 .pptpl JSON（含所有 5 字段）', () {
      final json = TemplateExporter.exportToPptpl(_makeRecord());
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect(data['format'], 'pptpl');
      expect(data['version'], '1.0');
      expect(data['meta'], isA<Map>());
      expect(data['composition'], isA<Map>());
      expect(data['pose'], isA<Map>());
      expect(data['camera'], isA<Map>());
      expect(data['sceneGuide'], isA<Map>());
      expect(data['postProcess'], isA<Map>());

      expect(data['meta']['id'], 'r1');
      expect(data['composition']['subjectFrame'], isNotNull);
      expect(data['pose']['silhouette'], isNotNull);
    });
  });

  group('TemplateExporter.exportToLumira', () {
    test('生成简化 .lumira JSON（仅 meta + camera + composition.overlayType）', () {
      final json = TemplateExporter.exportToLumira(_makeRecord());
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect(data['format'], 'lumira');
      expect(data['version'], '1.0');
      expect(data['meta'], isA<Map>());
      expect(data['camera'], isA<Map>());
      expect(data['composition'], isA<Map>());

      expect(data.containsKey('pose'), isFalse);
      expect(data.containsKey('sceneGuide'), isFalse);
      expect(data.containsKey('postProcess'), isFalse);

      expect(data['composition']['overlayType'], 'rule_of_thirds');
      expect(data['composition'].containsKey('subjectFrame'), isFalse);
    });
  });

  group('TemplateExporter.embedCoverData', () {
    test('data: URL cover is copied directly to coverData', () async {
      final record = _makeRecord().copyWith(
        cover: 'data:image/jpeg;base64,abc123',
      );
      final result = await TemplateExporter.embedCoverData(record);
      expect(result.coverData, 'data:image/jpeg;base64,abc123');
    });

    test('http URL cover leaves coverData null (offline app)', () async {
      final record = _makeRecord().copyWith(
        cover: 'https://picsum.photos/seed/test/400/600',
      );
      final result = await TemplateExporter.embedCoverData(record);
      expect(result.coverData, isNull);
    });

    test('empty cover leaves coverData null', () async {
      final record = _makeRecord(); // cover = ''
      final result = await TemplateExporter.embedCoverData(record);
      expect(result.coverData, isNull);
    });

    test('asset path cover loads bytes and encodes to base64 data URL', () async {
      final record = _makeRecord().copyWith(
        cover: 'assets/images/templates/cafe_portrait.jpg',
      );
      final fakeBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]); // JPEG magic bytes
      final result = await TemplateExporter.embedCoverData(
        record,
        assetLoader: (_) async => fakeBytes,
      );
      expect(result.coverData, isNotNull);
      expect(result.coverData!, startsWith('data:image/jpeg;base64,'));
    });

    test('coverData exceeding 500KB is skipped', () async {
      final record = _makeRecord().copyWith(
        cover: 'assets/images/templates/huge.jpg',
      );
      final hugeBytes = Uint8List(600 * 1024); // 600KB > 500KB limit
      final result = await TemplateExporter.embedCoverData(
        record,
        assetLoader: (_) async => hugeBytes,
      );
      expect(result.coverData, isNull);
    });

    test('local path cover reads file bytes to base64 data URL', () async {
      final pngUrl = await _noisePngDataUrl(8);
      final coverPath =
          await TemplateImageStore.saveDataUrl('emb1', 'cover', 0, pngUrl);
      final record = _makeRecord().copyWith(cover: coverPath);
      final result = await TemplateExporter.embedCoverData(record);
      expect(result.coverData, startsWith('data:image/png;base64,'));
      final decoded = base64Decode(
          result.coverData!.substring(result.coverData!.indexOf(',') + 1));
      expect(decoded, await File(coverPath).readAsBytes());
    });

    test('local path cover exceeding 500KB is skipped', () async {
      final bigFile = File('${tempDir.path}/exp_big_cover.png');
      await bigFile.writeAsBytes(Uint8List(600 * 1024));
      final record = _makeRecord().copyWith(cover: bigFile.path);
      final result = await TemplateExporter.embedCoverData(record);
      expect(result.coverData, isNull);
    });

    test('local path cover with missing file is skipped', () async {
      final missing = File('${tempDir.path}/exp_no_such_cover.png');
      if (missing.existsSync()) await missing.delete();
      final record = _makeRecord().copyWith(cover: missing.path);
      final result = await TemplateExporter.embedCoverData(record);
      expect(result.coverData, isNull);
    });
  });

  group('TemplateExporter.exportToPptpl with coverData', () {
    test('meta includes coverData when record has it', () {
      final record = _makeRecord().copyWith(
        coverData: 'data:image/jpeg;base64,abc123',
      );
      final json = TemplateExporter.exportToPptpl(record);
      final data = jsonDecode(json) as Map<String, dynamic>;
      expect(data['meta']['coverData'], 'data:image/jpeg;base64,abc123');
    });

    test('meta omits coverData when null', () {
      final record = _makeRecord(); // coverData = null
      final json = TemplateExporter.exportToPptpl(record);
      final data = jsonDecode(json) as Map<String, dynamic>;
      expect(data['meta'].containsKey('coverData'), isFalse);
    });
  });

  group('resolveCoverUrl', () {
    test('returns coverData when present', () {
      final record = _makeRecord().copyWith(
        cover: 'assets/images/templates/test.jpg',
        coverData: 'data:image/jpeg;base64,abc',
      );
      expect(TemplateExporter.resolveCoverUrl(record), 'data:image/jpeg;base64,abc');
    });

    test('returns cover when coverData is null', () {
      final record = _makeRecord().copyWith(
        cover: 'assets/images/templates/test.jpg',
      );
      expect(TemplateExporter.resolveCoverUrl(record), 'assets/images/templates/test.jpg');
    });
  });

  group('TemplateExporter.buildFileName', () {
    test('includes template ID for uniqueness', () {
      final record = _makeRecord(); // id='r1', name='测试模板'
      final filename = TemplateExporter.buildFileName(record, usePptpl: true);
      expect(filename, contains('r1'));
      expect(filename, contains('测试模板'));
      expect(filename, endsWith('.pptpl'));
    });

    test('lumira format uses .lumira extension', () {
      final record = _makeRecord();
      final filename = TemplateExporter.buildFileName(record, usePptpl: false);
      expect(filename, endsWith('.lumira'));
    });

    test('sanitizes illegal characters in name', () {
      final record = _makeRecord().copyWith(
        name: 'test/template:with*illegal',
        id: 'r2',
      );
      final filename = TemplateExporter.buildFileName(record, usePptpl: true);
      expect(filename, isNot(contains('/')));
      expect(filename, isNot(contains(':')));
      expect(filename, isNot(contains('*')));
      expect(filename, contains('r2'));
    });

    test('two templates with same name have different filenames', () {
      final r1 = _makeRecord().copyWith(name: 'same', id: 'id1');
      final r2 = _makeRecord().copyWith(name: 'same', id: 'id2');
      final f1 = TemplateExporter.buildFileName(r1, usePptpl: true);
      final f2 = TemplateExporter.buildFileName(r2, usePptpl: true);
      expect(f1, isNot(equals(f2)));
    });
  });

  group('TemplateExporter.resolveLocalImages', () {
    test('本地路径 coverData/cover/images/silhouette → data URL 且解码字节与文件一致', () async {
      final pngUrl = await _noisePngDataUrl(8);
      final coverPath =
          await TemplateImageStore.saveDataUrl('exp1', 'cover', 0, pngUrl);
      final imgPath =
          await TemplateImageStore.saveDataUrl('exp1', 'img', 1, pngUrl);
      final silPath = await TemplateImageStore.saveDataUrl(
          'exp1', 'silhouette', 0, pngUrl);

      final record = _makeRecord().copyWith(
        cover: coverPath,
        coverData: coverPath,
        images: [TemplateImage(url: '', data: imgPath)],
        pose: <dynamic>[
          {
            'silhouette': {'type': 'image', 'data': silPath},
            'position': {'x': 0.5, 'y': 0.5},
          },
        ],
      );

      final resolved = await TemplateExporter.resolveLocalImages(record);

      expect(resolved.coverData, startsWith('data:image/png;base64,'));
      expect(
        base64Decode(resolved.coverData!
            .substring(resolved.coverData!.indexOf(',') + 1)),
        await File(coverPath).readAsBytes(),
      );
      expect(resolved.cover, startsWith('data:image/png;base64,'));
      expect(resolved.images!.single.data, startsWith('data:image/png;base64,'));
      expect(
        base64Decode(resolved.images!.single.data!
            .substring(resolved.images!.single.data!.indexOf(',') + 1)),
        await File(imgPath).readAsBytes(),
      );
      final poses = resolved.pose as List<dynamic>;
      final sil = (poses.first as Map)['silhouette']['data'] as String;
      expect(sil, startsWith('data:image/png;base64,'));
      expect(
        base64Decode(sil.substring(sil.indexOf(',') + 1)),
        await File(silPath).readAsBytes(),
      );

      // 入参不被修改
      expect(record.coverData, coverPath);
      expect(record.cover, coverPath);
      expect(record.images!.single.data, imgPath);
    });

    test('data URL / http / 内置 key / assets 原样保留', () async {
      final record = _makeRecord().copyWith(
        cover: 'assets/images/templates/cafe_portrait.jpg',
        coverData: 'data:image/jpeg;base64,abc123',
        images: [
          TemplateImage(url: '', data: 'https://example.com/a.png'),
          TemplateImage(url: '', data: 'standing-profile'),
        ],
        pose: {
          'silhouette': {'type': 'builtin', 'data': 'standing-profile'},
        },
      );

      final resolved = await TemplateExporter.resolveLocalImages(record);

      expect(resolved.coverData, 'data:image/jpeg;base64,abc123');
      expect(resolved.cover, 'assets/images/templates/cafe_portrait.jpg');
      expect(resolved.images![0].data, 'https://example.com/a.png');
      expect(resolved.images![1].data, 'standing-profile');
      final pose = resolved.pose as Map;
      expect((pose['silhouette'] as Map)['data'], 'standing-profile');
    });

    test('本地路径文件缺失时保持原值', () async {
      const missing = '/data/user/0/xxx/lumira/templates/u1/cover.png';
      final record = _makeRecord().copyWith(cover: missing, coverData: missing);
      final resolved = await TemplateExporter.resolveLocalImages(record);
      expect(resolved.cover, missing);
      expect(resolved.coverData, missing);
    });

    test('pose 为单 Map 时剪影同样被解析', () async {
      final pngUrl = await _noisePngDataUrl(8);
      final silPath = await TemplateImageStore.saveDataUrl(
          'exp2', 'silhouette', 0, pngUrl);
      final record = _makeRecord().copyWith(
        pose: {
          'silhouette': {'type': 'image', 'data': silPath},
        },
      );
      final resolved = await TemplateExporter.resolveLocalImages(record);
      final pose = resolved.pose as Map;
      final data = (pose['silhouette'] as Map)['data'] as String;
      expect(data, startsWith('data:image/png;base64,'));
    });
  });
}
