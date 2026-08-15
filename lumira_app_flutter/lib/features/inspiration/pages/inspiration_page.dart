import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/inspiration_content.dart';
import '../widgets/inspiration_gallery_section.dart';
import '../widgets/inspiration_guide_bar.dart';
import '../widgets/today_shoot_section.dart';
import '../widgets/tutorial_section.dart';

/// 灵感页
///
/// 纯本地拍照灵感流：顶部引导 + 今日可拍 + 拍摄小课堂 + 灵感图集。
/// 所有内容来自 App 内置静态配置（InspirationContent）与本地拍摄统计。
class InspirationPage extends ConsumerWidget {
  const InspirationPage({super.key});

  void _goSceneGuide(BuildContext context, String sceneId) {
    GoRouter.of(context).push(
      RouteNames.build(
        RouteNames.captureSceneGuide,
        {RouteNames.paramScene: sceneId},
      ),
    );
  }

  void _goTemplateDetail(BuildContext context, String templateId) {
    GoRouter.of(context).push(
      RouteNames.withTemplateId(RouteNames.templatesDetail, templateId),
    );
  }

  String _defaultSceneForSlot() {
    final slot = InspirationContent.slotOf(DateTime.now());
    switch (slot) {
      case 'morning':
        return 'home-cozy';
      case 'noon':
        return 'cafe-window';
      case 'dusk':
        return 'sunset-silhouette';
      default:
        return 'night-street';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: const LumiraNav(title: '灵感', transparent: true),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.6),
            radius: 1.2,
            colors: [
              tokens.brandSubtle.withOpacity(0.35),
              tokens.canvas.withOpacity(0.0),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeUp(
                  child: InspirationGuideBar(
                    onTap: () => _goSceneGuide(context, _defaultSceneForSlot()),
                  ),
                ),
                const SizedBox(height: 20),
                FadeUp(
                  delay: const Duration(milliseconds: 100),
                  child: TodayShootSection(
                    onItemTap: (item) {
                      if (item.target == TodayShootTarget.scene) {
                        _goSceneGuide(context, item.targetId);
                      } else {
                        _goTemplateDetail(context, item.targetId);
                      }
                    },
                    onMoreScenes: () =>
                        GoRouter.of(context).push(RouteNames.scenes),
                  ),
                ),
                const SizedBox(height: 20),
                FadeUp(
                  delay: const Duration(milliseconds: 200),
                  child: TutorialSection(
                    onTutorialTap: (tutorial) => GoRouter.of(context).push(
                      RouteNames.build(
                        RouteNames.inspirationTutorialDetail,
                        {RouteNames.paramTutorialId: tutorial.id},
                      ),
                    ),
                    onAcademyTap: () =>
                        GoRouter.of(context).push(RouteNames.profileAcademy),
                  ),
                ),
                const SizedBox(height: 20),
                FadeUp(
                  delay: const Duration(milliseconds: 300),
                  child: InspirationGallerySection(
                    onItemTap: (item) =>
                        _goTemplateDetail(context, item.templateId),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
