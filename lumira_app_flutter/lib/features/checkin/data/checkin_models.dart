import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/tables.dart';

/// 探店打卡主表记录
class CheckinRecord {
  const CheckinRecord({
    required this.id,
    required this.name,
    this.place = '',
    this.category = '',
    this.rating = 0,
    this.note = '',
    required this.visitedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String place;
  final String category;
  final int rating;
  final String note;
  final int visitedAt;
  final int createdAt;
  final int updatedAt;

  Map<String, Object?> toRow() {
    return {
      CheckinTable.colId: id,
      CheckinTable.colName: name,
      CheckinTable.colPlace: place,
      CheckinTable.colCategory: category,
      CheckinTable.colRating: rating,
      CheckinTable.colNote: note,
      CheckinTable.colVisitedAt: visitedAt,
      CheckinTable.colCreatedAt: createdAt,
      CheckinTable.colUpdatedAt: updatedAt,
    };
  }

  static CheckinRecord fromRow(Map<String, Object?> row) {
    return CheckinRecord(
      id: row[CheckinTable.colId] as String,
      name: row[CheckinTable.colName] as String,
      place: (row[CheckinTable.colPlace] as String?) ?? '',
      category: (row[CheckinTable.colCategory] as String?) ?? '',
      rating: (row[CheckinTable.colRating] as num?)?.toInt() ?? 0,
      note: (row[CheckinTable.colNote] as String?) ?? '',
      visitedAt: (row[CheckinTable.colVisitedAt] as num).toInt(),
      createdAt: (row[CheckinTable.colCreatedAt] as num).toInt(),
      updatedAt: (row[CheckinTable.colUpdatedAt] as num).toInt(),
    );
  }
}

/// 列表项：足迹记录 + 封面图 URL（首张照片，无则 null）
class CheckinListItem {
  const CheckinListItem({required this.record, this.coverPhotoUrl});

  final CheckinRecord record;
  final String? coverPhotoUrl;
}

/// 详情：足迹记录 + 关联照片（按 position 排序）
class CheckinDetail {
  const CheckinDetail({required this.record, required this.photos});

  final CheckinRecord record;
  final List<GalleryItemRecord> photos;
}
