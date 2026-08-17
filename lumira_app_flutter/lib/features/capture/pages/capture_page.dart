import 'dart:async';
import 'dart:io' show File;
import 'dart:math' as math;
import 'dart:typed_data' show Uint8List;
import 'dart:ui' as ui show Canvas, ColorFilter, FilterQuality, Image, ImageByteFormat, ImageFilter, Paint, PictureRecorder, Offset, ImmutableBuffer, ImageDescriptor, PixelFormat;

import 'package:flutter/services.dart' show HapticFeedback;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screen/screen.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/db/dao/gallery_dao.dart';
import '../../challenge/widgets/challenge_overlay_bar.dart';
import '../../home/providers/banner_recommendation_provider.dart';
import '../../points/data/points_repository.dart';
import '../../sign_in/data/sign_in_repository.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../templates/data/remote_templates_providers.dart';
import '../data/capture_state.dart';
import '../data/capture_thumbnail_state.dart';
import '../data/custom_fill_light_colors.dart';
import '../domain/filter_recipe.dart' show composePostProcessMatrix;
import '../domain/photo_template.dart';
import '../services/camera_service.dart';
import '../services/camera_service_provider.dart';
import '../services/capture_worker.dart';
import '../watermark/data/watermark_providers.dart';
import '../watermark/models/watermark_template.dart';
import '../watermark/widgets/watermark_animation_overlay.dart';
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
import '../widgets/template_info_card.dart';
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
  const CapturePage({super.key, this.templateId, this.sceneId, this.kitId, this.challengeId, this.trialMode = false});

  /// 来自 URL ?templateId=xxx，null 表示自由拍摄
  final String? templateId;

  /// 来自 URL ?scene=xxx，表示从场景详情页进入，需应用场景预设
  final String? sceneId;

  /// 来自 URL ?kitId=xxx，表示套用组合套件（含场景+模板+参数覆盖）
  final String? kitId;

  /// 来自 URL ?challengeId=xxx，表示从挑战详情页进入，
  /// 拍照保存后需回写挑战状态并跳转 XP 奖励页
  final String? challengeId;

  /// 来自 URL ?trial=1，表示付费模板试用模式：
  /// 仅展示模板效果，隐藏参数调整/工具栏、禁用快门、取景器铺水印
  final bool trialMode;

  @override
  ConsumerState<CapturePage> createState() => _CapturePageState();
}

/// 相机权限状态
enum CameraPermissionStatus { unknown, granted, denied, permanentlyDenied }

