import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database_provider.dart';
import 'collections_dao.dart';

/// CollectionsDao Provider
/// 参考现有 DAO provider 写法（databaseProvider → DAO 实例）
final collectionsDaoProvider = FutureProvider<CollectionsDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return CollectionsDao(db);
});
