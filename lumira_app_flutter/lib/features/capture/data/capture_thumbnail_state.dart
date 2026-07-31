import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum CaptureThumbnailStatus { idle, processing, preview, final_ }

class CaptureThumbnailState {
  const CaptureThumbnailState({
    this.status = CaptureThumbnailStatus.idle,
    this.quickBytes,
    this.finalPath,
    this.photoId,
    this.captureSeq = 0,
  });
  final CaptureThumbnailStatus status;
  final Uint8List? quickBytes;
  final String? finalPath;
  final String? photoId;
  final int captureSeq;

  CaptureThumbnailState copyWith({
    CaptureThumbnailStatus? status,
    Uint8List? quickBytes,
    String? finalPath,
    String? photoId,
    int? captureSeq,
  }) => CaptureThumbnailState(
    status: status ?? this.status,
    quickBytes: quickBytes ?? this.quickBytes,
    finalPath: finalPath ?? this.finalPath,
    photoId: photoId ?? this.photoId,
    captureSeq: captureSeq ?? this.captureSeq,
  );
}

class CaptureThumbnailNotifier extends StateNotifier<CaptureThumbnailState> {
  CaptureThumbnailNotifier() : super(const CaptureThumbnailState());

  void startCapture() {
    state = CaptureThumbnailState(
      status: CaptureThumbnailStatus.processing,
      captureSeq: state.captureSeq + 1,
    );
  }

  void setQuickResult(Uint8List bytes) {
    // 仅当当前 seq 匹配时更新（避免旧 fullProcess 覆盖新拍摄）
    state = state.copyWith(
      status: CaptureThumbnailStatus.preview,
      quickBytes: bytes,
    );
  }

  void setFinalResult(String path, String photoId) {
    state = state.copyWith(
      status: CaptureThumbnailStatus.final_,
      finalPath: path,
      photoId: photoId,
    );
  }

  void reset() {
    state = const CaptureThumbnailState();
  }
}

final captureThumbnailProvider =
    StateNotifierProvider<CaptureThumbnailNotifier, CaptureThumbnailState>(
  (ref) => CaptureThumbnailNotifier(),
);
