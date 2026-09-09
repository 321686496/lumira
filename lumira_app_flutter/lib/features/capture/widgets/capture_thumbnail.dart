import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/capture_appearance.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/lumira/_internal/lumira_theme_resolver.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../data/capture_state.dart';
import '../data/capture_thumbnail_state.dart';

/// 底部角标缩略图。四态：idle(空)/processing(灰块)/preview(近似图)/final(最终图)
class CaptureThumbnail extends ConsumerWidget {
  const CaptureThumbnail({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(captureThumbnailProvider);
    // 缩略图视觉：immersive=暗底白环（现状）；theme=当前风格胶囊面
    final visual = LumiraThemeResolver.captureOverlayVisual(
      tokens: ref.watch(themeTokensProvider),
      style: ref.watch(appThemeProvider).style,
      appearance: ref.watch(CaptureState.captureAppearanceProvider),
      role: CaptureOverlayRole.pill,
      radiusDp: 8,
    );
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
          border: Border.all(color: visual.foreground, width: 2),
          color: visual.background,
        ),
        clipBehavior: Clip.antiAlias,
        child: _buildContent(state, visual),
      ),
    );
  }

  Widget _buildContent(CaptureThumbnailState state, CaptureOverlayVisual visual) {
    switch (state.status) {
      case CaptureThumbnailStatus.idle:
        // 暂无照片可预览：用半透明的相机图标占位，避免「黑块+白框」的空洞观感
        return Center(
          child: Icon(
            Icons.photo_camera_outlined,
            size: 20,
            color: visual.foregroundMuted,
          ),
        );
      case CaptureThumbnailStatus.processing:
        return Center(
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: visual.foreground),
          ),
        );
      case CaptureThumbnailStatus.interim:
        // 先快后真：早帧（低质量）先作为可见缩略图，full-res 后升级到 final_。
        final ip = state.interimPath;
        if (ip != null && File(ip).existsSync()) {
          return Image.file(File(ip), fit: BoxFit.cover);
        }
        // 早帧文件尚未就绪：退回转圈态
        return Center(
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: visual.foreground),
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
