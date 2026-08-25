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
      connectTimeout: AppConfig.connectTimeoutMs,
      receiveTimeout: AppConfig.receiveTimeoutMs,
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

  /// multipart POST（文本字段 + 文件，用于意见反馈截图上传）
  Future<T> multipartPost<T>(
    String path, {
    required Map<String, String> fields,
    required List<MultipartFile> files,
    String fileField = 'screenshots',
    required T Function(Object? json) fromJson,
  }) async {
    try {
      final form = FormData();
      fields.forEach((key, value) {
        form.fields.add(MapEntry(key, value));
      });
      for (final file in files) {
        form.files.add(MapEntry(fileField, file));
      }
      final resp = await _dio.post(path, data: form);
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

  /// DELETE 请求
  ///
  /// 镜像 [get] / [post]：成功时用 [fromJson] 转换响应，失败抛 [ApiException]。
  Future<T> delete<T>(
    String path, {
    required T Function(Object? json) fromJson,
  }) async {
    try {
      final resp = await _dio.delete(path);
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
