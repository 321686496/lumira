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

  /// 早帧（FAST_MODE 低质量）路径，先快后真：作为 interim 先顶屏，full-res 后升级。
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
  }) => CaptureThumbnailState(
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
      // photoId 在快门处唯一、提前生成；全链路（interim→final→DB→预览升级）复用同一 id。
      photoId: photoId ?? state.photoId,
      captureSeq: state.captureSeq + 1,
    );
  }

  /// 先快后真：早帧（FAST_MODE 低质量帧）先作为可见缩略图/预览顶屏。
  void setInterimResult(String path, {String? photoId}) {
    state = state.copyWith(
      status: CaptureThumbnailStatus.interim,
      interimPath: path,
      photoId: photoId ?? state.photoId,
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
    // 清空 quickBytes：角标组件优先显示 quickBytes，不清空会导致成品图永远被预览遮挡
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
