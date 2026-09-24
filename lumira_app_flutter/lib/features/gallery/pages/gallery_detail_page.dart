import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/images/fullscreen_image_gallery.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/common/lumira_surface.dart';
import '../../../shared/services/poster_generator.dart';
import '../../../shared/widgets/poster/poster_ratio.dart';
import '../../../shared/widgets/poster/poster_style_types.dart';
import '../../../shared/widgets/poster/template_poster_widgets.dart';

import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/dao/scenes_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/time_format.dart';
import '../../../shared/widgets/images/lumira_image.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../profile/providers/collection_providers.dart';
import '../../templates/widgets/adaptive_cover_image.dart';
import '../../watermark/data/watermark_providers.dart';
import '../../capture/data/scene_presets_data.dart';
import '../../capture/data/template_registry.dart';
import '../../capture/data/capture_preview_mock_data.dart';

/// 原生「保存到系统相册」MethodChannel（与拍摄预览页共用同一通道，见
/// CapturePreviewPage 同名字段）：{ 'path': <本地文件绝对路径> } -> { success, error }
const _photoSaverChannel = MethodChannel('lumira/photo_saver');

/// 相册照片详情页（查看为主）
///
/// 设计文档：docs/superpowers/specs/2026-07-31-gallery-detail-edit-split-design.md
///
/// 职责：
/// - 显示照片预览（只读，应用照片已保存的 postProcess 滤镜）
/// - 显示照片元信息：拍摄时间（相对+绝对）、原图保留状态
/// - 心情标签：点击可设置/更换/清除（与拍摄预览页同一套心情选项）
/// - 显示模板信息为可点击 Chip，点击跳转模板详情页
/// - 场景（分类）行始终展示并可设置/更换，未套用模板拍摄的照片同样可设置
/// - 底部"后期修图"按钮，跳转到 /gallery/edit?photoId=xxx
///
/// 编辑能力已迁移至 GalleryEditPage（lib/features/gallery/pages/gallery_edit_page.dart）
class GalleryDetailPage extends ConsumerStatefulWidget {
  const GalleryDetailPage({super.key, this.photoId, this.scopeIds});

  final String? photoId;

  /// 可选的左右滑动范围：非空时仅在该照片 ID 列表内滑动切换相邻照片
  /// （用于从拍摄日记进入时，滑动范围跟随拍摄日记的照片列表而非整个相册）
  final List<String>? scopeIds;

  @override
  ConsumerState<GalleryDetailPage> createState() => _GalleryDetailPageState();
}

class _GalleryDetailPageState extends ConsumerState<GalleryDetailPage> {
  /// 当前相册内全部照片（最新在前，顺序与相册列表一致），用于左右滑动切换相邻照片
  List<GalleryItemRecord> _photos = const [];

  /// 当前展示照片在 [_photos] 中的索引
  int _index = 0;

  /// 分页控制器，负责滑动切换相邻照片的动画
  late final PageController _pageController;

  bool _isLoading = true;
  bool _isInitialLoaded = false;

  /// 模板 id → 名称（整册预载，供每张照片详情页各自显示模板名）
  final Map<String, String> _templateNameById = {};

  /// 场景 id → 名称（整册预载，供每张照片详情页各自显示场景名）
  final Map<String, String> _sceneNameById = {};

  /// 所有可用场景列表（用于分类更换选择器）
  List<SceneRecord> _allScenes = const [];

  /// 是否处于"对比"模式（切换显示原图 / 已烘焙成品）。
  bool _isComparing = false;

