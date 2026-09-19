# 扫码功能原生化改造实施计划（Scan Native）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 photo_post 扫码从本地 fork `qr_code_scanner` 改为原生扫码：iOS/Android 用 `mobile_scanner`，OHOS 用 HarmonyOS Scan Kit 系统扫码界面，web 保持相册兜底，并删除 fork。

**Architecture:** 新增共享 `ScanView` 组件（主题化，按平台分发：OHOS → 自动拉起系统扫码 / 取消后兜底引导；iOS/Android → mobile_scanner 原生预览 + 权限流程；web → 相册引导卡）+ Dart 侧 `OhosScanService`（MethodChannel 桥）+ OHOS 原生 `ScanPlugin`（Scan Kit `startScanForResult`）。三个入口页（首页扫一扫 / 模板扫码导入 / 账号恢复）统一接入 `ScanView`。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6（禁 Dart 3 records 语法）、mobile_scanner ^3.5.5、permission_handler 10.3.2、HarmonyOS Scan Kit（@kit.ScanKit）、zxing2（相册解码）。

## Global Constraints

- Dart `>=2.19.6 <3.0.0`，禁止 Dart 3 新语法；`mobile_scanner: ^3.5.5`（与参考项目同版本，已验证兼容）
- 所有 UI 必须主题化：`tokens.*` 色板 / `NeuCard` / `LumiraButton` / `LumiraToast`，禁止硬编码黑底白字；仅叠在相机预览上的遮罩可用黑色半透明
- OHOS 判定用 `defaultTargetPlatform.name == 'ohos'`（标准 SDK 无 TargetPlatform.ohos）
- 相册解码复用现有 `FilePickerService` + `compute(decodeQrFromBytes, bytes)`（qr_decoder.dart）
- MethodChannel 命名沿用现有风格：`lumira/scan`（参照 `lumira/deep_link`）
- 每次任务完成执行 `flutter analyze`（cwd: `e:\Project\photo_post\lumira_app_flutter`）确认无错误
- 参考实现：`E:/Project/health_project/health_training/fittrack_flutter`（ohos_scan_service.dart / qr_scan_page.dart / EntryAbility.ets ScanCallHandler）
- 设计文档：`docs/superpowers/specs/2026-09-19-scan-native-design.md`

---

### Task 1: pubspec 增加 mobile_scanner 依赖

**Files:**
- Modify: `e:\Project\photo_post\lumira_app_flutter\pubspec.yaml`（qr_code_scanner 块附近，L116-124 区域）

**Interfaces:**
- Consumes: 无
- Produces: `mobile_scanner` 依赖（供 Task 4 ScanView 使用）；`qr_code_scanner` 暂保留（供 Task 5-7 迁移前编译通过，Task 8 移除）

- [ ] **Step 1: 在 pubspec.yaml 的扫码依赖区新增 mobile_scanner**

将现有 qr_code_scanner 依赖块（L116-124）修改为：

```yaml
  # 二维码渲染（纯 Dart，Dart 2.19 兼容）
  qr_flutter: ^4.1.0
  # 扫码（iOS/Android 原生相机扫码，AVFoundation / CameraX；无 OHOS/web 原生实现，
  # OHOS 走自研 Scan Kit MethodChannel（见 ohos/.../plugins/ScanPlugin.ets），web 走相册兜底）
  # 与参考项目 health_training 同版本，Dart 2.19.6 兼容
  mobile_scanner: ^3.5.5
  # 扫码（本地化 fork：CPF-Flutter 鸿蒙适配，源库 qr_code_scanner 0.7.0）
  # 已合并 android/ios/ohos 三端实现到 packages/qr_code_scanner
  # TODO(Task 8): 迁移完成后移除本依赖并删除 packages/qr_code_scanner 目录
  qr_code_scanner:
    path: packages/qr_code_scanner
  # 二维码解码（纯 Dart，无原生插件；用于「从相册选择二维码」识别）
  # 纯 Dart 实现，兼容 OHOS / Dart 2.19.6，web 端亦可用
  zxing2: 0.2.0
```

