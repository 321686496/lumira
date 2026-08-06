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
    final facing = ref.watch(CaptureState.cameraFacingProvider);

    final hasTemplate = currentTemplateId != null;
    // 前置摄像头无闪光灯硬件，隐藏闪光灯按钮
    final showFlashButton = facing == 'back';

    // 右侧按钮数量：全屏(1) + 模板叠图(1) + 剪影(1) + 场景灵感(1) + 闪光灯(1)
    final rightButtonCount = 1 + // 全屏
        (hasTemplate ? 2 : 0) + // 模板叠图 + 剪影
        1 + // 场景灵感
        (showFlashButton ? 1 : 0); // 闪光灯
    // 平衡间距：无模板时右侧按钮少，左侧补齐差值让标题居中
    // 有模板时右侧按钮多，补齐会导致 Expanded 宽度不足，故不补齐
    final balancePadding = !hasTemplate
        ? (rightButtonCount - 1) * 36.0 // -1 抵消左侧返回按钮
        : 0.0;

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
              // 平衡间距：让标题在无模板时相对屏幕居中
              if (balancePadding > 0) SizedBox(width: balancePadding),
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
                icon: Icons.explore,
                tooltip: '场景灵感',
                onPressed: () =>
                    GoRouter.of(context).push(RouteNames.captureSceneGuide),
              ),
              if (showFlashButton)
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
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color iconColor;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20, color: iconColor),
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      tooltip: tooltip,
    );
  }
}
