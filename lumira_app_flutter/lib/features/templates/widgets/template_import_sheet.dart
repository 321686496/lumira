import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/file_picker_service.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/lumira/lumira.dart' as lumira;
import '../../capture/data/capture_state.dart';
import '../../capture/data/template_registry.dart';
import '../services/pptpl_format.dart';
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
    // 版本标记：确认真机部署的是否为最新代码（v2 = 无提前 pop）
    debugPrint('[TemplateImport] code-version: v2-no-early-pop');
    // 注意：不能提前 navigator.pop() 关闭 BottomSheet。
    // pop 后本 widget 的 element 会被 deactivate，后续再使用 context/ref
    // （如 ref.read 查找 ProviderScope 祖先、toast 查找 Overlay）都会抛出
    // "Looking up a deactivated widget's ancestor is unsafe"。
    // 因此全程保持 BottomSheet 打开，所有操作完成后再统一关闭。
    try {
      final file = await FilePickerService.pickSingleFile(
        allowedExtensions: ['json', 'lumira', 'pptpl'],
        withData: true,
      );

      if (file == null) {
        // 用户取消选择
        if (context.mounted) navigator.pop();
        return;
      }

      // OHOS 上 file_picker_ohos 原生端 withData 返回的 bytes 被截断
      // （FileUtils.loadData 固定 4096 字节缓冲、只读一次），需从缓存路径
      // 读取完整内容，否则模板 JSON 解析会失败（大文件截断 / 小文件带零填充）。
      // 与 templates_editor_page 选图处理保持一致。
      final picked = await FilePickerService.ensureFullBytes(file);
      final bytes = picked.bytes;
      debugPrint('[TemplateImport] picked file: ${file.name}, '
          'bytes=${bytes?.length ?? -1}, path=${picked.path}');
      if (bytes == null) {
        if (context.mounted) {
          navigator.pop();
          _showToast(context, '无法读取文件内容');
        }
        return;
      }

      String content;
      try {
        content = utf8.decode(bytes);
      } on FormatException catch (e) {
        debugPrint('[TemplateImport] utf8.decode failed: $e');
        if (context.mounted) {
          navigator.pop();
          _showToast(context, '文件编码不是有效的 UTF-8，无法导入');
        }
        return;
      }
      debugPrint('[TemplateImport] utf8 decode ok, content.length=${content.length}');

      final parsed = _parseTemplateJson(content);
      debugPrint('[TemplateImport] parseTemplateJson => ${parsed != null}');
      if (parsed == null) {
        if (context.mounted) {
          navigator.pop();
          _showToast(context, '文件格式无效，请选择有效的模板文件');
        }
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      var record = TemplateMapper.recordFromImportedJson(
        parsed,
        createdAt: now,
      );
      debugPrint('[TemplateImport] recordFromImportedJson ok, '
          'id=${record.id}, name=${record.name}, coverDataLen=${record.coverData?.length ?? 0}, '
          'source=${record.source}');

      // ID 冲突处理：已存在则追加 _imported_ 时间戳后缀
      final dao = await ref.read(templatesDaoProvider.future);
      var finalId = record.id;
      while (await dao.getById(finalId) != null) {
        finalId = '${finalId}_imported_$now';
      }
      if (finalId != record.id) {
        record = record.copyWith(id: finalId);
      }
      debugPrint('[TemplateImport] final id: $finalId');

      await dao.upsert(record);
      debugPrint('[TemplateImport] dao.upsert ok');
      // 刷新 Capture 页模板缓存（系统 + 自定义），使新导入的模板立即出现
      ref.invalidate(CaptureState.allTemplatesProvider);

      if (context.mounted) {
        // 版本兼容性校验
        final warnings = PptplFormat.validate(parsed);
        if (warnings.isNotEmpty) {
          _showWarningsDialog(context, warnings);
        }
        _showToast(context, '已导入模板：${record.name}');
        navigator.pop();
      }
      onImported(record.id);
    } catch (e, st) {
      debugPrint('[TemplateImport] FAILED: $e\n$st');
      if (context.mounted) {
        navigator.pop();
        _showToast(context, '导入失败：$e');
      }
    }
  }

  // ===== 链接导入（DAO 持久化）=====
  Future<void> _handleLinkImport(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    // 与 _handleFileImport 同理：不提前关闭 BottomSheet，
    // 全程使用 sheet 的 context/ref（保持 active），操作完成后再统一关闭。
    final url = await _showInputDialog(
      context: context,
      title: '从链接导入',
      hint: 'lumira://tpl/xxx 或 https://...',
      keyboardType: TextInputType.url,
    );

    if (url == null || url.trim().isEmpty) {
      if (context.mounted) navigator.pop();
      return;
    }

    final parsed = _parseTemplateLink(url.trim());
    if (parsed == null) {
      if (context.mounted) {
        navigator.pop();
        _showToast(context, '链接格式无效，请输入有效的分享链接');
      }
      return;
    }

    // 轻量形式（无完整 JSON）→ 不支持
    if (parsed['name'] is String && parsed.containsKey('coverSeed') && !parsed.containsKey('meta')) {
      if (context.mounted) {
        navigator.pop();
        _showToast(context, '该分享链接不包含完整模板参数，请使用文件导入');
      }
      return;
    }

    // 完整 JSON 形式 → 走 DAO 持久化
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final warnings = PptplFormat.validate(parsed);
      var record = TemplateMapper.recordFromImportedJson(
        parsed,
        createdAt: now,
      );

      final dao = await ref.read(templatesDaoProvider.future);
      var finalId = record.id;
      while (await dao.getById(finalId) != null) {
        finalId = '${finalId}_imported_$now';
      }
      if (finalId != record.id) {
        record = record.copyWith(id: finalId);
      }

      await dao.upsert(record);
      // 刷新 Capture 页模板缓存（系统 + 自定义），使新导入的模板立即出现
      ref.invalidate(CaptureState.allTemplatesProvider);

      if (context.mounted) {
        _showToast(context, '已导入模板：${record.name}');
        if (warnings.isNotEmpty) {
          _showWarningsDialog(context, warnings);
        }
        navigator.pop();
      }
      onImported(record.id);
    } catch (e, st) {
      debugPrint('[TemplateImport] link FAILED: $e\n$st');
      if (context.mounted) {
        navigator.pop();
        _showToast(context, '导入失败：$e');
      }
    }
  }

  // ===== 扫码导入（DAO 持久化）=====
  Future<void> _handleQrImport(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    // 与 _handleFileImport 同理：不提前关闭 BottomSheet，操作完成后再统一关闭。
    final code = await _showInputDialog(
      context: context,
      title: '扫码导入',
      hint: '输入分享码（LUMIRA-分类-名称）',
      keyboardType: TextInputType.text,
    );

    if (code == null || code.trim().isEmpty) {
      if (context.mounted) navigator.pop();
      return;
    }

    final parsed = _parseTemplateCode(code.trim());
    if (parsed == null) {
      if (context.mounted) {
        navigator.pop();
        _showToast(context, '分享码无效，请检查后重试');
      }
      return;
    }

    try {
      final name = parsed['name'] as String;
      final category = parsed['category'] as String;
      final now = DateTime.now().millisecondsSinceEpoch;

      // 从内置模板取该 category 首个模板的参数作为默认值
      final builtinForCategory = TemplateRegistry.allTemplates
          .where((t) => t.meta.category == category)
          .toList();
      final defaultTpl = builtinForCategory.isNotEmpty
          ? builtinForCategory.first
          : TemplateRegistry.allTemplates.first;

      final record = TemplateMapper.toRecord(
        defaultTpl,
        createdAt: now,
        isBuiltin: false,
      ).copyWith(
        id: 'qr_${category}_$now',
        name: name,
        category: category,
        cover: '',
        isBuiltin: false,
        isRecommended: false,
      );

      final dao = await ref.read(templatesDaoProvider.future);
      await dao.upsert(record);
      // 刷新 Capture 页模板缓存（系统 + 自定义），使新导入的模板立即出现
      ref.invalidate(CaptureState.allTemplatesProvider);

      if (context.mounted) {
        _showToast(context, '已导入模板：$name');
        navigator.pop();
      }
      onImported(record.id);
    } catch (e, st) {
      debugPrint('[TemplateImport] qr FAILED: $e\n$st');
      if (context.mounted) {
        navigator.pop();
        _showToast(context, '导入失败：$e');
      }
    }
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

  void _showToast(BuildContext context, String msg) {
    if (!context.mounted) return;
    lumira.LumiraToast.show(context, msg);
  }

  void _showWarningsDialog(BuildContext context, List<TemplateImportWarning> warnings) {
    if (!context.mounted) return;
    final messages = warnings.map((w) {
      switch (w) {
        case TemplateImportWarning.legacyFormat:
          return '该模板为旧版格式，缺少版本信息，部分参数可能不兼容';
        case TemplateImportWarning.unsupportedVersion:
          return '该模板来自不支持的格式版本，部分参数可能不兼容';
      }
    }).join('\n');
    lumira.showLumiraDialog(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('导入提示', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(messages, style: const TextStyle(fontSize: 14, height: 1.5)),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: lumira.LumiraButton(
              variant: ButtonVariant.primary,
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('知道了'),
            ),
          ),
        ],
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
