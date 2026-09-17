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

  /// 缓存编辑页实时预览的解码源（原生侧解码一次并常驻，返回 cacheId）。
  ///
  /// 背景：flutter_ohos 上 Dart FragmentShader 在真机静默渲染为原图（保存链路
  /// 「GPU 磨皮无效」的同根因），编辑页实时预览改走与拍摄成片同一套 C++
  /// processRgba（见 [renderDetailPreview]）。[returnRgba] 为 true 时同时回传
  /// RGBA（调用方可直接建 ui.Image，免二次解码）。
  /// 原生侧 LRU 上限 4 条，超限自动淘汰最早缓存。
  Future<OhosDetailCacheResult?> cacheDetailSource({
    required String path,
    int maxEdge = 2048,
    bool returnRgba = false,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'cacheDetailSource',
        <String, Object?>{
          'path': path,
          'maxEdge': maxEdge,
          'returnRgba': returnRgba,
        },
      );
      if (result == null) return null;
      if (result.containsKey('error')) return null;
      final cacheId = result['cacheId'] as String?;
      final width = (result['width'] as num?)?.toInt() ?? 0;
      final height = (result['height'] as num?)?.toInt() ?? 0;
      if (cacheId == null || cacheId.isEmpty || width <= 0 || height <= 0) {
        return null;
      }
      Uint8List? rgba;
      final raw = result['rgba'];
      if (raw is Uint8List) rgba = raw;
      if (raw is List<int>) rgba = Uint8List.fromList(raw);
      if (returnRgba && rgba == null) return null;
      return OhosDetailCacheResult(
        cacheId: cacheId,
        width: width,
        height: height,
        rgba: rgba,
      );
    } catch (e) {
      debugPrint('[OhosImageProcessor] cacheDetailSource failed: $e');
      return null;
    }
  }

  /// 按当前增量参数渲染细节效果预览帧（C++ processRgba + swapRgba，返回展示用
  /// RGBA）。源缓冲原生只读，可安全重复调用；cacheId 失效（LRU 淘汰）返回 null。
  Future<OhosRgbaResult?> renderDetailPreview({
    required String cacheId,
    int sharpen = 0,
    int smooth = 0,
    int vignette = 0,
    int grain = 0,
    double clarity = 0,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'renderDetailPreview',
        <String, Object?>{
          'cacheId': cacheId,
          'sharpen': sharpen.clamp(0, 100),
          'smooth': smooth.clamp(0, 100),
          'vignette': vignette.clamp(0, 100),
          'grain': grain.clamp(0, 100),
          'clarity': clarity.clamp(-100.0, 100.0),
        },
      );
      if (result == null) return null;
      if (result.containsKey('error')) return null;
      final width = (result['width'] as num?)?.toInt() ?? 0;
      final height = (result['height'] as num?)?.toInt() ?? 0;
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
      debugPrint('[OhosImageProcessor] renderDetailPreview failed: $e');
      return null;
    }
  }

  /// 释放原生侧预览解码源缓存（编辑页销毁/切换照片时调用；未命中静默忽略）。
  Future<void> releaseDetailSource(String cacheId) async {
    try {
      await _channel.invokeMethod<void>(
        'releaseDetailSource',
        <String, Object?>{'cacheId': cacheId},
      );
    } catch (_) {
      // 释放失败无副作用（LRU 会淘汰），静默忽略
    }
  }

  /// OHOS 单次原生拍照后处理：解码→几何变换→色彩矩阵→磨皮→锐化→JPEG硬编码→写文件。
  ///
  /// 暗角/颗粒/清晰度已全部由原生 C++ 实现（矩阵含 clarity 对比度折叠 + 独立中频
  /// pass，与 Dart 慢管线同序同语义）。本方法负责原生产出"底片"。开水印时底片随后由
  /// 调用方用原生解码+水印渲染+原生编码合成（见 capture_page 水印分支），因此
  /// 水印不再导致回退慢管线。磨皮已由原生 C++ 全分辨率实现（肤色掩膜+边缘保护，
  /// 非皮肤保留原值），不再导致回退。失败一律返回 false 并由调用方回退原有管线，
  /// 绝不阻塞拍照。
  ///
  /// - [matrix]：20 元素 ColorMatrix（由 `composePostProcessMatrix` 产出，保证与取景器一致）
  /// - [sharpen]：锐化值（0 表示不锐化；严格使用用户/模板真实值，应用层不做强制下限）
  /// - [clarity]：清晰度 -100..100（null/0 表示关闭；负值柔化。与 Dart 慢管线双重应用语义一致）
  /// - [smoothStrength]：磨皮强度 0-100（0 表示不磨皮）
  /// - [vignette]：暗角强度 0-100（0 表示不施加暗角）
  /// - [grain]：颗粒强度 0-100（0 表示不施加颗粒）
  /// - [maxDim]：输出最大边（默认 [kMaxProcessDim]=1280）
  ///
  /// 成功写文件后返回 true；任何失败（原生报错 / 非 OHOS）返回 false（调用方回退原管线）。
  /// 原生失败时仍在 [timing] 里给出各阶段耗时（decode/transform/sharpen/encode），
  /// 便于定位瓶颈。
  Future<bool> processJpeg({
    required String inputPath,
    required String outputPath,
    required double targetRatio,
    required bool isPortrait,
    required bool isFront,
    required List<double> matrix,
    required int sharpen,
    double? clarity,
    int smoothStrength = 0,
    int vignette = 0,
    int grain = 0,
    int maxDim = 1280,
    Map<String, int>? timing,
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
          'clarity': (clarity ?? 0).clamp(-100.0, 100.0),
          'smooth': smoothStrength.clamp(0, 100),
          'vignette': vignette.clamp(0, 100),
          'grain': grain.clamp(0, 100),
          'maxDim': maxDim,
        },
      );
      if (result == null) return false;
      final t = result['timing'];
      if (timing != null && t is Map<Object?, Object?>) {
        t.forEach((k, v) {
          if (v is int) timing[k.toString()] = v;
        });
      }
      final srcW = result['srcW'];
      final srcH = result['srcH'];
      debugPrint('[OhosImageProcessor] processJpeg src=${srcW}x$srcH out=${result['width']}x${result['height']} timing=$timing');
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

/// OHOS 原生预览解码源缓存结果（[OhosImageProcessor.cacheDetailSource]）。
class OhosDetailCacheResult {
  OhosDetailCacheResult({
    required this.cacheId,
    required this.width,
    required this.height,
    this.rgba,
  });

  /// 原生缓存 id（renderDetailPreview / releaseDetailSource 使用）。
  final String cacheId;

  final int width;
  final int height;

  /// returnRgba=true 时回传的 RGBA 字节（可直接建 ui.Image）。
  final Uint8List? rgba;
}