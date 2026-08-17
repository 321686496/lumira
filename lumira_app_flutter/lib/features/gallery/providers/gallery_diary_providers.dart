import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/database_provider.dart';
import '../data/gallery_models.dart';

/// 本周某一天打卡状态（与首页 HomeStreakStatus 结构对齐）
class WeekDay {
  final String label;
  final bool done;
  final bool today;

  const WeekDay({required this.label, required this.done, required this.today});
}

/// 统一拍摄打卡状态
class ShootingCheckin {
  final int streakDays;
  final List<WeekDay> weekDays;
  final bool shotToday;

  const ShootingCheckin({
    required this.streakDays,
    required this.weekDays,
    required this.shotToday,
  });

  static const empty = ShootingCheckin(
    streakDays: 0,
    weekDays: [
      WeekDay(label: '一', done: false, today: false),
      WeekDay(label: '二', done: false, today: false),
      WeekDay(label: '三', done: false, today: false),
      WeekDay(label: '四', done: false, today: false),
      WeekDay(label: '五', done: false, today: false),
      WeekDay(label: '六', done: false, today: false),
      WeekDay(label: '日', done: false, today: false),
    ],
    shotToday: false,
  );
}

/// 拍摄日记筛选条件：tab（穿搭/拍摄）+ 可选心情
class DiaryFilter {
  const DiaryFilter({required this.tab, this.mood});

  final String tab;
  final String? mood;

  bool get isAllMood => mood == null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DiaryFilter && other.tab == tab && other.mood == mood;
  }

  @override
  int get hashCode => Object.hash(tab, mood);
}

/// 中文星期名（DateTime.weekday: 1=周一 ... 7=周日）
const List<String> kDiaryWeekdayNames = [
  '周一',
  '周二',
  '周三',
  '周四',
  '周五',
  '周六',
  '周日',
];

/// 视图 tab key
const String kDiaryTabOutfit = 'outfit'; // 穿搭日记：仅含 sceneId 的照片
const String kDiaryTabShoot = 'shoot'; // 拍摄日记：全部照片

/// 拍摄日记时间轴 entries（按天分组）
///
/// family 参数为筛选条件：[DiaryFilter.tab] 区分穿搭/拍摄视图，
/// [DiaryFilter.mood] 非空时仅保留该心情的照片。每篇 entry 对应一个有照片的日期。
final diaryEntriesProvider =
    FutureProvider.family<List<DiaryEntry>, DiaryFilter>((ref, filter) async {
  final dao = await ref.watch(galleryDaoProvider.future);
  final scenesDao = await ref.watch(scenesDaoProvider.future);
  final templatesDao = await ref.watch(templatesDaoProvider.future);

  // 取最近 50 张，按天分组展示
  final records = await dao.getRecent(limit: 50);

  // 按 tab 过滤：outfit 仅含 sceneId 的照片
  var filtered = filter.tab == kDiaryTabOutfit
      ? records.where((r) => r.sceneId != null && r.sceneId!.isNotEmpty).toList()
      : records;
  // 按心情过滤
  if (!filter.isAllMood) {
    filtered = filtered.where((r) => r.mood == filter.mood).toList();
  }

  // 预取 scene / template 名称用于派生标签
  final sceneNames = <String, String>{};
  final templateNames = <String, String>{};
  for (final r in filtered) {
    final sid = r.sceneId;
    if (sid != null && sid.isNotEmpty && !sceneNames.containsKey(sid)) {
      final s = await scenesDao.getById(sid);
      sceneNames[sid] = (s != null && s.name.isNotEmpty) ? s.name : sid;
    }
    final tid = r.templateId;
    if (tid != null && tid.isNotEmpty && !templateNames.containsKey(tid)) {
      final t = await templatesDao.getById(tid);
      templateNames[tid] = (t != null && t.name.isNotEmpty) ? t.name : tid;
    }
  }

  // 按天分组（保留插入顺序，DESC）
  final groups = <DateTime, List<GalleryItemRecord>>{};
  for (final r in filtered) {
    final dt = DateTime.fromMillisecondsSinceEpoch(r.createdAt);
    final day = DateTime(dt.year, dt.month, dt.day);
    groups.putIfAbsent(day, () => []).add(r);
  }
  final sortedDays = groups.keys.toList()..sort((a, b) => b.compareTo(a));

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  return sortedDays.map((day) {
    final photos = groups[day]!;
    final diaryPhotos = photos.map((r) {
      final tags = <DiaryTag>[];
      final img = (r.dataUrl ?? r.filePath) ?? '';
      final sid = r.sceneId;
      if (sid != null && sid.isNotEmpty) {
        tags.add(DiaryTag(
          label: sceneNames[sid] ?? sid,
          color: DiaryTagColor.gold,
          icon: Icons.place_outlined,
        ));
      }
      final tid = r.templateId;
      if (tid != null && tid.isNotEmpty) {
        tags.add(DiaryTag(
          label: templateNames[tid] ?? tid,
          color: DiaryTagColor.green,
          icon: Icons.photo_filter_outlined,
        ));
      }
      // 心情独立成字段（叠加在照片角上），不再混入下方标签
      final mood = r.mood;
      return DiaryPhoto(
        id: r.id,
        img: img,
        tags: tags,
        mood: (mood != null && mood.isNotEmpty) ? mood : null,
      );
    }).toList();

    return DiaryEntry(
      weekday: kDiaryWeekdayNames[day.weekday - 1],
      date: DateFormat('M月d日').format(day),
      photos: diaryPhotos,
      isToday: day == today,
    );
  }).toList();
});