  GalleryItemRecord? get _photo {
    if (_photos.isEmpty || _index < 0 || _index >= _photos.length) return null;
    return _photos[_index];
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadPhoto(GalleryDao dao) async {
    try {
      if (widget.photoId == null) {
        if (mounted) {
          setState(() {
            _photos = const [];
            _index = 0;
            _isLoading = false;
          });
        }
        return;
      }

      // 拉取照片列表并定位当前照片（找不到则停留在第一张）
      var photos = await dao.getAll();
      // 指定了滑动范围时，仅保留范围内的照片（拍摄日记进入场景）
      if (widget.scopeIds != null && widget.scopeIds!.isNotEmpty) {
        final scope = widget.scopeIds!.toSet();
        photos = photos.where((p) => scope.contains(p.id)).toList();
      }
      var index = photos.indexWhere((p) => p.id == widget.photoId);
      if (index < 0) index = 0;

      // 整册预载场景/模板名称映射，供左右滑动后每张照片各自正确显示来源信息
      try {
        final scenesDao = await ref.read(scenesDaoProvider.future);
        final allScenes = await scenesDao.getAll();
        final templateNameById = <String, String>{};
        final sceneNameById = <String, String>{
          for (final s in allScenes) s.id: s.name,
        };
        final templatesDao = await ref.read(templatesDaoProvider.future);
        for (final t in await templatesDao.getAll()) {
          templateNameById[t.id] = t.name;
        }
        // 补充 TemplateRegistry 中的模板名（DB 未种子化新模板时的兜底）
        for (final t in TemplateRegistry.allTemplates) {
          templateNameById.putIfAbsent(t.meta.id, () => t.meta.name);
        }
        if (mounted) {
          _templateNameById
            ..clear()
            ..addAll(templateNameById);
          _sceneNameById
            ..clear()
            ..addAll(sceneNameById);
          setState(() => _allScenes = allScenes);
        }
      } catch (e, st) {
        debugPrint('[gallery-detail] 预载场景/模板名称异常: $e\n$st');
      }

      if (mounted) {
        setState(() {
          _photos = photos;
          _index = index;
          _isComparing = false;
          _isLoading = false;
        });
      }
      if (photos.isEmpty) return;
      // 定位到目标照片（若初始页非 0，则跳到目标索引）
      if (index != 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) {
            _pageController.jumpToPage(index);
          }
        });
      }
    } catch (e, st) {
      debugPrint('[gallery-detail] _loadPhoto 异常: $e\n$st');
      if (mounted) {
        setState(() {
          _photos = const [];
          _index = 0;
          _isLoading = false;
        });
      }
    }
  }

  /// 覆盖当前照片记录（用于收藏/更换分类/标记穿搭日记后同步列表数据）
  void _replaceCurrent(GalleryItemRecord record) {
    if (_index < 0 || _index >= _photos.length) return;
    final next = List<GalleryItemRecord>.of(_photos);
    next[_index] = record;
    setState(() => _photos = next);
  }

  /// 滑动切换照片时更新当前索引并重置对比模式
  void _onPageChanged(int index) {
    if (index == _index) return;
    if (index < 0 || index >= _photos.length) return;
    setState(() {
      _index = index;
      _isComparing = false;
    });
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
    final appTheme = ref.read(appThemeProvider);

    final result = await showLumiraBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CategoryPickerSheet(
        tokens: appTheme.tokens,
        style: appTheme.style,
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
      final updatedPhoto = GalleryItemRecord(
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
      _replaceCurrent(updatedPhoto);
      if (newSceneId != null && newSceneName != null) {
        final name = newSceneName;
        setState(() => _sceneNameById[newSceneId] = name);
      }
      ref.invalidate(collectionsListProvider);
      // 场景被拍摄日记（穿搭视图）等下游页面使用，失效 DAO 让其重新读取
      ref.invalidate(galleryDaoProvider);
      LumiraToast.show(context, '已更换场景', duration: const Duration(milliseconds: 1000));
    } catch (e) {
      if (mounted) {
        LumiraToast.show(context, '更换失败：$e', duration: const Duration(seconds: 2));
      }
    }
  }

  /// 设置/更换/清除心情：弹出底部 Sheet 选择（与拍摄预览页同一套心情选项），
  /// 保存后同步更新当前照片记录，并失效 DAO 让日记等下游页面重新读取。
  Future<void> _onChangeMood() async {
    final photo = _photo;
    if (photo == null) return;
    final tokens = ref.read(themeTokensProvider);

    final result = await showLumiraBottomSheet<String?>(
      context: context,
      builder: (ctx) => _MoodPickerSheet(
        tokens: tokens,
        currentMood: photo.mood,
      ),
    );

    if (result == null || !mounted) return;

    // result 为 '__none__' 表示清除心情；否则为新心情名
    final newMood = result == '__none__' ? null : result;
    if (newMood == photo.mood) return;

    try {
      final dao = await ref.read(galleryDaoProvider.future);
      await dao.updateMood(photo.id, newMood);
      if (!mounted) return;
      final updatedPhoto = GalleryItemRecord(
        id: photo.id,
        dataUrl: photo.dataUrl,
        filePath: photo.filePath,
        originalPath: photo.originalPath,
        transform: photo.transform,
        postProcess: photo.postProcess,
        sceneId: photo.sceneId,
        templateId: photo.templateId,
        kitId: photo.kitId,
        mood: newMood,
        lut: photo.lut,
        isFavorite: photo.isFavorite,
        createdAt: photo.createdAt,
      );
      _replaceCurrent(updatedPhoto);
      ref.invalidate(galleryDaoProvider);
      LumiraToast.show(
        context,
        newMood == null ? '已清除心情' : '已更新心情',
        duration: const Duration(milliseconds: 1000),
      );
    } catch (e) {
      if (mounted) {
        LumiraToast.show(context, '更新失败：$e', duration: const Duration(seconds: 2));
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

  /// 点击照片预览 → 打开全屏大图查看器（整册多图：双指缩放 + 左右滑动切换）
  void _openFullscreen() {
    // 收集整册照片的可展示 URL，用于全屏内左右滑动浏览相邻照片
    final urls = <String>[];
    final urlIndexById = <String, int>{};
    for (final p in _photos) {
      final u = p.dataUrl ?? p.filePath;
      if (u == null || u.isEmpty) continue;
      urlIndexById[p.id] = urls.length;
      urls.add(u);
    }
    if (urls.isEmpty) return;
    final photo = _photo;
    final initial = (photo != null && urlIndexById.containsKey(photo.id))
        ? urlIndexById[photo.id]!
        : 0;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FullscreenImageGallery(
          urls: urls,
          initialIndex: initial,
        ),
      ),
    );
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

  /// 保存当前本地照片到系统相册：复用原生 `lumira/photo_saver` 通道。
  /// 网络图片（dataUrl/filePath 以 http 开头）不支持，弹 toast 提示。
  Future<void> _onSaveToAlbum() async {
    final photo = _photo;
    if (photo == null) return;
    final filePath = photo.filePath;
    final dataUrl = photo.dataUrl;
    final localPath = (filePath != null && filePath.isNotEmpty && !filePath.startsWith('http'))
        ? filePath
        : null;
    if (localPath == null) {
      final isNetwork = (dataUrl != null && dataUrl.startsWith('http')) ||
          (filePath != null && filePath.startsWith('http'));
      LumiraToast.show(
        context,
        isNetwork ? '网络图片暂不支持保存到系统相册' : '未找到可保存的照片文件',
        duration: const Duration(milliseconds: 1500),
      );
      return;
    }
    try {
      final result = await _photoSaverChannel.invokeMethod('saveToAlbum', {
        'path': localPath,
      });
      final success = result != null && result['success'] == true;
      if (!mounted) return;
      LumiraToast.show(
        context,
        success ? '已保存到系统相册' : '保存失败：${result?['error'] ?? '未知错误'}',
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      debugPrint('[gallery-detail] 保存到系统相册异常: $e');
      if (!mounted) return;
      LumiraToast.show(context, '保存失败：$e', duration: const Duration(seconds: 2));
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

  /// 「分享模板海报」：仅套用模板拍摄的照片可生成海报。
  /// 读取照片本地路径 + 拍摄用模板（用于二维码），弹出海报预览并导出/分享。
  Future<void> _onSharePoster() async {
    final photo = _photo;
    if (photo == null) return;
    final tplId = photo.templateId;
    if (tplId == null || tplId.isEmpty) {
      LumiraToast.show(
        context,
        '该照片未使用模板拍摄，无法生成模板海报',
        duration: const Duration(seconds: 2),
      );
      return;
    }
    final photoPath = photo.filePath;
    if (photoPath == null || photoPath.isEmpty) {
      LumiraToast.show(
        context,
        '仅支持本地照片生成模板海报',
        duration: const Duration(seconds: 2),
      );
      return;
    }
    try {
      final dao = await ref.read(templatesDaoProvider.future);
      final template = await dao.getById(tplId);
      if (template == null) {
        if (!mounted) return;
        LumiraToast.show(context, '模板未找到', duration: const Duration(seconds: 2));
        return;
      }
      // 自定义模板不允许生成照片分享海报（其二维码无法定位到模板详情）。
      if (template.source == 'custom') {
        if (!mounted) return;
        LumiraToast.show(
          context,
          '自定义模板不支持海报分享',
          duration: const Duration(seconds: 2),
        );
        return;
      }
      if (!mounted) return;
      final tokens = ref.read(themeTokensProvider);
      final shareText = buildAutoShareText(template);
      // 由照片本地文件解析海报比例（9:16 / 3:4 / 1:1 / 4:3 / 16:9），失败回退 9:16
      final ratio = await PosterRatio.fromFile(photoPath);
      if (!mounted) return;
      // 照片详情分享海报：落款 @小满，二维码沿用拍摄模板链接（可扫码拍同款/查看模板）。
      await PosterGenerator.showPosterWithStylePicker(
        context: context,
        tokens: tokens,
        title: '分享照片海报',
        kind: PosterKind.photo,
        ratio: ratio,
        data: PosterStyleData(
          ratio: ratio,
          title: template.name,
          category: template.category,
          qrData: buildTemplatePosterQrData(template),
          qrHint: '长按识别 · 查看高清原图',
          qrSub: '打开如画 · 保存原图',
          shareText: shareText,
          authorName: '小满',
          photoBuilder: (w, h) => Image.file(
            File(photoPath),
            width: w,
            height: h,
            fit: BoxFit.cover,
            cacheWidth: kPosterImageCacheWidth,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => Container(
              color: tokens.brandSubtle,
              alignment: Alignment.center,
              child: Icon(Icons.photo_outlined, size: 40, color: tokens.brand),
            ),
          ),
        ),
        shareSubject: '照片海报 · ${template.name}',
        shareText: shareText,
        fileNamePrefix: 'photo_poster',
      );
    } catch (e) {
      if (!mounted) return;
      LumiraToast.show(context, '分享失败：$e', duration: const Duration(seconds: 2));
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
            _MoreAction(
              tokens: tokens,
              canShare: _photo?.templateId != null,
              onCheckin: _onCheckin,
              onDelete: _onDelete,
              onAddWatermark: _onAddWatermark,
              onSaveToAlbum: _onSaveToAlbum,
              onSharePoster: _onSharePoster,
            ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          // skipLoadingOnReload：心情/场景更新后失效 galleryDaoProvider 刷新下游页面时，
          // 保留当前内容继续展示，避免整页闪加载圈
          daoAsync.when(
            skipLoadingOnReload: true,
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
              return _photo == null ? _EmptyCanvas(tokens: tokens) : _buildContent(tokens);
            },
          ),
        ],
      ),
      bottomNavigationBar: _photo == null
          ? null
          : _EditBottomBar(
              tokens: tokens,
              isReadOnly: _photo?.originalPath == null,
              photo: _photo!,
              onTap: _onEditTap,
              onSaveToAlbum: _onSaveToAlbum,
              onFavoriteToggle: _onFavoriteToggled,
            ),
    );
  }

  /// 收藏状态切换：更新当前照片记录并刷新收藏列表
  void _onFavoriteToggled(bool next) {
    final photo = _photo;
    if (photo == null) return;
    _replaceCurrent(GalleryItemRecord(
      id: photo.id,
      dataUrl: photo.dataUrl,
      filePath: photo.filePath,
      originalPath: photo.originalPath,
      transform: photo.transform,
      postProcess: photo.postProcess,
      sceneId: photo.sceneId,
      templateId: photo.templateId,
      kitId: photo.kitId,
      mood: photo.mood,
      lut: photo.lut,
      isFavorite: next,
      createdAt: photo.createdAt,
    ));
    ref.invalidate(collectionsListProvider);
  }

  /// 构建整册照片的分页视图：通过 PageView 左右滑动切换相邻照片（带动画）
  Widget _buildContent(ThemeTokens tokens) {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: _onPageChanged,
      itemCount: _photos.length,
      itemBuilder: (context, index) => _buildPhotoPage(_photos[index], tokens),
    );
  }

  /// 构建单张照片的详情内容（预览 + 心情 + 信息面板），作为 PageView 的一页
  Widget _buildPhotoPage(GalleryItemRecord photo, ThemeTokens tokens) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 照片预览区（应用 photo.postProcess 滤镜，只读，不缩放）
          _ReadOnlyCanvas(
            photo: photo,
            tokens: tokens,
            isComparing: _isComparing,
            onCompareToggle: _onCompareToggle,
            onTap: _openFullscreen,
          ),
          // 1.5 心情独立凸显（照片正下方、信息面板之上），点击可设置/更换/清除心情
          _MoodHero(
            mood: photo.mood,
            tokens: tokens,
            onTap: _onChangeMood,
          ),
          // 2. 照片信息 section（合并元信息/分类/来源）
          _PhotoInfoSection(
            photo: photo,
            tokens: tokens,
            sceneName: _sceneNameById[photo.sceneId],
            templateName: photo.templateId != null
                ? (_templateNameById[photo.templateId] ??
                    photo.templateId)
                : null,
            sceneId: photo.sceneId,
            templateId: photo.templateId,
            onChangeCategory: _onChangeCategory,
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

/// AppBar "更多"按钮：点击弹出 BottomSheet，提供"记录探店" / "保存到系统相册" /
/// "分享模板海报"（仅套用模板照片） / "添加水印" / "删除照片"操作。
class _MoreAction extends StatelessWidget {
  const _MoreAction({
    required this.tokens,
    required this.canShare,
    required this.onCheckin,
    required this.onDelete,
    required this.onAddWatermark,
    required this.onSaveToAlbum,
    required this.onSharePoster,
  });

  final ThemeTokens tokens;

  /// 当前照片是否套用了模板（决定是否展示"分享模板海报"选项）。
  final bool canShare;
  final Future<void> Function() onCheckin;
  final Future<void> Function() onDelete;
  final Future<void> Function() onAddWatermark;
  final Future<void> Function() onSaveToAlbum;
  final Future<void> Function() onSharePoster;

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
            icon: Icons.save_outlined,
            label: '保存到系统相册',
            onTap: () => Navigator.of(ctx).pop('saveToAlbum'),
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
          if (canShare)
            _MoreSheetOption(
              tokens: tokens,
              icon: Icons.photo_library_outlined,
              label: '分享模板海报',
              color: tokens.brand,
              onTap: () => Navigator.of(ctx).pop('sharePoster'),
            ),
          if (canShare) Divider(height: 1, color: tokens.divider),
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
    } else if (result == 'saveToAlbum') {
      await onSaveToAlbum();
    } else if (result == 'watermark') {
      await onAddWatermark();
    } else if (result == 'sharePoster') {
      await onSharePoster();
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
          // 个性化反馈：收藏照片（且照片带模板）→ 回写模板画像（失败静默）
          if (!photo.isFavorite && photo.templateId != null) {
            try {
              final interest =
                  await ref.read(interestServiceProvider.future);
              await interest.recordSignal(photo.templateId!, 1.5);
            } catch (_) {}
          }
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
///
/// 详情页的小图预览**不支持缩放/拖拽**——仅作为缩略展示，点击整区打开
/// [FullscreenImageGallery]（支持双指缩放 + 左AppBar右滑动）查看大图。
///
/// 当 isComparing 为 true 且 photo.originalPath 存在时，切换显示原图
/// （未应用后期参数的原始照片），便于与编辑后效果对比。
class _ReadOnlyCanvas extends StatefulWidget {
  const _ReadOnlyCanvas({
    required this.photo,
    required this.tokens,
    this.isComparing = false,
    required this.onCompareToggle,
    this.onTap,
  });

  final GalleryItemRecord photo;
  final ThemeTokens tokens;
  final bool isComparing;
  final VoidCallback onCompareToggle;

  /// 点击照片预览的回调（用于打开全屏大图查看器）
  final VoidCallback? onTap;

  @override
  State<_ReadOnlyCanvas> createState() => _ReadOnlyCanvasState();
}

class _ReadOnlyCanvasState extends State<_ReadOnlyCanvas> {
  /// 照片宽高比（宽/高）。异步解析后用于按自然比例自适应高度，null 时回退固定高度。
  double? _aspectRatio;

  /// 当前查询尺寸的图片流（dispose 时移除监听，避免泄漏）
  ImageStream? _measureStream;
  ImageStreamListener? _measureListener;

  @override
  void initState() {
    super.initState();
    _measureAspectRatio();
  }

  @override
  void didUpdateWidget(covariant _ReadOnlyCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo.id != widget.photo.id) {
      setState(() => _aspectRatio = null);
      _measureAspectRatio();
    }
  }

  @override
  void dispose() {
    _removeMeasureListener();
    super.dispose();
  }

  void _removeMeasureListener() {
    if (_measureStream != null && _measureListener != null) {
      _measureStream!.removeListener(_measureListener!);
    }
    _measureStream = null;
    _measureListener = null;
  }

  /// 解析当前展示图片的宽高比（本地文件与网络图片均支持），失败则保持 null
  void _measureAspectRatio() {
    final url = _displayUrl();
    if (url == null || url.isEmpty) return;
    _removeMeasureListener();
    final provider = _imageProviderFor(url);
    final listener = ImageStreamListener(
      (info, _) {
        final image = info.image;
        final ratio = image.width / (image.height == 0 ? 1 : image.height);
        if (mounted) setState(() => _aspectRatio = ratio);
      },
      onError: (Object? error, StackTrace? stackTrace) {
        debugPrint('[gallery-detail] 解析图片尺寸失败: $error');
      },
    );
    _measureStream = provider.resolve(const ImageConfiguration());
    _measureListener = listener;
    _measureStream!.addListener(listener);
  }

  /// 对比模式优先显示原图；否则显示已烘焙的成品（filePath 优先，回退 dataUrl）
  String? _displayUrl() {
    if (widget.isComparing &&
        widget.photo.originalPath != null &&
        widget.photo.originalPath!.isNotEmpty) {
      return widget.photo.originalPath;
    }
    return widget.photo.dataUrl ?? widget.photo.filePath;
  }

  /// 生成本地/网络/base64 图片的 ImageProvider。
  ImageProvider<Object> _imageProviderFor(String url) {
    if (url.startsWith('http')) return NetworkImage(url);
    if (url.startsWith('data:')) {
      final comma = url.indexOf(',');
      final b64 = comma >= 0 ? url.substring(comma + 1) : url;
      return MemoryImage(base64Decode(b64));
    }
    return FileImage(File(url));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final url = _displayUrl();
    final hasOriginal =
        widget.photo.originalPath != null && widget.photo.originalPath!.isNotEmpty;
    final screenHeight = MediaQuery.of(context).size.height;
    final canvasHeight = screenHeight * 0.45;

    // 小图预览：普通 Image，不做缩放/拖拽
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
          : Image(
              image: _imageProviderFor(url),
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
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
                          style: TextStyle(
                              fontSize: 12, color: tokens.textTertiary)),
                    ],
                  ),
                ),
              ),
            ),
    );

    // 有宽高比时按比例自适应，否则回退固定高度
    final Widget frame;
    if (_aspectRatio != null && _aspectRatio! > 0) {
      frame = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: AspectRatio(aspectRatio: _aspectRatio!, child: inner),
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
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: frame,
        ),
        // 对比切换浮层：从 AppBar 迁移到照片上，简化导航栏
        if (hasOriginal)
          Positioned(
            bottom: 16,
            right: 16,
            child: GestureDetector(
              onTap: widget.onCompareToggle,
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: widget.isComparing
                      ? tokens.brand
                      : Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(1000),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.isComparing
                          ? Icons.visibility
                          : Icons.compare_outlined,
                      size: 14,
                      color: widget.isComparing
                          ? tokens.textInverse
                          : Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      widget.isComparing ? '原图' : '对比',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: widget.isComparing
                            ? tokens.textInverse
                            : Colors.white,
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
}

/// 照片信息 Section：合并原"元信息 / 分类 / 来源"三张卡片为一张面板，
/// 消除卡片汤与"场景"信息的重复展示，同时保留全部原有功能：
/// - 拍摄时间（相对 + 绝对）、原图保留状态
/// - 分类（场景）行始终展示：未设置时提供「设置」入口（未套用模板拍摄的照片
///   也可设置场景），点击场景名跳转场景详情
/// - 拍摄模板展示 + 点击跳转模板详情（仅套用模板拍摄的照片显示）
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

    return LumiraSurface(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      radius: 12,
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
          // 场景行始终展示（未套用模板拍摄的照片同样可在此设置场景），
          // 拍摄模板 Chip 仅在套用模板拍摄时显示
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
              // 设置/更换分类
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
                        hasCategory ? '更换' : '设置',
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
/// 整区可点击弹出心情选择 Sheet：未记录心情时展示浅色占位态引导添加，
/// 已记录时可更换或清除。
class _MoodHero extends StatelessWidget {
  const _MoodHero({
    required this.mood,
    required this.tokens,
    required this.onTap,
  });

  /// 当前照片心情；null/空表示未记录（展示占位态）
  final String? mood;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasMood = mood != null && mood!.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: hasMood ? tokens.brandSubtle : tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                hasMood ? tokens.brandLight.withOpacity(0.5) : tokens.divider,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    hasMood
                        ? _moodIconFor(mood!)
                        : Icons.add_reaction_outlined,
                    size: 18,
                    color: hasMood ? tokens.brand : tokens.textTertiary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasMood ? '今天的心情 · $mood' : '记录今天的心情',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: hasMood ? FontWeight.w600 : FontWeight.w500,
                      color:
                          hasMood ? tokens.textPrimary : tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              hasMood ? Icons.edit_outlined : Icons.chevron_right,
              size: 14,
              color: hasMood ? tokens.brand : tokens.textTertiary,
            ),
          ],
        ),
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

