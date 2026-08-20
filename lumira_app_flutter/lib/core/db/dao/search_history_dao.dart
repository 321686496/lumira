import 'package:sqflite/sqflite.dart';

import '../tables.dart';

/// 搜索历史单条记录。
class SearchHistoryRecord {
  final int id;
  final String scope; // 'template' | 'scene' | 'academy'
  final String keyword;
  final int searchCount;
  final int lastSearchedAt;

  const SearchHistoryRecord({
    required this.id,
    required this.scope,
    required this.keyword,
    required this.searchCount,
    required this.lastSearchedAt,
  });
}

/// 搜索历史 DAO（scope 维度隔离；DAO 本身只认字符串，scope=all 的语义由 SearchStore 处理）。
class SearchHistoryDao {
  SearchHistoryDao(this._db);

  final Database _db;

  /// 同 scope+keyword 去重：累加 search_count 并刷新 last_searched_at。
  Future<void> upsert(String scope, String keyword) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _db.query(
      SearchHistoryTable.name,
      where:
          '${SearchHistoryTable.colScope} = ? AND ${SearchHistoryTable.colKeyword} = ?',
      whereArgs: [scope, keyword],
      limit: 1,
    );
    if (existing.isEmpty) {
      await _db.insert(SearchHistoryTable.name, {
        SearchHistoryTable.colScope: scope,
        SearchHistoryTable.colKeyword: keyword,
        SearchHistoryTable.colSearchCount: 1,
        SearchHistoryTable.colLastSearchedAt: now,
      });
    } else {
      final id = existing.first[SearchHistoryTable.colId];
      final count =
          (existing.first[SearchHistoryTable.colSearchCount] as num).toInt();
      await _db.update(
        SearchHistoryTable.name,
        {
          SearchHistoryTable.colSearchCount: count + 1,
          SearchHistoryTable.colLastSearchedAt: now,
        },
        where: '${SearchHistoryTable.colId} = ?',
        whereArgs: [id],
      );
    }
  }

  /// 某 scope 最近历史（last_searched_at 倒序）。
  Future<List<SearchHistoryRecord>> recent(
    String scope, {
    int limit = 10,
  }) async {
    final rows = await _db.query(
      SearchHistoryTable.name,
      where: '${SearchHistoryTable.colScope} = ?',
      whereArgs: [scope],
      orderBy: '${SearchHistoryTable.colLastSearchedAt} DESC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  /// 全 scope 并集：按 keyword 去重（保留最新一条），按 last_searched_at 倒序。
  Future<List<SearchHistoryRecord>> recentUnion({int limit = 10}) async {
    final rows = await _db.query(
      SearchHistoryTable.name,
      orderBy: '${SearchHistoryTable.colLastSearchedAt} DESC',
    );
    final seen = <String>{};
    final result = <SearchHistoryRecord>[];
    for (final r in rows) {
      final rec = _fromRow(r);
      if (seen.add(rec.keyword)) result.add(rec);
      if (result.length >= limit) break;
    }
    return result;
  }

  /// 某 scope 高频历史（search_count 降序，热搜候选）。
  Future<List<SearchHistoryRecord>> topByCount(
    String scope, {
    int limit = 10,
  }) async {
    final rows = await _db.query(
      SearchHistoryTable.name,
      where: '${SearchHistoryTable.colScope} = ?',
      whereArgs: [scope],
      orderBy:
          '${SearchHistoryTable.colSearchCount} DESC, ${SearchHistoryTable.colLastSearchedAt} DESC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  /// 删除某 scope 的单条关键词。
  Future<void> delete(String scope, String keyword) async {
    await _db.delete(
      SearchHistoryTable.name,
      where:
          '${SearchHistoryTable.colScope} = ? AND ${SearchHistoryTable.colKeyword} = ?',
      whereArgs: [scope, keyword],
    );
  }

  /// 清空某 scope。
  Future<void> clear(String scope) async {
    await _db.delete(
      SearchHistoryTable.name,
      where: '${SearchHistoryTable.colScope} = ?',
      whereArgs: [scope],
    );
  }

  SearchHistoryRecord _fromRow(Map<String, Object?> row) => SearchHistoryRecord(
        id: (row[SearchHistoryTable.colId] as num).toInt(),
        scope: row[SearchHistoryTable.colScope] as String,
        keyword: row[SearchHistoryTable.colKeyword] as String,
        searchCount: (row[SearchHistoryTable.colSearchCount] as num).toInt(),
        lastSearchedAt:
            (row[SearchHistoryTable.colLastSearchedAt] as num).toInt(),
      );
}
