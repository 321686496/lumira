import 'package:flutter/material.dart';

import '../../../core/db/dao/gallery_dao.dart';

/// 相册照片视图模型（包装 GalleryItemRecord + 衍生展示字段）
class GalleryPhoto {
  const GalleryPhoto({
    required this.id,
    required this.displayUrl,
    required this.sceneId,
    required this.templateId,
    required this.mood,
    required this.lut,
    required this.createdAt,
  });

  final String id;
  /// 优先 dataUrl，回退 filePath
  final String? displayUrl;
  final String? sceneId;
  final String? templateId;
  final String? mood;
  final String? lut;
  final int createdAt;

  /// 从 DAO Record 转换
  factory GalleryPhoto.fromRecord(GalleryItemRecord r) {
    return GalleryPhoto(
      id: r.id,
      displayUrl: r.dataUrl ?? r.filePath,
      sceneId: r.sceneId,
      templateId: r.templateId,
      mood: r.mood,
      lut: r.lut,
      createdAt: r.createdAt,
    );
  }
}

/// 场景筛选 pill 数据
class SceneFilterPill {
  const SceneFilterPill({
    required this.key,
    required this.label,
    required this.count,
    this.icon,
  });

  /// 'all' / 'uncategorized' / 'scene_<sceneId>'
  final String key;
  final String label;
  final int count;
  final IconData? icon;
}

/// 日记时间轴 entry
class DiaryEntry {
  const DiaryEntry({
    required this.weekday,
    required this.date,
    required this.day,
    required this.photos,
    this.isToday = false,
  });

  final String weekday;
  final String date;

  /// 对应的具体日期（用于日期选择器标记「有照片的日期」）
  final DateTime day;
  final List<DiaryPhoto> photos;
  final bool isToday;
}

/// 日记 entry 中的照片
class DiaryPhoto {
  const DiaryPhoto({
    required this.id,
    required this.img,
    required this.tags,
    this.mood,
  });

  /// 照片 ID，用于点击跳转详情页
  final String id;
  final String img;
  final List<DiaryTag> tags;

  /// 照片心情（可空，用于叠加在照片角上展示）
  final String? mood;
}

/// 日记 entry 照片标签
class DiaryTag {
  const DiaryTag({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final DiaryTagColor color;
  final IconData icon;
}

/// 日记标签颜色
enum DiaryTagColor {
  gold,
  green,
  red,
}

/// 月度手帐封面统计项
class CoverStat {
  const CoverStat({required this.num, required this.label});
  final String num;
  final String label;
}

/// 月度手帐照片墙项（带比例）
class DigestGalleryPhoto {
  const DigestGalleryPhoto({required this.img, required this.ratio});
  final String img;
  final DigestPhotoRatio ratio;
}

/// 月度手帐照片墙比例
enum DigestPhotoRatio {
  ratio11, // 1:1
  ratio34, // 3:4
  ratio45, // 4:5
}

/// 月度手帐本月精选项
class DigestSelectedPhoto {
  const DigestSelectedPhoto({
    required this.img,
    required this.title,
    required this.date,
    required this.tag,
  });
  final String img;
  final String title;
  final String date;
  final String tag;
}

/// 月度手帐总结统计项
class SummaryStat {
  const SummaryStat({required this.num, required this.label});
  final String num;
  final String label;
}

/// 月度手帐场景足迹 pill
class DigestSceneTag {
  const DigestSceneTag({
    required this.icon,
    required this.label,
    required this.count,
  });
  final IconData icon;
  final String label;
  final int count;
}

/// 画册统计聚合数据（gallery_stats_page）
class GalleryStats {
  const GalleryStats({
    required this.totalCount,
    required this.thisWeekCount,
    required this.avgPerDay,
    required this.dailyCounts,
    required this.categoryRanks,
    required this.timeOfDayDistribution,
  });

  /// 照片总数
  final int totalCount;
  /// 本周（近 7 天）拍摄数
  final int thisWeekCount;
  /// 日均拍摄数（保留 1 位小数）
  final double avgPerDay;
  /// 近 7 天每日计数（长度 7，索引 0 = 6 天前，索引 6 = 今天）
  final List<int> dailyCounts;
  /// 拍摄分类排行（按数量降序）
  final List<CategoryRank> categoryRanks;
  /// 拍摄时段分布（4 项：上午/下午/傍晚/夜晚）
  final List<TimeSlot> timeOfDayDistribution;
}

/// 拍摄分类排行项
class CategoryRank {
  const CategoryRank({
    required this.label,
    required this.count,
    required this.percent,
  });
  final String label;
  final int count;
  /// 占比 0.0 - 1.0
  final double percent;
}

/// 拍摄时段分布项
class TimeSlot {
  const TimeSlot({
    required this.label,
    required this.icon,
    required this.count,
    required this.percent,
  });
  final String label;
  final IconData icon;
  final int count;
  /// 占比 0.0 - 1.0
  final double percent;
}
