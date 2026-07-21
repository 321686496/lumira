import 'package:camerawesome_ohos/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:lumira_app_flutter/features/capture/domain/filter_recipe.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/templates/data/templates_editor_mock_data.dart'
    show EditorForm, EditorFormPostProcess, EditorFormComposition;
import 'package:lumira_app_flutter/features/templates/widgets/composition_overlay.dart';
import 'package:lumira_app_flutter/features/templates/widgets/pose_silhouette.dart';

import '../data/capture_state.dart';

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
/// 使用 camerawesome_ohos 1.0.2（CPF-Flutter Harmony 适配版本，对应原 camerawesome 1.4.0）实现。
/// 在真实设备上渲染相机预览；在 widget 测试中通过 cameraPreviewOverrideProvider 覆盖为占位 widget。
///
/// 视觉规格来源：lumira-app/src/pages/capture/index.vue line 44-68
///
/// 改造说明（移除 camerawesome 自带 UI）：
/// 早期版本使用 `CameraAwesomeBuilder.awesome(...)`，该工厂会自动加载 `AwesomeCameraLayout`，
/// 包含自带的顶部闪光灯/宽高比按钮、中间滤镜/模式选择器、底部拍摄按钮/摄像头切换/缩略图，
/// 与项目自定义 UI（CaptureNav/ParamPillBar/CaptureButton/ParamPanel 等）完全重叠。
/// 现改为 `CameraAwesomeBuilder.custom(...)`，传入返回 `SizedBox.shrink()` 的 builder，
/// 让 camerawesome 不渲染任何自带 UI，仅保留纯粹的相机预览 + 点击对焦 + 双指缩放手势。
/// 所有拍摄/缩放/摄像头切换/滤镜/参数功能均由项目自定义 UI 通过 [CameraState] 实现。
///
/// Forced fix: brief 原代码使用 camerawesome 1.5+ 的 API（sensorConfig / SingleCaptureRequest /
/// CaptureRequestType / mediaCapture.capture(onSuccess:, onImage:) / builder:），与已锁定的
/// camerawesome 1.4.0 实际 API 不匹配。1.4.0 的 `.custom()` 工厂接受 `builder:` 参数，
/// builder 签名为 `Widget Function(CameraState, PreviewSize, Rect)`；
/// `SaveConfig.photo(pathBuilder:)` 的 pathBuilder 返回 `Future<String>`；
/// `onPreviewTapBuilder` / `onPreviewScaleBuilder` 用于启用默认的点击对焦和双指缩放手势。
///
/// Harmony 适配：pub.dev 上的 camerawesome 无 ohos 实现，平台通道无人响应会导致取景器一直转圈。
/// 改用 CPF-Flutter fork 的 camerawesome_ohos 包（gitcode.com/CPF-Flutter/fluttertpc_camerawesome）。
class CameraPreview extends ConsumerWidget {
  const CameraPreview({
    super.key,
    required this.onCaptured,
    this.onCameraStateCreated,
    this.formOverride,
  });

  /// 拍照完成回调（传入文件路径）
  final void Function(String path) onCaptured;

  /// CameraState 创建回调（首次进入 PhotoCameraState 时触发）
  /// 上层通过此回调拿到 CameraState，用于实现拍照/缩放/摄像头切换等功能
  final void Function(CameraState state)? onCameraStateCreated;

  /// 表单覆盖参数（Bug 12 修复：模板预览页使用）
  ///
  /// 当非 null 时，使用此 EditorForm 的 postProcess/composition/pose.silhouette
  /// 替代 CaptureState providers 中的对应值。用于模板预览页直接套用编辑器表单参数。
  ///
  /// 取景器仍读 CaptureState 的 flash/facing 等基础相机控制 providers。
  final EditorForm? formOverride;

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
    final showSilhouette = hasOverride || ref.watch(CaptureState.showSilhouetteProvider);
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

