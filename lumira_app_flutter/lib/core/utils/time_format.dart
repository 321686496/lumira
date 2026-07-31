/// 时间格式化工具（三端纯 Dart，无原生依赖）
///
/// 用于相册详情页显示照片拍摄时间：
/// - 相对时间（"刚刚" / "X 分钟前" / "X 小时前" / "X 天前"）
/// - 绝对时间（"YYYY-MM-DD HH:mm"）

/// 格式化相对时间。
///
/// 规则：
/// - < 60s → "刚刚"
/// - < 60min → "X 分钟前"
/// - < 24h → "X 小时前"
/// - < 7d → "X 天前"
/// - ≥ 7d → 返回空字符串（调用方应仅显示绝对时间）
String formatRelativeTime(int timestampMs) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final diff = now - timestampMs;
  if (diff < 60 * 1000) return '刚刚';
  if (diff < 60 * 60 * 1000) return '${diff ~/ (60 * 1000)} 分钟前';
  if (diff < 24 * 60 * 60 * 1000) return '${diff ~/ (60 * 60 * 1000)} 小时前';
  if (diff < 7 * 24 * 60 * 60 * 1000) {
    return '${diff ~/ (24 * 60 * 60 * 1000)} 天前';
  }
  return '';
}

/// 格式化绝对时间 "YYYY-MM-DD HH:mm"
String formatAbsoluteTime(int timestampMs) {
  final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  final y = dt.year;
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final h = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $h:$min';
}
