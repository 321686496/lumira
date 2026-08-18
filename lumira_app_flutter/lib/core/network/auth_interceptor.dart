import 'package:dio/dio.dart';

import '../auth/auth_controller.dart';

/// 鉴权拦截器
///
/// 1. 请求注入 Bearer token（除 /device/register 外）
/// 2. 响应 401 → 触发 AuthController 失效（不吞错，由上层决策）
class AuthInterceptor extends Interceptor {
  final AuthController _auth;

  AuthInterceptor(this._auth);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _auth.currentToken;
    final isRegisterPath = options.path.contains('/device/register');
    if (token != null && !isRegisterPath) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    final statusCode = err.response?.statusCode;
    if (statusCode == 401) {
      _auth.invalidateRegistration();
      // 触发重新注册：旧 token 失效后立即获取新 token，
      // 避免后续请求继续使用无效 token（如 token 过期或服务器 JWT_SECRET 变更）
      _auth.registerIfNeeded();
    }
    handler.next(err);
  }
}