- [ ] **Step 2: 执行 pub get 并确认解析成功**

Run（cwd `e:\Project\photo_post\lumira_app_flutter`）:
```
flutter pub get
```
Expected: 解析成功，`mobile_scanner 3.5.5` 出现在 `pubspec.lock`；无版本冲突报错。若报 Dart 版本冲突，说明解析到更高版本，改用 `mobile_scanner: 3.5.5`（精确锁定）。

- [ ] **Step 3: 运行 analyze 确认无回归**

```
flutter analyze
```
Expected: 无新增 error（现状 warning 可接受）。

- [ ] **Step 4: Commit**

```
git add lumira_app_flutter/pubspec.yaml lumira_app_flutter/pubspec.lock
git commit -m "chore: add mobile_scanner dependency for native qr scanning"
```

---

### Task 2: OHOS 原生 ScanPlugin + EntryAbility 注册

**Files:**
- Create: `e:\Project\photo_post\lumira_app_flutter\ohos\entry\src\main\ets\plugins\ScanPlugin.ets`
- Modify: `e:\Project\photo_post\lumira_app_flutter\ohos\entry\src\main\ets\entryability\EntryAbility.ets`（import 区 L1-9、configureFlutterEngine L12-26）

**Interfaces:**
- Consumes: 无（纯原生）
- Produces: MethodChannel `lumira/scan` 的 `startScan` 方法：成功 `result.success(originalValue)`；用户取消 `result.error('USER_CANCELED')`；失败 `result.error('SCAN_FAILED')`。供 Task 3 `OhosScanService` 调用。

- [ ] **Step 1: 创建 ScanPlugin.ets（仿 DeepLinkPlugin / SystemSharePlugin 模式）**

Create `e:\Project\photo_post\lumira_app_flutter\ohos\entry\src\main\ets\plugins\ScanPlugin.ets`:

```ts
import {
  FlutterPlugin,
  FlutterPluginBinding,
  AbilityAware,
  AbilityPluginBinding
} from '@ohos/flutter_ohos';
import MethodChannel, {
  MethodCallHandler,
  MethodResult
} from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { common, UIAbility } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

/**
 * HarmonyOS 原生扫码插件（Scan Kit 系统扫码界面）。
 * 通过 MethodChannel "lumira/scan" 与 Flutter 层通信。
 *
 * 能力：
 * - startScan：启动 Scan Kit 默认扫码界面（scanBarcode.startScanForResult），
 *   相机权限由系统扫码界面预授权，调用期间处于安全访问状态，无需应用自行申请；
 *   扫码界面自带相册识码入口（enableAlbum: true）。
 *
 * 方法：startScan
 * - 成功：result.success(originalValue)
 * - 用户取消（错误码 1000500002）：result.error('USER_CANCELED', '用户取消扫码', null)
 * - 启动/识别失败：result.error('SCAN_FAILED', ...)
 */
export default class ScanPlugin implements FlutterPlugin, MethodCallHandler, AbilityAware {
  private channel: MethodChannel | null = null;
  private uiAbility: UIAbility | null = null;

  getUniqueClassName(): string {
    return 'ScanPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'lumira/scan');
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.uiAbility = binding.getAbility();
  }

  onDetachedFromAbility(): void {
    this.uiAbility = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method === 'startScan') {
      this.startScan(result);
    } else {
      result.notImplemented();
    }
  }

  /// 启动系统扫码界面
  private startScan(result: MethodResult): void {
    try {
      const options: scanBarcode.ScanOptions = {
        scanTypes: [scanCore.ScanType.ALL],
        enableMultiMode: true,
        enableAlbum: true,
      };
      scanBarcode.startScanForResult(this.uiAbility!.context, options,
        (err: BusinessError, data: scanBarcode.ScanResult) => {
          if (err) {
            console.error(`[Lumira] ScanKit 扫码失败: code=${err.code}, msg=${err.message}`);
            // 1000500002：用户取消扫码
            if (err.code === 1000500002) {
              result.error('USER_CANCELED', '用户取消扫码', null);
            } else {
              result.error('SCAN_FAILED', `code=${err.code}, msg=${err.message}`, null);
            }
            return;
          }
          const raw: string = data.originalValue;
          console.info(`[Lumira] ScanKit 扫码成功, len=${raw.length}`);
          result.success(raw);
        });
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      console.error(`[Lumira] ScanKit 启动扫码异常: code=${err.code}, msg=${err.message}`);
      result.error('SCAN_FAILED', `code=${err.code}, msg=${err.message}`, null);
    }
  }
}
```

