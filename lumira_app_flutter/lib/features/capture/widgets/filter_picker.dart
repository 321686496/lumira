import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/capture_state.dart';
import '../data/capture_thumbnail_state.dart';
import '../domain/filter_recipe.dart';

/// 所有系统滤镜名称（与 filter_recipe.dart 中 systemFilterLabel 的 keys 一致）。
const _allSystemFilters = [
  'none',
  'vivid',
  'vivid_warm',
  'vivid_cool',
  'mono',
  'silver',
  'noir',
];

/// 所有 LUT 预设名称（与 filter_recipe.dart 中 lutLabel 的 keys 一致）。
const _allLuts = [
  'none',
  'cinematic',
  'vintage',
  'bw',
  'warm_film',
  'cool_film',
  'pastel',
  'fuji',
  'portrait',
  'japanese',
  'cyberpunk',
  'sepia_classic',
  'mist',
  'rouge',
  'twilight',
  'cyan',
];

/// 滤镜选择器：内联透明抽屉组件。
///
/// 性能优化：直接存储 ui.Image（跳过 PNG 编码/解码），高频捕获（~250ms），
/// 滤镜卡片使用 RawImage 直接渲染，实现流畅实时预览。
class FilterPicker extends ConsumerStatefulWidget {
  const FilterPicker({super.key, this.rawCaptureKey});

  final GlobalKey? rawCaptureKey;

  @override
  ConsumerState<FilterPicker> createState() => _FilterPickerState();
}

class _FilterPickerState extends ConsumerState<FilterPicker> {
  Timer? _captureTimer;

  /// 上一帧的 ui.Image，捕获新帧前 dispose 释放 GPU 内存
  ui.Image? _lastFrame;

  /// 防重叠标志：toImage 是异步 GPU 操作，防止上一次未完成时定时器又触发
  bool _isCapturing = false;

  @override
  void dispose() {
    _captureTimer?.cancel();
    // 先清空 provider，避免父级 widget 在本 State dispose 后仍用旧 image 渲染。
    // 否则 RawImage 会引用已被 dispose 的 ui.Image，触发
    // "Creator of a RawImage disposed of the image" 断言。
    if (_lastFrame != null) {
      ref.read(CaptureState.filterPreviewImageProvider.notifier).state = null;
      _lastFrame?.dispose();
    }
    super.dispose();
  }

  /// 启动高频帧捕获，立即执行一次首次捕获。
  ///
  /// 性能优化（修复卡顿）：
  /// - 使用递归 Timer 替代 Timer.periodic：上一帧捕获完成后再调度下一帧，
  ///   避免 toImage 耗时 >interval 时多个捕获重叠导致 GPU 拥塞
  /// - _isCapturing 防重叠保护
  /// - pixelRatio 降至 0.15（72x96 缩略图足够，大幅降低 GPU 开销）
  void _startCapture() {
    _captureTimer?.cancel();
    _scheduleNextCapture(const Duration(milliseconds: 80));
    WidgetsBinding.instance.addPostFrameCallback((_) => _captureFrame());
  }

  void _scheduleNextCapture(Duration delay) {
    _captureTimer = Timer(delay, () {
      _captureFrame().then((_) {
        if (mounted && _captureTimer != null) {
          _scheduleNextCapture(const Duration(milliseconds: 120));
        }
      });
    });
  }

  void _stopCapture() {
    _captureTimer?.cancel();
    _captureTimer = null;
  }

  /// 捕取当前原始相机帧并直接存储 ui.Image（跳过 PNG 编码/解码）
  Future<void> _captureFrame() async {
    if (_isCapturing) return;
    final key = widget.rawCaptureKey;
    if (key == null || !mounted) return;
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || boundary.debugNeedsPaint) return;

