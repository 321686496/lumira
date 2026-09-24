import 'package:flutter/widgets.dart';

import 'poster_ratio.dart';

/// 海报类型：模板详情分享海报 / 照片详情分享海报 / 探店足迹分享海报 / 精选集分享海报。
enum PosterKind { template, photo, checkin, collection }

/// 海报展示数据。
///
/// [photoBuilder] 负责把照片按给定宽高渲染（cover 填充），供各样式在照片区调用，
/// 保证照片区域比例与 [ratio] 严格一致且不拉伸变形。
///
/// checkin 扩展字段（[note]/[place]/[dateText]/[rating]/[thumbBuilders]）为探店足迹
/// 海报专用，默认值为空/0/null，不影响既有模板/照片海报。
class PosterStyleData {
  const PosterStyleData({
    required this.ratio,
    required this.title,
    required this.category,
    required this.qrData,
    required this.qrHint,
    required this.qrSub,
    required this.shareText,
    this.authorName = '',
    required this.photoBuilder,
    this.note = '',
    this.place = '',
    this.dateText = '',
    this.rating = 0.0,
    this.thumbBuilders,
    this.photoCount = 0,
  });

  final PosterRatio ratio;

  /// 模板名 / 照片名 / 店名（海报主标题）。
  final String title;

  /// 分类文案，如 '人像写真 · 摄影模板' / 探店分类 label。
  final String category;

  /// 二维码内容（模板分享链接 / 照片高清原图链接；探店海报为空）。
  final String qrData;

  /// 二维码提示主文案。
  final String qrHint;

  /// 二维码提示副文案。
  final String qrSub;

  /// 分享文案（部分样式展示）。
  final String shareText;

  /// 照片海报落款作者名（如「小满」，显示为 @小满）。
  final String authorName;

  /// 照片按尺寸渲染：`photoBuilder(w, h)` 在 w×h 区域内以 cover 显示照片。
  final Widget Function(double w, double h) photoBuilder;

  /// 探店心得（可选）。
  final String note;

  /// 探店地点（可选）。
  final String place;

  /// 探店打卡日期（可选，展示文案）。
  final String dateText;

  /// 探店评分 0-5（0 表示未评分）。
  final double rating;

  /// 探店小图构建器（至多 4 张，每张 `(w,h) => Widget`）。
  final List<Widget Function(double w, double h)>? thumbBuilders;

  /// 精选集真实收录照片数（海报页脚「共收录 N 张」用，可大于 [thumbBuilders] 长度；
  /// 0 时样式回退到 `thumbBuilders.length`）。
  final int photoCount;
}

/// 一种海报样式定义。
class PosterStyle {
  const PosterStyle({
    required this.id,
    required this.name,
    required this.groupName,
    required this.kind,
    required this.ratios,
    required this.builder,
    this.group = '',
  });

  /// 样式 id，如 'pA' / 'dN' / 'pE' / 'ckF'。
  final String id;

  /// 样式名，如「经典面板」。
  final String name;

  /// 分组展示名，如「样式一 · 经典面板」。
  final String groupName;

  /// 样式选择条分组标签（如「净版 / 画刊 / 画卷」；为空表示不分组）。
  final String group;

  final PosterKind kind;

  /// 支持的照片比例集合。
  final Set<PosterRatio> ratios;

  /// 依据 [PosterStyleData] 渲染海报正文 Widget。
  final Widget Function(PosterStyleData data) builder;

  bool supports(PosterRatio ratio) => ratios.contains(ratio);
}
