import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../profile/data/composition_kit_models.dart';
import '../../profile/providers/composition_kits_providers.dart';

/// 「加入组合」底部 Sheet
///
/// 在场景详情页点击「加入组合」时弹出，让用户输入套件名 + 选择关联模板 + 备注，
/// 保存后写入 composition_kits 表。Toast 提供「查看组合」快捷入口。
class AddToCompositionSheet extends ConsumerStatefulWidget {
  const AddToCompositionSheet({
    super.key,
    required this.sceneId,
    required this.sceneName,
    this.sceneCoverUrl,
  });

  final String sceneId;
  final String sceneName;
  final String? sceneCoverUrl;

  static Future<void> show(
    BuildContext context, {
    required String sceneId,
    required String sceneName,
    String? sceneCoverUrl,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => AddToCompositionSheet(
        sceneId: sceneId,
        sceneName: sceneName,
        sceneCoverUrl: sceneCoverUrl,
      ),
    );
  }

  @override
  ConsumerState<AddToCompositionSheet> createState() =>
      _AddToCompositionSheetState();
}

class _AddToCompositionSheetState extends ConsumerState<AddToCompositionSheet> {
  late TextEditingController _nameController;
  late TextEditingController _noteController;
  String? _selectedTemplateId; // null = 自由拍摄
  List<_TemplateOption> _templateOptions = const [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // 默认名称 "场景名-自由拍摄"
    _nameController = TextEditingController(text: '${widget.sceneName}-自由拍摄');
    _noteController = TextEditingController();
    _loadTemplateOptions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplateOptions() async {
    try {
      final daoAsync = ref.read(templatesDaoProvider.future);
      final dao = await daoAsync;
      final records = await dao.getAll();
      if (!mounted) return;
      setState(() {
        _templateOptions = [
          const _TemplateOption(id: null, name: '自由拍摄（不关联模板）'),
          ...records.map((r) => _TemplateOption(id: r.id, name: r.name)),
        ];
      });
    } catch (_) {
      // 模板加载失败时仅显示自由拍摄选项
      if (!mounted) return;
      setState(() {
        _templateOptions = const [
          _TemplateOption(id: null, name: '自由拍摄（不关联模板）'),
        ];
      });
    }
  }

  Future<void> _onSave() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入套件名称')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final kit = CompositionKit(
        id: 'kit_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        sceneId: widget.sceneId,
        templateId: _selectedTemplateId,
        cameraOverrides: const {},
        note: _noteController.text.trim(),
        coverUrl: widget.sceneCoverUrl,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      final dao = await ref.read(compositionKitsDaoProvider.future);
      await dao.insert(kit);
      ref.invalidate(compositionKitsProvider);

      if (!mounted) return;
      Navigator.of(context).pop();

      // Toast + "查看组合"快捷入口
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('已加入组合'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: '查看组合',
            onPressed: () {
              GoRouter.of(context).push(RouteNames.profileCompositionKits);
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Material(
      color: tokens.canvas,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(tokens: tokens, title: '加入组合'),
              const SizedBox(height: 16),
              _Label(tokens: tokens, text: '套件名称'),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: '如：咖啡馆+柔光人像',
                  filled: true,
                  fillColor: tokens.canvasDeep,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(color: tokens.textPrimary, fontSize: 14),
              ),
              const SizedBox(height: 14),
              _Label(tokens: tokens, text: '关联模板（可选）'),
              _TemplateDropdown(
                tokens: tokens,
                value: _selectedTemplateId,
                options: _templateOptions,
                onChanged: (v) => setState(() => _selectedTemplateId = v),
              ),
              const SizedBox(height: 14),
              _Label(tokens: tokens, text: '备注'),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: '记录拍摄要点（可选）',
                  filled: true,
                  fillColor: tokens.canvasDeep,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(color: tokens.textPrimary, fontSize: 14),
              ),
              const SizedBox(height: 20),
              _SaveButton(
                tokens: tokens,
                saving: _saving,
                onTap: _onSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateOption {
  const _TemplateOption({required this.id, required this.name});
  final String? id;
  final String name;
}

class _Header extends StatelessWidget {
  const _Header({required this.tokens, required this.title});
  final ThemeTokens tokens;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
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
            child: Icon(Icons.close, size: 20, color: tokens.textTertiary),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.tokens, required this.text});
  final ThemeTokens tokens;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: tokens.textSecondary,
        ),
      ),
    );
  }
}

class _TemplateDropdown extends StatelessWidget {
  const _TemplateDropdown({
    required this.tokens,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final ThemeTokens tokens;
  final String? value;
  final List<_TemplateOption> options;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: tokens.canvasDeep,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: tokens.textTertiary),
          style: TextStyle(fontSize: 14, color: tokens.textPrimary),
          dropdownColor: tokens.surface,
          items: options
              .map((o) => DropdownMenuItem<String?>(
                    value: o.id,
                    child: Text(o.name),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.tokens,
    required this.saving,
    required this.onTap,
  });

  final ThemeTokens tokens;
  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: saving ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: tokens.textPrimary,
          borderRadius: BorderRadius.circular(22),
        ),
        alignment: Alignment.center,
        child: saving
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: tokens.canvas,
                ),
              )
            : Text(
                '保存套件',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tokens.canvas,
                ),
              ),
      ),
    );
  }
}
