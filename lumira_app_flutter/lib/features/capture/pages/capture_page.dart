import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../home/providers/banner_recommendation_provider.dart';
import '../../profile/providers/composition_kits_providers.dart';
import '../../../shared/widgets/feedback/lumira_toast.dart';
import '../data/capture_state.dart';
import '../data/capture_thumbnail_state.dart';
import '../domain/photo_template.dart';
import '../services/camera_service.dart';
import '../services/camera_service_provider.dart';
import '../services/photo_pipeline.dart';
import '../widgets/aspect_ratio_selector.dart';
import '../widgets/capture_button.dart';
import '../widgets/capture_nav.dart';
import '../widgets/camera_preview.dart';
import '../widgets/capture_thumbnail.dart';
import '../widgets/filter_picker.dart';
import '../widgets/level_indicator.dart';
import '../widgets/param_panel.dart';
import '../widgets/param_pill_bar.dart';
import '../widgets/scene_preset_strip.dart';
import '../widgets/shutter_feedback.dart';
import '../widgets/template_strip.dart';

/// 拍摄页（Phase 2 MVP）
///
/// 视觉规格来源：lumira-app/src/pages/capture/index.vue
/// 范围：导航栏 + 相机预览 + 拍摄按钮 + 缩略图 + 切换摄像头 + 横竖屏自适应 +
///      真实拍照/缩放/闪光灯同步/摄像头切换（通过 CameraState 实现）
///
/// 全屏模式说明（修复 Bug 10）：
/// - 全屏仅隐藏装饰性 UI（ParamPillBar、底部抽屉栏的模板/场景条）
/// - 保留 CaptureNav（含退出全屏按钮）和底部核心交互（拍摄按钮、缩略图、切换摄像头）
/// - 确保用户在全屏下仍能拍照、退出全屏
class CapturePage extends ConsumerStatefulWidget {
  const CapturePage({super.key, this.templateId, this.sceneId, this.kitId});

  /// 来自 URL ?templateId=xxx，null 表示自由拍摄
  final String? templateId;

  /// 来自 URL ?scene=xxx，表示从场景详情页进入，需应用场景预设
  final String? sceneId;

  /// 来自 URL ?kitId=xxx，表示套用组合套件（含场景+模板+参数覆盖）
  final String? kitId;

  @override
  ConsumerState<CapturePage> createState() => _CapturePageState();
}

/// 相机权限状态
enum CameraPermissionStatus { unknown, granted, denied, permanentlyDenied }

