import 'dart:async';
import 'dart:io';

import 'package:camerawesome_ohos/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../profile/providers/composition_kits_providers.dart';
import '../../../shared/widgets/feedback/lumira_toast.dart';
import '../data/capture_state.dart';
import '../domain/photo_template.dart';
import '../services/photo_post_processor.dart';
import '../widgets/aspect_ratio_selector.dart';
import '../widgets/capture_button.dart';
import '../widgets/capture_nav.dart';
import '../widgets/camera_preview.dart';
import '../widgets/filter_picker.dart';
import '../widgets/level_indicator.dart';
import '../widgets/param_panel.dart';
import '../widgets/param_pill_bar.dart';
import '../widgets/scene_preset_strip.dart';
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
  StreamSubscription<MediaCapture?>? _captureSub;
  CameraState? _lastState;
  CameraPermissionStatus _permissionStatus = CameraPermissionStatus.unknown;

  /// 拍照处理中标志：防止用户快速连续拍照导致文件并发写入冲突
  /// （之前的"照片只有一半/空白"问题的次要原因之一）
  bool _isProcessing = false;

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

      // 模板加载后，如果已有 CameraState，立即应用参数；
      // 否则等 _onCameraStateCreated 触发时再应用
      final state = ref.read(CaptureState.cameraStateProvider);
      if (state != null) {
        _applyTemplateCameraParams(state);
      }
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
    _captureSub?.cancel();
    // 使用缓存的 container 引用清除 cameraStateProvider，
    // 避免 ref.read 在 deactivated element 上查询 widget 树祖先
    _container?.read(CaptureState.cameraStateProvider.notifier).state = null;
    // 显式停止原生相机，防止退出后系统仍提示"正在使用取景器"。
    // 仅依赖 widget 树异步 dispose 不可靠（HarmonyOS 上 CameraAwesomeBuilder
    // 的 dispose 可能延迟或被跳过），导致下次进入时相机无法初始化。
    // CamerawesomePlugin.stop() 是幂等的，重复调用无副作用。
    // 使用 unawaited + catchError：stop() 返回 Future，测试环境中无平台通道
    // 会异步抛 MissingPluginException，直接调用会导致未捕获的 Future 错误。
    CamerawesomePlugin.stop().catchError((_) => false);
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
      // App 从后台恢复时，原生相机已被释放并重新初始化（CameraAbilityLifecycle.ets），
      // 但 Dart 侧的 AwesomeCameraPreview 仍持有旧的 textureId/previewSize，
      // 且 _CameraWidgetBuilder.didChangeAppLifecycleState(resumed) 不做任何处理。
      // 解决方案：递增 _cameraRebuildKey，通过 ValueKey 强制 CameraAwesomeBuilder
      // 完全重建（旧实例 dispose → CamerawesomePlugin.stop()，新实例 init → setupCamera()），
      // 确保取景器获取新的 textureId 和 previewSize。
      debugPrint('[capture] App resumed, forcing camera re-initialization');
      setState(() {
        _cameraRebuildKey++;
        _lastState = null;
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

  /// 由 CameraPreview 回调：拿到 CameraState 后，订阅拍照结果流并同步闪光灯
  void _onCameraStateCreated(CameraState state) {
    if (_lastState == state) return;
    _lastState = state;
    ref.read(CaptureState.cameraStateProvider.notifier).state = state;
    debugPrint('[capture] CameraState created, cameraStateProvider set');

    _captureSub?.cancel();
    _captureSub = state.captureState$.listen((media) async {
      debugPrint('[capture] captureState\$ event: status=${media?.status}, path=${media?.filePath}');
      if (media != null &&
          media.status == MediaCaptureStatus.success &&
          media.filePath.isNotEmpty) {
        // 并发保护：如果上一次拍照还在处理中，跳过本次（防止文件并发写入冲突）
        if (_isProcessing) {
          debugPrint('[capture] 上一次拍照处理中，跳过本次');
          return;
        }
        _isProcessing = true;

        ref.read(CaptureState.lastPhotoPathProvider.notifier).state =
            media.filePath;

        // 应用后期参数（滤镜、色彩、锐化等）和 aspectRatio 裁剪到照片文件
        final params = ref.read(CaptureState.effectivePostProcessProvider);
        final rawMode = ref.read(CaptureState.rawModeProvider);
        final aspectRatio = ref.read(CaptureState.aspectRatioProvider);
        // 获取屏幕宽高比，用于 fullscreen 模式按取景器裁剪
        final screenSize = MediaQuery.of(context).size;
        final screenRatio = screenSize.width / screenSize.height;
        final isPortrait = screenSize.height >= screenSize.width;
        debugPrint('[capture] 当前 aspectRatio=$aspectRatio, '
            'screenRatio=$screenRatio, isPortrait=$isPortrait, '
            'rawMode=$rawMode');
        final processedPath = await PhotoPostProcessor.processFile(
          inputPath: media.filePath,
          params: params,
          rawMode: rawMode,
          aspectRatio: aspectRatio,
          screenRatio: screenRatio,
          isPortrait: isPortrait,
        );

        _isProcessing = false;

        // 自动保存到应用相册（数据库），用户在预览页可决定是否另存到系统相册
        // 修复 Issue 4：原方案仅在用户点击预览页"保存"时写入 DB，
        // 若用户返回则照片成为孤儿（文件存在但无 DB 记录）。此处捕获后立即落库。
        final photoId = 'photo_${DateTime.now().millisecondsSinceEpoch}';
        try {
          final dao = await ref.read(galleryDaoProvider.future);
          final templateId = ref.read(CaptureState.currentTemplateIdProvider);
          final sceneId = ref.read(CaptureState.activeScenePresetIdProvider);
          final postProcess = ref.read(CaptureState.effectivePostProcessProvider);
          final lut = postProcess.lut;
          final record = GalleryItemRecord(
            id: photoId,
            filePath: processedPath,
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
          debugPrint('[capture] 自动保存失败: $e');
        }

        // 拍照成功后自动导航到预览页
        if (!mounted) return;
        if (_returnResult) {
          context.pop(processedPath);
        } else {
          GoRouter.of(context).push(
            '${RouteNames.capturePreview}'
            '?photoUrl=${Uri.encodeComponent(processedPath)}'
            '&photoId=$photoId',
          );
        }
      }
    });

    final flashMode = ref.read(CaptureState.flashModeProvider);
    state.sensorConfig.setFlashMode(_mapFlashMode(flashMode));

    // 修复：前置摄像头默认开启镜像，让预览与用户预期一致（像照镜子）
    // 拍照保存的照片也会同步镜像，避免"拍出来与预览水平翻转"的问题
    final facing = ref.read(CaptureState.cameraFacingProvider);
    final isFront = facing == 'front';
    state.sensorConfig.setMirrorFrontCamera(isFront);
    debugPrint('[capture] setMirrorFrontCamera($isFront)');

    // 默认缩放为 1x（前摄和后摄都重置）
    // 修复：直接调用 CamerawesomePlugin.setZoom(1.0)，原生期望真实倍数。
    final range = CaptureState.zoomRangeForFacing(facing);
    final normalized1x = CaptureState.zoomMultiplierToNormalized(
        1.0, range.min, range.max);
    try {
      CamerawesomePlugin.setZoom(1.0);
      ref.read(CaptureState.apparentZoomProvider.notifier).state = normalized1x;
      ref.read(CaptureState.zoomProvider.notifier).state = normalized1x;
    } catch (_) {}

    // 应用模板/自由模式的相机参数到 sensor（修复 Issue 7：
    // 模板的 EV、闪光灯、白平衡等参数之前未应用到相机）
    _applyTemplateCameraParams(state);
  }

  /// 应用模板/自由模式的相机参数到 sensor。
  /// 在 _onCameraStateCreated 末尾、模板加载后、参数变化时调用。
  void _applyTemplateCameraParams(CameraState state) {
    final params = ref.read(CaptureState.effectiveCameraProvider);
    debugPrint('[capture] 应用相机参数: EV=${params.exposureCompensation}, '
        'WB=${params.whiteBalance}K=${params.whiteBalanceK}, '
        'flash=${params.flashMode}, focus=${params.focusMode}');
    try {
      // EV [-3, +3] → brightness [0, 1]
      final brightness = (params.exposureCompensation + 3.0) / 6.0;
      state.sensorConfig.setBrightness(brightness.clamp(0.0, 1.0));
    } catch (e) {
      debugPrint('[capture] setBrightness 失败: $e');
    }
    try {
      state.sensorConfig.setFlashMode(_mapFlashModeString(params.flashMode));
    } catch (e) {
      debugPrint('[capture] setFlashMode 失败: $e');
    }
    // 白平衡、ISO、快门速度等高级参数在 camerawesome 1.4.0 中 API 有限；
    // 如果传感器支持会成功，否则静默忽略
  }

  FlashMode _mapFlashModeString(String mode) {
    switch (mode) {
      case 'off':
        return FlashMode.none;
      case 'on':
        return FlashMode.always;
      case 'auto':
        return FlashMode.auto;
      case 'torch':
        return FlashMode.always;
      default:
        return FlashMode.none;
    }
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

  /// 拍照：通过 CameraState.when 调用 PhotoCameraState.takePhoto()
  /// 修复：加诊断日志 + async/await 捕获异步异常
  Future<void> _onCapture() async {
    debugPrint('[capture] _onCapture() called');

    // 防抖：处理中或已导航到预览页时忽略新的拍照请求
    if (_isProcessing) {
      debugPrint('[capture] 处理中，忽略拍照请求');
      return;
    }

    final state = ref.read(CaptureState.cameraStateProvider);
    if (state == null) {
      debugPrint('[capture] cameraState is null — CameraAwesomeBuilder 未初始化');
      if (!mounted) return;
      // 替换 SnackBar 为 LumiraToast，与项目深色 + 金色主题高度匹配
      LumiraToast.show(
        context,
        '相机正在初始化，请稍候...',
        duration: const Duration(seconds: 1),
      );
      return;
    }
    debugPrint('[capture] cameraState OK, calling takePhoto()...');
    try {
      await state.when(
        onPhotoMode: (photoState) => photoState.takePhoto(),
      );
      debugPrint('[capture] takePhoto() completed (no exception)');
    } catch (e, st) {
      debugPrint('[capture] takePhoto() failed: $e\n$st');
      if (!mounted) return;
      // 替换 SnackBar 为 LumiraToast，与项目深色 + 金色主题高度匹配
      LumiraToast.show(
        context,
        '拍照失败：$e',
        duration: const Duration(seconds: 2),
      );
    }
  }

  void _onCaptured(String path) {
    ref.read(CaptureState.lastPhotoPathProvider.notifier).state = path;
  }

  /// 切换摄像头：同步更新 provider 与相机引擎
  void _switchCamera() {
    final current = ref.read(CaptureState.cameraFacingProvider);
    final next = current == 'back' ? 'front' : 'back';
    ref.read(CaptureState.cameraFacingProvider.notifier).state = next;

    final state = ref.read(CaptureState.cameraStateProvider);
    if (state != null) {
      state.switchCameraSensor(
        flash: _mapFlashMode(ref.read(CaptureState.flashModeProvider)),
      );
      // 切换后同步镜像设置：前置开启，后置关闭
      final isFront = next == 'front';
      state.sensorConfig.setMirrorFrontCamera(isFront);
      debugPrint('[capture] switchCamera: setMirrorFrontCamera($isFront)');
      // 切换摄像头后将缩放重置为 1x（新摄像头可能不支持当前倍数）
      // 修复：直接调用 CamerawesomePlugin.setZoom(1.0)，原生期望真实倍数。
      final range = CaptureState.zoomRangeForFacing(next);
      final normalized1x = CaptureState.zoomMultiplierToNormalized(
          1.0, range.min, range.max);
      ref.read(CaptureState.apparentZoomProvider.notifier).state = normalized1x;
      ref.read(CaptureState.zoomProvider.notifier).state = normalized1x;
      try {
        CamerawesomePlugin.setZoom(1.0);
      } catch (_) {}
    }
  }

  /// 缩放：以"倍数"为单位（前摄 [0.5, 2.0]，后摄 [0.3, 10.0]）。
  /// 默认 1x。通过 sensorConfig.setZoom 调用系统相机能力。
  ///
  /// 修复：HarmonyOS 原生 `session.setZoomRatio(zoom)` 期望"真实倍数"
  /// （1.0 = 1x，2.0 = 2x，0.5 = 0.5x），而 Flutter 侧 `SensorConfig.setZoom`
  /// 强制把入参归一化到 [0, 1]，导致 0.5–1.5x 区间被原生 clamp 到 1.0x 无变化。
  /// 这里直接调用 `CamerawesomePlugin.setZoom(multiplier)`，绕过 SensorConfig 的归一化校验，
  /// 把用户选择的倍数原样下发到原生相机。
  void _onZoomChanged(double multiplier) {
    final facing = ref.read(CaptureState.cameraFacingProvider);
    final range = CaptureState.zoomRangeForFacing(facing);
    final clamped = multiplier.clamp(range.min, range.max);

    // 仅用于 UI 显示的归一化值（apparentZoomProvider 仍为 [0,1]）
    final normalized = CaptureState.zoomMultiplierToNormalized(
        clamped, range.min, range.max);
    ref.read(CaptureState.apparentZoomProvider.notifier).state = normalized;
    ref.read(CaptureState.zoomProvider.notifier).state = normalized;

    // 直接把"真实倍数"传给原生相机（1.0=1x，2.0=2x，0.5=0.5x）
    // 不走 sensorConfig.setZoom，因为它会 throw >1 的值并归一化。
    try {
      CamerawesomePlugin.setZoom(clamped);
    } catch (e) {
      debugPrint('[capture] CamerawesomePlugin.setZoom($clamped) 失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFullscreen = ref.watch(CaptureState.isFullscreenProvider);
    final bottomPanelExpanded =
        ref.watch(CaptureState.bottomPanelExpandedProvider);

    // 监听闪光灯模式变化，同步到相机引擎
    ref.listen<CaptureFlashMode>(CaptureState.flashModeProvider, (prev, next) {
      final state = ref.read(CaptureState.cameraStateProvider);
      state?.sensorConfig.setFlashMode(_mapFlashMode(next));
    });

    // 监听相机参数变化，同步 EV 到 brightness（camerawesome 1.4.0 仅支持 brightness）
    // EV 范围 [-3, +3] 映射到 brightness [0, 1]，0 EV → 0.5 brightness
    ref.listen<CameraParams>(CaptureState.effectiveCameraProvider, (prev, next) {
      if (prev == next) return;
      final state = ref.read(CaptureState.cameraStateProvider);
      if (state == null) return;
      if (prev?.exposureCompensation != next.exposureCompensation) {
        // EV [-3, +3] → brightness [0, 1]：EV 0 = 0.5, EV +3 = 1.0, EV -3 = 0.0
        final brightness = (next.exposureCompensation + 3.0) / 6.0;
        try {
          state.sensorConfig.setBrightness(brightness.clamp(0.0, 1.0));
        } catch (_) {
          // 某些设备可能不支持 brightness 调节
        }
      }
      if (prev?.flashMode != next.flashMode) {
        try {
          state.sensorConfig.setFlashMode(_mapFlashModeString(next.flashMode));
        } catch (_) {
          // 某些设备/状态可能不支持闪光灯切换
        }
      }
    });

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
            onCaptured: _onCaptured,
            onCameraStateCreated: _onCameraStateCreated,
          ),

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
          //    全屏模式下仅隐藏模板/场景条等装饰性内容（在 _BottomControlArea 内部处理）
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomControlArea(
              isFullscreen: isFullscreen,
              bottomPanelExpanded: bottomPanelExpanded,
              onZoomChanged: _onZoomChanged,
              onTogglePanel: () => ref
                  .read(CaptureState.bottomPanelExpandedProvider.notifier)
                  .state = !bottomPanelExpanded,
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
        ],
      ),
    );
  }

  /// 修复 Bug 1：缩略图跳转，使用正确的参数名
  /// 路由配置 router.dart 读取 'photoUrl'，所以这里传 photoUrl
  void _onThumbnailTap(String path) {
    if (_returnResult) {
      context.pop(path);
    } else {
      GoRouter.of(context).push(
        '${RouteNames.capturePreview}?photoUrl=${Uri.encodeComponent(path)}',
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
    required this.onCaptured,
    required this.onCameraStateCreated,
  });

  final int rebuildKey;
  final void Function(String path) onCaptured;
  final void Function(CameraState state)? onCameraStateCreated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratioId = ref.watch(CaptureState.aspectRatioProvider);
    final screenSize = MediaQuery.of(context).size;
    final isPortrait = screenSize.height >= screenSize.width;
    final screenRatio = screenSize.width / screenSize.height;
    // fullscreen 模式：目标比例 = 屏幕比例；其他模式：按 ratioId 计算
    final targetRatio =
        CaptureState.computeTargetRatio(ratioId, isPortrait) ?? screenRatio;

    return Container(
      color: Colors.black,
      child: Center(
        child: Container(
          // 使用 ConstrainedBox + AspectRatio 确保预览区域不超过屏幕
          constraints: BoxConstraints(
            maxWidth: screenSize.width,
            maxHeight: screenSize.height,
          ),
          child: AspectRatio(
            aspectRatio: targetRatio,
            child: ClipRect(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    // fullscreen 模式下边框与屏幕几乎重合，仍保留极细边框作为视觉边界
                    color: Colors.white.withOpacity(
                        ratioId == 'fullscreen' ? 0.0 : 0.15),
                    width: 0.5,
                  ),
                ),
                child: CameraPreview(
                  key: ValueKey('camera_preview_$rebuildKey'),
                  onCaptured: onCaptured,
                  onCameraStateCreated: onCameraStateCreated,
                  previewFit: CameraPreviewFit.cover,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 底部控制区：缩放滑块 + 模板横滑条 + 折叠按钮 + 可折叠面板 + 拍摄按钮行
/// 修复 Bug 10：全屏模式下隐藏模板/场景条，保留拍摄按钮、缩略图、切换摄像头
/// 修复 Bug 4：紧凑模板条和展开面板互斥，避免重叠
class _BottomControlArea extends StatelessWidget {
  const _BottomControlArea({
    required this.isFullscreen,
    required this.bottomPanelExpanded,
    required this.onZoomChanged,
    required this.onTogglePanel,
    required this.onCapture,
    required this.onSwitchCamera,
    required this.onThumbnailTap,
  });

  final bool isFullscreen;
  final bool bottomPanelExpanded;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback onTogglePanel;
  final VoidCallback onCapture;
  final VoidCallback onSwitchCamera;
  final void Function(String path) onThumbnailTap;

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

            // 装饰性内容（全屏模式下隐藏）
            if (!isFullscreen) ...[
              // 紧凑模板条（仅在抽屉收起时显示，修复 Bug 4 重叠问题）
              if (!bottomPanelExpanded)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: TemplateStrip(compact: true),
                ),
              // 折叠/展开按钮
              GestureDetector(
                onTap: onTogglePanel,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Icon(
                    bottomPanelExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    color: Colors.white70,
                    size: 24,
                  ),
                ),
              ),
              // 展开时显示完整模板条 + 场景预设条（与紧凑条互斥）
              if (bottomPanelExpanded)
                SizedBox(
                  height: 220,
                  child: Column(
                    children: const [
                      Expanded(child: TemplateStrip(compact: false)),
                      Expanded(child: ScenePresetStrip()),
                    ],
                  ),
                ),
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

/// 拍摄按钮行：缩略图 + 拍摄按钮 + 翻转摄像头
class _CaptureButtonRow extends ConsumerWidget {
  const _CaptureButtonRow({
    required this.onCapture,
    required this.onSwitchCamera,
    required this.onThumbnailTap,
  });

  final VoidCallback onCapture;
  final VoidCallback onSwitchCamera;
  final void Function(String path) onThumbnailTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastPhotoPath = ref.watch(CaptureState.lastPhotoPathProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 缩略图（左）
          GestureDetector(
            onTap: lastPhotoPath != null
                ? () => onThumbnailTap(lastPhotoPath)
                : null,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: lastPhotoPath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6.75),
                      child: Image.file(
                        File(lastPhotoPath),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.photo,
                          color: Colors.white54,
                          size: 24,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.photo_camera,
                      color: Colors.white54,
                      size: 24,
                    ),
            ),
          ),
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
