import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/templates/widgets/adaptive_cover_image.dart';

void main() {
  group('clampCoverRatio', () {
    test('常规比例在区间内保持不变', () {
      expect(clampCoverRatio(3 / 4), closeTo(0.75, 1e-9));
      expect(clampCoverRatio(1.0), 1.0);
      expect(clampCoverRatio(16 / 9), closeTo(16 / 9, 1e-9));
    });
    test('9:16 长屏钳到最低比例 0.65', () {
      expect(clampCoverRatio(9 / 16), closeTo(kMinCoverRatio, 1e-9));
    });
    test('更长的竖图（如 1:4）也钳到 0.65', () {
      expect(clampCoverRatio(0.25), closeTo(kMinCoverRatio, 1e-9));
    });
    test('超宽全景钳到最高比例 2.0', () {
      expect(clampCoverRatio(3.0), closeTo(kMaxCoverRatio, 1e-9));
      expect(clampCoverRatio(4 / 1), closeTo(kMaxCoverRatio, 1e-9));
    });
  });

  group('buildCoverProvider', () {
    test('coverData base64 → MemoryImage', () {
      final p = buildCoverProvider(null, 'data:image/png;base64,aGVsbG8=');
      expect(p, isA<MemoryImage>());
    });
    test('cover 以 data: 开头 → MemoryImage', () {
      final p = buildCoverProvider('data:image/png;base64,aGVsbG8=', null);
      expect(p, isA<MemoryImage>());
    });
    test('assets 路径 → AssetImage', () {
      final p = buildCoverProvider('assets/templates/x.png', null);
      expect(p, isA<AssetImage>());
    });
    test('http → NetworkImage', () {
      final p = buildCoverProvider('https://example.com/a.jpg', null);
      expect(p, isA<NetworkImage>());
    });
    test('本地文件路径 → FileImage', () {
      final p = buildCoverProvider(r'C:\tmp\a.jpg', null);
      expect(p, isA<FileImage>());
    });
    test('无来源 → null', () {
      expect(buildCoverProvider(null, null), isNull);
      expect(buildCoverProvider('', null), isNull);
      expect(buildCoverProvider(null, ''), isNull);
    });
    test('非法 base64 → null', () {
      expect(buildCoverProvider('data:image/png;base64,!!!', null), isNull);
    });
  });

  group('AdaptiveCoverImage', () {
    // 1x1 透明 PNG（base64），解码后真实比例 = 1.0
    const png1x1 =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

    testWidgets('无来源时显示 fallback', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AdaptiveCoverImage(
            cover: null,
            coverData: null,
            fallback: const Text('EMPTY'),
          ),
        ),
      ));
      expect(find.text('EMPTY'), findsOneWidget);
    });

    testWidgets('加载中先用默认 3:4，解码完成后用真实比例', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AdaptiveCoverImage(
            cover: png1x1,
            fallback: const Text('EMPTY'),
          ),
        ),
      ));
      // 加载中（未解码）：默认比例 0.75
      expect(
        tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
        closeTo(kDefaultCoverRatio, 1e-9),
      );
      // 等待真实解码（base64 走 UI isolate 异步，需 runAsync）
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pump();
      // 1x1 图片真实比例 1.0
      expect(
        tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
        closeTo(1.0, 1e-9),
      );
    });
  });
}
