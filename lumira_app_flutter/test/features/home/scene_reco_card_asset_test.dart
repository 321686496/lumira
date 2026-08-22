import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/core/utils/image_cache.dart';
import 'package:lumira_app_flutter/features/home/data/home_mock_data.dart';
import 'package:lumira_app_flutter/features/home/widgets/scene_reco_card.dart';

void main() {
  Widget harness(SceneReco scene) {
    return ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
        uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 520,
            child: SceneRecoCard(scene: scene, onTap: _noop),
          ),
        ),
      ),
    );
  }

  testWidgets('coverUrl 为 http 时使用 CachedNetworkImage', (tester) async {
    await tester.pumpWidget(harness(const SceneReco(
      id: 'scene-x',
      name: '网络场景',
      vibe: 'v',
      imageSeed: 's',
      badgeText: '推荐',
      badgeBrand: false,
      photoCount: 0,
      coverUrl: 'https://example.com/c.jpg',
    )));
    await tester.pump();
    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets('coverUrl 为空时显示占位图（Image 数量为 0）', (tester) async {
    await tester.pumpWidget(harness(const SceneReco(
      id: 'scene-x',
      name: '无封面',
      vibe: 'v',
      imageSeed: 's',
      badgeText: '推荐',
      badgeBrand: false,
      photoCount: 0,
    )));
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.image_outlined), findsWidgets);
  });

  testWidgets('coverUrl 为 data:image 时使用 Image.memory', (tester) async {
    const tinyPng =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
    await tester.pumpWidget(harness(const SceneReco(
      id: 'scene-x',
      name: '数据场景',
      vibe: 'v',
      imageSeed: 's',
      badgeText: '推荐',
      badgeBrand: false,
      photoCount: 0,
      coverUrl: 'data:image/png;base64,$tinyPng',
    )));
    await tester.pump();
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images, isNotEmpty);
    expect(images.first.image, isA<MemoryImage>());
  });
}

void _noop() {}