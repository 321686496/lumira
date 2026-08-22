# Task 3 报告 — Android（CameraX via Camera2Interop）传感器级白平衡

**状态：DONE_WITH_CONCERNS（实现完成；本机无完整 Android SDK，未真编译 Kotlin）**

## 摘要

为 camerawesome 的 Android（CameraX 1.2.2）原生层补齐了 Pigeon 通道与
`CameraAwesomeX.setWhiteBalance(mode, temperatureK)`，实现传感器级白平衡：

- **预设**（`k == null`）：直接用 `CaptureRequest.CONTROL_AWB_MODE` 常量
  （auto/daylight/cloudy/fluorescent/incandescent），交给设备 3A 处理。
- **手动色温**（`k != null`，3000–8000K，中心 5500）：关掉自动 AWB
  （`CONTROL_AWB_MODE_OFF`），用 `COLOR_CORRECTION_GAINS` 设 `RggbChannelVector`，
  增益由 Kelvin→RGB→相对增益换算得到并钳制到 `[1/4, 4]`。
- 选项经 `Camera2CameraControl.setCaptureRequestOptions` 整体替换，作用于该相机
  所有 use case（预览实时生效 + 拍照/录像直出即带）；切回预设/自动时自动清除
  之前手动设的 gains。

## 关键澄清（API 已从官方 1.2.2 sources 核证，非猜测）

原 plan 及上一版 BLOCKED 报告假设的抽象 API（`Camera2Interop.Extender(control)` /
`asCamera2CameraControl`）在 **CameraX 1.2.2 中不存在**。我下载并解析了官方
`camera-camera2-1.2.2-sources.jar` 实际源码确认：

- `androidx.camera.camera2.interop.Camera2Interop`（1.2.2）**只含**嵌套
  `Extender<T>`（构造参数是 `ExtendableBuilder`，用于 use-case 配置期，**不是**用于运行中
  `CameraControl`）。既无 `asCamera2CameraControl`，也没有
  `setCaptureRequestOption(Camera2CameraControl, ...)` 静态方法。
- `androidx.camera.camera2.interop.Camera2CameraControl`（1.2.2）提供：
  - 静态工厂 `Camera2CameraControl.from(CameraControl)`（要求 CameraControl 是
    Camera2 实现，否则抛 `IllegalArgumentException`）。
  - `setCaptureRequestOptions(CaptureRequestOptions)`（**整体替换**已设选项）、
    `addCaptureRequestOptions(...)`、`clearCaptureRequestOptions()`。
- `androidx.camera.camera2.interop.CaptureRequestOptions.Builder.setCaptureRequestOption(
  CaptureRequest.Key<ValueT>, ValueT)`。

> 因此实现选用：`Camera2CameraControl.from(cameraControl)` +
> `setCaptureRequestOptions(...)`（每次整体替换，切换模式天然清除旧 gains）。
> camerawesome 通过 camera-lifecycle 的默认 Camera2 配置初始化，`previewCamera.cameraControl`
> 即为 `Camera2CameraControlImpl`，满足 `from()` 前置条件。

## 改动文件（仅 Android 层 2 个文件被修改，Dart 通道复用 Task 2）

1. `lumira_app_flutter/packages/camerawesome/android/src/main/kotlin/com/apparence/camerawesome/cameraX/Pigeon.kt`
   - `CameraInterface` 接口新增 `fun setWhiteBalance(mode: String, temperatureK: Int?)`。
   - `setUp` 新增分发通道 `dev.flutter.pigeon.CameraInterface.setWhiteBalance`，
     `args[1]` 解包为 `Int?`，与共享 pigeon.dart（`setWhiteBalance(String, int?)`）签名一致。
