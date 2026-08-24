import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/dao/collections_dao.dart';
import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/services/file_picker_service.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/safe_temp_dir.dart';
import '../../profile/providers/collection_providers.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/gallery_models.dart';
import '../data/name_resolver.dart';
import '../widgets/photo_cell.dart';
import '../widgets/scene_filter_pills.dart';
import '../widgets/sweep_select_grid.dart';
import '../widgets/view_toggle.dart';

/// 原生「保存到系统相册」MethodChannel（复用）：
/// { 'path': <本地文件绝对路径> } -> { success, error }
const _photoSaverChannel = MethodChannel('lumira/photo_saver');

/// 相册主页（首个接入 DAO 的页面）
///
/// 视觉规格来源：lumira-app/src/pages/gallery/index.vue（318 行）
/// - LumiraNav + 顶部信息条（张数 + 视图切换）+ 场景筛选 pills + 3 列网格 + 空状态
/// - 数据：通过 galleryDaoProvider 异步读取 GalleryDao.getAll()
class GalleryPage extends ConsumerStatefulWidget {
  const GalleryPage({super.key});

  @override
  ConsumerState<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends ConsumerState<GalleryPage> {
  String _activeFilter = 'all';
  final String _viewTab = 'photo'; // 默认照片视图；切到 diary 直接跳页
  bool _isMultiSelectMode = false;
  final Set<String> _selectedIds = <String>{};

  // 搜索状态
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Forced fix: FutureBuilder 在测试环境下不会从 ConnectionState.waiting
  // 切到 done（即使 future 已解析），导致 pumpAndSettle timed out。
  // 改用 state-variable-based loading + setState，绕过 FutureBuilder
  // 的内部 listener。CircularProgressIndicator（_isLoading=true 时显示，
  // 无限动画）让 pumpAndSettle 持续 pump 直到 setState 触发重建。
  List<GalleryItemRecord> _photos = const [];
  /// 全部照片（未过滤），用于顶部筛选 pill 稳定展示，避免切换筛选后多余 tab 消失
  List<GalleryItemRecord> _allPhotos = const [];
  bool _isLoading = true;
  bool _isInitialLoaded = false;

  Future<List<GalleryItemRecord>> _fetchPhotos(GalleryDao dao) async {
    if (_activeFilter == 'all') {
      return dao.getAll();
    }
    if (_activeFilter == 'uncategorized') {
      final all = await dao.getAll();
      return all.where((p) => p.sceneId == null || p.sceneId!.isEmpty).toList();
    }
    if (_activeFilter.startsWith('scene_')) {
      final sceneId = _activeFilter.replaceFirst('scene_', '');
      return dao.getByScene(sceneId);
    }
    return dao.getAll();
  }

  // Forced fix: 直接接收 GalleryDao 参数，避免在 _loadPhotos 内调用
  // `ref.read(galleryDaoProvider.future)`。在测试环境中，该 future 可能
  // 因 Riverpod provider 生命周期问题不解析。改为在 build() 的
  // daoAsync.when(data:) 分支中提取 dao 并传入。
  Future<void> _loadPhotos(GalleryDao dao) async {
    try {
      final photos = await _fetchPhotos(dao);
      final all = await dao.getAll();
      if (mounted) {
        setState(() {
          _photos = photos;
          _allPhotos = all;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _photos = const [];
          _allPhotos = const [];
          _isLoading = false;
        });
      }
    }
  }

  void _setFilter(String key) {
    final dao = ref.read(galleryDaoProvider).value;
    if (dao == null) return;
    setState(() {
      _activeFilter = key;
      _isLoading = true;
    });
    _loadPhotos(dao);
  }

  /// 退出搜索：清空关键词并恢复全量照片
  void _cancelSearch() {
    _searchController.clear();
    final dao = ref.read(galleryDaoProvider).value;
    setState(() => _isSearching = false);
    if (dao != null) {
      _loadPhotos(dao);
    }
  }

  /// 执行搜索：多字段模糊匹配（场景/模板/心情）
  void _doSearch(GalleryDao dao, String value) {
    if (value.isEmpty) {
      _loadPhotos(dao);
      return;
    }
    setState(() => _isLoading = true);
    dao.search(value).then((results) {
      if (!mounted) return;
      setState(() {
        _photos = results;
        _isLoading = false;
      });
    }).catchError((_) {
      if (!mounted) return;
      setState(() {
        _photos = const [];
        _isLoading = false;
      });
    });
  }

  /// 将照片按「今天/昨天/本周/更早」分组（用于相册时间轴分区展示）
  Map<String, List<GalleryItemRecord>> _groupByTime(List<GalleryItemRecord> photos) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(Duration(days: today.weekday - 1));

    final groups = <String, List<GalleryItemRecord>>{};
    for (final p in photos) {
      final dt = DateTime.fromMillisecondsSinceEpoch(p.createdAt);
      final day = DateTime(dt.year, dt.month, dt.day);
      String key;
      if (day == today) {
        key = '今天';
      } else if (day == yesterday) {
        key = '昨天';
      } else if (day.isAfter(weekStart.subtract(const Duration(days: 1)))) {
        key = '本周';
      } else {
        key = '更早';
      }
      groups.putIfAbsent(key, () => []).add(p);
    }
    return groups;
  }

