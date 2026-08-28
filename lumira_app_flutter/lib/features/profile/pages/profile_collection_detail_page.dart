import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lumira_app_flutter/core/utils/image_cache.dart';

import '../../../shared/widgets/images/lumira_image.dart';
import '../../../core/db/dao/collections_dao.dart';
import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/services/poster_generator.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../providers/collection_providers.dart';
import '../widgets/collection_poster_generator.dart';

/// 精选集详情页
///
/// 数据来源：[collectionDetailProvider]（基于 CollectionService）。
/// - 顶部：封面 + 名称 + 描述 + 照片数 + 创建时间
/// - 统计区：照片数 / 创建日（auto 类型不显示评分）
/// - 九宫格预览（前 9 张缩略图）
/// - 操作按钮：
///   - auto 类型：仅"导出九宫格拼图"
///   - manual 类型：显示"编辑"+ "导出九宫格拼图"+ "删除精选集"
class ProfileCollectionDetailPage extends ConsumerWidget {
  const ProfileCollectionDetailPage({super.key, this.collectionId});

  final String? collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);

    if (collectionId == null) {
      return Scaffold(
        backgroundColor: tokens.canvas,
        extendBodyBehindAppBar: true,
        appBar: const LumiraNav(
          title: '精选集详情',
          transparent: true,
          showBackButton: true,
        ),
        body: Stack(
          children: [
            const Positioned.fill(
              child: GlassBackground(variant: GlassBackgroundVariant.profile),
            ),
            Center(
              child: Text(
                '缺少精选集 ID',
                style: TextStyle(color: tokens.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    final asyncDetail =
        ref.watch(collectionDetailProvider(collectionId!));

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: asyncDetail.maybeWhen(
          data: (d) => d.collection.name,
          orElse: () => '精选集详情',
        ),
        transparent: true,
        showBackButton: true,
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: GlassBackground(variant: GlassBackgroundVariant.profile),
          ),
          SafeArea(
            top: false,
            child: asyncDetail.when(
              loading: () =>
                  Center(child: LumiraProgress.circular()),
              error: (e, _) => _ErrorState(
                tokens: tokens,
                message: '加载失败：$e',
                onRetry: () => ref.invalidate(
                    collectionDetailProvider(collectionId!)),
              ),
              data: (data) => _DetailContent(
                tokens: tokens,
                data: data,
                collectionId: collectionId!,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailContent extends ConsumerWidget {
  const _DetailContent({
    required this.tokens,
    required this.data,
    required this.collectionId,
  });
  final ThemeTokens tokens;
  final CollectionDetailData data;
  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = data.collection;
    final photos = data.photos;
    final isAuto = collection.type != CollectionType.manual;
    final created = DateFormat('yyyy-MM-dd').format(
      DateTime.fromMillisecondsSinceEpoch(collection.createdAt),
    );

    // Forced fix: extendBodyBehindAppBar=true 时 body 从 y=0 开始，
    // 用 viewPadding.top（状态栏） + 48（nav 内容高度） 精确占位
    final topPadding = MediaQuery.of(context).viewPadding.top + 48;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, topPadding, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部信息卡
          FadeUp(
            child: _HeaderCard(
              tokens: tokens,
              collection: collection,
              createdLabel: created,
            ),
          ),
          const SizedBox(height: 16),
          // 统计区
          FadeUp(
            delay: const Duration(milliseconds: 80),
            child: _StatsSection(
              tokens: tokens,
              photoCount: collection.photoCount,
              createdLabel: created,
              isAuto: isAuto,
            ),
          ),
          const SizedBox(height: 20),
          // 九宫格预览
          if (photos.isNotEmpty) ...[
            FadeUp(
              delay: const Duration(milliseconds: 160),
              child: _PhotoGrid(tokens: tokens, photos: photos),
            ),
            const SizedBox(height: 20),
          ],
          // 操作按钮
          FadeUp(
            delay: const Duration(milliseconds: 240),
            child: _ActionsSection(
              tokens: tokens,
              collectionId: collectionId,
              isAuto: isAuto,
              onExport: () => _showSharePoster(context, ref),
            ),
          ),
          const SizedBox(height: 16),
          // 提示
          Center(
            child: Text(
              '导出的拼图可直接分享到社交媒体',
              style: TextStyle(fontSize: 11, color: tokens.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  /// 精选集分享海报：生成「拼图海报」（名称 + 描述 + 照片拼图 + 二维码信息），
  /// 可导出到相册或分享到系统社交媒体。
  Future<void> _showSharePoster(BuildContext context, WidgetRef ref) async {
    final tokens = ref.read(themeTokensProvider);
    final collection = data.collection;
    final posterKey = GlobalKey();
    await PosterGenerator.showPoster(
      context: context,
      tokens: tokens,
      title: '精选集海报',
      content: CollectionPosterContent(
        tokens: tokens,
        name: collection.name,
        description: collection.description,
        photoCount: collection.photoCount,
        createdAt: collection.createdAt,
        photos: data.photos,
      ),
      posterKey: posterKey,
      shareSubject: '如画 · 精选集：${collection.name}',
      shareText: '我在如画精选了「${collection.name}」精选集，一起来看吧！',
      fileNamePrefix: 'lumira_collection_${collection.name}',
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.tokens,
    required this.collection,
    required this.createdLabel,
  });
  final ThemeTokens tokens;
  final CollectionRecord collection;
  final String createdLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: tokens.shadowConvexSubtle,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _CoverThumb(
            tokens: tokens,
            coverPhotoId: collection.coverPhotoId,
            size: 80,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  collection.name,
                  style: TextStyle(
                    fontFamily: 'Noto Serif SC',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (collection.description != null &&
                    collection.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    collection.description!,
                    style: TextStyle(
                        fontSize: 12, color: tokens.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '${collection.photoCount} 张照片 · 创建于 $createdLabel',
                  style:
                      TextStyle(fontSize: 11, color: tokens.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverThumb extends ConsumerStatefulWidget {
  const _CoverThumb({
    required this.tokens,
    required this.coverPhotoId,
    required this.size,
  });
  final ThemeTokens tokens;
  final String? coverPhotoId;
  final double size;

  @override
  ConsumerState<_CoverThumb> createState() => _CoverThumbState();
}

class _CoverThumbState extends ConsumerState<_CoverThumb> {
  GalleryItemRecord? _photo;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _loadCover();
    }
  }

  Future<void> _loadCover() async {
    if (widget.coverPhotoId == null || widget.coverPhotoId!.isEmpty) return;
    try {
      final db = await ref.read(databaseProvider.future);
      final photo = await GalleryDao(db).getById(widget.coverPhotoId!);
      if (mounted) setState(() => _photo = photo);
    } catch (_) {
      // 静默失败
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _photo?.dataUrl ?? _photo?.filePath;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: url == null || url.isEmpty
            ? Container(
                color: widget.tokens.surfaceAlt,
                child: Icon(
                  Icons.photo_outlined,
                  color: widget.tokens.textTertiary,
                  size: 28,
                ),
              )
            : url.startsWith('http')
                ? CachedNetworkImage(
                    url: url,
                    fit: BoxFit.cover,
                    errorWidget: Container(
                      color: widget.tokens.surfaceAlt,
                      child: Icon(Icons.broken_image_outlined,
                          color: widget.tokens.textTertiary),
                    ),
                  )
                : LumiraImage(
                    url,
                    fit: BoxFit.cover,
                    errorWidget: Container(
                      color: widget.tokens.surfaceAlt,
                      child: Icon(Icons.broken_image_outlined,
                          color: widget.tokens.textTertiary),
                    ),
                  ),
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({
    required this.tokens,
    required this.photoCount,
    required this.createdLabel,
    required this.isAuto,
  });
  final ThemeTokens tokens;
  final int photoCount;
  final String createdLabel;
  final bool isAuto;

  @override
  Widget build(BuildContext context) {
    // auto 类型不显示评分；manual 类型也按设计暂不显示评分（当前未实现照片评分）
    // 此处统一显示：照片数 / 创建日 两列
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: tokens.shadowConvexSubtle,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat('$photoCount', '张照片'),
          Container(width: 1, height: 28, color: tokens.divider),
          _stat(createdLabel, '创建日'),
        ],
      ),
    );
  }

  Widget _stat(String num, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          num,
          style: TextStyle(
            fontFamily: 'Noto Serif SC',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: tokens.textTertiary),
        ),
      ],
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.tokens, required this.photos});
  final ThemeTokens tokens;
  final List<GalleryItemRecord> photos;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.0,
      children: [
        for (var i = 0; i < photos.length; i++)
          FadeUp(
            delay: Duration(milliseconds: i * 50),
            child: _PhotoCell(tokens: tokens, photo: photos[i]),
          ),
      ],
    );
  }
}

class _PhotoCell extends StatelessWidget {
  const _PhotoCell({required this.tokens, required this.photo});
  final ThemeTokens tokens;
  final GalleryItemRecord photo;

  @override
  Widget build(BuildContext context) {
    final url = photo.dataUrl ?? photo.filePath;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: url == null || url.isEmpty
          ? Container(
              color: tokens.surfaceAlt,
              child: Icon(Icons.broken_image_outlined,
                  color: tokens.textTertiary),
            )
          : url.startsWith('http')
              ? CachedNetworkImage(
                  url: url,
                  fit: BoxFit.cover,
                  errorWidget: Container(
                    color: tokens.surfaceAlt,
                    child: Icon(Icons.broken_image_outlined,
                        color: tokens.textTertiary),
                  ),
                )
              : LumiraImage(
                  url,
                  fit: BoxFit.cover,
                  errorWidget: Container(
                    color: tokens.surfaceAlt,
                    child: Icon(Icons.broken_image_outlined,
                        color: tokens.textTertiary),
                  ),
                ),
    );
  }
}

class _ActionsSection extends ConsumerWidget {
  const _ActionsSection({
    required this.tokens,
    required this.collectionId,
    required this.isAuto,
    required this.onExport,
  });
  final ThemeTokens tokens;
  final String collectionId;
  final bool isAuto;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isAuto)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: LumiraButton(
              variant: ButtonVariant.secondary,
              onPressed: () => GoRouter.of(context).push(
                RouteNames.build(
                  RouteNames.profileCollectionEdit,
                  {RouteNames.paramCollectionId: collectionId},
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.edit_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('编辑'),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: LumiraButton(
            variant: ButtonVariant.primary,
            onPressed: onExport,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.send_outlined, size: 18),
                SizedBox(width: 8),
                Text('导出九宫格拼图'),
              ],
            ),
          ),
        ),
        if (!isAuto)
          Padding(
            padding: const EdgeInsets.only(bottom: 0),
            child: LumiraButton(
              variant: ButtonVariant.ghost,
              onPressed: () => _confirmDelete(context, ref),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.delete_outline, size: 18),
                  SizedBox(width: 8),
                  Text('删除精选集'),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final navigator = GoRouter.of(context);
    final confirmed = await LumiraAlertDialog.show<bool>(
      context: context,
      title: const Text('删除精选集'),
      content: const Text('删除后无法恢复，确认删除？'),
      actions: [
        LumiraButton(
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        LumiraButton(
          variant: ButtonVariant.danger,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('删除'),
        ),
      ],
    );
    if (confirmed != true) return;

    try {
      final service = await ref.read(collectionServiceProvider.future);
      await service.deleteCollection(collectionId);
      ref.invalidate(collectionsListProvider);
      // ignore: use_build_context_synchronously
      if (!context.mounted) return;
      LumiraToast.show(context, '已删除精选集', duration: const Duration(milliseconds: 1500));
      navigator.pop();
    } catch (e) {
      // ignore: use_build_context_synchronously
      if (!context.mounted) return;
      LumiraToast.show(context, '删除失败：$e', duration: const Duration(milliseconds: 1500));
    }
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.tokens,
    required this.message,
    required this.onRetry,
  });
  final ThemeTokens tokens;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: tokens.danger),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(fontSize: 13, color: tokens.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          LumiraButton(
            variant: ButtonVariant.secondary,
            onPressed: onRetry,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
