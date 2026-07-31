import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/capture_state.dart';
import '../domain/filter_recipe.dart';
import '../domain/photo_template.dart';

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
/// 改造说明（原为 showModalBottomSheet 模态弹窗）：
/// - 改为内联 widget，由 `_AnimatedToolDrawer` 在 `activeTool == 'filter'` 时渲染
/// - 透明背景，不遮挡取景器
/// - 横向滚动卡片，每张卡片实时显示取景框内容 + 套用该滤镜后的效果
/// - 通过 [rawCaptureKey] 周期性捕获原始相机帧（未经 ColorFiltered 处理），
///   在每张滤镜卡片中套用对应 ColorFilter 显示效果预览
/// - 支持 RAW 模式禁用
class FilterPicker extends ConsumerStatefulWidget {
  const FilterPicker({super.key, this.rawCaptureKey});

  /// 用于捕获原始相机帧的 RepaintBoundary key。
  /// 由 CapturePage 创建并传给 CameraPreview，FilterPicker 通过此 key
  /// 调用 `boundary.toImage()` 捕获当前帧。
  final GlobalKey? rawCaptureKey;

  @override
  ConsumerState<FilterPicker> createState() => _FilterPickerState();
}

class _FilterPickerState extends ConsumerState<FilterPicker> {
  Timer? _captureTimer;

  @override
  void dispose() {
    _captureTimer?.cancel();
    super.dispose();
  }

  /// 启动周期性帧捕获（每 2 秒一次），立即执行一次首次捕获
  void _startCapture() {
    _captureTimer?.cancel();
    _captureTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _captureFrame(),
    );
    // 首次立即捕获
    WidgetsBinding.instance.addPostFrameCallback((_) => _captureFrame());
  }

  /// 停止周期性帧捕获
  void _stopCapture() {
    _captureTimer?.cancel();
    _captureTimer = null;
  }

  /// 捕取当前原始相机帧并写入 [CaptureState.filterPreviewImageProvider]
  Future<void> _captureFrame() async {
    final key = widget.rawCaptureKey;
    if (key == null || !mounted) return;
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || boundary.debugNeedsPaint) return;
    try {
      // pixelRatio: 0.3 — 低分辨率足以在 72x96 缩略图中显示，降低捕获开销
      final image = await boundary.toImage(pixelRatio: 0.3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null && mounted) {
        ref.read(CaptureState.filterPreviewImageProvider.notifier).state =
            byteData.buffer.asUint8List();
      }
    } catch (e) {
      // 捕获失败时静默忽略（相机纹理可能在某些平台不支持 toImage）
      debugPrint('[FilterPicker] 帧捕获失败: $e');
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

    // 管理 capture timer
    if (isVisible && _captureTimer == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _captureTimer == null) _startCapture();
      });
    } else if (!isVisible && _captureTimer != null) {
      _stopCapture();
    }

    if (!isVisible) return const SizedBox.shrink();

    final raw = ref.watch(CaptureState.rawModeProvider);
    if (raw) {
      return const _RawModePlaceholder();
    }

    final post = ref.watch(CaptureState.effectivePostProcessProvider);
    final previewBytes = ref.watch(CaptureState.filterPreviewImageProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 系统滤镜行
          _FilterSection(
            label: '系统滤镜',
            filters: _allSystemFilters,
            activeFilter: post.systemFilter ?? 'none',
            previewBytes: previewBytes,
            filterKind: _FilterKind.system,
            onSelect: _selectSystemFilter,
          ),
          const SizedBox(height: 4),
          // LUT 滤镜行
          _FilterSection(
            label: 'LUT 预设',
            filters: _allLuts,
            activeFilter: post.lut,
            previewBytes: previewBytes,
            filterKind: _FilterKind.lut,
            onSelect: _selectLut,
          ),
        ],
      ),
    );
  }
}

/// 滤镜类型
enum _FilterKind { system, lut }

/// 滤镜分组：标题 + 横向滚动卡片行
class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.label,
    required this.filters,
    required this.activeFilter,
    required this.previewBytes,
    required this.filterKind,
    required this.onSelect,
  });

  final String label;
  final List<String> filters;
  final String activeFilter;
  final Uint8List? previewBytes;
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
          height: 120,
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
                previewBytes: previewBytes,
                onTap: () => onSelect(f),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 滤镜缩略卡片：显示取景框帧 + 套用该滤镜后的效果
class _FilterThumbCard extends StatelessWidget {
  const _FilterThumbCard({
    required this.name,
    required this.filterName,
    required this.filterKind,
    required this.active,
    required this.previewBytes,
    required this.onTap,
  });

  final String name;
  final String filterName;
  final _FilterKind filterKind;
  final bool active;
  final Uint8List? previewBytes;
  final VoidCallback onTap;

  /// 构建此滤镜对应的 ColorFilter（仅此滤镜，不叠加其他 PostProcess 参数）
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
    const thumbW = 72.0;
    const thumbH = 96.0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 缩略图
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
                // 取景框帧 + 滤镜效果
                if (previewBytes != null)
                  ColorFiltered(
                    colorFilter: _buildColorFilter(),
                    child: Image.memory(
                      previewBytes!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  )
                else
                  // 捕获前的占位（渐变背景）
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
                // 选中角标
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
          // 滤镜名称
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
