import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/features/academy/data/academy_content.dart';
import 'package:lumira_app_flutter/features/inspiration/data/tutorial_content.dart';
import 'package:lumira_app_flutter/features/inspiration/data/tutorial_models.dart';

void main() {
  const validCategories = {
    'general', 'portrait', 'landscape', 'food', 'street', 'night', 'macro', 'still-life',
  };

  test('id 唯一且命名规范', () {
    final ids = TutorialContent.all.map((t) => t.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'id 必须唯一');
    for (final t in TutorialContent.all) {
      expect(t.id, startsWith('tut_'));
    }
  });

  test('每篇必填字段非空', () {
    for (final t in TutorialContent.all) {
      expect(t.title, isNotEmpty, reason: t.id);
      expect(t.subtitle, isNotEmpty, reason: t.id);
      expect(t.intro, isNotEmpty, reason: t.id);
      expect(t.coverImage, isNotEmpty, reason: t.id);
      expect(t.readMinutes, isNotEmpty, reason: t.id);
      expect(t.steps, isNotEmpty, reason: '${t.id} 至少 1 个步骤');
      expect(t.tips, isNotEmpty, reason: '${t.id} 至少 1 条贴士');
      expect(validCategories.contains(t.category), isTrue, reason: '${t.id} 类别非法');
    }
  });

  test('CTA 目标为已验证 id', () {
    const validScenes = {
      'cafe-window', 'home-cozy', 'sunset-silhouette', 'night-street',
      'library-quiet', 'seaside-beach', 'forest-bamboo', 'rainy-window', 'golden-rim-portrait',
    };
    const validTemplates = {
      'cafe_portrait', 'soft_portrait', 'golden_landscape', 'food_flat_lay',
      'night_cityscape', 'street_bw', 'macro_flower', 'indoor_still_life',
      'sunset_silhouette', 'urban_architecture', 'film_vintage', 'neon_portrait',
      'morandi_minimal_portrait', 'japanese_fresh_portrait', 'cream_healing_portrait',
      'foodie_portrait',
    };
    for (final t in TutorialContent.all) {
      final cta = t.cta;
      if (cta.type == TutorialCtaType.scene) {
        expect(validScenes.contains(cta.targetId), isTrue, reason: '${t.id} 场景 ${cta.targetId} 未验证');
      } else {
        expect(validTemplates.contains(cta.targetId), isTrue, reason: '${t.id} 模板 ${cta.targetId} 未验证');
      }
    }
  });

  test('关联美学院课程必须存在', () {
    for (final t in TutorialContent.all) {
      final id = t.academyCourseId;
      if (id != null) {
        expect(AcademyContent.getCourse(id), isNotNull, reason: '${t.id} 关联课程 $id 不存在');
      }
    }
  });

  test('封面/步骤图 asset 文件真实存在', () {
    for (final t in TutorialContent.all) {
      final cover = File(t.coverImage);
      expect(cover.existsSync(), isTrue,
          reason: '封面 ${t.coverImage} 不存在（请在 Task 8 生成）');
      expect(cover.lengthSync(), greaterThan(0),
          reason: '封面 ${t.coverImage} 为空文件');
      for (final s in t.steps) {
        final img = s.imageAsset;
        if (img == null) continue;
        final f = File(img);
        expect(f.existsSync(), isTrue,
            reason: '步骤图 $img 不存在（请在 Task 8 生成）');
        expect(f.lengthSync(), greaterThan(0), reason: '步骤图 $img 为空文件');
      }
    }
  });

  test('getById 命中与未命中', () {
    expect(TutorialContent.getById('tut_general_premium'), isNotNull);
    expect(TutorialContent.getById('not-exist'), isNull);
  });

  test('各类别均有覆盖', () {
    final cats = TutorialContent.all.map((t) => t.category).toSet();
    for (final c in ['general', 'portrait', 'landscape', 'food', 'street', 'night', 'macro', 'still-life']) {
      expect(cats.contains(c), isTrue, reason: '缺少类别 $c');
    }
  });
}