- [ ] **Step 2: 在 EntryAbility.ets 注册 ScanPlugin**

Modify `e:\Project\photo_post\lumira_app_flutter\ohos\entry\src\main\ets\entryability\EntryAbility.ets`:

import 区（L8 后新增一行）：
```ts
import LumiraSensorPlugin from '../plugins/LumiraSensorPlugin';
import ScanPlugin from '../plugins/ScanPlugin';
```

configureFlutterEngine（L25 后新增一行）：
```ts
    // 注册原生加速度传感器插件（水平仪，sensors_plus 无 ohos 实现）
    flutterEngine.getPlugins()?.add(new LumiraSensorPlugin());
    // 注册原生扫码插件（OHOS 无 mobile_scanner 实现，改调 HarmonyOS Scan Kit 系统扫码界面）
    flutterEngine.getPlugins()?.add(new ScanPlugin());
```

- [ ] **Step 3: 验证 OHOS 构建**

Run（cwd `e:\Project\photo_post\lumira_app_flutter\ohos`）:
```
hvigorw assembleHap --mode module -p product=default
```
Expected: 构建通过（或至少无 ScanPlugin.ets 的 ArkTS 编译错误）。若本机无 hvigorw 环境，记录并在 Task 10 统一验证。

- [ ] **Step 4: Commit**

```
git add lumira_app_flutter/ohos/entry/src/main/ets/plugins/ScanPlugin.ets lumira_app_flutter/ohos/entry/src/main/ets/entryability/EntryAbility.ets
git commit -m "feat(ohos): add ScanPlugin bridging HarmonyOS Scan Kit system scanner"
```

---

### Task 3: Dart 侧 OhosScanService

**Files:**
- Create: `e:\Project\photo_post\lumira_app_flutter\lib\shared\services\scan_service.dart`

**Interfaces:**
- Consumes: Task 2 的 `lumira/scan` 通道
- Produces: `class OhosScanService`，`static final OhosScanService instance`，`Future<String?> scan()`（取消返回 null、未注册抛 MissingPluginException、失败抛 PlatformException）。供 Task 4 ScanView 调用。

- [ ] **Step 1: 创建 scan_service.dart**

Create `e:\Project\photo_post\lumira_app_flutter\lib\shared\services\scan_service.dart`:

```dart
import 'package:flutter/services.dart';

/// OHOS 原生扫码服务（HarmonyOS Scan Kit 默认界面扫码）
///
/// mobile_scanner 在 OHOS 平台无原生实现，相机扫码改为调用系统级扫码界面
/// （@kit.ScanKit scanBarcode.startScanForResult，见 ohos/.../plugins/ScanPlugin.ets）：
/// - 相机权限由系统扫码界面预授权，调用期间处于安全访问状态，无需应用自行申请
/// - 扫码界面自带相册识码入口（原生侧开启 enableAlbum）
///
/// 返回识别到的原始文本；用户取消返回 null；其他失败抛 PlatformException；
/// 原生侧未注册通道（非 OHOS 构建）抛 MissingPluginException。
class OhosScanService {
  OhosScanService._();

  static final OhosScanService instance = OhosScanService._();

  static const String _channelName = 'lumira/scan';

  final MethodChannel _channel = const MethodChannel(_channelName);

  /// 启动系统扫码界面并返回识别到的原始文本。
  ///
  /// - 用户取消扫码：返回 null
  /// - 平台未实现（非 OHOS 构建 / 原生侧未注册通道）：抛 MissingPluginException
  /// - 扫码失败：抛 PlatformException
  Future<String?> scan() async {
    try {
      final result = await _channel.invokeMethod<String>('startScan');
      return result;
    } on PlatformException catch (e) {
      if (e.code == 'USER_CANCELED') return null;
      rethrow;
    }
  }
}
```

