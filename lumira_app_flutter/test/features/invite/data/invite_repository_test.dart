import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/db/dao/api_cache_dao.dart';
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
}

class _FakeCacheDao implements ApiCacheDao {
  final Map<String, String> _store = {};

  @override
  Future<String?> load(String key) async => _store[key];
  @override
  Future<void> save(String key, String payload) async => _store[key] = payload;
  @override
  Future<void> clear(String key) async => _store.remove(key);
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

  group('RemoteInviteRepository.getStats offline fallback', () {
    test('returns cached stats on network error', () async {
      final api = _FakeApi()
        ..statsError = const ApiException(ApiErrorKind.network, 'timeout');
      final cache = _FakeCacheDao();
      // 预存缓存
      final cachedStats = InviteStats(
        totalInvites: 3,
        currentTier: 1,
        nextTier: null,
        unlockedRewards: [],
      );
      await cache.save('invite_stats', jsonEncode(cachedStats.toJson()));

      final repo = RemoteInviteRepository(
        api: api,
        cache: cache,
      );
      final result = await repo.getStats();
      expect(result.totalInvites, 3);
      expect(api.statsCallCount, 1);
    });

    test('rethrows non-network errors', () async {
      final api = _FakeApi()
        ..statsError = const ApiException(ApiErrorKind.server, '500');
      final cache = _FakeCacheDao();

      final repo = RemoteInviteRepository(
        api: api,
        cache: cache,
      );
      expect(
        () => repo.getStats(),
        throwsA(isA<ApiException>()),
      );
    });

    test('rethrows when no cache available', () async {
      final api = _FakeApi()
        ..statsError = const ApiException(ApiErrorKind.network, 'timeout');
      final cache = _FakeCacheDao();

      final repo = RemoteInviteRepository(
        api: api,
        cache: cache,
      );
      expect(
        () => repo.getStats(),
        throwsA(isA<ApiException>()),
      );
    });

    test('saves cache on successful call', () async {
      final api = _FakeApi()
        ..statsResponse = InviteStats(
          totalInvites: 7,
          currentTier: 2,
          nextTier: null,
          unlockedRewards: [],
        );
      final cache = _FakeCacheDao();

      final repo = RemoteInviteRepository(
        api: api,
        cache: cache,
      );
      await repo.getStats();
      final cached = await cache.load('invite_stats');
      expect(cached, isNotNull);
      final decoded = jsonDecode(cached!) as Map<String, dynamic>;
      expect(decoded['totalInvites'], 7);
    });
  });
}
