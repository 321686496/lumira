import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumira_app_flutter/core/db/dao/templates_dao.dart';
import 'package:lumira_app_flutter/core/network/api_client.dart';
import 'package:lumira_app_flutter/core/network/api_error.dart';
import 'package:lumira_app_flutter/features/templates/models/share_token.dart';
import 'package:lumira_app_flutter/features/templates/services/template_share_service.dart';

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
    composition: {'overlayType': 'rule_of_thirds'},
    pose: {'silhouette': {'type': 'builtin', 'data': 'standing-profile'}},
    camera: {'exposureCompensation': 0.3, 'iso': 200},
    sceneGuide: {'lightDirection': 'front'},
    postProcess: {'cropRatio': '3:4'},
    createdAt: 1700000000000,
    updatedAt: 1700000000000,
    isBuiltin: false,
    isRecommended: false,
  );
}

/// 实现 ApiClient 接口的假实现，记录调用并返回可控响应。
class _FakeApi implements ApiClient {
  Map<String, dynamic> createResponse = const {'token': 'abc123', 'expiresAt': 1700000000};
  Map<String, dynamic> fetchResponse = const {'payload': '{"a":1}', 'expiresAt': 1700000000};
  Object? thrownError;

  String? lastPostPath;
  Object? lastPostBody;
  String? lastGetPath;
  String? lastDeletePath;

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(Object? json) fromJson,
  }) async {
    lastGetPath = path;
    if (thrownError != null) throw thrownError!;
    return fromJson(fetchResponse);
  }

  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    required T Function(Object? json) fromJson,
  }) async {
    lastPostPath = path;
    lastPostBody = body;
    if (thrownError != null) throw thrownError!;
    return fromJson(createResponse);
  }

  @override
  Future<T> delete<T>(
    String path, {
    required T Function(Object? json) fromJson,
  }) async {
    lastDeletePath = path;
    if (thrownError != null) throw thrownError!;
    return fromJson(null);
  }

  @override
  Future<T?> patch<T>(
    String path, {
    Object? body,
    required T Function(Object? json) fromJson,
  }) async {
    throw UnimplementedError('PATCH $path');
  }

  @override
  Future<T> multipartPost<T>(
    String path, {
    required Map<String, String> fields,
    required List<MultipartFile> files,
    String fileField = 'screenshots',
    required T Function(Object? json) fromJson,
  }) async {
    throw UnimplementedError('MULTIPART $path');
  }
}