- [ ] **Step 2: 运行 analyze**

```
flutter analyze
```
Expected: 无 error。

- [ ] **Step 3: Commit**

```
git add lumira_app_flutter/lib/shared/services/scan_service.dart
git commit -m "feat(scan): add OhosScanService bridging native Scan Kit channel"
```

---

### Task 4: 共享 ScanView 组件

**Files:**
- Create: `e:\Project\photo_post\lumira_app_flutter\lib\shared\widgets\scan\scan_view.dart`

**Interfaces:**
- Consumes: Task 3 `OhosScanService.instance.scan()`；现有 `FilePickerService`（`core/services/file_picker_service.dart`）、`decodeQrFromBytes`（`shared/services/qr_decoder.dart`）、`themeTokensProvider`（`core/theme/theme_tokens.dart`）、`NeuCard` / `LumiraButton` / `LumiraToast`（`shared/widgets/cards/neu_card.dart`、`shared/widgets/lumira/lumira.dart`）、`permission_handler`
- Produces: `class ScanView extends ConsumerStatefulWidget`，构造参数：`required ValueChanged<String?> onResult`、`bool showGalleryButton = false`、`VoidCallback? onManualInput`、`String manualInputLabel = '手动输入'`、`String unsupportedTitle = '当前设备暂不支持摄像头扫码'`、`String unsupportedDesc = '请使用下方「从相册选择二维码」按钮，识别海报或截图中的二维码。'`。供 Task 5-7 三个页面使用。

- [ ] **Step 1: 创建 scan_view.dart**

Create `e:\Project\photo_post\lumira_app_flutter\lib\shared\widgets\scan\scan_view.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/services/file_picker_service.dart';
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
```

- [ ] **Step 2: 运行 analyze**

```
flutter analyze
```
Expected: 无 error（mobile_scanner 已由 Task 1 解析；若报 import 找不到，确认 pub get 成功）。

- [ ] **Step 3: Commit**

```
git add lumira_app_flutter/lib/shared/widgets/scan/scan_view.dart
git commit -m "feat(scan): add shared ScanView widget with per-platform native scanning"
```

---

### Task 5: 迁移首页扫一扫（scan_qr_page.dart）

**Files:**
- Modify: `e:\Project\photo_post\lumira_app_flutter\lib\features\home\widgets\scan_qr_page.dart`（整文件重写）

**Interfaces:**
- Consumes: Task 4 `ScanView`
- Produces: 无新接口；保持「pop 识别文本 / null」返回约定不变

- [ ] **Step 1: 重写 scan_qr_page.dart**

将文件内容整体替换为：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
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
```

- [ ] **Step 2: 运行 analyze**

```
flutter analyze
```
Expected: 无 error。确认无残留对 `qr_code_scanner` 的 import（`flutter analyze` 会因未使用/找不到依赖报错）。

- [ ] **Step 3: Commit**

```
git add lumira_app_flutter/lib/features/home/widgets/scan_qr_page.dart
git commit -m "refactor(scan): migrate home scan page to shared ScanView"
```

---

### Task 6: 迁移模板扫码导入（template_qr_scanner_page.dart）

**Files:**
- Modify: `e:\Project\photo_post\lumira_app_flutter\lib\features\templates\widgets\template_qr_scanner_page.dart`（整文件重写）

**Interfaces:**
- Consumes: Task 4 `ScanView`
- Produces: 无新接口；保持返回约定：扫到文本 pop `String`，「手动输入分享码」pop 空串 `''`，取消 pop null

- [ ] **Step 1: 重写 template_qr_scanner_page.dart**

将文件内容整体替换为：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
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
```