  Future<void> _deleteSelected() async {
    final dao = ref.read(galleryDaoProvider).value;
    if (dao == null) return;
    final deletedCount = _selectedIds.length;
    try {
      for (final id in _selectedIds) {
        await dao.delete(id);
      }
      ref.invalidate(galleryDaoProvider);
      setState(() {
        _isMultiSelectMode = false;
        _selectedIds.clear();
      });
      // _photos 仅在首次 build 时加载（_isInitialLoaded 守卫），仅 invalidate provider
      // 不会触发列表刷新。必须在此显式重拉当前视图，否则已删照片仍停留在列表中，
      // 直到重新进入相册页才会消失。
      await _loadPhotos(dao);
      if (mounted) {
        LumiraToast.show(context, '已删除 $deletedCount 张照片');
      }
    } catch (e) {
      if (mounted) {
        LumiraToast.show(context, '删除失败：$e');
      }
    }
  }

  /// 从系统相册/文件选择器导入照片到 App 相册（常驻入口）。
  ///
  /// 选择图片后写入应用本地目录并插入 gallery_items，随后重拉列表展示。
  Future<void> _importFromSystemGallery() async {
    final dao = ref.read(galleryDaoProvider).value;
    if (dao == null) return;
    try {
      final files = await FilePickerService.pickImages(allowMultiple: true);
      final picked = files ?? const <PickedFile>[];
      if (picked.isEmpty) return; // 用户取消，静默

      // 批量导入前先确定目标目录（path_provider 在鸿蒙未注册时自动降级）
      final dir = await getSafeDocumentsDirectory();
      final folder = Directory('${dir.path}/lumira_import');
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      int imported = 0;
      for (var i = 0; i < picked.length; i++) {
        final full = await FilePickerService.ensureFullBytes(picked[i]);
        final bytes = full.bytes;
        if (bytes == null || bytes.isEmpty) continue;
        final ext = _imageExtFrom(full);
        final path = '${folder.path}/import_${now}_$i.$ext';
        await File(path).writeAsBytes(bytes);
        final rec = GalleryItemRecord(
          id: 'photo_${now}_$i',
          filePath: path,
          createdAt: now,
        );
        await dao.insert(rec);
        imported++;
      }
      ref.invalidate(galleryDaoProvider);
      if (!mounted) return;
      if (imported > 0) {
        LumiraToast.show(
          context,
          '已导入 $imported 张照片',
          duration: const Duration(seconds: 2),
        );
        setState(() => _isLoading = true);
        await _loadPhotos(dao);
      } else {
        LumiraToast.show(
          context,
          '读取照片失败，请重试',
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('[gallery] 导入照片异常: $e');
      LumiraToast.show(context, '导入失败：$e', duration: const Duration(seconds: 2));
    }
  }

  /// 从 [PickedFile] 推断图片扩展名；无法推断时回退 jpg（保证可解码）。
  String _imageExtFrom(PickedFile f) {
    final r = RegExp(r'^(jpg|jpeg|png|gif|bmp|webp|heic|heif)$');
    final extRaw = f.extension;
    final ext = (extRaw == null ? '' : extRaw.trim()).toLowerCase();
    if (ext.isNotEmpty && r.hasMatch(ext)) return ext == 'jpeg' ? 'jpg' : ext;
    final name = f.name;
    final idx = name.lastIndexOf('.');
    if (idx >= 0 && idx < name.length - 1) {
      final ext2 = name.substring(idx + 1).toLowerCase();
      if (r.hasMatch(ext2)) return ext2 == 'jpeg' ? 'jpg' : ext2;
    }
    return 'jpg';
  }

  /// 将选中照片保存到系统相册：逐张解析本地文件路径（跳过网络图片），
  /// 复用原生 `lumira/photo_saver` 通道批量调用 saveToAlbum。
  Future<void> _saveSelectedToAlbum() async {
    final dao = ref.read(galleryDaoProvider).value;
    if (dao == null) return;
    final ids = _selectedIds.toList();
    int saved = 0;
    int skipped = 0;
    int failed = 0;
    try {
      for (final id in ids) {
        final record = await dao.getById(id);
        final filePath = record?.filePath;
        final dataUrl = record?.dataUrl;
        final isNetwork = (filePath != null && filePath.startsWith('http')) ||
            (dataUrl != null && dataUrl.startsWith('http'));
        final localPath = (filePath != null && filePath.isNotEmpty && !isNetwork)
            ? filePath
            : (dataUrl != null && dataUrl.isNotEmpty && !dataUrl.startsWith('http'))
                ? dataUrl
                : null;
        if (localPath == null) {
          skipped++;
          continue;
        }
        try {
          final result = await _photoSaverChannel.invokeMethod('saveToAlbum', {
            'path': localPath,
          });
          if (result != null && result['success'] == true) {
            saved++;
          } else {
            failed++;
          }
        } catch (_) {
          failed++;
        }
      }
      if (!mounted) return;
      final parts = <String>[
        '已保存 $saved 张',
        if (skipped > 0) '$skipped 张跳过',
        if (failed > 0) '$failed 张失败',
      ];
      LumiraToast.show(
        context,
        parts.join(' · '),
        duration: const Duration(seconds: 2),
      );
      if (saved > 0 && mounted) {
        setState(() {
          _isMultiSelectMode = false;
          _selectedIds.clear();
        });
      }
    } catch (e) {
      debugPrint('[gallery] 批量保存到系统相册异常: $e');
      if (!mounted) return;
      LumiraToast.show(context, '保存失败：$e', duration: const Duration(seconds: 2));
    }
  }

  /// 将选中照片加入精选集：弹出底部 Sheet 显示所有 manual 类型精选集 + "新建精选集"按钮。
  ///
  /// 设计文档 6.7：gallery_page 多选模式下底部操作栏增加"加入精选集"按钮。
  Future<void> _addToCollection() async {
    final tokens = ref.read(themeTokensProvider);

    final result = await showLumiraBottomSheet<_CollectionPickResult>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddToCollectionSheet(tokens: tokens),
    );

    if (result == null || !mounted) return;

    try {
      final service = await ref.read(collectionServiceProvider.future);
      if (result.isNew) {
        // 跳转新建精选集页（用户可在编辑页选择照片，这里不自动添加）
        if (mounted) {
          GoRouter.of(context).push(RouteNames.profileCollectionEdit);
        }
        return;
      }
      final collectionId = result.collectionId;
      if (collectionId == null) return;
      for (final pid in _selectedIds) {
        await service.addPhotoToCollection(collectionId, pid);
      }
      ref.invalidate(collectionsListProvider);
      if (mounted) {
        LumiraToast.show(
          context,
          '已将 ${_selectedIds.length} 张照片加入精选集',
          duration: const Duration(milliseconds: 1500),
        );
      }
      if (mounted) {
        setState(() {
          _isMultiSelectMode = false;
          _selectedIds.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        LumiraToast.show(
          context,
          '加入精选集失败：$e',
          duration: const Duration(milliseconds: 1500),
        );
      }
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
        title: _isSearching ? '' : '相册',
        transparent: true,
        leading: _isSearching
            ? _CancelSearchButton(tokens: tokens, onTap: _cancelSearch)
            : _BackButton(tokens: tokens),
        actions: [
          if (!_isSearching) ...[
            GestureDetector(
              onTap: () => setState(() => _isSearching = true),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.search_outlined,
                  size: 20,
                  color: tokens.textPrimary,
                ),
              ),
            ),
            _StatsAction(tokens: tokens),
          ],
        ],
      ),
      body: Stack(
        children: [
          // 1. 径向渐变背景装饰（glass 风格可见性）
          _BackgroundDecoration(tokens: tokens),
          // 2. 主内容层
          SafeArea(
            child: daoAsync.when(
              loading: () => Center(child: LumiraProgress.circular()),
              error: (e, _) => Center(
                child: Text('加载失败：$e', style: TextStyle(color: tokens.textSecondary)),
              ),
              // Forced fix: 在 data 分支启动首次加载，直接传入 dao，
              // 避免 _loadPhotos 内调用 ref.read(provider.future) 在测试环境不解析。
              data: (dao) {
                if (!_isInitialLoaded) {
                  _isInitialLoaded = true;
                  _loadPhotos(dao);
                }
                return _buildBody(tokens);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeTokens tokens) {
    final photoViews = _photos.map(GalleryPhoto.fromRecord).toList();
    final pills = _buildPills(_allPhotos);
    final grouped = _groupByTime(_photos);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 顶部信息条：搜索框 或 张数 + 视图切换
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  style: TextStyle(fontSize: 14, color: tokens.textPrimary),
                  decoration: InputDecoration(
                    hintText: '搜索场景、模板、心情...',
                    hintStyle: TextStyle(fontSize: 13, color: tokens.textTertiary),
                    prefixIcon: Icon(Icons.search, size: 18, color: tokens.textTertiary),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.close, size: 18, color: tokens.textTertiary),
                      onPressed: _cancelSearch,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(1000),
                      borderSide: BorderSide(color: tokens.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(1000),
                      borderSide: BorderSide(color: tokens.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(1000),
                      borderSide: BorderSide(color: tokens.brand),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    filled: true,
                    fillColor: tokens.surface,
                    isDense: true,
                  ),
                  onChanged: (value) {
                    final dao = ref.read(galleryDaoProvider).value;
                    if (dao != null) _doSearch(dao, value);
                  },
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_photos.length} 张照片',
                      style: TextStyle(
                        fontSize: 13,
                        color: tokens.textTertiary,
                        height: 1.3,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ImportAction(
                          tokens: tokens,
                          onTap: _importFromSystemGallery,
                        ),
                        const SizedBox(width: 12),
                        ViewToggle(
                          activeTab: _viewTab,
                          onPhotoTap: () {},
                          onDiaryTap: () => GoRouter.of(context).push(RouteNames.galleryDiary),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
        // 场景筛选 pills（搜索时隐藏）
        if (!_isSearching) ...[
          SceneFilterPills(
            pills: pills,
            activeKey: _activeFilter,
            onTap: _setFilter,
          ),
          const SizedBox(height: 12),
        ],
        // 内容区：时间分组 / 搜索网格 / 空状态（支持下拉刷新）
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              final dao = ref.read(galleryDaoProvider).value;
              if (dao == null) return;
              if (_isSearching && _searchController.text.isNotEmpty) {
                _doSearch(dao, _searchController.text);
              } else {
                await _loadPhotos(dao);
              }
            },
            child: _buildContent(tokens, photoViews, grouped),
          ),
        ),
        // 长按多选提示 / 多选操作栏（搜索时隐藏）
        if (!_isSearching)
          _isMultiSelectMode
              ? Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      LumiraButton(
                        variant: ButtonVariant.ghost,
                        onPressed: () {
                          setState(() {
                            _isMultiSelectMode = false;
                            _selectedIds.clear();
                          });
                        },
                        child: const Text('取消'),
                      ),
                      LumiraButton(
                        variant: ButtonVariant.ghost,
                        onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                        child: Text('删除 (${_selectedIds.length})'),
                      ),
                      LumiraButton(
                        variant: ButtonVariant.ghost,
                        onPressed: _selectedIds.isEmpty ? null : _saveSelectedToAlbum,
                        child: Text('保存到相册 (${_selectedIds.length})'),
                      ),
                      LumiraButton(
                        variant: ButtonVariant.ghost,
                        onPressed: _selectedIds.isEmpty ? null : _addToCollection,
                        child: const Text('加入精选集'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Center(
                    child: Text(
                      '长按照片进入多选模式 · 支持批量删除与导出',
                      style: TextStyle(
                        fontSize: 11,
                        color: tokens.textTertiary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
      ],
    );
  }

  /// 内容区构建：按当前状态渲染 加载 / 空状态 / 搜索网格 / 时间分组列表
  Widget _buildContent(
    ThemeTokens tokens,
    List<GalleryPhoto> photoViews,
    Map<String, List<GalleryItemRecord>> grouped,
  ) {
    if (_isLoading) {
      return Center(child: LumiraProgress.circular());
    }
    if (photoViews.isEmpty) {
      final empty = _isSearching
          ? _SearchEmptyState(tokens: tokens, onClear: _cancelSearch)
          : _EmptyState(
              tokens: tokens,
              onCapture: () => GoRouter.of(context).push(RouteNames.capture),
              onImport: _importFromSystemGallery,
            );
      // 用可滚动容器包裹空状态，使下拉刷新在空数据时依然可用
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: empty),
          ),
        ),
      );
    }
    if (_isSearching) {
      // 搜索时保持原有网格，不分时间组
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
        ),
        itemCount: photoViews.length,
        itemBuilder: (_, i) => _buildPhotoCell(tokens, photoViews, i),
      );
    }
    // 时间分组展示：杂志式翻阅
    final sectionKeys = grouped.keys.toList();
    final sectionViews = sectionKeys
        .map((k) => grouped[k]!.map(GalleryPhoto.fromRecord).toList())
        .toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
      itemCount: sectionKeys.length,
      itemBuilder: (_, sectionIndex) {
        final key = sectionKeys[sectionIndex];
        final sectionPhotos = sectionViews[sectionIndex];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 组头
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    key,
                    style: TextStyle(
                      fontFamily: 'Noto Serif SC',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 多选模式下一键全选/取消全选
                      if (_isMultiSelectMode)
                        _SectionSelectAllButton(
                          tokens: tokens,
                          allSelected: sectionPhotos.isNotEmpty &&
                              sectionPhotos
                                  .every((p) => _selectedIds.contains(p.id)),
                          onTap: () {
                            setState(() {
                              final allSelected = sectionPhotos
                                  .every((p) => _selectedIds.contains(p.id));
                              final ids =
                                  sectionPhotos.map((p) => p.id).toList();
                              if (allSelected) {
                                _selectedIds.removeAll(ids);
                              } else {
                                _selectedIds.addAll(ids);
                              }
                            });
                          },
                        ),
                      const SizedBox(width: 10),
                      Text(
                        '${sectionPhotos.length} 张',
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 该组照片网格（支持长按滑动批量选，仅限本分区内连续）
            _buildSectionGrid(tokens, sectionPhotos),
          ],
        );
      },
    );
  }

  Widget _buildPhotoCell(ThemeTokens tokens, List<GalleryPhoto> photoViews, int i) {
    final photo = photoViews[i];
    final isSelected = _selectedIds.contains(photo.id);
    return FadeUp(
      delay: Duration(milliseconds: (i % 6) * 50),
      child: PhotoCell(
        key: ValueKey('photo_cell_$i'),
        photo: photo,
        isSelected: isSelected,
        isMultiSelectMode: _isMultiSelectMode,
        onTap: () {
          if (_isMultiSelectMode) {
            setState(() {
              if (isSelected) {
                _selectedIds.remove(photo.id);
              } else {
                _selectedIds.add(photo.id);
              }
            });
          } else {
            _openDetail(photo);
          }
        },
        onLongPress: () {
          setState(() {
            _isMultiSelectMode = true;
            _selectedIds.add(photo.id);
          });
        },
      ),
    );
  }

  /// 构建某一个时间分区的照片网格，支持长按滑动批量选（仅限本分区连续）。
  Widget _buildSectionGrid(
      ThemeTokens tokens, List<GalleryPhoto> photos) {
    return SweepSelectGrid(
      itemCount: photos.length,
      idOf: (i) => photos[i].id,
      selectedIds: _selectedIds,
      onSelectionChanged: (next) => setState(() {
        _selectedIds
          ..clear()
          ..addAll(next);
      }),
      crossAxisCount: 3,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      padding: EdgeInsets.zero,
      aspectRatio: 1,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (_, i, isSelected, startSweep) {
        final photo = photos[i];
        return FadeUp(
          delay: Duration(milliseconds: (i % 6) * 50),
          child: PhotoCell(
            key: ValueKey('photo_cell_$i'),
            photo: photo,
            isSelected: isSelected,
            isMultiSelectMode: _isMultiSelectMode,
            onTap: () {
              if (_isMultiSelectMode) {
                setState(() {
                  if (!_selectedIds.remove(photo.id)) {
                    _selectedIds.add(photo.id);
                  }
                });
              } else {
                _openDetail(photo);
              }
            },
            onLongPress: () {
              if (!_isMultiSelectMode) {
                setState(() => _isMultiSelectMode = true);
              }
              startSweep();
            },
          ),
        );
      },
    );
  }

  /// 打开照片详情；返回后刷新列表。
  ///
  /// 详情页可能删除当前照片或修改分类/收藏，而 _photos 仅在首次 build 时加载
  /// （_isInitialLoaded 守卫），因此 pop 返回后必须显式重拉，否则已删照片仍留在列表中。
  Future<void> _openDetail(GalleryPhoto photo) async {
    await GoRouter.of(context).push(
      RouteNames.build(
        RouteNames.galleryDetail,
        {RouteNames.paramPhotoId: photo.id},
      ),
    );
    if (!mounted) return;
    final dao = ref.read(galleryDaoProvider).value;
    if (dao != null) {
      setState(() => _isLoading = true);
      await _loadPhotos(dao);
    }
  }

  List<SceneFilterPill> _buildPills(List<GalleryItemRecord> photos) {
    final result = <SceneFilterPill>[
      SceneFilterPill(key: 'all', label: '全部', count: photos.length),
    ];
    // 按场景分组
    final groups = <String, int>{};
    for (final p in photos) {
      final sid = (p.sceneId == null || p.sceneId!.isEmpty) ? 'uncategorized' : p.sceneId!;
      groups[sid] = (groups[sid] ?? 0) + 1;
    }
    // uncategorized 排在第二位
    if (groups.containsKey('uncategorized')) {
      result.add(SceneFilterPill(
        key: 'uncategorized',
        label: '未设置场景',
        count: groups['uncategorized']!,
        icon: Icons.folder_open_outlined,
      ));
    }
    // 其余场景（mock 阶段 sceneId 不是已知 scene，仅显示 sceneId 简短形式）
    groups.forEach((sid, cnt) {
      if (sid == 'uncategorized') return;
      result.add(SceneFilterPill(
        key: 'scene_$sid',
        label: sceneDisplayName(sid),
        count: cnt,
        icon: Icons.label_outlined,
      ));
    });
    return result;
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.tokens});
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

class _StatsAction extends StatelessWidget {
  const _StatsAction({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => GoRouter.of(context).push(RouteNames.galleryStats),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Icons.bar_chart_outlined,
          size: 20,
          color: tokens.textPrimary,
        ),
      ),
    );
  }
}

