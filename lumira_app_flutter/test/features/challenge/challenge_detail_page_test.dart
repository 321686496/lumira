import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/challenge/data/challenge_pool.dart';
import 'package:lumira_app_flutter/features/challenge/pages/challenge_detail_page.dart';

/// Forced fix: picsum.photos 在测试环境对部分 seed（如 challenge-work-1）返回 400，
/// 导致 NetworkImageLoadException。该异常通过 zone.handleUncaughtError 上报到
/// flutter_test 的 _pendingException，无法通过 FlutterError.onError 拦截。
///
/// 方案：用 HttpOverrides.global 拦截所有 HTTP 请求，返回 1x1 透明 PNG 字节，
/// 让 Image.network 能成功解码，不触发 NetworkImageLoadException。
class _ImageHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

class _FakeHttpClient implements HttpClient {
  // Forced fix: NetworkImage._sharedHttpClient 会在创建 HttpClient 后立即设置
  // autoUncompress = false，noMethod 会抛 UnimplementedError 导致测试失败。
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
  Stream<S> transform<S>(
      StreamTransformer<List<int>, S> streamTransformer) {
    return Stream<List<int>>.value(_pngBytes).transform(streamTransformer);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('HttpClientResponse.${invocation.memberName}');
  }
}

void main() {
  late GoRouter router;
  FlutterExceptionHandler? originalErrorHandler;

  // 使用题库中真实存在的 id
  const testChallengeId = 'portrait_001';
  final testItem = ChallengePool.byId(testChallengeId)!;

  setUp(() {
    router = GoRouter(
      initialLocation: '/challenge/detail?challengeId=$testChallengeId',
      routes: [
        GoRoute(
          path: '/challenge',
          name: 'challenge',
          builder: (_, __) => const Scaffold(body: Center(child: Text('challenge list'))),
        ),
        GoRoute(
          path: '/challenge/detail',
          name: 'challengeDetail',
          builder: (_, state) {
            final challengeId = state.queryParams['challengeId'];
            return ChallengeDetailPage(challengeId: challengeId);
          },
        ),
        GoRoute(
          path: '/capture',
          name: 'capture',
          builder: (_, __) => const Scaffold(body: Center(child: Text('capture'))),
        ),
      ],
    );
    HttpOverrides.global = _ImageHttpOverrides();
    // 兜底：即使 HttpOverrides 未能覆盖某条路径，也吞掉 NetworkImageLoadException
    originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception is NetworkImageLoadException) return;
      originalErrorHandler?.call(details);
    };
  });

  tearDown(() {
    HttpOverrides.global = null;
    FlutterError.onError = originalErrorHandler;
  });

  Widget wrap(ThemeKey themeKey, UIStyle uiStyle) {
    return ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => themeKey),
        uiStyleProvider.overrideWith((ref) => uiStyle),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Future<void> settleOrPump(WidgetTester tester, UIStyle style) async {
    if (style == UIStyle.female) {
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
  }

  testWidgets('renders all detail sections', (tester) async {
    // Forced fix: 默认 800x600 视口无法显示 ListView 全部 section（offstage 项不构建）。
    // 设置较大视口，使所有 section 进入可视区。
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
    await tester.pumpAndSettle();

    expect(find.byType(ChallengeDetailPage), findsOneWidget);
    expect(find.text('挑战详情'), findsOneWidget);
    // Hero 卡：标题来自题库
    expect(find.text(testItem.title), findsOneWidget);
    expect(find.text('人像'), findsOneWidget); // badge = 分类 label
    expect(find.text('奖励 +${testItem.rewardXP} XP'), findsOneWidget);
    expect(find.text('0/1 已完成'), findsOneWidget);
    // 挑战要求
    expect(find.text('挑战要求'), findsOneWidget);
    expect(find.text('完成主题拍摄'), findsOneWidget);
    expect(find.text('应用拍摄技巧'), findsOneWidget);
    expect(find.text('保存到画廊'), findsOneWidget);
    // 拍摄建议
    expect(find.text('拍摄建议'), findsOneWidget);
    expect(find.text('技巧提示'), findsOneWidget);
    expect(find.text('分类标签'), findsOneWidget);
    expect(find.text('奖励'), findsOneWidget);
    // 底部按钮
    expect(find.text('返回挑战'), findsOneWidget);
    expect(find.text('再拍一张'), findsOneWidget);
  });

  testWidgets('tapping "再拍一张" pushes /capture', (tester) async {
    // Forced fix: "再拍一张" 按钮在 ListView 底部，超出默认 600 视口。
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
    await tester.pumpAndSettle();

    await tester.tap(find.text('再拍一张'));
    await tester.pumpAndSettle();

    expect(find.text('capture'), findsOneWidget);
  });

  testWidgets('tapping "返回挑战" pops back', (tester) async {
    // Forced fix: "返回挑战" 按钮在 ListView 底部，超出默认 600 视口。
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    router.go('/challenge');
    await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
    await tester.pumpAndSettle();

    router.push('/challenge/detail?challengeId=$testChallengeId');
    await tester.pumpAndSettle();

    expect(find.byType(ChallengeDetailPage), findsOneWidget);

    await tester.tap(find.text('返回挑战'));
    await tester.pumpAndSettle();

    expect(find.byType(ChallengeDetailPage), findsNothing);
    expect(find.text('challenge list'), findsOneWidget);
  });

  testWidgets('renders across 4 UI styles', (tester) async {
    for (final style in UIStyle.values) {
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, style));
      await settleOrPump(tester, style);

      expect(find.byType(ChallengeDetailPage), findsOneWidget);
      expect(find.text(testItem.title), findsOneWidget);

      await tester.pumpWidget(Container());
    }
  });

  testWidgets('renders across 8 themes', (tester) async {
    for (final theme in ThemeKey.values) {
      await tester.pumpWidget(wrap(theme, UIStyle.neumorphic));
      await tester.pumpAndSettle();

      expect(find.byType(ChallengeDetailPage), findsOneWidget);
      expect(find.text(testItem.title), findsOneWidget);

      await tester.pumpWidget(Container());
    }
  });

  testWidgets('shows "挑战不存在" when challengeId is invalid', (tester) async {
    router = GoRouter(
      initialLocation: '/challenge/detail?challengeId=nonexistent_id',
      routes: [
        GoRoute(
          path: '/challenge/detail',
          name: 'challengeDetail',
          builder: (_, state) {
            final challengeId = state.queryParams['challengeId'];
            return ChallengeDetailPage(challengeId: challengeId);
          },
        ),
      ],
    );

    await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
    await tester.pumpAndSettle();

    expect(find.text('挑战不存在'), findsOneWidget);
  });
}