/// 连续拍摄天数：复用 [shootingCheckinProvider] 的统一语义
/// （今天已拍从今天起算，今天未拍从昨天往回数），保证与首页/挑战页数字一致
final diaryStreakProvider = FutureProvider<int>((ref) async {
  final checkin = await ref.watch(shootingCheckinProvider.future);
  return checkin.streakDays;
});

/// 统一拍摄打卡状态 Provider：由相册照片表计算连续拍摄天数、本周 7 天状态、今日是否已拍
final shootingCheckinProvider = FutureProvider<ShootingCheckin>((ref) async {
  final dao = await ref.watch(galleryDaoProvider.future);
  final records = await dao.getAll();

  // 格式化日期工具函数
  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // 构建已拍摄日期集合
  final shotDates = <String>{};
  for (final r in records) {
    final dt = DateTime.fromMillisecondsSinceEpoch(r.createdAt);
    shotDates.add(_formatDate(dt));
  }

  // 计算本周 7 天状态（周一到周日）
  final now = DateTime.now();
  final dayOfWeek = now.weekday; // 1=Mon..7=Sun
  final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: dayOfWeek - 1));
  final today = DateTime(now.year, now.month, now.day);
  final todayStr = _formatDate(today);
  const labels = ['一', '二', '三', '四', '五', '六', '日'];

  final weekDays = <WeekDay>[];
  for (var i = 0; i < 7; i++) {
    final d = monday.add(Duration(days: i));
    final ds = _formatDate(d);
    weekDays.add(WeekDay(
      label: labels[i],
      done: shotDates.contains(ds),
      today: ds == todayStr,
    ));
  }

  // 计算连续拍摄天数：从今天往回数，今天已拍则从今天起算；否则从昨天往回数
  int streak = 0;
  if (shotDates.contains(todayStr)) {
    streak = 1;
    var cursor = today.subtract(const Duration(days: 1));
    while (shotDates.contains(_formatDate(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
  } else {
    final yesterday = today.subtract(const Duration(days: 1));
    var cursor = yesterday;
    while (shotDates.contains(_formatDate(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
  }

  return ShootingCheckin(
    streakDays: streak,
    weekDays: weekDays,
    shotToday: shotDates.contains(todayStr),
  );
});

/// 照片总数
final diaryTotalCountProvider = FutureProvider<int>((ref) async {
  final dao = await ref.watch(galleryDaoProvider.future);
  return dao.count();
});

/// 月度统计：本月照片数 / 打卡天数 / 最常心情 / 常去场景 / 当前连续天数
class DiaryMonthlyStats {
  final int thisMonthPhotos;
  final int thisMonthDays;
  final String? mostCommonMood;
  final String? mostCommonScene;
  final int currentStreak;

  const DiaryMonthlyStats({
    required this.thisMonthPhotos,
    required this.thisMonthDays,
    this.mostCommonMood,
    this.mostCommonScene,
    required this.currentStreak,
  });
}

/// 本月统计 Provider：聚合本月照片数、打卡天数、最常心情、常去场景
final diaryMonthlyStatsProvider = FutureProvider<DiaryMonthlyStats>((ref) async {
  final dao = await ref.watch(galleryDaoProvider.future);
  final now = DateTime.now();
  final records = await dao.getByMonth(now.year, now.month);

  final daySet = <DateTime>{};
  final moodCounts = <String, int>{};
  final sceneCounts = <String, int>{};

  for (final r in records) {
    final dt = DateTime.fromMillisecondsSinceEpoch(r.createdAt);
    daySet.add(DateTime(dt.year, dt.month, dt.day));
    if (r.mood != null && r.mood!.isNotEmpty) {
      moodCounts[r.mood!] = (moodCounts[r.mood!] ?? 0) + 1;
    }
    if (r.sceneId != null && r.sceneId!.isNotEmpty) {
      sceneCounts[r.sceneId!] = (sceneCounts[r.sceneId!] ?? 0) + 1;
    }
  }

  String? topMood;
  if (moodCounts.isNotEmpty) {
    topMood = moodCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
  String? topScene;
  if (sceneCounts.isNotEmpty) {
    topScene = sceneCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  final streak = await ref.watch(diaryStreakProvider.future);

  return DiaryMonthlyStats(
    thisMonthPhotos: records.length,
    thisMonthDays: daySet.length,
    mostCommonMood: topMood,
    mostCommonScene: topScene,
    currentStreak: streak,
  );
});

