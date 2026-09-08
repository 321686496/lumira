import 'package:lumira_app_flutter/features/checkin/widgets/checkin_poster_styles.dart';

import 'photo_poster_styles.dart';
import 'poster_ratio.dart';
import 'poster_style_types.dart';
import 'template_poster_styles.dart';

export 'poster_style_types.dart' show PosterKind, PosterStyle, PosterStyleData;

/// 海报样式注册表：按 kind + ratio 返回可选样式。
///
/// 样式清单严格对应选型稿 `docs/design/poster_mockup_selected.html`
/// （模板 15 款 + 照片 11 款）；「扫码导入」海报走导出分享流程
/// （`export_detail_page` 内 `TemplateImportPoster`），不在此注册。
class PosterStyleRegistry {
  PosterStyleRegistry._();

  static final List<PosterStyle> _styles = [
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
