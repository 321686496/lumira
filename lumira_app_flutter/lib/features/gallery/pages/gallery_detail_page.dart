import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/dao/scenes_dao.dart';
import '../../../core/db/dao/templates_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/time_format.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../profile/providers/collection_providers.dart';

/// 相册照片详情页（查看为主）
///
/// 设计文档：docs/superpowers/specs/2026-07-31-gallery-detail-edit-split-design.md
///
/// 职责：
/// - 显示照片预览（只读，应用照片已保存的 postProcess 滤镜）
/// - 显示照片元信息：拍摄时间（相对+绝对）、心情标签、原图保留状态
/// - 显示模板/场景信息为可点击 Chip，点击跳转对应详情页
/// - 显示并允许更换照片分类（场景）
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

  /// 所有可用场景列表（用于分类更换选择器）
  List<SceneRecord> _allScenes = const [];

  /// 是否处于"对比"模式（点击 AppBar "对比"按钮切换）。
  /// 为 true 时 _ReadOnlyCanvas 显示原图（originalPath），为 false 时显示已烘焙的成品。
  bool _isComparing = false;

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

      // 并行查询模板名 / 场景名 / 全部场景列表
      String? templateName;
      String? sceneName;
      List<SceneRecord> allScenes = const [];
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
        // 加载所有场景用于分类更换
        futures.add(
          ref.read(scenesDaoProvider.future).then((d) => d.getAll()),
        );
        final results = await Future.wait(futures);
        if (results[0] is TemplateRecord) {
          templateName = (results[0] as TemplateRecord).name;
        }
        if (results[1] is SceneRecord) {
          sceneName = (results[1] as SceneRecord).name;
        }
        if (results[2] is List<SceneRecord>) {
          allScenes = results[2] as List<SceneRecord>;
        }
      }

      if (mounted) {
        setState(() {
          _photo = photo;
          _templateName = templateName;
          _sceneName = sceneName;
          _allScenes = allScenes;
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

  /// 更换照片分类（场景）：弹出底部 Sheet 选择新场景
  Future<void> _onChangeCategory() async {
    final photo = _photo;
    if (photo == null) return;
    final tokens = ref.read(themeTokensProvider);

    final result = await showLumiraBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CategoryPickerSheet(
        tokens: tokens,
        scenes: _allScenes,
        currentSceneId: photo.sceneId,
      ),
    );

    if (result == null || !mounted) return;

    // result 为 '__none__' 表示移除分类；否则为新 sceneId
    final newSceneId = result == '__none__' ? null : result;
    if (newSceneId == photo.sceneId) return;

    try {
      final dao = await ref.read(galleryDaoProvider.future);
      await dao.updateScene(photo.id, newSceneId);
      // 重新查询场景名
      String? newSceneName;
      if (newSceneId != null) {
        final scenesDao = await ref.read(scenesDaoProvider.future);
        final scene = await scenesDao.getById(newSceneId);
        newSceneName = scene?.name;
      }
      if (!mounted) return;
      setState(() {
        _photo = GalleryItemRecord(
          id: photo.id,
          dataUrl: photo.dataUrl,
          filePath: photo.filePath,
          originalPath: photo.originalPath,
          transform: photo.transform,
          postProcess: photo.postProcess,
          sceneId: newSceneId,
          templateId: photo.templateId,
          kitId: photo.kitId,
          mood: photo.mood,
          lut: photo.lut,
          isFavorite: photo.isFavorite,
          createdAt: photo.createdAt,
        );
        _sceneName = newSceneName;
      });
      ref.invalidate(collectionsListProvider);
      LumiraToast.show(context, '已更换分类', duration: const Duration(milliseconds: 1000));
    } catch (e) {
      if (mounted) {
        LumiraToast.show(context, '更换失败：$e', duration: const Duration(seconds: 2));
      }
    }
  }

  /// 点击 AppBar "对比"按钮：切换显示原图 / 成品。
  /// 若原图未保留，提示并保持原状。
  void _onCompareToggle() {
    final photo = _photo;
    if (photo == null) return;
    final hasOriginal =
        photo.originalPath != null && photo.originalPath!.isNotEmpty;
    if (!hasOriginal) {
      LumiraToast.show(
        context,
        '原图未保留，无法对比',
        duration: const Duration(milliseconds: 1500),
      );
      return;
    }
    setState(() => _isComparing = !_isComparing);
  }

  /// 分享当前照片：优先分享本地文件；网络图（dataUrl 以 http 开头）暂不支持。
  Future<void> _onShare() async {
    final photo = _photo;
    if (photo == null) return;
    final filePath = photo.filePath;
    final dataUrl = photo.dataUrl;
    // 选取第一个可用的本地路径
    final localPath = (filePath != null && filePath.isNotEmpty && !filePath.startsWith('http'))
        ? filePath
        : null;
    if (localPath == null) {
      final isNetwork = (dataUrl != null && dataUrl.startsWith('http')) ||
          (filePath != null && filePath.startsWith('http'));
      if (isNetwork) {
        LumiraToast.show(
          context,
          '网络图片暂不支持分享',
          duration: const Duration(milliseconds: 1500),
        );
      } else {
        LumiraToast.show(
          context,
          '未找到可分享的照片文件',
          duration: const Duration(milliseconds: 1500),
        );
      }
      return;
    }
    try {
      await Share.shareXFiles(
        [XFile(localPath)],
        subject: '如画 LUMIRA · 摄影作品',
        text: '我用如画拍了一张照片，快来看看吧！',
      );
    } catch (e) {
      if (!mounted) return;
      LumiraToast.show(
        context,
        '分享失败：$e',
        duration: const Duration(seconds: 2),
      );
    }
  }

  /// 删除当前照片：先弹出确认对话框，确认后调用 DAO 删除并返回上一页。
  Future<void> _onDelete() async {
    final photo = _photo;
    if (photo == null) return;
    final tokens = ref.read(themeTokensProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '删除照片',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
        content: Text(
          '确定删除这张照片吗？此操作不可撤销。',
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
    try {
      final dao = await ref.read(galleryDaoProvider.future);
      await dao.delete(photo.id);
      ref.invalidate(collectionsListProvider);
      if (!mounted) return;
      LumiraToast.show(
        context,
        '已删除',
        duration: const Duration(milliseconds: 1000),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      LumiraToast.show(
        context,
        '删除失败：$e',
        duration: const Duration(seconds: 2),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final daoAsync = ref.watch(galleryDaoProvider);
    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: LumiraNav(
        title: '照片详情',
        transparent: true,
        leading: _DarkBackButton(tokens: tokens),
        actions: [
          _CompareAction(
            tokens: tokens,
            isComparing: _isComparing,
            enabled: _photo != null &&
                _photo!.originalPath != null &&
                _photo!.originalPath!.isNotEmpty,
            onTap: _onCompareToggle,
          ),
          if (_photo != null)
            _FavoriteButton(
              photo: _photo!,
              tokens: tokens,
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
          if (_photo != null)
            _MoreAction(
              tokens: tokens,
              onShare: _onShare,
              onDelete: _onDelete,
            ),
        ],
      ),
      body: daoAsync.when(
        loading: () =>
            Center(child: LumiraProgress.circular()),
        error: (e, _) => Center(
          child: Text('加载失败：$e', style: TextStyle(color: tokens.textSecondary)),
        ),
        data: (dao) {
          if (!_isInitialLoaded) {
            _isInitialLoaded = true;
            _loadPhoto(dao);
          }
          if (_isLoading) {
            return Center(
                child: LumiraProgress.circular());
          }
          return _photo == null ? _EmptyCanvas(tokens: tokens) : _buildContent(_photo!, tokens);
        },
      ),
      bottomNavigationBar: _EditBottomBar(
        tokens: tokens,
        isReadOnly: _photo?.originalPath == null,
        onTap: _onEditTap,
      ),
    );
  }

  Widget _buildContent(GalleryItemRecord photo, ThemeTokens tokens) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 照片预览区（应用 photo.postProcess 滤镜，只读）
          // _isComparing 为 true 时切换显示原图
          _ReadOnlyCanvas(
            photo: photo,
            tokens: tokens,
            isComparing: _isComparing,
          ),
          // 2. 元信息 section
          _MetaInfoSection(photo: photo, tokens: tokens),
          // 3. 分类（场景）section —— 可查看并更换
          _CategorySection(
            tokens: tokens,
            sceneName: _sceneName,
            sceneId: photo.sceneId,
            onChange: _onChangeCategory,
          ),
          // 4. 模板/场景 Chip 区
          if (_sceneName != null || _templateName != null)
            _SourceChipsSection(
              tokens: tokens,
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
  const _DarkBackButton({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(Icons.arrow_back_ios_new, size: 18, color: tokens.textPrimary),
      ),
    );
  }
}

/// AppBar "对比"按钮：点击切换 _ReadOnlyCanvas 显示原图 / 成品。
/// isComparing 为 true 时高亮显示，提示当前正在对比。
/// enabled 为 false 时（原图未保留）按钮置灰，点击会触发外层提示。
class _CompareAction extends StatelessWidget {
  const _CompareAction({
    required this.tokens,
    required this.isComparing,
    required this.enabled,
    required this.onTap,
  });

  final ThemeTokens tokens;
  final bool isComparing;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isComparing
        ? tokens.brandDeep
        : (enabled ? tokens.brand : tokens.textTertiary);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        margin: const EdgeInsets.all(2),
        decoration: isComparing
            ? BoxDecoration(
                color: tokens.brandSubtle,
                borderRadius: BorderRadius.circular(1000),
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isComparing ? Icons.compare : Icons.compare_outlined,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              isComparing ? '原图' : '对比',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// AppBar "更多"按钮：点击弹出 BottomSheet，提供"分享照片" / "删除照片"操作。
class _MoreAction extends StatelessWidget {
  const _MoreAction({
    required this.tokens,
    required this.onShare,
    required this.onDelete,
  });

  final ThemeTokens tokens;
  final Future<void> Function() onShare;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showSheet(context),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(Icons.more_horiz, size: 20, color: tokens.textSecondary),
      ),
    );
  }

  Future<void> _showSheet(BuildContext context) async {
    final result = await showLumiraBottomSheet<String>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MoreSheetOption(
            tokens: tokens,
            icon: Icons.ios_share_outlined,
            label: '分享照片',
            onTap: () => Navigator.of(ctx).pop('share'),
          ),
          Divider(height: 1, color: tokens.divider),
          _MoreSheetOption(
            tokens: tokens,
            icon: Icons.delete_outline,
            label: '删除照片',
            isDanger: true,
            onTap: () => Navigator.of(ctx).pop('delete'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
    if (result == null) return;
    if (result == 'share') {
      await onShare();
    } else if (result == 'delete') {
      await onDelete();
    }
  }
}

/// _MoreAction BottomSheet 中的单行选项
class _MoreSheetOption extends StatelessWidget {
  const _MoreSheetOption({
    required this.tokens,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDanger = false,
  });

  final ThemeTokens tokens;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? tokens.danger : tokens.textPrimary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 收藏按钮
class _FavoriteButton extends ConsumerWidget {
  const _FavoriteButton({required this.photo, required this.tokens, required this.onToggled});
  final GalleryItemRecord photo;
  final ThemeTokens tokens;
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
          color: photo.isFavorite ? tokens.danger : tokens.textSecondary,
        ),
      ),
    );
  }
}

class _EmptyCanvas extends StatelessWidget {
  const _EmptyCanvas({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined, size: 48, color: tokens.textTertiary),
          const SizedBox(height: 12),
          Text(
            '照片不存在或已被删除',
            style: TextStyle(fontSize: 13, color: tokens.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// 只读照片预览区：直接显示已烘焙的 JPEG（filePath 已含 postProcess 色彩矩阵 +
/// transform 变换）。不再叠加 ColorFiltered，避免"2x 参数"效果。
/// 支持 InteractiveViewer 双指缩放与拖拽查看细节。
///
/// 当 isComparing 为 true 且 photo.originalPath 存在时，切换显示原图
/// （未应用后期参数的原始照片），便于与编辑后效果对比。
class _ReadOnlyCanvas extends StatelessWidget {
  const _ReadOnlyCanvas({
    required this.photo,
    required this.tokens,
    this.isComparing = false,
  });

  final GalleryItemRecord photo;
  final ThemeTokens tokens;
  final bool isComparing;

  @override
  Widget build(BuildContext context) {
    // 对比模式优先显示原图；否则显示已烘焙的成品（filePath 优先，回退 dataUrl）
    final String? url;
    if (isComparing &&
        photo.originalPath != null &&
        photo.originalPath!.isNotEmpty) {
      url = photo.originalPath;
    } else {
      url = photo.dataUrl ?? photo.filePath;
    }
    final screenHeight = MediaQuery.of(context).size.height;
    final canvasHeight = screenHeight * 0.45;

    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          height: canvasHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: url == null || url.isEmpty
                ? Container(
                    color: tokens.surfaceAlt,
                    child: Center(
                      child: Icon(Icons.image_outlined,
                          size: 32, color: tokens.textTertiary),
                    ),
                  )
                : InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    panEnabled: true,
                    scaleEnabled: true,
                    boundaryMargin: EdgeInsets.zero,
                    child: _buildImage(url),
                  ),
          ),
        ),
        // 对比模式右上角标记
        if (isComparing && url != null && url.isNotEmpty)
          Positioned(
            top: 24,
            right: 24,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tokens.brandDeep,
                borderRadius: BorderRadius.circular(1000),
              ),
              child: Text(
                '原图',
                style: TextStyle(
                  fontSize: 11,
                  color: tokens.textInverse,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImage(String url) {
    Widget imageWidget = url.startsWith('http')
        ? Image.network(url, fit: BoxFit.contain)
        : Image.file(
            File(url),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              color: tokens.surfaceAlt,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.broken_image_outlined,
                        size: 32, color: tokens.textTertiary),
                    const SizedBox(height: 8),
                    Text('图片加载失败',
                        style: TextStyle(fontSize: 12, color: tokens.textTertiary)),
                  ],
                ),
              ),
            ),
          );

    // JPEG 已烘焙 transform 变换（processFile 调用 _applyTransform），
    // 此处不再叠加 RotatedBox/Transform，避免双重变换。
    return imageWidget;
  }
}

/// 元信息 Section：拍摄时间 + 心情 + 原图保留状态
class _MetaInfoSection extends StatelessWidget {
  const _MetaInfoSection({required this.photo, required this.tokens});
  final GalleryItemRecord photo;
  final ThemeTokens tokens;

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
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 拍摄时间
          _MetaLabel(text: '拍摄时间', tokens: tokens),
          const SizedBox(height: 6),
          if (relative.isNotEmpty)
            Text(
              relative,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
          Text(
            absolute,
            style: TextStyle(
              fontSize: 12,
              color: tokens.textSecondary,
              height: 1.4,
            ),
          ),
          // 心情标签
          if (hasMood) ...[
            const SizedBox(height: 16),
            _MetaLabel(text: '心情', tokens: tokens),
            const SizedBox(height: 6),
            _MoodChip(mood: photo.mood!, tokens: tokens),
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
                  color: hasOriginal ? tokens.success : tokens.textTertiary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                hasOriginal ? '原图已保留 · 可再次修图' : '原图未保留',
                style: TextStyle(
                  fontSize: 12,
                  color: hasOriginal ? tokens.success : tokens.textTertiary,
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
  const _MetaLabel({required this.text, required this.tokens});
  final String text;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color: tokens.textTertiary,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _MoodChip extends StatelessWidget {
  const _MoodChip({required this.mood, required this.tokens});
  final String mood;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(1000),
        border: Border.all(color: tokens.brand.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mood_outlined, size: 14, color: tokens.brand),
          const SizedBox(width: 6),
          Text(
            mood,
            style: TextStyle(
              fontSize: 13,
              color: tokens.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 分类（场景）Section：显示当前分类并支持更换
class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.tokens,
    required this.sceneName,
    required this.sceneId,
    required this.onChange,
  });

  final ThemeTokens tokens;
  final String? sceneName;
  final String? sceneId;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final hasCategory = sceneId != null && sceneId!.isNotEmpty;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '分类',
                style: TextStyle(
                  fontSize: 11,
                  color: tokens.textTertiary,
                  letterSpacing: 0.5,
                ),
              ),
              GestureDetector(
                onTap: onChange,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_horiz, size: 14, color: tokens.brand),
                      const SizedBox(width: 4),
                      Text(
                        '更换',
                        style: TextStyle(
                          fontSize: 13,
                          color: tokens.brand,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (hasCategory)
            Row(
              children: [
                Icon(Icons.place_outlined, size: 16, color: tokens.brand),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    sceneName ?? '未知分类',
                    style: TextStyle(
                      fontSize: 15,
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Icon(Icons.label_off_outlined, size: 16, color: tokens.textTertiary),
                const SizedBox(width: 6),
                Text(
                  '未分类',
                  style: TextStyle(
                    fontSize: 14,
                    color: tokens.textTertiary,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// 分类选择底部 Sheet
class _CategoryPickerSheet extends StatelessWidget {
  const _CategoryPickerSheet({
    required this.tokens,
    required this.scenes,
    required this.currentSceneId,
  });

  final ThemeTokens tokens;
  final List<SceneRecord> scenes;
  final String? currentSceneId;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.7;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '选择分类',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 20, color: tokens.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: tokens.divider),
          // 场景列表
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // 移除分类选项
                if (currentSceneId != null)
                  _CategoryOption(
                    tokens: tokens,
                    icon: Icons.label_off_outlined,
                    label: '移除分类',
                    selected: false,
                    isRemove: true,
                    onTap: () => Navigator.of(context).pop('__none__'),
                  ),
                // 所有场景
                ...scenes.map((scene) => _CategoryOption(
                      tokens: tokens,
                      icon: _iconForScene(scene.icon),
                      label: scene.name.isEmpty ? '(未命名场景)' : scene.name,
                      selected: scene.id == currentSceneId,
                      onTap: () => Navigator.of(context).pop(scene.id),
                    )),
                if (scenes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '暂无可用场景',
                      style: TextStyle(fontSize: 13, color: tokens.textTertiary),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForScene(String icon) {
    switch (icon) {
      case 'cafe':
      case 'coffee':
        return Icons.local_cafe_outlined;
      case 'street':
        return Icons.location_city_outlined;
      case 'nature':
        return Icons.park_outlined;
      case 'portrait':
        return Icons.person_outlined;
      case 'food':
        return Icons.restaurant_outlined;
      case 'indoor':
        return Icons.home_outlined;
      case 'travel':
        return Icons.flight_outlined;
      default:
        return Icons.place_outlined;
    }
  }
}

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    required this.tokens,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.isRemove = false,
  });

  final ThemeTokens tokens;
  final IconData icon;
  final String label;
  final bool selected;
  final bool isRemove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isRemove
        ? tokens.danger
        : (selected ? tokens.brand : tokens.textPrimary);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (selected)
              Icon(Icons.check, size: 18, color: tokens.brand),
          ],
        ),
      ),
    );
  }
}

/// 模板/场景信息 Chip 区
class _SourceChipsSection extends StatelessWidget {
  const _SourceChipsSection({
    required this.tokens,
    required this.sceneName,
    required this.templateName,
    required this.sceneId,
    required this.templateId,
  });

  final ThemeTokens tokens;
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
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '拍摄来源',
            style: TextStyle(
              fontSize: 11,
              color: tokens.textTertiary,
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
                  tokens: tokens,
                  icon: Icons.place_outlined,
                  label: sceneName!,
                  onTap: () => GoRouter.of(context).push(
                    RouteNames.build(RouteNames.captureSceneDetail,
                        {RouteNames.paramSceneId: sceneId!}),
                  ),
                ),
              if (templateName != null && templateId != null)
                _SourceChip(
                  tokens: tokens,
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
    required this.tokens,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final ThemeTokens tokens;
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
          color: tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(1000),
          border: Border.all(color: tokens.brand, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: tokens.brand),
            const SizedBox(width: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: tokens.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 14, color: tokens.brand),
          ],
        ),
      ),
    );
  }
}

/// 底部"后期修图"按钮
class _EditBottomBar extends StatelessWidget implements PreferredSizeWidget {
  const _EditBottomBar({required this.tokens, required this.isReadOnly, required this.onTap});
  final ThemeTokens tokens;
  final bool isReadOnly;
  final VoidCallback onTap;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tokens.canvasDeep,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
          decoration: BoxDecoration(
            color: tokens.canvasDeep,
            border: Border(top: BorderSide(color: tokens.divider, width: 1)),
          ),
          child: GestureDetector(
            onTap: onTap,
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
                    Icon(
                      Icons.tune,
                      size: 18,
                      color: isReadOnly ? tokens.textTertiary : tokens.textInverse,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isReadOnly ? '原图未保留' : '后期修图',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isReadOnly ? tokens.textTertiary : tokens.textInverse,
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
