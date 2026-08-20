import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/safe_share.dart';

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
import '../../watermark/data/watermark_providers.dart';
import '../providers/gallery_diary_providers.dart';

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

  /// 展示中照片的宽高比（异步解析，用于让预览区按照片自然比例自适应，null 时回退固定高度）
  double? _photoAspectRatio;

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
      // 异步解析照片宽高比，让预览区按照片自然比例自适应（失败则回退固定高度）
      if (photo != null) {
        final displayUrl = photo.dataUrl ?? photo.filePath;
        if (displayUrl != null && displayUrl.isNotEmpty) {
          _resolveAspectRatio(displayUrl).then((ratio) {
            if (mounted && ratio != null && ratio > 0) {
              setState(() => _photoAspectRatio = ratio);
            }
          });
        }
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
      LumiraToast.show(context, '已更换场景', duration: const Duration(milliseconds: 1000));
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

  /// 当前预览中展示的图片 URL（对比时为原图，否则为成品）
  String? _currentDisplayUrl() {
    final photo = _photo;
    if (photo == null) return null;
    if (_isComparing &&
        photo.originalPath != null &&
        photo.originalPath!.isNotEmpty) {
      return photo.originalPath;
    }
    return photo.dataUrl ?? photo.filePath;
  }

  /// 点击照片预览 → 打开全屏大图查看器（支持双指缩放）
  void _openFullscreen() {
    final url = _currentDisplayUrl();
    if (url == null || url.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullscreenViewer(url: url),
      ),
    );
  }

  /// 解析图片宽高比（本地文件与网络图片均支持），失败返回 null
  Future<double?> _resolveAspectRatio(String url) {
    final completer = Completer<ui.Image>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) completer.complete(info.image);
      },
      onError: (error, _) {
        if (!completer.isCompleted) completer.completeError(error);
      },
    );
    final stream = _imageProviderFor(url).resolve(const ImageConfiguration());
    stream.addListener(listener);

    return completer.future.then<double?>((image) {
      stream.removeListener(listener);
      final ratio = image.width / (image.height == 0 ? 1 : image.height);
      image.dispose();
      return ratio;
    }).catchError((_) {
      stream.removeListener(listener);
      return null;
    });
  }

  ImageProvider<Object> _imageProviderFor(String url) {
    if (url.startsWith('http')) return NetworkImage(url);
    return FileImage(File(url));
  }

  /// 记录探店：跳转到探店新增页，预填当前照片
  Future<void> _onCheckin() async {
    final photo = _photo;
    if (photo == null) return;
    await GoRouter.of(context).push(RouteNames.build(
      RouteNames.checkinEdit,
      {RouteNames.paramPhotoId: photo.id},
    ));
  }

  /// 标记为穿搭日记：弹出场景选择器
  Future<void> _onOutfitMark() async {
    final photo = _photo;
    final scenes = _allScenes;
    if (photo == null) return;
    if (scenes.isEmpty) {
      LumiraToast.show(context, '暂无可用场景', duration: const Duration(milliseconds: 1500));
      return;
    }
    final tokens = ref.read(themeTokensProvider);
    final selected = await showLumiraBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _OutfitScenePicker(
        scenes: scenes,
        currentSceneId: photo.sceneId,
        tokens: tokens,
      ),
    );
    if (selected == null || !mounted) return;
    try {
      final dao = await ref.read(galleryDaoProvider.future);
      await dao.updateScene(photo.id, selected);
      if (!mounted) return;
      setState(() {
        _photo = GalleryItemRecord(
          id: photo.id,
          dataUrl: photo.dataUrl,
          filePath: photo.filePath,
          originalPath: photo.originalPath,
          transform: photo.transform,
          postProcess: photo.postProcess,
          sceneId: selected,
          templateId: photo.templateId,
          kitId: photo.kitId,
          mood: photo.mood,
          lut: photo.lut,
          isFavorite: photo.isFavorite,
          createdAt: photo.createdAt,
        );
      });
      ref.invalidate(diaryEntriesProvider(const DiaryFilter(tab: kDiaryTabOutfit)));
      ref.invalidate(diaryStreakProvider);
      LumiraToast.show(context, '已标记为穿搭日记', duration: const Duration(milliseconds: 1500));
    } catch (e) {
      if (mounted) {
        LumiraToast.show(context, '标记失败：$e', duration: const Duration(seconds: 2));
      }
    }
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
      await SafeShare.shareXFiles(
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

  /// 二次添加水印：读取当前照片路径与当前水印模板，跳转应用模式编辑器。
  /// 编辑器保存后以"另存新照片"入相册，返回后刷新画廊列表 provider。
  Future<void> _onAddWatermark() async {
    final photo = _photo;
    if (photo == null) return;
    final photoPath = photo.filePath;
    if (photoPath == null || photoPath.isEmpty) {
      LumiraToast.show(
        context,
        '仅支持本地照片添加水印',
        duration: const Duration(seconds: 2),
      );
      return;
    }
    final templateId = ref.read(currentWatermarkTemplateProvider)?.id;
    final target = RouteNames.build(
      RouteNames.galleryWatermarkApply,
      {
        RouteNames.paramPhoto: photoPath,
        if (templateId != null && templateId.isNotEmpty)
          RouteNames.paramTemplateId: templateId,
      },
    );
    debugPrint('[gallery-detail] onAddWatermark push target=$target');
    await GoRouter.of(context).push(target);
    if (!mounted) return;
    debugPrint('[gallery-detail] onAddWatermark after push uri=${GoRouter.of(context).routerDelegate.currentConfiguration.uri}');
    ref.invalidate(galleryDaoProvider);
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
          if (_photo != null)
            _FavoriteButton(
              photo: _photo!,
              tokens: tokens,
              onToggled: _onFavoriteToggled,
            ),
          if (_photo != null)
            _MoreAction(
              tokens: tokens,
              onCheckin: _onCheckin,
              onOutfitMark: _onOutfitMark,
              onShare: _onShare,
              onDelete: _onDelete,
              onAddWatermark: _onAddWatermark,
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
      bottomNavigationBar: _photo == null
          ? null
          : _EditBottomBar(
              tokens: tokens,
              isReadOnly: _photo?.originalPath == null,
              photo: _photo!,
              onTap: _onEditTap,
              onShare: _onShare,
              onFavoriteToggle: _onFavoriteToggled,
            ),
    );
  }

  /// 收藏状态切换：更新本地 _photo 并刷新收藏列表
  void _onFavoriteToggled(bool next) {
    if (_photo == null) return;
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
  }

  Widget _buildContent(GalleryItemRecord photo, ThemeTokens tokens) {
    // 进入/切换照片时淡入 + 轻微上移，提升流畅感
    return TweenAnimationBuilder<double>(
      key: ValueKey(photo.id),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - t)),
          child: child,
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. 照片预览区（应用 photo.postProcess 滤镜，只读）
            // _isComparing 为 true 时切换显示原图
            _ReadOnlyCanvas(
              photo: photo,
              tokens: tokens,
              isComparing: _isComparing,
              onCompareToggle: _onCompareToggle,
              aspectRatio: _photoAspectRatio,
              onTap: _openFullscreen,
            ),
            // 1.5 心情独立凸显（照片正下方、信息面板之上）
            if (photo.mood != null && photo.mood!.isNotEmpty)
              _MoodHero(mood: photo.mood!, tokens: tokens),
            // 2. 照片信息 section（合并元信息/分类/来源，消除卡片汤与场景重复）
            _PhotoInfoSection(
              photo: photo,
              tokens: tokens,
              sceneName: _sceneName,
              templateName: _templateName,
              sceneId: photo.sceneId,
              templateId: photo.templateId,
              onChangeCategory: _onChangeCategory,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// 穿搭场景选择器 BottomSheet
class _OutfitScenePicker extends StatelessWidget {
  const _OutfitScenePicker({
    required this.scenes,
    required this.currentSceneId,
    required this.tokens,
  });

  final List<SceneRecord> scenes;
  final String? currentSceneId;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.5;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Text(
              '选择穿搭场景',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                ...scenes.map((scene) => GestureDetector(
                  onTap: () => Navigator.of(context).pop(scene.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    decoration: BoxDecoration(
                      color: scene.id == currentSceneId ? tokens.brandSubtle : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.checkroom_outlined, size: 18, color: tokens.brand),
                        const SizedBox(width: 12),
                        Text(
                          scene.name,
                          style: TextStyle(fontSize: 15, color: tokens.textPrimary),
                        ),
                        if (scene.id == currentSceneId) ...[
                          const Spacer(),
                          Icon(Icons.check, size: 18, color: tokens.brand),
                        ],
                      ],
                    ),
                  ),
                )),
              ],
            ),
          ),
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