2. `lumira_app_flutter/packages/camerawesome/android/src/main/kotlin/com/apparence/camerawesome/cameraX/CameraAwesomeX.kt`
   - 新增 imports：`CaptureRequest`、`RggbChannelVector`、
     `Camera2CameraControl`、`CaptureRequestOptions`、`kotlin.math.ln/pow`。
   - 新增 `override fun setWhiteBalance(mode: String, temperatureK: Int?)`（含
     `@SuppressLint("RestrictedApi")`，`try/catch { Log.e("CameraAwesome", ...) }`）。
   - 新增辅助方法 `awbModeFor(mode)`、`kelvinToRgb(k)`、`gainsFromKelvin(k)`。

## Kelvin → RGB 相对增益换算（Tanner Helland 逆算法）

- `kelvinToRgb(k)`：`t = k/100`，分段公式给出 0..255 的 (R,G,B)：
  - 红：`t<=66 ? 255 : 329.6987*(t-60)^-0.13320`
  - 绿：`t<=66 ? 99.4708*ln(t)-161.1196 : 288.1222*(t-60)^-0.07551`
  - 蓝：`t>=66 ? 255 : (t<=19 ? 0 : 138.5177*ln(t-10)-305.0448)`，再各自 /255。
- `gainsFromKelvin(k)`：相对增益 = `kelvinToRgb(k) / kelvinToRgb(5500)`，钳制 `[0.25,4]`，
  返回 `RggbChannelVector(r, g, g, b)`（构造参数序为 R、Gr、Gb、B）。
- 极性校验（节选）：
  - 3000K → r≈1.00、g≈0.75、b≈0.49 → **R>G>B**（暖，红增强）✓
  - 8000K → r≈0.87、g≈0.97、b≈1.15 → **B>G>R**（冷，蓝增强）✓
  - 5500K → 相对 5500 恒为 1.0（中性）✓

## 测试 / 验证

- `cd e:\Project\photo_post\lumira_app_flutter; flutter analyze`
  - 结果 **0 error**；418 条 `info` 级 lint，均为项目既有（含 camerawesome 包内的
    `constant_identifier_names` 等既有告警），与本次改动无新增 error。
  - 注：`flutter analyze` 只分析 Dart，不编译 Kotlin。
- **未真编译 Kotlin**：本机 Android SDK 无 `platforms`、`~/.gradle/caches` 不存在，
  `flutter build apk` 无法运行。实现所依赖的 CameraX API 均已通过官方 1.2.2
  sources jar 逐一核证（`Camera2CameraControl.from` / `setCaptureRequestOptions` /
  `CaptureRequestOptions.Builder.setCaptureRequestOption` / `RggbChannelVector` 构造序）。
  已在新代码中加 `try/catch`，`from()` 若在个别设备非 Camera2 实现仅告警不致命。

## Commit / Push

- 仅 add 本次动到的 Android 文件：
  - `camerawesome/android/.../cameraX/Pigeon.kt`
  - `camerawesome/android/.../cameraX/CameraAwesomeX.kt`
- commit：`feat(camera): Android 传感器级白平衡 (CameraX mode + gain via Camera2Interop)`
- `git push origin master` 与 `git push github master` 均需成功。
- 共享 `pigeon.dart` 本次**未改动**（Task 2 已含通道），未 add。
- 其他未提交/游离文件（`lib/features/search/*`、`lib/features/templates/*`、
  `docs/superpowers/plans/reports/task-*`、`docs/superpowers/plans/*plan/spec` 等）一律不 add。

## Concerns / 遗留

1. **未真编译**（唯一硬性 concern）：Kotlin 层未跑过 `gradle/dlv` 编译，靠源码核证。
   万一某个新 API 在 1.2.2 其他变体（camera-lifecycle 依赖解析）有细微差异，需一次真机构建
   复核；但所用类/方法均取自 `camera-camera2-1.2.2` 源码，风险低。
2. 手动 K 的 `COLOR_CORRECTION_GAINS` 换算基于标准色温→RGB 近似；个别厂商 ISP 的色彩空间差异
   可能导致 W/B 略偏，属可接受的近似（与 iOS 用内置 `deviceWhiteBalanceGainsForTemperature`
   不完全等价，但 3000 暖/8000 冷/5500 中性方向正确）。
