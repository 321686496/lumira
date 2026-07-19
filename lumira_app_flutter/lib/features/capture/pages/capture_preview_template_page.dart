import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../templates/data/templates_editor_mock_data.dart';
import '../../templates/widgets/composition_overlay.dart';
import '../../templates/widgets/pose_silhouette.dart';
import '../data/capture_preview_mock_data.dart';

/// 模板预览页（Task 2.9A）
///
/// 视觉规格来源：lumira-app/src/pages/capture/preview-template.vue (754 行)
/// - 沉浸式自定义导航（不用 LumiraNav — brief §3.2 明示偏离）
/// - 取景器（3:4 AspectRatio + 背景图 + 遮罩 + CompositionOverlay + 可拖动 PoseSilhouette）
/// - 参数 pill 栏（EV/ISO/SS/WB）
/// - 折叠调整面板（4 slider 区 + 4 seg-btn 组）
/// - 同步按钮（SnackBar + pop）
///
/// 已知简化决策（brief §8）：
/// - CSS filter 滤镜预览省略（Flutter 无等价 API）
/// - 同步到编辑器：mock SnackBar + pop，不实际写回 EditorForm
class CapturePreviewTemplatePage extends ConsumerStatefulWidget {
  const CapturePreviewTemplatePage({
    super.key,
    this.templateId,
    this.draftId,
  });

  /// 路由参数：templateId（预览已有模板）
  final String? templateId;

  /// 路由参数：draftId（预览草稿，优先于 templateId）
  final String? draftId;

  @override
  ConsumerState<CapturePreviewTemplatePage> createState() =>
      _CapturePreviewTemplatePageState();
}

class _CapturePreviewTemplatePageState
    extends ConsumerState<CapturePreviewTemplatePage> {
  EditorForm? _template;
  bool _panelExpanded = false;
  bool _flashOn = false;
  bool _isDraggingSilhouette = false;

  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  void _loadTemplate() {
    EditorForm? loaded;
    // 优先 draftId，其次 templateId（与 uni-app onLoad 一致）
    if (widget.draftId != null && widget.draftId!.isNotEmpty) {
      loaded = CapturePreviewMockData.loadDraftById(widget.draftId);
    } else if (widget.templateId != null && widget.templateId!.isNotEmpty) {
      loaded = CapturePreviewMockData.loadTemplateById(widget.templateId);
    }

    if (loaded != null) {
      _template = loaded;
    } else {
      // 加载失败：SnackBar + 1000ms 后 pop（brief §3.2 + §6.3 mounted 检查）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('模板加载失败')),
        );
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (!mounted) return;
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            GoRouter.of(context).go(RouteNames.capture);
          }
        });
      });
    }
  }

  // ===== 事件处理 =====

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.of(context).go(RouteNames.capture);
    }
  }

  void _toggleFlash() {
    setState(() {
      _flashOn = !_flashOn;
    });
  }

  void _togglePanel() {
    setState(() {
      _panelExpanded = !_panelExpanded;
    });
  }

  // ===== 剪影拖动 =====

  void _onSilhouetteDragStart(DragStartDetails details) {
    setState(() {
      _isDraggingSilhouette = true;
    });
  }

  void _onSilhouetteDragUpdate(
      DragUpdateDetails details, BoxConstraints constraints) {
    final tpl = _template;
    if (tpl == null) return;
    setState(() {
      final dx = details.delta.dx / constraints.maxWidth;
      final dy = details.delta.dy / constraints.maxHeight;
      tpl.pose.position.x = (tpl.pose.position.x + dx).clamp(0.0, 1.0);
      tpl.pose.position.y = (tpl.pose.position.y + dy).clamp(0.0, 1.0);
    });
  }

  void _onSilhouetteDragEnd(DragEndDetails details) {
    setState(() {
      _isDraggingSilhouette = false;
    });
  }

  // ===== 表单变更 =====

  void _mutate(void Function() mutator) {
    setState(mutator);
  }

  // ===== 同步按钮 =====

  void _onSyncBack() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已同步到编辑器')),
    );
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        GoRouter.of(context).go(RouteNames.templates);
      }
    });
  }

  // ===== 格式化 =====

  String _formatEvDisplay(double ev) {
    return ev > 0 ? '+$ev' : '$ev';
  }

  String _formatWbDisplay(int k) {
    return '${k}K';
  }

  String get _categoryLabel {
    const map = {
      'portrait': '人像',
      'landscape': '风光',
      'food': '美食',
      'street': '街拍',
      'night': '夜景',
      'macro': '微距',
      'still-life': '静物',
    };
    final cat = _template?.meta.category ?? '';
    return map[cat] ?? cat;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);

    return Scaffold(
      // 硬编码颜色，与 uni-app 一致 (capture-page bg #181614)
      backgroundColor: const Color(0xFF181614),
      body: SafeArea(
        child: Column(
          children: [
            _PreviewTemplateNav(
              tokens: tokens,
              template: _template,
              categoryLabel: _categoryLabel,
              flashOn: _flashOn,
              onBack: _back,
              onToggleFlash: _toggleFlash,
            ),
            Expanded(
              child: _Viewfinder(
                tokens: tokens,
                template: _template,
                isDragging: _isDraggingSilhouette,
                onSilhouetteDragStart: _onSilhouetteDragStart,
                onSilhouetteDragUpdate: _onSilhouetteDragUpdate,
                onSilhouetteDragEnd: _onSilhouetteDragEnd,
                formatEv: _formatEvDisplay,
                formatWb: _formatWbDisplay,
              ),
            ),
            if (_template != null)
              _AdjustPanel(
                tokens: tokens,
                template: _template!,
                panelExpanded: _panelExpanded,
                onTogglePanel: _togglePanel,
                onChange: _mutate,
              ),
            _SyncButton(onTap: _onSyncBack),
          ],
        ),
      ),
    );
  }
}