- [ ] **Step 2: 运行 analyze**

```
flutter analyze
```
Expected: 无 error。

- [ ] **Step 3: Commit**

```
git add lumira_app_flutter/lib/features/templates/widgets/template_qr_scanner_page.dart
git commit -m "refactor(scan): migrate template qr scanner page to shared ScanView"
```

---

### Task 7: 迁移账号恢复扫码（recover_account_page.dart 的 _ScannerPage）

**Files:**
- Modify: `e:\Project\photo_post\lumira_app_flutter\lib\features\account\pages\recover_account_page.dart`
  - 顶部 import 区（L1-20 附近）：移除 `qr_code_scanner`、`file_picker_service`、`qr_decoder`（若仅 _ScannerPage 使用）；新增 `scan_view` import
  - `_ScannerPage` / `_ScannerPageState` 类（L423-549）：整体替换 build 与状态
  - `_UnsupportedScanGuide` 类（L552-603 附近）：删除（由 ScanView 内部引导替代）

**Interfaces:**
- Consumes: Task 4 `ScanView`
- Produces: 无新接口；保持返回约定：扫到文本 pop `String`；「返回手动输入恢复码」pop null

- [ ] **Step 1: 先读文件确认 import 与 _ScannerPage 的准确行号**

```
Read e:\Project\photo_post\lumira_app_flutter\lib\features\account\pages\recover_account_page.dart (前 30 行确认 import)
```
若 `file_picker_service` / `qr_decoder` 仅被 `_ScannerPage` 使用，一并移除；否则保留。

- [ ] **Step 2: 替换 _ScannerPage 与 _ScannerPageState**

将 `_ScannerPage`（含其 State）与 `_UnsupportedScanGuide` 整体替换为：

```dart
/// 全屏扫描恢复二维码子页，解析成功后把原始结果回传给父页。
///
/// 扫码能力由共享 [ScanView] 提供（按平台分发，同首页扫一扫）。
/// 其余平台（含 web）展示主题化引导卡片，引导用户回到父页手动输入恢复码
/// （设计文档已约定该兜底，见 2026-08-19-account-recovery-design.md）。
class _ScannerPage extends ConsumerStatefulWidget {
  const _ScannerPage();

  @override
  ConsumerState<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends ConsumerState<_ScannerPage> {
  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '扫描恢复二维码',
        transparent: true,
        leading: AccountBackButton(tokens: tokens),
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
            // 「返回手动输入恢复码」pop null（等同取消），父页据此回到手动输入
            onManualInput: () => Navigator.of(context).pop(),
            manualInputLabel: '返回手动输入恢复码',
            unsupportedDesc:
                '请返回「找回账号」页，手动输入旧设备上保存的恢复码即可找回账号。',
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
```

- [ ] **Step 3: 清理 import**

确认移除不再使用的：
- `package:qr_code_scanner/qr_code_scanner.dart`
- `../../../core/services/file_picker_service.dart` 与 `../../../shared/services/qr_decoder.dart`（若仅 _ScannerPage 使用）
- `dart:async`（若仅 _ScannerPage 使用 `compute` 需要 `package:flutter/foundation.dart`；若该文件其他处未用则一并移除）
- 保留 `flutter/foundation.dart`（若文件其他地方用了 kIsWeb / compute；仅 _ScannerPage 用则移除）
- 新增 `../../../shared/widgets/scan/scan_view.dart`

