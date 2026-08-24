import 'dart:async';

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/domain/filter_recipe.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/templates/data/templates_editor_mock_data.dart'
    show EditorForm, EditorFormPostProcess, EditorFormComposition;
import 'package:lumira_app_flutter/features/templates/widgets/composition_overlay.dart';
import 'package:lumira_app_flutter/features/templates/widgets/pose_silhouette.dart';

import '../data/capture_state.dart';
import '../services/camera_service.dart';
import '../services/camera_service_provider.dart';

/// 将 EditorFormPostProcess 转换为 domain PostProcess（用于 fromPostProcess）
///
/// Bug 12 修复：CameraPreview 支持 formOverride（EditorForm），
/// 但 fromPostProcess 接受 domain PostProcess，需要做类型转换。
/// 注意：EditorFormPostProcess 使用 int 字段，domain PostProcessColor 使用 double 字段
PostProcess _editorFormPostProcessToDomain(EditorFormPostProcess src) {
  return PostProcess(
    cropRatio: src.cropRatio,
    color: PostProcessColor(
      brightness: src.color.brightness.toDouble(),
      contrast: src.color.contrast.toDouble(),
      saturation: src.color.saturation.toDouble(),
      temperature: src.color.temperature.toDouble(),
      tint: src.color.tint.toDouble(),
    ),
    smoothStrength: src.smoothStrength,
    sharpen: src.sharpen,
    vignette: src.vignette,
    grain: src.grain,
    lut: src.lut,
  );
}

/// 将 EditorFormComposition 转换为 domain Composition
Composition _editorFormCompositionToDomain(EditorFormComposition src) {
  return Composition(
    overlayType: src.overlayType,
    opacity: src.opacity,
    aspectRatio: src.aspectRatio,
    description: src.description,
  );
}

/// 相机预览组件
///
/// 通过 [CameraService] 抽象层构建原生相机预览（三端适配），
/// 并叠加项目自定义的滤镜（ColorFiltered）、构图辅助线（CompositionOverlay）、
/// 姿势剪影（PoseSilhouette）。
///
/// 视觉规格来源：lumira-app/src/pages/capture/index.vue line 44-68
///
/// 改造说明（从 camerawesome 直连改为 CameraService 抽象层）：
/// 原版本直接调用 `CameraAwesomeBuilder.custom(...)` 并通过 `onCameraStateCreated`
/// 回调把 camerawesome 的 `CameraState` 暴露给上层。新版本通过
/// `ref.read(cameraServiceProvider).buildPreview(config: ...)` 构建预览，
/// CameraService 实现内部处理 camerawesome 的初始化、闪光灯、缩放、对焦等细节，
/// 上层不再接触 camerawesome 类型。相机就绪后通过 `onReady` 回调通知本 widget，
/// 由 [_onCameraReady] 应用初始闪光灯/缩放参数。
///
/// 模板叠加层（formOverride / editableTemplate）逻辑保留不变：
/// - ColorFiltered 包裹相机流，应用 fromPostProcess 调色矩阵
/// - CompositionOverlay 叠加构图辅助线（三分法、黄金螺旋等）
/// - PoseSilhouette 叠加姿势剪影
class CameraPreview extends ConsumerWidget {
  CameraPreview({
    super.key,
    this.onZoomChanged,
    this.formOverride,
    this.previewFit = CameraPreviewFit.cover,
    this.rawCaptureKey,
  });

  /// 缩放回调（传入真实倍数，1.0 = 1x），由外部（缩放轮盘等）触发。
  /// 取景器内的双指捏合缩放由本组件内置的 [_PinchZoomCamera] 处理，
  /// 此回调保留供外部复用。
  final ValueChanged<double>? onZoomChanged;

  /// 表单覆盖参数（Bug 12 修复：模板预览页使用）
  ///
  /// 当非 null 时，使用此 EditorForm 的 postProcess/composition/pose.silhouette
  /// 替代 CaptureState providers 中的对应值。用于模板预览页直接套用编辑器表单参数。
  ///
  /// 取景器仍读 CaptureState 的 flash/facing 等基础相机控制 providers。
  final EditorForm? formOverride;

  /// 预览填充模式：
  /// - [CameraPreviewFit.cover]（默认）：裁剪填充，与拍照后裁剪区域一致（适用于固定比例取景）
  /// - [CameraPreviewFit.contain]：完整显示传感器图像，可能有黑边（适用于全屏模式，
  ///   用户希望看到完整画面而不被裁剪）
  final CameraPreviewFit previewFit;

