import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// 决定性探针：dart:ui 解码 JPEG 时是否应用 EXIF Orientation。
///
/// 若应用：320x240 图 + EXIF 6 → 解码后应为 240x320（宽高互换）。
/// 若不应用：解码后仍为 320x240。
void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('exif_probe_');
  });

  tearDownAll(() {
    tempDir.deleteSync(recursive: true);
  });

  // 画一张非对称内容图（左半红 / 右半蓝，便于肉眼判断翻转），320x240。
  File makeJpeg({int orientation = 1}) {
    final image = img.Image(width: 320, height: 240);
    for (var y = 0; y < 240; y++) {
      for (var x = 0; x < 320; x++) {
        if (x < 160) {
          image.setPixelRgb(x, y, 255, 0, 0); // 左半红
        } else {
          image.setPixelRgb(x, y, 0, 0, 255); // 右半蓝
        }
      }
    }
    if (orientation != 1) {
      image.exif.imageIfd.orientation = orientation;
    }
    final path = '${tempDir.path}/exif_$orientation.jpg';
    File(path).writeAsBytesSync(img.encodeJpg(image));
    return File(path);
  }

  // 决定性断言：EXIF6(90°CW) 若被应用，解码后应为 240x320；若不应用则为 320x240。
  test('instantiateImageCodec EXIF 应用探针', () async {
    final f = makeJpeg(orientation: 6);
    final bytes = await f.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final w = frame.image.width;
    final h = frame.image.height;
    codec.dispose();
    // ignore: avoid_print
    print('PROBE instantiateImageCodec EXIF6: decoded=${w}x$h '
        '(raw=320x240, expected-if-applied=240x320)');
    expect([w, h], equals([240, 320]));
  });

  // 决定性断言：descriptor 路径是否应用 EXIF，与 instantiateImageCodec 是否一致。
  test('ImageDescriptor.encoded instantiateCodec EXIF 应用探针', () async {
    final f = makeJpeg(orientation: 6);
    final bytes = await f.readAsBytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final srcW = descriptor.width;
    final srcH = descriptor.height;
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    final w = frame.image.width;
    final h = frame.image.height;
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
    // ignore: avoid_print
    print('PROBE descriptor: rawDims=${srcW}x$srcH decoded=${w}x$h '
        '(raw=320x240, expected-if-applied=240x320)');
    expect([srcW, srcH], equals([240, 320]));
    expect([w, h], equals([240, 320]));
  });
}
