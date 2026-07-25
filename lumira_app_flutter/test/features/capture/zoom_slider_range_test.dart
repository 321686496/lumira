import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';

void main() {
  group('zoomMultiplierToNormalized', () {
    test('front camera: 0.5x → 0.0, 1x → mid, 2x → 1.0', () {
      // Front: min=0.5, max=2.0; range = 1.5
      // 0.5 → (0.5-0.5)/1.5 = 0.0
      // 1.0 → (1.0-0.5)/1.5 = 0.333
      // 2.0 → (2.0-0.5)/1.5 = 1.0
      expect(CaptureState.zoomMultiplierToNormalized(0.5, 0.5, 2.0),
          closeTo(0.0, 0.001));
      expect(CaptureState.zoomMultiplierToNormalized(1.0, 0.5, 2.0),
          closeTo(0.3333, 0.001));
      expect(CaptureState.zoomMultiplierToNormalized(2.0, 0.5, 2.0),
          closeTo(1.0, 0.001));
    });

    test('back camera: 0.3x → 0.0, 1x → mid, 10x → 1.0', () {
      // Back: min=0.3, max=10.0; range = 9.7
      // 0.3 → 0.0
      // 1.0 → (1.0-0.3)/9.7 = 0.0722
      // 10.0 → 1.0
      expect(CaptureState.zoomMultiplierToNormalized(0.3, 0.3, 10.0),
          closeTo(0.0, 0.001));
      expect(CaptureState.zoomMultiplierToNormalized(1.0, 0.3, 10.0),
          closeTo(0.0722, 0.001));
      expect(CaptureState.zoomMultiplierToNormalized(10.0, 0.3, 10.0),
          closeTo(1.0, 0.001));
    });

    test('clamps out-of-range multipliers', () {
      expect(CaptureState.zoomMultiplierToNormalized(0.0, 0.5, 2.0),
          closeTo(0.0, 0.001));
      expect(CaptureState.zoomMultiplierToNormalized(5.0, 0.5, 2.0),
          closeTo(1.0, 0.001));
    });
  });

  group('normalizedToZoomMultiplier', () {
    test('front camera: 0.0 → 0.5x, 1.0 → 2x', () {
      expect(CaptureState.normalizedToZoomMultiplier(0.0, 0.5, 2.0),
          closeTo(0.5, 0.001));
      expect(CaptureState.normalizedToZoomMultiplier(1.0, 0.5, 2.0),
          closeTo(2.0, 0.001));
    });

    test('back camera: 0.0 → 0.3x, 1.0 → 10x', () {
      expect(CaptureState.normalizedToZoomMultiplier(0.0, 0.3, 10.0),
          closeTo(0.3, 0.001));
      expect(CaptureState.normalizedToZoomMultiplier(1.0, 0.3, 10.0),
          closeTo(10.0, 0.001));
    });
  });
}
