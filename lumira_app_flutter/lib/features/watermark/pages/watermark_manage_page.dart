import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/watermark_providers.dart';
import '../models/watermark_template.dart';
import '../widgets/watermark_preview.dart';

/// 水印管理页：列出所有预置水印模板，支持选择 / 跳转编辑。
///
/// 选择某卡片时更新 [watermarkSettingsProvider] 的 `activeTemplateId` 并返回；
/// 编辑按钮跳转到 [WatermarkEditorPage]（携带 templateId 查询参数）。
class WatermarkManagePage extends ConsumerWidget {
  const WatermarkManagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final presets = ref.watch(presetWatermarksProvider);
    final settings = ref.watch(watermarkSettingsProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: const LumiraNav(
        title: '水印管理',
        transparent: true,
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: presets.length,
          itemBuilder: (context, index) {
            final template = presets[index];
            final selected = template.id == settings.activeTemplateId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _WatermarkCard(
                template: template,
                selected: selected,
                tokens: tokens,
                onSelect: () {
                  ref.read(watermarkSettingsProvider.notifier).state =
                      ref
                          .read(watermarkSettingsProvider)
                          .copyWith(activeTemplateId: template.id);
                  scheduleWatermarkPersist(
                      ProviderScope.containerOf(context, listen: false));
                  if (context.canPop()) {
                    context.pop();
                  }
                },
                onEdit: () {
                  context.push(
                    '${RouteNames.profileSettingsWatermarkEdit}'
                    '?${RouteNames.paramTemplateId}=${template.id}',
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WatermarkCard extends StatelessWidget {
  const _WatermarkCard({
    required this.template,
    required this.selected,
    required this.tokens,
    required this.onSelect,
    required this.onEdit,
  });

  final WatermarkTemplate template;
  final bool selected;
  final ThemeTokens tokens;
  final VoidCallback onSelect;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 可点击的选择区（预览 + 名称 + 类型标签）
          Expanded(
            child: GestureDetector(
              onTap: onSelect,
              behavior: HitTestBehavior.opaque,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  WatermarkPreview(
                    template: template,
                    width: 96,
                    height: 124,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          template.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: tokens.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        _TypeTag(
                          type: template.type,
                          tokens: tokens,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 右侧：选中显示对勾，否则显示编辑按钮
          if (selected)
            _SelectedBadge(tokens: tokens)
          else
            _EditButton(tokens: tokens, onTap: onEdit),
        ],
      ),
    );
  }
}

class _TypeTag extends StatelessWidget {
  const _TypeTag({required this.type, required this.tokens});
  final WatermarkTemplateType type;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final label = type == WatermarkTemplateType.preset ? '预置' : '自定义';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tokens.brandSubtle,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: tokens.brandText,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _SelectedBadge extends StatelessWidget {
  const _SelectedBadge({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: tokens.brand,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check, size: 18, color: Colors.white),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.tokens, required this.onTap});
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        child: Icon(
          Icons.edit_outlined,
          size: 20,
          color: tokens.textSecondary,
        ),
      ),
    );
  }
}
