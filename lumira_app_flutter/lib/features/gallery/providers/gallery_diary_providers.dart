import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../features/inspiration/data/inspiration_mock_data.dart';
import '../data/gallery_models.dart';

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
/// family 参数为视图 tab：[kDiaryTabOutfit] 仅展示带 sceneId 的照片，
/// [kDiaryTabShoot] 展示全部照片。每篇 entry 对应一个有照片的日期。
final diaryEntriesProvider =
    FutureProvider.family<List<DiaryEntry>, String>((ref, viewTab) async {
  final dao = await ref.watch(galleryDaoProvider.future);
  final scenesDao = await ref.watch(scenesDaoProvider.future);
  final templatesDao = await ref.watch(templatesDaoProvider.future);

  // 取最近 50 张，按天分组展示
  final records = await dao.getRecent(limit: 50);

  // 按 tab 过滤：outfit 仅含 sceneId 的照片
  final filtered = viewTab == kDiaryTabOutfit
      ? records.where((r) => r.sceneId != null && r.sceneId!.isNotEmpty).toList()
      : records;

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
      final mood = r.mood;
      if (mood != null && mood.isNotEmpty) {
        tags.add(DiaryTag(
          label: mood,
          color: DiaryTagColor.red,
          icon: Icons.sentiment_satisfied_outlined,
        ));
      }
      return DiaryPhoto(id: r.id, img: img, tags: tags);
    }).toList();

    return DiaryEntry(
      weekday: kDiaryWeekdayNames[day.weekday - 1],
      date: DateFormat('M月d日').format(day),
      photos: diaryPhotos,
      isToday: day == today,
    );
  }).toList();
});

/// 连续打卡天数（从今天起向前连续有照片的天数）
final diaryStreakProvider = FutureProvider<int>((ref) async {
  final dao = await ref.watch(galleryDaoProvider.future);
  final records = await dao.getAll();
  final daySet = <DateTime>{};
  for (final r in records) {
    final dt = DateTime.fromMillisecondsSinceEpoch(r.createdAt);
    daySet.add(DateTime(dt.year, dt.month, dt.day));
  }
  final now = DateTime.now();
  var cursor = DateTime(now.year, now.month, now.day);
  var streak = 0;
  while (daySet.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
});

/// 照片总数
final diaryTotalCountProvider = FutureProvider<int>((ref) async {
  final dao = await ref.watch(galleryDaoProvider.future);
  return dao.count();
});

/// 穿搭日记卡片数据：连续打卡天数 + 最近 2 张穿搭照片
final outfitDiaryCardProvider = FutureProvider<OutfitDiaryCardData>((ref) async {
  final streak = await ref.watch(diaryStreakProvider.future);
  final entries = await ref.watch(diaryEntriesProvider(kDiaryTabOutfit).future);
  final recentPhotos = <OutfitPhoto>[];
  if (entries.isNotEmpty) {
    final firstEntry = entries.first;
    for (final p in firstEntry.photos.take(2)) {
      recentPhotos.add(OutfitPhoto(imageSeed: p.img, date: firstEntry.date));
    }
  }
  return OutfitDiaryCardData(streak: streak, photos: recentPhotos);
});
