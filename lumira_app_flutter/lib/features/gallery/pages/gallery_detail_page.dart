import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/dao/scenes_dao.dart';
import '../../../core/db/dao/templates_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/utils/time_format.dart';
import '../../../shared/widgets/feedback/lumira_toast.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../capture/domain/filter_recipe.dart';
import '../../capture/domain/photo_template.dart';
import '../../profile/providers/collection_providers.dart';

/// 相册照片详情页（查看为主）
///
/// 设计文档：docs/superpowers/specs/2026-07-31-gallery-detail-edit-split-design.md
///
/// 职责：
/// - 显示照片预览（只读，应用照片已保存的 postProcess 滤镜）
/// - 显示照片元信息：拍摄时间（相对+绝对）、心情标签、原图保留状态
/// - 显示模板/场景信息为可点击 Chip，点击跳转对应详情页
/// - 底部"后期修图"按钮，跳转到 /gallery/edit?photoId=xxx
///
/// 编辑能力已迁移至 GalleryEditPage（lib/features/gallery/pages/gallery_edit_page.dart）
class GalleryDetailPage extends ConsumerStatefulWidget {
  const GalleryDetailPage({super.key, this.photoId});

  final String? photoId;

  @override
  ConsumerState<GalleryDetailPage> createState() => _GalleryDetailPageState();
}

class _GalleryDetailPageState extends ConsumerState<GalleryDetailPage> {
  GalleryItemRecord? _photo;
  bool _isLoading = true;
  bool _isInitialLoaded = false;

  /// 模板名称（异步查询，null 表示未查询到或未加载）
  String? _templateName;

  /// 场景名称（异步查询，null 表示未查询到或未加载）
  String? _sceneName;

  Future<void> _loadPhoto(GalleryDao dao) async {
    try {
      if (widget.photoId == null) {
        if (mounted) {
          setState(() {
            _photo = null;
            _isLoading = false;
          });
        }
        return;
      }
      final photo = await dao.getById(widget.photoId!);

      // 并行查询模板名 / 场景名
      String? templateName;
      String? sceneName;
      if (photo != null) {
        final futures = <Future<dynamic>>[];
        if (photo.templateId != null && photo.templateId!.isNotEmpty) {
          futures.add(
            ref.read(templatesDaoProvider.future).then((d) => d.getById(photo.templateId!)),
          );
        } else {
          futures.add(Future.value(null));
        }
        if (photo.sceneId != null && photo.sceneId!.isNotEmpty) {
          futures.add(
            ref.read(scenesDaoProvider.future).then((d) => d.getById(photo.sceneId!)),
          );
        } else {
          futures.add(Future.value(null));
        }
        final results = await Future.wait(futures);
        if (results[0] is TemplateRecord) {
          templateName = (results[0] as TemplateRecord).name;
        }
        if (results[1] is SceneRecord) {
          sceneName = (results[1] as SceneRecord).name;
        }
      }

      if (mounted) {
        setState(() {
          _photo = photo;
          _templateName = templateName;
          _sceneName = sceneName;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('[gallery-detail] _loadPhoto 异常: $e\n$st');
      if (mounted) {
        setState(() {
          _photo = null;
          _isLoading = false;
        });
      }
    }
  }

  /// 点击"后期修图"按钮：跳转修图页，返回后刷新
  Future<void> _onEditTap() async {
    final photo = _photo;
    if (photo == null) return;

    if (photo.originalPath == null || photo.originalPath!.isEmpty) {
      LumiraToast.show(context, '原图未保留，无法修图');
      return;
    }

    await GoRouter.of(context).push(
      RouteNames.build(
        RouteNames.galleryEdit,
        {RouteNames.paramPhotoId: photo.id},
      ),
    );

    // 修图页 pop 返回后刷新预览
    if (!mounted) return;
    final dao = ref.read(galleryDaoProvider).value;
    if (dao != null) {
      setState(() => _isLoading = true);
      _loadPhoto(dao);
    }
  }

  @override
  Widget build(BuildContext context) {
    final daoAsync = ref.watch(galleryDaoProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF1C1A17),
      appBar: LumiraNav(
        title: '照片详情',
        transparent: true,
        leading: const _DarkBackButton(),
        actions: [
          const _CompareAction(),
          if (_photo != null)
            _FavoriteButton(
              photo: _photo!,
              onToggled: (next) {
                setState(() {
                  _photo = GalleryItemRecord(
                    id: _photo!.id,
                    dataUrl: _photo!.dataUrl,
                    filePath: _photo!.filePath,
                    originalPath: _photo!.originalPath,
                    transform: _photo!.transform,
                    postProcess: _photo!.postProcess,
                    sceneId: _photo!.sceneId,
                    templateId: _photo!.templateId,
                    kitId: _photo!.kitId,
                    mood: _photo!.mood,
                    lut: _photo!.lut,
                    isFavorite: next,
                    createdAt: _photo!.createdAt,
                  );
                });
                ref.invalidate(collectionsListProvider);
              },
            ),
          const _MoreAction(),
        ],
      ),
      body: daoAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Color(0xFFC9A96E))),
        error: (e, _) => Center(
          child: Text('加载失败：$e', style: const TextStyle(color: Colors.white60)),
        ),
        data: (dao) {
          if (!_isInitialLoaded) {
            _isInitialLoaded = true;
            _loadPhoto(dao);
          }
          if (_isLoading) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFFC9A96E)));
          }
          return _photo == null ? const _EmptyCanvas() : _buildContent(_photo!);
        },
      ),
      bottomNavigationBar: _EditBottomBar(
        isReadOnly: _photo?.originalPath == null,
        onTap: _onEditTap,
      ),
    );
  }

  Widget _buildContent(GalleryItemRecord photo) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 照片预览区（应用 photo.postProcess 滤镜，只读）
          _ReadOnlyCanvas(photo: photo),
          // 2. 元信息 section
          _MetaInfoSection(photo: photo),
          // 3. 模板/场景 Chip 区
          if (_sceneName != null || _templateName != null)
            _SourceChipsSection(
              sceneName: _sceneName,
              templateName: _templateName,
              sceneId: photo.sceneId,
              templateId: photo.templateId,
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// === 私有 widget ===

class _DarkBackButton extends StatelessWidget {
  const _DarkBackButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      behavior: HitTestBehavior.opaque,
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white),
      ),
    );
  }
}

