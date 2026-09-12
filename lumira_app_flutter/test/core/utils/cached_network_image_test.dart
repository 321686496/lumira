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
    expect(find.byType(Image), findsOneWidget);

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
}