/// 顶部沉浸式导航（Stack 布局：返回按钮 / 标题+副标题 / 闪光灯切换）
/// 不用 LumiraNav — brief §3.2 明示偏离（沉浸式自定义导航与 LumiraNav 视觉规格不同）
class _PreviewTemplateNav extends StatelessWidget {
  const _PreviewTemplateNav({
    required this.tokens,
    required this.template,
    required this.categoryLabel,
    required this.flashOn,
    required this.onBack,
    required this.onToggleFlash,
  });

  final ThemeTokens tokens;
  final EditorForm? template;
  final String categoryLabel;
  final bool flashOn;
  final VoidCallback onBack;
  final VoidCallback onToggleFlash;

  @override
  Widget build(BuildContext context) {
    final title = template?.meta.name ?? '模板预览';
    final hasSub = template != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _NavCircleButton(
            icon: Icons.arrow_back_ios_new,
            onTap: onBack,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    // 硬编码颜色，与 uni-app 一致 (nav-title color #fff)
                    color: Colors.white,
                  ),
                ),
                if (hasSub)
                  Text(
                    '$categoryLabel · ${template!.composition.aspectRatio}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      // 硬编码颜色，与 uni-app 一致 (nav-sub color rgba(255,255,255,0.7))
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
              ],
            ),
          ),
          _NavCircleButton(
            icon: flashOn ? Icons.flash_on : Icons.flash_off,
            active: flashOn,
            onTap: onToggleFlash,
          ),
        ],
      ),
    );
  }
}

