import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../data/questionnaire_answers.dart';
import '../data/questionnaire_dao.dart';

/// 问卷提交结果
class SubmitResult {
  final bool success;
  final String? error;
  const SubmitResult({required this.success, this.error});
}

/// 问卷同步服务
///
/// 离线优先：先落本地 sqflite，再上报后端；网络失败不阻塞，标记未同步。
class QuestionnaireSyncService {
  QuestionnaireSyncService({
    required QuestionnaireDao dao,
    required ApiClient apiClient,
  })  : _dao = dao,
        _apiClient = apiClient;

  final QuestionnaireDao _dao;
  final ApiClient _apiClient;

  /// 提交问卷答案
  ///
  /// 1. 本地落库（立即生效，推荐可用）
  /// 2. 上报后端（失败不阻塞，标记未同步）
  Future<SubmitResult> submit(QuestionnaireAnswers answers) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // 1. 本地落库
    await _dao.upsert(answers, now);

    // 2. 上报后端
    try {
      await _apiClient.post(
        '/questionnaire/submit',
        body: {
          'answers': answers.toJson(),
          'submittedAt': now,
        },
        fromJson: (json) => json,
      );
      await _dao.markSynced(now);
      return const SubmitResult(success: true);
    } on ApiException catch (e) {
      return SubmitResult(success: false, error: e.message);
    } catch (e) {
      return SubmitResult(success: false, error: e.toString());
    }
  }

  /// 补传未同步的提交（App 启动时调用）
  ///
  /// 最小实现：只重试一次，失败则等下次启动。
  Future<void> syncPendingIfNeeded() async {
    final hasUnsynced = await _dao.hasUnsynced();
    if (!hasUnsynced) return;

    final answers = await _dao.getAnswers();
    if (answers == null) return;

    try {
      await _apiClient.post(
        '/questionnaire/submit',
        body: {
          'answers': answers.toJson(),
          'submittedAt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        },
        fromJson: (json) => json,
      );
      await _dao.markSynced(DateTime.now().millisecondsSinceEpoch ~/ 1000);
    } catch (_) {
      // 静默失败，下次启动再试
    }
  }
}