class _CapturePageState extends ConsumerState<CapturePage>
    with WidgetsBindingObserver {
  bool _isLandscape = false;
  CameraPermissionStatus _permissionStatus = CameraPermissionStatus.unknown;

  /// quickProcess 窗口阻塞标志：仅在 quickProcess 主 Isolate 处理期间为 true，
  /// 完成后立即恢复 false 以支持连拍。fullProcess 在后台 Isolate 执行，不阻塞。
  bool _isQuickProcessing = false;

  /// 白闪动画触发器：每次拍照时递增，ShutterFeedback widget 监听变化播放动画。
  int _shutterTrigger = 0;

  /// 返回结果模式：当通过 ?mode=return 进入时，拍照完成后 pop 回上一页
  /// （用于实战作业页的"去拍摄"流程，捕获路径作为 String 返回）
  bool _returnResult = false;

  /// 当前套用的 kit ID（用于拍照完成时 incrementUsage）
  String? _activeKitId;

  /// 相机重建 key：每次 app 从后台恢复时递增，
  /// 强制 CameraAwesomeBuilder 销毁旧实例并创建新实例，
  /// 确保原生相机被重新初始化（修复取景器一直转圈的问题）。
  int _cameraRebuildKey = 0;

  /// 缓存的 ProviderContainer 引用。
  /// 在 dispose() 中调用 ref.read 会触发 ProviderScope.containerOf(this)，
  /// 它通过 getElementForInheritedWidgetOfExactType 查询 widget 树祖先；
  /// 但 dispose() 执行时 element 已被 deactivate，断言 "Looking up a
  /// deactivated widget's ancestor is unsafe" 会抛出。
  /// 在 didChangeDependencies（element 仍 active）中缓存 container 引用，
  /// dispose 时通过引用直接操作 provider，绕过 widget 树查询。
  ProviderContainer? _container;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyRouteParamsToState();
      ref.read(CaptureState.currentTemplateIdProvider.notifier).state =
          widget.templateId;
      // 解析 returnResult 模式：?mode=return 时拍照完成后 pop 回上一页
      final mode = GoRouterState.of(context).queryParams[RouteNames.paramMode];
      _returnResult = mode == 'return';
      _requestCameraPermission();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Element 仍 active 时缓存 container，供 dispose() 使用
    _container = ProviderScope.containerOf(context);
  }

  /// 读取路由参数（sceneId / templateId / kitId）并应用到 CaptureState
  /// 优先级：kitId > templateId（套件已包含 templateId）；sceneId 独立设置
  Future<void> _applyRouteParamsToState() async {
    final kitId = widget.kitId;
    final sceneId = widget.sceneId;

    if (sceneId != null) {
      ref.read(CaptureState.activeScenePresetIdProvider.notifier).state =
          sceneId;
    }

    if (kitId == null) return;
    _activeKitId = kitId;

    try {
      final dao = await ref.read(compositionKitsDaoProvider.future);
      final kit = await dao.getById(kitId);
      if (kit == null) return;

      // 设置 sceneId（套件中的 sceneId 优先于 URL scene 参数）
      ref.read(CaptureState.activeScenePresetIdProvider.notifier).state =
          kit.sceneId;

      // 设置 templateId（套件中的 templateId 优先）
      if (kit.templateId != null) {
        ref.read(CaptureState.currentTemplateIdProvider.notifier).state =
            kit.templateId;
      }

      // 应用相机参数覆盖到 freeModeCamera（无模板时）或 editableTemplate（有模板时）
      final overrides = kit.cameraOverrides;
      if (overrides.isNotEmpty) {
        final editable = ref.read(CaptureState.editableTemplateProvider);
        if (editable != null) {
          // 有模板：基于模板相机参数叠加覆盖
          final newCamera = editable.camera.copyWith(
            exposureCompensation:
                (overrides['exposureCompensation'] as num?)?.toDouble() ??
                    editable.camera.exposureCompensation,
            iso: (overrides['iso'] as num?)?.toInt() ?? editable.camera.iso,
            shutterSpeed: (overrides['shutterSpeed'] as String?) ??
                editable.camera.shutterSpeed,
          );
          ref.read(CaptureState.editableTemplateProvider.notifier).state =
              editable.copyWith(camera: newCamera);
        } else {
          // 无模板：直接写 freeModeCamera
          final current = ref.read(CaptureState.freeModeCameraProvider);
          ref.read(CaptureState.freeModeCameraProvider.notifier).state =
              current.copyWith(
            exposureCompensation:
                (overrides['exposureCompensation'] as num?)?.toDouble() ??
                    current.exposureCompensation,
            iso: (overrides['iso'] as num?)?.toInt() ?? current.iso,
            shutterSpeed: (overrides['shutterSpeed'] as String?) ??
                current.shutterSpeed,
          );
        }
      }
    } catch (e) {
      debugPrint('[capture] 加载套件失败: $e');
    }
  }

  /// 请求相机权限
  /// 修复：原代码从未调用 permission_handler 请求运行时权限，
  /// 导致 CameraAwesomeBuilder 无法初始化，cameraStateProvider 始终为 null，
  /// _onCapture() 永远显示"相机正在初始化，请稍候..."
  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() {
      switch (status) {
        case PermissionStatus.granted:
          _permissionStatus = CameraPermissionStatus.granted;
          break;
        case PermissionStatus.permanentlyDenied:
          _permissionStatus = CameraPermissionStatus.permanentlyDenied;
          break;
        default:
          _permissionStatus = CameraPermissionStatus.denied;
      }
    });
  }

  @override
  void dispose() {
    // 通过 CameraService 抽象层释放原生相机资源（替代 CamerawesomePlugin.stop）。
    // 使用缓存的 container 引用，避免 ref.read 在 deactivated element 上查询 widget 树祖先。
    // dispose() 返回 Future，测试环境中无平台通道会异步抛 MissingPluginException，
    // 用 catchError 吞掉错误避免未捕获的 Future 异常。
    final service = _container?.read(cameraServiceProvider);
    service?.dispose().catchError((_) {});
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final size = WidgetsBinding.instance.window.physicalSize;
    final newIsLandscape = size.width > size.height;
    if (newIsLandscape != _isLandscape) {
      setState(() => _isLandscape = newIsLandscape);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // App 从后台恢复时，原生相机已被释放并重新初始化，
      // 但 Dart 侧的 AwesomeCameraPreview 仍持有旧的 textureId/previewSize。
      // 解决方案：递增 _cameraRebuildKey，通过 ValueKey 强制 CameraPreview
      // （及其内部的 CameraAwesomeBuilder）完全重建，
      // 确保取景器获取新的 textureId 和 previewSize。
      debugPrint('[capture] App resumed, forcing camera re-initialization');
      setState(() {
        _cameraRebuildKey++;
      });
    }
  }

  void _onBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.of(context).go(RouteNames.home);
    }
  }

  /// 将 CaptureState 的 CaptureFlashMode 映射为 CameraService 的 CameraFlashMode。
  /// CameraService 实现内部会再映射到各平台 camerawesome 的 FlashMode 枚举。
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

  /// 拍照入口：双管线（quickProcess + fullProcess）+ 角标缩略图模式。
  ///
  /// 流程：
  /// 1. 检查 `_isQuickProcessing`，true 则 return（防止 quickProcess 窗口并发）
  /// 2. 读取 CameraService + 闪光灯/facing/zoom 状态快照
  /// 3. 设置 `_isQuickProcessing = true`
  /// 4. 立即反馈：`_shutterTrigger++` 触发白闪动画 + `startCapture()` 角标转 processing 态
  /// 5. 调用 `cameraService.capture()` 获取原始 JPEG 路径
  /// 6. 读取后处理参数快照（params/rawMode/aspectRatio/screenRatio/isPortrait）
  /// 7. 调用 `photoPipelineProvider.quickProcess(...)` → 若成功，角标 setQuickResult
  /// 8. `_isQuickProcessing = false`（恢复可拍，支持连拍）
  /// 9. 调用 `_runFullProcess(...)`（不 await，后台 Isolate 执行）
  Future<void> _onCapture() async {
    debugPrint('[capture] _onCapture() called');

    if (_isQuickProcessing) {
      debugPrint('[capture] quickProcess 处理中，忽略拍照请求');
      return;
    }

    final cameraService = ref.read(cameraServiceProvider);
    final flashMode = ref.read(CaptureState.flashModeProvider);
    final facing = ref.read(CaptureState.cameraFacingProvider);
    final zoom = ref.read(CaptureState.zoomProvider);
    final zoomRange = CaptureState.zoomRangeForFacing(facing);
    final zoomMultiplier = CaptureState.normalizedToZoomMultiplier(
        zoom, zoomRange.min, zoomRange.max);

    // 在 await 之前读取 BuildContext 相关数据，避免 use_build_context_synchronously
    final screenSize = MediaQuery.of(context).size;
    final screenRatio = screenSize.width / screenSize.height;
    final isPortrait = screenSize.height >= screenSize.width;

    _isQuickProcessing = true;
    // 立即反馈：白闪 + 角标 processing 态
    setState(() => _shutterTrigger++);
    ref.read(captureThumbnailProvider.notifier).startCapture();

    try {
      final result = await cameraService.capture(
        config: CaptureConfig(
          facing: facing,
          zoomMultiplier: zoomMultiplier,
          flashMode: _mapFlashMode(flashMode),
        ),
      );

      // quickProcess（主 Isolate，< 100ms）
      final params = ref.read(CaptureState.effectivePostProcessProvider);
      final rawMode = ref.read(CaptureState.rawModeProvider);
      final aspectRatio = ref.read(CaptureState.aspectRatioProvider);

      final quick = await ref.read(photoPipelineProvider).quickProcess(
            inputPath: result.filePath,
            params: params,
            aspectRatio: aspectRatio,
            screenRatio: screenRatio,
            isPortrait: isPortrait,
            rawMode: rawMode,
          );

      if (quick != null) {
        ref.read(captureThumbnailProvider.notifier).setQuickResult(quick.bytes);
      }
      // quickProcess 完成，恢复可拍（支持连拍）
      _isQuickProcessing = false;

      // fullProcess（后台 Isolate，不阻塞，不 await）
      _runFullProcess(
        inputPath: result.filePath,
        params: params,
        rawMode: rawMode,
        aspectRatio: aspectRatio,
        screenRatio: screenRatio,
        isPortrait: isPortrait,
      );
    } catch (e, st) {
      _isQuickProcessing = false;
      debugPrint('[capture] capture failed: $e\n$st');
      if (!mounted) return;
      LumiraToast.show(
        context,
        '拍照失败：$e',
        duration: const Duration(seconds: 2),
      );
    }
  }

  /// 后台完整处理管线（在 worker Isolate 中执行 image 包逐像素效果）。
  ///
  /// 流程：
  /// 1. 原图备份（File.copy 到 .original.jpg）供非破坏性编辑使用
  /// 2. 调用 `photoPipelineProvider.fullProcess(...)`（Isolate 执行）
  /// 3. evict FileImage 缓存（防止旧解码图残留）
  /// 4. 落库（GalleryItemRecord → dao.insert → invalidate providers）
  /// 5. `captureThumbnailProvider.notifier.setFinalResult` 角标 swap 最终图
  /// 6. 更新 `lastPhotoPathProvider`
  /// 7. catch：降级提示"图像增强失败，已保存基础图"
  Future<void> _runFullProcess({
    required String inputPath,
    required PostProcess params,
    required bool rawMode,
    required String aspectRatio,
    required double screenRatio,
    required bool isPortrait,
  }) async {
    final fillLight = ref.read(CaptureState.fillLightStateProvider);

    // [非破坏性编辑] 复制原始文件，供后续编辑时重新处理
    // 复制到 <inputPath>.original.jpg，与处理后的文件并存
    // 失败不阻塞拍摄流程（originalPath 为 null 时预览页降级为只读）
    String? originalPath;
    try {
      originalPath = '$inputPath.original.jpg';
      await File(inputPath).copy(originalPath);
      debugPrint('[capture] 原图已保留: $originalPath');
    } catch (e) {
      debugPrint('[capture] 原图保留失败（不阻塞）: $e');
      originalPath = null;
    }

    try {
      final result = await ref.read(photoPipelineProvider).fullProcess(
            inputPath: inputPath,
            params: params,
            aspectRatio: aspectRatio,
            screenRatio: screenRatio,
            isPortrait: isPortrait,
            rawMode: rawMode,
            fillLight: fillLight,
          );

      // evict FileImage 缓存，防止 fullProcess 写入新字节后旧解码图残留
      try {
        PaintingBinding.instance.imageCache
            .evict(FileImage(File(result.filePath)));
      } catch (e) {
        debugPrint('[capture] evict FileImage 缓存失败: $e');
      }

      // 落库（修复 Issue 4：拍照后立即写入 DB，避免孤儿文件）
      final photoId = 'photo_${DateTime.now().millisecondsSinceEpoch}';
      try {
        final dao = await ref.read(galleryDaoProvider.future);
        final templateId = ref.read(CaptureState.currentTemplateIdProvider);
        final sceneId = ref.read(CaptureState.activeScenePresetIdProvider);
        final lut = params.lut;
        final record = GalleryItemRecord(
          id: photoId,
          filePath: result.filePath,
          originalPath: originalPath,
          postProcess: params,
          dataUrl: null,
          sceneId: sceneId,
          templateId: templateId,
          kitId: null,
          mood: null,
          lut: (lut == 'none' || lut.isEmpty) ? null : lut,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );
        await dao.insert(record);
        ref.invalidate(galleryDaoProvider);
        // 让首页 banner 推荐失效，下次进入首页刷新（基于最新拍摄历史）
        ref.invalidate(bannerRecommendationProvider);
        debugPrint('[capture] 自动保存到应用相册: ${record.id}');

        // 套件使用次数 +1（仅在套用 kit 进入时）
        if (_activeKitId != null) {
          try {
            final kitsDao =
                await ref.read(compositionKitsDaoProvider.future);
            await kitsDao.incrementUsage(_activeKitId!);
            ref.invalidate(compositionKitsProvider);
          } catch (e) {
            debugPrint('[capture] 套件 usage 计数失败: $e');
          }
        }
      } catch (e) {
        debugPrint('[capture] 落库失败: $e');
      }

      // 角标 swap 最终图 + 更新 lastPhotoPathProvider
      if (mounted) {
        ref
            .read(captureThumbnailProvider.notifier)
            .setFinalResult(result.filePath, photoId);
        ref.read(CaptureState.lastPhotoPathProvider.notifier).state =
            result.filePath;
      }
    } catch (e, st) {
      debugPrint('[capture] fullProcess failed: $e\n$st');
      // 降级：角标保持 preview 态，Toast 提示
      if (mounted) {
        LumiraToast.show(
          context,
          '图像增强失败，已保存基础图',
          duration: const Duration(seconds: 2),
        );
      }
    }
  }

  /// 切换摄像头：仅切换 `cameraFacingProvider` 状态。
  /// CameraPreview widget 会 watch 此 provider 并通过 CameraService 重建预览，
  /// onReady 回调中重新应用闪光灯/缩放/镜像等参数。
  void _switchCamera() {
    final current = ref.read(CaptureState.cameraFacingProvider);
    final next = current == 'back' ? 'front' : 'back';
    ref.read(CaptureState.cameraFacingProvider.notifier).state = next;

    // 切换摄像头后将缩放重置为 1x（新摄像头可能不支持当前倍数）
    final range = CaptureState.zoomRangeForFacing(next);
    final normalized1x = CaptureState.zoomMultiplierToNormalized(
        1.0, range.min, range.max);
    ref.read(CaptureState.apparentZoomProvider.notifier).state = normalized1x;
    ref.read(CaptureState.zoomProvider.notifier).state = normalized1x;
  }

  /// 缩放：以"倍数"为单位（前摄 [0.5, 2.0]，后摄 [0.3, 10.0]）。
  /// 默认 1x。通过 CameraService.setZoom 下发到原生相机。
  ///
  /// CameraService 实现内部按平台差异处理：
  /// - OHOS：直接传真实倍数（CamerawesomePlugin.setZoom）
  /// - iOS/Android：归一化到 [0,1]（SensorConfig.setZoom）
  void _onZoomChanged(double multiplier) {
    final facing = ref.read(CaptureState.cameraFacingProvider);
    final range = CaptureState.zoomRangeForFacing(facing);
    final clamped = multiplier.clamp(range.min, range.max);

    // 仅用于 UI 显示的归一化值（apparentZoomProvider 仍为 [0,1]）
    final normalized = CaptureState.zoomMultiplierToNormalized(
        clamped, range.min, range.max);
    ref.read(CaptureState.apparentZoomProvider.notifier).state = normalized;
    ref.read(CaptureState.zoomProvider.notifier).state = normalized;

    // 通过 CameraService 抽象层下发到原生相机
    ref.read(cameraServiceProvider).setZoom(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final isFullscreen = ref.watch(CaptureState.isFullscreenProvider);

    // 监听闪光灯模式变化，通过 CameraService 同步到相机引擎
    ref.listen<CaptureFlashMode>(CaptureState.flashModeProvider, (prev, next) {
      ref.read(cameraServiceProvider).setFlashMode(_mapFlashMode(next));
    });

    // 模板切换时同步 aspectRatioProvider 为模板的 cropRatio
    // 修复：之前模板的 cropRatio 字段被完全忽略，导致不同模板拍出来比例都一样
    // （永远使用 aspectRatioProvider 的默认值 'fullscreen'）。
    // 现在模板加载/切换时自动套用其 cropRatio，取景器、比例切换器、拍照裁剪
    // 三者都跟随模板比例，保证 WYSIWYG。用户仍可手动点比例切换器覆盖，
    // 直到下次切换模板。
    // 切到自由模式（next == null）时不主动改比例，保留用户上一次的选择。
    ref.listen<PhotoTemplate?>(CaptureState.originalTemplateProvider, (prev, next) {
      if (next != null && next.postProcess.cropRatio.isNotEmpty) {
        final cropRatio = next.postProcess.cropRatio;
        final current = ref.read(CaptureState.aspectRatioProvider);
        if (current != cropRatio) {
          ref.read(CaptureState.aspectRatioProvider.notifier).state = cropRatio;
          debugPrint('[capture] 模板切换，同步比例: $cropRatio');
        }
      }
    });

    // 注：原 effectiveCameraProvider 监听器（EV→brightness、flashMode 同步）已移除。
    // CameraService 抽象接口当前未暴露 setBrightness，EV 调整的实时预览
    // 依赖 camera_preview.dart 的 onReady 回调在相机重建时应用初始值。
    // 闪光灯模式变化已由上方 flashModeProvider 监听器通过 CameraService.setFlashMode 处理。

    // 权限未授予时显示权限引导 UI
    if (_permissionStatus == CameraPermissionStatus.unknown ||
        _permissionStatus == CameraPermissionStatus.denied) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _CameraPermissionGuide(
          status: _permissionStatus,
          onRetry: _requestCameraPermission,
          onBack: _onBack,
        ),
      );
    }

    if (_permissionStatus == CameraPermissionStatus.permanentlyDenied) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _CameraPermissionGuide(
          status: _permissionStatus,
          onRetry: _requestCameraPermission,
          onBack: _onBack,
          onOpenSettings: () => openAppSettings(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 取景器（按选定比例约束显示区域，所见即所得）
          // key 绑定 _cameraRebuildKey：app 恢复时 key 变化，
          // 强制 CameraPreview（及其内部的 CameraAwesomeBuilder）完全重建
          _ViewfinderArea(
            rebuildKey: _cameraRebuildKey,
            onZoomChanged: _onZoomChanged,
          ),

          // 1.5 补光叠层（仅在取景器上方、ParamPillBar 之下）
          const _FillLightOverlay(),

          // 2. 导航栏（始终保留：含返回 + 全屏切换 + 闪光灯）
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CaptureNav(onBack: _onBack),
          ),

          // 2.5 比例切换器（导航栏下方居中）
          Positioned(
            top: MediaQuery.of(context).padding.top + 64,
            left: 0,
            right: 0,
            child: const Center(child: AspectRatioSelector()),
          ),

          // 3. 顶部参数 pill 栏（全屏模式下隐藏，下移避开比例切换器）
          if (!isFullscreen)
            Positioned(
              top: MediaQuery.of(context).padding.top + 112,
              left: 12,
              right: 12,
              child: const ParamPillBar(),
            ),

          // 4. 底部控制区（始终保留：含拍摄按钮 + 缩略图 + 切换摄像头）
          //    全屏模式下仅隐藏工具栏与抽屉（在 _BottomControlArea 内部处理）
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomControlArea(
              isFullscreen: isFullscreen,
              onZoomChanged: _onZoomChanged,
              onCapture: _onCapture,
              onSwitchCamera: _switchCamera,
              onThumbnailTap: _onThumbnailTap,
            ),
          ),

          // 5. 参数面板（底部滑入，使用 AnimatedPositioned，必须在 Stack 内）
          const ParamPanel(),

          // 6. 滤镜选择器（不可见触发器，showModalBottomSheet）
          const FilterPicker(),

          // 7. 水平仪（使用 Positioned，必须在 Stack 内）
          const LevelIndicator(),

          // 8. 快门白闪反馈 overlay（最顶层，IgnorePointer 不拦截手势）
          Positioned.fill(
            child: ShutterFeedback(trigger: _shutterTrigger),
          ),
        ],
      ),
    );
  }

  /// 角标缩略图点击跳预览页。
  /// 从 `captureThumbnailProvider` 读取最终图路径和 photoId，
  /// 仅在 fullProcess 完成（finalPath/photoId 非 null）时响应。
  void _onThumbnailTap() {
    final state = ref.read(captureThumbnailProvider);
    final path = state.finalPath;
    final photoId = state.photoId;
    if (path == null || photoId == null) return;
    final aspectRatio = ref.read(CaptureState.aspectRatioProvider);
    if (_returnResult) {
      context.pop(path);
    } else {
      GoRouter.of(context).push(
        '${RouteNames.capturePreview}'
        '?photoUrl=${Uri.encodeComponent(path)}'
        '&photoId=$photoId'
        '&aspectRatio=${Uri.encodeComponent(aspectRatio)}',
      );
    }
  }
}

