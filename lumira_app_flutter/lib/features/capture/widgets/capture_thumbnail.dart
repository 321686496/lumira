import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/capture_thumbnail_state.dart';

/// 底部角标缩略图。四态：idle(空)/processing(灰块)/preview(近似图)/final(最终图)
class CaptureThumbnail extends ConsumerWidget {
  const CaptureThumbnail({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(captureThumbnailProvider);
    return GestureDetector(
      onTap: state.status == CaptureThumbnailStatus.idle ? null : onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white, width: 2),
          color: Colors.black26,
        ),
        clipBehavior: Clip.antiAlias,
        child: _buildContent(state),
      ),
    );
  }

  Widget _buildContent(CaptureThumbnailState state) {
    switch (state.status) {
      case CaptureThumbnailStatus.idle:
        return const SizedBox.shrink();
      case CaptureThumbnailStatus.processing:
        return const Center(
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
        );
      case CaptureThumbnailStatus.preview:
      case CaptureThumbnailStatus.final_:
        final Uint8List? bytes = state.quickBytes;
        if (bytes != null) {
          return Image.memory(bytes, fit: BoxFit.cover);
        }
        if (state.finalPath != null) {
          return Image.file(File(state.finalPath!), fit: BoxFit.cover);
        }
        return const SizedBox.shrink();
    }
  }
}
