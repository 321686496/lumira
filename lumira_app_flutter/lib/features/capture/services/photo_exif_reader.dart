import 'dart:io';

import 'package:image/image.dart' as img;
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

    // 拍摄时间（DateTime tag 0x132，ASCII "YYYY:MM:DD HH:MM:SS"）
    final dateTimeValue = imageIfd['DateTime'];
    final String? dtString = dateTimeValue?.toString();

    // 焦距（FocalLength tag 0x920A，Rational）
    final focalLengthValue = exifIfd['FocalLength'];
    final String? focalLength = focalLengthValue != null
        ? '${focalLengthValue.toRational().toDouble()}mm'
        : null;

    // 光圈（FNumber tag 0x829D，Rational）
    final fNumberValue = exifIfd['FNumber'];
    final String? fNumber = fNumberValue != null
        ? 'f/${fNumberValue.toRational().toDouble()}'
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

    return ExifInfo(
      cameraModel: cameraModel,
      focalLength: focalLength,
      fNumber: fNumber,
      iso: iso,
      shutterSpeed: shutterSpeed,
      timestamp: dtString?.isNotEmpty == true
          ? dtString
          : (timestamp != null
              ? DateTime.fromMillisecondsSinceEpoch(timestamp).toString()
              : null),
      sceneName: sceneName,
      template: template,
    );
  }

  static String _formatShutterSpeed(double seconds) {
    if (seconds >= 1) return '${seconds}s';
    return '1/${(1 / seconds).round()}s';
  }
}
