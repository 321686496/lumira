import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/lumira/_internal/lumira_theme_resolver.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../data/capture_state.dart';
import '../services/camera_service_provider.dart';
import '../services/white_balance.dart';
import 'post_process_adjust_panel.dart';

/// 参数面板工具条条目
enum _ParamTool { ev, wb, flash, color, detail, composition, scene }

/// 拍摄页底部参数面板：图标工具条 + 点选滑出控件区（总高 ≤220）。
///
/// 交互与预览页编辑工具条 / iPhone 原生相机一致：
/// - 点工具图标 → 控件区滑出该组控件；再点同图标 → 收起控件区
/// - 点把手行关闭图标 / 面板外取景器区域 → 关闭整栏（panelExpandedProvider）
///
/// 视觉：容器与强调色全部从当前 UI 风格 + 主题 tokens 派生；叠在取景器
/// 动态画面上，新拟态走「半透明暗底 + 细边」取向（无阴影无模糊铁律，
/// 色值由 [LumiraThemeResolver.darkNeuPalette] 从主题 canvas lerp 派生），
/// 暗色语境文字用白色系（与 ParamPillBar 拍摄页先例一致）。
///
/// 白平衡应用逻辑（预设→色温联动、OHOS 隐藏色温滑块、iOS 残差拉取）
/// 与旧版一致，仅迁移位置。
class ParamPanel extends ConsumerStatefulWidget {
  const ParamPanel({super.key});

  @override
  ConsumerState<ParamPanel> createState() => _ParamPanelState();
}

class _ParamPanelState extends ConsumerState<ParamPanel> {
  /// 控件区固定高度：pill 行 + 滑块 / AdjustPanel 均按此设计
  static const _controlH = 132.0;

  _ParamTool? _activeTool;

  void _close() {
    ref.read(CaptureState.panelExpandedProvider.notifier).state = false;
  }

  void _toggleTool(_ParamTool tool) {
    setState(() => _activeTool = _activeTool == tool ? null : tool);
    HapticFeedback.lightImpact();
  }

