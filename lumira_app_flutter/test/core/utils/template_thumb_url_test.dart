import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/utils/image_cache.dart';

void main() {
  test('rewrites template upload URLs to backend webp variants', () {
    const original =
        'https://cdn.example.com/uploads/templates/srv_a/image_0.png';
    expect(
      templateThumbUrl(
        original,
        baseUrl: 'https://api.example.com/api/v1',
        w: 800,
      ),
      'https://api.example.com/api/v1/thumbs/templates/srv_a/image_0.png?w=800',
    );
  });

  test('keeps non-template and already-optimized urls unchanged', () {
    const original = 'https://cdn.example.com/uploads/categories/a/icon.png';
    const optimized =
        'https://api.example.com/api/v1/thumbs/templates/a/i.png?w=800';
    expect(templateThumbUrl(original), original);
    expect(templateThumbUrl(optimized), optimized);
  });
}