/// 相册顶部信息条的「导入」常驻入口：点击从系统相册/文件选择器导入照片。
class _ImportAction extends StatelessWidget {
  const _ImportAction({required this.tokens, required this.onTap});
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: tokens.brandSubtle,
          borderRadius: BorderRadius.circular(1000),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 14,
              color: tokens.brand,
            ),
            const SizedBox(width: 4),
            Text(
              '导入',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tokens.brand,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CancelSearchButton extends StatelessWidget {
  const _CancelSearchButton({required this.tokens, required this.onTap});
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          '取消',
          style: TextStyle(fontSize: 13, color: tokens.brand),
        ),
      ),
    );
  }
}

/// 分区头部的一键全选/取消全选按钮（仅多选模式显示，主题自适应）。
class _SectionSelectAllButton extends StatelessWidget {
  const _SectionSelectAllButton({
    required this.tokens,
    required this.allSelected,
    required this.onTap,
  });

  final ThemeTokens tokens;
  final bool allSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: tokens.textTertiary.withOpacity(0.6)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              allSelected ? Icons.deselect_outlined : Icons.select_all,
              size: 13,
              color: tokens.brand,
            ),
            const SizedBox(width: 4),
            Text(
              allSelected ? '取消全选' : '全选',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tokens.brand,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tokens, this.onCapture, this.onImport});
  final ThemeTokens tokens;
  final VoidCallback? onCapture;
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: tokens.brandSubtle,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.image_outlined, size: 34, color: tokens.brand),
          ),
          const SizedBox(height: 16),
          Text(
            '还没有照片，去拍一张吧',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: tokens.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '记录每一个值得收藏的瞬间',
            style: TextStyle(
              fontSize: 12,
              color: tokens.textTertiary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LumiraButton(
                variant: ButtonVariant.primary,
                onPressed: onCapture ?? () => GoRouter.of(context).push(RouteNames.capture),
                child: const Text('去拍摄'),
              ),
              const SizedBox(width: 12),
              LumiraButton(
                variant: ButtonVariant.secondary,
                onPressed: onImport ?? () {},
                child: const Text('导入照片'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({required this.tokens, required this.onClear});
  final ThemeTokens tokens;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_outlined, size: 44, color: tokens.textTertiary),
          const SizedBox(height: 12),
          Text(
            '未找到相关照片',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '试试换个关键词，或按场景 / 模板 / 心情搜索',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: tokens.textTertiary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          LumiraButton(
            variant: ButtonVariant.secondary,
            onPressed: onClear,
            child: const Text('清空搜索'),
          ),
        ],
      ),
    );
  }
}