/// 心情选择底部 Sheet：复用拍摄预览页的心情选项（CapturePreviewMockData.moods），
/// 已记录心情时额外提供「不记录心情」清除项（与场景选择 Sheet 的「移除场景」同语义）。
class _MoodPickerSheet extends StatelessWidget {
  const _MoodPickerSheet({required this.tokens, required this.currentMood});

  final ThemeTokens tokens;
  final String? currentMood;

  @override
  Widget build(BuildContext context) {
    const moods = CapturePreviewMockData.moods;
    final hasMood = currentMood != null && currentMood!.isNotEmpty;
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
                  '选择心情',
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
                    child: Icon(Icons.close,
                        size: 20, color: tokens.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: tokens.divider),
          // 心情列表
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // 清除心情选项（仅在已记录心情时展示）
                if (hasMood)
                  _CategoryOption(
                    tokens: tokens,
                    icon: Icons.label_off_outlined,
                    label: '不记录心情',
                    selected: false,
                    isRemove: true,
                    onTap: () => Navigator.of(context).pop('__none__'),
                  ),
                // 所有心情选项
                ...moods.map((m) => _CategoryOption(
                      tokens: tokens,
                      icon: m.icon,
                      label: m.name,
                      selected: hasMood && m.name == currentMood,
                      onTap: () => Navigator.of(context).pop(m.name),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 分类选择底部 Sheet
///
/// 提供两种可切换的选择模式（头部右上角分段开关）：
/// - 卡片模式（默认）：单行横向滑动卡片，快速浏览与选择
/// - 瀑布流模式：上下滑动的双栏错落卡片，场景较多时更易扫视
///
/// 卡片表面与选中态严格跟随当前 UI 风格（4 风格 × 8+1 主题，禁止硬编码颜色）：
/// - neumorphic：未选中 = surface + 微凸起双向外阴影；选中 = 凹陷内影渐变
/// - flat：surface + divider 细边；选中 = brandSubtle + brand 边
/// - glass：glassFill + glassBorder；选中 = brandSubtle + brand 边
/// - female：surface + 细边 + 柔和品牌投影；选中 = brandSubtle→surface 渐变 + brand 边
class _CategoryPickerSheet extends StatefulWidget {
  const _CategoryPickerSheet({
    required this.tokens,
    required this.style,
    required this.scenes,
    required this.currentSceneId,
  });

  final ThemeTokens tokens;
  final UIStyle style;
  final List<SceneRecord> scenes;
  final String? currentSceneId;

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  /// true = 单行横滑卡片；false = 双栏瀑布流
  bool _cardMode = true;

  ThemeTokens get _tokens => widget.tokens;
  UIStyle get _style => widget.style;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.7;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          Divider(height: 1, color: _tokens.divider),
          Flexible(
            child: _cardMode ? _buildCardStrip() : _buildMasonry(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Row(
        children: [
          Text(
            '选择场景',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _tokens.textPrimary,
            ),
          ),
          const Spacer(),
          _ScenePickerModeSwitch(
            tokens: _tokens,
            style: _style,
            cardMode: _cardMode,
            onChanged: (cardMode) => setState(() => _cardMode = cardMode),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close, size: 20, color: _tokens.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  /// 卡片模式：单行横向滑动卡片
  Widget _buildCardStrip() {
    final hasRemove = widget.currentSceneId != null;
    if (widget.scenes.isEmpty && !hasRemove) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '暂无可用场景',
          style: TextStyle(fontSize: 13, color: _tokens.textTertiary),
          textAlign: TextAlign.center,
        ),
      );
    }
    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: widget.scenes.length + (hasRemove ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (hasRemove && i == 0) {
            return _SceneRemoveCard(
              tokens: _tokens,
              dense: true,
              onTap: () => Navigator.of(ctx).pop('__none__'),
            );
          }
          final scene = widget.scenes[hasRemove ? i - 1 : i];
          return _SceneStripCard(
            tokens: _tokens,
            style: _style,
            icon: _iconForScene(scene.icon),
            cover: _sceneCoverOf(scene),
            label: scene.name.isEmpty ? '(未命名场景)' : scene.name,
            selected: scene.id == widget.currentSceneId,
            onTap: () => Navigator.of(ctx).pop(scene.id),
          );
        },
      ),
    );
  }

  /// 瀑布流模式：上下滑动的双栏 Masonry（懒加载）。
  ///
  /// - 懒加载：`MasonryGridView.builder` 底层是 `SliverChildBuilderDelegate`，
  ///   只构建视口 + cacheExtent 内的卡片（含封面图），滑到哪才加载到哪，
  ///   不会一次性把全部场景的封面图解码/下载排队（避免「先灌满第一列」的观感）。
  /// - 封面高度自适应：由 `AdaptiveCoverImage` 按图片真实宽高比决定卡片高度，
  ///   双栏按最短列排布，天然错落；无封面的场景回退固定高度图标卡。
  /// - 两栏间距：crossAxisSpacing 10；行间距：mainAxisSpacing 10。
  /// - 移除场景：顶部通栏动作卡（虚线描边），滚动时保持可见。
  Widget _buildMasonry() {
    final hasRemove = widget.currentSceneId != null;
    if (widget.scenes.isEmpty && !hasRemove) {
      return _buildMasonryEmpty();
    }
    return Column(
      children: [
        if (hasRemove)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _SceneRemoveCard(
              tokens: _tokens,
              onTap: () => Navigator.of(context).pop('__none__'),
            ),
          ),
        Expanded(
          child: widget.scenes.isEmpty
              ? _buildMasonryEmpty()
              : MasonryGridView.builder(
                  gridDelegate:
                      const SliverSimpleGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                  ),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  padding: EdgeInsets.fromLTRB(20, hasRemove ? 10 : 12, 20, 20),
                  itemCount: widget.scenes.length,
                  itemBuilder: (ctx, i) {
                    final s = widget.scenes[i];
                    return _SceneTile(
                      tokens: _tokens,
                      style: _style,
                      icon: _iconForScene(s.icon),
                      cover: _sceneCoverOf(s),
                      label: s.name.isEmpty ? '(未命名场景)' : s.name,
                      selected: s.id == widget.currentSceneId,
                      result: s.id,
                      tall: i.isOdd,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMasonryEmpty() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        '暂无可用场景',
        style: TextStyle(fontSize: 13, color: _tokens.textTertiary),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// 场景图标：兼容早期以风格键（'cafe'/'street'/...）存储的值，
  /// 其余按 phosphor 图标名（'ph-xxx'，见 ScenePresetsData）映射到 Material 图标。
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
    }
    return _sceneIcons[icon] ?? Icons.place_outlined;
  }

  /// 场景封面来源解析：自定义场景封面 → 内置场景本地资产封面 → 示例图首图；
  /// 均拿不到时返回 null，卡片回退到「图标 + 名称」设计。
  String? _sceneCoverOf(SceneRecord scene) {
    if (scene.coverUrl.isNotEmpty) return scene.coverUrl;
    final local = ScenePresetsData.localCoverOf(scene.id);
    if (local.isNotEmpty) return local;
    if (scene.exampleImages.isNotEmpty) return scene.exampleImages.first;
    return null;
  }
}

/// 场景 phosphor 图标名（'ph-xxx'）→ Material 图标（覆盖全部内置预设场景）
const Map<String, IconData> _sceneIcons = {
  'ph-coffee': Icons.local_cafe_outlined,
  'ph-books': Icons.menu_book_outlined,
  'ph-house': Icons.home_outlined,
  'ph-sunset': Icons.wb_twilight_outlined,
  'ph-sun-horizon': Icons.wb_twilight_outlined,
  'ph-road-horizon': Icons.wb_twilight_outlined,
  'ph-moon-stars': Icons.nightlight_outlined,
  'ph-candle': Icons.nightlight_outlined,
  'ph-martini': Icons.local_bar_outlined,
  'ph-storefront': Icons.storefront_outlined,
  'ph-waves': Icons.waves_outlined,
  'ph-mountains': Icons.landscape_outlined,
  'ph-tree': Icons.park_outlined,
  'ph-leaf': Icons.eco_outlined,
  'ph-building': Icons.location_city_outlined,
  'ph-buildings': Icons.location_city_outlined,
  'ph-fountain': Icons.location_city_outlined,
  'ph-train': Icons.train_outlined,
  'ph-bed': Icons.bed_outlined,
  'ph-cooking-pot': Icons.restaurant_outlined,
  'ph-bowl-food': Icons.dinner_dining_outlined,
  'ph-tray': Icons.fastfood_outlined,
  'ph-carrot': Icons.shopping_basket_outlined,
  'ph-drop': Icons.water_drop_outlined,
  'ph-umbrella': Icons.umbrella_outlined,
  'ph-palette': Icons.palette_outlined,
  'ph-shopping-bag': Icons.shopping_bag_outlined,
  'ph-dumbbell': Icons.fitness_center_outlined,
  'ph-footprints': Icons.directions_walk_outlined,
  'ph-plant': Icons.local_florist_outlined,
  'ph-flower': Icons.local_florist_outlined,
  'ph-scissors': Icons.content_cut_outlined,
  'ph-cloud-sun': Icons.wb_cloudy_outlined,
  'ph-hoodie': Icons.checkroom_outlined,
  'ph-graduation-cap': Icons.school_outlined,
  'ph-chalkboard-teacher': Icons.school_outlined,
  'ph-window': Icons.window_outlined,
  'ph-sofa': Icons.weekend_outlined,
  'ph-laptop': Icons.laptop_outlined,
  'ph-basketball': Icons.sports_basketball_outlined,
  'ph-bus': Icons.directions_bus_outlined,
};

/// 选择模式分段开关（卡片 / 瀑布流）
///
/// 视觉与相册页 ViewToggle 同构：新拟态凹槽轨道 + 选中段凸起；
/// 其余风格 surfaceAlt 轨道 + canvas 选中段。
class _ScenePickerModeSwitch extends StatelessWidget {
  const _ScenePickerModeSwitch({
    required this.tokens,
    required this.style,
    required this.cardMode,
    required this.onChanged,
  });

  final ThemeTokens tokens;
  final UIStyle style;
  final bool cardMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isNeu = style == UIStyle.neumorphic;
    return Container(
      decoration: BoxDecoration(
        color: isNeu ? null : tokens.surfaceAlt,
        gradient:
            isNeu ? ThemeTokens.recessedGradient(tokens, depth: 0.18) : null,
        borderRadius: BorderRadius.circular(1000),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment('卡片', cardMode, () => onChanged(true)),
          _segment('瀑布流', !cardMode, () => onChanged(false)),
        ],
      ),
    );
  }

  Widget _segment(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? tokens.canvas : Colors.transparent,
          borderRadius: BorderRadius.circular(1000),
          boxShadow: active ? tokens.shadowConvexSubtle : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? tokens.textPrimary : tokens.textTertiary,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

/// 场景卡片表面：4 风格自适应（颜色/描边/阴影全部派生自当前主题 token）
class _SceneCardSurface extends StatelessWidget {
  const _SceneCardSurface({
    required this.tokens,
    required this.style,
    required this.selected,
    required this.child,
  });

  final ThemeTokens tokens;
  final UIStyle style;
  final bool selected;
  final Widget child;

  /// 卡片圆角（与主题卡片圆角语言一致的固定值，封面裁剪共用）
  static const double radius = 16;

  @override
  Widget build(BuildContext context) {
    final accent = tokens.brand;
    switch (style) {
      case UIStyle.neumorphic:
        // 选中 = 凹陷（内影渐变，模拟按下拟态）；未选中 = surface + 微凸起双向外阴影
        return Container(
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(radius),
            gradient: selected
                ? ThemeTokens.recessedGradient(tokens, depth: 0.5)
                : null,
            boxShadow: selected ? null : tokens.shadowConvexSubtle,
          ),
          child: child,
        );
      case UIStyle.flat:
        return Container(
          decoration: BoxDecoration(
            color: selected ? tokens.brandSubtle : tokens.surface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: selected ? accent : tokens.divider,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: child,
        );
      case UIStyle.glass:
        return Container(
          decoration: BoxDecoration(
            color: selected ? tokens.brandSubtle : ThemeTokens.glassFill(tokens),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: selected ? accent : ThemeTokens.glassBorder(tokens),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: child,
        );
      case UIStyle.female:
        return Container(
          decoration: BoxDecoration(
            color: tokens.surface,
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [tokens.brandSubtle, tokens.surface],
                  )
                : null,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: selected ? accent.withOpacity(0.5) : tokens.divider,
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.brand.withOpacity(selected ? 0.18 : 0.08),
                offset: const Offset(0, 6),
                blurRadius: 16,
              ),
            ],
          ),
          child: child,
        );
    }
  }
}

/// 选中角标（品牌色实心圆 + 对勾）
class _SceneSelectedBadge extends StatelessWidget {
  const _SceneSelectedBadge({required this.tokens});

  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(color: tokens.brand, shape: BoxShape.circle),
      child: Icon(Icons.check, size: 11, color: tokens.textInverse),
    );
  }
}

/// 卡片模式：单行横滑卡片。
///
/// 有场景封面时以封面为主视觉（BoxFit.cover 铺满 + 底部黑色渐变遮罩 +
/// 白色名称，叠图遮罩为跨风格通用叠加视觉）；无封面时回退「图标圆底 + 名称」。
/// 固定 84×108。
class _SceneStripCard extends StatelessWidget {
  const _SceneStripCard({
    required this.tokens,
    required this.style,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.cover,
  });

  final ThemeTokens tokens;
  final UIStyle style;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 场景封面来源（asset / data: / http / 本地文件路径），null 走图标回退
  final String? cover;

  @override
  Widget build(BuildContext context) {
    final cover = this.cover;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 84,
        height: 108,
        child: _SceneCardSurface(
          tokens: tokens,
          style: style,
          selected: selected,
          child: cover != null && cover.isNotEmpty
              ? _buildCoverBody(cover)
              : _buildIconBody(),
        ),
      ),
    );
  }