  /// 用于捕获原始相机帧（未经 ColorFiltered 处理）的 RepaintBoundary key。
  /// FilterPicker 抽屉展开时，通过此 key 调用 `boundary.toImage()` 捕获当前帧，
  /// 然后在每张滤镜卡片中套用对应 ColorFilter 显示效果预览。
  /// 为 null 时不包裹 RepaintBoundary（兼容不需要捕获的场景）。
  final GlobalKey? rawCaptureKey;

  /// 对焦反馈层（[_FocusOverlay]）状态驱动 key：单击对焦 / 长按锁定回调
  /// 通过它显示金色对焦框与「AE/AF 锁定」标签。
  /// facing 变化时由外层 KeyedSubtree（ValueKey）+ _FocusOverlay.didUpdateWidget 复位。
  /// 注意：本构造为非 const（GlobalKey 非 const 工厂，无法作为 const 字段初始化式）。
  final GlobalKey<_FocusOverlayState> _focusKey =
      GlobalKey<_FocusOverlayState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overrideWidget = ref.watch(cameraPreviewOverrideProvider);
    final hasOverride = formOverride != null;

    // 当 formOverride 非空时，silhouette/composition/postProcess 都来自 formOverride，
    // 不再 watch editableTemplateProvider（避免预览页与拍摄页状态耦合）
    final editable =
        hasOverride ? null : ref.watch(CaptureState.editableTemplateProvider);

    final flashMode = ref.watch(CaptureState.flashModeProvider);
    final facing = ref.watch(CaptureState.cameraFacingProvider);
    final showTemplate =
        hasOverride || ref.watch(CaptureState.showTemplateProvider);
    // Bug fix: 当 formOverride 非空时，不在此处渲染剪影——
    // 调用方（如 _Viewfinder）会自行渲染可拖动的剪影交互层。
    // 否则会出现两个剪影叠加（中间一个不可拖 + 真实位置一个可拖）。
    final showSilhouette =
        !hasOverride && ref.watch(CaptureState.showSilhouetteProvider);
    final rawMode = ref.watch(CaptureState.rawModeProvider);

    // 修复 Bug 2/3：自由模式下也应用滤镜（来自 freeModePostProcessProvider）
    // 通过 effectivePostProcessProvider 统一获取当前生效的后期参数
    // Bug 12 修复：formOverride 非空时，使用其 postProcess（转换为 domain 类型）
    final effectivePost = hasOverride
        ? _editorFormPostProcessToDomain(formOverride!.postProcess)
        : ref.watch(CaptureState.effectivePostProcessProvider);
    final effectiveComp = hasOverride
        ? _editorFormCompositionToDomain(formOverride!.composition)
        : ref.watch(CaptureState.effectiveCompositionProvider);

    // 滤镜仅在 !rawMode 时应用（无论是否有模板）
    final applyFilter = !rawMode;

    // 相机预览本体：测试中由 override 替换 CameraService.buildPreview 部分，
    // 但保留滤镜和构图叠图逻辑（让测试可以验证 ColorFiltered/CompositionOverlay 包裹）
    final cameraService = ref.read(cameraServiceProvider);
    // 用 SizedBox.expand 包裹，强制 CameraAwesomeBuilder 填满父容器，
    // 避免 camerawesome 内部根据 previewSize 计算尺寸时留下黑边
    final cameraWidget = overrideWidget ??
        SizedBox.expand(
          child: cameraService.buildPreview(
            config: CameraPreviewConfig(
              facing: facing,
              fit: previewFit,
              onReady: () => _onCameraReady(ref, flashMode, facing),
              onTapFocus: (position, previewSize) {
                final overlay = _focusKey.currentState;
                // 锁定状态下单击其他位置 → 先解除锁定，再对新触点重新对焦（iPhone 行为）
                if (overlay?.isLocked == true) {
                  cameraService.setFocusAndExposureLock(locked: false);
                  overlay?.unlock();
                }
                cameraService.focusOnPoint(position, previewSize);
                overlay?.showFocus(position);
              },
            ),
          ),
        );

    // 原始相机流（未经 ColorFiltered 处理），用 RepaintBoundary 包裹以支持帧捕获。
    // rawCaptureKey 非 null 时，FilterPicker 可通过 boundary.toImage() 捕获当前帧，
    // 在滤镜卡片中套用各滤镜的 ColorFilter 显示实时效果预览。
    final rawCamera = rawCaptureKey != null
        ? RepaintBoundary(key: rawCaptureKey, child: cameraWidget)
        : cameraWidget;

