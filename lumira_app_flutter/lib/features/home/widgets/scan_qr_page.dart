import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../../shared/widgets/scan/scan_view.dart';

/// 首页「扫一扫」全屏扫码页。
///
/// 扫码能力由共享 [ScanView] 提供（按平台分发）：
/// - iOS / Android：mobile_scanner 原生相机预览
/// - OHOS（HarmonyOS）：Scan Kit 系统扫码界面（进入自动拉起，取消后兜底引导）
/// - Web / 其他：主题化引导卡，提示使用相册识别
///
/// 返回约定（经 [Navigator.pop] 回传）：
/// - 扫到 / 识别到有效文本 → pop 原始识别文本（[String]）
/// - 用户取消 / 系统返回 → pop null
class ScanQrPage extends ConsumerStatefulWidget {
  const ScanQrPage({super.key});

  @override
  ConsumerState<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends ConsumerState<ScanQrPage> {
  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: const LumiraNav(
        title: '扫一扫',
        transparent: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.6),
            radius: 1.2,
            colors: [
              tokens.brandSubtle.withOpacity(0.35),
              tokens.canvas.withOpacity(0.0),
            ],
          ),
        ),
        child: SafeArea(
          child: ScanView(
            showGalleryButton: true,
            onResult: (text) {
              if (text != null && text.isNotEmpty) {
                Navigator.of(context).pop(text);
              }
            },
          ),
        ),
      ),
    );
  }
}
