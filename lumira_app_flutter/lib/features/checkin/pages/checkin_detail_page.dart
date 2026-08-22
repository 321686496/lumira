import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/images/fullscreen_image_gallery.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../data/checkin_categories.dart';
import '../data/checkin_models.dart';
import '../data/checkin_providers.dart';
import '../widgets/checkin_common.dart';

/// 探店足迹详情页（精致手帐风）
///
/// - 沉浸式大封面：照片铺满顶部约 57% 屏高，店名/评分/分类/日期叠放于底部渐变遮罩上
/// - 封面可左右滑动切换照片，点击直接进入全屏大图（多图左右切换）
/// - 封面下方缩略图带 / 信息卡
class CheckinDetailPage extends ConsumerStatefulWidget {
  const CheckinDetailPage({super.key, this.checkinId});

  final String? checkinId;

  @override
  ConsumerState<CheckinDetailPage> createState() => _CheckinDetailPageState();
}

class _CheckinDetailPageState extends ConsumerState<CheckinDetailPage> {
  int _coverIndex = 0;

  /// 封面左右滑动用的分页控制器
  final PageController _coverController = PageController();

  /// 封面随滑动到位时更新高亮（不跳页，避免打断滑动动画）
  void _selectCoverBySwipe(int i) {
    if (!mounted) return;
    setState(() => _coverIndex = i);
  }