    // 滤镜包裹（修复 Bug 2/3：使用 effectivePost，自由模式也应用）
    // 双指捏合缩放：最外层包 _PinchZoomCamera，在整个取景器上监听捏合手势，
    // 从当前倍数出发按比例缩放并真正下发到相机（替代 camerawesome 内置的
    // 仅更新状态、不下发相机的 onPreviewScale 流程）。
    final filteredCamera = _PinchZoomCamera(
      onLongPressStart: (localPosition, previewSize) {
        _focusKey.currentState?.showLock(localPosition);
        cameraService.setFocusAndExposureLock(
          locked: true,
          position: localPosition,
          previewSize: previewSize,
        );
      },
      onLongPressEnd: () {
        // 锁定常驻，抬手不隐藏（避免动画闪烁）
      },
      child: applyFilter
          ? ColorFiltered(
              colorFilter: fromPostProcess(effectivePost),
              child: rawCamera,
            )
          : rawCamera,
    );

    // 构图叠图（修复 Bug 2：使用 effectiveComp，自由模式也显示构图辅助线）
    final compositionOverlay =
        (showTemplate && effectiveComp.overlayType != 'none')
            ? Positioned.fill(
                child: IgnorePointer(
                  child: CompositionOverlay(
                    overlayType: effectiveComp.overlayType,
                    opacity: effectiveComp.opacity,
                  ),
                ),
              )
            : const SizedBox.shrink();

    // 姿势剪影（仅在 silhouette.data != 'none' && showSilhouette 时显示）
    // Bug fix: formOverride 非空时不渲染剪影（调用方自行渲染可拖动层）
    // 注意：EditorForm 和 PhotoTemplate 都有 SilhouetteResource 类（同名不同类），
    // 这里统一提取为基本类型（String/-double）避免类型冲突
    final String silhouetteType;
    final String silhouetteData;
    final double silhouetteScale;
    final double silhouetteRotation;
    // 剪影位置（0..1，相对当前取景器比例框：x:0,y:0 = 比例框左上角）。
    // 与模板预览页/编辑页保持一致，统一以取景比例框为参考系，
    // 避免全屏比例下 x:0,y:0 在手机左上角、4:3 时位置错位的现象。
    final double silhouettePosX;
    final double silhouettePosY;
    final bool hasSilhouette;
    if (formOverride != null) {
      // formOverride 模式下不渲染剪影（showSilhouette 已为 false，hasSilhouette 不影响）
      silhouetteType = '';
      silhouetteData = 'none';
      silhouetteScale = 1.0;
      silhouetteRotation = 0.0;
      silhouettePosX = 0.5;
      silhouettePosY = 0.5;
      hasSilhouette = false;
    } else if (editable != null) {
      silhouetteType = editable.pose.silhouette.type;
      silhouetteData = editable.pose.silhouette.data;
      silhouetteScale = editable.pose.scale;
      silhouetteRotation = editable.pose.rotation;
      silhouettePosX = editable.pose.position.x;
      silhouettePosY = editable.pose.position.y;
      hasSilhouette = silhouetteData != 'none';
    } else {
      silhouetteType = '';
      silhouetteData = 'none';
      silhouetteScale = 1.0;
      silhouetteRotation = 0.0;
      silhouettePosX = 0.5;
      silhouettePosY = 0.5;
      hasSilhouette = false;
    }
    final silhouetteOverlay = (hasSilhouette && showSilhouette)
        ? Positioned.fill(
            child: IgnorePointer(
              child: SilhouetteLayer(
                silhouetteType: silhouetteType,
                silhouetteData: silhouetteData,
                positionX: silhouettePosX,
                positionY: silhouettePosY,
                scale: silhouetteScale,
                rotation: silhouetteRotation,
              ),
            ),
          )
        : const SizedBox.shrink();