    // 相机预览本体：测试中由 override 替换 CameraAwesomeBuilder 部分，
    // 但保留滤镜和构图叠图逻辑（让测试可以验证 ColorFiltered/CompositionOverlay 包裹）
    final cameraWidget = overrideWidget ?? CameraAwesomeBuilder.custom(
      saveConfig: SaveConfig.photo(
        pathBuilder: () async {
          // 1.4.0: pathBuilder 返回 Future<String>（路径），由调用方决定保存位置
          // 使用 path_provider 生成时间戳路径，确保 takePhoto() 能成功写入文件
          final dir = await getTemporaryDirectory();
          final ts = DateTime.now().millisecondsSinceEpoch;
          return '${dir.path}/capture_$ts.jpg';
        },
      ),
      sensor: facing == 'front' ? Sensors.front : Sensors.back,
      flashMode: _mapFlashMode(flashMode),
      // builder 返回空 widget，移除 camerawesome 自带的 AwesomeCameraLayout
      // （顶部闪光灯按钮、中间滤镜/模式选择器、底部拍摄按钮/摄像头切换/缩略图）
      // 所有 UI 由项目自定义组件通过 Stack 叠加在 CameraPreview 上
      builder: (cameraState, previewSize, previewRect) {
        // 首次拿到 CameraState 时通知上层（用于实现拍照/缩放/切换等功能）
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onCameraStateCreated?.call(cameraState);
        });
        return const SizedBox.shrink();
      },
      // 启用默认的点击对焦手势（AwesomeCameraGestureDetector 内部处理）
      onPreviewTapBuilder: (state) => OnPreviewTap(
        onTap: (position, flutterPreviewSize, pixelPreviewSize) {
          state.when(
            onPhotoMode: (photoState) => photoState.focusOnPoint(
              flutterPosition: position,
              pixelPreviewSize: pixelPreviewSize,
              flutterPreviewSize: flutterPreviewSize,
            ),
            onPreviewMode: (previewState) => previewState.focusOnPoint(
              flutterPosition: position,
              pixelPreviewSize: pixelPreviewSize,
              flutterPreviewSize: flutterPreviewSize,
            ),
          );
        },
      ),
      // 启用默认的双指缩放手势，同步到 zoomProvider 以便 UI 显示当前缩放级别
      onPreviewScaleBuilder: (state) => OnPreviewScale(
        onScale: (scale) {
          state.sensorConfig.setZoom(scale);
        },
      ),
    );

    // 滤镜包裹（修复 Bug 2/3：使用 effectivePost，自由模式也应用）
    final filteredCamera = applyFilter
        ? ColorFiltered(
            colorFilter: fromPostProcess(effectivePost),
            child: cameraWidget,
          )
        : cameraWidget;

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
    // Bug 12 修复：formOverride 非空时使用 formOverride.pose.silhouette
    // 注意：EditorForm 和 PhotoTemplate 都有 SilhouetteResource 类（同名不同类），
    // 这里统一提取为基本类型（String/-double）避免类型冲突
    final String silhouetteType;
    final String silhouetteData;
    final double silhouetteScale;
    final double silhouetteRotation;
    final bool hasSilhouette;
    if (formOverride != null) {
      silhouetteType = formOverride!.pose.silhouette.type;
      silhouetteData = formOverride!.pose.silhouette.data;
      silhouetteScale = formOverride!.pose.scale;
      silhouetteRotation = formOverride!.pose.rotation;
      hasSilhouette = silhouetteData != 'none';
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

  FlashMode _mapFlashMode(CaptureFlashMode mode) {
    switch (mode) {
      case CaptureFlashMode.off:
        return FlashMode.none;
      case CaptureFlashMode.on:
        return FlashMode.always;
      case CaptureFlashMode.auto:
        return FlashMode.auto;
      case CaptureFlashMode.torch:
        return FlashMode.always;
    }
  }
}

/// 测试覆写 provider（生产环境为 null，测试中注入占位 widget）
final cameraPreviewOverrideProvider = Provider<Widget?>((ref) => null);
