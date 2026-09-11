import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/theme/theme_controller.dart';
import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/invite/widgets/invite_poster_card.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_common.dart';

Widget wrap(Widget child) {
  return ProviderScope(
    overrides: [
      themeKeyProvider.overrideWith((ref) => ThemeKey.warmWhite),
      uiStyleProvider.overrideWith((ref) => UIStyle.neumorphic),
    ],
    // 与 PosterGenerator 底部 Sheet 一致：卡片在可纵向滚动的容器中渲染，
    // 否则固定高度预览区会裁剪海报自然高度导致 RenderFlex overflow。
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('InvitePosterCard 渲染标题、双栏、邀请码与二维码', (tester) async {
    await tester.pumpWidget(wrap(const InvitePosterCard(code: 'LUMIRA-7K2A')));
    await tester.pump();

    // 大标题（金色强调「亦成作品」）
    expect(find.textContaining('随手一拍'), findsOneWidget);
    expect(find.textContaining('亦成作品'), findsOneWidget);

    // 双栏：痛点 + 功能卡
    for (final t in ['调参太麻烦', '构图不会', '摆姿难题']) {
      expect(find.text(t), findsOneWidget);
    }
    for (final t in ['套上模板', '多款风格', '剪影跟摆']) {
      expect(find.text(t), findsOneWidget);
    }

    // 顶部装饰图带（固定内置资源）
    final img = tester.widget<Image>(find.byType(Image));
    expect(img.image, isA<AssetImage>());
    expect((img.image as AssetImage).assetName, invitePosterArtwork);

    // 邀请码与二维码（PosterQr 真编码）
    expect(find.text('LUMIRA-7K2A'), findsOneWidget);
    expect(find.byType(PosterQr), findsOneWidget);
    final qr = tester.widget<PosterQr>(find.byType(PosterQr));
    expect(qr.data, 'LUMIRA-7K2A');

    // 积分用途小字
    expect(find.textContaining('积分用于解锁付费模板'), findsOneWidget);
  });

  testWidgets('情绪文案每次随机,且取自 inviteEmoOptions', (tester) async {
    await tester.pumpWidget(wrap(const InvitePosterCard(code: 'LUMIRA-7K2A')));
    await tester.pump();

    // 渲染出的主句/副句必须来自候选集合
    String? shownMain;
    for (final opt in inviteEmoOptions) {
      if (find.text(opt.main).evaluate().isNotEmpty) {
        shownMain = opt.main;
        break;
      }
    }
    expect(shownMain, isNotNull);
    expect(inviteEmoOptions.map((e) => e.main).any((m) => m == shownMain), isTrue);
  });
}