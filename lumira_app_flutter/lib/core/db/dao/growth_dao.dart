import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../tables.dart';
import '../../../features/profile/data/growth_models.dart';

/// 经验来源 → 展示文案
const Map<String, String> kXpSourceLabel = {
  'shoot_daily': '每日首拍',
  'challenge': '完成挑战',
  'course': '学习课程',
  'share': '每日首享',
};

/// 成长中心只读 DAO
/// 聚合 user_progress / challenge_history / gallery_items / academy_course_progress 表
class GrowthDao {
  GrowthDao(this._db);

  final Database _db;

  /// 获取总 XP：经验台账 xp_events 求和（真实数据）。
  Future<int> getTotalXP() async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(${XpEventsTable.colAmount}), 0) AS s FROM ${XpEventsTable.name}',
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// 获取用户累计拍摄照片数（user_progress.total_photos）。
  /// 用于首页 Banner 推荐算法的新老用户分层判断（< 3 视为新用户）。
  ///
  /// 兜底合并：以 gallery_items 真实行数为准（历史版本 total_photos 从未随拍摄
  /// 递增，导致该值恒为 0、用户被永远判定为新用户、首槽一直被推"新手友好场景"），
  /// 此处返回 max(已存值, 实际相册照片数) 作为自愈，避免再出现类似问题。
  Future<int> getTotalPhotos() async {
    var stored = 0;
    try {
      final rows = await _db.query(
        Tables.userProgress,
        where: '${Tables.colId} = ?',
        whereArgs: [1],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final v = rows.first[Tables.colTotalPhotos];
        if (v != null) stored = (v as num).toInt();
      }
    } catch (_) {
      // 表/记录异常时忽略已存值，走实际相册行数
    }
    // 兜底：直接 COUNT gallery_items
    final cntRows = await _db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM ${Tables.galleryItems}',
    );
    final actual = Sqflite.firstIntValue(cntRows) ?? 0;
    return stored > actual ? stored : actual;
  }

  /// 当前等级（阶梯阈值表 Lv.1–20）。
  Future<int> getLevel() async {
    final xp = await getTotalXP();
    return levelForXp(xp);
  }

  /// 当前等级称号。
  Future<String> getLevelName() async {
    final level = await getLevel();
    return levelNameFor(level) ?? '';
  }

  /// 成长总览（等级进度）。
  Future<GrowthSummary> getSummary() async {
    final xp = await getTotalXP();
    final level = levelForXp(xp);
    // 距下一级 = 下一级阈值 - 当前总XP；已达最高级(Lv.20)则为 0
    final next = LEVEL_THRESHOLDS.where((t) => t.level == level + 1).toList();
    final raw = next.isEmpty ? 0 : (next.first.xp - xp);
    return GrowthSummary(
      level: level,
      currentXp: xp,
      xpToNextLevel: raw < 0 ? 0 : raw,
      levelName: levelNameFor(level) ?? '',
    );
  }

  /// 经验来源明细：按 source 求和 + 占比，固定展示顺序（shoot_daily, challenge, course, share）。
  Future<List<XpBreakdownEntry>> getXpBreakdown() async {
    final rows = await _db.rawQuery('''
      SELECT ${XpEventsTable.colSource} AS src,
             SUM(${XpEventsTable.colAmount}) AS s
      FROM ${XpEventsTable.name}
      GROUP BY ${XpEventsTable.colSource}
    ''');
    var total = 0;
    for (final r in rows) {
      total += (r['s'] as num?)?.toInt() ?? 0;
    }
    if (total <= 0) return const [];
    int sourceOrder(String key) => kXpSourceLabel.keys.toList().indexOf(key);
    final list = <XpBreakdownEntry>[];
    for (final r in rows) {
      final src = r['src'] as String? ?? '';
      final amount = (r['s'] as num?)?.toInt() ?? 0;
      if (amount <= 0) continue;
      list.add(XpBreakdownEntry(
        source: src,
        amount: amount,
        label: kXpSourceLabel[src] ?? src,
        ratio: amount / total,
      ));
    }
    list.sort((a, b) => sourceOrder(a.source).compareTo(sourceOrder(b.source)));
    return list;
  }

  /// 获取成就墙（6 项）。
  /// 优先从 user_progress.achievements_json 反序列化；无记录时返回 6 项占位。
  Future<List<AchievementRecord>> getAchievements() async {
    final rows = await _db.query(Tables.userProgress, where: '${Tables.colId} = ?', whereArgs: [1]);
    if (rows.isEmpty) return _withRealLevel(kPlaceholderAchievements);

    final raw = rows.first[Tables.colAchievementsJson] as String?;
    if (raw == null || raw.isEmpty || raw == '[]') {
      return _withRealLevel(kPlaceholderAchievements);
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final unlockedMap = <String, int>{};
      for (final item in list) {
        final m = item as Map<String, dynamic>;
        final id = m['id'] as String?;
        final ts = m['unlockedAt'] as int?;
        if (id != null) unlockedMap[id] = ts ?? 0;
      }
      final result = kPlaceholderAchievements.map((a) {
        if (unlockedMap.containsKey(a.id)) {
          return AchievementRecord(
            id: a.id,
            name: a.name,
            description: a.description,
            iconKey: a.iconKey,
            unlocked: true,
            unlockedAt: unlockedMap[a.id],
          );
        }
        return a;
      }).toList();
      return await _withRealLevel(result);
    } catch (_) {
      return _withRealLevel(kPlaceholderAchievements);
    }
  }

  /// 按真实等级（阈值表）修正 ach_level_5 解锁状态：真实等级 ≥ 5 则强制解锁。
  Future<List<AchievementRecord>> _withRealLevel(List<AchievementRecord> source) async {
    final level = await getLevel();
    if (level < 5) return source;
    return source.map((a) {
      if (a.id != 'ach_level_5' || a.unlocked) return a;
      return AchievementRecord(
        id: a.id,
        name: a.name,
        description: a.description,
        iconKey: a.iconKey,
        unlocked: true,
        unlockedAt: a.unlockedAt ?? DateTime.now().millisecondsSinceEpoch,
      );
    }).toList();
  }

  /// 获取成长轨迹（最近 4 条，时间倒序）。
  /// 聚合 challenge_history.completed_at + gallery_items.created_at（milestone）
  /// 简化：仅聚合这两条流；academy_course_progress 完成事件在 M6 任务接入
  Future<List<GrowthTrajectoryRecord>> getGrowthTrajectory() async {
    final challengeRows = await _db.rawQuery('''
      SELECT ${ChallengeHistoryTable.colId} AS eid,
             ${ChallengeHistoryTable.colTitle} AS title,
             ${ChallengeHistoryTable.colCompletedAt} AS ts
      FROM ${ChallengeHistoryTable.name}
      WHERE ${ChallengeHistoryTable.colStatus} = ? AND ${ChallengeHistoryTable.colCompletedAt} IS NOT NULL
    ''', ['done']);

    final galleryRows = await _db.rawQuery('''
      SELECT ${Tables.colId} AS eid, ${Tables.colCreatedAt} AS ts
      FROM ${Tables.galleryItems}
      ORDER BY ${Tables.colCreatedAt} ASC
    ''');

    final events = <GrowthTrajectoryRecord>[];
    for (final r in challengeRows) {
      events.add(GrowthTrajectoryRecord(
        eventId: r['eid'] as String,
        type: 'challenge',
        title: r['title'] as String? ?? '挑战完成',
        timestamp: (r['ts'] as num).toInt(),
      ));
    }
    // gallery 取首张作为里程碑
    if (galleryRows.isNotEmpty) {
      final first = galleryRows.first;
      events.add(GrowthTrajectoryRecord(
        eventId: first['eid'] as String,
        type: 'milestone',
        title: '首次拍摄',
        timestamp: (first['ts'] as num).toInt(),
      ));
    }

    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return events.take(4).toList();
  }

  /// 获取每日活跃度（用于 112 格热力图）。
  /// 聚合 challenge_history.completed_at + gallery_items.created_at 按日期 GROUP BY。
  Future<Map<String, int>> getDailyActivity() async {
    final rows = await _db.rawQuery('''
      SELECT date(${ChallengeHistoryTable.colCompletedAt} / 1000, 'unixepoch') AS d, COUNT(*) AS c
      FROM ${ChallengeHistoryTable.name}
      WHERE ${ChallengeHistoryTable.colStatus} = ? AND ${ChallengeHistoryTable.colCompletedAt} IS NOT NULL
      GROUP BY d
      UNION ALL
      SELECT date(${Tables.colCreatedAt} / 1000, 'unixepoch') AS d, COUNT(*) AS c
      FROM ${Tables.galleryItems}
      WHERE ${Tables.colCreatedAt} IS NOT NULL AND ${Tables.colCreatedAt} > 0
      GROUP BY d
    ''', ['done']);
    final result = <String, int>{};
    for (final r in rows) {
      final d = r['d'] as String?;
      final c = (r['c'] as num?)?.toInt() ?? 0;
      if (d != null) result[d] = (result[d] ?? 0) + c;
    }
    return result;
  }

  /// 获取某日（YYYY-MM-DD，UTC 口径，与 getDailyActivity 一致）拍摄的照片（缩略图展示用）。
  /// 排除从系统相册引入且隐藏的项。
  Future<List<DayPhoto>> getPhotosByDate(String date) async {
    final rows = await _db.query(
      Tables.galleryItems,
      where: "date(${Tables.colCreatedAt} / 1000, 'unixepoch') = ? "
          'AND (${Tables.colGalleryItemHidden} IS NULL OR ${Tables.colGalleryItemHidden} != 1)',
      whereArgs: [date],
      orderBy: '${Tables.colCreatedAt} DESC',
    );
    return rows.map((r) {
      final thumb =
          (r[Tables.colDataUrl] as String?) ?? (r[Tables.colFilePath] as String?) ?? '';
      return DayPhoto(
        id: r[Tables.colId] as String,
        thumb: thumb,
        createdAt: (r[Tables.colCreatedAt] as num).toInt(),
      );
    }).toList();
  }

  /// 获取某日（YYYY-MM-DD）完成挑战的标题列表。
  Future<List<String>> getChallengesByDate(String date) async {
    final rows = await _db.query(
      ChallengeHistoryTable.name,
      where: '${ChallengeHistoryTable.colStatus} = ? '
          'AND ${ChallengeHistoryTable.colCompletedAt} IS NOT NULL '
          "AND date(${ChallengeHistoryTable.colCompletedAt} / 1000, 'unixepoch') = ?",
      whereArgs: ['done', date],
      orderBy: '${ChallengeHistoryTable.colCompletedAt} DESC',
    );
    return rows
        .map((r) => (r[ChallengeHistoryTable.colTitle] as String?) ?? '挑战完成')
        .toList();
  }

  /// 组装某日详情（照片 + 挑战），供热力图格子点击后的弹层展示。
  Future<DayActivityDetail> getDayDetail(String date) async {
    final photos = await getPhotosByDate(date);
    final challenges = await getChallengesByDate(date);
    return DayActivityDetail(
      date: date,
      photoCount: photos.length,
      challengeCount: challenges.length,
      photos: photos,
      challenges: challenges,
    );
  }
}
