import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

/// 从图片字节流解码二维码文本，未识别到返回 null。
///
/// 采用「快速路径 → 阈值二值化 → linear 2x 兜底」多策略解码，对齐微信等
/// 主流扫码工具的识别能力与速度：
/// - 快速路径：原图直解（清晰图一次命中，约 40ms 级）
/// - 增强路径 A：Rec.601 亮度 + Otsu 自适应阈值二值化（约 200ms 级）——
///   救回大图 / 光照不均 / 压缩失真的二维码，无需放大，避免整图 2x 的
///   数秒级耗时（旧实现 cubic 2x 在 1080w 海报上实测 ~4-25s，是本问题
///   「等五六秒」的根因）
/// - 增强路径 B：linear 2x 放大 + TRY_HARDER（Hybrid 二值化）——兜底救回
///   小模块 / 边缘略糊的二维码；基于限幅后的工作图，避免内存爆炸
///
/// 本函数为纯 Dart 顶层函数，可直接作为 `compute`（后台 isolate）的入口，
/// 避免在 UI 线程上执行解码导致界面卡顿。
String? decodeQrFromBytes(List<int> bytes) {
  final image = img.decodeImage(Uint8List.fromList(bytes));
  if (image == null) return null;

  // 快速路径：清晰图一次命中，零开销
  final fast = _decodeOnce(image);
  if (fast != null) return fast;

  // 增强路径 A：阈值二值化（线性开销，远快于 2x 放大，识别率更高）
  final threshold = _decodeThreshold(image);
  if (threshold != null) return threshold;

  // 增强路径 B：linear 2x 兜底（基于限幅后的工作图）
  final work = _boundedSource(image);
  return _decodeOnce(work, scale: 2, tryHarder: true);
}

/// 将超大图等比缩到增强路径可接受的尺寸（最长边 ≤ 2048），避免 2x 放大内存爆炸。
img.Image _boundedSource(img.Image image) {
  const maxSide = 2048;
  final longest = image.width > image.height ? image.width : image.height;
  if (longest <= maxSide) return image;
  final ratio = maxSide / longest;
  return img.copyResize(
    image,
    width: (image.width * ratio).round(),
    height: (image.height * ratio).round(),
    interpolation: img.Interpolation.linear,
  );
}

/// 单次解码尝试；失败（无码 / 解码失败）返回 null。
String? _decodeOnce(
  img.Image image, {
  int scale = 1,
  bool tryHarder = false,
}) {
  try {
    var work = image;
    if (scale > 1) {
      work = img.copyResize(
        image,
        width: image.width * scale,
        height: image.height * scale,
        interpolation: img.Interpolation.linear,
      );
    }
    final pixels = work.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
    final source =
        RGBLuminanceSource(work.width, work.height, pixels.buffer.asInt32List());
    final bitmap = BinaryBitmap(HybridBinarizer(source));
    final hints =
        tryHarder ? (DecodeHints()..put(DecodeHintType.tryHarder)) : null;
    final result = QRCodeReader().decode(bitmap, hints: hints);
    final text = result.text;
    return text.isNotEmpty ? text : null;
  } catch (_) {
    // 图片中无二维码，或解码失败
    return null;
  }
}

/// 增强路径 A：Rec.601 亮度 → Otsu 自适应阈值 → 多阈值迭代二值化解码。
///
/// 相比「整图 2x 放大」，这里只做线性扫描 + 阈值尝试，耗时约 200ms 级，
/// 且对边缘略糊 / 光照不均 / 压缩失真的二维码识别率更高。
String? _decodeThreshold(img.Image image) {
  try {
    final n = image.width * image.height;
    final rgba = image.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
    final src = rgba.buffer.asInt32List();
    final lum = Int32List(n);
    final hist = List<int>.filled(256, 0);
    for (var i = 0; i < n; i++) {
      final p = src[i];
      final r = p & 0xff;
      final g = (p >> 8) & 0xff;
      final b = (p >> 16) & 0xff;
      // Rec.601 亮度公式（与 image 包 grayscale 一致）
      final l = (0.299 * r + 0.587 * g + 0.114 * b).round();
      lum[i] = l;
      hist[l]++;
    }
    final otsu = _otsuFromHist(hist, n);
    final ths = [otsu, 128, otsu + 24, 96, 160]; // 多阈值尝试
    for (final th in ths) {
      if (th < 0 || th > 255) continue;
      try {
        final bin = Int32List(n);
        for (var i = 0; i < n; i++) {
          bin[i] = lum[i] > th ? 0xFFFFFFFF : 0xFF000000;
        }
        final source = RGBLuminanceSource(image.width, image.height, bin);
        final result = QRCodeReader().decode(BinaryBitmap(HybridBinarizer(source)));
        final text = result.text;
        if (text.isNotEmpty) return text;
      } catch (_) {
        // 该阈值下解码失败，尝试下一个阈值
      }
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// Otsu 大津法：从灰度直方图自适应选取「类间方差最大」的分割阈值。
int _otsuFromHist(List<int> hist, int total) {
  var sum = 0;
  for (var i = 0; i < 256; i++) {
    sum += i * hist[i];
  }
  var sumB = 0, wB = 0;
  var maxVariance = -1.0;
  var threshold = 128;
  for (var t = 0; t < 256; t++) {
    wB += hist[t];
    if (wB == 0) continue;
    final wF = total - wB;
    if (wF == 0) break;
    sumB += t * hist[t];
    final mB = sumB / wB;
    final mF = (sum - sumB) / wF;
    final variance = wB * wF * (mB - mF) * (mB - mF);
    if (variance > maxVariance) {
      maxVariance = variance;
      threshold = t;
    }
  }
  return threshold;
}
