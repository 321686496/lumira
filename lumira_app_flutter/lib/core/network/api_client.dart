import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../config/app_config.dart';
import 'api_error.dart';
import 'auth_interceptor.dart';

/// API 客户端
///
/// 包装 Dio，统一 baseUrl / 超时 / 鉴权拦截器
/// 所有方法返回 Future<T>，失败抛 ApiException
class ApiClient {
  final Dio _dio;

  ApiClient._(this._dio);

  static Future<ApiClient> create(AuthController auth) async {
    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: Duration(milliseconds: AppConfig.connectTimeoutMs),
      receiveTimeout: Duration(milliseconds: AppConfig.receiveTimeoutMs),
      headers: {'Content-Type': 'application/json'},
    ));
    dio.interceptors.add(AuthInterceptor(auth));
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(responseBody: false, requestBody: false));
    }
    return ApiClient._(dio);
  }

  /// GET 请求
  ///
  /// [path] 相对路径，如 '/invite/stats'
  /// [fromJson] 将 response.data 转为目标类型
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(Object? json) fromJson,
  }) async {
    try {
      final resp = await _dio.get(path, queryParameters: query);
      return fromJson(resp.data);
    } on DioError catch (e) {
      throw classifyDioError(e);
    }
  }

  /// POST 请求
  Future<T> post<T>(
    String path, {
    Object? body,
    required T Function(Object? json) fromJson,
  }) async {
    try {
      final resp = await _dio.post(path, data: body);
      return fromJson(resp.data);
    } on DioError catch (e) {
      throw classifyDioError(e);
    }
  }

  /// PATCH 请求
  Future<T?> patch<T>(
    String path, {
    Object? body,
    required T Function(Object? json) fromJson,
  }) async {
    try {
      final resp = await _dio.patch(path, data: body);
      return fromJson(resp.data);
    } on DioError catch (e) {
      throw classifyDioError(e);
    }
  }
}

/// 全局 ApiClient Provider
///
/// 注意：依赖 authControllerProvider（Task 3），故为 FutureProvider
final apiClientProvider = FutureProvider<ApiClient>((ref) async {
  final auth = ref.watch(authControllerProvider.notifier);
  return ApiClient.create(auth);
});
