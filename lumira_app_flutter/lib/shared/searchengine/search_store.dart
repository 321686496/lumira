import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/dao/search_history_dao.dart';
import '../../core/db/database_provider.dart';
import 'search_scope.dart';

/// 搜索历史/热搜的封装（scope 维度隔离；scope=all 的多写/并集语义在此处理）。
class SearchStore {
  SearchStore(this._dao);

  final SearchHistoryDao _dao;

  /// 记录一次搜索。scope=all 时同步写入三个真实 scope。
  Future<void> record(SearchScope scope, String keyword) async {
    final k = keyword.trim();
    if (k.isEmpty) return;
    if (scope == SearchScope.all) {
      for (final s in SearchScopeExt.searchableScopes) {
        await _dao.upsert(s.name, k);
      }
    } else {
      await _dao.upsert(scope.name, k);
    }
  }

  /// 最近搜索关键词。scope=all 返回跨 scope 去重并集。
  Future<List<String>> recentKeywords(SearchScope scope, {int limit = 10}) async {
    final rows = scope == SearchScope.all
        ? await _dao.recentUnion(limit: limit)
        : await _dao.recent(scope.name, limit: limit);
    return rows.map((r) => r.keyword).toList();
  }

  /// 热门搜索：预置词 ∪ 自身高频历史，去重后限长。
  /// （子项目 B 云端热搜就绪后在此换成远程数据源即可。）
  Future<List<String>> hotKeywords(SearchScope scope, {int limit = 10}) async {
    final presets = kPresetHotWords[scope] ?? const <String>[];
    final top = scope == SearchScope.all
        ? const <String>[]
        : (await _dao.topByCount(scope.name))
            .map((r) => r.keyword)
            .toList();
    final seen = <String>{};
    final result = <String>[];
    for (final w in [...presets, ...top]) {
      if (seen.add(w)) result.add(w);
      if (result.length >= limit) break;
    }
    return result;
  }

  /// 删除单条关键词。scope=all 时跨三个真实 scope 删除。
  Future<void> deleteKeyword(SearchScope scope, String keyword) async {
    if (scope == SearchScope.all) {
      for (final s in SearchScopeExt.searchableScopes) {
        await _dao.delete(s.name, keyword);
      }
    } else {
      await _dao.delete(scope.name, keyword);
    }
  }

  /// 清空。scope=all 时清空全部三个 scope。
  Future<void> clear(SearchScope scope) async {
    if (scope == SearchScope.all) {
      for (final s in SearchScopeExt.searchableScopes) {
        await _dao.clear(s.name);
      }
    } else {
      await _dao.clear(scope.name);
    }
  }
}

final searchStoreProvider = FutureProvider<SearchStore>((ref) async {
  final dao = await ref.watch(searchHistoryDaoProvider.future);
  return SearchStore(dao);
});