class _CapturePageState extends ConsumerState<CapturePage>
    with WidgetsBindingObserver {
  bool _isLandscape = false;
  CameraPermissionStatus _permissionStatus = CameraPermissionStatus.unknown;

  /// 白闪动画触发器：每次拍照时递增，ShutterFeedback widget 监听变化播放动画。
  int _shutterTrigger = 0;

  /// 返回结果模式：当通过 ?mode=return 进入时，拍照完成后 pop 回上一页
  /// （用于实战作业页的"去拍摄"流程，捕获路径作为 String 返回）
  bool _returnResult = false;

  /// 挑战模式自动导航标志：照片处理完成后仅自动跳转一次挑战确认页，
  /// 防止状态持续为 final_ 时重复触发导航。
  bool _hasNavigatedToChallenge = false;

  /// 相机重建 key：每次 app 从后台恢复时递增，
  /// 强制 CameraAwesomeBuilder 销毁旧实例并创建新实例，
  /// 确保原生相机被重新初始化（修复取景器一直转圈的问题）。
  int _cameraRebuildKey = 0;

  /// 取景器原始帧捕获 key：包裹 CameraPreview 的原始相机流（ColorFiltered 之前），
  /// FilterPicker 抽屉展开时通过此 key 调用 `boundary.toImage()` 捕获当前帧，
  /// 在滤镜卡片中套用各滤镜的 ColorFilter 显示实时效果预览。
  ///
  /// 修复 Bug：之前用固定 GlobalKey，切换摄像头时 Flutter reparent 复用旧
  /// RepaintBoundary 及其子树（CameraAwesomeBuilder），导致 sensor 不切换。
  /// 现在改为在 facing 变化时重建 key，强制 RepaintBoundary + CameraAwesomeBuilder 重建。
  GlobalKey _viewfinderCaptureKey = GlobalKey(debugLabel: 'viewfinder');

  /// 上一次构建时的 facing，用于检测 facing 变化并重建 captureKey
  String? _lastFacingForKey;

  /// 补光开启前的原始屏幕亮度（0.0~1.0）。
  /// 补光关闭或页面退出时恢复此值；null 表示未保存（补光未开启或已恢复）。
  double? _originalScreenBrightness;

  /// 相机就绪流订阅：驱动取景器加载看门狗。
  /// readyStream 收到 true 表示相机已就绪（CameraAwesomeBuilder 状态脱离 Preparing）。
  StreamSubscription<bool>? _cameraReadySub;

  /// 取景器加载看门狗定时器。
  ///
  /// 修复 Bug：重复进入拍摄页时，上一会话的相机释放（native releaseCamera 未被
  /// stop 等待）可能与本次初始化冲突，导致 CameraAwesomeBuilder 一直停留在
  /// PreparingCameraState，取景器永远显示加载圈。这里在相机超时未就绪时递增
  /// _cameraRebuildKey 强制重建 CameraAwesomeBuilder（与 App 恢复重建策略一致），
  /// 让相机重新走完整的初始化流程。
  Timer? _cameraReadyWatchdog;

  /// 当前相机是否已就绪（readyStream 最近一次事件）。
  bool _cameraReady = false;

  /// 看门狗已触发的重建次数（上限 2 次，避免无限重建）。
  int _cameraReadyRebuildCount = 0;

  /// 水印相框动画状态：拍照完成且水印 + 动画开关均开启时挂载 overlay。
  bool _showWatermarkAnimation = false;
  String? _animationPhotoPath;
  WatermarkTemplate? _animationTemplate;
  Rect _animationTargetRect = Rect.zero;
  VoidCallback? _onAnimationComplete;

  /// 角标缩略图的 GlobalKey：水印动画 Phase 4 需要
  /// 读取其在屏幕上的全局 Rect 作为缩小/平移的目标位置。
  final _thumbnailKey = GlobalKey(debugLabel: 'watermarkThumb');

  /// 每日首次拍摄积分是否已在本会话尝试过。
  /// 仅用于减少重复请求；最终幂等由服务端 point_earn_events 唯一约束保证。
  bool _dailyShootEarned = false;
  bool _dailyAutoSignInDone = false; // 同一会话避免重复自动签到

  @override
  void initState() {
    super.initState();
    // 挑战模式：重置缩略图状态，确保 provider 处于 idle 初始态，
    // 避免 StateNotifierProvider 残留 final_ 状态导致 ref.listen 误触发（直接跳转到确认页）。
    if (widget.challengeId != null && widget.challengeId!.isNotEmpty) {
      ref.read(captureThumbnailProvider.notifier).reset();
    }
    WidgetsBinding.instance.addObserver(this);
    // 预热常驻 worker isolate（性能优化 A）：提前创建，避免第一张照片承担 isolate 创建开销
    CaptureWorker.instance.ensureStarted().catchError((Object e) {
      debugPrint('[capture] worker 预热失败（首次拍照时会重试）: $e');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _applyRouteParamsToState();
      ref.read(CaptureState.currentTemplateIdProvider.notifier).state =
          widget.templateId;
      // 试用模式：付费模板未解锁时仅展示效果，隐藏参数/禁用快门/铺水印
      if (widget.trialMode) {
        ref.read(CaptureState.trialModeProvider.notifier).state = true;
      }
      // 解析 returnResult 模式：?mode=return 时拍照完成后 pop 回上一页
      final mode = GoRouterState.of(context).queryParams[RouteNames.paramMode];
      _returnResult = mode == 'return';
      // 加载持久化的前后置摄像头与照片比例（先于相机初始化，保证首次进入即恢复）
      await CaptureState.loadCameraPrefs(
          ProviderScope.containerOf(context, listen: false));

      // 修复 Bug（重复进入取景器卡加载）：
      // 1. 订阅相机就绪流，驱动取景器加载看门狗（超时未就绪自动重建）
      // 2. 调用 initialize() 让单例服务清除上一会话残留状态，保证干净起点
      final cameraService = ref.read(cameraServiceProvider);
      _cameraReadySub ??= cameraService.readyStream.listen((ready) {
        if (!mounted) return;
        if (ready) {
          _cameraReady = true;
          _cameraReadyWatchdog?.cancel();
          _cameraReadyWatchdog = null;
        } else {
          _cameraReady = false;
        }
      });
      cameraService.initialize(
        facing: ref.read(CaptureState.cameraFacingProvider),
      );

      _requestCameraPermission();
      _loadLastPhotoForThumbnail();
      // 异步加载持久化的自由模式参数（仅在自由模式生效，模板模式由 currentTemplateId 覆盖）
      CaptureState.loadFreeModeParams(
          ProviderScope.containerOf(context, listen: false));
      // 触发远程模板同步（invalidate 强制重新拉取），同步完成后 allTemplatesProvider 自动重新评估
      ref.invalidate(remoteTemplatesSyncProvider);
      ref.invalidate(remoteCategoriesSyncProvider);
    });
    // 从 DB 异步加载水印设置 + 自定义模板到 provider（非阻塞）。
    // 修复：原仅在设置页 initState 加载，用户直奔拍摄页时水印设置/自定义模板为空。
    Future.microtask(() {
      final container = ProviderScope.containerOf(context, listen: false);
      loadWatermarkSettings(container);
      loadCustomWatermarks(container);
    });
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
          // 权限就绪后相机预览即将构建，启动取景器加载看门狗：
          // 相机超时未就绪时自动重建 CameraAwesomeBuilder，避免取景器一直加载。
          _startCameraReadyWatchdog();
          break;
        case PermissionStatus.permanentlyDenied:
          _permissionStatus = CameraPermissionStatus.permanentlyDenied;
          break;
        default:
          _permissionStatus = CameraPermissionStatus.denied;
      }
    });
  }

  /// 启动取景器加载看门狗。
  ///
  /// 相机在 [_cameraReadyTimeout] 内未就绪（readyStream 未收到 true）时，
  /// 递增 [_cameraRebuildKey] 强制 CameraPreview 重建（ValueKey 变化 →
  /// CameraAwesomeBuilder 销毁重建，相机重新初始化），最多重建 2 次。
  /// 修复 Bug：重复进入拍摄页时相机初始化可能卡住，取景器永远显示加载圈。
  void _startCameraReadyWatchdog() {
    _cameraReadyWatchdog?.cancel();
    _cameraReady = false;
    _cameraReadyWatchdog = Timer(_cameraReadyTimeout, () {
      if (!mounted || _cameraReady) return;
      if (_cameraReadyRebuildCount >= 2) {
        debugPrint('[capture] 相机多次重建后仍未就绪，放弃自动恢复');
        return;
      }
      _cameraReadyRebuildCount++;
      debugPrint(
          '[capture] 相机 ${_cameraReadyTimeout.inSeconds}s 内未就绪，'
          '强制重建取景器（第 $_cameraReadyRebuildCount 次）');
      setState(() => _cameraRebuildKey++);
      // 重建后重新计时（新 CameraAwesomeBuilder 会走完整初始化流程）
      _startCameraReadyWatchdog();
    });
  }

  static const _cameraReadyTimeout = Duration(seconds: 10);

  /// 从数据库加载最近一张照片，显示在左下角缩略图（与原生相机行为一致）。
  /// 修复 Bug：之前缩略图仅在拍摄后显示，进入拍摄页时为空白。
  Future<void> _loadLastPhotoForThumbnail() async {
    try {
      final dao = await ref.read(galleryDaoProvider.future);
      final recent = await dao.getRecent(limit: 1);
      if (!mounted || recent.isEmpty) return;
      final photo = recent.first;
      final path = photo.filePath;
      if (path == null || path.isEmpty) return;
      ref
          .read(captureThumbnailProvider.notifier)
          .setFinalResult(path, photo.id);
    } catch (e) {
      debugPrint('[capture] 加载最近照片失败: $e');
    }
  }

  @override
  void dispose() {
    // 退出页面时恢复屏幕亮度（安全网：补光仍开启时退出）
    _restoreBrightness();
    // 修复 Bug：不再在这里调用 cameraService.dispose()。
    // 相机资源由 CameraAwesomeBuilder 自身的 CameraContext.dispose() 在卸载时
    // 通过 CamerawesomePlugin.stop() 停止；这里再 stop 一次会与前者并发，且
    // cameraServiceProvider 是 app 级单例，dispose 会把 _readyController 永久
    // 关闭，导致再次进入拍摄页时取景器就绪流失效、卡在加载中。
    _cameraReadySub?.cancel();
    _cameraReadyWatchdog?.cancel();
    // 释放常驻 worker isolate（性能优化 A：避免 isolate 泄漏）
    CaptureWorker.instance.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 补光开启：保存当前屏幕亮度，然后调至最高（1.0）。
  void _enableMaxBrightness() {
    () async {
      try {
        _originalScreenBrightness = await Screen.brightness;
        await Screen.setBrightness(1.0);
      } catch (e) {
        debugPrint('[capture] set max brightness failed: $e');
      }
    }();
  }

  /// 补光关闭或页面退出：恢复原始屏幕亮度。
  void _restoreBrightness() {
    final saved = _originalScreenBrightness;
    if (saved == null) return;
    _originalScreenBrightness = null;
    () async {
      try {
        await Screen.setBrightness(saved);
      } catch (e) {
        debugPrint('[capture] restore brightness failed: $e');
      }
    }();
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

  /// 拍照入口：调用 CameraService 拿到原始 JPEG，后处理后显示到角标。
  ///
  /// 连拍优化：capture（相机拍照）和后处理解耦。
  /// - capture 调用立即返回（camerawesome 内部排队 takePhoto，每次返回独立文件）
  /// - 后处理在独立 isolate 中串行执行，不阻塞 UI 和下次 capture 调用
  /// - 角标显示最新完成的一张
  Future<void> _onCapture() async {
    debugPrint('[capture] _onCapture() called');

    // 试用模式：禁用快门，提示用户解锁后再拍摄
    if (ref.read(CaptureState.trialModeProvider)) {
      LumiraToast.show(
        context,
        '试用模式不可拍摄，购买解锁后即可使用',
        duration: const Duration(milliseconds: 1200),
      );
      return;
    }

    final cameraService = ref.read(cameraServiceProvider);
    final flashMode = ref.read(CaptureState.flashModeProvider);
    final facing = ref.read(CaptureState.cameraFacingProvider);
    final zoom = ref.read(CaptureState.zoomProvider);

    // 立即反馈：白闪 + 角标 processing 态
    setState(() => _shutterTrigger++);
    ref.read(captureThumbnailProvider.notifier).startCapture();

    // 快照当前比例参数（避免连拍中切换比例导致参数不一致）
    final ratioId = ref.read(CaptureState.aspectRatioProvider);
    // 使用 MediaQuery（与取景器一致）而非已废弃的 WidgetsBinding.instance.window.physicalSize，
    // 后者在部分平台返回 Size.zero 导致 screenRatio=NaN，isolate 裁切失败后 catch 返回原始 4:3 图像。
    final screenSize = MediaQuery.of(context).size;
    final isPortrait = screenSize.height >= screenSize.width;
    var screenRatio = screenSize.width / screenSize.height;
    if (!screenRatio.isFinite || screenRatio <= 0) {
      // Fallback：典型手机屏幕比例（竖屏 9:19.5，横屏 19.5:9）
      screenRatio = isPortrait ? 9.0 / 19.5 : 19.5 / 9.0;
    }
    final targetRatio =
        CaptureState.computeTargetRatio(ratioId, isPortrait) ?? screenRatio;

    try {
      // === 性能测量（临时，定位 1.5-2s 瓶颈后移除） ===
      final sw = Stopwatch()..start();
      final result = await cameraService.capture(
        config: CaptureConfig(
          facing: facing,
          zoomMultiplier: zoom,
          flashMode: _mapFlashMode(flashMode),
        ),
      );
      debugPrint('[perf] cameraService.capture: ${sw.elapsedMilliseconds}ms');

      // === 水印相框入场动画（立即触发） ===
      // 快门按下并拿到原始 JPEG 后立即播放动画，使用原始照片 + CustomPaint
      // 叠加水印（与最终渲染水印视觉一致），后处理在队列中并行执行。
      // 这样用户按下快门即可看到水印动画，无需等待 GPU/isolate/落库完成。
      final wmSettings = ref.read(watermarkSettingsProvider);
      final wmTemplate = ref.read(currentWatermarkTemplateProvider);
      final shouldAnimateNow = wmSettings.enabled &&
          wmSettings.animationEnabled &&
          wmTemplate != null;
      if (shouldAnimateNow && mounted) {
        setState(() {
          _showWatermarkAnimation = true;
          _animationPhotoPath = result.filePath;
          _animationTemplate = wmTemplate;
          _animationTargetRect = _getThumbnailGlobalRect();
        });
        _onAnimationComplete = () {
          if (mounted) {
            setState(() => _showWatermarkAnimation = false);
          }
        };
      }

      // 后处理异步执行，不阻塞下次 capture 调用（支持连拍）
      final postProcess = ref.read(CaptureState.effectivePostProcessProvider);
      debugPrint('[capture] postProcess for isolate: '
          'brightness=${postProcess.color.brightness}, '
          'sharpen=${postProcess.sharpen}, '
          'smooth=${postProcess.smoothStrength}, '
          'vignette=${postProcess.vignette}, '
          'grain=${postProcess.grain}, '
          'clarity=${postProcess.color.clarity}, '
          'brilliance=${postProcess.color.brilliance}, '
          'vibrance=${postProcess.color.vibrance}');
      _processCaptureQueue.add(_CaptureProcessParams(
        inputPath: result.filePath,
        targetRatio: targetRatio,
        isPortrait: isPortrait,
        isFront: facing == 'front',
        postProcess: postProcess,
      ));
      _processCaptureQueueItem();
    } catch (e, st) {
      debugPrint('[capture] capture failed: $e\n$st');
      if (!mounted) return;
      LumiraToast.show(
        context,
        '拍照失败：$e',
        duration: const Duration(seconds: 2),
      );
    }
  }

  /// 拍照后处理队列（串行消费，避免 isolate 并发创建开销和内存峰值）
  final _processCaptureQueue = <_CaptureProcessParams>[];
  bool _isProcessingCapture = false;

  /// 串行处理拍照后处理队列。
  /// 每张照片在独立 isolate 中处理（方向对齐 + 前置镜像 + 比例裁切），
  /// 处理完成后更新角标为最新一张。
  Future<void> _processCaptureQueueItem() async {
    if (_isProcessingCapture || _processCaptureQueue.isEmpty) return;
    _isProcessingCapture = true;
    final params = _processCaptureQueue.removeAt(0);

    // 提前判断是否需要水印（决定 isolate 输出 rawRgba 还是 JPEG）
    final watermarkSettings = ref.read(watermarkSettingsProvider);
    final watermarkTemplate = ref.read(currentWatermarkTemplateProvider);
    final needWatermark = watermarkSettings.enabled && watermarkTemplate != null;

    // [非破坏性编辑] 在 isolate 处理前备份原图（isolate 会覆写 inputPath）
    // 与 GPU 处理并行执行（两者都只读 inputPath，互不干扰），节省 ~50ms
    String? originalPath;
    Future<void>? backupFuture;
    try {
      originalPath = '${params.inputPath}.original.jpg';
      backupFuture = File(params.inputPath).copy(originalPath).then((_) {});
    } catch (e) {
      debugPrint('[capture] 原图保留启动失败（不阻塞）: $e');
      originalPath = null;
    }

    // === 性能测量（临时，定位 1.5-2s 瓶颈后移除） ===
    final swTotal = Stopwatch()..start();
    try {
      final swGpu = Stopwatch()..start();
      // 【所见即所得修复】先在主 isolate 中用 dart:ui GPU 管线应用色彩矩阵，
      // 与取景器 ColorFiltered 使用完全相同的渲染管线。
      // 然后传 rawRgba 给 worker isolate 做后续 CPU 处理（锐化/磨皮/暗角/JPEG 编码）。
      final gpuData = await _applyColorMatrixOnGpu(params, needRawRgba: needWatermark);
      swGpu.stop();
      debugPrint('[perf] _applyColorMatrixOnGpu: ${swGpu.elapsedMilliseconds}ms');
      if (gpuData == null) {
        // GPU 处理失败，跳过后续处理（不阻塞拍照流程）
        debugPrint('[capture] GPU 处理失败，使用原始照片');
        _isProcessingCapture = false;
        return;
      }
      // 等待原图备份完成（isolate 即将覆写 inputPath）
      if (backupFuture != null) {
        await backupFuture.catchError((Object e) {
          debugPrint('[capture] 原图保留失败（不阻塞）: $e');
          originalPath = null;
        });
      }
      final swIso = Stopwatch()..start();
      // 常驻 worker isolate（A 优化），避免 compute() 每次创建 isolate 的开销
      final workerResult = await CaptureWorker.instance.process(
        CaptureWorkerRequest(
          rgbaBytes: gpuData.rgbaBytes,
          width: gpuData.width,
          height: gpuData.height,
          outputPath: gpuData.outputPath,
          sharpen: gpuData.sharpen,
          clarity: gpuData.clarity,
          grain: gpuData.grain,
          smoothStrength: gpuData.smoothStrength,
          vignette: gpuData.vignette,
          needRawRgba: gpuData.needRawRgba,
        ),
      );
      swIso.stop();
      debugPrint('[perf] CaptureWorker.process: ${swIso.elapsedMilliseconds}ms');
      if (!mounted) {
        _isProcessingCapture = false;
        return;
      }

      String processedPath = workerResult.outputPath;

      // evict FileImage 缓存，防止 isolate 覆写后旧解码图残留
      try {
        PaintingBinding.instance.imageCache
            .evict(FileImage(File(processedPath)));
      } catch (e) {
        debugPrint('[capture] evict FileImage 缓存失败: $e');
      }

      // === 水印渲染 ===
      // 在主 isolate 中将水印合成到处理后的图像上，生成带水印的 finalPath。
      // 失败时静默回退到 processedPath，绝不阻塞拍照流程。
      // originalPath 仍为未加水印的原始备份，不受此步骤影响。
      String finalPath = processedPath;
      if (watermarkTemplate != null &&
          watermarkSettings.enabled &&
          workerResult.rgbaBytes != null) {
        ui.Image? sourceImage;
        final swWm = Stopwatch()..start();
        try {
          // 用 worker 返回的 rawRgba 直接创建 ui.Image（ImageDescriptor.raw）
          // 避免 JPEG 编解码往返（节省 ~180ms）
          final buffer = await ui.ImmutableBuffer.fromUint8List(workerResult.rgbaBytes!);
          final descriptor = ui.ImageDescriptor.raw(
            buffer,
            width: workerResult.width,
            height: workerResult.height,
            pixelFormat: ui.PixelFormat.rgba8888,
          );
          buffer.dispose();
          final codec = await descriptor.instantiateCodec();
          final frame = await codec.getNextFrame();
          sourceImage = frame.image;
          descriptor.dispose();
          codec.dispose();

          final renderer = ref.read(watermarkRendererProvider);
          final rgbaBytes = await renderer.render(
            sourceImage: sourceImage,
            elements: watermarkTemplate.elements,
          );

          // 将 RGBA 字节编码为 JPEG（quality 90，与 worker 输出统一）
          // 注：Flutter 3.7 的 dart:ui toByteData 不支持 JPEG（ImageByteFormat.jpeg
          // 是较新版本 API），此处用 image 包纯 Dart 编码；1280px 下耗时已可接受。
          final outputImage = img.Image.fromBytes(
            width: workerResult.width,
            height: workerResult.height,
            bytes: rgbaBytes.buffer,
            numChannels: 4,
            order: img.ChannelOrder.rgba,
          );
          final jpegBytes = img.encodeJpg(outputImage, quality: 90);
          finalPath = processedPath.replaceAll(RegExp(r'\.jpg$'), '_wm.jpg');
          await File(finalPath).writeAsBytes(jpegBytes);

          debugPrint('[watermark] rendered to $finalPath');
        } catch (e) {
          debugPrint('[watermark] render failed, using original: $e');
          finalPath = processedPath;
        } finally {
          sourceImage?.dispose();
          swWm.stop();
          debugPrint('[perf] watermark render: ${swWm.elapsedMilliseconds}ms');
        }
      }

      final photoId = 'photo_${DateTime.now().millisecondsSinceEpoch}';

      // 落库到相册（原图备份 + GalleryItemRecord + provider 失效）
      try {
        final dao = await ref.read(galleryDaoProvider.future);
        final templateId = ref.read(CaptureState.currentTemplateIdProvider);
        final sceneId = ref.read(CaptureState.activeScenePresetIdProvider);
        final lut = params.postProcess.lut;
        final record = GalleryItemRecord(
          id: photoId,
          filePath: finalPath,
          originalPath: originalPath,
          postProcess: params.postProcess,
          dataUrl: null,
          sceneId: sceneId,
          templateId: templateId,
          kitId: widget.kitId,
          mood: null,
          lut: (lut == 'none' || lut.isEmpty) ? null : lut,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );
        await dao.insert(record);
        ref.invalidate(galleryDaoProvider);
        ref.invalidate(bannerRecommendationProvider);
        debugPrint('[capture] 自动保存到应用相册: ${record.id}');

        // 每日首次拍摄积分（后台幂等；失败静默，绝不阻塞拍照流程）
        if (!_dailyShootEarned) {
          _dailyShootEarned = true;
          _earnDailyShootPoints();
        }

        // === 自动签到：每日首拍自动触发 ===
        if (!_dailyAutoSignInDone) {
          _dailyAutoSignInDone = true;
          _autoSignIn();
        }

        // 套件使用次数 +1（仅在套用 kit 进入时）
        if (widget.kitId != null) {
          try {
            final kitsDao = await ref.read(compositionKitsDaoProvider.future);
            await kitsDao.incrementUsage(widget.kitId!);
          } catch (e) {
            debugPrint('[capture] 套件 usage 计数失败: $e');
          }
        }
      } catch (e) {
        debugPrint('[capture] 落库失败: $e');
      }

      // === 角标缩略图更新 ===
      // 动画已在 _onCapture() 中立即触发（使用原始照片 + 水印 overlay），
      // 后处理完成后直接更新角标，无需等待动画结束。
      // 动画 overlay 覆盖在角标上方，用户在动画结束后才看到更新后的角标。
      ref.read(captureThumbnailProvider.notifier)
          .setFinalResult(finalPath, photoId);
      ref.read(CaptureState.lastPhotoPathProvider.notifier).state =
          finalPath;

      // 诊断：确认最终照片文件的实际像素尺寸（排查横向拉伸）
      try {
        final fb = await File(finalPath).readAsBytes();
        final decoder = img.findDecoderForData(fb);
        final info = decoder?.startDecode(fb);
        debugPrint('[capture] 照片文件实际尺寸: ${info?.width}x${info?.height} '
            'ratio=${info != null && info.height != 0 ? (info.width / info.height).toStringAsFixed(4) : "?"}');
      } catch (e) {
        debugPrint('[capture] 读取照片尺寸失败: $e');
      }
    } catch (e) {
      debugPrint('[capture] process failed: $e');
    } finally {
      swTotal.stop();
      debugPrint('[perf] _processCaptureQueueItem total: ${swTotal.elapsedMilliseconds}ms');
      _isProcessingCapture = false;
      // 队列中还有则继续处理
      if (_processCaptureQueue.isNotEmpty && mounted) {
        _processCaptureQueueItem();
      }
    }
  }

  /// 读取角标缩略图在屏幕上的全局 Rect。
  ///
  /// 用于水印动画 Phase 4（缩小 + 平移到角标位置）。当 GlobalKey
  /// 尚未挂载或 RenderBox 还没测量时，回退到一个合理的左下角矩形。
  Rect _getThumbnailGlobalRect() {
    final ctx = _thumbnailKey.currentContext;
    if (ctx == null) return const Rect.fromLTWH(24, 0, 48, 48);
    final renderBox = ctx.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return const Rect.fromLTWH(24, 0, 48, 48);
    }
    final position = renderBox.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      position.dx,
      position.dy,
      renderBox.size.width,
      renderBox.size.height,
    );
  }

  /// 切换摄像头：仅切换 `cameraFacingProvider` 状态。
  /// CameraPreview widget 会 watch 此 provider 并通过 CameraService 重建预览，
  /// onReady 回调中重新应用闪光灯/缩放/镜像等参数。
  void _switchCamera() {
    final current = ref.read(CaptureState.cameraFacingProvider);
    final next = current == 'back' ? 'front' : 'back';
    ref.read(CaptureState.cameraFacingProvider.notifier).state = next;

    // 持久化前后置选择：退出拍摄页/App 后下次进入自动恢复
    CaptureState.persistCameraFacing(
        ProviderScope.containerOf(context, listen: false), next);

    // 切换到前置摄像头时关闭闪光灯（前置无闪光灯硬件）
    if (next == 'front' &&
        ref.read(CaptureState.flashModeProvider) != CaptureFlashMode.off) {
      ref.read(CaptureState.flashModeProvider.notifier).state =
          CaptureFlashMode.off;
    }

    // 切换到后置摄像头时自动关闭补光灯（补光仅前置有效）
    // 同时重置悬浮取景器的位置和大小，以便下次开启时恢复初始状态
    if (next == 'back' &&
        ref.read(CaptureState.fillLightEnabledProvider)) {
      ref.read(CaptureState.fillLightEnabledProvider.notifier).state = false;
      ref.read(CaptureState.fillLightViewfinderScaleProvider.notifier).state =
          0.5;
      ref.read(CaptureState.fillLightViewfinderOffsetProvider.notifier).state =
          Offset.zero;
    }
    // 切换到后置时收起补光抽屉（工具已被隐藏）
    if (next == 'back' &&
        ref.read(CaptureState.activeToolProvider) == 'fillLight') {
      ref.read(CaptureState.activeToolProvider.notifier).state = null;
    }

    // 切换摄像头后将缩放重置为 1x
    ref.read(CaptureState.apparentZoomProvider.notifier).state = 1.0;
    ref.read(CaptureState.zoomProvider.notifier).state = 1.0;
  }

  /// 每日首次拍摄积分（fire-and-forget）。
  /// 服务端按 UTC+8 自然日幂等，同一会话只请求一次。
  Future<void> _earnDailyShootPoints() async {
    try {
      final repo = await ref.read(pointsRepositoryProvider.future);
      final result = await repo.earn(type: 'shoot_daily');
      if (result.granted && mounted) {
        LumiraToast.show(context, '每日首拍 +${result.delta} 积分');
      }
    } catch (e) {
      // 离线/网络异常静默，不打扰拍摄
      debugPrint('[capture] earn daily shoot points failed: $e');
    }
  }

  /// 每日首拍自动签到（fire-and-forget）。
  /// 服务端幂等；失败静默，绝不阻塞拍照流程。
  Future<void> _autoSignIn() async {
    try {
      final repo = await ref.read(signInRepositoryProvider.future);
      await repo.signIn();
      // 签到成功后刷新状态
      ref.invalidate(signInRepositoryProvider);
      ref.invalidate(pointsRepositoryProvider);
      debugPrint('[auto-signin] daily first shoot auto signin success');
    } catch (e) {
      // 网络错误 / 重复签到都静默，绝不阻塞拍照
      debugPrint('[auto-signin] auto signin failed (silent): $e');
    }
  }

  /// 缩放回调：接收真实倍数，clamp 到设备支持范围后下发到相机。
  /// 由 _ZoomDial 倍数切换或水平拖动触发。
  /// 比例切换的视觉效果由取景器容器大小变化 + cover 裁切自动实现，无需 zoom 补偿。
  void _onZoomChanged(double multiplier) {
    final minZoom = ref.read(CaptureState.deviceMinZoomProvider) ?? 1.0;
    final maxZoom = ref.read(CaptureState.deviceMaxZoomProvider) ?? 10.0;
    final clamped = multiplier.clamp(minZoom, maxZoom);
    ref.read(CaptureState.apparentZoomProvider.notifier).state = clamped;
    ref.read(CaptureState.zoomProvider.notifier).state = clamped;
    ref.read(cameraServiceProvider).setZoomMultiplier(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final isFullscreen = ref.watch(CaptureState.isFullscreenProvider);
    final isTrialMode = ref.watch(CaptureState.trialModeProvider);
    final thumbState = ref.watch(captureThumbnailProvider);
    final isChallengeMode =
        widget.challengeId != null && widget.challengeId!.isNotEmpty;
    final captureInProgress =
        thumbState.status == CaptureThumbnailStatus.processing;
    // 当前套用的模板（null = 自由模式）。用于顶部模板信息卡显示。
    final template = ref.watch(CaptureState.originalTemplateProvider);
    // 修复 Bug：watch facing 以在 facing 变化时重建 _viewfinderCaptureKey，
    // 强制 RepaintBoundary + CameraAwesomeBuilder 重建（切换 sensor）
    final facing = ref.watch(CaptureState.cameraFacingProvider);
    if (_lastFacingForKey != facing) {
      _viewfinderCaptureKey = GlobalKey(debugLabel: 'viewfinder_$facing');
      _lastFacingForKey = facing;
    }

    // 监听闪光灯模式变化，通过 CameraService 同步到相机引擎
    ref.listen<CaptureFlashMode>(CaptureState.flashModeProvider, (prev, next) {
      ref.read(cameraServiceProvider).setFlashMode(_mapFlashMode(next));
    });

    // EV 补偿 → 取景器亮度：将 EV [-3, +3] 映射到 brightness [0, 1]
    // EV=0 → brightness=0.5（中性），EV=+3 → brightness=1.0（最亮），EV=-3 → brightness=0.0（最暗）
    ref.listen<CameraParams>(CaptureState.effectiveCameraProvider, (prev, next) {
      if (prev?.exposureCompensation != next.exposureCompensation) {
        final ev = next.exposureCompensation;
        final brightness = (0.5 + ev / 6.0).clamp(0.0, 1.0);
        ref.read(cameraServiceProvider).setBrightness(brightness);
      }
    });

    // 比例切换时重新下发当前缩放（真实倍数不变，直接下发）
    // 比例切换的视觉效果由取景器容器大小变化 + cover 裁切自动实现
    ref.listen<String>(CaptureState.aspectRatioProvider, (prev, next) {
      if (prev != next) {
        final multiplier = ref.read(CaptureState.zoomProvider);
        ref.read(cameraServiceProvider).setZoomMultiplier(multiplier);
      }
    });

    // 补光灯开关 → 屏幕亮度：开启时调至最高（1.0），关闭时恢复原值。
    // 监听 fillLightEnabledProvider 以覆盖所有开关路径（颜色选择、关闭按钮、切后置摄像头、退出页面）。
    ref.listen<bool>(CaptureState.fillLightEnabledProvider, (prev, next) {
      if (prev == next) return;
      if (next) {
        _enableMaxBrightness();
      } else {
        _restoreBrightness();
      }
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

    // 挑战模式：照片处理完成（状态变为 final_ 且 photoId 就绪）后，
    // 直接跳转挑战确认页，跳过预览页的"保存"步骤。
    // 用户可在确认页点"重拍"回到拍摄页重新拍摄。
    if (isChallengeMode) {
      ref.listen<CaptureThumbnailState>(captureThumbnailProvider,
          (prev, next) {
        if (_hasNavigatedToChallenge) return;
        if (next.status != CaptureThumbnailStatus.final_) return;
        if (next.photoId == null || next.finalPath == null) return;
        // 必须从 processing 或 preview 过渡到 final_ 才触发，避免：
        // 1. prev 为 null（首次监听/重建后 provider 残留 final_ 状态）时误触发
        // 2. 状态一直为 final_ 时重复触发
        if (prev?.status != CaptureThumbnailStatus.processing &&
            prev?.status != CaptureThumbnailStatus.preview) return;
        _hasNavigatedToChallenge = true;
        final cid = widget.challengeId!;
        final pid = next.photoId!;
        GoRouter.of(context).go(
          '${RouteNames.challengeConfirm}'
          '?${RouteNames.paramChallengeId}=${Uri.encodeComponent(cid)}'
          '&${RouteNames.paramPhotoId}=${Uri.encodeComponent(pid)}',
        );
      });
    }

    // EV 补偿通过上方 effectiveCameraProvider 监听器实时下发到取景器。
    // 闪光灯模式变化由 flashModeProvider 监听器通过 CameraService.setFlashMode 处理。
    // 白平衡功能已下线（SDK 不支持手动设置），ISO/快门为推荐参考值，
    // 三者（WB/快门/ISO）的真实实现见 docs/superpowers/plans/ 下的相机手动参数计划。

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
          // 1. 取景器 + 补光背景
          // 补光开启时：取景器缩小为悬浮窗口，背景显示补光色
          // 补光关闭时：取景器全屏铺满
          _ViewfinderArea(
            rebuildKey: _cameraRebuildKey,
            onZoomChanged: _onZoomChanged,
            rawCaptureKey: _viewfinderCaptureKey,
          ),

          // 1.5 试用模式水印遮罩（铺在取景器上方，不可点击穿透）
          if (isTrialMode)
            const Positioned.fill(
              child: _TrialWatermarkOverlay(),
            ),

          // 2. 导航栏（始终保留：含返回 + 全屏切换 + 闪光灯）
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CaptureNav(onBack: _onBack),
          ),

          // 2.5 顶部浮层组：比例切换器 → 参数 pill 栏 → 挑战悬浮条 → 模板信息卡
          //    比例/参数固定在顶部，模板信息卡放在最下方避免挤压上方控件
          //    导航栏改为毛玻璃胶囊后，需要更大的偏移量来留出间隙
          Positioned(
            top: MediaQuery.of(context).padding.top + 76,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 比例切换器（导航栏下方居中，全屏也显示，行为不变）
                const Center(child: AspectRatioSelector()),
                // 比例切换器与参数 pill 栏之间的间隙
                const SizedBox(height: 8),
                // 参数 pill 栏（全屏 / 试用模式隐藏）
                if (!isFullscreen && !isTrialMode)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: ParamPillBar(),
                  ),
                // 挑战悬浮条（仅挑战拍摄模式显示）
                if (isChallengeMode && !isFullscreen)
                  ChallengeOverlayBar(
                    challengeId: widget.challengeId!,
                    captureInProgress: captureInProgress,
                  ),
                // 套用模板时显示可折叠模板信息卡（移至下方，避免挤压比例/参数选项）
                // 试用模式隐藏（仅展示效果，不暴露参数）
                if (template != null && !isFullscreen && !isTrialMode)
                  TemplateInfoCard(template: template),
              ],
            ),
          ),

          // 4. 底部控制区（始终保留：含拍摄按钮 + 缩略图 + 切换摄像头）
          //    全屏模式下仅隐藏工具栏与抽屉（在 _BottomControlArea 内部处理）
          //    试用模式下隐藏工具栏/抽屉/缩放栏，快门替换为锁定态
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomControlArea(
              isFullscreen: isFullscreen,
              isTrialMode: isTrialMode,
              onZoomChanged: _onZoomChanged,
              onCapture: _onCapture,
              onSwitchCamera: _switchCamera,
              onThumbnailTap: _onThumbnailTap,
              rawCaptureKey: _viewfinderCaptureKey,
              thumbnailKey: _thumbnailKey,
            ),
          ),

          // 4.5 抽屉浮层已移除，恢复 Column 流式布局

          // 5. 参数面板（底部滑入，使用 AnimatedPositioned，必须在 Stack 内）
          const ParamPanel(),

          // 6. 水平仪（使用 Positioned，必须在 Stack 内）
          const LevelIndicator(),

          // 8. 快门白闪反馈 overlay（最顶层，IgnorePointer 不拦截手势）
          Positioned.fill(
            child: ShutterFeedback(trigger: _shutterTrigger),
          ),

          // 9. 水印相框动画 overlay（最顶层，IgnorePointer 不拦截手势）
          if (_showWatermarkAnimation &&
              _animationPhotoPath != null &&
              _animationTemplate != null)
            Positioned.fill(
              child: WatermarkAnimationOverlay(
                key: const ValueKey('watermark_anim'),
                photoPath: _animationPhotoPath!,
                watermarkTemplate: _animationTemplate!,
                targetRect: _animationTargetRect,
                onAnimationComplete: _onAnimationComplete ?? () {},
              ),
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
      // 拼接 capturePreview 路由 URL，可选追加 challengeId（挑战闭环）
      final buf = StringBuffer(
        '${RouteNames.capturePreview}'
        '?photoUrl=${Uri.encodeComponent(path)}'
        '&photoId=$photoId'
        '&aspectRatio=${Uri.encodeComponent(aspectRatio)}',
      );
      final cid = widget.challengeId;
      if (cid != null && cid.isNotEmpty) {
        buf.write('&${RouteNames.paramChallengeId}=${Uri.encodeComponent(cid)}');
      }
      GoRouter.of(context).push(buf.toString());
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
    this.rawCaptureKey,
  });

  final int rebuildKey;
  final ValueChanged<double>? onZoomChanged;
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

    // 补光悬浮模式：仅前置摄像头 + 补光开启时激活
    final isFloating = fillLightEnabled && facing == 'front';

    if (!isFloating) {
      // 取景器容器大小变化方案（原生相机行为）：
      // 容器比例 = 目标比例时，cover 不额外裁切传感器图像，
      // 4:3 显示传感器全视角（最广），全屏 cover 裁切左右（视野变窄）。
      // 容器外为纯黑背景，居中对称黑边。
      double vfW, vfH;
      if (isFullscreen) {
        vfW = screenSize.width;
        vfH = screenSize.height;
      } else {
        if (screenRatio > targetRatio) {
          // 屏幕比目标宽 → 容器按高度填满，左右留黑边
          vfH = screenSize.height;
          vfW = vfH * targetRatio;
        } else {
          // 屏幕比目标窄 → 容器按宽度填满，上下留黑边
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
              key: ValueKey('camera_preview_${rebuildKey}_$facing'),
              onZoomChanged: onZoomChanged,
              previewFit: CameraPreviewFit.cover,
              rawCaptureKey: rawCaptureKey,
            ),
          ),
        ),
      );
    }

    // 补光悬浮模式：取景器缩小为可拖动窗口，背景显示补光色
    return _FloatingViewfinder(
      rebuildKey: rebuildKey,
      facing: facing,
      onZoomChanged: onZoomChanged,
      rawCaptureKey: rawCaptureKey,
      screenSize: screenSize,
    );
  }
}

