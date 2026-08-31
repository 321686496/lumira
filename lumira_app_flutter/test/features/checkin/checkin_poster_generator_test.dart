import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/checkin/data/checkin_models.dart';
import 'package:lumira_app_flutter/features/checkin/widgets/checkin_poster_generator.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_ratio.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_registry.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_types.dart';

CheckinRecord buildRecord({String name = '小店探店', String place = '某市某路 1 号'}) {
  final now = DateTime.now();
  return CheckinRecord(
    id: 'r1',
    name: name,
    place: place,
    category: 'cafe',
    rating: 5,
    note: '氛围很棒，值得一去',
    visitedAt: now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
    createdAt: now.millisecondsSinceEpoch,
    updatedAt: now.millisecondsSinceEpoch,
  );
}

final _tokens = ThemeTokens.of(ThemeKey.warmWhite);

void main() {
  group('buildCheckinData', () {
    test('首位为大图，其余为小图（至多 4 张）', () {
      final data = buildCheckinData(
        record: buildRecord(),
        photoUrls: ['a', 'b', 'c', 'd', 'e', 'f'],
        tokens: _tokens,
      );
      expect(data.ratio, PosterRatio.ratio34);
      expect(data.title, '小店探店');
      expect(data.place, '某市某路 1 号');
      expect(data.rating, 5.0);
      expect(data.note, '氛围很棒，值得一去');
      expect(data.thumbBuilders, hasLength(4));
    });

    test('不足 5 张时小图少几张', () {
      final data = buildCheckinData(
        record: buildRecord(),
        photoUrls: ['a', 'b'],
        tokens: _tokens,
      );
      expect(data.thumbBuilders, hasLength(1));
    });

    test('仅 1 张时无小图', () {
      final data = buildCheckinData(
        record: buildRecord(),
        photoUrls: ['a'],
        tokens: _tokens,
      );
      expect(data.thumbBuilders, isEmpty);
    });
  });

  group('样式注册', () {
    test('checkin kind 注册了 4 款样式', () {
      final styles = PosterStyleRegistry.stylesFor(PosterKind.checkin, PosterRatio.ratio34);
      expect(styles, hasLength(4));
      final ids = styles.map((s) => s.id).toSet();
      expect(ids, containsAll({'ckF', 'ckBase', 'ckV4', 'ckM4'}));
    });
  });

  group('4 款样式渲染', () {
    PosterStyleData buildData({int thumbCount = 4}) {
      return PosterStyleData(
        ratio: PosterRatio.ratio34,
        title: '小店探店',
        category: '咖啡',
        qrData: '',
        qrHint: '',
        qrSub: '',
        shareText: '推荐你这家店：小店探店',
        photoBuilder: (w, h) => Container(width: w, height: h, color: Colors.grey),
        note: '氛围很棒，值得一去',
        place: '某市某路 1 号',
        dateText: '3分钟前',
        rating: 4.5,
        thumbBuilders: [
          for (var i = 0; i < thumbCount; i++)
            (w, h) => Container(width: w, height: h, color: Colors.amber),
        ],
      );
    }

    testWidgets('温柔手帐 ckF 在 FittedBox 无界约束下可布局', (tester) async {
      final style = PosterStyleRegistry.stylesFor(PosterKind.checkin, PosterRatio.ratio34)
          .firstWhere((s) => s.id == 'ckF');
      await _pumpSteel(tester, style.builder(buildData()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('原版足迹 ckBase 在 FittedBox 无界约束下可布局', (tester) async {
      final style = PosterStyleRegistry.stylesFor(PosterKind.checkin, PosterRatio.ratio34)
          .firstWhere((s) => s.id == 'ckBase');
      await _pumpSteel(tester, style.builder(buildData()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('金字招牌 ckV4 在 FittedBox 无界约束下可布局', (tester) async {
      final style = PosterStyleRegistry.stylesFor(PosterKind.checkin, PosterRatio.ratio34)
          .firstWhere((s) => s.id == 'ckV4');
      await _pumpSteel(tester, style.builder(buildData()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('克制奢华 ckM4 在 FittedBox 无界约束下可布局', (tester) async {
      final style = PosterStyleRegistry.stylesFor(PosterKind.checkin, PosterRatio.ratio34)
          .firstWhere((s) => s.id == 'ckM4');
      await _pumpSteel(tester, style.builder(buildData()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('无小图时各样式仍可布局（全兜底路径）', (tester) async {
      final styles = PosterStyleRegistry.stylesFor(PosterKind.checkin, PosterRatio.ratio34);
      for (final s in styles) {
        await _pumpSteel(tester, s.builder(buildData(thumbCount: 0)));
        expect(tester.takeException(), isNull, reason: '${s.id} 无小图应可布局');
      }
    });
  });
}

Future<void> _pumpSteel(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          height: 700,
          child: SingleChildScrollView(
            child: Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}