  void _reset() {
    final editable = ref.read(CaptureState.editableTemplateProvider);
    final original = ref.read(CaptureState.originalTemplateProvider);
    if (editable != null && original != null) {
      // 模板模式：重置为模板原始值
      ref.read(CaptureState.editableTemplateProvider.notifier).state =
          original.copyWith();
    } else {
      // 自由模式：重置为默认值并持久化
      CaptureState.resetFreeModeParams(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expanded = ref.watch(CaptureState.panelExpandedProvider);
    final theme = ref.watch(appThemeProvider);
    final tokens = theme.tokens;
    final style = theme.style;
    final accent = tokens.brand;
    final hasTemplate =
        ref.watch(CaptureState.editableTemplateProvider) != null;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Stack(
      children: [
        // 点击面板外取景器区域关闭整栏（面板本体在其上层，不受影响）
        if (expanded)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _close,
              child: const SizedBox.expand(),
            ),
          ),
        // 面板本体：底部贴边 + AnimatedSlide 进出（高度由内容自然撑开，
        // 控件区用 AnimatedSize 滑出，避免固定高容器在动画期溢出）
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            offset: expanded ? Offset.zero : const Offset(0, 1.2),
            child: _panelShell(
              style: style,
              tokens: tokens,
              bottomInset: bottomInset,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HandleRow(
                    hasTemplate: hasTemplate,
                    accent: accent,
                    onReset: _reset,
                    onClose: _close,
                  ),
                  _ToolbarRow(
                    activeTool: _activeTool,
                    accent: accent,
                    onToolTap: _toggleTool,
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: _activeTool == null
                        ? const SizedBox.shrink()
                        : SizedBox(
                            height: _controlH,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: KeyedSubtree(
                                key: ValueKey(_activeTool),
                                child: _buildControl(accent),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── 面板外壳：按当前 UI 风格派生暗色语境视觉 ──

  Widget _panelShell({
    required UIStyle style,
    required ThemeTokens tokens,
    required double bottomInset,
    required Widget child,
  }) {
    const radius = BorderRadius.vertical(top: Radius.circular(24));
    final palette = LumiraThemeResolver.darkNeuPalette(tokens);
    Widget body;
    switch (style) {
      case UIStyle.glass:
        // 暗玻璃：毛玻璃 + 近黑半透明底（ParamPillBar 玻璃胶囊同取向）
        body = ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: EdgeInsets.only(bottom: bottomInset),
              decoration: BoxDecoration(
                color: palette.surface.withOpacity(0.80),
                borderRadius: radius,
                border: Border.all(
                    color: Colors.white.withOpacity(0.10), width: 0.5),
              ),
              child: child,
            ),
          ),
        );
        break;
      case UIStyle.female:
        // 暗渐变：黑 → 品牌微染，柔和细边
        body = Container(
          padding: EdgeInsets.only(bottom: bottomInset),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.82),
                Color.lerp(Colors.black, tokens.brand, 0.16)!
                    .withOpacity(0.84),
              ],
            ),
            borderRadius: radius,
            border: Border.all(
                color: Colors.white.withOpacity(0.08), width: 0.6),
          ),
          child: child,
        );
        break;
      case UIStyle.neumorphic:
        // 新拟态叠动态画面：半透明暗底 + 细边（无阴影无模糊铁律）
        body = Container(
          padding: EdgeInsets.only(bottom: bottomInset),
          decoration: BoxDecoration(
            color: palette.surface.withOpacity(0.94),
            borderRadius: radius,
            border: Border.all(
                color: Colors.white.withOpacity(0.14), width: 0.6),
          ),
          child: child,
        );
        break;
      case UIStyle.flat:
        // 扁平：半透明暗底 + 细边
        body = Container(
          padding: EdgeInsets.only(bottom: bottomInset),
          decoration: BoxDecoration(
            color: palette.surface.withOpacity(0.92),
            borderRadius: radius,
            border: Border.all(
                color: Colors.white.withOpacity(0.08), width: 0.5),
          ),
          child: child,
        );
        break;
    }
    return body;
  }

  // ── 控件区内容分发 ──

