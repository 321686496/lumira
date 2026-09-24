import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_seal.dart';

void main() {
  testWidgets('PosterSeal 渲染竖排两字且尺寸 22×22', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: PosterSeal()),
        ),
      ),
    );
    expect(find.text('如'), findsOneWidget);
    expect(find.text('画'), findsOneWidget);
    final box = tester.getSize(find.byType(PosterSeal));
    expect(box.width, 22);
    expect(box.height, 22);
  });
}
