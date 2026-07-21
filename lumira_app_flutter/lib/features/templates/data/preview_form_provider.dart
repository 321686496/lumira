import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'templates_editor_mock_data.dart';

/// 模板预览页与编辑器之间共享的 EditorForm
///
/// Bug 12 修复：让预览页接入真实取景器并与编辑器参数双向同步。
///
/// 工作流：
/// 1. 编辑器点击"预览"按钮时（_onPreview），将当前 _form 的副本写入此 provider
/// 2. 预览页 initState 时优先读取此 provider（若为 null，则回退到 mock 数据，
///    兼容 templateId 直接预览的场景）
/// 3. 预览页用户修改参数时，直接修改此 provider 中的 EditorForm 实例
/// 4. 用户点击"同步到编辑器"按钮时，将当前 EditorForm 保留在 provider 中并 pop
/// 5. 编辑器 await push 返回后，读取此 provider；若非空，则将修改后的 form 复制回 _form
/// 6. 编辑器读取完毕后清空此 provider（设为 null），避免污染下次预览
final previewEditorFormProvider = StateProvider<EditorForm?>((ref) => null);
