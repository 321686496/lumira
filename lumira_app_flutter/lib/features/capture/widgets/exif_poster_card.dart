import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../shared/widgets/poster/poster_common.dart';
import '../services/exif_info.dart';

/// 读取图片宽高比（宽/高）。
///
/// 只需比例，用 `targetHeight: 120` 的小尺寸快速解码，避免整图解码耗时；
/// 失败回退 3:4（拍摄最常用的竖图比例）。
Future<double> probePhotoAspect(String path) async {
  try {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes, targetHeight: 120);
    final frame = await codec.getNextFrame();
    final aspect = frame.image.width / frame.image.height;
    frame.image.dispose();
    codec.dispose();
    return aspect;
  } catch (_) {
    return 3 / 4;
  }
}

/// EXIF 海报（品牌纸感卡）。
///
/// 暖白纸底 + 金色发丝线 + 衬线字体的 LUMIRA 分享海报品牌体系，与相册/模板/
/// 探店海报同一套视觉语言。照片按原图宽高比全宽铺排（无黑边；高度钳制在
/// 0.5~2.0 倍画布宽，越界居中裁切）；参数分层展示并逐项降级：
/// 曝光四要素 → 相机型号 → 时间/位置 → 分辨率/大小 → 场景/模板，缺项自动跳过。
///
/// App 内拍摄的照片经重编码后不含相机 EXIF（仅导入照片有完整参数），
/// 因此版式必须容忍大部分字段缺省：全部缺省时仅呈现照片 + 品牌信息。
class ExifPosterCard extends StatelessWidget {
  const ExifPosterCard({
    super.key,
    required this.photoPath,
    required this.aspect,
    required this.exif,
  });

  /// 本地照片文件路径。
  final String photoPath;

  /// 照片宽高比（宽/高）。
  final double aspect;

  final ExifInfo exif;

