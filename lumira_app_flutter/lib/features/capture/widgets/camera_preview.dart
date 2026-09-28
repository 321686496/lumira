import 'dart:async';
import 'dart:io' show Platform;

import 'package:camerawesome/camerawesome_plugin.dart'
    show CamerawesomePlugin;
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
import '../services/white_balance.dart';

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
    this.previewCaptureKey,
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

  /// 用于捕获「已合成取景器」的 RepaintBoundary key（含 ColorFiltered 色彩矩阵 +
  /// 前置镜像 + 比例裁切，即用户最终所见，WYSIWYG）。
  /// OHOS 水印动画源改用它：快门瞬间 `boundary.toImage()` 冻结取景器当前帧，
  /// 替代原生高增强链路早帧，使动画内容 = 取景器。为 null 时不包裹。
  final GlobalKey? previewCaptureKey;

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
              legStretch: effectivePost.legStretch,
              onReady: () => _onCameraReady(ref, flashMode, facing),
              onTapFocus: (position, previewSize) {
                final overlay = _focusKey.currentState;
                // 锁定状态下单击其他位置 → 先解除锁定，再对新触点重新对焦（iPhone 行为）
                if (overlay?.isLocked == true) {
                  cameraService.setFocusAndExposureLock(locked: false);
                  overlay?.unlock();
                }
                cameraService.focusOnPoint(position, previewSize);
                overlay?.showFocus(position, previewSize);
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

    // 拉腿实时预览：legStretch 通过 CameraPreviewConfig 透传给相机预览底层，
    // 由 camerawesome 的「双层 GPU 合成」在纹理层直接渲染（锚点上方恒等、下方
    // 纵向放大），全程零读回、零 CPU 拉伸、零半透明叠层 → 取景器不卡顿、无重影，
    // 且与成片 legStretchRgba 几何一致（WYSIWYG）。这里无需任何叠层。
    final cameraBody = rawCamera;

    // 滤镜包裹（修复 Bug 2/3：使用 effectivePost，自由模式也应用）
    // 双指捏合缩放：最外层包 _PinchZoomCamera，在整个取景器上监听捏合手势，
    // 从当前倍数出发按比例缩放并真正下发到相机（替代 camerawesome 内置的
    // 仅更新状态、不下发相机的 onPreviewScale 流程）。
    final filteredCamera = _PinchZoomCamera(
      focusKey: _focusKey,
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
      child: Platform.isIOS || Platform.operatingSystem == 'ohos'
          // iOS/OHOS：锐化/磨皮/暗角/颗粒 + 色彩矩阵改由原生 GPU 逐帧渲染
          //（_PostEffectSync 把参数推给 PreviewEffectProcessor / libpreview_fx.so），
          // 取景器 == 成片通道，因此不再叠加 Dart ColorFiltered（避免双重矩阵）。
          // rawMode 时 enabled=false → 推全零参数关闭原生处理，恢复原始取景。
          ? _PostEffectSync(
              enabled: applyFilter,
              post: effectivePost,
              child: cameraBody,
            )
          // Android：仅实时呈现色彩矩阵（ColorFiltered）；细节参数仅作用于成片。
          : applyFilter
              ? _buildAndroidLivePreview(effectivePost, cameraBody)
              : cameraBody,
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
      // 多姿势模板：跟随当前选中姿势的下标读取剪影（默认 poses[0]）。
      final poses = editable.poses;
      final idx = ref.watch(CaptureState.currentPoseIndexProvider);
      final Pose current = poses.isNotEmpty
          ? poses[idx.clamp(0, poses.length - 1)]
          : const Pose();
      silhouetteType = current.silhouette.type;
      silhouetteData = current.silhouette.data;
      silhouetteScale = current.scale;
      silhouetteRotation = current.rotation;
      silhouettePosX = current.position.x;
      silhouettePosY = current.position.y;
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

    // 已合成取景器（含 ColorFiltered 色彩矩阵 + 前置镜像 + 比例裁切），用于
    // OHOS 快门冻结帧捕获（水印动画源，WYSIWYG）。previewCaptureKey 非 null 时
    // 用 RepaintBoundary 包裹，供快门时刻 boundary.toImage() 冻结当前帧。
    final composedPreview = previewCaptureKey != null
        ? RepaintBoundary(key: previewCaptureKey, child: filteredCamera)
        : filteredCamera;

    return Stack(
      fit: StackFit.expand,
      children: [
        composedPreview,
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

    // 应用初始 EV 补偿：实际 EV = 参数 EV（模板/会话基准）+ 对焦曝光偏移
    //（见 CaptureState.effectiveExposureEvProvider），映射 brightness ∈ [0,1]
    final ev = ref.read(CaptureState.effectiveExposureEvProvider);
    cameraService.setBrightness((0.5 + ev / 6.0).clamp(0.0, 1.0));

    // 异步查询设备缩放能力（不阻塞相机就绪）
    _queryZoomCapabilities(ref, cameraService);

    // 恢复当前缩放（不重置为 1x，保留用户已调整的值）
    final currentZoom = ref.read(CaptureState.zoomProvider);
    cameraService.setZoomMultiplier(currentZoom);

    // 重放白平衡会话状态：相机重建（切前后摄 / 返回拍摄页 / App 恢复 / 拍照后
    // 重建）后，新会话的硬件白平衡回到默认 auto，而模板白平衡只在模板应用时
    // 下发过一次（可能落在旧会话上）→ 丢失。相机就绪时按会话状态重放一次，
    // 与 flash/EV/zoom 的重放语义一致；重锁同一增益幂等无害。非 auto 时还需
    // 刷新 iOS 硬件残差（不同摄像头增益特性不同，旧残差对新相机不成立）。
    final wb = ref.read(whiteBalanceSessionProvider);
    if (!wb.isAuto) {
      cameraService.setWhiteBalance(wb);
      refreshWbResidual(ref);
    }
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
    this.focusKey,
    this.onLongPressStart,
    this.onLongPressEnd,
  });

  final Widget child;

  /// 对焦反馈层的状态 key：读取对焦框可见性（可见期间启用纵向拖动调曝光）
  /// 与 AE/AF 锁定态，并驱动太阳滑块位置更新。
  final GlobalKey<_FocusOverlayState>? focusKey;

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

  /// 纵向拖动调曝光的起始「对焦偏移」（未在拖动时为 null）
  double? _exposureStartOffset;

  /// 纵向拖动调曝光的起始 Y 坐标（未在拖动时为 null）
  double? _exposureStartY;

  void _resetGesture() {
    _lastScale = 1.0;
    _currentMultiplier = 1.0;
    _lastPointerCount = 0;
    _lastAppliedMultiplier = null;
    _exposureStartOffset = null;
    _exposureStartY = null;
  }

  /// 对焦框可见期间的单指纵向拖动：向上拖动增大对焦曝光、向下减小
  /// （模仿 iOS 原相机：轻点对焦后即可上下拖动太阳滑块，无需先长按锁定）。
  ///
  /// 只改 [CaptureState.focusExposureOffsetProvider]（锚定当前对焦点的临时微调），
  /// **不动**参数面板 / 胶囊的 `exposureCompensation`（模板/会话曝光基准）。
  /// 150px 位移 ≈ 3 EV；与当前值差 < 0.05 时不下发，避免每帧刷 provider。
  void _applyExposureDrag(ScaleUpdateDetails details) {
    final startY = _exposureStartY;
    final startOffset = _exposureStartOffset;
    if (startY == null || startOffset == null) return;
    final dy = details.localFocalPoint.dy - startY;
    // 偏移量上限取「参数 EV 基准到 ±3 档满量程的余量」，保证太阳滑块位置
    // 与实际下发的曝光始终一致（基准越接近满量程，可偏移区间越窄）
    final baseEv = ref
        .read(CaptureState.effectiveCameraProvider)
        .exposureCompensation
        .clamp(-3.0, 3.0);
    final offset = (startOffset - dy / 150).clamp(-3.0 - baseEv, 3.0 - baseEv);
    final current = ref.read(CaptureState.focusExposureOffsetProvider);
    if ((offset - current).abs() < 0.05) return;
    ref.read(CaptureState.focusExposureOffsetProvider.notifier).state = offset;
    widget.focusKey?.currentState?.updateExposure(offset);
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
        onScaleStart: (details) {
          _resetGesture();
          // 对焦框可见期间（轻点对焦 / AE-AF 锁定）单指纵向拖动用于调曝光：
          // 记录起始偏移与起始 Y，并让对焦框+太阳滑块在拖动期间挂住不淡出
          final overlay = widget.focusKey?.currentState;
          if (overlay?.isFocusActive == true) {
            final startOffset =
                ref.read(CaptureState.focusExposureOffsetProvider);
            _exposureStartOffset = startOffset;
            _exposureStartY = details.localFocalPoint.dy;
            overlay?.beginExposureDrag();
          }
        },
        onScaleUpdate: (details) {
          final pc = details.pointerCount;
          if (pc < 2) {
            // 单指/点击不干扰缩放（点击对焦仍由相机组件处理）；
            // 对焦框可见期间则用于纵向拖动调曝光。
            _applyExposureDrag(details);
            _lastPointerCount = pc;
            return;
          }
          // 双指落下：退出曝光拖动，恢复对焦框的自动淡出，只走原有缩放逻辑
          if (_exposureStartY != null) {
            _exposureStartOffset = null;
            _exposureStartY = null;
            widget.focusKey?.currentState?.endExposureDrag();
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
        onScaleEnd: (_) {
          _resetGesture();
          widget.focusKey?.currentState?.endExposureDrag();
        },
        child: widget.child,
      );
    });
  }
}

