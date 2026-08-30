import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumira_app_flutter/core/auth/auth_controller.dart';
import 'package:lumira_app_flutter/core/auth/auth_dao.dart';
import 'package:lumira_app_flutter/core/auth/auth_state.dart';
import 'package:lumira_app_flutter/core/router/route_names.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/profile/pages/profile_invite_page.dart';
import 'package:lumira_app_flutter/features/invite/data/invite_models.dart';
import 'package:lumira_app_flutter/features/invite/data/invite_repository.dart';
import 'package:lumira_app_flutter/features/rewards/data/rewards_models.dart';
import 'package:lumira_app_flutter/shared/widgets/nav/lumira_nav.dart';

import '../../../test/helpers/test_http_overrides.dart';

class _FakeInviteRepository implements InviteRepository {
  @override
  Future<InviteCode> generate() async => const InviteCode(code: 'ABC234');

  @override
  Future<ActivateInviteResponse> activate(ActivateInviteRequest req) async =>
      const ActivateInviteResponse(inviterDeviceId: 'device');

  @override
  Future<InviteStats> stats() async => throw UnimplementedError();
}

/// 测试用 AuthDao stub（避免依赖 sqflite）
class _NoopDao implements AuthDaoLike {
  @override
  Future<AuthRecord?> load() async => null;
  @override
  Future<void> save(AuthRecord r) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<void> clearToken() async {}
}

/// 测试用 AuthController stub（默认新设备，展示绑定入口）
class _FakeAuthController extends AuthController {
  _FakeAuthController()
      : super(
          dao: _NoopDao(),
          resolveDeviceId: () async => '',
          resolveOs: () => 'android',
          doRegister: ({required deviceId, required os}) async {
            return const RegisterResult(token: '', isNewDevice: false);
          },
        ) {
    state = const AuthState(
      status: AuthStatus.registered,
      isNewDevice: true,
    );
  }
}

