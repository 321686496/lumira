import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/capture_state.dart';
import '../domain/photo_template.dart';

/// 底部抽屉式参数编辑面板。
/// 5 个 Tab：相机 / 色彩 / 细节 / 构图 / 场景。
/// 通过 panelExpandedProvider 控制展开/收起（AnimatedPositioned）。
///
/// UI 美化：深色背景 + 金色强调色、卡片式分组、自定义滑块外观、
/// 可滚动标签条、统一间距系统。
class ParamPanel extends ConsumerWidget {
  const ParamPanel({super.key});

  void _close(WidgetRef ref) {
    ref.read(CaptureState.panelExpandedProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(CaptureState.panelExpandedProvider);
    final editable = ref.watch(CaptureState.editableTemplateProvider);
    final original = ref.watch(CaptureState.originalTemplateProvider);

    return Stack(
      children: [
        if (expanded)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _close(ref),
              child: Container(color: Colors.black54),
            ),
          ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          left: 0,
          right: 0,
          bottom: expanded ? 0 : -520,
          height: 520,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1C),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 20,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: DefaultTabController(
                length: 5,
                child: Column(
                  children: [
                    _PanelHeader(
                      hasTemplate: editable != null,
                      onClose: () => _close(ref),
                    ),
                    _TabBarSection(
                      tabs: const ['相机', '色彩', '细节', '构图', '场景'],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _CameraTab(),
                          _ColorTab(),
                          _DetailTab(),
                          _CompositionTab(),
                          _SceneTab(),
                        ],
                      ),
                    ),
                    _PanelFooter(
                      hasTemplate: editable != null && original != null,
                      isModified: editable != null &&
                          original != null &&
                          editable != original,
                      onReset: () {
                        if (original != null) {
                          ref
                              .read(CaptureState.editableTemplateProvider.notifier)
                              .state = original.copyWith();
                        }
                      },
                      onDone: () => _close(ref),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 面板头部
// ─────────────────────────────────────────────────────────────────────
class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.hasTemplate, required this.onClose});

  final bool hasTemplate;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
      child: Column(
        children: [
          // 拖动条
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标题行
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFC9A96E).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.tune,
                  color: Color(0xFFC9A96E),
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                '参数调整',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasTemplate
                      ? const Color(0xFFC9A96E).withOpacity(0.15)
                      : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  hasTemplate ? '模板' : '自由',
                  style: TextStyle(
                    color: hasTemplate
                        ? const Color(0xFFC9A96E)
                        : Colors.white60,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              _CircleIconButton(
                icon: Icons.close,
                onTap: onClose,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white70, size: 16),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// TabBar
// ─────────────────────────────────────────────────────────────────────
class _TabBarSection extends StatelessWidget {
  const _TabBarSection({required this.tabs});
  final List<String> tabs;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.06),
            width: 0.5,
          ),
        ),
      ),
      child: TabBar(
        tabs: tabs.map((t) => Tab(text: t)).toList(),
        labelColor: const Color(0xFFC9A96E),
        unselectedLabelColor: Colors.white38,
        indicatorColor: const Color(0xFFC9A96E),
        indicatorSize: TabBarIndicatorSize.label,
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 面板底部
// ─────────────────────────────────────────────────────────────────────
class _PanelFooter extends StatelessWidget {
  const _PanelFooter({
    required this.hasTemplate,
    required this.isModified,
    required this.onReset,
    required this.onDone,
  });

  final bool hasTemplate;
  final bool isModified;
  final VoidCallback onReset;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.06),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          if (hasTemplate && isModified)
            GestureDetector(
              onTap: onReset,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.refresh, size: 14, color: Colors.white70),
                    SizedBox(width: 4),
                    Text('重置', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            )
          else
            const Spacer(),
          const Spacer(),
          GestureDetector(
            onTap: onDone,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 100,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFC9A96E), Color(0xFFB8954E)],
                ),
                borderRadius: BorderRadius.circular(19),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC9A96E).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  '完成',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 相机 Tab