具体以文件实际 import 使用情况为准，确保 `flutter analyze` 无 "unused import" 之外的新错误（unused import 亦需清理干净）。

- [ ] **Step 4: 运行 analyze**

```
flutter analyze
```
Expected: 无 error、无 unused import warning（对本文件）。

- [ ] **Step 5: Commit**

```
git add lumira_app_flutter/lib/features/account/pages/recover_account_page.dart
git commit -m "refactor(scan): migrate account recovery scanner to shared ScanView"
```

---

### Task 8: 移除 qr_code_scanner 依赖并删除 fork 目录

**Files:**
- Modify: `e:\Project\photo_post\lumira_app_flutter\pubspec.yaml`（移除 qr_code_scanner 块）
- Delete: `e:\Project\photo_post\lumira_app_flutter\packages\qr_code_scanner\`（整个目录，含 ohos/build 产物）

**Interfaces:**
- Consumes: Task 5-7 已完成迁移（代码中不再 import qr_code_scanner）
- Produces: 依赖树干净；pubspec.lock 移除 qr_code_scanner

- [ ] **Step 1: 前置确认无残留引用**

```
grep -rn "qr_code_scanner" e:\Project\photo_post\lumira_app_flutter\lib e:\Project\photo_post\lumira_app_flutter\pubspec.yaml
```
Expected: 仅剩 pubspec.yaml 中的依赖块与 compliance_content.dart（Task 9 处理）；lib 下无 import（Task 5-7 已清）。

- [ ] **Step 2: 从 pubspec.yaml 删除 qr_code_scanner 依赖块**

将 Task 1 中带 TODO 的块删除，保留：

```yaml
  # 二维码渲染（纯 Dart，Dart 2.19 兼容）
  qr_flutter: ^4.1.0
  # 扫码（iOS/Android 原生相机扫码，AVFoundation / CameraX；无 OHOS/web 原生实现，
  # OHOS 走自研 Scan Kit MethodChannel（见 ohos/.../plugins/ScanPlugin.ets），web 走相册兜底）
  # 与参考项目 health_training 同版本，Dart 2.19.6 兼容
  mobile_scanner: ^3.5.5
  # 二维码解码（纯 Dart，无原生插件；用于「从相册选择二维码」识别）
  # 纯 Dart 实现，兼容 OHOS / Dart 2.19.6，web 端亦可用
  zxing2: 0.2.0
```

- [ ] **Step 3: 删除 packages/qr_code_scanner 目录**

使用 DeleteFile 工具删除 `e:\Project\photo_post\lumira_app_flutter\packages\qr_code_scanner\` 下所有文件（含 build 产物），或确认目录后可整目录删除。

- [ ] **Step 4: 重新 pub get 并 analyze**

```
flutter pub get
flutter analyze
```
Expected: 解析成功（lock 中移除 qr_code_scanner），无 error。

- [ ] **Step 5: Commit**

```
git add -A lumira_app_flutter
git commit -m "chore: remove local qr_code_scanner fork, use mobile_scanner + Scan Kit"
```

---

### Task 9: 更新合规 SDK 列表

**Files:**
- Modify: `e:\Project\photo_post\lumira_app_flutter\lib\features\profile\data\compliance_content.dart`（L402-410 的「扫码识别」条目）

**Interfaces:**
- Consumes: 无
- Produces: 合规文案与依赖一致

- [ ] **Step 1: 更新「扫码识别」条目**

将：

```dart
        ComplianceListItem(
          title: '扫码识别',
          rows: [
            ComplianceKVRow(label: 'SDK 名称', value: 'qr_code_scanner'),
            ComplianceKVRow(label: '提供方', value: '开源组件'),
            ComplianceKVRow(label: '使用目的', value: '扫描二维码完成模板导入或账号恢复'),
            ComplianceKVRow(label: '收集的信息', value: '相机画面仅在本地解析'),
          ],
        ),
