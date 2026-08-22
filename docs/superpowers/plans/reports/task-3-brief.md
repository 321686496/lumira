# Task 3 简报 — Android 原生白平衡（CameraX via Camera2Interop）

**目标：** 在 camerawesome 的 Android（CameraX）原生层新增传感器级白平衡，用户从 Dart 调 `setWhiteBalance(mode, k)`，取景实时生效、直出即带。预设 + 手动色温 K（3000–8000）都要真正、连续地生效（与 iOS 等价）。

**重要更正：** 原 plan 写的 CameraX `setWhiteBalanceMode`/`setWhiteBalanceOffsetLinear`/`WhiteBalanceState.RANGE_*` **在 CameraX 稳定版中不存在**（官方 `CameraControl` 无从手动 AWB 接口，上游 camerawesome #584 亦确认）。改用 **Camera2Interop**：

- **预设**：`Camera2Interop.Extender(cameraControl).setCaptureRequestOption(CaptureRequest.CONTROL_AWB_MODE, <int>)`，映射：
  - auto → `CaptureRequest.CONTROL_AWB_MODE_AUTO`
  - daylight → `CONTROL_AWB_MODE_DAYLIGHT`
  - cloudy → `CONTROL_AWB_MODE_CLOUDY_DAYLIGHT`
  - fluorescent → `CONTROL_AWB_MODE_FLUORESCENT`
  - incandescent → `CONTROL_AWB_MODE_INCANDESCENT`
- **手动 K**（k != null）：关自动然后设 RGB gains：
  1. `setCaptureRequestOption(CaptureRequest.CONTROL_AWB_MODE, CaptureRequest.CONTROL_AWB_MODE_OFF)`
  2. 由开尔文 T 换算 RGB 增益 → 设 `CaptureRequest.COLOR_CORRECTION_GAINS = RggbChannelVector(r, g, g, b)`。
     换算算法（Tanner Helland 逆算法或等价的色温→RGB→相对增益）：
     - 计算 T 下对应 "(R,G,B)" 三色刺激，除以参考点（如 5500K）的三色刺激，得到相对增益；G 通道取两绿色项的平均（RggbChannelVector 的 4 项是 R,G1,G2,B）。
     - 对增益做钳制（如 [1/4, 4] 或按设备范围），避免越界。
     - 若不想写完整黑体转换，可提供"简版黑体色温→RGB"查表/分段函数（覆盖 3000–8000K 可分几十个采样点做分段线性），保证在 3000/5500/8000 处连续且单调即可；3000K 偏暖（R>G>B），8000K 偏冷（B>G>R）。优先用标准算法。
  3. 用 `cameraControl` 的 Camera2Interop 接口（CameraX 1.2.x 支持 `asCamera2CameraControl` 或 `Camera2Interop.Extender(cameraControl)`，任选项目可用者）。

**Files:**
- Modify: `lumira_app_flutter/packages/camerawesome/lib/pigeon.dart` — Task 2 已加 `setWhiteBalance` 共用通道，核对沿用，勿重复。
- Modify: `lumira_app_flutter/packages/camerawesome/android/.../Pigeon.kt`（或项目实际的 Pigeon Android 文件）— 补 `setWhiteBalance(String mode, Integer k)` 通道，接线到 `CameraAwesomeX.setWhiteBalance`。签名与 iOS 一致。
- Modify: `lumira_app_flutter/packages/camerawesome/android/src/main/kotlin/com/apparence/camerawesome/cameraX/CameraAwesomeX.kt` — 新增 `override fun setWhiteBalance(mode: String, k: Int?)`。

**Interfaces:**
- Consumes: 共享 Pigeon 通道 `CameraInterface.setWhiteBalance(String, Integer)`（Dart 侧 `CamerawesomePlugin.setWhiteBalance` 已接好）。
- Produces: Android `CameraAwesomeX.setWhiteBalance(mode, k)` → Camera2Interop 设 AWB 模式/gains。

## 全局约束（强）
- Dart 2.19.6，禁 records；签名 `setWhiteBalance(String mode, int? k)`。
- 白平衡仅实时会话调节，不写入模板 CameraParams。
- 手动 K 3000–8000、中心 5500；预设 daylight 5500/cloudy 6500/fluorescent 4200/incandescent 3000。
- 取景实时生效、直出即带。

## 实现步骤
1. 读 CameraAwesomeX.kt 现有画面控制方法（`setCorrection`/`setBrightness`/缩放等，用 `cameraState.previewCamera?.cameraControl`）当模板；读共享 `pigeon.dart` 确认 `setWhiteBalance` 通道已存在；读 Android 的 Pigeon 定义文件找加方法的位置（仿 iOS Pigeon.m 的 selector 命名 → Kotlin 侧同理）。
2. Pigeon.kt 加 `setWhiteBalance`，接线到 `CameraAwesomeX.setWhiteBalance`。
3. 实现 `setWhiteBalance(mode, k)`：
   - 取 `val control = cameraState.previewCamera?.cameraControl ?: return`。
   - `val ext = Camera2Interop.Extender(control)`（或 CamelScope 内可用的 asCamera2CameraControl）。`cameraControl`、Camera2Interop 需在合适作用域内；复用现有 CameraX interop 用法（CamelScope）。
   - 预设分支走 `ext.setCaptureRequestOption(CaptureRequest.CONTROL_AWB_MODE, wbMode)`。
   - 手动分支：先 `ext.setCaptureRequestOption(CaptureRequest.CONTROL_AWB_MODE, CaptureRequest.CONTROL_AWB_MODE_OFF)`，再 `ext.setCaptureRequestOption(CaptureRequest.COLOR_CORRECTION_GAINS, gainsFromKelvin(k))`，gainsFromKelvin 用标准色温→RGB→相对增益算法，钳制到合理范围。
   - try/catch CameraAccessException / 运行时异常，Log.e("CameraAwesome", ...)。
   - 若某些请求参数在某些设备不支持，绿区：logging 警告即可，不致命。
4. 验证：`cd lumira_app_flutter; flutter analyze` 无因本次改动新增 error。本机无完整 Android SDK 无法 `flutter build apk`，如实标记 DONE_WITH_CONCERNS 并说明未能真编译。
5. Commit + push：只 add 你动的文件（android + 若确实需改的共享 pigeon.dart），commit message `feat(camera): Android 传感器级白平衡 (CameraX mode + gain via Camera2Interop)`，然后 `git push origin master; git push github master`。两个 remote 都要成功。严禁 add 游离文件（lib/features/search/...、lib/features/templates/...、docs/superpowers/plans/reports/ 下未提交项）。

## 不确定就问
若 CameraX 版本/API 使用与上面不一致（如 RggbChannelVector 构造、Camera2Interop 方法名、CONTROL_AWB 常量）、或色温→增益换算需要，先搜/读，仍不确定就 BLOCKED 上报，别硬猜。

写详细报告到 `e:\Project\photo_post\docs\superpowers\plans\reports\task-3-report.md`（新建，覆盖实现、换算算法、analyze 结果、改动文件、concern）。返回（15 行内）：Status + commit SHA/主题 + 测试摘要 + concerns + 报告路径。