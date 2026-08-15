import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../gallery/widgets/crop_overlay.dart';
import '../domain/filter_recipe.dart';
import '../domain/photo_template.dart';
import '../domain/post_process_delta.dart';

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

  const PreviewEditPanel({
    super.key,
    required this.postProcess,
    required this.transform,
    required this.onPostProcessChanged,
    required this.onTransformChanged,
    this.previewImagePath,
    this.bakedPostProcess,
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
  void _updatePostFromFull(PostProcess newFull) =>
      widget.onPostProcessChanged(deltaOf(_baked, newFull));

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
        return _ColorTab(
          postProcess: _fullForEdit,
          onChanged: _updatePostFromFull,
        );
      case 1:
        return _DetailTab(
          postProcess: _fullForEdit,
          onChanged: _updatePostFromFull,
        );
      case 2:
        return _FilterTab(
          postProcess: _fullForEdit,
          onChanged: _updatePostFromFull,
          previewImagePath: widget.previewImagePath,
          tokens: tokens,
        );
      case 3:
        return _CropTab(
          transform: widget.transform,
          onChanged: _updateTransform,
          postProcess: widget.postProcess,
          onPostProcessChanged: _updatePost,
          tokens: tokens,
          previewImagePath: widget.previewImagePath,
        );
      default:
        return _ColorTab(
          postProcess: widget.postProcess,
          onChanged: _updatePost,
        );
    }
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '编辑',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
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
                  ));
                  break;
                case 3:
                  _updateTransform(const TransformParams());
                  break;
              }
            },
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                '重置',
                style: TextStyle(fontSize: 11, color: Colors.white54),
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

// === Color Tab ===
class _ColorTab extends StatelessWidget {
  final PostProcess postProcess;
  final ValueChanged<PostProcess> onChanged;

  const _ColorTab({required this.postProcess, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = postProcess.color;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      children: [
        _SliderRow(
          label: '亮度',
          value: c.brightness,
          min: -100,
          max: 100,
          onChanged: (v) => onChanged(postProcess.copyWith(
            color: c.copyWith(brightness: v),
          )),
        ),
        _SliderRow(
          label: '对比度',
          value: c.contrast,
          min: -100,
          max: 100,
          onChanged: (v) => onChanged(postProcess.copyWith(
            color: c.copyWith(contrast: v),
          )),
        ),
        _SliderRow(
          label: '饱和度',
          value: c.saturation,
          min: -100,
          max: 100,
          onChanged: (v) => onChanged(postProcess.copyWith(
            color: c.copyWith(saturation: v),
          )),
        ),
        _SliderRow(
          label: '色温',
          value: c.temperature,
          min: -100,
          max: 100,
          onChanged: (v) => onChanged(postProcess.copyWith(
            color: c.copyWith(temperature: v),
          )),
        ),
        _SliderRow(
          label: '色调',
          value: c.tint,
          min: -100,
          max: 100,
          onChanged: (v) => onChanged(postProcess.copyWith(
            color: c.copyWith(tint: v),
          )),
        ),
        _SliderRow(
          label: '高光',
          value: c.highlights ?? 0,
          min: -100,
          max: 100,
          onChanged: (v) => onChanged(postProcess.copyWith(
            color: c.copyWith(highlights: v),
          )),
        ),
        _SliderRow(
          label: '阴影',
          value: c.shadows ?? 0,
          min: -100,
          max: 100,
          onChanged: (v) => onChanged(postProcess.copyWith(
            color: c.copyWith(shadows: v),
          )),
        ),
        _SliderRow(
          label: '黑点',
          value: c.blackPoint ?? 0,
          min: -100,
          max: 100,
          onChanged: (v) => onChanged(postProcess.copyWith(
            color: c.copyWith(blackPoint: v),
          )),
        ),
        _SliderRow(
          label: '自然饱和度',
          value: c.vibrance ?? 0,
          min: -100,
          max: 100,
          onChanged: (v) => onChanged(postProcess.copyWith(
            color: c.copyWith(vibrance: v),
          )),
        ),
        _SliderRow(
          label: '明亮度',
          value: c.brilliance ?? 0,
          min: -100,
          max: 100,
          onChanged: (v) => onChanged(postProcess.copyWith(
            color: c.copyWith(brilliance: v),
          )),
        ),
      ],
    );
  }
}

