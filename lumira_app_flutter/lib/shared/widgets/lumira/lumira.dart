/// Lumira 全局组件库 barrel export
///
/// 所有 Lumira 自定义组件统一从此处导出，调用方应：
/// ```dart
/// import 'package:.../shared/widgets/lumira/lumira.dart';
/// ```
///
/// 设计文档：docs/superpowers/specs/2026-08-04-lumira-component-foundation-design.md

// 内部工具（仅供组件实现使用，不对外暴露）
// export '_internal/lumira_theme_resolver.dart';

// === Phase 1：反馈与按钮 ===
export 'feedback/lumira_toast.dart';
export 'feedback/lumira_progress.dart';
export 'buttons/lumira_button.dart';
export 'buttons/lumira_icon_button.dart';

// === Phase 2：弹层 ===
export 'dialog/lumira_dialog.dart';
export 'dialog/lumira_bottom_sheet.dart';
export 'dialog/lumira_menu.dart';

// === Phase 3：表单 ===
export 'form/lumira_text_field.dart';
export 'form/lumira_dropdown.dart';
export 'form/lumira_slider.dart';
export 'form/lumira_switch.dart';
export 'form/lumira_checkbox.dart';

// === Phase 4：日期选择器 ===
export 'picker/lumira_date_picker.dart';

// === Phase 5：列表与导航 ===
export 'nav/lumira_list_tile.dart';
export 'nav/lumira_tab_bar.dart';
export 'nav/lumira_fab.dart';
export 'nav/lumira_bottom_nav.dart';
