import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/services/file_picker_service.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../services/qr_decoder.dart';
import '../../services/scan_service.dart';
import '../cards/neu_card.dart';
import '../lumira/lumira.dart';

/// 全屏扫码能力组件（相机扫码 + 相册选图兜底，按平台分发）。
///
/// - iOS / Android：mobile_scanner 原生相机预览（AVFoundation / CameraX）
/// - OHOS（HarmonyOS）：Scan Kit 系统扫码界面（startScanForResult），进入页面
///   自动拉起；取消 / 失败后留在本页显示主题化兜底引导（可重试相机扫码）
/// - Web / 其他平台：主题化引导卡，引导使用相册识别
///
/// 返回约定（[onResult] 回调）：
/// - 识别到有效文本 → onResult(原始文本)（仅回调一次，内部已去重）
/// - 其余（取消 / 系统返回 / 手动输入）→ 不回调，由页面自行处理
class ScanView extends ConsumerStatefulWidget {
  const ScanView({
    super.key,
    required this.onResult,
    this.showGalleryButton = false,
    this.onManualInput,
    this.manualInputLabel = '手动输入',
    this.unsupportedTitle = '当前设备暂不支持摄像头扫码',
    this.unsupportedDesc = '请使用下方「从相册选择二维码」按钮，识别海报或截图中的二维码。',
  });

  /// 识别到有效二维码文本时回调（页面据此 [Navigator.pop]）
  final ValueChanged<String?> onResult;

  /// 是否在底部显示「从相册选择二维码」按钮（首页扫一扫 / 找回账号用）
  final bool showGalleryButton;

  /// 非空时，在兜底引导中显示「手动输入」按钮（模板导入 / 找回账号用）
  final VoidCallback? onManualInput;

  /// 手动输入按钮文案
  final String manualInputLabel;

  /// 不支持相机扫码平台（web / 降级）引导卡标题
  final String unsupportedTitle;

  /// 不支持相机扫码平台（web / 降级）引导卡描述
  final String unsupportedDesc;

  @override
  ConsumerState<ScanView> createState() => _ScanViewState();
}

class _ScanViewState extends ConsumerState<ScanView> {
  final MobileScannerController _controller = MobileScannerController();

  /// 是否已识别到有效码并回调（防止原生端每帧回调导致重复 pop，损坏导航栈）。
  bool _resolved = false;
  bool _picking = false;

  // 相机权限状态：_permissionChecked=false 表示还在请求
  bool _permissionChecked = false;
  bool _cameraAllowed = false;
  bool _cameraFailed = false;

  // OHOS：Scan Kit 系统扫码界面状态
  bool _ohosScanSupported = false;
  bool _nativeScanning = false;

  bool get _isOhos => defaultTargetPlatform.name == 'ohos';

  bool get _canNativePreview =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get _cameraActive =>
      _permissionChecked && _cameraAllowed && !_cameraFailed;

