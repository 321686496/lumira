import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum CaptureThumbnailStatus { idle, processing, interim, preview, final_ }

class CaptureThumbnailState {
  const CaptureThumbnailState({
    this.status = CaptureThumbnailStatus.idle,
    this.quickBytes,
    this.interimPath,
    this.finalPath,
    this.photoId,
    this.captureSeq = 0,
  });

  final CaptureThumbnailStatus status;
  final Uint8List? quickBytes;
  final String? interimPath;
  final String? finalPath;
  final String? photoId;
  final int captureSeq;

  CaptureThumbnailState copyWith({
    CaptureThumbnailStatus? status,
    Uint8List? quickBytes,
    String? interimPath,
    String? finalPath,
    String? photoId,
    int? captureSeq,
  }) =>
      CaptureThumbnailState(
        status: status ?? this.status,
        quickBytes: quickBytes ?? this.quickBytes,
        interimPath: interimPath ?? this.interimPath,
        finalPath: finalPath ?? this.finalPath,
        photoId: photoId ?? this.photoId,
        captureSeq: captureSeq ?? this.captureSeq,
      );
}

class CaptureThumbnailNotifier extends StateNotifier<CaptureThumbnailState> {
  CaptureThumbnailNotifier() : super(const CaptureThumbnailState());

  void startCapture({String? photoId}) {
    state = CaptureThumbnailState(
      status: CaptureThumbnailStatus.processing,
      photoId: photoId ?? state.photoId,
      captureSeq: state.captureSeq + 1,
    );
  }

  /// 先快后真：早帧/原图路径先支持点击预览，缩略图保持加载态，成品就绪后一次替换。
  void setInterimResult(String path, {String? photoId}) {
    state = state.copyWith(
      status: CaptureThumbnailStatus.processing,
      interimPath: path,
      photoId: photoId ?? state.photoId,
    );
  }

  void setFinalResult(String path, String photoId) {
    state = CaptureThumbnailState(
      status: CaptureThumbnailStatus.final_,
      finalPath: path,
      photoId: photoId,
      captureSeq: state.captureSeq,
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