/// 取景器区域：按用户选定的比例约束相机预览的显示范围。
///
/// 修复（用户反馈）：
/// 之前全屏模式使用 contain 模式，会把 3:4 的传感器图像完整显示在 9:19.5 的屏幕里
/// （留黑边），但拍照后却按屏幕比例 9:19.5 裁剪。预览和照片不一致（非 WYSIWYG），
/// 导致用户看到全身预览，照片却只有脸部。
///
/// 现行方案（WYSIWYG，与系统相机一致）：
/// - 所有比例（包括 'fullscreen'）都使用 [CameraPreviewFit.cover]，预览 = 照片
/// - 'fullscreen' 模式：目标比例 = 屏幕比例，预览填满屏幕，照片按屏幕比例裁剪
/// - 其他比例：将预览约束到目标比例的矩形框内，cover 裁剪填充
/// - 取景器所见即所得，切换比例时主体大小变化仅来自裁剪区域差异（与系统相机一致）
class _ViewfinderArea extends ConsumerWidget {
  const _ViewfinderArea({
    required this.rebuildKey,
    required this.onZoomChanged,
  });

  final int rebuildKey;
  final ValueChanged<double>? onZoomChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratioId = ref.watch(CaptureState.aspectRatioProvider);
    final screenSize = MediaQuery.of(context).size;
    final isPortrait = screenSize.height >= screenSize.width;
    final screenRatio = screenSize.width / screenSize.height;
    // fullscreen 模式：目标比例 = 屏幕比例；其他模式：按 ratioId 计算
    final targetRatio =
        CaptureState.computeTargetRatio(ratioId, isPortrait) ?? screenRatio;
    final isFullscreen = ratioId == 'fullscreen';

