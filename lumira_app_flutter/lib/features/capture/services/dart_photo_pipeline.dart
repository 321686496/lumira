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

  // 4. 降采样到长边 ≤ 1536
  const maxDimension = 1536;
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
void applyPerPixelEffectsImg(
  img.Image image, {
  required int sharpen,
  required double? clarity,
  required int grain,
}) {
  // Sharpen（卷积核）
  if (sharpen > 0) {
    final a = (sharpen / 100.0).clamp(0.0, 1.0);
    img.convolution(
      image,
      filter: [0, -a, 0, -a, 1 + 4 * a, -a, 0, -a, 0],
      div: 1.0,
      amount: 1.0,
    );
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

  // Grain（胶片颗粒噪声）
  if (grain > 0) {
    final intensity = (grain / 100.0).clamp(0.0, 1.0) * 0.25;
    const maxOffset = 64.0;
    final random = math.Random(42);
    for (final p in image) {
      final noise = (random.nextDouble() * 2 - 1) * intensity * maxOffset;
      p
        ..r = (p.r + noise).clamp(0, 255)
        ..g = (p.g + noise).clamp(0, 255)
        ..b = (p.b + noise).clamp(0, 255);
    }
  }
}

/// 磨皮：降采样模糊 + 原图混合（仅 smoothStrength > 0 时调用）
/// 通过降采样到 1/4 尺寸后高斯模糊，再与原图按比例混合，实现快速磨皮。
void applySmoothSkinImg(img.Image image, {required int smoothStrength}) {
  if (smoothStrength <= 0) return;
  final mix = (smoothStrength / 100.0).clamp(0.0, 0.8);

  // 降采样到 1/4 尺寸
  final smallW = (image.width / 4).clamp(1, image.width).toInt();
  final smallH = (image.height / 4).clamp(1, image.height).toInt();
  final small = img.copyResize(image, width: smallW, height: smallH);

  // 高斯模糊（radius 根据 smoothStrength 映射 2-6）
  final radius = 2 + (smoothStrength / 100 * 4).round();
  final blurred = img.gaussianBlur(small, radius: radius);

  // 放大回原尺寸
  final upscaled = img.copyResize(blurred, width: image.width, height: image.height);

  // 与原图混合
  for (final p in image) {
    final bp = upscaled.getPixel(p.x, p.y);
    p
      ..r = (p.r * (1 - mix) + bp.r * mix).clamp(0, 255)
      ..g = (p.g * (1 - mix) + bp.g * mix).clamp(0, 255)
      ..b = (p.b * (1 - mix) + bp.b * mix).clamp(0, 255);
  }
}

/// 暗角：径向渐变暗化四角（仅 vignette > 0 时调用）
void applyVignetteImg(img.Image image, {required int vignette}) {
  if (vignette <= 0) return;
  final strength = (vignette / 100.0).clamp(0.0, 1.0) * 0.6;
  final centerX = image.width / 2;
  final centerY = image.height / 2;
  // 对角线距离的平方
  final maxDistSq = centerX * centerX + centerY * centerY;

  for (final p in image) {
    final dx = p.x - centerX;
    final dy = p.y - centerY;
    final distSq = dx * dx + dy * dy;
    // 距离比例 0-1（中心=0，四角=1）
    final ratio = distSq / maxDistSq;
    // 仅在 ratio > 0.3 时开始暗化（中心 30% 区域不受影响）
    if (ratio > 0.3) {
      final darken = ((ratio - 0.3) / 0.7) * strength;
      p
        ..r = (p.r * (1 - darken)).clamp(0, 255)
        ..g = (p.g * (1 - darken)).clamp(0, 255)
        ..b = (p.b * (1 - darken)).clamp(0, 255);
    }
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
