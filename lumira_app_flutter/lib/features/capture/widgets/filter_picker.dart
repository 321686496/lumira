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

/// 滤镜选择器：一个不可见的触发 widget。
/// 当 `filterPickerVisibleProvider` 变为 true 时，通过 post-frame callback
/// 弹出 `showModalBottomSheet` 显示系统滤镜和 LUT 预设的选择器。
///
/// 修复 Bug 5：
/// - 使用可滚动的 CustomScrollView + SliverGrid 解决 OVERFLOW
/// - 大卡片设计，显示滤镜名称和当前选中状态
/// - 显示当前应用的滤镜信息
/// - 支持 RAW 模式禁用
class FilterPicker extends ConsumerWidget {
  const FilterPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(CaptureState.filterPickerVisibleProvider);

    if (!visible) return const SizedBox.shrink();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final currentVisible = ref.read(CaptureState.filterPickerVisibleProvider);
      if (!currentVisible) return;
      _showSheet(context, ref);
    });

    return const SizedBox.shrink();
  }

  void _showSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final raw = ref.watch(CaptureState.rawModeProvider);
          final post = ref.watch(CaptureState.effectivePostProcessProvider);

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 头部
              _FilterSheetHeader(
                rawMode: raw,
                currentSystemFilter: post.systemFilter,
                currentLut: post.lut,
                onClose: () => Navigator.of(context).pop(),
              ),
              // 内容（可滚动）
              Expanded(
                child: raw
                    ? _RawModePlaceholder()
                    : CustomScrollView(
                        slivers: [
                          // 系统滤镜分组
                          SliverToBoxAdapter(
                            child: _SectionLabel(
                              icon: Icons.tune,
                              title: '系统滤镜',
                              subtitle: '基于苹果系统滤镜风格',
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 0.85,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) {
                                  final f = _allSystemFilters[i];
                                  final active = post.systemFilter == f ||
                                      (f == 'none' &&
                                          post.systemFilter == null);
                                  return _FilterCard(
                                    name: systemFilterLabel(f),
                                    description: _systemFilterDesc(f),
                                    active: active,
                                    onTap: () => _selectSystemFilter(ref, f),
                                  );
                                },
                                childCount: _allSystemFilters.length,
                              ),
                            ),
                          ),
                          // LUT 分组
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 16),
                          ),
                          SliverToBoxAdapter(
                            child: _SectionLabel(
                              icon: Icons.palette_outlined,
                              title: 'LUT 预设',
                              subtitle: '胶片色调风格（CSS 滤镜近似）',
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 0.85,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) {
                                  final lut = _allLuts[i];
                                  final active = post.lut == lut;
                                  return _FilterCard(
                                    name: lutLabel(lut),
                                    description: _lutDesc(lut),
                                    active: active,
                                    onTap: () => _selectLut(ref, lut),
                                  );
                                },
                                childCount: _allLuts.length,
                              ),
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 16),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    ).whenComplete(() {
      ref.read(CaptureState.filterPickerVisibleProvider.notifier).state = false;
    });
  }

  void _selectSystemFilter(WidgetRef ref, String filter) {
    final target = filter == 'none' ? null : filter;
    CaptureState.updatePostProcess(
        ref, (p) => p.copyWith(systemFilter: target));
  }

  void _selectLut(WidgetRef ref, String lut) {
    CaptureState.updatePostProcess(ref, (p) => p.copyWith(lut: lut));
  }

  static String _systemFilterDesc(String f) {
    switch (f) {
      case 'none':
        return '原相机直出';
      case 'vivid':
        return '高对比高饱和';
      case 'vivid_warm':
        return '暖色调鲜艳';
      case 'vivid_cool':
        return '冷色调鲜艳';
      case 'mono':
        return '经典黑白';
      case 'silver':
        return '银盐黑白';
      case 'noir':
        return '黑色电影风';
      default:
        return '';
    }
  }

  static String _lutDesc(String lut) {
    switch (lut) {
      case 'none':
        return '无 LUT';
      case 'cinematic':
        return '电影感青橙';
      case 'vintage':
        return '复古胶片';
      case 'bw':
        return '黑白纪实';
      case 'warm_film':
        return '暖色胶片';
      case 'cool_film':
        return '冷色胶片';
      case 'pastel':
        return '柔和粉彩';
      case 'fuji':
        return '富士胶片';
      case 'portrait':
        return '人像肤色';
      case 'japanese':
        return '日系清新';
      case 'cyberpunk':
        return '赛博朋克';
      case 'sepia_classic':
        return '怀旧棕褐';
      case 'mist':
        return '朦胧雾感';
      case 'rouge':
        return '胭脂红调';
      case 'twilight':
        return '暮色蓝调';
      case 'cyan':
        return '青色冷调';
      default:
        return '';
    }
  }
}

/// 滤镜弹窗头部
class _FilterSheetHeader extends StatelessWidget {
  const _FilterSheetHeader({
    required this.rawMode,
    required this.currentSystemFilter,
    required this.currentLut,
    required this.onClose,
  });

  final bool rawMode;
  final String? currentSystemFilter;
  final String currentLut;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final hasFilter =
        (currentSystemFilter != null && currentSystemFilter != 'none') ||
            currentLut != 'none';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white12, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          // 拖动条
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 4, bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white38,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标题行
          Row(
            children: [
              const Icon(Icons.filter_alt, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '滤镜选择',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // 当前滤镜标识
              if (hasFilter && !rawMode)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _currentFilterText(),
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 11,
                    ),
                  ),
                ),
              if (rawMode)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'RAW 模式',
                    style: TextStyle(color: Colors.orange, fontSize: 11),
                  ),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white70, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _currentFilterText() {
    final parts = <String>[];
    if (currentSystemFilter != null && currentSystemFilter != 'none') {
      parts.add(systemFilterLabel(currentSystemFilter!));
    }
    if (currentLut != 'none') {
      parts.add(lutLabel(currentLut));
    }
    return parts.isEmpty ? '无' : parts.join(' + ');
  }
}

/// 分组标题
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 滤镜卡片（大卡片设计）
class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.name,
    required this.description,
    required this.active,
    required this.onTap,
  });

  final String name;
  final String description;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: active
              ? Colors.amber.withOpacity(0.12)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: active
              ? Border.all(color: Colors.amber, width: 1.5)
              : Border.all(color: Colors.white12, width: 0.5),
        ),
        child: Stack(
          children: [
            // 内容
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 滤镜图标占位
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.amber.withOpacity(0.2)
                          : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: active ? Colors.amber : Colors.white54,
                      size: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 滤镜名称
                  Text(
                    name,
                    style: TextStyle(
                      color: active ? Colors.amber : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // 描述
                  if (description.isNotEmpty)
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // 选中角标
            if (active)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.black,
                    size: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// RAW 模式占位
class _RawModePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.raw_on, color: Colors.orange.withOpacity(0.5), size: 56),
          const SizedBox(height: 16),
          const Text(
            'RAW 模式已启用',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '原相机直出，无任何滤镜处理\n关闭 RAW 模式后可使用滤镜',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
