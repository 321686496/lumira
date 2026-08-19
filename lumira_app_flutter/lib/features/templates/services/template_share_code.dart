import 'dart:convert';

import '../../../core/db/dao/templates_dao.dart';
import 'template_exporter.dart';

/// 模板分享码 / 分享链接 生成与解析工具。
///
/// - 分享码：`LUMIRA-{category}-{name}`（适合内置模板，接收端映射为分类默认参数）
/// - 分享链接：`lumira://tpl/{base64url(json)}`（携带完整模板 JSON，适合自定义模板）
///
/// 生成（buildShareCode / buildShareLink）与解析（parseCode / parseLink）
/// 必须保持往返一致，测试见 test/template_share_code_test.dart。
class TemplateShareCode {
  TemplateShareCode._();

  /// 构建分享码：`LUMIRA-{category}-{name}`
  static String buildShareCode(TemplateRecord record) {
    final category = _sanitizeSegment(record.category);
    final name = _sanitizeSegment(record.name);
    return 'LUMIRA-$category-$name';
  }

  /// 构建分享链接：`lumira://tpl/{base64url(json)}`
  ///
  /// [usePptpl] 为 true 时携带完整 .pptpl JSON（含全部 6 区段），否则为简化 .lumira JSON。
  static String buildShareLink(TemplateRecord record, {bool usePptpl = false}) {
    final json = usePptpl
        ? TemplateExporter.exportToPptpl(record)
        : TemplateExporter.exportToLumira(record);
    final encoded = base64UrlEncode(utf8.encode(json));
    return 'lumira://tpl/$encoded';
  }

  /// 解析分享链接。
  /// 支持：`lumira://tpl/{base64}` / `https://lumira.app/tpl/{base64}` / `https://lumira.app/tpl?name=...&category=...`
  static Map<String, dynamic>? parseLink(String url) {
    try {
      Uri? uri;
      try {
        uri = Uri.parse(url);
      } catch (_) {
        return null;
      }

      // 路径形式：lumira://tpl/{base64}
      if (uri.scheme == 'lumira' && uri.host == 'tpl') {
        final segments = uri.pathSegments;
        if (segments.isNotEmpty) {
          final decoded = safeBase64Decode(segments.last);
          if (decoded != null) {
            final data = jsonDecode(decoded);
            if (data is Map<String, dynamic>) {
              final name = data['name'];
              if (name is String && name.isNotEmpty) return data;
              // 兼容导出格式：name 位于 meta 下（exportToLumira / exportToPptpl），
              // 回填顶层 name 供轻量形式判定与展示复用，保持往返一致。
              final meta = data['meta'];
              if (meta is Map<String, dynamic>) {
                final metaName = meta['name'];
                if (metaName is String && metaName.isNotEmpty) {
                  data['name'] = metaName;
                  return data;
                }
              }
            }
          }
        }
      }

      // https://lumira.app/tpl?name=xxx&category=xxx（轻量形式，无完整 JSON）
      if (uri.scheme == 'https' && uri.host.endsWith('lumira.app')) {
        final params = uri.queryParameters;
        if (params.containsKey('name') && params['name']!.isNotEmpty) {
          return {
            'name': params['name'],
            'category': params['category'] ?? 'still-life',
            'tags': params['tags']?.split(',') ?? <String>[],
            'coverSeed': params['coverSeed'],
          };
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// 解析分享码（LUMIRA-分类-名称）
  static Map<String, dynamic>? parseCode(String code) {
    if (!code.startsWith('LUMIRA-')) return null;

    final parts = code.split('-');
    if (parts.length < 3) return null;

    final category = normalizeCategory(parts[1].toLowerCase());
    final name = parts.sublist(2).join('-');

    return {
      'name': name,
      'category': category,
      'tags': <String>['导入'],
      'coverSeed': 'qr-$code',
    };
  }

  /// base64url 解码（兼容标准 base64 的 +/ 与 = 填充）
  static String? safeBase64Decode(String s) {
    try {
      final normalized = s.replaceAll('-', '+').replaceAll('_', '/');
      final padded = normalized + '=' * ((4 - normalized.length % 4) % 4);
      return utf8.decode(base64.decode(padded));
    } catch (_) {
      return null;
    }
  }

  /// 分类名归一化：非法分类回退到 still-life
  static String normalizeCategory(String s) {
    const valid = {
      'portrait', 'landscape', 'food', 'street', 'night', 'macro', 'still-life'
    };
    return valid.contains(s) ? s : 'still-life';
  }

  /// 清理分享码分段：去除会破坏 `LUMIRA-a-b` 拆分的字符（`-`、空白等）
  static String _sanitizeSegment(String s) {
    return s.trim().replaceAll(RegExp(r'[-\s]'), '_');
  }
}
