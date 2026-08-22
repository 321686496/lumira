import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/features/capture/pages/capture_scene_detail_page.dart';

void main() {
  group('buildSceneAchievement 等级阈值边界', () {
    const sceneId = 'scene-test';

    test('count=0 → Lv0/未开始，nextLevelCount=1', () {
      final a = buildSceneAchievement(sceneId, 0);
      expect(a.sceneId, sceneId);
      expect(a.level, 0);
      expect(a.levelName, '未开始');
      expect(a.photoCount, 0);
      expect(a.nextLevelCount, 1);
    });

    test('count=1/2 → Lv1/初遇，nextLevelCount=3', () {
      final a1 = buildSceneAchievement(sceneId, 1);
      expect(a1.level, 1);
      expect(a1.levelName, '初遇');
      expect(a1.photoCount, 1);
      expect(a1.nextLevelCount, 3);

      final a2 = buildSceneAchievement(sceneId, 2);
      expect(a2.level, 1);
      expect(a2.levelName, '初遇');
      expect(a2.photoCount, 2);
      expect(a2.nextLevelCount, 3);
    });

    test('count=3/9 → Lv2/熟悉，nextLevelCount=10', () {
      final a3 = buildSceneAchievement(sceneId, 3);
      expect(a3.level, 2);
      expect(a3.levelName, '熟悉');
      expect(a3.photoCount, 3);
      expect(a3.nextLevelCount, 10);

      final a9 = buildSceneAchievement(sceneId, 9);
      expect(a9.level, 2);
      expect(a9.levelName, '熟悉');
      expect(a9.photoCount, 9);
      expect(a9.nextLevelCount, 10);
    });

    test('count=10/30 → Lv3/精通，nextLevelCount=30', () {
      final a10 = buildSceneAchievement(sceneId, 10);
      expect(a10.level, 3);
      expect(a10.levelName, '精通');
      expect(a10.photoCount, 10);
      expect(a10.nextLevelCount, 30);

      final a30 = buildSceneAchievement(sceneId, 30);
      expect(a30.level, 3);
      expect(a30.levelName, '精通');
      expect(a30.photoCount, 30);
      expect(a30.nextLevelCount, 30);
    });
  });
}