class _BackgroundDecoration extends StatelessWidget {
  const _BackgroundDecoration({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.7, -0.8),
              radius: 1.2,
              colors: [
                tokens.brandSubtle.withOpacity(0.35),
                tokens.canvas.withOpacity(0),
              ],
              stops: const [0.0, 0.6],
            ),
          ),
        ),
      ),
    );
  }
}

/// 加入精选集 Sheet 的选择结果
class _CollectionPickResult {
  const _CollectionPickResult({this.collectionId, this.isNew = false});
  final String? collectionId;
  final bool isNew;
}

/// 加入精选集底部 Sheet：显示所有 manual 类型精选集 + "新建精选集"按钮
class _AddToCollectionSheet extends ConsumerStatefulWidget {
  const _AddToCollectionSheet({required this.tokens});
  final ThemeTokens tokens;

  @override
  ConsumerState<_AddToCollectionSheet> createState() =>
      _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends ConsumerState<_AddToCollectionSheet> {
  List<CollectionRecord> _manuals = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadManuals();
  }

  Future<void> _loadManuals() async {
    try {
      final service = await ref.read(collectionServiceProvider.future);
      final all = await service.listCollections();
      if (mounted) {
        setState(() {
          _manuals = all.where((c) => c.type == CollectionType.manual).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _manuals = const [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final height = MediaQuery.of(context).size.height * 0.6;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          // drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '加入精选集',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                const Spacer(),
                LumiraButton(
                  variant: ButtonVariant.ghost,
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    '取消',
                    style: TextStyle(color: tokens.textTertiary),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 新建精选集入口
          LumiraListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tokens.brandSubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.add, color: tokens.brand, size: 20),
            ),
            title: Text(
              '新建精选集',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: tokens.textPrimary,
              ),
            ),
            onTap: () => Navigator.of(context).pop(
              const _CollectionPickResult(isNew: true),
            ),
          ),
          const Divider(height: 1),
          // manual 精选集列表
          Expanded(
            child: _isLoading
                ? Center(child: LumiraProgress.circular())
                : _manuals.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            '暂无手动精选集\n点击上方"新建精选集"创建',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: tokens.textTertiary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _manuals.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: tokens.divider),
                        itemBuilder: (_, i) {
                          final c = _manuals[i];
                          return LumiraListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: tokens.surfaceAlt,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.photo_library_outlined,
                                  color: tokens.textTertiary, size: 18),
                            ),
                            title: Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: tokens.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              '${c.photoCount} 张照片',
                              style: TextStyle(
                                fontSize: 11,
                                color: tokens.textTertiary,
                              ),
                            ),
                            onTap: () => Navigator.of(context).pop(
                              _CollectionPickResult(collectionId: c.id),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
