import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/db/dao/api_cache_dao.dart';
import 'package:lumira_app_flutter/core/network/api_client.dart';
import 'package:lumira_app_flutter/core/network/api_error.dart';
import 'package:lumira_app_flutter/features/rewards/data/rewards_models.dart';
import 'package:lumira_app_flutter/features/rewards/data/rewards_repository.dart';

class _FakeApi implements ApiClient {
  RewardsList? listResponse;
  Map<int, ClaimResult>? claimResponses;
  dynamic listError;
  int listCallCount = 0;

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(Object? json) fromJson,
  }) async {
    if (path == '/rewards') {
      listCallCount++;
      if (listError != null) throw listError;
      if (listResponse != null) return fromJson(listResponse!.toJson()) as T;
    }
    throw UnimplementedError('GET $path');
  }

  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    required T Function(Object? json) fromJson,
  }) async {
    if (path.startsWith('/rewards/') && path.endsWith('/claim')) {
      final idStr = path.split('/')[2];
      final id = int.parse(idStr);
      final resp = claimResponses?[id];
      if (resp != null) return fromJson({'success': resp.success}) as T;
    }
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
  group('RewardType / RewardSource / UnlockStatus ext', () {
    test('toJson/fromJson round trip', () {
      expect(RewardTypeExt.fromJson(RewardType.template.toJson()), RewardType.template);
      expect(RewardTypeExt.fromJson(RewardType.templatePack.toJson()), RewardType.templatePack);
      expect(RewardTypeExt.fromJson(RewardType.achievement.toJson()), RewardType.achievement);
      expect(RewardTypeExt.fromJson('unknown'), RewardType.template);

      expect(RewardSourceExt.fromJson(RewardSource.invite.toJson()), RewardSource.invite);
      expect(RewardSourceExt.fromJson(RewardSource.redemption.toJson()), RewardSource.redemption);

      expect(UnlockStatusExt.fromJson(UnlockStatus.unlocked.toJson()), UnlockStatus.unlocked);
      expect(UnlockStatusExt.fromJson(UnlockStatus.claimed.toJson()), UnlockStatus.claimed);
    });
  });

  group('RewardItem / UnlockedReward parsing', () {
    test('parses correctly', () {
      final item = RewardItem.fromJson({
        'type': 'template_pack',
        'id': 'pk-1',
        'label': 'Pack 1',
      });
      expect(item.type, RewardType.templatePack);
      expect(item.id, 'pk-1');

      final unlocked = UnlockedReward.fromJson({
        'id': 5,
        'tier': 2,
        'source': 'redemption',
        'sourceDetail': 'campaign-x',
        'status': 'claimed',
        'rewardItems': [item.toJson()],
        'unlockedAt': 1700000000,
        'claimedAt': 1700000001,
      });
      expect(unlocked.id, 5);
      expect(unlocked.source, RewardSource.redemption);
      expect(unlocked.status, UnlockStatus.claimed);
      expect(unlocked.claimedAt, 1700000001);
      expect(unlocked.rewardItems.length, 1);
    });
  });

  group('RemoteRewardsRepository.list offline fallback', () {
    test('returns cached list on network error', () async {
      final api = _FakeApi()..listError = const ApiException(ApiErrorKind.network, 'timeout');
      final cache = _FakeCacheDao();
      final cachedList = RewardsList(rewards: [
        UnlockedReward(
          id: 1,
          tier: 1,
          source: RewardSource.invite,
          sourceDetail: null,
          status: UnlockStatus.unlocked,
          rewardItems: const [],
          unlockedAt: 1700000000,
          claimedAt: null,
        ),
      ]);
      await cache.save('rewards_list', jsonEncode(cachedList.toJson()));

      final repo = RemoteRewardsRepository(api: api, cache: cache);
      final result = await repo.list();
      expect(result.rewards.length, 1);
      expect(result.rewards.first.id, 1);
      expect(api.listCallCount, 1);
    });

    test('rethrows non-network error', () async {
      final api = _FakeApi()..listError = const ApiException(ApiErrorKind.server, '500');
      final cache = _FakeCacheDao();

      final repo = RemoteRewardsRepository(api: api, cache: cache);
      expect(() => repo.list(), throwsA(isA<ApiException>()));
    });

    test('saves cache on success', () async {
      final api = _FakeApi()
        ..listResponse = RewardsList(rewards: const []);
      final cache = _FakeCacheDao();

      final repo = RemoteRewardsRepository(api: api, cache: cache);
      await repo.list();
      final cached = await cache.load('rewards_list');
      expect(cached, isNotNull);
    });
  });

  group('RemoteRewardsRepository.claim', () {
    test('sends correct path and parses response', () async {
      final api = _FakeApi()
        ..claimResponses = {42: const ClaimResult(success: true)};
      final cache = _FakeCacheDao();

      final repo = RemoteRewardsRepository(api: api, cache: cache);
      final result = await repo.claim(42);
      expect(result.success, true);
    });
  });
}
