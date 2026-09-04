import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/theme_tokens.dart';
import '../domain/photo_template.dart';

// =============================================================================
// 调节项定义
// =============================================================================

class AdjustDef {
  final String label;
  final IconData icon;
  final double min;
  final double max;
  final double Function(PostProcess) getValue;
  final PostProcess Function(PostProcess, double) setValue;
  final String? hint;

  const AdjustDef({
    required this.label,
    required this.icon,
    required this.min,
    required this.max,
    required this.getValue,
    required this.setValue,
    this.hint,
  });
}

/// 色彩调节项列表
List<AdjustDef> colorAdjustDefs() => [
      AdjustDef(
        label: '亮度',
        icon: Icons.wb_sunny_outlined,
        min: -100,
        max: 100,
        getValue: (p) => p.color.brightness,
        setValue: (p, v) => p.copyWith(color: p.color.copyWith(brightness: v)),
      ),
      AdjustDef(
        label: '鲜明度',
        icon: Icons.auto_awesome,
        min: -100,
        max: 100,
        getValue: (p) => p.color.brilliance ?? 0,
        setValue: (p, v) => p.copyWith(color: p.color.copyWith(brilliance: v)),
      ),
      AdjustDef(
        label: '高光',
        icon: Icons.wb_incandescent_outlined,
        min: -100,
        max: 100,
        getValue: (p) => p.color.highlights ?? 0,
        setValue: (p, v) => p.copyWith(color: p.color.copyWith(highlights: v)),
      ),
      AdjustDef(
        label: '阴影',
        icon: Icons.nights_stay_outlined,
        min: -100,
        max: 100,
        getValue: (p) => p.color.shadows ?? 0,
        setValue: (p, v) => p.copyWith(color: p.color.copyWith(shadows: v)),
      ),
      AdjustDef(
        label: '对比度',
        icon: Icons.contrast,
        min: -100,
        max: 100,
        getValue: (p) => p.color.contrast,
        setValue: (p, v) => p.copyWith(color: p.color.copyWith(contrast: v)),
      ),
      AdjustDef(
        label: '黑点',
        icon: Icons.circle_outlined,
        min: -100,
        max: 100,
        getValue: (p) => p.color.blackPoint ?? 0,
        setValue: (p, v) => p.copyWith(color: p.color.copyWith(blackPoint: v)),
      ),
      AdjustDef(
        label: '饱和度',
        icon: Icons.palette_outlined,
        min: -100,
        max: 100,
        getValue: (p) => p.color.saturation,
        setValue: (p, v) => p.copyWith(color: p.color.copyWith(saturation: v)),
      ),
      AdjustDef(
        label: '自然饱和度',
        icon: Icons.spa_outlined,
        min: -100,
        max: 100,
        getValue: (p) => p.color.vibrance ?? 0,
        setValue: (p, v) => p.copyWith(color: p.color.copyWith(vibrance: v)),
      ),
      AdjustDef(
        label: '色温',
        icon: Icons.thermostat,
        min: -100,
        max: 100,
        getValue: (p) => p.color.temperature,
        setValue: (p, v) => p.copyWith(color: p.color.copyWith(temperature: v)),
      ),
      AdjustDef(
        label: '色调',
        icon: Icons.filter_vintage,
        min: -100,
        max: 100,
        getValue: (p) => p.color.tint,
        setValue: (p, v) => p.copyWith(color: p.color.copyWith(tint: v)),
      ),
    ];

/// 细节调节项列表
List<AdjustDef> detailAdjustDefs() => [
      AdjustDef(
        label: '清晰度',
        icon: Icons.blur_on,
        min: -100,
        max: 100,
        getValue: (p) => p.color.clarity ?? 0,
        setValue: (p, v) => p.copyWith(color: p.color.copyWith(clarity: v)),
      ),
      AdjustDef(
        label: '锐化',
        icon: Icons.bolt,
        min: 0,
        max: 100,
        getValue: (p) => p.sharpen.toDouble(),
        setValue: (p, v) => p.copyWith(sharpen: v.round()),
      ),
      AdjustDef(
        label: '磨皮',
        icon: Icons.spa_outlined,
        min: 0,
        max: 100,
        getValue: (p) => p.smoothStrength.toDouble(),
        setValue: (p, v) => p.copyWith(smoothStrength: v.round()),
      ),
      AdjustDef(
        label: '晕影',
        icon: Icons.photo_size_select_actual_outlined,
        min: 0,
        max: 100,
        getValue: (p) => p.vignette.toDouble(),
        setValue: (p, v) => p.copyWith(vignette: v.round()),
      ),
      AdjustDef(
        label: '颗粒',
        icon: Icons.grain,
        min: 0,
        max: 100,
        getValue: (p) => p.grain.toDouble(),
        setValue: (p, v) => p.copyWith(grain: v.round()),
      ),
      AdjustDef(
        label: '拉腿',
        icon: Icons.accessibility_new,
        min: 0,
        max: 100,
        hint: '导出后生效',
        getValue: (p) => p.legStretch.toDouble(),
        setValue: (p, v) => p.copyWith(legStretch: v.round()),
      ),
    ];

// =============================================================================
// iPhone 风格两级调节面板
// =============================================================================

/// 顶部横向调节条（圆形图标 + 名称），下方单个滑块
class AdjustPanel extends StatefulWidget {
  final List<AdjustDef> defs;
  final PostProcess full;
  final ValueChanged<PostProcess> onChanged;

  /// 浅色主题色板；null 时使用半透明深色配色（拍摄预览页）
  final ThemeTokens? tokens;

  const AdjustPanel({
    super.key,
    required this.defs,
    required this.full,
    required this.onChanged,
    this.tokens,
  });

  @override
  State<AdjustPanel> createState() => _AdjustPanelState();
}

