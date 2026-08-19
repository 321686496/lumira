import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../data/checkin_categories.dart';
import '../data/checkin_models.dart';
import '../data/checkin_providers.dart';
import '../widgets/checkin_common.dart';

/// 探店足迹详情页（精致手帐风）
///
/// - 沉浸式大封面：首张照片铺满顶部约 57% 屏高，店名/评分/分类/日期叠放于底部渐变遮罩上
/// - 缩略图带：首图之外的照片横向小图，点击切换封面
/// - 浮层信息卡：地点/心得，圆角 20，与封面重叠产生「浮上来」手帐感
class CheckinDetailPage extends ConsumerStatefulWidget {
  const CheckinDetailPage({super.key, this.checkinId});

  final String? checkinId;

  @override
  ConsumerState<CheckinDetailPage> createState() => _CheckinDetailPageState();
}

class _CheckinDetailPageState extends ConsumerState<CheckinDetailPage> {
  int _coverIndex = 0;

  void _goEdit(String id) {
    GoRouter.of(context).push(RouteNames.build(
      RouteNames.checkinEdit,
      {RouteNames.paramCheckinId: id},
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final id = widget.checkinId;
    final detailAsync = id == null
        ? const AsyncValue<CheckinDetail?>.data(null)
        : ref.watch(checkinDetailProvider(id));
    final hasDetail = detailAsync.valueOrNull != null;

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: Stack(
        children: [
          detailAsync.when(
            loading: () => Center(child: LumiraProgress.circular()),
            error: (e, _) => Center(
              child: Text('加载失败：$e', style: TextStyle(color: tokens.textSecondary)),
            ),
            data: (detail) {
              if (detail == null) return _MissingState(tokens: tokens);
              return _DetailContent(
                tokens: tokens,
                detail: detail,
                coverIndex: _coverIndex,
                onThumbTap: (i) => setState(() => _coverIndex = i),
              );
            },
          ),
          // 顶部叠层：返回 + 编辑/删除（白色毛玻璃胶囊）
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Row(
                children: [
                  _FrostedIconButton(
                    icon: Icons.chevron_left,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  if (hasDetail && id != null) ...[
                    _FrostedIconButton(
                      icon: Icons.edit_outlined,
                      onTap: () => _goEdit(id),
                    ),
                    const SizedBox(width: 10),
                    _FrostedIconButton(
                      icon: Icons.delete_outline,
                      onTap: _onDelete,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onDelete() async {
    final id = widget.checkinId;
    if (id == null) return;
    final tokens = ref.read(themeTokensProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '删除足迹',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: tokens.textPrimary),
        ),
        content: Text(
          '确定删除这条探店足迹吗？此操作不可撤销。',
          style: TextStyle(fontSize: 14, color: tokens.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('取消', style: TextStyle(color: tokens.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('删除', style: TextStyle(color: tokens.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    try {
      final dao = await ref.read(checkinDaoProvider.future);
      await dao.delete(id);
      ref.invalidate(checkinsProvider);
      ref.invalidate(checkinTotalCountProvider);
      ref.invalidate(checkinDetailProvider(id));
      if (!mounted) return;
      LumiraToast.show(context, '已删除', duration: const Duration(milliseconds: 1000));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      LumiraToast.show(context, '删除失败：$e', duration: const Duration(seconds: 2));
    }
  }
}

/// 详情正文：封面 + 缩略图 + 浮层信息卡
class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.tokens,
    required this.detail,
    required this.coverIndex,
    required this.onThumbTap,
  });

  final ThemeTokens tokens;
  final CheckinDetail detail;
  final int coverIndex;
  final ValueChanged<int> onThumbTap;

  @override
  Widget build(BuildContext context) {
    final record = detail.record;
    final category = checkinCategoryOf(record.category);
    final photoUrls = detail.photos
        .map((p) => p.dataUrl ?? p.filePath)
        .where((u) => u != null && u.isNotEmpty)
        .cast<String>()
        .toList();
    final screenH = MediaQuery.of(context).size.height;
    final coverH = screenH * 0.57;
    final active = photoUrls.isEmpty ? 0 : (coverIndex >= photoUrls.length ? 0 : coverIndex);
    const infoOverlap = 28.0;
    final hasInfo = record.place.isNotEmpty || record.note.isNotEmpty;

    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 基础流：先占满封面高度 + 尾部留白区，供浮层卡被 Stack 定位
          SizedBox(
            width: double.infinity,
            height: coverH + 40, // 预留缩略图带空间
            child: _CoverHeader(
              tokens: tokens,
              category: category,
              photoUrls: photoUrls,
              active: active,
              record: record,
              onThumbTap: onThumbTap,
            ),
          ),
          // 浮层信息卡：与封面重叠 infoOverlap
          if (hasInfo)
            Positioned(
              left: 24,
              right: 24,
              top: coverH + 40 - infoOverlap,
              child: _InfoCard(tokens: tokens, record: record),
            ),
          if (!hasInfo)
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}

/// 沉浸式封面部（含缩略图带）
class _CoverHeader extends StatelessWidget {
  const _CoverHeader({
    required this.tokens,
    required this.category,
    required this.photoUrls,
    required this.active,
    required this.record,
    required this.onThumbTap,
  });

  final ThemeTokens tokens;
  final CheckinCategory category;
  final List<String> photoUrls;
  final int active;
  final CheckinRecord record;
  final ValueChanged<int> onThumbTap;

  @override
  Widget build(BuildContext context) {
    final showThumbs = photoUrls.length > 1;
    return SizedBox(
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 大封面（首张 或 缩略图选中项）
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            child: photoUrls.isEmpty
                ? Container(
                    color: category.iconBgColor,
                    alignment: Alignment.center,
                    child: Icon(category.icon, size: 96, color: category.iconColor),
                  )
                : CheckinPhotoImage(url: photoUrls[active], tokens: tokens, fit: BoxFit.cover),
          ),
          // 上下渐变遮罩
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.45),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.55),
                  ],
                  stops: const [0.0, 0.35, 0.6, 1.0],
                ),
              ),
            ),
          ),
          // 底部信息区 + 缩略图带
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showThumbs) ...[
                  _ThumbStrip(
                    tokens: tokens,
                    photoUrls: photoUrls,
                    active: active,
                    onTap: onThumbTap,
                  ),
                  const SizedBox(height: 12),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (record.rating > 0) ...[
                            CheckinRatingStars(rating: record.rating, tokens: tokens, size: 18),
                            const SizedBox(width: 10),
                          ],
                          CheckinCategoryTag(category: category, tokens: tokens),
                          if (record.rating >= 4) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.22),
                                borderRadius: BorderRadius.circular(1000),
                                border: Border.all(color: Colors.white.withOpacity(0.35), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.thumb_up_alt_outlined, size: 11, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    '值得一去',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 13, color: Colors.white.withOpacity(0.85)),
                          const SizedBox(width: 6),
                          Text(
                            formatCheckinDate(record.visitedAt),
                            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 横向缩略图带
class _ThumbStrip extends StatelessWidget {
  const _ThumbStrip({
    required this.tokens,
    required this.photoUrls,
    required this.active,
    required this.onTap,
  });

  final ThemeTokens tokens;
  final List<String> photoUrls;
  final int active;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: photoUrls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final selected = i == active;
          return GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? Colors.white : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CheckinPhotoImage(url: photoUrls[i], tokens: tokens, width: 60, height: 60, fit: BoxFit.cover),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 浮层信息卡（地点/心得）
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.tokens, required this.record});

  final ThemeTokens tokens;
  final CheckinRecord record;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (record.place.isNotEmpty) ...[
            _InfoRow(
              tokens: tokens,
              icon: Icons.place_outlined,
              label: '地点',
              value: record.place,
            ),
            if (record.note.isNotEmpty) Divider(height: 20, color: tokens.divider),
          ],
          if (record.note.isNotEmpty)
            _InfoRow(
              tokens: tokens,
              icon: Icons.notes_outlined,
              label: '心得',
              value: record.note,
              multiline: true,
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.tokens,
    required this.icon,
    required this.label,
    required this.value,
    this.multiline = false,
  });

  final ThemeTokens tokens;
  final IconData icon;
  final String label;
  final String value;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: tokens.brandSubtle,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: tokens.brand),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: tokens.textTertiary,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: tokens.textPrimary,
                  height: multiline ? 1.5 : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 白色毛玻璃胶囊按钮（叠层专用；遮罩上白图标，依赖黑色遮罩保证对比）
class _FrostedIconButton extends StatelessWidget {
  const _FrostedIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.22),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.22), width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}

class _MissingState extends StatelessWidget {
  const _MissingState({required this.tokens});

  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.place_outlined, size: 48, color: tokens.textTertiary),
          const SizedBox(height: 12),
          Text(
            '足迹不存在或已删除',
            style: TextStyle(fontSize: 13, color: tokens.textSecondary),
          ),
        ],
      ),
    );
  }
}