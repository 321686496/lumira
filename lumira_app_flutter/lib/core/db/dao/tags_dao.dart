import 'package:sqflite/sqflite.dart';

import '../tables.dart';

/// 可打标签的内容类型
class TagItemType {
  TagItemType._();
  static const String template = 'template';
  static const String scene = 'scene';
}

/// 一条用户标签（user_tags 行）
class UserTag {
  const UserTag({required this.id, required this.name, required this.createdAt});

  final int id;
  final String name;
  final int createdAt;

  factory UserTag.fromRow(Map<String, Object?> row) => UserTag(
        id: row[Tables.colId] as int,
        name: row[Tables.colName] as String,
        createdAt: (row[Tables.colCreatedAt] as num).toInt(),
      );
}

/// 标签 + 关联内容数量（标签夹/筛选栏展示）
class TagWithCount {
  const TagWithCount({required this.tag, required this.count});

  final UserTag tag;
  final int count;
}

class TagsDao {
  TagsDao(this._db);

  final Database _db;

  /// 归一化标签名：trim + 长度截断（最长 20 字）
  static String normalize(String name) {
    final t = name.trim();
    if (t.length > 20) return t.substring(0, 20);
    return t;
  }

  /// 确保标签字典中存在 name，返回其 id（不存在则创建，同名复用）。
  Future<int> touchTag(String name) async {
    final normalized = normalize(name);
    if (normalized.isEmpty) {
      throw ArgumentError('label name must not be empty');
    }
    final rows = await _db.query(
      Tables.userTags,
      columns: [Tables.colId],
      where: '${Tables.colName} = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return rows.first[Tables.colId] as int;
    }
    return _db.insert(Tables.userTags, {
      Tables.colName: normalized,
      Tables.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 为某条目打一个标签（同名标签跨条目复用；重复绑定自动忽略，返回 tagId）。
  Future<int> addTag({
    required String itemType,
    required String itemId,
    required String name,
  }) async {
    final tagId = await touchTag(name);
    await _db.insert(Tables.itemTags, {
      Tables.colItemType: itemType,
      Tables.colItemId: itemId,
      Tables.colTagId: tagId,
      Tables.colCreatedAt: DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    return tagId;
  }

  /// 全量替换某条目的标签集合（names 为空则清空）。编辑场景下一次性保存用。
  Future<void> setTags({
    required String itemType,
    required String itemId,
    required List<String> names,
  }) async {
    await _db.delete(
      Tables.itemTags,
      where: '${Tables.colItemType} = ? AND ${Tables.colItemId} = ?',
      whereArgs: [itemType, itemId],
    );
    for (final name in names) {
      final normalized = normalize(name);
      if (normalized.isEmpty) continue;
      await addTag(itemType: itemType, itemId: itemId, name: normalized);
    }
  }

  /// 取消某条目上的某标签绑定。
  Future<void> removeTag({
    required String itemType,
    required String itemId,
    required int tagId,
  }) async {
    await _db.delete(
      Tables.itemTags,
      where:
          '${Tables.colItemType} = ? AND ${Tables.colItemId} = ? AND ${Tables.colTagId} = ?',
      whereArgs: [itemType, itemId, tagId],
    );
  }

  /// 删除一个标签（级联删除其所有绑定；sqflite 需手动删绑定再删字典行）。
  Future<void> deleteTag(int tagId) async {
    await _db.delete(
      Tables.itemTags,
      where: '${Tables.colTagId} = ?',
      whereArgs: [tagId],
    );
    await _db.delete(
      Tables.userTags,
      where: '${Tables.colId} = ?',
      whereArgs: [tagId],
    );
  }

  /// 标签改名（新名归一化，若与现有标签重名则复用后者并合并绑定）。
  Future<void> renameTag(int tagId, String newName) async {
    final normalized = normalize(newName);
    if (normalized.isEmpty) return;
    final existed = await _db.query(
      Tables.userTags,
      columns: [Tables.colId],
      where: '${Tables.colId} != ? AND ${Tables.colName} = ?',
      whereArgs: [tagId, normalized],
      limit: 1,
    );
    if (existed.isNotEmpty) {
      final target = existed.first[Tables.colId] as int;
      // 合并绑定到目标 id
      await _db.rawInsert(
        'INSERT OR IGNORE INTO ${Tables.itemTags}'
        '(${Tables.colItemType}, ${Tables.colItemId}, ${Tables.colTagId}, ${Tables.colCreatedAt})'
        ' SELECT ${Tables.colItemType}, ${Tables.colItemId}, ?, ${Tables.colCreatedAt}'
        ' FROM ${Tables.itemTags} WHERE ${Tables.colTagId} = ?',
        [target, tagId],
      );
      await deleteTag(tagId);
      return;
    }
    await _db.update(
      Tables.userTags,
      {Tables.colName: normalized},
      where: '${Tables.colId} = ?',
      whereArgs: [tagId],
    );
  }

  /// 某条目的全部用户标签。
  Future<List<UserTag>> tagsFor({
    required String itemType,
    required String itemId,
  }) async {
    final rows = await _db.rawQuery('''
      SELECT u.* FROM ${Tables.userTags} u
      INNER JOIN ${Tables.itemTags} b ON b.${Tables.colTagId} = u.${Tables.colId}
      WHERE b.${Tables.colItemType} = ? AND b.${Tables.colItemId} = ?
      ORDER BY u.${Tables.colId}
    ''', [itemType, itemId]);
    return rows.map(UserTag.fromRow).toList();
  }

  /// 某标签下指定类型的所有条目 id。
  Future<List<String>> itemIdsByTag({
    required String itemType,
    required int tagId,
  }) async {
    final rows = await _db.query(
      Tables.itemTags,
      columns: [Tables.colItemId],
      where: '${Tables.colItemType} = ? AND ${Tables.colTagId} = ?',
      whereArgs: [itemType, tagId],
    );
    return rows.map((r) => r[Tables.colItemId] as String).toList();
  }

  /// 某条目已绑定的 tag id 集合（供“已打标签”判断/剔除）。
  Future<Set<int>> tagIdsFor({
    required String itemType,
    required String itemId,
  }) async {
    final rows = await _db.query(
      Tables.itemTags,
      columns: [Tables.colTagId],
      where: '${Tables.colItemType} = ? AND ${Tables.colItemId} = ?',
      whereArgs: [itemType, itemId],
    );
    return rows.map((r) => r[Tables.colTagId] as int).toSet();
  }

  /// 全部用户标签（含各自 count），可选按 itemType 过滤。
  Future<List<TagWithCount>> allTags({String? itemType}) async {
    final whereType = itemType != null;
    final rows = await _db.rawQuery('''
      SELECT u.${Tables.colId}, u.${Tables.colName}, u.${Tables.colCreatedAt},
             COUNT(b.${Tables.colItemType}) AS cnt
      FROM ${Tables.userTags} u
      LEFT JOIN ${Tables.itemTags} b ON b.${Tables.colTagId} = u.${Tables.colId}
        ${whereType ? 'AND b.${Tables.colItemType} = ?' : ''}
      GROUP BY u.${Tables.colId}
      ORDER BY cnt DESC, u.${Tables.colName}
    ''', whereType ? [itemType] : []);
    return rows.map((r) => TagWithCount(
      tag: UserTag.fromRow(r),
      count: (r['cnt'] as num?)?.toInt() ?? 0,
    )).toList();
  }

  /// 标签名模糊匹配关键词，返回命中的 tag id 列表（搜索“匹配标签名”用）。
  Future<List<int>> matchingTagIds(String query) async {
    final key = '%$query%';
    final rows = await _db.query(
      Tables.userTags,
      columns: [Tables.colId],
      where: '${Tables.colName} LIKE ?',
      whereArgs: [key],
    );
    return rows.map((r) => r[Tables.colId] as int).toList();
  }
}