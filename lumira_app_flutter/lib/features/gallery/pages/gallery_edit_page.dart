import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/feedback/lumira_toast.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../capture/domain/filter_recipe.dart';
import '../../capture/domain/photo_template.dart';
import '../../capture/services/photo_post_processor.dart';
import '../../capture/widgets/preview_edit_panel.dart';
import '../../profile/providers/collection_providers.dart';

/// 相册照片修图页（独立编辑页）
///
/// 设计文档：docs/superpowers/specs/2026-07-31-gallery-detail-edit-split-design.md
///
/// 职责：承载原 gallery_detail_page 的完整编辑能力（PreviewEditPanel 4 标签
/// + 重置/导出按钮），保存成功后自动 pop 返回详情页。
///
/// 与原 gallery_detail_page 的差异：
/// 1. 标题"后期修图"（原"照片详情"）
/// 2. 保存成功后 Navigator.maybePop() 自动返回
/// 3. 直达 URL 时若 originalPath == null 显示只读横幅 + 禁用编辑
class GalleryEditPage extends ConsumerStatefulWidget {
  const GalleryEditPage({super.key, this.photoId});

  final String? photoId;

  @override
  ConsumerState<GalleryEditPage> createState() => _GalleryEditPageState();
}

class _GalleryEditPageState extends ConsumerState<GalleryEditPage> {
  /// 本地编辑状态（从照片记录初始化，编辑时实时更新预览，保存时写回 DB）
  PostProcess _localPostProcess = const PostProcess(color: PostProcessColor());
  TransformParams _localTransform = const TransformParams();
  bool _isExporting = false;

  GalleryItemRecord? _photo;
  bool _isLoading = true;
  bool _isInitialLoaded = false;

