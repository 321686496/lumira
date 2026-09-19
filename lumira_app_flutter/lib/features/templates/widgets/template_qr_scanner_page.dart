import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../../shared/widgets/scan/scan_view.dart';

/// 全屏相机扫码子页：扫描「二维码分享」的二维码并回传原始文本。
///
/// 扫码能力由共享 [ScanView] 提供（按平台分发，同首页扫一扫）。
///
/// 返回约定（经 [Navigator.pop] 回传给父页 [TemplateImportSheet]）：
/// - 扫到有效二维码 → pop 原始识别文本（[String]）
/// - 不支持平台「手动输入分享码」按钮 → pop 空串 `''`（父页据此进入手动输入兜底）
/// - 其余取消 / 系统返回 → pop null（父页据此关闭导入面板）
class TemplateQrScannerPage extends ConsumerStatefulWidget {
  const TemplateQrScannerPage({super.key});

  @override
  ConsumerState<TemplateQrScannerPage> createState() =>
      _TemplateQrScannerPageState();
}

class _TemplateQrScannerPageState extends ConsumerState<TemplateQrScannerPage> {
  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: const LumiraNav(
        title: '扫码导入',
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
            // 「手动输入分享码」pop 空串 `''`，父页据此进入手动输入兜底
            onManualInput: () => Navigator.of(context).pop(''),
            manualInputLabel: '手动输入分享码',
            unsupportedDesc:
                '请改用手动输入分享码（LUMIRA-分类-名称），或使用「从链接导入」。',
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