void main() {
  group('parseTokenFromScannedText', () {
    test('识别 lumira://imp/ 前缀并返回 token', () {
      expect(
        TemplateShareService.parseTokenFromScannedText('lumira://imp/abc123'),
        'abc123',
      );
    });

    test('识别 https://lumira.app/imp/ 前缀并返回 token', () {
      expect(
        TemplateShareService.parseTokenFromScannedText('https://lumira.app/imp/xyz'),
        'xyz',
      );
    });

    test('imp 前缀缺 token 视为无效（空串）', () {
      expect(TemplateShareService.parseTokenFromScannedText('lumira://imp/'), '');
      expect(TemplateShareService.parseTokenFromScannedText('https://lumira.app/imp/'), '');
    });

    test('离线分享链接返回 null', () {
      expect(
        TemplateShareService.parseTokenFromScannedText('lumira://tpl/eyJmb3JtYXQiOiJwdHB0bCJ9'),
        isNull,
      );
      expect(
        TemplateShareService.parseTokenFromScannedText('https://lumira.app/tpl?name=foo&category=portrait'),
        isNull,
      );
    });

    test('无关文本返回空串（无效）', () {
      expect(TemplateShareService.parseTokenFromScannedText('garbage-text'), '');
      expect(TemplateShareService.parseTokenFromScannedText('LUMIRA-portrait-name'), '');
      expect(TemplateShareService.parseTokenFromScannedText(''), '');
    });
  });

  group('buildQrText', () {
    test('生成 lumira://imp/{token}', () {
      expect(TemplateShareService.buildQrText('abc123'), 'lumira://imp/abc123');
    });
  });

  group('compressImageToLimit', () {
    test('未超限时原样返回（不重新编码）', () async {
      // 4x4 纯色图：PNG 编码后很小，远低于 1MB 阈值。
      final image = img.Image(width: 4, height: 4);
      img.fill(image, color: img.ColorRgb8(200, 100, 50));
      final bytes = img.encodePng(image);
      expect(bytes, isNotNull);

      final out = await TemplateShareService.compressImageToLimit(bytes, 1024 * 1024);
      expect(out, same(bytes));
    });

    test('超限时压缩后 ≤ maxBytes', () async {
      // 600x600 随机噪点图，PNG 编码后远超 8KB 阈值；压缩算法应按需缩放/降质至 8KB 内。
      final image = img.Image(width: 600, height: 600);
      final rnd = math.Random(42);
      for (var y = 0; y < 600; y++) {
        for (var x = 0; x < 600; x++) {
          image.setPixelRgb(x, y, rnd.nextInt(256), rnd.nextInt(256), rnd.nextInt(256));
        }
      }
      final bytes = Uint8List.fromList(img.encodePng(image));
      const maxBytes = 8000;
      expect(bytes.length, greaterThan(maxBytes));

      final out = await TemplateShareService.compressImageToLimit(bytes, maxBytes);
      expect(out.length, lessThanOrEqualTo(maxBytes));
    });
  });

  group('shareTemplate', () {
    test('POST 到 /templates/share，携带 payload 字符串与 expiresInSeconds', () async {
      final api = _FakeApi()
        ..createResponse = {'token': 'tok_1', 'expiresAt': 1800000000};
      final service = TemplateShareService(api);

      final result = await service.shareTemplate(_makeRecord(), 3600);

      expect(api.lastPostPath, '/templates/share');
      final body = api.lastPostBody as Map<String, dynamic>;
      expect(body['expiresInSeconds'], 3600);
      expect(body['payload'], isA<String>());

      // payload 应为可解析的 .pptpl JSON 字符串，且含完整 6 区段。
      final payload = jsonDecode(body['payload'] as String) as Map<String, dynamic>;
      expect(payload['format'], 'pptpl');
      expect(payload['meta']['name'], '测试模板');
      for (final key in ['composition', 'pose', 'camera', 'sceneGuide', 'postProcess']) {
        expect(payload[key], isA<Map>());
      }

      expect(result, isA<ShareToken>());
      expect(result.token, 'tok_1');
      expect(result.expiresAt, 1800000000);
    });

    test('shareTemplate 抛出的 ApiException 不被吞掉', () async {
      final api = _FakeApi()
        ..thrownError = const ApiException(ApiErrorKind.network, 'timeout');
      final service = TemplateShareService(api);

      expect(
        () => service.shareTemplate(_makeRecord(), 3600),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('fetchShare', () {
    test('GET /templates/share/{token} 返回 {payload, expiresAt}', () async {
      final api = _FakeApi()
        ..fetchResponse = {'payload': '{"format":"pptpl"}', 'expiresAt': 1700000000};
      final service = TemplateShareService(api);

      final data = await service.fetchShare('abc123');

      expect(api.lastGetPath, '/templates/share/abc123');
      expect(data['payload'], '{"format":"pptpl"}');
      expect(data['expiresAt'], 1700000000);
    });
  });

  group('revokeShare', () {
    test('DELETE /templates/share/{token}', () async {
      final api = _FakeApi();
      final service = TemplateShareService(api);

      await service.revokeShare('abc123');

      expect(api.lastDeletePath, '/templates/share/abc123');
    });
  });

  group('downscaleBytes', () {
    test('未超过阈值时原样返回（不重新编码）', () async {
      final image = img.Image(width: 4, height: 4);
      img.fill(image, color: img.ColorRgb8(200, 100, 50));
      final bytes = img.encodePng(image);
      final out = await TemplateShareService.downscaleBytes(bytes);
      expect(out, same(bytes));
    });

    test('超限大图降采样到 maxDimension 内且变小', () async {
      // 600x600 噪点图，压到 200x200 以内。
      final image = img.Image(width: 600, height: 600);
      final rnd = math.Random(7);
      for (var y = 0; y < 600; y++) {
        for (var x = 0; x < 600; x++) {
          image.setPixelRgb(x, y, rnd.nextInt(256), rnd.nextInt(256), rnd.nextInt(256));
        }
      }
      final bytes = Uint8List.fromList(img.encodePng(image));
      const maxBytes = 8000;
      expect(bytes.length, greaterThan(maxBytes));

      final out = await TemplateShareService.downscaleBytes(
        bytes,
        maxDimension: 200,
        maxBytes: maxBytes,
      );
      final decoded = img.decodeImage(out);
      expect(decoded, isNotNull);
      expect(decoded!.width, lessThanOrEqualTo(200));
      expect(decoded.height, lessThanOrEqualTo(200));
      expect(out.length, lessThan(bytes.length));
    });

    test('带透明通道的剪影 PNG 重编码后保留 alpha', () async {
      // 随机 RGBA 噪点：PNG 几乎无法压缩，保证超过 maxBytes 阈值。
      final image = img.Image(width: 600, height: 600, numChannels: 4);
      final rnd = math.Random(9);
      for (var y = 0; y < 600; y++) {
        for (var x = 0; x < 600; x++) {
          image.setPixelRgba(
            x, y,
            rnd.nextInt(256), rnd.nextInt(256), rnd.nextInt(256), rnd.nextInt(256),
          );
        }
      }
      final bytes = Uint8List.fromList(img.encodePng(image));
      const maxBytes = 8000;
      expect(bytes.length, greaterThan(maxBytes));

      final out = await TemplateShareService.downscaleBytes(
        bytes,
        maxDimension: 300,
        maxBytes: maxBytes,
      );
      final decoded = img.decodeImage(out);
      expect(decoded, isNotNull);
      expect(decoded!.numChannels, 4, reason: '透明剪影不得退化为 JPEG 丢失 alpha');
      expect(decoded.width, lessThanOrEqualTo(300));
    });

    test('非法字节原样返回（fail-open）', () async {
      final junk = Uint8List.fromList(List<int>.filled(400 * 1024, 0xAB));
      final out = await TemplateShareService.downscaleBytes(junk);
      expect(out, same(junk));
    });
  });

  group('compressDataUrlsToBudget', () {
    Future<String> noiseDataUrl(int size, {int channels = 3}) async {
      final image = img.Image(width: size, height: size, numChannels: channels);
      final rnd = math.Random(42);
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          if (channels == 4) {
            image.setPixelRgba(
                x, y, rnd.nextInt(256), rnd.nextInt(256), rnd.nextInt(256), rnd.nextInt(256));
          } else {
            image.setPixelRgb(
                x, y, rnd.nextInt(256), rnd.nextInt(256), rnd.nextInt(256));
          }
        }
      }
      final bytes = img.encodePng(image);
      return 'data:image/png;base64,${base64Encode(bytes)}';
    }

    test('预算充足时原样返回（不重新编码）', () async {
      final urls = <String>['standing-profile', 'data:image/png;base64,AAAA'];
      final out = await TemplateShareService.compressDataUrlsToBudget(urls);
      expect(out, urls);
      expect(out[0], same(urls[0]));
      expect(out[1], same(urls[1]));
    });

    test('超预算时多张图按比例压小，总长明显下降', () async {
      // 6 张 800x800 噪点图，总长远超预算；压缩后每张仍可解码且总体显著变小。
      final urls = <String>[];
      for (var i = 0; i < 6; i++) {
        urls.add(await noiseDataUrl(800));
      }
      const budget = 64 * 1024;
      final totalBefore = urls.fold<int>(0, (s, u) => s + u.length);
      expect(totalBefore, greaterThan(budget * 6));

      final out = await TemplateShareService.compressDataUrlsToBudget(
        urls,
        totalBudgetChars: budget,
        reserveChars: 4 * 1024,
      );
      expect(out.length, urls.length);
      final totalAfter = out.fold<int>(0, (s, u) => s + u.length);
      expect(totalAfter, lessThan(totalBefore));
      // 每张仍应是可解码的图片
      for (final url in out) {
        final m = RegExp(r'^data:image/png;base64,(.+)$').firstMatch(url);
        expect(m, isNotNull);
        final decoded = img.decodeImage(base64Decode(m!.group(1)!));
        expect(decoded, isNotNull);
      }
    });

    test('非图片字符串与已超预算的图片混排时，非图片原样保留', () async {
      final big = await noiseDataUrl(600);
      final urls = <String>['standing-profile', big];
      const budget = 64 * 1024;
      expect(urls.fold<int>(0, (s, u) => s + u.length), greaterThan(budget));

      final out = await TemplateShareService.compressDataUrlsToBudget(
        urls,
        totalBudgetChars: budget,
        reserveChars: 4 * 1024,
      );
      expect(out[0], 'standing-profile'); // 内置剪影 key 不被压缩
      expect(out[1], isNot(big));
      expect(out[1].startsWith('data:image/png;base64,'), isTrue);
    });

    test('透明剪影 PNG 压缩后保留 alpha', () async {
      final big = await noiseDataUrl(500, channels: 4);
      final urls = <String>[big];
      const budget = 64 * 1024;
      expect(big.length, greaterThan(budget));

      final out = await TemplateShareService.compressDataUrlsToBudget(
        urls,
        totalBudgetChars: budget,
        reserveChars: 4 * 1024,
      );
      final m = RegExp(r'^data:image/png;base64,(.+)$').firstMatch(out[0]);
      final decoded = img.decodeImage(base64Decode(m!.group(1)!));
      expect(decoded, isNotNull);
      expect(decoded!.numChannels, 4, reason: '透明剪影不得退化为 JPEG 丢失 alpha');
    });
  });
}