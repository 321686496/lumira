import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_tokens.dart';
import '../../../shared/services/poster_generator.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/poster/poster_ratio.dart';
import '../../../shared/widgets/poster/poster_style_types.dart';
import '../data/checkin_categories.dart';
import '../data/checkin_models.dart';
import '../data/checkin_providers.dart';
import 'checkin_common.dart';
import 'checkin_poster_photo_picker.dart';
import 'checkin_poster_widgets.dart';

/// 展示海报：直接调用 [showCheckinPoster] 生成/导出/分享探店足迹海报。
///
/// 会异步加载该次探店全部照片；照片 >5 张时先弹选图面板（最多 5 张，首位为大图），
/// 再进入样式选择器预览（温柔手帐 / 原版足迹 / 金字招牌 / 克制奢华）。
Future<void> showCheckinPoster({
  required BuildContext context,
  required ThemeTokens tokens,
  required CheckinListItem item,
  required WidgetRef ref,
}) async {
  final detail = await ref.read(checkinDetailProvider(item.record.id).future);
  final record = detail?.record ?? item.record;

  final all = (detail?.photos ?? const <dynamic>[])
      .map((p) => _photoUrl(p))
      .where((u) => u.isNotEmpty)
      .toList();
  final base = all.isEmpty
      ? [item.coverPhotoUrl ?? ''].where((u) => u.isNotEmpty).toList()
      : all;

  if (!context.mounted) return;
  if (base.isEmpty) {
    LumiraToast.show(context, '暂无可分享的照片');
    return;
  }

  final List<String> urls;
  if (base.length > 5) {
    final picked =
        await showCheckinPhotoPicker(context: context, tokens: tokens, photoUrls: base);
    if (picked == null || picked.isEmpty) return; // 用户取消
    urls = picked;
  } else {
    urls = base.take(5).toList(growable: false);
  }

  if (!context.mounted) return;
  if (urls.isEmpty || urls.first.isEmpty) {
    LumiraToast.show(context, '暂无可分享的照片');
    return;
  }

  final data = buildCheckinData(record: record, photoUrls: urls, tokens: tokens);

  if (!context.mounted) return;
  await PosterGenerator.showPosterWithStylePicker(
    context: context,
    tokens: tokens,
    title: '探店足迹海报',
    kind: PosterKind.checkin,
    ratio: PosterRatio.ratio34,
    data: data,
    shareSubject: '如画 LUMIRA · 探店足迹',
    shareText: '推荐你这家店：${record.name}',
    fileNamePrefix: 'checkin_${record.id}',
  );
}

/// 组装海报数据：首位照片为大图，其余为小图（至多 4 张）。
/// 发布于测试可见：供 Widget/单测直接构造数据。
@visibleForTesting
PosterStyleData buildCheckinData({
  required CheckinRecord record,
  required List<String> photoUrls,
  required ThemeTokens tokens,
}) {
  final big = photoUrls.isNotEmpty ? photoUrls.first : '';
  final thumbs = photoUrls.skip(1).take(4).toList(growable: false);
  return PosterStyleData(
    ratio: PosterRatio.ratio34,
    title: record.name,
    category: checkinCategoryOf(record.category).label,
    qrData: '',
    qrHint: '',
    qrSub: '',
    shareText: '推荐你这家店：${record.name}',
    photoBuilder: (w, h) => checkinPhoto(url: big, tokens: tokens, width: w, height: h),
    note: record.note,
    place: record.place,
    dateText: formatCheckinDate(record.visitedAt),
    rating: record.rating.toDouble(),
    thumbBuilders: [
      for (final u in thumbs)
        (w, h) => checkinPhoto(url: u, tokens: tokens, width: w, height: h),
    ],
  );
}

String _photoUrl(Object? photo) {
  // GalleryItemRecord：优先 dataUrl，其次 filePath，最后空。
  try {
    final d = (photo as dynamic);
    final dataUrl = d.dataUrl;
    if (dataUrl is String && dataUrl.isNotEmpty) return dataUrl;
    final f = d.filePath;
    if (f is String && f.isNotEmpty) return f;
  } catch (_) {
    return '';
  }
  return '';
}
