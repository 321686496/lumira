# Task 4 简报 — OHOS 原生白平衡（CameraKit）

**目标：** 在本地化的 camerawesome_ohos 包的原生（ETS/CameraKit）层新增传感器级白平衡，用户从 Dart 调 `setWhiteBalance(mode, k)` 时，取景实时生效、直出即带。

**Files（均在 `lumira_app_flutter/packages/camerawesome_ohos/`）：**
- Modify: `lib/camerawesome_plugin.dart`（把 Task 1 留的占位 `setWhiteBalance(String mode, int? k)`（现为 `return Future<void>.value();`）改为 `return CameraInterface().setWhiteBalance(mode, k);`）
- Modify: `ohos/src/main/ets/components/cameraX/Pigeon.ets`（新增 `setWhiteBalance` 通道方法 + 注册）
- Modify: `ohos/src/main/ets/components/plugin/CameraAwesomeX.ets`（新增 `setWhiteBalance(mode, k)` 转发到 `cameraState.setWhiteBalanceFn(...)`，仿 `setFlashMode` L239 / `setCorrection`/`setExposureBias` L281）
- Modify: `ohos/src/main/ets/components/cameraX/CameraState.ets`（新增 `setWhiteBalanceFn(mode, k)` 实现，仿 `setExposureBias` L1005 / `setFlashFn` L719）

**Interfaces:**
- Consumes: Task 1 Dart `CamerawesomePlugin.setWhiteBalance(String mode, int? k)`（dart 侧静态方法已在文本页面；三端签名一致，禁 Dart 3 records）
- Produces: OHOS 原生白平衡：预设映射 + 手动色温（若 CameraKit 支持任意开尔文则用；否则映射到最近预设并在报告如实说明）。

## 全局约束（来自 plan，binding）
- 禁止 Dart 3 records；三端 Dart 签名完全一致 `setWhiteBalance(String mode, int? k)`，mode ∈ {auto,daylight,cloudy,fluorescent,incandescent}，k 3000–8000 或 null。
- 白平衡仅实时会话调节，不写入模板 CameraParams；取景实时生效、直出即带。
- 手动色温 K 3000–8000、中心 5500；预设 daylight 5500 / cloudy 6500 / fluorescent 4200 / incandescent 3000。
- OHOS 原生改动需重新编译安装验证（无热重载）；本机一般无 DevEco/ohos 工具链，用 `flutter analyze` 兜底并如实标注。

## 实现步骤
1. **读现状（必做）**：读 `CameraState.ets` 的 import（`@kit.CameraKit`，`session: camera.PhotoSession | camera.VideoSession` 结构见 L64/L227-279）、`setExposureBias`（L1005，`this.session?.setExposureBias(brightness)`）、`setFlashFn`（L719-755，含 `isFlashModeSupported`/`hasFlash` 守卫与 try/catch）、以及 createSession/commit 时机；读 `CameraAwesomeX.ets` `setFlashMode`（L239）/`setExposureBias`（L281）转发写法；读 `Pigeon.ets` `setFlashMode` 通道定义（约 L740 接口 + L1169 注册）。
2. **确认 OHOS 白平衡 API 真实形态**（关键，别猜）：用 WebSearch 查 OHOS `@kit.CameraKit` / `@ohos.multimedia.camera` 的 `CameraSession` 白平衡能力，确认：
   - 是否存在 `session.isWhiteBalanceModeSupported(mode)` / `session.setWhiteBalanceMode(mode)` 及 `WhiteBalanceModeType` 枚举（AUTO / INCANDESCENT / FLUORESCENT / DAYLIGHT / CLOUDY_DAYLIGHT 等）。
   - **是否支持任意开尔文色温**。若只有预设枚举、无连续 Kelvin（多半如此）：实现策略=预设映射到对应 `WhiteBalanceModeType`；手动 K 映射到最近预设（区间 3000–8000 内选最近），并在报告 + 任务台账明示该设备限制（列入 future-optimizations 候选：OHOS 手动色温=最近预设近似，非连续）。
   - REPORT 需写清你核对到的枚举成员名与"是否支持任意 K"的结论。
3. **dart**：`lib/camerawesome_plugin.dart` 占位改为真实 Pigeon 调用。
4. **Pigeon.ets**：新增 `setWhiteBalance(mode: string, temperatureK: number | undefined): void`（或按 Pigeon 现有生成风格）接口方法 + 在 `setUp` 注册通道 `dev.flutter.pigeon.camerawesome.CameraInterface.setWhiteBalance`（通道名遵循文件中既有命名，先看 Pigeon.ets 实际 prefix）。接线到 `CameraAwesomeX.setWhiteBalance`。
5. **CameraAwesomeX.ets**：新增 `setWhiteBalance(mode: string, temperatureK?: number): void` 转发 `this.cameraState?.setWhiteBalanceFn(mode, temperatureK)`。
6. **CameraState.ets**：新增 `setWhiteBalanceFn(mode: string, k?: number): void`：
   - auto → `session.setWhiteBalanceMode(WhiteBalanceModeType.AUTO)`（若存在；守卫 isWhiteBalanceModeSupported）。
   - 预设 → 对应 WhiteBalanceModeType。
   - 手动 k → 若支持连续 Kelvin 用真实 API；否则映射最近预设。全程 try/catch + Logger.error。
   - 时刻关注 `this.session` 可能未就绪（undefined）→ 直接 return 或 guard，勿炸。
7. **验证**：`cd e:\Project\photo_post\lumira_app_flutter; flutter analyze` 无因本次改动新增 error。本机无 ohos 工具链则如实 DONE_WITH_CONCERNS。
8. **Commit + push**（只 add `packages/camerawesome_ohos` 下你动的文件）：
   ```
   git add lumira_app_flutter/packages/camerawesome_ohos/lib/camerawesome_plugin.dart lumira_app_flutter/packages/camerawesome_ohos/ohos/src/main/ets
   git commit -m "feat(camera): OHOS 传感器级白平衡 (CameraKit)"
   git push origin master ; git push github master
   ```
   **严禁** add 游离文件（lib/features/search/...、lib/features/templates/...、docs/superpowers/plans/reports/ 下未提交项、.trae/tasks/）。

## 不确定就问
OHOS API 名/枚举/是否支持任意 K 不确定 → 用 WebSearch 核对 OHOS 官方文档；仍不确定 BLOCKED/NEEDS_CONTEXT 上报，别硬造 API。

写详细报告到 `e:\Project\photo_post\docs\superpowers\plans\reports\task-4-report.md`（新建，覆盖：你核对到的 OHOS 白平衡 API 形态、是否支持任意 K、实现、analyze 结果、改动文件、concern）。返回（15 行内）：Status + commit SHA/主题 + 测试摘要 + concerns + 报告路径。