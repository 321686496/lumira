import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/searchengine/search_scope.dart';
import '../../templates/widgets/template_cover_image.dart';
import '../data/search_result.dart';

/// 搜索结果卡片。showTypeBadge=true（scope=all）时左上角叠加类型角标。
class SearchResultCard extends ConsumerWidget {
  const SearchResultCard({
    super.key,
    required this.result,
    required this.showTypeBadge,
    required this.onTap,
  });

  final SearchResult result;
  final bool showTypeBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tokens.divider, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _image(tokens),
                  if (showTypeBadge)
                    Positioned(top: 8, left: 8, child: _badge(tokens)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Noto Serif SC',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: tokens.brand,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _image(ThemeTokens tokens) {
    final url = result.imageUrl;
    final data = result.coverData;
    if ((url == null || url.isEmpty) && (data == null || data.isEmpty)) {
      return _placeholder(tokens);
    }
    // 复用模板封面组件：内置资产路径 / 远程 http URL / base64 data URL 一揽子处理。
    return TemplateCoverImage(
      cover: url,
      coverData: data,
      fit: BoxFit.cover,
      fallback: _placeholder(tokens),
      errorFallback: _placeholder(tokens),
    );
  }

  Widget _placeholder(ThemeTokens tokens) => Container(
        color: tokens.surfaceAlt,
        child: Icon(
          result.scope == SearchScope.scene
              ? Icons.image_outlined
              : Icons.photo_outlined,
          color: tokens.textTertiary,
          size: 28,
        ),
      );

  Widget _badge(ThemeTokens tokens) {
    final label = result.scope.label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tokens.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: tokens.divider, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: tokens.textPrimary),
      ),
    );
  }
}