  Widget _buildControl(Color accent) {
    switch (_activeTool!) {
      case _ParamTool.ev:
        return _EvControl(accent: accent);
      case _ParamTool.wb:
        return _WbControl(accent: accent);
      case _ParamTool.flash:
        return _FlashControl(accent: accent);
      case _ParamTool.color:
        return AdjustPanel(
          defs: colorAdjustDefs(),
          full: ref.watch(CaptureState.effectivePostProcessProvider),
          onChanged: (p) => CaptureState.updatePostProcess(ref, (_) => p),
          accentColor: accent,
        );
      case _ParamTool.detail:
        return AdjustPanel(
          defs: detailAdjustDefs(),
          full: ref.watch(CaptureState.effectivePostProcessProvider),
          onChanged: (p) => CaptureState.updatePostProcess(ref, (_) => p),
          accentColor: accent,
        );
      case _ParamTool.composition:
        return const _CompositionControl();
      case _ParamTool.scene:
        return const _SceneControl();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// 把手行
// ─────────────────────────────────────────────────────────────────────

/// 把手行：拖动条 + 模板/自由徽标 + 重置 pill + 关闭图标
class _HandleRow extends StatelessWidget {
  const _HandleRow({
    required this.hasTemplate,
    required this.accent,
    required this.onReset,
    required this.onClose,
  });

  final bool hasTemplate;
  final Color accent;
  final VoidCallback onReset;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 6),
      child: Row(
        children: [
          // 拖动条（装饰）
          Container(
            width: 24,
            height: 3,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: hasTemplate
                  ? accent.withOpacity(0.15)
                  : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              hasTemplate ? '模板' : '自由',
              style: TextStyle(
                color: hasTemplate ? accent : Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onReset,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.refresh, size: 12, color: Colors.white70),
                  SizedBox(width: 4),
                  Text('重置',
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          LumiraIconButton(
            icon: Icons.close,
            onPressed: onClose,
            color: Colors.white70,
            size: 16,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 图标工具条
// ─────────────────────────────────────────────────────────────────────

/// 图标工具条：7 项单行（曝光/白平衡/闪光/色彩/细节/构图/场景）
class _ToolbarRow extends StatelessWidget {
  const _ToolbarRow({
    required this.activeTool,
    required this.accent,
    required this.onToolTap,
  });

  final _ParamTool? activeTool;
  final Color accent;
  final ValueChanged<_ParamTool> onToolTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToolItem(
            icon: Icons.exposure,
            label: '曝光',
            selected: activeTool == _ParamTool.ev,
            accent: accent,
            onTap: () => onToolTap(_ParamTool.ev),
          ),
          _ToolItem(
            icon: Icons.wb_sunny_outlined,
            label: '白平衡',
            selected: activeTool == _ParamTool.wb,
            accent: accent,
            onTap: () => onToolTap(_ParamTool.wb),
          ),
          _ToolItem(
            icon: Icons.flash_on_outlined,
            label: '闪光',
            selected: activeTool == _ParamTool.flash,
            accent: accent,
            onTap: () => onToolTap(_ParamTool.flash),
          ),
          _ToolItem(
            icon: Icons.tune,
            label: '色彩',
            selected: activeTool == _ParamTool.color,
            accent: accent,
            onTap: () => onToolTap(_ParamTool.color),
          ),
          _ToolItem(
            icon: Icons.auto_fix_high_outlined,
            label: '细节',
            selected: activeTool == _ParamTool.detail,
            accent: accent,
            onTap: () => onToolTap(_ParamTool.detail),
          ),
          _ToolItem(
            icon: Icons.grid_4x4_outlined,
            label: '构图',
            selected: activeTool == _ParamTool.composition,
            accent: accent,
            onTap: () => onToolTap(_ParamTool.composition),
          ),
          _ToolItem(
            icon: Icons.tips_and_updates_outlined,
            label: '场景',
            selected: activeTool == _ParamTool.scene,
            accent: accent,
            onTap: () => onToolTap(_ParamTool.scene),
          ),
        ],
      ),
    );
  }
}

/// 单个工具项：图标 + 文字，选中态 accent 高亮 + 胶囊底
class _ToolItem extends StatelessWidget {
  const _ToolItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? accent : Colors.white70;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? accent.withOpacity(0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(1000),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 控件区：曝光 / 白平衡 / 闪光 / 构图 / 场景
// ─────────────────────────────────────────────────────────────────────

/// 曝光 EV 单滑块
class _EvControl extends ConsumerWidget {
  const _EvControl({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cam = ref.watch(CaptureState.effectiveCameraProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: AdjustSlider(
        label: 'EV',
        value: cam.exposureCompensation,
        min: -3,
        max: 3,
        accentColor: accent,
        format: (v) =>
            v >= 0 ? '+${v.toStringAsFixed(1)}' : v.toStringAsFixed(1),
        onChanged: (v) => CaptureState.updateCamera(
            ref, (c) => c.copyWith(exposureCompensation: v)),
      ),
    );
  }
}

/// 白平衡：预设 pill + 色温滑块（自旧 _CameraTab 原样迁移）
class _WbControl extends ConsumerWidget {
  const _WbControl({required this.accent});

  final Color accent;

  /// 白平衡预设 pill（mode → 显示名）。
  static const _wbPresets = <WhiteBalanceMode, String>{
    WhiteBalanceMode.auto: '自动',
    WhiteBalanceMode.daylight: '日光',
    WhiteBalanceMode.cloudy: '阴天',
    WhiteBalanceMode.fluorescent: '荧光',
    WhiteBalanceMode.incandescent: '白炽',
  };

  /// 预设 → 色温(K)。与 iOS 原生映射保持一致，用于 iOS/Android 预设点击
  /// 时把滑块联动到对应档位（两者底层同为锁定色温）。OHOS 不使用。
  static const _wbPresetK = <WhiteBalanceMode, int>{
    WhiteBalanceMode.daylight: 5500,
    WhiteBalanceMode.cloudy: 6500,
    WhiteBalanceMode.fluorescent: 4200,
    WhiteBalanceMode.incandescent: 3000,
  };

  /// 应用白平衡设置：写入会话 provider + 实时下发取景器。
  /// 仅实时会话调节，**不写入 CameraParams**。
  /// 随后拉取 iOS 硬件「残差」（软封顶削减比），供软件矩阵补足
  ///（极值色温下取景器局部冷/暖色丢失的修复，见 white_balance.dart）。
  void _apply(WidgetRef ref, WhiteBalanceSettings s) {
    ref.read(whiteBalanceSessionProvider.notifier).state = s;
    ref.read(cameraServiceProvider).setWhiteBalance(s);
    refreshWbResidual(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wb = ref.watch(whiteBalanceSessionProvider);
    // OHOS 连续色温（setWhiteBalance/getWhiteBalanceRange）真机不可用，
    // 传感器级手动值无法落地，仅保留预设 pill，隐藏色温滑块。
    final showWbSlider = Platform.isAndroid || Platform.isIOS;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      children: [
        _WbPresetRow(
          presets: _wbPresets,
          selected: wb.mode,
          accent: accent,
          onSelected: (mode) {
            if (mode == WhiteBalanceMode.auto) {
              // 切回 Auto：temperatureK 置 null，插件端 auto 复位
              _apply(ref, const WhiteBalanceSettings());
            } else {
              // 非 Auto 预设。iOS/Android：预设与色温滑块底层同为“锁定色温”，
              // 预设点击时把 temperatureK 联动到对应档位，使滑块跟随；
              // OHOS：预设走原生 mode 分支，temperatureK 保持 null。
              _apply(
                ref,
                showWbSlider
                    ? WhiteBalanceSettings(
                        mode: mode, temperatureK: _wbPresetK[mode])
                    : WhiteBalanceSettings(mode: mode),
              );
            }
          },
        ),
        if (showWbSlider && !wb.isAuto)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: AdjustSlider(
              label: '色温',
              value: (wb.temperatureK ?? 5500).toDouble(),
              min: 3000,
              max: 8000,
              accentColor: accent,
              format: (v) => '${(v / 100).round() * 100} K',
              onChanged: (v) => _apply(
                ref,
                WhiteBalanceSettings(
                  mode: wb.mode,
                  temperatureK: (v / 100).round() * 100,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 闪光：4 选项 pill 单选
class _FlashControl extends ConsumerWidget {
  const _FlashControl({required this.accent});

  final Color accent;

  static const _flashChoices = [
    _ChoiceItem('off', '关闭'),
    _ChoiceItem('on', '常亮'),
    _ChoiceItem('auto', '自动'),
    _ChoiceItem('torch', '手电筒'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cam = ref.watch(CaptureState.effectiveCameraProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: _ChoicePillRow(
        items: _flashChoices,
        selected: cam.flashMode,
        accent: accent,
        onSelected: (v) =>
            CaptureState.updateCamera(ref, (c) => c.copyWith(flashMode: v)),
      ),
    );
  }
}

/// 构图：辅助线类型 pill + 透明度滑块
class _CompositionControl extends ConsumerWidget {
  const _CompositionControl();

  static const _overlayTypes = [
    _ChoiceItem('rule_of_thirds', '三分法'),
    _ChoiceItem('golden_ratio', '黄金比例'),
    _ChoiceItem('center', '居中'),
    _ChoiceItem('diagonal', '对角线'),
    _ChoiceItem('symmetry', '对称'),
    _ChoiceItem('none', '无'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comp = ref.watch(CaptureState.effectiveCompositionProvider);
    final accent = ref.watch(appThemeProvider).tokens.brand;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      children: [
        _ChoicePillRow(
          items: _overlayTypes,
          selected: comp.overlayType,
          accent: accent,
          onSelected: (v) => CaptureState.updateComposition(
              ref, (c) => c.copyWith(overlayType: v)),
        ),
        const SizedBox(height: 8),
        AdjustSlider(
          label: '透明度',
          value: comp.opacity,
          min: 0,
          max: 1,
          accentColor: accent,
          format: (v) => '${(v * 100).round()}%',
          onChanged: (v) => CaptureState.updateComposition(
              ref, (c) => c.copyWith(opacity: v)),
        ),
      ],
    );
  }
}

/// 场景指南：紧凑 label:value 只读列表（自旧 _SceneTab 迁移）
class _SceneControl extends ConsumerWidget {
  const _SceneControl();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sg = ref.watch(CaptureState.effectiveSceneGuideProvider);

    // 自由模式返回空 SceneGuide（字段全空）：所有展示字段均无内容 → 空态
    final hasGuide = sg.lightDirection.isNotEmpty ||
        sg.shootingDistance.isNotEmpty ||
        sg.background.isNotEmpty ||
        sg.bestTime.isNotEmpty ||
        sg.presetId != null ||
        sg.bestTimeFrom != null ||
        sg.bestTimeTo != null ||
        sg.props.isNotEmpty ||
        sg.tips.isNotEmpty;

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

    if (!hasGuide) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('当前为自由模式，无场景指南',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
            SizedBox(height: 4),
            Text('选择场景预设或套用模板后可查看',
                style: TextStyle(color: Colors.white24, fontSize: 10)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 64,
                  child: Text(row.key,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 10)),
                ),
                Expanded(
                  child: Text(
                    row.value.isEmpty ? '—' : row.value,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11, height: 1.4),
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
// 通用 pill 组件
// ─────────────────────────────────────────────────────────────────────

/// 选项键值对（泛型 pill 行的条目）
class _ChoiceItem {
  final String value;
  final String label;
  const _ChoiceItem(this.value, this.label);
}

/// 通用选项 pill 行（暗色语境）：胶囊单选，选中态 accent
class _ChoicePillRow extends StatelessWidget {
  const _ChoicePillRow({
    required this.items,
    required this.selected,
    required this.accent,
    required this.onSelected,
  });

  final List<_ChoiceItem> items;
  final String selected;
  final Color accent;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          GestureDetector(
            onTap: () => onSelected(item.value),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: item.value == selected
                    ? accent.withOpacity(0.18)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: item.value == selected
                      ? accent.withOpacity(0.6)
                      : Colors.white.withOpacity(0.08),
                  width: item.value == selected ? 1 : 0.5,
                ),
              ),
              child: Text(
                item.label,
                style: TextStyle(
                  color: item.value == selected ? accent : Colors.white70,
                  fontSize: 12,
                  fontWeight: item.value == selected
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 白平衡预设 pill 行 — 胶囊式单选（自旧版迁移，强调色主题化）
class _WbPresetRow extends StatelessWidget {
  const _WbPresetRow({
    required this.presets,
    required this.selected,
    required this.accent,
    required this.onSelected,
  });

  final Map<WhiteBalanceMode, String> presets;
  final WhiteBalanceMode selected;
  final Color accent;
  final ValueChanged<WhiteBalanceMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: presets.entries.map((e) {
        final active = e.key == selected;
        return GestureDetector(
          onTap: () => onSelected(e.key),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: active
                  ? accent.withOpacity(0.18)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: active
                    ? accent.withOpacity(0.6)
                    : Colors.white.withOpacity(0.08),
                width: active ? 1 : 0.5,
              ),
            ),
            child: Text(
              e.value,
              style: TextStyle(
                color: active ? accent : Colors.white70,
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
