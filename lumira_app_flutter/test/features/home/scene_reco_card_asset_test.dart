import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/home/data/home_mock_data.dart';
import 'package:lumira_app_flutter/features/home/widgets/scene_reco_card.dart';

void main() {
  testWidgets('renders local asset image when imageSeed starts with assets/',
      (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(800, 1400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SceneRecoCard(
            scene: SceneReco(
              id: 'scene-x',
              name: '本地场景',
              vibe: '本地图片',
              imageSeed: 'assets/images/scenes/scene_cafe.jpg',
              badgeText: '推荐',
              badgeBrand: false,
              photoCount: 0,
            ),
            onTap: _noop,
          ),
        ),
      ),
    ));

    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images, isNotEmpty);
    expect(images.first.image, isA<AssetImage>());
    expect((images.first.image as AssetImage).assetName,
        'assets/images/scenes/scene_cafe.jpg');
  });
}

void _noop() {}
