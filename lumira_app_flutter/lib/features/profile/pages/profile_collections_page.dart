import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/db/dao/collections_dao.dart';
import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../providers/collection_providers.dart';

/// 我的精选集页
///
/// 数据来源：[collectionsListProvider]（基于 CollectionsDao + CollectionService）。
/// - auto 类型在上（带"自动"小标签）
/// - manual 类型在下
/// - 每张卡：封面（cover_photo_id 缩略图，无封面用前 4 张缩略图九宫格预览）+
///   名称 + 照片数 + 更新时间 + 类型标签
class ProfileCollectionsPage extends ConsumerWidget {
  const ProfileCollectionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final asyncList = ref.watch(collectionsListProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '我的精选集',
        transparent: true,
        showBackButton: true,
        actions: [
          _CreateButton(tokens: tokens),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: GlassBackground(variant: GlassBackgroundVariant.profile),
          ),
          SafeArea(
            top: false,
            child: asyncList.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(
                tokens: tokens,
                message: '加载失败：$e',
                onRetry: () => ref.invalidate(collectionsListProvider),
              ),
              data: (collections) => collections.isEmpty
                  ? _EmptyState(tokens: tokens)
                  : _buildList(context, tokens, collections),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, ThemeTokens tokens, List<CollectionRecord> collections) {
    final totalPhotos = collections.fold<int>(0, (s, c) => s + c.photoCount);
    // Forced fix: extendBodyBehindAppBar=true 时 body 从 y=0 开始，
    // 用 viewPadding.top（状态栏） + 48（nav 内容高度） 精确占位
    final topPadding = MediaQuery.of(context).viewPadding.top + 48;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: topPadding)),
        SliverToBoxAdapter(
          child: _StatsCard(
            tokens: tokens,
            collectionCount: collections.length,
            photoCount: totalPhotos,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final collection = collections[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: FadeUp(
                    delay: Duration(milliseconds: (i % 6) * 60),
                    child: _CollectionCard(
                      tokens: tokens,
                      collection: collection,
                    ),
                  ),
                );
              },
              childCount: collections.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => GoRouter.of(context).push(RouteNames.profileCollectionEdit),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: tokens.brand,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Center(
          child: Text(
            '+ 新建',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: tokens.textInverse,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.tokens,
    required this.collectionCount,
    required this.photoCount,
  });
  final ThemeTokens tokens;
  final int collectionCount;
  final int photoCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: tokens.shadowConvexSubtle,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _stat('$collectionCount', '个精选集'),
            Container(
              width: 1,
              height: 28,
              color: tokens.divider,
            ),
            _stat('$photoCount', '张照片'),
          ],
        ),
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
            fontSize: 22,
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

class _CollectionCard extends ConsumerWidget {
  const _CollectionCard({required this.tokens, required this.collection});
  final ThemeTokens tokens;
  final CollectionRecord collection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuto = collection.type != CollectionType.manual;
    final updated = DateFormat('M月d日').format(
      DateTime.fromMillisecondsSinceEpoch(collection.updatedAt),
    );

    return GestureDetector(
      onTap: () => GoRouter.of(context).push(
        RouteNames.build(
          RouteNames.profileCollectionDetail,
          {RouteNames.paramCollectionId: collection.id},
        ),
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: tokens.shadowConvexSubtle,
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 封面：coverPhotoId 缩略图，无封面用占位图标
              _CoverThumb(
                tokens: tokens,
                coverPhotoId: collection.coverPhotoId,
                photoCount: collection.photoCount,
              ),
              // 信息区
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              collection.name,
                              style: TextStyle(
                                fontFamily: 'Noto Serif SC',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: tokens.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isAuto)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: tokens.brandSubtle,
                                borderRadius: BorderRadius.circular(9999),
                              ),
                              child: Text(
                                '自动',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: tokens.brandText,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${collection.photoCount} 张照片 · 更新于 $updated',
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 封面缩略图：若有 coverPhotoId，从 GalleryDao 取缩略图；否则显示占位图标。
class _CoverThumb extends ConsumerStatefulWidget {
  const _CoverThumb({
    required this.tokens,
    required this.coverPhotoId,
    required this.photoCount,
  });
  final ThemeTokens tokens;
  final String? coverPhotoId;
  final int photoCount;

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
    if (widget.coverPhotoId == null || widget.coverPhotoId!.isEmpty) {
      return;
    }
    try {
      final db = await ref.read(databaseProvider.future);
      final photo = await GalleryDao(db).getById(widget.coverPhotoId!);
      if (mounted) {
        setState(() => _photo = photo);
      }
    } catch (_) {
      // 静默失败：保持 _photo=null，UI 显示占位
    }
  }

  @override
  Widget build(BuildContext context) {
    const size = 96.0;
    final url = _photo?.dataUrl ?? _photo?.filePath;
    return SizedBox(
      width: size,
      height: size,
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
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: widget.tokens.surfaceAlt,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: widget.tokens.textTertiary,
                    ),
                  ),
                )
              : Image.file(
                  File(url),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: widget.tokens.surfaceAlt,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: widget.tokens.textTertiary,
                    ),
                  ),
                ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_library_outlined,
              size: 48, color: tokens.textTertiary),
          const SizedBox(height: 12),
          Text(
            '暂无精选集',
            style: TextStyle(fontSize: 14, color: tokens.textTertiary),
          ),
          const SizedBox(height: 4),
          Text(
            '拍摄几张照片后，系统会自动生成精选集',
            style: TextStyle(fontSize: 12, color: tokens.textTertiary),
          ),
        ],
      ),
    );
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
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
