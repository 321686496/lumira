import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/gallery_mock_data.dart';

/// 相册详情页（暗色主题）
///
/// 视觉规格来源：lumira-app/src/pages/gallery/detail.vue（550 行）
/// - 暗色硬编码背景（#1C1A17）— 与 uni-app 一致，不接主题
/// - 画布区 + 场景信息行 + 工具 pills + 调色滑块 + LUT 缩略图 + EXIF 按钮 + 底部操作栏 + 场景选择 sheet
/// - 数据：通过 galleryDaoProvider.getById(photoId) 读取
class GalleryDetailPage extends ConsumerStatefulWidget {
  const GalleryDetailPage({super.key, this.photoId});

  final String? photoId;

  @override
  ConsumerState<GalleryDetailPage> createState() => _GalleryDetailPageState();
}

class _GalleryDetailPageState extends ConsumerState<GalleryDetailPage> {
  int _activeTool = 0;
  int _activeLut = 0;
  late List<_SliderState> _sliders;

  // Forced fix: FutureBuilder 在测试环境下不会从 ConnectionState.waiting
  // 切到 done（即使 future 已解析），导致 pumpAndSettle timed out。
  // 改用 state-variable-based loading + setState，绕过 FutureBuilder
  // 的内部 listener。CircularProgressIndicator（_isLoading=true 时显示，
  // 无限动画）让 pumpAndSettle 持续 pump 直到 setState 触发重建。
  GalleryItemRecord? _photo;
  bool _isLoading = true;
  bool _isInitialLoaded = false;

  @override
  void initState() {
    super.initState();
    _sliders = GalleryMockData.detailSliders
        .map((s) => _SliderState(label: s.label, value: s.value.toDouble(), display: s.display))
        .toList();
  }

  // Forced fix: 直接接收 GalleryDao 参数，避免在 _loadPhoto 内调用
  // `ref.read(galleryDaoProvider.future)`。在测试环境中，该 future 可能
  // 不解析。改为在 build() 的 daoAsync.when(data:) 分支中提取 dao 并传入。
  Future<void> _loadPhoto(GalleryDao dao) async {
    try {
      final photo = widget.photoId == null ? null : await dao.getById(widget.photoId!);
      if (mounted) {
        setState(() {
          _photo = photo;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _photo = null;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final daoAsync = ref.watch(galleryDaoProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF1C1A17), // 暗色硬编码
      appBar: LumiraNav(
        title: '照片详情',
        transparent: true,
        leading: _DarkBackButton(),
        actions: const [_CompareAction(), _MoreAction()],
      ),
      body: daoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFC9A96E))),
        error: (e, _) => Center(
          child: Text('加载失败：$e', style: const TextStyle(color: Colors.white60)),
        ),
        // Forced fix: 在 data 分支启动首次加载，直接传入 dao，
        // 避免 _loadPhoto 内调用 ref.read(provider.future) 在测试环境不解析。
        data: (dao) {
          if (!_isInitialLoaded) {
            _isInitialLoaded = true;
            _loadPhoto(dao);
          }
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFC9A96E)));
          }
          return _photo == null ? _EmptyCanvas() : _buildContent(_photo!);
        },
      ),
      bottomNavigationBar: _BottomBar(
        onReset: _reset,
        onExport: _export,
      ),
    );
  }

  Widget _buildContent(GalleryItemRecord photo) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 画布区
          _CanvasArea(photo: photo),
          // 场景信息行
          _SceneInfoRow(
            sceneName: photo.sceneId ?? '未分类',
            onTap: () {},
          ),
          // 工具 pills
          _ToolPillsRow(
            activeTool: _activeTool,
            onTap: (i) => setState(() => _activeTool = i),
          ),
          // 调色滑块
          _SliderBlock(
            sliders: _sliders,
            onChanged: (i, v) => setState(() {
              _sliders[i].value = v;
              final delta = (v - 50).round();
              _sliders[i].display = delta >= 0 ? '+$delta' : '$delta';
            }),
          ),
          // LUT 缩略图
          _LutBlock(
            activeLut: _activeLut,
            onTap: (i) => setState(() => _activeLut = i),
          ),
          // EXIF 按钮
          const _ExifButton(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _reset() {
    setState(() {
      for (final s in _sliders) {
        s.value = 50;
        s.display = '0';
      }
    });
  }

  void _export() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已导出'), duration: Duration(seconds: 1)),
    );
  }
}