class _CompareAction extends StatelessWidget {
  const _CompareAction();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          '对比',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFFC9A96E),
          ),
        ),
      ),
    );
  }
}

class _MoreAction extends StatelessWidget {
  const _MoreAction();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Icons.more_horiz, size: 20, color: Colors.white60),
      ),
    );
  }
}

/// 收藏按钮
class _FavoriteButton extends ConsumerWidget {
  const _FavoriteButton({required this.photo, required this.onToggled});
  final GalleryItemRecord photo;
  final void Function(bool next) onToggled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        try {
          final dao = await ref.read(galleryDaoProvider.future);
          await dao.toggleFavorite(photo.id);
          onToggled(!photo.isFavorite);
          if (context.mounted) {
            LumiraToast.show(
              context,
              photo.isFavorite ? '已取消收藏' : '已收藏',
              duration: const Duration(milliseconds: 1000),
            );
          }
        } catch (e) {
          if (context.mounted) {
            LumiraToast.show(
              context,
              '操作失败：$e',
              duration: const Duration(milliseconds: 1500),
            );
          }
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          photo.isFavorite ? Icons.favorite : Icons.favorite_border,
          size: 20,
          color: photo.isFavorite ? const Color(0xFFE57373) : Colors.white60,
        ),
      ),
    );
  }
}

class _EmptyCanvas extends StatelessWidget {
  const _EmptyCanvas();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.image_outlined, size: 48, color: Colors.white38),
          SizedBox(height: 12),
          Text(
            '照片不存在或已被删除',
            style: TextStyle(fontSize: 13, color: Colors.white60),
          ),
        ],
      ),
    );
  }
}

/// 只读照片预览区：直接使用 photo.postProcess / photo.transform 显示已保存效果
class _ReadOnlyCanvas extends StatelessWidget {
  const _ReadOnlyCanvas({required this.photo});
  final GalleryItemRecord photo;

  @override
  Widget build(BuildContext context) {
    final url = photo.dataUrl ?? photo.filePath;
    final screenHeight = MediaQuery.of(context).size.height;
    final canvasHeight = screenHeight * 0.45;
    final transform = photo.transform ?? const TransformParams();
    final postProcess =
        photo.postProcess ?? const PostProcess(color: PostProcessColor());

    return Container(
      padding: const EdgeInsets.all(16),
      height: canvasHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: url == null || url.isEmpty
            ? Container(
                color: const Color(0xFF2A2724),
                child: const Center(
                  child: Icon(Icons.image_outlined, size: 32, color: Colors.white38),
                ),
              )
            : _buildImage(url, transform, postProcess),
      ),
    );
  }

  Widget _buildImage(
      String url, TransformParams transform, PostProcess postProcess) {
    Widget imageWidget = url.startsWith('http')
        ? Image.network(url, fit: BoxFit.contain)
        : Image.file(
            File(url),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF2A2724),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.broken_image_outlined,
                        size: 32, color: Colors.white38),
                    SizedBox(height: 8),
                    Text('图片加载失败',
                        style: TextStyle(fontSize: 12, color: Colors.white38)),
                  ],
                ),
              ),
            ),
          );

    if (!transform.isIdentity) {
      imageWidget = RotatedBox(
        quarterTurns: transform.rotation ~/ 90,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..scale(
              transform.flipH ? -1.0 : 1.0,
              transform.flipV ? -1.0 : 1.0,
              1.0,
            ),
          child: Transform.rotate(
            angle: transform.straighten * math.pi / 180.0,
            child: ColorFiltered(
              colorFilter: fromPostProcess(postProcess),
              child: imageWidget,
            ),
          ),
        ),
      );
    } else {
      imageWidget = ColorFiltered(
        colorFilter: fromPostProcess(postProcess),
        child: imageWidget,
      );
    }
    return imageWidget;
  }
}