    _isCapturing = true;
    try {
      // pixelRatio: 0.15 — 极低分辨率足以在 72x96 缩略图中显示，大幅降低捕获开销
      final image = await boundary.toImage(pixelRatio: 0.15);
      if (!mounted) {
        image.dispose();
        return;
      }
      // dispose 上一帧释放 GPU 内存
      // 关键：先清空 provider 引用，再 dispose oldFrame。
      // 否则 provider 仍持有旧 image，而 RawImage 在下一帧渲染时发现 image 已被
      // dispose，触发 "Creator of a RawImage disposed of the image" 断言。
      final oldFrame = _lastFrame;
      _lastFrame = image;
      ref.read(CaptureState.filterPreviewImageProvider.notifier).state = image;
      oldFrame?.dispose();
    } catch (e) {
      // 捕获失败时静默忽略
    } finally {
      _isCapturing = false;
    }
  }

  void _selectSystemFilter(String filter) {
    final target = filter == 'none' ? null : filter;
    CaptureState.updatePostProcess(
        ref, (p) => p.copyWith(systemFilter: target));
  }

  void _selectLut(String lut) {
    CaptureState.updatePostProcess(ref, (p) => p.copyWith(lut: lut));
  }

  @override
  Widget build(BuildContext context) {
    final activeTool = ref.watch(CaptureState.activeToolProvider);
    final isVisible = activeTool == 'filter';
    // 拍照处理中暂停帧捕获，避免 GPU 占用导致连拍卡顿
    final thumbnailStatus = ref.watch(captureThumbnailProvider).status;
    final isCapturing = thumbnailStatus == CaptureThumbnailStatus.processing;

    if (isVisible && _captureTimer == null && !isCapturing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _captureTimer == null) _startCapture();
      });
    } else if ((!isVisible || isCapturing) && _captureTimer != null) {
      _stopCapture();
    }

    if (!isVisible) return const SizedBox.shrink();

    final raw = ref.watch(CaptureState.rawModeProvider);
    if (raw) {
      return const _RawModePlaceholder();
    }

    final post = ref.watch(CaptureState.effectivePostProcessProvider);
    final previewImage = ref.watch(CaptureState.filterPreviewImageProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.35,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FilterSection(
                label: '系统滤镜',
                filters: _allSystemFilters,
                activeFilter: post.systemFilter ?? 'none',
                previewImage: previewImage,
                filterKind: _FilterKind.system,
                onSelect: _selectSystemFilter,
              ),
              const SizedBox(height: 4),
              _FilterSection(
                label: 'LUT 预设',
                filters: _allLuts,
                activeFilter: post.lut,
                previewImage: previewImage,
                filterKind: _FilterKind.lut,
                onSelect: _selectLut,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _FilterKind { system, lut }

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.label,
    required this.filters,
    required this.activeFilter,
    required this.previewImage,
    required this.filterKind,
    required this.onSelect,
  });

  final String label;
  final List<String> filters;
  final String activeFilter;
  final ui.Image? previewImage;
  final _FilterKind filterKind;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (ctx, i) {
              final f = filters[i];
              final active = activeFilter == f ||
                  (f == 'none' && activeFilter.isEmpty);
              return _FilterThumbCard(
                name: filterKind == _FilterKind.system
                    ? systemFilterLabel(f)
                    : lutLabel(f),
                filterName: f,
                filterKind: filterKind,
                active: active,
                previewImage: previewImage,
                onTap: () => onSelect(f),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 滤镜缩略卡片：使用 RawImage 直接渲染 ui.Image（无需 PNG 解码）
class _FilterThumbCard extends StatelessWidget {
  const _FilterThumbCard({
    required this.name,
    required this.filterName,
    required this.filterKind,
    required this.active,
    required this.previewImage,
    required this.onTap,
  });

  final String name;
  final String filterName;
  final _FilterKind filterKind;
  final bool active;
  final ui.Image? previewImage;
  final VoidCallback onTap;

  ColorFilter _buildColorFilter() {
    if (filterName == 'none') {
      return const ColorFilter.mode(Colors.transparent, BlendMode.dst);
    }
    final matrix = filterKind == _FilterKind.system
        ? composeSystemFilterMatrix(filterName)
        : composeLutMatrix(filterName);
    return ColorFilter.matrix(matrix);
  }

  @override
  Widget build(BuildContext context) {
    const thumbW = 64.0;
    const thumbH = 80.0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: thumbW,
            height: thumbH,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: active
                    ? const Color(0xFFC9A96E)
                    : Colors.white.withOpacity(0.15),
                width: active ? 2 : 0.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (previewImage != null)
                  ColorFiltered(
                    colorFilter: _buildColorFilter(),
                    // RawImage 直接渲染 ui.Image，跳过 PNG 解码，零延迟
                    child: RawImage(
                      image: previewImage,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.08),
                          Colors.white.withOpacity(0.02),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.image_outlined,
                          color: Colors.white24, size: 20),
                    ),
                  ),
                if (active)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Color(0xFFC9A96E),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.black,
                        size: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            width: thumbW,
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active
                    ? const Color(0xFFC9A96E)
                    : Colors.white70,
                fontSize: 10,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// RAW 模式占位
class _RawModePlaceholder extends StatelessWidget {
  const _RawModePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.raw_on, color: Colors.orange.withOpacity(0.5), size: 40),
            const SizedBox(height: 8),
            const Text(
              'RAW 模式已启用',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '原相机直出，无任何滤镜处理\n关闭 RAW 模式后可使用滤镜',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