class _SliderState {
  _SliderState({required this.label, required this.value, required this.display});
  String label;
  double value;
  String display;
}

// === 私有 widget ===

class _DarkBackButton extends StatelessWidget {
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

class _EmptyCanvas extends StatelessWidget {
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

class _CanvasArea extends StatelessWidget {
  const _CanvasArea({required this.photo});
  final GalleryItemRecord photo;

  @override
  Widget build(BuildContext context) {
    final url = photo.dataUrl ?? photo.filePath;
    return Container(
      padding: const EdgeInsets.all(16), // 32rpx → 16dp
      height: 360,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12), // 24rpx → 12dp
        child: url == null || url.isEmpty
            ? Container(
                color: const Color(0xFF2A2724),
                child: const Center(
                  child: Icon(Icons.image_outlined, size: 32, color: Colors.white38),
                ),
              )
            : url.startsWith('http')
                ? Image.network(url, fit: BoxFit.contain)
                : Image.asset(url, fit: BoxFit.contain),
      ),
    );
  }
}

class _SceneInfoRow extends StatelessWidget {
  const _SceneInfoRow({required this.sceneName, required this.onTap});
  final String sceneName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white12, width: 1),
            bottom: BorderSide(color: Colors.white12, width: 1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.place_outlined, size: 14, color: Color(0xFFC9A96E)),
                SizedBox(width: 6),
                Text(
                  '场景',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sceneName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 16, color: Colors.white60),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolPillsRow extends StatelessWidget {
  const _ToolPillsRow({required this.activeTool, required this.onTap});
  final int activeTool;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        itemCount: GalleryMockData.detailTools.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final active = i == activeTool;
          return GestureDetector(
            onTap: () => onTap(i),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                gradient: active
                    ? const LinearGradient(
                        colors: [Color(0xFFC9A96E), Color(0xFFA88550)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: active ? null : Colors.transparent,
                border: active ? null : Border.all(color: Colors.white24, width: 1.5),
                borderRadius: BorderRadius.circular(1000),
              ),
              child: Center(
                child: Text(
                  GalleryMockData.detailTools[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: active ? const Color(0xFF1C1A17) : Colors.white70,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SliderBlock extends StatelessWidget {
  const _SliderBlock({required this.sliders, required this.onChanged});
  final List<_SliderState> sliders;
  final void Function(int, double) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: List.generate(sliders.length, (i) {
          final s = sliders[i];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    s.label,
                    style: const TextStyle(fontSize: 13, color: Colors.white60),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: s.value,
                    min: 0,
                    max: 100,
                    activeColor: const Color(0xFFC9A96E),
                    inactiveColor: Colors.white.withOpacity(0.15),
                    onChanged: (v) => onChanged(i, v),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    s.display,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _LutBlock extends StatelessWidget {
  const _LutBlock({required this.activeLut, required this.onTap});
  final int activeLut;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        itemCount: GalleryMockData.detailLuts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final lut = GalleryMockData.detailLuts[i];
          final active = i == activeLut;
          return GestureDetector(
            onTap: () => onTap(i),
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: active
                        ? Border.all(color: const Color(0xFFC9A96E), width: 2)
                        : Border.all(color: Colors.white24, width: 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.network(
                      lut.img,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: Colors.white12),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                if (lut.name.isNotEmpty)
                  Text(
                    lut.name,
                    style: TextStyle(
                      fontSize: 11,
                      color: active ? const Color(0xFFC9A96E) : Colors.white60,
                    ),
                  )
                else
                  const SizedBox(height: 14),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ExifButton extends StatelessWidget {
  const _ExifButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: GestureDetector(
        onTap: () {},
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.assignment_outlined, size: 16, color: Color(0xFFC9A96E)),
              SizedBox(width: 8),
              Text(
                '生成 EXIF 卡片',
                style: TextStyle(fontSize: 13, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.onReset, required this.onExport});
  final VoidCallback onReset;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: const BoxDecoration(
          color: Color(0xFF1C1A17),
          border: Border(top: BorderSide(color: Colors.white12, width: 1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onReset,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24, width: 1),
                    borderRadius: BorderRadius.circular(1000),
                  ),
                  child: const Center(
                    child: Text(
                      '重置',
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: onExport,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFC9A96E), Color(0xFFA88550)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(1000),
                  ),
                  child: const Center(
                    child: Text(
                      '导出',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1A17),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
