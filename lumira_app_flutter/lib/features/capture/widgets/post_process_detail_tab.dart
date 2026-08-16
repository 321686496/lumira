import 'package:flutter/material.dart';
import '../../../core/theme/theme_tokens.dart';
import '../domain/photo_template.dart';
import 'post_process_adjust_panel.dart';

/// 共享细节编辑 Tab（受控纯展示）。
///
/// 接收全量 [PostProcess]，UI 只读字段并通过 [onChanged] 回调新的全量值。
/// 全量↔增量换算由上层负责（PreviewEditPanel 用 deltaOf，ParamPanel 用
/// CaptureState.updatePostProcess），本组件不感知 baked 基线。
class PostProcessDetailTab extends StatelessWidget {
  final PostProcess full;
  final ValueChanged<PostProcess> onChanged;

  /// 浅色主题色板；为 null 时滑块使用默认半透明深色配色。
  final ThemeTokens? tokens;

  const PostProcessDetailTab({
    super.key,
    required this.full,
    required this.onChanged,
    this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return AdjustPanel(
      defs: detailAdjustDefs(),
      full: full,
      onChanged: onChanged,
      tokens: tokens,
    );
  }
}