void main() {
  late GoRouter router;
  FlutterExceptionHandler? originalErrorHandler;

  setUp(() {
    router = GoRouter(
      initialLocation: RouteNames.profileInvite,
      routes: [
        GoRoute(
          path: RouteNames.profileInvite,
          name: 'profileInvite',
          builder: (_, __) => const ProfileInvitePage(),
        ),
      ],
    );
    HttpOverrides.global = TestHttpOverrides();
    originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('NetworkImageLoadException')) return;
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
        authControllerProvider.overrideWith((ref) => _FakeAuthController()),
        themeKeyProvider.overrideWith((ref) => themeKey),
        uiStyleProvider.overrideWith((ref) => uiStyle),
        inviteRepositoryProvider.overrideWith((ref) async => _FakeInviteRepository()),
        inviteStatsProvider.overrideWith((ref) async => const InviteStats(
              totalInvites: 3,
              currentTier: 1,
              myInviteCode: 'ABC234',
              tiers: [
                InviteTierEntry(
                  tier: 1,
                  requiredInvites: 1,
                  rewards: [RewardItem(type: RewardType.template, id: 'jp-film', label: '日系胶片模板')],
                  done: true,
                  locked: false,
                ),
                InviteTierEntry(
                  tier: 2,
                  requiredInvites: 5,
                  rewards: [RewardItem(type: RewardType.templatePack, id: 'atmosphere', label: '氛围感包')],
                  done: false,
                  locked: false,
                ),
              ],
              invitees: [
                Invitee(
                  inviteeDeviceId: '33333333-3333-4333-8333-333333333333',
                  channel: 'direct',
                  activatedAt: 1700000001,
                ),
              ],
              nextTier: NextInviteTier(
                tier: 2,
                requiredInvites: 5,
                rewards: [
                  RewardItem(
                    type: RewardType.templatePack,
                    id: 'atmosphere',
                    label: '氛围感包',
                  ),
                ],
              ),
              unlockedRewards: [
                UnlockedReward(
                  id: 1,
                  tier: 1,
                  source: RewardSource.invite,
                  sourceDetail: '小雅',
                  status: UnlockStatus.unlocked,
                  rewardItems: [],
                  unlockedAt: 1700000000000,
                ),
                UnlockedReward(
                  id: 2,
                  tier: 1,
                  source: RewardSource.invite,
                  sourceDetail: '小琳',
                  status: UnlockStatus.unlocked,
                  rewardItems: [],
                  unlockedAt: 1700000000000,
                ),
                UnlockedReward(
                  id: 3,
                  tier: 1,
                  source: RewardSource.invite,
                  sourceDetail: '小悦',
                  status: UnlockStatus.unlocked,
                  rewardItems: [],
                  unlockedAt: 1700000000000,
                ),
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

  void setLargeViewport(WidgetTester tester) {
    tester.binding.window.physicalSizeTestValue = const Size(800, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
  }

  group('ProfileInvitePage', () {
    testWidgets('renders LumiraNav with title 邀请有礼', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.byType(ProfileInvitePage), findsOneWidget);
      expect(find.widgetWithText(LumiraNav, '邀请有礼'), findsOneWidget);
    });

    testWidgets('renders all sections', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 1. HeroCard
      expect(find.text('邀请好友，获得奖励'), findsOneWidget);
      expect(find.text('邀请好友一起记录美好，解锁专属模板'), findsOneWidget);
      // 2. 我的邀请码
      expect(find.text('我的邀请码：ABC234'), findsOneWidget);
      expect(find.text('复制'), findsOneWidget);
      // 3. RewardCard（dynamic tiers）
      expect(find.text('奖励阶梯'), findsOneWidget);
      expect(find.text('日系胶片模板'), findsOneWidget);
      expect(find.text('氛围感包'), findsOneWidget);
      expect(find.text('已达成'), findsOneWidget);
      // 4. ProgressCard
      expect(find.text('当前进度'), findsOneWidget);
      expect(find.text('已邀请 3 位'), findsOneWidget);
      expect(find.text('再邀请 2 人可解锁「氛围感包」'), findsOneWidget);
      // 5. 生成邀请卡片 button
      expect(find.text('生成邀请卡片'), findsOneWidget);
      // 6. CodeCard
      expect(find.text('输入好友邀请码'), findsOneWidget);
      expect(find.text('确认绑定'), findsOneWidget);
      // 7. RecordCard（real invitee）
      expect(find.text('邀请记录'), findsOneWidget);
      expect(find.text('333333…3333'), findsOneWidget);
      expect(find.text('直接邀请'), findsOneWidget);
    });

    testWidgets('renders dynamic reward ladder from tiers', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('日系胶片模板'), findsOneWidget);
      expect(find.text('氛围感包'), findsOneWidget);
      expect(find.text('已达成'), findsOneWidget);
    });

    testWidgets('renders real invite records from invitees', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('333333…3333'), findsOneWidget);
      expect(find.text('直接邀请'), findsOneWidget);
      // activatedAt 为秒级；按本地时区计算期望日期（若按毫秒解析会渲出 1970-…）
      final _t = DateTime.fromMillisecondsSinceEpoch(1700000001 * 1000);
      final _date =
          '${_t.year}-${_t.month.toString().padLeft(2, '0')}-${_t.day.toString().padLeft(2, '0')}';
      expect(find.text(_date), findsOneWidget);
    });

    testWidgets('shows my invite code', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('我的邀请码：ABC234'), findsOneWidget);
    });

    testWidgets('copy my invite code', (tester) async {
      setLargeViewport(tester);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => null,
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      await tester.tap(find.text('复制'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('邀请码已复制'), findsOneWidget);
    });

    testWidgets('tapping 生成邀请卡片 opens poster', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('生成邀请卡片'), findsOneWidget);

      await tester.tap(find.text('生成邀请卡片'));
      await settleOrPump(tester, UIStyle.neumorphic);

      expect(find.text('邀请卡片'), findsOneWidget);
      expect(find.text('复制邀请码'), findsOneWidget);
      expect(find.text('保存到相册'), findsOneWidget);
    });

    testWidgets('tapping 确认绑定 with empty code shows error SnackBar', (tester) async {
      setLargeViewport(tester);
      await tester.pumpWidget(wrap(ThemeKey.warmWhite, UIStyle.neumorphic));
      await settleOrPump(tester, UIStyle.neumorphic);

      // 不输入任何内容直接点击确认绑定
      await tester.tap(find.text('确认绑定'));
      await settleOrPump(tester, UIStyle.neumorphic);

      // LumiraToast 显示错误提示
      expect(find.text('请输入邀请码'), findsOneWidget);
    });

    testWidgets('renders correctly across all 8 themes', (tester) async {
      setLargeViewport(tester);
      for (final theme in ThemeKey.values) {
        await tester.pumpWidget(wrap(theme, UIStyle.neumorphic));
        await settleOrPump(tester, UIStyle.neumorphic);
        expect(find.byType(ProfileInvitePage), findsOneWidget, reason: 'theme=$theme');
        expect(find.text('邀请好友，获得奖励'), findsOneWidget, reason: 'theme=$theme');
      }
    });

    testWidgets('renders correctly across all 4 UI styles', (tester) async {
      setLargeViewport(tester);
      for (final style in UIStyle.values) {
        await tester.pumpWidget(wrap(ThemeKey.warmWhite, style));
        await settleOrPump(tester, style);
        expect(find.byType(ProfileInvitePage), findsOneWidget, reason: 'style=$style');
        expect(find.text('邀请好友，获得奖励'), findsOneWidget, reason: 'style=$style');
      }
    });
  });
}
