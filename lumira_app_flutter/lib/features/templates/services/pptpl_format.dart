/// .pptpl 格式版本常量与导入校验
///
/// 规范要求（AGENT.md §5）："离线版导入时做版本兼容性检查"
class PptplFormat {
  PptplFormat._();

  /// 当前格式版本
  static const String currentVersion = '1.0';

  /// 支持的格式版本集合
  static const Set<String> supportedVersions = {'1.0'};

  /// 校验导入的 JSON 格式版本，返回警告列表。
  ///
  /// - 无 `version` 字段 → [TemplateImportWarning.legacyFormat]
  /// - `version` 在 [supportedVersions] 中 → 无警告
  /// - `version` 不在支持列表 → [TemplateImportWarning.unsupportedVersion]
  ///
  /// 警告为非阻塞——调用方应继续 best-effort 解析（前向兼容）。
  static List<TemplateImportWarning> validate(Map<String, dynamic> json) {
    final warnings = <TemplateImportWarning>[];
    final version = json['version'] as String?;

    if (version == null) {
      warnings.add(TemplateImportWarning.legacyFormat);
    } else if (!supportedVersions.contains(version)) {
      warnings.add(TemplateImportWarning.unsupportedVersion);
    }

    return warnings;
  }
}

/// 模板导入警告类型
enum TemplateImportWarning {
  /// 旧版格式（无 version 字段）
  legacyFormat,

  /// 不支持的格式版本（可能不兼容）
  unsupportedVersion,
}

/// 模板导入结果
class TemplateImportResult {
  final bool success;
  final String? templateId;
  final String? errorMessage;
  final List<TemplateImportWarning> warnings;

  const TemplateImportResult({
    required this.success,
    this.templateId,
    this.errorMessage,
    this.warnings = const [],
  });

  bool get hasWarnings => warnings.isNotEmpty;
}
