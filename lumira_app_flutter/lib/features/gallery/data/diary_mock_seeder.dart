import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/database_provider.dart';

/// 展示图⑤⑦「把生活拍成日记 / 相册·详情页·导出海报」mock 造数器。
///
/// [seed] 在 App 启动时直接调用（幂等，已存在则跳过）：把生成的资产图**复制成
/// 真实文件**到 `<getDatabasesPath()>/photos/`，并把 `filePath` 指向该绝对路径，
/// 同时写入相册表。这样一来：
/// - 相册/拍摄日记/详情页展示：LumiraImage 读真实文件，正常显示；
/// - 详情页「分享模板海报」导出：需要 `dart:io File(photoPath)`（`PosterRatio.fromFile`、
///   「仅支持本地照片」校验），用了真实本地文件才能成功生成/导出海报；
/// - 数据走真实代码路径：时间轴 / 连续打卡 / 月度统计 均有真实可见数据。
///
/// 普通 `flutter run` 启动或热重启都能直接看到数据（见 main.dart）。
///
/// 不再需要时：删除 main.dart 中的调用，并按需调用 [clear] 清理所有 `mockdiary_`
/// 前缀的记录及其复制出的本地文件（绝不动真实照片）。
class DiaryMockSeeder {
  DiaryMockSeeder._();

  /// mock 记录 id 前缀，用于识别与清理。
  static const String prefix = 'mockdiary_';

  static bool isMockId(String id) => id.startsWith(prefix);

  /// 幂等造数：若已存在 mock 记录则跳过。
  ///
  /// 若存在"旧格式"mock 记录（只有 filePath、无 dataUrl），则先清理再重新以
  /// 「dataUrl 内存解码 + 真实文件」新格式造数，从而在热重启后自动修复展示。
  static Future<void> seed(ProviderContainer container) async {
    final dao = await container.read(galleryDaoProvider.future);

    var existing = await dao.getAll();
    final stale = existing
        .where((r) => isMockId(r.id) && (r.dataUrl ?? '').isEmpty)
        .toList();
    if (stale.isNotEmpty) {
      await _deleteRecordsAndFiles(dao, stale);
      existing = await dao.getAll();
    }
    if (existing.any((r) => isMockId(r.id))) return;

    final photosDir = await _ensurePhotosDir();

    final days = _mockDays();
    final now = DateTime.now();
    final today0 = DateTime(now.year, now.month, now.day);

    for (var d = 0; d < days.length; d++) {
      final day = days[d];
      final createdAt = today0
          .subtract(Duration(days: day.offsetDays))
          .add(day.timeOfDay);

      for (var i = 0; i < day.images.length; i++) {
        final assetPath = day.images[i];
        final fileName = '${prefix}d${day.offsetDays}_$i.png';
        final file = File(p.join(photosDir.path, fileName));

        final raw = (await rootBundle.load(assetPath)).buffer.asUint8List();

        // 展示用 dataUrl：转更小的 JPEG 并以 base64 存库，应用从内存直接解码，
        // 不依赖 asset 是否打包、也不依赖设备文件路径，保证任意环境稳定显示。
        String? dataUrl;
        try {
          final decoded = img.decodeImage(raw);
          if (decoded != null) {
            final jpg = img.encodeJpg(decoded, quality: 80);
            dataUrl = 'data:image/jpeg;base64,${base64Encode(jpg)}';
          }
        } catch (_) {/* 转码失败则回退纯 filePath */}

        // 海报导出用真实全量 PNG 文件（详情页 PosterRatio.fromFile / 本地照片校验用）。
        if (!await file.exists()) {
          await file.writeAsBytes(raw, flush: true);
        }

        await dao.insert(GalleryItemRecord(
          id: '${prefix}d${day.offsetDays}_$i',
          dataUrl: dataUrl,
          filePath: file.path,
          templateId: day.templateId,
          mood: day.mood,
          createdAt: createdAt.millisecondsSinceEpoch,
        ));
      }
    }
  }

  /// 恢复原状：删除所有 `mockdiary_` 前缀记录并删除复制出的本地文件，返回清理条数。
  static Future<int> clear(ProviderContainer container) async {
    final dao = await container.read(galleryDaoProvider.future);
    final mock = (await dao.getAll())
        .where((r) => isMockId(r.id))
        .toList();
    return _deleteRecordsAndFiles(dao, mock);
  }

  /// 删除给定记录并同步删除其海报导出用的本地文件。
  static Future<int> _deleteRecordsAndFiles(
    GalleryDao dao,
    List<GalleryItemRecord> rows,
  ) async {
    var removed = 0;
    for (final r in rows) {
      await dao.delete(r.id);
      try {
        final path = r.filePath;
        if (path != null && path.contains('${prefix}d')) {
          final f = File(path);
          if (await f.exists()) {
            await f.delete();
          }
        }
      } catch (_) {/* 文件清理失败不影响记录清理 */}
      removed++;
    }
    return removed;
  }

  static Future<Directory> _ensurePhotosDir() async {
    final base = await getDatabasesPath();
    final photosDir = Directory(p.join(base, 'photos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    return photosDir;
  }

  /// 4 天连拍 → 连续打卡 streak=4；每天 2 张 → 时间轴每篇呈两列宫格。
  /// 模板均用内置（source != custom）模板，详情页才能导出模板海报。
  static List<_MockDay> _mockDays() => const [
    _MockDay(
      offsetDays: 0,
      timeOfDay: Duration(hours: 10, minutes: 20),
      images: [
        'assets/images/diary/mock_coffee_01.png',
        'assets/images/diary/mock_coffee_02.png',
      ],
      templateId: 'cafe_portrait',
      mood: '治愈',
    ),
    _MockDay(
      offsetDays: 1,
      timeOfDay: Duration(hours: 18, minutes: 45),
      images: [
        'assets/images/diary/mock_street_01.png',
        'assets/images/diary/mock_street_02.png',
      ],
      templateId: 'street_bw',
      mood: '甜酷',
    ),
    _MockDay(
      offsetDays: 2,
      timeOfDay: Duration(hours: 21, minutes: 5),
      images: [
        'assets/images/diary/mock_night_01.png',
        'assets/images/diary/mock_night_02.png',
      ],
      templateId: 'night_cityscape',
      mood: '文艺',
    ),
    _MockDay(
      offsetDays: 3,
      timeOfDay: Duration(hours: 9, minutes: 50),
      images: [
        'assets/images/diary/mock_still_01.png',
        'assets/images/diary/mock_still_02.png',
      ],
      templateId: 'still_life_warm',
      mood: '清新',
    ),
  ];
}

class _MockDay {
  const _MockDay({
    required this.offsetDays,
    required this.timeOfDay,
    required this.images,
    required this.templateId,
    required this.mood,
  });

  final int offsetDays;
  final Duration timeOfDay;
  final List<String> images;
  final String templateId;
  final String mood;
}