    return Stack(
      fit: StackFit.expand,
      children: [
        filteredCamera,
        compositionOverlay,
        silhouetteOverlay,
        // 对焦反馈层：GlobalKey 不能同时充当 ValueKey，因此用 KeyedSubtree 包一层。
        // ValueKey('focus_overlay_$facing') + _FocusOverlay.didUpdateWidget
        // 在切换前后摄像头时复位锁定态与对焦框。
        KeyedSubtree(
          key: ValueKey('focus_overlay_$facing'),
          child: _FocusOverlay(key: _focusKey, facing: facing),
        ),
      ],
    );
  }

  /// 相机就绪回调：应用初始闪光灯模式 + EV 补偿 + 查询设备缩放能力 + 恢复当前缩放。
  /// 由 CameraService.buildPreview 的 onReady 触发（首次初始化和重建时）。
  ///
  /// 注意：不重置缩放为 1x，而是恢复 zoomProvider 中保存的当前值。
  /// 这样拍照后 CameraPreview 重建（_cameraRebuildKey 递增）触发 onReady 时，
  // 不会丢失用户已调整的缩放比例。
  void _onCameraReady(
      WidgetRef ref, CaptureFlashMode flashMode, String facing) {
    final cameraService = ref.read(cameraServiceProvider);
    // 应用闪光灯模式
    cameraService.setFlashMode(_mapFlashMode(flashMode));

    // 应用初始 EV 补偿（从 effectiveCameraProvider 读取）
    final cam = ref.read(CaptureState.effectiveCameraProvider);
    final ev = cam.exposureCompensation;
    final brightness = (0.5 + ev / 6.0).clamp(0.0, 1.0);
    cameraService.setBrightness(brightness);

    // 异步查询设备缩放能力（不阻塞相机就绪）
    _queryZoomCapabilities(ref, cameraService);

    // 恢复当前缩放（不重置为 1x，保留用户已调整的值）
    final currentZoom = ref.read(CaptureState.zoomProvider);
    cameraService.setZoomMultiplier(currentZoom);
  }

  /// 异步查询设备缩放能力（最大/最小倍数、是否支持超广角），
  /// 结果写入对应 provider 供上层 UI（如变焦滑块范围）使用。
  /// 失败时仅打印日志，不阻塞相机就绪流程。
  Future<void> _queryZoomCapabilities(
      WidgetRef ref, CameraService service) async {
    try {
      final maxZoom = await service.getMaxZoomMultiplier();
      final minZoom = await service.getMinZoomMultiplier();
      final ultraWide = await service.supportsUltraWide();
      ref.read(CaptureState.deviceMaxZoomProvider.notifier).state = maxZoom;
      ref.read(CaptureState.deviceMinZoomProvider.notifier).state = minZoom;
      ref.read(CaptureState.supportsUltraWideProvider.notifier).state =
          ultraWide;
    } catch (e) {
      debugPrint('[camera] query zoom capabilities failed: $e');
    }
  }

  /// 将 CaptureState 的 CaptureFlashMode 映射为 CameraService 的 CameraFlashMode。
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
}

/// 测试覆写 provider（生产环境为 null，测试中注入占位 widget）
final cameraPreviewOverrideProvider = Provider<Widget?>((ref) => null);

/// 双指捏合缩放包装：在取景器最外层监听 onScale 手势实现 iPhone 原生相机式缩放。
///
/// 行为说明：
/// - 手势起始时记录当前缩放倍数（apparentZoomProvider），
///   随手势 `details.scale` 按比例缩放（张开放大、捏合缩小），
///   与外部缩放轮盘/水平拖动共用同一倍数语义，不产生跳变。
/// - 同步更新 apparentZoomProvider（缩放轮盘指示器）/ zoomProvider（成片缩放），
///   并真正调用 [CameraService.setZoomMultiplier] 下发到相机，
///   保证取景器画面实时缩放（此前 camerawesome 内置手势只更新状态、不下发相机）。
/// - 倍数变化 < 0.01 时不下发，避免高频原生调用。
class _PinchZoomCamera extends ConsumerStatefulWidget {
  const _PinchZoomCamera({
    required this.child,
    this.onLongPressStart,
    this.onLongPressEnd,
  });

  final Widget child;

  /// 长按开始（约 500ms 无位移按下）：[localPosition] 为取景器内本地坐标，
  /// [previewSize] 为取景器当前尺寸（用于原生 AE/AF 锁定坐标换算）。
  final void Function(Offset localPosition, Size previewSize)? onLongPressStart;

  /// 长按结束（抬手）。锁定常驻，抬手不隐藏（避免动画闪烁）。
  final VoidCallback? onLongPressEnd;

  @override
  ConsumerState<_PinchZoomCamera> createState() => _PinchZoomCameraState();
}

class _PinchZoomCameraState extends ConsumerState<_PinchZoomCamera> {
  /// 上一次 update 的 scale（用于相邻帧增量比，抵消初始跨度影响）
  double _lastScale = 1.0;

  /// 本次捏合手势的当前缩放倍数（增量累积）
  double _currentMultiplier = 1.0;

