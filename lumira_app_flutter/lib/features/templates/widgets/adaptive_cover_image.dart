import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// 模板封面默认展示比例（加载中/未知比例兜底，≈ 3:4）。
const double kDefaultCoverRatio = 3 / 4;

/// 封面展示比例下限：9:16(0.5625) 等长屏钳到 0.65，高度温和削减约 13%。
const double kMinCoverRatio = 0.65;

/// 封面展示比例上限：超宽全景（>2:1）钳到 2.0，裁左右。
const double kMaxCoverRatio = 2.0;

/// 将图片真实宽高比钳制到 [kMinCoverRatio, kMaxCoverRatio]。
///
/// 区间内的比例完全展示；超出区间的（9:16 长屏 / 超宽全景）用 cover 裁切多余方向。
double clampCoverRatio(double realRatio) =>
    realRatio.clamp(kMinCoverRatio, kMaxCoverRatio);

/// 构造封面 ImageProvider（四种来源统一路由，与 LumiraImage 内部路由保持一致）：
/// 1. [coverData] 非空 → base64 → [MemoryImage]
/// 2. [cover] 以 `data:` 开头 → base64 → [MemoryImage]
/// 3. [cover] 以 `assets/` 开头 → [AssetImage]
/// 4. [cover] 以 `http(s)` 开头 → [NetworkImage]
/// 5. 其它 → 本地文件 [FileImage]
/// 无任何有效来源时返回 null。
ImageProvider? buildCoverProvider(String? cover, String? coverData) {
  final cd = coverData;
  if (cd != null && cd.isNotEmpty) {
    final bytes = _decodeBase64Bytes(cd);
    if (bytes != null) return MemoryImage(bytes);
  }
  final c = cover;
  if (c == null || c.isEmpty) return null;
  if (c.startsWith('data:')) {
    final bytes = _decodeBase64Bytes(c);
    if (bytes == null) return null;
    return MemoryImage(bytes);
  }
  if (c.startsWith('assets/')) return AssetImage(c);
  if (c.startsWith('http://') || c.startsWith('https://')) {
    return NetworkImage(c);
  }
  return FileImage(File(c));
}

Uint8List? _decodeBase64Bytes(String data) {
  try {
    final commaIdx = data.indexOf(',');
    final raw = (commaIdx >= 0 && data.startsWith('data:'))
        ? data.substring(commaIdx + 1)
        : data;
    return base64Decode(raw);
  } catch (_) {
    return null;
  }
}