  /// 只读模式标志（originalPath == null 时为 true）
  bool _isReadOnly = false;

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
      if (mounted) {
        setState(() {
          _photo = photo;
          _localPostProcess =
              photo?.postProcess ?? const PostProcess(color: PostProcessColor());
          _localTransform = photo?.transform ?? const TransformParams();
          _isReadOnly = photo?.originalPath == null;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('[gallery-edit] _loadPhoto 异常: $e\n$st');
      if (mounted) {
        setState(() {
          _photo = null;
          _isLoading = false;
        });
      }
    }
  }

  void _showReadOnlyToast() {
    if (!mounted) return;
    LumiraToast.show(
      context,
      '原图未保留，无法编辑',
      duration: const Duration(seconds: 2),
    );
  }

  void _onPostProcessChanged(PostProcess next) {
    if (!mounted) return;
    if (_isReadOnly) {
      _showReadOnlyToast();
      return;
    }
    setState(() => _localPostProcess = next);
  }

  void _onTransformChanged(TransformParams t) {
    if (!mounted) return;
    if (_isReadOnly) {
      _showReadOnlyToast();
      return;
    }
    setState(() => _localTransform = t);
  }

  @override
  Widget build(BuildContext context) {
    final daoAsync = ref.watch(galleryDaoProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF1C1A17),
      appBar: LumiraNav(
        title: '后期修图',
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
      bottomNavigationBar: _BottomBar(
        isReadOnly: _isReadOnly,
        onReset: _reset,
        onExport: _isExporting ? () {} : () => _export(),
      ),
    );
  }

  Widget _buildContent(GalleryItemRecord photo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 只读横幅（originalPath == null 时显示）
        if (_isReadOnly)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFFFB74D).withOpacity(0.15),
            child: Row(
              children: const [
                Icon(Icons.lock_outline,
                    size: 16, color: Color(0xFFFFB74D)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '此照片未保留原图，仅可查看，无法编辑',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFFFFB74D)),
                  ),
                ),
              ],
            ),
          ),
        // 画布区（占屏幕 55%）
        _CanvasArea(
          photo: photo,
          postProcess: _localPostProcess,
          transform: _localTransform,
        ),
        // 编辑面板
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 420,
                  child: PreviewEditPanel(
                    postProcess: _localPostProcess,
                    transform: _localTransform,
                    onPostProcessChanged: _onPostProcessChanged,
                    onTransformChanged: _onTransformChanged,
                    previewImagePath: _photo?.dataUrl ?? _photo?.filePath,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _reset() {
    if (_isReadOnly) {
      _showReadOnlyToast();
      return;
    }
    setState(() {
      _localPostProcess = const PostProcess(color: PostProcessColor());
      _localTransform = const TransformParams();
    });
  }

  Future<void> _export() async {
    if (_photo == null) return;
    if (_isReadOnly) {
      _showReadOnlyToast();
      return;
    }

    final originalPath = _photo!.originalPath ?? _photo!.filePath;
    final photoPath = _photo!.filePath;

    if (originalPath == null || originalPath.isEmpty) {
      LumiraToast.show(context, '原图未保留，无法重新编辑');
      return;
    }
    if (photoPath == null || photoPath.isEmpty) {
      LumiraToast.show(context, '照片路径无效');
      return;
    }
    if (originalPath.startsWith('http') || photoPath.startsWith('http')) {
      LumiraToast.show(context, '网络图片不支持编辑');
      return;
    }

    final screenSize = MediaQuery.of(context).size;
    final screenRatio = screenSize.width / screenSize.height;
    final isPortrait = screenSize.height >= screenSize.width;
    final aspectRatio = _localPostProcess.cropRatio.isNotEmpty
        ? _localPostProcess.cropRatio
        : 'fullscreen';

    if (!await File(originalPath).exists()) {
      if (!mounted) return;
      LumiraToast.show(context, '原图文件不存在，无法重新处理');
      return;
    }

    setState(() => _isExporting = true);

    try {
      final processedPath = await PhotoPostProcessor.processFile(
        inputPath: originalPath,
        params: _localPostProcess,
        transform: _localTransform,
        aspectRatio: aspectRatio,
        screenRatio: screenRatio,
        isPortrait: isPortrait,
        outputPath: photoPath,
      );

      try {
        PaintingBinding.instance.imageCache.evict(FileImage(File(processedPath)));
        PaintingBinding.instance.imageCache.evict(FileImage(File(originalPath)));
      } catch (_) {}

      final dao = await ref.read(galleryDaoProvider.future);
      await dao.updateEdit(
        id: _photo!.id,
        filePath: processedPath,
        originalPath: originalPath,
        transform: _localTransform,
        postProcess: _localPostProcess,
      );
      ref.invalidate(galleryDaoProvider);
      ref.invalidate(collectionsListProvider);

      setState(() {
        _photo = GalleryItemRecord(
          id: _photo!.id,
          dataUrl: _photo!.dataUrl,
          filePath: processedPath,
          originalPath: originalPath,
          transform: _localTransform,
          postProcess: _localPostProcess,
          sceneId: _photo!.sceneId,
          templateId: _photo!.templateId,
          kitId: _photo!.kitId,
          mood: _photo!.mood,
          lut: _photo!.lut,
          isFavorite: _photo!.isFavorite,
          createdAt: _photo!.createdAt,
        );
      });

      if (mounted) {
        LumiraToast.show(context, '已保存', duration: const Duration(seconds: 1));
      }

      // 保存成功后延迟 1s 让 toast 显示，再 pop 返回详情页
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    } catch (e, st) {
      debugPrint('[gallery-edit] 导出失败: $e\n$st');
      if (mounted) {
        LumiraToast.show(context, '保存失败：$e', duration: const Duration(seconds: 2));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
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

/// 收藏按钮：点击切换 is_favorite
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

/// 画布区：实时应用 PostProcess（ColorFiltered）+ TransformParams（旋转/翻转/拉直）
class _CanvasArea extends StatelessWidget {
  const _CanvasArea({
    required this.photo,
    required this.postProcess,
    required this.transform,
  });
  final GalleryItemRecord photo;
  final PostProcess postProcess;
  final TransformParams transform;

  @override
  Widget build(BuildContext context) {
    final url = photo.dataUrl ?? photo.filePath;
    final screenHeight = MediaQuery.of(context).size.height;
    final canvasHeight = screenHeight * 0.55;

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
            : _buildImage(url),
      ),
    );
  }

  Widget _buildImage(String url) {
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

    // 晕影预览：通过 Stack + RadialGradient 叠加在图片上方
    // （smoothStrength/sharpen 为逐像素效果，仅导出时生效，无法用 ColorFilter 模拟）
    if (postProcess.vignette > 0) {
      imageWidget = Stack(
        fit: StackFit.passthrough,
        children: [
          imageWidget,
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(
                          postProcess.vignette / 100 * 0.5),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return imageWidget;
  }
}

class _BottomBar extends ConsumerWidget implements PreferredSizeWidget {
  const _BottomBar({
    required this.isReadOnly,
    required this.onReset,
    required this.onExport,
  });
  final bool isReadOnly;
  final VoidCallback onReset;
  final VoidCallback onExport;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    return Material(
      color: tokens.canvasDeep,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
          decoration: BoxDecoration(
            color: tokens.canvasDeep,
            border: Border(
                top: BorderSide(color: tokens.divider, width: 1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onReset,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      border: Border.all(color: tokens.divider, width: 1),
                      borderRadius: BorderRadius.circular(1000),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh, size: 16, color: tokens.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            '重置',
                            style: TextStyle(
                                fontSize: 14, color: tokens.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: isReadOnly ? null : onExport,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: isReadOnly
                          ? null
                          : LinearGradient(
                              colors: [tokens.brand, tokens.brandDeep],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: isReadOnly ? tokens.surfaceAlt : null,
                      borderRadius: BorderRadius.circular(1000),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.download_outlined,
                              size: 16,
                              color: isReadOnly
                                  ? tokens.textTertiary
                                  : tokens.textInverse),
                          const SizedBox(width: 6),
                          Text(
                            '导出',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isReadOnly
                                  ? tokens.textTertiary
                                  : tokens.textInverse,
                            ),
                          ),
                        ],
                      ),
                    ),
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
