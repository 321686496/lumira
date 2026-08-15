import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/features/inspiration/data/tutorial_models.dart';

void main() {
  test('ShootingTutorial 构建与字段访问', () {
    const t = ShootingTutorial(
      id: 'tut_general_premium',
      title: '如何拍出高级感',
      subtitle: '留白与克制',
      coverImage: 'assets/images/tutorials/cover_tut_general_premium.png',
      category: 'general',
      readMinutes: '3分钟',
      tags: ['高级感', '留白'],
      intro: '高级感不是滤镜，是减法。',
      steps: [
        TutorialStep(title: '第一步', body: '减少画面元素', imageAsset: null),
      ],
      tips: ['少即是多'],
      cta: TutorialCta(type: TutorialCtaType.scene, targetId: 'cafe-window'),
      academyCourseId: 'course_13',
    );
    expect(t.id, 'tut_general_premium');
    expect(t.cta.type, TutorialCtaType.scene);
    expect(t.steps.first.title, '第一步');
    expect(t.academyCourseId, 'course_13');
  });
}