import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/network/api_error.dart';

void main() {
  group('classifyDioError', () {
    test('connectTimeout maps to network', () {
      final err = DioError(
        type: DioErrorType.connectTimeout,
        requestOptions: RequestOptions(path: '/test'),
      );
      final apiErr = classifyDioError(err);
      expect(apiErr.kind, ApiErrorKind.network);
      expect(apiErr.isNetworkError, true);
    });

    test('receiveTimeout maps to network', () {
      final err = DioError(
        type: DioErrorType.receiveTimeout,
        requestOptions: RequestOptions(path: '/test'),
      );
      final apiErr = classifyDioError(err);
      expect(apiErr.kind, ApiErrorKind.network);
    });

    test('401 response maps to unauthorized', () {
      final err = DioError(
        type: DioErrorType.response,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 401,
        ),
      );
      final apiErr = classifyDioError(err);
      expect(apiErr.kind, ApiErrorKind.unauthorized);
      expect(apiErr.isUnauthorized, true);
      expect(apiErr.statusCode, 401);
    });

    test('403 response maps to forbidden', () {
      final err = DioError(
        type: DioErrorType.response,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 403,
        ),
      );
      final apiErr = classifyDioError(err);
      expect(apiErr.kind, ApiErrorKind.forbidden);
    });

    test('404 response maps to notFound', () {
      final err = DioError(
        type: DioErrorType.response,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 404,
        ),
      );
      final apiErr = classifyDioError(err);
      expect(apiErr.kind, ApiErrorKind.notFound);
    });

    test('500 response maps to server', () {
      final err = DioError(
        type: DioErrorType.response,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 500,
        ),
      );
      final apiErr = classifyDioError(err);
      expect(apiErr.kind, ApiErrorKind.server);
    });
  });

  group('ApiException', () {
    test('isNetworkError getter works', () {
      const err = ApiException(ApiErrorKind.network, 'timeout');
      expect(err.isNetworkError, true);
      expect(err.isUnauthorized, false);
    });

    test('isUnauthorized getter works', () {
      const err = ApiException(ApiErrorKind.unauthorized, '401', statusCode: 401);
      expect(err.isUnauthorized, true);
      expect(err.isNetworkError, false);
    });

    test('toString contains kind', () {
      const err = ApiException(ApiErrorKind.server, 'boom', statusCode: 500);
      expect(err.toString(), contains('server'));
      expect(err.toString(), contains('500'));
    });
  });
}
