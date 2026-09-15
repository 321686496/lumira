import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/data/templates/hk_noir_portrait.dart';
import 'package:lumira_app_flutter/features/capture/data/templates/soft_portrait.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/capture/widgets/template_info_card.dart';

void main() {
  Widget wrap(Widget child, {List<Override> overrides = const <Override>[]}) =>
      ProviderScope(
        overrides: <Override>[
          themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
          ...overrides,
        ],
        child: MaterialApp(
          home: Scaffold(body: child),
        ),
      );

  /// 仅场景指南有内容的模板（无姿势描述、无道具）
  const sceneOnlyTemplate = PhotoTemplate(
    meta: TemplateMeta(
      id: 'scene_only',
      name: '仅场景模板',
      category: 'portrait',
      classification: TemplateClassification(type: 'portrait'),
      description: '这是模板描述，信息卡不应展示',
    ),
    composition: Composition(),
    pose: Pose(),
    camera: CameraParams(),
    sceneGuide: SceneGuide(
      lightDirection: '侧逆光',
      shootingDistance: '1.5m',
      background: '白墙',
      bestTime: '15:00-17:00',
      tips: <String>['注意避开正午硬光'],
    ),
    postProcess: PostProcess(color: PostProcessColor()),
  );

  /// 仅道具信息有内容的模板（无姿势描述、无场景指南）
  const propsOnlyTemplate = PhotoTemplate(
    meta: TemplateMeta(
      id: 'props_only',
      name: '仅道具模板',
      category: 'portrait',
      classification: TemplateClassification(type: 'portrait'),
    ),
    composition: Composition(),
    pose: Pose(),
    camera: CameraParams(),
    sceneGuide: SceneGuide(props: <String>['咖啡杯', '干花']),
    postProcess: PostProcess(color: PostProcessColor()),
  );

  testWidgets('默认展开并默认选中姿势描述：展示姿势文案，不展示模板描述',
      (tester) async {
    await tester
        .pumpWidget(wrap(const TemplateInfoCard(template: softPortraitTemplate)));

    // 模板名
    expect(find.textContaining('柔光人像'), findsOneWidget);
    // 姿势描述（默认选中 姿势 tab，取当前姿势下标 0 的描述）
    expect(find.textContaining('人物位于画面中央偏右'), findsOneWidget);
    // 模板描述（meta.description）不再展示
    expect(find.textContaining('本模板专为打造低对比'), findsNothing);
    // 三个 tab 均可用
    expect(find.text('场景'), findsOneWidget);
    expect(find.text('道具'), findsOneWidget);
    expect(find.text('姿势'), findsOneWidget);
  });

  testWidgets('tab 切换：点击场景/道具切到对应内容', (tester) async {
    await tester
        .pumpWidget(wrap(const TemplateInfoCard(template: softPortraitTemplate)));

    // 切到场景指南：展示拍摄注意点
    await tester.tap(find.text('场景'));
    await tester.pumpAndSettle();
    expect(find.textContaining('补光指引'), findsOneWidget);
    expect(find.textContaining('人物位于画面中央偏右'), findsNothing);

    // 切到道具信息：展示道具
    await tester.tap(find.text('道具'));
    await tester.pumpAndSettle();
    expect(find.text('米白色单肩包'), findsOneWidget);
    expect(find.textContaining('补光指引'), findsNothing);
  });

  testWidgets('tab 选择写入持久化 provider', (tester) async {
    ProviderContainer? container;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return const TemplateInfoCard(template: softPortraitTemplate);
          },
        ),
      ),
    );

    expect(container!.read(CaptureState.templateInfoCardTabProvider), isNull);

    await tester.tap(find.text('道具'));
    await tester.pumpAndSettle();
    expect(container!.read(CaptureState.templateInfoCardTabProvider), 'props');
  });

  testWidgets('无姿势描述时默认选中场景指南', (tester) async {
    await tester
        .pumpWidget(wrap(const TemplateInfoCard(template: sceneOnlyTemplate)));

    // 默认落到场景指南：展示拍摄注意点
    expect(find.textContaining('注意避开正午硬光'), findsOneWidget);
    // 无道具、无姿势描述 → 只剩「场景」一个分区，无需切换故不渲染 tab
    expect(find.text('道具'), findsNothing);
    expect(find.text('姿势'), findsNothing);
    expect(find.text('场景'), findsNothing);
  });

  testWidgets('无姿势描述且无场景指南时默认选中道具信息', (tester) async {
    await tester
        .pumpWidget(wrap(const TemplateInfoCard(template: propsOnlyTemplate)));

    expect(find.text('咖啡杯'), findsOneWidget);
    // 只有一个可用分区时无需 tab 切换
    expect(find.text('道具'), findsNothing);
  });

  testWidgets('点击折叠后隐藏内容与 tab，再点展开恢复', (tester) async {
    await tester
        .pumpWidget(wrap(const TemplateInfoCard(template: softPortraitTemplate)));

    // 点击标题行折叠
    await tester.tap(find.textContaining('柔光人像'));
    await tester.pumpAndSettle();
    expect(find.textContaining('人物位于画面中央偏右'), findsNothing);
    expect(find.text('场景'), findsNothing);

    // 再点展开
    await tester.tap(find.textContaining('柔光人像'));
    await tester.pumpAndSettle();
    expect(find.textContaining('人物位于画面中央偏右'), findsOneWidget);
    expect(find.text('场景'), findsOneWidget);
  });

  testWidgets('切换模板（不同 id）后重置为展开', (tester) async {
    await tester
        .pumpWidget(wrap(const TemplateInfoCard(template: softPortraitTemplate)));

    // 先折叠
    await tester.tap(find.textContaining('柔光人像'));
    await tester.pumpAndSettle();
    expect(find.textContaining('人物位于画面中央偏右'), findsNothing);

    // 切换到另一模板
    await tester.pumpWidget(
        wrap(const TemplateInfoCard(template: hkNoirPortraitTemplate)));
    await tester.pumpAndSettle();

    expect(find.textContaining('港风'), findsOneWidget);
  });

  testWidgets('空内容模板：无任何分区时仅渲染标题条', (tester) async {
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
    // 无 tab、无内容
    expect(find.text('场景'), findsNothing);
    expect(find.text('道具'), findsNothing);
    expect(find.text('姿势'), findsNothing);
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
  });
}