/// AppBar "更多"按钮：点击弹出 BottomSheet，提供"记录探店" / "标记为穿搭日记" / "分享照片" / "添加水印" / "删除照片"操作。
class _MoreAction extends StatelessWidget {
  const _MoreAction({
    required this.tokens,
    required this.onCheckin,
    required this.onOutfitMark,
    required this.onShare,
    required this.onDelete,
    required this.onAddWatermark,
  });

  final ThemeTokens tokens;
  final Future<void> Function() onCheckin;
  final Future<void> Function() onOutfitMark;
  final Future<void> Function() onShare;
  final Future<void> Function() onDelete;
  final Future<void> Function() onAddWatermark;

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
            icon: Icons.place_outlined,
            label: '记录探店',
            color: tokens.brand,
            onTap: () => Navigator.of(ctx).pop('checkin'),
          ),
          Divider(height: 1, color: tokens.divider),
          _MoreSheetOption(
            tokens: tokens,
            icon: Icons.checkroom_outlined,
            label: '标记为穿搭日记',
            color: tokens.brand,
            onTap: () => Navigator.of(ctx).pop('outfit'),
          ),
          Divider(height: 1, color: tokens.divider),
          _MoreSheetOption(
            tokens: tokens,
            icon: Icons.ios_share_outlined,
            label: '分享照片',
            onTap: () => Navigator.of(ctx).pop('share'),
          ),
          Divider(height: 1, color: tokens.divider),
          _MoreSheetOption(
            tokens: tokens,
            icon: Icons.photo_filter_outlined,
            label: '添加水印',
            color: tokens.brand,
            onTap: () => Navigator.of(ctx).pop('watermark'),
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
    if (result == 'checkin') {
      await onCheckin();
    } else if (result == 'outfit') {
      await onOutfitMark();
    } else if (result == 'share') {
      await onShare();
    } else if (result == 'watermark') {
      await onAddWatermark();
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
    this.color,
  });

  final ThemeTokens tokens;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDanger;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? (isDanger ? tokens.danger : tokens.textPrimary);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: effectiveColor),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: effectiveColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 收藏按钮（心心点击有按压缩放 + 弹跳动效）
