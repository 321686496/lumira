import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:share_plus/share_plus.dart';

import '../../../core/db/dao/templates_dao.dart';
import '../../../core/utils/safe_share.dart';
import '../../../core/utils/safe_temp_dir.dart';

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
      'pose': Map<String, dynamic>.from(record.pose),
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

  /// 导出模板到临时文件并返回文件路径。
  /// [usePptpl] 为 true 时使用 .pptpl 完整格式，否则使用 .lumira 简化格式。
  static Future<String> exportToTempFile(TemplateRecord record, {required bool usePptpl}) async {
    final recordWithCover = usePptpl ? await embedCoverData(record) : record;
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
    final json = usePptpl ? exportToPptpl(record) : exportToLumira(record);
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
