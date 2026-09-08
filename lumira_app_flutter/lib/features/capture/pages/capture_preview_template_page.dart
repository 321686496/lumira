import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../templates/data/preview_form_provider.dart';
import '../../templates/data/templates_editor_mock_data.dart';
import '../../templates/services/template_mapper.dart';
import '../data/capture_preview_mock_data.dart';
import '../data/capture_state.dart';
import '../domain/photo_template.dart';
import '../services/camera_service.dart';
import '../services/camera_service_provider.dart';
import '../widgets/aspect_ratio_selector.dart';
import '../widgets/camera_preview.dart';
import '../widgets/capture_bottom_controls.dart';
import '../widgets/capture_nav.dart';
import '../widgets/delay_timer_button.dart';
import '../widgets/level_indicator.dart';
import '../widgets/param_panel.dart';
import '../widgets/param_pill_bar.dart';
import '../widgets/shutter_feedback.dart';

/// 模板预览页（对齐拍摄页 capture_page.dart）
///
/// 「添加/编辑自定义模板」表单点「预览」进入。通过桥接方案把 EditorForm 转换为
/// PhotoTemplate 喂给拍摄页公共组件，使功能、布局、参数调整效果与拍摄页完全一致：
/// - 导航胶囊（CaptureNav）
/// - 取景器（CameraPreview 走 editableTemplate 路径，与参数面板同源）
/// - 顶部浮层（延时 / 比例切换 / 参数 pill）
/// - 右侧多姿势切换（CapturePoseSwitchButton）
/// - 底部控制区（CaptureBottomBar：缩放轮盘 + 5 页签工具栏 + 抽屉 + 拍照）
/// - 参数面板（ParamPanel）、水平仪（LevelIndicator）、快门白闪（ShutterFeedback）
///
/// 与拍摄页的不同（预览场景限定）：
/// - 导航返回 / 右下「完成」均触发 [CaptureState.previewTemplateSourceProvider] 清理并回写。
/// - 拍照仅预览、不入成片库（不写缩略图 / 水印 / gallery）。
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
  /// 编辑器传入的 EditorForm 源（作为回写合并的 base，保留 meta 独有字段）
  EditorForm? _template;

  /// 是否已完成桥接（未桥接前不渲染拍摄组件，避免 editableTemplate 为空）
  bool _hasBridged = false;

  /// 快门白闪触发版本号
  int _shutterTrigger = 0;

  /// 取景器 RepaintBoundary key（facing 变化时重建以切换传感器）
  GlobalKey? _viewfinderCaptureKey;
  String _lastFacingForKey = '';

  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  @override
  void dispose() {
    // dispose 兜底清理预览桥接源，避免残留到真实拍摄页
    _clearPreviewSource();
    super.dispose();
  }

  void _loadTemplate() {
    // 优先读取 previewEditorFormProvider（来自编辑器的实时表单），
    // fallback 到 mock 数据兼容 templateId / draftId 直接预览场景。
    EditorForm? loaded = ref.read(previewEditorFormProvider);

    if (loaded == null) {
      if (widget.draftId != null && widget.draftId!.isNotEmpty) {
        loaded = CapturePreviewMockData.loadDraftById(widget.draftId);
      } else if (widget.templateId != null && widget.templateId!.isNotEmpty) {
        loaded = CapturePreviewMockData.loadTemplateById(widget.templateId);
      }
    }

    if (loaded == null) {
      // 加载失败：Toast + 1000ms 后 pop
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        LumiraToast.show(context, '模板加载失败');
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (!mounted) return;
          _finishAndPop();
        });
      });
      return;
    }

    _template = loaded;
    // 桥接需在 widget 树构建完成后写入 provider（riverpod 禁止在 build/initState 直接写
    // provider，否则抛 "Tried to modify a provider while the widget tree was building"）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bridgeTemplate();
      setState(() {});
    });
  }

  /// 把 EditorForm 桥接进拍摄页状态，供拍摄页公共组件复用。
  void _bridgeTemplate() {
    final form = _template!;
    final id = form.meta.id.isNotEmpty
        ? form.meta.id
        : 'preview_${DateTime.now().millisecondsSinceEpoch}';
    final bridge = TemplateMapper.editorFormToPhotoTemplate(form, id: id);

    // 清空拍摄残留状态（currentTemplateId/aspectRatio/facing/补光/参数面板等）
    final container = ProviderScope.containerOf(context, listen: false);
    CaptureState.resetAll(container);

    // 1. 预览原始快照 → originalTemplateProvider 优先返回它（ParamPanel 重置可用）
    ref.read(CaptureState.previewTemplateSourceProvider.notifier).state = bridge;
    // 2. currentTemplateId → CaptureNav 识别「模板拍摄」+ 显示模板/剪影按钮
    ref.read(CaptureState.currentTemplateIdProvider.notifier).state = bridge.meta.id;
    // 3. 比例跟随模板 cropRatio（回退构图比例）
    final cropRatio = bridge.postProcess.cropRatio;
    ref.read(CaptureState.aspectRatioProvider.notifier).state =
        cropRatio.isNotEmpty ? cropRatio : bridge.composition.aspectRatio;
    // 4. 补光：模板启用补光时套用颜色/强度
    final fl = form.fillLight;
    if (fl != null && fl.enabled) {
      ref.read(CaptureState.fillLightEnabledProvider.notifier).state = true;
      ref.read(CaptureState.fillLightColorProvider.notifier).state = Color(fl.color);
      ref.read(CaptureState.fillLightIntensityProvider.notifier).state =
          fl.intensity;
    }
    // 5. 首姿势相机方向为前置时切前摄（补光仅前摄生效，需保证前置）
    final poses = bridge.poses;
    if (poses.isNotEmpty && poses[0].cameraDirection == 'front') {
      ref.read(CaptureState.cameraFacingProvider.notifier).state = 'front';
    }

    _hasBridged = true;
  }

  /// 清除预览桥接源。必须在退出预览前调用，保证真实拍摄页无残留。
  void _clearPreviewSource() {
    try {
      ref.read(CaptureState.previewTemplateSourceProvider.notifier).state = null;
    } catch (_) {
      // dispose 后 ref 不可读，静默忽略
    }
  }

  // ── 相机副作用（对齐拍摄页，保证取景器随控件实时变化）──

  CameraFlashMode _mapFlashMode(CaptureFlashMode mode) {
    switch (mode) {
      case CaptureFlashMode.off:
        return CameraFlashMode.off;
      case CaptureFlashMode.on:
        return CameraFlashMode.on;
      case CaptureFlashMode.auto:
        return CameraFlashMode.auto;
      case CaptureFlashMode.torch:
        return CameraFlashMode.torch;
    }
  }

  void _onZoomChanged(double multiplier) {
    final minZoom = ref.read(CaptureState.deviceMinZoomProvider) ?? 1.0;
    final maxZoom = ref.read(CaptureState.deviceMaxZoomProvider) ?? 10.0;
    final clamped = multiplier.clamp(minZoom, maxZoom);
    ref.read(CaptureState.apparentZoomProvider.notifier).state = clamped;
    ref.read(CaptureState.zoomProvider.notifier).state = clamped;
    ref.read(cameraServiceProvider).setZoomMultiplier(clamped);
  }

  void _switchCamera() {
    final current = ref.read(CaptureState.cameraFacingProvider);
    final next = current == 'back' ? 'front' : 'back';
    ref.read(CaptureState.cameraFacingProvider.notifier).state = next;

    // 前置无闪光灯硬件，切换时关闭
    if (next == 'front' &&
        ref.read(CaptureState.flashModeProvider) != CaptureFlashMode.off) {
      ref.read(CaptureState.flashModeProvider.notifier).state =
          CaptureFlashMode.off;
    }
    // 后置无屏幕补光，切换时关闭补光
    if (next == 'back' && ref.read(CaptureState.fillLightEnabledProvider)) {
      ref.read(CaptureState.fillLightEnabledProvider.notifier).state = false;
    }
    ref.read(CaptureState.apparentZoomProvider.notifier).state = 1.0;
    ref.read(CaptureState.zoomProvider.notifier).state = 1.0;
  }

  // ── 拍照：仅预览，不入成片库 ──

  Future<void> _onCapture() async {
    setState(() => _shutterTrigger++);
    try {
      await ref.read(cameraServiceProvider).capture(
            config: CaptureConfig(
              facing: ref.read(CaptureState.cameraFacingProvider),
              zoomMultiplier: ref.read(CaptureState.zoomProvider),
              flashMode: _mapFlashMode(ref.read(CaptureState.flashModeProvider)),
            ),
          );
      if (!mounted) return;
      LumiraToast.show(context, '已拍摄（预览，不入图库）');
    } catch (e) {
      if (!mounted) return;
      LumiraToast.show(context, '拍摄失败：$e');
    }
  }

  // ── 同步写回 ──

  /// 导航返回 / 「完成」按钮：把调整后的 editableTemplate 合并回 EditorForm 写进
  /// previewEditorFormProvider，编辑器 await push 返回后读取并同步到 _form。
  void _onSyncBack() {
    final bridge = ref.read(CaptureState.editableTemplateProvider);
    final base = _template;
    if (bridge != null && base != null) {
      final merged = TemplateMapper.photoTemplateToEditorFormMerge(bridge, base);
      ref.read(previewEditorFormProvider.notifier).state = merged;
    }
    _finishAndPop();
  }

  void _finishAndPop() {
    _clearPreviewSource();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else if (mounted) {
      GoRouter.of(context).go(RouteNames.templates);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasBridged || _template == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final isFullscreen = ref.watch(CaptureState.isFullscreenProvider);
    final isTrialMode = ref.watch(CaptureState.trialModeProvider);
    final facing = ref.watch(CaptureState.cameraFacingProvider);

    // 监听闪光灯模式变化，同步相机引擎（对齐拍摄页）
    ref.listen<CaptureFlashMode>(CaptureState.flashModeProvider, (prev, next) {
      ref.read(cameraServiceProvider).setFlashMode(_mapFlashMode(next));
    });

    // EV 补偿 → 取景器亮度（[−3,+3] → brightness [0,1]）
    ref.listen<CameraParams>(CaptureState.effectiveCameraProvider, (prev, next) {
      if (prev?.exposureCompensation != next.exposureCompensation) {
        final ev = next.exposureCompensation;
        final brightness = (0.5 + ev / 6.0).clamp(0.0, 1.0);
        ref.read(cameraServiceProvider).setBrightness(brightness);
      }
    });

    // 比例切换时重新下发当前缩放（取景器容器变 + cover 裁切自动实现视觉切换）
    ref.listen<String>(CaptureState.aspectRatioProvider, (prev, next) {
      if (prev != next) {
        final multiplier = ref.read(CaptureState.zoomProvider);
        ref.read(cameraServiceProvider).setZoomMultiplier(multiplier);
      }
    });

    // facing 变化时重建取景器 RepaintBoundary + CameraAwesomeBuilder
    if (_lastFacingForKey != facing) {
      _viewfinderCaptureKey = GlobalKey(debugLabel: 'preview_viewfinder_$facing');
      _lastFacingForKey = facing;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 取景器（含补光悬浮模式）
          _PreviewViewfinderArea(
            onZoomChanged: _onZoomChanged,
            rawCaptureKey: _viewfinderCaptureKey,
          ),

          // 2. 导航胶囊（返回即同步写回）
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CaptureNav(onBack: _onSyncBack),
          ),

          // 3. 顶部浮层组：延时 / 比例切换 / 参数 pill
          Positioned(
            top: MediaQuery.of(context).padding.top + 76,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isTrialMode)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Center(child: DelayTimerButton()),
                  ),
                if (!isFullscreen) const Center(child: AspectRatioSelector()),
                const SizedBox(height: 8),
                if (!isFullscreen && !isTrialMode)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: ParamPillBar(),
                  ),
              ],
            ),
          ),

          // 4. 多姿势切换按钮（仅 poses>1 的模板显示）
          if (!isTrialMode)
            Positioned(
              right: 12,
              top: MediaQuery.of(context).size.height * 0.40,
              child: const CapturePoseSwitchButton(),
            ),

          // 5. 底部控制区（缩放轮盘 + 5 页签工具栏 + 抽屉 + 拍摄按钮行）
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CaptureBottomBar(
              isFullscreen: isFullscreen,
              isTrialMode: isTrialMode,
              onZoomChanged: _onZoomChanged,
              onCapture: _onCapture,
              onSwitchCamera: _switchCamera,
              // 预览页不产生成片缩略图（角标缩略图为空，点击无操作）
              onThumbnailTap: () {},
              rawCaptureKey: _viewfinderCaptureKey,
            ),
          ),

          // 5.5 参数面板（底部滑入）
          const ParamPanel(),

          // 6. 水平仪
          const LevelIndicator(),

          // 7. 快门白闪反馈（最顶层，IgnorePointer 不拦截手势）
          Positioned.fill(
            child: ShutterFeedback(trigger: _shutterTrigger),
          ),

          // 8. 右下「完成」浮层胶囊（tokens.surface + 细边，叠照片浮层规范）
          Positioned(
            right: 14,
            bottom: MediaQuery.of(context).size.height * 0.34,
            child: _DoneFloatingButton(onTap: _onSyncBack),
          ),
        ],
      ),
    );
  }
}

