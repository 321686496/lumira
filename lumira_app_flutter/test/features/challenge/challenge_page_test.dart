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
import 'package:lumira_app_flutter/features/challenge/pages/challenge_page.dart';

/// Forced fix: picsum.photos 在测试环境对部分 seed（如纯数字 733872）返回 400，
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
  // autoUncompress = false，noSuchMethod 会抛 UnimplementedError 导致测试失败。
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

  setUp(() {
    router = GoRouter(
      initialLocation: '/challenge',
      routes: [
        GoRoute(
          path: '/challenge',
          name: 'challenge',
          builder: (_, __) => const ChallengePage(),
        ),
        GoRoute(
          path: '/challenge/detail',
          name: 'challengeDetail',
          builder: (_, __) => const Scaffold(body: Center(child: Text('detail'))),
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

  testWidgets('renders all main sections', (tester) async {
    // Forced fix: 默认 800x600 视口无法显示 ListView 全部 section（offstage 项不构建）。
    // 设置较大视口，使所有 section 进入可视区，让 find.text(...) 能找到 '附加挑战' / '连续打卡 7 天' 等靠后内容。
    // 计算依据：LumiraNav(56) + MainChallengeCard(~320) + 32 + 附加挑战标题(28) + 16
    // + 2 × SubChallengeRow(~140 + 100) + 12 + 32 + 明日预览标题(28) + 16 + TomorrowPreviewCard(~120)
    // + 32 + StreakCard(~240) ≈ 1300dp。视口设 1800dp 留缓冲。
    tester.binding.window.physicalSizeTestValue = const Size(800, 1800);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
    await tester.pumpAndSettle();

    expect(find.byType(ChallengePage), findsOneWidget);
    expect(find.text('每日挑战'), findsOneWidget);
    // 主挑战卡
    expect(find.text('今日挑战已完成'), findsOneWidget);
    expect(find.text('用模板拍一张人像照'), findsOneWidget);
    // 附加挑战区块
    expect(find.text('附加挑战'), findsOneWidget);
    expect(find.text('1+2 弹性模式'), findsOneWidget);
    // 支线挑战 A
    expect(find.text('3个不同模板分别拍一张'), findsOneWidget);
    // 支线挑战 B
    expect(find.text('拍一张照片完成调色并导出'), findsOneWidget);
    expect(find.text('去完成'), findsOneWidget);
    // 明日预览
    expect(find.text('明日挑战预览'), findsOneWidget);
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('明日揭晓'), findsOneWidget);
    // 连续打卡
    expect(find.text('连续打卡 7 天'), findsOneWidget);
    expect(find.text('继续保持，解锁连续打卡奖励！'), findsOneWidget);
    // tip
    expect(find.text('再坚持 1 天获得额外 50 XP'), findsOneWidget);
  });

  testWidgets('tapping "去完成" pushes /challenge/detail with challengeId',
      (tester) async {
    // Forced fix: "去完成" 按钮在 SubChallengeRow B 中，位于 ListView 中部，超出默认 600 视口。
    tester.binding.window.physicalSizeTestValue = const Size(800, 1800);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
    await tester.pumpAndSettle();

    await tester.tap(find.text('去完成'));
    await tester.pumpAndSettle();

    expect(find.text('detail'), findsOneWidget);
  });

  testWidgets('renders across 4 UI styles', (tester) async {
    for (final style in UIStyle.values) {
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, style));
      await settleOrPump(tester, style);

      expect(find.byType(ChallengePage), findsOneWidget);
      expect(find.text('今日挑战已完成'), findsOneWidget);

      await tester.pumpWidget(Container());
    }
  });

  testWidgets('renders across 8 themes', (tester) async {
    for (final theme in ThemeKey.values) {
      await tester.pumpWidget(wrap(theme, UIStyle.neumorphic));
      await tester.pumpAndSettle();

      expect(find.byType(ChallengePage), findsOneWidget);
      expect(find.text('今日挑战已完成'), findsOneWidget);

      await tester.pumpWidget(Container());
    }
  });

  testWidgets('tapping "全部" pushes /challenge/detail', (tester) async {
    // Forced fix: "全部" 链接在明日挑战预览区块标题右侧，位于 ListView 中下部，超出默认 600 视口。
    tester.binding.window.physicalSizeTestValue = const Size(800, 1800);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
    await tester.pumpAndSettle();

    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();

    expect(find.text('detail'), findsOneWidget);
  });
}
