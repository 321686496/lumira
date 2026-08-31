import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:zxing2/qrcode.dart';

import '../../../core/services/file_picker_service.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';

/// 首页「扫一扫」全屏扫码页。
///
/// - 原生相机扫码在 android / iOS / ohos（HarmonyOS）可用：本地化的
///   `qr_code_scanner` 已合并 CPF-Flutter 鸿蒙适配（OhosView 原生扫码）；
///   其余平台（含 web）展示主题化引导卡，提示使用相册识别。
/// - 底部固定「从相册选择二维码」按钮：调起系统相册选图，用纯 Dart `zxing2`
///   解码（全平台可用，web 也能识别海报 / 截图中的二维码）。
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
  final _key = GlobalKey();
  QRViewController? _controller;
  bool _picking = false;

  /// 支持原生相机扫码的平台：android / iOS / ohos；其余（含 web）走主题化回退。
  bool get _canScanNative {
    if (kIsWeb) return false;
    final p = defaultTargetPlatform;
    return p == TargetPlatform.android ||
        p == TargetPlatform.iOS ||
        // 标准 Flutter SDK 没有 TargetPlatform.ohos，用名称判断保持双 SDK 兼容
        p.name == 'ohos';
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// 从相册选择图片并尝试识别二维码，成功则 pop 回传识别文本。
  Future<void> _pickFromGallery() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final file = await FilePickerService.pickSingleImage();
      if (file == null) return; // 用户取消选择
      final full = await FilePickerService.ensureFullBytes(file);
      final bytes = full.bytes;
      if (bytes == null || bytes.isEmpty) {
        if (mounted) LumiraToast.show(context, '读取图片失败，请重试');
        return;
      }
      final text = _decodeQrFromBytes(bytes);
      if (!mounted) return;
      if (text != null && text.isNotEmpty) {
        Navigator.of(context).pop(text);
      } else {
        LumiraToast.show(context, '未识别到二维码，请选择清晰的二维码图片');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  /// 从图片字节解码二维码文本，未识别到返回 null。
  String? _decodeQrFromBytes(List<int> bytes) {
    final image = img.decodeImage(Uint8List.fromList(bytes));
    if (image == null) return null;
    try {
      final pixels = image
          .convert(numChannels: 4)
          .getBytes(order: img.ChannelOrder.rgba);
      final source =
          RGBLuminanceSource(image.width, image.height, pixels.buffer.asInt32List());
      final bitmap = BinaryBitmap(HybridBinarizer(source));
      final result = QRCodeReader().decode(bitmap);
      final text = result.text;
      return text.isNotEmpty ? text : null;
    } catch (_) {
      // 图片中无二维码，或解码失败
      return null;
    }
  }

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
          child: Column(
            children: [
              Expanded(
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: LumiraButton(
                  variant: ButtonVariant.secondary,
                  onPressed: _picking ? null : _pickFromGallery,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _picking
                            ? Icons.hourglass_top
                            : Icons.photo_library_outlined,
                      ),
                      const SizedBox(width: 8),
                      Text(_picking ? '识别中…' : '从相册选择二维码'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 读取不到原生相机扫码能力时的引导卡片（主题一致，不崩溃）。
///
/// 不 pop（与模板扫码页不同，扫一扫没有「手动输入」兜底），引导用户改用
/// 下方「从相册选择二维码」按钮识别海报 / 截图中的二维码。
class _UnsupportedScanGuide extends StatelessWidget {
  const _UnsupportedScanGuide({required this.tokens});

  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: NeuCard(
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
                '请使用下方「从相册选择二维码」按钮，识别海报或截图中的二维码。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
