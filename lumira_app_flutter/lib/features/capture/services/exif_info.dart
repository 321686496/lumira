/// EXIF 信息（用于 EXIF 海报显示）
///
/// 从 [PhotoExifReader] 读取文件元数据后填充；场景/模板由调用方传入**显示名**
/// （取不到中文名时回退原 ID），字段缺省即为「海报上不展示该项」。
class ExifInfo {
  final String? cameraModel;
  final String? make;
  final String? focalLength;
  final String? fNumber;
  final String? iso;
  final String? shutterSpeed;
  final String? exposureCompensation;
  final String? whiteBalance;
  final String? resolution;
  final String? fileSize;
  final String? location;
  final String? timestamp;
  final String? sceneName;
  final String? template;

  const ExifInfo({
    this.cameraModel,
    this.make,
    this.focalLength,
    this.fNumber,
    this.iso,
    this.shutterSpeed,
    this.exposureCompensation,
    this.whiteBalance,
    this.resolution,
    this.fileSize,
    this.location,
    this.timestamp,
    this.sceneName,
    this.template,
  });
}
