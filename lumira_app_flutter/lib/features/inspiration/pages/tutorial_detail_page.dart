import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/inspiration_providers.dart';
import '../data/tutorial_content.dart';
import '../data/tutorial_models.dart';

/// 拍摄小课堂详情页
class TutorialDetailPage extends ConsumerWidget {
  const TutorialDetailPage({super.key, this.tutorialId});

  final String? tutorialId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final isNeumorphic = appTheme.style == UIStyle.neumorphic;
    final tutorial = tutorialId != null
        ? TutorialContent.getById(tutorialId!)
        : null;

    if (tutorial == null) {
      return Scaffold(
        backgroundColor: tokens.canvas,
        appBar: const LumiraNav(title: '拍摄小课堂', transparent: true),
        body: Center(
          child: Text('教程不存在', style: TextStyle(color: tokens.textTertiary)),
        ),
      );
    }

    // 进入即标记已读（幂等）
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final dao = await ref.read(tutorialReadDaoProvider.future);
      await dao.markRead(tutorial.id);
      ref.invalidate(tutorialReadIdsProvider);
    });

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: const LumiraNav(title: '拍摄小课堂', transparent: true),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.6),
            radius: 1.2,
            colors: [tokens.brandSubtle.withOpacity(0.35), tokens.canvas.withOpacity(0.0)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  tutorial.coverImage,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    height: 200,
                    color: tokens.surfaceAlt,
                    child: Icon(Icons.photo_outlined,
                        size: 40, color: tokens.textTertiary),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tutorial.title,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                          fontFamily: 'Noto Serif SC',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _MetaChip(label: tutorial.readMinutes, tokens: tokens),
                          for (final tag in tutorial.tags)
                            _MetaChip(label: tag, tokens: tokens),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        tutorial.intro,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.7,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      for (var i = 0; i < tutorial.steps.length; i++) ...[
                        _StepBlock(
                          index: i + 1,
                          step: tutorial.steps[i],
                          tokens: tokens,
                        ),
                        const SizedBox(height: 16),
                      ],
                      const SizedBox(height: 8),
                      _TipsBlock(
                        tips: tutorial.tips,
                        tokens: tokens,
                        isNeumorphic: isNeumorphic,
                      ),
                      const SizedBox(height: 24),
                      _CtaButton(tutorial: tutorial, tokens: tokens),
                      if (tutorial.academyCourseId != null) ...[
                        const SizedBox(height: 16),
                        _AcademyBanner(
                          onTap: () => GoRouter.of(context).push(
                            RouteNames.build(
                              RouteNames.profileAcademyDetail,
                              {RouteNames.paramAcademyId: tutorial.academyCourseId!},
                            ),
                          ),
                          tokens: tokens,
                          isNeumorphic: isNeumorphic,
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.tokens});
  final String label;
  final ThemeTokens tokens;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.brandSubtle,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, color: tokens.brandDeep)),
    );
  }
}

class _StepBlock extends StatelessWidget {
  const _StepBlock({required this.index, required this.step, required this.tokens});
  final int index;
  final TutorialStep step;
  final ThemeTokens tokens;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.brand,
                shape: BoxShape.circle,
              ),
              child: Text('$index',
                  style: const TextStyle(fontSize: 12, color: Colors.white)),
            ),
            const SizedBox(width: 8),
            Text(
              step.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
                fontFamily: 'Noto Serif SC',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 30),
          child: Text(
            step.body,
            style: TextStyle(fontSize: 14, height: 1.6, color: tokens.textSecondary),
          ),
        ),
        if (step.imageAsset != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                step.imageAsset!,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  height: 120,
                  color: tokens.surfaceAlt,
                  child: Icon(Icons.image_outlined,
                      size: 24, color: tokens.textTertiary),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TipsBlock extends StatelessWidget {
  const _TipsBlock({
    required this.tips,
    required this.tokens,
    this.isNeumorphic = false,
  });
  final List<String> tips;
  final ThemeTokens tokens;
  final bool isNeumorphic;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      // neumorphic 风格：画布上信息卡用 surface 同源底 + 轻量双向凸起阴影；
      // 其余风格保留原品牌淡色信息底。
      decoration: BoxDecoration(
        color: isNeumorphic ? tokens.surface : tokens.brandSubtle.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        boxShadow: isNeumorphic ? tokens.shadowConvexSubtle : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('小贴士',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tokens.brandDeep)),
          const SizedBox(height: 8),
          for (final tip in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, size: 14, color: tokens.brand),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(tip,
                        style: TextStyle(
                            fontSize: 13, height: 1.5, color: tokens.textSecondary)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  const _CtaButton({required this.tutorial, required this.tokens});
  final ShootingTutorial tutorial;
  final ThemeTokens tokens;
  @override
  Widget build(BuildContext context) {
    return LumiraButton(
      variant: ButtonVariant.primary,
      onPressed: () {
        final cta = tutorial.cta;
        if (cta.type == TutorialCtaType.scene) {
          GoRouter.of(context).push(
            RouteNames.withSceneId(RouteNames.captureSceneDetail, cta.targetId),
          );
        } else {
          GoRouter.of(context).push(RouteNames.withTemplateId(RouteNames.templatesDetail, cta.targetId));
        }
      },
      child: const Text('去试试'),
    );
  }
}

class _AcademyBanner extends StatelessWidget {
  const _AcademyBanner({
    required this.onTap,
    required this.tokens,
    this.isNeumorphic = false,
  });
  final VoidCallback onTap;
  final ThemeTokens tokens;
  final bool isNeumorphic;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        // neumorphic 风格：画布上卡片用 surface 同源底 + 轻量凸起阴影，去品牌描边；
        // 其余风格保留原「品牌细描边」透明卡片。
        decoration: BoxDecoration(
          color: isNeumorphic ? tokens.surface : null,
          border: isNeumorphic
              ? null
              : Border.all(color: tokens.brand.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isNeumorphic ? tokens.shadowConvexSubtle : null,
        ),
        child: Row(
          children: [
            Icon(Icons.school_outlined, size: 18, color: tokens.brand),
            const SizedBox(width: 8),
            Expanded(
              child: Text('想系统学？进入美学院',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tokens.brandDeep)),
            ),
            Icon(Icons.chevron_right, size: 18, color: tokens.textTertiary),
          ],
        ),
      ),
    );
  }
}