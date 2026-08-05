import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/checkin_categories.dart';
import '../data/checkin_models.dart';
import '../data/checkin_providers.dart';
import '../widgets/checkin_common.dart';

/// 探店足迹详情页
///
/// - 照片区：横向滑动 1-9 张（4:3），无照片显示分类彩色图标占位
/// - 信息区：店名 + 评分星 + 分类 tag + 打卡日期 + 地点 + 心得
/// - AppBar 右上角：编辑（→ edit 带 checkinId）、删除（确认弹窗 → 删库 → 返回）
class CheckinDetailPage extends ConsumerWidget {
  const CheckinDetailPage({super.key, this.checkinId});

  final String? checkinId;

  void _goEdit(BuildContext context) {
    final id = checkinId;
    if (id == null) return;
    GoRouter.of(context).push(RouteNames.build(
      RouteNames.checkinEdit,
      {RouteNames.paramCheckinId: id},
    ));
  }

  Future<void> _onDelete(BuildContext context, WidgetRef ref) async {
    final id = checkinId;
    if (id == null) return;
    final tokens = ref.read(themeTokensProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '删除足迹',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
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
            child: Text(
              '删除',
              style: TextStyle(color: tokens.danger, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final dao = await ref.read(checkinDaoProvider.future);
      await dao.delete(id);
      ref.invalidate(checkinsProvider);
      ref.invalidate(checkinTotalCountProvider);
      ref.invalidate(checkinDetailProvider(id));
      if (!context.mounted) return;
      LumiraToast.show(context, '已删除', duration: const Duration(milliseconds: 1000));
      context.pop();
    } catch (e) {
      if (!context.mounted) return;
      LumiraToast.show(context, '删除失败：$e', duration: const Duration(seconds: 2));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final id = checkinId;
    final detailAsync = id == null
        ? const AsyncValue<CheckinDetail?>.data(null)
        : ref.watch(checkinDetailProvider(id));

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '足迹详情',
        transparent: true,
        actions: [
          if (id != null) ...[
            GestureDetector(
              onTap: () => _goEdit(context),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.edit_outlined, size: 20, color: tokens.textSecondary),
              ),
            ),
            GestureDetector(
              onTap: () => _onDelete(context, ref),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.delete_outline, size: 20, color: tokens.textSecondary),
              ),
            ),
          ],
        ],
      ),
      body: detailAsync.when(
        loading: () => Center(child: LumiraProgress.circular()),
        error: (e, _) => Center(
          child: Text('加载失败：$e', style: TextStyle(color: tokens.textSecondary)),
        ),
        data: (detail) {
          if (detail == null) return _MissingState(tokens: tokens);
          return _buildContent(context, detail, tokens);
        },
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, CheckinDetail detail, ThemeTokens tokens) {
    final record = detail.record;
    final category = checkinCategoryOf(record.category);
    final photoUrls = detail.photos
        .map((p) => p.dataUrl ?? p.filePath)
        .where((u) => u != null && u.isNotEmpty)
        .toList();
    final screenW = MediaQuery.of(context).size.width;
    final itemW = screenW - 48;
    final itemH = itemW * 0.75; // 4:3

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        const SizedBox(height: 64),
        // 照片区：横向滑动 4:3
        SizedBox(
          height: itemH,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              for (var i = 0; i < photoUrls.length; i++) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CheckinPhotoImage(
                    url: photoUrls[i],
                    tokens: tokens,
                    width: itemW,
                    height: itemH,
                  ),
                ),
                if (i < photoUrls.length - 1) const SizedBox(width: 12),
              ],
              if (photoUrls.isEmpty)
                Container(
                  width: itemW,
                  height: itemH,
                  decoration: BoxDecoration(
                    color: category.iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(category.icon, size: 48, color: category.iconColor),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // 信息区
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.name,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (record.rating > 0) ...[
                    CheckinRatingStars(rating: record.rating, tokens: tokens, size: 16),
                    const SizedBox(width: 10),
                  ],
                  CheckinCategoryTag(category: category, tokens: tokens),
                ],
              ),
              const SizedBox(height: 16),
              NeuCard(
                child: Column(
                  children: [
                    _InfoRow(
                      tokens: tokens,
                      icon: Icons.calendar_today_outlined,
                      label: '打卡日期',
                      value: formatCheckinDate(record.visitedAt),
                    ),
                    if (record.place.isNotEmpty) ...[
                      Divider(height: 1, color: tokens.divider),
                      _InfoRow(
                        tokens: tokens,
                        icon: Icons.place_outlined,
                        label: '地点',
                        value: record.place,
                      ),
                    ],
                    if (record.note.isNotEmpty) ...[
                      Divider(height: 1, color: tokens.divider),
                      _InfoRow(
                        tokens: tokens,
                        icon: Icons.notes_outlined,
                        label: '心得',
                        value: record.note,
                        multiline: true,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: tokens.brand),
          const SizedBox(width: 10),
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: tokens.textTertiary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: tokens.textPrimary,
                height: multiline ? 1.5 : null,
              ),
            ),
          ),
        ],
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
