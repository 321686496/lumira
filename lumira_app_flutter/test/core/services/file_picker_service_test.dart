import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/services/file_picker_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fp_svc_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('FilePickerService.ensureFullBytes', () {
    test('path 可用时应读取完整字节覆盖插件截断数据', () async {
      final full = Uint8List.fromList(
        List<int>.generate(5000, (i) => i % 256),
      );
      final file = File('${tempDir.path}/photo.jpg');
      await file.writeAsBytes(full, flush: true);

      final truncated = full.sublist(0, 4096);
      final picked = PickedFile(
        name: 'photo.jpg',
        bytes: truncated,
        path: file.path,
        extension: 'jpg',
        size: full.length,
      );

      final result = await FilePickerService.ensureFullBytes(picked);

      expect(result.bytes, isNotNull);
      expect(result.bytes!.length, full.length);
      expect(result.bytes, equals(full));
      expect(result.size, full.length);
    });

    test('path 为 null 时应原样返回插件 bytes', () async {
      final picked = PickedFile(
        name: 'photo.jpg',
        bytes: Uint8List.fromList([1, 2, 3]),
        path: null,
        extension: 'jpg',
        size: 3,
      );

      final result = await FilePickerService.ensureFullBytes(picked);

      expect(result, same(picked));
      expect(result.bytes, equals([1, 2, 3]));
    });

    test('path 指向的文件不存在时应保留插件 bytes', () async {
      final picked = PickedFile(
        name: 'photo.jpg',
        bytes: Uint8List.fromList([1, 2, 3]),
        path: '${tempDir.path}/not_exists.jpg',
        extension: 'jpg',
        size: 3,
      );

      final result = await FilePickerService.ensureFullBytes(picked);

      expect(result, same(picked));
      expect(result.bytes, equals([1, 2, 3]));
    });
  });
}
