import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';

/// 全屏相机扫码子页：扫描「二维码分享」的二维码并回传原始文本。
///
/// 原生相机扫码仅在 android / iOS 可用。当前接入的扫码插件（qr_code_scanner）
/// 的 [QRView] 只适配了 android / iOS / web 的 platform view，未适配 OHOS，
/// 直接渲染会抛「Unsupported operation ... TargetPlatform.ohos」的运行时错误，
/// 因此对不支持平台展示与 App 主题一致的引导卡片（同「恢复账号」页的做法）。
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
  final _key = GlobalKey();
  QRViewController? _controller;

  /// 仅 android / iOS 提供原生相机扫码 platform view；其余平台（含 OHOS）走主题化回退。
  bool get _canScanNative {
    if (kIsWeb) return false;
    final p = defaultTargetPlatform;
    return p == TargetPlatform.android || p == TargetPlatform.iOS;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

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
          child: _canScanNative
              ? QRView(
                  key: _key,
                  overlay: QrScannerOverlayShape(
                    overlayColor: Colors.black26,
                    borderColor: tokens.brand,
                    borderLength: 30,
                    borderWidth: 5,
                  ),
                  onQRViewCreated: (c) {
                    _controller = c;
                    c.scannedDataStream.listen((barcode) {
                      final code = barcode.code;
                      if (code != null && code.isNotEmpty) {
                        Navigator.of(context).pop(code);
                      }
                    });
                  },
                )
              : _UnsupportedScanGuide(tokens: tokens),
        ),
      ),
    );
  }
}

/// 读取不到原生相机扫码能力的引导卡片（主题一致，不崩溃）。
///
/// 「手动输入分享码」按钮 pop 空串 `''`，父页据此进入手动输入兜底，
/// 而非把本次扫码当作「取消」（取消返回 null，父页会关闭导入面板）。
class _UnsupportedScanGuide extends StatelessWidget {
  const _UnsupportedScanGuide({required this.tokens});

  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: NeuCard(
          onTap: () => Navigator.of(context).pop(''),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: tokens.brandSubtle,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.qr_code_scanner,
                  size: 32,
                  color: tokens.brand,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '当前设备暂不支持摄像头扫码',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '请改用手动输入分享码（LUMIRA-分类-名称），或使用「从链接导入」。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              LumiraButton(
                variant: ButtonVariant.primary,
                onPressed: () => Navigator.of(context).pop(''),
                child: const Text('手动输入分享码'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}