/// 悬浮取景器：补光开启时显示，可拖动、可缩放
/// 背景为补光色（模拟屏幕发光），取景器窗口浮在上方
class _FloatingViewfinder extends ConsumerStatefulWidget {
  const _FloatingViewfinder({
    required this.rebuildKey,
    required this.facing,
    required this.onZoomChanged,
    required this.rawCaptureKey,
    required this.screenSize,
  });

  final int rebuildKey;
  final String facing;
  final ValueChanged<double>? onZoomChanged;
  final GlobalKey? rawCaptureKey;
  final Size screenSize;

  @override
  ConsumerState<_FloatingViewfinder> createState() => _FloatingViewfinderState();
}

class _FloatingViewfinderState extends ConsumerState<_FloatingViewfinder> {
  Offset _dragOffset = Offset.zero;
  // 当前活跃的指针数量，用于区分单指拖动 vs 多指缩放
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
    // 窗口宽高比：与用户选择的成像比例一致
    final windowRatio =
        CaptureState.computeTargetRatio(ratioId, isPortrait) ?? screenRatio;
    // 窗口宽 = 屏幕宽 * scale；窗口高 = 宽 / windowRatio
    final windowW = sw * scale;
    final windowH = windowW / windowRatio;

    // 窗口中心点的绝对位置 = 屏幕中心 + 保存的偏移 + 当前拖动偏移
    final centerX = sw / 2 + savedOffset.dx + _dragOffset.dx;
    final centerY = sh * 0.42 + savedOffset.dy + _dragOffset.dy;
    // 窗口左上角坐标
    final left = centerX - windowW / 2;
    final top = centerY - windowH / 2;

