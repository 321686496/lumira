import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/dao/templates_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/lumira/lumira.dart' as lumira;
import '../data/imported_templates_provider.dart';
import '../services/template_mapper.dart';

/// 模板导入 BottomSheet
///
/// 共享组件，供 templates_all_page 和 profile_my_templates_page 使用。
/// 提供 3 种导入方式：
/// 1. 从文件导入（.json / .lumira / .pptpl）
/// 2. 从链接导入（粘贴分享链接）
/// 3. 扫码导入（手动输入分享码，无相机库依赖）
class TemplateImportSheet extends ConsumerWidget {
  const TemplateImportSheet({super.key, required this.onImported});

  /// 导入成功后的回调（传入新模板 id）
  final void Function(String newTemplateId) onImported;

  /// 显示导入面板
  static Future<void> show(
    BuildContext context, {
    required void Function(String newTemplateId) onImported,
  }) {
    return lumira.showLumiraBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => TemplateImportSheet(onImported: onImported),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '导入模板',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 20,
                  color: tokens.textTertiary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ImportOption(
          icon: Icons.insert_drive_file_outlined,
          title: '从文件导入',
          subtitle: '支持 .json / .lumira / .pptpl 模板文件',
          tokens: tokens,
          onTap: () => _handleFileImport(context, ref),
        ),
        _ImportOption(
          icon: Icons.link_outlined,
          title: '从链接导入',
          subtitle: '粘贴分享链接（lumira://tpl/xxx）',
          tokens: tokens,
          onTap: () => _handleLinkImport(context, ref),
        ),
        _ImportOption(
          icon: Icons.qr_code_scanner_outlined,
          title: '扫码导入',
          subtitle: '输入模板分享码（LUMIRA-xxx）',
          tokens: tokens,
          onTap: () => _handleQrImport(context, ref),
        ),
        const SizedBox(height: 8),
        Text(
          '导入的模板将出现在「我的模板」中，可随时编辑或删除',
          style: TextStyle(
            fontSize: 11,
            color: tokens.textTertiary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ===== 文件导入（DAO 持久化 + 双格式嗅探）=====
  Future<void> _handleFileImport(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    navigator.pop(); // 先关闭 BottomSheet

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'lumira', 'pptpl'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        // 用户取消选择
        return;
      }

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        _showToast(navigator, '无法读取文件内容');
        return;
      }

      final content = utf8.decode(bytes);
      final parsed = _parseTemplateJson(content);
      if (parsed == null) {
        _showToast(navigator, '文件格式无效，请选择有效的模板文件');
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      var record = TemplateMapper.recordFromImportedJson(
        parsed,
        createdAt: now,
      );

      // ID 冲突处理：已存在则追加 _imported_ 时间戳后缀
      final dao = await ref.read(templatesDaoProvider.future);
      var finalId = record.id;
      while (await dao.getById(finalId) != null) {
        finalId = '${finalId}_imported_$now';
      }
      if (finalId != record.id) {
        record = _copyRecordWithId(record, finalId);
      }

      await dao.upsert(record);

      _showToast(navigator, '已导入模板：${record.name}');
      onImported(record.id);
    } catch (e) {
      _showToast(navigator, '导入失败：$e');
    }
  }

  /// 复制 TemplateRecord 并替换 id（用于 ID 冲突时生成新记录）
  TemplateRecord _copyRecordWithId(TemplateRecord src, String newId) {
    return TemplateRecord(
      id: newId,
      name: src.name,
      author: src.author,
      version: src.version,
      category: src.category,
      classification: src.classification,
      tags: src.tags,
      tagIds: src.tagIds,
      price: src.price,
      cover: src.cover,
      description: src.description,
      referenceSource: src.referenceSource,
      composition: src.composition,
      pose: src.pose,
      camera: src.camera,
      sceneGuide: src.sceneGuide,
      postProcess: src.postProcess,
      createdAt: src.createdAt,
      updatedAt: src.updatedAt,
      isBuiltin: src.isBuiltin,
      isRecommended: src.isRecommended,
    );
  }

  // ===== 链接导入 =====
  Future<void> _handleLinkImport(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    navigator.pop(); // 先关闭 BottomSheet

    final url = await _showInputDialog(
      context: context,
      title: '从链接导入',
      hint: 'lumira://tpl/xxx 或 https://...',
      keyboardType: TextInputType.url,
    );

    if (url == null || url.trim().isEmpty) return;

    final parsed = _parseTemplateLink(url.trim());
    if (parsed == null) {
      _showToast(navigator, '链接格式无效，请输入有效的分享链接');
      return;
    }

    _showLoadingWithNavigator(navigator, '正在导入...');

    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 800));

    navigator.pop(); // 关闭 loading

    final name = parsed['name'] as String;
    final category = (parsed['category'] as String?) ?? 'still-life';
    final tags = (parsed['tags'] as List<dynamic>?)?.cast<String>() ?? <String>[];
    final coverSeed = parsed['coverSeed'] as String?;

    final newId = ref.read(importedTemplatesProvider.notifier).addTemplate(
          name: name,
          category: category,
          tags: tags,
          source: 'link',
          coverSeed: coverSeed,
        );

