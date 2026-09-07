import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/image_cache.dart';
import '../../../shared/widgets/effects/recessed_surface.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../domain/filter_recipe.dart';
import '../domain/photo_template.dart';
import '../domain/post_process_delta.dart';
import 'post_process_color_tab.dart';
import 'post_process_detail_tab.dart';
import 'post_process_slider_row.dart';

/// 预览页编辑面板（4 标签底部抽屉）
///
/// 美化版要点：
/// - 字体全面缩小（标题 13 / Tab 12 / 滑块标签 11 / 滑块数值 11 / Chip 10）
/// - 自定义滑块：细线轨道 + 圆形把手 + 品牌色填充，支持拖拽
/// - 自定义 Chip：圆角矩形，选中品牌色背景 + 黑字，未选中半透明白色
/// - 中文标签映射（Filter Tab）
/// - 高度自适应：移除硬编码 height: 360，依赖外层约束
class PreviewEditPanel extends ConsumerStatefulWidget {
  final PostProcess postProcess;
  final TransformParams transform;
  final ValueChanged<PostProcess> onPostProcessChanged;
  final ValueChanged<TransformParams> onTransformChanged;

  /// 预览图路径（用于滤镜缩略图）。可为空（此时滤镜页降级为文字 Chip）。
  final String? previewImagePath;

  /// 拍摄时烘焙的基线参数。为 null 时视为全零基线（默认行为不变）。
  /// 色彩/细节 Tab 的滑块显示全量值（baked + 增量），onChanged 时反推增量传回上层。
  final PostProcess? bakedPostProcess;

  /// 裁剪工具激活状态回调（true = 用户切到「裁剪旋转」Tab）。
  /// 上层据此在照片本身上叠加裁剪框（iPhone 风格，而非底部小预览）。
  final ValueChanged<bool>? onCropModeChanged;

  const PreviewEditPanel({
    super.key,
    required this.postProcess,
    required this.transform,
    required this.onPostProcessChanged,
    required this.onTransformChanged,
    this.previewImagePath,
    this.bakedPostProcess,
    this.onCropModeChanged,
  });

  @override
  ConsumerState<PreviewEditPanel> createState() => _PreviewEditPanelState();
}

