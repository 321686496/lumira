import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/onboarding/data/questionnaire_answers.dart';

void main() {
  test('gender serialization round-trip', () {
    const ans = QuestionnaireAnswers(
      gender: 'female',
      favoriteCategories: ['portrait'],
      painPoints: [],
      skillLevel: 'beginner',
      expectations: [],
      commonScenes: [],
      shootFrequency: null,
    );
    expect(ans.toJson()['gender'], 'female');
    final restored = QuestionnaireAnswers.fromJson(ans.toJson());
    expect(restored.gender, 'female');
  });

  test('isAllSkipped true only when gender also null', () {
    expect(QuestionnaireAnswers.empty().isAllSkipped, isTrue);
    const withGender = QuestionnaireAnswers(
      gender: 'male',
      favoriteCategories: [],
      painPoints: [],
      expectations: [],
      commonScenes: [],
    );
    expect(withGender.isAllSkipped, isFalse);
  });
}