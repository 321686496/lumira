import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../data/capture_state.dart';

/// 按钮：有模板且未应用时显示"应用参数"，点击重置 editableTemplate 为 original 副本。
/// 当 original 为 null（自由拍摄）或 applied == true（无修改）时，按钮隐藏。
class ApplyButton extends ConsumerWidget {
  const ApplyButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final original = ref.watch(CaptureState.originalTemplateProvider);
    final applied = ref.watch(CaptureState.appliedProvider);
    if (original == null || applied) return const SizedBox.shrink();

    final tokens = ref.watch(appThemeProvider).tokens;

    return GestureDetector(
      onTap: () {
        ref.read(CaptureState.editableTemplateProvider.notifier).state =
            original.copyWith();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: tokens.brand,
          borderRadius: BorderRadius.circular(16),
          // 浮在取景器/预览图上：禁用品牌浮雕内嵌/双向投影（动态画面光影易错乱），
          // 保持实心品牌色，不挂浮雕阴影。
          boxShadow: null,
        ),
        child: Text(
          '应用',
          style: TextStyle(
            color: tokens.textInverse,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