  /// 上一次 update 的指针数（用于检测手指重新落下时重新锚定）
  int _lastPointerCount = 0;

  /// 上一次实际下发到相机的倍数（用于节流）
  double? _lastAppliedMultiplier;

  void _resetGesture() {
    _lastScale = 1.0;
    _currentMultiplier = 1.0;
    _lastPointerCount = 0;
    _lastAppliedMultiplier = null;
  }

  /// 将目标倍数 clamp 到设备范围后更新状态并下发相机。
  void _applyZoom(double target) {
    final minZoom = ref.read(CaptureState.deviceMinZoomProvider) ?? 1.0;
    final maxZoom = ref.read(CaptureState.deviceMaxZoomProvider) ?? 10.0;
    final clamped = target.clamp(minZoom, maxZoom);
    final last = _lastAppliedMultiplier;
    if (last != null && (clamped - last).abs() < 0.01) return;
    _lastAppliedMultiplier = clamped;
    ref.read(CaptureState.apparentZoomProvider.notifier).state = clamped;
    ref.read(CaptureState.zoomProvider.notifier).state = clamped;
    ref.read(cameraServiceProvider).setZoomMultiplier(clamped);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final previewSize = Size(constraints.maxWidth, constraints.maxHeight);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        // 用 start 让 Flutter 在手势被接受时重新捕获初始跨度，
        // 避免“双指刚落下间距极小”导致初始 scale 巨大、一捏就跳最大倍数
        dragStartBehavior: DragStartBehavior.start,
        // 长按与 onScale* 同处手势竞技场：长按超过 500ms 由 LongPress 胜出
        // （tap/scale 被拒），双指捏合由 Scale 胜出，两者互不干扰。
        onLongPressStart: (details) => widget.onLongPressStart
            ?.call(details.localPosition, previewSize),
        onLongPressEnd: (_) => widget.onLongPressEnd?.call(),
        onScaleStart: (_) => _resetGesture(),
        onScaleUpdate: (details) {
          final pc = details.pointerCount;
          if (pc < 2) {
            // 单指/点击不干扰（点击对焦仍由相机组件处理）
            _lastPointerCount = pc;
            return;
          }
          // 指针数从 <2 变为 >=2（新捏合或手指重新落下），重新锚定起始倍数，
          // 防止 Flutter 重置初始跨度后 scale 跳变导致倍数突变
          if (_lastPointerCount < 2) {
            _lastPointerCount = pc;
            _lastScale = details.scale;
            _currentMultiplier = ref.read(CaptureState.apparentZoomProvider);
            return;
          }
          _lastPointerCount = pc;
          if (details.scale == 0 || _lastScale == 0) return;
          // 增量缩放：用相邻两帧 scale 的比值（不受初始跨度影响），
          // 让捏合缩放平滑连续，不再“一捏就跳到最大倍数”
          final ratio = details.scale / _lastScale;
          _lastScale = details.scale;
          _currentMultiplier *= ratio;
          _applyZoom(_currentMultiplier);
        },
        onScaleEnd: (_) => _resetGesture(),
        child: widget.child,
      );
    });
  }
}

/// 对焦反馈层：渲染金色四角对焦框（单击对焦）与「AE/AF 锁定」标签（长按锁定）。
///
/// 自管理显示状态，由外部通过 [_FocusOverlayState]（`GlobalKey`）驱动，
/// 不污染任何 provider。切换前后摄像头时由外层 KeyedSubtree(ValueKey(facing))
/// 重建整棵子树，锁定态与对焦框自动复位；`facing` 字段仅作 didUpdateWidget 兜底。
class _FocusOverlay extends ConsumerStatefulWidget {
  const _FocusOverlay({super.key, this.facing});

  /// 当前摄像头 facing（切换时复位对焦/锁定态，正常路径由外层 KeyedSubtree 重建完成）。
  final String? facing;

  @override
  ConsumerState<_FocusOverlay> createState() => _FocusOverlayState();
}

class _FocusOverlayState extends ConsumerState<_FocusOverlay> {
  Offset? _point;
  bool _locked = false;
  bool _visible = false;
  Timer? _hideTimer;

  bool get isLocked => _locked;