    return Container(
      color: Colors.black,
      child: SizedBox(
        width: screenSize.width,
        height: screenSize.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 相机流铺满全屏（所有模式都一样），与 iPhone 系统相机 4:3 模式一致
            CameraPreview(
              key: ValueKey('camera_preview_$rebuildKey'),
              onZoomChanged: onZoomChanged,
              previewFit: CameraPreviewFit.cover,
            ),
            // 非 fullscreen 模式叠加裁剪辅助线，指示实际裁剪区域
            if (!isFullscreen)
              _CropGuideOverlay(
                aspectRatio: targetRatio,
                screenSize: screenSize,
              ),
          ],
        ),
      ),
    );
  }
}

/// 裁剪辅助线 overlay：非 fullscreen 模式下叠加在相机流上
/// 显示实际裁剪区域（框线）+ 框外半透明遮罩
/// 与 iPhone 系统相机 4:3 模式一致
class _CropGuideOverlay extends StatelessWidget {
  const _CropGuideOverlay({
    required this.aspectRatio,
    required this.screenSize,
  });

  final double aspectRatio; // 裁剪框宽高比 (w/h)
  final Size screenSize;

  @override
  Widget build(BuildContext context) {
    final sw = screenSize.width;
    final sh = screenSize.height;

    // 计算裁剪框尺寸：在屏幕内居中，尽可能大，宽高比 = aspectRatio
    double cropW, cropH;
    if (sw / sh > aspectRatio) {
      // 屏幕比目标更宽 → 高度铺满，宽度按比例
      cropH = sh;
      cropW = sh * aspectRatio;
    } else {
      // 屏幕比目标更窄 → 宽度铺满，高度按比例
      cropW = sw;
      cropH = sw / aspectRatio;
    }

    final left = (sw - cropW) / 2;
    final top = (sh - cropH) / 2;
    const maskColor = Color(0x80000000); // 框外遮罩：黑色 50% 透明
    const borderColor = Color(0x99FFFFFF); // 框线：白色 60% 透明

    return IgnorePointer(
      child: Stack(
        children: [
          // 框外遮罩（四块）
          // 上
          Positioned(left: 0, top: 0, right: 0, height: top,
            child: ColoredBox(color: maskColor)),
          // 下
          Positioned(left: 0, top: top + cropH, right: 0, bottom: 0,
            child: ColoredBox(color: maskColor)),
          // 左
          Positioned(left: 0, top: top, width: left, height: cropH,
            child: ColoredBox(color: maskColor)),
          // 右
          Positioned(left: left + cropW, top: top, right: 0, height: cropH,
            child: ColoredBox(color: maskColor)),
          // 裁剪框线
          Positioned(
            left: left,
            top: top,
            width: cropW,
            height: cropH,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: borderColor, width: 1.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 底部控制区：缩放滑块 + 工具栏 + 抽屉 + 拍摄按钮行
/// 修复 Bug 10：全屏模式下隐藏工具栏与抽屉，保留拍摄按钮、缩略图、切换摄像头
/// 改造：原"紧凑模板条+折叠按钮+展开面板"已替换为一排图标工具栏 + 底部抽屉
class _BottomControlArea extends StatelessWidget {
  const _BottomControlArea({
    required this.isFullscreen,
    required this.onZoomChanged,
    required this.onCapture,
    required this.onSwitchCamera,
    required this.onThumbnailTap,
  });

  final bool isFullscreen;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback onCapture;
  final VoidCallback onSwitchCamera;
  final VoidCallback onThumbnailTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.6),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 缩放滑块（始终显示，便于用户主动缩放）
            _ZoomSlider(onChanged: onZoomChanged),

            // 工具栏 + 抽屉（全屏模式下隐藏）
            if (!isFullscreen) ...[
              const _CaptureToolbar(),
              const _AnimatedToolDrawer(),
            ],

            // 拍摄按钮行（始终显示，确保全屏下也能拍照）
            _CaptureButtonRow(
              onCapture: onCapture,
              onSwitchCamera: onSwitchCamera,
              onThumbnailTap: onThumbnailTap,
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部工具栏：一排图标按钮（模板/场景/参数/补光）
/// 点击未激活的工具 → 激活并展开抽屉
/// 点击已激活的工具 → 收起抽屉
/// 点击"参数" → 直接打开 ParamPanel
class _CaptureToolbar extends ConsumerWidget {
  const _CaptureToolbar();

  static const _tools = [
    _ToolDef('templates', Icons.dashboard_outlined, Icons.dashboard, '模板'),
    _ToolDef('scenes', Icons.palette_outlined, Icons.palette, '场景'),
    _ToolDef('params', Icons.tune, Icons.tune, '参数'),
    _ToolDef('fillLight', Icons.lightbulb_outline, Icons.lightbulb, '补光'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTool = ref.watch(CaptureState.activeToolProvider);
    final isFullscreen = ref.watch(CaptureState.isFullscreenProvider);
    if (isFullscreen) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.08), width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _tools.map((tool) {
          final active = activeTool == tool.id;
          return _ToolButton(
            tool: tool,
            active: active,
            onTap: () => _onTap(ref, tool.id, active),
          );
        }).toList(),
      ),
    );
  }

  void _onTap(WidgetRef ref, String toolId, bool active) {
    if (toolId == 'params') {
      // 参数 tab：直接打开 ParamPanel，同时高亮 params tab
      final panelExpanded = ref.read(CaptureState.panelExpandedProvider);
      if (active && panelExpanded) {
        // 已激活且面板展开 → 关闭面板并收起抽屉
        ref.read(CaptureState.panelExpandedProvider.notifier).state = false;
        ref.read(CaptureState.activeToolProvider.notifier).state = null;
      } else {
        ref.read(CaptureState.panelExpandedProvider.notifier).state = true;
        ref.read(CaptureState.activeToolProvider.notifier).state = 'params';
      }
      return;
    }
    // 其他 tab：toggle 行为
    final next = active ? null : toolId;
    ref.read(CaptureState.activeToolProvider.notifier).state = next;
  }
}

class _ToolDef {
  const _ToolDef(this.id, this.icon, this.activeIcon, this.label);
  final String id;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.tool, required this.active, required this.onTap});
  final _ToolDef tool;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFFC9A96E) : Colors.white70;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 选中指示器（2dp 金色短横线）
            Container(
              width: 16,
              height: 2,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: active ? const Color(0xFFC9A96E) : Colors.transparent,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            Icon(active ? tool.activeIcon : tool.icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              tool.label,
              style: TextStyle(color: color, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

/// 工具栏下方的抽屉：根据 activeToolProvider 渲染对应内容
/// 高度根据内容自适应（child 自然撑开），收起时高度 0（AnimatedSize 动画）
class _AnimatedToolDrawer extends ConsumerWidget {
  const _AnimatedToolDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTool = ref.watch(CaptureState.activeToolProvider);
    final isFullscreen = ref.watch(CaptureState.isFullscreenProvider);
    if (isFullscreen) return const SizedBox.shrink();

    final hasContent = activeTool != null;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: hasContent
          ? Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
              ),
              child: _buildContent(activeTool, ref),
            )
          : const SizedBox(height: 0, width: double.infinity),
    );
  }

  Widget _buildContent(String toolId, WidgetRef ref) {
    switch (toolId) {
      case 'templates':
        return const TemplateStrip(compact: false);
      case 'scenes':
        return const ScenePresetStrip();
      case 'params':
        return _buildParamsHint(ref);
      case 'fillLight':
        return const _FillLightPanel();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildParamsHint(WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '参数面板已展开',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              ref.read(CaptureState.panelExpandedProvider.notifier).state = false;
              ref.read(CaptureState.activeToolProvider.notifier).state = null;
            },
            child: const Text(
              '关闭参数面板',
              style: TextStyle(color: Color(0xFFC9A96E)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 补光控制面板：预设色行 + 亮度滑块 + 可展开色环
class _FillLightPanel extends ConsumerWidget {
  const _FillLightPanel();

  static const _presets = [
    _FillLightPreset('暖白', Color(0xFFFFE5B4), 0.6),
    _FillLightPreset('冷白', Color(0xFFE0F0FF), 0.6),
    _FillLightPreset('黄金', Color(0xFFFFB347), 0.7),
    _FillLightPreset('柔粉', Color(0xFFFFC0CB), 0.6),
    _FillLightPreset('青蓝', Color(0xFF8FD3F4), 0.5),
    _FillLightPreset('紫', Color(0xFFD8BFD8), 0.5),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(CaptureState.fillLightEnabledProvider);
    final color = ref.watch(CaptureState.fillLightColorProvider);
    final intensity = ref.watch(CaptureState.fillLightIntensityProvider);
    final ringExpanded = ref.watch(_ringExpandedProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 提示行
          Row(
            children: [
              const Text(
                '补光',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  enabled ? '已启用 · 仅前置显示叠层' : '点击颜色开启',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 预设色行
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ..._presets.map((p) => _PresetColorDot(
                  preset: p,
                  selected: enabled && _colorMatches(color, p.color),
                  onTap: () {
                    ref.read(CaptureState.fillLightEnabledProvider.notifier).state = true;
                    ref.read(CaptureState.fillLightColorProvider.notifier).state = p.color;
                    ref.read(CaptureState.fillLightIntensityProvider.notifier).state = p.intensity;
                    ref.read(_ringExpandedProvider.notifier).state = false;
                  },
                )),
                // 自定义按钮
                _ActionDot(
                  icon: Icons.color_lens,
                  label: '自定义',
                  selected: ringExpanded,
                  onTap: () {
                    ref.read(CaptureState.fillLightEnabledProvider.notifier).state = true;
                    ref.read(_ringExpandedProvider.notifier).state = !ringExpanded;
                  },
                ),
                // 关闭按钮
                _ActionDot(
                  icon: Icons.close,
                  label: '关闭',
                  selected: false,
                  onTap: () {
                    ref.read(CaptureState.fillLightEnabledProvider.notifier).state = false;
                    ref.read(_ringExpandedProvider.notifier).state = false;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // 亮度滑块
          Row(
            children: [
              const Icon(Icons.brightness_6, color: Colors.white54, size: 16),
              Expanded(
                child: Slider(
                  value: intensity.clamp(0.1, 1.0),
                  min: 0.1,
                  max: 1.0,
                  divisions: 18,
                  activeColor: const Color(0xFFC9A96E),
                  inactiveColor: Colors.white24,
                  onChanged: enabled
                      ? (v) => ref.read(CaptureState.fillLightIntensityProvider.notifier).state = v
                      : null,
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '${(intensity * 100).round()}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          // 可展开色环（水平居中显示）
          if (ringExpanded)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Center(
                child: _HueRingPicker(
                  onColorChanged: (c) {
                    ref.read(CaptureState.fillLightColorProvider.notifier).state = c;
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _colorMatches(Color a, Color b) => a.value == b.value;
}

class _FillLightPreset {
  const _FillLightPreset(this.label, this.color, this.intensity);
  final String label;
  final Color color;
  final double intensity;
}

class _PresetColorDot extends StatelessWidget {
  const _PresetColorDot({required this.preset, required this.selected, required this.onTap});
  final _FillLightPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        margin: const EdgeInsets.only(right: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: preset.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? const Color(0xFFC9A96E) : Colors.white24,
                  width: selected ? 2 : 1,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              preset.label,
              style: TextStyle(
                color: selected ? const Color(0xFFC9A96E) : Colors.white54,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionDot extends StatelessWidget {
  const _ActionDot({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        margin: const EdgeInsets.only(right: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white12,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? const Color(0xFFC9A96E) : Colors.white24,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Icon(icon, color: Colors.white70, size: 16),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFFC9A96E) : Colors.white54,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 色环展开状态（仅 capture_page 内部使用）
final _ringExpandedProvider = StateProvider<bool>((ref) => false);

/// 简易 HSV 色环（自实现，无外部依赖）
/// 外环：色相（0-360°）
/// 内部：当前选中色相对应的纯色填充
class _HueRingPicker extends StatefulWidget {
  const _HueRingPicker({required this.onColorChanged});
  final ValueChanged<Color> onColorChanged;

  @override
  State<_HueRingPicker> createState() => _HueRingPickerState();
}

class _HueRingPickerState extends State<_HueRingPicker> {
  double _hue = 30.0; // 默认暖白附近

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: GestureDetector(
        onPanUpdate: _onPanUpdate,
        onTapDown: _onTapDown,
        child: CustomPaint(
          painter: _HueRingPainter(hue: _hue),
          child: Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: HSVColor.fromAHSV(1.0, _hue, 0.6, 1.0).toColor(),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white38, width: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onPanUpdate(DragUpdateDetails details) => _handleTouch(details.localPosition);

  void _onTapDown(TapDownDetails details) => _handleTouch(details.localPosition);

  void _handleTouch(Offset localPos) {
    const center = Offset(100, 100);
    final dx = localPos.dx - center.dx;
    final dy = localPos.dy - center.dy;
    final distance = dx * dx + dy * dy;
    // 仅在外环区域（半径 70-95）内响应
    if (distance < 70 * 70 || distance > 95 * 95) return;
    var angle = math.atan2(dy, dx) * 180 / math.pi;
    if (angle < 0) angle += 360;
    setState(() => _hue = angle);
    widget.onColorChanged(HSVColor.fromAHSV(1.0, _hue, 0.6, 1.0).toColor());
  }
}

class _HueRingPainter extends CustomPainter {
  const _HueRingPainter({required this.hue});
  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - 5;
    final innerRadius = outerRadius - 25;

    // 绘制色相环
    const segments = 60;
    for (var i = 0; i < segments; i++) {
      final startAngle = (i / segments) * 2 * math.pi - math.pi / 2;
      final endAngle = ((i + 1) / segments) * 2 * math.pi - math.pi / 2;
      final hueAngle = (i / segments) * 360;
      final paint = Paint()
        ..color = HSVColor.fromAHSV(1.0, hueAngle, 1.0, 1.0).toColor()
        ..style = PaintingStyle.fill;
      final path = Path()
        ..moveTo(center.dx + innerRadius * math.cos(startAngle),
            center.dy + innerRadius * math.sin(startAngle))
        ..arcTo(
            Rect.fromCircle(center: center, radius: outerRadius),
            startAngle,
            endAngle - startAngle,
            false)
        ..arcTo(
            Rect.fromCircle(center: center, radius: innerRadius),
            endAngle,
            startAngle - endAngle,
            false)
        ..close();
      canvas.drawPath(path, paint);
    }

    // 绘制当前色相指示器
    final indicatorAngle = hue * math.pi / 180 - math.pi / 2;
    final indicatorRadius = (outerRadius + innerRadius) / 2;
    final indicatorPos = Offset(
      center.dx + indicatorRadius * math.cos(indicatorAngle),
      center.dy + indicatorRadius * math.sin(indicatorAngle),
    );
    canvas.drawCircle(
        indicatorPos,
        6,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill);
    canvas.drawCircle(
        indicatorPos,
        6,
        Paint()
          ..color = Colors.black87
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant _HueRingPainter old) => old.hue != hue;
}

/// 取景器上方的补光叠层
/// 仅在 fillLightEnabled && cameraFacing=='front' 时渲染
/// 用 BlendMode.screen 模拟屏幕发光的视觉效果
class _FillLightOverlay extends ConsumerWidget {
  const _FillLightOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(CaptureState.fillLightEnabledProvider);
    final facing = ref.watch(CaptureState.cameraFacingProvider);
    if (!enabled || facing != 'front') return const SizedBox.shrink();

    final color = ref.watch(CaptureState.fillLightColorProvider);
    final intensity = ref.watch(CaptureState.fillLightIntensityProvider);
    // 直接用 intensity 作为 alpha（最大 1.0），提升屏幕补光亮度
    final alpha = intensity.clamp(0.0, 1.0);

    return IgnorePointer(
      child: Positioned.fill(
        child: CustomPaint(
          painter: _FillLightOverlayPainter(color: color, alpha: alpha),
        ),
      ),
    );
  }
}

class _FillLightOverlayPainter extends CustomPainter {
  const _FillLightOverlayPainter({required this.color, required this.alpha});
  final Color color;
  final double alpha;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 中心可见区域：1/3 宽 × 1/3 高（缩小镂空范围，让更多区域被补光照亮）
    final hollowWidth = size.width * 0.33;
    final hollowHeight = size.height * 0.33;
    final hollowLeft = (size.width - hollowWidth) / 2;
    final hollowTop = (size.height - hollowHeight) / 2;
    final hollowRect = Rect.fromLTWH(hollowLeft, hollowTop, hollowWidth, hollowHeight);

    // 2. 外圈全屏底色（屏幕发光）—— evenOdd 路径实现中心镂空
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final fillPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(fullRect)
      ..addRect(hollowRect);

    final basePaint = Paint()
      ..color = color.withOpacity(alpha)
      ..blendMode = BlendMode.screen
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, basePaint);

    // 3. 径向渐变（中心亮、边缘暗），模拟屏幕光源中心衰减
    //    渐变中心设在镂空区域上方 1/3 处（模拟面部补光方向）
    final center = Offset(size.width / 2, size.height / 3);
    final gradient = RadialGradient(
      center: Alignment(
        (center.dx / size.width) * 2 - 1,
        (center.dy / size.height) * 2 - 1,
      ),
      radius: 0.85,
      colors: [
        color.withOpacity(alpha),
        color.withOpacity(alpha * 0.55),
      ],
    );
    final rect = Offset.zero & size;
    final shaderPaint = Paint()
      ..blendMode = BlendMode.screen
      ..style = PaintingStyle.fill;
    shaderPaint.shader = gradient.createShader(rect);

    // 渐变层也用镂空路径
    canvas.drawPath(fillPath, shaderPaint);

    // 4. 中心镂空区域加一层低 alpha 补光（不完全镂空，既补光又能看到面部）
    final centerPaint = Paint()
      ..color = color.withOpacity(alpha * 0.35)
      ..blendMode = BlendMode.screen
      ..style = PaintingStyle.fill;
    canvas.drawRect(hollowRect, centerPaint);
  }

  @override
  bool shouldRepaint(covariant _FillLightOverlayPainter old) =>
      old.color != color || old.alpha != alpha;
}

/// 缩放滑块：以倍数显示，根据 facing 切换范围
///
/// 前摄 [0.5, 2.0]，后摄 [0.3, 10.0]，默认 1x。
/// 滑块内部 watch [CaptureState.apparentZoomProvider]（归一化值），
/// 通过 [CaptureState.zoomRangeForFacing] 与 [CaptureState.normalizedToZoomMultiplier]
/// 还原为倍数显示与控制。
class _ZoomSlider extends ConsumerWidget {
  const _ZoomSlider({required this.onChanged});

  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facing = ref.watch(CaptureState.cameraFacingProvider);
    final normalized = ref.watch(CaptureState.apparentZoomProvider);
    final range = CaptureState.zoomRangeForFacing(facing);
    final multiplier = CaptureState.normalizedToZoomMultiplier(
        normalized, range.min, range.max);
    final displayX = multiplier.toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.zoom_in, color: Colors.white70, size: 16),
          Expanded(
            child: Slider(
              value: multiplier.clamp(range.min, range.max),
              min: range.min,
              max: range.max,
              divisions: ((range.max - range.min) * 10).round(),
              label: '${displayX}x',
              activeColor: Colors.amber,
              inactiveColor: Colors.white24,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '${displayX}x',
              style: const TextStyle(color: Colors.white, fontSize: 11),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

/// 拍摄按钮行：角标缩略图 + 拍摄按钮 + 翻转摄像头
class _CaptureButtonRow extends ConsumerWidget {
  const _CaptureButtonRow({
    required this.onCapture,
    required this.onSwitchCamera,
    required this.onThumbnailTap,
  });

  final VoidCallback onCapture;
  final VoidCallback onSwitchCamera;
  final VoidCallback onThumbnailTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 角标缩略图（左）：四态状态机驱动（idle/processing/preview/final）
          CaptureThumbnail(onTap: onThumbnailTap),
          // 拍摄按钮（中）
          CaptureButton(onTap: onCapture),
          // 翻转摄像头（右）
          GestureDetector(
            onTap: onSwitchCamera,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.cameraswitch_outlined,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 相机权限引导页
/// 在权限未授予时显示，提供重新请求/跳转系统设置的入口
class _CameraPermissionGuide extends StatelessWidget {
  const _CameraPermissionGuide({
    required this.status,
    required this.onRetry,
    required this.onBack,
    this.onOpenSettings,
  });

  final CameraPermissionStatus status;
  final VoidCallback onRetry;
  final VoidCallback onBack;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final bool isPermanentlyDenied =
        status == CameraPermissionStatus.permanentlyDenied;
    final String message = isPermanentlyDenied
        ? '相机权限已被永久拒绝，请在系统设置中手动开启相机权限后返回应用。'
        : '需要相机权限才能进行拍摄，请授予相机权限。';
    final String actionText = isPermanentlyDenied ? '前往设置' : '重新授权';

    return SafeArea(
      child: Stack(
        children: [
          // 返回按钮
          Positioned(
            top: 0,
            left: 0,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: onBack,
            ),
          ),
          // 居中引导内容
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.camera_alt_outlined,
                    size: 64,
                    color: Colors.white54,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '相机权限未开启',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // 主操作按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC9A96E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: isPermanentlyDenied
                          ? onOpenSettings
                          : onRetry,
                      child: Text(actionText),
                    ),
                  ),
                  if (isPermanentlyDenied) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                        ),
                        onPressed: onRetry,
                        child: const Text('返回后重试'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
