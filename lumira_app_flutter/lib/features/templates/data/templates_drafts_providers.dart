import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import 'templates_management_mock_data.dart';

/// 草稿列表（真实数据，构造函数读 template_drafts 表）。在保存/删除/恢复草稿后
/// 通过 `ref.invalidate(draftsListProvider)` 刷新。
final draftsListProvider = FutureProvider<List<DraftItem>>((ref) async {
  final dao = await ref.watch(templatesDraftsDaoProvider.future);
  return dao.getAll();
});