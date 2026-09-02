import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../data/capture_state.dart';

/// 拍摄页导航栏（毛玻璃胶囊设计）
///
/// 视觉规格来源：lumira-app/src/pages/capture/index.vue line 4-42
/// - 毛玻璃胶囊容器：rgba(20,20,22,0.75) + blur(20) + 圆角 + 边框 + 阴影
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
    final isTrialMode = ref.watch(CaptureState.trialModeProvider);
    final showTemplate = ref.watch(CaptureState.showTemplateProvider);
    final showSilhouette = ref.watch(CaptureState.showSilhouetteProvider);
    final flashMode = ref.watch(CaptureState.flashModeProvider);
    final facing = ref.watch(CaptureState.cameraFacingProvider);
    // 新拟态双轨：叠在相机/动态画面上禁止 blur(毛玻璃)，退回半透明暗底浮层
    final isNeu = ref.watch(appThemeProvider).style == UIStyle.neumorphic;

    final hasTemplate = currentTemplateId != null;
    // 前置摄像头无闪光灯硬件，隐藏闪光灯按钮（试用模式也不显示）
    final showFlashButton = facing == 'back' && !isTrialMode;

    // 右侧按钮数量：全屏(1) + 模板叠图(1) + 剪影(1) + 场景灵感(1) + 闪光灯(1)
    // 试用模式：仅保留"购买解锁"按钮（右侧），不显示全屏/模板/剪影/闪光灯
    final rightButtonCount = isTrialMode
        ? 1
        : 1 + // 全屏
            (hasTemplate ? 2 : 0) + // 模板叠图 + 剪影
            1 + // 场景灵感
            (showFlashButton ? 1 : 0); // 闪光灯
    // 平衡间距：无模板时右侧按钮少，左侧补齐差值让标题居中
    // 有模板时右侧按钮多，补齐会导致 Expanded 宽度不足，故不补齐
    final balancePadding = !hasTemplate && !isTrialMode
        ? (rightButtonCount - 1) * 36.0 // -1 抵消左侧返回按钮
        : 0.0;

    // 导航胶囊本体
    final Widget capsule = Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF141416).withOpacity(0.75),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            // 返回按钮
            _NavIcon(
              icon: Icons.arrow_back_ios_new,
              onPressed: onBack,
            ),
            // 平衡间距：让标题在无模板时相对屏幕居中
            if (balancePadding > 0) SizedBox(width: balancePadding),
            // 标题（点击打开参数面板；试用模式点击提示解锁）
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (isTrialMode) {
                    LumiraToast.show(
                      context,
                      '试用模式不可调整参数，购买解锁后即可使用',
                      duration: const Duration(milliseconds: 1200),
                    );
                    return;
                  }
                  ref
                      .read(CaptureState.panelExpandedProvider.notifier)
                      .state = true;
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      isTrialMode
                          ? '试用模板'
                          : (hasTemplate ? '模板拍摄' : '自由调参'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.2,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasTemplate && !isTrialMode)
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
            if (isTrialMode)
              _NavIcon(
                icon: Icons.lock_open_outlined,
                tooltip: '购买解锁',
                onPressed: () {
                  final tid = currentTemplateId;
                  if (tid == null || tid.isEmpty) return;
                  final tpl = ref.read(CaptureState.originalTemplateProvider);
                  final price = tpl?.meta.price ?? 0;
                  GoRouter.of(context).push(
                    '${RouteNames.templatesUnlock}?templateId=$tid&price=$price',
                  );
                },
              )
            else ...[
              _NavIcon(
                icon: isFullscreen
                    ? Icons.fullscreen_exit
                    : Icons.fullscreen,
                onPressed: () => ref
                    .read(CaptureState.isFullscreenProvider.notifier)
                    .state = !isFullscreen,
              ),
              if (hasTemplate)
                _NavIcon(
                  icon: Icons.crop_free,
                  iconColor: showTemplate ? const Color(0xFFC9A96E) : Colors.white,
                  onPressed: () => ref
                      .read(CaptureState.showTemplateProvider.notifier)
                      .state = !showTemplate,
                ),
              if (hasTemplate)
                _NavIcon(
                  icon: Icons.accessibility_new,
                  iconColor: showSilhouette ? const Color(0xFFC9A96E) : Colors.white,
                  onPressed: () => ref
                      .read(CaptureState.showSilhouetteProvider.notifier)
                      .state = !showSilhouette,
                ),
              _NavIcon(
                icon: Icons.explore,
                tooltip: '使用指南',
                onPressed: () =>
                    GoRouter.of(context).push(RouteNames.captureTutorial),
              ),
              if (showFlashButton)
                _NavIcon(
                  icon: flashMode == CaptureFlashMode.off
                      ? Icons.flash_off
                      : flashMode == CaptureFlashMode.torch
                          ? Icons.flashlight_on
                          : Icons.flash_on,
                  iconColor: flashMode != CaptureFlashMode.off
                      ? const Color(0xFFC9A96E)
                      : Colors.white,
                  onPressed: () {
                    final next = flashMode == CaptureFlashMode.off
                        ? CaptureFlashMode.torch
                        : CaptureFlashMode.off;
                    ref.read(CaptureState.flashModeProvider.notifier).state = next;
                  },
                ),
            ],
          ],
        ),
      ),
    );

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        // 新拟态下不引入毛玻璃：直接呈现半透明暗底浮层（无 blur）
        child: isNeu
            ? capsule
            : ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: capsule,
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
      icon: Icon(icon, size: 18, color: iconColor),
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      tooltip: tooltip,
    );
  }
}