class _FavoriteButton extends ConsumerStatefulWidget {
  const _FavoriteButton({
    required this.photo,
    required this.tokens,
    required this.onToggled,
    this.round = false,
  });
  final GalleryItemRecord photo;
  final ThemeTokens tokens;
  final void Function(bool next) onToggled;

  /// 是否为底部栏的圆形图标按钮样式（new 拟态凸起）
  final bool round;

  @override
  ConsumerState<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<_FavoriteButton> {
  bool _pressed = false;

  ThemeTokens get tokens => widget.tokens;

  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    final selected = photo.isFavorite;
    final color = selected ? tokens.danger : tokens.textSecondary;

    final Widget icon = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => ScaleTransition(
        scale: Tween(begin: 0.4, end: 1.0).animate(anim),
        child: child,
      ),
      child: Icon(
        selected ? Icons.favorite : Icons.favorite_border,
        key: ValueKey(selected),
        size: widget.round ? 20 : 20,
        color: color,
      ),
    );

    final Widget content = widget.round
        ? Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tokens.canvasDeep,
              borderRadius: BorderRadius.circular(1000),
              boxShadow: tokens.shadowConvexSubtle,
            ),
            child: Center(child: icon),
          )
        : Padding(
            padding: const EdgeInsets.all(8),
            child: icon,
          );

    return GestureDetector(
      onTap: () async {
        try {
          final dao = await ref.read(galleryDaoProvider.future);
          await dao.toggleFavorite(photo.id);
          widget.onToggled(!photo.isFavorite);
          if (context.mounted) {
            // 轻触震动，强化交互反馈
            HapticFeedback.lightImpact();
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
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: content,
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
    required this.onCompareToggle,
    this.aspectRatio,
    this.onTap,
  });

  final GalleryItemRecord photo;
  final ThemeTokens tokens;
  final bool isComparing;
  final VoidCallback onCompareToggle;

  /// 照片宽高比（宽/高）。有值时预览区按此比例自适应高度，避免固定高度带来的空白。
  final double? aspectRatio;

  /// 点击照片预览的回调（用于打开全屏大图查看器）
  final VoidCallback? onTap;

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
    final hasOriginal =
        photo.originalPath != null && photo.originalPath!.isNotEmpty;
    final screenHeight = MediaQuery.of(context).size.height;
    final canvasHeight = screenHeight * 0.45;

    final Widget inner = ClipRRect(
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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: KeyedSubtree(
                  key: ValueKey(url),
                  child: _buildImage(url),
                ),
              ),
            ),
    );

    // 有宽高比时按比例自适应，否则回退固定高度
    final Widget frame;
    if (aspectRatio != null && aspectRatio! > 0) {
      frame = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: AspectRatio(aspectRatio: aspectRatio!, child: inner),
      );
    } else {
      frame = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: canvasHeight,
        child: inner,
      );
    }

    return Stack(
      children: [
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: frame,
        ),
        // 对比切换浮层：从 AppBar 迁移到照片上，简化导航栏
        if (hasOriginal)
          Positioned(
            bottom: 16,
            right: 16,
            child: GestureDetector(
              onTap: onCompareToggle,
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isComparing
                      ? tokens.brand
                      : Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(1000),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isComparing ? Icons.visibility : Icons.compare_outlined,
                      size: 14,
                      color: isComparing ? tokens.textInverse : Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isComparing ? '原图' : '对比',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isComparing ? tokens.textInverse : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImage(String url) {
    // 强制图片填满整个取景框，让 BoxFit.contain 在框内水平居中；
    // 否则 InteractiveViewer 会把小于视口的图片按左上角对齐，导致右侧大片空白。
    Widget imageWidget = url.startsWith('http')
        ? Image.network(
            url,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.contain,
          )
        : Image.file(
            File(url),
            width: double.infinity,
            height: double.infinity,
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

/// 照片信息 Section：合并原"元信息 / 分类 / 来源"三张卡片为一张面板，
/// 消除卡片汤与"场景"信息的重复展示，同时保留全部原有功能：
/// - 拍摄时间（相对 + 绝对）、心情、原图保留状态
/// - 分类（场景）展示 + "更换"操作 + 点击场景名跳转场景详情
/// - 拍摄模板展示 + 点击跳转模板详情
class _PhotoInfoSection extends StatelessWidget {
  const _PhotoInfoSection({
    required this.photo,
    required this.tokens,
    required this.sceneName,
    required this.templateName,
    required this.sceneId,
    required this.templateId,
    required this.onChangeCategory,
  });

  final GalleryItemRecord photo;
  final ThemeTokens tokens;
  final String? sceneName;
  final String? templateName;
  final String? sceneId;
  final String? templateId;
  final VoidCallback onChangeCategory;

  @override
  Widget build(BuildContext context) {
    final relative = formatRelativeTime(photo.createdAt);
    final absolute = formatAbsoluteTime(photo.createdAt);
    final hasOriginal =
        photo.originalPath != null && photo.originalPath!.isNotEmpty;
    final hasCategory = sceneId != null && sceneId!.isNotEmpty;
    final showSource =
        hasCategory || (templateName != null && templateId != null);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: tokens.shadowConvex,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 面板标题
          _MetaLabel(text: '照片信息', tokens: tokens),
          const SizedBox(height: 12),
          // 拍摄时间
          if (relative.isNotEmpty)
            Text(
              relative,
              style: TextStyle(
                fontSize: 17,
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
          // 原图保留状态
          const SizedBox(height: 12),
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
              Expanded(
                child: Text(
                  hasOriginal ? '原图已保留 · 可再次修图' : '原图未保留',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: hasOriginal ? tokens.success : tokens.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          // 来源信息：分类（场景）+ 拍摄模板
          if (showSource) ...[
            Divider(height: 24, color: tokens.divider),
            Row(
              children: [
                Icon(Icons.place_outlined, size: 16, color: tokens.brand),
                const SizedBox(width: 6),
                Expanded(
                  child: hasCategory
                      ? GestureDetector(
                          onTap: () => _jumpScene(context),
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  sceneName ?? '未知场景',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: tokens.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(Icons.chevron_right,
                                  size: 14, color: tokens.brand),
                            ],
                          ),
                        )
                      : Text(
                          '未设置场景',
                          style:
                              TextStyle(fontSize: 14, color: tokens.textTertiary),
                        ),
                ),
                const SizedBox(width: 8),
                // 更换分类
                GestureDetector(
                  onTap: onChangeCategory,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: tokens.brandSubtle,
                      borderRadius: BorderRadius.circular(1000),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.swap_horiz, size: 13, color: tokens.brand),
                        const SizedBox(width: 4),
                        Text(
                          '更换',
                          style: TextStyle(
                            fontSize: 12,
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
            // 拍摄模板
            if (templateName != null && templateId != null) ...[
              const SizedBox(height: 12),
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
          ],
        ],
      ),
    );
  }

  void _jumpScene(BuildContext context) {
    final id = sceneId;
    if (id == null || id.isEmpty) return;
    GoRouter.of(context).push(
      RouteNames.build(RouteNames.captureSceneDetail,
          {RouteNames.paramSceneId: id}),
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

/// 照片正下方的独立心情凸显区：柔和背景胶囊 + 表情图标 + 心情名，成为视觉焦点。
class _MoodHero extends StatelessWidget {
  const _MoodHero({required this.mood, required this.tokens});
  final String mood;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.brandSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.brandLight.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_moodIconFor(mood), size: 18, color: tokens.brand),
          const SizedBox(width: 8),
          Text(
            '今天的心情 · $mood',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 心情名 → 图标映射（与 CapturePreviewMockData.moods 保持一致）
IconData _moodIconFor(String mood) {
  switch (mood) {
    case '开心':
      return Icons.sentiment_satisfied;
    case '甜酷':
      return Icons.wb_sunny_outlined;
    case '温柔':
      return Icons.local_florist_outlined;
    case '复古':
      return Icons.movie_outlined;
    case '清新':
      return Icons.eco_outlined;
    case '文艺':
      return Icons.palette_outlined;
    case '治愈':
      return Icons.grass_outlined;
    default:
      return Icons.sentiment_satisfied;
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
                  '选择场景',
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
                    label: '移除场景',
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
          color: tokens.brandSubtle,
          borderRadius: BorderRadius.circular(1000),
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

/// 底部操作栏：左侧收藏/分享辅操作 + 右侧"后期修图"主按钮。
/// 简洁一栏式；辅操作用新拟态圆形图标按钮，主按钮用品牌金色渐变 +
/// 柔和品牌辉光，按下有缩放反馈，贴合项目 warm 新拟态美学。
class _EditBottomBar extends StatelessWidget implements PreferredSizeWidget {
  const _EditBottomBar({
    required this.tokens,
    required this.isReadOnly,
    required this.photo,
    required this.onTap,
    required this.onShare,
    required this.onFavoriteToggle,
  });
  final ThemeTokens tokens;
  final bool isReadOnly;
  final GalleryItemRecord photo;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final ValueChanged<bool> onFavoriteToggle;

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tokens.canvasDeep,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(color: tokens.canvasDeep),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 辅操作组：收藏 + 分享
              _FavoriteButton(
                photo: photo,
                tokens: tokens,
                onToggled: onFavoriteToggle,
                round: true,
              ),
              const SizedBox(width: 16),
              _RoundActionButton(
                tokens: tokens,
                icon: Icons.ios_share_outlined,
                onTap: onShare,
              ),
              const Spacer(),
              // 主按钮：后期修图
              _PrimaryPillButton(
                tokens: tokens,
                isReadOnly: isReadOnly,
                onTap: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 底部主按钮：品牌金色渐变胶囊 + 柔和辉光，按下缩放反馈。
class _PrimaryPillButton extends StatelessWidget {
  const _PrimaryPillButton({
    required this.tokens,
    required this.isReadOnly,
    required this.onTap,
  });

  final ThemeTokens tokens;
  final bool isReadOnly;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PressableScale(
      onTap: onTap,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: BoxDecoration(
          gradient: isReadOnly
              ? null
              : LinearGradient(
                  colors: [tokens.brandLight, tokens.brand, tokens.brandDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: isReadOnly ? tokens.surfaceAlt : null,
          borderRadius: BorderRadius.circular(1000),
          boxShadow: isReadOnly
              ? null
              : [
                  BoxShadow(
                    color: tokens.brand.withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: tokens.brandLight.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(-2, -2),
                  ),
                ],
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
    );
  }
}

/// 新拟态圆形图标辅操作按钮（凸起阴影 + 按下缩放反馈）
class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    required this.tokens,
    required this.icon,
    required this.onTap,
  });

  final ThemeTokens tokens;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PressableScale(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: tokens.canvasDeep,
          borderRadius: BorderRadius.circular(1000),
          boxShadow: tokens.shadowConvexSubtle,
        ),
        child: Center(
          child: Icon(icon, size: 20, color: tokens.textSecondary),
        ),
      ),
    );
  }
}

/// 通用按压缩放反馈容器：按下缩小 0.9，松开回弹。
class _PressableScale extends StatefulWidget {
  const _PressableScale({required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// 全屏大图查看器：黑底 + InteractiveViewer 双指缩放/拖拽，点击图片或右上角关闭。
/// 用于从相册详情页点击照片预览后查看大图。
class _FullscreenViewer extends StatelessWidget {
  const _FullscreenViewer({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 图片主体：黑底居中，支持缩放/拖拽
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 5.0,
                panEnabled: true,
                scaleEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                child: url.startsWith('http')
                    ? Image.network(
                        url,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : Image.file(
                        File(url),
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                      ),
              ),
            ),
          ),
          // 右上角关闭按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