  /// 点缩略图时带动画跳到对应封面
  void _selectCoverByThumb(int i) {
    if (!mounted) return;
    setState(() => _coverIndex = i);
    if (_coverController.hasClients) {
      _coverController.animateToPage(
        i,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _coverController.dispose();
    super.dispose();
  }

  void _goEdit(String id) {
    GoRouter.of(context).push(RouteNames.build(
      RouteNames.checkinEdit,
      {RouteNames.paramCheckinId: id},
    ));
  }

  /// 打开全屏多图查看器（从当前选中封面开始）
  void _openViewer(List<String> urls, int index) {
    if (urls.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FullscreenImageGallery(urls: urls, initialIndex: index),
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
                coverController: _coverController,
                onCoverChanged: _selectCoverBySwipe,
                onThumbTap: _selectCoverByThumb,
                onOpenViewer: _openViewer,
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
                  _FloatingControl(
                    icon: Icons.chevron_left,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  if (hasDetail && id != null) ...[
                    _FloatingControl(
                      icon: Icons.edit_outlined,
                      onTap: () => _goEdit(id),
                    ),
                    const SizedBox(width: 10),
                    _FloatingControl(
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

/// 详情正文：封面（可左右滑动切换）+ 缩略图带 + 信息卡
class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.tokens,
    required this.detail,
    required this.coverIndex,
    required this.coverController,
    required this.onCoverChanged,
    required this.onThumbTap,
    required this.onOpenViewer,
  });

  final ThemeTokens tokens;
  final CheckinDetail detail;
  final int coverIndex;
  final PageController coverController;
  final ValueChanged<int> onCoverChanged;
  final ValueChanged<int> onThumbTap;
  final void Function(List<String> urls, int index) onOpenViewer;

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
    final hasInfo = record.place.isNotEmpty || record.note.isNotEmpty;

    void openAt(int i) {
      if (photoUrls.isNotEmpty) onOpenViewer(photoUrls, i.clamp(0, photoUrls.length - 1));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // 沉浸式封面（左右滑动切换图片，点击进全屏）
          SizedBox(
            width: double.infinity,
            height: coverH,
            child: _CoverHeader(
              tokens: tokens,
              category: category,
              photoUrls: photoUrls,
              active: active,
              record: record,
              controller: coverController,
              onCoverChanged: onCoverChanged,
              onOpenImage: openAt,
            ),
          ),
          // 缩略图带：移到封面下方，不再遮挡大图
          if (photoUrls.length > 1) ...[
            const SizedBox(height: 12),
            _ThumbStrip(
              tokens: tokens,
              photoUrls: photoUrls,
              active: active,
              onTap: onThumbTap,
            ),
          ],
          // 信息卡（正常流式布局，不与封面上浮重叠）
          if (hasInfo) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _InfoCard(tokens: tokens, record: record),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}

/// 沉浸式封面：可左右滑动切换照片，点击进入全屏大图
class _CoverHeader extends StatelessWidget {
  const _CoverHeader({
    required this.tokens,
    required this.category,
    required this.photoUrls,
    required this.active,
    required this.record,
    required this.controller,
    required this.onCoverChanged,
    required this.onOpenImage,
  });

  final ThemeTokens tokens;
  final CheckinCategory category;
  final List<String> photoUrls;
  final int active;
  final CheckinRecord record;
  final PageController controller;
  final ValueChanged<int> onCoverChanged;
  final void Function(int index) onOpenImage;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 大封面：左右滑动切换图片，点击进全屏；无图时显示分类占位
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            child: photoUrls.isEmpty
                ? Container(
                    color: category.iconBgColor,
                    alignment: Alignment.center,
                    child: Icon(category.icon, size: 96, color: category.iconColor),
                  )
                : PageView.builder(
                    controller: controller,
                    itemCount: photoUrls.length,
                    onPageChanged: onCoverChanged,
                    itemBuilder: (_, i) => _PressScale(
                      onTap: () => onOpenImage(i),
                      child: CheckinPhotoImage(url: photoUrls[i], tokens: tokens, fit: BoxFit.cover),
                    ),
                  ),
          ),
          // 上下渐变遮罩（纯装饰，IgnorePointer 让点击/滑动穿透到 PageView）
          Positioned.fill(
            child: IgnorePointer(
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
          ),
          // 底部：页码指示 + 店名/评分/分类/日期（纯装饰，IgnorePointer）
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (photoUrls.length > 1) ...[
                  _PageDots(count: photoUrls.length, active: active),
                  const SizedBox(height: 10),
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
      // 叠在封面上：新拟态放弃双向浮雕阴影，避免照片上"发光"
      overlayOnImage: true,
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

/// 叠在照片上的风格自适应浮层圆钮（返回/编辑/删除）
///
/// 严格遵循「风格不混搭」规范：组件叠在照片等非纯色底之上时，新拟态的
/// 双向浮雕外阴影无法被照片承接，会像光晕般发散——因此叠图表面一律**不做
/// 外阴影**，改用当前风格的表面 + 细描边表达；只有玻璃风格本身保留其玻璃底。
class _FloatingControl extends ConsumerWidget {
  const _FloatingControl({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appThemeProvider);
    final tokens = app.tokens;

    late final Color bg;
    final Color iconColor;
    final bool useGlass;
    Border? border;
    switch (app.style) {
      case UIStyle.neumorphic:
        // 压图表面：实心 surface + 细描边，无外阴影、无模糊
        bg = tokens.surface;
        border = Border.all(color: tokens.divider, width: 1);
        iconColor = tokens.textPrimary;
        useGlass = false;
        break;
      case UIStyle.flat:
        bg = tokens.surfaceAlt.withOpacity(0.78);
        border = Border.all(color: tokens.divider, width: 1);
        iconColor = tokens.textPrimary;
        useGlass = false;
        break;
      case UIStyle.glass:
        bg = Colors.white.withOpacity(0.45);
        border = Border.all(color: Colors.white.withOpacity(0.5), width: 1);
        iconColor = Colors.white;
        useGlass = true;
        break;
      case UIStyle.female:
        bg = tokens.brandSubtle.withOpacity(0.6);
        border = Border.all(color: Colors.white.withOpacity(0.6), width: 0.8);
        iconColor = tokens.textInverse;
        useGlass = false;
        break;
    }

    Widget circle = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: border,
      ),
      child: Icon(icon, size: 20, color: iconColor),
    );

    // 仅玻璃风格保留其自身的玻璃底
    if (useGlass) {
      circle = ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: circle,
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: circle,
    );
  }
}

/// 封面页码圆点指示器（叠在底部暗渐变遮罩上，便于观察左右滑动的当前位置）
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final on = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: on ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: on ? Colors.white : Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(1000),
          ),
        );
      }),
    );
  }
}

/// 按压缩放反馈容器（tap 反馈）
class _PressScale extends StatefulWidget {
  const _PressScale({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
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