import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'skin_smooth_preview.dart';

/// 磨皮实时预览的解码/承载层：把来源（本地文件 / base64 data URL）解码为 GPU-backed
/// [ui.Image]，就绪后交给 [SkinSmoothPreview] 做 shader 渲染；未就绪/解码失败一律
/// 回退到 [fallback]（原图片路径，如 [LumiraImage] / Image.file / CachedNetworkImage），
/// 不白屏不阻塞编辑页。
///
/// 零 GPU 读回：这里只对**源字节**解码（[ui.instantiateImageCodec]），不做「渲染后再
/// toImage 回灌」；滑块拖动仅改 [strength]，复用已解码的 [_SmoothImageLayerState._image]
/// 不重复解码。
///
/// 宽高比正确性：shader 画布是「全尺寸铺满 + uv 按画布 size 映射」会拉伸，
/// 这里用 [AspectRatio] 把渲染尺寸锁定为解码图宽高比并居中，观感等价 [BoxFit.contain]。
class SmoothImageLayer extends StatefulWidget {
  const SmoothImageLayer({
    super.key,
    required this.url,
    required this.strength,
    required this.fallback,
    this.maxEdge = 2048,
  });

  final String url;
  final double strength;

  /// 解码未就绪/失败时回退到的基础图片 widget（即原未套 shader 的路径）。
  final Widget Function() fallback;

  /// 解码最长边封顶，减少内存与耗时（源字节解码，非 GPU 读回）。
  final int maxEdge;

  @override
  State<SmoothImageLayer> createState() => _SmoothImageLayerState();
}

class _SmoothImageLayerState extends State<SmoothImageLayer> {
  ui.Image? _image;
  String? _decodingUrl;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(SmoothImageLayer old) {
    super.didUpdateWidget(old);
    // 仅来源变化才重新解码；strength 变化复用已解码 _image，
    // build 会自动以新 strength 触发 shader 重绘（不每帧解码）。
    if (old.url != widget.url) {
      _image = null;
      _decode();
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    final targetUrl = widget.url;
    _decodingUrl = targetUrl;
    final next = await _decodeToUiImage(targetUrl);
    // 已卸载，或被更新的 url 解码取代 → 丢弃结果，避免竞态覆盖。
    if (!mounted || _decodingUrl != targetUrl) return;
    setState(() => _image = next);
  }

  /// 从来源字节解码出 GPU-backed [ui.Image]（data:/本地文件）。
  /// 失败或来源类型不受支持时返回 null（由 [build] 走 [fallback] 降级）。
  Future<ui.Image?> _decodeToUiImage(String url) async {
    if (url.isEmpty) return null;
    final maxEdge = widget.maxEdge;
    Uint8List bytes;
    try {
      if (url.startsWith('data:')) {
        final comma = url.indexOf(',');
        bytes = base64Decode(comma >= 0 ? url.substring(comma + 1) : url);
      } else if (url.startsWith('assets/') ||
          url.startsWith('http://') ||
          url.startsWith('https://')) {
        // 来源仅支持 data:/本地文件；其它类型不进入 shader 层（走 fallback）。
        return null;
      } else {
        bytes = File(url).readAsBytesSync();
      }
    } catch (_) {
      return null;
    }

    late ui.Codec codec;
    try {
      codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final longest = math.max(img.width, img.height);
      if (longest <= maxEdge) {
        codec.dispose();
        return img;
      }
      // 最长边超限：按比例缩到封顶边长再重解码（仍是源字节解码，非 GPU 读回）。
      final scale = maxEdge / longest;
      codec.dispose();
      codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: (img.width * scale).round(),
        targetHeight: (img.height * scale).round(),
      );
      final frame2 = await codec.getNextFrame();
      final resized = frame2.image;
      codec.dispose();
      img.dispose();
      return resized;
    } catch (_) {
      try {
        codec.dispose();
      } catch (_) {}
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    if (img == null) {
      return widget.fallback(); // 未就绪 / 解码失败 → 原图片路径
    }
    return Center(
      child: AspectRatio(
        aspectRatio: img.width / img.height,
        child: SkinSmoothPreview(image: img, strength: widget.strength),
      ),
    );
  }
}