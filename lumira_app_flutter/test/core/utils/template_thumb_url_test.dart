import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/utils/image_cache.dart';

const backendUrl = 'https://api.example.com/api/v1';

void main() {
  test('rewrites template upload URLs to storage-direct thumbnails', () {
    const original = 'https://cdn.example.com/uploads/templates/srv_a/image_0.png';
    expect(
      templateThumbUrl(original, baseUrl: backendUrl, w: 800),
      'https://cdn.example.com/uploads/thumbs/templates/srv_a/image_0.w800.webp',
    );
  });

  test('snaps requested width to the ladder', () {
    const original = 'https://cdn.example.com/uploads/templates/srv_a/image_0.png';
    // 700 距 640 最近 → w640
    expect(
      templateThumbUrl(original, baseUrl: backendUrl, w: 700),
      'https://cdn.example.com/uploads/thumbs/templates/srv_a/image_0.w640.webp',
    );
  });

  test('keeps non-template and already-thumb urls unchanged', () {
    const original = 'https://cdn.example.com/uploads/categories/a/icon.png';
    const thumb =
        'https://cdn.example.com/uploads/thumbs/templates/a/i.w800.webp';
    expect(templateThumbUrl(original), original);
    expect(templateThumbUrl(thumb), thumb);
  });

  test('parses legacy thumbnail-endpoint URLs into storage-direct thumbnails', () {
    // DB 里可能遗留旧版缩略图端点 /api/v1/thumbs/*，应能识别并推导存储直连
    expect(
      templateThumbUrl(
        'https://lumira.iwtle.top/api/v1/thumbs/templates/srv_b/image_0.webp?w=480',
        baseUrl: backendUrl,
        w: 480,
      ),
      'https://lumira.iwtle.top/uploads/thumbs/templates/srv_b/image_0.w480.webp',
    );
    expect(
      categoryThumbUrl(
        'https://lumira.iwtle.top/api/v1/thumbs/categories/portrait?w=320',
        'portrait',
        baseUrl: backendUrl,
        w: 320,
      ),
      'https://lumira.iwtle.top/uploads/thumbs/categories/portrait/w320.jpg',
    );
  });

  test('builds template thumbnail fallback URL on the backend endpoint', () {
    const original = 'https://cdn.example.com/uploads/templates/srv_a/image_0.png';
    expect(
      templateThumbFallbackUrl(original, baseUrl: backendUrl, w: 800),
      'https://api.example.com/api/v1/thumbs/templates/srv_a/image_0.png?w=800',
    );
  });

  test('builds category storage-direct thumbnails and fallbacks', () {
    const iconUrl = 'https://cdn.example.com/uploads/categories/portrait/icon.png';
    // 600 距 640 最近 → w640
    expect(
      categoryThumbUrl(iconUrl, 'portrait', baseUrl: backendUrl, w: 600),
      'https://cdn.example.com/uploads/thumbs/categories/portrait/w640.jpg',
    );
    expect(
      categoryThumbFallbackUrl(iconUrl, 'portrait', baseUrl: backendUrl, w: 600),
      'https://api.example.com/api/v1/thumbs/categories/portrait?w=640',
    );
    // key 不匹配时原样返回，由上层走内置图标兜底
    expect(categoryThumbUrl(iconUrl, 'other'), iconUrl);
    expect(categoryThumbFallbackUrl(iconUrl, 'other'), isNull);
  });
}
