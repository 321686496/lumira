import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import 'questionnaire_answers.dart';

export 'questionnaire_answers.dart';
export 'questionnaire_data.dart';

/// 问卷答案 Provider（读取本地最新答案）
final questionnaireAnswersProvider =
    FutureProvider<QuestionnaireAnswers?>((ref) async {
  final dao = await ref.watch(questionnaireDaoProvider.future);
  return dao.getAnswers();
});

/// 是否已填过问卷
final questionnaireCompletedProvider = FutureProvider<bool>((ref) async {
  final dao = await ref.watch(questionnaireDaoProvider.future);
  return dao.isCompleted();
});
