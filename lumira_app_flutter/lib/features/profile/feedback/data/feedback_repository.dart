import 'package:dio/dio.dart' show MultipartFile;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import 'feedback_models.dart';

/// 意见反馈 Repository：向 POST /feedback 提交（multipart）
abstract class FeedbackRepository {
  Future<SubmitFeedbackResult> submit(SubmittedFeedback feedback);
}

class FeedbackRepositoryImpl implements FeedbackRepository {
  FeedbackRepositoryImpl(Future<ApiClient> Function() apiClientFactory)
      : _apiClientFactory = apiClientFactory;

  final Future<ApiClient> Function() _apiClientFactory;

  @override
  Future<SubmitFeedbackResult> submit(SubmittedFeedback feedback) async {
    final api = await _apiClientFactory();
    final fields = <String, String>{
      'type': feedback.type,
      'content': feedback.content,
    };
    if (feedback.contact != null && feedback.contact!.trim().isNotEmpty) {
      fields['contact'] = feedback.contact!.trim();
    }
    final files = <MultipartFile>[];
    for (var i = 0; i < feedback.screenshots.length; i++) {
      final name = i < feedback.screenshotNames.length
          ? feedback.screenshotNames[i]
          : 'shot-$i.png';
      files.add(MultipartFile.fromBytes(feedback.screenshots[i], filename: name));
    }
    return api.multipartPost(
      '/feedback',
      fields: fields,
      files: files,
      fileField: 'screenshots',
      fromJson: (j) =>
          SubmitFeedbackResult.fromJson(j as Map<String, dynamic>),
    );
  }
}

/// 全局 Provider：懒加载 apiClient（FutureProvider）
final feedbackRepositoryProvider = Provider<FeedbackRepository>((ref) {
  return FeedbackRepositoryImpl(() => ref.read(apiClientProvider.future));
});