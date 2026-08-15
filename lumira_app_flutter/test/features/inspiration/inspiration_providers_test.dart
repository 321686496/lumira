import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/features/inspiration/data/inspiration_content.dart';
import 'package:lumira_app_flutter/features/inspiration/data/inspiration_providers.dart';
import 'package:lumira_app_flutter/features/inspiration/data/tutorial_models.dart';

void main() {
  group('InspirationContent.slotOf', () {
    test('morning is 05:00-09:59', () {
      expect(InspirationContent.slotOf(DateTime(2026, 8, 14, 8)), 'morning');
    });
    test('noon is 10:00-13:59', () {
      expect(InspirationContent.slotOf(DateTime(2026, 8, 14, 12)), 'noon');
    });
    test('dusk is 14:00-17:59', () {
      expect(InspirationContent.slotOf(DateTime(2026, 8, 14, 16)), 'dusk');
    });
    test('night is otherwise', () {
      expect(InspirationContent.slotOf(DateTime(2026, 8, 14, 22)), 'night');
    });
  });

  group('InspirationContent.pickTodayShoot', () {
    test('prefers slot matching items', () {
      final items = InspirationContent.pickTodayShoot(
        null,
        DateTime(2026, 8, 14, 16), // dusk
      );
      expect(items.length, 4);
      final topIds = items.take(2).map((e) => e.id).toList();
      expect(topIds, containsAll(['sunset-silhouette', 'golden_landscape']));
    });

    test('prefers category matching items', () {
      final items = InspirationContent.pickTodayShoot(
        'night',
        DateTime(2026, 8, 14, 22),
      );
      expect(items.first.categories, contains('night'));
    });
  });

  group('tutorialPicksProvider', () {
    test('可 override 返回教程列表', () async {
      const tutorials = [
        ShootingTutorial(
          id: 't1', title: 't', subtitle: 's',
          coverImage: 'c', category: 'general', readMinutes: '3分钟',
          intro: 'i', cta: TutorialCta(type: TutorialCtaType.scene, targetId: 'cafe-window'),
        ),
      ];
      final container = ProviderContainer(
        overrides: [tutorialPicksProvider.overrideWith((ref) async => tutorials)],
      );
      addTearDown(container.dispose);
      final value = await container.read(tutorialPicksProvider.future);
      expect(value, hasLength(1));
      expect(value.first.id, 't1');
    });
  });

  group('InspirationContent.galleryItems', () {
    test('all items use local assets and known template ids', () {
      expect(InspirationContent.galleryItems.length, 8);
      for (final item in InspirationContent.galleryItems) {
        expect(item.assetPath, startsWith('assets/'));
        expect(item.templateId, isNotEmpty);
      }
    });
  });
}
