import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/network/api_client.dart';
import 'package:lumira_app_flutter/features/redeem/data/redeem_models.dart';
import 'package:lumira_app_flutter/features/redeem/data/redeem_repository.dart';

class _FakeApi implements ApiClient {
  final Map<String, dynamic> _redeemResponse;

  _FakeApi(this._redeemResponse);

  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    required T Function(Object? json) fromJson,
  }) async {
    expect(path, '/redeem');
    final bodyMap = body as Map<String, dynamic>;
    expect(bodyMap['code'], 'ABC123');
    return fromJson(_redeemResponse) as T;
  }

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(Object? json) fromJson,
  }) async {
    throw UnimplementedError('GET $path');
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

void main() {
  group('RedeemCodeRequest', () {
    test('toJson wraps code', () {
      const req = RedeemCodeRequest(code: 'XYZ');
      expect(req.toJson(), {'code': 'XYZ'});
    });
  });

  group('RedeemCodeResponse.fromJson', () {
    test('parses correctly', () {
      final resp = RedeemCodeResponse.fromJson({
        'batchId': 42,
        'campaignName': 'Spring Campaign',
        'rewardPoints': 100,
        'balance': 150,
      });
      expect(resp.batchId, 42);
      expect(resp.campaignName, 'Spring Campaign');
      expect(resp.rewardPoints, 100);
      expect(resp.balance, 150);
    });
  });

  group('RemoteRedeemRepository', () {
    test('redeem sends request and parses response', () async {
      final fakeApi = _FakeApi({
        'batchId': 1,
        'campaignName': 'Test',
        'rewardPoints': 50,
        'balance': 50,
      });
      final repo = RemoteRedeemRepository(fakeApi);
      final resp = await repo.redeem(const RedeemCodeRequest(code: 'ABC123'));
      expect(resp.batchId, 1);
      expect(resp.campaignName, 'Test');
      expect(resp.rewardPoints, 50);
      expect(resp.balance, 50);
    });
  });
}