// === Detail Tab ===
class _DetailTab extends StatelessWidget {
  final PostProcess postProcess;
  final ValueChanged<PostProcess> onChanged;

  const _DetailTab({required this.postProcess, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = postProcess.color;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      children: [
        _SliderRow(
          label: '清晰度',
          value: c.clarity ?? 0,
          min: -100,
          max: 100,
          onChanged: (v) => onChanged(postProcess.copyWith(
            color: c.copyWith(clarity: v),
          )),
        ),
        _SliderRow(
          label: '锐化',
          value: postProcess.sharpen.toDouble(),
          min: 0,
          max: 100,
          hint: '导出后生效',
          onChanged: (v) =>
              onChanged(postProcess.copyWith(sharpen: v.round())),
        ),
        _SliderRow(
          label: '磨皮',
          value: postProcess.smoothStrength.toDouble(),
          min: 0,
          max: 100,
          hint: '导出后生效',
          onChanged: (v) =>
              onChanged(postProcess.copyWith(smoothStrength: v.round())),
        ),
        _SliderRow(
          label: '晕影',
          value: postProcess.vignette.toDouble(),
          min: 0,
          max: 100,
          onChanged: (v) =>
              onChanged(postProcess.copyWith(vignette: v.round())),
        ),
        _SliderRow(
          label: '颗粒',
          value: postProcess.grain.toDouble(),
          min: 0,
          max: 100,
          onChanged: (v) => onChanged(postProcess.copyWith(grain: v.round())),
        ),
      ],
    );
  }
}

// === Filter Tab ===
const _systemFilterLabels = <String, String>{
  'none': '原图',
  'vivid': '鲜艳',
  'vivid_warm': '暖艳',
  'vivid_cool': '冷艳',
  'mono': '黑白',
  'silver': '银盐',
  'noir': '黑色电影',
};

const _lutLabels = <String, String>{
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
  'cyberpunk': '赛博朋克',
  'sepia_classic': '棕褐',
  'mist': '薄雾',
  'rouge': '胭脂',
  'twilight': '暮光',
  'cyan': '青调',
};

class _FilterTab extends StatelessWidget {
  final PostProcess postProcess;
  final ValueChanged<PostProcess> onChanged;

  /// 预览图路径。为空时降级为文字 Chip。
  final String? previewImagePath;

  /// 主题色板
  final ThemeTokens tokens;

