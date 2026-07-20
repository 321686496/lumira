import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../data/capture_state.dart';

/// 拍摄页导航栏（深色沉浸式）
///
/// 视觉规格来源：lumira-app/src/pages/capture/index.vue line 4-42
/// - 背景: rgba(0,0,0,0.4) 半透明深色
/// - 左侧: 返回按钮
/// - 中间: 标题 + 副标题（模板分类 + 宽高比，自由拍摄时仅显示"自由调参"）
/// - 右侧: 全屏 / 模板叠图显隐 / 剪影显隐 / 场景指南 / 闪光灯
class CaptureNav extends ConsumerWidget implements PreferredSizeWidget {
  const CaptureNav({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTemplateId = ref.watch(CaptureState.currentTemplateIdProvider);
    final isFullscreen = ref.watch(CaptureState.isFullscreenProvider);
    final showTemplate = ref.watch(CaptureState.showTemplateProvider);
    final showSilhouette = ref.watch(CaptureState.showSilhouetteProvider);
    final flashMode = ref.watch(CaptureState.flashModeProvider);

    final hasTemplate = currentTemplateId != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56, // 56dp 主导航高度（不含状态栏）
          child: Row(
            children: [
              // 返回按钮
              _NavIcon(
                icon: Icons.arrow_back_ios_new,
                onPressed: onBack,
              ),
              // 标题（点击打开参数面板）
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => ref
                      .read(CaptureState.panelExpandedProvider.notifier)
                      .state = true,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        hasTemplate ? '模板拍摄' : '自由调参',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (hasTemplate)
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text(
                            '点击调整参数',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                              height: 1.2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // 右侧操作按钮组
              _NavIcon(
                icon: isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                onPressed: () => ref
                    .read(CaptureState.isFullscreenProvider.notifier)
                    .state = !isFullscreen,
              ),
              if (hasTemplate)
                _NavIcon(
                  icon: Icons.crop_free,
                  iconColor: showTemplate ? Colors.amber : Colors.white,
                  onPressed: () => ref
                      .read(CaptureState.showTemplateProvider.notifier)
                      .state = !showTemplate,
                ),
              if (hasTemplate)
                _NavIcon(
                  icon: Icons.accessibility_new,
                  iconColor: showSilhouette ? Colors.amber : Colors.white,
                  onPressed: () => ref
                      .read(CaptureState.showSilhouetteProvider.notifier)
                      .state = !showSilhouette,
                ),
              _NavIcon(
                icon: Icons.help_outline,
                onPressed: () =>
                    GoRouter.of(context).push(RouteNames.captureSceneGuide),
              ),
              _NavIcon(
                icon: flashMode == CaptureFlashMode.off
                    ? Icons.flash_off
                    : flashMode == CaptureFlashMode.torch
                        ? Icons.flashlight_on
                        : Icons.flash_on,
                iconColor: flashMode != CaptureFlashMode.off
                    ? Colors.amber
                    : Colors.white,
                onPressed: () {
                  final next = flashMode == CaptureFlashMode.off
                      ? CaptureFlashMode.torch
                      : CaptureFlashMode.off;
                  ref.read(CaptureState.flashModeProvider.notifier).state = next;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.onPressed,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20, color: iconColor),
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      tooltip: null,
    );
  }
}
