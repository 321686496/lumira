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
import 'package:lumira_app_flutter/features/challenge/data/challenge_models.dart';
import 'package:lumira_app_flutter/features/challenge/data/challenge_pool.dart';
import 'package:lumira_app_flutter/features/challenge/data/challenge_providers.dart';
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

  /// 测试用预选数据：已翻牌状态，使用题库第一项
  final testSelectedItem = ChallengePool.all.first;
  final testRevealedState = DailyChallengeState.revealedState(testSelectedItem);
  final testTip = ChallengeTip(
    title: '测试技巧',
    description: '测试技巧描述',
    icon: Icons.camera_alt_outlined,
    category: testSelectedItem.category,
  );
  final testSubs = <SubChallenge>[
    SubChallenge(
      id: 'sub_test_1',
      title: '测试附加挑战 1',
      icon: Icons.face_outlined,
      status: ChallengeStatus.pending,
      progressCurrent: 0,
      progressTotal: 1,
      rewardXP: 30,
      tags: [ChallengeTag(label: '+30 XP', color: ChallengeTagColor.gold)],
    ),
    SubChallenge(
      id: 'sub_test_2',
      title: '测试附加挑战 2',
      icon: Icons.landscape_outlined,
      status: ChallengeStatus.pending,
      progressCurrent: 0,
      progressTotal: 1,
      rewardXP: 25,
      tags: [ChallengeTag(label: '+25 XP', color: ChallengeTagColor.gold)],
    ),
  ];
  final testAchievements = <ChallengeAchievement>[
    ChallengeAchievement(
      id: 'first_challenge',
      title: '初出茅庐',
      description: '完成第 1 个挑战',
      icon: Icons.flag_outlined,
      unlocked: false,
      progress: 0,
    ),
  ];

  Widget wrap(ThemeKey themeKey, UIStyle uiStyle) {
    return ProviderScope(
      overrides: [
        themeKeyProvider.overrideWith((ref) => themeKey),
        uiStyleProvider.overrideWith((ref) => uiStyle),
        // 直接覆盖依赖数据库的 providers
        dailyChallengeStateProvider
            .overrideWith((ref) async => testRevealedState),
        subChallengesProvider.overrideWith((ref) async => testSubs),
        weeklyHistoryProvider.overrideWith((ref) async => <ChallengeHistoryRecord>[]),
        challengeAchievementsProvider.overrideWith((ref) async => testAchievements),
        challengeTipProvider.overrideWith((ref) async => testTip),
        // 挑战打卡：注入确定值，避免依赖真实挑战历史数据库
        challengeCheckinProvider.overrideWith((ref) async =>
            const ChallengeCheckin(
              streakDays: 0,
              completedToday: false,
              weekDays: [
                ChallengeCheckinDay(label: '一', done: false, today: false),
                ChallengeCheckinDay(label: '二', done: false, today: false),
                ChallengeCheckinDay(label: '三', done: false, today: false),
                ChallengeCheckinDay(label: '四', done: false, today: false),
                ChallengeCheckinDay(label: '五', done: false, today: false),
                ChallengeCheckinDay(label: '六', done: false, today: false),
                ChallengeCheckinDay(label: '日', done: false, today: false),
              ],
            )),
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

  testWidgets('renders all main sections after flip', (tester) async {
    // Forced fix: 默认 800x600 视口无法显示 ListView 全部 section（offstage 项不构建）。
    // 设置较大视口，使所有 section 进入可视区。
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
    await tester.pumpAndSettle();

    expect(find.byType(ChallengePage), findsOneWidget);
    expect(find.text('每日挑战'), findsOneWidget);
    // 主挑战卡：使用题库第一项的标题
    expect(find.text(testSelectedItem.title), findsOneWidget);
    // 附加挑战区块
    expect(find.text('附加挑战'), findsOneWidget);
    expect(find.text('1+2 弹性模式'), findsOneWidget);
    // 测试附加挑战
    expect(find.text('测试附加挑战 1'), findsOneWidget);
    expect(find.text('测试附加挑战 2'), findsOneWidget);
    expect(find.text('去完成'), findsWidgets);
    // 本周日历
    expect(find.text('本周日历'), findsOneWidget);
    expect(find.text('查看本周挑战进度'), findsOneWidget);
    // 挑战成就
    expect(find.text('荣誉墙'), findsOneWidget);
    expect(find.text('挑战成就'), findsOneWidget);
    expect(find.text('初出茅庐'), findsOneWidget);
    // 拍摄技巧
    expect(find.text('拍摄技巧'), findsOneWidget);
    expect(find.text('测试技巧'), findsOneWidget);
  });

  testWidgets('tapping challenge card pushes /challenge/detail with challengeId',
      (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);

    await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
    await tester.pumpAndSettle();

    // MainChallengeCard 整卡可点击跳详情（pending 态按钮"去拍照"跳拍摄页）
    await tester.tap(find.text(testSelectedItem.title));
    await tester.pumpAndSettle();

    expect(find.text('detail'), findsOneWidget);
  });

  testWidgets('renders across 4 UI styles', (tester) async {
    for (final style in UIStyle.values) {
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, style));
      await settleOrPump(tester, style);

      expect(find.byType(ChallengePage), findsOneWidget);
      expect(find.text(testSelectedItem.title), findsOneWidget);

      await tester.pumpWidget(Container());
    }
  });

  testWidgets('renders across 8 themes', (tester) async {
    for (final theme in ThemeKey.values) {
      await tester.pumpWidget(wrap(theme, UIStyle.neumorphic));
      await tester.pumpAndSettle();

      expect(find.byType(ChallengePage), findsOneWidget);
      expect(find.text(testSelectedItem.title), findsOneWidget);

      await tester.pumpWidget(Container());
    }
  });

  testWidgets('renders flip view when needsFlip state', (tester) async {
    // 覆盖为 needsFlip 状态
    final flipState = DailyChallengeState.needsFlipState(ChallengePool.all.take(3).toList());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
          uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
          dailyChallengeStateProvider.overrideWith((ref) async => flipState),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    // Forced fix: DailyFlipCard 内的 _shimmerController 调用 ..repeat()，
    // 动画永不停止，pumpAndSettle() 会等到默认 10s 超时失败。
    // 改用固定时长 pump 让 widget 完成首帧构建与布局即可。
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('今日挑战翻牌'), findsOneWidget);
    expect(find.text('从 3 张卡牌中选 1 张作为你的今日挑战'), findsOneWidget);
    expect(find.text('点击翻开'), findsWidgets);
  });
}
