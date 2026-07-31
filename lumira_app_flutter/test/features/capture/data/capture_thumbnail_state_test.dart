// test/features/capture/data/capture_thumbnail_state_test.dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_thumbnail_state.dart';

void main() {
  test('initial state is idle', () {
    final notifier = CaptureThumbnailNotifier();
    expect(notifier.state.status, CaptureThumbnailStatus.idle);
    expect(notifier.state.captureSeq, 0);
  });

  test('startCapture transitions to processing and increments seq', () {
    final notifier = CaptureThumbnailNotifier();
    notifier.startCapture();
    expect(notifier.state.status, CaptureThumbnailStatus.processing);
    expect(notifier.state.captureSeq, 1);
    notifier.startCapture();
    expect(notifier.state.captureSeq, 2);
  });

  test('setQuickResult transitions to preview', () {
    final notifier = CaptureThumbnailNotifier();
    notifier.startCapture();
    notifier.setQuickResult(Uint8List.fromList([1, 2, 3]));
    expect(notifier.state.status, CaptureThumbnailStatus.preview);
    expect(notifier.state.quickBytes, isNotNull);
  });

  test('setFinalResult transitions to final', () {
    final notifier = CaptureThumbnailNotifier();
    notifier.startCapture();
    notifier.setFinalResult('/path/photo.jpg', 'photo_123');
    expect(notifier.state.status, CaptureThumbnailStatus.final_);
    expect(notifier.state.finalPath, '/path/photo.jpg');
    expect(notifier.state.photoId, 'photo_123');
  });

  test('reset returns to idle', () {
    final notifier = CaptureThumbnailNotifier();
    notifier.startCapture();
    notifier.reset();
    expect(notifier.state.status, CaptureThumbnailStatus.idle);
  });
}