/// 元信息 Section：拍摄时间 + 心情 + 原图保留状态
class _MetaInfoSection extends StatelessWidget {
  const _MetaInfoSection({required this.photo});
  final GalleryItemRecord photo;

  @override
  Widget build(BuildContext context) {
    final relative = formatRelativeTime(photo.createdAt);
    final absolute = formatAbsoluteTime(photo.createdAt);
    final hasMood = photo.mood != null && photo.mood!.isNotEmpty;
    final hasOriginal = photo.originalPath != null && photo.originalPath!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2724),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 拍摄时间
          const _MetaLabel(text: '拍摄时间'),
          const SizedBox(height: 6),
          if (relative.isNotEmpty)
            Text(
              relative,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          Text(
            absolute,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.6),
              height: 1.4,
            ),
          ),
          // 心情标签
          if (hasMood) ...[
            const SizedBox(height: 16),
            const _MetaLabel(text: '心情'),
            const SizedBox(height: 6),
            _MoodChip(mood: photo.mood!),
          ],
          // 原图保留状态
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasOriginal
                      ? const Color(0xFF7CB342)
                      : const Color(0xFF888888),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                hasOriginal ? '原图已保留 · 可再次修图' : '原图未保留',
                style: TextStyle(
                  fontSize: 12,
                  color: hasOriginal
                      ? const Color(0xFF7CB342)
                      : const Color(0xFF888888),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaLabel extends StatelessWidget {
  const _MetaLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color: Colors.white.withOpacity(0.5),
        letterSpacing: 0.5,
      ),
    );
  }
}

class _MoodChip extends StatelessWidget {
  const _MoodChip({required this.mood});
  final String mood;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF3A3530),
        borderRadius: BorderRadius.circular(1000),
        border: Border.all(color: const Color(0xFFC9A96E).withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mood_outlined, size: 14, color: Color(0xFFC9A96E)),
          const SizedBox(width: 6),
          Text(
            mood,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 模板/场景信息 Chip 区
class _SourceChipsSection extends StatelessWidget {
  const _SourceChipsSection({
    required this.sceneName,
    required this.templateName,
    required this.sceneId,
    required this.templateId,
  });

  final String? sceneName;
  final String? templateName;
  final String? sceneId;
  final String? templateId;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2724),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '拍摄来源',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.5),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (sceneName != null && sceneId != null)
                _SourceChip(
                  icon: Icons.place_outlined,
                  label: sceneName!,
                  onTap: () => GoRouter.of(context).push(
                    RouteNames.build(RouteNames.captureSceneDetail,
                        {RouteNames.paramSceneId: sceneId!}),
                  ),
                ),
              if (templateName != null && templateId != null)
                _SourceChip(
                  icon: Icons.collections_bookmark_outlined,
                  label: templateName!,
                  onTap: () => GoRouter.of(context).push(
                    RouteNames.build(RouteNames.templatesDetail,
                        {RouteNames.paramTemplateId: templateId!}),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 可点击的来源 Chip
class _SourceChip extends StatelessWidget {
  const _SourceChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF3A3530),
          borderRadius: BorderRadius.circular(1000),
          border: Border.all(color: const Color(0xFFC9A96E), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFFC9A96E)),
            const SizedBox(width: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 14, color: Color(0xFFC9A96E)),
          ],
        ),
      ),
    );
  }
}

/// 底部"后期修图"按钮
class _EditBottomBar extends StatelessWidget implements PreferredSizeWidget {
  const _EditBottomBar({required this.isReadOnly, required this.onTap});
  final bool isReadOnly;
  final VoidCallback onTap;

  @override
  Size get preferredSize => const Size.fromHeight(62);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: preferredSize.height,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFF1C1A17),
            border: Border(top: BorderSide(color: Colors.white12, width: 1)),
          ),
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: isReadOnly
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFFC9A96E), Color(0xFFA88550)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: isReadOnly ? const Color(0xFF3A3530) : null,
                borderRadius: BorderRadius.circular(1000),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tune,
                      size: 18,
                      color: isReadOnly
                          ? const Color(0xFF888888)
                          : const Color(0xFF1C1A17),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '后期修图',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isReadOnly
                            ? const Color(0xFF888888)
                            : const Color(0xFF1C1A17),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
