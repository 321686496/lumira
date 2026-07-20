import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/photo_template.dart';
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

  /// 当前场景对应的滤镜名称（派生）
  static final activeSceneFilterProvider = Provider<String?>((ref) {
    final id = ref.watch(activeScenePresetIdProvider);
    if (id == null) return null;
    final preset = ScenePresetsData.getScenePreset(id);
    return preset?.filter.lut;
  });

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
    // editableTemplateProvider 和 appliedProvider 是派生的，不需要显式重置
    // （当 currentTemplateIdProvider 设为 null 时，originalTemplateProvider 返回 null，
    //  editableTemplateProvider 会自动重置为 null）
  }
}
