import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_ratio.dart';

void main() {
  group('PosterRatio.fromAspect 边界归类', () {
    test('宽幅横图 16:9 / 19:6 / 恰好 1.6 → ratio169', () {
      expect(PosterRatio.fromAspect(16 / 9), PosterRatio.ratio169);
      expect(PosterRatio.fromAspect(19 / 6), PosterRatio.ratio169);
      expect(PosterRatio.fromAspect(2.0), PosterRatio.ratio169);
      expect(PosterRatio.fromAspect(1.6), PosterRatio.ratio169);
    });

    test('4:3 横图 / 恰好 1.15 → ratio43', () {
      expect(PosterRatio.fromAspect(4 / 3), PosterRatio.ratio43);
      expect(PosterRatio.fromAspect(1.2), PosterRatio.ratio43);
      expect(PosterRatio.fromAspect(1.15), PosterRatio.ratio43);
      expect(PosterRatio.fromAspect(1.59), PosterRatio.ratio43);
    });

    test('1:1 方图 / 恰好 0.87 → square', () {
      expect(PosterRatio.fromAspect(1.0), PosterRatio.square);
      expect(PosterRatio.fromAspect(0.9), PosterRatio.square);
      expect(PosterRatio.fromAspect(0.87), PosterRatio.square);
      expect(PosterRatio.fromAspect(1.14), PosterRatio.square);
    });

    test('3:4 竖图 / 恰好 0.65 → ratio34', () {
      expect(PosterRatio.fromAspect(3 / 4), PosterRatio.ratio34);
      expect(PosterRatio.fromAspect(0.7), PosterRatio.ratio34);
      expect(PosterRatio.fromAspect(0.65), PosterRatio.ratio34);
      expect(PosterRatio.fromAspect(0.86), PosterRatio.ratio34);
    });

    test('9:16 全屏竖图 → fullScreen', () {
      expect(PosterRatio.fromAspect(9 / 16), PosterRatio.fullScreen);
      expect(PosterRatio.fromAspect(0.5), PosterRatio.fullScreen);
      expect(PosterRatio.fromAspect(0.6499), PosterRatio.fullScreen);
    });
  });

  group('PosterRatio.fromSize', () {
    test('按像素宽高比归类', () {
      expect(PosterRatio.fromSize(1080, 1920), PosterRatio.fullScreen);
      expect(PosterRatio.fromSize(900, 1200), PosterRatio.ratio34);
      expect(PosterRatio.fromSize(1200, 1200), PosterRatio.square);
      expect(PosterRatio.fromSize(1600, 1200), PosterRatio.ratio43);
      expect(PosterRatio.fromSize(1920, 1080), PosterRatio.ratio169);
    });

    test('非法尺寸回退 fullScreen', () {
      expect(PosterRatio.fromSize(0, 0), PosterRatio.fullScreen);
      expect(PosterRatio.fromSize(-1, 100), PosterRatio.fullScreen);
      expect(PosterRatio.fromSize(100, 0), PosterRatio.fullScreen);
    });
  });
}
