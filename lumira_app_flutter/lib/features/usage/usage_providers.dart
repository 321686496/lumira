// lumira_app_flutter/lib/features/usage/usage_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import 'usage_event_recorder.dart';

final usageEventRecorderProvider = FutureProvider<UsageEventRecorder>((ref) async {
  final dao = await ref.watch(usageDaoProvider.future);
  return UsageEventRecorder(dao);
});