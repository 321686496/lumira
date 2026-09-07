// lib/features/templates/data/builtin_silhouettes.dart

/// 内置剪影库（asset 路径映射）
///
/// 剪影为黑色线条风格 PNG（透明背景），存放于 assets/images/silhouettes/。
/// 此文件为剪影数据的唯一真实源（source of truth）。
class BuiltinSilhouettes {
  BuiltinSilhouettes._();

  /// 无姿势占位（空字符串）
  static const String noneSvg = '';

  /// 内置剪影 key → asset 路径映射
  static const Map<String, String> assetMap = {
    'standing-profile': 'assets/images/silhouettes/standing-profile.png',
    'sitting-cafe': 'assets/images/silhouettes/sitting-cafe.png',
    'walking-street': 'assets/images/silhouettes/walking-street.png',
    'soft-portrait': 'assets/images/silhouettes/soft-portrait.png',
    'neon-pose': 'assets/images/silhouettes/neon-pose.png',
    'vintage-portrait': 'assets/images/silhouettes/vintage-portrait.png',
    'peace-sign-girl': 'assets/images/silhouettes/peace-sign-girl.png',
    'food-overhead': 'assets/images/silhouettes/food-overhead.png',
    'cityscape-tripod': 'assets/images/silhouettes/cityscape-tripod.png',
    'landscape-wide': 'assets/images/silhouettes/landscape-wide.png',
    'macro-flower': 'assets/images/silhouettes/macro-flower.png',
    'still-life-table': 'assets/images/silhouettes/still-life-table.png',
  };

  /// 所有内置剪影 key 列表（排除 'none'）
  static const List<String> keys = [
    'standing-profile', 'sitting-cafe', 'walking-street', 'soft-portrait',
    'neon-pose', 'vintage-portrait', 'peace-sign-girl', 'food-overhead',
    'cityscape-tripod', 'landscape-wide', 'macro-flower', 'still-life-table',
  ];

  /// 内置剪影友好名称映射（中文）
  static const Map<String, String> friendlyNames = {
    'standing-profile': '站立侧影',
    'sitting-cafe': '坐姿咖啡',
    'walking-street': '街拍行走',
    'soft-portrait': '柔和肖像',
    'neon-pose': '霓虹姿势',
    'vintage-portrait': '复古肖像',
    'peace-sign-girl': '比心女孩',
    'food-overhead': '美食俯拍',
    'cityscape-tripod': '城市三脚架',
    'landscape-wide': '广角风景',
    'macro-flower': '微距花卉',
    'still-life-table': '静物桌面',
  };

  /// 根据 key 获取友好名称
  static String getFriendlyName(String key) {
    return friendlyNames[key] ?? key;
  }
}

/// 顶层常量导出（便于直接引用）
const List<String> kBuiltinSilhouetteKeys = BuiltinSilhouettes.keys;
const Map<String, String> kBuiltinSilhouettes = BuiltinSilhouettes.assetMap;