  /// 单击对焦：显示金色对焦框，约 1.5s 后自动消失。
  void showFocus(Offset point) {
    _hideTimer?.cancel();
    setState(() {
      _point = point;
      _locked = false;
      _visible = true;
    });
    _hideTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _visible = false);
    });
  }

  /// 长按锁定：显示金色对焦框 + 「AE/AF 锁定」标签，常驻不消失。
  void showLock(Offset point) {
    _hideTimer?.cancel();
    setState(() {
      _point = point;
      _locked = true;
      _visible = true;
    });
  }

  /// 解除锁定并隐藏（用于「锁定后单击其他位置」的解锁阶段）。
  void unlock() {
    _hideTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _locked = false;
      _visible = false;
    });
  }

  @override
  void didUpdateWidget(_FocusOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 兜底：facing 变化时复位（正常路径由外层 KeyedSubtree 重建完成）。
    if (widget.facing != oldWidget.facing) {
      _hideTimer?.cancel();
      _point = null;
      _locked = false;
      _visible = false;
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible || _point == null) return const SizedBox.shrink();
    final tokens = ref.watch(appThemeProvider).tokens;
    return IgnorePointer(
      child: Stack(
        children: [
          _FocusFrame(point: _point!),
          if (_locked) _LockBadge(point: _point!, tokens: tokens),
        ],
      ),
    );
  }
}

/// 金色四角 L 形对焦框：叠照片浮层语义（跨风格金色描边，不外发光、无阴影、无模糊）。
///
/// 尺寸约 70×70，中心位于 [point]；出现时做 1.6→1.0 弹性缩入 + 轻微淡入。
class _FocusFrame extends StatefulWidget {
  const _FocusFrame({required this.point});

  final Offset point;

  @override
  State<_FocusFrame> createState() => _FocusFrameState();
}

class _FocusFrameState extends State<_FocusFrame>
    with SingleTickerProviderStateMixin {
  static const double _size = 70.0;
  static const double _stroke = 3.0;
  static const double _cornerLength = 22.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  late final Animation<double> _scale = Tween<double>(begin: 1.6, end: 1.0)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
  late final Animation<double> _opacity = Tween<double>(begin: 0.0, end: 1.0)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void didUpdateWidget(_FocusFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 对焦框移动到新触点时重放弹性缩入动画
    if (oldWidget.point != widget.point) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 金色：跨风格叠加视觉，透明度 0.9
    final borderColor = Colors.amber.shade400.withOpacity(0.9);
    return Positioned(
      left: widget.point.dx - _size / 2,
      top: widget.point.dy - _size / 2,
      width: _size,
      height: _size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacity.value,
            child: Transform.scale(scale: _scale.value, child: child),
          );
        },
        child: CustomPaint(
          key: const Key('focus_frame'),
          size: const Size(_size, _size),
          painter: _FocusFramePainter(
            color: borderColor,
            strokeWidth: _stroke,
            cornerLength: _cornerLength,
          ),
        ),
      ),
    );
  }
}

/// 四角 L 形描边画笔（金色对焦框）。
class _FocusFramePainter extends CustomPainter {
  const _FocusFramePainter({
    required this.color,
    required this.strokeWidth,
    required this.cornerLength,
  });

  final Color color;
  final double strokeWidth;
  final double cornerLength;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    final l = cornerLength;
    // 左上
    canvas.drawLine(Offset(0, l), const Offset(0, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(l, 0), paint);
    // 右上
    canvas.drawLine(Offset(w - l, 0), Offset(w, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, l), paint);
    // 右下
    canvas.drawLine(Offset(w, h - l), Offset(w, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w - l, h), paint);
    // 左下
    canvas.drawLine(Offset(l, h), Offset(0, h), paint);
    canvas.drawLine(Offset(0, h), Offset(0, h - l), paint);
  }

  @override
  bool shouldRepaint(covariant _FocusFramePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.cornerLength != cornerLength;
}

/// 「AE/AF 锁定」胶囊标签：对焦框正下方（约 56px）居中显示。
///
/// 实心 `tokens.surface` + 细边 `tokens.divider` + `tokens.textPrimary` 文字，
/// 跨风格通用叠照片浮层：不使用 BackdropFilter / 阴影 / 玻璃。
class _LockBadge extends StatelessWidget {
  const _LockBadge({required this.point, required this.tokens});

  final Offset point;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: point.dx,
      top: point.dy + 56,
      child: FractionalTranslation(
        // 以对焦框中心为轴水平居中
        translation: const Offset(-0.5, 0),
        child: Container(
          key: const Key('focus_lock_badge'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tokens.divider, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock, size: 14, color: tokens.textPrimary),
              const SizedBox(width: 4),
              Text(
                'AE/AF 锁定',
                style: TextStyle(fontSize: 12, color: tokens.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
