import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/data/templates/hk_noir_portrait.dart';
import 'package:lumira_app_flutter/features/capture/data/templates/soft_portrait.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/capture/widgets/template_info_card.dart';

void main() {
  Widget wrap(Widget child) => ProviderScope(
        overrides: [
          themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        ],
        child: MaterialApp(
          home: Scaffold(body: child),
        ),
      );

  testWidgets('默认展开：显示模板名、简介与注意点', (tester) async {
    await tester.pumpWidget(wrap(const TemplateInfoCard(template: softPortraitTemplate)));

    // 模板名
    expect(find.text('柔光人像'), findsOneWidget);
    // 简介（meta.description）
    expect(find.textContaining('柔光环境下的半身人像'), findsOneWidget);
    // 注意点（sceneGuide.tips）
    expect(find.textContaining('避免顶光直射造成眼窝阴影'), findsOneWidget);
  });

  testWidgets('点击折叠后隐藏内容，再点展开恢复', (tester) async {
    await tester.pumpWidget(wrap(const TemplateInfoCard(template: softPortraitTemplate)));

    // 点击标题行折叠
    await tester.tap(find.text('柔光人像'));
    await tester.pumpAndSettle();
    expect(find.textContaining('柔光环境下的半身人像'), findsNothing);

    // 再点展开
    await tester.tap(find.text('柔光人像'));
    await tester.pumpAndSettle();
    expect(find.textContaining('柔光环境下的半身人像'), findsOneWidget);
  });

  testWidgets('切换模板（不同 id）后重置为展开', (tester) async {
    await tester.pumpWidget(wrap(const TemplateInfoCard(template: softPortraitTemplate)));

    // 先折叠
    await tester.tap(find.text('柔光人像'));
    await tester.pumpAndSettle();
    expect(find.textContaining('柔光环境下的半身人像'), findsNothing);

    // 切换到另一模板
    await tester.pumpWidget(
        wrap(const TemplateInfoCard(template: hkNoirPortraitTemplate)));
    await tester.pumpAndSettle();

    expect(find.text('港风夜景人像'), findsOneWidget);
    expect(find.textContaining('王家卫式港风夜景'), findsOneWidget);
  });

  testWidgets('空内容模板：无简介与注意点时仅渲染标题条', (tester) async {
    const emptyTemplate = PhotoTemplate(
      meta: TemplateMeta(
        id: 'empty',
        name: '空内容模板',
        category: 'portrait',
        classification: TemplateClassification(type: 'portrait'),
        description: '',
      ),
      composition: Composition(),
      pose: Pose(),
      camera: CameraParams(),
      sceneGuide: SceneGuide(tips: <String>[]),
      postProcess: PostProcess(color: PostProcessColor()),
    );

    await tester.pumpWidget(wrap(const TemplateInfoCard(template: emptyTemplate)));

    // 模板名（标题条）仍渲染
    expect(find.text('空内容模板'), findsOneWidget);
    // 简介（description 为空字符串）不渲染
    expect(find.text(''), findsNothing);
    // 注意点（check 图标行）不渲染
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
  });
}
