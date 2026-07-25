import 'dart:math' as math;

import 'package:camerawesome_ohos/camerawesome_plugin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/photo_template.dart';
import '../domain/scene_preset.dart';
import '../data/template_registry.dart';
import '../data/scene_presets_data.dart';

/// 闪光灯模式
enum CaptureFlashMode { off, on, auto, torch }

/// 拍摄页状态 providers
class CaptureState {
  CaptureState._();

  // ── 已有 providers（保留不变）──
  static final currentTemplateIdProvider = StateProvider<String?>((ref) => null);
  static final flashModeProvider = StateProvider<CaptureFlashMode>((ref) => CaptureFlashMode.off);
  static final isFullscreenProvider = StateProvider<bool>((ref) => false);
  static final showTemplateProvider = StateProvider<bool>((ref) => true);
  static final showSilhouetteProvider = StateProvider<bool>((ref) => true);
  static final lastPhotoPathProvider = StateProvider<String?>((ref) => null);
  static final cameraFacingProvider = StateProvider<String>((ref) => 'back');

  // ── 相机引擎状态（由 CameraPreview 通过 onCameraStateCreated 回调注入）──
  // 持有 camerawesome 的 CameraState 引用，用于实现真实拍照/缩放/摄像头切换/闪光灯同步。
  // 测试环境中为 null（cameraPreviewOverrideProvider 注入占位 widget，不创建真实 CameraState）。
  static final cameraStateProvider = StateProvider<CameraState?>((ref) => null);

  /// 当前缩放级别（0.0 = 无缩放，1.0 = 最大缩放）
  /// 由双指缩放手势或自定义滑块更新，再同步到 [cameraStateProvider] 的 sensorConfig
  static final zoomProvider = StateProvider<double>((ref) => 0.0);

  /// 用户面对的"视觉缩放"（与取景器中显示的内容大小一致，跨比例切换保持稳定）。
  /// 范围 [0.0, 1.0]，0 = 1x，1 = 最大缩放。
  /// 切换比例时此值不变，但实际传给 sensorConfig.setZoom 的值会按比例补偿。
  static final apparentZoomProvider = StateProvider<double>((ref) => 0.0);

  /// 根据 aspectRatio 和屏幕比例计算"比例补偿系数"。
  /// 全屏（不裁剪）时系数为 1.0；其他比例下，相机预览在更小的框内 cover 显示，
  /// 实际看到的视野更窄，等效于放大了 (boxHeight/screenHeight) 倍。
  /// 系数 = 视野缩放比 = 显示框的最短边 / 屏幕最短边。
  static double ratioCompensationFactor(String ratioId, bool isPortrait) {
    final target = computeTargetRatio(ratioId, isPortrait);
    if (target == null) return 1.0; // fullscreen
    // 这里只能给一个近似估计：3:4 框 vs 全屏框的差距
    // 全屏框 ratio ≈ 9/19.5 = 0.46（竖屏），3:4 框 ratio = 0.75
    // 假设屏幕短边固定，框短边 = 屏幕短边（竖屏即 width）
    // 框长边 / 屏幕长边 = ratio 屏 / ratio 框 = 0.46/0.75 ≈ 0.61
    // 即 3:4 框只显示屏幕全屏 61% 的高度 → 等效放大 1/0.61 ≈ 1.64
    // 但这只是在 width 上的差距；为简化，使用 width 比作为补偿
    if (isPortrait) {
      switch (ratioId) {
        case '4:3':
        case '3:4':
          return 0.75; // 3:4 框相对全屏框的宽度比
        case '1:1':
          return 1.0; // 1:1 框宽度等于屏宽
        default:
          return 1.0;
      }
    } else {
      switch (ratioId) {
        case '4:3':
          return 0.75;
        case '1:1':
          return 1.0;
        default:
          return 1.0;
      }
    }
  }

  /// 实际传给 sensorConfig.setZoom 的值。
  /// = sqrt(apparentZoom) * ratioCompensationFactor
  /// （sqrt 沿用原有曲线；乘以补偿系数让 3:4 框下的实际 sensor zoom 更小，
  /// 抵消框缩小带来的视觉放大）
  static double computeSensorZoom(double apparentZoom, double factor) {
    final sqrtZoom = math.sqrt(apparentZoom.clamp(0.0, 1.0));
    return (sqrtZoom * factor).clamp(0.0, 1.0);
  }

  /// 照片比例（用户可切换）
  /// 'fullscreen' = 与取景器全屏一致（9:16 或 16:9）
  /// '4:3' = 标准 4:3 比例
  /// '1:1' = 正方形
  /// '3:4' = 竖版 3:4
  static final aspectRatioProvider = StateProvider<String>((ref) => 'fullscreen');

