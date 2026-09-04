import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/features/home/data/inspiration_rules.dart';
import 'package:lumira_app_flutter/features/home/data/template_context_rules.dart';

void main() {
  const ctxSunnyWarmNoon = InspirationContext(
    slot: 'noon', season: '夏季', tempRange: '温暖', weather: '晴');

  group('resolveContextFit', () {
    test('晴天+温暖命中含 portrait/landscape 的规则', () {
      final fit = resolveContextFit(ctxSunnyWarmNoon);
      expect(fit.categories, contains('portrait'));
      expect(fit.categories, contains('landscape'));
    });

    test('夜晚命中夜景/街拍类别', () {
      const c = InspirationContext(slot: 'night', season: '冬季', tempRange: '寒冷');
      final fit = resolveContextFit(c);
      expect(fit.categories, contains('night'));
      expect(fit.categories, contains('street'));
    });
  });

  group('ambienceMatches', () {
    test('空 ambience 不视为匹配', () {
      expect(ambienceMatches(const {}, ctxSunnyWarmNoon), isFalse);
    });

    test('天气命中（晴→sunny）即匹配', () {
      expect(ambienceMatches({'weathers': ['sunny']}, ctxSunnyWarmNoon), isTrue);
    });

    test('天气不匹配则不命中', () {
      expect(ambienceMatches({'weathers': ['rain']}, ctxSunnyWarmNoon), isFalse);
    });

    test('季节不匹配则不命中', () {
      expect(ambienceMatches({'seasons': ['winter']}, ctxSunnyWarmNoon), isFalse);
    });

    test('timeTones 按时段宽松匹配（day 命中 noon）', () {
      expect(ambienceMatches({'timeTones': ['day']}, ctxSunnyWarmNoon), isTrue);
      const night = InspirationContext(slot: 'night', season: '冬季', tempRange: '寒冷');
      expect(ambienceMatches({'timeTones': ['night']}, night), isTrue);
    });
  });

  group('pickRecommendedTemplate', () {
    Candidate _c(String id, {String category = 'portrait', String? style,
        String? subStyle, String? type, int popularity = 0,
        Map<String, dynamic> ambience = const {}}) {
      return Candidate(id: id, name: '模板$id', category: category,
        style: style, subStyle: subStyle, type: type,
        ambience: ambience, popularity: popularity);
    }

    test('候选为空返回 null', () {
      expect(pickRecommendedTemplate(candidates: const [], context: ctxSunnyWarmNoon, preferredCategory: 'portrait'), isNull);
    });

    test('无语境命中（类别/风格/ambience 均不匹配）返回 null', () {
      final cands = [_c('a', category: 'food')];
      expect(pickRecommendedTemplate(candidates: cands, context: ctxSunnyWarmNoon, preferredCategory: 'portrait'), isNull);
    });

    test('语境类别命中时选中（不上偏好类别也选热度高者）', () {
      final cands = [
        _c('a', category: 'landscape', popularity: 1),
        _c('b', category: 'portrait', popularity: 100),
      ];
      final r = pickRecommendedTemplate(candidates: cands, context: ctxSunnyWarmNoon, preferredCategory: 'portrait');
      expect(r!.id, 'b'); // 都命中语境，portrait 且两者都匹配用户类别 → 热度高者
    });

    test('ambience 命中优先于规则命中', () {
      final cands = [
        _c('a', category: 'portrait', popularity: 999), // 规则命中（人像）+高热度
        _c('b', category: 'landscape', popularity: 1, ambience: {'weathers': ['sunny']}), // ambience 命中
      ];
      final r = pickRecommendedTemplate(candidates: cands, context: ctxSunnyWarmNoon, preferredCategory: 'portrait');
      expect(r!.id, 'b'); // ambience 最高优先
    });

    test('无条件命中时选择热度最高者', () {
      final cands = [
        _c('a', category: 'portrait', popularity: 50),
        _c('b', category: 'portrait', popularity: 2000),
      ];
      final r = pickRecommendedTemplate(candidates: cands, context: ctxSunnyWarmNoon, preferredCategory: 'portrait');
      expect(r!.id, 'b');
    });

    test('无 diversity 种子时保持确定性（取热度最高者）', () {
      final cands = [
        _c('a', category: 'portrait', popularity: 50),
        _c('b', category: 'portrait', popularity: 2000),
        _c('c', category: 'portrait', popularity: 100),
      ];
      final r = pickRecommendedTemplate(candidates: cands, context: ctxSunnyWarmNoon, preferredCategory: 'portrait');
      expect(r!.id, 'b'); // 未传 seed：永远取排序第一
    });

    test('提供 diversity 种子时，在热门候选内变化但不会跳到冷门', () {
      final cands = [
        _c('hot1', category: 'portrait', popularity: 1000),
        _c('hot2', category: 'portrait', popularity: 900),
        _c('hot3', category: 'portrait', popularity: 800),
        _c('cold', category: 'portrait', popularity: 1),
      ];
      // 两个不同日期种子都应命中热门三甲（不会选中 cold）
      for (final seed in [20260903, 20260904, 20260905]) {
        final r = pickRecommendedTemplate(
            candidates: cands, context: ctxSunnyWarmNoon,
            preferredCategory: 'portrait', varietySeed: seed);
        expect(['hot1', 'hot2', 'hot3'], contains(r!.id), reason: 'seed=$seed');
      }
    });
  });
}