3. `setCaptureRequestOptions` 返回的 `ListenableFuture` 被丢弃：它仅在「选项真正写入 session」
   时完成、被更新请求/camera 关闭时以 `OperationCanceledException` 失败。因我们每次整体替换，
   连续滑动时前者会被后者取代属预期，故未在该 future 上挂失败日志以免误报；同步异常已由
   `try/catch` 兜底。
4. 预设（AWB_MODE 常量）与手动（gains）都经同一 `setCaptureRequestOptions` 替换，互不残留。

## 评审与修复（评审结果：Needs fixes → 复审后定）

首次评审（Base 7f1b6c5 / Head 761c030）判定 **Needs fixes**，2 个 Important：
1. **手动 K 增益方向疑似反了**：`gainsFromKelvin = kelvinToRgb(k)/kelvinToRgb(5500)` 放大该色温的特征色偏（3000K 携 R>G>B → 更暖/更橙），而非中和；与 iOS `deviceWhiteBalanceGainsForTemperatureAndTintValues` 的**补偿式**语义不符，也不符摄影白平衡本义。修复：改为补偿式 `gain = kelvinToRgb(5500)/kelvinToRgb(k)`（3000K → R 低 B 高 → 中和暖光）。需真机黑白卡核实方向。
2. **缺实验 interop opt-in**：`Camera2CameraControl`/`CaptureRequestOptions` 属 `androidx.camera.camera2.interop` 实验 API，仅 `@SuppressLint("RestrictedApi")` 不够；库内既有为 `@androidx.annotation.OptIn(ExperimentalCamera2Interop::class)` 或 `@SuppressLint("RestrictedApi", "UnsafeOptInUsageError")`（见 CameraCapabilities.kt:13 / CameraXState.kt:198）。缺则 `UnsafeOptInUsageError` lint 可能挂构建。修复：补 opt-in/压制，与库内对齐。

✅ 正确项：Pigeon 通道名与共享 Dart 通道逐字符一致；`Camera2CameraControl.from/setCaptureRequestOptions` 是真实存在的 1.2.2 API（整体替换自动清旧 gains）；RggbChannelVector 四参序 R,G_even,G_odd,B 正确；三分支齐全；`k` 越界被 `coerceIn(3000,8000)` 钳制。

⚠️ 登记 Minor（给最终整体评审）：① `setCaptureRequestOptions` 返回的 `ListenableFuture` 被丢弃，异步失败无日志；② 增益未按设备 `COLOR_CORRECTION_GAINS_RANGE` 归一，暖端 B<1 增益在部分下界=1.0 的机型会被钳掉/拒绝；③ `kelvinToRgb` 红通道在 t 略>66 时越过 255 被 clamp，纯观感。

## 复审结论：Approved

修复 commit `e342eb6`（仅 CameraAwesomeX.kt，+15/-5），两个 Important 均已落实：
- `gainsFromKelvin` 比值反转为 `kelvinToRgb(5500)/kelvinToRgb(k)`；代入内核验：3000K→R=1.00/G=1.34/B=2.02（B>1 主导降温中和）、8000K→R=1.15/G=1.03/B=0.87（升温）、5500K 全 1。补偿方向正确，未出现 R>1/B<1。
- `setWhiteBalance` 补 `@androidx.annotation.OptIn(ExperimentalCamera2Interop::class)` + import，与 CameraCapabilities.kt:13 一致，`UnsafeOptInUsageError` 风险消除。
- 无新增回归（coerceIn 钳制/try-catch/签名均保留）。
- 唯一字面偏差（3000K 红 clamp → R 增益实为 1.0 非 <1）：源于既知红 clamp Minor，不影响补偿语义；真机方向建议最终评审后用灰卡复核。