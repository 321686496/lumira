import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:lumira_app_flutter/features/templates/services/template_image_store.dart';

/// 生成一张 size×size 的随机噪点 PNG data URL（可指定通道数，4 通道保留 alpha）。
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

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tpl_img_');
    TemplateImageStore.overrideBaseDir = tempDir.path;
  });

  tearDown(() async {
    TemplateImageStore.overrideBaseDir = null;
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('saveDataUrl', () {
    test('小 PNG data URL → 绝对路径，文件字节与 base64 解码一致，目录结构正确', () async {
      final url = await _noisePngDataUrl(8);
      final path = await TemplateImageStore.saveDataUrl('tpl1', 'cover', 0, url);

      // 目录为 <base>/lumira/templates/<templateId>/<kind>_<index>.<ext>
      final expected = p.normalize(
          p.join(tempDir.path, 'lumira', 'templates', 'tpl1', 'cover.png'));
      expect(p.normalize(path), expected);

      final bytes = await File(path).readAsBytes();
      expect(base64Decode(url.substring(url.indexOf(',') + 1)), bytes);
    });

    test('index 非 0 时文件名含 kind 与 index（img_<i>.png）', () async {
      final url = await _noisePngDataUrl(8);
      final path =
          await TemplateImageStore.saveDataUrl('tpl1', 'img', 2, url);
      expect(
        p.normalize(path),
        p.normalize(
            p.join(tempDir.path, 'lumira', 'templates', 'tpl1', 'img_2.png')),
      );
    });

    test('透明 PNG 剪影落盘后仍是 PNG，img.decodeImage 保留 4 通道', () async {
      final url = await _noisePngDataUrl(8, channels: 4);
      final path =
          await TemplateImageStore.saveDataUrl('tpl1', 'silhouette', 0, url);
      expect(path.endsWith('.png'), isTrue,
          reason: '透明 PNG 必须保留 alpha，扩展名应为 .png');
      final decoded = img.decodeImage(await File(path).readAsBytes());
      expect(decoded, isNotNull);
      expect(decoded!.numChannels, 4, reason: '剪影 PNG 不得丢失 alpha 通道');
    });

    test('非图片输入原样返回，不写文件', () async {
      const inputs = <String>[
        'standing-profile', // 内置剪影 key
        'data:application/json;base64,e30=', // 非 image data URL
        'http://example.com/a.png', // http URL
        'https://example.com/a.png', // https URL
        '', // 空串
        'none', // none
        'assets/images/silhouettes/x.png', // assets 路径
      ];
      for (final input in inputs) {
        final out = await TemplateImageStore.saveDataUrl('tpl1', 'img', 0, input);
        expect(out, input, reason: '非 data:image 输入应原样返回: $input');
      }
      // 上述输入均未落盘：目录不应存在
      final dir = Directory(
          p.join(tempDir.path, 'lumira', 'templates', 'tpl1'));
      expect(dir.existsSync(), isFalse);
    });
  });

  group('isLocalImageRef', () {
    test('非本地引用一律 false', () {
      const inputs = <String>[
        'data:image/png;base64,AAAA',
        'http://example.com/a.png',
        'https://example.com/a.png',
        'assets/images/silhouettes/x.png',
        '',
        'none',
        'standing-profile', // 纯 key
      ];
      for (final input in inputs) {
        expect(TemplateImageStore.isLocalImageRef(input), isFalse,
            reason: '$input 不应被识别为本地路径');
      }
    });

    test('绝对路径被识别为本地引用', () {
      expect(
        TemplateImageStore.isLocalImageRef(
            '/data/user/0/xxx/lumira/templates/u1/cover.png'),
        isTrue,
      );
      expect(
        TemplateImageStore.isLocalImageRef(
            r'C:\data\user\0\xxx\lumira\templates\u1\cover.png'),
        isTrue,
      );
    });
  });

  group('readBytes', () {
    test('路径存在返回字节，不存在返回 null', () async {
      final url = await _noisePngDataUrl(8);
      final path = await TemplateImageStore.saveDataUrl('tpl1', 'cover', 0, url);
      final bytes = await TemplateImageStore.readBytes(path);
      expect(bytes, isNotNull);
      expect(base64Decode(url.substring(url.indexOf(',') + 1)), bytes);

      final missing =
          await TemplateImageStore.readBytes('$path.missing');
      expect(missing, isNull);
    });
  });

  group('toDataUrl', () {
    test('本地路径 → data:image/png;base64,... 且解码字节与文件一致', () async {
      final url = await _noisePngDataUrl(8);
      final path = await TemplateImageStore.saveDataUrl('tpl1', 'cover', 0, url);
      final out = await TemplateImageStore.toDataUrl(path);

      expect(out.startsWith('data:image/png;base64,'), isTrue);
      final decoded = base64Decode(out.substring(out.indexOf(',') + 1));
      expect(decoded, await File(path).readAsBytes());
    });

    test('非本地引用（data URL / http / 内置 key）原样返回', () async {
      const inputs = <String>[
        'data:image/png;base64,AAAA',
        'http://example.com/a.png',
        'standing-profile',
      ];
      for (final input in inputs) {
        expect(await TemplateImageStore.toDataUrl(input), input,
            reason: '$input 应原样返回');
      }
    });

    test('本地路径文件缺失时返回原引用', () async {
      const missing = '/data/user/0/xxx/lumira/templates/u1/cover.png';
      expect(await TemplateImageStore.toDataUrl(missing), missing);
    });
  });

  group('deleteAll', () {
    test('删除整个模板图片目录', () async {
      final url = await _noisePngDataUrl(8);
      await TemplateImageStore.saveDataUrl('tpl1', 'cover', 0, url);
      await TemplateImageStore.saveDataUrl('tpl1', 'img', 1, url);
      await TemplateImageStore.saveDataUrl('tpl1', 'silhouette', 0, url);

      final dir =
          Directory(p.join(tempDir.path, 'lumira', 'templates', 'tpl1'));
      expect(dir.existsSync(), isTrue);

      await TemplateImageStore.deleteAll('tpl1');
      expect(dir.existsSync(), isFalse);
    });

    test('目录不存在时静默通过', () async {
      await TemplateImageStore.deleteAll('no_such_template');
      // 不抛异常即通过
    });
  });
}
