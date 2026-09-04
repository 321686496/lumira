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
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/safe_share.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/effects/pressable_recess.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../providers/collection_providers.dart';

/// 我的精选集页
///
/// 数据来源：[collectionsListProvider]（基于 CollectionsDao + CollectionService）。
/// - 按类型分区：手动「自建精选」在上，自动「系统精选」在下
/// - 每张卡：封面（cover_photo_id 缩略图，无封面用前 4 张缩略图拼贴）+
///   名称 + 照片数 + 更新时间 + 类型标签；manual 卡带「⋯」菜单（编辑/分享/删除）
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
              loading: () => Center(child: LumiraProgress.circular()),
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

  Widget _buildList(
      BuildContext context, ThemeTokens tokens, List<CollectionRecord> collections) {
    final manuals =
        collections.where((c) => c.type == CollectionType.manual).toList();
    final autos =
        collections.where((c) => c.type != CollectionType.manual).toList();
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
        // === 手动区：自建精选 ===
        SliverToBoxAdapter(
          child: _SectionHeader(
            tokens: tokens,
            title: '自建精选',
            action: '新建',
            onAction: () => GoRouter.of(context).push(RouteNames.profileCollectionEdit),
          ),
        ),
        if (manuals.isEmpty)
          SliverToBoxAdapter(
            child: _ManualEmptyHint(tokens: tokens),
          )
        else
          ...manuals.map(
            (c) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: FadeUp(
                  child: _CollectionCard(tokens: tokens, collection: c),
                ),
              ),
            ),
          ),
        // === 自动区：系统精选 ===
        if (autos.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionHeader(
              tokens: tokens,
              title: '系统精选',
              subtitle: '根据你的照片自动生成',
            ),
          ),
          ...autos.map(
            (c) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: FadeUp(
                  child: _CollectionCard(tokens: tokens, collection: c),
                ),
              ),
            ),
          ),
        ],
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
    // 品牌 CTA 新拟态内斜边：纯品牌色顶面 + 内斜边（亮上左/暗下右），
    // 按压时反转斜边（暗上左/亮下右），1.5px 实线不发散，无外阴影避免悬浮感。
    return Padding(
      padding: const EdgeInsets.all(8),
      child: PressableRecess(
        onTap: () => GoRouter.of(context).push(RouteNames.profileCollectionEdit),
        borderRadius: 9999,
        raisedFill: tokens.brand,
        bevelLight: ThemeTokens.brandBevelLight(tokens),
        bevelDark: ThemeTokens.brandBevelDark(tokens),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.tokens,
    required this.title,
    this.subtitle,
    this.action,
    this.onAction,
  });
  final ThemeTokens tokens;
  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Noto Serif SC',
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 11, color: tokens.textTertiary),
            ),
          ],
          const Spacer(),
          if (action != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  action!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: tokens.brand,
                  ),
                ),
              ),
            ),
        ],
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
              // 封面：coverPhotoId 缩略图，无封面用 2×2 照片拼贴 / 占位
              _CoverThumb(
                tokens: tokens,
                collectionId: collection.id,
                isManual: !isAuto,
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
                            )
                          else
                            GestureDetector(
                              onTap: () => _showCardMenu(context, ref),
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.more_horiz,
                                  size: 20,
                                  color: tokens.textTertiary,
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

  /// manual 卡片的「⋯」菜单：编辑 / 分享 / 删除
  Future<void> _showCardMenu(BuildContext context, WidgetRef ref) async {
    final tokens = ref.read(themeTokensProvider);
    final collection = this.collection;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: tokens.divider,
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
              ListTile(
                leading: Icon(Icons.edit_outlined, color: tokens.brandText),
                title: const Text('编辑'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  GoRouter.of(context).push(RouteNames.build(
                    RouteNames.profileCollectionEdit,
                    {RouteNames.paramCollectionId: collection.id},
                  ));
                },
              ),
              ListTile(
                leading: Icon(Icons.share_outlined, color: tokens.brandText),
                title: const Text('分享'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  SafeShare.share(
                    '精选集：${collection.name}\n共 ${collection.photoCount} 张照片\n来自如画 LUMIRA',
                    subject: '如画 LUMIRA · 精选集',
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: tokens.danger),
                title: Text('删除', style: TextStyle(color: tokens.danger)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final service = await ref.read(collectionServiceProvider.future);
                  await service.deleteCollection(collection.id);
                  ref.invalidate(collectionsListProvider);
                  if (context.mounted) {
                    LumiraToast.show(context, '已删除精选集');
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// 封面缩略图：若有 coverPhotoId，从 GalleryDao 取缩略图；
/// 无封面但照片数 > 0 时，取该精选集前 4 张照片做 2×2 拼贴；否则占位图标。
class _CoverThumb extends ConsumerStatefulWidget {
  const _CoverThumb({
    required this.tokens,
    required this.collectionId,
    required this.isManual,
    required this.coverPhotoId,
    required this.photoCount,
  });
  final ThemeTokens tokens;
  final String collectionId;
  final bool isManual;
  final String? coverPhotoId;
  final int photoCount;

  @override
  ConsumerState<_CoverThumb> createState() => _CoverThumbState();
}

class _CoverThumbState extends ConsumerState<_CoverThumb> {
  GalleryItemRecord? _photo;
  bool _loaded = false;
  List<GalleryItemRecord> _collagePhotos = [];
  bool _collageLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _loadCover();
    }
    final needCollage = (widget.coverPhotoId == null || widget.coverPhotoId!.isEmpty) &&
        widget.photoCount > 0;
    if (!_collageLoaded && needCollage) {
      _collageLoaded = true;
      _loadCollage();
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

  Future<void> _loadCollage() async {
    try {
      final db = await ref.read(databaseProvider.future);
      final galleryDao = GalleryDao(db);
      if (widget.isManual) {
        final ids = await CollectionsDao(db).getPhotos(widget.collectionId);
        final photos = <GalleryItemRecord>[];
        for (final rec in ids.take(4)) {
          final p = await galleryDao.getById(rec.photoId);
          if (p != null) photos.add(p);
        }
        if (mounted && photos.isNotEmpty) {
          setState(() => _collagePhotos = photos);
        }
      } else {
        final all = await galleryDao.getAll(limit: 4);
        if (mounted && all.isNotEmpty) {
          setState(() => _collagePhotos = all);
        }
      }
    } catch (_) {
      // 静默失败：保持空，UI 显示占位
    }
  }

  @override
  Widget build(BuildContext context) {
    const size = 96.0;
    final url = _photo?.dataUrl ?? _photo?.filePath;
    if (url != null && url.isNotEmpty) {
      return _buildSingle(url, size);
    }
    if (_collagePhotos.length >= 2) {
      return _buildCollage(size);
    }
    return _buildPlaceholder(size);
  }

  Widget _buildSingle(String url, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: url.startsWith('http')
          ? CachedNetworkImage(
              url: url,
              fit: BoxFit.cover,
              errorWidget: _buildPlaceholder(size),
            )
          : LumiraImage(
              url,
              fit: BoxFit.cover,
              errorWidget: _buildPlaceholder(size),
            ),
    );
  }

  Widget _buildCollage(double size) {
    return SizedBox(
      width: size,
      height: size,
      child: GridView.count(
        crossAxisCount: 2,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        mainAxisSpacing: 1,
        crossAxisSpacing: 1,
        children: List.generate(4, (i) {
          if (i < _collagePhotos.length) {
            final p = _collagePhotos[i];
            final u = p.dataUrl ?? p.filePath;
            if (u == null || u.isEmpty) return _buildPlaceholder(size / 2);
            return u.startsWith('http')
                ? CachedNetworkImage(
                    url: u,
                    fit: BoxFit.cover,
                    errorWidget: _buildPlaceholder(size / 2),
                  )
                : LumiraImage(
                    u,
                    fit: BoxFit.cover,
                    errorWidget: _buildPlaceholder(size / 2),
                  );
          }
          return _buildPlaceholder(size / 2);
        }),
      ),
    );
  }

  Widget _buildPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      color: widget.tokens.surfaceAlt,
      child: Icon(
        Icons.photo_outlined,
        color: widget.tokens.textTertiary,
        size: 28,
      ),
    );
  }
}

class _ManualEmptyHint extends StatelessWidget {
  const _ManualEmptyHint({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            '还没有自建精选集\n点击「+ 新建」从相册选照片创建',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: tokens.textTertiary, height: 1.5),
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
            '去相册选照片创建你的第一个精选集吧',
            style: TextStyle(fontSize: 12, color: tokens.textTertiary),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LumiraButton(
                variant: ButtonVariant.primary,
                onPressed: () => GoRouter.of(context).push(RouteNames.profileCollectionEdit),
                child: const Text('创建精选集'),
              ),
              const SizedBox(width: 12),
              LumiraButton(
                variant: ButtonVariant.secondary,
                onPressed: () => GoRouter.of(context).push(RouteNames.gallery),
                child: const Text('去相册'),
              ),
            ],
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
