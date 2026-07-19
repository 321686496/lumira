/// 草稿项（drafts 页用）
///
/// 视觉规格来源：lumira-app/src/pages/templates/drafts.vue 的 TemplateDraft
/// 简化结构：将 uni-app 的 draft.template.meta.category / draft.template.camera.* 拍平到顶层字段
class DraftItem {
  const DraftItem({
    required this.id,
    required this.name,
    required this.updatedAt,
    required this.category,
    required this.exposureCompensation,
    required this.iso,
    required this.shutterSpeed,
  });

  final String id;
  final String name;
  final int updatedAt; // 毫秒时间戳
  final String category; // 'portrait' / 'landscape' / 'food' / 'street' / 'night' / 'macro' / 'still-life'
  final double exposureCompensation; // EV 值
  final int iso;
  final String shutterSpeed; // '1/125s' 等
}

/// 草稿箱 mock 数据
///
/// 视觉规格来源：drafts.vue 的 useTemplate().getAllDrafts()
/// 注意：[drafts] 使用 `static final`（非 const），因 updatedAt 需基于 DateTime.now() 动态计算
class DraftsMockData {
  DraftsMockData._();

  /// 当前用户草稿列表（3 条，覆盖不同时间格式分支）
  /// - draft-1: 2 小时前 → formatDraftTime 返回 '2小时前'
  /// - draft-2: 3 天前 → formatDraftTime 返回 '3天前'
  /// - draft-3: 15 天前 → formatDraftTime 返回 '15天前'
  static final List<DraftItem> drafts = [
    DraftItem(
      id: 'draft-1',
      name: '咖啡馆人像草稿',
      // 2 小时前
      updatedAt:
          DateTime.now().millisecondsSinceEpoch - 2 * 60 * 60 * 1000,
      category: 'portrait',
      exposureCompensation: 0.7,
      iso: 400,
      shutterSpeed: '1/125s',
    ),
    DraftItem(
      id: 'draft-2',
      name: '日落风光草稿',
      // 3 天前
      updatedAt:
          DateTime.now().millisecondsSinceEpoch - 3 * 24 * 60 * 60 * 1000,
      category: 'landscape',
      exposureCompensation: -0.3,
      iso: 200,
      shutterSpeed: '1/60s',
    ),
    DraftItem(
      id: 'draft-3',
      name: '街拍黑白草稿',
      // 15 天前
      updatedAt:
          DateTime.now().millisecondsSinceEpoch - 15 * 24 * 60 * 60 * 1000,
      category: 'street',
      exposureCompensation: 1.0,
      iso: 800,
      shutterSpeed: '1/250s',
    ),
  ];

  /// 空草稿列表（用于测试空状态）
  static const List<DraftItem> emptyDrafts = [];
}

/// 格式化时间为相对时间
///
/// 来源：drafts.vue formatTime
/// Forced fix: 将 'N天前' 阈值从 7 天扩展到 30 天（uni-app 原值为 7 天）。
/// 原因：brief 第 2.2 节明确要求 15 天前的草稿格式化为 '15天前'，与 mock 数据 draft-3 (15 天前) 一致。
/// uni-app 原逻辑对 15 天前返回 '7月4日'，与 brief 测试期望冲突。
/// 影响：超过 30 天的草稿才会回落到 'M月D日' 格式，更符合用户感知。
String formatDraftTime(int timestamp, {int? now}) {
  final nowMs = now ?? DateTime.now().millisecondsSinceEpoch;
  final diff = nowMs - timestamp;
  const minute = 60 * 1000;
  const hour = 60 * minute;
  const day = 24 * hour;
  if (diff < minute) return '刚刚';
  if (diff < hour) return '${diff ~/ minute}分钟前';
  if (diff < day) return '${diff ~/ hour}小时前';
  if (diff < 2 * day) return '昨天';
  if (diff < 30 * day) return '${diff ~/ day}天前';
  final d = DateTime.fromMillisecondsSinceEpoch(timestamp);
  return '${d.month}月${d.day}日';
}

/// 格式化 EV 值
///
/// 来源：drafts.vue formatEv
String formatEv(double v) {
  return v > 0 ? '+${v.toStringAsFixed(1)}' : v.toStringAsFixed(1);
}