    _showToast(navigator, '已导入模板：$name');
    onImported(newId);
  }

  // ===== 扫码导入 =====
  Future<void> _handleQrImport(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    navigator.pop(); // 先关闭 BottomSheet

    // 无相机 QR 扫描库依赖，使用手动输入码作为简化实现
    // 用户可以输入分享码（如 LUMIRA-XXX-名称）
    final code = await _showInputDialog(
      context: context,
      title: '扫码导入',
      hint: '输入分享码（LUMIRA-分类-名称）',
      keyboardType: TextInputType.text,
    );

    if (code == null || code.trim().isEmpty) return;

    final parsed = _parseTemplateCode(code.trim());
    if (parsed == null) {
      _showToast(navigator, '分享码无效，请检查后重试');
      return;
    }

    _showLoadingWithNavigator(navigator, '正在解析二维码...');

    await Future.delayed(const Duration(milliseconds: 600));

    navigator.pop(); // 关闭 loading

    final name = parsed['name'] as String;
    final category = (parsed['category'] as String?) ?? 'still-life';
    final tags = (parsed['tags'] as List<dynamic>?)?.cast<String>() ?? <String>[];
    final coverSeed = parsed['coverSeed'] as String?;

    final newId = ref.read(importedTemplatesProvider.notifier).addTemplate(
          name: name,
          category: category,
          tags: tags,
          source: 'qr',
          coverSeed: coverSeed,
        );

    _showToast(navigator, '已导入模板：$name');
    onImported(newId);
  }

  // ===== 解析逻辑 =====

  /// 解析模板 JSON（文件内容）
  /// 支持格式：
  /// - .pptpl: { "format": "pptpl", "meta": {...}, "composition": {...}, ... }
  /// - .lumira: { "format": "lumira", "meta": {...}, "camera": {...}, ... }
  /// - 旧版扁平: { "name": "...", "category": "...", "tags": [...], "coverSeed": "..." }
  /// 返回原始 JSON Map；具体格式嗅探由 TemplateMapper.recordFromImportedJson 完成
  Map<String, dynamic>? _parseTemplateJson(String content) {
    try {
      final data = jsonDecode(content);
      if (data is! Map<String, dynamic>) return null;

      // 新格式：含 format 字段或 meta 字段 → 直接返回，交给 mapper 嗅探
      if (data['format'] is String || data['meta'] is Map) {
        return data;
      }

      // 旧版扁平格式：{ name, category, tags, coverSeed }
      // 包装为 lumira 简化格式交给 mapper
      final name = data['name'];
      if (name is String && name.isNotEmpty) {
        return {
          'format': 'lumira',
          'version': '1.0',
          'meta': {
            'id': data['id'] ?? 'imported_legacy_${DateTime.now().millisecondsSinceEpoch}',
            'name': name,
            'category': data['category'] ?? 'still-life',
            'tags': data['tags'] ?? <String>[],
          },
          'camera': <String, dynamic>{},
          'composition': {'overlayType': 'rule_of_thirds'},
        };
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 解析分享链接
  /// 支持格式：
  /// - lumira://tpl/{base64(json)}
  /// - https://lumira.app/tpl/{base64(json)}
  /// - https://lumira.app/tpl?name=xxx&category=xxx
  Map<String, dynamic>? _parseTemplateLink(String url) {
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
          final decoded = _safeBase64Decode(segments.last);
          if (decoded != null) {
            final data = jsonDecode(decoded);
            if (data is Map<String, dynamic>) {
              final name = data['name'];
              if (name is String && name.isNotEmpty) return data;
            }
          }
        }
      }

      // https://lumira.app/tpl?name=xxx&category=xxx
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
  Map<String, dynamic>? _parseTemplateCode(String code) {
    if (!code.startsWith('LUMIRA-')) return null;

    final parts = code.split('-');
    if (parts.length < 3) return null;

    final category = _normalizeCategory(parts[1].toLowerCase());
    final name = parts.sublist(2).join('-');

    return {
      'name': name,
      'category': category,
      'tags': <String>['导入'],
      'coverSeed': 'qr-$code',
    };
  }

  String _normalizeCategory(String s) {
    const valid = {
      'portrait', 'landscape', 'food', 'street', 'night', 'macro', 'still-life'
    };
    return valid.contains(s) ? s : 'still-life';
  }

  String? _safeBase64Decode(String s) {
    try {
      final normalized = s.replaceAll('-', '+').replaceAll('_', '/');
      final padded = normalized + '=' * ((4 - normalized.length % 4) % 4);
      return utf8.decode(base64.decode(padded));
    } catch (_) {
      return null;
    }
  }

  // ===== UI 辅助 =====

  void _showToast(NavigatorState navigator, String msg) {
    if (!navigator.context.mounted) return;
    lumira.LumiraToast.show(navigator.context, msg);
  }

  void _showLoadingWithNavigator(NavigatorState navigator, String msg) {
    navigator.push(
      DialogRoute(
        context: navigator.context,
        barrierDismissible: false,
        builder: (ctx) => SafeArea(
          child: Center(
            child: lumira.LumiraDialogContainer(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  lumira.LumiraProgress.circular(),
                  const SizedBox(width: 16),
                  Text(msg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<String?> _showInputDialog({
    required BuildContext context,
    required String title,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) async {
    final controller = TextEditingController();
    return lumira.showLumiraDialog<String>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          lumira.LumiraTextField(
            controller: controller,
            hintText: hint,
            keyboardType: keyboardType,
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              lumira.LumiraButton(
                variant: ButtonVariant.ghost,
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              lumira.LumiraButton(
                variant: ButtonVariant.primary,
                onPressed: () => Navigator.of(ctx).pop(controller.text),
                child: const Text('确定'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 导入方式选项
class _ImportOption extends StatelessWidget {
  const _ImportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tokens,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tokens.brand.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: tokens.brand),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: tokens.textTertiary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: tokens.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
