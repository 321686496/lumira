import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// OHOS 原生图像解码桥接（MethodChannel `lumira/image_processor`）。
///
/// 触发背景：flutter_ohos 引擎的 dart:ui JPEG **软件**解码极慢，
/// 实测 1200x1600 需约 6s，导致 OHOS 拍照后处理严重超时（远超 800ms 目标）。
/// 本桥接把「JPEG 解码 → RGBA」交给 OHOS 系统 `image.ImageSource`
/// （系统级/硬件加速解码），返回 RGBA 后由 Flutter 用 `ImageDescriptor.raw`
/// 建 ui.Image，绕过 dart:ui 的慢速 JPEG 解码路径。
class OhosImageProcessor {
  OhosImageProcessor._();

  static final OhosImageProcessor instance = OhosImageProcessor._();

  static const MethodChannel _channel = MethodChannel('lumira/image_processor');

  /// 仅在 OHOS 平台启用（`defaultTargetPlatform.name == 'ohos'`，
  /// 避免依赖标准 Flutter SDK 不存在的 TargetPlatform.ohos）。
  static bool get isSupported => defaultTargetPlatform.name == 'ohos';

  /// 解码指定 JPEG 文件为 RGBA。
  ///
  /// - [path]：JPEG 文件绝对路径
  /// - [targetWidth]/[targetHeight]：解码降采样包围盒（等比 fit，不会拉伸），0 表示不解码缩放
  ///
  /// 返回解码后的实际宽高与 RGBA 字节；失败返回 null（调用方回退 dart:ui 解码）。
  Future<OhosRgbaResult?> decodeJpegToRgba({
    required String path,
    int targetWidth = 1600,
    int targetHeight = 1600,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'decodeJpegToRgba',
        <String, Object?>{
          'path': path,
          'targetWidth': targetWidth,
          'targetHeight': targetHeight,
        },
      );
      if (result == null) return null;
      final width = result['width'] as int;
      final height = result['height'] as int;
      final raw = result['rgba'];
      if (width <= 0 || height <= 0 || raw == null) return null;
      final Uint8List rgba;
      if (raw is Uint8List) {
        rgba = raw;
      } else if (raw is List<int>) {
        rgba = Uint8List.fromList(raw);
      } else {
        return null;
      }
      return OhosRgbaResult(width: width, height: height, rgba: rgba);
    } catch (e) {
      debugPrint('[OhosImageProcessor] decodeJpegToRgba failed: $e');
      return null;
    }
  }

  /// 把 RGBA_8888 字节编码为 JPEG（OHOS 系统硬件编码）。
  ///
  /// - [rgba]：RGBA_8888 字节（长 = [width]×[height]×4）
  /// - [quality]：JPEG 质量（0-100，默认 90）
  ///
  /// 返回 JPEG 字节；失败返回 null（调用方回退 Dart 软件编码）。
  Future<Uint8List?> encodeJpegFromRgba({
    required Uint8List rgba,
    required int width,
    required int height,
    int quality = 90,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'encodeJpegFromRgba',
        <String, Object?>{
          'rgba': rgba,
          'width': width,
          'height': height,
          'quality': quality,
        },
      );
      if (result == null) return null;
      if (result.containsKey('error')) return null;
      final jpeg = result['jpeg'];
      if (jpeg is Uint8List) return jpeg;
      if (jpeg is List<int>) return Uint8List.fromList(jpeg);
      return null;
    } catch (e) {
      debugPrint('[OhosImageProcessor] encodeJpegFromRgba failed: $e');
      return null;
    }
  }

  /// OHOS 单次原生拍照后处理：解码→几何变换→色彩矩阵→锐化→JPEG硬编码→写文件。
  ///
  /// 只要「带暂未原生实现的复杂效果（磨皮/暗角/颗粒/Clarity）」时为 false，
  /// 调用方走现有 GPU+isolate 管线；本方法负责原生产出"底片"。开水印时底片随后由
  /// 调用方用原生解码+水印渲染+原生编码合成（见 capture_page 水印分支），因此
  /// 水印不再导致回退慢管线。失败一律返回 false 并由调用方回退原有管线，绝不阻塞拍照。
  ///
  /// - [matrix]：20 元素 ColorMatrix（由 `composePostProcessMatrix` 产出，保证与取景器一致）
  /// - [sharpen]：有效锐化值（应已应用 kMinLiveSharpen 下限）
  /// - [maxDim]：输出最大边（默认 [kMaxProcessDim]=1280）
  ///
  /// 成功写文件后返回 true；任何失败（原生报错 / 非 OHOS）返回 false（调用方回退原管线）。
  Future<bool> processJpeg({
    required String inputPath,
    required String outputPath,
    required double targetRatio,
    required bool isPortrait,
    required bool isFront,
    required List<double> matrix,
    required int sharpen,
    int maxDim = 1280,
  }) async {
    if (!isSupported) return false;
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'processJpeg',
        <String, Object?>{
          'inputPath': inputPath,
          'outputPath': outputPath,
          'targetRatio': targetRatio,
          'isPortrait': isPortrait,
          'isFront': isFront,
          'matrix': matrix,
          'sharpen': sharpen,
          'maxDim': maxDim,
        },
      );
      if (result == null) return false;
      return result['ok'] == true;
    } catch (e) {
      debugPrint('[OhosImageProcessor] processJpeg failed: $e');
      return false;
    }
  }
}

/// OHOS 原生解码结果。
class OhosRgbaResult {
  OhosRgbaResult({
    required this.width,
    required this.height,
    required this.rgba,
  });

  final int width;
  final int height;
  final Uint8List rgba;
}