/// 叠照片浮层通用金色（金色对焦框 / 曝光太阳图标共用）。
/// 属叠照片叠加视觉：跨风格固定金色，不随主题变化（硬编码主题色的唯一合法例外）。
const Color _focusGold = Color(0xE6FFCA28); // Colors.amber.shade400 @ 0.9

/// 将 [value] 钳制到 [min, max]；区间非法（max < min，即取景框过小）时取中点，
/// 避免 `num.clamp` 在 lowerLimit > upperLimit 时抛 ArgumentError。
double _clampInto(double value, double min, double max) =>
    max < min ? (min + max) / 2 : value.clamp(min, max);

/// 对焦反馈层：渲染金色四角对焦框（单击对焦）、框右侧太阳滑块（上下拖动调曝光，
/// 单击对焦即出现）与「AE/AF 锁定」标签（长按锁定）。
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
  /// 对焦框尺寸（与 [_FocusFrameState._size] 一致，用于边界钳制）
  static const double _frameSize = 70.0;
  /// 「AE/AF 锁定」徽标尺寸估算（用于边界钳制）
  static const double _badgeWidth = 70.0;
  static const double _badgeHeight = 36.0;
  /// 徽标与对焦框的默认间距
  static const double _badgeGap = 56.0;
  /// 太阳滑块尺寸（细竖线轨道 2×88 + 太阳图标 16）
  static const double _exposureTrackHeight = 88.0;
  static const double _exposureIconSize = 16.0;
  /// 对焦框（含太阳滑块）可见时长：模仿 iOS 原相机，轻点后约 2.5s 淡出；
  /// 拖动调曝光期间挂住不淡出，松手后重新计时
  static const Duration _focusDisplayDuration = Duration(milliseconds: 2500);
  /// 取景框内安全边距
  static const double _edgeMargin = 8.0;

  Offset? _point;
  bool _locked = false;
  bool _visible = false;
  Timer? _hideTimer;

  /// 单击对焦 5s 后恢复连续自动对焦/曝光的定时器（统一三端行为）
  Timer? _autoRecoverTimer;

  /// 最近一次单击对焦时的取景框尺寸（5s 恢复连续自动对焦时回传原生）
  Size? _lastPreviewSize;

  /// 当前对焦曝光偏移（相对参数 EV 基准；0 = 太阳图标停在竖线中点）
  double _exposureOffset = 0.0;

  bool get isLocked => _locked;

  /// 对焦框（含太阳滑块）是否可见。可见期间单指纵向拖动即可调曝光
  /// ——模仿 iOS 原相机「轻点屏幕显示自动对焦区域和曝光设置（太阳图标）」。
  bool get isFocusActive => _visible;

  /// 单击对焦：显示金色对焦框 + 右侧太阳滑块（模仿 iOS 原相机：轻点即同时
  /// 显示对焦区域与曝光设置），约 2.5s 后一起淡出；
  /// 同时（重置）起 5s 定时器，到点恢复连续自动对焦/曝光——此前 iOS/OHOS
  /// 单击对焦后会停在「单次对焦」，与 Android 的 5s 自动恢复不一致。
  void showFocus(Offset point, Size previewSize) {
    _hideTimer?.cancel();
    _autoRecoverTimer?.cancel();
    // 换点重新测光：对焦曝光偏移归零（对齐 iPhone，太阳图标回到中点）。
    // 只归零临时偏移，不动参数面板/模板里的 EV 基准。
    ref.read(CaptureState.focusExposureOffsetProvider.notifier).state = 0.0;
    setState(() {
      _point = point;
      _lastPreviewSize = previewSize;
      _locked = false;
      _visible = true;
      _exposureOffset = 0.0;
    });
    _restartHideTimer();
    _autoRecoverTimer = Timer(const Duration(seconds: 5), () {
      final p = _point;
      final s = _lastPreviewSize;
      if (!mounted || p == null || s == null) return;
      // locked=false 时原生忽略坐标，仅恢复到连续自动对焦/曝光
      ref.read(cameraServiceProvider).setFocusAndExposureLock(
            locked: false,
            position: p,
            previewSize: s,
          );
    });
  }

  /// 长按锁定：显示金色对焦框 + 「AE/AF 锁定」标签 + 太阳滑块，常驻不消失
  /// （对齐原相机：锁定后太阳图标一直挂在框边，可随时再上下拖动拉曝光）。
  /// 锁定同样是一次新的测光（在新触点上），故对焦曝光偏移一并归零。
  void showLock(Offset point) {
    _hideTimer?.cancel();
    _autoRecoverTimer?.cancel();
    ref.read(CaptureState.focusExposureOffsetProvider.notifier).state = 0.0;
    setState(() {
      _point = point;
      _locked = true;
      _visible = true;
      _exposureOffset = 0.0;
    });
  }

  /// 解除锁定并隐藏（用于「锁定后单击其他位置」的解锁阶段）。
  void unlock() {
    _hideTimer?.cancel();
    _autoRecoverTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _locked = false;
      _visible = false;
    });
  }

  /// 开始纵向拖动调曝光：拖动期间对焦框与太阳滑块挂住不淡出
  /// （模仿 iOS：手指按住拖动时对焦区域与太阳图标保持可见）。
  void beginExposureDrag() {
    if (!mounted || !_visible) return;
    _hideTimer?.cancel();
  }

  /// 拖动过程中更新太阳图标在竖线上的位置（[offset] 为对焦曝光偏移）。
  void updateExposure(double offset) {
    if (!mounted || !_visible) return;
    _hideTimer?.cancel();
    if ((_exposureOffset - offset).abs() < 0.001) return;
    setState(() => _exposureOffset = offset);
  }

  /// 结束纵向拖动：未锁定则重新计时淡出；锁定态常驻不淡出。
  void endExposureDrag() {
    if (!mounted || !_visible || _locked) return;
    _restartHideTimer();
  }

  /// （重新）起「对焦框 + 太阳滑块」淡出定时器。
  void _restartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_focusDisplayDuration, () {
      if (!mounted) return;
      setState(() => _visible = false);
    });
  }

  @override
  void didUpdateWidget(_FocusOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 兜底：facing 变化时复位（正常路径由外层 KeyedSubtree 重建完成）。
    if (widget.facing != oldWidget.facing) {
      _hideTimer?.cancel();
      _autoRecoverTimer?.cancel();
      _point = null;
      _lastPreviewSize = null;
      _locked = false;
      _visible = false;
      // 对焦偏移锚定的是上一个摄像头的对焦点，换摄后该点已不存在，连同对焦框
      // 一起归零，否则会留下用户看不见、也无法复位的残余曝光。
      // riverpod 禁止在 didUpdateWidget 内直接写 provider，故用 post-frame。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(CaptureState.focusExposureOffsetProvider.notifier).state = 0.0;
      });
      _exposureOffset = 0.0;
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _autoRecoverTimer?.cancel();
    super.dispose();
  }

  /// 对焦框中心安全钳制，保证 70×70 完整可见。
  Offset _clampFocusCenter(Offset point, Size bounds) {
    const half = _frameSize / 2;
    return Offset(
      _clampInto(
          point.dx, _edgeMargin + half, bounds.width - _edgeMargin - half),
      _clampInto(
          point.dy, _edgeMargin + half, bounds.height - _edgeMargin - half),
    );
  }

  /// 「AE/AF 锁定」徽标：默认在对焦框下方（56px），下方空间不足时翻到对焦框
  /// 上方；左右/上下均钳制在取景框内，避免贴边溢出。
  Widget _buildLockBadge(Offset center, Size bounds, ThemeTokens tokens) {
    final centerX = _clampInto(
      center.dx,
      _edgeMargin + _badgeWidth / 2,
      bounds.width - _edgeMargin - _badgeWidth / 2,
    );
    final belowTop = center.dy + _badgeGap;
    final fitsBelow = belowTop + _badgeHeight <= bounds.height - _edgeMargin;
    final rawTop = fitsBelow ? belowTop : center.dy - _badgeGap - _badgeHeight;
    final top = _clampInto(
      rawTop,
      _edgeMargin,
      bounds.height - _edgeMargin - _badgeHeight,
    );
    return _LockBadge(centerX: centerX, top: top, tokens: tokens);
  }

  /// 太阳滑块：贴在金色对焦框右侧，钳制在取景框内避免贴边溢出。
  Widget _buildExposureSlider(Offset center, Size bounds) {
    final left = _clampInto(
      center.dx + _frameSize / 2 + _edgeMargin,
      _edgeMargin,
      bounds.width - _edgeMargin - _exposureIconSize,
    );
    final top = _clampInto(
      center.dy - _exposureTrackHeight / 2,
      _edgeMargin,
      bounds.height - _edgeMargin - _exposureTrackHeight,
    );
    return _ExposureSlider(offset: _exposureOffset, left: left, top: top);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible || _point == null) return const SizedBox.shrink();
    final tokens = ref.watch(appThemeProvider).tokens;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bounds = Size(constraints.maxWidth, constraints.maxHeight);
          final center = _clampFocusCenter(_point!, bounds);
          return Stack(
            children: [
              _FocusFrame(point: center),
              // 太阳滑块与对焦框同生共灭：轻点对焦即出现（模仿 iOS 原相机），
              // 上下拖动即在两者可见期间调整曝光
              _buildExposureSlider(center, bounds),
              if (_locked) _buildLockBadge(center, bounds, tokens),
            ],
          );
        },
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
    // 金色：叠照片叠加视觉，跨风格固定金色（与曝光条共用 _focusGold）
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
        child: const CustomPaint(
          key: Key('focus_frame'),
          size: Size(_size, _size),
          painter: _FocusFramePainter(
            color: _focusGold,
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

/// 「AE/AF 锁定」胶囊标签：默认对焦框正下方（约 56px）居中显示，
/// 由 [_FocusOverlayState] 传入已钳制的水平中心 [centerX] 与 [top]
/// （下方空间不足时会翻到对焦框上方）。
///
/// 实心 `tokens.surface` + 细边 `tokens.divider` + `tokens.textPrimary` 文字，
/// 跨风格通用叠照片浮层：不使用 BackdropFilter / 阴影 / 玻璃。
class _LockBadge extends StatelessWidget {
  const _LockBadge({
    required this.centerX,
    required this.top,
    required this.tokens,
  });

  /// 已钳制在取景框内的水平中心（配合 FractionalTranslation 居中渲染）
  final double centerX;

  /// 已钳制在取景框内的顶部位置
  final double top;

  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: centerX,
      top: top,
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

/// 曝光补偿太阳滑块（模仿 iOS 原相机：金色对焦框右侧一条细竖线，
/// 太阳图标沿竖线上下滑动，向上 = 加曝光 / 向下 = 减曝光）。
///
/// 位置反映的是**对焦曝光偏移**（相对参数 EV 基准的临时微调），
/// 0 表示本次测光点无补偿 —— 与参数面板/胶囊显示的 EV 基准是两回事。
///
/// - 轨道：2×88 细竖线，白色半透明（叠照片叠加视觉，跨风格固定，不随主题变化）
/// - 太阳图标：金色（与对焦框同色），偏移 0 时停在竖线中点，±3 档滑到两端
/// 无阴影、无模糊、无玻璃（叠照片浮层铁律）。
class _ExposureSlider extends StatelessWidget {
  const _ExposureSlider({
    required this.offset,
    required this.left,
    required this.top,
  });

  /// 当前对焦曝光偏移（-3..3，0 = 无补偿）
  final double offset;

  /// 已钳制在取景框内的左侧位置
  final double left;

  /// 已钳制在取景框内的顶部位置
  final double top;

  static const double _trackWidth = 2.0;
  static const double _trackHeight = 88.0;
  static const double _iconSize = 16.0;
  /// 太阳图标自轨道中点起可达的最大位移（留出图标半径，避免贴出两端）
  static const double _maxTravel = _trackHeight / 2 - _iconSize / 2;
  /// 与 [CaptureState.effectiveExposureEvProvider] 的满量程一致：±3 档
  static const double _maxOffset = 3.0;

  @override
  Widget build(BuildContext context) {
    final ratio = (offset / _maxOffset).clamp(-1.0, 1.0);
    return Positioned(
      left: left,
      top: top,
      child: SizedBox(
        width: _iconSize,
        height: _trackHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              key: const Key('focus_exposure_bar'),
              width: _trackWidth,
              height: _trackHeight,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.35),
                borderRadius: BorderRadius.circular(_trackWidth / 2),
              ),
            ),
            Transform.translate(
              // 向上（正 EV）为负向位移
              offset: Offset(0, -ratio * _maxTravel),
              child: const Icon(
                Icons.wb_sunny,
                size: _iconSize,
                color: _focusGold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// iOS/OHOS 取景器逐帧效果同步器。
///
/// 监听 [PostProcess] 变化（微节流 16ms 去抖），把完整色彩矩阵 + 锐化/磨皮/
/// 暗角/颗粒参数推给原生 GPU 管线（iOS `PreviewEffectProcessor` /
/// OHOS `libpreview_fx.so`），使取景器实时呈现与成片一致的细节效果
/// （WYSIWYG）。调用方已按平台分支，Android 不走本组件
/// （仍用 Dart ColorFiltered 矩阵叠加）。
class _PostEffectSync extends StatefulWidget {
  const _PostEffectSync({
    required this.enabled,
    required this.post,
    required this.child,
  });

  /// 是否启用取景器效果。为 false（rawMode）时推全零参数关闭原生处理。
  final bool enabled;
  final PostProcess post;
  final Widget child;

  @override
  State<_PostEffectSync> createState() => _PostEffectSyncState();
}

class _PostEffectSyncState extends State<_PostEffectSync> {
  Timer? _debounce;
  PostProcess? _lastPushed;
  bool? _lastEnabled;

  @override
  void initState() {
    super.initState();
    _push();
  }

  @override
  void didUpdateWidget(_PostEffectSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    _push();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _push() {
    if (identical(widget.post, _lastPushed) &&
        widget.enabled == _lastEnabled) {
      return;
    }
    _lastPushed = widget.post;
    _lastEnabled = widget.enabled;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 16), _applyLatest);
  }

  Future<void> _applyLatest() async {
    try {
      if (!widget.enabled) {
        // rawMode：全零 → 原生处理器关闭，恢复原始取景帧（免 GPU）。
        await CamerawesomePlugin.updatePreviewEffects(
          matrix: null, vignette: 0, smooth: 0, sharpen: 0, grain: 0,
        );
        return;
      }
      final p = widget.post;
      final matrix = composePostProcessMatrix(p);
      // 诊断（2026-09-19 前置白平衡软件模拟）：确认矩阵是否到达本层。
      debugPrint('[fx] _applyLatest enabled=${widget.enabled} '
          'frontWb=${p.frontWbCompensation?.r}/${p.frontWbCompensation?.b} '
          'm0=${matrix[0]} m6=${matrix[6]} m12=${matrix[12]}');
      await CamerawesomePlugin.updatePreviewEffects(
        // 全中性时传 null → 原生处理器保持不激活、走免 GPU 直通快路径。
        matrix: _isIdentityMatrix(matrix) ? null : matrix,
        vignette: p.vignette.toDouble(),
        smooth: p.smoothStrength.toDouble(),
        sharpen: p.sharpen.toDouble(),
        grain: p.grain.toDouble(),
      );
    } catch (e) {
      debugPrint('[camera] updatePreviewEffects failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Android 取景器实时预览包装：仅实时呈现色彩矩阵（ColorFiltered）。
///
/// 2026-09-05 停用「真视图层逐帧美颜」（_LiveBeautyLayer，已删除）：
/// Dart 层 Ticker 逐帧 RepaintBoundary.toImage 读回在 OHOS 上单帧需数百 ms
/// （快门冻结帧实测 455ms@1.0x，叠加层按 DPR 级采样更慢），取景器沦为幻灯片；
/// 且 shader 半径-1 的 5-tap 磨皮核在预览分辨率下视觉不可感知（成片的
/// 频率分离磨皮才可见）。回退纯 ColorFiltered：色彩/亮度等矩阵效果仍实时预览，
/// 磨皮/锐化/颗粒/暗角仅作用于成片。2026-09-05 起 OHOS 改由原生 GPU 管线
/// （libpreview_fx.so：预览流→GL 着色器→Flutter Texture）接管全部实时特效
/// （见 _PostEffectSync），本包装仅剩 Android 使用。
Widget _buildAndroidLivePreview(PostProcess post, Widget child) =>
    ColorFiltered(colorFilter: fromPostProcess(post), child: child);

/// 判断 20 元素 ColorMatrix 是否为恒等（无任何色彩调整）。
bool _isIdentityMatrix(List<double> m) {
  for (var i = 0; i < 20; i++) {
    final row = i ~/ 5;
    final col = i % 5;
    final expected = col == 4 ? 0.0 : (row == col ? 1.0 : 0.0);
    if ((m[i] - expected).abs() > 1e-9) return false;
  }
  return true;
}

// ─────────────────────────────────────────────────────────────────────
// 拉腿实时预览说明（LegStretchPreviewOverlay 已移除）
// ─────────────────────────────────────────────────────────────────────
// 早期实现：从 RepaintBoundary 抓帧（toImage 降采样 400px）→ 后台 isolate 像素拉伸
// （LegStretchWorker）→ 以「半透明幽灵」叠加在实时取景之上。该方案在 iOS/OHOS 上
// 存在 GPU 读回打断渲染管线导致的卡顿，以及新旧帧半透明叠加产生的重影。
//
// 现已替换为「双层 GPU 合成」：取景器纹理在 camerawesome 底层直接以两个 Texture
// 图层渲染（锚点 60% 高度上方恒等、下方 Transform 纵向放大），全程零 GPU 读回、
// 零 CPU 逐像素拉伸、零半透明叠层 → 取景器不卡顿、无重影，且与成片 legStretchRgba
// 几何一致（WYSIWYG）。拉腿强度经 CameraPreviewConfig.legStretch 透传至底层。