import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/capture_state.dart';
import '../domain/photo_template.dart';

/// 底部抽屉式参数编辑面板。
/// 5 个 Tab：相机 / 色彩 / 细节 / 构图 / 场景。
/// 通过 panelExpandedProvider 控制展开/收起（AnimatedPositioned）。
///
/// 设计要点：
/// - 自由拍摄模式（无模板）下也能调整所有参数，通过 CaptureState.update* 辅助方法
///   自动路由到 freeMode*Provider 或 editableTemplateProvider
/// - 拖动条可点击关闭，右上角有关闭按钮
/// - 点击面板外部区域可关闭
/// - 所有 Dropdown 用 PopupMenu 实现，避免 DropdownButton 触发 PopupRoute 路由变化
///   （已被 route_observers 修复，但 PopupMenu 更轻量）
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
        // 点击外部关闭（仅展开时显示）
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
          curve: Curves.easeInOut,
          left: 0,
          right: 0,
          bottom: expanded ? 0 : -480,
          height: 480,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C1E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // 头部：拖动条 + 标题 + 关闭按钮
                _PanelHeader(
                  hasTemplate: editable != null,
                  onClose: () => _close(ref),
                ),
                // Tab 切换 + 内容
                Expanded(
                  child: DefaultTabController(
                    length: 5,
                    child: Column(
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.white12,
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: const TabBar(
                            tabs: [
                              Tab(text: '相机'),
                              Tab(text: '色彩'),
                              Tab(text: '细节'),
                              Tab(text: '构图'),
                              Tab(text: '场景'),
                            ],
                            labelColor: Colors.amber,
                            unselectedLabelColor: Colors.white54,
                            indicatorColor: Colors.amber,
                            indicatorSize: TabBarIndicatorSize.label,
                            labelStyle: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            unselectedLabelStyle: TextStyle(fontSize: 13),
                          ),
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
                      ],
                    ),
                  ),
                ),
                // 底部操作栏
                _PanelFooter(
                  hasTemplate: editable != null && original != null,
                  isModified: editable != null && original != null && editable != original,
                  onReset: () {
                    if (original != null) {
                      ref.read(CaptureState.editableTemplateProvider.notifier).state =
                          original.copyWith();
                    }
                  },
                  onDone: () => _close(ref),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 面板头部：拖动条 + 标题 + 关闭按钮
class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.hasTemplate, required this.onClose});

  final bool hasTemplate;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          // 拖动条
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 8, bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white38,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标题行
          Row(
            children: [
              const Icon(Icons.tune, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '参数调整',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // 模式标识
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: hasTemplate
                      ? Colors.amber.withOpacity(0.15)
                      : Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  hasTemplate ? '模板模式' : '自由模式',
                  style: TextStyle(
                    color: hasTemplate ? Colors.amber : Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 关闭按钮
              GestureDetector(
                onTap: onClose,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white70,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 面板底部：重置 + 完成
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white12, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          if (hasTemplate && isModified)
            TextButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.refresh, size: 16, color: Colors.white70),
              label: const Text(
                '重置',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            )
          else
            const Spacer(),
          const Spacer(),
          SizedBox(
            width: 96,
            height: 36,
            child: ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                '完成',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
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
// 相机 Tab：EV / ISO / 快门 / 白平衡 / 闪光 / 对焦
// ─────────────────────────────────────────────────────────────────────
class _CameraTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cam = ref.watch(CaptureState.effectiveCameraProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _SectionHeader(title: '曝光'),
        _SliderRow(
          label: 'EV',
          value: cam.exposureCompensation,
          min: -3.0,
          max: 3.0,
          divisions: 120,
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
          items: const ['auto', '1/30', '1/60', '1/125', '1/200', '1/500', '1/1000'],
          onChanged: (v) => CaptureState.updateCamera(
              ref, (c) => c.copyWith(shutterSpeed: v)),
        ),
        const SizedBox(height: 12),
        _SectionHeader(title: '白平衡'),
        _PopupRow(
          label: '预设',
          value: cam.whiteBalance,
          items: const ['auto', 'daylight', 'cloudy', 'shade', 'tungsten', 'fluorescent', 'custom'],
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
        const SizedBox(height: 12),
        _SectionHeader(title: '其他'),
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
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 色彩 Tab：亮度 / 对比度 / 饱和度 / 色温 / 色调 / 高光 / 阴影 / 黑点 / 鲜明度 / 明度
// ─────────────────────────────────────────────────────────────────────
class _ColorTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = ref.watch(CaptureState.effectivePostProcessProvider).color;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _SectionHeader(title: '基础调整'),
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
        const SizedBox(height: 12),
        _SectionHeader(title: '局部调整'),
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
// 细节 Tab：清晰度 / 锐化 / 磨皮 / 暗角 / 颗粒
// ─────────────────────────────────────────────────────────────────────
class _DetailTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = ref.watch(CaptureState.effectivePostProcessProvider);
    final color = post.color;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _SectionHeader(title: '画质'),
        _SliderRow(
          label: '清晰度',
          value: color.clarity ?? 0,
          min: 0,
          max: 100,
          divisions: 100,
          display: (color.clarity ?? 0).toStringAsFixed(0),
          onChanged: (v) => CaptureState.updatePostProcess(ref,
              (p) => p.copyWith(color: p.color.copyWith(clarity: v))),
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
        const SizedBox(height: 12),
        _SectionHeader(title: '特效'),
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
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 构图 Tab：叠图类型选择器 + 透明度滑块
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _SectionHeader(title: '构图辅助线'),
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
        const SizedBox(height: 12),
        if (comp.description.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    comp.description,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
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
// 场景 Tab：场景指南文本预览（只读）
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        for (final row in rows)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 72,
                  child: Text(
                    row.key,
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    row.value.isEmpty ? '—' : row.value,
                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
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

/// 小节标题
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

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
            width: 56,
            child: Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              label: display,
              activeColor: Colors.amber,
              inactiveColor: Colors.white24,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              display,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

/// 用 PopupMenu 替代 DropdownButton，避免触发 PopupRoute 路由变化
/// （虽然 route_observers 已修复，但 PopupMenu 更轻量、更可控）
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
          Expanded(
            child: PopupMenuButton<String>(
              tooltip: '选择$label',
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12, width: 0.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasValue ? _display(value) : '请选择',
                        style: TextStyle(
                          color: hasValue ? Colors.white : Colors.white38,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down,
                        color: Colors.white54, size: 18),
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
                                  color: Colors.amber, size: 16)
                            else
                              const SizedBox(width: 16),
                            const SizedBox(width: 8),
                            Text(_display(v)),
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
