import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  const CameraPreview({
    super.key,
    this.onZoomChanged,
    this.formOverride,
    this.previewFit = CameraPreviewFit.cover,
    this.rawCaptureKey,
  });

  /// 双指缩放手势回调（传入真实倍数，1.0 = 1x）。
  /// 由 CameraService 的 onScaleZoom 触发，透传给上层 _onZoomChanged 同步 provider 状态。
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overrideWidget = ref.watch(cameraPreviewOverrideProvider);
    final hasOverride = formOverride != null;

    // 当 formOverride 非空时，silhouette/composition/postProcess 都来自 formOverride，
    // 不再 watch editableTemplateProvider（避免预览页与拍摄页状态耦合）
    final editable = hasOverride
        ? null
        : ref.watch(CaptureState.editableTemplateProvider);

    final flashMode = ref.watch(CaptureState.flashModeProvider);
    final facing = ref.watch(CaptureState.cameraFacingProvider);
    final showTemplate = hasOverride || ref.watch(CaptureState.showTemplateProvider);
    // Bug fix: 当 formOverride 非空时，不在此处渲染剪影——
    // 调用方（如 _Viewfinder）会自行渲染可拖动的剪影交互层。
    // 否则会出现两个剪影叠加（中间一个不可拖 + 真实位置一个可拖）。
    final showSilhouette = !hasOverride && ref.watch(CaptureState.showSilhouetteProvider);
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
    final cameraWidget = overrideWidget ?? cameraService.buildPreview(
      config: CameraPreviewConfig(
        facing: facing,
        fit: previewFit,
        onReady: () => _onCameraReady(ref, flashMode, facing),
        onTapFocus: (position, previewSize) {
          cameraService.focusOnPoint(position, previewSize);
        },
        onScaleZoom: (scale) {
          // 透传给上层 _onZoomChanged，由其同步 provider 状态并下发原生相机
          onZoomChanged?.call(scale);
        },
      ),
    );

    // 原始相机流（未经 ColorFiltered 处理），用 RepaintBoundary 包裹以支持帧捕获。
    // rawCaptureKey 非 null 时，FilterPicker 可通过 boundary.toImage() 捕获当前帧，
    // 在滤镜卡片中套用各滤镜的 ColorFilter 显示实时效果预览。
    final rawCamera = rawCaptureKey != null
        ? RepaintBoundary(key: rawCaptureKey, child: cameraWidget)
        : cameraWidget;

    // 滤镜包裹（修复 Bug 2/3：使用 effectivePost，自由模式也应用）
    final filteredCamera = applyFilter
        ? ColorFiltered(
            colorFilter: fromPostProcess(effectivePost),
            child: rawCamera,
          )
        : rawCamera;

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
    final bool hasSilhouette;
    if (formOverride != null) {
      // formOverride 模式下不渲染剪影（showSilhouette 已为 false，hasSilhouette 不影响）
      silhouetteType = '';
      silhouetteData = 'none';
      silhouetteScale = 1.0;
      silhouetteRotation = 0.0;
      hasSilhouette = false;
    } else if (editable != null) {
      silhouetteType = editable.pose.silhouette.type;
      silhouetteData = editable.pose.silhouette.data;
      silhouetteScale = editable.pose.scale;
      silhouetteRotation = editable.pose.rotation;
      hasSilhouette = silhouetteData != 'none';
    } else {
      silhouetteType = '';
      silhouetteData = 'none';
      silhouetteScale = 1.0;
      silhouetteRotation = 0.0;
      hasSilhouette = false;
    }
    final silhouetteOverlay = (hasSilhouette && showSilhouette)
        ? Positioned.fill(
            child: IgnorePointer(
              child: PoseSilhouette(
                silhouetteType: silhouetteType,
                silhouetteData: silhouetteData,
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
      ],
    );
  }

  /// 相机就绪回调：应用初始闪光灯模式 + 重置缩放为 1x。
  /// 由 CameraService.buildPreview 的 onReady 触发（首次初始化和重建时）。
  ///
  /// 注：原 _onCameraStateCreated 中的 setMirrorFrontCamera（前置镜像）和
  /// setBrightness（EV 补偿）逻辑未迁移——CameraService 抽象接口当前未暴露
  /// 这些方法，依赖 camerawesome 默认行为。后续如需恢复可扩展 CameraService。
  void _onCameraReady(WidgetRef ref, CaptureFlashMode flashMode, String facing) {
    final cameraService = ref.read(cameraServiceProvider);
    // 应用闪光灯模式
    cameraService.setFlashMode(_mapFlashMode(flashMode));
    // 重置缩放为 1x
    cameraService.setZoom(1.0);
    final range = CaptureState.zoomRangeForFacing(facing);
    final normalized1x = CaptureState.zoomMultiplierToNormalized(
        1.0, range.min, range.max);
    ref.read(CaptureState.apparentZoomProvider.notifier).state = normalized1x;
    ref.read(CaptureState.zoomProvider.notifier).state = normalized1x;
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