class _PreviewEditPanelState extends ConsumerState<PreviewEditPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // 监听 tab index 变化（点击 tab 切换），触发 setState 重绘内容
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
        // 通知上层裁剪工具激活状态（在照片上叠加裁剪框）
        widget.onCropModeChanged?.call(_tabController.index == 3);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updatePost(PostProcess p) => widget.onPostProcessChanged(p);
  void _updateTransform(TransformParams t) => widget.onTransformChanged(t);

  /// 烘焙基线（未提供时为全零基线）。
  PostProcess get _baked =>
      widget.bakedPostProcess ?? const PostProcess(color: PostProcessColor());

  /// 用户在色彩/细节面板上看到并操作的全量参数（baked + 增量）。
  PostProcess get _fullForEdit => fullOf(_baked, widget.postProcess);

  /// 由新的全量值反推增量并回调上层。
  /// 传入当前增量（widget.postProcess）以保留裁剪比例/裁剪框字段
  /// （见 deltaOf 的 current 参数说明）。
  void _updatePostFromFull(PostProcess newFull) =>
      widget.onPostProcessChanged(
          deltaOf(_baked, newFull, current: widget.postProcess));

  @override
  Widget build(BuildContext context) {
    return Container(
      // 透明背景：外层 _BottomSheet 已有半透明深色背景
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          // 点击 Tab 切换：不再用 TabBarView，直接根据 _tabController.index 显示对应 Tab
          Expanded(
            child: _buildCurrentTab(),
          ),
        ],
      ),
    );
  }

  /// 根据 _tabController.index 显示当前 Tab 内容（点击切换，非滑动）
  Widget _buildCurrentTab() {
    final tokens = ref.watch(themeTokensProvider);
    switch (_tabController.index) {
      case 0:
        return PostProcessColorTab(
          full: _fullForEdit,
          onChanged: _updatePostFromFull,
          tokens: tokens,
        );
      case 1:
        return PostProcessDetailTab(
          full: _fullForEdit,
          onChanged: _updatePostFromFull,
          tokens: tokens,
        );
      case 2:
        return FilterTab(
          postProcess: _fullForEdit,
          onChanged: _updatePostFromFull,
          previewImagePath: widget.previewImagePath,
          tokens: tokens,
        );
      case 3:
        return CropTab(
          transform: widget.transform,
          onChanged: _updateTransform,
          postProcess: widget.postProcess,
          onPostProcessChanged: _updatePost,
          tokens: tokens,
          previewImagePath: widget.previewImagePath,
        );
      default:
        return PostProcessColorTab(
          full: _fullForEdit,
          onChanged: _updatePostFromFull,
        );
    }
  }

  Widget _buildHeader() {
    final tokens = ref.watch(themeTokensProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '编辑',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          GestureDetector(
            onTap: () {
              // 重置当前 Tab 的参数
              switch (_tabController.index) {
                case 0:
                  // 重置到烘焙基线：全量 = _baked，反推增量自然为 0
                  _updatePostFromFull(_baked);
                  break;
                case 1:
                  // 重置细节字段（smooth/sharpen/vignette/grain）为烘焙基线，保留 color 增量。
                  // 在 _fullForEdit 基础上逐字段覆盖，避免细节重置时把 color 增量（含清晰度）一并置零。
                  _updatePostFromFull(_fullForEdit.copyWith(
                    smoothStrength: _baked.smoothStrength,
                    sharpen: _baked.sharpen,
                    vignette: _baked.vignette,
                    grain: _baked.grain,
                    legStretch: _baked.legStretch,
                  ));
                  break;
                case 3:
                  _updateTransform(const TransformParams());
                  break;
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                '重置',
                style: TextStyle(fontSize: 11, color: tokens.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return LumiraTabBar(
      controller: _tabController,
      tabs: const [
        Text('色彩'),
        Text('细节'),
        Text('滤镜'),
        Text('裁剪旋转'),
      ],
    );
  }
}

// === Filter Tab ===
const editLutLabels = <String, String>{
  'none': '原图',
  'cinematic': '电影感',
  'vintage': '复古',
  'bw': '黑白胶片',
  'warm_film': '暖色胶片',
  'cool_film': '冷色胶片',
  'pastel': '柔彩',
  'fuji': '富士',
  'portrait': '人像',
  'japanese': '日系',
  'japanese_fresh': '日系清新',
  'cream': '奶油感',
  'cyberpunk': '赛博朋克',
  'night_cyber': '夜景赛博',
  'hk_neon': '港风霓虹',
  'sepia_classic': '棕褐',
  'mist': '薄雾',
  'rouge': '胭脂',
  'twilight': '暮光',
  'cyan': '青调',
  'noir': '黑白',
  'fine_art_bw': '黑白艺术',
  'silver': '银盐感',
  'morandi': '莫兰迪',
  'muted_gray': '低饱和高级灰',
  'heavy_film': '浓厚胶片',
};

/// 旧系统滤镜 → 统一滤镜库 key 的映射（用于高亮旧数据中的系统滤镜）。
const _editLegacySystemToUnified = <String, String>{
  'vivid': 'fuji',
  'vivid_warm': 'warm_film',
  'vivid_cool': 'cool_film',
  'mono': 'fine_art_bw',
  'silver': 'silver',
  'noir': 'noir',
};

class FilterTab extends StatelessWidget {
  final PostProcess postProcess;
  final ValueChanged<PostProcess> onChanged;

  /// 预览图路径。为空时降级为文字 Chip。
  final String? previewImagePath;

  /// 主题色板
  final ThemeTokens tokens;

  const FilterTab({
    super.key,
    required this.postProcess,
    required this.onChanged,
    required this.previewImagePath,
    required this.tokens,
  });

  /// 当前高亮的统一滤镜 key。
  String _activeFilter() {
    if (postProcess.lut != 'none' && postProcess.lut.isNotEmpty) {
      return postProcess.lut;
    }
    final sf = postProcess.systemFilter;
    if (sf != null && sf.isNotEmpty) {
      return _editLegacySystemToUnified[sf] ?? sf;
    }
    return 'none';
  }

  @override
  Widget build(BuildContext context) {
    final activeFilter = _activeFilter();
    const filters = unifiedFilters;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          '滤镜',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final name = filters[i];
              final selected = activeFilter == name;
              return FilterThumbnail(
                label: editLutLabels[name] ?? name,
                selected: selected,
                tokens: tokens,
                matrix: composeLutMatrix(name),
                previewImagePath: previewImagePath,
                onTap: () => onChanged(postProcess.copyWith(
                  lut: name,
                  systemFilter: null,
                )),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 滤镜缩略图卡片：64x80 预览图 + 滤镜名 + 选中边框
class FilterThumbnail extends StatelessWidget {
  final String label;
  final bool selected;
  final ThemeTokens tokens;
  final List<double> matrix;
  final String? previewImagePath;
  final VoidCallback onTap;

  const FilterThumbnail({
    super.key,
    required this.label,
    required this.selected,
    required this.tokens,
    required this.matrix,
    required this.previewImagePath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = previewImagePath != null && previewImagePath!.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 72,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selected ? tokens.brand : tokens.divider,
                      width: selected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: selected ? tokens.shadowFloat : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: hasImage
                        ? ColorFiltered(
                            colorFilter: ColorFilter.matrix(matrix),
                            child: previewImagePath!.startsWith('http')
                                ? CachedNetworkImage(
                                    url: previewImagePath!,
                                    fit: BoxFit.cover)
                                : Image.file(File(previewImagePath!),
                                    fit: BoxFit.cover),
                          )
                        : Container(
                            color: tokens.surfaceAlt,
                            alignment: Alignment.center,
                            child: Text(
                              label,
                              style: TextStyle(
                                  fontSize: 9, color: tokens.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ),
                  ),
                ),
                // 选中态徽标（右上角对勾）
                if (selected)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: tokens.brand,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: tokens.surface, width: 1.5),
                      ),
                      child: Icon(Icons.check,
                          size: 11, color: tokens.textInverse),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: selected ? tokens.brand : tokens.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// === Crop Tab ===
class CropTab extends ConsumerWidget {
  final TransformParams transform;
  final ValueChanged<TransformParams> onChanged;

  /// 后期参数（用于裁剪比例 cropRatio 和自定义裁剪框 customCropRect）
  final PostProcess postProcess;

  /// 后期参数更新回调（用于裁剪比例和裁剪框）
  final ValueChanged<PostProcess> onPostProcessChanged;

  /// 主题色板
  final ThemeTokens tokens;

  /// 预览图路径（用于裁剪框预览区）
  final String? previewImagePath;

  const CropTab({
    super.key,
    required this.transform,
    required this.onChanged,
    required this.postProcess,
    required this.onPostProcessChanged,
    required this.tokens,
    required this.previewImagePath,
  });

  /// 裁剪比例选择器：自由 / 1:1 / 4:3 / 3:4 / 16:9 / 全屏
  Widget _buildRatioSelector(bool isNeu) {
    const ratios = <MapEntry<String, String>>[
      MapEntry('free', '自由'),
      MapEntry('1:1', '1:1'),
      MapEntry('4:3', '4:3'),
      MapEntry('3:4', '3:4'),
      MapEntry('16:9', '16:9'),
      MapEntry('fullscreen', '全屏'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            '裁剪比例',
            style: TextStyle(
                fontSize: 13,
                color: tokens.textSecondary,
                fontWeight: FontWeight.w500),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: ratios.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final ratio = ratios[i].key;
              final label = ratios[i].value;
              final selected = postProcess.cropRatio == ratio;
              final labelContent = Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: selected
                        ? (isNeu ? tokens.brandText : tokens.textInverse)
                        : tokens.textPrimary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              );

              return GestureDetector(
                onTap: () {
                  // 切换比例时重置自定义裁剪框（null = 使用默认居中）
                  onPostProcessChanged(postProcess.copyWith(
                    cropRatio: ratio,
                    customCropRect: null,
                  ));
                },
                behavior: HitTestBehavior.opaque,
                child: isNeu && selected
                    ? RecessedSurface(
                        tokens: tokens,
                        borderRadius: 1000,
                        depth: 0.7,
                        rimFraction: 0.32,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: labelContent,
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          // neumorphic：方案 B 选中/未选中同为 surface，仅凸起↔凹陷翻转；品牌色只在文字
                          color: isNeu
                              ? tokens.surface
                              : (selected ? tokens.brand : tokens.surfaceAlt),
                          borderRadius: BorderRadius.circular(1000),
                          border: isNeu
                              ? null
                              : Border.all(
                                  color: selected
                                      ? tokens.brand
                                      : tokens.divider,
                                  width: 1),
                          boxShadow: isNeu ? tokens.shadowConvexSubtle : null,
                        ),
                        child: labelContent,
                      ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 裁剪框已迁移到照片本体上（PhotoCropLayer 叠加），
    // 底部面板不再显示小预览框，保留比例选择 / 旋转翻转 / 拉直。
    final isNeu = ref.watch(uiStyleProvider) == UIStyle.neumorphic;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      children: [
        _buildRatioSelector(isNeu),
        // 旋转 / 翻转 控制组：圆角容器内一字排开的图标操作
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: tokens.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CropAction(
                icon: Icons.rotate_left,
                label: '逆时针',
                tokens: tokens,
                isNeu: isNeu,
                onTap: () => onChanged(transform.copyWith(
                  rotation: (transform.rotation - 90) % 360,
                )),
              ),
              _CropAction(
                icon: Icons.rotate_right,
                label: '顺时针',
                tokens: tokens,
                isNeu: isNeu,
                onTap: () => onChanged(transform.copyWith(
                  rotation: (transform.rotation + 90) % 360,
                )),
              ),
              _CropAction(
                icon: Icons.flip,
                label: '水平',
                active: transform.flipH,
                tokens: tokens,
                isNeu: isNeu,
                onTap: () =>
                    onChanged(transform.copyWith(flipH: !transform.flipH)),
              ),
              _CropAction(
                icon: Icons.flip,
                label: '垂直',
                active: transform.flipV,
                quarterTurns: 1,
                tokens: tokens,
                isNeu: isNeu,
                onTap: () =>
                    onChanged(transform.copyWith(flipV: !transform.flipV)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        PostProcessSliderRow(
          label: '拉直',
          value: transform.straighten,
          min: -15,
          max: 15,
          tokens: tokens,
          onChanged: (v) => onChanged(transform.copyWith(straighten: v)),
        ),
      ],
    );
  }
}

/// 裁剪变换操作项：圆形图标 + 下方名称，翻转类操作高亮选中态
class _CropAction extends StatelessWidget {
  const _CropAction({
    required this.icon,
    required this.label,
    required this.tokens,
    required this.isNeu,
    required this.onTap,
    this.active = false,
    this.quarterTurns = 0,
  });

  final IconData icon;
  final String label;
  final bool active;
  final int quarterTurns;
  final ThemeTokens tokens;
  final bool isNeu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? (isNeu ? tokens.brandText : tokens.brand)
        : tokens.textSecondary;

    final Widget iconCircle;
    if (isNeu && active) {
      // 新拟态圆底选中态用 RecessedSurface 沿四边叠加明暗呈凹陷（40×40 → 圆角 20）
      iconCircle = RecessedSurface(
        tokens: tokens,
        borderRadius: 20,
        depth: 0.7,
        rimFraction: 0.32,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: RotatedBox(
              quarterTurns: quarterTurns,
              child: Icon(icon, size: 20, color: color),
            ),
          ),
        ),
      );
    } else {
      iconCircle = AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          // neumorphic：方案 B 选中/未选中同为 surface 圆底，选中态由 RecessedSurface 凹陷表达
          color: isNeu
              ? tokens.surface
              : (active ? tokens.brandSubtle : Colors.transparent),
          shape: BoxShape.circle,
          boxShadow: isNeu ? tokens.shadowConvexSubtle : null,
        ),
        alignment: Alignment.center,
        child: RotatedBox(
          quarterTurns: quarterTurns,
          child: Icon(icon, size: 20, color: color),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconCircle,
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