class _AdjustPanelState extends State<AdjustPanel> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final def = widget.defs[_selected];
    final value = def.getValue(widget.full);
    final t = widget.tokens;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 横向调节条
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.defs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _AdjustStripChip(
                def: widget.defs[i],
                selected: i == _selected,
                tokens: t,
                onTap: () => setState(() => _selected = i),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // 选中项的单个滑块。用 Expanded + SingleChildScrollView 包裹，
          // 即使抽屉高度不足（如展开动画期间）也只会滚动而不会 RenderFlex overflow。
          Expanded(
            child: SingleChildScrollView(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: child,
                ),
                child: _EditSlider(
                  key: ValueKey(def.label),
                  label: def.label,
                  value: value,
                  min: def.min,
                  max: def.max,
                  hint: def.hint,
                  tokens: t,
                  onChanged: (v) =>
                      widget.onChanged(def.setValue(widget.full, v)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 调节条单项（圆形图标 + 下方名称）
// =============================================================================

class _AdjustStripChip extends StatelessWidget {
  final AdjustDef def;
  final bool selected;
  final ThemeTokens? tokens;
  final VoidCallback onTap;

  const _AdjustStripChip({
    required this.def,
    required this.selected,
    required this.tokens,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final bgColor = selected
        ? (t?.brand ?? const Color(0xFFE5C07B))
        : (t?.surfaceAlt ?? Colors.white12);
    final iconColor = selected
        ? (t?.textInverse ?? Colors.black)
        : (t?.textSecondary ?? Colors.white70);
    final labelColor = selected
        ? (t?.brand ?? const Color(0xFFE5C07B))
        : (t?.textSecondary ?? Colors.white70);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 48,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(def.icon, size: 16, color: iconColor),
            ),
            const SizedBox(height: 2),
            Text(
              def.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                color: labelColor,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 单滑块（名称 + 数值 + 轨道 + 可选提示文字）
// =============================================================================

class _EditSlider extends StatefulWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ThemeTokens? tokens;
  final ValueChanged<double> onChanged;
  final String? hint;

  const _EditSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.tokens,
    required this.onChanged,
    this.hint,
  });

  @override
  State<_EditSlider> createState() => _EditSliderState();
}

class _EditSliderState extends State<_EditSlider> {
  double _dragValue = double.nan;

  double get _effectiveValue =>
      _dragValue.isNaN ? widget.value : _dragValue;

  @override
  void didUpdateWidget(_EditSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _dragValue = double.nan;
    }
  }

  String _format(double v) {
    final rounded = v.round();
    return rounded > 0 ? '+$rounded' : '$rounded';
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final v = _effectiveValue;
    final tValue = ((v - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);

    const trackHeight = 4.0;
    const thumbSize = 18.0;
    const trackAreaHeight = 28.0;
    const trackTop = (trackAreaHeight - trackHeight) / 2;

    final labelColor = t?.textSecondary ?? Colors.white70;
    final valueColor = t?.textSecondary ?? Colors.white54;
    final valueActiveColor = t?.brand ?? const Color(0xFFE5C07B);
    final trackColor = t?.divider ?? Colors.white24;
    final fillColor = t?.brand ?? const Color(0xFFE5C07B);
    final thumbBorderColor = t?.brand ?? const Color(0xFFE5C07B);
    final thumbFillColor = t?.surface ?? Colors.white;
    final hintColor = t?.textTertiary ?? Colors.white38;

    // 使用 mainAxisSize.min + 固定轨道高度，整体 shrink-wrap 到自然尺寸，
    // 避免嵌套 Expanded 在紧凑抽屉中强制最小高度导致 RenderFlex overflow。
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 名称 + 数值
        Row(
          children: [
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: labelColor,
              ),
            ),
            const Spacer(),
            Text(
              _format(v),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: v == 0 ? valueColor : valueActiveColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        // 滑块轨道（固定高度，命中区高度 28px）
        SizedBox(
          height: trackAreaHeight,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final trackWidth = constraints.maxWidth;
              final thumbX = trackWidth * tValue;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) {
                  final newV =
                      ((d.localPosition.dx / trackWidth).clamp(0.0, 1.0) *
                              (widget.max - widget.min)) +
                          widget.min;
                  setState(() => _dragValue = newV);
                  widget.onChanged(newV);
                  HapticFeedback.selectionClick();
                },
                onPanUpdate: (d) {
                  final newV =
                      ((d.localPosition.dx / trackWidth).clamp(0.0, 1.0) *
                              (widget.max - widget.min)) +
                          widget.min;
                  setState(() => _dragValue = newV);
                  widget.onChanged(newV);
                },
                onPanEnd: (_) {
                  setState(() => _dragValue = double.nan);
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 轨道背景
                    Positioned(
                      left: 0,
                      right: 0,
                      top: trackTop,
                      height: trackHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: trackColor,
                          borderRadius: BorderRadius.circular(trackHeight / 2),
                        ),
                      ),
                    ),
                    // 填充部分
                    Positioned(
                      left: 0,
                      top: trackTop,
                      width: thumbX,
                      height: trackHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: fillColor,
                          borderRadius: BorderRadius.circular(trackHeight / 2),
                        ),
                      ),
                    ),
                    // 把手
                    Positioned(
                      left: thumbX - thumbSize / 2,
                      top: (trackAreaHeight - thumbSize) / 2,
                      child: Container(
                        width: thumbSize,
                        height: thumbSize,
                        decoration: BoxDecoration(
                          color: thumbFillColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: thumbBorderColor, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x22000000),
                              blurRadius: 5,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 提示文字（右下角浮层，不占用布局高度）
                    if (widget.hint != null)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          child: Text(
                            widget.hint!,
                            style: TextStyle(fontSize: 8, color: hintColor),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}