  /// 无封面回退：图标圆底 + 名称（画布态，跟随主题 token）
  Widget _buildIconBody() {
    final iconColor = selected ? tokens.brandText : tokens.textSecondary;
    final nameColor = selected ? tokens.brandText : tokens.textPrimary;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected ? tokens.brandSubtle : tokens.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: nameColor,
                ),
              ),
            ],
          ),
        ),
        if (selected)
          Positioned(
            top: 6,
            right: 6,
            child: _SceneSelectedBadge(tokens: tokens),
          ),
      ],
    );
  }

  /// 封面态：封面铺满卡片，底部黑色渐变遮罩 + 白色名称（叠图通用叠加视觉）
  Widget _buildCoverBody(String src) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(_SceneCardSurface.radius),
          child: LumiraImage(
            src,
            fit: BoxFit.cover,
            errorWidget: Container(color: tokens.surfaceAlt),
          ),
        ),
        const _CoverScrim(),
        _CoverName(label: label, selected: selected, centered: true),
        if (selected)
          Positioned(
            top: 6,
            right: 6,
            child: _SceneSelectedBadge(tokens: tokens),
          ),
      ],
    );
  }
}

/// 瀑布流模式：双栏 Masonry 中的单张场景卡片。
///
/// 有场景封面时高度由 [AdaptiveCoverImage] 按图片真实宽高比自适应
/// （9:16 长图 / 超宽图比例钳制，避免双栏高度失衡），底部黑色渐变遮罩 +
/// 白色名称；无封面回退「图标圆底 + 名称横排」固定高度（[tall] 错落）。
class _SceneTile extends StatelessWidget {
  const _SceneTile({
    required this.tokens,
    required this.style,
    required this.icon,
    required this.label,
    required this.selected,
    required this.result,
    this.cover,
    this.tall = false,
  });