class _NavCircleButton extends StatelessWidget {
  const _NavCircleButton({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          // 硬编码颜色，与 uni-app 一致 (nav-back bg rgba(0,0,0,0.35) / nav-action.active bg rgba(201,169,110,0.7))
          color: active
              ? const Color.fromRGBO(201, 169, 110, 0.7)
              : const Color.fromRGBO(0, 0, 0, 0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 16,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// 取景器（AspectRatio + Stack：bg image / mask / CompositionOverlay / draggable pose / param pills）
class _Viewfinder extends StatelessWidget {
  const _Viewfinder({
    required this.tokens,
    required this.template,
    required this.isDragging,
    required this.onSilhouetteDragStart,
    required this.onSilhouetteDragUpdate,
    required this.onSilhouetteDragEnd,
    required this.formatEv,
    required this.formatWb,
  });

  final ThemeTokens tokens;
  final EditorForm? template;
  final bool isDragging;
  final void Function(DragStartDetails) onSilhouetteDragStart;
  final void Function(DragUpdateDetails, BoxConstraints) onSilhouetteDragUpdate;
  final void Function(DragEndDetails) onSilhouetteDragEnd;
  final String Function(double) formatEv;
  final String Function(int) formatWb;

  @override
  Widget build(BuildContext context) {
    if (template == null) {
      return const SizedBox.shrink();
    }
    final tpl = template!;
    final aspectRatio = parseAspectRatio(tpl.composition.aspectRatio);
    final hasSilhouette = !(tpl.pose.silhouette.type == 'builtin' &&
        tpl.pose.silhouette.data == 'none');

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(0),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 背景图
                      Image.network(
                        'https://picsum.photos/seed/lumira-template-cover/800/1067',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          // 硬编码颜色，与 uni-app 一致 (viewfinder bg fallback #181614)
                          color: const Color(0xFF181614),
                        ),
                      ),
                      // 遮罩
                      // 硬编码颜色，与 uni-app 一致 (viewfinder-mask bg rgba(24,22,20,0.35))
                      const ColoredBox(
                        color: Color.fromRGBO(24, 22, 20, 0.35),
                      ),
                      // 构图叠图
                      CompositionOverlay(
                        overlayType: tpl.composition.overlayType,
                        opacity: tpl.composition.opacity,
                      ),
                      // 可拖动剪影
                      if (hasSilhouette)
                        GestureDetector(
                          onPanStart: onSilhouetteDragStart,
                          onPanUpdate: (details) =>
                              onSilhouetteDragUpdate(details, constraints),
                          onPanEnd: onSilhouetteDragEnd,
                          behavior: HitTestBehavior.opaque,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Positioned(
                                left: constraints.maxWidth * tpl.pose.position.x,
                                top: constraints.maxHeight * tpl.pose.position.y,
                                child: FractionalTranslation(
                                  translation: const Offset(-0.5, -0.5),
                                  child: PoseSilhouette(
                                    silhouetteType:
                                        tpl.pose.silhouette.type,
                                    silhouetteData:
                                        tpl.pose.silhouette.data,
                                    scale: tpl.pose.scale,
                                    rotation: tpl.pose.rotation,
                                  ),
                                ),
                              ),
                              // 拖动提示
                              if (!isDragging)
                                Positioned(
                                  bottom: 12,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        // 硬编码颜色，与 uni-app 一致 (drag-hint bg rgba(0,0,0,0.5))
                                        color: const Color.fromRGBO(
                                            0, 0, 0, 0.5),
                                        borderRadius:
                                            BorderRadius.circular(9999),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.open_with,
                                            size: 12,
                                            color: Colors.white
                                                .withOpacity(0.8),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '拖动调整剪影位置',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.white
                                                  .withOpacity(0.8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        // 参数 pill 栏（Positioned 在取景器上方）
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: _ParamPillBar(
            template: tpl,
            formatEv: formatEv,
            formatWb: formatWb,
          ),
        ),
      ],
    );
  }
}

/// 参数 pill 栏（4 个 pill：EV / ISO / SS / WB）
class _ParamPillBar extends StatelessWidget {
  const _ParamPillBar({
    required this.template,
    required this.formatEv,
    required this.formatWb,
  });

  final EditorForm template;
  final String Function(double) formatEv;
  final String Function(int) formatWb;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ParamPill(label: 'EV', value: formatEv(template.camera.exposureCompensation)),
            const SizedBox(width: 8),
            _ParamPill(label: 'ISO', value: '${template.camera.iso}'),
            const SizedBox(width: 8),
            _ParamPill(label: 'SS', value: template.camera.shutterSpeed),
            const SizedBox(width: 8),
            _ParamPill(label: 'WB', value: formatWb(template.camera.whiteBalanceK)),
          ],
        ),
      ),
    );
  }
}

class _ParamPill extends StatelessWidget {
  const _ParamPill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        // 硬编码颜色，与 uni-app 一致 (param-pill bg rgba(0,0,0,0.5))
        color: const Color.fromRGBO(0, 0, 0, 0.5),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              // 硬编码颜色，与 uni-app 一致 (pill-label color rgba(255,255,255,0.6))
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              // 硬编码颜色，与 uni-app 一致 (pill-value color #fff, font-family Courier New)
              color: Colors.white,
              fontFamily: 'SF Mono',
            ),
          ),
        ],
      ),
    );
  }
}

/// 折叠调整面板
class _AdjustPanel extends StatelessWidget {
  const _AdjustPanel({
    required this.tokens,
    required this.template,
    required this.panelExpanded,
    required this.onTogglePanel,
    required this.onChange,
  });

