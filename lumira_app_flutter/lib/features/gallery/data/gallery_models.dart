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
    required this.photos,
    this.isToday = false,
  });

  final String weekday;
  final String date;
  final List<DiaryPhoto> photos;
  final bool isToday;
}

/// 日记 entry 中的照片
class DiaryPhoto {
  const DiaryPhoto({
    required this.img,
    required this.tags,
  });

  final String img;
  final List<DiaryTag> tags;
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
