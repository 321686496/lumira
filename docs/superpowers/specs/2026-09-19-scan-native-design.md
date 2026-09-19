# 扫码功能原生化改造设计（Scan Native）

日期：2026-09-19
状态：已评审通过，进入实施

## 背景与目标

当前扫码使用本地 fork 的 `qr_code_scanner`（`packages/qr_code_scanner`），三端实现：
- iOS：UiKitView（MTBBarcodeScanner）
- Android：AndroidView
- OHOS：OhosView 自绘相机预览 + 自研 CameraService/解码循环（慢、易黑屏）

用户要求对齐参考项目 `E:/Project/health_project/health_training`（fittrack_flutter）的原生扫码方案，OHOS 与 iOS 均改为原生扫码：

| 平台 | 现状 | 目标（参考项目同款） |
| --- | --- | --- |
| iOS | qr_code_scanner UiKitView | `mobile_scanner` ^3.5.5（AVFoundation 原生） |
| Android | qr_code_scanner AndroidView | `mobile_scanner` ^3.5.5（CameraX 原生） |
| OHOS | qr_code_scanner 自绘相机预览 | HarmonyOS Scan Kit 系统扫码界面 `startScanForResult`（相机权限系统预授权，自带相册入口），经 MethodChannel 桥接 |
| Web | 相册兜底引导卡 | 保持相册兜底引导卡 |

**决策（用户已确认）**：
1. 全平台统一：iOS/Android 用 mobile_scanner，OHOS 用 Scan Kit 系统扫码，web 保持相册兜底；删除 `packages/qr_code_scanner` fork。
2. OHOS 交互：进入扫码页自动拉起系统扫码界面；取消后留在本页显示主题化兜底引导（「相机扫码」重试 + 「从相册选择二维码」）。

兼容性事实：参考项目与 photo_post 同为 Dart `>=2.19.6 <3.0.0`（Flutter 3.7.x），`mobile_scanner: ^3.5.5` 已验证兼容。

## 架构

### 1. Dart 层：统一扫码服务 + 共享扫码组件

**新增 `lib/shared/services/scan_service.dart`**：
- `OhosScanService`（单例，对齐参考 `OhosScanService`）：
  - `static const String _channelName = 'lumira/scan';`
  - `MethodChannel _channel`
  - `Future<String?> scan()`：`invokeMethod<String>('startScan')`
    - 用户取消：原生回 `PlatformException(code: 'USER_CANCELED')` → 返回 `null`
    - 通道未注册（非 OHOS 构建）：抛 `MissingPluginException`（由调用方降级相册兜底）
    - 其他失败：抛 `PlatformException`

**新增共享扫码组件 `lib/shared/widgets/scan/scan_view.dart`**（ConsumerStatefulWidget，主题化）：
- 对外契约：`onResult(String? text)` 回调 + `TextEditingController` 不需要；由页面负责 `Navigator.pop`，保持现有「pop 识别文本 / null」约定
- 内部状态机（参考 `qr_scan_page.dart` 流程 + photo_post 主题化 UI）：
  - OHOS：
    - `_nativeScanning=true` 时显示「正在启动相机扫码…」加载态（主题化）
    - 进入页面后自动拉起 `OhosScanService.scan()`（postFrameCallback + 300ms 延迟）
    - 成功 → `onResult(raw)`
    - `USER_CANCELED` / 取消 → 引导页（「相机扫码」重试按钮 + 「从相册选择二维码」按钮）
    - `MissingPluginException` → 降级为纯相册兜底引导
    - `SCAN_FAILED` → toast + 引导页
  - iOS/Android：
    - 相机权限（permission_handler，沿用 `_requestCameraPermission` 流程）
    - 授权 → `MobileScanner(controller, onDetect, errorBuilder)` 全屏预览 + 主题化扫描框（`tokens.brand` 金色边框 250×250）+ 底部「从相册选择二维码」按钮
    - 权限拒绝 → 授权引导页 + 相册入口
    - 相机失败（errorBuilder）→ 相机兜底引导页（重试相机 + 相册入口）
  - Web/其他：现有 `_UnsupportedScanGuide` 主题化引导卡（相册入口）
- 相册识别：复用现有 `FilePickerService` + `compute(decodeQrFromBytes, bytes)`（`qr_decoder.dart`，zxing2 多策略）
- `onDetect` 去重：`_resolved` 标志防重复 pop

### 2. OHOS 原生层：新增 ScanPlugin

