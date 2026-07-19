import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// 测试用 HttpOverrides：拦截所有 HTTP 请求返回 1x1 透明 PNG
///
/// 用途：避免 picsum.photos 等网络图片在测试中触发 NetworkImageLoadException
/// 用法：
///   setUp(() {
///     HttpOverrides.global = TestHttpOverrides();
///   });
///   tearDown(() {
///     HttpOverrides.global = null;
///   });
///
/// 来源：从 Task 2.4 challenge_page_test.dart 提取，供 Task 2.5+ 复用。
class TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

class _FakeHttpClient implements HttpClient {
  // Forced fix: NetworkImage._sharedHttpClient 会在创建后立即设置 autoUncompress = false
  @override
  bool autoUncompress = false;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeHttpClientRequest();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('HttpClient.${invocation.memberName}');
  }
}

class _FakeHttpClientRequest implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('HttpClientRequest.${invocation.memberName}');
  }
}

class _FakeHttpClientResponse implements HttpClientResponse {
  /// 1x1 透明 PNG（base64 解码）
  static final Uint8List _pngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  );

  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => _pngBytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_pngBytes).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  Stream<S> transform<S>(StreamTransformer<List<int>, S> streamTransformer) {
    return Stream<List<int>>.value(_pngBytes).transform(streamTransformer);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('HttpClientResponse.${invocation.memberName}');
  }
}
