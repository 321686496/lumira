import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

/// 从图片字节流解码二维码文本，未识别到返回 null。
///
/// 采用「先限幅 → 快速直解 → 阈值二值化 → 2x 兜底 → 原图兜底」策略，对齐
/// 微信等主流扫码工具的识别能力与速度：
/// - 预处理：先限幅到最长边 2048 的「工作图」——手机照片普遍 12MP，
///   在原尺寸上做逐像素 RGBA 转换 / 二值化 / 解码是此前「识别要等好几秒」
///   的根因；二维码识别不依赖全分辨率，限幅后所有常规策略都快一个量级
/// - 快速路径：工作图直解（清晰图一次命中，几十 ms 级）
/// - 增强路径 A：Rec.601 亮度 + Otsu 自适应阈值二值化——救回大图 /
///   光照不均 / 压缩失真的二维码（多阈值循环在工作图上跑，开销可控）
/// - 增强路径 B：linear 2x 放大 + TRY_HARDER（Hybrid 二值化）——救回
///   小模块 / 边缘略糊的二维码
/// - 原图兜底：仅当原图大于工作图且以上全部失败时，才在原图（限幅内）
///   上做一次阈值尝试，覆盖「二维码在超大海报中占比极小、限幅后模块
///   过小」的极端场景（只在失败场景付出代价，不拖慢常规路径）
///
/// 本函数为纯 Dart 顶层函数，可直接作为 `compute`（后台 isolate）的入口，
/// 避免在 UI 线程上执行解码导致界面卡顿。
String? decodeQrFromBytes(List<int> bytes) {
  final image = img.decodeImage(Uint8List.fromList(bytes));
  if (image == null) return null;

  // 预处理：限幅出工作图，所有常规策略在工作图上执行
  final work = _boundedSource(image);
  final downscaled = !identical(work, image);

  // 快速路径：清晰图一次命中，零额外开销
  final fast = _decodeOnce(work);
  if (fast != null) return fast;

  // 增强路径 A：阈值二值化（线性开销，识别率高于盲放大）
  final threshold = _decodeThreshold(work);
  if (threshold != null) return threshold;

  // 增强路径 B：linear 2x 兜底（基于工作图，限幅后不会内存爆炸）
  final scaled = _decodeOnce(work, scale: 2, tryHarder: true);
  if (scaled != null) return scaled;

  // 原图兜底：限幅可能伤害「大图中的极小二维码」，仅在以上全部失败时
  // 用原图做一次阈值尝试（原图通常 12MP 级，这一步本身可达秒级，
  // 所以放在最后，成功即返回、失败也只付出一次代价）。
  if (downscaled) {
    final original = _decodeThreshold(image);
    if (original != null) return original;
  }
  return null;
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
