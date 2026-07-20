import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../data/capture_state.dart';
import '../widgets/capture_button.dart';
import '../widgets/capture_nav.dart';
import '../widgets/camera_preview.dart';

/// 拍摄页（Phase 2 MVP）
///
/// 视觉规格来源：lumira-app/src/pages/capture/index.vue
/// 本任务范围：导航栏 + 相机预览 + 拍摄按钮 + 缩略图 + 切换摄像头 + 横竖屏自适应
/// 范围外（后续任务）：构图叠图 / 姿势剪影 / 参数面板 / 滤镜选择器 / 场景预设 / Raw 模式 / 水平仪 / 双击
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

  @override
  void initState() {
    super.initState();
    // 监听系统 metrics 变化（横竖屏切换）
    WidgetsBinding.instance.addObserver(this);
    // 初始化 templateId 状态（来自 URL）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(CaptureState.currentTemplateIdProvider.notifier).state =
          widget.templateId;
    });
  }

  @override
  void dispose() {
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
    // Forced fix: 使用 canPop 保护，避免从深链接直接进入 capture 时 pop 到空栈退出应用
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.of(context).go(RouteNames.home);
    }
  }

  void _onCapture() {
    // 实际拍照由 CameraAwesomeBuilder.onMediaTap 处理
    // 此处仅做 UI 反馈（按钮动画已在 CaptureButton 中处理）
  }

  void _onCaptured(String path) {
    ref.read(CaptureState.lastPhotoPathProvider.notifier).state = path;
  }

  void _switchCamera() {
    final current = ref.read(CaptureState.cameraFacingProvider);
    ref.read(CaptureState.cameraFacingProvider.notifier).state =
        current == 'back' ? 'front' : 'back';
  }

  @override
  Widget build(BuildContext context) {
    final isFullscreen = ref.watch(CaptureState.isFullscreenProvider);
    final lastPhoto = ref.watch(CaptureState.lastPhotoPathProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 相机预览（全屏）
          CameraPreview(onCaptured: _onCaptured),

          // 顶部导航栏（全屏模式下隐藏）
          if (!isFullscreen)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: CaptureNav(onBack: _onBack),
            ),

          // 底部操作栏（拍摄按钮 + 缩略图 + 切换摄像头）
          if (!isFullscreen)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BottomBar(
                isLandscape: _isLandscape,
                lastPhotoPath: lastPhoto,
                onCapture: _onCapture,
                onSwitchCamera: _switchCamera,
                onThumbnailTap: (path) {
                  GoRouter.of(context).push(
                    '${RouteNames.capturePreview}?${RouteNames.paramPhotoId}=$path',
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// 底部操作栏
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.isLandscape,
    required this.lastPhotoPath,
    required this.onCapture,
    required this.onSwitchCamera,
    required this.onThumbnailTap,
  });

  final bool isLandscape;
  final String? lastPhotoPath;
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 缩略图（左）
            GestureDetector(
              onTap: lastPhotoPath != null
                  ? () => onThumbnailTap(lastPhotoPath!)
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
                        child: Image.network(
                          lastPhotoPath!,
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
            const Spacer(),
            // 拍摄按钮（中）
            CaptureButton(onTap: onCapture),
            const Spacer(),
            // 切换摄像头（右）
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
      ),
    );
  }
}
