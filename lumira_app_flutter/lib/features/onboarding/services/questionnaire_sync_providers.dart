import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/network/api_client.dart';
import 'questionnaire_sync_service.dart';

final questionnaireSyncServiceProvider =
    FutureProvider<QuestionnaireSyncService>((ref) async {
  final dao = await ref.watch(questionnaireDaoProvider.future);
  final apiClient = await ref.watch(apiClientProvider.future);
  return QuestionnaireSyncService(dao: dao, apiClient: apiClient);
});
