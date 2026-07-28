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
  /// 由拍摄页 _onZoomChanged 同步写入，与 [zoomProvider] 保持一致。
  static final apparentZoomProvider = StateProvider<double>((ref) => 0.0);

  /// 默认缩放范围（前端：0.5x ~ 2x；后端：0.3x ~ 10x）
  /// 真实设备的 minZoom/maxZoom 通过 SensorConfig 查询；这里作为 fallback。
  static const double frontMinZoom = 0.5;
  static const double frontMaxZoom = 2.0;
  static const double backMinZoom = 0.3;
  static const double backMaxZoom = 10.0;

  /// 缩放倍数 → 归一化 [0, 1]（用于 sensorConfig.setZoom）
  static double zoomMultiplierToNormalized(
      double multiplier, double minZoom, double maxZoom) {
    if (maxZoom <= minZoom) return 0.0;
    return ((multiplier - minZoom) / (maxZoom - minZoom)).clamp(0.0, 1.0);
  }

  /// 归一化 [0, 1] → 缩放倍数（用于 UI 显示）
  static double normalizedToZoomMultiplier(
      double normalized, double minZoom, double maxZoom) {
    return minZoom + (maxZoom - minZoom) * normalized.clamp(0.0, 1.0);
  }

  /// 根据当前 facing 获取缩放范围
  static ZoomRange zoomRangeForFacing(String facing) {
    return facing == 'front'
        ? const ZoomRange(frontMinZoom, frontMaxZoom)
        : const ZoomRange(backMinZoom, backMaxZoom);
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
  ///
  /// 支持任意 "W:H" 格式（如 '4:5'、'16:9'、'9:16'、'2:3'），
  /// 用于模板的 cropRatio 字段。'W:H' 始终按字面比例计算（不做方向自适应），
  /// 因为模板的 cropRatio 已经表达了作者期望的最终画面方向。
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
        // 解析任意 "W:H" 格式（如 '4:5'、'16:9'、'9:16'、'2:3'）
        final parts = ratioId.split(':');
        if (parts.length == 2) {
          final w = double.tryParse(parts[0]);
          final h = double.tryParse(parts[1]);
          if (w != null && h != null && w > 0 && h > 0) {
            return w / h;
          }
        }
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
    container.read(apparentZoomProvider.notifier).state = 0.0;
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

/// 缩放范围（最小与最大倍数）
/// 真实设备的 minZoom/maxZoom 通过 SensorConfig 查询；
/// `CaptureState.zoomRangeForFacing` 提供默认 fallback 范围。
class ZoomRange {
  const ZoomRange(this.min, this.max);

  final double min;
  final double max;
}