    // 补光色：整个屏幕都是补光色（无黑色背景）
    // intensity > 1.0 时，将颜色向白色混合，让补光更亮
    final bgFull = intensity > 1.0
        ? Color.lerp(color, Colors.white, (intensity - 1.0).clamp(0.0, 0.5))!
        : color.withOpacity(intensity.clamp(0.0, 1.0));

    // clipBehavior: Clip.none 让窗口可溢出屏幕边缘（拖动时部分超出仍可见）
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        // 1. 全屏补光色背景（整个屏幕都是补光色，无黑色）
        Positioned.fill(child: ColoredBox(color: bgFull)),

        // 2. 悬浮取景器窗口：独立小窗，可拖动，浮在补光色背景之上
        //    用 Listener（而非 GestureDetector）直接处理指针事件，
        //    绕过手势竞技场——CameraPreview 内部的缩放/对焦手势不会抢走拖动事件。
        //    translucent 让 CameraPreview 也能收到事件，缩放/对焦仍可用。
        Positioned(
          left: left,
          top: top,
          width: windowW,
          height: windowH,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) {
              _activePointers++;
            },
            onPointerMove: (event) {
              // 仅单指时拖动窗口；多指（双指缩放）交给 CameraPreview 处理
              if (_activePointers == 1) {
                setState(() => _dragOffset += event.delta);
              }
            },
            onPointerUp: (_) {
              _activePointers = (_activePointers - 1).clamp(0, 99);
              if (_activePointers == 0 && _dragOffset != Offset.zero) {
                ref.read(CaptureState.fillLightViewfinderOffsetProvider.notifier).state =
                    savedOffset + _dragOffset;
                _dragOffset = Offset.zero;
              }
            },
            onPointerCancel: (_) {
              _activePointers = (_activePointers - 1).clamp(0, 99);
              if (_activePointers == 0) {
                _dragOffset = Offset.zero;
              }
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white54, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CameraPreview(
                  key: ValueKey(
                      'camera_preview_${widget.rebuildKey}_${widget.facing}'),
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

/// 底部控制区：缩放Tab栏 + 工具栏 + 抽屉 + 拍摄按钮行
/// 修复 Bug 10：全屏模式下隐藏工具栏与抽屉，保留拍摄按钮、缩略图、切换摄像头
/// 改造：原"紧凑模板条+折叠按钮+展开面板"已替换为一排图标工具栏 + 底部抽屉
/// 修复：操作栏背景完全覆盖到底部（不使用 SafeArea，手动处理 bottom padding）
class _BottomControlArea extends StatelessWidget {
  const _BottomControlArea({
    required this.isFullscreen,
    required this.isTrialMode,
    required this.onZoomChanged,
    required this.onCapture,
    required this.onSwitchCamera,
    required this.onThumbnailTap,
    this.rawCaptureKey,
    this.thumbnailKey,
  });

  final bool isFullscreen;
  final bool isTrialMode;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback onCapture;
  final VoidCallback onSwitchCamera;
  final VoidCallback onThumbnailTap;
  final GlobalKey? rawCaptureKey;
  final GlobalKey? thumbnailKey;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.3),
            Colors.black.withOpacity(0.7),
            Colors.black.withOpacity(0.95),
          ],
          stops: const [0.0, 0.4, 0.7, 1.0],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 缩放Tab栏（全屏 / 试用模式隐藏）
            if (!isFullscreen && !isTrialMode)
              _ZoomBar(onChanged: onZoomChanged),

            // 工具栏 + 抽屉（全屏 / 试用模式隐藏）
            if (!isFullscreen && !isTrialMode) ...[
              const _CaptureToolbar(),
              _AnimatedToolDrawer(rawCaptureKey: rawCaptureKey),
            ],

            // 拍摄按钮行（试用模式下快门替换为锁定态，不响应拍照）
            _CaptureButtonRow(
              onCapture: onCapture,
              onSwitchCamera: onSwitchCamera,
              onThumbnailTap: onThumbnailTap,
              thumbnailKey: thumbnailKey,
              locked: isTrialMode,
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部工具栏：一排图标按钮（模板/场景/参数/补光）— 圆角矩形半透明背景
/// 点击未激活的工具 → 激活并展开抽屉
/// 点击已激活的工具 → 收起抽屉
/// 点击"参数" → 直接打开 ParamPanel
class _CaptureToolbar extends ConsumerWidget {
  const _CaptureToolbar();

  static const _tools = [
    _ToolDef('templates', Icons.dashboard_outlined, Icons.dashboard, '模板'),
    _ToolDef('scenes', Icons.palette_outlined, Icons.palette, '场景'),
    _ToolDef('params', Icons.tune, Icons.tune, '参数'),
    _ToolDef('filter', Icons.filter_alt_outlined, Icons.filter_alt, '滤镜'),
    _ToolDef('fillLight', Icons.lightbulb_outline, Icons.lightbulb, '补光'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTool = ref.watch(CaptureState.activeToolProvider);
    final isFullscreen = ref.watch(CaptureState.isFullscreenProvider);
    final facing = ref.watch(CaptureState.cameraFacingProvider);
    if (isFullscreen) return const SizedBox.shrink();

    // 补光工具仅在前置摄像头时显示（屏幕补光仅对前摄自拍摄影有效）
    final tools = facing == 'front'
        ? _tools
        : _tools.where((t) => t.id != 'fillLight').toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: tools.map((tool) {
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
    // 补光 tab：仅切换控制面板开合，不关闭补光灯本身
    // 补光灯的关闭由用户在面板中点击已选中的预设色来完成
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
  const _AnimatedToolDrawer({this.rawCaptureKey});

  final GlobalKey? rawCaptureKey;

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
        // 参数面板由 ParamPanel（底部滑入）处理，抽屉不显示额外内容
        return const SizedBox.shrink();
      case 'filter':
        return const FilterPicker();
      case 'fillLight':
        return const _FillLightPanel();
      default:
        return const SizedBox.shrink();
    }
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
    final viewfinderScale = ref.watch(CaptureState.fillLightViewfinderScaleProvider);
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
                  enabled ? '已启用 · 再次点击选中色关闭' : '点击颜色开启',
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
                ..._presets.map((p) {
                  final isSelected = enabled && _colorMatches(color, p.color);
                  return _PresetColorDot(
                    preset: p,
                    selected: isSelected,
                    onTap: () {
                      if (isSelected) {
                        // 已选中 → 关闭补光，恢复取景器原状
                        _turnOffFillLight(ref);
                      } else {
                        // 未选中 → 切换补光色，保留当前亮度（不重置）
                        ref.read(CaptureState.fillLightEnabledProvider.notifier).state = true;
                        ref.read(CaptureState.fillLightColorProvider.notifier).state = p.color;
                        ref.read(_ringExpandedProvider.notifier).state = false;
                      }
                    },
                  );
                }),
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
              ],
            ),
          ),
          const SizedBox(height: 4),
          // 亮度滑块（0.1 ~ 1.5，可超过 100% 让补光更亮）
          Row(
            children: [
              const Icon(Icons.brightness_6, color: Colors.white54, size: 16),
              Expanded(
                child: LumiraSlider(
                  value: intensity.clamp(0.1, 1.5),
                  min: 0.1,
                  max: 1.5,
                  divisions: 28,
                  onChanged: enabled
                      ? (v) => ref.read(CaptureState.fillLightIntensityProvider.notifier).state = v
                      : (double _) {},
                ),
              ),
              SizedBox(
                width: 42,
                child: Text(
                  '${(intensity * 100).round()}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          // 取景器窗口大小滑块（仅补光开启时可用）
          Row(
            children: [
              const Icon(Icons.crop_free, color: Colors.white54, size: 16),
              Expanded(
                child: LumiraSlider(
                  value: viewfinderScale.clamp(0.3, 1.0),
                  min: 0.3,
                  max: 1.0,
                  divisions: 14,
                  onChanged: enabled
                      ? (v) => ref.read(CaptureState.fillLightViewfinderScaleProvider.notifier).state = v
                      : (double _) {},
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '${(viewfinderScale * 100).round()}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          // 可展开方形取色盘 + 收藏的颜色
          if (ringExpanded) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Center(
                child: _SquareColorPicker(
                  onColorChanged: (c) {
                    ref.read(CaptureState.fillLightColorProvider.notifier).state = c;
                  },
                ),
              ),
            ),
            // 保存颜色行（合并系统预设与用户保存颜色）
            _SaveColorsRow(
              onPick: (c) {
                ref.read(CaptureState.fillLightEnabledProvider.notifier).state = true;
                ref.read(CaptureState.fillLightColorProvider.notifier).state = c;
              },
              onAdd: (name, c) {
                ref.read(customFillLightColorsProvider.notifier).add(name, c);
              },
            ),
          ],
        ],
      ),
    );
  }

  bool _colorMatches(Color a, Color b) => a.value == b.value;

  /// 关闭补光并重置悬浮取景器到初始状态（位置、大小）
  void _turnOffFillLight(WidgetRef ref) {
    ref.read(CaptureState.fillLightEnabledProvider.notifier).state = false;
    ref.read(CaptureState.fillLightViewfinderScaleProvider.notifier).state = 0.5;
    ref.read(CaptureState.fillLightViewfinderOffsetProvider.notifier).state =
        Offset.zero;
    ref.read(_ringExpandedProvider.notifier).state = false;
  }
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

/// 方形 HSV 取色盘（色相 + 饱和度/亮度二维面板）
/// 顶部：色相条（水平滑动选色相）
/// 下方：SV 方形面板（X=饱和度，Y=亮度，左下黑、右下灰、右上纯色、左上白）
class _SquareColorPicker extends StatefulWidget {
  const _SquareColorPicker({required this.onColorChanged});
  final ValueChanged<Color> onColorChanged;

  @override
  State<_SquareColorPicker> createState() => _SquareColorPickerState();
}

class _SquareColorPickerState extends State<_SquareColorPicker> {
  double _hue = 40.0; // 默认暖白附近
  double _saturation = 0.6;
  double _value = 1.0;

  @override
  Widget build(BuildContext context) {
    const panelSize = 220.0;
    const hueBarHeight = 24.0;
    final currentColor =
        HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // SV 方形面板
        SizedBox(
          width: panelSize,
          height: panelSize,
          child: GestureDetector(
            onPanDown: (d) => _handleSv(d.localPosition, panelSize),
            onPanUpdate: (d) => _handleSv(d.localPosition, panelSize),
            child: CustomPaint(
              painter: _SvPanelPainter(
                hue: _hue,
                saturation: _saturation,
                value: _value,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // 色相条
        SizedBox(
          width: panelSize,
          height: hueBarHeight,
          child: GestureDetector(
            onPanDown: (d) => _handleHue(d.localPosition, panelSize),
            onPanUpdate: (d) => _handleHue(d.localPosition, panelSize),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(hueBarHeight / 2),
              child: CustomPaint(
                painter: _HueBarPainter(hue: _hue),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // 当前色预览
        Container(
          width: panelSize,
          height: 28,
          decoration: BoxDecoration(
            color: currentColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          alignment: Alignment.center,
          child: Text(
            '#${currentColor.red.toRadixString(16).padLeft(2, '0').toUpperCase()}'
            '${currentColor.green.toRadixString(16).padLeft(2, '0').toUpperCase()}'
            '${currentColor.blue.toRadixString(16).padLeft(2, '0').toUpperCase()}',
            style: TextStyle(
              color: _value > 0.5 ? Colors.black54 : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _handleSv(Offset localPos, double size) {
    final s = (localPos.dx / size).clamp(0.0, 1.0);
    // Y 轴反向：顶部=亮度1.0，底部=亮度0.0
    final v = (1.0 - localPos.dy / size).clamp(0.0, 1.0);
    setState(() {
      _saturation = s;
      _value = v;
    });
    widget.onColorChanged(
        HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor());
  }

  void _handleHue(Offset localPos, double width) {
    final h = (localPos.dx / width * 360.0).clamp(0.0, 360.0);
    setState(() => _hue = h);
    widget.onColorChanged(
        HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor());
  }
}

/// SV 面板绘制器：横向饱和度，纵向亮度
class _SvPanelPainter extends CustomPainter {
  const _SvPanelPainter({
    required this.hue,
    required this.saturation,
    required this.value,
  });
  final double hue;
  final double saturation;
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // 基色：当前色相的纯色
    final baseColor = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();

    // 横向：白→纯色（饱和度）
    final saturatePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Colors.white, baseColor],
      ).createShader(rect);
    canvas.drawRect(rect, saturatePaint);

    // 纵向：透明→黑（亮度）
    final valuePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black],
      ).createShader(rect);
    canvas.drawRect(rect, valuePaint);

    // 指示器圆圈
    final cx = saturation * size.width;
    final cy = (1.0 - value) * size.height;
    final indicator = Offset(cx, cy);
    canvas.drawCircle(indicator, 8, Paint()..color = Colors.white);
    canvas.drawCircle(indicator, 8,
        Paint()..color = Colors.black38..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant _SvPanelPainter old) =>
      old.hue != hue ||
      old.saturation != saturation ||
      old.value != value;
}

/// 色相条绘制器
class _HueBarPainter extends CustomPainter {
  const _HueBarPainter({required this.hue});
  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          for (var h = 0; h <= 360; h += 30)
            HSVColor.fromAHSV(1.0, h.toDouble(), 1.0, 1.0).toColor(),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    // 指示器
    final x = (hue / 360.0) * size.width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, size.height / 2), width: 6, height: size.height + 4),
        const Radius.circular(3),
      ),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _HueBarPainter old) => old.hue != hue;
}

/// 保存颜色行：合并系统预设与用户保存颜色为一个列表，
/// 用户保存的颜色可长按修改或删除。
class _SaveColorsRow extends ConsumerStatefulWidget {
  const _SaveColorsRow({
    required this.onPick,
    required this.onAdd,
  });
  final ValueChanged<Color> onPick;
  final void Function(String name, Color color) onAdd;

  @override
  ConsumerState<_SaveColorsRow> createState() => _SaveColorsRowState();
}

class _SaveColorsRowState extends ConsumerState<_SaveColorsRow> {
  bool _showNameInput = false;
  final _nameController = TextEditingController();
  bool _hintShown = false;

  @override
  void initState() {
    super.initState();
    _loadHintState();
  }

  Future<void> _loadHintState() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/lumira_fill_light_hint.json');
      if (await file.exists()) {
        if (mounted) setState(() => _hintShown = true);
      }
    } catch (_) {}
  }

  Future<void> _markHintShown() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/lumira_fill_light_hint.json');
      await file.writeAsString('{"shown":true}');
      if (mounted) setState(() => _hintShown = true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // 系统预设颜色（与 _FillLightPanel._presets 一致）
  static const _presets = [
    _FillLightPreset('暖白', Color(0xFFFFE5B4), 0.6),
    _FillLightPreset('冷白', Color(0xFFE0F0FF), 0.6),
    _FillLightPreset('黄金', Color(0xFFFFB347), 0.7),
    _FillLightPreset('柔粉', Color(0xFFFFC0CB), 0.6),
    _FillLightPreset('青蓝', Color(0xFF8FD3F4), 0.5),
    _FillLightPreset('紫', Color(0xFFD8BFD8), 0.5),
  ];

  void _showEditSheet(String name, Color color) {
    _markHintShown();
    showLumiraBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          LumiraListTile(
            leading: const Icon(Icons.edit, color: Color(0xFFC9A96E), size: 20),
            title: const Text('修改名称', style: TextStyle(color: Colors.white70, fontSize: 14)),
            onTap: () {
              Navigator.pop(ctx);
              _showRenameDialog(name);
            },
          ),
          LumiraListTile(
            leading: const Icon(Icons.color_lens, color: Color(0xFFC9A96E), size: 20),
            title: const Text('修改颜色', style: TextStyle(color: Colors.white70, fontSize: 14)),
            onTap: () {
              Navigator.pop(ctx);
              // 用当前颜色打开色环
              ref.read(CaptureState.fillLightColorProvider.notifier).state = color;
            },
          ),
          LumiraListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
            title: const Text('删除', style: TextStyle(color: Colors.redAccent, fontSize: 14)),
            onTap: () {
              ref.read(customFillLightColorsProvider.notifier).remove(name);
              Navigator.pop(ctx);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showRenameDialog(String oldName) {
    final controller = TextEditingController(text: oldName);
    showLumiraDialog(
      context: context,
      builder: (ctx) => LumiraAlertDialog(
        title: const Text('修改名称'),
        content: LumiraTextField(
          controller: controller,
          hintText: '输入新名称',
        ),
        actions: [
          LumiraButton(
            variant: ButtonVariant.ghost,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          LumiraButton(
            variant: ButtonVariant.primary,
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != oldName) {
                ref.read(customFillLightColorsProvider.notifier).update(oldName, newName: newName);
              }
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customColors = ref.watch(customFillLightColorsProvider);
    final currentColor = ref.watch(CaptureState.fillLightColorProvider);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行 + 保存按钮
          Row(
            children: [
              const Text(
                '保存颜色',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _showNameInput = !_showNameInput),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bookmark_add_outlined, size: 12, color: const Color(0xFFC9A96E)),
                      const SizedBox(width: 3),
                      Text(
                        '保存当前',
                        style: TextStyle(color: const Color(0xFFC9A96E), fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // 命名输入框
          if (_showNameInput) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: currentColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LumiraTextField(
                    controller: _nameController,
                    hintText: '为该颜色命名（如：日落金）',
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    final name = _nameController.text.trim();
                    if (name.isEmpty) return;
                    widget.onAdd(name, currentColor);
                    _nameController.clear();
                    setState(() => _showNameInput = false);
                    _markHintShown();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC9A96E),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '保存',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
          // 合并的颜色列表：系统预设 + 用户保存
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // 系统预设颜色（不可删改）
                ..._presets.map((p) {
                  final isSelected = _colorMatch(currentColor, p.color);
                  return _PresetColorDot(
                    preset: p,
                    selected: isSelected,
                    onTap: () => widget.onPick(p.color),
                  );
                }),
                // 分隔符
                if (customColors.isNotEmpty)
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    color: Colors.white12,
                  ),
                // 用户保存颜色（可长按删改）
                ...customColors.map((c) {
                  final isSelected = _colorMatch(currentColor, c.color);
                  return _SavedColorDot(
                    name: c.name,
                    color: c.color,
                    selected: isSelected,
                    onTap: () => widget.onPick(c.color),
                    onLongPress: () => _showEditSheet(c.name, c.color),
                  );
                }),
              ],
            ),
          ),
          // 操作提示（首次显示，用户长按或保存后消失）
          if (!_hintShown)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white30, size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '长按保存的颜色可修改或删除',
                      style: TextStyle(color: Colors.white30, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool _colorMatch(Color a, Color b) => a.value == b.value;
}

/// 用户保存的颜色圆点（支持长按）
class _SavedColorDot extends StatelessWidget {
  const _SavedColorDot({
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });
  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
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
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? const Color(0xFFC9A96E) : Colors.white24,
                  width: selected ? 2 : 1,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? const Color(0xFFC9A96E) : Colors.white54,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 缩放栏：默认胶囊 Tab + 拖动弹出 iPhone 原生风格旋转轮盘
///
/// 默认状态：半透明胶囊容器，显示预设倍数 Tab，点击快速切换。
/// 后置摄像头：水平拖动胶囊时弹出旋转轮盘（从底部滑入），可精细调整缩放。
/// 轮盘旋转，指针固定在顶部不动（与 iPhone 原生相机一致）。
/// 前置摄像头：仅支持点按 Tab 切换，不支持拖动精细调整。
class _ZoomBar extends ConsumerStatefulWidget {
  const _ZoomBar({required this.onChanged});

  final ValueChanged<double> onChanged;

  @override
  ConsumerState<_ZoomBar> createState() => _ZoomBarState();
}

class _ZoomBarState extends ConsumerState<_ZoomBar> {
  /// 是否正在显示弧形轮盘（水平拖动中）
  bool _showDial = false;

  /// 拖动起始时的倍数
  double _dragStartMultiplier = 1.0;

  /// 拖动起始时的水平位置
  double _dragStartX = 0.0;

  /// 轮盘滑入动画控制器
  double _dialOffset = 1.0; // 1.0 = 完全隐藏（底部），0.0 = 完全显示

  /// 上一次触发震动的倍数（用于检测刻度变化）
  double _lastHapticMultiplier = -1.0;

  /// 根据设备能力动态生成预设倍数列表。
  List<double> _getZoomPresets(String facing, double maxZoom, bool supportsUltraWide) {
    final base = <double>[1.0];
    if (facing == 'back') {
      if (maxZoom >= 2.0) base.add(2.0);
      if (maxZoom >= 3.0) base.add(3.0);
      if (maxZoom >= 5.0) base.add(5.0);
    }
    if (supportsUltraWide) base.insert(0, 0.5);
    return base;
  }

  /// 找到最接近当前倍数的预设索引
  int _nearestPresetIndex(double multiplier, List<double> presets) {
    int nearest = 0;
    double minDiff = double.infinity;
    for (var i = 0; i < presets.length; i++) {
      final diff = (presets[i] - multiplier).abs();
      if (diff < minDiff) {
        minDiff = diff;
        nearest = i;
      }
    }
    return nearest;
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    final facing = ref.read(CaptureState.cameraFacingProvider);
    if (facing != 'back') return;
    _dragStartMultiplier = ref.read(CaptureState.apparentZoomProvider);
    _dragStartX = details.globalPosition.dx;
    _lastHapticMultiplier = _dragStartMultiplier;
    setState(() => _showDial = true);
    _animateDialIn();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final facing = ref.read(CaptureState.cameraFacingProvider);
    if (facing != 'back') return;
    final minZoom = ref.read(CaptureState.deviceMinZoomProvider) ?? 1.0;
    final maxZoom = ref.read(CaptureState.deviceMaxZoomProvider) ?? 10.0;
    final deltaX = details.globalPosition.dx - _dragStartX;
    // 每 30px = 0.1x 倍数变化
    final deltaMultiplier = (deltaX / 30) * 0.1;
    var newMultiplier = _dragStartMultiplier + deltaMultiplier;
    newMultiplier = newMultiplier.clamp(minZoom, maxZoom);
    widget.onChanged(newMultiplier);

    // 每变化 0.1x 触发一次震动反馈
    final roundedNew = (newMultiplier * 10).round() / 10.0;
    final roundedLast = (_lastHapticMultiplier * 10).round() / 10.0;
    if (roundedNew != roundedLast) {
      HapticFeedback.lightImpact();
      _lastHapticMultiplier = newMultiplier;
    }
  }

  void _onHorizontalDragEnd(DragEndDetails _) {
    HapticFeedback.mediumImpact();
    _animateDialOut();
  }

  void _animateDialIn() {
    double start = 1.0;
    double end = 0.0;
    const duration = Duration(milliseconds: 250);
    final startTime = DateTime.now();

    void tick() {
      final elapsed = DateTime.now().difference(startTime);
      final t = (elapsed.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
      final eased = 1 - math.pow(1 - t, 3).toDouble();
      setState(() {
        _dialOffset = start + (end - start) * eased;
      });
      if (t < 1.0) {
        Future.delayed(const Duration(milliseconds: 16), tick);
      }
    }
    tick();
  }

  void _animateDialOut() {
    double start = _dialOffset;
    double end = 1.0;
    const duration = Duration(milliseconds: 200);
    final startTime = DateTime.now();

    void tick() {
      final elapsed = DateTime.now().difference(startTime);
      final t = (elapsed.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
      final eased = t * t;
      setState(() {
        _dialOffset = start + (end - start) * eased;
      });
      if (t < 1.0) {
        Future.delayed(const Duration(milliseconds: 16), tick);
      } else {
        setState(() => _showDial = false);
      }
    }
    tick();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final facing = ref.watch(CaptureState.cameraFacingProvider);
    final multiplier = ref.watch(CaptureState.apparentZoomProvider);
    final maxZoom = ref.watch(CaptureState.deviceMaxZoomProvider) ?? 10.0;
    final minZoom = ref.watch(CaptureState.deviceMinZoomProvider) ?? 1.0;
    final supportsUltraWide = ref.watch(CaptureState.supportsUltraWideProvider);
    final presets = _getZoomPresets(facing, maxZoom, supportsUltraWide);
    final activeIndex = _nearestPresetIndex(multiplier, presets);
    final canDrag = facing == 'back';

    return GestureDetector(
      onHorizontalDragStart: canDrag ? _onHorizontalDragStart : null,
      onHorizontalDragUpdate: canDrag ? _onHorizontalDragUpdate : null,
      onHorizontalDragEnd: canDrag ? _onHorizontalDragEnd : null,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 60,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // 默认胶囊 Tab 栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < presets.length; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    _ZoomTab(
                      label: presets[i] == presets[i].toInt()
                          ? '${presets[i].toInt()}'
                          : presets[i].toStringAsFixed(1),
                      active: i == activeIndex && !_showDial,
                      onTap: () {
                        widget.onChanged(presets[i]);
                      },
                    ),
                  ],
                ],
              ),
            ),
            // 圆形轮盘 overlay（后置拖动时从底部滑入）
            if (_showDial)
              Positioned(
                bottom: 0 + 80 * _dialOffset,
                left: 0,
                right: 0,
                child: SizedBox(
                  width: screenWidth,
                  height: screenWidth / 2,
                  child: _HalfCircleDial(
                    multiplier: multiplier,
                    presets: presets,
                    activeIndex: activeIndex,
                    minZoom: minZoom,
                    maxZoom: maxZoom,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 单个缩放 Tab 按钮 — iPhone 原生风格
class _ZoomTab extends StatelessWidget {
  const _ZoomTab({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFF0C040) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : Colors.white.withOpacity(0.85),
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

/// 半圆缩放轮盘 — 完整圆形只显示上半部分
///
/// 直径 = 屏幕宽度 100%，圆心在底部中央。
/// 半透明黑色圆形背景，只显示上半圆。
class _HalfCircleDial extends StatelessWidget {
  const _HalfCircleDial({
    required this.multiplier,
    required this.presets,
    required this.activeIndex,
    required this.minZoom,
    required this.maxZoom,
  });

  final double multiplier;
  final List<double> presets;
  final int activeIndex;
  final double minZoom;
  final double maxZoom;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final radius = screenWidth / 2;

    final totalRange = maxZoom - minZoom;
    final currentT = totalRange > 0 ? (multiplier - minZoom) / totalRange : 0.0;
    // 与 iPhone 原生一致：半圆弧（180°），从左侧经顶部到右侧
    const tickStartAngle = -math.pi;
    const tickSweepAngle = math.pi;
    final currentAngleOnDial = tickStartAngle + currentT * tickSweepAngle;
    final rotationAngle = (-math.pi / 2) - currentAngleOnDial;

    return SizedBox(
      width: screenWidth,
      height: radius,
      child: ClipRect(
        child: OverflowBox(
          maxHeight: screenWidth,
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: screenWidth,
            height: screenWidth,
            child: Stack(
              children: [
                // 半透明黑色圆形背景
                Container(
                  width: screenWidth,
                  height: screenWidth,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                  ),
                ),
                // 旋转轮盘（刻度 + 数字标签一起旋转，指针固定）
                Transform.rotate(
                  angle: rotationAngle,
                  child: SizedBox(
                    width: screenWidth,
                    height: screenWidth,
                    child: Stack(
                      children: [
                        CustomPaint(
                          painter: _HalfCircleTickPainter(
                            radius: radius,
                            startAngle: tickStartAngle,
                            sweepAngle: tickSweepAngle,
                            totalRange: totalRange,
                          ),
                        ),
                        // 数字标签与刻度同层旋转，反向旋转保持正立
                        ..._buildUprightLabels(radius, rotationAngle, totalRange, tickStartAngle, tickSweepAngle),
                      ],
                    ),
                  ),
                ),
                // 固定指针
                Positioned(
                  top: screenWidth * 0.04,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: CustomPaint(painter: _PointerPainter()),
                  ),
                ),
                // 当前倍数显示
                Positioned(
                  top: screenWidth * 0.15,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0C040),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${multiplier.toStringAsFixed(1)}x',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildUprightLabels(double radius, double rotationAngle, double totalRange, double tickStartAngle, double tickSweepAngle) {
    final widgets = <Widget>[];
    for (var i = 0; i < presets.length; i++) {
      final preset = presets[i];
      final t = totalRange > 0 ? (preset - minZoom) / totalRange : 0.0;
      final angle = tickStartAngle + t * tickSweepAngle;
      final isMajor = i == activeIndex;

      final labelRadius = radius * 0.82 - 22;
      final centerX = radius;
      final centerY = radius;
      final labelX = centerX + labelRadius * math.cos(angle);
      final labelY = centerY + labelRadius * math.sin(angle);

      final label = preset == preset.toInt()
          ? '${preset.toInt()}'
          : preset.toStringAsFixed(1);

      widgets.add(
        Positioned(
          left: labelX,
          top: labelY,
          child: Transform.rotate(
            angle: -rotationAngle,
            child: Text(
              label,
              style: TextStyle(
                color: isMajor ? const Color(0xFFF0C040) : Colors.white.withOpacity(0.8),
                fontSize: isMajor ? 15 : 12,
                fontWeight: isMajor ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }
}

/// 半圆刻度绘制器（随轮盘旋转）
class _HalfCircleTickPainter extends CustomPainter {
  _HalfCircleTickPainter({
    required this.radius,
    required this.startAngle,
    required this.sweepAngle,
    required this.totalRange,
  });

  final double radius;
  final double startAngle;
  final double sweepAngle;
  final double totalRange;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final arcR = radius * 0.82;

    // 1. 绘制弧线
    final arcPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(centerX, centerY), radius: arcR),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );

    // 2. 绘制密集刻度线
    final stepCount = ((totalRange / 0.1).round()).clamp(10, 200);
    for (var i = 0; i <= stepCount; i++) {
      final t = i / stepCount;
      final angle = startAngle + t * sweepAngle;
      final isMajorTick = i % 10 == 0;
      final tickLength = isMajorTick ? 14.0 : 6.0;
      final tickWidth = isMajorTick ? 1.5 : 0.7;

      final outerR = arcR;
      final innerR = arcR - tickLength;

      final p1 = Offset(
        centerX + outerR * math.cos(angle),
        centerY + outerR * math.sin(angle),
      );
      final p2 = Offset(
        centerX + innerR * math.cos(angle),
        centerY + innerR * math.sin(angle),
      );

      canvas.drawLine(
        p1, p2,
        Paint()
          ..color = Colors.white.withOpacity(isMajorTick ? 0.75 : 0.35)
          ..strokeWidth = tickWidth,
      );
    }
  }

  @override
  bool shouldRepaint(_HalfCircleTickPainter oldDelegate) => false;
}

/// 顶部固定指针绘制器（金黄色向下小三角）
class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFF0C040);
    final s = 6.0;
    final path = Path()
      ..moveTo(0, s)
      ..lineTo(-s * 0.8, -s * 0.5)
      ..lineTo(s * 0.8, -s * 0.5)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 拍摄按钮行：角标缩略图 + 拍摄按钮 + 翻转摄像头
/// 试用模式水印遮罩
///
/// 铺在取景器上方：半透明白色斜纹 + 重复"LUMIRA 试用"水印文字，
/// 中央提示"购买解锁后去除水印"。IgnorePointer 不拦截手势，
/// 导航栏（含购买/退出）与底部锁定快门仍可操作。
class _TrialWatermarkOverlay extends StatelessWidget {
  const _TrialWatermarkOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        color: Colors.white.withOpacity(0.06),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 斜纹水印文字（CustomPainter 绘制，性能优于大量 Transform Text）
            CustomPaint(painter: _TrialWatermarkPainter()),
            // 中央提示
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 0.5,
                  ),
                ),
                child: const Text(
                  '试用模式 · 购买解锁后去除水印',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 斜纹"LUMIRA 试用"水印文字画笔
class _TrialWatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final textStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Colors.white.withOpacity(0.22),
      letterSpacing: 2,
    );

    canvas.save();
    canvas.rotate(-0.45);
    const step = 130.0;
    const offset = -200.0;
    // 沿斜向网格铺满水印文字
    for (var x = offset; x < size.height + 200; x += step) {
      for (var y = offset; y < size.width + 200; y += step) {
        final tp = TextPainter(
          text: TextSpan(text: 'LUMIRA 试用', style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(y, x));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CaptureButtonRow extends ConsumerWidget {
  const _CaptureButtonRow({
    required this.onCapture,
    required this.onSwitchCamera,
    required this.onThumbnailTap,
    this.thumbnailKey,
    this.locked = false,
  });

  final VoidCallback onCapture;
  final VoidCallback onSwitchCamera;
  final VoidCallback onThumbnailTap;
  final GlobalKey? thumbnailKey;
  /// 试用模式：快门替换为锁定态，点击提示解锁
  final bool locked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 角标缩略图（左）：四态状态机驱动（idle/processing/preview/final）
          // thumbnailKey：水印动画 Phase 4 通过此 key 读取角标全局 Rect
          // 试用模式隐藏缩略图（不产生照片）
          if (!locked)
            CaptureThumbnail(key: thumbnailKey, onTap: onThumbnailTap),
          // 拍摄按钮（中）：试用模式替换为锁定快门
          locked ? const _LockedCaptureButton() : CaptureButton(onTap: onCapture),
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

/// 试用模式锁定快门：不可拍照，点击提示解锁
class _LockedCaptureButton extends StatelessWidget {
  const _LockedCaptureButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => LumiraToast.show(
        context,
        '试用模式不可拍摄，购买解锁后即可使用',
        duration: const Duration(milliseconds: 1200),
      ),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.6), width: 4),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.85),
          ),
          child: const Icon(
            Icons.lock_outline,
            size: 28,
            color: Colors.black54,
          ),
        ),
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
            child: LumiraIconButton(
              icon: Icons.arrow_back_ios_new,
              color: Colors.white,
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
                    child: LumiraButton(
                      variant: ButtonVariant.primary,
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
                      child: LumiraButton(
                        variant: ButtonVariant.ghost,
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

/// 拍照后处理参数（传给 worker isolate）。
class _CaptureProcessParams {
  const _CaptureProcessParams({
    required this.inputPath,
    required this.targetRatio,
    required this.isPortrait,
    required this.isFront,
    required this.postProcess,
  });
  final String inputPath;
  final double targetRatio; // 目标宽高比（正向像素）
  final bool isPortrait;
  final bool isFront;
  final PostProcess postProcess;
}

/// 后处理输出最大边（px）。
/// 2048 → 1280 大幅降低逐像素 CPU 处理耗时（锐化/清晰度/颗粒/磨皮/暗角均为 O(N)），
/// 像素数降为原来的 (1280/2048)^2 ≈ 39%，CPU 处理耗时约减半。
/// 【性能优化 B】
const int kMaxProcessDim = 1280;

/// JPEG 降采样解码目标长边（px）。
/// 相机原始图通常 4000px 级别，用 targetWidth/targetHeight 让引擎在解码阶段
/// 直接降采样到略高于输出尺寸（1600），避免全尺寸解码后再 GPU 缩小，
/// 可省 0.4-1.0s。略高于输出 1280 是为了留出画质余量。
/// 【性能优化 C】
const int kDecodeTargetDim = 1600;

/// GPU 处理后的 rawRgba 数据 + 尺寸，传给 worker isolate 做后续 CPU 处理。
class _GpuProcessedData {
  const _GpuProcessedData({
    required this.rgbaBytes,
    required this.width,
    required this.height,
    required this.outputPath,
    required this.sharpen,
    required this.clarity,
    required this.grain,
    required this.smoothStrength,
    required this.vignette,
    required this.needRawRgba,
  });
  final Uint8List rgbaBytes;
  final int width;
  final int height;
  final String outputPath;
  final int sharpen;
  final double? clarity;
  final int grain;
  final int smoothStrength;
  final int vignette;
  /// 为 true 时 isolate 不编码 JPEG，直接返回 rawRgba 给主 isolate 做水印合成，
  /// 避免主 isolate 重复解码 JPEG（节省 ~180ms）。
  /// 为 false 时 isolate 直接编码 JPEG 写文件（无水印场景，不阻塞 UI）。
  final bool needRawRgba;
}

/// 在主 isolate 中用 dart:ui GPU 管线处理照片：
/// 1. 解码 JPEG（降采样，C 优化）
/// 2. 方向对齐 + cover 裁切 + 前置镜像 + 缩放到 kMaxProcessDim（B 优化）
/// 3. 应用色彩矩阵（与取景器 ColorFiltered 使用完全相同的 GPU 渲染管线）
/// 4. 导出 rawRgba 给常驻 worker isolate（capture_worker.dart）做后续 CPU 处理
///
/// 【所见即所得修复】
/// 之前在 worker isolate 中用 image 包的 applyColorMatrixImg 逐像素应用色彩矩阵，
/// 与取景器 GPU 渲染管线（dart:ui ColorFilter.matrix）存在色彩空间差异，
/// 导致拍照后效果与取景器不一致。
/// 现在改为在主 isolate 中用 dart:ui 的 Canvas + ColorFilter.matrix 处理，
/// 与取景器使用完全相同的渲染管线，保证所见即所得。
Future<_GpuProcessedData?> _applyColorMatrixOnGpu(_CaptureProcessParams params, {required bool needRawRgba}) async {
  // === 性能测量（临时，定位 1.5-2s 瓶颈后移除） ===
  final swDecode = Stopwatch()..start();
  try {
    final bytes = await File(params.inputPath).readAsBytes();
    // 高效降采样解码：先用 ImageDescriptor 读取原始宽高，再按比例缩放到
    // 不超过 kDecodeTargetDim 的包围盒内（保持原始宽高比，避免拉伸）。
    // 相比固定 targetWidth:1600（竖屏 3:4 会解出 1600x2133），竖屏 3:4 只需
    // 解 1200x1600，少解约 1.8 倍像素，显著降低 OHOS 大 JPEG 解码耗时。
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final srcW = descriptor.width;
    final srcH = descriptor.height;
    final decodeScale = math.min(
      kDecodeTargetDim / srcW,
      kDecodeTargetDim / srcH,
    ).clamp(0.0, 1.0); // 小图不放大
    final resizedW = (srcW * decodeScale).round().clamp(1, kDecodeTargetDim);
    final resizedH = (srcH * decodeScale).round().clamp(1, kDecodeTargetDim);
    final codec = await descriptor.instantiateCodec(
      targetWidth: resizedW,
      targetHeight: resizedH,
    );
    final frame = await codec.getNextFrame();
    final srcImage = frame.image;
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
    swDecode.stop();
    debugPrint('[perf] gpu decode JPEG: ${swDecode.elapsedMilliseconds}ms (src=${srcImage.width}x${srcImage.height})');

    // 计算方向对齐参数
    final jpegIsLandscape = srcImage.width > srcImage.height;
    final needRotate = (params.isPortrait && jpegIsLandscape) ||
        (!params.isPortrait && !jpegIsLandscape);
    final needMirror = params.isFront;
    final alignRotation = needRotate ? (params.isPortrait ? 90 : 270) : 0;

    // 计算输出尺寸（基于 targetRatio，限制最大边 kMaxProcessDim）
    // （B 优化：2048 → 1280，逐像素 CPU 效果处理耗时约减半）
    const maxDim = kMaxProcessDim;
    double outW, outH;
    if (params.isPortrait) {
      outH = maxDim.toDouble();
      outW = maxDim * params.targetRatio;
      if (outW > maxDim) {
        outW = maxDim.toDouble();
        outH = maxDim / params.targetRatio;
      }
    } else {
      outW = maxDim.toDouble();
      outH = maxDim / params.targetRatio;
      if (outH > maxDim) {
        outH = maxDim.toDouble();
        outW = maxDim * params.targetRatio;
      }
    }
    final iOutW = outW.round();
    final iOutH = outH.round();

    // cover 缩放（等比，不改变内容比例）：在原始图像坐标系中计算，
    // 让旋转后的图像完全覆盖输出画布，溢出部分由画布边界自动裁剪。
    //
    // 关键数学：canvas 变换顺序是 scale → rotate（先写的先应用到源图坐标）。
    // 对源点 (x, y)，经过均匀 scale(s) 再 rotate 90°：
    //   rotate 90° 矩阵: [0, 1, -1, 0]
    //   (x·s, y·s) → (y·s, -x·s)
    // 因此：
    //   - 源宽 srcW 映射到输出 Y 轴范围: ±srcW·s/2，需 ≥ outH/2 → s ≥ outH / srcW
    //   - 源高 srcH 映射到输出 X 轴范围: ±srcH·s/2，需 ≥ outW/2 → s ≥ outW / srcH
    // 不旋转时：s ≥ outW / srcW 且 s ≥ outH / srcH
    // 取较大值（cover 定义：完全覆盖画布，允许溢出）
    final swapDims = alignRotation == 90 || alignRotation == 270;
    final double coverScale;
    if (swapDims) {
      coverScale = math.max(
        outW / srcImage.height.toDouble(), // 源高 → 输出宽
        outH / srcImage.width.toDouble(),  // 源宽 → 输出高
      );
    } else {
      coverScale = math.max(
        outW / srcImage.width.toDouble(),
        outH / srcImage.height.toDouble(),
      );
    }
    debugPrint('[capture] transform: src=${srcImage.width}x${srcImage.height}, '
        'isPortrait=${params.isPortrait}, isFront=${params.isFront}, '
        'jpegIsLandscape=$jpegIsLandscape, needRotate=$needRotate, '
        'alignRotation=${alignRotation}°, swapDims=$swapDims, '
        'targetRatio=${params.targetRatio.toStringAsFixed(4)}, '
        'out=$iOutW x $iOutH (ratio=${(iOutW / iOutH).toStringAsFixed(4)}), '
        'coverScale=${coverScale.toStringAsFixed(5)}');
    final rotatedImgW = swapDims ? srcImage.height * coverScale : srcImage.width * coverScale;
    final rotatedImgH = swapDims ? srcImage.width * coverScale : srcImage.height * coverScale;
    debugPrint('[capture] 旋转后图像尺寸: ${rotatedImgW.toStringAsFixed(1)}x${rotatedImgH.toStringAsFixed(1)} '
        '(覆盖画布 $iOutW x $iOutH: X方向${rotatedImgW >= iOutW - 0.5 ? "✓" : "❌(拉伸!"}'
        ' Y方向${rotatedImgH >= iOutH - 0.5 ? "✓" : "❌(拉伸!"})');

    // 构造色彩矩阵
    final matrix = composePostProcessMatrix(params.postProcess);

    // 单次 Canvas：方向对齐 + cover 裁剪 + 镜像 + 缩放 + ColorMatrix（一步完成）
    //
    // 关键：scale 和 mirror 必须在 rotate 之前应用（在原始图像坐标系中）。
    // rotate 之后画布 X/Y 轴互换，若 scale 在 rotate 之后会导致宽高缩放因子被交换→拉伸；
    // mirror 在 rotate 之后会导致左右镜像变成上下翻转。
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final paint = ui.Paint()..filterQuality = ui.FilterQuality.low;
    paint.colorFilter = ui.ColorFilter.matrix(matrix);

    canvas.translate(outW / 2.0, outH / 2.0);
    canvas.scale(
      (needMirror ? -1.0 : 1.0) * coverScale,
      coverScale,
    );
    canvas.rotate(alignRotation * math.pi / 180.0);
    canvas.drawImage(
      srcImage,
      ui.Offset(-srcImage.width / 2.0, -srcImage.height / 2.0),
      paint,
    );

    final picture = recorder.endRecording();
    final swToImage = Stopwatch()..start();
    final outImage = await picture.toImage(iOutW, iOutH);
    swToImage.stop();
    picture.dispose();
    srcImage.dispose();

    // 导出 rawRgba
    final swRgba = Stopwatch()..start();
    final byteData = await outImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    outImage.dispose();
    swRgba.stop();
    debugPrint('[perf] gpu canvas toImage: ${swToImage.elapsedMilliseconds}ms, '
        'toByteData(rawRgba): ${swRgba.elapsedMilliseconds}ms (out=$iOutW x $iOutH)');
    if (byteData == null) return null;

    return _GpuProcessedData(
      rgbaBytes: byteData.buffer.asUint8List(),
      width: iOutW,
      height: iOutH,
      outputPath: params.inputPath,
      sharpen: params.postProcess.sharpen,
      clarity: params.postProcess.color.clarity,
      grain: params.postProcess.grain,
      smoothStrength: params.postProcess.smoothStrength,
      vignette: params.postProcess.vignette,
      needRawRgba: needRawRgba,
    );
  } catch (e, st) {
    debugPrint('[capture] GPU 色彩矩阵处理失败: $e\n$st');
    return null;
  }
}
