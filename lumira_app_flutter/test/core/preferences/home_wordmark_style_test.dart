import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/preferences/home_wordmark_style.dart';

void main() {
  group('HomeWordmarkStyle', () {
    test('enum has exactly 3 variants in expected order', () {
      expect(HomeWordmarkStyle.values.length, 3);
      expect(HomeWordmarkStyle.values[0], HomeWordmarkStyle.logoEnglish);
      expect(HomeWordmarkStyle.values[1], HomeWordmarkStyle.logoEnglishChinese);
      expect(HomeWordmarkStyle.values[2], HomeWordmarkStyle.englishChinese);
    });

    test('provider defaults to logoEnglish', () {
      final container = ProviderContainer();
      expect(container.read(homeWordmarkStyleProvider), HomeWordmarkStyle.logoEnglish);
      container.dispose();
    });

    test('provider can be updated to other styles', () {
      final container = ProviderContainer();
      container.read(homeWordmarkStyleProvider.notifier).state =
          HomeWordmarkStyle.logoEnglishChinese;
      expect(container.read(homeWordmarkStyleProvider),
          HomeWordmarkStyle.logoEnglishChinese);
      container.dispose();
    });
  });
}