  @override
  void initState() {
    super.initState();
    if (_isOhos) {
      // OHOS：页面出现后自动拉起系统扫码界面（Scan Kit 默认界面扫码）
      _ohosScanSupported = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _startNativeScan();
        });
      });
    } else if (_canNativePreview) {
      _initCameraPermission();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 申请相机权限（仅 iOS / Android）
  Future<void> _initCameraPermission() async {
    try {
      final status = await Permission.camera.status;
      if (!mounted) return;
      if (status.isGranted) {
        setState(() {
          _permissionChecked = true;
          _cameraAllowed = true;
        });
        return;
      }
      if (status.isPermanentlyDenied) {
        setState(() {
          _permissionChecked = true;
          _cameraAllowed = false;
        });
        return;
      }
      final result = await Permission.camera.request();
      if (!mounted) return;
      setState(() {
        _permissionChecked = true;
        _cameraAllowed = result.isGranted;
      });
    } catch (_) {
      // 平台未实现（如桌面/测试环境）：交给相机控件自行失败并走相册兜底
      if (mounted) {
        setState(() {
          _permissionChecked = true;
          _cameraAllowed = true;
        });
      }
    }
  }

  /// 权限被拒后手动重试授权
  Future<void> _retryPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted || !status.isPermanentlyDenied) {
      final result = await Permission.camera.request();
      if (!mounted) return;
      setState(() {
        _cameraAllowed = result.isGranted;
        if (result.isGranted) _cameraFailed = false;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _cameraAllowed = false;
      _cameraFailed = false;
    });
  }

  /// OHOS：调用原生 Scan Kit 启动系统扫码界面
  ///
  /// - 识别成功：回调原始文本
  /// - 用户取消：回到本页显示兜底引导（可重试相机扫码或从相册选图）
  /// - 原生侧未接入 Scan Kit 通道：降级为纯相册兜底
  Future<void> _startNativeScan() async {
    if (_nativeScanning || _resolved) return;
    setState(() => _nativeScanning = true);
    try {
      final raw = await OhosScanService.instance.scan();
      if (raw == null || raw.isEmpty) {
        if (mounted) setState(() => _nativeScanning = false);
        return;
      }
      _resolved = true;
      if (mounted) widget.onResult(raw);
    } on MissingPluginException {
      if (mounted) {
        setState(() {
          _ohosScanSupported = false;
          _nativeScanning = false;
        });
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => _nativeScanning = false);
        if (e.code != 'USER_CANCELED') {
          LumiraToast.show(context, '无法启动相机扫码，请重试');
        }
      }
    } catch (_) {
      if (mounted) setState(() => _nativeScanning = false);
    }
  }

  /// 从相册选择图片并尝试识别二维码，成功则回调识别文本。
  ///
  /// 解码移入后台 isolate（compute）：图片解码 + 多策略识别耗时约 200ms-1s，
  /// 若在 UI 线程执行会卡住按钮 / 转圈动画。
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
      final text = await compute(decodeQrFromBytes, bytes);
      if (!mounted) return;
      if (text != null && text.isNotEmpty) {
        _resolved = true;
        widget.onResult(text);
      } else {
        LumiraToast.show(context, '未识别到二维码，请选择清晰的二维码图片');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  /// mobile_scanner 相机扫码回调（iOS / Android）
  void _onDetect(BarcodeCapture capture) {
    if (_resolved) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;
    _resolved = true;
    unawaited(_controller.stop());
    widget.onResult(raw);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    return Column(
      children: [
        Expanded(child: _buildScanArea(tokens)),
        if (widget.showGalleryButton)
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
    );
  }

  /// 扫码区域（按平台分发）
  Widget _buildScanArea(ThemeTokens tokens) {
    if (_isOhos) {
      if (_nativeScanning) return _buildNativeScanLoading(tokens);
      if (_ohosScanSupported) return _buildOhosScanFallback(tokens);
      // MissingPluginException：原生侧未接入 Scan Kit 通道，降级纯相册兜底
      return _buildUnsupportedGuide(tokens);
    }
    if (!_canNativePreview) return _buildUnsupportedGuide(tokens);
    // iOS / Android
    return Stack(
      children: [
        if (!_permissionChecked)
          _buildPermissionLoading(tokens)
        else if (!_cameraAllowed)
          _buildPermissionDenied(tokens)
        else if (_cameraFailed)
          _buildCameraFallback(tokens)
        else
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) => _buildCameraFallback(tokens),
          ),
        if (_cameraActive)
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: tokens.brand, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        if (_cameraActive)
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Text(
              '将二维码对准框内即可自动扫描',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 14,
                shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
              ),
            ),
          ),
      ],
    );
  }

  /// OHOS：正在拉起系统扫码界面
  Widget _buildNativeScanLoading(ThemeTokens tokens) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: tokens.brand),
          const SizedBox(height: 12),
          Text(
            '正在启动相机扫码…',
            style: TextStyle(color: tokens.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// OHOS：系统扫码取消 / 失败后的引导（可重试相机扫码；手动输入 / 相册由页面配置）
  Widget _buildOhosScanFallback(ThemeTokens tokens) {
    final albumHint = widget.showGalleryButton ? '，或从相册选择二维码图片' : '';
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
                '使用相机扫码',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '点击「相机扫码」启动系统扫码$albumHint。',
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
                onPressed: _nativeScanning ? null : _startNativeScan,
                child: Text(_nativeScanning ? '启动中…' : '相机扫码'),
              ),
              if (widget.onManualInput != null) ...[
                const SizedBox(height: 12),
                LumiraButton(
                  variant: ButtonVariant.secondary,
                  onPressed: widget.onManualInput,
                  child: Text(widget.manualInputLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 权限请求中（iOS / Android）
  Widget _buildPermissionLoading(ThemeTokens tokens) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: tokens.brand),
          const SizedBox(height: 12),
          Text(
            '正在申请相机权限…',
            style: TextStyle(color: tokens.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// 相机权限被拒（iOS / Android）
  Widget _buildPermissionDenied(ThemeTokens tokens) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: NeuCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.no_photography_outlined, size: 48, color: tokens.textSecondary),
              const SizedBox(height: 16),
              Text(
                '需要相机权限',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.showGalleryButton
                    ? '用于扫描二维码。您也可以使用下方「从相册选择二维码图片」导入。'
                    : '用于扫描二维码。请授权后重试。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              LumiraButton(
                variant: ButtonVariant.secondary,
                onPressed: _retryPermission,
                child: const Text('授权相机'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 相机不可用（无权限 / 平台不支持）时的兜底引导（iOS / Android）
  Widget _buildCameraFallback(ThemeTokens tokens) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: NeuCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.no_photography_outlined, size: 48, color: tokens.textSecondary),
              const SizedBox(height: 16),
              Text(
                '无法启动相机',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '请检查相机权限，或使用下方「从相册选择二维码图片」导入',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              LumiraButton(
                variant: ButtonVariant.secondary,
                onPressed: () async {
                  setState(() => _cameraFailed = false);
                  try {
                    await _controller.start();
                  } catch (_) {
                    if (mounted) setState(() => _cameraFailed = true);
                  }
                },
                child: const Text('重试相机'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 不支持相机扫码平台（web / 桌面 / OHOS 通道降级）引导卡
  Widget _buildUnsupportedGuide(ThemeTokens tokens) {
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
                widget.unsupportedTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.unsupportedDesc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: tokens.textSecondary,
                ),
              ),
              if (widget.onManualInput != null) ...[
                const SizedBox(height: 20),
                LumiraButton(
                  variant: ButtonVariant.primary,
                  onPressed: widget.onManualInput,
                  child: Text(widget.manualInputLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
