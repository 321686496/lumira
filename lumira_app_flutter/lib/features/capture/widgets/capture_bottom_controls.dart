// Bottom control area widgets for the capture page, extracted (pure move)
// from capture_page.dart so the template preview page can reuse the exact
// same layout/controls as the real capture screen.
// ignore_for_file: use_key_in_widget_constructors
import 'dart:io';

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/capture_appearance.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/lumira/_internal/lumira_theme_resolver.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../data/capture_state.dart';
import '../data/custom_fill_light_colors.dart';
import '../domain/photo_template.dart';
import 'capture_button.dart';
import 'capture_thumbnail.dart';
import 'filter_picker.dart';
import 'scene_preset_strip.dart';
import 'template_drawer_panel.dart';
import 'template_strip.dart';

/// 相机权限状态（由 capture_page.dart 迁移至此，供 CameraPermissionGuide 与拍摄页共用）。
enum CameraPermissionStatus { unknown, granted, denied, permanentlyDenied }

/// 底部控制区：缩放Tab栏 + 工具栏 + 抽屉 + 拍摄按钮行
/// 修复 Bug 10：全屏模式下隐藏工具栏与抽屉，保留拍摄按钮、缩略图、切换摄像头
/// 改造：原"紧凑模板条+折叠按钮+展开面板"已替换为一排图标工具栏 + 底部抽屉
/// 修复：操作栏背景完全覆盖到底部（不使用 SafeArea，手动处理 bottom padding）
class CaptureBottomBar extends ConsumerWidget {
  const CaptureBottomBar({
    required this.isFullscreen,
    required this.isTrialMode,
    required this.onZoomChanged,
    required this.onCapture,
    required this.onSwitchCamera,
    required this.onThumbnailTap,
    this.rawCaptureKey,
    this.thumbnailKey,
  });

