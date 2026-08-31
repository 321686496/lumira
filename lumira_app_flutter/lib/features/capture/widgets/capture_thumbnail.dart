import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../data/capture_thumbnail_state.dart';

/// 底部角标缩略图。四态：idle(空)/processing(灰块)/preview(近似图)/final(最终图)
class CaptureThumbnail extends ConsumerWidget {
  const CaptureThumbnail({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(captureThumbnailProvider);
    return GestureDetector(
      onTap: () {
        // 无照片时点击给友好提示，而不是无响应
        if (state.status == CaptureThumbnailStatus.idle) {
          LumiraToast.show(context, '还没有照片可预览，先拍一张吧');
          return;
        }
        onTap?.call();
      },
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
        // 暂无照片可预览：用半透明的相机图标占位，避免「黑块+白框」的空洞观感
        return const Center(
          child: Icon(
            Icons.photo_camera_outlined,
            size: 20,
            color: Colors.white38,
          ),
        );
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
