import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lumira_app_flutter/core/db/dao/gallery_dao.dart';
import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/templates/data/templates_mock_data.dart';
import 'package:lumira_app_flutter/features/templates/data/templates_providers.dart';

class _MockGalleryDao extends Mock implements GalleryDao {}

void main() {
  test('sortedTemplatesProvider returns at least 12 system templates', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final result = await container.read(CaptureState.sortedTemplatesProvider.future);
    // At least 12 system templates
    expect(result.length, greaterThanOrEqualTo(12));
    // First entry should have a valid (non-empty) id
    expect(result.first.meta.id, isNotEmpty);
  });

  test('sortedTemplatesProvider degrades gracefully when DAO unavailable', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // In test environment, DAO is unavailable, should fallback to unsorted system templates
    final result = await container.read(CaptureState.sortedTemplatesProvider.future);
    expect(result.length, greaterThanOrEqualTo(12));
  });

  test('sortedTemplatesProvider sorts by usage frequency when DB available', () async {
    // Override galleryDaoProvider with a mock returning known usage counts.
    // 'soft_portrait' → 5, 'film_vintage' → 3, all others → 0 (not in map).
    final mockGalleryDao = _MockGalleryDao();
    when(() => mockGalleryDao.countByTemplate()).thenAnswer(
      (_) async => {'soft_portrait': 5, 'film_vintage': 3},
    );

    final container = ProviderContainer(
      overrides: [
        galleryDaoProvider.overrideWith((ref) async => mockGalleryDao),
        userPreferenceProvider.overrideWith((ref) async => const UserPreference(
              totalPhotos: 8,
              topCategory: '',
              topCategoryPercentage: 0,
            )),
      ],
    );
    addTearDown(container.dispose);

    final result =
        await container.read(CaptureState.sortedTemplatesProvider.future);
    expect(result.length, greaterThanOrEqualTo(12));

    // Templates with higher usage count should appear before those with lower count.
    final softPortraitIndex =
        result.indexWhere((t) => t.meta.id == 'soft_portrait');
    final filmVintageIndex =
        result.indexWhere((t) => t.meta.id == 'film_vintage');
    final goldenLandscapeIndex =
        result.indexWhere((t) => t.meta.id == 'golden_landscape');

    expect(softPortraitIndex, greaterThanOrEqualTo(0));
    expect(filmVintageIndex, greaterThanOrEqualTo(0));
    expect(goldenLandscapeIndex, greaterThanOrEqualTo(0));
    // count 5 > 3 > 0 → soft_portrait before film_vintage before golden_landscape
    expect(softPortraitIndex, lessThan(filmVintageIndex));
    expect(filmVintageIndex, lessThan(goldenLandscapeIndex));
  });
}