  /// 计算目标宽高比（width / height），取景器显示与照片裁剪共用此逻辑以确保一致。
  ///
  /// 返回 null 表示 'fullscreen' 模式（应使用屏幕实际宽高比）。
  /// 方向自适应：'4:3' 在竖屏下显示为 3:4（标准相机 App 行为），
  /// '3:4' 始终为竖版 3:4（即使横屏也显示竖版长条）。
  static double? computeTargetRatio(String ratioId, bool isPortrait) {
    switch (ratioId) {
      case 'fullscreen':
        return null;
      case '4:3':
        // 标准相机比例，按设备方向自适应：竖屏→3:4，横屏→4:3
        return isPortrait ? 3.0 / 4.0 : 4.0 / 3.0;
      case '1:1':
        return 1.0;
      case '3:4':
        // 始终竖版 3:4
        return 3.0 / 4.0;
      default:
        return null;
    }
  }

  // ── 新增：模板编辑状态 ──

  /// 原始模板（只读，派生自 currentTemplateIdProvider）
  /// 当 currentTemplateIdProvider 为 null 时返回 null（自由拍摄模式）
  static final originalTemplateProvider = Provider<PhotoTemplate?>((ref) {
    final id = ref.watch(currentTemplateIdProvider);
    if (id == null) return null;
    return TemplateRegistry.getTemplate(id);
  });

  /// 可编辑模板副本（参数面板的所有修改都写到这里）
  /// 当 currentTemplateIdProvider 变化时，自动重置为新模板的副本
  /// （StateProvider 的 initializer 在依赖 invalidation 时重新执行）
  static final editableTemplateProvider = StateProvider<PhotoTemplate?>((ref) {
    final original = ref.watch(originalTemplateProvider);
    return original?.copyWith();
  });

  /// applied = editableTemplate 与 originalTemplate 是否完全一致
  /// true 表示用户没有修改任何参数（或已重置）
  static final appliedProvider = Provider<bool>((ref) {
    final original = ref.watch(originalTemplateProvider);
    final editable = ref.watch(editableTemplateProvider);
    if (original == null || editable == null) return false;
    return original == editable;
  });

  // ── 新增：模式开关 ──

  /// 原相机模式（禁用所有滤镜和后期）
  static final rawModeProvider = StateProvider<bool>((ref) => false);

  /// 参数面板展开状态
  static final panelExpandedProvider = StateProvider<bool>((ref) => false);

  /// 滤镜选择器可见状态
  static final filterPickerVisibleProvider = StateProvider<bool>((ref) => false);

  /// 底部可折叠面板展开状态
  static final bottomPanelExpandedProvider = StateProvider<bool>((ref) => false);

  // ── 新增：场景 ──

  /// 当前选中的场景预设 ID
  static final activeScenePresetIdProvider = StateProvider<String?>((ref) => null);

  /// 当前场景对应的完整滤镜配方（包含 lut 和 systemFilter）
  /// 由 ScenePresetStrip 选中场景时设置，CameraPreview 通过 watch 应用到取景器
  static final activeSceneFilterProvider =
      Provider<SceneFilter?>((ref) {
    final id = ref.watch(activeScenePresetIdProvider);
    if (id == null) return null;
    final preset = ScenePresetsData.getScenePreset(id);
    return preset?.filter;
  });

  /// 自由拍摄模式下的相机参数（无模板时使用）
  /// 解耦 ParamPanel 与 editableTemplate，使自由模式也能调参
  static final freeModeCameraProvider =
      StateProvider<CameraParams>((ref) => const CameraParams());

  /// 自由拍摄模式下的后期参数（无模板时使用）
  /// 包含色彩、细节、LUT、systemFilter 等所有 postProcess 参数
  static final freeModePostProcessProvider =
      StateProvider<PostProcess>((ref) => const PostProcess(color: PostProcessColor()));

  /// 自由拍摄模式下的构图参数（无模板时使用）
  static final freeModeCompositionProvider =
      StateProvider<Composition>((ref) => const Composition());

  /// 统一的可编辑相机参数（无论是否有模板，都返回当前生效的 CameraParams）
  /// ParamPanel 等组件通过此 provider 读取，避免 editable==null 时无法调参
  static final effectiveCameraProvider = Provider<CameraParams>((ref) {
    final editable = ref.watch(editableTemplateProvider);
    if (editable != null) return editable.camera;
    return ref.watch(freeModeCameraProvider);
  });

