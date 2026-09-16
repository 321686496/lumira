import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumira_app_flutter/features/capture/services/exif_info.dart';
import 'package:lumira_app_flutter/features/capture/widgets/exif_poster_card.dart';

/// 生成一张纯灰测试照片（真实存在本地文件，供 Image.file 加载/失败均不影响文本断言），
/// 返回临时目录（断言结束后整体删除）。
///
/// 注意：testWidgets 的 FakeAsync 环境中 `await` 真实 IO 永远不会返回，
/// 这里全部使用同步 IO（createTempSync / writeAsBytesSync / deleteSync）。
Directory _createTestPhoto(int w, int h) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(150, 150, 150));
  final dir = Directory.systemTemp.createTempSync('exif_poster_test_');
  File('${dir.path}/photo.jpg').writeAsBytesSync(img.encodeJpg(image));
  return dir;
}

Widget _wrap(Widget child) => MaterialApp(
      // 与 PosterGenerator._PosterSheet 普通模式一致：内容包在纵向 ScrollView 里，
      // 海报总高可超视口（测试默认视口 800x600，放不下完整海报）。
      home: Scaffold(
        body: SingleChildScrollView(child: Center(child: child)),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('参数齐全:渲染四要素/相机/时间/创作信息/品牌落款', (tester) async {
    final dir = _createTestPhoto(300, 400);
    addTearDown(() => dir.deleteSync(recursive: true));

    await tester.pumpWidget(_wrap(ExifPosterCard(
      photoPath: '${dir.path}/photo.jpg',
      aspect: 300 / 400,
      exif: const ExifInfo(
        cameraModel: 'HUAWEI Pura 70',
        focalLength: '35mm',
        fNumber: 'f/1.8',
        iso: 'ISO 200',
        shutterSpeed: '1/200s',
        resolution: '4096x3072',
        fileSize: '8.2 MB',
        timestamp: '2026:09:16 14:32:05',
        location: '30.25° N, 120.16° E',
        sceneName: '咖啡馆',
        template: '胶片人像',
      ),
    )));
    await tester.pump();

    expect(find.text('EXIF'), findsOneWidget);
    // 曝光四要素一行
    expect(find.textContaining('35mm'), findsOneWidget);
    expect(find.textContaining('f/1.8'), findsOneWidget);
    expect(find.textContaining('ISO 200'), findsOneWidget);
    expect(find.text('HUAWEI Pura 70'), findsOneWidget);
    // EXIF ASCII 时间格式归一化为「YYYY.MM.DD HH:MM」
    expect(find.textContaining('2026.09.16 14:32'), findsOneWidget);
    expect(find.textContaining('30.25° N'), findsOneWidget);
    // 四要素齐全时分辨率归入 meta 行
    expect(find.textContaining('4096 × 3072'), findsOneWidget);
    expect(find.textContaining('场景「咖啡馆」'), findsOneWidget);
    expect(find.textContaining('模板「胶片人像」'), findsOneWidget);
    expect(find.text('如你所见，皆成画卷'), findsOneWidget);
  });

  testWidgets('缺参降级:无相机参数时首行回退分辨率,创作信息缺省不渲染', (tester) async {
    final dir = _createTestPhoto(400, 300);
    addTearDown(() => dir.deleteSync(recursive: true));

    await tester.pumpWidget(_wrap(ExifPosterCard(
      photoPath: '${dir.path}/photo.jpg',
      aspect: 400 / 300,
      exif: const ExifInfo(
        resolution: '4096x3072',
        timestamp: '2026-09-16 14:32:05.123',
      ),
    )));
    await tester.pump();

    // 首行大字回退为分辨率
    expect(find.textContaining('4096 × 3072'), findsOneWidget);
    // DateTime.toString() 时间同样归一化
    expect(find.textContaining('2026.09.16 14:32'), findsOneWidget);
    // 场景/模板缺省不渲染
    expect(find.textContaining('场景「'), findsNothing);
    expect(find.textContaining('模板「'), findsNothing);
    // 品牌脚仍在
    expect(find.text('如你所见，皆成画卷'), findsOneWidget);
  });

  testWidgets('全空参数:不抛异常,仅照片区 + 品牌信息', (tester) async {
    final dir = _createTestPhoto(300, 300);
    addTearDown(() => dir.deleteSync(recursive: true));

    await tester.pumpWidget(_wrap(ExifPosterCard(
      photoPath: '${dir.path}/photo.jpg',
      aspect: 1,
      exif: const ExifInfo(),
    )));
    await tester.pump();

    expect(find.text('EXIF'), findsOneWidget);
    expect(find.text('如你所见，皆成画卷'), findsOneWidget);
  });
}
