import 'dart:async';
import 'dart:io';
import 'dart:math' show sqrt;

import 'package:camerawesome_ohos/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../data/capture_state.dart';
import '../domain/photo_template.dart';
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
  const CapturePage({super.key, this.templateId});

  /// 来自 URL ?templateId=xxx，null 表示自由拍摄
  final String? templateId;

  @override
  ConsumerState<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends ConsumerState<CapturePage>
    with WidgetsBindingObserver {
  bool _isLandscape = false;
  StreamSubscription<MediaCapture?>? _captureSub;
  CameraState? _lastState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(CaptureState.currentTemplateIdProvider.notifier).state =
          widget.templateId;
    });
  }

  @override
  void dispose() {
    _captureSub?.cancel();
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

    _captureSub?.cancel();
    _captureSub = state.captureState$.listen((media) {
      if (media != null &&
          media.status == MediaCaptureStatus.success &&
          media.filePath.isNotEmpty) {
        ref.read(CaptureState.lastPhotoPathProvider.notifier).state =
            media.filePath;
      }
    });

    final flashMode = ref.read(CaptureState.flashModeProvider);
    state.sensorConfig.setFlashMode(_mapFlashMode(flashMode));
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
  /// 修复 Bug 1：添加错误反馈，避免静默失败
  void _onCapture() {
    final state = ref.read(CaptureState.cameraStateProvider);
    if (state == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('相机正在初始化，请稍候...'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    try {
      state.when(
        onPhotoMode: (photoState) => photoState.takePhoto(),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('拍照失败：$e'),
          duration: const Duration(seconds: 2),
        ),
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
    }
  }

  /// 缩放：同步到相机引擎与 zoomProvider
  ///
  /// 滑块值 [0, 1] 通过平方根曲线映射到相机 zoom [0, 1]，
  /// 使滑块前半段也能产生明显的缩放效果（camerawesome 的 setZoom 在低值段
  /// 视觉变化很小，用 sqrt 曲线让 0.5 → 0.707 而非 0.5 → 0.5）。
  void _onZoomChanged(double sliderValue) {
    ref.read(CaptureState.zoomProvider.notifier).state = sliderValue;
    final actualZoom = sqrt(sliderValue);
    final state = ref.read(CaptureState.cameraStateProvider);
    state?.sensorConfig.setZoom(actualZoom);
  }

  @override
  Widget build(BuildContext context) {
    final isFullscreen = ref.watch(CaptureState.isFullscreenProvider);
    final bottomPanelExpanded =
        ref.watch(CaptureState.bottomPanelExpandedProvider);
    final zoom = ref.watch(CaptureState.zoomProvider);

    // 监听闪光灯模式变化，同步到相机引擎
    ref.listen<CaptureFlashMode>(CaptureState.flashModeProvider, (prev, next) {
      final state = ref.read(CaptureState.cameraStateProvider);
      state?.sensorConfig.setFlashMode(_mapFlashMode(next));
    });

    // 监听相机参数变化，同步 EV 到 brightness（camerawesome 1.4.0 仅支持 brightness）
    // EV 范围 [-3, +3] 映射到 brightness [0, 1]，0 EV → 0.5 brightness
    ref.listen<CameraParams>(CaptureState.effectiveCameraProvider, (prev, next) {
      if (prev?.exposureCompensation == next.exposureCompensation) return;
      final state = ref.read(CaptureState.cameraStateProvider);
      if (state == null) return;
      // EV [-3, +3] → brightness [0, 1]：EV 0 = 0.5, EV +3 = 1.0, EV -3 = 0.0
      final brightness = (next.exposureCompensation + 3.0) / 6.0;
      try {
        state.sensorConfig.setBrightness(brightness.clamp(0.0, 1.0));
      } catch (_) {
        // 某些设备可能不支持 brightness 调节
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 取景器 + 叠图
          CameraPreview(
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

          // 3. 顶部参数 pill 栏（全屏模式下隐藏）
          if (!isFullscreen)
            Positioned(
              top: MediaQuery.of(context).padding.top + 72,
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
              zoom: zoom,
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
    GoRouter.of(context).push(
      '${RouteNames.capturePreview}?photoUrl=${Uri.encodeComponent(path)}',
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
    required this.zoom,
    required this.onZoomChanged,
    required this.onTogglePanel,
    required this.onCapture,
    required this.onSwitchCamera,
    required this.onThumbnailTap,
  });

  final bool isFullscreen;
  final bool bottomPanelExpanded;
  final double zoom;
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
            _ZoomSlider(value: zoom, onChanged: onZoomChanged),

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

/// 缩放滑块：横向滑块 + 当前倍数显示
///
/// 滑块值 [0, 1] 经 sqrt 曲线映射到相机 zoom [0, 1]，
/// 显示的倍数基于实际 zoom 值：1.0x (zoom=0) ~ 6.0x (zoom=1)。
class _ZoomSlider extends StatelessWidget {
  const _ZoomSlider({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    // 实际相机 zoom = sqrt(sliderValue)，显示倍数 = 1 + zoom * 5
    final actualZoom = sqrt(value);
    final displayX = (1 + actualZoom * 5).toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.zoom_in, color: Colors.white70, size: 16),
          Expanded(
            child: Slider(
              value: value.clamp(0.0, 1.0),
              min: 0.0,
              max: 1.0,
              divisions: 100,
              label: '${displayX}x',
              activeColor: Colors.amber,
              inactiveColor: Colors.white24,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 40,
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
