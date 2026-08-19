import '../../../core/db/dao/templates_dao.dart';
import 'pptpl_format.dart';
import 'template_mapper.dart';

/// 模板导入结果（无 UI 依赖，由调用方负责 toast / 弹窗）
class TemplateImportResult {
  final bool ok;
  final String? id; // 导入成功的模板 id（ok=true 时）
  final String? error; // 失败原因（ok=false 时）
  final String message; // 成功提示文本（ok=true 时）
  final List<TemplateImportWarning> warnings;

  const TemplateImportResult({
    required this.ok,
    this.id,
    this.error,
    this.message = '',
    this.warnings = const [],
  });
}

/// 模板导入服务：把已解析的模板 JSON 持久化到本地 DAO。
/// 供「从链接导入」「从文件导入」及「深链自动导入」复用，逻辑单一来源。
class TemplateImportService {
  TemplateImportService._();

  /// 导入完整模板 JSON（format/meta 形式）。
  ///
  /// [invalidateTemplates]：导入成功后刷新 Capture 页模板缓存
  /// （如 CaptureState.allTemplatesProvider），使新模板立即出现在拍摄页。
  static Future<TemplateImportResult> importJson(
    Map<String, dynamic> json, {
    required TemplatesDao dao,
    required Future<void> Function() invalidateTemplates,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final warnings = PptplFormat.validate(json);
      var record = TemplateMapper.recordFromImportedJson(json, createdAt: now);

      // ID 冲突处理：已存在则追加 _imported_ 时间戳后缀
      var finalId = record.id;
      while (await dao.getById(finalId) != null) {
        finalId = '${finalId}_imported_$now';
      }
      if (finalId != record.id) {
        record = record.copyWith(id: finalId);
      }

      await dao.upsert(record);
      await invalidateTemplates();

      return TemplateImportResult(
        ok: true,
        id: record.id,
        message: '已导入模板：${record.name}',
        warnings: warnings,
      );
    } catch (e) {
      return TemplateImportResult(ok: false, error: '$e');
    }
  }
}
