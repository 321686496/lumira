import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;

import '../../../core/db/dao/templates_dao.dart';
import '../../../features/capture/domain/photo_template.dart';

/// 分享海报照片比例归类。
///
/// App 内可调整三种照片比例（全屏 9:16 / 3:4 / 1:1），横屏拍摄时会旋转
/// （19:6 / 4:3 / 1:1），共 5 类。按照片宽高比 `aspect = width / height` 归类：
///
/// | 区间 | 枚举 | 说明 |
/// |---|---|---|
/// | `aspect >= 1.6` | [ratio169] | 16:9 / 19:6 宽幅横图 |
/// | `1.15 <= aspect < 1.6` | [ratio43] | 4:3 横图 |
/// | `0.87 <= aspect < 1.15` | [square] | 1:1 方图 |
/// | `0.65 <= aspect < 0.87` | [ratio34] | 3:4 竖图 |
/// | `aspect < 0.65` | [fullScreen] | 9:16 全屏竖图 |
enum PosterRatio {
  fullScreen,
  ratio34,
  square,
  ratio43,
  ratio169;

  /// 由宽高比归类（纯函数，供单测覆盖边界）。
  static PosterRatio fromAspect(double aspect) {
    if (aspect >= 1.6) return PosterRatio.ratio169;
    if (aspect >= 1.15) return PosterRatio.ratio43;
    if (aspect >= 0.87) return PosterRatio.square;
    if (aspect >= 0.65) return PosterRatio.ratio34;
    return PosterRatio.fullScreen;
  }

  /// 由像素宽高归类；非法尺寸回退 [fullScreen]。
  static PosterRatio fromSize(double width, double height) {
    if (width <= 0 || height <= 0) return PosterRatio.fullScreen;
    return fromAspect(width / height);
  }

  /// 从本地图片文件解析比例；解码失败回退 [fullScreen]。
  static Future<PosterRatio> fromFile(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      return await fromBytes(bytes);
    } catch (_) {
      return PosterRatio.fullScreen;
    }
  }

  /// 从模板封面解析比例（coverData base64 → assets 资源 → http url）。
  /// 解析失败回退 [fullScreen]。
  static Future<PosterRatio> fromTemplateCover(TemplateRecord record) async {
    final img = _coverOf(record);
    final data = img.data;
    if (data != null && data.isNotEmpty) {
      try {
        final bytes = base64Decode(
          data.contains(',') ? data.substring(data.indexOf(',') + 1) : data,
        );
        return await fromBytes(bytes);
      } catch (_) {}
    }
    final url = img.url;
    if (url.startsWith('assets/')) {
      try {
        final loaded = await rootBundle.load(url);
        return await fromBytes(loaded.buffer.asUint8List());
      } catch (_) {}
    }
    if (url.startsWith('http')) {
      try {
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 3);
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close().timeout(const Duration(seconds: 4));
        final builder = BytesBuilder();
        await for (final chunk in response) {
          builder.add(chunk);
        }
        client.close();
        return await fromBytes(builder.takeBytes());
      } catch (_) {}
    }
    return PosterRatio.fullScreen;
  }

  /// 从图片字节解析比例；解码失败回退 [fullScreen]。
  static Future<PosterRatio> fromBytes(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final width = frame.image.width.toDouble();
      final height = frame.image.height.toDouble();
      frame.image.dispose();
      codec.dispose();
      return fromSize(width, height);
    } catch (_) {
      return PosterRatio.fullScreen;
    }
  }

  /// 封面图（images[0] 优先，缺省用 cover/coverData 构造）。
  static TemplateImage _coverOf(TemplateRecord record) {
    final images = record.images;
    if (images != null && images.isNotEmpty) return images.first;
    return TemplateImage(url: record.cover, data: record.coverData);
  }
}
