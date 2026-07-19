import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/gallery_models.dart';
import '../widgets/photo_cell.dart';
import '../widgets/scene_filter_pills.dart';
import '../widgets/view_toggle.dart';

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

  // Forced fix: FutureBuilder 在测试环境下不会从 ConnectionState.waiting
  // 切到 done（即使 future 已解析），导致 pumpAndSettle timed out。
  // 改用 state-variable-based loading + setState，绕过 FutureBuilder
  // 的内部 listener。CircularProgressIndicator（_isLoading=true 时显示，
  // 无限动画）让 pumpAndSettle 持续 pump 直到 setState 触发重建。
  List<GalleryItemRecord> _photos = const [];
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
      if (mounted) {
        setState(() {
          _photos = photos;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _photos = const [];
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

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final daoAsync = ref.watch(galleryDaoProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: LumiraNav(
        title: '相册',
        transparent: true,
        leading: _BackButton(tokens: tokens),
        actions: [
          _CollectionsAction(tokens: tokens),
        ],
      ),
      body: Stack(
        children: [
          // 1. 径向渐变背景装饰（glass 风格可见性）
          _BackgroundDecoration(tokens: tokens),
          // 2. 主内容层
          SafeArea(
            child: daoAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
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
    final pills = _buildPills(_photos);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 顶部信息条：张数 + 视图切换
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Row(
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
              ViewToggle(
                activeTab: _viewTab,
                onPhotoTap: () {},
                onDiaryTap: () => GoRouter.of(context).push(RouteNames.galleryDiary),
              ),
            ],
          ),
        ),
        // 场景筛选 pills
        SceneFilterPills(
          pills: pills,
          activeKey: _activeFilter,
          onTap: _setFilter,
        ),
        const SizedBox(height: 12),
        // 网格或空状态
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : photoViews.isEmpty
                  ? _EmptyState(tokens: tokens)
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 6, // 12rpx → 6dp
                        crossAxisSpacing: 6,
                      ),
                      itemCount: photoViews.length,
                      itemBuilder: (_, i) {
                        final photo = photoViews[i];
                        return FadeUp(
                          delay: Duration(milliseconds: (i % 6) * 50),
                          child: PhotoCell(
                            photo: photo,
                            onTap: () => GoRouter.of(context).push(
                              RouteNames.build(
                                RouteNames.galleryDetail,
                                {RouteNames.paramPhotoId: photo.id},
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
        // 长按多选提示
        Padding(
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
        label: '未分类',
        count: groups['uncategorized']!,
        icon: Icons.folder_open_outlined,
      ));
    }
    // 其余场景（mock 阶段 sceneId 不是已知 scene，仅显示 sceneId 简短形式）
    groups.forEach((sid, cnt) {
      if (sid == 'uncategorized') return;
      result.add(SceneFilterPill(
        key: 'scene_$sid',
        label: sid.length > 4 ? sid.substring(0, 4) : sid,
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

class _CollectionsAction extends StatelessWidget {
  const _CollectionsAction({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => GoRouter.of(context).push(RouteNames.profileCollections),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          '精选集',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: tokens.brand,
            height: 1.3,
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
          Icon(Icons.image_outlined, size: 48, color: tokens.textTertiary),
          const SizedBox(height: 12),
          Text(
            '还没有照片，去拍一张吧',
            style: TextStyle(
              fontSize: 13,
              color: tokens.textTertiary,
              height: 1.3,
            ),
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
