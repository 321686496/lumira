// lib/features/capture/services/dart_photo_pipeline.dart
import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../data/capture_state.dart';
import '../domain/filter_recipe.dart';
import '../domain/photo_template.dart';
import 'photo_pipeline.dart';
import 'photo_post_processor.dart';
import 'skin_smoother.dart';

/// 基于 Dart（dart:ui Canvas + image 包）的双管线 PhotoPipeline 实现。
///
/// - [quickProcess]：主 Isolate，用 dart:ui Canvas（GPU 加速）做解码+裁剪+
///   ColorMatrix+Vignette，返回 PNG 内存字节，目标 <100ms。
/// - [fullProcess]：通过 [compute] 把纯 image 包实现丢到 worker Isolate，
///   完成全部逐像素效果（皮肤平滑/Sharpen/Clarity/Grain/补光/JPEG 编码），
///   返回最终文件路径。失败时降级调用 [PhotoPostProcessor.processFile]。
class DartPhotoPipeline implements PhotoPipeline {
  DartPhotoPipeline();

  // ─────────────────────────────────────────────────────────────────────
  // quickProcess：主 Isolate，dart:ui Canvas
  // ─────────────────────────────────────────────────────────────────────

  @override
  Future<QuickResult?> quickProcess({
    required String inputPath,
    required PostProcess params,
    required String aspectRatio,
    required double screenRatio,
    required bool isPortrait,
    bool rawMode = false,
    TransformParams? transform,
    String facing = 'back',
  }) async {
    final sw = Stopwatch()..start();
    try {
      // 1. 读取并解码 JPEG（降采样解码，减少内存和后续处理开销）
      final bytes = await io.File(inputPath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 500);
      final frame = await codec.getNextFrame();
      final srcImage = frame.image;
      codec.dispose();
      debugPrint(
          '[quickProcess] 解码: ${srcImage.width}x${srcImage.height}, facing=$facing, isPortrait=$isPortrait, ${sw.elapsedMilliseconds}ms');

      // 2. 计算方向对齐参数（不实际旋转，仅计算变换矩阵，稍后合并到 Canvas）
      final jpegIsLandscape = srcImage.width > srcImage.height;
      final needRotate = (isPortrait && jpegIsLandscape) ||
          (!isPortrait && !jpegIsLandscape);
      final needMirror = facing == 'front';
      // 用户变换（如果有，则在方向对齐之上叠加）
      final hasTransform = transform != null && !transform.isIdentity;
      final userRotation = hasTransform ? transform.rotation : 0;
      final userFlipH = hasTransform ? transform.flipH : false;
      final userFlipV = hasTransform ? transform.flipV : false;

      // 3. 计算输出尺寸（基于 screenRatio，角标缩略图长边 ≤ 256）
      const maxDimension = 256;
      var outW = (isPortrait ? screenRatio : 1.0) * maxDimension;
      var outH = (isPortrait ? 1.0 : 1.0 / screenRatio) * maxDimension;
      if (outW > maxDimension) {
        outH = outH * maxDimension / outW;
        outW = maxDimension.toDouble();
      }
      if (outH > maxDimension) {
        outW = outW * maxDimension / outH;
        outH = maxDimension.toDouble();
      }
      // 严格保持 screenRatio
      if (isPortrait) {
        outW = maxDimension * screenRatio;
        outH = maxDimension.toDouble();
      } else {
        outW = maxDimension.toDouble();
        outH = maxDimension / screenRatio;
      }
      final iOutW = outW.round();
      final iOutH = outH.round();

      // 4. 单次 Canvas：方向对齐 + cover 裁剪 + 降采样 + ColorMatrix（一步完成）
      //    将旋转/翻转/cover 缩放全部合并到 Canvas 变换中，避免多次 GPU 往返。
      final matrix = rawMode ? null : composePostProcessMatrix(params);
      final hasMatrix = matrix != null && !_isIdentityMatrix(matrix);

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      final paint = ui.Paint()..filterQuality = ui.FilterQuality.low;
      if (hasMatrix) {
        paint.colorFilter = ui.ColorFilter.matrix(matrix);
      }

      // 计算变换参数
      final alignRotation = needRotate ? (isPortrait ? 90 : 270) : 0;
      final totalRotation =
          (alignRotation + userRotation) * math.pi / 180.0;
      final totalFlipH = needMirror != userFlipH; // XOR
      final totalFlipV = userFlipV;

      // cover 缩放（等比，不改变内容比例）：在原始图像坐标系中计算，
      // 让旋转后的图像完全覆盖输出画布，溢出部分由画布边界自动裁剪。
      //
      // 关键数学：canvas 变换顺序是 scale → rotate（先写的先应用到源图坐标）。
      // 对源点 (x, y)，经过均匀 scale(s) 再 rotate 90°：
      //   rotate 90° 矩阵: [0, 1, -1, 0]
      //   (x·s, y·s) → (y·s, -x·s)
      // 因此：
      //   - 源宽 srcW 映射到输出 Y 轴 → s ≥ outH / srcW
      //   - 源高 srcH 映射到输出 X 轴 → s ≥ outW / srcH
      // 不旋转时：s ≥ outW / srcW 且 s ≥ outH / srcH
      // 取较大值（cover 定义：完全覆盖画布，允许溢出）
      final swapDims = (alignRotation == 90 || alignRotation == 270) ||
          userRotation == 90 ||
          userRotation == 270;
      final double coverScale;
      if (swapDims) {
        coverScale = math.max(
          outW / srcImage.height.toDouble(), // 源高 → 输出宽
          outH / srcImage.width.toDouble(),  // 源宽 → 输出高
        );
      } else {
        coverScale = math.max(
          outW / srcImage.width.toDouble(),
          outH / srcImage.height.toDouble(),
        );
      }

      // 关键：scale 和 mirror 必须在 rotate 之前应用（在原始图像坐标系中）。
      // rotate 之后画布 X/Y 轴互换，若 scale 在 rotate 之后会导致宽高缩放因子被交换→拉伸；
      // mirror 在 rotate 之后会导致左右镜像变成上下翻转。
      canvas.translate(outW / 2.0, outH / 2.0);
      canvas.scale(
        (totalFlipH ? -1.0 : 1.0) * coverScale,
        (totalFlipV ? -1.0 : 1.0) * coverScale,
      );
      canvas.rotate(totalRotation);
      canvas.drawImage(
        srcImage,
        ui.Offset(-srcImage.width / 2.0, -srcImage.height / 2.0),
        paint,
      );

      final picture = recorder.endRecording();
      final outImage = await picture.toImage(iOutW, iOutH);
      picture.dispose();
      srcImage.dispose();
      debugPrint(
          '[quickProcess] GPU合并: ${outImage.width}x${outImage.height}, ${sw.elapsedMilliseconds}ms');

      // 5. 导出 PNG 字节
      final byteData =
          await outImage.toByteData(format: ui.ImageByteFormat.png);
      outImage.dispose();
      if (byteData == null) {
        debugPrint('[quickProcess] toByteData(png) 返回 null');
        return null;
      }

      final elapsed = sw.elapsedMilliseconds;
      debugPrint('[quickProcess] 完成: ${elapsed}ms');
      if (elapsed > 200) {
        debugPrint('[quickProcess] WARN: 超出 200ms 预算 (${elapsed}ms)');
      }
      return QuickResult(
        bytes: byteData.buffer.asUint8List(),
        width: iOutW,
        height: iOutH,
      );
    } catch (e, st) {
      debugPrint('[quickProcess] 失败: $e\n$st');
      return null;
    } finally {
      sw.stop();
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // fullProcess：worker Isolate（compute），image 包纯 Dart
  // ─────────────────────────────────────────────────────────────────────

  @override
  Future<FullResult> fullProcess({
    required String inputPath,
    required PostProcess params,
    required String aspectRatio,
    required double screenRatio,
    required bool isPortrait,
    bool rawMode = false,
    TransformParams? transform,
    FillLightState? fillLight,
    String? outputPath,
    String facing = 'back',
  }) async {
    final sw = Stopwatch()..start();
    final finalOutputPath = outputPath ?? inputPath.replaceAll('.jpg', '_final.jpg');

    try {
      // 1. 主 Isolate 读取原图字节
      final inputBytes = await io.File(inputPath).readAsBytes();

      // 2. 构造 Isolate 输入（全部可序列化的字段）
      final isolateInput = _IsolateInput(
        inputBytes: inputBytes,
        params: params,
        aspectRatio: aspectRatio,
        screenRatio: screenRatio,
        isPortrait: isPortrait,
        rawMode: rawMode,
        transform: transform,
        fillLight: fillLight,
        facing: facing,
      );

      // 3. 在 worker Isolate 中执行完整处理
      //    用 compute() 而非 Isolate.run —— compute() 在所有 Flutter 平台
      //    （含 OHOS Flutter 3.7）上可用，API 更简单，内部封装 Isolate。
      final result = await compute(_processInIsolate, isolateInput);

      // 4. 主 Isolate 写文件
      await io.File(finalOutputPath).writeAsBytes(result.bytes);

      debugPrint('[fullProcess] 完成: ${sw.elapsedMilliseconds}ms');
      return FullResult(
        filePath: finalOutputPath,
        width: result.width,
        height: result.height,
      );
    } catch (e, st) {
      debugPrint('[fullProcess] Isolate 失败，降级到 PhotoPostProcessor: $e\n$st');
      // 5. 降级：用主 Isolate 的 PhotoPostProcessor.processFile
      try {
        final path = await PhotoPostProcessor.processFile(
          inputPath: inputPath,
          params: params,
          outputPath: finalOutputPath,
          rawMode: rawMode,
          aspectRatio: aspectRatio,
          screenRatio: screenRatio,
          isPortrait: isPortrait,
          transform: transform,
          fillLight: fillLight,
          facing: facing,
        );
        debugPrint('[fullProcess] 降级完成: ${sw.elapsedMilliseconds}ms');
        return FullResult(filePath: path, width: 0, height: 0);
      } catch (e2, st2) {
        debugPrint('[fullProcess] 降级也失败: $e2\n$st2');
        return FullResult(filePath: finalOutputPath, width: 0, height: 0);
      }
    } finally {
      sw.stop();
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // 主 Isolate 辅助：判断 ColorMatrix
  // ─────────────────────────────────────────────────────────────────────

  /// 判断 4×5 ColorMatrix 是否为单位矩阵。
  /// 从 PhotoPostProcessor._isIdentityMatrix 移植。
  static bool _isIdentityMatrix(List<double> m) {
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        final idx = i * 5 + j;
        final expected = (i == j) ? 1.0 : 0.0;
        if ((m[idx] - expected).abs() > 0.001) return false;
      }
      if (m[i * 5 + 4].abs() > 0.001) return false;
    }
    return true;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Isolate 通信类型（全部可序列化）
// ─────────────────────────────────────────────────────────────────────────

/// compute() 的输入参数。所有字段必须可跨 Isolate 传递。
class _IsolateInput {
  const _IsolateInput({
    required this.inputBytes,
    required this.params,
    required this.aspectRatio,
    required this.screenRatio,
    required this.isPortrait,
    required this.rawMode,
    required this.transform,
    required this.fillLight,
    required this.facing,
  });

  final Uint8List inputBytes;
  final PostProcess params;
  final String aspectRatio;
  final double screenRatio;
  final bool isPortrait;
  final bool rawMode;
  final TransformParams? transform;
  final FillLightState? fillLight;
  final String facing;
}

/// compute() 的输出。所有字段必须可跨 Isolate 传递。
class _IsolateResult {
  const _IsolateResult({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

// ─────────────────────────────────────────────────────────────────────────
// 顶层函数：worker Isolate 入口（compute 要求顶层或静态）
// 纯 image 包实现，无 dart:ui 依赖
// ─────────────────────────────────────────────────────────────────────────

/// 判断 JPEG 是否内嵌 Display P3 / DCI-P3 的 ICC 配置文件（宽色域 iPhone 相机输出）。
///
/// image 包纯 Dart 解码忽略 ICC，需据此决定是否做 P3→sRGB 色域换算。
/// 仅在 JPEG 字节里捜索 ICC 描述文本，命中概率极低、误判可忽略。
bool _isDisplayP3Jpeg(Uint8List bytes) {
  for (final marker in const ['Display P3', 'DCI-P3', 'P3D65', 'DISPLAY P3']) {
    if (_bytesContainsAscii(bytes, marker)) return true;
  }
  return false;
}

/// 在字节流中查找 ASCII 子串（大小写敏感）。
bool _bytesContainsAscii(Uint8List hay, String needle) {
  final pat = needle.codeUnits;
  final n = hay.length - pat.length;
  if (n < 0) return false;
  outer:
  for (int i = 0; i <= n; i++) {
    for (int j = 0; j < pat.length; j++) {
      if (hay[i + j] != pat[j]) continue outer;
    }
    return true;
  }
  return false;
}

// sRGB 传递函数的线性化与编码用查表（避免逐像素 pow 影响 800ms 预算）。
final List<double> _srgbToLinearLut = _buildSrgbToLinearLut();
final List<double> _srgbEncodeLut = _buildSrgbEncodeLut();

List<double> _buildSrgbToLinearLut() {
  return List<double>.generate(256, (i) {
    final v = i / 255.0;
    if (v <= 0.04045) return v / 12.92;
    return math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  });
}

List<double> _buildSrgbEncodeLut() {
  const steps = 4096;
  return List<double>.generate(steps, (i) {
    final c = i / (steps - 1);
    if (c <= 0.0031308) return c * 12.92;
    return (1.055 * math.pow(c, 1.0 / 2.4) - 0.055).clamp(0.0, 1.0).toDouble();
  });
}

/// 将 image 包解码出的 Display P3（sRGB 传递函数 + P3 基色）像素就地换算为 sRGB。
///
/// P3 与 sRGB 同为 D65 白点、同为 sRGB 传递函数，仅基色不同，故只需线性化后乘
/// P3→sRGB 线性基色转换矩阵，再按 sRGB 传递函数编码即可。
///
/// ⚠️ 方向铁律：此处必须用「sRGB→P3」矩阵的逆（P3→sRGB）。常见的
/// [[0.8225,0.1774,0],[0.0332,0.9669,0],[0.0171,0.0724,0.9105]] 是 sRGB→P3（正向）
/// 矩阵；把它当成 P3→sRGB 去乘 P3 像素会对肤色引入残余的黄色/偏暖（R 被压低、
/// G/B 抬升）。正确的逆矩阵带负系数，能还原 P3 中超出 sRGB 色域的红色。
void _applyP3ToSrgb(img.Image image) {
  const steps = 4096;
  for (final p in image) {
    final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
    final lr = _srgbToLinearLut[r];
    final lg = _srgbToLinearLut[g];
    final lb = _srgbToLinearLut[b];
    // P3(D65) → sRGB(D65) 线性基色转换矩阵（sRGB→P3 正向矩阵的逆）。
    final sr = (1.2249 * lr - 0.2247 * lg).clamp(0.0, 1.0);
    final sg = (-0.0420 * lr + 1.0419 * lg).clamp(0.0, 1.0);
    final sb = (-0.0197 * lr - 0.0786 * lg + 1.0983 * lb).clamp(0.0, 1.0);
    p
      ..r = (_srgbEncodeLut[(sr * (steps - 1)).round()] * 255).round()
      ..g = (_srgbEncodeLut[(sg * (steps - 1)).round()] * 255).round()
      ..b = (_srgbEncodeLut[(sb * (steps - 1)).round()] * 255).round();
  }
}

/// 判断 JPEG 字节是否内嵌 Display P3 / DCI-P3 ICC（宽色域 iPhone 相机输出）。
///
/// 与 [_isDisplayP3Jpeg] 相同，公开给 capture 拍摄通路（dart:ui 解码）复用。
bool isDisplayP3Jpeg(Uint8List bytes) => _isDisplayP3Jpeg(bytes);

/// 对 RGBA 字节缓冲内的像素就地做正确的 P3→sRGB 色域换算。
///
/// capture 拍摄走 dart:ui 解码（[ui.ImageDescriptor.encoded]，忽略 JPEG 内嵌 ICC），
/// 宽色域 iPhone 原片会被当作 sRGB 解释 → 肤色/暖色偏黄，而取景器走系统色管
/// （P3 渲染正确）故不黄。此函数把解码出的 RGBA（r,g,b,a 顺序）像素经
/// 线性化 → 正确的 P3→sRGB 逆矩阵 → sRGB 编码，使成片与取景器一致。
///
/// 方向铁律参照 [_applyP3ToSrgb]：必须用 sRGB→P3 正向矩阵的逆（带负系数），
/// 若误用正向矩阵会把红色进一步放大、更黄。
void applyP3ToSrgbRgba(Uint8List rgba) {
  const steps = 4096;
  for (int i = 0; i + 2 < rgba.length; i += 4) {
    final r = rgba[i], g = rgba[i + 1], b = rgba[i + 2];
    final lr = _srgbToLinearLut[r];
    final lg = _srgbToLinearLut[g];
    final lb = _srgbToLinearLut[b];
    // P3(D65) → sRGB(D65) 线性基色转换矩阵（sRGB→P3 正向矩阵的逆）。
    final sr = (1.2249 * lr - 0.2247 * lg).clamp(0.0, 1.0);
    final sg = (-0.0420 * lr + 1.0419 * lg).clamp(0.0, 1.0);
    final sb = (-0.0197 * lr - 0.0786 * lg + 1.0983 * lb).clamp(0.0, 1.0);
    rgba[i] = (_srgbEncodeLut[(sr * (steps - 1)).round()] * 255).round();
    rgba[i + 1] = (_srgbEncodeLut[(sg * (steps - 1)).round()] * 255).round();
    rgba[i + 2] = (_srgbEncodeLut[(sb * (steps - 1)).round()] * 255).round();
  }
}

/// 在 worker Isolate 中执行完整照片后处理。
///
/// 从 [PhotoPostProcessor] 移植全部逻辑到 image 包 API：
/// - 解码 → 变换 → 裁剪 → 降采样 → ColorMatrix → 皮肤平滑 → Sharpen/Clarity/Grain → 补光 → JPEG 编码
Future<_IsolateResult> _processInIsolate(_IsolateInput input) async {
  // 1. 解码 JPEG（image 包）
  final decoded = img.decodeJpg(input.inputBytes);
  if (decoded == null) {
    throw StateError('img.decodeJpg 返回 null');
  }
  var image = decoded;

  // 0. 尽早降采样到输出上限尺寸，避免在 8.2MP 等高分辨率原图上做昂贵的
  //    方向对齐/旋转/裁剪/磨皮等逐像素运算（纯 Dart image 包在 OHOS 端极慢）。
  //    成片最终本就固定压到 ≤ maxDimension（见步骤 4），提前降采样对最终
  //    逐像素结果完全等价、画质零损失，仅省掉「大图白算」的开销。
  const maxDimension = 1536;
  if (image.width > maxDimension || image.height > maxDimension) {
    final scale = maxDimension / math.max(image.width, image.height);
    image = img.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
    );
  }

  // 1.2 iOS 宽色域照片的色域校正：宽色域 iPhone 相机 JPEG 内嵌 Display P3 的 ICC
  //     配置文件，而 image 包纯 Dart 解码忽略 ICC，直接以 sRGB 解释 P3 数值，导致
  //     肤色偏黄（取景器走 dart:ui / 系统色管，渲染 P3 正确，故两者不一致）。
  //     检测到 P3 时做 P3→sRGB 线性矩阵变换，使保存成图与取景器一致。
  if (_isDisplayP3Jpeg(input.inputBytes)) {
    _applyP3ToSrgb(image);
  }

  // 1.5 方向对齐：把 JPEG 像素旋转到与取景器显示方向一致（WYSIWYG）
  // 与 quickProcess._alignOrientationUi 使用相同逻辑，确保两条管线输出一致。
  // 不依赖 EXIF（平台差异大），改为基于 JPEG 实际像素方向 + 设备方向对齐。
  image = _alignOrientationImg(image, input.isPortrait, input.facing);

  // 2. 变换（旋转/翻转/拉直）—— 从 PhotoPostProcessor._applyTransform 移植到 image 包
  if (input.transform != null && !input.transform!.isIdentity) {
    image = _applyTransformImg(image, input.transform!);
  }

  // 3. 裁剪（复用 PhotoPostProcessor.computeCropRect 纯数学计算）
  final cropRect = PhotoPostProcessor.computeCropRect(
    input.aspectRatio,
    image.width,
    image.height,
    input.screenRatio,
    input.isPortrait,
  );
  image = img.copyCrop(
    image,
    x: cropRect[0],
    y: cropRect[1],
    width: cropRect[2],
    height: cropRect[3],
  );

  // 4. 降采样兜底（前序变换如「拉直」小角度旋转会扩展画布，可能把尺寸推回上限之上，
  //    此处复用步骤 0 的 maxDimension 做最终收敛，保证输出长边恒 ≤ 1536）。
  if (image.width > maxDimension || image.height > maxDimension) {
    final scale = maxDimension / math.max(image.width, image.height);
    image = img.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
    );
  }

  // 5. ColorMatrix 逐像素应用（rawMode 跳过）
  if (!input.rawMode) {
    final matrix = composePostProcessMatrix(input.params);
    if (!_isIdentityMatrixImg(matrix)) {
      image = applyColorMatrixImg(image, matrix);
    }
  }

  // 5.5. 拉腿（几何形变，改变高度；rawMode 下同样应用，与裁剪/变换一致）
  if (input.params.legStretch > 0) {
    image = applyLegStretchImg(image, legStretch: input.params.legStretch);
  }

  // 6. 皮肤平滑（rawMode 跳过）—— 直接复用 SkinSmoother（已是纯 image 包实现）
  if (!input.rawMode && input.params.smoothStrength > 0) {
    try {
      image = SkinSmoother.smooth(image, input.params.smoothStrength);
    } catch (e) {
      // 皮肤平滑失败不阻塞，静默跳过
    }
  }

  // 7. Sharpen / Clarity / Grain（rawMode 跳过）
  //    从 PhotoPostProcessor._applyPerPixelEffects 移植到 image 包
  if (!input.rawMode) {
    final clarityVal = input.params.color.clarity;
    final needsPerPixel = input.params.sharpen > 0 ||
        (clarityVal != null && clarityVal != 0) ||
        input.params.grain > 0;
    if (needsPerPixel) {
      applyPerPixelEffectsImg(
        image,
        sharpen: input.params.sharpen,
        clarity: clarityVal,
        grain: input.params.grain,
      );
    }
  }

  // 8. 补光效果不应用到照片
  // 补光是屏幕发光照亮被摄物（物理光源），不应作为颜色滤镜叠加到照片上。

  // 9. JPEG 编码（quality: 88，与 PhotoPostProcessor._encodeJpg 一致）
  final outputBytes = img.encodeJpg(image, quality: 88);

  return _IsolateResult(
    bytes: Uint8List.fromList(outputBytes),
    width: image.width,
    height: image.height,
  );
}

// ─────────────────────────────────────────────────────────────────────────
// image 包逐像素实现（从 PhotoPostProcessor 移植）
// ─────────────────────────────────────────────────────────────────────────

/// 应用变换（旋转/翻转/拉直）via image 包。
/// 从 PhotoPostProcessor._applyTransform 移植，把 dart:ui Canvas 调用改为 image 包 API。
img.Image _applyTransformImg(img.Image src, TransformParams t) {
  var result = src;

  // 1. 旋转（90/180/270 度精确旋转，image 包自动处理维度交换）
  if (t.rotation != 0) {
    result = img.copyRotate(result, angle: t.rotation.toDouble());
  }

  // 2. 拉直（小角度旋转，image 包会扩展画布以容纳旋转后的图像）
  if (t.straighten.abs() >= 0.01) {
    result = img.copyRotate(result, angle: t.straighten);
  }

  // 3. 翻转
  if (t.flipH) {
    result = img.flip(result, direction: img.FlipDirection.horizontal);
  }
  if (t.flipV) {
    result = img.flip(result, direction: img.FlipDirection.vertical);
  }

  return result;
}

/// 把 JPEG 像素旋转到与取景器显示方向一致（image 包 API）。
///
/// 与 [DartPhotoPipeline._alignOrientationUi] 使用相同逻辑，确保两条管线输出一致。
/// 不依赖 EXIF，基于 JPEG 实际像素方向 + 设备方向对齐 + 前置镜像。
img.Image _alignOrientationImg(img.Image src, bool isPortrait, String facing) {
  final jpegIsLandscape = src.width > src.height;
  final deviceIsPortrait = isPortrait;
  final needRotate =
      (deviceIsPortrait && jpegIsLandscape) || (!deviceIsPortrait && !jpegIsLandscape);
  final needMirror = facing == 'front';

  if (!needRotate && !needMirror) return src;

  var result = src;
  if (needRotate) {
    // 竖屏 + JPEG横向 → 顺时针 90°
    // 横屏 + JPEG竖向 → 逆时针 90°（270°）
    final angle = deviceIsPortrait ? 90 : 270;
    result = img.copyRotate(result, angle: angle);
  }
  if (needMirror) {
    result = img.flip(result, direction: img.FlipDirection.horizontal);
  }
  return result;
}

/// 逐像素应用 4×5 ColorMatrix（公共方法，供 isolate 后处理复用）。
/// matrix 长度 20，按行优先存储：
///   R' = m[0]*R + m[1]*G + m[2]*B + m[3]*A + m[4]
///   G' = m[5]*R + m[6]*G + m[7]*B + m[8]*A + m[9]
///   B' = m[10]*R + m[11]*G + m[12]*B + m[13]*A + m[14]
///   A' = m[15]*R + m[16]*G + m[17]*B + m[18]*A + m[19]
///
/// 像素值范围 0-255（与 dart:ui ColorFilter.matrix 一致）。
///
/// 注意：此函数仅在无法使用 dart:ui GPU 路径时作为 fallback。
/// 主流程应使用 [applyColorMatrixOnGpu] 以保证与取景器所见即所得。
img.Image applyColorMatrixImg(img.Image image, List<double> m) {
  for (final p in image) {
    final r = p.r;
    final g = p.g;
    final b = p.b;
    final a = p.a;
    p
      ..r = (m[0] * r + m[1] * g + m[2] * b + m[3] * a + m[4]).clamp(0, 255)
      ..g = (m[5] * r + m[6] * g + m[7] * b + m[8] * a + m[9]).clamp(0, 255)
      ..b = (m[10] * r + m[11] * g + m[12] * b + m[13] * a + m[14]).clamp(0, 255)
      ..a = (m[15] * r + m[16] * g + m[17] * b + m[18] * a + m[19]).clamp(0, 255);
  }
  return image;
}

/// Sharpen + Clarity + Grain 逐像素效果（公共方法，供 isolate 后处理复用）。
/// 从 PhotoPostProcessor._applyPerPixelEffects 移植，去掉 ui.Image ↔ img.Image 转换。
///
/// 统一算法规格（与 OHOS C++ / 预览 FragmentShader 同源）：
/// - 锐化：亮度域死区 Unsharp（lumaBlur=4 邻域均值，死区 thr=0.75，edge=smoothstep(0.75,2.25)，
///   a=sharpen/100×6.0 上限 6.0 —— 2026-09-05 二次修正对齐 iOS 相册锐化量级），
///   仅亮度方向增益 → 色相不变、平坦区不放大颗粒、避免 halo。
/// - 颗粒：预置 128×128 tile + 双线性 + 幅度随亮度（阴影弱、高光强，胶片感），
///   固定 offset (13,29) → 与预览/水印/成片一致。
void applyPerPixelEffectsImg(
  img.Image image, {
  required int sharpen,
  required double? clarity,
  required int grain,
}) {
  // Sharpen（亮度域死区 Unsharp）
  // 强度 a=v/100×6.0（上限 6.0，四端统一）：6.0 是 OHOS 同步前的原始值，真机
  // 观感校准点（「锐化明显可感知」）。2026-09-06 曾误回调 1.2/2.5——真机实测
  // 拉满无感（硬边缘增益仅 1-2%/255 级别，人眼不可察），恢复 6.0。与 iOS 取景器
  // PreviewEffectProcessor / OHOS photo_processor.cpp / preview_fx.cpp 同步。
  // 历史注：曾全局 ×6.0 时代用户反馈「效果过重」实为 kernel 坐标 bug 叠加所致，
  // kernel 修复后纯 6.0 即正常锐化观感。死区 0.75、门控 (0.75,2.25) 不变。
  if (sharpen > 0) {
    final double a = (sharpen / 100.0 * 6.0).clamp(0.0, 6.0).toDouble();
    const thr = 0.75; // 死区下界（0-255 亮度差）
    const e0 = 0.75, e1v = 2.25;
    final w = image.width, h = image.height;
    final luma = Float64List(w * h);
    final lumaBlur = Float64List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = image.getPixel(x, y);
        luma[y * w + x] = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
      }
    }
    for (var y = 0; y < h; y++) {
      final ym0 = y > 0 ? y - 1 : y;
      final yp1 = y < h - 1 ? y + 1 : y;
      for (var x = 0; x < w; x++) {
        final xm0 = x > 0 ? x - 1 : x;
        final xp1 = x < w - 1 ? x + 1 : x;
        final idx = y * w + x;
        lumaBlur[idx] =
            (luma[ym0 * w + x] + luma[yp1 * w + x] +
                luma[y * w + xm0] + luma[y * w + xp1]) *
            0.25;
      }
    }
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final idx = y * w + x;
        final diff = luma[idx] - lumaBlur[idx];
        double amnt = 0;
        if (diff > thr) {
          amnt = a * (diff - thr);
        } else if (diff < -thr) {
          amnt = a * (diff + thr);
        }
        var et = (diff.abs() - e0) / (e1v - e0);
        et = et.clamp(0.0, 1.0).toDouble();
        final edge = et * et * (3.0 - 2.0 * et); // 0..1
        final gain = amnt * edge;
        final p = image.getPixel(x, y);
        p
          ..r = (p.r + gain).clamp(0, 255)
          ..g = (p.g + gain).clamp(0, 255)
          ..b = (p.b + gain).clamp(0, 255);
      }
    }
  }

  // Clarity（中频对比度：原图 - 高斯模糊，再按 amount 混合）
  if (clarity != null && clarity != 0) {
    final amount = (clarity.abs() / 100.0).clamp(0.0, 1.0) * 0.6;
    final sign = clarity > 0 ? 1.0 : -1.0;
    final blurred = img.gaussianBlur(img.Image.from(image), radius: 3);
    for (final p in image) {
      final bp = blurred.getPixel(p.x, p.y);
      p
        ..r = (p.r + (p.r - bp.r) * sign * amount).clamp(0, 255)
        ..g = (p.g + (p.g - bp.g) * sign * amount).clamp(0, 255)
        ..b = (p.b + (p.b - bp.b) * sign * amount).clamp(0, 255);
    }
  }

  // Grain（预置 128×128 tile + 双线性 + 亮度驱动幅度）
  if (grain > 0) {
    final tile = _ensureGrainTile();
    final double s = (grain / 100.0).clamp(0.0, 1.0).toDouble();
    const kFilm = 24.0; // 峰值幅度 ±24/255
    const invTex = 1.0 / _kGrainTex;
    final uOff = 13.0 * invTex, vOff = 29.0 * invTex;
    final w = image.width, h = image.height;
    for (var y = 0; y < h; y++) {
      var v = (y * invTex) + vOff;
      v -= v.floor();
      final yp = v * _kGrainTex - 0.5;
      final y0f = yp.floor();
      var y0 = y0f;
      final wy = yp - y0;
      final y1 = _wrapMod(y0 + 1);
      y0 = _wrapMod(y0);
      for (var x = 0; x < w; x++) {
        var u = (x * invTex) + uOff;
        u -= u.floor();
        final xp = u * _kGrainTex - 0.5;
        final x0f = xp.floor();
        var x0 = x0f;
        final wx = xp - x0;
        final x1 = _wrapMod(x0 + 1);
        x0 = _wrapMod(x0);
        final g00 = tile[y0 * _kGrainTex + x0];
        final g10 = tile[y0 * _kGrainTex + x1];
        final g01 = tile[y1 * _kGrainTex + x0];
        final g11 = tile[y1 * _kGrainTex + x1];
        final gval = g00 * (1 - wx) * (1 - wy) +
            g10 * wx * (1 - wy) +
            g01 * (1 - wx) * wy +
            g11 * wx * wy;

        final p = image.getPixel(x, y);
        final luma = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
        final ln = luma / 255.0;
        var lw = (ln - 0.05) / (0.85 - 0.05);
        lw = lw.clamp(0.0, 1.0).toDouble();
        final lumaScale = 0.35 + 0.65 * (lw * lw * (3.0 - 2.0 * lw));
        final off = gval * s * kFilm * lumaScale;

        p
          ..r = (p.r + off).clamp(0, 255)
          ..g = (p.g + off).clamp(0, 255)
          ..b = (p.b + off).clamp(0, 255);
      }
    }
  }
}

/// 预计算 128×128 白噪声 tile（进程一次，固定 LCG 种子族与 OHOS C++ 一致）。
const int _kGrainTex = 128;
List<double>? _grainTileCache;
List<double> _ensureGrainTile() {
  final cached = _grainTileCache;
  if (cached != null) return cached;
  final tile = List<double>.filled(_kGrainTex * _kGrainTex, 0);
  var seed = 0x85EBCA6B; // 固定种子（与旧 LCG 同种子族，可复现）
  for (var i = 0; i < _kGrainTex * _kGrainTex; ++i) {
    seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF;
    final rnd = ((seed >> 8) & 0xFFFF) / 65535.0; // 0..1
    tile[i] = rnd * 2.0 - 1.0; // -1..1
  }
  _grainTileCache = tile;
  return tile;
}

int _wrapMod(int x) {
  return ((x % _kGrainTex) + _kGrainTex) % _kGrainTex;
}

/// 磨皮：边缘感知的皮肤平滑（仅 smoothStrength > 0 时调用）
/// 统一复用 [SkinSmoother.smooth]（与 image 包原生管线同源），
/// 平坦/皮肤区域平滑、强边缘（眼睛/发丝/衣物/背景）保留细节，避免整图变糊。
void applySmoothSkinImg(img.Image image, {required int smoothStrength}) {
  if (smoothStrength <= 0) return;
  final smoothed = SkinSmoother.smooth(image, smoothStrength);
  if (identical(smoothed, image)) return;

  // 将结果写回原图（原地修改，worker 复用像素缓冲）
  for (final p in image) {
    final sp = smoothed.getPixel(p.x, p.y);
    p
      ..r = sp.r
      ..g = sp.g
      ..b = sp.b;
  }
}

/// 拉腿：对图像下半部做平滑纵向拉伸，仅改变高度（宽度不变）。
///
/// 反向映射 + 垂直双线性插值，质量优先：
/// - [legStretch] 0-100，满档（100）时整图高度最大增幅 20%。
/// - 锚点位于源图 60% 高度处（约臀部/大腿根部），锚点上方完全不动；
/// - 拉伸区起点用 smoothstep 过渡带平滑衔接，避免锚点处出现硬折线。
img.Image applyLegStretchImg(img.Image src, {required int legStretch}) {
  if (legStretch <= 0) return src;
  final strength = (legStretch / 100.0).clamp(0.0, 1.0);
  final stretchFactor = strength * 0.20;
  if (stretchFactor < 0.001) return src;

  final w = src.width;
  final h = src.height;
  final outH = (h * (1 + stretchFactor)).round().clamp(h + 1, 3 * h);
  if (outH <= h) return src;

  // 锚点：源图 60% 高度处（约臀部/大腿根部），上方保持不动。
  final anchor = (h * 0.60).round();
  final srcRegion = h - anchor; // 拉伸区源高度
  final destRegion = outH - anchor; // 拉伸区目标高度
  // 过渡带（占拉伸区的比例）：smoothstep 平滑衔接，消除锚点处的硬折线。
  const featherT = 0.12;
  final hLast = (h - 1).toDouble();

  final out = img.Image(width: w, height: outH);
  // 注意：Image(width,height) 初始化全 0（alpha=0 全透明），
  // 必须用 setPixelRgba 显式写 alpha=255，否则输出整图透明不可见。
  for (var y = 0; y < outH; y++) {
    double srcY;
    if (y <= anchor) {
      srcY = y.toDouble();
    } else {
      final t = (y - anchor) / destRegion; // 0..1
      final srcYStretched = anchor + t * srcRegion;
      if (t < featherT) {
        // 过渡带内与「不拉伸」（srcY = y）平滑混合，避免锚点处硬折线
        final blend = _smoothstep(t / featherT);
        srcY = srcYStretched * blend + y * (1 - blend);
      } else {
        srcY = srcYStretched;
      }
    }
    srcY = srcY.clamp(0.0, hLast);
    final y0 = srcY.floor();
    final y1 = y0 < h - 1 ? y0 + 1 : y0;
    final fy = srcY - y0;
    for (var x = 0; x < w; x++) {
      final p0 = src.getPixel(x, y0);
      final p1 = src.getPixel(x, y1);
      out.setPixelRgba(
        x,
        y,
        _lerpByte(p0.r, p1.r, fy),
        _lerpByte(p0.g, p1.g, fy),
        _lerpByte(p0.b, p1.b, fy),
        255,
      );
    }
  }
  return out;
}

/// smoothstep 平滑插值（0→1，两端导数为 0）。
double _smoothstep(double t) {
  final x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

/// 垂直双线性插值：两整数通道值按 [f] 线性混合。
int _lerpByte(num a, num b, double f) => (a + (b - a) * f).round();

/// 拉腿（字节级快速实现）的输出：拉伸后的 RGBA 字节流 + 新高度。
/// 用普通类而非 Dart 3 records（项目 Dart 2.19.6 不支持 records 语法）。
class LegStretchBytes {
  const LegStretchBytes({required this.bytes, required this.height});
  final Uint8List bytes;
  final int height;
}

/// 拉腿（字节级快速实现）：对 RGBA 字节流做与 [applyLegStretchImg] 相同的
/// 平滑纵向拉伸（反向映射 + 垂直双线性插值 + smoothstep 过渡带）。
///
/// 用于拉腿实时预览的常驻 worker isolate。直接操作 [Uint8List] 并按行拷贝，
/// 避免 [img.Image] 逐像素 getPixel/setPixel 的对象分配开销，实测比
/// [applyLegStretchImg] 快 5-10 倍，使单次抓帧+拉伸能在定时间隔内完成，
/// 不再叠加 GPU 读回/上传导致拍摄页卡顿。
///
/// 输入 [src] 为 RGBA 字节流（length = width*height*4）；返回拉伸后的
/// 字节流（length = width*outHeight*4）与新的高度。
LegStretchBytes legStretchRgba(
  Uint8List src, {
  required int width,
  required int height,
  required int legStretch,
}) {
  if (legStretch <= 0) return LegStretchBytes(bytes: src, height: height);
  final strength = (legStretch / 100.0).clamp(0.0, 1.0);
  final stretchFactor = strength * 0.20;
  if (stretchFactor < 0.001) {
    return LegStretchBytes(bytes: src, height: height);
  }

  final w = width;
  final h = height;
  final outH = (h * (1 + stretchFactor)).round().clamp(h + 1, 3 * h);
  if (outH <= h) return LegStretchBytes(bytes: src, height: height);

  // 锚点：源图 60% 高度处（约臀部/大腿根部），上方保持不动。
  final anchor = (h * 0.60).round();
  final srcRegion = h - anchor; // 拉伸区源高度
  final destRegion = outH - anchor; // 拉伸区目标高度
  // 过渡带（占拉伸区的比例）：smoothstep 平滑衔接，消除锚点处的硬折线。
  const featherT = 0.12;
  final hLast = (h - 1).toDouble();

  final rowBytes = w * 4;
  final out = Uint8List(outH * rowBytes);

  for (var y = 0; y < outH; y++) {
    double srcY;
    if (y <= anchor) {
      srcY = y.toDouble();
    } else {
      final t = (y - anchor) / destRegion; // 0..1
      final srcYStretched = anchor + t * srcRegion;
      if (t < featherT) {
        // 过渡带内与「不拉伸」（srcY = y）平滑混合，避免锚点处硬折线
        final blend = _smoothstep(t / featherT);
        srcY = srcYStretched * blend + y * (1 - blend);
      } else {
        srcY = srcYStretched;
      }
    }
    srcY = srcY.clamp(0.0, hLast);
    final y0 = srcY.floor();
    final fy = srcY - y0;
    final dst = y * rowBytes;
    if (fy < 0.001) {
      // 整数行（锚点上方等）：整行拷贝，避免逐像素开销。
      out.setRange(dst, dst + rowBytes, src, y0 * rowBytes);
    } else {
      final y1 = y0 < h - 1 ? y0 + 1 : y0;
      final src0 = y0 * rowBytes;
      final src1 = y1 * rowBytes;
      final f0 = 1.0 - fy;
      for (var x = 0; x < rowBytes; x++) {
        out[dst + x] =
            (src[src0 + x] * f0 + src[src1 + x] * fy + 0.5).toInt();
      }
    }
  }
  return LegStretchBytes(bytes: out, height: outH);
}

/// 暗角：径向边缘压暗（仅 vignette > 0 时调用）。
///
/// 通用于 OHOS C++ `applyVignette` 与 iOS 预览内核的同一条公式，保证
/// 成片==预览==双端：
///   dn = length(dx,dy)/sqrt(2)，dx=(x+0.5-cx)/cx（-1..1，cx=宽/2）
///   factor = 1 − s·smoothstep(0.45, 1.0, dn)，s=vignette/100
/// 中心(dn≈0)不动、越靠边越暗、对角(dn≈1)最深。
void applyVignetteImg(img.Image image, {required int vignette}) {
  if (vignette <= 0) return;
  final double s = (vignette / 100.0).clamp(0.0, 1.0).toDouble();
  const e0 = 0.45, e1 = 1.0;             // 暗角起止区间（归一径向）
  final invMax = 1.0 / math.sqrt(2.0);   // 对角归一化
  final hw = image.width / 2.0, hh = image.height / 2.0;

  for (final p in image) {
    final dy = (p.y + 0.5 - hh) / hh;    // -1..1
    final dx = (p.x + 0.5 - hw) / hw;    // -1..1
    final dn = math.sqrt(dx * dx + dy * dy) * invMax; // 0..~1
    final t = ((dn - e0) / (e1 - e0)).clamp(0.0, 1.0).toDouble();
    final factor = 1.0 - s * (t * t * (3.0 - 2.0 * t)); // 1 - s·smoothstep
    p
      ..r = (p.r * factor).clamp(0, 255)
      ..g = (p.g * factor).clamp(0, 255)
      ..b = (p.b * factor).clamp(0, 255);
  }
}

/// 判断 4×5 ColorMatrix 是否为单位矩阵（Isolate 内独立副本）。
bool _isIdentityMatrixImg(List<double> m) {
  for (int i = 0; i < 4; i++) {
    for (int j = 0; j < 4; j++) {
      final idx = i * 5 + j;
      final expected = (i == j) ? 1.0 : 0.0;
      if ((m[idx] - expected).abs() > 0.001) return false;
    }
    if (m[i * 5 + 4].abs() > 0.001) return false;
  }
  return true;
}
