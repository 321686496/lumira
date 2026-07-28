import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/photo_template.dart';

/// 预览页编辑面板（4 标签底部抽屉）
/// 替代原 _AdjustSection（仅 3 滑块）
class PreviewEditPanel extends ConsumerStatefulWidget {
  final PostProcess postProcess;
  final TransformParams transform;
  final ValueChanged<PostProcess> onPostProcessChanged;
  final ValueChanged<TransformParams> onTransformChanged;

  const PreviewEditPanel({
    super.key,
    required this.postProcess,
    required this.transform,
    required this.onPostProcessChanged,
    required this.onTransformChanged,
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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updatePost(PostProcess p) => widget.onPostProcessChanged(p);
  void _updateTransform(TransformParams t) => widget.onTransformChanged(t);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 360,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ColorTab(
                  postProcess: widget.postProcess,
                  onChanged: _updatePost,
                ),
                _DetailTab(
                  postProcess: widget.postProcess,
                  onChanged: _updatePost,
                ),
                _FilterTab(
                  postProcess: widget.postProcess,
                  onChanged: _updatePost,
                ),
                _CropTab(
                  transform: widget.transform,
                  onChanged: _updateTransform,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('编辑',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          TextButton(
            onPressed: () {
              // Reset current tab
              switch (_tabController.index) {
                case 0:
                  _updatePost(const PostProcess(color: PostProcessColor()));
                  break;
                case 1:
                  _updatePost(widget.postProcess.copyWith(
                    smoothStrength: 0,
                    sharpen: 0,
                    vignette: 0,
                    grain: 0,
                  ));
                  break;
                case 3:
                  _updateTransform(const TransformParams());
                  break;
              }
            },
            child: const Text('重置'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      tabs: const [
        Tab(text: '色彩'),
        Tab(text: '细节'),
        Tab(text: '滤镜'),
        Tab(text: '裁剪旋转'),
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
        ]);
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
            onChanged: (v) =>
                onChanged(postProcess.copyWith(sharpen: v.round())),
          ),
          _SliderRow(
            label: '磨皮',
            value: postProcess.smoothStrength.toDouble(),
            min: 0,
            max: 100,
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
        ]);
  }
}

// === Filter Tab ===
class _FilterTab extends ConsumerWidget {
  final PostProcess postProcess;
  final ValueChanged<PostProcess> onChanged;

  const _FilterTab({required this.postProcess, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('系统滤镜', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          'none',
          'vivid',
          'vivid_warm',
          'vivid_cool',
          'mono',
          'silver',
          'noir'
        ].map((name) {
          final selected = postProcess.systemFilter == name;
          return ChoiceChip(
            label: Text(name),
            selected: selected,
            onSelected: (_) => onChanged(postProcess.copyWith(
              systemFilter: name == 'none' ? null : name,
            )),
          );
        }).toList(),
      ),
      const SizedBox(height: 16),
      const Text('LUT 预设', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
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
          'cyan'
        ].map((name) {
          final selected = postProcess.lut == name;
          return ChoiceChip(
            label: Text(name),
            selected: selected,
            onSelected: (_) => onChanged(postProcess.copyWith(lut: name)),
          );
        }).toList(),
      ),
    ]);
  }
}

// === Crop Tab ===
class _CropTab extends StatelessWidget {
  final TransformParams transform;
  final ValueChanged<TransformParams> onChanged;

  const _CropTab({required this.transform, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('旋转'),
              Row(children: [
                IconButton(
                  icon: const Icon(Icons.rotate_left),
                  onPressed: () => onChanged(transform.copyWith(
                    rotation: (transform.rotation - 90) % 360,
                  )),
                ),
                IconButton(
                  icon: const Icon(Icons.rotate_right),
                  onPressed: () => onChanged(transform.copyWith(
                    rotation: (transform.rotation + 90) % 360,
                  )),
                ),
                SizedBox(
                    width: 60,
                    child: Text('${transform.rotation}°',
                        textAlign: TextAlign.center)),
              ]),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('翻转'),
              Row(children: [
                FilterChip(
                  label: const Text('水平'),
                  selected: transform.flipH,
                  onSelected: (_) =>
                      onChanged(transform.copyWith(flipH: !transform.flipH)),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('垂直'),
                  selected: transform.flipV,
                  onSelected: (_) =>
                      onChanged(transform.copyWith(flipV: !transform.flipV)),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('拉直'),
              Text(': ${transform.straighten.toStringAsFixed(1)}°'),
            ],
          ),
          Slider(
            value: transform.straighten,
            min: -15,
            max: 15,
            divisions: 60,
            onChanged: (v) => onChanged(transform.copyWith(straighten: v)),
          ),
        ]);
  }
}

// === Shared Slider Row ===
class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(label)),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: ((max - min).round()),
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(value.toStringAsFixed(0), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
