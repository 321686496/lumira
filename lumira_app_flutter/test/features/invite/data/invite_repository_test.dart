import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/network/api_client.dart';
import 'package:lumira_app_flutter/core/network/api_error.dart';
import 'package:lumira_app_flutter/features/invite/data/invite_models.dart';
import 'package:lumira_app_flutter/features/invite/data/invite_repository.dart';
import 'package:lumira_app_flutter/features/rewards/data/rewards_models.dart';

class _FakeApi implements ApiClient {
  InviteStats? statsResponse;
  dynamic statsError;
  int statsCallCount = 0;

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(Object? json) fromJson,
  }) async {
    if (path == '/invite/stats') {
      statsCallCount++;
      if (statsError != null) throw statsError;
      if (statsResponse != null) return fromJson(statsResponse!.toJson()) as T;
    }
    throw UnimplementedError('GET $path');
  }

  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    required T Function(Object? json) fromJson,
  }) async {
    throw UnimplementedError('POST $path');
  }

  @override
  Future<T?> patch<T>(
    String path, {
    Object? body,
    required T Function(Object? json) fromJson,
  }) async {
    throw UnimplementedError('PATCH $path');
  }

  @override
  Future<T> multipartPost<T>(
    String path, {
    required Map<String, String> fields,
    required List<MultipartFile> files,
    String fileField = 'screenshots',
    required T Function(Object? json) fromJson,
  }) async {
    throw UnimplementedError('MULTIPART $path');
  }
}

void main() {
  group('InviteChannelExt', () {
    test('toJson returns snake_case', () {
      expect(InviteChannel.direct.toJson(), 'direct');
      expect(InviteChannel.shareCard.toJson(), 'share_card');
      expect(InviteChannel.qrcode.toJson(), 'qrcode');
    });

    test('fromJson parses correctly', () {
      expect(InviteChannelExt.fromJson('direct'), InviteChannel.direct);
      expect(InviteChannelExt.fromJson('share_card'), InviteChannel.shareCard);
      expect(InviteChannelExt.fromJson('qrcode'), InviteChannel.qrcode);
      expect(InviteChannelExt.fromJson(null), isNull);
      expect(InviteChannelExt.fromJson('unknown'), isNull);
    });
  });

  group('ActivateInviteRequest', () {
    test('toJson omits null channel', () {
      const req = ActivateInviteRequest(inviteCode: 'ABC');
      expect(req.toJson(), {'inviteCode': 'ABC'});
    });

    test('toJson includes channel when set', () {
      const req = ActivateInviteRequest(
        inviteCode: 'ABC',
        channel: InviteChannel.qrcode,
      );
      expect(req.toJson(), {'inviteCode': 'ABC', 'channel': 'qrcode'});
    });
  });

  group('InviteStats parsing', () {
    test('parses full response', () {
      final stats = InviteStats.fromJson({
        'totalInvites': 5,
        'currentTier': 2,
        'nextTier': {
          'tier': 3,
          'requiredInvites': 10,
          'rewards': [
            {'type': 'template', 'id': 'tpl-1', 'label': 'Template 1'}
          ],
        },
        'unlockedRewards': [
          {
            'id': 1,
            'tier': 1,
            'source': 'invite',
            'sourceDetail': null,
            'status': 'unlocked',
            'rewardItems': [
              {'type': 'template', 'id': 'tpl-0', 'label': 'Template 0'}
            ],
            'unlockedAt': 1700000000,
            'claimedAt': null,
          }
        ],
      });
      expect(stats.totalInvites, 5);
      expect(stats.currentTier, 2);
      expect(stats.nextTier?.tier, 3);
      expect(stats.nextTier?.rewards.length, 1);
      expect(stats.unlockedRewards.length, 1);
      expect(stats.unlockedRewards.first.id, 1);
      expect(stats.unlockedRewards.first.status, UnlockStatus.unlocked);
    });
  });

  group('RemoteInviteRepository.stats', () {
    test('rethrows non-network errors', () async {
      final api = _FakeApi()
        ..statsError = const ApiException(ApiErrorKind.server, '500');

      final repo = RemoteInviteRepository(api);
      expect(
        () => repo.stats(),
        throwsA(isA<ApiException>()),
      );
    });

    test('rethrows network errors', () async {
      final api = _FakeApi()
        ..statsError = const ApiException(ApiErrorKind.network, 'timeout');

      final repo = RemoteInviteRepository(api);
      expect(
        () => repo.stats(),
        throwsA(isA<ApiException>()),
      );
    });

    test('returns stats on successful call', () async {
      final api = _FakeApi()
        ..statsResponse = InviteStats(
          totalInvites: 7,
          currentTier: 2,
          nextTier: null,
          unlockedRewards: [],
        );

      final repo = RemoteInviteRepository(api);
      final result = await repo.stats();
      expect(result.totalInvites, 7);
      expect(api.statsCallCount, 1);
    });
  });
}
