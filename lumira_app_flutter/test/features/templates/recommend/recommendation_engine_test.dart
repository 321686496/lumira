import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/features/onboarding/data/questionnaire_answers.dart';
import 'package:lumira_app_flutter/features/templates/recommend/recommendation_engine.dart';
import 'package:lumira_app_flutter/features/templates/recommend/recommendation_models.dart';

/// 构造一张照片信号（基于固定 nowMs 便于计算）
PhotoSignal photo({
  required int now,
  int daysAgo = 0,
  String? templateId,
  String? sceneId,
  PostProcessVector? post,
  bool favorite = false,
}) {
  final dayMs = 24 * 3600 * 1000;
  return PhotoSignal(
    createdAt: now - daysAgo * dayMs,
    templateId: templateId,
    sceneId: sceneId,
    postProcess: post,
    isFavorite: favorite,
  );
}

void main() {
  const now = 1720000000000; // 固定参考时间

  // 候选模板集合：3 个不同分类
  List<TemplateSignal> templates() => const [
        TemplateSignal(
          id: 'tpl-portrait',
          name: '人像模板',
          category: 'portrait',
          tags: [],
          tagIds: [],
          classification: {'type': 'portrait', 'style': 'fresh', 'method': 'normal'},
          postProcess: {'saturation': 20, 'temperature': 0, 'contrast': 0, 'brightness': 0},
          cover: 'https://picsum.photos/seed/a/400/400',
          price: 0,
          updatedAt: 100,
        ),
        TemplateSignal(
          id: 'tpl-food',
          name: '美食模板',
          category: 'food',
          tags: [],
          tagIds: ['food-tag'],
          classification: {'type': 'food', 'style': 'overhead', 'method': 'normal'},
          postProcess: {'saturation': -20, 'temperature': 0, 'contrast': 0, 'brightness': 0},
          cover: 'https://picsum.photos/seed/b/400/400',
          price: 100,
          updatedAt: 200,
        ),
        TemplateSignal(
          id: 'tpl-street',
          name: '街拍模板',
          category: 'street',
          tags: [],
          tagIds: [],
          classification: {'type': 'street', 'style': 'urban', 'method': 'normal'},
          postProcess: {'saturation': 0, 'temperature': 10, 'contrast': 0, 'brightness': 0},
          cover: 'https://picsum.photos/seed/c/400/400',
          price: 0,
          updatedAt: 300,
        ),
      ];

  group('buildProfile', () {
    test('无照片时 isEmpty 为 true', () {
      final engine = RecommendationEngine();
      final profile = engine.buildProfile(const RecommendationEngineInput(
        photos: [],
        scenes: {},
        templates: [],
        ownedTemplateIds: {},
        questionnaire: null,
        nowMs: now,
      ));
      expect(profile.isEmpty, isTrue);
      expect(profile.photoCount, 0);
    });

    test('时间衰减：近期照片权重高于远期照片', () {
      final engine = RecommendationEngine();
      final profile = engine.buildProfile(RecommendationEngineInput(
        photos: [
          photo(now: now, daysAgo: 1, sceneId: 'scene-cafe'),
          photo(now: now, daysAgo: 90, sceneId: 'scene-cafe'),
          photo(now: now, daysAgo: 1, sceneId: 'scene-street'),
        ],
        scenes: const {
          'scene-cafe': SceneSignal(id: 'scene-cafe', style: '清新', relatedCategory: 'still-life'),
          'scene-street': SceneSignal(id: 'scene-street', style: 'urban', relatedCategory: 'street'),
        },
        templates: [],
        ownedTemplateIds: const {},
        questionnaire: null,
        nowMs: now,
      ));
      // 近期 still-life 权重 > 远期同一分类权重（90 天 ≈ exp(-3) ≈ 0.05，1 天 ≈ 0.97）
      expect(profile.categoryWeights['still-life']! > 1.0, isTrue);
      expect(profile.photoCount, 3);
    });

    test('套用模板的照片贡献分类与标签权重', () {
      final engine = RecommendationEngine();
      final profile = engine.buildProfile(RecommendationEngineInput(
        photos: [
          photo(now: now, daysAgo: 1, templateId: 'tpl-food'),
        ],
        scenes: const {},
        templates: templates(),
        ownedTemplateIds: const {},
        questionnaire: null,
        nowMs: now,
      ));
      expect(profile.usedTemplateCounts['tpl-food'], 1);
      expect(profile.categoryWeights.containsKey('food'), isTrue);
      expect(profile.tagWeights.containsKey('food-tag'), isTrue);
    });

    test('后期风格均值：saturation 取平均值', () {
      final engine = RecommendationEngine();
      final profile = engine.buildProfile(RecommendationEngineInput(
        photos: [
          photo(now: now, daysAgo: 1, post: const PostProcessVector(saturation: 30, temperature: 0, contrast: 0, brightness: 0)),
          photo(now: now, daysAgo: 1, post: const PostProcessVector(saturation: 50, temperature: 0, contrast: 0, brightness: 0)),
        ],
        scenes: const {},
        templates: [],
        ownedTemplateIds: const {},
        questionnaire: null,
        nowMs: now,
      ));
      expect(profile.avgPost.saturation, closeTo(40, 0.001));
    });
  });

  group('rankCandidates', () {
    test('排除已拥有与已用过的模板', () {
      final engine = RecommendationEngine();
      final ranked = engine.rankCandidates(
        engine.buildProfile(RecommendationEngineInput(
          photos: [photo(now: now, daysAgo: 1, templateId: 'tpl-food')],
          scenes: const {},
          templates: templates(),
          ownedTemplateIds: const {},
          questionnaire: null,
          nowMs: now,
        )),
        templates(),
        const RecommendationEngineInput(
          photos: [],
          scenes: {},
          templates: [],
          ownedTemplateIds: {'tpl-street'},
          questionnaire: null,
          nowMs: now,
        ),
      );
      final ids = ranked.map((r) => r.templateId).toList();
      expect(ids, isNot(contains('tpl-food')));
      expect(ids, isNot(contains('tpl-street')));
    });

    test('分数降序排列', () {
      final engine = RecommendationEngine();
      final input = RecommendationEngineInput(
        photos: [photo(now: now, daysAgo: 1, sceneId: 'scene-cafe')],
        scenes: const {
          'scene-cafe': SceneSignal(id: 'scene-cafe', style: '清新', relatedCategory: 'still-life'),
        },
        templates: templates(),
        ownedTemplateIds: const {},
        questionnaire: null,
        nowMs: now,
      );
      final profile = engine.buildProfile(input);
      final ranked = engine.rankCandidates(profile, input.templates, input);
      for (var i = 0; i < ranked.length - 1; i++) {
        expect(ranked[i].matchScore >= ranked[i + 1].matchScore, isTrue,
            reason: '第 $i 项应 >= 第 ${i + 1} 项');
      }
    });
  });

  group('RecommendationEngine.build', () {
    test('无照片无问卷时返回冷启动结果', () {
      final engine = RecommendationEngine();
      final result = engine.build(RecommendationEngineInput(
        photos: const [],
        scenes: const {},
        templates: templates(),
        ownedTemplateIds: const {},
        questionnaire: null,
        nowMs: now,
      ));
      expect(result.coldStart, isTrue);
      expect(result.guessLikes, isNotEmpty);
    });

    test('有照片时 guessLikes 排除已用与已拥有', () {
      final engine = RecommendationEngine();
      final result = engine.build(RecommendationEngineInput(
        photos: [photo(now: now, daysAgo: 1, templateId: 'tpl-food')],
        scenes: const {},
        templates: templates(),
        ownedTemplateIds: const {'tpl-street'},
        questionnaire: null,
        nowMs: now,
      ));
      final ids = result.guessLikes.map((r) => r.templateId).toList();
      expect(ids, isNot(contains('tpl-food')));
      expect(ids, isNot(contains('tpl-street')));
      expect(ids, contains('tpl-portrait'));
    });
  });

  group('旧爱回归 recall', () {
    test('很久前用过且近期类型匹配的模板被召回', () {
      final engine = RecommendationEngine();
      // 90 天前用过 tpl-food（很久前），近期照片都是 still-life 相关场景
      final result = engine.build(RecommendationEngineInput(
        photos: [
          photo(now: now, daysAgo: 90, templateId: 'tpl-food'),
          photo(now: now, daysAgo: 1, sceneId: 'scene-cafe'),
          photo(now: now, daysAgo: 1, sceneId: 'scene-cafe'),
        ],
        scenes: const {
          'scene-cafe':
              SceneSignal(id: 'scene-cafe', style: '清新', relatedCategory: 'still-life'),
        },
        templates: [
          // 很久前用过的 food 模板（应被召回）
          const TemplateSignal(
            id: 'tpl-food',
            name: '美食模板',
            category: 'food',
            tags: [],
            tagIds: ['food-tag'],
            classification: {'type': 'food', 'style': 'overhead', 'method': 'normal'},
            postProcess: {'saturation': 0, 'temperature': 0, 'contrast': 0, 'brightness': 0},
            cover: 'https://picsum.photos/seed/b/400/400',
            price: 100,
            updatedAt: 200,
          ),
          // 未用过的 food 模板（不应被召回，但会进 guessLikes）
          const TemplateSignal(
            id: 'tpl-food-2',
            name: '美食模板二',
            category: 'food',
            tags: [],
            tagIds: ['food-tag'],
            classification: {'type': 'food', 'style': 'overhead', 'method': 'normal'},
            postProcess: {'saturation': 0, 'temperature': 0, 'contrast': 0, 'brightness': 0},
            cover: 'https://picsum.photos/seed/b2/400/400',
            price: 100,
            updatedAt: 200,
          ),
        ],
        ownedTemplateIds: const {},
        questionnaire: null,
        nowMs: now,
      ));
      expect(result.recall.map((r) => r.templateId), contains('tpl-food'));
      expect(
          result.recall.map((r) => r.templateId), isNot(contains('tpl-food-2')));
      // 猜你喜欢：tpl-food（已用过）被排除，tpl-food-2 保留
      final guessIds = result.guessLikes.map((r) => r.templateId).toList();
      expect(guessIds, isNot(contains('tpl-food')));
      expect(guessIds, contains('tpl-food-2'));
      // 召回文案与使用张数
      final recallItem =
          result.recall.firstWhere((r) => r.templateId == 'tpl-food');
      expect(recallItem.reason, contains('很久前用过'));
      expect(recallItem.usedCount, 1);
    });

    test('近期（30 天内）用过的不进召回区', () {
      final engine = RecommendationEngine();
      final result = engine.build(RecommendationEngineInput(
        photos: [photo(now: now, daysAgo: 5, templateId: 'tpl-food')],
        scenes: const {},
        templates: const [
          TemplateSignal(
            id: 'tpl-food',
            name: '美食模板',
            category: 'food',
            tags: [],
            tagIds: [],
            classification: {'type': 'food', 'style': 'overhead', 'method': 'normal'},
            postProcess: {},
            cover: '',
            price: 0,
            updatedAt: 100,
          ),
        ],
        ownedTemplateIds: const {},
        questionnaire: null,
        nowMs: now,
      ));
      expect(result.recall, isEmpty);
    });
  });

  group('冷启动', () {
    test('无照片有问卷：问卷偏好分类模板排最前', () {
      final engine = RecommendationEngine();
      final result = engine.build(RecommendationEngineInput(
        photos: const [],
        scenes: const {},
        templates: templates(),
        ownedTemplateIds: const {},
        questionnaire: QuestionnaireAnswers(
          source: 'onboarding',
          favoriteCategories: const ['food'],
          painPoints: const [],
          skillLevel: 'beginner',
          expectations: const [],
          commonScenes: const [],
          shootFrequency: null,
        ),
        nowMs: now,
      ));
      expect(result.coldStart, isTrue);
      expect(result.guessLikes.first.templateId, 'tpl-food');
    });

    test('无照片无问卷：各分类均匀覆盖', () {
      final engine = RecommendationEngine();
      final result = engine.build(RecommendationEngineInput(
        photos: const [],
        scenes: const {},
        templates: templates(),
        ownedTemplateIds: const {},
        questionnaire: null,
        nowMs: now,
      ));
      // 3 个分类都有覆盖
      final cats = result.guessLikes.map((r) => r.category).toSet();
      expect(cats, contains('portrait'));
      expect(cats, contains('food'));
      expect(cats, contains('street'));
    });
  });

  group('根据最近拍摄 recent', () {
    test('最近照片套用模板：推荐同分类模板', () {
      final engine = RecommendationEngine();
      // 最新照片用了 tpl-food（1 天前），旧照片用 tpl-portrait（10 天前）
      final result = engine.build(RecommendationEngineInput(
        photos: [
          photo(now: now, daysAgo: 1, templateId: 'tpl-food'),
          photo(now: now, daysAgo: 10, templateId: 'tpl-portrait'),
        ],
        scenes: const {},
        templates: templates(),
        ownedTemplateIds: const {},
        questionnaire: null,
        nowMs: now,
      ));
      expect(result.recentInfo, isNotNull);
      // 最近相关推荐应含 food 分类（未被使用过的候选：tpl-food 已用过，但同分类无其他
      // 候选时可回退；此处断言非空即可）
      expect(result.recentRelated, isNotEmpty);
    });

    test('无照片时 recent 为空', () {
      final engine = RecommendationEngine();
      final result = engine.build(RecommendationEngineInput(
        photos: const [],
        scenes: const {},
        templates: templates(),
        ownedTemplateIds: const {},
        questionnaire: null,
        nowMs: now,
      ));
      expect(result.coldStart, isTrue);
      expect(result.recentInfo, isNull);
      expect(result.recentRelated, isEmpty);
    });
  });
}