  /// 统一的可编辑后期参数（无论是否有模板）
  static final effectivePostProcessProvider = Provider<PostProcess>((ref) {
    final editable = ref.watch(editableTemplateProvider);
    if (editable != null) return editable.postProcess;
    return ref.watch(freeModePostProcessProvider);
  });

  /// 统一的可编辑构图参数（无论是否有模板）
  static final effectiveCompositionProvider = Provider<Composition>((ref) {
    final editable = ref.watch(editableTemplateProvider);
    if (editable != null) return editable.composition;
    return ref.watch(freeModeCompositionProvider);
  });

  /// 统一的可编辑场景指南（无论是否有模板，自由模式返回空 SceneGuide）
  static final effectiveSceneGuideProvider = Provider<SceneGuide>((ref) {
    final editable = ref.watch(editableTemplateProvider);
    return editable?.sceneGuide ?? const SceneGuide();
  });

  /// 统一更新相机参数的辅助方法
  /// 有模板时更新 editableTemplate，无模板时更新 freeModeCamera
  static void updateCamera(WidgetRef ref, CameraParams Function(CameraParams) updater) {
    final editable = ref.read(editableTemplateProvider);
    if (editable != null) {
      ref.read(editableTemplateProvider.notifier).state =
          editable.copyWith(camera: updater(editable.camera));
    } else {
      final current = ref.read(freeModeCameraProvider);
      ref.read(freeModeCameraProvider.notifier).state = updater(current);
    }
  }

  /// 统一更新后期参数的辅助方法
  static void updatePostProcess(WidgetRef ref, PostProcess Function(PostProcess) updater) {
    final editable = ref.read(editableTemplateProvider);
    if (editable != null) {
      ref.read(editableTemplateProvider.notifier).state =
          editable.copyWith(postProcess: updater(editable.postProcess));
    } else {
      final current = ref.read(freeModePostProcessProvider);
      ref.read(freeModePostProcessProvider.notifier).state = updater(current);
    }
  }

  /// 统一更新构图参数的辅助方法
  static void updateComposition(WidgetRef ref, Composition Function(Composition) updater) {
    final editable = ref.read(editableTemplateProvider);
    if (editable != null) {
      ref.read(editableTemplateProvider.notifier).state =
          editable.copyWith(composition: updater(editable.composition));
    } else {
      final current = ref.read(freeModeCompositionProvider);
      ref.read(freeModeCompositionProvider.notifier).state = updater(current);
    }
  }

  // ── 新增：水平仪 ──

  static final levelEnabledProvider = StateProvider<bool>((ref) => true);
  static final levelAngleProvider = StateProvider<double>((ref) => 0.0);

  // ── 新增：拍摄组合（内存态，Phase 1 不持久化）──

  static final kitsProvider = StateProvider<List<Object>>((ref) => []);

  /// 重置所有拍摄页状态
  static void resetAll(ProviderContainer container) {
    // 已有
    container.read(currentTemplateIdProvider.notifier).state = null;
    container.read(flashModeProvider.notifier).state = CaptureFlashMode.off;
    container.read(isFullscreenProvider.notifier).state = false;
    container.read(showTemplateProvider.notifier).state = true;
    container.read(showSilhouetteProvider.notifier).state = true;
    container.read(lastPhotoPathProvider.notifier).state = null;
    container.read(cameraFacingProvider.notifier).state = 'back';
    // 新增
    container.read(rawModeProvider.notifier).state = false;
    container.read(panelExpandedProvider.notifier).state = false;
    container.read(filterPickerVisibleProvider.notifier).state = false;
    container.read(bottomPanelExpandedProvider.notifier).state = false;
    container.read(activeScenePresetIdProvider.notifier).state = null;
    container.read(levelEnabledProvider.notifier).state = true;
    container.read(levelAngleProvider.notifier).state = 0.0;
    container.read(kitsProvider.notifier).state = [];
    // 引擎状态与缩放
    container.read(cameraStateProvider.notifier).state = null;
    container.read(zoomProvider.notifier).state = 0.0;
    container.read(aspectRatioProvider.notifier).state = 'fullscreen';
    // 自由模式参数
    container.read(freeModeCameraProvider.notifier).state = const CameraParams();
    container.read(freeModePostProcessProvider.notifier).state =
        const PostProcess(color: PostProcessColor());
    container.read(freeModeCompositionProvider.notifier).state = const Composition();
    // editableTemplateProvider 和 appliedProvider 是派生的，不需要显式重置
    // （当 currentTemplateIdProvider 设为 null 时，originalTemplateProvider 返回 null，
    //  editableTemplateProvider 会自动重置为 null）
  }
}
