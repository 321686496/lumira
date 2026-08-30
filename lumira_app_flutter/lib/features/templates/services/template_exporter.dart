import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:share_plus/share_plus.dart';

import '../../../core/db/dao/templates_dao.dart';
import '../../../core/utils/safe_share.dart';
import '../../../core/utils/safe_temp_dir.dart';
import '../../../features/capture/domain/photo_template.dart';
import 'template_image_store.dart';

/// Asset 加载函数类型（便于测试注入）
typedef AssetLoader = Future<Uint8List> Function(String assetPath);

/// 模板导出器：双格式导出（.pptpl 完整格式 / .lumira 简化格式）。
///
/// - `.pptpl`：包含 meta/composition/pose/camera/sceneGuide/postProcess 全部 6 个区段，
///   适用于完整模板分享与跨设备迁移。
/// - `.lumira`：仅包含 meta + camera（曝光/ISO/快门）+ composition.overlayType，
///   作为简化快照用于社交分享或预览。
class TemplateExporter {
  TemplateExporter._();

  /// 导出为完整 .pptpl JSON 字符串。
  static String exportToPptpl(TemplateRecord record) {
    final data = <String, dynamic>{
      'format': 'pptpl',
      'version': '1.0',
      'meta': {
        'id': record.id,
        'name': record.name,
        'author': record.author,
        'version': record.version,
        'category': record.category,
        'classification': Map<String, dynamic>.from(record.classification),
        'tags': List<String>.from(record.tags),
        'tagIds': List<String>.from(record.tagIds),
        'price': record.price,
        'cover': record.cover,
        if (record.coverData != null) 'coverData': record.coverData,
        'description': record.description,
        'referenceSource': record.referenceSource,
        'isBuiltin': record.isBuiltin,
        'isRecommended': record.isRecommended,
        'createdAt': record.createdAt,
        'updatedAt': record.updatedAt,
      },
      'composition': Map<String, dynamic>.from(record.composition),
      'pose': record.pose,
      'camera': Map<String, dynamic>.from(record.camera),
      'sceneGuide': Map<String, dynamic>.from(record.sceneGuide),
      'postProcess': Map<String, dynamic>.from(record.postProcess),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// 导出为简化 .lumira JSON 字符串。
  /// 仅保留 meta（id/name/category/tags）+ camera（曝光/ISO/快门）+ composition（overlayType）。
  static String exportToLumira(TemplateRecord record) {
    final data = <String, dynamic>{
      'format': 'lumira',
      'version': '1.0',
      'meta': {
        'id': record.id,
        'name': record.name,
        'category': record.category,
        'tags': List<String>.from(record.tags),
      },
      'camera': {
        'exposureCompensation': record.camera['exposureCompensation'],
        'iso': record.camera['iso'],
        'shutterSpeed': record.camera['shutterSpeed'],
      },
      'composition': {
        'overlayType': record.composition['overlayType'],
      },
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// 嵌入封面图数据到 record.coverData（base64 data URL）。
  ///
  /// 策略：
  /// - cover 以 `data:` 开头 → 直接复制
  /// - cover 以 `assets/` 开头 → 通过 rootBundle 加载字节，base64 编码
  /// - cover 以 `http` 开头 → 离线 App 无法 fetch，跳过
  /// - cover 为空 → 跳过
  /// - 编码后超过 500KB → 跳过（避免膨胀 .pptpl）
  static Future<TemplateRecord> embedCoverData(
    TemplateRecord record, {
    AssetLoader? assetLoader,
  }) async {
    final cover = record.cover;
    if (cover.isEmpty) return record;

    // 已是 data URL → 直接复制
    if (cover.startsWith('data:')) {
      return record.copyWith(coverData: cover);
    }

    // HTTP URL → 离线 App 无法 fetch
    if (cover.startsWith('http://') || cover.startsWith('https://')) {
      return record;
    }

    // Asset 路径 → 加载字节
    if (cover.startsWith('assets/')) {
      try {
        final loader = assetLoader ?? _defaultAssetLoader;
        final bytes = await loader(cover);
        // 大小守卫：500KB
        if (bytes.lengthInBytes > 500 * 1024) {
          // ignore: avoid_print
          print('Warning: cover asset "$cover" exceeds 500KB, skipping embed');
          return record;
        }
        final mime = _mimeFromPath(cover);
        final base64Str = base64Encode(bytes);
        return record.copyWith(coverData: 'data:$mime;base64,$base64Str');
      } catch (e) {
        // ignore: avoid_print
        print('Warning: failed to load cover asset "$cover": $e');
        return record;
      }
    }

    // 本地路径 → 读文件字节 → base64 data URL（含 500KB 大小守卫，超限跳过）
    if (TemplateImageStore.isLocalImageRef(cover)) {
      final bytes = await TemplateImageStore.readBytes(cover);
      if (bytes == null) return record; // 文件缺失，保持原值
      if (bytes.lengthInBytes > 500 * 1024) {
        // ignore: avoid_print
        print('Warning: cover local file "$cover" exceeds 500KB, skipping embed');
        return record;
      }
      final mime = _mimeFromPath(cover);
      final base64Str = base64Encode(bytes);
      return record.copyWith(coverData: 'data:$mime;base64,$base64Str');
    }

    return record;
  }

  /// 默认 asset 加载器（使用 rootBundle）
  static Future<Uint8List> _defaultAssetLoader(String path) async {
    final byteData = await rootBundle.load(path);
    return byteData.buffer.asUint8List();
  }

  /// 根据文件扩展名推断 MIME 类型
  static String _mimeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg'; // 默认
  }

  /// 解析封面显示 URL：coverData 优先，否则 cover
  static String resolveCoverUrl(TemplateRecord record) {
    return record.coverData ?? record.cover;
  }

  /// 将 record 内的本地图片路径解析为 base64 data URL（导出/分享前调用）。
  ///
  /// 覆盖：`coverData` / `cover` / `images[].data` / pose 剪影（`type == 'image'`
  /// 且 data 为本地路径）。非本地引用（data URL / http / 内置 key / assets）
  /// 原样保留；文件缺失时保持原引用。返回新 record（copyWith），不修改入参。
  static Future<TemplateRecord> resolveLocalImages(
    TemplateRecord record,
  ) async {
    var coverData = record.coverData;
    if (coverData != null && TemplateImageStore.isLocalImageRef(coverData)) {
      coverData = await TemplateImageStore.toDataUrl(coverData);
    }

    // custom 模板 cover == coverData，双保险
    var cover = record.cover;
    if (cover.isNotEmpty && TemplateImageStore.isLocalImageRef(cover)) {
      cover = await TemplateImageStore.toDataUrl(cover);
    }

    List<TemplateImage>? images;
    if (record.images != null) {
      images = <TemplateImage>[];
      for (final img in record.images!) {
        var data = img.data;
        if (data != null && TemplateImageStore.isLocalImageRef(data)) {
          data = await TemplateImageStore.toDataUrl(data);
        }
        images.add(data == img.data ? img : img.copyWith(data: data));
      }
    }

    dynamic pose = record.pose;
    if (pose is Map) {
      pose = await _resolvePoseSilhouette(Map<String, dynamic>.from(pose));
    } else if (pose is List) {
      final resolved = <dynamic>[];
      for (final item in pose) {
        if (item is Map) {
          resolved.add(
              await _resolvePoseSilhouette(Map<String, dynamic>.from(item)));
        } else {
          resolved.add(item);
        }
      }
      pose = resolved;
    }

    return record.copyWith(
      cover: cover,
      coverData: coverData,
      images: images,
      pose: pose,
    );
  }

  /// 解析单个 pose Map 的 image 剪影：`type == 'image'` 且 data 为本地路径时
  /// 替换为 data URL。copyWith 无法改嵌套 map，需重建 Map。
  static Future<Map<String, dynamic>> _resolvePoseSilhouette(
    Map<String, dynamic> pose,
  ) async {
    final silhouette = pose['silhouette'];
    if (silhouette is! Map) return pose;
    if (silhouette['type'] != 'image') return pose;
    final data = silhouette['data'];
    if (data is! String || !TemplateImageStore.isLocalImageRef(data)) {
      return pose;
    }
    final resolved = await TemplateImageStore.toDataUrl(data);
    final newSilhouette = Map<String, dynamic>.from(silhouette)
      ..['data'] = resolved;
    return Map<String, dynamic>.from(pose)..['silhouette'] = newSilhouette;
  }

  /// 导出模板到临时文件并返回文件路径。
  /// [usePptpl] 为 true 时使用 .pptpl 完整格式，否则使用 .lumira 简化格式。
  static Future<String> exportToTempFile(TemplateRecord record, {required bool usePptpl}) async {
    final resolved = await resolveLocalImages(record);
    final recordWithCover = usePptpl ? await embedCoverData(resolved) : resolved;
    final json = usePptpl ? exportToPptpl(recordWithCover) : exportToLumira(recordWithCover);
    final fileName = buildFileName(record, usePptpl: usePptpl);
    final tempDir = await getSafeTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(json);
    return file.path;
  }

  /// 调用系统分享面板分享模板文件。
  /// [usePptpl] 为 true 时使用 .pptpl 完整格式，否则使用 .lumira 简化格式。
  static Future<void> shareTemplate(TemplateRecord record, {required bool usePptpl}) async {
    final filePath = await exportToTempFile(record, usePptpl: usePptpl);
    await SafeShare.shareXFiles(
      [XFile(filePath)],
      subject: '如画模板：${record.name}',
      text: '我分享了一个如画摄影模板「${record.name}」，用如画 App 导入即可使用。',
    );
  }

  /// 保存模板文件到指定目录。
  /// [usePptpl] 为 true 时使用 .pptpl 完整格式，否则使用 .lumira 简化格式。
  static Future<void> saveToFile(TemplateRecord record, {required bool usePptpl, required String dirPath}) async {
    final resolved = await resolveLocalImages(record);
    final json = usePptpl ? exportToPptpl(resolved) : exportToLumira(resolved);
    final fileName = buildFileName(record, usePptpl: usePptpl);
    final file = File('$dirPath/$fileName');
    await file.writeAsString(json);
  }

  /// 替换文件名中的非法字符（Windows 非法字符集合）。
  static String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  /// 构建唯一文件名：`{sanitized_name}_{template_id}.{ext}`
  ///
  /// 模板 ID 在 DAO 中唯一，保证文件名不冲突。
  /// 名称截断至 30 字符，移除文件系统非法字符。
  static String buildFileName(TemplateRecord record, {required bool usePptpl}) {
    final ext = usePptpl ? 'pptpl' : 'lumira';
    final safeName = _sanitizeFileName(record.name);
    final trimmed = safeName.length > 30 ? safeName.substring(0, 30) : safeName;
    return '${trimmed}_${record.id}.$ext';
  }
}