// ─────────────────────────────────────────────────────────────────────
class _CameraTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cam = ref.watch(CaptureState.effectiveCameraProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      children: [
        _SectionCard(
          title: '曝光',
          children: [
            _SliderRow(
              label: 'EV',
              value: cam.exposureCompensation,
              min: -3.0,
              max: 3.0,
              divisions: 60,
              display:
                  '${cam.exposureCompensation >= 0 ? '+' : ''}${cam.exposureCompensation.toStringAsFixed(1)}',
              onChanged: (v) => CaptureState.updateCamera(
                  ref, (c) => c.copyWith(exposureCompensation: v)),
            ),
            _SliderRow(
              label: 'ISO',
              value: cam.iso.toDouble(),
              min: 100,
              max: 6400,
              divisions: 63,
              display: cam.iso == 0 ? 'Auto' : cam.iso.toString(),
              onChanged: (v) => CaptureState.updateCamera(
                  ref, (c) => c.copyWith(iso: v.round())),
            ),
            _PopupRow(
              label: '快门',
              value: cam.shutterSpeed,
              items: const [
                'auto',
                '1/30',
                '1/60',
                '1/125',
                '1/200',
                '1/500',
                '1/1000'
              ],
              onChanged: (v) => CaptureState.updateCamera(
                  ref, (c) => c.copyWith(shutterSpeed: v)),
            ),
          ],
        ),
        _SectionCard(
          title: '白平衡',
          children: [
            _PopupRow(
              label: '预设',
              value: cam.whiteBalance,
              items: const [
                'auto',
                'daylight',
                'cloudy',
                'shade',
                'tungsten',
                'fluorescent',
                'custom'
              ],
              displayLabels: const {
                'auto': '自动',
                'daylight': '日光',
                'cloudy': '阴天',
                'shade': '阴影',
                'tungsten': '白炽灯',
                'fluorescent': '荧光',
                'custom': '自定义',
              },
              onChanged: (v) => CaptureState.updateCamera(
                  ref, (c) => c.copyWith(whiteBalance: v)),
            ),
          ],
        ),
        _SectionCard(
          title: '其他',
          children: [
            _PopupRow(
              label: '闪光',
              value: cam.flashMode,
              items: const ['off', 'on', 'auto', 'torch'],
              displayLabels: const {
                'off': '关闭',
                'on': '常亮',
                'auto': '自动',
                'torch': '手电筒',
              },
              onChanged: (v) => CaptureState.updateCamera(
                  ref, (c) => c.copyWith(flashMode: v)),
            ),
            _PopupRow(
              label: '对焦',
              value: cam.focusMode,
              items: const ['auto', 'manual', 'continuous'],
              displayLabels: const {
                'auto': '自动对焦',
                'manual': '手动对焦',
                'continuous': '连续对焦',
              },
              onChanged: (v) => CaptureState.updateCamera(
                  ref, (c) => c.copyWith(focusMode: v)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 提示：ISO/快门/白平衡为推荐值
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white24, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'EV 可实时影响取景器亮度；ISO/快门/白平衡为推荐参考值',
                  style: TextStyle(color: Colors.white24, fontSize: 10, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 色彩 Tab
// ─────────────────────────────────────────────────────────────────────
class _ColorTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = ref.watch(CaptureState.effectivePostProcessProvider).color;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      children: [
        _SectionCard(
          title: '基础调整',
          children: [
            _SliderRow(
              label: '亮度',
              value: color.brightness,
              min: -100,
              max: 100,
              divisions: 200,
              display: color.brightness.toStringAsFixed(0),
              onChanged: (v) => _setColor(ref, (c) => c.copyWith(brightness: v)),
            ),
            _SliderRow(
              label: '对比度',
              value: color.contrast,
              min: -100,
              max: 100,
              divisions: 200,
              display: color.contrast.toStringAsFixed(0),
              onChanged: (v) => _setColor(ref, (c) => c.copyWith(contrast: v)),
            ),
            _SliderRow(
              label: '饱和度',
              value: color.saturation,
              min: -100,
              max: 100,
              divisions: 200,
              display: color.saturation.toStringAsFixed(0),
              onChanged: (v) => _setColor(ref, (c) => c.copyWith(saturation: v)),
            ),
            _SliderRow(
              label: '色温',
              value: color.temperature,
              min: -100,
              max: 100,
              divisions: 200,
              display: color.temperature.toStringAsFixed(0),
              onChanged: (v) => _setColor(ref, (c) => c.copyWith(temperature: v)),
            ),
            _SliderRow(
              label: '色调',
              value: color.tint,
              min: -100,
              max: 100,
              divisions: 200,
              display: color.tint.toStringAsFixed(0),
              onChanged: (v) => _setColor(ref, (c) => c.copyWith(tint: v)),
            ),
          ],
        ),
        _SectionCard(
          title: '局部调整',
          children: [
            _SliderRow(
              label: '高光',
              value: color.highlights ?? 0,
              min: -100,
              max: 100,
              divisions: 200,
              display: (color.highlights ?? 0).toStringAsFixed(0),
              onChanged: (v) => _setColor(ref, (c) => c.copyWith(highlights: v)),
            ),
            _SliderRow(
              label: '阴影',
              value: color.shadows ?? 0,
              min: -100,
              max: 100,
              divisions: 200,
              display: (color.shadows ?? 0).toStringAsFixed(0),
              onChanged: (v) => _setColor(ref, (c) => c.copyWith(shadows: v)),
            ),
            _SliderRow(
              label: '黑点',
              value: color.blackPoint ?? 0,
              min: -100,
              max: 100,
              divisions: 200,
              display: (color.blackPoint ?? 0).toStringAsFixed(0),
              onChanged: (v) => _setColor(ref, (c) => c.copyWith(blackPoint: v)),
            ),
            _SliderRow(
              label: '鲜明度',
              value: color.vibrance ?? 0,
              min: -100,
              max: 100,
              divisions: 200,
              display: (color.vibrance ?? 0).toStringAsFixed(0),
              onChanged: (v) => _setColor(ref, (c) => c.copyWith(vibrance: v)),
            ),
            _SliderRow(
              label: '明度',
              value: color.brilliance ?? 0,
              min: -100,
              max: 100,
              divisions: 200,
              display: (color.brilliance ?? 0).toStringAsFixed(0),
              onChanged: (v) => _setColor(ref, (c) => c.copyWith(brilliance: v)),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  static void _setColor(
      WidgetRef ref, PostProcessColor Function(PostProcessColor) updater) {
    CaptureState.updatePostProcess(ref, (p) {
      final newColor = updater(p.color);
      return p.copyWith(color: newColor);
    });
  }
}

// ─────────────────────────────────────────────────────────────────────
// 细节 Tab
// ─────────────────────────────────────────────────────────────────────
class _DetailTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = ref.watch(CaptureState.effectivePostProcessProvider);
    final color = post.color;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      children: [
        _SectionCard(
          title: '画质',
          children: [
            _SliderRow(
              label: '清晰度',
              value: color.clarity ?? 0,
              min: -100,
              max: 100,
              divisions: 200,
              display: (color.clarity ?? 0).toStringAsFixed(0),
              onChanged: (v) => CaptureState.updatePostProcess(
                  ref, (p) => p.copyWith(color: p.color.copyWith(clarity: v))),
            ),
            _SliderRow(
              label: '锐化',
              value: post.sharpen.toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              display: post.sharpen.toString(),
              onChanged: (v) => CaptureState.updatePostProcess(
                  ref, (p) => p.copyWith(sharpen: v.round())),
            ),
            _SliderRow(
              label: '磨皮',
              value: post.smoothStrength.toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              display: post.smoothStrength.toString(),
              onChanged: (v) => CaptureState.updatePostProcess(
                  ref, (p) => p.copyWith(smoothStrength: v.round())),
            ),
          ],
        ),
        _SectionCard(
          title: '特效',
          children: [
            _SliderRow(
              label: '暗角',
              value: post.vignette.toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              display: post.vignette.toString(),
              onChanged: (v) => CaptureState.updatePostProcess(
                  ref, (p) => p.copyWith(vignette: v.round())),
            ),
            _SliderRow(
              label: '颗粒',
              value: post.grain.toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              display: post.grain.toString(),
              onChanged: (v) => CaptureState.updatePostProcess(
                  ref, (p) => p.copyWith(grain: v.round())),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 构图 Tab
// ─────────────────────────────────────────────────────────────────────
class _CompositionTab extends ConsumerWidget {
  static const _overlayTypes = {
    'rule_of_thirds': '三分法',
    'golden_ratio': '黄金比例',
    'center': '居中',
    'diagonal': '对角线',
    'symmetry': '对称',
    'none': '无',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comp = ref.watch(CaptureState.effectiveCompositionProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      children: [
        _SectionCard(
          title: '构图辅助线',
          children: [
            _PopupRow(
              label: '类型',
              value: comp.overlayType,
              items: _overlayTypes.keys.toList(),
              displayLabels: _overlayTypes,
              onChanged: (v) => CaptureState.updateComposition(
                  ref, (c) => c.copyWith(overlayType: v)),
            ),
            _SliderRow(
              label: '透明度',
              value: comp.opacity,
              min: 0,
              max: 1,
              divisions: 100,
              display: '${(comp.opacity * 100).round()}%',
              onChanged: (v) => CaptureState.updateComposition(
                  ref, (c) => c.copyWith(opacity: v)),
            ),
          ],
        ),
        if (comp.description.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFC9A96E).withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFC9A96E).withOpacity(0.12),
                width: 0.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline,
                    color: Color(0xFFC9A96E), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    comp.description,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 场景 Tab
// ─────────────────────────────────────────────────────────────────────
class _SceneTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = ref.watch(CaptureState.effectiveSceneGuideProvider);

    final rows = <MapEntry<String, String>>[
      MapEntry('光线方向', sg.lightDirection),
      MapEntry('拍摄距离', sg.shootingDistance),
      MapEntry('背景建议', sg.background),
      MapEntry('最佳时段', sg.bestTime),
      if (sg.bestTimeFrom != null && sg.bestTimeTo != null)
        MapEntry('时段范围', '${sg.bestTimeFrom} - ${sg.bestTimeTo}'),
      if (sg.presetId != null) MapEntry('场景预设', sg.presetId!),
      if (sg.props.isNotEmpty) MapEntry('推荐道具', sg.props.join('、')),
      if (sg.tips.isNotEmpty) MapEntry('拍摄贴士', sg.tips.join('\n• ')),
    ];

    if (rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, color: Colors.white24, size: 48),
            const SizedBox(height: 12),
            const Text(
              '当前为自由模式，无场景指南',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              '选择场景预设或套用模板后可查看场景指南',
              style: TextStyle(color: Colors.white24, fontSize: 11),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      children: [
        for (final row in rows)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 72,
                  child: Text(
                    row.key,
                    style: const TextStyle(
                      color: Color(0xFFC9A96E),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    row.value.isEmpty ? '—' : row.value,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────

/// 卡片式分区分组容器
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 11,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC9A96E),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// 滑块行 — label + slider + value
class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6), fontSize: 12)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: const Color(0xFFC9A96E),
                inactiveTrackColor: Colors.white.withOpacity(0.1),
                thumbColor: Colors.white,
                overlayColor: const Color(0xFFC9A96E).withOpacity(0.2),
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 12),
                trackHeight: 3,
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                label: display,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              display,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontFamily: 'SF Mono'),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

/// 弹出菜单行 — label + popup button
class _PopupRow extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final Map<String, String>? displayLabels;
  final ValueChanged<String> onChanged;
  const _PopupRow({
    required this.label,
    required this.value,
    required this.items,
    this.displayLabels,
    required this.onChanged,
  });

  String _display(String v) => displayLabels?[v] ?? v;

  @override
  Widget build(BuildContext context) {
    final hasValue = items.contains(value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6), fontSize: 12)),
          ),
          Expanded(
            child: PopupMenuButton<String>(
              tooltip: '选择$label',
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              color: const Color(0xFF2A2A2C),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.08), width: 0.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasValue ? _display(value) : '请选择',
                        style: TextStyle(
                          color: hasValue ? Colors.white : Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_drop_down,
                        color: Colors.white38, size: 16),
                  ],
                ),
              ),
              itemBuilder: (ctx) => items
                  .map((v) => PopupMenuItem<String>(
                        value: v,
                        child: Row(
                          children: [
                            if (v == value)
                              const Icon(Icons.check,
                                  color: Color(0xFFC9A96E), size: 14)
                            else
                              const SizedBox(width: 14),
                            const SizedBox(width: 6),
                            Text(_display(v),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      ))
                  .toList(),
              onSelected: (v) => onChanged(v),
            ),
          ),
        ],
      ),
    );
  }
}
