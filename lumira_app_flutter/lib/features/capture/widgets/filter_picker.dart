import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/capture_state.dart';
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

/// 静态预览图 URL（替代实时取景，减少 GPU 开销）
const _staticLandscapeImage =
    'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=200&q=80';
const _staticPortraitImage =
    'https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?w=200&q=80';

/// 滤镜选择器：内联透明抽屉组件。
/// 使用静态图片预览，根据前后置摄像头自动切换。
class FilterPicker extends ConsumerWidget {
  const FilterPicker({super.key});

  void _selectSystemFilter(WidgetRef ref, String filter) {
    final target = filter == 'none' ? null : filter;
    CaptureState.updatePostProcess(
        ref, (p) => p.copyWith(systemFilter: target));
  }

  void _selectLut(WidgetRef ref, String lut) {
    CaptureState.updatePostProcess(ref, (p) => p.copyWith(lut: lut));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTool = ref.watch(CaptureState.activeToolProvider);
    final isVisible = activeTool == 'filter';
    if (!isVisible) return const SizedBox.shrink();

    final raw = ref.watch(CaptureState.rawModeProvider);
    if (raw) {
      return const _RawModePlaceholder();
    }

    final post = ref.watch(CaptureState.effectivePostProcessProvider);
    final facing = ref.watch(CaptureState.cameraFacingProvider);
    // 根据前后置摄像头选择静态预览图
    final previewImageUrl = facing == 'front'
        ? _staticPortraitImage
        : _staticLandscapeImage;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FilterSection(
            label: '系统滤镜',
            filters: _allSystemFilters,
            activeFilter: post.systemFilter ?? 'none',
            previewImageUrl: previewImageUrl,
            filterKind: _FilterKind.system,
            onSelect: (filter) => _selectSystemFilter(ref, filter),
          ),
          const SizedBox(height: 4),
          _FilterSection(
            label: 'LUT 预设',
            filters: _allLuts,
            activeFilter: post.lut,
            previewImageUrl: previewImageUrl,
            filterKind: _FilterKind.lut,
            onSelect: (lut) => _selectLut(ref, lut),
          ),
        ],
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
    required this.previewImageUrl,
    required this.filterKind,
    required this.onSelect,
  });

  final String label;
  final List<String> filters;
  final String activeFilter;
  final String previewImageUrl;
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
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 4),
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
                previewImageUrl: previewImageUrl,
                onTap: () => onSelect(f),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 滤镜缩略卡片：使用静态网络图片 + ColorFiltered 应用滤镜效果
class _FilterThumbCard extends StatelessWidget {
  const _FilterThumbCard({
    required this.name,
    required this.filterName,
    required this.filterKind,
    required this.active,
    required this.previewImageUrl,
    required this.onTap,
  });

  final String name;
  final String filterName;
  final _FilterKind filterKind;
  final bool active;
  final String previewImageUrl;
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
    // 75% 缩小：原 64x80 → 48x60
    const thumbW = 48.0;
    const thumbH = 60.0;

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
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: active
                    ? const Color(0xFFC9A96E)
                    : Colors.white.withOpacity(0.15),
                width: active ? 1.5 : 0.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColorFiltered(
                  colorFilter: _buildColorFilter(),
                  child: Image.network(
                    previewImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
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
                            color: Colors.white24, size: 16),
                      ),
                    ),
                  ),
                ),
                if (active)
                  Positioned(
                    top: 3,
                    right: 3,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFFC9A96E),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.black,
                        size: 8,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
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
                fontSize: 9,
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
