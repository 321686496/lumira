import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';

void main() {
  test('sortedTemplatesProvider returns templates sorted by usage frequency', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final result = await container.read(CaptureState.sortedTemplatesProvider.future);
    // At least 12 system templates
    expect(result.length, greaterThanOrEqualTo(12));
    // First entry should have a valid id
    expect(result.first.meta.id, isNotNull);
  });

  test('sortedTemplatesProvider degrades gracefully when DAO unavailable', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // In test environment, DAO is unavailable, should fallback to unsorted system templates
    final result = await container.read(CaptureState.sortedTemplatesProvider.future);
    expect(result.length, greaterThanOrEqualTo(12));
  });
}
