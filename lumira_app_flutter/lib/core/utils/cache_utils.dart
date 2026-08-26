import 'package:flutter/painting.dart';

import '../db/dao/api_cache_dao.dart';
import 'image_cache.dart';

/// 字节数人类可读格式化：B / KB / MB / GB
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

/// 应用缓存统计与清理（供设置页展示 / 缓存详情页使用）
///
/// 覆盖三类缓存：
/// - 图片磁盘缓存（[ImageCacheUtil] 的 image_cache 目录文件）
/// - 图片内存缓存（Flutter 解码缓存 + [ImageCacheUtil] 内存缓存）
/// - API 离线缓存（api_cache 表）
class CacheInfo {
  CacheInfo._();

  /// 图片磁盘缓存字节数
  static Future<int> diskImageCacheBytes() =>
      ImageCacheUtil.calculateDiskCacheBytes();

  /// 图片内存缓存字节数（Flutter 解码缓存 + ImageCacheUtil 内存）
  static int memoryImageCacheBytes() {
    final decoded = PaintingBinding.instance.imageCache.currentSizeBytes;
    return decoded + ImageCacheUtil.memoryCacheBytes;
  }

  /// API 离线缓存字节数
  static Future<int> apiCacheBytes(ApiCacheDao dao) => dao.payloadBytes();

  /// 全部缓存字节数（磁盘 + 内存 + API）
  static Future<int> totalBytes(ApiCacheDao dao) async {
    var total = 0;
    total += await diskImageCacheBytes();
    total += memoryImageCacheBytes();
    total += await apiCacheBytes(dao);
    return total;
  }

  /// 清空图片磁盘缓存
  static Future<void> clearDiskImageCache() => ImageCacheUtil.clearCache();

  /// 清空图片内存缓存（Flutter 解码缓存 + ImageCacheUtil 内存）
  static void clearMemoryImageCache() {
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.clear();
    imageCache.clearLiveImages();
    ImageCacheUtil.clearMemoryOnly();
  }

  /// 清空 API 离线缓存
  static Future<void> clearApiCache(ApiCacheDao dao) => dao.clearAll();
}
