import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// GET /sign-in/status 响应体
@immutable
class SignInStatus {
  final bool signedToday;
  final int consecutiveDays;
  final String? lastSignInDate;

  const SignInStatus({
    required this.signedToday,
    required this.consecutiveDays,
    this.lastSignInDate,
  });

  factory SignInStatus.fromJson(Map<String, dynamic> j) => SignInStatus(
        signedToday: j['signedToday'] as bool? ?? false,
        consecutiveDays: (j['consecutiveDays'] as num?)?.toInt() ?? 0,
        lastSignInDate: j['lastSignInDate'] as String?,
      );
}

/// POST /sign-in 响应体
@immutable
class SignInResult {
  final bool success;
  final int dayIndex;
  final int pointsEarned;
  final int balance;

  const SignInResult({
    required this.success,
    required this.dayIndex,
    required this.pointsEarned,
    required this.balance,
  });

  factory SignInResult.fromJson(Map<String, dynamic> j) => SignInResult(
        success: j['success'] as bool? ?? false,
        dayIndex: (j['dayIndex'] as num?)?.toInt() ?? 0,
        pointsEarned: (j['pointsEarned'] as num?)?.toInt() ?? 0,
        balance: (j['balance'] as num?)?.toInt() ?? 0,
      );
}

/// 签到 Repository
abstract class SignInRepository {
  /// GET /sign-in/status
  Future<SignInStatus> getStatus();

  /// POST /sign-in
  Future<SignInResult> signIn();
}

class RemoteSignInRepository implements SignInRepository {
  final ApiClient _api;

  RemoteSignInRepository(this._api);

  @override
  Future<SignInStatus> getStatus() {
    return _api.get(
      '/sign-in/status',
      fromJson: (j) => SignInStatus.fromJson(j as Map<String, dynamic>),
    );
  }

  @override
  Future<SignInResult> signIn() {
    return _api.post(
      '/sign-in',
      fromJson: (j) => SignInResult.fromJson(j as Map<String, dynamic>),
    );
  }
}

final signInRepositoryProvider = FutureProvider<SignInRepository>((ref) async {
  final api = await ref.watch(apiClientProvider.future);
  return RemoteSignInRepository(api);
});