  final ThemeTokens tokens;
  final UIStyle style;
  final IconData icon;
  final String label;
  final bool selected;

  /// 点击结果：sceneId
  final String result;

  /// 场景封面来源（asset / data: / http / 本地文件路径），null 走图标回退
  final String? cover;

  /// 无封面兜底高度：true = 116；false = 100（相邻条目错落）
  final bool tall;

  @override
  Widget build(BuildContext context) {
    final cover = this.cover;

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(result),
      behavior: HitTestBehavior.opaque,
      child: cover != null && cover.isNotEmpty
          // 封面态：高度由 AdaptiveCoverImage 按图片真实宽高比决定
          // （ResizeImage 64px 探测 + 比例钳制），与模板瀑布流一致
          ? _SceneCardSurface(
              tokens: tokens,
              style: style,
              selected: selected,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_SceneCardSurface.radius),
                child: AdaptiveCoverImage(
                  cover: cover,
                  fit: BoxFit.cover,
                  errorFallback: Container(color: tokens.surfaceAlt),
                  overlay: [
                    const _CoverScrim(),
                    _CoverName(label: label, selected: selected),
                    if (selected)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: _SceneSelectedBadge(tokens: tokens),
                      ),
                  ],
                ),
              ),
            )
          : SizedBox(
              height: tall ? 116 : 100,
              child: _SceneCardSurface(
                tokens: tokens,
                style: style,
                selected: selected,
                child: _buildIconBody(),
              ),
            ),
    );
  }

  /// 无封面回退：图标圆底 + 名称横排（画布态，跟随主题 token）
  Widget _buildIconBody() {
    final iconColor = selected ? tokens.brandText : tokens.textSecondary;
    final nameColor = selected ? tokens.brandText : tokens.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: selected ? tokens.brandSubtle : tokens.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.3,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: nameColor,
              ),
            ),
          ),
          if (selected) ...[
            const SizedBox(width: 6),
            _SceneSelectedBadge(tokens: tokens),
          ],
        ],
      ),
    );
  }
}