/// 右下「完成」浮层胶囊：跟随主题（surface + 细边），不沿用旧硬编码金色渐变。
class _DoneFloatingButton extends ConsumerWidget {
  const _DoneFloatingButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: tokens.surface.withOpacity(0.9),
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: tokens.surfaceAlt, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, size: 16, color: tokens.textPrimary),
            const SizedBox(width: 4),
            Text(
              '同步到编辑器',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 取景器区域：按用户选定的比例约束相机预览（对齐 capture_page._ViewfinderArea）。
/// 补光开启 + 前摄时切换为悬浮取景器（对齐 _FloatingViewfinder）。
class _PreviewViewfinderArea extends ConsumerWidget {
  const _PreviewViewfinderArea({required this.onZoomChanged, this.rawCaptureKey});

  final ValueChanged<double> onZoomChanged;
  final GlobalKey? rawCaptureKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratioId = ref.watch(CaptureState.aspectRatioProvider);
    final facing = ref.watch(CaptureState.cameraFacingProvider);
    final fillLightEnabled = ref.watch(CaptureState.fillLightEnabledProvider);
    final screenSize = MediaQuery.of(context).size;
    final isPortrait = screenSize.height >= screenSize.width;
    final screenRatio = screenSize.width / screenSize.height;
    final targetRatio =
        CaptureState.computeTargetRatio(ratioId, isPortrait) ?? screenRatio;
    final isFullscreen = ratioId == 'fullscreen';

    // 补光悬浮模式：仅前置 + 补光开启时激活
    final isFloating = fillLightEnabled && facing == 'front';

    if (!isFloating) {
      double vfW, vfH;
      if (isFullscreen) {
        vfW = screenSize.width;
        vfH = screenSize.height;
      } else {
        if (screenRatio > targetRatio) {
          vfH = screenSize.height;
          vfW = vfH * targetRatio;
        } else {
          vfW = screenSize.width;
          vfH = vfW / targetRatio;
        }
      }
      return Container(
        color: Colors.black,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: vfW,
            height: vfH,
            child: CameraPreview(
              key: ValueKey('camera_preview_preview_$facing'),
              onZoomChanged: onZoomChanged,
              previewFit: CameraPreviewFit.cover,
              rawCaptureKey: rawCaptureKey,
            ),
          ),
        ),
      );
    }

    // 补光悬浮模式：取景器缩小为可拖动窗口，背景显示补光色
    return _PreviewFloatingViewfinder(
      onZoomChanged: onZoomChanged,
      rawCaptureKey: rawCaptureKey,
      screenSize: screenSize,
    );
  }
}

