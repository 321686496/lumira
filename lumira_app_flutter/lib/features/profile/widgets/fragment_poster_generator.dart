import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lumira_app_flutter/core/utils/image_cache.dart';

import '../../../core/theme/theme_tokens.dart';
import '../../../shared/services/poster_generator.dart';
import '../data/profile_mock_data.dart';

/// 碎片海报内容 Widget（公开，供 PosterGenerator 包裹渲染）
///
/// 渲染碎片图标、名称、进度环、图片九宫格、进度文字、品牌水印。
class FragmentPosterContent extends StatelessWidget {
  const FragmentPosterContent({
    super.key,
    required this.tokens,
    required this.fragment,
  });

  final ThemeTokens tokens;
  final FragmentItem fragment;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final fragment = this.fragment;
    final done = fragment.current >= fragment.max;
    final percent = fragment.percent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.brandSubtle, t.canvas],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.camera_alt_outlined, size: 18, color: t.brand),
              const SizedBox(width: 6),
              Text(
                'LUMIRA · 如画',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: t.brand,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [t.brand, t.brandDeep]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(fragment.icon, size: 28, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '碎片收集',
                      style: TextStyle(
                        fontSize: 12,
                        color: t.textTertiary,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fragment.name,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Noto Serif SC',
                        color: t.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(48, 48),
                      painter: _DeterminateProgressRing(
                        progress: percent / 100.0,
                        strokeWidth: 4,
                        trackColor: t.brandSubtle,
                        progressColor: t.brand,
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (fragment.photoUrls.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _PhotoGrid(tokens: t, urls: fragment.photoUrls),
            ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: done ? t.successSubtle : t.brand.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  done
                      ? Icons.check_circle
                      : Icons.local_fire_department_outlined,
                  size: 16,
                  color: done ? t.success : t.brand,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    done
                        ? '已集齐 ${fragment.max} 枚「${fragment.name}」碎片！'
                        : '已收集 ${fragment.current}/${fragment.max}，再收集 ${fragment.max - fragment.current} 枚即可集齐',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: done ? t.success : t.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.center,
            child: Text(
              '如画 LUMIRA · 记录每一帧光影',
              style: TextStyle(
                fontSize: 10,
                color: t.textTertiary,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 图片九宫格（自适应 2-9 张）
class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.tokens, required this.urls});
  final ThemeTokens tokens;
  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final count = urls.length;
    int crossCount;
    if (count <= 1) {
      crossCount = 1;
    } else if (count <= 4) {
      crossCount = 2;
    } else {
      crossCount = 3;
    }

    final rows = (count / crossCount).ceil();
    final cellHeight = crossCount == 1 ? 200.0 : 110.0;

    return Column(
      children: [
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < crossCount; c++)
                Expanded(
                  child: (r * crossCount + c) < count
                      ? Container(
                          height: cellHeight,
                          margin: EdgeInsets.only(
                            right: c < crossCount - 1 ? 3 : 0,
                            bottom: r < rows - 1 ? 3 : 0,
                          ),
                          child: _buildImage(urls[r * crossCount + c]),
                        )
                      : SizedBox(height: cellHeight),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildImage(String url) {
    final fallback = Container(
      color: tokens.brandSubtle,
      child: Icon(Icons.image_outlined, size: 24, color: tokens.brand),
    );
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return CachedNetworkImage(url: url, fit: BoxFit.cover,
          errorWidget: fallback);
    }
    return Image.file(File(url), fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback);
  }
}

/// Deprecated: 请直接使用 PosterGenerator.showPoster + FragmentPosterContent
@Deprecated('Use PosterGenerator.showPoster with FragmentPosterContent instead')
class FragmentPosterGenerator {
  FragmentPosterGenerator._();

  static Future<void> showPoster(
    BuildContext context, {
    required ThemeTokens tokens,
    required FragmentItem fragment,
    required GlobalKey posterKey,
  }) async {
    await PosterGenerator.showPoster(
      context: context,
      tokens: tokens,
      title: '海报预览',
      content: FragmentPosterContent(tokens: tokens, fragment: fragment),
      posterKey: posterKey,
      shareSubject: '如画 · 碎片收集：${fragment.name}',
      shareText:
          '我在如画收集了「${fragment.name}」碎片 ${fragment.current}/${fragment.max}，快来一起收集吧！',
      fileNamePrefix: 'lumira_fragment_${fragment.name}',
    );
  }
}

/// 确定性圆形进度环（替代 Material CircularProgressIndicator 的 determinate 模式）
///
/// LumiraProgress.circular() 仅支持 indeterminate 模式，
/// 此 painter 用于海报中展示静态进度百分比。
class _DeterminateProgressRing extends CustomPainter {
  const _DeterminateProgressRing({
    required this.progress,
    required this.strokeWidth,
    required this.trackColor,
    required this.progressColor,
  });

  final double progress;
  final double strokeWidth;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    if (radius <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // 背景圆环
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // 进度弧（从顶部开始，顺时针）
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _DeterminateProgressRing oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