/// 封面底部黑色渐变遮罩（叠图通用叠加视觉，不随主题/风格变化）
class _CoverScrim extends StatelessWidget {
  const _CoverScrim();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0x00000000), Color(0x99000000)],
          stops: [0, 0.45, 1],
        ),
      ),
    );
  }
}

/// 封面底部场景名称（白色，叠图通用叠加视觉）
class _CoverName extends StatelessWidget {
  const _CoverName({
    required this.label,
    required this.selected,
    this.centered = false,
  });

  final String label;
  final bool selected;

  /// 横滑卡片（84 宽）居中对齐；瀑布流卡左对齐
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        centered ? 6 : 12,
        8,
        centered ? 6 : 12,
        centered ? 7 : 9,
      ),
      child: Align(
        alignment: centered ? Alignment.bottomCenter : Alignment.bottomLeft,
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: centered ? TextAlign.center : null,
          style: TextStyle(
            fontSize: centered ? 11 : 12,
            height: 1.3,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// 「移除场景」动作卡：虚线描边 + danger 色调（画布态，跟随主题 token）。
///
/// - 瀑布流模式：通栏横排（图标 + 文字），滚动时保持可见；
/// - 卡片横滑模式（[dense]）：84×108 竖排小卡，与场景封面卡同尺寸。
class _SceneRemoveCard extends StatelessWidget {
  const _SceneRemoveCard({
    required this.tokens,
    required this.onTap,
    this.dense = false,
  });

  final ThemeTokens tokens;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      Icons.label_off_outlined,
      size: dense ? 20 : 18,
      color: tokens.danger,
    );
    final text = Text(
      '移除场景',
      style: TextStyle(
        fontSize: dense ? 11 : 13,
        height: 1.3,
        fontWeight: FontWeight.w500,
        color: tokens.danger,
      ),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        painter: _DashedRRectPainter(
          color: tokens.danger.withOpacity(0.45),
          radius: _SceneCardSurface.radius,
        ),
        child: Container(
          width: dense ? 84 : null,
          height: dense ? 108 : 52,
          alignment: Alignment.center,
          padding: dense ? null : const EdgeInsets.symmetric(horizontal: 14),
          child: dense
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    icon,
                    const SizedBox(height: 6),
                    text,
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    icon,
                    const SizedBox(width: 8),
                    text,
                  ],
                ),
        ),
      ),
    );
  }
}

/// 虚线圆角矩形描边 painter（移除场景卡用）
class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(radius),
      ));

    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
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

/// 底部操作栏：左侧收藏/保存到相册辅操作 + 右侧"后期修图"主按钮。
/// 简洁一栏式；辅操作用新拟态圆形图标按钮，主按钮用品牌金色渐变 +
/// 柔和品牌辉光，按下有缩放反馈，贴合项目 warm 新拟态美学。
class _EditBottomBar extends StatelessWidget implements PreferredSizeWidget {
  const _EditBottomBar({
    required this.tokens,
    required this.isReadOnly,
    required this.photo,
    required this.onTap,
    required this.onSaveToAlbum,
    required this.onFavoriteToggle,
  });
  final ThemeTokens tokens;
  final bool isReadOnly;
  final GalleryItemRecord photo;
  final VoidCallback onTap;
  final VoidCallback onSaveToAlbum;
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
              // 辅操作组：收藏 + 保存到系统相册
              _FavoriteButton(
                photo: photo,
                tokens: tokens,
                onToggled: onFavoriteToggle,
                round: true,
              ),
              const SizedBox(width: 16),
              _RoundActionButton(
                tokens: tokens,
                icon: Icons.download_outlined,
                onTap: onSaveToAlbum,
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
