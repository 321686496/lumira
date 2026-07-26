import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/db/dao/templates_dao.dart';

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

  /// 调用系统分享面板分享模板文件。
  /// [usePptpl] 为 true 时使用 .pptpl 完整格式，否则使用 .lumira 简化格式。
  static Future<void> shareTemplate(TemplateRecord record, {required bool usePptpl}) async {
    final json = usePptpl ? exportToPptpl(record) : exportToLumira(record);
    final ext = usePptpl ? 'pptpl' : 'lumira';
    final safeName = _sanitizeFileName(record.name);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/lumira_template_$safeName.$ext');
    await file.writeAsString(json);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: '如画模板：${record.name}',
      text: '我分享了一个如画摄影模板「${record.name}」，用如画 App 导入即可使用。',
    );
  }

  /// 保存模板文件到指定目录。
  /// [usePptpl] 为 true 时使用 .pptpl 完整格式，否则使用 .lumira 简化格式。
  static Future<void> saveToFile(TemplateRecord record, {required bool usePptpl, required String dirPath}) async {
    final json = usePptpl ? exportToPptpl(record) : exportToLumira(record);
    final ext = usePptpl ? 'pptpl' : 'lumira';
    final safeName = _sanitizeFileName(record.name);
    final file = File('$dirPath/lumira_template_$safeName.$ext');
    await file.writeAsString(json);
  }

  /// 替换文件名中的非法字符（Windows 非法字符集合）。
  static String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }
}
