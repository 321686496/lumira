import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/capture/domain/post_process_delta.dart';
import 'package:lumira_app_flutter/features/capture/widgets/post_process_color_tab.dart';
import 'package:lumira_app_flutter/features/capture/widgets/post_process_detail_tab.dart';
import 'package:lumira_app_flutter/features/capture/widgets/preview_edit_panel.dart';

/// 拍摄预览页编辑工具（与 gallery_edit_page._EditTool 对齐的公开版本）。
enum PreviewEditTool { color, detail, filter, crop }

/// 底部图标工具条（色彩/细节/滤镜/裁剪/重置）+ 点选滑出的参数面板。
///
/// - 面板内部复用 PostProcessColorTab / PostProcessDetailTab / FilterTab / CropTab
/// - 全量↔增量换算与旧 PreviewEditPanel 一致：fullOf(baked, local) 显示、
///   deltaOf(baked, full, current: local) 回传
/// - 面板高度与后期修图页一致：色彩/细节 160、滤镜 264、裁剪 328
class PreviewEditToolbar extends StatelessWidget {
  const PreviewEditToolbar({
    Key? key,
    required this.activeTool,
    required this.postProcess,
    this.bakedPostProcess,
    required this.transform,
    required this.onToolChanged,
    required this.onPostProcessChanged,
    required this.onTransformChanged,
    required this.onReset,
    this.previewImagePath,
    this.isReadOnly = false,
    this.onReadOnlyTap,
    required this.tokens,
  }) : super(key: key);

  /// 当前激活工具；null = 面板收起
  final PreviewEditTool? activeTool;

  /// 本地增量参数（页面持有）
  final PostProcess postProcess;

  /// 烘焙基线（null 视为全零基线）
  final PostProcess? bakedPostProcess;

  final TransformParams transform;

  /// 工具切换；null 表示收起面板
  final ValueChanged<PreviewEditTool?> onToolChanged;
  final ValueChanged<PostProcess> onPostProcessChanged;
  final ValueChanged<TransformParams> onTransformChanged;
  final VoidCallback onReset;

  /// 滤镜缩略图路径（null = 降级文字 Chip）
  final String? previewImagePath;

  /// 只读模式：点工具/重置 → onReadOnlyTap，不展开面板
  final bool isReadOnly;
  final VoidCallback? onReadOnlyTap;

  final ThemeTokens tokens;

  PostProcess get _baked =>
      bakedPostProcess ?? const PostProcess(color: PostProcessColor());

  PostProcess get _fullForEdit => fullOf(_baked, postProcess);

  void _updatePostFromFull(PostProcess newFull) =>
      onPostProcessChanged(deltaOf(_baked, newFull, current: postProcess));

  void _toggle(PreviewEditTool tool) {
    if (isReadOnly) {
      onReadOnlyTap?.call();
      return;
    }
    onToolChanged(activeTool == tool ? null : tool);
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ToolItem(
                icon: Icons.tune,
                label: '色彩',
                selected: activeTool == PreviewEditTool.color,
                tokens: tokens,
                onTap: () => _toggle(PreviewEditTool.color),
              ),
              _ToolItem(
                icon: Icons.auto_fix_high_outlined,
                label: '细节',
                selected: activeTool == PreviewEditTool.detail,
                tokens: tokens,
                onTap: () => _toggle(PreviewEditTool.detail),
              ),
              _ToolItem(
                icon: Icons.filter_vintage_outlined,
                label: '滤镜',
                selected: activeTool == PreviewEditTool.filter,
                tokens: tokens,
                onTap: () => _toggle(PreviewEditTool.filter),
              ),
              _ToolItem(
                icon: Icons.crop_rotate,
                label: '裁剪',
                selected: activeTool == PreviewEditTool.crop,
                tokens: tokens,
                onTap: () => _toggle(PreviewEditTool.crop),
              ),
              _ToolItem(
                icon: Icons.refresh,
                label: '重置',
                selected: false,
                tokens: tokens,
                onTap: () {
                  if (isReadOnly) {
                    onReadOnlyTap?.call();
                    return;
                  }
                  onReset();
                  HapticFeedback.lightImpact();
                },
              ),
            ],
          ),
        ),
        // 参数面板：点选工具后滑出，再次点击收起
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: activeTool == null
              ? const SizedBox.shrink()
              : _buildPanel(),
        ),
      ],
    );
  }

  Widget _buildPanel() {
    final Widget panel;
    final double height;
    switch (activeTool!) {
      case PreviewEditTool.color:
        panel = PostProcessColorTab(
          full: _fullForEdit,
          onChanged: _updatePostFromFull,
          tokens: tokens,
        );
        height = 160;
        break;
      case PreviewEditTool.detail:
        panel = PostProcessDetailTab(
          full: _fullForEdit,
          onChanged: _updatePostFromFull,
          tokens: tokens,
        );
        height = 160;
        break;
      case PreviewEditTool.filter:
        panel = FilterTab(
          postProcess: _fullForEdit,
          onChanged: _updatePostFromFull,
          previewImagePath: previewImagePath,
          tokens: tokens,
        );
        height = 264;
        break;
      case PreviewEditTool.crop:
        panel = CropTab(
          transform: transform,
          onChanged: onTransformChanged,
          postProcess: postProcess,
          onPostProcessChanged: onPostProcessChanged,
          tokens: tokens,
          previewImagePath: previewImagePath,
        );
        height = 328;
        break;
    }
    return SizedBox(height: height, child: panel);
  }
}

/// 单个工具项：图标 + 文字，选中时品牌色高亮 + 圆角底（与 gallery _ToolItem 同款）
class _ToolItem extends StatelessWidget {
  const _ToolItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.tokens,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? tokens.brand : tokens.textSecondary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? tokens.brandSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(1000),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}