  final bool isFullscreen;
  final bool isTrialMode;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback onCapture;
  final VoidCallback onSwitchCamera;
  final VoidCallback onThumbnailTap;
  final GlobalKey? rawCaptureKey;
  final GlobalKey? thumbnailKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    // scrim：immersive=黑渐变（现状）；theme=画布色渐变（照片向画布过渡）
    final appearance = ref.watch(CaptureState.captureAppearanceProvider);
    final tokens = ref.watch(themeTokensProvider);
    final scrimBase =
        appearance == CaptureAppearance.theme ? tokens.canvas : Colors.black;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            scrimBase.withOpacity(0.3),
            scrimBase.withOpacity(0.7),
            scrimBase.withOpacity(0.95),
          ],
          stops: const [0.0, 0.4, 0.7, 1.0],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        // clipBehavior: Clip.none 允许缩放轮盘向上溢出到取景器区域
        // （此 OHOS fork 的 Column 不透传 clipBehavior，改用 Flex 显式指定）
        child: Flex(
          direction: Axis.vertical,
          mainAxisSize: MainAxisSize.min,
          clipBehavior: Clip.none,
          children: [
            // 缩放Tab栏（全屏 / 试用模式隐藏）
            if (!isFullscreen && !isTrialMode)
              ZoomBar(onChanged: onZoomChanged),

            // 工具栏 + 抽屉（全屏 / 试用模式隐藏）
            if (!isFullscreen && !isTrialMode) ...[
              const CaptureToolbar(),
              AnimatedToolDrawer(rawCaptureKey: rawCaptureKey),
            ],

            // 拍摄按钮行（试用模式下快门替换为锁定态，不响应拍照）
            CaptureButtonRow(
              onCapture: onCapture,
              onSwitchCamera: onSwitchCamera,
              onThumbnailTap: onThumbnailTap,
              thumbnailKey: thumbnailKey,
              locked: isTrialMode,
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部工具栏：一排图标按钮（模板/场景/参数/补光）— 圆角矩形半透明背景
/// 点击未激活的工具 → 激活并展开抽屉
/// 点击已激活的工具 → 收起抽屉
/// 点击"参数" → 直接打开 ParamPanel
class CaptureToolbar extends ConsumerWidget {
  const CaptureToolbar();

  static const _tools = [
    ToolDef('templates', Icons.dashboard_outlined, Icons.dashboard, '模板'),
    ToolDef('scenes', Icons.palette_outlined, Icons.palette, '场景'),
    ToolDef('params', Icons.tune, Icons.tune, '参数'),
    ToolDef('filter', Icons.filter_alt_outlined, Icons.filter_alt, '滤镜'),
    ToolDef('fillLight', Icons.lightbulb_outline, Icons.lightbulb, '补光'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTool = ref.watch(CaptureState.activeToolProvider);
    final isFullscreen = ref.watch(CaptureState.isFullscreenProvider);
    final facing = ref.watch(CaptureState.cameraFacingProvider);
    if (isFullscreen) return const SizedBox.shrink();

    // 双模式视觉：immersive=暗色工具栏 / theme=当前风格的叠照片浮层取向
    final visual = LumiraThemeResolver.captureOverlayVisual(
      tokens: ref.watch(themeTokensProvider),
      style: ref.watch(appThemeProvider).style,
      appearance: ref.watch(CaptureState.captureAppearanceProvider),
      role: CaptureOverlayRole.pill,
      radiusDp: 24,
    );

    // 补光工具仅在前置摄像头时显示（屏幕补光仅对前摄自拍摄影有效）
    final tools = facing == 'front'
        ? _tools
        : _tools.where((t) => t.id != 'fillLight').toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: visual.background,
        borderRadius: BorderRadius.circular(24),
        border: visual.border,
        boxShadow: visual.shadows,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: tools.map((tool) {
          final active = activeTool == tool.id;
          return ToolButton(
            tool: tool,
            active: active,
            visual: visual,
            onTap: () => _onTap(ref, tool.id, active),
          );
        }).toList(),
      ),
    );
  }

  void _onTap(WidgetRef ref, String toolId, bool active) {
    // 任意工具栏点击都会收起模板「显示更多」大面板（回到横向模板条）
    ref.read(CaptureState.templateDrawerExpandedProvider.notifier).state =
        false;
    if (toolId == 'params') {
      // 参数 tab：直接打开 ParamPanel，同时高亮 params tab
      final panelExpanded = ref.read(CaptureState.panelExpandedProvider);
      if (active && panelExpanded) {
        // 已激活且面板展开 → 关闭面板并收起抽屉
        ref.read(CaptureState.panelExpandedProvider.notifier).state = false;
        ref.read(CaptureState.activeToolProvider.notifier).state = null;
      } else {
        ref.read(CaptureState.panelExpandedProvider.notifier).state = true;
        ref.read(CaptureState.activeToolProvider.notifier).state = 'params';
      }
      return;
    }
    // 补光 tab：仅切换控制面板开合，不关闭补光灯本身
    // 补光灯的关闭由用户在面板中点击已选中的预设色来完成
    // 其他 tab：toggle 行为
    final next = active ? null : toolId;
    ref.read(CaptureState.activeToolProvider.notifier).state = next;
  }
}

class ToolDef {
  const ToolDef(this.id, this.icon, this.activeIcon, this.label);
  final String id;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class ToolButton extends StatelessWidget {
  const ToolButton({
    required this.tool,
    required this.active,
    required this.visual,
    required this.onTap,
  });
  final ToolDef tool;
  final bool active;
  final CaptureOverlayVisual visual;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? visual.accent : visual.foregroundSecondary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 选中指示器（2dp 强调色短横线）
            Container(
              width: 16,
              height: 2,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: active ? visual.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            Icon(active ? tool.activeIcon : tool.icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              tool.label,
              style: TextStyle(color: color, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

/// 工具栏下方的抽屉：根据 activeToolProvider 渲染对应内容
/// 高度根据内容自适应（child 自然撑开），收起时高度 0（AnimatedSize 动画）
class AnimatedToolDrawer extends ConsumerWidget {
  const AnimatedToolDrawer({this.rawCaptureKey});

  final GlobalKey? rawCaptureKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTool = ref.watch(CaptureState.activeToolProvider);
    final isFullscreen = ref.watch(CaptureState.isFullscreenProvider);
    if (isFullscreen) return const SizedBox.shrink();

    // 抽屉容器视觉：immersive=半透明暗底 / theme=当前风格面板底
    final visual = LumiraThemeResolver.captureOverlayVisual(
      tokens: ref.watch(themeTokensProvider),
      style: ref.watch(appThemeProvider).style,
      appearance: ref.watch(CaptureState.captureAppearanceProvider),
      role: CaptureOverlayRole.panel,
      radiusDp: 0,
    );

    final hasContent = activeTool != null;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: hasContent
          ? Container(
              width: double.infinity,
              decoration: BoxDecoration(color: visual.background),
              child: _buildContent(activeTool, ref),
            )
          : const SizedBox(height: 0, width: double.infinity),
    );
  }

  Widget _buildContent(String toolId, WidgetRef ref) {
    switch (toolId) {
      case 'templates':
        // 「显示更多」展开为 60% 高度 + 搜索框的大面板，否则显示前 10 个模板条
        final expanded =
            ref.watch(CaptureState.templateDrawerExpandedProvider);
        if (expanded) return const TemplateDrawerPanel();
        return TemplateStrip(
          onShowMore: () => ref
              .read(CaptureState.templateDrawerExpandedProvider.notifier)
              .state = true,
        );
      case 'scenes':
        return const ScenePresetStrip();
      case 'params':
        // 参数面板由 ParamPanel（底部滑入）处理，抽屉不显示额外内容
        return const SizedBox.shrink();
      case 'filter':
        return const FilterPicker();
      case 'fillLight':
        return const CaptureFillLightPanel();
      default:
        return const SizedBox.shrink();
    }
  }
}

/// 补光控制面板：预设色行 + 亮度滑块 + 可展开色环
class CaptureFillLightPanel extends ConsumerWidget {
  const CaptureFillLightPanel();

  static const _presets = [
    FillLightPreset('暖白', Color(0xFFFFE5B4), 0.6),
    FillLightPreset('冷白', Color(0xFFE0F0FF), 0.6),
    FillLightPreset('黄金', Color(0xFFFFB347), 0.7),
    FillLightPreset('柔粉', Color(0xFFFFC0CB), 0.6),
    FillLightPreset('青蓝', Color(0xFF8FD3F4), 0.5),
    FillLightPreset('紫', Color(0xFFD8BFD8), 0.5),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(CaptureState.fillLightEnabledProvider);
    final color = ref.watch(CaptureState.fillLightColorProvider);
    final intensity = ref.watch(CaptureState.fillLightIntensityProvider);
    final viewfinderScale = ref.watch(CaptureState.fillLightViewfinderScaleProvider);
    final ringExpanded = ref.watch(_ringExpandedProvider);
    // 补光面板视觉：immersive=暗色面板 / theme=当前风格面板底
    final visual = LumiraThemeResolver.captureOverlayVisual(
      tokens: ref.watch(themeTokensProvider),
      style: ref.watch(appThemeProvider).style,
      appearance: ref.watch(CaptureState.captureAppearanceProvider),
      role: CaptureOverlayRole.panel,
      radiusDp: 0,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 提示行
          Row(
            children: [
              Text(
                '补光',
                style: TextStyle(color: visual.foreground, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  enabled ? '已启用 · 再次点击选中色关闭' : '点击颜色开启',
                  style: TextStyle(color: visual.foregroundMuted, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 预设色行：选中的预设色移到第一位
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ..._orderedPresets(enabled, color).map((p) {
                  final isSelected = enabled && _colorMatches(color, p.color);
                  return PresetColorDot(
                    preset: p,
                    selected: isSelected,
                    visual: visual,
                    onTap: () {
                      if (isSelected) {
                        // 已选中 → 关闭补光，恢复取景器原状
                        _turnOffFillLight(ref);
                      } else {
                        // 未选中 → 切换补光色，保留当前亮度（不重置）
                        ref.read(CaptureState.fillLightEnabledProvider.notifier).state = true;
                        ref.read(CaptureState.fillLightColorProvider.notifier).state = p.color;
                        ref.read(_ringExpandedProvider.notifier).state = false;
                      }
                    },
                  );
                }),
                // 自定义按钮
                ActionDot(
                  icon: Icons.color_lens,
                  label: '自定义',
                  selected: ringExpanded,
                  visual: visual,
                  onTap: () {
                    ref.read(CaptureState.fillLightEnabledProvider.notifier).state = true;
                    ref.read(_ringExpandedProvider.notifier).state = !ringExpanded;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // 亮度滑块（0.1 ~ 1.5，可超过 100% 让补光更亮）
          Row(
            children: [
              Icon(Icons.brightness_6, color: visual.foregroundMuted, size: 16),
              Expanded(
                child: LumiraSlider(
                  value: intensity.clamp(0.1, 1.5),
                  min: 0.1,
                  max: 1.5,
                  divisions: 28,
                  onChanged: enabled
                      ? (v) {
                          ref.read(CaptureState.fillLightIntensityProvider.notifier)
                              .state = v;
                          // 调试（Bug：亮度到一定值后补光色反而变暗）：
                          // 与 _FloatingViewfinder 里 bgFull 完全相同的算法，逐帧输出供真机比对。
                          if (kDebugMode) {
                            final c = ref.read(
                                CaptureState.fillLightColorProvider);
                            final b = v > 1.0
                                ? Color.lerp(c, Colors.white,
                                    (v - 1.0).clamp(0.0, 0.5))
                                : c.withOpacity(v.clamp(0.0, 1.0));
                            debugPrint(
                                '[fillLight] intensity=$v color=#${c.value.toRadixString(16).padLeft(8, '0')} bgFull=${b?.value.toRadixString(16).padLeft(8, '0')}');
                          }
                        }
                      : (double _) {},
                ),
              ),
              SizedBox(
                width: 42,
                child: Text(
                  '${(intensity * 100).round()}%',
                  style: TextStyle(color: visual.foregroundSecondary, fontSize: 11),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          // 取景器窗口大小滑块（仅补光开启时可用）
          Row(
            children: [
              Icon(Icons.crop_free, color: visual.foregroundMuted, size: 16),
              Expanded(
                child: LumiraSlider(
                  value: viewfinderScale.clamp(0.3, 1.0),
                  min: 0.3,
                  max: 1.0,
                  divisions: 14,
                  onChanged: enabled
                      ? (v) => ref.read(CaptureState.fillLightViewfinderScaleProvider.notifier).state = v
                      : (double _) {},
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '${(viewfinderScale * 100).round()}%',
                  style: TextStyle(color: visual.foregroundSecondary, fontSize: 11),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          // 可展开方形取色盘 + 收藏的颜色
          if (ringExpanded) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Center(
                child: SquareColorPicker(
                  onColorChanged: (c) {
                    ref.read(CaptureState.fillLightColorProvider.notifier).state = c;
                  },
                ),
              ),
            ),
            // 保存颜色行（合并系统预设与用户保存颜色）
            SaveColorsRow(
              onPick: (c) {
                ref.read(CaptureState.fillLightEnabledProvider.notifier).state = true;
                ref.read(CaptureState.fillLightColorProvider.notifier).state = c;
              },
              onAdd: (name, c) {
                ref.read(customFillLightColorsProvider.notifier).add(name, c);
              },
            ),
          ],
        ],
      ),
    );
  }

  bool _colorMatches(Color a, Color b) => a.value == b.value;

  /// 将当前选中的预设色移到列表第一位（未启用、未选中或已在第一位时保持原顺序）。
  List<FillLightPreset> _orderedPresets(bool enabled, Color color) {
    if (!enabled) return _presets;
    final index = _presets.indexWhere((p) => _colorMatches(color, p.color));
    if (index <= 0) return _presets;
    final result = [..._presets];
    final item = result.removeAt(index);
    result.insert(0, item);
    return result;
  }

  /// 关闭补光并重置悬浮取景器到初始状态（位置、大小）
  void _turnOffFillLight(WidgetRef ref) {
    ref.read(CaptureState.fillLightEnabledProvider.notifier).state = false;
    ref.read(CaptureState.fillLightViewfinderScaleProvider.notifier).state = 0.5;
    ref.read(CaptureState.fillLightViewfinderOffsetProvider.notifier).state =
        Offset.zero;
    ref.read(_ringExpandedProvider.notifier).state = false;
  }
}

class FillLightPreset {
  const FillLightPreset(this.label, this.color, this.intensity);
  final String label;
  final Color color;
  final double intensity;
}

class PresetColorDot extends StatelessWidget {
  const PresetColorDot({
    required this.preset,
    required this.selected,
    required this.visual,
    required this.onTap,
  });
  final FillLightPreset preset;
  final bool selected;
  final CaptureOverlayVisual visual;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        margin: const EdgeInsets.only(right: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: preset.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? visual.accent : visual.foregroundMuted,
                  width: selected ? 2 : 1,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              preset.label,
              style: TextStyle(
                color: selected ? visual.accent : visual.foregroundMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ActionDot extends StatelessWidget {
  const ActionDot({
    required this.icon,
    required this.label,
    required this.selected,
    required this.visual,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final CaptureOverlayVisual visual;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        margin: const EdgeInsets.only(right: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: visual.fillSubtle,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? visual.accent : visual.foregroundMuted,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Icon(icon, color: visual.foregroundSecondary, size: 16),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: selected ? visual.accent : visual.foregroundMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 色环展开状态（仅 capture_page 内部使用）
final _ringExpandedProvider = StateProvider<bool>((ref) => false);

/// 方形 HSV 取色盘（色相 + 饱和度/亮度二维面板）
/// 顶部：色相条（水平滑动选色相）
/// 下方：SV 方形面板（X=饱和度，Y=亮度，左下黑、右下灰、右上纯色、左上白）
class SquareColorPicker extends StatefulWidget {
  const SquareColorPicker({required this.onColorChanged});
  final ValueChanged<Color> onColorChanged;

  @override
  State<SquareColorPicker> createState() => SquareColorPickerState();
}

class SquareColorPickerState extends State<SquareColorPicker> {
  double _hue = 40.0; // 默认暖白附近
  double _saturation = 0.6;
  double _value = 1.0;

  @override
  Widget build(BuildContext context) {
    const panelSize = 220.0;
    const hueBarHeight = 24.0;
    final currentColor =
        HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // SV 方形面板
        SizedBox(
          width: panelSize,
          height: panelSize,
          child: GestureDetector(
            onPanDown: (d) => _handleSv(d.localPosition, panelSize),
            onPanUpdate: (d) => _handleSv(d.localPosition, panelSize),
            child: CustomPaint(
              painter: SvPanelPainter(
                hue: _hue,
                saturation: _saturation,
                value: _value,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // 色相条
        SizedBox(
          width: panelSize,
          height: hueBarHeight,
          child: GestureDetector(
            onPanDown: (d) => _handleHue(d.localPosition, panelSize),
            onPanUpdate: (d) => _handleHue(d.localPosition, panelSize),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(hueBarHeight / 2),
              child: CustomPaint(
                painter: HueBarPainter(hue: _hue),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // 当前色预览
        Container(
          width: panelSize,
          height: 28,
          decoration: BoxDecoration(
            color: currentColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          alignment: Alignment.center,
          child: Text(
            '#${currentColor.red.toRadixString(16).padLeft(2, '0').toUpperCase()}'
            '${currentColor.green.toRadixString(16).padLeft(2, '0').toUpperCase()}'
            '${currentColor.blue.toRadixString(16).padLeft(2, '0').toUpperCase()}',
            style: TextStyle(
              color: _value > 0.5 ? Colors.black54 : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _handleSv(Offset localPos, double size) {
    final s = (localPos.dx / size).clamp(0.0, 1.0);
    // Y 轴反向：顶部=亮度1.0，底部=亮度0.0
    final v = (1.0 - localPos.dy / size).clamp(0.0, 1.0);
    setState(() {
      _saturation = s;
      _value = v;
    });
    widget.onColorChanged(
        HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor());
  }

  void _handleHue(Offset localPos, double width) {
    final h = (localPos.dx / width * 360.0).clamp(0.0, 360.0);
    setState(() => _hue = h);
    widget.onColorChanged(
        HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor());
  }
}

/// SV 面板绘制器：横向饱和度，纵向亮度
class SvPanelPainter extends CustomPainter {
  const SvPanelPainter({
    required this.hue,
    required this.saturation,
    required this.value,
  });
  final double hue;
  final double saturation;
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // 基色：当前色相的纯色
    final baseColor = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();

    // 横向：白→纯色（饱和度）
    final saturatePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Colors.white, baseColor],
      ).createShader(rect);
    canvas.drawRect(rect, saturatePaint);

    // 纵向：透明→黑（亮度）
    final valuePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black],
      ).createShader(rect);
    canvas.drawRect(rect, valuePaint);

    // 指示器圆圈
    final cx = saturation * size.width;
    final cy = (1.0 - value) * size.height;
    final indicator = Offset(cx, cy);
    canvas.drawCircle(indicator, 8, Paint()..color = Colors.white);
    canvas.drawCircle(indicator, 8,
        Paint()..color = Colors.black38..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant SvPanelPainter old) =>
      old.hue != hue ||
      old.saturation != saturation ||
      old.value != value;
}

/// 色相条绘制器
class HueBarPainter extends CustomPainter {
  const HueBarPainter({required this.hue});
  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          for (var h = 0; h <= 360; h += 30)
            HSVColor.fromAHSV(1.0, h.toDouble(), 1.0, 1.0).toColor(),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    // 指示器
    final x = (hue / 360.0) * size.width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, size.height / 2), width: 6, height: size.height + 4),
        const Radius.circular(3),
      ),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant HueBarPainter old) => old.hue != hue;
}

/// 保存颜色行：合并系统预设与用户保存颜色为一个列表，
/// 用户保存的颜色可长按修改或删除。
class SaveColorsRow extends ConsumerStatefulWidget {
  const SaveColorsRow({
    required this.onPick,
    required this.onAdd,
  });
  final ValueChanged<Color> onPick;
  final void Function(String name, Color color) onAdd;

  @override
  ConsumerState<SaveColorsRow> createState() => SaveColorsRowState();
}

class SaveColorsRowState extends ConsumerState<SaveColorsRow> {
  bool _showNameInput = false;
  final _nameController = TextEditingController();
  bool _hintShown = false;

  @override
  void initState() {
    super.initState();
    _loadHintState();
  }

  Future<void> _loadHintState() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/lumira_fill_light_hint.json');
      if (await file.exists()) {
        if (mounted) setState(() => _hintShown = true);
      }
    } catch (_) {}
  }

  Future<void> _markHintShown() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/lumira_fill_light_hint.json');
      await file.writeAsString('{"shown":true}');
      if (mounted) setState(() => _hintShown = true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // 系统预设颜色（与 CaptureFillLightPanel._presets 一致）
  static const _presets = [
    FillLightPreset('暖白', Color(0xFFFFE5B4), 0.6),
    FillLightPreset('冷白', Color(0xFFE0F0FF), 0.6),
    FillLightPreset('黄金', Color(0xFFFFB347), 0.7),
    FillLightPreset('柔粉', Color(0xFFFFC0CB), 0.6),
    FillLightPreset('青蓝', Color(0xFF8FD3F4), 0.5),
    FillLightPreset('紫', Color(0xFFD8BFD8), 0.5),
  ];

  /// 解析当前浮层视觉（编辑 Sheet 弹出时读取一次即可）
  CaptureOverlayVisual _visualOf(WidgetRef ref) =>
      LumiraThemeResolver.captureOverlayVisual(
        tokens: ref.read(themeTokensProvider),
        style: ref.read(appThemeProvider).style,
        appearance: ref.read(CaptureState.captureAppearanceProvider),
        role: CaptureOverlayRole.panel,
        radiusDp: 0,
      );

  void _showEditSheet(String name, Color color) {
    _markHintShown();
    final visual = _visualOf(ref);
    showLumiraBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: visual.fillSubtle),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  name,
                  style: TextStyle(color: visual.foreground, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          LumiraListTile(
            leading: Icon(Icons.edit, color: visual.accent, size: 20),
            title: Text('修改名称', style: TextStyle(color: visual.foregroundSecondary, fontSize: 14)),
            onTap: () {
              Navigator.pop(ctx);
              _showRenameDialog(name);
            },
          ),
          LumiraListTile(
            leading: Icon(Icons.color_lens, color: visual.accent, size: 20),
            title: Text('修改颜色', style: TextStyle(color: visual.foregroundSecondary, fontSize: 14)),
            onTap: () {
              Navigator.pop(ctx);
              // 用当前颜色打开色环
              ref.read(CaptureState.fillLightColorProvider.notifier).state = color;
            },
          ),
          LumiraListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
            title: const Text('删除', style: TextStyle(color: Colors.redAccent, fontSize: 14)),
            onTap: () {
              ref.read(customFillLightColorsProvider.notifier).remove(name);
              Navigator.pop(ctx);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showRenameDialog(String oldName) {
    final controller = TextEditingController(text: oldName);
    showLumiraDialog(
      context: context,
      builder: (ctx) => LumiraAlertDialog(
        title: const Text('修改名称'),
        content: LumiraTextField(
          controller: controller,
          hintText: '输入新名称',
        ),
        actions: [
          LumiraButton(
            variant: ButtonVariant.ghost,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          LumiraButton(
            variant: ButtonVariant.primary,
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != oldName) {
                ref.read(customFillLightColorsProvider.notifier).update(oldName, newName: newName);
              }
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customColors = ref.watch(customFillLightColorsProvider);
    final currentColor = ref.watch(CaptureState.fillLightColorProvider);
    // 保存颜色行视觉：随拍摄外观双模式解析
    final visual = LumiraThemeResolver.captureOverlayVisual(
      tokens: ref.watch(themeTokensProvider),
      style: ref.watch(appThemeProvider).style,
      appearance: ref.watch(CaptureState.captureAppearanceProvider),
      role: CaptureOverlayRole.panel,
      radiusDp: 0,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行 + 保存按钮
          Row(
            children: [
              Text(
                '保存颜色',
                style: TextStyle(color: visual.foregroundMuted, fontSize: 11),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _showNameInput = !_showNameInput),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: visual.fillSubtle,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bookmark_add_outlined, size: 12, color: visual.accent),
                      const SizedBox(width: 3),
                      Text(
                        '保存当前',
                        style: TextStyle(color: visual.accent, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // 命名输入框
          if (_showNameInput) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: currentColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: visual.fillSubtle, width: 1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LumiraTextField(
                    controller: _nameController,
                    hintText: '为该颜色命名（如：日落金）',
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    final name = _nameController.text.trim();
                    if (name.isEmpty) return;
                    widget.onAdd(name, currentColor);
                    _nameController.clear();
                    setState(() => _showNameInput = false);
                    _markHintShown();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: visual.accent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '保存',
                      style: TextStyle(color: visual.onAccent, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
          // 合并的颜色列表：系统预设 + 用户保存
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // 系统预设颜色（不可删改）
                ..._presets.map((p) {
                  final isSelected = _colorMatch(currentColor, p.color);
                  return PresetColorDot(
                    preset: p,
                    selected: isSelected,
                    visual: visual,
                    onTap: () => widget.onPick(p.color),
                  );
                }),
                // 分隔符
                if (customColors.isNotEmpty)
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    color: visual.fillSubtle,
                  ),
                // 用户保存颜色（可长按删改）
                ...customColors.map((c) {
                  final isSelected = _colorMatch(currentColor, c.color);
                  return SavedColorDot(
                    name: c.name,
                    color: c.color,
                    selected: isSelected,
                    visual: visual,
                    onTap: () => widget.onPick(c.color),
                    onLongPress: () => _showEditSheet(c.name, c.color),
                  );
                }),
              ],
            ),
          ),
          // 操作提示（首次显示，用户长按或保存后消失）
          if (!_hintShown)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: visual.foregroundMuted, size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '长按保存的颜色可修改或删除',
                      style: TextStyle(color: visual.foregroundMuted, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool _colorMatch(Color a, Color b) => a.value == b.value;
}

/// 用户保存的颜色圆点（支持长按）
class SavedColorDot extends StatelessWidget {
  const SavedColorDot({
    required this.name,
    required this.color,
    required this.selected,
    required this.visual,
    required this.onTap,
    required this.onLongPress,
  });
  final String name;
  final Color color;
  final bool selected;
  final CaptureOverlayVisual visual;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 44,
        margin: const EdgeInsets.only(right: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? visual.accent : visual.foregroundMuted,
                  width: selected ? 2 : 1,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? visual.accent : visual.foregroundMuted,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 缩放栏：默认胶囊 Tab + 拖动弹出 iPhone 原生风格旋转轮盘
///
/// 默认状态：半透明胶囊容器，显示预设倍数 Tab，点击快速切换。
/// 后置摄像头：水平拖动胶囊时弹出旋转轮盘（从底部滑入），可精细调整缩放。
/// 轮盘旋转，指针固定在顶部不动（与 iPhone 原生相机一致）。
/// 前置摄像头：仅支持点按 Tab 切换，不支持拖动精细调整。
class ZoomBar extends ConsumerStatefulWidget {
  const ZoomBar({required this.onChanged});

  final ValueChanged<double> onChanged;

  @override
  ConsumerState<ZoomBar> createState() => ZoomBarState();
}

class ZoomBarState extends ConsumerState<ZoomBar> {
  /// 是否正在显示弧形轮盘（水平拖动中）
  bool _showDial = false;

  /// 拖动起始时的倍数
  double _dragStartMultiplier = 1.0;

  /// 拖动起始时的水平位置
  double _dragStartX = 0.0;

  /// 轮盘滑入动画控制器
  double _dialOffset = 1.0; // 1.0 = 完全隐藏（底部），0.0 = 完全显示

  /// 上一次触发震动的倍数（用于检测刻度变化）
  double _lastHapticMultiplier = -1.0;

  /// 当前活跃指针数：用于区分「单指横向滑动」与「双指捏合」。
  /// 轮盘只在缩放 Tab 上单指左右滑动时弹出，捏合缩放不弹轮盘。
  int _activePointers = 0;

  void _onPointerDown(PointerDownEvent event) {
    _activePointers++;
    setState(() {});
    // 第二根手指落下（开始捏合）时立即收起轮盘
    if (_activePointers >= 2 && _showDial) {
      _animateDialOut();
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    setState(() => _activePointers = (_activePointers - 1).clamp(0, 10));
  }

  void _onPointerCancel(PointerCancelEvent event) {
    setState(() => _activePointers = (_activePointers - 1).clamp(0, 10));
  }

  /// 根据设备能力动态生成预设倍数列表。
  List<double> _getZoomPresets(String facing, double maxZoom, bool supportsUltraWide) {
    final base = <double>[1.0];
    if (facing == 'back') {
      if (maxZoom >= 2.0) base.add(2.0);
      if (maxZoom >= 3.0) base.add(3.0);
      if (maxZoom >= 5.0) base.add(5.0);
    }
    if (supportsUltraWide) base.insert(0, 0.5);
    return base;
  }

  /// 找到最接近当前倍数的预设索引
  int _nearestPresetIndex(double multiplier, List<double> presets) {
    int nearest = 0;
    double minDiff = double.infinity;
    for (var i = 0; i < presets.length; i++) {
      final diff = (presets[i] - multiplier).abs();
      if (diff < minDiff) {
        minDiff = diff;
        nearest = i;
      }
    }
    return nearest;
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    final facing = ref.read(CaptureState.cameraFacingProvider);
    if (facing != 'back') return;
    // 仅单指横向滑动显示轮盘；双指捏合不显示（由 _PinchZoomCamera 处理缩放）
    if (_activePointers != 1) return;
    _dragStartMultiplier = ref.read(CaptureState.apparentZoomProvider);
    _dragStartX = details.globalPosition.dx;
    _lastHapticMultiplier = _dragStartMultiplier;
    setState(() => _showDial = true);
    _animateDialIn();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final facing = ref.read(CaptureState.cameraFacingProvider);
    if (facing != 'back') return;
    // 拖动过程中第二根手指落下（变成捏合）时停止缩放调整
    if (_activePointers != 1) return;
    final minZoom = ref.read(CaptureState.deviceMinZoomProvider) ?? 1.0;
    final maxZoom = ref.read(CaptureState.deviceMaxZoomProvider) ?? 10.0;
    final deltaX = details.globalPosition.dx - _dragStartX;
    // 每 30px = 0.1x 倍数变化
    final deltaMultiplier = (deltaX / 30) * 0.1;
    var newMultiplier = _dragStartMultiplier + deltaMultiplier;
    newMultiplier = newMultiplier.clamp(minZoom, maxZoom);
    widget.onChanged(newMultiplier);

    // 每变化 0.1x 触发一次震动反馈
    final roundedNew = (newMultiplier * 10).round() / 10.0;
    final roundedLast = (_lastHapticMultiplier * 10).round() / 10.0;
    if (roundedNew != roundedLast) {
      HapticFeedback.lightImpact();
      _lastHapticMultiplier = newMultiplier;
    }
  }

  void _onHorizontalDragEnd(DragEndDetails _) {
    HapticFeedback.mediumImpact();
    _animateDialOut();
  }

  void _animateDialIn() {
    double start = 1.0;
    double end = 0.0;
    const duration = Duration(milliseconds: 250);
    final startTime = DateTime.now();

    void tick() {
      final elapsed = DateTime.now().difference(startTime);
      final t = (elapsed.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
      final eased = 1 - math.pow(1 - t, 3).toDouble();
      setState(() {
        _dialOffset = start + (end - start) * eased;
      });
      if (t < 1.0) {
        Future.delayed(const Duration(milliseconds: 16), tick);
      }
    }
    tick();
  }

  void _animateDialOut() {
    double start = _dialOffset;
    double end = 1.0;
    const duration = Duration(milliseconds: 200);
    final startTime = DateTime.now();

    void tick() {
      final elapsed = DateTime.now().difference(startTime);
      final t = (elapsed.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
      final eased = t * t;
      setState(() {
        _dialOffset = start + (end - start) * eased;
      });
      if (t < 1.0) {
        Future.delayed(const Duration(milliseconds: 16), tick);
      } else {
        setState(() => _showDial = false);
      }
    }
    tick();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final facing = ref.watch(CaptureState.cameraFacingProvider);
    final multiplier = ref.watch(CaptureState.apparentZoomProvider);
    final maxZoom = ref.watch(CaptureState.deviceMaxZoomProvider) ?? 10.0;
    final minZoom = ref.watch(CaptureState.deviceMinZoomProvider) ?? 1.0;
    final supportsUltraWide = ref.watch(CaptureState.supportsUltraWideProvider);
    final presets = _getZoomPresets(facing, maxZoom, supportsUltraWide);
    final activeIndex = _nearestPresetIndex(multiplier, presets);
    final canDrag = facing == 'back';
    // 缩放栏视觉：immersive=暗色 / theme=当前风格面板底
    final visual = LumiraThemeResolver.captureOverlayVisual(
      tokens: ref.watch(themeTokensProvider),
      style: ref.watch(appThemeProvider).style,
      appearance: ref.watch(CaptureState.captureAppearanceProvider),
      role: CaptureOverlayRole.panel,
      radiusDp: 18,
    );

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      behavior: HitTestBehavior.translucent,
      child: SizedBox(
        height: 60,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // 默认胶囊 Tab 栏：仅在此胶囊上单指左右滑动才弹出轮盘
            // （GestureDetector 只包住胶囊，避免整条空白区域误触发轮盘）
            GestureDetector(
              onHorizontalDragStart: canDrag ? _onHorizontalDragStart : null,
              onHorizontalDragUpdate: canDrag ? _onHorizontalDragUpdate : null,
              onHorizontalDragEnd: canDrag ? _onHorizontalDragEnd : null,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: visual.background,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < presets.length; i++) ...[
                      if (i > 0) const SizedBox(width: 2),
                      ZoomTab(
                        label: presets[i] == presets[i].toInt()
                            ? '${presets[i].toInt()}'
                            : presets[i].toStringAsFixed(1),
                        active: i == activeIndex && !_showDial,
                        visual: visual,
                        onTap: () {
                          widget.onChanged(presets[i]);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // 圆形轮盘 overlay（后置拖动时从底部滑入）
            if (_showDial)
              Positioned(
                bottom: 0 + 80 * _dialOffset,
                left: 0,
                right: 0,
                child: SizedBox(
                  width: screenWidth,
                  height: screenWidth / 2,
                  child: HalfCircleDial(
                    multiplier: multiplier,
                    presets: presets,
                    activeIndex: activeIndex,
                    minZoom: minZoom,
                    maxZoom: maxZoom,
                    visual: visual,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 单个缩放 Tab 按钮 — iPhone 原生风格
class ZoomTab extends StatelessWidget {
  const ZoomTab({
    required this.label,
    required this.active,
    required this.visual,
    required this.onTap,
  });
  final String label;
  final bool active;
  final CaptureOverlayVisual visual;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? visual.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? visual.onAccent : visual.foregroundSecondary,
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

/// 半圆缩放轮盘 — 完整圆形只显示上半部分
///
/// 直径 = 屏幕宽度 100%，圆心在底部中央。
/// 半透明黑色圆形背景，只显示上半圆。
class HalfCircleDial extends StatelessWidget {
  const HalfCircleDial({
    required this.multiplier,
    required this.presets,
    required this.activeIndex,
    required this.minZoom,
    required this.maxZoom,
    required this.visual,
  });

  final double multiplier;
  final List<double> presets;
  final int activeIndex;
  final double minZoom;
  final double maxZoom;
  final CaptureOverlayVisual visual;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final radius = screenWidth / 2;

    final totalRange = maxZoom - minZoom;
    final currentT = totalRange > 0 ? (multiplier - minZoom) / totalRange : 0.0;
    // 与 iPhone 原生一致：半圆弧（180°），从左侧经顶部到右侧
    const tickStartAngle = -math.pi;
    const tickSweepAngle = math.pi;
    final currentAngleOnDial = tickStartAngle + currentT * tickSweepAngle;
    final rotationAngle = (-math.pi / 2) - currentAngleOnDial;

    return SizedBox(
      width: screenWidth,
      height: radius,
      child: ClipRect(
        // topCenter：让完整圆从顶部开始向下溢出，只露出上半圆（∩ 形，圆心在底部中央）。
        // 之前误用 bottomCenter 导致露出的是下半圆（∪ 形），上半弧上的刻度全被裁掉。
        child: OverflowBox(
          maxHeight: screenWidth,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: screenWidth,
            height: screenWidth,
            child: Stack(
              children: [
                // 半透明轮盘背景（immersive=暗底 / theme=风格面板底）
                Container(
                  width: screenWidth,
                  height: screenWidth,
                  decoration: BoxDecoration(
                    color: visual.background,
                    shape: BoxShape.circle,
                  ),
                ),
                // 旋转刻度层（刻度随轮盘旋转，指针固定）
                Transform.rotate(
                  angle: rotationAngle,
                  child: SizedBox(
                    width: screenWidth,
                    height: screenWidth,
                    child: CustomPaint(
                      painter: HalfCircleTickPainter(
                        radius: radius,
                        startAngle: tickStartAngle,
                        sweepAngle: tickSweepAngle,
                        totalRange: totalRange,
                        tickColor: visual.foregroundMuted,
                      ),
                    ),
                  ),
                ),
                // 数字标签：按旋转后的屏幕坐标直接定位，保持正立且不被底部裁切
                ..._buildUprightLabels(radius, rotationAngle, totalRange, tickStartAngle, tickSweepAngle),
                // 固定指针
                Positioned(
                  top: screenWidth * 0.04,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: CustomPaint(
                      painter: PointerPainter(color: visual.accent),
                    ),
                  ),
                ),
                // 当前倍数显示（居中于半圆中心，避免与顶部刻度数字重叠）
                Positioned(
                  top: screenWidth * 0.25 - 14,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: visual.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${multiplier.toStringAsFixed(1)}x',
                        style: TextStyle(
                          color: visual.onAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildUprightLabels(double radius, double rotationAngle, double totalRange, double tickStartAngle, double tickSweepAngle) {
    final widgets = <Widget>[];
    const labelBoxW = 44.0;
    const labelBoxH = 20.0;
    final labelR = radius * 0.82 - 22;

    for (var i = 0; i < presets.length; i++) {
      final preset = presets[i];
      final t = totalRange > 0 ? (preset - minZoom) / totalRange : 0.0;
      final markAngle = tickStartAngle + t * tickSweepAngle;
      // 轮盘层旋转后，刻度在屏幕上的角度（0 = 正右，-π/2 = 正上）
      final screenAngle = markAngle + rotationAngle;
      final isMajor = i == activeIndex;

      // 标签中心落在旋转后的屏幕坐标（始终正立，无需反向旋转）
      final cx = radius + labelR * math.cos(screenAngle);
      var cy = radius + labelR * math.sin(screenAngle);
      // 夹紧在上半圆内，避免位于基线（左右两端）的标签被底部裁掉一半
      cy = cy.clamp(labelBoxH / 2 + 2, radius - labelBoxH / 2 - 2).toDouble();

      final label = preset == preset.toInt()
          ? '${preset.toInt()}'
          : preset.toStringAsFixed(1);

      widgets.add(
        Positioned(
          left: cx - labelBoxW / 2,
          top: cy - labelBoxH / 2,
          child: SizedBox(
            width: labelBoxW,
            height: labelBoxH,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: isMajor ? visual.accent : visual.foregroundSecondary,
                  fontSize: isMajor ? 15 : 12,
                  fontWeight: isMajor ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }
}

/// 半圆刻度绘制器（随轮盘旋转）
class HalfCircleTickPainter extends CustomPainter {
  HalfCircleTickPainter({
    required this.radius,
    required this.startAngle,
    required this.sweepAngle,
    required this.totalRange,
    required this.tickColor,
  });

  final double radius;
  final double startAngle;
  final double sweepAngle;
  final double totalRange;

  /// 刻度基色（弧线/刻度线按原透明度 0.25/0.35/0.75 施加）
  final Color tickColor;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final arcR = radius * 0.82;

    // 1. 绘制弧线
    final arcPaint = Paint()
      ..color = tickColor.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(centerX, centerY), radius: arcR),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );

    // 2. 绘制密集刻度线
    final stepCount = ((totalRange / 0.1).round()).clamp(10, 200);
    for (var i = 0; i <= stepCount; i++) {
      final t = i / stepCount;
      final angle = startAngle + t * sweepAngle;
      final isMajorTick = i % 10 == 0;
      final tickLength = isMajorTick ? 14.0 : 6.0;
      final tickWidth = isMajorTick ? 1.5 : 0.7;

      final outerR = arcR;
      final innerR = arcR - tickLength;

      final p1 = Offset(
        centerX + outerR * math.cos(angle),
        centerY + outerR * math.sin(angle),
      );
      final p2 = Offset(
        centerX + innerR * math.cos(angle),
        centerY + innerR * math.sin(angle),
      );

      canvas.drawLine(
        p1, p2,
        Paint()
          ..color = tickColor.withOpacity(isMajorTick ? 0.75 : 0.35)
          ..strokeWidth = tickWidth,
      );
    }
  }

  @override
  bool shouldRepaint(HalfCircleTickPainter oldDelegate) =>
      oldDelegate.tickColor != tickColor ||
      oldDelegate.totalRange != totalRange;
}

/// 顶部固定指针绘制器（强调色向下小三角）
class PointerPainter extends CustomPainter {
  PointerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const s = 6.0;
    final path = Path()
      ..moveTo(0, s)
      ..lineTo(-s * 0.8, -s * 0.5)
      ..lineTo(s * 0.8, -s * 0.5)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant PointerPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 拍摄按钮行：角标缩略图 + 拍摄按钮 + 翻转摄像头
/// 试用模式水印遮罩
///
/// 铺在取景器上方：半透明白色斜纹 + 重复"LUMIRA 试用"水印文字，
/// 中央提示"购买解锁后去除水印"。IgnorePointer 不拦截手势，
/// 导航栏（含购买/退出）与底部锁定快门仍可操作。
class TrialWatermarkOverlay extends StatelessWidget {
  const TrialWatermarkOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        color: Colors.white.withOpacity(0.06),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 斜纹水印文字（CustomPainter 绘制，性能优于大量 Transform Text）
            CustomPaint(painter: TrialWatermarkPainter()),
            // 中央提示
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 0.5,
                  ),
                ),
                child: const Text(
                  '试用模式 · 购买解锁后去除水印',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 斜纹"LUMIRA 试用"水印文字画笔
class TrialWatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final textStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Colors.white.withOpacity(0.22),
      letterSpacing: 2,
    );

    canvas.save();
    canvas.rotate(-0.45);
    const step = 130.0;
    const offset = -200.0;
    // 沿斜向网格铺满水印文字
    for (var x = offset; x < size.height + 200; x += step) {
      for (var y = offset; y < size.width + 200; y += step) {
        final tp = TextPainter(
          text: TextSpan(text: 'LUMIRA 试用', style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(y, x));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CaptureButtonRow extends ConsumerWidget {
  const CaptureButtonRow({
    required this.onCapture,
    required this.onSwitchCamera,
    required this.onThumbnailTap,
    this.thumbnailKey,
    this.locked = false,
  });

  final VoidCallback onCapture;
  final VoidCallback onSwitchCamera;
  final VoidCallback onThumbnailTap;
  final GlobalKey? thumbnailKey;
  /// 试用模式：快门替换为锁定态，点击提示解锁
  final bool locked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 快门行浮层视觉：切摄圆钮/锁定快门共用（role=pill）
    final visual = LumiraThemeResolver.captureOverlayVisual(
      tokens: ref.watch(themeTokensProvider),
      style: ref.watch(appThemeProvider).style,
      appearance: ref.watch(CaptureState.captureAppearanceProvider),
      role: CaptureOverlayRole.pill,
      radiusDp: 24,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 角标缩略图（左）：四态状态机驱动（idle/processing/preview/final）
          // thumbnailKey：水印动画 Phase 4 通过此 key 读取角标全局 Rect
          // 试用模式隐藏缩略图（不产生照片）
          if (!locked)
            CaptureThumbnail(key: thumbnailKey, onTap: onThumbnailTap),
          // 拍摄按钮（中）：试用模式替换为锁定快门
          locked
              ? LockedCaptureButton(visual: visual)
              : CaptureButton(onTap: onCapture),
          // 翻转摄像头（右）
          GestureDetector(
            onTap: onSwitchCamera,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: visual.background,
                shape: BoxShape.circle,
                border: visual.border,
              ),
              child: Icon(
                Icons.cameraswitch_outlined,
                color: visual.foreground,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 试用模式锁定快门：不可拍照，点击提示解锁
class LockedCaptureButton extends StatelessWidget {
  const LockedCaptureButton({required this.visual});

  /// 快门行浮层视觉（由 CaptureButtonRow 传入）
  final CaptureOverlayVisual visual;

  @override
  Widget build(BuildContext context) {
    // 锁图标用 visual.background 作内圆对比色：
    // immersive=暗底配白内圆；theme=浅 surface 配深内圆（明暗主题均成立）
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => LumiraToast.show(
        context,
        '试用模式不可拍摄，购买解锁后即可使用',
        duration: const Duration(milliseconds: 1200),
      ),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border:
              Border.all(color: visual.foreground.withOpacity(0.6), width: 4),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: visual.foreground.withOpacity(0.85),
          ),
          child: Icon(
            Icons.lock_outline,
            size: 28,
            color: visual.background,
          ),
        ),
      ),
    );
  }
}

/// 相机权限引导页
/// 在权限未授予时显示，提供重新请求/跳转系统设置的入口
class CameraPermissionGuide extends ConsumerWidget {
  const CameraPermissionGuide({
    super.key,
    required this.status,
    required this.onRetry,
    required this.onBack,
    this.onOpenSettings,
  });

  final CameraPermissionStatus status;
  final VoidCallback onRetry;
  final VoidCallback onBack;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isPermanentlyDenied =
        status == CameraPermissionStatus.permanentlyDenied;
    final String message = isPermanentlyDenied
        ? '相机权限已被永久拒绝，请在系统设置中手动开启相机权限后返回应用。'
        : '需要相机权限才能进行拍摄，请授予相机权限。';
    final String actionText = isPermanentlyDenied ? '前往设置' : '重新授权';

    // 前景跟随拍摄外观：immersive=白系（黑底）；theme=tokens（画布底）
    final tokens = ref.watch(themeTokensProvider);
    final isThemed =
        ref.watch(CaptureState.captureAppearanceProvider) ==
            CaptureAppearance.theme;
    final fg = isThemed ? tokens.textPrimary : Colors.white;
    final fgSecondary = isThemed ? tokens.textSecondary : Colors.white70;
    final fgMuted = isThemed ? tokens.textTertiary : Colors.white54;

    return SafeArea(
      child: Stack(
        children: [
          // 返回按钮
          Positioned(
            top: 0,
            left: 0,
            child: LumiraIconButton(
              icon: Icons.arrow_back_ios_new,
              color: fg,
              onPressed: onBack,
            ),
          ),
          // 居中引导内容
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.camera_alt_outlined,
                    size: 64,
                    color: fgMuted,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '相机权限未开启',
                    style: TextStyle(
                      color: fg,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: fgSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // 主操作按钮
                  SizedBox(
                    width: double.infinity,
                    child: LumiraButton(
                      variant: ButtonVariant.primary,
                      onPressed: isPermanentlyDenied
                          ? onOpenSettings
                          : onRetry,
                      child: Text(actionText),
                    ),
                  ),
                  if (isPermanentlyDenied) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: LumiraButton(
                        variant: ButtonVariant.ghost,
                        onPressed: onRetry,
                        child: const Text('返回后重试'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
/// 多姿势模板的「切换姿势」按钮（叠照片浮层）。
/// 仅在 `editableTemplateProvider.poses.length > 1` 时渲染；点击调用
/// [CaptureState.nextPose] 循环切换，剪影随 [CaptureState.currentPoseIndexProvider] 跟随。
/// 背景/描边随当前 UI 风格派生（实心/半透明 surface + 细边，无外阴影、无毛玻璃、不硬编码颜色）。
class CapturePoseSwitchButton extends ConsumerWidget {
  const CapturePoseSwitchButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final poses = ref.watch(CaptureState.editableTemplateProvider)?.poses ??
        const <Pose>[];
    if (poses.length <= 1) return const SizedBox.shrink();
    final idx = ref.watch(CaptureState.currentPoseIndexProvider);

    // 叠在照片上的浮层取向：各风格都用「实心/半透明 surface + 细边」表达表面，
    // 不做模糊、不挂外阴影；glass 风格用其自身的半透明白表达玻璃表面。
    final Color bg;
    final Border border;
    switch (appTheme.style) {
      case UIStyle.neumorphic:
        bg = tokens.surface.withOpacity(0.78);
        border = Border.all(color: tokens.divider.withOpacity(0.7), width: 0.8);
        break;
      case UIStyle.flat:
        bg = tokens.surface.withOpacity(0.75);
        border = Border.all(color: tokens.divider, width: 1);
        break;
      case UIStyle.glass:
        bg = Colors.white.withOpacity(0.22);
        border = Border.all(color: Colors.white.withOpacity(0.35), width: 0.8);
        break;
      case UIStyle.female:
        bg = tokens.surface.withOpacity(0.82);
        border = Border.all(color: tokens.brand.withOpacity(0.15), width: 0.8);
        break;
    }

    return Semantics(
      label: '切换姿势，当前 ${idx + 1} / ${poses.length}',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => CaptureState.nextPose(ref),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: border,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.swap_horiz, size: 16, color: tokens.textPrimary),
              const SizedBox(width: 4),
              Text(
                '${idx + 1}/${poses.length}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