```

替换为：

```dart
        ComplianceListItem(
          title: '扫码识别',
          rows: [
            ComplianceKVRow(label: 'SDK 名称', value: 'mobile_scanner / HarmonyOS Scan Kit'),
            ComplianceKVRow(label: '提供方', value: '开源组件与系统能力'),
            ComplianceKVRow(label: '使用目的', value: '扫描二维码完成模板导入或账号恢复'),
            ComplianceKVRow(label: '收集的信息', value: '相机画面仅在本地解析'),
          ],
        ),
```

- [ ] **Step 2: analyze + commit**

```
flutter analyze
git add lumira_app_flutter/lib/features/profile/data/compliance_content.dart
git commit -m "chore: update compliance SDK list for scan (mobile_scanner + Scan Kit)"
```

---

### Task 10: 全量验证

**Files:** 无代码改动

**Interfaces:** 验证 Task 1-9 产物

- [ ] **Step 1: flutter analyze 全量**

Run（cwd `e:\Project\photo_post\lumira_app_flutter`）:
```
flutter analyze
```
Expected: 0 error。若有 warning，确认为改动前既有、非本次引入。

- [ ] **Step 2: grep 确认无 qr_code_scanner 残留**

```
grep -rn "qr_code_scanner" e:\Project\photo_post\lumira_app_flutter --include="*.dart" --include="*.yaml" --include="*.lock" --include="*.ets"
```
Expected: 无匹配（或仅文档/合规文案外）。若 pubspec.lock 有残留，`flutter pub get` 已清理。

- [ ] **Step 3: OHOS 构建（若有 hvigorw 环境）**

Run（cwd `e:\Project\photo_post\lumira_app_flutter\ohos`）:
```
hvigorw assembleHap --mode module -p product=default
```
Expected: 构建通过。无环境则记录待真机验证。

- [ ] **Step 4: iOS 构建（可选）**

Run（cwd `e:\Project\photo_post\lumira_app_flutter`）:
```
flutter build ios --no-codesign
```
Expected: 构建通过（mobile_scanner pod 集成成功）。

- [ ] **Step 5: 真机/模拟器手动验证清单**

- iOS：进入首页扫一扫 → 相机预览 + 金色扫描框出现 → 扫模板分享二维码 → pop 回文本并进入导入流程；拒绝权限 → 授权引导；从相册选择二维码 → 识别成功
- OHOS：进入扫一扫 → 自动拉起系统扫码界面 → 扫码成功回传；取消 → 留在本页显示「使用相机扫码」引导（重试可再拉起）；「从相册选择二维码」可用
- 模板导入页：OHOS 取消后「手动输入分享码」可用
- 找回账号页：扫码 / 「返回手动输入恢复码」行为与改造前一致
- web（若可跑）：显示引导卡 + 相册识别可用

- [ ] **Step 6: 收尾 commit（如有遗留改动）**

若验证中有零散修复，单独 commit 并注明原因。

---

## Self-Review

- **Spec coverage**：设计文档 7 节全部覆盖 —— 架构（Task 2/3/4）、3 入口页（Task 5/6/7）、依赖清理（Task 1/8）、合规（Task 9）、UI 规范（Task 4 主题化实现）、错误处理（Task 4 各状态分支）、验证（Task 10）。
- **Placeholder scan**：无 TBD/TODO（Task 1 的 `TODO(Task 8)` 为计划内占位标记，Task 8 已定义移除动作）。
- **Type consistency**：`ScanView` 参数名（onResult/showGalleryButton/onManualInput/manualInputLabel/unsupportedTitle/unsupportedDesc）在 Task 4 定义、Task 5-7 使用，完全一致；`OhosScanService.instance.scan()` 返回 `String?`，Task 4 消费一致；通道名 `lumira/scan` 在 Task 2/3 一致；错误码 `USER_CANCELED` / `SCAN_FAILED` 在 Task 2/3/4 一致。