/// 悬浮取景器（对齐 capture_page._FloatingViewfinder）：可拖动、可缩放，背景为补光色。
class _PreviewFloatingViewfinder extends ConsumerStatefulWidget {
  const _PreviewFloatingViewfinder({
    required this.onZoomChanged,
    required this.rawCaptureKey,
    required this.screenSize,
  });

  final ValueChanged<double> onZoomChanged;
  final GlobalKey? rawCaptureKey;
  final Size screenSize;

  @override
  ConsumerState<_PreviewFloatingViewfinder> createState() =>
      _PreviewFloatingViewfinderState();
}

class _PreviewFloatingViewfinderState
    extends ConsumerState<_PreviewFloatingViewfinder> {
  Offset _dragOffset = Offset.zero;
  int _activePointers = 0;

  @override
  Widget build(BuildContext context) {
    final color = ref.watch(CaptureState.fillLightColorProvider);
    final intensity = ref.watch(CaptureState.fillLightIntensityProvider);
    final scale = ref.watch(CaptureState.fillLightViewfinderScaleProvider);
    final savedOffset =
        ref.watch(CaptureState.fillLightViewfinderOffsetProvider);
    final ratioId = ref.watch(CaptureState.aspectRatioProvider);

    final sw = widget.screenSize.width;
    final sh = widget.screenSize.height;
    final isPortrait = sh >= sw;
    final screenRatio = sw / sh;
    final windowRatio =
        CaptureState.computeTargetRatio(ratioId, isPortrait) ?? screenRatio;
    final windowW = sw * scale;
    final windowH = windowW / windowRatio;

    final centerX = sw / 2 + savedOffset.dx + _dragOffset.dx;
    final centerY = sh * 0.42 + savedOffset.dy + _dragOffset.dy;
    final left = centerX - windowW / 2;
    final top = centerY - windowH / 2;

    final bgFull = intensity > 1.0
        ? Color.lerp(color, Colors.white, (intensity - 1.0).clamp(0.0, 0.5))!
        : color.withOpacity(intensity.clamp(0.0, 1.0));

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: ColoredBox(color: bgFull)),
        Positioned(
          left: left,
          top: top,
          width: windowW,
          height: windowH,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _activePointers++,
            onPointerMove: (event) {
              if (_activePointers == 1) {
                setState(() => _dragOffset += event.delta);
              }
            },
            onPointerUp: (_) {
              _activePointers = (_activePointers - 1).clamp(0, 99);
              if (_activePointers == 0 && _dragOffset != Offset.zero) {
                ref
                    .read(CaptureState.fillLightViewfinderOffsetProvider.notifier)
                    .state = savedOffset + _dragOffset;
                _dragOffset = Offset.zero;
              }
            },
            onPointerCancel: (_) {
              _activePointers = (_activePointers - 1).clamp(0, 99);
              if (_activePointers == 0) _dragOffset = Offset.zero;
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white54, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CameraPreview(
                  key: const ValueKey('camera_preview_preview'),
                  onZoomChanged: widget.onZoomChanged,
                  previewFit: CameraPreviewFit.cover,
                  rawCaptureKey: widget.rawCaptureKey,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}