import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/features/templates/widgets/pose_silhouette.dart';

void main() {
  group('PoseSilhouette', () {
    testWidgets(
        'builtin silhouette renders real SVG art instead of generic icon',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 200,
            height: 320,
            child: PoseSilhouette(
              silhouetteType: 'builtin',
              silhouetteData: 'standing-profile',
            ),
          ),
        ),
      ));

      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsNothing);
    });

    testWidgets('fills its parent box (100% width / 100% height)',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 200,
            height: 320,
            child: PoseSilhouette(
              silhouetteType: 'builtin',
              silhouetteData: 'standing-profile',
            ),
          ),
        ),
      ));

      final transform = tester.widget<Transform>(find.byType(Transform));
      final box = transform.child;
      expect(box, isA<SizedBox>());
      expect((box! as SizedBox).width, 200);
      expect((box as SizedBox).height, 320);
    });
  });

  group('SilhouetteLayer', () {
    testWidgets(
        'sizes silhouette box as 40% of area width with 1:1.6 aspect and '
        'anchors center at percentage position', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 400,
              height: 600,
              child: Stack(
                fit: StackFit.expand,
                children: const [
                  Positioned.fill(
                    child: SilhouetteLayer(
                      silhouetteType: 'builtin',
                      silhouetteData: 'standing-profile',
                      positionX: 0.25,
                      positionY: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final box = tester.widget<SizedBox>(
        find.byKey(const ValueKey('silhouette_box')),
      );
      expect(box.width, 160); // 400 * 0.4
      expect(box.height, 256); // 160 * 1.6

      final positioned = tester.widget<Positioned>(
        find.descendant(
          of: find.byType(SilhouetteLayer),
          matching: find.byType(Positioned),
        ),
      );
      expect(positioned.left, 100); // 400 * 0.25
      expect(positioned.top, 300); // 600 * 0.5
    });

    testWidgets('passes template scale and rotation through to PoseSilhouette',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 400,
              height: 600,
              child: Stack(
                fit: StackFit.expand,
                children: const [
                  Positioned.fill(
                    child: SilhouetteLayer(
                      silhouetteType: 'builtin',
                      silhouetteData: 'standing-profile',
                      positionX: 0.5,
                      positionY: 0.5,
                      scale: 1.35,
                      rotation: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final silhouette =
          tester.widget<PoseSilhouette>(find.byType(PoseSilhouette));
      expect(silhouette.scale, 1.35);
      expect(silhouette.rotation, 12);
    });
  });
}
