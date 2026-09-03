import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/theme_tokens.dart';

/// Lumira 全局下拉选择器
///
/// 视觉规格来源：spec §3.3 LumiraDropdown
/// - 触发器：复用 LumiraTextField 视觉（只读 + 右侧 chevron-down 图标）
/// - 弹出层：调用 `showModalBottomSheet`（Phase 2 的 `showLumiraBottomSheet` 未就绪时的回退）
///   容器使用 `tokens.surface` + `popupRadius`
/// - 菜单项：ListTile 样式，选中项右侧显示 check 图标（color = tokens.brand）
class LumiraDropdown<T> extends ConsumerWidget {
  const LumiraDropdown({
    super.key,
    required this.value,
    required this.items,
    this.onChanged,
    this.hintText,
    this.enabled = true,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hintText;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    // 触发器使用 inputRadius（与 LumiraTextField 一致）
    final radius = appTheme.inputRadius / 2;

    final InputState state = enabled
        ? InputState.default_
        : InputState.disabled;
    final visual = appTheme.inputVisual(state);

    final BoxDecoration decoration = _buildTriggerDecoration(appTheme, tokens, visual, radius);

    final DropdownMenuItem<T>? selectedItem = items
        .cast<DropdownMenuItem<T>?>()
        .firstWhere((item) => item?.value == value, orElse: () => null);

    return GestureDetector(
      onTap: enabled ? () => _showOptions(context) : null,
      child: Container(
        decoration: decoration,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: selectedItem != null
                  ? DefaultTextStyle.merge(
                      style: TextStyle(
                        fontSize: 14,
                        color: visual.foreground,
                      ),
                      child: selectedItem.child,
                    )
                  : Text(
                      hintText ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: tokens.textTertiary,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: enabled ? tokens.textTertiary : tokens.textTertiary.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _buildTriggerDecoration(
    AppThemeData appTheme,
    ThemeTokens tokens,
    InputVisual visual,
    double radius,
  ) {
    switch (appTheme.style) {
      case UIStyle.neumorphic:
        return BoxDecoration(
          color: visual.gradient == null ? visual.background : null,
          gradient: visual.gradient,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: visual.shadows,
        );
      case UIStyle.flat:
        return BoxDecoration(
          color: visual.background,
          borderRadius: BorderRadius.circular(radius),
          border: visual.border,
        );
      case UIStyle.glass:
        return BoxDecoration(
          color: visual.background,
          borderRadius: BorderRadius.circular(radius),
          border: visual.border,
        );
      case UIStyle.female:
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tokens.brandSubtle.withOpacity(0.55),
              tokens.brandLight.withOpacity(0.25),
            ],
          ),
          borderRadius: BorderRadius.circular(radius),
          border: visual.border,
        );
    }
  }

  Future<void> _showOptions(BuildContext context) async {
    final T? selected = await showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final currentTheme = ref.watch(appThemeProvider);
            final currentTokens = currentTheme.tokens;
            final currentPopupRadius = currentTheme.popupRadius / 2;
            return Container(
              decoration: BoxDecoration(
                color: currentTokens.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(currentPopupRadius),
                  topRight: Radius.circular(currentPopupRadius),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 拖柄
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: currentTokens.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final isSelected = item.value == value;
                          return InkWell(
                            onTap: () => Navigator.of(context).pop<T>(item.value),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: DefaultTextStyle.merge(
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: isSelected
                                            ? currentTokens.brand
                                            : currentTokens.textPrimary,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                      child: item.child,
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.check,
                                      size: 18,
                                      color: currentTokens.brand,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selected != null) {
      onChanged?.call(selected);
    }
  }
}

/// LumiraDropdown 的 FormField 变体
///
/// 与 Flutter 原生 `DropdownButtonFormField` 对齐，用于 `Form` 内部场景。
class LumiraDropdownFormField<T> extends FormField<T> {
  LumiraDropdownFormField({
    super.key,
    required List<DropdownMenuItem<T>> items,
    T? initialValue,
    ValueChanged<T?>? onChanged,
    String? hintText,
    bool enabled = true,
    super.validator,
    super.autovalidateMode,
  }) : super(
          initialValue: initialValue,
          builder: (FormFieldState<T> field) {
            return Consumer(
              builder: (context, ref, _) {
                final tokens = ref.watch(appThemeProvider).tokens;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LumiraDropdown<T>(
                      value: field.value,
                      items: items,
                      onChanged: (v) {
                        field.didChange(v);
                        onChanged?.call(v);
                      },
                      hintText: hintText,
                      enabled: enabled,
                    ),
                    if (field.hasError && field.errorText != null) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(
                          field.errorText!,
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.danger,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        );
}
