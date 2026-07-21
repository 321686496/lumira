import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../data/imported_templates_provider.dart';

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
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => TemplateImportSheet(onImported: onImported),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);

    return Material(
      color: tokens.canvas,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '导入的模板将出现在「我的模板」中，可随时编辑或删除',
                  style: TextStyle(
                    fontSize: 11,
                    color: tokens.textTertiary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== 文件导入 =====
  Future<void> _handleFileImport(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
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
        _showSnackMsg(messenger, '无法读取文件内容');
        return;
      }

      final content = utf8.decode(bytes);
      final parsed = _parseTemplateJson(content);
      if (parsed == null) {
        _showSnackMsg(messenger, '文件格式无效，请选择有效的模板文件');
        return;
      }

      final name = parsed['name'] as String;
      final category = (parsed['category'] as String?) ?? 'still-life';
      final tags = (parsed['tags'] as List<dynamic>?)?.cast<String>() ?? <String>[];
      final coverSeed = parsed['coverSeed'] as String?;

      final newId = ref.read(importedTemplatesProvider.notifier).addTemplate(
            name: name,
            category: category,
            tags: tags,
            source: 'file',
            coverSeed: coverSeed,
          );

      _showSnackMsg(messenger, '已导入模板：$name');
      onImported(newId);
    } catch (e) {
      _showSnackMsg(messenger, '导入失败：$e');
    }
  }

  // ===== 链接导入 =====
  Future<void> _handleLinkImport(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
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
      _showSnackMsg(messenger, '链接格式无效，请输入有效的分享链接');
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

    _showSnackMsg(messenger, '已导入模板：$name');
    onImported(newId);
  }

  // ===== 扫码导入 =====
  Future<void> _handleQrImport(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
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
      _showSnackMsg(messenger, '分享码无效，请检查后重试');
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

    _showSnackMsg(messenger, '已导入模板：$name');
    onImported(newId);
  }

  // ===== 解析逻辑 =====

  /// 解析模板 JSON（文件内容）
  /// 支持格式：
  /// { "name": "...", "category": "portrait", "tags": ["..."], "coverSeed": "..." }
  Map<String, dynamic>? _parseTemplateJson(String content) {
    try {
      final data = jsonDecode(content);
      if (data is! Map<String, dynamic>) return null;
      final name = data['name'];
      if (name is! String || name.isEmpty) return null;
      return data;
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

  void _showSnackMsg(ScaffoldMessengerState messenger, String msg) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  void _showLoadingWithNavigator(NavigatorState navigator, String msg) {
    navigator.push(
      DialogRoute(
        context: navigator.context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Text(msg),
            ],
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
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
          keyboardType: keyboardType,
          autofocus: true,
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('确定'),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
