import 'dart:io';

import 'package:image/image.dart' as img;
// 依赖 image 4.2.0 内部 EXIF 目录/取值 API 读取扩展字段，需要访问 lib/src 实现。
// ignore_for_file: implementation_imports
import 'package:image/src/exif/ifd_directory.dart';
import 'package:image/src/exif/ifd_value.dart';
import 'exif_card_generator.dart';

/// 从 JPEG 文件读取 EXIF 元数据
///
/// 注意：依赖 `image` 包 v4.2.0 的 EXIF API。
/// 该版本 `ExifData` 不提供 `imageMake`/`imageModel`/`focalLength` 等便捷 getter，
/// 需通过 `imageIfd`/`exifIfd` 目录按 tag 名取值。
class PhotoExifReader {
  PhotoExifReader._();

  static Future<ExifInfo> read(String photoPath, {
    String? sceneName,
    String? template,
    int? timestamp,
  }) async {
    final bytes = await File(photoPath).readAsBytes();
    final image = img.decodeJpg(bytes);
    if (image == null) {
      return ExifInfo(
        sceneName: sceneName,
        template: template,
        timestamp: timestamp != null
            ? DateTime.fromMillisecondsSinceEpoch(timestamp).toString()
            : null,
      );
    }
    final exif = image.exif;
    final imageIfd = exif.imageIfd;
    final exifIfd = exif.exifIfd;

    // 相机厂商 + 型号（imageIfd.make / imageIfd.model）
    final make = imageIfd.make;
    final model = imageIfd.model;
    final String? cameraModel = make != null
        ? '$make ${model ?? ""}'.trim()
        : model;

    // 分辨率：采用解码后的实际像素宽高（WxH）
    final resolution = '${image.width}x${image.height}';

    // 文件大小（读源文件字节数，转为可读单位）
    String? fileSize;
    try {
      final size = File(photoPath).lengthSync();
      fileSize = _formatFileSize(size);
    } catch (_) {}

    // 拍摄时间（DateTime tag 0x132，ASCII "YYYY:MM:DD HH:MM:SS"）
    final dateTimeValue = imageIfd['DateTime'];
    final String? dtString = dateTimeValue?.toString();

    // 焦距（FocalLength tag 0x920A，Rational）— 保留 1 位小数（相机通常报告到 0.1mm）
    final focalLengthValue = exifIfd['FocalLength'];
    final String? focalLength = focalLengthValue != null
        ? '${focalLengthValue.toRational().toDouble().toStringAsFixed(1)}mm'
        : null;

    // 光圈（FNumber tag 0x829D，Rational）— 保留 1 位小数（标准 f/1.8、f/2.8 等）
    final fNumberValue = exifIfd['FNumber'];
    final String? fNumber = fNumberValue != null
        ? 'f/${fNumberValue.toRational().toDouble().toStringAsFixed(1)}'
        : null;

    // ISO（ISOSpeed tag 0x8827，Long）
    final isoValue = exifIfd['ISOSpeed'];
    final String? iso = isoValue != null
        ? 'ISO ${isoValue.toInt()}'
        : null;

    // 快门速度（ExposureTime tag 0x829A，Rational，单位秒）
    final exposureTimeValue = exifIfd['ExposureTime'];
    final String? shutterSpeed = exposureTimeValue != null
        ? _formatShutterSpeed(exposureTimeValue.toRational().toDouble())
        : null;

    // 曝光补偿（ExposureBiasValue tag 0x9204，Rational，单位 EV，通常为 ±小数）
    final biasValue = exifIfd['ExposureBiasValue'];
    final String? exposureCompensation = biasValue != null
        ? '${_formatExposureBias(biasValue.toRational().toDouble())} EV'
        : null;

    // 白平衡（WhiteBalance tag 0xA403，Long：0=自动 1=手动）
    final wbValue = exifIfd['WhiteBalance'];
    final String? whiteBalance = wbValue != null
        ? (wbValue.toInt() == 0 ? '自动' : '手动')
        : null;

    // GPS 位置（gpsIfd，纬度/经度 Rational + Ref 方向）
    final String? location = _readGps(exif.gpsIfd);

    return ExifInfo(
      cameraModel: cameraModel,
      make: make,
      focalLength: focalLength,
      fNumber: fNumber,
      iso: iso,
      shutterSpeed: shutterSpeed,
      exposureCompensation: exposureCompensation,
      whiteBalance: whiteBalance,
      resolution: resolution,
      fileSize: fileSize,
      location: location,
      timestamp: dtString?.isNotEmpty == true
          ? dtString
          : (timestamp != null
              ? DateTime.fromMillisecondsSinceEpoch(timestamp).toString()
              : null),
      sceneName: sceneName,
      template: template,
    );
  }

  /// 把字节数格式化为可读大小（B / KB / MB）。
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 曝光补偿显示：保留符号并避免尾随 0（如 0 EV、+0.3 EV、-1 EV）。
  static String _formatExposureBias(double ev) {
    if (ev == 0) return '0';
    final sign = ev > 0 ? '+' : '-';
    final abs = ev.abs();
    final s = abs == abs.toInt() ? abs.toInt().toString() : abs.toStringAsFixed(1);
    return '$sign$s';
  }

  /// 从 GPS IFD 读取并以「纬度, 经度」形式返回可读坐标。
  /// 依赖 image 4.2.0 的 IfdDirectory：GPSLatitude/GPSLongitude 为 Rational 数组。
  static String? _readGps(IfdDirectory gps) {
    final latV = gps['GPSLatitude'];
    final lonV = gps['GPSLongitude'];
    if (latV == null || lonV == null) return null;
    final lat = _formatCoordinate(latV, gps['GPSLatitudeRef']?.toString());
    final lon = _formatCoordinate(lonV, gps['GPSLongitudeRef']?.toString());
    if (lat == null && lon == null) return null;
    return [lat, lon].whereType<String>().join(', ');
  }

  /// 单个坐标：Rational 数组 [度, 分, 秒] + 方向 ref（N/S/E/W）。
  /// 依赖 image 4.2.0 的 IfdValue.length / toRational(index)。
  static String? _formatCoordinate(IfdValue value, String? ref) {
    if (value.length == 0) return null;
    final deg = value.toRational(0).toDouble();
    var result = '${deg.toStringAsFixed(2)}°';
    if (ref != null) result += ' $ref';
    return result;
  }

  static String _formatShutterSpeed(double seconds) {
    // 整数秒（如 2s、5s）避免显示 "2.0s"
    if (seconds >= 1 && seconds == seconds.toInt()) {
      return '${seconds.toInt()}s';
    }
    if (seconds >= 1) return '${seconds}s';
    return '1/${(1 / seconds).round()}s';
  }
}
