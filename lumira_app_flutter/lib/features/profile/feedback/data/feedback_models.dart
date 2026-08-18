import 'dart:typed_data';

class FeedbackType {
  const FeedbackType(this.key, this.label);
  final String key;
  final String label;
}

const feedbackTypes = <FeedbackType>[
  FeedbackType('inconvenience', '使用不便'),
  FeedbackType('bug', '漏洞Bug'),
  FeedbackType('feature', '功能建议'),
  FeedbackType('template', '模板建议'),
  FeedbackType('scene', '场景建议'),
  FeedbackType('other', '其他'),
];

class SubmittedFeedback {
  const SubmittedFeedback({
    required this.type,
    required this.content,
    this.contact,
    this.screenshots = const [],
    this.screenshotNames = const [],
  });

  final String type;
  final String content;
  final String? contact;
  final List<Uint8List> screenshots;
  final List<String> screenshotNames;
}

class SubmitFeedbackResult {
  const SubmitFeedbackResult({
    required this.success,
    required this.id,
    required this.receivedAt,
  });

  final bool success;
  final String id;
  final int receivedAt;

  factory SubmitFeedbackResult.fromJson(Map<String, dynamic> json) {
    return SubmitFeedbackResult(
      success: json['success'] as bool? ?? false,
      id: json['id'] as String? ?? '',
      receivedAt: json['receivedAt'] as int? ?? 0,
    );
  }
}