  const _FilterTab({
    required this.postProcess,
    required this.onChanged,
    required this.previewImagePath,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final systemFilters = [
      'none',
      'vivid',
      'vivid_warm',
      'vivid_cool',
      'mono',
      'silver',
      'noir',
    ];
    final luts = [
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

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          '系统滤镜',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: systemFilters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final name = systemFilters[i];
              final selected = postProcess.systemFilter == name;
              return _FilterThumbnail(
                label: _systemFilterLabels[name] ?? name,
                selected: selected,
                tokens: tokens,
                matrix: composeSystemFilterMatrix(name),
                previewImagePath: previewImagePath,
                onTap: () => onChanged(postProcess.copyWith(
                  systemFilter: name == 'none' ? null : name,
                )),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'LUT 预设',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: luts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final name = luts[i];
              final selected = postProcess.lut == name;
              return _FilterThumbnail(
                label: _lutLabels[name] ?? name,
                selected: selected,
                tokens: tokens,
                matrix: composeLutMatrix(name),
                previewImagePath: previewImagePath,
                onTap: () => onChanged(postProcess.copyWith(lut: name)),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 滤镜缩略图卡片：64x80 预览图 + 滤镜名 + 选中边框
class _FilterThumbnail extends StatelessWidget {
  final String label;
  final bool selected;
  final ThemeTokens tokens;
  final List<double> matrix;
  final String? previewImagePath;
  final VoidCallback onTap;

  const _FilterThumbnail({
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
        width: 64,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 80,
              decoration: BoxDecoration(
                border: Border.all(
                  color: selected ? tokens.brand : tokens.divider,
                  width: selected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: hasImage
                    ? ColorFiltered(
                        colorFilter: ColorFilter.matrix(matrix),
                        child: previewImagePath!.startsWith('http')
                            ? Image.network(previewImagePath!,
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
class _CropTab extends StatelessWidget {
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

  const _CropTab({
    required this.transform,
    required this.onChanged,
    required this.postProcess,
    required this.onPostProcessChanged,
    required this.tokens,
    required this.previewImagePath,
  });

  /// 将裁剪比例字符串解析为数值宽高比（width/height）
  /// 返回 null 表示自由裁剪（不锁定比例）
  double? _parseCropAspectRatio(String ratio, bool isPortrait) {
    if (ratio == 'free' || ratio == 'none' || ratio == 'fullscreen') {
      return null;
    }
    if (ratio == '4:3') return isPortrait ? 3.0 / 4.0 : 4.0 / 3.0;
    if (ratio == '1:1') return 1.0;
    final parts = ratio.split(':');
    if (parts.length == 2) {
      final w = double.tryParse(parts[0]);
      final h = double.tryParse(parts[1]);
      if (w != null && h != null && w > 0 && h > 0) return w / h;
    }
    return null;
  }

  /// 裁剪比例选择器：自由 / 1:1 / 4:3 / 3:4 / 16:9 / 全屏
  Widget _buildRatioSelector() {
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
              return GestureDetector(
                onTap: () {
                  // 切换比例时重置自定义裁剪框（null = 使用默认居中）
                  onPostProcessChanged(postProcess.copyWith(
                    cropRatio: ratio,
                    customCropRect: null,
                  ));
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? tokens.brand : tokens.surfaceAlt,
                    borderRadius: BorderRadius.circular(1000),
                    border: Border.all(
                        color: selected ? tokens.brand : tokens.divider,
                        width: 1),
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        color: selected
                            ? tokens.textInverse
                            : tokens.textPrimary,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
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
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.of(context).size.height >= MediaQuery.of(context).size.width;
    final cropAspect = _parseCropAspectRatio(postProcess.cropRatio, isPortrait);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      children: [
        _buildRatioSelector(),
        // 裁剪框预览区
        _CropPreview(
          imagePath: previewImagePath,
          cropRect: postProcess.customCropRect,
          aspectRatio: cropAspect,
          tokens: tokens,
          onCropChanged: (rect) {
            onPostProcessChanged(postProcess.copyWith(
              customCropRect: CropRect(
                x: rect.left,
                y: rect.top,
                w: rect.width,
                h: rect.height,
              ),
            ));
          },
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '旋转',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
            Row(
              children: [
                LumiraIconButton(
                  icon: Icons.rotate_left,
                  onPressed: () => onChanged(transform.copyWith(
                    rotation: (transform.rotation - 90) % 360,
                  )),
                  color: Colors.white70,
                  size: 18,
                ),
                LumiraIconButton(
                  icon: Icons.rotate_right,
                  onPressed: () => onChanged(transform.copyWith(
                    rotation: (transform.rotation + 90) % 360,
                  )),
                  color: Colors.white70,
                  size: 18,
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${transform.rotation}°',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white54),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '翻转',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
            Row(
              children: [
                _CustomChip(
                  label: '水平',
                  selected: transform.flipH,
                  onTap: () =>
                      onChanged(transform.copyWith(flipH: !transform.flipH)),
                ),
                const SizedBox(width: 6),
                _CustomChip(
                  label: '垂直',
                  selected: transform.flipV,
                  onTap: () =>
                      onChanged(transform.copyWith(flipV: !transform.flipV)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        _SliderRow(
          label: '拉直',
          value: transform.straighten,
          min: -15,
          max: 15,
          onChanged: (v) => onChanged(transform.copyWith(straighten: v)),
        ),
      ],
    );
  }
}

/// 裁剪框预览区
///
/// 加载图片获取宽高比，按比例显示图片 + 可拖拽裁剪框叠加层。
/// 使用 ImageStream 监听图片加载完成，获取 intrinsic 尺寸。
class _CropPreview extends StatefulWidget {
  /// 图片路径（文件路径或 URL）
  final String? imagePath;

  /// 当前裁剪框（相对坐标），null = 使用默认居中
  final CropRect? cropRect;

  /// 锁定宽高比（null = 自由）
  final double? aspectRatio;

  /// 主题色板
  final ThemeTokens tokens;

  /// 裁剪框变化回调
  final ValueChanged<Rect> onCropChanged;

  const _CropPreview({
    required this.imagePath,
    required this.cropRect,
    required this.aspectRatio,
    required this.tokens,
    required this.onCropChanged,
  });

  @override
  State<_CropPreview> createState() => _CropPreviewState();
}

class _CropPreviewState extends State<_CropPreview> {
  /// 图片宽高比（width / height），加载前为 null
  double? _imageAspect;

  /// 图片流和监听器（用于 dispose 时移除）
  ImageStream? _imageStream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(_CropPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imagePath != oldWidget.imagePath) {
      _loadImage();
    }
  }

  @override
  void dispose() {
    _imageStream?.removeListener(_listener!);
    super.dispose();
  }

  /// 加载图片获取宽高比
  void _loadImage() {
    if (widget.imagePath == null || widget.imagePath!.isEmpty) {
      if (mounted) setState(() => _imageAspect = null);
      return;
    }
    // 移除旧监听
    _imageStream?.removeListener(_listener!);
    // 分别处理网络图片和本地文件，避免泛型类型推断问题
    if (widget.imagePath!.startsWith('http')) {
      _imageStream =
          NetworkImage(widget.imagePath!).resolve(const ImageConfiguration());
    } else {
      _imageStream =
          FileImage(File(widget.imagePath!)).resolve(const ImageConfiguration());
    }
    _listener = ImageStreamListener((info, _) {
      if (mounted) {
        setState(() {
          _imageAspect = info.image.width / info.image.height;
        });
      }
    });
    _imageStream!.addListener(_listener!);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imagePath == null || widget.imagePath!.isEmpty) {
      return _buildPlaceholder('无图片');
    }
    if (_imageAspect == null) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // 在可用空间内按图片宽高比计算显示尺寸（最大高度 200）
        const maxH = 200.0;
        final maxW = constraints.maxWidth;
        final ratio = _imageAspect!;
        double w, h;
        if (maxW / maxH > ratio) {
          // 受高度约束
          h = maxH;
          w = h * ratio;
        } else {
          // 受宽度约束
          w = maxW;
          h = w / ratio;
        }
        return Center(
          child: SizedBox(
            width: w,
            height: h,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 图片（BoxFit.fill 填满整个区域，与裁剪框坐标对齐）
                  widget.imagePath!.startsWith('http')
                      ? Image.network(widget.imagePath!,
                          fit: BoxFit.fill,
                          errorBuilder: (_, __, ___) => _buildErrorWidget())
                      : Image.file(File(widget.imagePath!),
                          fit: BoxFit.fill,
                          errorBuilder: (_, __, ___) => _buildErrorWidget()),
                  // 裁剪框叠加层
                  CropOverlay(
                    initialRect: widget.cropRect != null
                        ? Rect.fromLTWH(
                            widget.cropRect!.x,
                            widget.cropRect!.y,
                            widget.cropRect!.w,
                            widget.cropRect!.h,
                          )
                        : null,
                    aspectRatio: widget.aspectRatio,
                    onChanged: widget.onCropChanged,
                    tokens: widget.tokens,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder(String text) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Text(text,
            style: const TextStyle(fontSize: 12, color: Colors.white38)),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: const Color(0xFF2A2724),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.broken_image_outlined, size: 32, color: Colors.white38),
            SizedBox(height: 8),
            Text('图片加载失败',
                style: TextStyle(fontSize: 12, color: Colors.white38)),
          ],
        ),
      ),
    );
  }
}

// === 自定义滑块 ===
/// 细线轨道（3px）+ 圆形把手（16px，命中区域 24x24）+ 品牌色填充
/// 用 LayoutBuilder + Stack 实现，支持拖拽（onPanStart + onPanUpdate）
///
/// 修复要点：使用绝对位置（details.localPosition.dx）而非增量（delta.dx），
/// 避免多次 pan 事件共用过时 t 导致拖拽不灵敏；移除重复的轨道 GestureDetector。
class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  /// 可选提示文字（如"导出后生效"），显示在滑块下方。
  final String? hint;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final slider = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 标签宽 64 + 数值宽 32，剩余为轨道宽度
          const labelWidth = 64.0;
          const valueWidth = 32.0;
          final trackWidth =
              (constraints.maxWidth - labelWidth - valueWidth).clamp(0.0, double.infinity);
          final t = ((value - min) / (max - min)).clamp(0.0, 1.0);
          final thumbX = labelWidth + (trackWidth * t);

          // 整体高度 32，把手 16px，垂直居中
          const rowHeight = 32.0;
          const thumbSize = 16.0;
          const trackHeight = 3.0;
          const trackTop = (rowHeight - trackHeight) / 2;

          // 绝对位置计算：将 localPosition.dx（相对 Stack 左上角）映射到轨道比例
          void updateFromLocal(double localDx) {
            if (trackWidth <= 0) return;
            final localX = localDx - labelWidth;
            final newT = (localX / trackWidth).clamp(0.0, 1.0);
            onChanged(min + newT * (max - min));
          }

          return SizedBox(
            height: rowHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) =>
                  updateFromLocal(details.localPosition.dx),
              onPanUpdate: (details) =>
                  updateFromLocal(details.localPosition.dx),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 标签
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: labelWidth,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        label,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white70),
                      ),
                    ),
                  ),
                  // 轨道背景
                  Positioned(
                    left: labelWidth,
                    right: valueWidth,
                    top: trackTop,
                    height: trackHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // 已填充部分
                  Positioned(
                    left: labelWidth,
                    top: trackTop,
                    width: (trackWidth * t).clamp(0.0, trackWidth),
                    height: trackHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5C07B),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // 把手（纯视觉，手势由外层 GestureDetector 统一处理）
                  Positioned(
                    left: thumbX - thumbSize / 2,
                    top: (rowHeight - thumbSize) / 2,
                    child: Container(
                      width: thumbSize,
                      height: thumbSize,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x44000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 数值
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: valueWidth,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        value.toStringAsFixed(0),
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white54),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (hint == null) return slider;
    // 有 hint 时在滑块下方显示提示文字
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        slider,
        Padding(
          padding: const EdgeInsets.only(left: 64, bottom: 2),
          child: Text(
            hint!,
            style: const TextStyle(fontSize: 9, color: Colors.white38),
          ),
        ),
      ],
    );
  }
}

// === 自定义 Chip ===
/// 圆角矩形（borderRadius 8）
/// 选中：品牌色背景 + 黑字
/// 未选中：半透明白色背景 + 白字
class _CustomChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CustomChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFE5C07B)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: selected ? Colors.black : Colors.white70,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
