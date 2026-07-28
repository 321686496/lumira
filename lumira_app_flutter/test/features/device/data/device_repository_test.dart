import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/network/api_client.dart';
import 'package:lumira_app_flutter/features/device/data/device_models.dart';
import 'package:lumira_app_flutter/features/device/data/device_repository.dart';

class _FakeApiClient implements ApiClient {
  final Map<String, dynamic> _registerResponse;

  _FakeApiClient(this._registerResponse);

  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    required T Function(Object? json) fromJson,
  }) async {
    expect(path, '/device/register');
    final bodyMap = body as Map<String, dynamic>;
    expect(bodyMap['deviceId'], 'dev-123');
    expect(bodyMap['os'], 'android');
    return fromJson(_registerResponse) as T;
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
  group('RemoteDeviceRepository', () {
    test('register sends correct request and parses response', () async {
      final fakeApi = _FakeApiClient({
        'token': 'jwt-abc',
        'isNewDevice': true,
      });
      final repo = RemoteDeviceRepository(fakeApi);
      final resp = await repo.register(const RegisterDeviceRequest(
        deviceId: 'dev-123',
        os: DeviceOs.android,
      ));
      expect(resp.token, 'jwt-abc');
      expect(resp.isNewDevice, true);
    });
  });

  group('DeviceOsExt', () {
    test('toJson returns correct string', () {
      expect(DeviceOs.android.toJson(), 'android');
      expect(DeviceOs.ios.toJson(), 'ios');
      expect(DeviceOs.harmonyos.toJson(), 'harmonyos');
    });

    test('fromJson parses correctly', () {
      expect(DeviceOsExt.fromJson('android'), DeviceOs.android);
      expect(DeviceOsExt.fromJson('ios'), DeviceOs.ios);
      expect(DeviceOsExt.fromJson('harmonyos'), DeviceOs.harmonyos);
      expect(DeviceOsExt.fromJson('unknown'), DeviceOs.android); // fallback
    });
  });

  group('RegisterDeviceRequest', () {
    test('toJson includes os string', () {
      const req = RegisterDeviceRequest(
        deviceId: 'dev-1',
        os: DeviceOs.harmonyos,
      );
      final j = req.toJson();
      expect(j['deviceId'], 'dev-1');
      expect(j['os'], 'harmonyos');
    });
  });

  group('RegisterDeviceResponse', () {
    test('fromJson parses correctly', () {
      final resp = RegisterDeviceResponse.fromJson({
        'token': 'jwt-xyz',
        'isNewDevice': false,
      });
      expect(resp.token, 'jwt-xyz');
      expect(resp.isNewDevice, false);
    });
  });
}