  final ThemeTokens tokens;
  final EditorForm template;
  final bool panelExpanded;
  final VoidCallback onTogglePanel;
  final void Function(void Function() mutator) onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      // 硬编码颜色，与 uni-app 一致 (adjust-panel bg rgba(24,22,20,0.9))
      color: const Color.fromRGBO(24, 22, 20, 0.9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PanelHeader(
            expanded: panelExpanded,
            onTap: onTogglePanel,
          ),
          if (panelExpanded)
            SizedBox(
              height: 300,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CompositionSection(
                      template: template,
                      onChange: onChange,
                    ),
                    _CameraSection(
                      template: template,
                      onChange: onChange,
                    ),
                    _PostProcessSection(
                      template: template,
                      onChange: onChange,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.expanded, required this.onTap});
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
              size: 14,
              // 硬编码颜色，与 uni-app 一致 (panel-header .ph color rgba(255,255,255,0.6))
              color: Colors.white.withOpacity(0.6),
            ),
            const SizedBox(width: 6),
            const Text(
              '参数调整',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                // 硬编码颜色，与 uni-app 一致 (panel-title color #fff)
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '实时调整模板参数',
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  // 硬编码颜色，与 uni-app 一致 (panel-hint color rgba(255,255,255,0.4))
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 构图区（叠图透明度 slider）
class _CompositionSection extends StatelessWidget {
  const _CompositionSection({required this.template, required this.onChange});
  final EditorForm template;
  final void Function(void Function() mutator) onChange;

  @override
  Widget build(BuildContext context) {
    return _AdjustSection(
      title: '构图',
      children: [
        _SliderRow(
          label: '叠图透明度',
          value: template.composition.opacity * 100,
          min: 0,
          max: 100,
          divisions: 20,
          onChanged: (v) => onChange(() {
            template.composition.opacity = v / 100;
          }),
          valueText: '${(template.composition.opacity * 100).round()}',
        ),
      ],
    );
  }
}

/// 相机参数区（EV/ISO/WBK sliders + WB/Flash/Focus seg-btns）
class _CameraSection extends StatelessWidget {
  const _CameraSection({required this.template, required this.onChange});
  final EditorForm template;
  final void Function(void Function() mutator) onChange;

  @override
  Widget build(BuildContext context) {
    return _AdjustSection(
      title: '相机参数',
      children: [
        _SliderRow(
          label: '曝光补偿',
          value: template.camera.exposureCompensation,
          min: -3,
          max: 3,
          divisions: 20,
          onChanged: (v) => onChange(() {
            template.camera.exposureCompensation =
                double.parse(v.toStringAsFixed(1));
          }),
          valueText: '${formatEvSlider(template.camera.exposureCompensation)} EV',
        ),
        _SliderRow(
          label: 'ISO',
          value: template.camera.iso.toDouble(),
          min: 50,
          max: 6400,
          divisions: 127,
          onChanged: (v) => onChange(() {
            template.camera.iso = v.round();
          }),
          valueText: '${template.camera.iso}',
        ),
        _SliderRow(
          label: '色温 K',
          value: template.camera.whiteBalanceK.toDouble(),
          min: 2500,
          max: 10000,
          divisions: 75,
          onChanged: (v) => onChange(() {
            template.camera.whiteBalanceK = v.round();
          }),
          valueText: '${template.camera.whiteBalanceK}K',
        ),
        _SegBtnRow(
          label: '白平衡',
          options: PreviewTemplateOptions.whiteBalance,
          value: template.camera.whiteBalance,
          onChanged: (v) => onChange(() {
            template.camera.whiteBalance = v;
          }),
        ),
        _SegBtnRow(
          label: '闪光',
          options: PreviewTemplateOptions.flashMode,
          value: template.camera.flashMode,
          onChanged: (v) => onChange(() {
            template.camera.flashMode = v;
          }),
        ),
        _SegBtnRow(
          label: '对焦',
          options: PreviewTemplateOptions.focusMode,
          value: template.camera.focusMode,
          onChanged: (v) => onChange(() {
            template.camera.focusMode = v;
          }),
        ),
      ],
    );
  }
}

/// 后期参数区（LUT seg-btns + brightness/contrast/saturation/temperature/smooth/sharpen/vignette sliders）
class _PostProcessSection extends StatelessWidget {
  const _PostProcessSection({required this.template, required this.onChange});
  final EditorForm template;
  final void Function(void Function() mutator) onChange;

  @override
  Widget build(BuildContext context) {
    return _AdjustSection(
      title: '后期调色',
      children: [
        _SegBtnRow(
          label: 'LUT 预设',
          options: PreviewTemplateOptions.lutPreset,
          value: template.postProcess.lut,
          onChanged: (v) => onChange(() {
            template.postProcess.lut = v;
          }),
        ),
        _SliderRow(
          label: '亮度',
          value: template.postProcess.color.brightness.toDouble(),
          min: -100,
          max: 100,
          divisions: 200,
          onChanged: (v) => onChange(() {
            template.postProcess.color.brightness = v.round();
          }),
          valueText: formatSigned(template.postProcess.color.brightness),
        ),
        _SliderRow(
          label: '对比度',
          value: template.postProcess.color.contrast.toDouble(),
          min: -100,
          max: 100,
          divisions: 200,
          onChanged: (v) => onChange(() {
            template.postProcess.color.contrast = v.round();
          }),
          valueText: formatSigned(template.postProcess.color.contrast),
        ),
        _SliderRow(
          label: '饱和度',
          value: template.postProcess.color.saturation.toDouble(),
          min: -100,
          max: 100,
          divisions: 200,
          onChanged: (v) => onChange(() {
            template.postProcess.color.saturation = v.round();
          }),
          valueText: formatSigned(template.postProcess.color.saturation),
        ),
        _SliderRow(
          label: '色温',
          value: template.postProcess.color.temperature.toDouble(),
          min: -100,
          max: 100,
          divisions: 200,
          onChanged: (v) => onChange(() {
            template.postProcess.color.temperature = v.round();
          }),
          valueText: formatSigned(template.postProcess.color.temperature),
        ),
        _SliderRow(
          label: '磨皮',
          value: template.postProcess.smoothStrength.toDouble(),
          min: 0,
          max: 100,
          divisions: 100,
          onChanged: (v) => onChange(() {
            template.postProcess.smoothStrength = v.round();
          }),
          valueText: '${template.postProcess.smoothStrength}',
        ),
        _SliderRow(
          label: '锐化',
          value: template.postProcess.sharpen.toDouble(),
          min: 0,
          max: 100,
          divisions: 100,
          onChanged: (v) => onChange(() {
            template.postProcess.sharpen = v.round();
          }),
          valueText: '${template.postProcess.sharpen}',
        ),
        _SliderRow(
          label: '暗角',
          value: template.postProcess.vignette.toDouble(),
          min: 0,
          max: 100,
          divisions: 100,
          onChanged: (v) => onChange(() {
            template.postProcess.vignette = v.round();
          }),
          valueText: '${template.postProcess.vignette}',
        ),
      ],
    );
  }
}

/// 调整区容器
class _AdjustSection extends StatelessWidget {
  const _AdjustSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          // 硬编码颜色，与 uni-app 一致 (adjust-section border-bottom rgba(255,255,255,0.06))
          bottom: BorderSide(
            color: Color.fromRGBO(255, 255, 255, 0.06),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                // 硬编码颜色，与 uni-app 一致 (section-title color rgba(201,169,110,0.9))
                color: const Color(0xFFC9A96E).withOpacity(0.9),
                letterSpacing: 0.4,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// 调整行 — slider
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.valueText,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final String valueText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                // 硬编码颜色，与 uni-app 一致 (row-label color rgba(255,255,255,0.7))
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              activeColor: const Color(0xFFC9A96E),
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              valueText,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                // 硬编码颜色，与 uni-app 一致 (row-value color #fff, font-family Courier New)
                color: Colors.white,
                fontFamily: 'SF Mono',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 调整行 — seg-btns
class _SegBtnRow extends StatelessWidget {
  const _SegBtnRow({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<PreviewTemplateOption> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                // 硬编码颜色，与 uni-app 一致 (row-label color rgba(255,255,255,0.7))
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: options.map((o) {
              final active = o.value == value;
              return GestureDetector(
                onTap: () => onChanged(o.value),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    // 硬编码颜色，与 uni-app 一致 (seg-btn.active bg rgba(201,169,110,0.9) / inactive bg rgba(255,255,255,0.08))
                    color: active
                        ? const Color(0xFFC9A96E).withOpacity(0.9)
                        : Colors.white.withOpacity(0.08),
                    // 硬编码颜色，与 uni-app 一致 (seg-btn border rgba(255,255,255,0.12))
                    border: Border.all(
                      color: active
                          ? const Color(0xFFC9A96E)
                          : Colors.white.withOpacity(0.12),
                      width: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    o.label,
                    style: TextStyle(
                      fontSize: 12,
                      // 硬编码颜色，与 uni-app 一致 (seg-btn text active #fff / inactive rgba(255,255,255,0.7))
                      color: active
                          ? Colors.white
                          : Colors.white.withOpacity(0.7),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// 底部同步按钮
class _SyncButton extends StatelessWidget {
  const _SyncButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            // 硬编码颜色，与 uni-app 一致 (sync-btn linear-gradient(135deg, #C9A96E 0%, #A88550 100%))
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFC9A96E), Color(0xFFA88550)],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.refresh,
                size: 16,
                color: Colors.white,
              ),
              SizedBox(width: 6),
              Text(
                '同步调整到编辑器',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  letterSpacing: 0.4,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