  @override
  Widget build(BuildContext context) {
    const width = 300.0;
    final safeAspect = (aspect.isFinite && aspect > 0) ? aspect : 3 / 4;
    final photoHeight = (width / safeAspect)
        .clamp(width * 0.5, width * 2.0);

    return PosterCanvas(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const PosterDivider(),
          SizedBox(
            height: photoHeight,
            child: Image.file(
              File(photoPath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: PosterPalette.surfaceAlt,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.image_outlined,
                  size: 40,
                  color: PosterPalette.text3,
                ),
              ),
            ),
          ),
          const PosterDivider(),
          _buildInfo(),
          _buildFooter(),
        ],
      ),
    );
  }

  /// 顶部品牌行 + 右侧金色 EXIF 标识。
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          const PosterBrandRow(logoSize: 14),
          const Spacer(),
          Text(
            'EXIF',
            style: posterSerifEn(
              11,
              color: PosterPalette.goldDeep,
              letterSpacing: 4,
            ),
          ),
        ],
      ),
    );
  }

  /// 照片下方的参数信息区。
  Widget _buildInfo() {
    final camera = exif.cameraModel?.trim() ?? '';
    final hero = _buildHero();
    final metaLine1 = _buildMetaLine1();
    final metaLine2 = _buildMetaLine2();
    final creative = _buildCreativeLine();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hero != null) ...[
            hero,
            const SizedBox(height: 4),
          ],
          if (camera.isNotEmpty)
            Text(
              camera,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: posterSerifEn(
                10.5,
                color: PosterPalette.text2,
                letterSpacing: 2,
              ),
            ),
          if (metaLine1 != null) ...[
            const SizedBox(height: 6),
            Text(
              metaLine1,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: posterPlain(10, color: PosterPalette.text3, letterSpacing: 1),
            ),
          ],
          if (metaLine2 != null) ...[
            const SizedBox(height: 4),
            Text(
              metaLine2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: posterPlain(10, color: PosterPalette.text3, letterSpacing: 1),
            ),
          ],
          if (creative != null) ...[
            const SizedBox(height: 10),
            PosterKicker(text: creative, size: 9, letterSpacing: 2),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 首行大字：曝光四要素（`35mm · ƒ/1.8 · 1/250s · ISO 200`）；
  /// 无相机参数时回退为分辨率（`4096 × 3072`）；两者皆无则不展示。
  Widget? _buildHero() {
    final exposure = [
      exif.focalLength,
      exif.fNumber,
      exif.shutterSpeed,
      exif.iso,
    ]
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (exposure.isNotEmpty) {
      return _goldDotLine(
        exposure,
        posterSerif(16, weight: FontWeight.w600, letterSpacing: 0.5),
      );
    }
    final resolution = _formattedResolution();
    if (resolution == null) return null;
    return _goldDotLine(
      [resolution],
      posterSerif(16, weight: FontWeight.w600, letterSpacing: 0.5),
    );
  }

  /// 时间 · 位置；两者皆无则不展示。
  String? _buildMetaLine1() {
    final segs = <String?>[
      _formatTimestamp(exif.timestamp),
      exif.location?.trim(),
    ].whereType<String>().where((s) => s.isNotEmpty).toList();
    return segs.isEmpty ? null : segs.join('  ·  ');
  }

  /// 分辨率 · 文件大小。四要素齐全（首行已是参数）时才补分辨率；
  /// 首行回退为分辨率时只补文件大小，避免重复。
  String? _buildMetaLine2() {
    final hasExposure = [
      exif.focalLength,
      exif.fNumber,
      exif.shutterSpeed,
      exif.iso,
    ].any((s) => s != null && s.trim().isNotEmpty);

    final segs = <String?>[
      if (hasExposure) _formattedResolution(),
      exif.fileSize?.trim(),
    ].whereType<String>().where((s) => s.isNotEmpty).toList();
    return segs.isEmpty ? null : segs.join('  ·  ');
  }

  /// 场景/模板创作信息：`场景「咖啡馆」 · 模板「胶片人像」`；皆无则不展示。
  String? _buildCreativeLine() {
    final segs = <String>[];
    final scene = exif.sceneName?.trim() ?? '';
    if (scene.isNotEmpty) segs.add('场景「$scene」');
    final template = exif.template?.trim() ?? '';
    if (template.isNotEmpty) segs.add('模板「$template」');
    return segs.isEmpty ? null : segs.join('  ·  ');
  }

  /// 底部品牌脚（复用品牌组件：LUMIRA · 如画 + 标语）。
  Widget _buildFooter() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: PosterBrandFoot(logoSize: 13),
    );
  }

  /// 用金色「 · 」分隔点拼接多段文字（与 PosterCatText 的分隔语言一致）。
  Widget _goldDotLine(List<String> segments, TextStyle style) {
    final spans = <TextSpan>[];
    for (var i = 0; i < segments.length; i++) {
      if (i > 0) {
        spans.add(TextSpan(
          text: '  ·  ',
          style: style.copyWith(color: PosterPalette.gold),
        ));
      }
      spans.add(TextSpan(text: segments[i]));
    }
    return Text.rich(
      TextSpan(children: spans, style: style),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// 分辨率 `4096x3072` → `4096 × 3072`。
  String? _formattedResolution() {
    final r = exif.resolution?.trim() ?? '';
    if (r.isEmpty) return null;
    return r.replaceFirst(RegExp(r'[xX]'), ' × ');
  }

  /// 时间归一化：EXIF ASCII（`2026:09:16 14:32:05`）与 DateTime.toString()
  /// （`2026-09-16 14:32:05.123`）统一为 `2026.09.16 14:32`；解析失败原样返回。
  String? _formatTimestamp(String? raw) {
    final t = raw?.trim() ?? '';
    if (t.isEmpty) return null;
    final m = RegExp(r'^(\d{4})\D(\d{1,2})\D(\d{1,2})\D+(\d{1,2}):(\d{2})')
        .firstMatch(t);
    if (m == null) return t;
    String pad(int g) => m.group(g)!.padLeft(2, '0');
    return '${m.group(1)}.${pad(2)}.${pad(3)} ${pad(4)}:${m.group(5)}';
  }
}