**新增 `ohos/entry/src/main/ets/plugins/ScanPlugin.ets`**（仿 `DeepLinkPlugin.ets` / `SystemSharePlugin.ets` 模式）：
- `export default class ScanPlugin implements FlutterPlugin, MethodCallHandler, AbilityAware`
- `onAttachedToEngine(binding)`：`new MethodChannel(binding.getBinaryMessenger(), 'lumira/scan')` + `setMethodCallHandler(this)`
- `onAttachedToAbility(binding)`：`this.uiAbility = binding.getAbility();`
- `onMethodCall`：`startScan` → `this.startScan(result)`；其他 `result.notImplemented()`
- `startScan(result)`：
  ```ts
  import { scanBarcode, scanCore } from '@kit.ScanKit';
  const options: scanBarcode.ScanOptions = {
    scanTypes: [scanCore.ScanType.ALL],
    enableMultiMode: true,
    enableAlbum: true,
  };
  scanBarcode.startScanForResult(this.uiAbility.context, options, (err, data) => {
    if (err) {
      // 1000500002：用户取消扫码
      if (err.code === 1000500002) result.error('USER_CANCELED', '用户取消扫码', null);
      else result.error('SCAN_FAILED', `code=${err.code}, msg=${err.message}`, null);
      return;
    }
    result.success(data.originalValue);
  });
  ```
- `getUniqueClassName()` 返回 `'ScanPlugin'`

**修改 `ohos/entry/src/main/ets/entryability/EntryAbility.ets`**：
- `import ScanPlugin from '../plugins/ScanPlugin';`
- `configureFlutterEngine` 中注册：`flutterEngine.getPlugins()?.add(new ScanPlugin());`

**module.json5**：无需新增权限（`ohos.permission.CAMERA` 已声明；Scan Kit 系统扫码界面调用期间预授权相机）。

### 3. 三个扫码入口页统一接入

| 文件 | 现状 | 改造 |
| --- | --- | --- |
| `lib/features/home/widgets/scan_qr_page.dart`（首页扫一扫） | QRView + 相册按钮 | 替换为共享 `ScanView`，`onResult` → `Navigator.pop(text)` |
| `lib/features/templates/widgets/template_qr_scanner_page.dart`（模板扫码） | QRView + 手动输入兜底 | 替换为共享 `ScanView`，保留「手动输入」兜底 |
| `lib/features/account/pages/recover_account_page.dart`（账号恢复扫码） | QRView | 替换为共享 `ScanView`，`onResult` → 走恢复流程 |

各页面前置/后置业务逻辑（扫码结果分发、模板导入、账号恢复）保持不变，仅替换扫描 UI 载体。

### 4. 依赖与清理

- `pubspec.yaml`：
  - 删除：`qr_code_scanner: path: packages/qr_code_scanner`
  - 新增：`mobile_scanner: ^3.5.5`
  - 注释说明：mobile_scanner 无 OHOS 原生实现，OHOS 走自研 Scan Kit MethodChannel；无 web 实现，web 走相册兜底
- 删除整个 `packages/qr_code_scanner/` 目录（含 ohos/build 构建产物）
- 更新 `lib/features/profile/data/compliance_content.dart` SDK 合规列表：`qr_code_scanner` → `mobile_scanner`（+ OHOS 侧 `@kit.ScanKit`）
- iOS `Info.plist` 已有 `NSCameraUsageDescription`，无需改动
- 检查 `pubspec.lock` 随 `flutter pub get` 自动更新

### 5. UI 细节（遵循项目 UI 铁律）

- 所有状态页（加载/引导/权限/相机失败）使用主题化：`NeuCard`、`LumiraButton`、`tokens.*` 色板，禁止硬编码黑底/白字（区别于参考项目）
- 叠在相机预览上的扫描框与提示文案：黑色半透明遮罩 + `tokens.brand` 边框（规范允许的叠图遮罩例外）
- 底部相册按钮沿用现有 `LumiraButton(ButtonVariant.secondary)` 样式

### 6. 错误处理汇总

| 场景 | 处理 |
| --- | --- |
| OHOS `USER_CANCELED` | 显示引导页（相机扫码重试 + 相册） |
| OHOS `MissingPluginException` | 降级纯相册兜底引导 |
| OHOS `SCAN_FAILED` | `LumiraToast` 提示 + 引导页 |
| iOS/Android 相机权限拒绝 | 授权引导页（授权按钮 + 相册入口） |
| iOS/Android 相机启动失败 | errorBuilder → 相机兜底引导（重试 + 相册） |
| 相册识别失败 | `LumiraToast`「未识别到二维码…」 |
| 重复回调 | `_resolved` 标志防止重复 pop |

### 7. 验证

- `flutter analyze`（lumira_app_flutter）通过
- OHOS：hvigor 构建通过；真机验证系统扫码拉起 / 取消回落 / 相册识码 / 成功回传
- iOS：xcodebuild 或真机验证 mobile_scanner 预览与识别
- Android：构建验证（可选真机）
- 3 个入口页（扫一扫 / 模板扫码 / 账号恢复）手动验证
