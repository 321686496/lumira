import 'package:lumira_app_flutter/features/checkin/widgets/checkin_poster_styles.dart';

import 'photo_poster_styles.dart';
import 'poster_ratio.dart';
import 'poster_style_types.dart';
import 'template_import_poster_styles.dart';
import 'template_poster_styles.dart';

export 'poster_style_types.dart' show PosterKind, PosterStyle, PosterStyleData;

/// 海报样式注册表：按 kind + ratio 返回可选样式。
class PosterStyleRegistry {
  PosterStyleRegistry._();

  static final List<PosterStyle> _styles = [
    // 「扫码导入」海报优先：作为 template kind 各比例的默认（首个）样式。
    ...templateImportPosterStyles(),
    ...templatePosterStyles(),
    ...photoPosterStyles(),
    ...checkinPosterStyles(),
  ];

  /// 该 kind + ratio 下可用的全部样式（保持注册顺序）。
  static List<PosterStyle> stylesFor(PosterKind kind, PosterRatio ratio) {
    return _styles.where((s) => s.kind == kind && s.supports(ratio)).toList();
  }

  /// 默认样式（首个）。
  static PosterStyle? defaultFor(PosterKind kind, PosterRatio ratio) {
    final list = stylesFor(kind, ratio);
    return list.isEmpty ? null : list.first;
  }

  /// 全部样式。
  static List<PosterStyle> all() => List.unmodifiable(_styles);
}
