/// API 错误类型枚举
enum ApiErrorKind {
  /// 断网 / 连接超时 / 接收超时
  network,
  /// 401 未授权 → 触发重新注册
  unauthorized,
  /// 403 禁止访问
  forbidden,
  /// 404 未找到
  notFound,
  /// 409 冲突（如重复签到）
  conflict,
  /// 5xx 服务端错误
  server,
  /// 其他未知错误
  unknown,
}

/// API 异常
///
/// 包装 Dio 错误为业务可识别的枚举类型
class ApiException implements Exception {
  final ApiErrorKind kind;
  final int? statusCode;
  final String message;
  final dynamic original;

  const ApiException(
    this.kind,
    this.message, {
    this.statusCode,
    this.original,
  });

  /// 网络错误（断网/超时）→ Repository 层可回退缓存
  bool get isNetworkError => kind == ApiErrorKind.network;

  /// 401 未授权 → AuthController 应清除本地 token
  bool get isUnauthorized => kind == ApiErrorKind.unauthorized;

  @override
  String toString() => 'ApiException($kind, $statusCode): $message';
}

/// 将 Dio 异常映射为 ApiException
///
/// 注意：调用方需传入 dio 4.0.6 的 DioError 类型
/// 此处使用 dynamic 以避免循环依赖（network 层不直接 import dio）
ApiException classifyDioError(dynamic err) {
  // 通过反射访问 err.type 和 err.response
  // dio 4.0.6 DioErrorType 枚举值：connectTimeout / sendTimeout / receiveTimeout / response / cancel / other
  final type = err.type;
  final typeStr = type?.toString() ?? '';

  if (typeStr.contains('Timeout') ||
      typeStr.contains('connectionError') ||
      typeStr.contains('connectTimeout') ||
      typeStr.contains('receiveTimeout') ||
      typeStr.contains('sendTimeout')) {
    return const ApiException(ApiErrorKind.network, 'Network timeout or connection error');
  }

  final statusCode = err.response?.statusCode as int?;
  switch (statusCode) {
    case 401:
      return ApiException(ApiErrorKind.unauthorized, 'Unauthorized', statusCode: 401, original: err);
    case 403:
      return ApiException(ApiErrorKind.forbidden, 'Forbidden', statusCode: 403, original: err);
    case 404:
      return ApiException(ApiErrorKind.notFound, 'Not Found', statusCode: 404, original: err);
    case 409:
      return ApiException(ApiErrorKind.conflict, 'Conflict', statusCode: 409, original: err);
    default:
      if (statusCode != null && statusCode >= 500) {
        return ApiException(ApiErrorKind.server, 'Server error', statusCode: statusCode, original: err);
      }
      return ApiException(ApiErrorKind.unknown, 'Unknown error', statusCode: statusCode, original: err);
  }
}
