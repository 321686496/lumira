import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/core/utils/image_cache.dart';

void main() {
  final pngBytes = Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    ),
  );

  testWidgets('discards a stale failed response after url changes',
      (tester) async {
    final completers = <String, Completer<Uint8List?>>{
      'a': Completer<Uint8List?>(),
      'b': Completer<Uint8List?>(),
    };
    final calls = <String>[];
    Future<Uint8List?> loader(String url) {
      calls.add(url);
      return completers[url]!.future;
    }

    Widget build(String url) => Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: CachedNetworkImage(url: url, loader: loader),
          ),
        );

    await tester.pumpWidget(build('a'));
    await tester.pump();
    await tester.pumpWidget(build('b'));
    await tester.pump();
    completers['b']!.complete(pngBytes);
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsWidgets);

    completers['a']!.complete(null);
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('passes only one decode dimension to preserve aspect ratio',
      (tester) async {
    Future<Uint8List?> loader(String url) =>
        SynchronousFuture<Uint8List?>(pngBytes);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 200,
            child: CachedNetworkImage(url: 'a', loader: loader),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image;
    expect(provider, isA<ResizeImage>());
    expect((provider as ResizeImage).height, isNull);
  });

  testWidgets('reloads when a PageView page becomes visible again',
      (tester) async {
    final loadedUrls = <String>{};
    Future<Uint8List?> loader(String url) {
      loadedUrls.add(url);
      return SynchronousFuture<Uint8List?>(pngBytes);
    }

    Widget build() => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 150,
              child: PageView.builder(
                itemCount: 3,
                itemBuilder: (_, index) => CachedNetworkImage(
                  url: 'page-$index',
                  loader: loader,
                ),
              ),
            ),
          ),
        );

    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    expect(loadedUrls, contains('page-0'));

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(loadedUrls, contains('page-1'));

    await tester.drag(find.byType(PageView), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(loadedUrls, contains('page-0'));
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('reloads when a ListView item becomes visible again',
      (tester) async {
    final loadedUrls = <String>{};
    Future<Uint8List?> loader(String url) {
      loadedUrls.add(url);
      return SynchronousFuture<Uint8List?>(pngBytes);
    }

    Widget build() => MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: 30,
              itemExtent: 120,
              itemBuilder: (_, index) => CachedNetworkImage(
                url: 'item-$index',
                loader: loader,
              ),
            ),
          ),
        );

    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    expect(loadedUrls, contains('item-0'));

    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(loadedUrls, contains('item-0'));
  });

  testWidgets('shows a pending ListView image after it returns to viewport',
      (tester) async {
    final completer = Completer<Uint8List?>();
    var calls = 0;
    Future<Uint8List?> loader(String url) {
      calls++;
      return completer.future;
    }

    Widget build() => MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: 30,
              itemExtent: 120,
              itemBuilder: (_, index) => CachedNetworkImage(
                url: 'item-$index',
                loader: loader,
              ),
            ),
          ),
        );

    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    expect(calls, greaterThan(0));

    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 2000));
    await tester.pumpAndSettle();

    completer.complete(pngBytes);
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsWidgets);
  });
}
