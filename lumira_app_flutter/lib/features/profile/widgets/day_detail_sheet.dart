import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../data/growth_models.dart';
import '../providers/growth_providers.dart';

/// 弹出拍摄日历热力图某格子的单日详情弹层。
void showDayDetailSheet(
  BuildContext context, {
  required String date,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DayDetailSheet(date: date),
  );
}

class _DayDetailSheet extends ConsumerWidget {
  const _DayDetailSheet({required this.date});
  final String date; // YYYY-MM-DD

  String _formatTitle() {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return date;
    const week = ['日', '一', '二', '三', '四', '五', '六'];
    return '${parsed.year}年${parsed.month}月${parsed.day}日 · 星期${week[parsed.weekday % 7]}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final height = MediaQuery.of(context).size.height;
    return Container(
      constraints: BoxConstraints(maxHeight: height * 0.72),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽指示条
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(
                color: tokens.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 12, 0),
              child: Row(
                children: [
                  Text(
                    _formatTitle(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, size: 20, color: tokens.textTertiary),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Consumer(
                builder: (context, ref, _) {
                  final async = ref.watch(growthDayDetailProvider(date));
                  return async.when(
                    loading: () => SizedBox(
                      height: 200,
                      child: Center(child: LumiraProgress.circular()),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(
                        '加载失败，请稍后重试',
                        style: TextStyle(color: tokens.textSecondary),
                      ),
                    ),
                    data: (detail) => _DayDetailBody(
                      detail: detail,
                      tokens: tokens,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDetailBody extends StatelessWidget {
  const _DayDetailBody({required this.detail, required this.tokens});
  final DayActivityDetail detail;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final photoCount = detail.photoCount;
    final challengeCount = detail.challengeCount;
    final challenges = detail.challenges;
    final hasData = photoCount > 0 || challengeCount > 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 统计
          Row(
            children: [
              _StatChip(
                label: '拍摄',
                value: photoCount,
                icon: Icons.camera_alt_outlined,
                tokens: tokens,
              ),
              const SizedBox(width: 10),
              _StatChip(
                label: '挑战',
                value: challengeCount,
                icon: Icons.emoji_events_outlined,
                tokens: tokens,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasData)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  '当天没有拍摄或挑战记录',
                  style: TextStyle(fontSize: 13, color: tokens.textSecondary),
                ),
              ),
            ),
          // 照片网格
          if (photoCount > 0) ...[
            Text(
              '当日照片',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 100,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: photoCount,
              itemBuilder: (context, i) {
                final photo = detail.photos[i];
                return _PhotoThumb(photo: photo, tokens: tokens);
              },
            ),
            const SizedBox(height: 16),
          ],
          // 挑战标题
          if (challengeCount > 0) ...[
            Text(
              '完成挑战',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            for (final title in challenges)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 15, color: tokens.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.tokens,
  });
  final String label;
  final int value;
  final IconData icon;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.brand.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: tokens.brand),
          const SizedBox(width: 6),
          Text(
            '$label $value',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
              fontFamily: 'Courier New',
            ),
          ),
        ],
      ),
    );
  }
}

/// 照片缩略图（支持 filePath / base64 data URL / http），点击进入相册详情。
class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.photo, required this.tokens});
  final DayPhoto photo;
  final ThemeTokens tokens;

  Widget _image(String thumb) {
    if (thumb.startsWith('http://') || thumb.startsWith('https://')) {
      return Image.network(thumb, fit: BoxFit.cover);
    }
    if (thumb.startsWith('data:')) {
      try {
        final b64 = thumb.contains(',')
            ? thumb.substring(thumb.indexOf(',') + 1)
            : thumb;
        return Image.memory(base64Decode(b64), fit: BoxFit.cover);
      } catch (_) {
        return _placeholder();
      }
    }
    return Image.file(File(thumb), fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder());
  }

  Widget _placeholder() {
    return Container(color: tokens.brand.withOpacity(0.08));
  }

  @override
  Widget build(BuildContext context) {
    final thumb = photo.thumb;
    return GestureDetector(
      onTap: () => context.push(
        RouteNames.build(
          RouteNames.galleryDetail,
          {RouteNames.paramPhotoId: photo.id},
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: thumb.isEmpty ? _placeholder() : _image(thumb),
      ),
    );
  }
}